--!strict
-- Items and the hotbar.
--   - Every item a player holds (herbs, spirit cores, treasures) is a real Tool in
--     their Backpack, cloned from ServerStorage.ItemTemplates by category. Holding
--     one out and activating it (click / tap) uses it.
--   - The hotbar (Hotbar.luau) is nine free-form slots of techniques and items;
--     a newly gained item goes into the first empty slot.
--   - Items come from beasts (EnemyService drops), heavenly treasures
--     (Treasures.luau) and the garden.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Hotbar = require(ReplicatedStorage.Shared.Hotbar)
local Items = require(ReplicatedStorage.Shared.Items)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)
local Roots = require(script.Parent.Roots)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent
local templates = ServerStorage:WaitForChild("ItemTemplates") :: Folder

local Inventory = {}

local tools: { [Player]: { [string]: Tool } } = {}
local nextUse: { [Player]: number } = {}

--[[ Tools ]]

-- Tint a template's "Tint" parts, lights and sparkles to the item's color.
local function paint(tool: Tool, item: Items.Item)
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Tint" then
			d.Color = item.color
		elseif d:IsA("Light") then
			d.Color = item.color
		elseif d:IsA("ParticleEmitter") then
			d.Color = ColorSequence.new(item.color)
		end
	end
end

local function makeTool(player: Player, item: Items.Item): Tool?
	local template = templates:FindFirstChild(item.category) :: Tool?
	if not template then
		warn(`Inventory: no tool template for {item.category}`)
		return nil
	end
	local tool = template:Clone()
	tool.Name = item.name
	tool.ToolTip = item.blurb
	tool.CanBeDropped = false
	tool:SetAttribute("ItemId", item.id)
	paint(tool, item)
	tool.Activated:Connect(function()
		local _, message = Inventory.use(player, item.id)
		if message then
			Cultivation.notify(player, message)
		end
	end)
	return tool
end

-- Make the Backpack match the inventory: one Tool per item held, none for the rest.
function Inventory.sync(player: Player)
	local data = PlayerData.get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not (data and backpack) then
		return
	end
	local mine = tools[player] or {}
	tools[player] = mine
	for _, id in Items.Order do
		local count = Items.count(data, id)
		local tool = mine[id]
		local alive = tool ~= nil and tool.Parent ~= nil
		if count > 0 and not alive then
			local made = makeTool(player, Items.Defs[id])
			if made then
				made.Parent = backpack
				mine[id] = made
			end
		elseif count <= 0 and tool then
			tool:Destroy()
			mine[id] = nil
		end
		if mine[id] then
			(mine[id] :: Tool):SetAttribute("Count", count)
		end
	end
end

--[[ Gaining and using ]]

-- Give `count` of an item, put it on the hotbar if it isn't, and show where it came from.
function Inventory.grant(player: Player, id: string, count: number, from: Vector3?)
	local data = PlayerData.get(player)
	local item = Items.Defs[id]
	if not (data and item) or count <= 0 then
		return
	end
	local bag = Items.bag(data, id)
	bag[id] = (bag[id] or 0) + count
	Hotbar.place(data.hotbar, id)
	effectRemote:FireClient(player, "loot", id, count, from)
	Cultivation.pushState(player)
end

local function take(data: PlayerData.Data, id: string)
	local bag = Items.bag(data, id)
	bag[id] = (bag[id] or 0) - 1
	if bag[id] <= 0 then
		bag[id] = nil
	end
end

-- Use one of an item. Refuses when it would do nothing at all.
function Inventory.use(player: Player, id: any): (boolean, string?)
	local data = PlayerData.get(player)
	local item = if type(id) == "string" then Items.Defs[id] else nil
	if not (data and item) then
		return false, "Unknown item"
	end
	if Items.count(data, item.id) < 1 then
		return false, "You have none left"
	end
	local now = os.clock()
	if now < (nextUse[player] or 0) then
		return false, nil
	end
	local use = item.use
	local stage = Cultivation.stage(data)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local qi = (use.qi or 0) + stage.dantian * (use.qiShare or 0)
	local onlyQi = qi > 0
		and not (use.buffs or use.cultivationShare or use.insight or (use.heal and humanoid and humanoid.Health < humanoid.MaxHealth))
	if onlyQi and data.rawQi >= stage.dantian then
		return false, "Your dantian is already full."
	end
	if use.rootGrade or use.rootReroll then
		if not (Cultivation.meditation and Cultivation.meditation(player)) then
			return false, "Sit and meditate to absorb it."
		end
		local why = if use.rootGrade then Roots.cantRaise(data) else Roots.cantReroll(data)
		if why then
			return false, why
		end
	end
	nextUse[player] = now + (if item.category == "Herb" then Items.HERB_EAT_SECONDS else Items.USE_COOLDOWN)
	take(data, item.id)

	data.rawQi = math.min(stage.dantian, data.rawQi + qi)
	if use.cultivationShare then
		data.cultivation = math.min(stage.bar, data.cultivation + stage.bar * use.cultivationShare)
	end
	if use.heal and humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * use.heal)
	end
	for _, b in use.buffs or {} do
		Cultivation.addBuff(data, item.id, b.kind, b.amount, b.seconds)
	end
	if use.insight then
		Progression.grantInsight(player, use.insight, item.name)
	end
	if use.rootGrade then
		Roots.raiseGrade(player)
	end
	if use.rootReroll then
		Roots.reroll(player)
	end
	Cultivation.markActive(player)
	Cultivation.applyStats(player, data)
	Cultivation.pushState(player)
	if item.category == "Herb" and player.Character then
		effectRemote:FireAllClients("herbEat", player.Character, item.id, workspace:GetServerTimeNow())
	end
	effectRemote:FireClient(player, "used", item.id)
	return true, `{item.name}: {item.blurb}`
