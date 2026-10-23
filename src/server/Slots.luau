--!strict
-- Save slots on the server (docs/systems/save-slots.md). A player joins onto the
-- slot screen; Main waits in `awaitPlay` until they play a slot, then runs the
-- rest of the join on that slot's profile. Everything here is checked on the
-- server: the client only asks.
--
-- Race (with its variant) and last name belong to a slot position
-- (Account.fates), not to the character in it: drawn free the first time New is
-- pressed there, kept when the slot is deleted, so delete-then-new draws nothing
-- new. A paid reroll changes the fate of the position the creator has open. The
-- played slot's traits follow its race in Traits.luau (docs/systems/identity.md).
--
-- Actions (through CharacterAction, CharacterIdentity.handle):
--   "slots"            -> { slots = { Summary }, max, canSave, last, playing }
--   "new", id          -> opens the creator on an empty (or unnamed) slot:
--                         { id, mode = "new", progress } and the fate attributes
--   "edit", id         -> opens it on a named slot's look: { id, mode = "edit", look, firstName }
--   "cancel"           -> back to the slot screen from the creator
--   "play", id         -> plays a named slot (the join continues in Main)
--   "deleteAsk", id    -> { token }: the hold-to-delete sends it back
--   "delete", { id, token, name } -> moves the slot to the trash and saves
--   "slotHairs", id    -> { { id, accessory } } preview copies of the slot's hairs

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local CC = ReplicatedStorage.Shared.CharacterCreator
local Clothing = require(CC.Clothing)
local HairColors = require(CC.HairColors)
local Registry = require(ReplicatedStorage.Shared.Identity.Registry)
local Rules = require(CC.Rules)
local Surnames = require(CC.Surnames)
local PlayerData = require(script.Parent.PlayerData)
local Traits = require(script.Parent.Traits)

local SlotConfig = Config.Slots

export type Summary = {
	id: string,
	filled: boolean,
	named: boolean,
	firstName: string?,
	race: string?,
	variant: string?,
	surname: string?,
	realm: { major: string, minor: number }?,
	lastPlayed: number?,
	look: { [string]: any }?,
}
export type Session = { id: string, mode: string } -- the creator open on a slot

local Slots = {}

local random = Random.new()
local pending: { [Player]: thread } = {} -- Main's join, waiting for Play
local sessions: { [Player]: Session } = {}
local deleteTokens: { [Player]: { id: string, token: string, at: number } } = {}
local busy: { [Player]: boolean } = {}

local KINDS = { Race = true, Surname = true }

local function named(data: PlayerData.Data?): boolean
	local character = data and data.character
	return character ~= nil and type(character.firstName) == "string" and character.firstName ~= ""
end

local function kept(raceId: string, variantId: string?): boolean
	if not Registry.race(raceId) or Registry.disabled(Registry.raceEntry(raceId)) then
		return false
	elseif not Registry.hasVariants(raceId) then
		return true
	end
	return Registry.variant(raceId, variantId) ~= nil and not Registry.disabled(Registry.variantEntry(raceId, variantId :: string))
end

-- A fresh race and variant from the join roll (Availability Roll, weighted).
local function rollRace(fate: any)
	local pool = Registry.racePool("Roll")
	if not next(pool) then
		warn("Slots: no race can be rolled (Identity/Availability.luau)")
		return
	end
	fate.Race = Rules.roll(pool, random)
	local variants = Registry.variantPool(fate.Race, "Roll")
	fate.Variant = if next(variants) then Rules.roll(variants, random) else ""
end

-- The race, variant and last name of a slot position, drawn (free) where missing
-- or no longer in the config. A race kept without a variant (saved before
-- variants, or its variant was dropped) draws only the variant. Hidden races and
-- variants stay: an admin gave them.
function Slots.fate(player: Player, id: string): PlayerData.Fate?
	local account = PlayerData.account(player)
	if not (account and PlayerData.validSlot(id)) then
		return nil
	end
	local fate = account.fates[id] or {} :: any
	if not kept(fate.Race or "", fate.Variant) then
		if Registry.race(fate.Race) and next(Registry.variantPool(fate.Race, "Roll")) then
			fate.Variant = Rules.roll(Registry.variantPool(fate.Race, "Roll"), random)
		else
			rollRace(fate)
		end
	elseif not Registry.hasVariants(fate.Race) then
		fate.Variant = ""
	end
	if not (Surnames :: any)[fate.Surname or ""] then
		fate.Surname = Rules.roll(Surnames :: any, random)
	end
	account.fates[id] = fate
	return fate
end

