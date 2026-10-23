--!strict
-- Owns the played character's race, variant and traits on the server
-- (docs/systems/identity.md). The config and the rules are in Shared.Identity
-- (Registry reads them); this module is the only one that changes a profile's
-- `identity`, so normal play, game code and the admin panel all go through the
-- same checks. The race and variant are the slot position's fate (Slots.luau):
-- CharacterIdentity.load copies the fate in on Play, and setRace writes a change
-- back to it.
--   Traits.setRace     a race and variant (roll, pick, admin), then a sync
--   Traits.sync        innate traits follow the race and variant, Unlock traits
--                      whose Requires are met are granted, effects are reapplied
--   Traits.grant       normal grants from game code (quests, items, events)
--   Traits.adminGrant  / adminRemove: the admin panel; Hidden is allowed, Disabled
--                      never, and a trait outside its Access only with `force`
--
-- Published as player attributes (they replicate; the screens only read them):
--   Race, RaceVariant          ids ("" when the race has no variants)
--   Traits, TraitsInactive     comma lists of owned trait ids, active or not
--
-- Mechanics: races, variants and traits may name passives or abilities
-- (`Mechanics`). Register a handler in Traits.mechanics[id] = { attach =
-- fn(player), detach = fn(player) } and it's attached while the player has it.
-- Nothing is registered yet; unknown ids do nothing.
--
-- Cosmetics: races, variants and traits may name accessories (`Cosmetics`, ids
-- in ReplicatedStorage.Cosmetics, assets/Cosmetics/<set>.rbxm). applyBody wears them while
-- they apply and takes them off when they don't, along with the body size.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(ReplicatedStorage.Shared.Identity.Registry)
local Requirements = require(ReplicatedStorage.Shared.Identity.Requirements)
local Rules = require(ReplicatedStorage.Shared.CharacterCreator.Rules)
local PlayerData = require(script.Parent.PlayerData)
local Cultivation = require(script.Parent.Cultivation)

export type Mechanic = { attach: (Player) -> (), detach: (Player) -> () }

local Traits = {}
Traits.mechanics = {} :: { [string]: Mechanic }
-- Hooks: (player, traitId, src) when a trait is gained or lost.
Traits.onGained = {} :: { (Player, string, string) -> () }
Traits.onLost = {} :: { (Player, string) -> () }

local random = Random.new()
local attached: { [Player]: { [string]: boolean } } = {}

local function fire(list: { any }, ...: any)
	for _, hook in list do
		task.spawn(hook, ...)
	end
end

local function sortedIds(map: { [string]: any }): { string }
	local ids = {}
	for id in map do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

-- The mechanics the player has right now: from their race, variant and active traits.
local function mechanicsOf(data: PlayerData.Data): { [string]: boolean }
	local identity = data.identity
	local set = {}
	local race = Registry.race(identity.race)
	local variant = Registry.variant(identity.race, identity.variant)
	if race and not Registry.disabled(Registry.raceEntry(identity.race)) then
		for _, id in race.Mechanics or {} do
			set[id] = true
		end
		if variant and not Registry.disabled(Registry.variantEntry(identity.race, identity.variant)) then
			for _, id in variant.Mechanics or {} do
				set[id] = true
			end
		end
	end
	for traitId in identity.traits do
		if Registry.active(data, traitId) then
			for _, id in Registry.trait(traitId).Mechanics or {} do
				set[id] = true
			end
		end
	end
	return set
end

--[[ Body size (the `size` modifier, e.g. Titan Frame) ]]

local MIN_SCALE, MAX_SCALE = 0.5, 2
local ROOT_HEIGHT = 3 -- studs from the ground to an R6 root's centre at scale 1

-- The body scale this profile should have: 1 plus every `size` modifier.
function Traits.scaleOf(data: PlayerData.Data): number
	return math.clamp(1 + Registry.stat(data, "size"), MIN_SCALE, MAX_SCALE)
end

-- Scales a character to `target` with Model:ScaleTo, which scales every part,
-- joint, accessory and the held weapon together so animations and welds stay
-- right, then moves it so the feet stay on the ground (ScaleTo scales about the
-- root). Hitboxes don't change: strike and enemy hit checks are boxes and
-- distances from the root (Shared.Hitbox, Config.CLASSES), not the body's size.
function Traits.scaleCharacter(character: Model, target: number)
	local current = character:GetScale()
	if math.abs(current - target) < 1e-3 then
		return
	end
	local pivot = character:GetPivot()
	character:ScaleTo(target)
	character:PivotTo(pivot + Vector3.yAxis * (target - current) * ROOT_HEIGHT)
end

--[[ Cosmetics (fox ears and tail: `Cosmetics` on races, variants and traits) ]]

