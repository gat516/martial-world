--!strict
-- Owned and equipped weapons, the held weapon model, and weapon Dao comprehension.
--   WeaponAction (RemoteFunction): ("equip", weaponId) / ("unequip") -> (ok, message)
--   ("stow", character, boolean) mirrors cosmetic control locks to all observers.
--   The equipped weapon's model (ServerStorage.WeaponModels.<model>) is cloned
--   into the character as "HeldWeapon" and its joint Motor6D's Part0 set to the
--   Right Arm; it's re-applied on every respawn. Attributes: player `Weapon`
--   (equipped id or ""), character `WeaponClass` (every client's animator reads it).
--   Dao XP comes from landing M1s (Combat), casting class techniques and learning
--   their manuals; it multiplies M1 and class-technique damage (Pacing.Weapons).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Defs = require(ReplicatedStorage.Shared.Weapons)
local Pacing = require(ReplicatedStorage.Shared.Pacing).Weapons
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

local HELD_NAME = "HeldWeapon"
local BREAKTHROUGH_STOW_SECONDS = 1.6 -- the breakthrough column's lifetime

local Weapons = {}

local warned: { [string]: boolean } = {}
type Watch = {
	player: { RBXScriptConnection },
	character: { RBXScriptConnection },
}
local watched: { [Player]: Watch } = {}

local function disconnect(connections: { RBXScriptConnection })
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function equippedId(data: PlayerData.Data?): string
	local id = data and data.weapons.equipped or ""
	return if Defs.Defs[id] then id else ""
end

-- The player's equipped weapon class ("Fist" with nothing equipped).
function Weapons.class(player: Player): string
	return Defs.classOf(equippedId(PlayerData.get(player)))
end

function Weapons.level(data: PlayerData.Data, class: string): number
	local entry = data.dao[class]
	return if entry then entry.level else 0
end

-- Damage multiplier for `class` hits: the equipped weapon's grade (when it's
-- that class) times the class's Dao comprehension.
function Weapons.multiplier(player: Player, class: string): number
	local data = PlayerData.get(player)
	if not data then
		return 1
	end
	local id = equippedId(data)
	local grade = if Defs.classOf(id) == class then Defs.gradeMultiplier(id) else 1
	return grade * Defs.daoMultiplier(Weapons.level(data, class))
end

-- Called with (player, class) after a class's Dao level rises (Progression learns
-- kept manuals that need it).
Weapons.onLevelUp = {} :: { (Player, string) -> () }

-- Add Dao XP to a class. Pushes state only on a level-up (the periodic refresh
-- carries the rest), so it's cheap on the hit path.
function Weapons.addXp(player: Player, class: string, amount: number)
	local data = PlayerData.get(player)
	local def = Defs.Classes[class]
	if not (data and def) or amount <= 0 then
		return
	end
	local entry = data.dao[class]
	if not entry then
		entry = { level = 0, xp = 0 }
		data.dao[class] = entry
	end
	if entry.level >= Pacing.MAX_LEVEL then
		return
	end
	entry.xp += amount
	local leveled = false
	while entry.level < Pacing.MAX_LEVEL and entry.xp >= Defs.xpToNext(entry.level) do
		entry.xp -= Defs.xpToNext(entry.level)
		entry.level += 1
		leveled = true
	end
	if entry.level >= Pacing.MAX_LEVEL then
		entry.xp = 0
	end
	if leveled then
		Cultivation.notify(player, `Your {def.dao} comprehension rose to {entry.level}!`)
		Cultivation.pushState(player)
		for _, fn in Weapons.onLevelUp do
			fn(player, class)
		end
	end
end

--[[ Held model ]]

