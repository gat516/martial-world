--!strict
-- Wraps Roblox AnalyticsService: the onboarding funnel (one step per beat) and the
-- custom events the playtest is judged on. Every call is pcall'd; analytics must
-- never break gameplay.
--
-- Funnel: 1 Joined, 2 First circulation, 3 First breakthrough, 4 Reached gate,
-- 5 First kill, 6 First technique slotted, 7 Refined at a node/peak, 8 QC3.
-- Custom events: CirculationScore (0-100), Breakthrough (seconds since the last
-- one, field: realm), TribulationResult (1/0), Death (field: what killed them),
-- OfflineQiClaimed, SessionLength (seconds), InsightBlocked (stage index, field:
-- stage name; a full bar at a stage that still needs insight).
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
	"Reached gate",
	"First kill",
	"First technique slotted",
	"Refined qi",
	"QC3",
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
