--!strict
-- World events on screen (server: WorldEvents/init.luau publishes the running
-- events in the workspace attribute WorldEvents, JSON { id, name, ends, at?,
-- direction? }). For each event that starts while you're here:
--   herald   the event scroll unrolls at the top centre with the name and which
--            way it lies, holds, and rolls up (Gui.herald queues it with the
--            tribulation ribbon). Skipped while a menu is open.
--   tracker  a countdown ring with the time left and the name, in a row at the
--            top centre, for as long as it runs (stepping aside for heralds and
--            menus).
--   pin      a gold, jade, crimson or violet pin over the spot (`at`) in the
--            world with the event's glyph and your distance.
--   chip     when the spot is off screen, a small gold plaque with the name and
--            distance that slides along an inset border of the screen to the side
--            the event lies on (behind you too), a gold chevron beside it turning to
--            point at it. It eases frame to frame, fades out as the spot comes on
--            screen (the pin takes over), stays clear of the HUD's top-right buttons
--            and bottom stack, and several chips keep apart along the border.
-- Events already running when you join get a tracker and pin without a herald.
-- The server's announce toast still carries the flavour line. Looks per event:
-- LOOKS (by def id, then kind). docs/ui/world-events.md.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local WorldEvents = require(ReplicatedStorage.Shared.WorldEvents)
local Menus = require(script.Parent.Parent.Menus)
local Ribbon = require(script.Parent.Parent.Ribbon)
local EdgeMath = require(script.Parent.EdgeMath)
local Gui = require(script.Parent.Gui)

local player = Players.LocalPlayer

local HOLD = 3.6 -- seconds the herald stays unrolled
local ROLLED = 0.3 -- the herald's width share when rolled up (caps only)
local UNROLL = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ROLLUP = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TEXT_IN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CHIP_GAP = 10 -- baseline px between chips sharing an edge
local CHIP_MARGIN = 0.04 -- share of the screen an on-screen spot must be inside for the pin to take over
local CHIP_EDGE = 8 -- the least room between a chip (pointer included) and the screen or HUD
local CHIP_EASE = 10 -- per second: how fast a chip slides, turns and fades toward its target
local CHIP_TURN = math.rad(300) -- the fastest a chip swings round the screen, radians a second
local CHIP_SAMPLE = "  ·  9999m" -- the plaque is fitted once to the name plus this, so it never jitters
-- Per layout: the plaque's height and text size, the pointer (the kit's gold chevron,
-- 210 x 129) and the insets that keep chips off the HUD (baseline px; the top clears
-- the top-right buttons and the toast, the bottom the vitals stack and, on the phone,
-- most of the touch cluster).
type ChipSpec = { height: number, text: number, pointer: Vector2, top: number, bottom: number, side: number }
local CHIP: { [string]: ChipSpec } = {
	Desktop = { height = 44, text = 16, pointer = Vector2.new(26, 16), top = 84, bottom = 222, side = 0 },
	Phone = { height = 36, text = 14, pointer = Vector2.new(22, 13.5), top = 56, bottom = 124, side = 0 },
}
local CHIP_POINTER_GAP = 2 -- between the plaque and the pointer's near edge
local GOLD_HEX = "#E6BE5C"
local URGENT = 60 -- seconds left when the time turns lacquer red
local URGENT_COLOR = Color3.fromRGB(255, 120, 100)

local PINS = {
	gold = "rbxassetid://96305267556093",
	jade = "rbxassetid://92544899232500",
	crimson = "rbxassetid://91686137821368",
	violet = "rbxassetid://105425408900947",
}

