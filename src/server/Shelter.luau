--!strict
-- The party shelter (docs/systems/combat.md "Realm pressure", Pacing.Shelter): a
-- player in a party with a member of a higher major realm nearby fights that member's
-- beasts fairly. Realm suppression (Realms.suppression) is applied through here:
-- Combat.damageEnemy (Shelter.hit), EnemyService's hurtBy and PlayerPoison
-- (Shelter.hurt). The check is live on every hit, so leaving the party or the radius
-- ends it at once. Player attribute `ShelteredBy`: the patron's UserId while one is
-- near (refreshed every TICK), for the qi thread (ShelterFX) and the bars' tiers.
-- Player attribute `Suppressed`: the major gap while the player trades blows with a
-- beast of a higher major unsheltered (set on each such hit or blow here, cleared
-- SUPPRESSED_HOLD after the last), for the HUD's Suppressed status chip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Realms = require(ReplicatedStorage.Shared.Realms)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Tuning = Pacing.Shelter
local RADIUS = Pacing.Party.RADIUS
local PlayerData = require(script.Parent.PlayerData)
local Cultivation = require(script.Parent.Cultivation)

local Shelter = {}

-- Called (patron, patron's data, junior, junior's data) for each kill Shelter.credit
-- credits; Main wires Sect.onShelter (the patron's sect contribution, bonus quests).
Shelter.onCredit = {} :: { (Player, PlayerData.Data, Player, PlayerData.Data) -> () }

local lastSuppressed: { [Player]: number } = {} -- os.clock() of the last unsheltered upward hit or blow

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0) then
		return nil
	end
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
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

-- A hit or blow with a beast of a higher major, unsheltered: the Suppressed status.
local function markSuppressed(player: Player, data: PlayerData.Data, beast: Realms.Stage)
	local gap = Realms.majorIndex(beast.major) - Realms.majorIndex(data.realm.major)
	if gap <= 0 then
		return
	end
	lastSuppressed[player] = os.clock()
	if player:GetAttribute("Suppressed") ~= gap then
		player:SetAttribute("Suppressed", gap)
	end
end

-- The multiplier on the player's hit on a beast of `beast`'s stage: realm suppression,
-- or the shelter's sync when that is better.
function Shelter.hit(player: Player, data: PlayerData.Data, beast: Realms.Stage): number
	local defier = Cultivation.heavenDefying(data)
	local plain = Realms.suppression(data.realm.major, beast.major, defier)
	local patron, sync = syncFor(player, data, beast)
	if not (patron and sync) then
		markSuppressed(player, data, beast)
		return plain
	end
	local own = Cultivation.fightStage(player, data)
	local sheltered = Realms.suppression(sync.major, beast.major, defier) * Tuning.HIT * sync.power / own.power
	return math.max(plain, sheltered)
end

-- The multiplier on a beast's blow (or poison tick) of `beast`'s stage on the player:
-- realm suppression, scaled down while sheltered, never above it.
function Shelter.hurt(player: Player, data: PlayerData.Data, beast: Realms.Stage): number
	local plain = Realms.suppression(beast.major, data.realm.major)
	local patron, sync = syncFor(player, data, beast)
	if not (patron and sync) then
		markSuppressed(player, data, beast)
		return plain
	end
	local scale = math.min(1, Tuning.HURT * Cultivation.stage(data).health / sync.health)
	return plain * scale
end

-- The patron who sheltered the player's credited kill of a beast of `beast`'s stage
-- (counted on both sides: stats.sheltered for the patron, stats.leaned for the player),
-- or nil. EnemyService pays the patron's share (SENIOR_QI_SHARE); onCredit hooks the rest.
function Shelter.credit(player: Player, data: PlayerData.Data, beast: Realms.Stage): Player?
	local patron = syncFor(player, data, beast)
	local pd = patron and PlayerData.get(patron)
	if not (patron and pd) then
		return nil
	end
	data.stats.leaned = (data.stats.leaned or 0) + 1
	pd.stats.sheltered = (pd.stats.sheltered or 0) + 1
	for _, fn in Shelter.onCredit do
		task.spawn(fn, patron, pd, player, data)
	end
	return patron
end

function Shelter.forget(player: Player)
	lastSuppressed[player] = nil
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
				-- the Suppressed status lapses a few seconds after the last such hit,
				-- or at once when a shelter lifts it
				local last = lastSuppressed[player]
				if last and (patron or os.clock() - last > Tuning.SUPPRESSED_HOLD) then
					lastSuppressed[player] = nil
					player:SetAttribute("Suppressed", nil)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(Shelter.forget)
end

return Shelter
