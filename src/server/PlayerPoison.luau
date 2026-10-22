--!strict
-- Poison on players (the Jade Jiao's bite, bolts and pools). Server authority.
-- Each stack (at most MAX_STACKS) costs SHARE of max health every second until the
-- poison runs out (`seconds` after the last application; re-applying adds a stack and
-- refreshes it). It never kills (Combat.dot leaves 1 HP), ignores dodges and doesn't
-- flinch. Ends on death or when the character goes. There is no cure yet.
--
-- Character attributes, for PoisonFX: PoisonStacks, PoisonUntil (server time).

local Players = game:GetService("Players")

local Combat = require(script.Parent.Combat)

local MAX_STACKS = 3
local SHARE = 0.012 -- of max health, per stack per second
local TICK = 1

type State = { stacks: number, untilAt: number, source: string, character: Model }

local PlayerPoison = {}

local states: { [Player]: State } = {}
local running = false

local function show(player: Player, state: State?)
	local character = player.Character
	if character then
		character:SetAttribute("PoisonStacks", if state then state.stacks else nil)
		character:SetAttribute("PoisonUntil", if state then state.untilAt else nil)
	end
end

local function clear(player: Player)
	states[player] = nil
	show(player, nil)
end

local function loop()
	running = true
	while next(states) do
		task.wait(TICK)
		local now = workspace:GetServerTimeNow()
		for player, state in states do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 or character ~= state.character or now >= state.untilAt then
				clear(player)
			else
				Combat.dot(player, state.stacks * SHARE * humanoid.MaxHealth, state.source)
			end
		end
	end
	running = false
end

-- Add `stacks` of poison (capped) and refresh it to last `seconds`.
function PlayerPoison.apply(player: Player, stacks: number, seconds: number, source: string?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	local state = states[player]
	if state and now >= state.untilAt then
		state = nil
	end
	local new: State = {
		stacks = math.min(MAX_STACKS, (if state then state.stacks else 0) + stacks),
		untilAt = math.max(now + seconds, if state then state.untilAt else 0),
		source = source or "Poison",
		character = character :: Model,
	}
	states[player] = new
	show(player, new)
	if not running then
		task.spawn(loop)
	end
end

function PlayerPoison.clear(player: Player)
	clear(player)
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

return PlayerPoison
