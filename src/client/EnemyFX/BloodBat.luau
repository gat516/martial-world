--!strict
-- Iron-Winged Blood Bat cues (EnemyFX): crimson blood and pale wind. A swarm of
-- 3 to 4, so every beat is 1 to 3 emitters (templates ReplicatedStorage.Effects.BloodBat,
-- builder tools/vfx_specs/BloodBat.luau); only the single shrieker plays rings.
-- Record: docs/enemies/third-wave.md. Gated by Template = "BloodBat".
--
-- Attacks (cue.attack): bloodDive, sonicShriek, hop.
--   windup   eyes crimson star + held glow; WingEdgeTell, MouthTell and ChestCore dim
--            -> flare. sonicShriek adds Impact.roar (palette) from 40% of the windup.
--   dash     bloodDive: DiveStreak on the Core for the dive (0.47 s).
--   skid     bloodDiveSkid: nothing extra (default dust is too heavy for a swarm).
--   leech    (enemyCue, target = the bitten Character): LeechMote flies from the
--            target's torso to the bat's Core in 0.5 s, then a ChestFlash.
--   hit      BiteHit on the torso. hop: HopPuff.
--   stagger  StaggerFlash. death: eyes out, Death (iron feathers, blood mist).
-- Hooks (tolerated missing): Mouth, Core, WingTipL/R_FX, ChestCore, WingEdgeTell*.

local RunService = game:GetService("RunService")

local Kit = require(script.Parent.BeastKit)
local Impact = require(script.Parent.Impact)

type Cue = Kit.Cue

local TEMPLATE = "BloodBat"
local LIT = Color3.fromRGB(255, 120, 130)
local WINDUP = { bloodDive = 0.6, sonicShriek = 1.0 }
local DIVE = 0.47
local LEECH = 0.5
local PALETTE = {
	core = Color3.fromRGB(216, 230, 242),
	color = Color3.fromRGB(206, 30, 54),
	dark = Color3.fromRGB(26, 10, 16),
	dust = Color3.fromRGB(150, 140, 150),
	rock = Color3.fromRGB(80, 80, 90),
}

local K = Kit.new("BloodBat")
local BloodBat = {}

local function own(cue: Cue): boolean
	return cue.model:GetAttribute("Template") == TEMPLATE
end

local function core(cue: Cue): CFrame
	return K.point(cue, "Core", { "Body" })
end

function BloodBat.windup(cue: Cue)
	if not own(cue) then
		return
	end
	local attack = cue.attack or ""
	local seconds = cue.seconds or WINDUP[attack] or 0.6
	K.tell(cue.model, seconds, LIT)
	if attack == "sonicShriek" then
		local model = cue.model
		task.delay(seconds * 0.4, function()
			if model.Parent and model:GetAttribute("AIState") == "windup" then
				local m = K.point(cue, "Mouth", { "Skull" }, Vector3.new(0, 0, -1.3))
				Impact.roar(m, K.ground(m.Position, model), { palette = PALETTE, scale = 0.7, seconds = seconds * 0.6 })
			end
		end)
	end
end

function BloodBat.dash(cue: Cue)
	if own(cue) and cue.attack == "bloodDive" then
		K.play("DiveStreak", core(cue), K.host(cue, "Core", { "Body" }), function(clone)
			K.duration(clone, DIVE)
		end)
	end
end

function BloodBat.strike(cue: Cue)
	if own(cue) and cue.attack == "hop" then
		K.play("HopPuff", core(cue))
	end
end

-- The lifesteal flow: a crimson mote trail from the target to the bat.
function BloodBat.leech(cue: Cue)
	if not own(cue) then
		return
	end
	local torso = K.torso(cue.target)
	local template = K.template("LeechMote")
	if not (torso and template) then
		return
	end
	local fx = template:Clone()
	fx.CFrame = torso.CFrame
	fx.Parent = workspace.CurrentCamera
	for _, e in fx:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			e.Enabled = true
		end
	end
	local t0 = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / LEECH, 0, 1)
		local to = core(cue).Position
		local from = torso.Position
		-- an S-curve: rises off the target first, then homes in on the bat
		local position = from:Lerp(to, u * u * (3 - 2 * u)) + Vector3.new(0, 1.2 * math.sin(math.pi * u), 0)
		fx.CFrame = CFrame.new(position)
		if u >= 1 or not cue.model.Parent then
			connection:Disconnect()
			for _, e in fx:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					e.Enabled = false
				end
			end
			task.delay(0.6, function()
				fx:Destroy()
			end)
			if cue.model.Parent then
				K.play("ChestFlash", core(cue), K.host(cue, "Core", { "Body" }))
			end
		end
	end)
end

function BloodBat.hit(cue: Cue)
	if not own(cue) then
		return
	end
	local frame = K.hitFrame(cue)
	if frame then
		K.play("BiteHit", frame)
	end
end

function BloodBat.stagger(cue: Cue)
	if own(cue) then
		K.play("StaggerFlash", core(cue), K.host(cue, "Core", { "Body" }))
	end
end

function BloodBat.death(cue: Cue)
	if not own(cue) then
		return
	end
	K.eyesOut(cue.model, Color3.fromRGB(40, 10, 14))
	K.play("Death", core(cue))
end

-- No skid handler: a bat has no feet, and the default dust spray is too much for a swarm.
function BloodBat.skid(_cue: Cue) end

return BloodBat