-- pin: PINS key; glyph: one character in the pin's head; short: the chip's name;
-- kicker: the herald's kicker colour (dark enough for the paper).
type Look = { pin: string, glyph: string, short: string?, kicker: Color3 }
local JADE_INK = Color3.fromRGB(30, 110, 80)
local CRIMSON_INK = Color3.fromRGB(150, 28, 30)
local GOLD_INK = Color3.fromRGB(150, 100, 20)
local VIOLET_INK = Color3.fromRGB(100, 50, 160)
local LOOKS: { [string]: Look } = {
	ThousandYearGinseng = { pin = "jade", glyph = "參", short = "Ginseng", kicker = JADE_INK },
	BeastSurge = { pin = "crimson", glyph = "獸", kicker = CRIMSON_INK },
	VioletCloudMist = { pin = "violet", glyph = "紫", short = "Violet Mist", kicker = VIOLET_INK },
	GoldenAuspiciousClouds = { pin = "gold", glyph = "金", short = "Golden Clouds", kicker = GOLD_INK },
	-- by kind
	GuardedHerb = { pin = "jade", glyph = "藥", kicker = JADE_INK },
	AuspiciousClouds = { pin = "gold", glyph = "雲", short = "Clouds", kicker = GOLD_INK },
}
local DEFAULT_LOOK: Look = { pin = "gold", glyph = "祥", kicker = CRIMSON_INK }

export type Entry = { id: string, name: string, ends: number, at: { number }?, direction: string? }

type Shown = {
	entry: Entry,
	look: Look,
	tracker: Frame,
	pin: BillboardGui?,
	anchor: Attachment?,
	chip: Chip?,
	at: Vector3?,
}

-- An edge chip's state: eased angle (radians, from the screen centre), border
-- distance and opacity; size is the plaque once fitted (nil until then).
type Chip = {
	frame: Frame,
	plate: Frame,
	pointer: ImageLabel,
	title: TextLabel,
	size: Vector2?,
	angle: number?,
	s: number?,
	alpha: number,
	text: string,
}

local WorldEventView = {}

local shown: { [string]: Shown } = {}
local order = 0
local trackerSlot: Frame
local chipSlot: Frame
local chipLayer: Frame -- the active layout (the canvas in baseline px)
local canvasScale: UIScale

local function lookOf(id: string): Look
	local def = WorldEvents.Defs[id]
	return LOOKS[id] or (def and LOOKS[def.kind]) or DEFAULT_LOOK
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function distanceText(studs: number): string
	return if studs >= 1000 then string.format("%.1fkm", studs / 1000) else `{math.floor(studs / 10 + 0.5) * 10}m`
end

-- The herald: unroll the scroll, hold, roll up.
local function herald(entry: Entry, look: Look)
	Gui.herald(function()
		if Menus.isOpen() then
			return
		end
		local scroll = Gui.place("EventScroll", "Herald") :: Frame
		scroll.AnchorPoint = Vector2.new(0.5, 0)
		scroll.Position = UDim2.fromScale(0.5, 0)
		local kicker = scroll:FindFirstChild("Kicker") :: TextLabel
		local title = scroll:FindFirstChild("Title") :: TextLabel
		kicker.Text = if entry.direction then `WORLD EVENT  ·  TO THE {string.upper(entry.direction)}` else "WORLD EVENT"
		kicker.TextColor3 = look.kicker
		title.Text = entry.name
		kicker.TextTransparency = 1
		title.TextTransparency = 1
		scroll.Size = UDim2.fromScale(ROLLED, 1)
		TweenService:Create(scroll, UNROLL, { Size = UDim2.fromScale(1, 1) }):Play()
		task.wait(UNROLL.Time * 0.7)
		TweenService:Create(kicker, TEXT_IN, { TextTransparency = 0 }):Play()
		TweenService:Create(title, TEXT_IN, { TextTransparency = 0 }):Play()
		task.wait(HOLD)
		TweenService:Create(kicker, ROLLUP, { TextTransparency = 1 }):Play()
		TweenService:Create(title, ROLLUP, { TextTransparency = 1 }):Play()
		TweenService:Create(scroll, ROLLUP, { Size = UDim2.fromScale(ROLLED, 1) }):Play()
		task.wait(ROLLUP.Time)
		Gui.fadeOut(scroll, function()
			scroll:Destroy()
		end)
		task.wait(0.15)
	end)
