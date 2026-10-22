--!strict
-- Slow on players (an attack's `slow` and slow `patch`; no beast uses it since the Frost
-- Spider was cut). Server authority. A slow
-- scales walking speed by `factor` until it expires (re-applying refreshes it and keeps the
-- stronger factor; it never stacks, never roots, and a dodge or dash skill ignores it since
-- those move the character by impulses, not by WalkSpeed). Humanoid attributes, read by
-- Movement (server and client) and by the effects:
--   SlowMove   walk speed share (1 = none)
--   SlowUntil  server time the slow ends

local Players = game:GetService("Players")

local Movement = require(script.Parent.Movement)

local PlayerSlow = {}

type State = { untilAt: number, factor: number, character: Model }
local states: { [Player]: State } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function clear(player: Player)
	states[player] = nil
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid:SetAttribute("SlowMove", nil)
		humanoid:SetAttribute("SlowUntil", nil)
		Movement.apply(humanoid)
	end
end

-- Slow `player` to `factor` of their walk speed for `seconds`.
function PlayerSlow.apply(player: Player, factor: number, seconds: number)
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	local state = states[player]
	if state and (now >= state.untilAt or state.character ~= player.Character) then
		state = nil
	end
	local new: State = {
		untilAt = math.max(now + seconds, if state then state.untilAt else 0),
		factor = math.min(factor, if state then state.factor else 1),
		character = player.Character :: Model,
	}
	states[player] = new
	humanoid:SetAttribute("SlowMove", new.factor)
	humanoid:SetAttribute("SlowUntil", new.untilAt)
	Movement.apply(humanoid)
	task.delay(new.untilAt - now + 0.05, function()
		local current = states[player]
		if current == new and workspace:GetServerTimeNow() >= new.untilAt then
			clear(player)
		end
	end)
end

function PlayerSlow.active(player: Player): boolean
	local state = states[player]
	return state ~= nil and workspace:GetServerTimeNow() < state.untilAt
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

return PlayerSlow