local function rightArm(character: Model): BasePart?
	return (character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")) :: BasePart?
end

-- Put the equipped weapon's model in the character's hand (or clear it).
function Weapons.apply(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local id = equippedId(PlayerData.get(player))
	player:SetAttribute("Weapon", id)
	character:SetAttribute("WeaponClass", Defs.classOf(id))
	local stowed = character:FindFirstChildOfClass("Tool") ~= nil
		or character:GetAttribute("WeaponControlsLocked") == true
		or (character:GetAttribute("WeaponBreakthroughUntil") or 0) > workspace:GetServerTimeNow()
	character:SetAttribute("WeaponStowed", stowed)
	local old = character:FindFirstChild(HELD_NAME)
	-- Releasing one lock must not redraw a weapon while another still owns it.
	if old and not stowed and old:GetAttribute("WeaponId") == id then return end
	if old then old:Destroy() end
	if stowed then
		return
	end
	local def = Defs.Defs[id]
	if not def then
		return
	end
	local class = Defs.Classes[def.class]
	local folder = ServerStorage:FindFirstChild("WeaponModels")
	local template = folder and folder:FindFirstChild(def.model)
	if not (template and template:IsA("Model")) then
		if not warned[def.model] then
			warned[def.model] = true
			warn(`Weapons: ServerStorage.WeaponModels.{def.model} is missing; {def.name} is held invisibly`)
		end
		return
	end
	local arm = rightArm(character)
	if not arm then
		return
	end
	local model = template:Clone()
	model.Name = HELD_NAME
	model:SetAttribute("WeaponId", id)
	local hilt = model.PrimaryPart
	local joint = hilt and class.joint and hilt:FindFirstChild(class.joint)
	if not (hilt and joint and joint:IsA("Motor6D")) then
		warn(`Weapons: {def.model} has no {class.joint} Motor6D in its PrimaryPart`)
		model:Destroy()
		return
	end
	-- A scaled body (a Titan Frame giant, Traits.applyBody) holds a weapon scaled
	-- to match: ScaleTo also scales the hand joint's C0/C1, so the grip lands on
	-- the bigger hand. A weapon already held when the body scales grows with it.
	local scale = character:GetScale()
	if math.abs(scale - 1) > 1e-3 then
		model:ScaleTo(scale)
	end
	-- Put the hilt at the motor's rest frame, then activate the model's welds
	-- before connecting it to the arm. Connecting outside Workspace lets the
	-- motor snap the hilt alone on insertion and bake that offset into the welds.
	model:PivotTo(arm.CFrame * joint.C0 * joint.C1:Inverse() * hilt.PivotOffset)
	model.Parent = character
	joint.Part0 = arm
end

-- Re-apply on respawn and whenever a Backpack Tool takes or releases the hand.
function Weapons.watch(player: Player)
	Weapons.forget(player)
	local watch: Watch = { player = {}, character = {} }
	watched[player] = watch
	local function onCharacter(character: Model)
		if watched[player] ~= watch or player.Character ~= character then return end
		disconnect(watch.character)
		local pending = false
		local function changed(child: Instance)
			if not child:IsA("Tool") or pending then return end
			pending = true
			-- Coalesce a Tool swap so the weapon doesn't reappear between items.
			task.defer(function()
				pending = false
				if watched[player] == watch and player.Character == character then
					Weapons.apply(player)
				end
			end)
		end
		table.insert(watch.character, character.ChildAdded:Connect(changed))
		table.insert(watch.character, character.ChildRemoved:Connect(changed))
		if character:WaitForChild("Right Arm", 5) or character:FindFirstChild("RightHand") then
			if watched[player] == watch and player.Character == character then
				Weapons.apply(player)
			end
		end
	end
	table.insert(watch.player, player.CharacterAdded:Connect(onCharacter))
	table.insert(watch.player, player.CharacterRemoving:Connect(function()
		disconnect(watch.character)
	end))
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function Weapons.forget(player: Player)
	local watch = watched[player]
	if watch then
		disconnect(watch.player)
		disconnect(watch.character)
		watched[player] = nil
	end
end

-- Includes forced breakthroughs outside meditation. A later breakthrough or
-- respawn supersedes this callback; movement/Tool locks still apply afterward.
function Weapons.onBreakthrough(player: Player)
	local character = player.Character
	if not character then return end
	local untilTime = workspace:GetServerTimeNow() + BREAKTHROUGH_STOW_SECONDS
	character:SetAttribute("WeaponBreakthroughUntil", untilTime)
	Weapons.apply(player)
	task.delay(BREAKTHROUGH_STOW_SECONDS, function()
		if player.Character ~= character or character:GetAttribute("WeaponBreakthroughUntil") ~= untilTime then return end
		character:SetAttribute("WeaponBreakthroughUntil", nil)
		Weapons.apply(player)
	end)
end

--[[ Owning and equipping ]]

-- Give a player a weapon. Fires Effect "weapon" (the rewards toast) unless silent.
function Weapons.grant(player: Player, weaponId: string, silent: boolean?): boolean
	local data = PlayerData.get(player)
	if not (data and Defs.Defs[weaponId]) then
		return false
	end
	data.weapons.owned[weaponId] = (data.weapons.owned[weaponId] or 0) + 1
	if not silent then
		effectRemote:FireClient(player, "weapon", weaponId)
	end
	Cultivation.pushState(player)
	return true
end

local function busy(player: Player): boolean
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid:GetAttribute("ActionBusy") == true
end

function Weapons.equip(player: Player, weaponId: string?): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading"
	end
	local id = weaponId or ""
	if id ~= "" and (not Defs.Defs[id] or (data.weapons.owned[id] or 0) <= 0) then
		return false, "You don't own that weapon"
	end
	if busy(player) then
		return false, "Finish your move first"
	end
	if data.weapons.equipped == id then
		return true, nil
	end
	data.weapons.equipped = id
	Weapons.apply(player)
	Cultivation.pushState(player)
	return true, if id == "" then "Fighting bare-handed" else `Equipped {Defs.Defs[id].name}`
end

function Weapons.handle(player: Player, action: any, weaponId: any, stowed: any): (boolean, string?)
	if action == "stow" then
		local character = player.Character
		if not character or weaponId ~= character or type(stowed) ~= "boolean" then
			return false, "Invalid weapon presentation"
		end
		-- Cosmetic only: this never changes selection, stats or action eligibility.
		if character:GetAttribute("WeaponControlsLocked") ~= stowed then
			character:SetAttribute("WeaponControlsLocked", stowed)
			Weapons.apply(player)
		end
		return true, nil
	elseif action == "equip" then
		if type(weaponId) ~= "string" then
			return false, "Unknown weapon"
		end
		return Weapons.equip(player, weaponId)
	elseif action == "unequip" then
		return Weapons.equip(player, nil)
	end
	return false, "Unknown action"
end

Players.PlayerRemoving:Connect(Weapons.forget)

return Weapons