end

local function makePin(entry: Entry, look: Look, at: Vector3): (BillboardGui, Attachment)
	local anchor = Instance.new("Attachment")
	anchor.Name = `WorldEventPin_{entry.id}`
	anchor.WorldPosition = at
	anchor.Parent = workspace.Terrain
	local pin = Gui.clone("EventPin") :: BillboardGui
	pin.Name = `WorldEventPin_{entry.id}`
	pin.Adornee = anchor
	local art = pin:FindFirstChild("Pin") :: ImageLabel
	art.Image = PINS[look.pin] or PINS.gold;
	(art:FindFirstChild("Glyph") :: TextLabel).Text = look.glyph
	pin.Parent = player:FindFirstChildOfClass("PlayerGui")
	return pin, anchor
end

local function add(entry: Entry, announce: boolean)
	local look = lookOf(entry.id)
	order += 1
	local tracker = Gui.clone("TrackerEntry") :: Frame
	tracker.Name = entry.id
	tracker.LayoutOrder = order
	local ring = tracker:FindFirstChild("Ring") :: ImageLabel;
	(ring:FindFirstChild("Pin") :: ImageLabel).Image = PINS[look.pin] or PINS.gold
	local title = tracker:FindFirstChild("Title") :: TextLabel
	title.Text = entry.name
	title.TextSize = Gui.textSize("tracker")
	tracker.Parent = trackerSlot
	local s: Shown = { entry = entry, look = look, tracker = tracker }
	if entry.at and #entry.at == 3 then
		local at = Vector3.new(entry.at[1], entry.at[2], entry.at[3])
		s.at = at
		s.pin, s.anchor = makePin(entry, look, at)
	end
	shown[entry.id] = s
	if announce then
		herald(entry, look)
	end
end

local function remove(id: string)
	local s = shown[id]
	if not s then
		return
	end
	shown[id] = nil
	local tracker = s.tracker
	Gui.fadeOut(tracker, function()
		tracker:Destroy()
	end)
	for _, inst in { s.pin, s.anchor } :: { Instance? } do
		if inst then
			inst:Destroy()
		end
	end
	if s.chip then
		s.chip.frame:Destroy()
	end
end

local function decode(): { Entry }
	local raw = workspace:GetAttribute("WorldEvents")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	if not (ok and type(list) == "table") then
		return {}
	end
	local out = {}
	for _, e in list do
		if type(e) == "table" and type(e.id) == "string" and type(e.ends) == "number" then
			table.insert(out, {
				id = e.id,
				name = if type(e.name) == "string" then e.name else e.id,
				ends = e.ends,
				at = if type(e.at) == "table" then e.at else nil,
				direction = if type(e.direction) == "string" then e.direction else nil,
			})
		end
	end
	return out
end

local function sync(announce: boolean)
	local live: { [string]: boolean } = {}
	for _, entry in decode() do
		live[entry.id] = true
		local s = shown[entry.id]
		if s and s.entry.ends ~= entry.ends then
			remove(entry.id) -- restarted
			s = nil
		end
		if not s then
			add(entry, announce)
		elseif entry.at and not s.at then
			-- located after it started
			remove(entry.id)
			add(entry, false)
		end
	end
	for id in shown do
		if not live[id] then
			remove(id)
		end
	end
end

local function chipSpec(): ChipSpec
	return CHIP[if Gui.isPhone() then "Phone" else "Desktop"]
end

local function setAlpha(c: Chip, alpha: number)
	local t = 1 - alpha
	for _, part in (c.plate:FindFirstChild("Art") :: Frame):GetChildren() do
		if part:IsA("ImageLabel") then
			part.ImageTransparency = t
		end
	end
	c.pointer.ImageTransparency = t
	c.title.TextTransparency = t
	c.title.TextStrokeTransparency = t
	c.frame.Visible = alpha > 0.01
