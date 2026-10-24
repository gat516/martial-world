--!strict
-- The party shelter (docs/systems/combat.md "Realm pressure", Pacing.Shelter): a
-- player in a party with a member of a higher major realm nearby fights that member's
-- beasts fairly. Realm suppression (Realms.suppression) is applied through here:
-- Combat.damageEnemy (Shelter.hit), EnemyService's hurtBy and PlayerPoison
-- (Shelter.hurt). The check is live on every hit, so leaving the party or the radius
-- ends it at once. Player attribute `ShelteredBy`: the patron's UserId while one is
-- near (refreshed every TICK), for the enemy bars and the qi thread (ShelterFX).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Realms = require(ReplicatedStorage.Shared.Realms)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Tuning = Pacing.Shelter
local RADIUS = Pacing.Party.RADIUS
local PlayerData = require(script.Parent.PlayerData)
local Cultivation = require(script.Parent.Cultivation)

local Shelter = {}

local lastCue: { [Player]: number } = {} -- os.clock() of the last sheltered hit or blow

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0) then
		return nil
	end
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function nameOf(player: Player): string
	local first, last = player:GetAttribute("FirstName"), player:GetAttribute("Surname")
	if type(first) == "string" and first ~= "" then
		return if type(last) == "string" and last ~= "" then `{first} {last}` else first
	end
	return player.DisplayName
end

-- The strongest party member within RADIUS whose major realm is above the player's,
-- and their stage; nil when there is none (solo, alone, or nobody of a higher major).
function Shelter.patron(player: Player, data: PlayerData.Data?): (Player?, Realms.Stage?)
	local party = player:GetAttribute("Party")
	local root = rootOf(player)
	data = data or PlayerData.get(player)
	if party == nil or not root or not data then
		return nil, nil
	end
	local mine = Realms.majorIndex(data.realm.major)
	local best, bestStage, bestIndex = nil, nil, 0
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("Party") == party then
			local od = PlayerData.get(other)
			local oroot = rootOf(other)
			if od and oroot and Realms.majorIndex(od.realm.major) > mine
				and (oroot.Position - root.Position).Magnitude <= RADIUS
			then
				local index = Realms.index(od.realm.major, od.realm.minor)
				if index > bestIndex then
					best, bestStage, bestIndex = other, Realms.Stages[index], index
				end
			end
		end
	end
	return best, bestStage
end

-- The patron and the stage the player fights `beast` at: the beast's own, capped at
-- the patron's. Nil unless sheltered and the beast is above the player's major.
local function syncFor(player: Player, data: PlayerData.Data, beast: Realms.Stage): (Player?, Realms.Stage?)
	if Realms.majorIndex(beast.major) <= Realms.majorIndex(data.realm.major) then
		return nil, nil
	end
	local patron, stage = Shelter.patron(player, data)
	if not (patron and stage) then
		return nil, nil
	end
	local sync = if Realms.index(beast.major, beast.minor) <= Realms.index(stage.major, stage.minor) then beast else stage
	return patron, sync
end

-- Once per engagement (CUE_GAP without a sheltered hit or blow): the feed line.
local function cue(player: Player, patron: Player)
	local now = os.clock()
	local last = lastCue[player]
	lastCue[player] = now
	if not last or now - last > Tuning.CUE_GAP then
		Cultivation.notify(player, `Sheltered by {nameOf(patron)}: you fight at their side as an equal.`)
	end
end

-- The multiplier on the player's hit on a beast of `beast`'s stage: realm suppression,
-- or the shelter's sync when that is better.
function Shelter.hit(player: Player, data: PlayerData.Data, beast: Realms.Stage): number
	local defier = Cultivation.heavenDefying(data)
	local plain = Realms.suppression(data.realm.major, beast.major, defier)
	local patron, sync = syncFor(player, data, beast)
	if not (patron and sync) then
		return plain
	end
	local own = Cultivation.fightStage(player, data)
	local sheltered = Realms.suppression(sync.major, beast.major, defier) * Tuning.HIT * sync.power / own.power
	if sheltered <= plain then
		return plain
	end
	cue(player, patron)
	return sheltered
end

-- The multiplier on a beast's blow (or poison tick) of `beast`'s stage on the player:
-- realm suppression, scaled down while sheltered, never above it.
function Shelter.hurt(player: Player, data: PlayerData.Data, beast: Realms.Stage): number
	local plain = Realms.suppression(beast.major, data.realm.major)
	local patron, sync = syncFor(player, data, beast)
	if not (patron and sync) then
		return plain
	end
	local scale = math.min(1, Tuning.HURT * Cultivation.stage(data).health / sync.health)
	if scale < 1 then
		cue(player, patron)
	end
	return plain * scale
end

-- The patron who sheltered the player's credited kill of a beast of `beast`'s stage
-- (counted on both sides: stats.sheltered for the patron, stats.leaned for the player),
-- or nil. EnemyService pays the patron's share (SENIOR_QI_SHARE).
function Shelter.credit(player: Player, data: PlayerData.Data, beast: Realms.Stage): Player?
	local patron = syncFor(player, data, beast)
	local pd = patron and PlayerData.get(patron)
	if not (patron and pd) then
		return nil
	end
	data.stats.leaned = (data.stats.leaned or 0) + 1
	pd.stats.sheltered = (pd.stats.sheltered or 0) + 1
	return patron
end

function Shelter.forget(player: Player)
	lastCue[player] = nil
end

function Shelter.start()
	task.spawn(function()
		while true do
			task.wait(Tuning.TICK)
			for _, player in Players:GetPlayers() do
				local patron = Shelter.patron(player)
				local id = if patron then patron.UserId else nil
				if player:GetAttribute("ShelteredBy") ~= id then
					player:SetAttribute("ShelteredBy", id)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(Shelter.forget)
end

return Shelter
