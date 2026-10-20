--!strict
-- Basic attack hits, predicted by the client and checked here. The client swings,
-- casts its hitbox, shows the hit at once, and reports the swing's server-clock
-- timestamp (GetServerTimeNow) plus the enemies it hit. The server:
--   - rejects timestamps too old, from the future, or closer together than the
--     swing cooldown (so spam can't outpace the animation);
--   - works out the chain step itself from the timestamps, so damage can't be
--     inflated by always claiming the finisher;
--   - re-casts the hitbox (GetPartBoundsInBox) at the attacker's current position,
--     grown by HITBOX_SLACK, and only damages claimed enemies that overlap it.
-- Enemies are models tagged "Enemy" with a Humanoid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Combat
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)

type Chain = { lastSwing: number, index: number }
local chains: { [Player]: Chain } = {}

local Combat = {}

function Combat.swing(player: Player, swingTime: any, claimed: any)
	if type(swingTime) ~= "number" or swingTime ~= swingTime or type(claimed) ~= "table" then
		return
	end
	local now = workspace:GetServerTimeNow()
	if swingTime > now + Config.CLOCK_SLACK or now - swingTime > Config.MAX_LAG then
		return
	end
	local chain = chains[player] or { lastSwing = -math.huge, index = 0 }
	chains[player] = chain
	local since = swingTime - chain.lastSwing
	if since < Config.SWING_SECONDS * Config.COOLDOWN_SLACK then
		return
	end
	chain.index = if since > Config.CHAIN_RESET then 1 else chain.index % #Config.FIST_DAMAGE + 1
	chain.lastSwing = swingTime

	local data = PlayerData.get(player)
	local character = player.Character
	local myHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (data and myHumanoid and root and myHumanoid.Health > 0) then
		return
	end

	-- claimed enemies, deduplicated and capped
	local targets: { Model } = {}
	local seen: { [Instance]: boolean } = {}
	for _, model in claimed do
		if #targets >= Config.MAX_TARGETS then
			break
		end
		if typeof(model) == "Instance" and Hitbox.alive(model) and not seen[model] then
			seen[model] = true
			table.insert(targets, model)
		end
	end
	if #targets == 0 then
		return
	end

	local cframe, size = Hitbox.box(root, Config.HITBOX_SLACK)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = targets
	local hits = Hitbox.enemiesIn(cframe, size, params, root.Position)

	local damage = Config.FIST_DAMAGE[chain.index] * Cultivation.stage(data).power
	for _, model in hits do
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		model:SetAttribute("LastHitBy", player.UserId)
		humanoid:TakeDamage(damage)
	end
	if #hits > 0 then
		Cultivation.markActive(player)
	end
end

function Combat.forget(player: Player)
	chains[player] = nil
end

return Combat