end

-- An edge chip for an event with a spot: hidden until its plaque is fitted.
local function makeChip(s: Shown): Chip
	local spec = chipSpec()
	local frame = Gui.clone("EdgeChip") :: Frame
	frame.Name = s.entry.id
	local plate = frame:FindFirstChild("Plate") :: Frame
	local pointer = frame:FindFirstChild("Pointer") :: ImageLabel
	local title = plate:FindFirstChild("Title") :: TextLabel
	plate.Size = UDim2.fromOffset(0, spec.height)
	pointer.Size = UDim2.fromOffset(spec.pointer.X, spec.pointer.Y)
	local c: Chip = { frame = frame, plate = plate, pointer = pointer, title = title, alpha = 0, text = "" }
	setAlpha(c, 0)
	frame.Parent = chipLayer
	local name = s.look.short or s.entry.name
	task.spawn(function()
		local fit = Ribbon.fit(plate, name .. CHIP_SAMPLE, {
			style = "gold",
			textSize = spec.text,
			height = spec.height,
		})
		c.size = Vector2.new(fit.width, spec.height)
		frame.Size = UDim2.fromOffset(fit.width, spec.height)
		title.Text = ""
	end)
	return c
end

-- The chip's half extents with the pointer orbiting it, and the pointer's orbit.
local function extents(size: Vector2, spec: ChipSpec): (Vector2, Vector2, number)
	local p = spec.pointer
	local orbit = Vector2.new(size.X / 2 + CHIP_POINTER_GAP + p.Y / 2, size.Y / 2 + CHIP_POINTER_GAP + p.Y / 2)
	local reach = math.sqrt((p.X / 2) ^ 2 + (p.Y / 2) ^ 2)
	return orbit + Vector2.new(reach, reach), orbit, reach
end

-- Every frame: slide, turn and fade the edge chips (one pass for all of them).
local function moveChips(dt: number)
	local camera = workspace.CurrentCamera
	if not (camera and chipLayer) then
		return
	end
	local spec = chipSpec()
	local scale = math.max(canvasScale.Scale, 1e-3)
	local size = chipLayer.AbsoluteSize / scale
	local origin = chipLayer.AbsolutePosition
	local centre = size / 2
	local hidden = Menus.isOpen()
	local k = 1 - math.exp(-CHIP_EASE * dt)
	local insets = { top = spec.top, bottom = spec.bottom, side = spec.side }
	-- one rect for all chips, from the widest (a shared edge keeps them in line)
	local widest = Vector2.zero
	for _, s in shown do
		local c = s.chip
		if c and c.size then
			widest = Vector2.new(math.max(widest.X, c.size.X), math.max(widest.Y, c.size.Y))
		end
	end
	if widest == Vector2.zero then
		return
	end
	local half = extents(widest, spec)
	local rect = EdgeMath.rect(size, insets, half, CHIP_EDGE)
	local items: { EdgeMath.Item & { s: number, chip: Chip, show: boolean, dir: Vector2 } } = {}
	for _, s in shown do
		local c, at = s.chip, s.at
		if not (c and c.size and at) then
			continue
		end
		local target = at + Vector3.new(0, 16, 0)
		local dir = EdgeMath.direction(camera.CFrame, target)
		-- on screen (in front and well inside the edges): the pin takes over
		local point, inFront = camera:WorldToViewportPoint(target)
		local q = (Vector2.new(point.X, point.Y) - origin) / scale
		local mx, my = size.X * CHIP_MARGIN, size.Y * CHIP_MARGIN
		local onScreen = inFront and point.Z > 0 and q.X > mx and q.X < size.X - mx and q.Y > my and q.Y < size.Y - my
		local angle = math.atan2(dir.Y, dir.X)
		c.angle = if c.angle then EdgeMath.easeAngle(c.angle :: number, angle, k, CHIP_TURN * dt) else angle
		local eased = Vector2.new(math.cos(c.angle :: number), math.sin(c.angle :: number))
		local sTarget = EdgeMath.param(rect, EdgeMath.hit(rect, centre, eased))
		table.insert(items, { s = sTarget, size = c.size :: Vector2, chip = c, show = not (hidden or onScreen), dir = eased })
	end
	EdgeMath.separate(rect, items :: any, CHIP_GAP)
	for _, it in items do
		local c = it.chip
		c.s = if c.s then EdgeMath.ease(rect, c.s :: number, it.s, k) else it.s
		c.alpha += ((if it.show then 1 else 0) - c.alpha) * k
		if not it.show and c.alpha < 0.02 then
			c.alpha = 0
		end
		setAlpha(c, c.alpha)
		if c.alpha <= 0 then
			continue
		end
		local p = EdgeMath.point(rect, c.s :: number)
		c.frame.Position = UDim2.fromOffset(p.X, p.Y)
		local _, orbit = extents(c.size :: Vector2, spec)
		c.pointer.Position = UDim2.new(0.5, it.dir.X * orbit.X, 0.5, it.dir.Y * orbit.Y)
		-- the chevron art points down (+y); turn it toward the event
		c.pointer.Rotation = math.deg(math.atan2(it.dir.Y, it.dir.X)) - 90
	end
