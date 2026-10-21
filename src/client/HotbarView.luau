--!strict
-- The hotbar: nine slots of techniques and items (Hotbar.luau), Stack.Hotbar.Slots
-- Slot1-9 (SlotTemplate is the drag ghost). Keys 1-9 or tapping a slot cast its technique or
-- hold out its item (a real Tool from the Backpack; activate it to use it).
-- Anything can be dragged: from the Inventory onto a slot, between slots to swap
-- them, or off the bar to clear a slot.
-- One row along the bottom on every device; the Stack frame sizes it.
-- An art whose weapon class isn't in hand dims and wears that class's badge; it
-- still casts, and the server answers "Requires a ...".

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
local SlotArt = require(script.Parent.SlotArt)
local State = require(script.Parent.State)

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

local HotbarView = {}

local gui: ScreenGui
local bar: Frame
local template: TextButton
local slots: { TextButton } = {}
local ghost: TextButton? -- the slot following the pointer while dragging
local lastDragEnd = -math.huge

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

-- Set by Inventory: while it's open, tapping a slot shows that slot's art or item
-- in its detail pane instead of casting or holding it (returns true when it did).
HotbarView.inspect = nil :: ((id: string) -> boolean)?

--[[ Drag and drop ]]

-- True just after a drag ends, so the release isn't also taken as a click.
function HotbarView.justDragged(): boolean
	return os.clock() - lastDragEnd < 0.15
end

local function slotAt(position: Vector2): number?
	for i, s in slots do
		if s.Visible then
			local p, size = s.AbsolutePosition, s.AbsoluteSize
			if position.X >= p.X and position.X <= p.X + size.X and position.Y >= p.Y and position.Y <= p.Y + size.Y then
				return i
			end
		end
	end
	return nil
end

local function drop(id: string, from: number?, position: Vector2)
	local to = slotAt(position)
	if to and from then
		if to ~= from then
			invoke("swap", from, to)
		end
	elseif to then
		invoke("slot", id, to)
	elseif from then
		invoke("clear", from)
	end
end

-- Let a button be dragged onto the hotbar. getId says what it carries right now;
-- from is the hotbar slot it lives in (nil for Inventory cells).
function HotbarView.draggable(button: GuiButton, getId: () -> string?, from: number?)
	button.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		local id = getId()
		if not id or id == "" then
			return
		end
		local start = Vector2.new(input.Position.X, input.Position.Y)
		local moved, ended
		local function pointer(i: InputObject): boolean
			if kind == Enum.UserInputType.Touch then
				return i == input
			end
			return i.UserInputType == Enum.UserInputType.MouseMovement
		end
		moved = UserInputService.InputChanged:Connect(function(change)
			if not pointer(change) then
				return
			end
			local at = Vector2.new(change.Position.X, change.Position.Y)
			if not ghost and (at - start).Magnitude >= DRAG_PIXELS then
				local g = template:Clone()
				g.Name = "DragGhost"
				g.Visible = true
				g.Active = false
				g.AnchorPoint = Vector2.new(0.5, 0.5)
				g.Size = UDim2.fromOffset(56, 56)
				g.ZIndex = 50
				SlotArt.paint(g, id, Items.Defs[id] and Items.count(State.current, id) or nil, "")
				local key = g:FindFirstChild("KeyLabel") :: GuiObject
				key.Visible = false
				g.Parent = gui
				ghost = g
			end
			if ghost then
				ghost.Position = UDim2.fromOffset(at.X, at.Y)
			end
		end)
		ended = UserInputService.InputEnded:Connect(function(release)
			local isEnd = if kind == Enum.UserInputType.Touch
				then release == input
				else release.UserInputType == Enum.UserInputType.MouseButton1
			if not isEnd then
				return
			end
			moved:Disconnect()
			ended:Disconnect()
			if ghost then
				ghost:Destroy()
				ghost = nil
				lastDragEnd = os.clock()
				drop(id, from, Vector2.new(release.Position.X, release.Position.Y))
			end
		end)
	end)
end

--[[ Drawing ]]

-- On touch, empty slots hide (less to look at) except while the inventory is
-- open, when every slot is a drop target.
local function render()
	local s = State.current
	local inventory = gui:FindFirstChild("Inventory") :: GuiObject
	local showEmpty = not Platform.isTouch() or Menus.isOpen(inventory)
	for i, slot in slots do
		local id = s.hotbar[i] or ""
		local item = Items.Defs[id]
		SlotArt.paint(slot, if id ~= "" then id else nil, if item then Items.count(s, id) else nil)
		SlotArt.gate(slot, id, false)
		slot.Visible = showEmpty or id ~= ""
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
		local halo = slot:FindFirstChild("Halo") :: GuiObject
		halo.Visible = heldId ~= nil and heldId == id
	end
end

function HotbarView.init(screenGui: ScreenGui)
	gui = screenGui
	bar = (gui:FindFirstChild("Stack") :: Frame):FindFirstChild("Hotbar") :: Frame
	local holder = bar:FindFirstChild("Slots") :: Frame
	template = holder:FindFirstChild("SlotTemplate") :: TextButton
	for i = 1, Hotbar.SIZE do
		local slot = holder:FindFirstChild(`Slot{i}`) :: TextButton
		local key = slot:FindFirstChild("KeyLabel") :: TextLabel
		key.Text = tostring(i)
		key.Visible = not Platform.isTouch()
		slot.Activated:Connect(function()
			if HotbarView.justDragged() then
				return
			end
			local inspect = HotbarView.inspect
			if inspect and inspect(State.current.hotbar[i] or "") then
				return
			end
			press(i)
		end)
		HotbarView.draggable(slot, function()
			return State.current.hotbar[i]
		end, i)
		slots[i] = slot
	end
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
	RunService.RenderStepped:Connect(tick)
end

return HotbarView
