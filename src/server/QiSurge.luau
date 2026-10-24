--!strict
-- The qi surge (docs/systems/cultivation.md "Qi surge"; tuning Pacing.Surge): the
-- clutch comeback that replaced the forced breakthrough. In a fight, badly hurt
-- (Pacing.Breakthrough.FORCE_HEALTH_SHARE) with the realm bar nearly full
-- (FORCE_BAR_SHARE), the player can surge: for Pacing.Surge.SECONDS they fight at the
-- next stage's health and power (Cultivation.fightStage), healed HEAL_SHARE of the
-- raised max health, and it burns RAW_QI_SHARE of the raw qi in the dantian. Not
-- seated, not in a tribulation, not at the peak stage; once per combat engagement
-- (until the InCombat tag drops) when ONCE_PER_COMBAT. Nothing is kept: the stage,
-- bar and foundation don't move.
-- Attributes on the player: SurgeReady (the client's M key and surge pill),
-- SurgeUntil (server time it ends; every client plays the burst on it) and
-- SurgeRealm (the stage shown on the realm plaque while it lasts).
-- Fired with CultivationAction "surge" (Circulation.handle -> Cultivation.surge).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)
local Tribulation = require(script.Parent.Tribulation)

local TICK = 0.2 -- seconds between ready checks

type State = {
	untilClock: number, -- os.clock() the surge ends, 0 when not surging
	used: boolean, -- surged this engagement (cleared when the InCombat tag drops)
	fallBack: boolean, -- owes the "falls back" toast once the surge is over and the tag drops
}
local states: { [Player]: State } = {}

local QiSurge = {}

local function state(player: Player): State
	local s = states[player]
	if not s then
		s = { untilClock = 0, used = false, fallBack = false }
		states[player] = s
	end
	return s
end

local function humanoidOf(player: Player): Humanoid?
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end

local function surging(s: State?): boolean
	return s ~= nil and os.clock() < s.untilClock
end

function QiSurge.surging(player: Player): boolean
	return surging(states[player])
end

Cultivation.surgeStage = function(player: Player): Realms.Stage?
	if not surging(states[player]) then
		return nil
	end
	local data = PlayerData.get(player)
	if not data then
		return nil
	end
	local stage = Cultivation.stage(data)
	return Realms.after(stage.major, stage.minor)
end

-- Why the surge can't fire right now, or nil when it's ready.
local function blocked(player: Player, data: PlayerData.Data, s: State): string?
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return "You can't gather your qi now."
	end
	if surging(s) then
		return "Your qi is already surging."
	end
	if player:GetAttribute("InCombat") ~= true then
		return "Your qi only surges in a fight."
	end
	if s.used and Pacing.Surge.ONCE_PER_COMBAT then
		return "Your qi has already surged this fight."
	end
	if Cultivation.meditation and Cultivation.meditation(player) then
		return "Rise first."
	end
	if Tribulation.isActive(player) then
		return "The heavens are watching. Your qi won't answer."
	end
	local stage = Cultivation.stage(data)
	if not Realms.after(stage.major, stage.minor) then
		return "You stand at the peak of this world's cultivation, for now."
	end
	if humanoid.Health > humanoid.MaxHealth * Pacing.Breakthrough.FORCE_HEALTH_SHARE then
		return "Your qi surges only when you're badly hurt."
	end
	if data.cultivation < stage.bar * Pacing.Breakthrough.FORCE_BAR_SHARE then
		return "Your realm bar isn't full enough to surge."
	end
	return nil
end

local function setAttribute(player: Player, name: string, value: any)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

-- End the surge: back to the player's own stage. `quiet` skips the toast (death,
-- breakthrough, leaving).
local function finish(player: Player, s: State, quiet: boolean)
	if s.untilClock == 0 then
		return
	end
	s.untilClock = 0
	s.fallBack = not quiet
	setAttribute(player, "SurgeUntil", nil)
	setAttribute(player, "SurgeRealm", nil)
	local data = PlayerData.get(player)
	if data and player.Parent then
		Cultivation.applyStats(player, data) -- keeps the health fraction
		Cultivation.pushState(player)
	end
end

-- CultivationAction "surge".
function QiSurge.fire(player: Player): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading"
	end
	local s = state(player)
	local why = blocked(player, data, s)
	if why then
		return false, why
	end
	local cost = math.floor(data.rawQi * Pacing.Surge.RAW_QI_SHARE)
	data.rawQi -= cost
	s.used = true
	s.fallBack = false
	data.stats.surges += 1 -- the heart-demon trial asks what it cost
	s.untilClock = os.clock() + Pacing.Surge.SECONDS
	local nextStage = Cultivation.surgeStage and Cultivation.surgeStage(player)
	setAttribute(player, "SurgeReady", false)
	setAttribute(player, "SurgeRealm", if nextStage then nextStage.name else nil)
	setAttribute(player, "SurgeUntil", workspace:GetServerTimeNow() + Pacing.Surge.SECONDS)
	Cultivation.applyStats(player, data) -- max health rises, the fraction is kept
	local humanoid = humanoidOf(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * Pacing.Surge.HEAL_SHARE)
	end
	Cultivation.markActive(player)
	Cultivation.pushState(player)
	local spent = if cost > 0 then ` (-{cost} raw qi)` else ""
	Cultivation.notify(player, `Your qi surges to {if nextStage then nextStage.name else "a higher stage"}!{spent}`)
	return true, nil
end
Cultivation.surge = QiSurge.fire

-- A breakthrough moves the real stage on: any surge is over.
table.insert(Cultivation.onBreakthrough, function(player: Player)
	local s = states[player]
	if s then
		finish(player, s, true)
	end
end)

function QiSurge.forget(player: Player)
	states[player] = nil
end

task.spawn(function()
	while true do
		task.wait(TICK)
		for _, player in Players:GetPlayers() do
			local data = PlayerData.get(player)
			if data then
				local s = state(player)
				local humanoid = humanoidOf(player)
				if s.untilClock > 0 and (not humanoid or humanoid.Health <= 0) then
					finish(player, s, true) -- died while surging
				elseif s.untilClock > 0 and not surging(s) then
					finish(player, s, false)
				end
				if player:GetAttribute("InCombat") ~= true and not surging(s) then
					if s.fallBack then
						s.fallBack = false
						Cultivation.notify(player, "Your cultivation falls back.")
					end
					s.used = false
				end
				setAttribute(player, "SurgeReady", blocked(player, data, s) == nil)
			end
		end
	end
end)

return QiSurge
