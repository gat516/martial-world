--!strict
-- Blood Centipede cues (EnemyFX): earth-blood, bone white and rust red.
-- Templates: ReplicatedStorage.Effects.BloodCentipede (builder
-- tools/vfx_specs/BloodCentipede.luau). Record: docs/systems/enemies.md.
-- Gated by the model's Template = "BloodCentipede".
--
-- Attacks (cue.attack): pincerSnap, coilSweep, burrowDive, erupt.
--   windup   eyes red star + held glow; the SeamTell strips and PincerTells flare
--            front to back (BeastKit.tell sweep). Nothing else (the body tells).
--   strike   pincerSnap: CrescentSnap at the Mouth. coilSweep: SweepArc on the
--            ground under the body + Impact.swipe. erupt: Eruption (scar, rust
--            glow, dust column, chips, flash) + Impact.ground earth with rocks and
--            a shake within reach 30. 
--   dash     burrowDive: DiveBurst at the root as it sinks.
--   Burrowed (attribute, wired on `ready`): on true the plates fade out, a
--            BurrowMound (dirt puffs, chips, earth hump) rides the ground under the
--            root and CrackStamp is stamped along the lane every 0.14 s as it moves;
--            on false the mound stops and the body returns (the erupt cue adds the
--            ground break). The server is assumed to leave body transparency to
--            the client for Burrowed.
--   hit      BloodHit on the torso. stagger: StaggerFlash + flash.
--   death    eyes out, Death (bone dust, red motes, glint).
-- Hooks (tolerated missing): Mouth, Core, Seg6_FX, TailTip_FX, SeamTell*, PincerTell*.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.BeastKit)
local Impact = require(script.Parent.Impact)

type Cue = Kit.Cue

local TEMPLATE = "BloodCentipede"
local LIT = Color3.fromRGB(255, 120, 96)
local WINDUP = { pincerSnap = 0.6, coilSweep = 0.9, burrowDive = 0.5, erupt = 0.7 }
local ERUPT_RADIUS = 6.5
local SWEEP_RADIUS = 12
local STAMP_EVERY = 0.14
local PALETTE = {
	core = Color3.fromRGB(238, 230, 208),
	color = Color3.fromRGB(176, 56, 36),
	dark = Color3.fromRGB(30, 16, 14),
	dust = Color3.fromRGB(122, 98, 74),
	rock = Color3.fromRGB(110, 92, 74),
}

local K = Kit.new("BloodCentipede")
local BloodCentipede = {}

local function own(cue: Cue): boolean
	return cue.model:GetAttribute("Template") == TEMPLATE
end

local function underRoot(cue: Cue): Vector3
	return K.ground(cue.root.Position, cue.model)
end

function BloodCentipede.windup(cue: Cue)
	if not own(cue) then
		return
	end
	local attack = cue.attack or ""
	local seconds = cue.seconds or WINDUP[attack] or 0.6
	K.tell(cue.model, seconds, LIT, nil, nil, true)
end

function BloodCentipede.strike(cue: Cue)
	if not own(cue) then
		return
	end
	local attack = cue.attack
	local face = cue.root.CFrame.Rotation
	if attack == "pincerSnap" then
		K.play("CrescentSnap", K.point(cue, "Mouth", { "Skull" }, Vector3.new(0, 0, -1)))
	elseif attack == "coilSweep" then
		local at = underRoot(cue)
		K.play("SweepArc", CFrame.new(at + Vector3.new(0, 0.1, 0)) * face, nil, function(clone)
			K.resize(clone, SWEEP_RADIUS / ((clone:GetAttribute("AuthoredRadius") :: number?) or 12))
		end)
		Impact.swipe(at, face.LookVector, { palette = PALETTE, radius = 8, contact = false })
	elseif attack == "erupt" then
		local at = underRoot(cue)
		K.play("Eruption", CFrame.new(at + Vector3.new(0, 0.08, 0)) * face, nil, function(clone)
			K.resize(clone, ERUPT_RADIUS / ((clone:GetAttribute("AuthoredRadius") :: number?) or 6.5))
		end)
		Impact.ground(at, { palette = PALETTE, radius = ERUPT_RADIUS, rocks = true, scar = false, shake = 0.3, reach = 30 })
	end
end

function BloodCentipede.dash(cue: Cue)
	if own(cue) and cue.attack == "burrowDive" then
		K.play("DiveBurst", CFrame.new(underRoot(cue) + Vector3.new(0, 0.1, 0)) * cue.root.CFrame.Rotation)
	end
end

function BloodCentipede.hit(cue: Cue)
	if not own(cue) then
		return
	end
	local frame = K.hitFrame(cue)
	if frame then
		K.play("BloodHit", frame)
	end
end

function BloodCentipede.stagger(cue: Cue)
	if not own(cue) then
		return
	end
	K.play("StaggerFlash", K.point(cue, "Core", { "Seg3" }), K.host(cue, "Core", { "Seg3" }))
	K.flash(cue.model)
	K.flicker(cue.model)
end

function BloodCentipede.death(cue: Cue)
	if not own(cue) then
		return
	end
	K.eyesOut(cue.model, Color3.fromRGB(40, 12, 12))
	K.play("Death", K.point(cue, "Core", { "Seg3" }))
end

-- Burrowed: fade the plates, ride a mound under the root, stamp a crack lane.
function BloodCentipede.ready(cue: Cue)
	if not own(cue) then
		return
	end
	local model = cue.model
	local saved: { [BasePart]: number } = {}
	local mound: BasePart? = nil
	local connection: RBXScriptConnection? = nil
	local lastStamp = 0
	local lastPosition = cue.root.Position

	local function hide(on: boolean)
		if on then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
					saved[d] = d.Transparency
					TweenService:Create(d, TweenInfo.new(0.2), { Transparency = 1 }):Play()
				end
			end
		else
			for part, t in saved do
				if part.Parent and model:GetAttribute("FadeAt") == nil then
					TweenService:Create(part, TweenInfo.new(0.15), { Transparency = t }):Play()
				end
			end
			table.clear(saved)
		end
	end

	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if mound then
			local m = mound
			mound = nil
			for _, e in m:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					e.Enabled = false
				end
			end
			task.delay(1.2, function()
				m:Destroy()
			end)
		end
	end

	local function start()
		stop()
		hide(true)
		lastPosition = cue.root.Position
		local m = K.play("BurrowMound", CFrame.new(underRoot(cue)) * cue.root.CFrame.Rotation)
		mound = m
		connection = RunService.RenderStepped:Connect(function()
			if not (model.Parent and mound) then
				stop()
				return
			end
			local at = underRoot(cue)
			local flatMove = Vector3.new(cue.root.Position.X - lastPosition.X, 0, cue.root.Position.Z - lastPosition.Z)
			local look = if flatMove.Magnitude > 0.05 then flatMove.Unit else cue.root.CFrame.LookVector
			;(mound :: BasePart).CFrame = CFrame.lookAt(at, at + look)
			if os.clock() - lastStamp > STAMP_EVERY and flatMove.Magnitude > 0.05 then
				lastStamp = os.clock()
				lastPosition = cue.root.Position
				K.play("CrackStamp", CFrame.lookAt(at + Vector3.new(0, 0.06, 0), at + look + Vector3.new(0, 0.06, 0)))
			end
		end)
	end

	model:GetAttributeChangedSignal("Burrowed"):Connect(function()
		if model:GetAttribute("Burrowed") == true then
			start()
		else
			stop()
			hide(false)
		end
	end)
	if model:GetAttribute("Burrowed") == true then
		start()
	end
end

return BloodCentipede