end

local function step()
	local now = workspace:GetServerTimeNow()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hidden = Menus.isOpen()
	trackerSlot.Visible = not hidden and not Gui.heraldActive()
	for _, s in shown do
		local left = s.entry.ends - now
		local time = (s.tracker:FindFirstChild("Ring") :: ImageLabel):FindFirstChild("Time") :: TextLabel
		time.Text = clock(left)
		time.TextColor3 = if left <= URGENT then URGENT_COLOR else Color3.fromRGB(250, 236, 195)
		local at = s.at
		if not at then
			continue
		end
		local studs = if root then (root.Position - at).Magnitude else 0
		if s.pin then
			s.pin.Enabled = not hidden;
			(s.pin:FindFirstChild("Distance") :: TextLabel).Text = distanceText(studs)
		end
		local c = s.chip or makeChip(s)
		s.chip = c
		local text = `{s.look.short or s.entry.name}  ·  <font color="{GOLD_HEX}">{distanceText(studs)}</font>`
		if c.size and c.text ~= text then
			c.text = text
			c.title.Text = text
		end
	end
end

function WorldEventView.init()
	Gui.init()
	trackerSlot = Gui.slot("Tracker")
	chipSlot = Gui.slot("Chips")
	chipLayer = chipSlot.Parent :: Frame
	canvasScale = (chipLayer.Parent :: Frame):FindFirstChild("UiScale") :: UIScale
	sync(false)
	workspace:GetAttributeChangedSignal("WorldEvents"):Connect(function()
		sync(true)
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		if next(shown) == nil then
			return
		end
		moveChips(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		step()
	end)
end

-- Sample content for a look in play (client console):
--   require(game.Players.LocalPlayer.PlayerScripts.Client.Events.WorldEventView).preview()
-- Shows a herald and a tracker with a pin 120 studs ahead; nothing is sent to the server.
function WorldEventView.preview()
	Gui.init()
	if not trackerSlot then
		trackerSlot = Gui.slot("Tracker")
		chipSlot = Gui.slot("Chips")
		chipLayer = chipSlot.Parent :: Frame
		canvasScale = (chipLayer.Parent :: Frame):FindFirstChild("UiScale") :: UIScale
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local ahead = if root then root.Position + root.CFrame.LookVector * 120 else Vector3.zero
	local entry: Entry = {
		id = "ThousandYearGinseng",
		name = "Thousand-Year Ginseng",
		ends = workspace:GetServerTimeNow() + 90,
		at = { ahead.X, ahead.Y, ahead.Z },
		direction = "northeast",
	}
	remove(entry.id)
	add(entry, true)
	task.delay(90, remove, entry.id)
end

return WorldEventView