local COSMETIC_ATTRIBUTE = "Cosmetic" -- on each worn cosmetic accessory: its id
local warnedCosmetic: { [string]: boolean } = {}

local function cosmeticTemplate(id: string): Accessory?
	-- one folder per set (assets/Cosmetics/<set>.rbxm), so look through all of them
	local folder = ReplicatedStorage:FindFirstChild("Cosmetics")
	local template = folder and folder:FindFirstChild(id, true)
	if template and template:IsA("Accessory") then
		return template
	end
	if not warnedCosmetic[id] then
		warnedCosmetic[id] = true
		warn(`Traits: cosmetic "{id}" isn't in ReplicatedStorage.Cosmetics (assets/Cosmetics/)`)
	end
	return nil
end

-- Brings the character's body in line with the profile: the cosmetics its race,
-- variant and active traits call for (added or taken off), then its size.
-- Cosmetics go on at scale 1 and grow with the body, like dress-up's accessories.
-- Skipped while CharacterIdentity is dressing it (it unscales, dresses, then calls
-- this again), since ApplyDescription strips accessories.
function Traits.applyBody(player: Player)
	local character = player.Character
	local data = PlayerData.get(player)
	if not (character and data) or character:GetAttribute("Dressing") then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and character:FindFirstChild("HumanoidRootPart")) then
		return
	end
	local want = Registry.cosmetics(data)
	local worn: { [string]: Accessory } = {}
	for _, child in character:GetChildren() do
		local id = child:GetAttribute(COSMETIC_ATTRIBUTE)
		if child:IsA("Accessory") and type(id) == "string" then
			worn[id] = child
		end
	end
	local stale, missing = {}, {}
	for id, accessory in worn do
		if not want[id] then
			table.insert(stale, accessory)
		end
	end
	for id in want do
		if not worn[id] and cosmeticTemplate(id) then
			table.insert(missing, id)
		end
	end
	local target = Traits.scaleOf(data)
	if #stale > 0 or #missing > 0 then
		Traits.scaleCharacter(character, 1)
		for _, accessory in stale do
			accessory:Destroy()
		end
		for _, id in missing do
			local accessory = (cosmeticTemplate(id) :: Accessory):Clone()
			accessory:SetAttribute(COSMETIC_ATTRIBUTE, id)
			humanoid:AddAccessory(accessory)
		end
	end
	Traits.scaleCharacter(character, target)
end

-- Every spawn gets its cosmetics and size once the avatar's appearance has loaded (accessories
-- that arrive later would stay small otherwise).
function Traits.watch(player: Player)
	local function onCharacter(character: Model)
		local waited = 0
		while not player:HasAppearanceLoaded() and waited < 5 and player.Character == character do
			waited += task.wait(0.1)
		end
		if player.Character == character then
			Traits.applyBody(player)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

-- Attributes, mechanics and stats follow the profile.
function Traits.publish(player: Player, data: PlayerData.Data)
	local identity = data.identity
	player:SetAttribute("Race", if identity.race ~= "" then identity.race else nil)
	player:SetAttribute("RaceVariant", identity.variant)
	local active, inactive = {}, {}
	for _, id in sortedIds(identity.traits) do
		table.insert(if Registry.active(data, id) then active else inactive, id)
	end
	player:SetAttribute("Traits", table.concat(active, ","))
	player:SetAttribute("TraitsInactive", table.concat(inactive, ","))

	local now = mechanicsOf(data)
	local was = attached[player] or {}
	for id in was do
		local mechanic = Traits.mechanics[id]
		if not now[id] and mechanic then
			task.spawn(mechanic.detach, player)
		end
	end
	for id in now do
		local mechanic = Traits.mechanics[id]
		if not was[id] and mechanic then
			task.spawn(mechanic.attach, player)
		end
	end
	attached[player] = now
	Cultivation.applyStats(player, data)
	Traits.applyBody(player)
end

local function add(player: Player, data: PlayerData.Data, id: string, src: string, force: boolean?)
	data.identity.traits[id] = { src = src, t = os.time(), force = if force then true else nil }
	fire(Traits.onGained, player, id, src)
end

local function drop(player: Player, data: PlayerData.Data, id: string)
	data.identity.traits[id] = nil
	fire(Traits.onLost, player, id)
end

