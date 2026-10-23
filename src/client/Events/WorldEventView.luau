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
--   chip     when the spot is off screen, an arrow chip at the left or right
--            edge pointing toward it, with the name and distance.
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
local Gui = require(script.Parent.Gui)

local player = Players.LocalPlayer

local HOLD = 3.6 -- seconds the herald stays unrolled
local ROLLED = 0.3 -- the herald's width share when rolled up (caps only)
local UNROLL = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ROLLUP = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TEXT_IN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CHIP_GAP = 8 -- baseline px between stacked chips
local CHIP_MARGIN = 0.04 -- share of the screen's width an on-screen pin must be inside
local URGENT = 60 -- seconds left when the time turns lacquer red
local URGENT_COLOR = Color3.fromRGB(255, 120, 100)

local PINS = {
	gold = "rbxassetid://140034976306899",
	jade = "rbxassetid://125833552344790",
	crimson = "rbxassetid://92114884196856",
	violet = "rbxassetid://102174260949277",
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
	chip: GuiObject?,
	chipSide: string?,
	at: Vector3?,
}

local WorldEventView = {}

local shown: { [string]: Shown } = {}
local order = 0
local trackerSlot: Frame
local chipSlot: Frame

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
	for _, inst in { s.pin, s.anchor, s.chip } :: { Instance? } do
		if inst then
			inst:Destroy()
		end
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

local function chipFor(s: Shown, side: string): GuiObject
	if s.chip and s.chipSide == side then
		return s.chip
	end
	if s.chip then
		s.chip:Destroy()
	end
	local chip = Gui.clone(if side == "Right" then "ChipRight" else "ChipLeft") :: ImageLabel
	chip.Name = s.entry.id
	chip.AnchorPoint = Vector2.new(if side == "Right" then 1 else 0, 0.5)
	chip.Size = UDim2.fromScale(4, 1);
	chip.Position = UDim2.fromScale(if side == "Right" then 1 else 0, 0.5);
	(chip:FindFirstChild("Title") :: TextLabel).Text = s.look.short or s.entry.name
	chip.Parent = chipSlot
	Gui.fadeIn(chip)
	s.chip, s.chipSide = chip, side
	return chip
end

local function step()
	local now = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hidden = Menus.isOpen()
	trackerSlot.Visible = not hidden and not Gui.heraldActive()
	chipSlot.Visible = not hidden
	local stack = { Left = 0, Right = 0 }
	local ids = {}
	for id in shown do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return shown[a].tracker.LayoutOrder < shown[b].tracker.LayoutOrder
	end)
	for _, id in ids do
		local s = shown[id]
		local left = s.entry.ends - now
		local time = (s.tracker:FindFirstChild("Ring") :: ImageLabel):FindFirstChild("Time") :: TextLabel
		time.Text = clock(left)
		time.TextColor3 = if left <= URGENT then URGENT_COLOR else Color3.fromRGB(250, 236, 195)
		local at = s.at
		if not (at and camera) then
			continue
		end
		local studs = if root then (root.Position - at).Magnitude else 0
		if s.pin then
			s.pin.Enabled = not hidden;
			(s.pin:FindFirstChild("Distance") :: TextLabel).Text = distanceText(studs)
		end
		local point, visible = camera:WorldToViewportPoint(at + Vector3.new(0, 16, 0))
		local view = camera.ViewportSize
		local inside = visible and point.X > view.X * CHIP_MARGIN and point.X < view.X * (1 - CHIP_MARGIN)
		if inside then
			if s.chip then
				s.chip:Destroy()
				s.chip, s.chipSide = nil, nil
			end
			continue
		end
		local toward = camera.CFrame:VectorToObjectSpace(at - camera.CFrame.Position)
		local side = if toward.X >= 0 then "Right" else "Left"
		local chip = chipFor(s, side);
		(chip:FindFirstChild("Distance") :: TextLabel).Text = distanceText(studs)
		local index = stack[side]
		stack[side] += 1
		-- slot offsets are baseline pixels (the canvas's UIScale does the rest)
		chip.Position = UDim2.new(if side == "Right" then 1 else 0, 0, 0.5, index * (chipSlot.Size.Y.Offset + CHIP_GAP))
	end
end

function WorldEventView.init()
	Gui.init()
	trackerSlot = Gui.slot("Tracker")
	chipSlot = Gui.slot("Chips")
	sync(false)
	workspace:GetAttributeChangedSignal("WorldEvents"):Connect(function()
		sync(true)
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 0.1 or next(shown) == nil then
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
