--!strict
-- Poison on players (the Jade Jiao's bite, bolts and pools). Server authority.
-- Each stack (at most MAX_STACKS) costs SHARE of the poisoner's stage health (the
-- curve's health at its `realm`, so a beast's poison follows the curve like its blows)
-- every second, times realm suppression when the poisoner's major realm is below the
-- player's (Realms.suppression, as EnemyService hurtBy does for blows; eased by the
-- party shelter, Shelter.hurt), until the
-- poison runs out (`seconds` after the last application; re-applying adds a stack and
-- refreshes it). It never kills (Combat.dot leaves 1 HP), ignores dodges and doesn't
-- flinch. Ends on death or when the character goes. There is no cure yet.
--
-- Character attributes, for PoisonFX: PoisonStacks, PoisonUntil (server time).

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Realms = require(ReplicatedStorage.Shared.Realms)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local Shelter = require(script.Parent.Shelter)

local MAX_STACKS = 3
local SHARE = 0.012 -- of the poisoner's stage health, per stack per second
local TICK = 1

type State = { stacks: number, perStack: number, untilAt: number, source: string, character: Model }

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
				Combat.dot(player, state.stacks * state.perStack, state.source)
			end
		end
	end
	running = false
end

-- Add `stacks` of poison (capped) and refresh it to last `seconds`. `realm` is the
-- poisoner's Enemies `realm` ({ major, minor }); a stack's tick is the strongest
-- poisoner's while the poison runs.
function PlayerPoison.apply(player: Player, stacks: number, seconds: number, source: string?, realm: { any })
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
	local perStack = SHARE * Realms.ofBeast(realm).health
	local data = PlayerData.get(player)
	if data then
		perStack *= Shelter.hurt(player, data, Realms.ofBeast(realm))
	end
	local new: State = {
		perStack = math.max(perStack, if state then state.perStack else 0),
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