-- Bring the profile in line with the config: innate traits follow the race and
-- variant (old innate ones go, new ones come), and every released Unlock trait the
-- player may own and whose Requires are met is granted. Then publish.
function Traits.sync(player: Player, data: PlayerData.Data?)
	data = data or PlayerData.get(player)
	if not data then
		return
	end
	local profile = data :: PlayerData.Data
	local identity = profile.identity
	if identity.race ~= "" then
		local innate = Registry.innate(identity.race, identity.variant)
		for id, owned in identity.traits do
			if owned.src == "innate" and not table.find(innate, id) then
				drop(player, profile, id)
			end
		end
		for _, id in innate do
			local entry = Registry.traitEntry(id)
			if not identity.traits[id] and Registry.trait(id) and not Registry.disabled(entry) then
				add(player, profile, id, "innate")
			end
		end
		local bloodline = type((profile :: any).bloodline) == "table" and (profile :: any).bloodline.id or nil
		for id, def in Registry.Traits do
			if def.Obtain == "Unlock" and not identity.traits[id]
				and Registry.released(Registry.traitEntry(id))
				and Registry.accessible(id, identity, bloodline)
				and not Registry.conflict(identity, id)
				and Requirements.met(profile, def.Requires)
			then
				add(player, profile, id, "unlock")
			end
		end
	end
	Traits.publish(player, profile)
end

-- Picks a key from a { [key]: { Weight } } pool, or nil when it's empty.
local function pick(pool: { [string]: any }): string?
	return if next(pool) then Rules.roll(pool, random) else nil
end

-- A variant for a race: one that can be rolled, else the first the player may
-- pick, else nil. "" for a race without variants.
local function landingVariant(raceId: string, data: PlayerData.Data): string?
	if not Registry.hasVariants(raceId) then
		return ""
	end
	return pick(Registry.variantPool(raceId, "Roll")) or sortedIds(Registry.choosableVariants(raceId, data))[1]
end

-- Sets the race and variant (variant nil = land on one), then syncs. Validation
-- of who may have it is the caller's (rollRace, choose, admin).
function Traits.setRace(player: Player, data: PlayerData.Data, raceId: string, variantId: string?): (boolean, string?)
	if not Registry.race(raceId) then
		return false, "Unknown race"
	end
	local variant = if variantId and variantId ~= "" then variantId else landingVariant(raceId, data)
	if variant == nil then
		return false, `{Registry.race(raceId).DisplayName} has no variant you can have`
	elseif variant ~= "" and not Registry.variant(raceId, variant) then
		return false, "Unknown variant"
	end
	data.identity.race = raceId
	data.identity.variant = variant :: string
	-- the played slot's fate keeps the race (it's what the slot screen and a rejoin read)
	local account, active = PlayerData.account(player), PlayerData.active(player)
	local fate = account and active and account.fates[active]
	if fate and (account :: PlayerData.Account).slots[active :: string] == data then
		fate.Race = raceId
		fate.Variant = variant :: string
	end
	Traits.sync(player, data)
	return true, Registry.label(raceId, variant)
end

-- The free join roll and the paid reroll: a released Roll race, then its variant.
function Traits.rollRace(player: Player, data: PlayerData.Data): string?
	local raceId = pick(Registry.racePool("Roll"))
	if not raceId then
		warn("Traits: no race can be rolled (Identity/Availability.luau)")
		return nil
	end
	Traits.setRace(player, data, raceId, nil)
	return raceId
end

-- On join: keep the saved race and variant unless the config dropped them
-- (deleted or Disabled), then sync. Hidden ones stay: an admin gave them.
function Traits.load(player: Player, data: PlayerData.Data)
	local identity = data.identity
	local raceOk = Registry.race(identity.race) ~= nil and not Registry.disabled(Registry.raceEntry(identity.race))
	if not raceOk then
		Traits.rollRace(player, data)
		return
	end
	if Registry.hasVariants(identity.race) then
		local variantOk = Registry.variant(identity.race, identity.variant) ~= nil
			and not Registry.disabled(Registry.variantEntry(identity.race, identity.variant))
		if not variantOk then
			identity.variant = landingVariant(identity.race, data) or ""
			if identity.variant == "" then
				Traits.rollRace(player, data) -- nothing of this race is left to land on
				return
			end
		end
	elseif identity.variant ~= "" then
		identity.variant = ""
	end
	Traits.sync(player, data)
end

-- A player picking a race or variant on the character screen ("Race" | "Variant").
-- Only what Availability lets them pick (Select, or Unlock with Requires met).
function Traits.choose(player: Player, kind: any, id: any): (boolean, string?)
	local data = PlayerData.get(player)
	if not data or type(id) ~= "string" then
		return false, "Bad request"
	end
	if kind == "Race" then
		if not Registry.choosableRaces(data)[id] then
			return false, "You can't choose that race"
		end
		return Traits.setRace(player, data, id, nil)
	elseif kind == "Variant" then
		local raceId = data.identity.race
		if not Registry.choosableVariants(raceId, data)[id] then
			return false, "You can't choose that variant"
		end
		return Traits.setRace(player, data, raceId, id)
	end
	return false, "Bad request"