-- Shows a slot's race, last name and first name as the player's attributes
-- (the character screen and nameplates read them).
function Slots.showIdentity(player: Player, id: string)
	local fate = Slots.fate(player, id)
	local account = PlayerData.account(player)
	local data = account and account.slots[id]
	if fate then
		player:SetAttribute("Race", fate.Race)
		player:SetAttribute("RaceVariant", fate.Variant)
		player:SetAttribute("Surname", fate.Surname)
	end
	player:SetAttribute("FirstName", if named(data) then (data :: any).character.firstName else nil)
end

-- Rerolls one part of a slot position's fate ("Race" draws a variant too);
-- returns the new key. On the played slot a race change goes through Traits,
-- so its innate traits follow.
function Slots.reroll(player: Player, id: string, kind: string): string?
	local fate = KINDS[kind] and Slots.fate(player, id)
	if not fate then
		return nil
	end
	if kind == "Race" then
		rollRace(fate)
	else
		fate.Surname = Rules.roll(Surnames :: any, random)
	end
	local key = (fate :: any)[kind]
	local data = PlayerData.get(player)
	if kind == "Race" and data and PlayerData.active(player) == id then
		Traits.setRace(player, data, fate.Race, fate.Variant)
	end
	local session = sessions[player]
	if (session and session.id == id) or PlayerData.active(player) == id then
		player:SetAttribute(kind, key)
		if kind == "Race" then
			player:SetAttribute("RaceVariant", fate.Variant)
		end
	end
	return key
end

-- The slot the character screen has open, if any.
function Slots.session(player: Player): Session?
	return sessions[player]
end

local function summary(account: PlayerData.Account, id: string): Summary
	local data = account.slots[id]
	if not data then
		return { id = id, filled = false, named = false } -- an empty slot's fate stays hidden
	end
	local fate = account.fates[id]
	local character = data.character or {}
	return {
		id = id,
		filled = true,
		named = named(data),
		firstName = character.firstName,
		race = fate and fate.Race,
		variant = fate and fate.Variant,
		surname = fate and fate.Surname,
		realm = { major = data.realm.major, minor = data.realm.minor },
		lastPlayed = data.lastLogoutUnix,
		look = character.look,
	}
end

-- Waits (up to 30 s) for the join to load the account.
local function waitAccount(player: Player): PlayerData.Account?
	local deadline = os.clock() + 30
	while player.Parent and os.clock() < deadline do
		local account = PlayerData.account(player)
		if account then
			return account
		end
		task.wait(0.1)
	end
	return nil
end

local function defaultLook(): { [string]: any }
	return {
		Shirt = Clothing.Shirt[1].Id,
		Pants = Clothing.Pants[1].Id,
		HairIds = {},
		HairColor = HairColors[1].Id,
		SkinColor = "Avatar",
	}
end

-- The testbed's first visit: a ready "Tester" in slot 1 and slot 2 left empty,
-- so the slot screen and the creator can both be tried at once.
local function seedTestbed(player: Player)
	local account = PlayerData.account(player)
	if not (Config.TESTBED and account and next(account.slots) == nil) then
		return
	end
	local data = PlayerData.createSlot(player, "1")
	if data then
		data.character = { firstName = "Tester", look = defaultLook() }
		Slots.fate(player, "1")
		account.last = "1"
	end
end

-- Main's join waits here until the player plays a slot; returns its profile
-- (nil if they left first). Slots off: slot 1 at once, as before slots.
-- QuickPlay: the last (or first named) slot at once, no screens.
function Slots.awaitPlay(player: Player): PlayerData.Data?
	if not SlotConfig.ENABLED then
		return PlayerData.activate(player, "1")
	end
	seedTestbed(player)
	if SlotConfig.QUICK_PLAY then
		local account = PlayerData.account(player) :: PlayerData.Account
		local pick = if named(account.slots[account.last]) then account.last else nil
		for _, id in PlayerData.SLOT_IDS do
			if not pick and named(account.slots[id]) then
				pick = id
			end
		end
		if pick then
			return PlayerData.activate(player, pick)
		end
	end
	if player.Parent == nil then
		return nil
	end
	pending[player] = coroutine.running()
	return coroutine.yield()
end

-- Plays a slot: the waiting join resumes with its profile.
function Slots.play(player: Player, id: string): (boolean, any)
	local thread = pending[player]
	local account = PlayerData.account(player)
	if not (thread and account) then
		return false, "Already in the world"
	end
	if not named(account.slots[id]) then
		return false, "Name this cultivator first"
	end
	local data = PlayerData.activate(player, id)
	if not data then
		return false, "That slot can't be played"
	end
	pending[player] = nil
	sessions[player] = nil
	task.spawn(thread, data)
	return true, id
end

