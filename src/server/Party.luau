--!strict
-- Parties and the player card (docs/systems/party.md). Server-local groups of up to
-- Pacing.Party MAX_SIZE: invite, accept, decline, leave, kick and hand the lead on.
-- Nothing persists; a party lives as long as its members stay in this server.
-- What a party gives: nearby members share in each other's kills (EnemyService.died
-- reads Party.members through EnemyService.partyOf), a small group qi bonus, "Join"
-- rides to a member (Travel.toPlayer), and the heart demon counts time spent
-- together (stats.partied). Never required for anything.
--
-- PartyAction (RemoteFunction), each returning (ok, payload|message):
--   "state"            -> { party = snapshot?, invites = { invite } } (on load)
--   "invite", userId   invite them (anyone in the server, no range rule); you lead
--                      the party it makes, or must lead the one you're in
--   "accept", userId   take that player's invite (leave your own party first)
--   "decline", userId  turn it down (they hear so)
--   "leave"            leave; the next member in join order leads; one left disbands
--   "kick", userId     leader only
--   "promote", userId  leader only: hand the lead to that member
--   "card", userId     -> the player card (Party.card)
--   "people"           -> everyone else here, friends first (Party.people)
--   "join", userId     ride to a party member (Travel.toPlayer "join")
--   "visit", userId    ride to their spirit peak (Travel.toPlayer "visit")
-- PartyState (RemoteEvent, S->C), (kind, payload):
--   "party", snapshot | nil        your party changed (members, leader, health, near)
--   "invite", invite               someone invited you
--   "inviteGone", userId, reason   that invite is over: "expired", "withdrawn", "answered"
--   "friendHere", { userId, name } a Roblox friend is in this server (once per session each)
-- Player attribute `Party`: the party's id (nil when solo), so nameplates can mark members.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Realms = require(ReplicatedStorage.Shared.Realms)
local Races = require(ReplicatedStorage.Shared.Identity.Races)
local Tuning = require(ReplicatedStorage.Shared.Pacing).Party
local PlayerData = require(script.Parent.PlayerData)
local Peaks = require(script.Parent.Peaks)
local Quests = require(script.Parent.Quests)
local Travel = require(script.Parent.Travel)
local Analytics = require(script.Parent.Analytics)

local remotes = ReplicatedStorage.Remotes
local stateRemote = remotes.PartyState :: RemoteEvent
local notifyRemote = remotes.Notify :: RemoteEvent

type PartyT = { id: string, leader: Player, members: { Player } }

local Party = {}

local partyOf: { [Player]: PartyT } = {}
local invites: { [Player]: { [Player]: number } } = {} -- invitee -> inviter -> expires (os.clock)
local lastInvite: { [Player]: number } = {}
local lastSent: { [Player]: string } = {} -- each member's last snapshot signature
local friends: { [Player]: { [Player]: boolean } } = {} -- IsFriendsWith answers, both ways
local nudged: { [Player]: { [number]: boolean } } = {} -- friendHere already sent, by userId
local nextId = 0

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

-- The name a card shows: the character's first and last name, else the display name.
function Party.nameOf(player: Player): string
	local first, last = player:GetAttribute("FirstName"), player:GetAttribute("Surname")
	if type(first) == "string" and first ~= "" then
		return if type(last) == "string" and last ~= "" then `{first} {last}` else first
	end
	return player.DisplayName
end

local function byId(userId: any): Player?
	local id = tonumber(userId)
	return if id then Players:GetPlayerByUserId(id) else nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0) then
		return nil
	end
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function near(a: Player, b: Player): boolean
	local ra, rb = rootOf(a), rootOf(b)
	return ra ~= nil and rb ~= nil and (ra.Position - rb.Position).Magnitude <= Tuning.RADIUS
end

-- The player's party members, themselves included ({ player } when solo).
function Party.members(player: Player): { Player }
	local party = partyOf[player]
	return if party then table.clone(party.members) else { player }
end

function Party.sameParty(a: Player, b: Player): boolean
	return partyOf[a] ~= nil and partyOf[a] == partyOf[b]
end

--[[ State pushes ]]

local function healthShare(player: Player): number
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.MaxHealth <= 0 then
		return 0
	end
	return math.floor(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) * 20 + 0.5) / 20 -- 5% steps
end