end

-- Gives a trait through normal play (Obtain "Grant" or "Unlock" traits, from a
-- quest, item or event). Only released traits the player may own, never one that
-- conflicts with what they have.
function Traits.grant(player: Player, id: string, src: string?): (boolean, string?)
	local data = PlayerData.get(player)
	local def = Registry.trait(id)
	if not data or not def then
		return false, "Unknown trait"
	end
	local identity = data.identity
	local bloodline = type((data :: any).bloodline) == "table" and (data :: any).bloodline.id or nil
	if identity.traits[id] then
		return false, "Already has it"
	elseif not Registry.released(Registry.traitEntry(id)) then
		return false, "Not released"
	elseif not Registry.accessible(id, identity, bloodline) then
		return false, "Not open to this character"
	end
	local clash = Registry.conflict(identity, id)
	if clash then
		return false, `Can't be held with {Registry.trait(clash).DisplayName}`
	end
	add(player, data, id, src or "grant")
	Traits.publish(player, data)
	return true, def.DisplayName
end

--[[ Admin (Admin.luau checks the caller) ]]

function Traits.adminGrant(target: Player, id: any, force: any): (boolean, string?)
	local data = PlayerData.get(target)
	local def = Registry.trait(id)
	if not data or not def then
		return false, "Unknown trait or player not loaded"
	end
	local identity = data.identity
	if identity.traits[id] then
		return false, `{target.Name} already has {def.DisplayName}`
	elseif Registry.disabled(Registry.traitEntry(id)) then
		return false, `{def.DisplayName} is disabled`
	end
	local bloodline = type((data :: any).bloodline) == "table" and (data :: any).bloodline.id or nil
	local open = Registry.accessible(id, identity, bloodline)
	if not open and force ~= true then
		return false, `{def.DisplayName} is for {Registry.accessLabel(id)}; force it to test`
	end
	local clash = Registry.conflict(identity, id)
	if clash then
		return false, `Can't be held with {Registry.trait(clash).DisplayName}; remove that first`
	end
	add(target, data, id, "admin", not open)
	Traits.publish(target, data)
	return true, `Gave {target.Name} {def.DisplayName}{if open then "" else " (forced)"}`
end

function Traits.adminRemove(target: Player, id: any): (boolean, string?)
	local data = PlayerData.get(target)
	if not data or type(id) ~= "string" or not data.identity.traits[id] then
		return false, "They don't have that trait"
	end
	drop(target, data, id)
	Traits.publish(target, data)
	local def = Registry.trait(id)
	local innate = table.find(Registry.innate(data.identity.race, data.identity.variant), id) ~= nil
	return true, `Removed {if def then def.DisplayName else id}{if innate then " (innate: it returns on their next sync or join)" else ""}`
end

-- Any race or variant that isn't Disabled, Hidden ones included (for testing).
function Traits.adminSetRace(target: Player, raceId: any, variantId: any): (boolean, string?)
	local data = PlayerData.get(target)
	if not data or not Registry.race(raceId) then
		return false, "Unknown race or player not loaded"
	end
	if Registry.disabled(Registry.raceEntry(raceId)) then
		return false, `{Registry.race(raceId).DisplayName} is disabled`
	end
	if variantId ~= nil and variantId ~= "" then
		if not Registry.variant(raceId, variantId) then
			return false, "Unknown variant"
		elseif Registry.disabled(Registry.variantEntry(raceId, variantId)) then
			return false, `{Registry.label(raceId, variantId)} is disabled`
		end
	end
	local ok, label = Traits.setRace(target, data, raceId, variantId)
	return ok, if ok then `{target.Name} is now {label}` else label
end

-- What the admin panel shows for a player.
function Traits.describe(target: Player): { [string]: any }?
	local data = PlayerData.get(target)
	if not data then
		return nil
	end
	local owned = {}
	for _, id in sortedIds(data.identity.traits) do
		local t = data.identity.traits[id]
		table.insert(owned, { id = id, src = t.src, force = t.force == true, active = Registry.active(data, id) })
	end
	return {
		userId = target.UserId,
		name = target.Name,
		race = data.identity.race,
		variant = data.identity.variant,
		label = Registry.label(data.identity.race, data.identity.variant),
		traits = owned,
	}
end

-- Unlock checks after anything that can meet a requirement.
function Traits.check(player: Player)
	local data = PlayerData.get(player)
	if data and data.identity.race ~= "" then
		Traits.sync(player, data)
	end
end

function Traits.forget(player: Player)
	attached[player] = nil
end

return Traits
