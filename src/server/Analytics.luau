--!strict
-- Wraps Roblox AnalyticsService: the onboarding funnel (one step per beat) and the
-- custom events the playtest is judged on. Every call is pcall'd; analytics must
-- never break gameplay.
--
-- Funnel (Quests.Beats positions + 1): 1 Joined, 2 First circulation, 3 First
-- breakthrough, 4 First kill, 5 First technique earned, 6 First technique cast,
-- 7 Haul stored, 8 Refined at a node/peak, 9 QC3, 10 Root tested, 11 QC4.
-- Custom events: CirculationScore (0-100), Breakthrough (seconds since the last
-- one, field: realm), TribulationResult (1/0), Death (field: what killed them),
-- OfflineQiClaimed, SessionLength (seconds).
--
-- Realm progression (path "Realm", level = Realms stage index, name = stage
-- name): Start when a player enters a stage (stage 1 on their first join),
-- Complete when they break out of it, Fail when a tribulation guarding it beats
-- them. In the Creator Dashboard's Progression view, the drop between a level's
-- starts and completes is the stage's dropoff; tune it in Pacing.Adjust.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

local FUNNEL_NAMES = {
	"Joined",
	"First circulation",
	"First breakthrough",
	"First kill",
	"First technique earned",
	"First technique cast",
	"Haul stored",
	"Refined qi",
	"QC3",
	"Root tested",
	"QC4",
}

function Analytics.funnel(player: Player, step: number)
	local name = FUNNEL_NAMES[step]
	if not name then
		return
	end
	local ok, err = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
	if not ok then
		warn(`Analytics: funnel {step} failed: {err}`)
	end
end

-- status: "start" | "complete" | "fail"
function Analytics.progression(player: Player, status: string, level: number, levelName: string)
	local ok, err = pcall(function()
		if status == "start" then
			AnalyticsService:LogProgressionStartEvent(player, "Realm", level, levelName)
		elseif status == "complete" then
			AnalyticsService:LogProgressionCompleteEvent(player, "Realm", level, levelName)
		elseif status == "fail" then
			AnalyticsService:LogProgressionFailEvent(player, "Realm", level, levelName)
		end
	end)
	if not ok then
		warn(`Analytics: progression {status} {level} failed: {err}`)
	end
end

function Analytics.event(player: Player, name: string, value: number, field: string?)
	local ok, err = pcall(function()
		if field then
			AnalyticsService:LogCustomEvent(player, name, value, {
				[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = field,
			})
		else
			AnalyticsService:LogCustomEvent(player, name, value)
		end
	end)
	if not ok then
		warn(`Analytics: {name} failed: {err}`)
	end
end

return Analytics
