--!strict
-- Practice Dao: a short seated drill with the equipped weapon for its class's
-- Dao XP (tuning: Pacing.DaoPractice; design: docs/systems/meditation.md). It
-- plays a circulation minigame through the same client runner, over
-- CultivationAction "practiceStart" / "practiceFinish" / "practiceCancel".
-- Scored like a circulation run; finishing starts the cooldown, leaving early
-- doesn't.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config).Circulation
local Pacing = require(ReplicatedStorage.Shared.Pacing).DaoPractice
local WeaponPacing = require(ReplicatedStorage.Shared.Pacing).Weapons
local Realms = require(ReplicatedStorage.Shared.Realms)
local WeaponDefs = require(ReplicatedStorage.Shared.Weapons)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)
local Weapons = require(script.Parent.Weapons)

type Run = { id: string, started: number, duration: number, impurities: number, class: string }

local runs: { [Player]: Run } = {}

local DaoPractice = {}

-- Why the player can't drill right now, or nil.
function DaoPractice.blocked(player: Player, data: PlayerData.Data): string?
	local from = Realms.ByKey[Pacing.FROM]
	if from and Realms.index(data.realm.major, data.realm.minor) < Realms.index(from.major, from.minor) then
		return `Reach {from.name} to practice your Dao.`
	end
	if not (Cultivation.meditation and Cultivation.meditation(player)) then
		return "Sit and meditate to practice."
	end
	local class = Weapons.class(player)
	if Weapons.level(data, class) >= WeaponPacing.MAX_LEVEL then
		return `Your {WeaponDefs.Classes[class].dao} is already mastered.`
	end
	local wait = data.daoPracticeReadyUnix - os.time()
	if wait > 0 then
		return `Rest your arms a while ({math.ceil(wait / 60)} min).`
	end
	return nil
end

function DaoPractice.start(player: Player): (boolean, any)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading"
	end
	local active = runs[player]
	if active and os.clock() - active.started < active.duration + Config.RUN_TIMEOUT_GRACE then
		return false, "You're already practicing"
	end
	local why = DaoPractice.blocked(player, data)
	if why then
		return false, why
	end
	local class = Weapons.class(player)
	local run = {
		id = HttpService:GenerateGUID(false),
		started = os.clock(),
		duration = Pacing.SECONDS,
		impurities = math.max(1, math.floor(Pacing.SECONDS / 10 * Config.IMPURITIES_PER_10S + 0.5)),
		class = class,
	}
	runs[player] = run
	return true,
		{
			id = run.id,
			game = Pacing.GAME,
			duration = run.duration,
			difficulty = Pacing.DIFFICULTY,
			impurities = run.impurities,
			seed = math.random(1, 1e6),
			title = `{WeaponDefs.Classes[class].name} Forms`,
		}
end

function DaoPractice.finish(player: Player, id: any, accuracy: any, purged: any): (boolean, any)
	local run = runs[player]
	local data = PlayerData.get(player)
	if not (run and data and run.id == id) then
		return false, "That drill has ended"
	end
	runs[player] = nil
	if os.clock() - run.started < run.duration * Config.MIN_DURATION_FRACTION then
		return false, "The drill ended too soon"
	end
	local acc = if type(accuracy) == "number" and accuracy == accuracy then math.clamp(accuracy, 0, 1) else 0
	local purgedShare = if type(purged) == "number" then math.clamp(math.floor(purged), 0, run.impurities) / run.impurities else 0
	local score = acc * Config.ACCURACY_WEIGHT + purgedShare * (1 - Config.ACCURACY_WEIGHT)
	local level = Weapons.level(data, run.class)
	local gain = math.max(1, math.floor(score * Pacing.XP_SHARE * WeaponDefs.xpToNext(level) + 0.5))
	data.daoPracticeReadyUnix = os.time() + Pacing.COOLDOWN
	Weapons.addXp(player, run.class, gain)
	Cultivation.markActive(player)
	Cultivation.pushState(player)
	return true, { score = score, gain = gain, dao = WeaponDefs.Classes[run.class].dao }
end

-- Leave a drill early: nothing gained, no cooldown.
function DaoPractice.cancel(player: Player, id: any): (boolean, any)
	local run = runs[player]
	if run and run.id == id then
		runs[player] = nil
	end
	return true, nil
end

function DaoPractice.forget(player: Player)
	runs[player] = nil
end

return DaoPractice