end

-- EnemyService.onKill: roll the beast's drops for this player.
function Inventory.onKill(player: Player, def: Enemies.Def, model: Model)
	local at = model:GetPivot().Position
	for _, drop in def.drops or {} do
		if math.random() < drop.chance then
			Inventory.grant(player, drop.item, 1, at)
		end
	end
end

--[[ Hotbar ]]

local function owns(data: PlayerData.Data, id: string): boolean
	if Hotbar.isTechnique(id) then
		return data.techniques.owned[id] ~= nil
	end
	return Items.Defs[id] ~= nil
end

-- Put `id` into `slot` (or the first empty slot), swapping whatever was there
-- into the slot `id` came from.
local function setSlot(data: PlayerData.Data, id: string, slot: number?): (boolean, string?)
	local bar = data.hotbar
	local from = table.find(bar, id)
	local to = slot or from or table.find(bar, "")
	if not to then
		return false, "Hotbar is full."
	end
	local displaced = bar[to]
	if
		Hotbar.isTechnique(id)
		and not from
		and not Hotbar.isTechnique(displaced)
		and Hotbar.techniqueCount(bar) >= Hotbar.MAX_TECHNIQUES
	then
		return false, `You can keep at most {Hotbar.MAX_TECHNIQUES} techniques ready. Remove one first.`
	end
	bar[to] = id
	if from and from ~= to then
		bar[from] = displaced
	end
	return true, nil
end

local function validSlot(slot: any): boolean
	return type(slot) == "number" and slot % 1 == 0 and slot >= 1 and slot <= Hotbar.SIZE
end

-- InventoryAction remote:
--   ("use", itemId)           use one
--   ("slot", id, slot?)       put a technique or item on the hotbar
--   ("clear", slot)           empty a slot
--   ("swap", slotA, slotB)    swap two slots
--   ("comprehend", techniqueId) break its bottleneck (Progression.comprehend)
function Inventory.handle(player: Player, action: any, a: any, b: any): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading"
	end
	local ok, message = true, nil
	if action == "use" then
		return Inventory.use(player, a)
	elseif action == "comprehend" then
		return Progression.comprehend(player, a)
	elseif action == "slot" then
		if type(a) ~= "string" or not owns(data, a) or (b ~= nil and not validSlot(b)) then
			return false, "You can't place that"
		end
		ok, message = setSlot(data, a, b)
	elseif action == "clear" then
		if not validSlot(a) then
			return false, "No such slot"
		end
		data.hotbar[a] = ""
	elseif action == "swap" then
		if not (validSlot(a) and validSlot(b)) then
			return false, "No such slot"
		end
		data.hotbar[a], data.hotbar[b] = data.hotbar[b], data.hotbar[a]
	else
		return false, "Unknown action"
	end
	Cultivation.pushState(player)
	return ok, message
end

-- A new manual goes onto the hotbar if there's room for another technique.
function Inventory.slotTechnique(data: PlayerData.Data, id: string): boolean
	if not Techniques.Defs[id] or table.find(data.hotbar, id) then
		return table.find(data.hotbar, id) ~= nil
	end
	if Hotbar.techniqueCount(data.hotbar) >= Hotbar.MAX_TECHNIQUES then
		return false
	end
	return Hotbar.place(data.hotbar, id) ~= nil
end

function Inventory.forget(player: Player)
	tools[player] = nil
	nextUse[player] = nil
end

function Inventory.start()
	table.insert(Cultivation.onPush, function(player)
		Inventory.sync(player)
	end)
	Progression.slotTechnique = Inventory.slotTechnique
	local function watch(player: Player)
		-- a respawn brings a fresh Backpack; refill it
		player.CharacterAdded:Connect(function()
			task.defer(Inventory.sync, player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Inventory
