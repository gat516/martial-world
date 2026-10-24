--!strict
-- Realm pressure's moments (docs/systems/combat.md "Realm pressure"): when a beast
-- flinches at a player a major above it, or a breakthrough's wave staggers the beasts
-- around, a small ripple of qi rings out on the ground at that player's feet, so
-- they notice "it feared me". A beast that flinches also kicks up a little dust where
-- it stands. Reads the enemy model's `Awed` attribute ("<userId> <kind> <n>", kind
-- "flinch" or "wave"; EnemyService cueAwe). Reuses the enemy impact kit's Shock ring
-- and Dust (EnemyFX/Impact, ReplicatedStorage.Effects.EnemyImpact), flat on the
-- ground, short-lived; nothing faces the camera.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Impact = require(script.Parent.EnemyFX.Impact)

local PressureFX = {}

local GAP = 1.5 -- seconds: one ripple per player, however many beasts quail at once
local RING = { flinch = 4, wave = 7 } -- ripple radius (studs) per kind: about a body across
-- the player's own qi, pale gold, so it reads as theirs and not as a beast's attack
local QI = {
	core = Color3.fromRGB(255, 250, 232),
	color = Color3.fromRGB(246, 214, 150),
	dust = Color3.fromRGB(214, 202, 176),
	dark = Color3.fromRGB(196, 176, 128), -- the ring's base layer: no dark scorch, it's not a blow
}

local lastRipple: { [number]: number } = {}

local function feet(model: Model?): Vector3?
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	return Impact.floor(root.Position, { model :: Instance })
end

local function cue(enemy: Model)
	local value = enemy:GetAttribute("Awed")
	if type(value) ~= "string" then
		return
	end
	local id, kind = string.match(value, "^(%-?%d+) (%a+)")
	local userId = tonumber(id)
	local player = userId and Players:GetPlayerByUserId(userId)
	if not (player and kind) then
		return
	end
	local now = os.clock()
	if now - (lastRipple[player.UserId] or -math.huge) >= GAP then
		lastRipple[player.UserId] = now
		local at = feet(player.Character)
		if at then
			Impact.takeoff(at, { radius = RING[kind] or RING.flinch, palette = QI, dust = 0.25 })
		end
	end
	if kind == "flinch" then
		local at = feet(enemy)
		if at then
			Impact.takeoff(at, { radius = 3, element = "earth", dust = 0.4 })
		end
	end
end

local function watch(enemy: Instance)
	if enemy:IsA("Model") then
		enemy:GetAttributeChangedSignal("Awed"):Connect(function()
			cue(enemy)
		end)
	end
end

function PressureFX.init()
	for _, enemy in CollectionService:GetTagged("Enemy") do
		watch(enemy)
	end
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		lastRipple[player.UserId] = nil
	end)
end

return PressureFX
