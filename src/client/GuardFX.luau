--!strict
-- Guard visuals: the perfect parry clash, the blocked-hit ripple, the guard
-- break shatter and the faint forearm shimmer while guard is held. Templates
-- live in ReplicatedStorage.GuardFX (assets/GuardFX.rbxm, built by
-- tools/guardfx_build.luau) and play through the vfxia Game Module via
-- TechniqueVFX, so what plays is what the plugin's Emit button shows.
--
-- Every call is cosmetic: a missing template warns once and does nothing.
-- Screen extras (shake, the grade/camera punch) run only for the local player.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatEffects = require(script.Parent.CombatEffects)
local TechniqueVFX = require(script.Parent.TechniqueVFX)

local GuardFX = {}

local CULL = 120 -- studs from the camera past which observers' guard fx are skipped
local HOLD_CULL = 70
local CHEST = Vector3.new(0, 0.5, 0)
local PARRY_TINT = Color3.fromRGB(255, 250, 225)
local BREAK_TINT = Color3.fromRGB(190, 240, 215)

local warned: { [string]: boolean } = {}

local function template(name: string): Instance?
	local folder = ReplicatedStorage:FindFirstChild("GuardFX")
	local found = folder and folder:FindFirstChild(name)
	if not found and not warned[name] then
		warned[name] = true
		warn(`GuardFX: ReplicatedStorage.GuardFX.{name} is missing; skipping`)
	end
	return found
end

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function nearCamera(at: Vector3, range: number): boolean
	return (workspace.CurrentCamera.CFrame.Position - at).Magnitude <= range
end

-- Flat direction from the character toward `from` (its facing when `from` is on top of it).
local function toward(root: BasePart, from: Vector3): Vector3
	local flat = Vector3.new(from.X - root.Position.X, 0, from.Z - root.Position.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	return flat.Unit
end

-- A positioned copy of a template, played and cleaned up.
local function play(name: string, cframe: CFrame)
	local source = template(name)
	if not (source and source:IsA("Model")) then
		return
	end
	local copy = source:Clone()
	copy:PivotTo(cframe)
	copy.Parent = TechniqueVFX.folder
	TechniqueVFX.emit(copy)
	TechniqueVFX.cleanup(copy, 0.2)
end

-- A crisp metallic clash where the strike met the guard: white-hot star glint,
-- sparks along the deflect, crescent arc and a quick ring. `from` is the attacker.
function GuardFX.parry(character: Model, from: Vector3, isLocal: boolean)
	local root = rootOf(character)
	if not root then
		return
	end
	local dir = toward(root, from)
	local contact = root.Position + CHEST + dir * 2.4
	if not isLocal and not nearCamera(contact, CULL) then
		return
	end
	-- the deflect throws outward and a touch up
	local aim = (dir + Vector3.new(0, 0.18, 0)).Unit
	play("Parry", CFrame.lookAt(contact, contact + aim))
	if isLocal then
		CombatEffects.shake(0.3)
		-- 0.05 s grade + camera punch: the hitstop feel without touching time
		CombatEffects.punch(contact, 0.55, PARRY_TINT, 0.05)
	end
end

-- A blocked, non-perfect hit: small jade sparks and a ripple on the guard plane.
function GuardFX.blocked(character: Model, from: Vector3)
	local root = rootOf(character)
	if not root then
		return
	end
	local dir = toward(root, from)
	local at = root.Position + CHEST + dir * 2.1
	if not nearCamera(at, CULL) then
		return
	end
	play("Block", CFrame.lookAt(at, at + dir))
end

-- The guard shell cracks and bursts outward, with dust at the feet.
function GuardFX.guardBreak(character: Model, isLocal: boolean)
	local root = rootOf(character)
	if not root then
		return
	end
	local here = root.CFrame
	if not isLocal and not nearCamera(here.Position, CULL) then
		return
	end
	-- upright, facing the way the player faces
	local look = here.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.05 then flat.Unit else Vector3.new(0, 0, -1)
	play("GuardBreak", CFrame.lookAt(here.Position + CHEST, here.Position + CHEST + flat))
	if isLocal then
		CombatEffects.shake(0.55)
		CombatEffects.punch(here.Position, 0.35, BREAK_TINT, 0.08)
	end
end

-- Faint qi shimmer on both forearms while guard is held: one low-rate emitter
-- each, only for characters near the camera.
local held: { [Model]: { Instance } } = setmetatable({}, { __mode = "k" }) :: any

local FOREARMS = { "RightLowerArm", "LeftLowerArm", "Right Arm", "Left Arm" }

function GuardFX.hold(character: Model, on: boolean)
	local existing = held[character]
	if existing then
		for _, inst in existing do
			inst:Destroy()
		end
		held[character] = nil
	end
	if not on then
		return
	end
	local root = rootOf(character)
	if not root or not nearCamera(root.Position, HOLD_CULL) then
		return
	end
	local source = template("Hold")
	if not (source and source:IsA("Attachment")) then
		return
	end
	local made: { Instance } = {}
	for _, name in FOREARMS do
		local arm = character:FindFirstChild(name)
		if arm and arm:IsA("BasePart") then
			local copy = source:Clone()
			for _, d in copy:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					d.Enabled = true
				end
			end
			copy.Parent = arm
			table.insert(made, copy)
		end
	end
	held[character] = made
end

return GuardFX
