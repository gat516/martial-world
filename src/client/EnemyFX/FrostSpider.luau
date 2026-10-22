--!strict
-- Frost Spider cues (EnemyFX): ice white-blue on slate. Templates:
-- ReplicatedStorage.Effects.FrostSpider (builder tools/vfx_specs/FrostSpider.luau).
-- Record: docs/systems/enemies.md. Gated by the model's Template = "FrostSpider".
--
-- Attacks (cue.attack): webShot, frostFang, hop (the skitter).
--   windup   all: the six eyes (Eye1..6) star + glow; FangTell, FrostVeinTell and
--            CoreGlow Tells dim -> ice; FangGlint on each fang.
--            webShot: SpinneretGlow at the Spinneret; the landing point is remembered.
--   strike   webShot: a WebBeam thread from the Spinneret to the landing, held 0.4 s,
--            then WebSplat + Impact.explode (ice) there. frostFang: FangFrost at the
--            Mouth. hop: SkitterPuff at the feet.
--   skid     frostFangSkid: Impact.skid from the four front feet (ice palette).
--   patch    (Effect enemyPatch: shape.center/radius/effect "slow", seconds) WebPatch
--            (slate base, silk, dark+bright edge rings, strands, glints) refit to the
--            patch; while it lasts, any character standing inside gets the foot frost.
--   hit      frostFang: FrostHit on the torso, then the foot frost on the target.
--   slow     (enemyCue, target = the slowed Character) FootFrost on both feet for the
--            remaining slow (Humanoid attribute SlowUntil, server time; else 1.5 s).
--   stagger  StaggerFlash + flash. death: it shatters (Death: shards, flash, mist, glint).
-- Hooks (tolerated missing): Mouth, Spinneret, Core, FootL1..R4_FX, Eye1..6, Fang/Vein Tells.

local Players = game:GetService("Players")

local Kit = require(script.Parent.BeastKit)
local Impact = require(script.Parent.Impact)

type Cue = Kit.Cue

local TEMPLATE = "FrostSpider"
local LIT = Color3.fromRGB(200, 236, 255)
local WINDUP = { webShot = 0.9, frostFang = 0.7 }
local BEAM = 0.4
local PATCH_TICK = 0.4
local PALETTE = {
	core = Color3.fromRGB(236, 247, 255),
	color = Color3.fromRGB(150, 205, 250),
	dark = Color3.fromRGB(32, 42, 58),
	dust = Color3.fromRGB(200, 220, 236),
	rock = Color3.fromRGB(150, 190, 220),
}
local FEET = { "L1", "R1", "L2", "R2" }

local K = Kit.new("FrostSpider")
local FrostSpider = {}