-- Called by the character screen's Enter World on a "new" session, after the
-- look and name are checked: fills the slot (a fresh profile, or the unnamed
-- migrated one keeps its progress), saves, and plays it.
function Slots.commitNew(player: Player, look: { [string]: any }, firstName: string): (boolean, any)
	local session = sessions[player]
	if not (session and session.mode == "new") then
		return false, "Pick a slot first"
	end
	local account = PlayerData.account(player) :: PlayerData.Account
	local data = account.slots[session.id] or PlayerData.createSlot(player, session.id)
	if not data or named(data) then
		return false, "That slot is taken"
	end
	data.character = { firstName = firstName, look = look }
	Slots.fate(player, session.id)
	task.spawn(PlayerData.save, player)
	return Slots.play(player, session.id)
end

-- Edit look: only the look changes (the first name is locked once named).
function Slots.commitEdit(player: Player, look: { [string]: any }): (boolean, any)
	local session = sessions[player]
	local account = PlayerData.account(player)
	local data = session and session.mode == "edit" and account and account.slots[session.id]
	if not (data and named(data)) then
		return false, "Pick a slot first"
	end
	data.character.look = look
	sessions[player] = nil
	task.spawn(PlayerData.save, player)
	return true, summary(account :: PlayerData.Account, (session :: Session).id)
end

local function onScreen(player: Player): boolean
	return pending[player] ~= nil
end

function Slots.handle(player: Player, action: string, arg: any): (boolean, any)
	if action == "slots" then
		local account = waitAccount(player)
		if not account then
			return false, "Your characters are still loading"
		end
		local list = {}
		for _, id in PlayerData.SLOT_IDS do
			table.insert(list, summary(account, id))
		end
		return true, {
			slots = list,
			max = SlotConfig.MAX,
			canSave = PlayerData.canSave(player),
			last = account.last,
			playing = PlayerData.active(player) ~= nil,
		}
	end
	local account = PlayerData.account(player)
	if not account then
		return false, "Your characters are still loading"
	end
	if action == "slotHairs" then
		local data = PlayerData.validSlot(arg) and account.slots[arg]
		local look = data and data.character and data.character.look
		return true, if look and type(look.HairIds) == "table" then look.HairIds else {}
	end
	if not onScreen(player) then
		return false, "Already in the world"
	end
	if action == "cancel" then
		sessions[player] = nil
		return true, nil
	elseif action == "play" then
		return Slots.play(player, arg)
	end
	if busy[player] then
		return false, "One moment"
	end
	busy[player] = true
	local ok, success, payload = pcall(function(): (boolean, any)
		if action == "new" then
			if not PlayerData.validSlot(arg) or named(account.slots[arg]) then
				return false, "That slot is taken"
			end
			sessions[player] = { id = arg, mode = "new" }
			Slots.showIdentity(player, arg)
			task.spawn(PlayerData.save, player) -- the draw is kept even if they leave now
			return true, { id = arg, mode = "new", progress = account.slots[arg] ~= nil }
		elseif action == "edit" then
			local data = PlayerData.validSlot(arg) and account.slots[arg]
			if not (data and named(data)) then
				return false, "That slot is empty"
			end
			sessions[player] = { id = arg, mode = "edit" }
			Slots.showIdentity(player, arg)
			return true, { id = arg, mode = "edit", look = data.character.look, firstName = data.character.firstName }
		elseif action == "deleteAsk" then
			if not (PlayerData.validSlot(arg) and account.slots[arg]) then
				return false, "That slot is empty"
			end
			if not PlayerData.canSave(player) then
				return false, "Your characters couldn't be loaded, so nothing can be deleted now"
			end
			local token = HttpService:GenerateGUID(false)
			deleteTokens[player] = { id = arg, token = token, at = os.clock() }
			return true, { token = token }
		elseif action == "delete" then
			local ask = deleteTokens[player]
			deleteTokens[player] = nil
			if type(arg) ~= "table" or not ask or ask.id ~= arg.id or ask.token ~= arg.token then
				return false, "Try deleting again"
			end
			if os.clock() - ask.at > SlotConfig.DELETE_TOKEN_SECONDS then
				return false, "That took too long. Try again."
			end
			local data = account.slots[ask.id]
			local name = if data and named(data) then data.character.firstName else ""
			if not data or arg.name ~= name then
				return false, "Try deleting again"
			end
			if not PlayerData.deleteSlot(player, ask.id) then
				return false, "That slot can't be deleted"
			end
			PlayerData.save(player) -- before saying it's gone
			return true, summary(account, ask.id)
		end
		return false, "Bad request"
	end)
	busy[player] = nil
	if not ok then
		warn(`Slots: {action} failed for {player.Name}: {success}`)
		return false, "Something went wrong"
	end
	return success, payload
end

function Slots.forget(player: Player)
	local thread = pending[player]
	pending[player] = nil
	sessions[player] = nil
	deleteTokens[player] = nil
	busy[player] = nil
	if thread then
		task.spawn(thread, nil) -- the join gives up: they left on the slot screen
	end
end

Players.PlayerRemoving:Connect(Slots.forget)

return Slots
