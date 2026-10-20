--!strict
-- Wraps Roblox AnalyticsService: the onboarding funnel (one step per beat) and the
-- custom events the playtest is judged on. Every call is pcall'd; analytics must
-- never break gameplay.
--
-- Funnel: 1 Joined, 2 First circulation, 3 First breakthrough, 4 Reached gate,
-- 5 First kill, 6 First technique slotted, 7 Refined at a node/peak, 8 QC3.
-- Custom events: CirculationScore (0-100), Breakthrough (seconds since the last
-- one, field: realm), TribulationResult (1/0), Death (field: what killed them),
-- OfflineQiClaimed, SessionLength (seconds).

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