-- What `viewer` sees of their party: members in join order.
local function snapshot(party: PartyT, viewer: Player)
	local members = {}
	for _, member in party.members do
		table.insert(members, {
			userId = member.UserId,
			name = Party.nameOf(member),
			realm = member:GetAttribute("Realm"),
			health = healthShare(member),
			leader = member == party.leader,
			near = member == viewer or near(member, viewer),
			self = member == viewer,
		})
	end
	return { id = party.id, leader = party.leader.UserId, size = #party.members, max = Tuning.MAX_SIZE, members = members }
end

local function signature(snap: any): string
	local parts = { snap.id, tostring(snap.leader) }
	for _, m in snap.members do
		table.insert(parts, `{m.userId}:{m.name}:{m.realm}:{m.health}:{m.near}`)
	end
	return table.concat(parts, "|")
end

local function push(player: Player, force: boolean?)
	local party = partyOf[player]
	if not party then
		if force or lastSent[player] ~= nil then
			lastSent[player] = nil
			stateRemote:FireClient(player, "party", nil)
		end
		return
	end
	local snap = snapshot(party, player)
	local sig = signature(snap)
	if force or lastSent[player] ~= sig then
		lastSent[player] = sig
		stateRemote:FireClient(player, "party", snap)
	end
end

local function pushAll(party: PartyT)
	for _, member in party.members do
		push(member, true)
	end
end

local function inviteView(from: Player, expires: number)
	return {
		from = from.UserId,
		name = Party.nameOf(from),
		realm = from:GetAttribute("Realm"),
		partySize = if partyOf[from] then #(partyOf[from] :: PartyT).members else 1,
		expires = workspace:GetServerTimeNow() + math.max(0, expires - os.clock()),
	}
end

--[[ Membership ]]

local function dropInvite(invitee: Player, inviter: Player, reason: string)
	local mine = invites[invitee]
	if mine and mine[inviter] then
		mine[inviter] = nil
		stateRemote:FireClient(invitee, "inviteGone", inviter.UserId, reason)
	end
end

local function remove(player: Player, why: "left" | "kicked" | "gone")
	local party = partyOf[player]
	if not party then
		return
	end
	partyOf[player] = nil
	player:SetAttribute("Party", nil)
	local index = table.find(party.members, player)
	if index then
		table.remove(party.members, index)
	end
	if why ~= "gone" then
		push(player, true)
	end
	if why == "kicked" then
		notify(player, "You were removed from the party.")
	end
	if #party.members == 1 then
		local last = party.members[1]
		partyOf[last] = nil
		last:SetAttribute("Party", nil)
		push(last, true)
		notify(last, "Your party has disbanded.")
		return
	end
	local name = Party.nameOf(player)
	if party.leader == player then
		party.leader = party.members[1]
		for _, member in party.members do
			notify(member, `{name} left. {Party.nameOf(party.leader)} now leads the party.`)
		end
	else
		for _, member in party.members do
			notify(member, if why == "kicked" then `{name} was removed from the party.` else `{name} left the party.`)
		end
	end
	pushAll(party)
end

local function invite(player: Player, target: Player?): (boolean, any)
	if not target or target == player then
		return false, "They're not on this mountain."
	end
	local party = partyOf[player]
	if party and party.leader ~= player then
		return false, "Only the party's leader can invite."
	end
	if party and #party.members >= Tuning.MAX_SIZE then
		return false, `Your party is full ({Tuning.MAX_SIZE}).`
	end
	if partyOf[target] then
		return false, if Party.sameParty(player, target) then `{Party.nameOf(target)} is already with you.` else `{Party.nameOf(target)} is already in a party.`
	end
	local now = os.clock()
	if now - (lastInvite[player] or -math.huge) < Tuning.INVITE_COOLDOWN then
		return false, "Wait a moment before inviting again."
	end
	lastInvite[player] = now
	invites[target] = invites[target] or {}
	local expires = now + Tuning.INVITE_SECONDS;
	(invites[target] :: { [Player]: number })[player] = expires
	stateRemote:FireClient(target, "invite", inviteView(player, expires))
	return true, `Invited {Party.nameOf(target)}.`
end

local function accept(player: Player, inviter: Player?): (boolean, any)
	local mine = invites[player]
	local expires = inviter and mine and mine[inviter]
	if not inviter or not expires or expires < os.clock() then
		if inviter then
			dropInvite(player, inviter, "expired")
		end
		return false, "That invitation has lapsed."
	end
	if partyOf[player] then
		return false, "Leave your party first."
	end
	local party = partyOf[inviter]
	if party and party.leader ~= inviter then
		dropInvite(player, inviter, "withdrawn")
		return false, `{Party.nameOf(inviter)} no longer leads a party.`
	end
	if party and #party.members >= Tuning.MAX_SIZE then
		dropInvite(player, inviter, "withdrawn")
		return false, "That party is full."
	end
	local formed = party == nil
	if not party then
		nextId += 1
		local fresh: PartyT = { id = `P{nextId}`, leader = inviter, members = { inviter } }
		partyOf[inviter] = fresh
		inviter:SetAttribute("Party", fresh.id)
		party = fresh
	end
	local p = party :: PartyT
	table.insert(p.members, player)
	partyOf[player] = p
	player:SetAttribute("Party", p.id)
	-- every other invite this player held is answered by joining
	for from in table.clone(mine :: { [Player]: number }) do
		dropInvite(player, from, "answered")
	end
	local name = Party.nameOf(player)
	for _, member in p.members do
		if member ~= player then
			notify(member, `{name} joined the party.`)
		end
	end
	if #p.members >= Tuning.MAX_SIZE then
		-- a full party withdraws its leader's other invites
		for invitee, from in invites do
			if from[p.leader] then
				dropInvite(invitee, p.leader, "withdrawn")
			end
		end
	end
	pushAll(p)
	-- PartyFormed: the party's size, "new" (two players started one) or "joined"
	Analytics.event(p.leader, "PartyFormed", #p.members, if formed then "new" else "joined")
	return true, snapshot(p, player)
end

local function decline(player: Player, inviter: Player?): (boolean, any)
	if inviter and invites[player] and (invites[player] :: { [Player]: number })[inviter] then
		dropInvite(player, inviter, "answered")
		notify(inviter, `{Party.nameOf(player)} declined your invitation.`)
	end
	return true, nil
end

local function leaderAct(player: Player, target: Player?, act: "kick" | "promote"): (boolean, any)
	local party = partyOf[player]
	if not party then
		return false, "You're not in a party."
	end
	if party.leader ~= player then
		return false, "Only the party's leader can do that."
	end
	if not target or target == player or partyOf[target] ~= party then
		return false, "They're not in your party."
	end
	if act == "kick" then
		remove(target, "kicked")
	else
		party.leader = target
		for _, member in party.members do
			notify(member, `{Party.nameOf(target)} now leads the party.`)
		end
		pushAll(party)
	end
	return true, nil
end

--[[ The player card and the people list ]]

local function raceInfo(player: Player): (string?, string?, string?)
	local race = player:GetAttribute("Race")
	local variant = player:GetAttribute("RaceVariant")
	if type(race) ~= "string" then
		return nil, nil, nil
	end
	local def = (Races :: any)[race]
	local raceName = def and def.DisplayName or race
	local variantName = nil
	if type(variant) == "string" and def and type(def.Variants) == "string" then
		local folder = ReplicatedStorage.Shared.Identity:FindFirstChild("Variants")
		local module = folder and folder:FindFirstChild(def.Variants)
		local ok, list = pcall(require, module :: ModuleScript)
		local v = ok and type(list) == "table" and (list :: any)[variant]
		variantName = if v then v.DisplayName else variant
	end
	return race, raceName, variantName
end

-- Whether a and b are Roblox friends (asked once per pair; yields the first time).
local function isFriend(a: Player, b: Player): boolean
	local known = friends[a] and (friends[a] :: { [Player]: boolean })[b]
	if known ~= nil then
		return known
	end
	local ok, yes = pcall(a.IsFriendsWith, a, b.UserId)
	local answer = ok and yes == true
	friends[a] = friends[a] or {};
	(friends[a] :: { [Player]: boolean })[b] = answer
	friends[b] = friends[b] or {};
	(friends[b] :: { [Player]: boolean })[a] = answer
	return answer
end

-- A player's public card, as `viewer` sees it (docs/systems/party.md#player-card).
function Party.card(viewer: Player, other: Player): any
	local data = PlayerData.get(other)
	local viewerData = PlayerData.get(viewer)
	local stage = data and Realms.get(data.realm.major, data.realm.minor)
	local race, raceName, variantName = raceInfo(other)
	local theirs, mine = partyOf[other], partyOf[viewer]
	local isSelf = viewer == other
	local same = theirs ~= nil and theirs == mine
	local peak = Peaks.ownedBy(other)
	local canTravel = viewerData ~= nil and Quests.travelUnlocked(viewerData)
	return {
		userId = other.UserId,
		name = Party.nameOf(other),
		displayName = other.DisplayName,
		username = other.Name,
		realm = stage and stage.name or other:GetAttribute("Realm"),
		major = data and data.realm.major,
		minor = data and data.realm.minor,
		race = race,
		raceName = raceName,
		variant = other:GetAttribute("RaceVariant"),
		variantName = variantName,
		bloodline = nil, -- "None" until bloodlines are built
		hall = nil, -- no Halls yet
		friend = not isSelf and isFriend(viewer, other),
		self = isSelf,
		party = {
			inParty = theirs ~= nil,
			size = if theirs then #theirs.members else 0,
			leader = theirs ~= nil and theirs.leader == other,
			withYou = same,
		},
		canInvite = not isSelf and theirs == nil and (mine == nil or (mine.leader == viewer and #mine.members < Tuning.MAX_SIZE)),
		invitedYou = invites[viewer] ~= nil and (invites[viewer] :: { [Player]: number })[other] ~= nil,
		canKick = same and not isSelf and mine ~= nil and mine.leader == viewer,
		canJoin = same and not isSelf and canTravel,
		canVisit = not isSelf and peak ~= nil and canTravel,
	}
end

-- Everyone else in the server for the People list: friends first, then by name.
function Party.people(viewer: Player): { any }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= viewer and PlayerData.get(other) then
			local _, raceName = raceInfo(other)
			table.insert(list, {
				userId = other.UserId,
				name = Party.nameOf(other),
				realm = other:GetAttribute("Realm"),
				raceName = raceName,
				friend = isFriend(viewer, other),
				withYou = Party.sameParty(viewer, other),
				inParty = partyOf[other] ~= nil,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.friend ~= b.friend then
			return a.friend
		end
		return a.name < b.name
	end)
	return list
end

--[[ Remote ]]

function Party.handle(player: Player, action: any, arg: any): (boolean, any)
	if not PlayerData.get(player) then
		return false, "Still loading"
	end
	if action == "state" then
		local list = {}
		for from, expires in invites[player] or {} do
			if expires >= os.clock() then
				table.insert(list, inviteView(from, expires))
			end
		end
		local party = partyOf[player]
		return true, { party = party and snapshot(party, player), invites = list }
	elseif action == "invite" then
		return invite(player, byId(arg))
	elseif action == "accept" then
		return accept(player, byId(arg))
	elseif action == "decline" then
		return decline(player, byId(arg))
	elseif action == "leave" then
		if not partyOf[player] then
			return false, "You're not in a party."
		end
		remove(player, "left")
		return true, nil
	elseif action == "kick" then
		return leaderAct(player, byId(arg), "kick")
	elseif action == "promote" then
		return leaderAct(player, byId(arg), "promote")
	elseif action == "card" then
		local other = byId(arg)
		if not other or not PlayerData.get(other) then
			return false, "They're not on this mountain."
		end
		return true, Party.card(player, other)
	elseif action == "people" then
		return true, Party.people(player)
	elseif action == "join" then
		local other = byId(arg)
		if not other or not Party.sameParty(player, other) then
			return false, "You can only join a member of your party."
		end
		return Travel.toPlayer(player, other, "join")
	elseif action == "visit" then
		local other = byId(arg)
		if not other then
			return false, "They're not on this mountain."
		end
		return Travel.toPlayer(player, other, "visit")
	end
	return false, "Unknown party action"
end

--[[ Lifecycle ]]

-- Once the player's profile has loaded: tell them and their friends here that the
-- other is on the mountain, once per session per friend.
function Party.entered(player: Player)
	nudged[player] = nudged[player] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player and PlayerData.get(other) and isFriend(player, other) then
			for _, pair in { { player, other }, { other, player } } do
				local to, about = pair[1], pair[2]
				local seen = nudged[to]
				if seen and not seen[about.UserId] then
					seen[about.UserId] = true
					stateRemote:FireClient(to, "friendHere", { userId = about.UserId, name = Party.nameOf(about) })
				end
			end
		end
	end
end

function Party.forget(player: Player)
	remove(player, "gone")
	for invitee, from in invites do
		if from[player] then
			dropInvite(invitee, player, "withdrawn")
		end
	end
	invites[player] = nil
	lastInvite[player] = nil
	lastSent[player] = nil
	nudged[player] = nil
	friends[player] = nil
	for _, known in friends do
		known[player] = nil
	end
end

-- Expire invites, count time spent together, and re-send members' health and nearness.
local function tick(elapsed: number)
	local now = os.clock()
	for invitee, from in invites do
		for inviter, expires in table.clone(from) do
			if expires < now then
				dropInvite(invitee, inviter, "expired")
			end
		end
	end
	for player, party in partyOf do
		local data = PlayerData.get(player)
		if data then
			for _, member in party.members do
				if member ~= player and near(player, member) then
					data.stats.partied = (data.stats.partied or 0) + elapsed
					break
				end
			end
		end
		push(player)
	end
end

function Party.start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Tuning.PUSH_SECONDS)
			local now = os.clock()
			tick(now - last)
			last = now
		end
	end)
end

return Party
