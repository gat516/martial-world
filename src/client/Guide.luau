--!strict
-- The onboarding guide: shows the player what the server's QuestState.guide
-- points at (see the guide keys at the top of src/server/Quests.luau).
--
--   button  pulse that HUD control. With `dim`, a spotlight too: the rest of the
--           HUD greys out under a gentle ink veil (Hud.Guide.Dim, a soft hole
--           around the control) and stops taking taps, and the elder's line sits
--           beside it (Guide.Callout). Movement and the camera are never touched:
--           the veil sinks no input, other HUD controls are only made
--           non-interactable. The spotlight lifts once the control is pressed or
--           the guide changes, and never shows during combat, the calm view, or
--           while a window the guide doesn't point into is open.
--   to      with button "Travel": once the travel menu is open, the destination
--           button in it (named after the gate id) is the target instead.
--           In-window keys (INSIDE, e.g. "RootPill") work the same way for any
--           window: the control marks itself with a `GuideKey` attribute, and
--           until the window holding it is open the guide points at the control
--           that opens it. A target inside a scrolling list is scrolled into view.
--   point   without dim: a bobbing gold pointer beside the control (Guide.Pointer)
--           and the guide's line in the callout, nothing greyed out or blocked.
--           It lifts like the spotlight: once the control is pressed.
--   say     the short line for the callout at this step (else the elder's line).
--           An in-window control's own GuideSay attribute wins while it's the
--           target (e.g. "Absorb it to temper your root" on the pill's button).
--   place   a world target to walk to: a stream of qi along the ground from
--           the player's feet toward it and a formation circle with a faint
--           column of light at its foot (GuideFX, Effects.Guide), a marker
--           over it (Hud.GuideMarker) and, while it's off screen, an arrow at
--           the screen edge (Guide.Arrow). The nearest candidate is re-picked
--           every second; all of it hides once the player is within a few
--           studs, and the first arrival per guide plays a short flourish
--           there (not for enemies: that's a fight, and the circle and column
--           would sit on the beast).
--
-- The HUD pieces are authored in StarterGui.Hud, the world pieces in
-- ReplicatedStorage.Effects.Guide; this only places and shows them.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Gates = require(ReplicatedStorage.Shared.Gates)
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local GuideFX = require(script.Parent.GuideFX)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local MyPeak = require(script.Parent.MyPeak)
local ScrollHint = require(script.Parent.ScrollHint)

local player = Players.LocalPlayer

-- Guide button keys -> where the control lives under the Hud.
local BUTTONS: { [string]: { string } } = {
	Cultivate = { "Buttons", "CultivateButton" },
	Self = { "Buttons", "SelfButton" },
	Inventory = { "Buttons", "InventoryButton" },
	Travel = { "Buttons", "TravelButton" },
	Attack = { "Play", "AttackButton" },
	Circulate = { "Stack", "CultivatePrompt", "Circulate" },
	Breakthrough = { "Stack", "CultivatePrompt", "Breakthrough" },
	Practice = { "Stack", "CultivatePrompt", "Practice" },
	-- the Practice row's tiles: until that row is open, point at Practice
	PracticeTechnique = { "Stack", "CultivatePrompt", "PracticeTechnique" },
	PracticeDao = { "Stack", "CultivatePrompt", "PracticeDao" },
	Method = { "Stack", "CultivatePrompt", "Method" },
	SpiritRoot = { "Stack", "CultivatePrompt", "Root" },
}

-- Tiles inside the seated Practice row -> the main-row tile that opens it.
local FOLDED: { [string]: string } = { PracticeTechnique = "Practice", PracticeDao = "Practice" }

-- Controls inside a window -> the key of the control that opens that window.
-- The control itself carries the attribute GuideKey = <key> (set by the window's
-- script on the row it builds, e.g. MeditationMenu's pill rows).
local INSIDE: { [string]: string } = { RootPill = "SpiritRoot" }

local HOLE_PAD = 6 -- clear space around the control before the veil starts
local HOLE_FADE = 24 -- the hole art's soft edge (48px corners at SliceScale 0.5)
local FAR = 4000 -- the veil's side pieces reach this far past the screen
local CALLOUT_GAP = 10
local EDGE = 12 -- keep the callout and arrow this far inside the screen
local ARROW_TOP = 80 -- the arrow stays below the chat and the top-right tiles
local POINTER_GAP = 4 -- between a control and the pointer's tip
local POINTER_BOB = 5 -- px
local NEAR = 8 -- studs: close enough, the path hides
local REPICK = 1 -- seconds between picks of the nearest target
local MARKER_BOB = 0.35 -- studs

local Guide = {}

local gui: ScreenGui
local root: Frame -- Hud.Guide
local dim: Frame
local hole: ImageLabel
local sides: { [string]: Frame } = {}
local callout: GuiObject
local calloutLine: TextLabel
local arrow: ImageLabel
local pointer: ImageLabel
local marker: BillboardGui

type GuideSpec = { button: string?, to: string?, dim: boolean?, place: string?, point: boolean?, say: string? }
local guide: GuideSpec? = nil
local line = ""
local pointing = false
local target: GuiButton? = nil -- the control currently pointed at
local pressed: GuiButton? = nil -- pressed since it became the target: no spotlight
local pressConn: RBXScriptConnection? = nil
local pulsing: GuiButton? = nil
local spotlit = false
local blocked: { [GuiObject]: boolean } = {} -- made non-interactable -> its own value
local lastHurt = -math.huge

local place: { inst: Instance, part: BasePart, top: number }? = nil -- the walking target
local lastPick = -math.huge
local lastStep = os.clock()
local arrived = false -- the arrival flourish has played for this guide
local stepConn: RBXScriptConnection? = nil

--[[ HUD controls ]]

-- A shown control marked GuideKey = key inside the open window, if any.
local function insideOpenWindow(key: string): GuiButton?
	local open = Menus.current()
	if not open then
		return nil
	end
	for _, inst in open:GetDescendants() do
		if inst:IsA("GuiButton") and inst:GetAttribute("GuideKey") == key and inst.Visible then
			return inst
		end
	end
	return nil
end

local function resolveKey(key: string): GuiButton?
	local path = BUTTONS[key]
	if not path then
		return nil
	end
	local node: Instance? = gui
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	if not (node and node:IsA("GuiButton")) then
		return nil
	end
	if FOLDED[key] and not node.Visible then
		-- the Practice row is closed: point at the tile that opens it
		local parent = node.Parent :: Instance
		local opener = parent:FindFirstChild(FOLDED[key])
		return if opener and opener:IsA("GuiButton") then opener else node
	end
	return node
end

local function resolve(): GuiButton?
	local g = guide
	if not g or not g.button then
		return nil
	end
	local opener = INSIDE[g.button]
	if opener then
		return insideOpenWindow(g.button) or resolveKey(opener)
	end
	if g.button == "Travel" and g.to then
		local menu = gui:FindFirstChild("TravelMenu") :: GuiObject?
		if menu and menu.Visible then
			local list = menu:FindFirstChild("List")
			local dest = list and list:FindFirstChild(g.to, true)
			if dest and dest:IsA("GuiButton") then
				return dest
			end
		end
	end
	return resolveKey(g.button)
end

-- Whether a control is actually on screen (it and every frame above it shown).
local function shown(obj: GuiObject): boolean
	if not gui.Enabled or obj.AbsoluteSize.X < 1 then
		return false
	end
	local node: Instance? = obj
	while node and node ~= gui do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node == gui
end

local function setPulse(button: GuiButton?)
	if pulsing == button then
		return
	end
	if pulsing then
		Motion.stopPulse(pulsing)
	end
	pulsing = button
	if button then
		Motion.pulse(button)
	end
end

-- Every HUD control off the path from the Hud down to the target stops taking
-- taps (it keeps its look under the veil); the target and its frames stay live,
-- and so do the touch Jump and Dash buttons (movement is never blocked).
local MOVEMENT = { JumpButton = true, DodgeButton = true }

local function unblock()
	for obj, was in blocked do
		obj.Interactable = was
	end
	table.clear(blocked)
end

local function block(button: GuiButton)
	unblock()
	local node: Instance = button
	while node ~= gui and node.Parent do
		local parent = node.Parent :: Instance
		for _, sibling in parent:GetChildren() do
			if sibling ~= node and sibling ~= root and sibling:IsA("GuiObject") and not MOVEMENT[sibling.Name] then
				blocked[sibling] = sibling.Interactable
				sibling.Interactable = false
			end
		end
		node = parent
	end
end

local function inCombat(): boolean
	return os.clock() - lastHurt < Config.Combat.IN_COMBAT_SECONDS
end

-- A window is open that the target isn't inside of.
local function otherWindowOpen(button: GuiButton): boolean
	local open = Menus.current()
	return open ~= nil and not button:IsDescendantOf(open)
end

local function wantSpotlight(button: GuiButton?): boolean
	local g = guide
	return g ~= nil
		and g.dim == true
		and button ~= nil
		and pressed ~= button
		and shown(button)
		and not inCombat()
		and not Menus.isCalm()
		and not otherWindowOpen(button)
end

local function wantPointer(button: GuiButton?): boolean
	local g = guide
	return g ~= nil
		and g.point == true
		and not spotlit
		and button ~= nil
		and pressed ~= button
		and shown(button)
		and not inCombat()
		and not Menus.isCalm()
		and not otherWindowOpen(button)
end

-- The control's own box, without the pulse's swell.
local function baseBox(button: GuiButton): (Vector2, Vector2)
	local size, pos = button.AbsoluteSize, button.AbsolutePosition
	local scale = button:FindFirstChild("Motion")
	local s = if scale and scale:IsA("UIScale") and scale.Scale > 0 then scale.Scale else 1
	local centre = pos + size / 2
	local base = size / s
	return centre - base / 2, base
end

-- The guide's line beside a control (pos relative to the Guide frame): below a
-- control in the top half, above one in the bottom half, `clear` px away,
-- centred on it and kept on screen.
local function placeCallout(pos: Vector2, size: Vector2, clear: number)
	local area = root.AbsoluteSize
	local w, h = callout.AbsoluteSize.X, callout.AbsoluteSize.Y
	local cx = pos.X + size.X / 2
	local below = pos.Y + size.Y / 2 < area.Y / 2
	local y = if below then pos.Y + size.Y + clear + CALLOUT_GAP else pos.Y - clear - CALLOUT_GAP - h
	local x = math.clamp(cx - w / 2, EDGE, math.max(EDGE, area.X - w - EDGE))
	callout.Position = UDim2.fromOffset(x, math.clamp(y, EDGE, math.max(EDGE, area.Y - h - EDGE)))
end

-- The pointer beside a control, its tip toward it: below a control near the
-- top, above one near the bottom, else on the control's outer side (away from
-- the screen's middle: in a centred window that's toward its edge, past the
-- row's text). The callout goes past the pointer: below or above it, or out to
-- the side when there's room there, else above or below the control.
local function placePointer(button: GuiButton)
	local area = root.AbsoluteSize
	local pos, size = baseBox(button)
	pos -= root.AbsolutePosition
	local half = pointer.AbsoluteSize / 2
	local bob = (math.sin(os.clock() * 6) + 1) / 2 * POINTER_BOB
	local cx, cy = pos.X + size.X / 2, pos.Y + size.Y / 2
	local reach = POINTER_GAP + half.Y * 2 + POINTER_BOB -- the pointer's whole run
	if cy < area.Y * 0.3 then
		pointer.Position = UDim2.fromOffset(cx, pos.Y + size.Y + POINTER_GAP + half.Y + bob)
		pointer.Rotation = -90
		placeCallout(pos, size, reach)
		return
	elseif cy > area.Y * 0.7 then
		pointer.Position = UDim2.fromOffset(cx, pos.Y - POINTER_GAP - half.Y - bob)
		pointer.Rotation = 90
		placeCallout(pos, size, reach)
		return
	end
	local w, h = callout.AbsoluteSize.X, callout.AbsoluteSize.Y
	local y = math.clamp(cy - h / 2, EDGE, math.max(EDGE, area.Y - h - EDGE))
	if cx > area.X / 2 then
		-- right of the control, pointing left
		pointer.Position = UDim2.fromOffset(pos.X + size.X + POINTER_GAP + half.X + bob, cy)
		pointer.Rotation = 180
		local x = pos.X + size.X + reach + CALLOUT_GAP
		if x + w <= area.X - EDGE then
			callout.Position = UDim2.fromOffset(x, y)
		else
			placeCallout(pos, size, 0)
		end
	else
		pointer.Position = UDim2.fromOffset(pos.X - POINTER_GAP - half.X - bob, cy)
		pointer.Rotation = 0
		local x = pos.X - reach - CALLOUT_GAP - w
		if x >= EDGE then
			callout.Position = UDim2.fromOffset(x, y)
		else
			placeCallout(pos, size, 0)
		end
	end
end

local function placeSpotlight(button: GuiButton)
	local origin = root.AbsolutePosition
	local area = root.AbsoluteSize
	local pos, size = baseBox(button)
	pos -= origin
	local margin = HOLE_PAD + HOLE_FADE
	local l, t = pos.X - margin, pos.Y - margin
	local r, b = pos.X + size.X + margin, pos.Y + size.Y + margin
	hole.Position = UDim2.fromOffset(l, t)
	hole.Size = UDim2.fromOffset(r - l, b - t)
	sides.Top.Position = UDim2.fromOffset(-FAR, -FAR)
	sides.Top.Size = UDim2.fromOffset(2 * FAR + area.X, FAR + t)
	sides.Bottom.Position = UDim2.fromOffset(-FAR, b)
	sides.Bottom.Size = UDim2.fromOffset(2 * FAR + area.X, FAR + area.Y - b)
	sides.Left.Position = UDim2.fromOffset(-FAR, t)
	sides.Left.Size = UDim2.fromOffset(FAR + l, b - t)
	sides.Right.Position = UDim2.fromOffset(r, t)
	sides.Right.Size = UDim2.fromOffset(FAR + area.X - r, b - t)

	placeCallout(pos, size, HOLE_PAD)
end

local function setSpotlight(on: boolean, button: GuiButton?)
	if on and button then
		if not spotlit then
			block(button)
		end
		placeSpotlight(button)
	end
	if on == spotlit then
		return
	end
	spotlit = on
	if not on then
		unblock()
	end
	Motion.setShown(dim, on, true)
end

local function retarget(button: GuiButton?)
	if button == target then
		return
	end
	target = button
	pressed = nil
	if pressConn then
		pressConn:Disconnect()
		pressConn = nil
	end
	if button then
		pressConn = button.Activated:Connect(function()
			pressed = button
			setPulse(nil)
		end)
	end
	if spotlit and button then
		block(button)
	end
	setPulse(button)
	if button and button:FindFirstAncestorWhichIsA("ScrollingFrame") then
		-- bring it into the list's view now, and again once the window's pop
		-- and the list's layout have settled
		ScrollHint.reveal(button)
		task.delay(0.3, function()
			if target == button then
				ScrollHint.reveal(button)
			end
		end)
	end
end

--[[ Walking guide ]]

local function coreOf(inst: Instance): BasePart?
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart
			or inst:FindFirstChild("HumanoidRootPart") :: BasePart?
			or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

-- The world height of the top of a target (where the marker floats).
local function topOf(inst: Instance, part: BasePart): number
	if inst:IsA("Model") then
		local cf, size = inst:GetBoundingBox()
		return cf.Position.Y + size.Y / 2
	end
	return part.Position.Y + part.Size.Y / 2
end

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function nearest(candidates: { Instance }, from: Vector3, accept: ((Instance) -> boolean)?): Instance?
	local best, bestDist = nil, math.huge
	for _, inst in candidates do
		if not accept or accept(inst) then
			local part = coreOf(inst)
			if part then
				local d = (part.Position - from).Magnitude
				if d < bestDist then
					best, bestDist = inst, d
				end
			end
		end
	end
	return best
end

local GARDEN_RANGE = 150 -- with no peak known, herb plots this close count

-- The instance a place key points at, nearest to `from`.
local function pickPlace(key: string, from: Vector3): Instance?
	local hub = workspace:FindFirstChild("Hub")
	if key == "TestingStone" or key == "Elder" or key == "QuestBoard" then
		return hub and hub:FindFirstChild(key)
	elseif key == "QiNode" then
		return nearest(CollectionService:GetTagged("QiNode"), from)
	elseif key == "Enemy" then
		-- enemies have no Humanoid: Health is an attribute on the server root
		return nearest(CollectionService:GetTagged("Enemy"), from, Hitbox.alive)
	elseif key == "WeaponRack" then
		return nearest(CollectionService:GetTagged("WeaponRack"), from)
	elseif key == "Garden" then
		local peak = MyPeak.model()
		return nearest(CollectionService:GetTagged("HerbPlot"), from, function(plot)
			if peak then
				return plot:IsDescendantOf(peak)
			end
			local part = coreOf(plot)
			return part ~= nil and (part.Position - from).Magnitude < GARDEN_RANGE
		end)
	end
	local gate = string.match(key, "^Array:(.+)$")
	if gate then
		return nearest(CollectionService:GetTagged(Gates.TAG), from, function(array)
			if array:GetAttribute("Gate") ~= gate then
				return false
			end
			-- "Peak" means your own peak's array
			return gate ~= "Peak" or MyPeak.owns(array.Parent)
		end)
	elseif key == "Array" then
		return nearest(CollectionService:GetTagged(Gates.TAG), from)
	end
	return nil
end

local function hidePath()
	GuideFX.hidePath()
	GuideFX.hideMarker()
	marker.Enabled = false
	arrow.Visible = false
end

-- Point the edge arrow from the screen's middle toward a world point.
local function placeArrow(world: Vector3)
	local camera = workspace.CurrentCamera
	local point, onScreen = camera:WorldToViewportPoint(world)
	local view = camera.ViewportSize
	if onScreen and point.Z > 0 then
		arrow.Visible = false
		return
	end
	local origin = root.AbsolutePosition
	local area = root.AbsoluteSize
	local centre = view / 2
	local dir = Vector2.new(point.X, point.Y) - centre
	if point.Z < 0 then
		dir = -dir -- behind the camera: the projection is mirrored
	end
	if dir.Magnitude < 1 then
		dir = Vector2.new(0, 1)
	end
	dir = dir.Unit
	local half = arrow.AbsoluteSize / 2
	local minX, maxX = EDGE + half.X, area.X - EDGE - half.X
	local minY, maxY = ARROW_TOP + half.Y, area.Y - EDGE - half.Y
	local c = centre - origin
	-- walk out from the centre until the first edge of the allowed box
	local tx = if dir.X > 0 then (maxX - c.X) / dir.X elseif dir.X < 0 then (minX - c.X) / dir.X else math.huge
	local ty = if dir.Y > 0 then (maxY - c.Y) / dir.Y elseif dir.Y < 0 then (minY - c.Y) / dir.Y else math.huge
	local at = c + dir * math.max(0, math.min(tx, ty))
	arrow.Position = UDim2.fromOffset(math.clamp(at.X, minX, maxX), math.clamp(at.Y, minY, maxY))
	arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X))
	arrow.Visible = true
end

local function stepPath(now: number)
	local dt = math.min(now - lastStep, 0.1)
	lastStep = now
	local g = guide
	local me = myRoot()
	if not g or not g.place or not me or Menus.isOpen() then
		hidePath()
		return
	end
	if now - lastPick >= REPICK or (place and not place.part:IsDescendantOf(workspace)) then
		lastPick = now
		local inst = pickPlace(g.place, me.Position)
		local part = inst and coreOf(inst)
		place = if inst and part then { inst = inst, part = part, top = topOf(inst, part) } else nil
	end
	local p = place
	if not p then
		hidePath()
		return
	end
	local goal = p.part.Position
	local fight = g.place == "Enemy"
	local flat = (goal - me.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < NEAR and math.abs(goal.Y - me.Position.Y) < 12 then
		if not arrived and not fight then
			arrived = true
			GuideFX.arrive()
		end
		hidePath()
		return
	end
	-- the formation at its foot (not under a beast), and the stream up to its edge
	local radius = if fight then nil else GuideFX.showMarker(p.inst, p.part, true, now)
	if fight then
		GuideFX.hideMarker()
	end
	GuideFX.showPath(me.Position, goal, if radius then radius * 0.8 else 3, dt)

	marker.Adornee = p.part
	marker.StudsOffsetWorldSpace = Vector3.new(0, p.top - goal.Y + 2.5 + math.sin(now * 3) * MARKER_BOB, 0)
	marker.Enabled = true
	placeArrow(Vector3.new(goal.X, p.top, goal.Z))
end

--[[ Per frame ]]

local function step()
	local now = os.clock()
	local button = resolve()
	retarget(button)
	setSpotlight(wantSpotlight(button), button)
	pointing = wantPointer(button)
	if pointing and button then
		placePointer(button)
	end
	pointer.Visible = pointing
	stepPath(now)
	-- an in-window control can carry its own step line (GuideSay attribute)
	local own = if button then button:GetAttribute("GuideSay") else nil
	local text = if type(own) == "string" and own ~= "" then own
		elseif guide and guide.say and guide.say ~= "" then guide.say
		else line
	if calloutLine.Text ~= text then
		calloutLine.Text = text
	end
	callout.Visible = (spotlit or pointing) and text ~= ""
	root.Visible = spotlit or pointing or arrow.Visible or dim.Visible
	if not guide then
		hidePath()
		if not dim.Visible and stepConn then
			stepConn:Disconnect()
			stepConn = nil
		end
	end
end

local function run()
	if not stepConn then
		stepConn = RunService.RenderStepped:Connect(step)
	end
	step()
end

-- The server's current guide (nil: none) and the elder's line to show beside a
-- spotlight.
local function keyOf(g: GuideSpec?): string
	if not g then
		return ""
	end
	return `{g.button or ""}/{g.to or ""}/{g.dim == true}/{g.place or ""}/{g.point == true}/{g.say or ""}`
end

function Guide.set(g: any, elderLine: string?)
	local key = keyOf(g)
	local oldKey = keyOf(guide)
	if elderLine and elderLine ~= "" then
		line = elderLine
	end
	if key ~= oldKey then
		guide = g
		pressed = nil
		lastPick = -math.huge
		place = nil
		arrived = false
		GuideFX.reset()
		if not g then
			retarget(nil)
			setSpotlight(false)
		end
	end
	run()
end

-- Whether the spotlight (with the elder's line beside it) is up right now. The
-- pointer's callout carries its own short `say` line, so the elder still
-- speaks in the usual place while it shows.
function Guide.spotlit(): boolean
	return spotlit
end

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local health = humanoid.Health
	humanoid.HealthChanged:Connect(function(value)
		if value < health then
			lastHurt = os.clock()
		end
		health = value
	end)
end

function Guide.init(screenGui: ScreenGui)
	gui = screenGui
	root = gui:FindFirstChild("Guide") :: Frame
	dim = root:FindFirstChild("Dim") :: Frame
	hole = dim:FindFirstChild("Hole") :: ImageLabel
	for _, name in { "Top", "Bottom", "Left", "Right" } do
		sides[name] = dim:FindFirstChild(name) :: Frame
	end
	callout = root:FindFirstChild("Callout") :: GuiObject
	calloutLine = callout:FindFirstChild("Line") :: TextLabel
	arrow = root:FindFirstChild("Arrow") :: ImageLabel
	pointer = root:FindFirstChild("Pointer") :: ImageLabel
	Motion.appear(callout)

	marker = (gui:FindFirstChild("GuideMarker") :: BillboardGui):Clone()
	marker.Enabled = false
	marker.Parent = player:WaitForChild("PlayerGui")

	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
	Menus.onChanged(function()
		if guide then
			run()
		end
	end)
end

return Guide
