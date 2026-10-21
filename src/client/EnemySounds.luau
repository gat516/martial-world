--!strict
-- Beast voices, played from each enemy as its AIState attribute changes (see
-- EnemyAnimator): a cry when it takes notice, its attack sound as the windup
-- starts (so the ear warns of the blow along with the telegraph), and a death
-- cry. The sounds are SoundService.SFX.Enemies.<EnemyType>.Aggro / Attack / Death.
-- Optional, per beast: Attack_<name> for one attack (the model's Attack
-- attribute; falls back to Attack), Howl for a pack call, Hurt on a stagger,
-- Land when a leap touches down or a charge skids to a stop.

local CollectionService = game:GetService("CollectionService")

local Sfx = require(script.Parent.Sfx)

local AGGRO_GAP = 6 -- seconds before the same beast cries out on noticing you again

local EnemySounds = {}

-- streamed-out enemies come back as the same instance: watch each only once
local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function watch(model: Instance)
	if not model:IsA("Model") or watched[model] then
		return
	end
	watched[model] = true
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not (root and root:IsA("BasePart")) then
		return
	end
	local kind = model:GetAttribute("EnemyType")
	if type(kind) ~= "string" then
		return
	end
	local base = `Enemies/{kind}/`
	local lastAggro = -math.huge
	local previous = model:GetAttribute("AIState")
	model:GetAttributeChangedSignal("AIState"):Connect(function()
		local state = model:GetAttribute("AIState")
		if state == "chase" and (previous == "idle" or previous == "return") then
			local now = os.clock()
			if now - lastAggro >= AGGRO_GAP then
				lastAggro = now
				Sfx.play(base .. "Aggro", root)
			end
		elseif state == "windup" then
			local attack = model:GetAttribute("Attack")
			local played = false
			if attack == "howl" then
				played = Sfx.play(base .. "Howl", root) ~= nil
			elseif type(attack) == "string" then
				played = Sfx.play(base .. "Attack_" .. attack, root) ~= nil
			end
			if not played then
				Sfx.play(base .. "Attack", root)
			end
		elseif state == "stagger" then
			Sfx.play(base .. "Hurt", root, 0.3)
		end
		local attack = model:GetAttribute("Attack")
		if previous == "dash" and state ~= "dash" and (attack == "leap" or attack == "charge") then
			Sfx.play(base .. "Land", root)
		end
		previous = state
	end)
	-- Health is an attribute (no Humanoid); hitting 0 is the death
	local died = false
	model:GetAttributeChangedSignal("Health"):Connect(function()
		local health = model:GetAttribute("Health")
		if not died and type(health) == "number" and health <= 0 then
			died = true
			-- from where it fell: the body may be removed before the cry ends
			Sfx.play(base .. "Death", root.Position)
		end
	end)
end

function EnemySounds.init()
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(function(model)
		task.spawn(watch, model)
	end)
	for _, model in CollectionService:GetTagged("Enemy") do
		task.spawn(watch, model)
	end
end

return EnemySounds
