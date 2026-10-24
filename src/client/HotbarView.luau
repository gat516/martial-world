--!strict
-- The hotbar: nine slots of techniques and items (Hotbar.luau), Stack.Hotbar.Slots
-- Slot1-9 (SlotTemplate is the drag ghost). Keys 1-9 or tapping a slot cast its technique or
-- hold out its item (a real Tool from the Backpack; activate it to use it).
-- Anything can be dragged (mouse: press and move; touch: hold, then move): from the
-- Inventory onto a slot (an occupied slot's item goes back to the bag), between slots
-- to swap them (empty ones too), or back onto the Inventory window to clear a slot.
-- Dropping anywhere else cancels.
-- Weapons: while the Inventory is open, a weapon slot (Stack.Hotbar.WeaponSlot)
-- shows left of the bar with the weapon in hand. Dropping a weapon on it (or on
-- any hotbar slot) equips it; dragging the weapon from it back onto the Inventory
-- window puts it away (bare fists). Both go through WeaponAction, which the server
-- validates.
-- One row along the bottom on every device; the Stack frame sizes it.
-- Words only (user, 2026-10-23: "you can't fit either [icon or words]... words only
-- makes the most sense here"): each art or item slot is its short name (Hotbar.label),
-- centred, the key number top-left on keyboards, the cooldown a darkening sweep with
-- the seconds over the words. The full name shows in Hotbar.NameTip above the slot
-- while the mouse is over it, or while a finger holds it (touch, Inventory closed:
-- a hold of PEEK_SECONDS shows the name and doesn't cast; a quicker tap still casts).
-- An art whose weapon class isn't in hand dims; it still casts, and the server
-- answers "Requires a ...".
-- An art the player hasn't the combat qi for (Qi < Techniques.qiCost) dims too; it
-- still casts, and the qi bar flashes the refusal (Hud, QiDenied).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Hotbar = require(ReplicatedStorage.Shared.Hotbar)
local Items = require(ReplicatedStorage.Shared.Items)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local BuildMode = require(script.Parent.BuildMode)
local CombatController = require(script.Parent.CombatController)
local Hud = require(script.Parent.Hud)
local Menus = require(script.Parent.Menus)
local Platform = require(script.Parent.Platform)
local Motion = require(script.Parent.Motion)
local SlotArt = require(script.Parent.SlotArt)
local State = require(script.Parent.State)

local Weapons = require(ReplicatedStorage.Shared.Weapons)

local inventoryRemote = ReplicatedStorage.Remotes.InventoryAction :: RemoteFunction
local player = Players.LocalPlayer

local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}
local DRAG_PIXELS = 10 -- a press that moves this far becomes a drag
local SHORT_FRAME = 0.3 -- frame transparency on an art the player can't use right now
local PEEK_SECONDS = 0.5 -- touch: a hold this long on a slot shows its full name instead of casting
local TIP_GAP = 6 -- px between the name tip and the slot's top
local COOLING_WORDS = 0.85 -- the words' transparency under a cooldown's seconds

local HotbarView = {}

local gui: ScreenGui
local bar: Frame
local template: TextButton
local slots: { TextButton } = {}
local weaponSlot: TextButton -- Stack.Hotbar.WeaponSlot, shown while the Inventory is open
local lastDragEnd = -math.huge

local showTip: (GuiObject?, string?) -> () -- defined with the tip below; the drag starts use it first
local function invoke(...: any)
	local ok, message = inventoryRemote:InvokeServer(...)
	if not ok and message then
		Hud.toast(message)
	end
end

--[[ Holding items ]]

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- The item Tool the character is holding, if any.
function HotbarView.held(): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return if tool and tool:GetAttribute("ItemId") then tool else nil
end

local function toolFor(id: string): Tool?
	for _, holder in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		if holder then
			for _, tool in holder:GetChildren() do
				if tool:IsA("Tool") and tool:GetAttribute("ItemId") == id then
					return tool
				end
			end
		end
	end
	return nil
end

-- Hold out the item, or put it away if it's already in hand.
function HotbarView.toggleHold(id: string)
	local h = humanoid()
	if not h or h.Health <= 0 then
		return
	end
	if BuildMode.isActive() then
		Hud.toast("Hands are empty while building.")
		return
	end
	local held = HotbarView.held()
	if held and held:GetAttribute("ItemId") == id then
		h:UnequipTools()
		return
	end
	local tool = toolFor(id)
	if tool then
		h:EquipTool(tool)
	else
		Hud.toast("You have none left.")
	end
end

-- A technique slot casts (putting away any item in hand first); an item slot holds
-- that item out, or puts it away if it's the one already in hand.
local function press(i: number)
	local id = State.current.hotbar[i] or ""
	if Techniques.Defs[id] then
		local h = humanoid()
		if h and HotbarView.held() then
			h:UnequipTools()
		end
		CombatController.cast(id)
	elseif Items.Defs[id] then
		HotbarView.toggleHold(id)
	end
end

-- Set by Inventory: while it's open, tapping slot i places the art, item or weapon
-- chosen in its grid, or shows that slot's art or item in its detail pane, instead
-- of casting or holding it (returns true when it handled the tap).
HotbarView.tapSlot = nil :: ((i: number) -> boolean)?
-- Set by Inventory: tapping the weapon slot (equips the chosen weapon, or shows
-- the one in hand).
HotbarView.tapWeapon = nil :: (() -> ())?

local function isWeapon(id: string): boolean
	return id == Weapons.FIST or Weapons.Defs[id] ~= nil
end

-- Equip a weapon (Bare Fists put the weapon away). The server checks ownership.
function HotbarView.equipWeapon(id: string)
	local remote = ReplicatedStorage.Remotes:FindFirstChild("WeaponAction") :: RemoteFunction
	task.spawn(function()
		local ok, message
		if id == Weapons.FIST then
			ok, message = remote:InvokeServer("unequip")
		else
			ok, message = remote:InvokeServer("equip", id)
		end
		if not ok and message then
			Hud.toast(message)
		end
	end)
end

--[[ Drag and drop ]]
-- Picking up: a mouse press that moves DRAG_PIXELS; on touch, a hold of HOLD_SECONDS
-- without moving (moving first scrolls the grid instead). A ghost of the slot follows
-- the pointer (above the finger on touch, so the finger doesn't hide it), the slot it
-- would land on wears the cream ring, and a hotbar item over the Inventory window fades
-- (dropping it there takes it off the bar). Dropping anywhere else, or Escape, cancels.
-- Hit tests go through PlayerGui:GetGuiObjectsAtPosition, which takes input positions
-- as they come, so the GUI inset never skews them.

local HOLD_SECONDS = 0.3
local GHOST_SCALE = 1.12 -- the ghost is a little larger than the slot it left
local GHOST_LIFT = 0.65 -- touch: the ghost's centre sits this many sizes above the finger
local GHOST_REMOVE = 0.5 -- ghost transparency over the Inventory window (comes off the bar)

type Drag = {
	id: string,
	from: (number | string)?, -- hotbar slot, "weapon", or nil for an Inventory cell
	ghost: TextButton,
	size: number,
	touch: boolean,
	scroller: ScrollingFrame?,
	scrolling: boolean,
	target: Target?,
	finish: () -> (),
}
type Target = { kind: "slot", index: number } | { kind: "weapon" } | { kind: "bag" }

local drag: Drag? = nil
local dropTarget: GuiObject? = nil -- the slot showing the drop ring

-- True while dragging and just after a drag ends, so the release isn't also taken
-- as a click or tap.
function HotbarView.justDragged(): boolean
	return drag ~= nil or os.clock() - lastDragEnd < 0.15
end

local function inventoryWindow(): GuiObject?
	local window = gui:FindFirstChild("Inventory") :: GuiObject?
	return if window and window.Visible then window else nil
end

-- What lies under an input position: a hotbar slot, the weapon slot, or the
-- Inventory window (the bag), whichever is on top.
local function targetAt(position: Vector3 | Vector2): Target?
	local playerGui = gui.Parent :: BasePlayerGui
	local window = inventoryWindow()
	for _, object in playerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
		if object:IsDescendantOf(gui) and object.Name ~= "DragGhost" then
			for i, s in slots do
				if s.Visible and (object == s or object:IsDescendantOf(s)) then
					return { kind = "slot", index = i }
				end
			end
			if weaponSlot.Visible and (object == weaponSlot or object:IsDescendantOf(weaponSlot)) then
				return { kind = "weapon" }
			end
			if window and (object == window or object:IsDescendantOf(window)) then
				return { kind = "bag" }
			end
		end
	end
	return nil
end

-- Whether dropping this drag on target does something (else it's a cancel).
local function accepts(d: Drag, target: Target?): boolean
	if not target then
		return false
	end
	if isWeapon(d.id) then
		if target.kind == "bag" then
			return d.from == "weapon" and d.id ~= Weapons.FIST -- put the weapon away
		end
		return d.from ~= "weapon" -- wield it (weapon slot or any hotbar slot)
	end
	if target.kind == "weapon" then
		return false
	elseif target.kind == "bag" then
		return type(d.from) == "number" -- take it off the bar
	end
	return d.from ~= target.index
end

local function targetObject(target: Target?): GuiObject?
	if target and target.kind == "slot" then
		return slots[target.index]
	elseif target and target.kind == "weapon" then
		return weaponSlot
	end
	return nil
end

local function moveGhost(d: Drag, position: Vector3 | Vector2)
	local origin = gui.AbsolutePosition
	local lift = if d.touch then d.size * GHOST_LIFT else 0
	d.ghost.Position = UDim2.fromOffset(position.X - origin.X, position.Y - origin.Y - lift)
	local target = targetAt(position)
	d.target = if accepts(d, target) then target else nil
	dropTarget = targetObject(d.target)
	if dropTarget == weaponSlot then
		(weaponSlot:FindFirstChild("Halo") :: GuiObject).Visible = true
	else
		(weaponSlot:FindFirstChild("Halo") :: GuiObject).Visible = false
	end
	local fade = if d.target and d.target.kind == "bag" then GHOST_REMOVE else 0
	for _, part in d.ghost:GetDescendants() do
		if part:IsA("ImageLabel") then
			part:SetAttribute("BaseTransparency", part:GetAttribute("BaseTransparency") or part.ImageTransparency)
			part.ImageTransparency = 1 - (1 - (part:GetAttribute("BaseTransparency") :: number)) * (1 - fade)
		end
	end
end

local function pickUp(id: string, from: (number | string)?, source: GuiObject, touch: boolean, position: Vector3 | Vector2, finish: () -> ())
	local g = template:Clone()
	g.Name = "DragGhost"
	g.Visible = true
	g.Active = false
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	local size = math.max(source.AbsoluteSize.X, 44) * GHOST_SCALE
	g.Size = UDim2.fromOffset(size, size)
	g.ZIndex = 50
	SlotArt.paint(g, id, Items.Defs[id] and Items.count(State.current, id) or nil, "")
	SlotArt.words(g, id, Hotbar.label(id), false);
	(g:FindFirstChild("KeyLabel") :: GuiObject).Visible = false
	for _, part in g:GetDescendants() do
		if part:IsA("GuiObject") then
			part.ZIndex += 50 -- over every window
		end
	end
	-- a finger that holds a cell inside the grid would otherwise scroll it
	local scroller = source:FindFirstAncestorWhichIsA("ScrollingFrame")
	local d: Drag = {
		id = id,
		from = from,
		ghost = g,
		size = size,
		touch = touch,
		scroller = scroller,
		scrolling = if scroller then scroller.ScrollingEnabled else false,
		target = nil,
		finish = finish,
	}
	if scroller then
		scroller.ScrollingEnabled = false
	end
	g.Parent = gui
	drag = d
	showTip(nil, nil)
	moveGhost(d, position)
	-- a short lift so the pick-up reads (a hold on touch has no other feedback)
	local scale = g:FindFirstChild("Motion") :: UIScale?
	if scale then
		scale.Scale = 0.85
		Motion.tween(scale, { Scale = 1 }, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
	end
end

-- End the drag: drop it on its target, or (cancel) just put the ghost away.
local function endDrag(drop: boolean)
	local d = drag
	if not d then
		return
	end
	drag = nil
	dropTarget = nil;
	(weaponSlot:FindFirstChild("Halo") :: GuiObject).Visible = false
	d.ghost:Destroy()
	if d.scroller then
		d.scroller.ScrollingEnabled = d.scrolling
	end
	lastDragEnd = os.clock()
	d.finish()
	local target = d.target
	if not drop or not target then
		return
	end
	local landed = targetObject(target)
	if landed then
		Motion.tap(landed)
	end
	local id, from = d.id, d.from
	if isWeapon(id) then
		HotbarView.equipWeapon(if target.kind == "bag" then Weapons.FIST else id)
	elseif target.kind == "bag" then
		invoke("clear", from)
	elseif target.kind == "slot" then
		if type(from) == "number" then
			invoke("swap", from, target.index)
		else
			-- onto an empty or occupied slot: an occupied slot's item goes back to the
			-- bag (or, if this one was already on the bar, the two swap); the server checks
			invoke("slot", id, target.index)
		end
	end
end

-- Let a button be dragged onto the hotbar. getId says what it carries right now;
-- from is the hotbar slot it lives in, "weapon" for the weapon slot, nil for
-- Inventory cells.
function HotbarView.draggable(button: GuiButton, getId: () -> string?, from: (number | string)?)
	button.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		local touch = kind == Enum.UserInputType.Touch
		if (kind ~= Enum.UserInputType.MouseButton1 and not touch) or drag then
			return
		end
		-- on touch a hold on a hotbar slot means rearranging only while the Inventory is
		-- open; in a fight a slow tap must still cast
		if touch and type(from) == "number" and not inventoryWindow() then
			return
		end
		local id = getId()
		if not id or id == "" then
			return
		end
		local start = Vector2.new(input.Position.X, input.Position.Y)
		local at: Vector3 | Vector2 = input.Position
		local moved: RBXScriptConnection, ended: RBXScriptConnection
		local hold: thread? = nil
		local done = false
		local function finish()
			done = true
			moved:Disconnect()
			ended:Disconnect()
			if hold then
				task.cancel(hold)
				hold = nil
			end
		end
		local function lift()
			hold = nil
			if not done and not drag then
				pickUp(id, from, button, touch, at, finish)
			end
		end
		moved = UserInputService.InputChanged:Connect(function(change)
			local mine = if touch then change == input else change.UserInputType == Enum.UserInputType.MouseMovement
			if not mine then
				return
			end
			at = change.Position
			local d = drag
			if d and d.finish == finish then
				moveGhost(d, at)
			elseif (Vector2.new(at.X, at.Y) - start).Magnitude >= DRAG_PIXELS then
				if touch then
					finish() -- the finger moved before the hold: it's a scroll
				else
					lift()
				end
			end
		end)
		ended = UserInputService.InputEnded:Connect(function(release)
			local isEnd = if touch then release == input else release.UserInputType == Enum.UserInputType.MouseButton1
			if not isEnd then
				return
			end
			local d = drag
			if d and d.finish == finish then
				endDrag(true)
			else
				finish()
			end
		end)
		if touch then
			hold = task.delay(HOLD_SECONDS, lift)
		end
	end)
end

-- Escape drops nothing.
UserInputService.InputBegan:Connect(function(input)
	if drag and input.KeyCode == Enum.KeyCode.Escape then
		endDrag(false)
	end
end)

--[[ Drawing ]]

-- Whether the art in this slot costs more combat qi than the player has.
local function short(id: string): boolean
	local def = Techniques.Defs[id]
	if not def then
		return false
	end
	local ok, cost = pcall(function()
		return (Techniques :: any).qiCost(def)
	end)
	local qi = tonumber(player:GetAttribute("Qi"))
	return ok and typeof(cost) == "number" and qi ~= nil and qi < cost
end
local shortKey = "" -- which slots were short at the last render

-- On touch, empty slots hide (less to look at) except while the inventory is
-- open, when every slot is a drop target.
local function render()
	local s = State.current
	local inventory = gui:FindFirstChild("Inventory") :: GuiObject
	local showEmpty = not Platform.isTouch() or Menus.isOpen(inventory)
	local key = {}
	for i, slot in slots do
		local id = s.hotbar[i] or ""
		local item = Items.Defs[id]
		local count = if item then Items.count(s, id) else nil
		SlotArt.paint(slot, if id ~= "" then id else nil, count)
		local poor = short(id)
		key[i] = if poor then "1" else "0"
		local dim = poor or SlotArt.weaponMissing(id) or (count ~= nil and count <= 0)
		SlotArt.words(slot, if id ~= "" then id else nil, Hotbar.label(id), dim)
		local words = slot:FindFirstChild("NameLabel") :: TextLabel
		if words:GetAttribute("Cooling") then
			words.TextTransparency = COOLING_WORDS
			words.TextStrokeTransparency = COOLING_WORDS
		end
		if dim then
			(slot:FindFirstChild("Frame") :: ImageLabel).ImageTransparency = SHORT_FRAME
		end
		slot.Visible = showEmpty or id ~= ""
	end
	shortKey = table.concat(key)
	-- the weapon slot: the weapon in hand (its model, on its grade's edge), only
	-- while the Inventory is open (it's a drop target, not part of the fighting HUD)
	local held = SlotArt.equipped()
	local weaponId = if held == "" then Weapons.FIST else held
	weaponSlot.Visible = Menus.isOpen(inventory)
	SlotArt.paint(weaponSlot, weaponId, nil, "")
end

-- Qi changes often (regen); repaint only when a slot's affordability flips.
local function qiChanged()
	local key = {}
	for i in slots do
		key[i] = if short(State.current.hotbar[i] or "") then "1" else "0"
	end
	if table.concat(key) ~= shortKey then
		render()
	end
end

-- Cooldown sweeps on technique slots and the halo on the held item's slot.
local function tick()
	local held = HotbarView.held()
	local heldId = held and held:GetAttribute("ItemId")
	for i, slot in slots do
		local id = State.current.hotbar[i] or ""
		local remaining, total = 0, 1
		if Techniques.Defs[id] then
			remaining, total = CombatController.cooldown(id)
		end
		local overlay = slot:FindFirstChild("Cooldown") :: Frame
		local label = slot:FindFirstChild("CooldownLabel") :: TextLabel
		overlay.Visible = remaining > 0
		overlay.Size = UDim2.fromScale(1, math.clamp(remaining / total, 0, 1))
		label.Visible = remaining > 0
		label.Text = string.format("%d", math.ceil(remaining))
		-- the seconds read over the words: fade them while it cools (render sets the rest)
		local words = slot:FindFirstChild("NameLabel") :: TextLabel
		local cooling = remaining > 0
		if cooling ~= (words:GetAttribute("Cooling") == true) then
			words:SetAttribute("Cooling", cooling)
			render()
		end
		-- the cream ring: the held item's slot, and the slot a drag would land on
		local halo = slot:FindFirstChild("Halo") :: GuiObject
		halo.Visible = (heldId ~= nil and heldId == id) or slot == dropTarget
	end
end

--[[ Full names ]]
-- Hotbar.NameTip (BuffTip's look) above the slot, with the def's full name.

local tip: GuiObject
local tipSlot: GuiObject? = nil

local function fullName(id: string): string
	local def: any = Techniques.Defs[id] or Items.Defs[id]
	return if def then def.name else ""
end

showTip = function(slot: GuiObject?, id: string?)
	local name = if slot and id then fullName(id) else ""
	tipSlot = if name ~= "" then slot else nil
	tip.Visible = tipSlot ~= nil
	if slot and tipSlot then
		(tip:FindFirstChild("Text") :: TextLabel).Text = name
		local x = slot.AbsolutePosition.X + slot.AbsoluteSize.X / 2 - bar.AbsolutePosition.X
		local y = slot.AbsolutePosition.Y - bar.AbsolutePosition.Y - TIP_GAP
		tip.Position = UDim2.fromOffset(x, y)
	end
end

function HotbarView.init(screenGui: ScreenGui)
	gui = screenGui
	bar = (gui:FindFirstChild("Stack") :: Frame):FindFirstChild("Hotbar") :: Frame
	local holder = bar:FindFirstChild("Slots") :: Frame
	template = holder:FindFirstChild("SlotTemplate") :: TextButton
	tip = bar:FindFirstChild("NameTip") :: GuiObject
	for i = 1, Hotbar.SIZE do
		local slot = holder:FindFirstChild(`Slot{i}`) :: TextButton
		local key = slot:FindFirstChild("KeyLabel") :: TextLabel
		key.Text = tostring(i)
		key.Visible = not Platform.isTouch()
		-- the full name: while the mouse is over the slot, or a finger holds it (then
		-- the release doesn't cast)
		local peeked = false
		slot.MouseEnter:Connect(function()
			if not Platform.isTouch() and not drag then
				showTip(slot, State.current.hotbar[i])
			end
		end)
		slot.MouseLeave:Connect(function()
			if tipSlot == slot then
				showTip(nil, nil)
			end
		end)
		slot.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch or inventoryWindow() then
				return
			end
			peeked = false
			local hold = task.delay(PEEK_SECONDS, function()
				peeked = true
				showTip(slot, State.current.hotbar[i])
			end)
			local ended: RBXScriptConnection
			ended = UserInputService.InputEnded:Connect(function(release)
				if release == input then
					ended:Disconnect()
					task.cancel(hold)
					if tipSlot == slot then
						showTip(nil, nil)
					end
				end
			end)
		end)
		slot.Activated:Connect(function()
			if HotbarView.justDragged() then
				return
			end
			if peeked then
				peeked = false
				return
			end
			local tapSlot = HotbarView.tapSlot
			if tapSlot and tapSlot(i) then
				return
			end
			press(i)
		end)
		HotbarView.draggable(slot, function()
			return State.current.hotbar[i]
		end, i)
		slots[i] = slot
	end
	weaponSlot = bar:FindFirstChild("WeaponSlot") :: TextButton
	weaponSlot.Activated:Connect(function()
		if not HotbarView.justDragged() and HotbarView.tapWeapon then
			(HotbarView.tapWeapon :: () -> ())()
		end
	end)
	HotbarView.draggable(weaponSlot, function()
		local held = SlotArt.equipped()
		return if held == "" then nil else held
	end, "weapon")
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local i = table.find(KEYS, input.KeyCode)
		if i then
			press(i)
		end
	end)
	State.onChanged(render)
	Menus.onChanged(render)
	player:GetAttributeChangedSignal("Weapon"):Connect(render)
	player:GetAttributeChangedSignal("Qi"):Connect(qiChanged)
	RunService.RenderStepped:Connect(tick)
end

return HotbarView