local webTarget: { [Model]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
local tinted: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function own(cue: Cue): boolean
	return cue.model:GetAttribute("Template") == TEMPLATE
end

local function eyes(model: Model): { BasePart }
	return K.named(model, "^Eye%d$")
end

local function feet(cue: Cue): CFrame
	return CFrame.new(K.ground(cue.root.Position, cue.model) + Vector3.new(0, 0.1, 0)) * cue.root.CFrame.Rotation
end

-- Frost on a character's feet for `seconds` (refreshing at most every 0.5 s).
local function frostFeet(character: Model, seconds: number)
	local now = os.clock()
	if now - (tinted[character] or 0) < 0.5 then
		return
	end
	tinted[character] = now
	for _, names in { { "LeftFoot", "Left Leg" }, { "RightFoot", "Right Leg" } } do
		local foot = character:FindFirstChild(names[1]) or character:FindFirstChild(names[2])
		if foot and foot:IsA("BasePart") then
			local at = foot.CFrame * CFrame.new(0, -foot.Size.Y / 2 + 0.05, 0)
			K.play("FootFrost", at, foot, function(clone)
				K.duration(clone, seconds)
			end)
		end
	end
end

function FrostSpider.windup(cue: Cue)
	if not own(cue) then
		return
	end
	local model = cue.model
	local attack = cue.attack or ""
	local seconds = cue.seconds or WINDUP[attack] or 0.6
	K.tell(model, seconds, LIT, nil, eyes(model))
	for _, fang in K.named(model, "^FangTell") do
		K.play("FangGlint", fang.CFrame, fang)
	end
	if attack == "webShot" then
		K.play("SpinneretGlow", K.point(cue, "Spinneret", { "Body" }, Vector3.new(0, 0, 3.5)), K.host(cue, "Spinneret", { "Body" }), function(clone)
			K.duration(clone, seconds)
		end)
		local shape = cue.shape
		if type(shape) == "table" and typeof(shape.center) == "Vector3" then
			webTarget[model] = shape.center
		end
	end
end

function FrostSpider.strike(cue: Cue)
	if not own(cue) then
		return
	end
	local model = cue.model
	local attack = cue.attack
	if attack == "webShot" then
		local center = webTarget[model]
		local a0 = K.attachment(model, "Spinneret")
		if center and a0 then
			local floor = K.ground(center, model)
			K.beam("WebBeam", a0, K.anchorAt(floor + Vector3.new(0, 0.3, 0), BEAM + 0.3), BEAM)
			task.delay(BEAM * 0.6, function()
				Impact.explode(floor, { palette = PALETTE, radius = 4, scar = false, dust = 0.5 })
				K.play("WebSplat", CFrame.new(floor + Vector3.new(0, 0.2, 0)))
			end)
		end
	elseif attack == "frostFang" then
		K.play("FangFrost", K.point(cue, "Mouth", { "Body" }, Vector3.new(0, 0, -3.5)))
	elseif attack == "hop" then
		K.play("SkitterPuff", feet(cue))
	end
end

function FrostSpider.skid(cue: Cue)
	if not own(cue) then
		return
	end
	local points = {}
	for _, which in FEET do
		local cf = K.point(cue, `Foot{which}_FX`, { `Foot{which}` }, Vector3.new(0, -0.2, 0))
		table.insert(points, K.ground(cf.Position, cue.model))
	end
	Impact.skid(points, cue.root.CFrame.LookVector, { palette = PALETTE, scale = 0.8, seconds = 0.35 })
end

-- The slow web patch (Effect enemyPatch): cue.shape = { center, radius, effect }.
function FrostSpider.patch(cue: Cue)
	if not own(cue) then
		return
	end
	local shape = cue.shape
	if type(shape) ~= "table" or typeof(shape.center) ~= "Vector3" then
		return
	end
	local radius = if type(shape.radius) == "number" then shape.radius else 5
	local seconds = cue.seconds or 4
	local floor = K.ground(shape.center, cue.model)
	K.play("WebPatch", CFrame.new(floor + Vector3.new(0, 0.1, 0)), nil, function(clone)
		K.retime(clone, seconds / 4.1)
		K.resize(clone, radius / ((clone:GetAttribute("AuthoredRadius") :: number?) or 5))
	end)
	-- anyone standing in it shows the frost on their feet
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < seconds and cue.model.Parent do
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if character and root and root:IsA("BasePart") then
					local d = Vector3.new(root.Position.X - floor.X, 0, root.Position.Z - floor.Z).Magnitude
					if d <= radius then
						frostFeet(character, 0.8)
					end
				end
			end
			task.wait(PATCH_TICK)
		end
	end)
end

function FrostSpider.slow(cue: Cue)
	if not own(cue) or not cue.target then
		return
	end
	local humanoid = cue.target:FindFirstChildOfClass("Humanoid")
	local untilAt = humanoid and humanoid:GetAttribute("SlowUntil")
	local seconds = if type(untilAt) == "number" then math.max(0.3, untilAt - workspace:GetServerTimeNow()) else 1.5
	frostFeet(cue.target, seconds)
end

function FrostSpider.hit(cue: Cue)
	if not own(cue) then
		return
	end
	local frame = K.hitFrame(cue)
	if frame then
		K.play("FrostHit", frame)
	end
end

function FrostSpider.stagger(cue: Cue)
	if not own(cue) then
		return
	end
	K.play("StaggerFlash", K.point(cue, "Core", { "CoreGlow" }), K.host(cue, "Core", { "CoreGlow" }))
	K.flash(cue.model)
end

function FrostSpider.death(cue: Cue)
	if not own(cue) then
		return
	end
	for _, eye in eyes(cue.model) do
		eye.Transparency = 1
	end
	K.play("Death", K.point(cue, "Core", { "CoreGlow" }))
end

return FrostSpider
