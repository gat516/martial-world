--!strict
-- Guard visuals: the perfect parry clash, the blocked-hit ripple, the guard
-- break shatter and the faint forearm shimmer while guard is held. Templates
-- live in ReplicatedStorage.GuardFX (assets/GuardFX.rbxm, built by
-- tools/guardfx_build.luau) and play through the vfxia Game Module via
-- TechniqueVFX, so what plays is what the plugin's Emit button shows.
--
-- Chain parries escalate with what's there: each deflect throws to alternate
-- sides (Parry right, ParryAlt left, matching the clips), the burst grows and
-- the shake and punch climb; the blow that closes a chain, or the chain running
-- dry, adds a finisher (an oversized Parry, a second delayed one and a wide
-- Block ripple). No new templates.
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
local FINISH_TINT = Color3.fromRGB(255, 226, 150)
local CHAIN_GROW = 0.07 -- each chained deflect's burst is this much bigger...
local CHAIN_STEPS = 5 -- ...for up to this many steps
local SIDE_THROW = 0.55 -- how far sideways a chained deflect throws

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

-- A positioned copy of a template (scaled by `scale`), played and cleaned up.
local function play(name: string, cframe: CFrame, scale: number?)
	local source = template(name)
	if not (source and source:IsA("Model")) then
		return
	end
	local copy = source:Clone()
	copy:PivotTo(cframe)
	if scale then
		TechniqueVFX.rescale(copy, scale)
	end
	copy.Parent = TechniqueVFX.folder
	TechniqueVFX.emit(copy)
	TechniqueVFX.cleanup(copy, 0.2)
end

-- The closing beat of a chain: an oversized clash, a second one a beat later
-- and a wide ripple, with a heavy shake and a longer gold punch.
local function finish(contact: Vector3, dir: Vector3, n: number, isLocal: boolean)
	local up = CFrame.lookAt(contact, contact + (dir + Vector3.new(0, 0.35, 0)).Unit)
	local big = 1.45 + 0.05 * math.min(n, CHAIN_STEPS)
	play("Parry", up, big)
	task.delay(0.06, function()
		play("Parry", up * CFrame.Angles(0, 0, math.rad(45)), big * 1.15)
		play("Block", CFrame.lookAt(contact, contact + dir), 1.7)
	end)
	if isLocal then
		CombatEffects.shake(0.65)
		CombatEffects.punch(contact, 0.95, FINISH_TINT, 0.1)
	end
end

-- A crisp metallic clash where the strike met the guard: white-hot star glint,
-- sparks along the deflect, crescent arc and a quick ring. `from` is the attacker.
-- `chain` (default 1): the blow's place in a chain parry; from the second on the
-- deflect alternates sides and grows. `closing`: it ended the chain (finisher).
function GuardFX.parry(character: Model, from: Vector3, isLocal: boolean, chain: number?, closing: boolean?)
	local root = rootOf(character)
	if not root then
		return
	end
	local n = chain or 1
	local dir = toward(root, from)
	local right = dir:Cross(Vector3.yAxis)
	-- Parry throws right, ParryAlt (even blows) left; the timed first stays centred
	local side = if n == 1 then 0 elseif n % 2 == 0 then -1 else 1
	local contact = root.Position + CHEST + dir * 2.4 + right * side * 0.7
	if not isLocal and not nearCamera(contact, CULL) then
		return
	end
	-- the deflect throws outward and a touch up
	local aim = (dir + right * side * SIDE_THROW + Vector3.new(0, 0.18, 0)).Unit
	local step = math.min(n - 1, CHAIN_STEPS)
	play("Parry", CFrame.lookAt(contact, contact + aim), if step > 0 then 1 + CHAIN_GROW * step else nil)
	if closing then
		finish(root.Position + CHEST + dir * 2.4, dir, n, isLocal)
	elseif isLocal then
		CombatEffects.shake(0.3 + 0.04 * step)
		-- 0.05 s grade + camera punch: the hitstop feel without touching time
		CombatEffects.punch(contact, 0.55 + 0.06 * step, PARRY_TINT, 0.05)
	end
end

-- A chain that ran dry (the attacker stopped mid-flurry and reels): just the
-- finisher, `n` blows deflected.
function GuardFX.finisher(character: Model, from: Vector3, isLocal: boolean, n: number)
	local root = rootOf(character)
	if not root then
		return
	end
	local dir = toward(root, from)
	local contact = root.Position + CHEST + dir * 2.4
	if not isLocal and not nearCamera(contact, CULL) then
		return
	end
	finish(contact, dir, n, isLocal)
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
