--!strict
-- Helpers shared by the weapon techniques' effect modules (MoonflashDraw,
-- DragonPierce, CrescentSweep). Not a technique itself: CombatEffects only
-- loads TechniqueFX modules by technique id.
--
--   phases(def, clip)  the cast's windup/active/recovery/speed: from
--       ActionRules.castProfile when it understands the def (the same numbers
--       the hitbox runs on), else from the def's own clip times and castSpeed
--       (`clip` = { hit, hitStop } fallbacks, clip seconds).
--   tip(character)     the equipped weapon's blade-tip Attachment (`Tip`), or nil.
--   tipPosition(character, side)  the tip's world position, else the hand's.
--   sample(curve, t)   a NumberSequence's value at t (0..1).
--   drive(seconds, onStep, onDone)  a pausable tween clock (TechniqueVFX.waves).
--   ghost(character, color, transparency, hold, fade)  a Neon afterimage of the
--       body's current pose, left where it is.
--   fadeOut(part, seconds, delay, goal?)  a pausable fade that destroys the part.
--   worldParams(character)  raycast params for world geometry only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local TechniqueVFX = require(Client.TechniqueVFX)
local CastFX = require(Client.CastFX)

local WeaponFX = {}

export type Clip = { hit: number, hitStop: number }

-- The def's first hit window in clip seconds: `hits[1]` as { time, hitStop }
-- or { time = .., hitStop = .. } when the backend provides it, else `clip`.
function WeaponFX.clip(def: any, clip: Clip): Clip
	local hits = def.hits
	local first = type(hits) == "table" and hits[1]
	if type(first) == "table" then
		local hit = first.time or first.hit or first[1]
		local stop = first.hitStop or first.stop or first[3]
		if type(hit) == "number" then
			return { hit = hit, hitStop = if type(stop) == "number" and stop > hit then stop else clip.hitStop - clip.hit + hit }
		end
	end
	return clip
end

function WeaponFX.phases(def: any, clip: Clip): CastFX.Phases
	local ok, p = pcall(CastFX.phases, def)
	if ok and type(p) == "table" and type(p.windup) == "number" and p.windup > 0 then
		return p
	end
	local c = WeaponFX.clip(def, clip)
	local speed = if type(def.castSpeed) == "number" and def.castSpeed > 0 then def.castSpeed else 1
	local recovery = if type(def.cast) == "table" and type(def.cast.recovery) == "number" then def.cast.recovery else 0.2
	return { windup = c.hit / speed, active = (c.hitStop - c.hit) / speed, recovery = recovery, speed = speed }
end

-- The equipped weapon's `Tip` attachment (WeaponModels contract: a Model in
-- the character with Tip/Base attachments on its hilt part or blade).
function WeaponFX.tip(character: Model?): Attachment?
	if not character then
		return nil
	end
	for _, d in character:GetDescendants() do
		if d:IsA("Attachment") and (d.Name == "Tip" or d.Name == "tip") and d.Parent and d.Parent:IsA("BasePart") then
			return d
		end
	end
	return nil
end

function WeaponFX.tipPosition(character: Model?, side: string?): Vector3?
	local tip = WeaponFX.tip(character)
	if tip then
		return tip.WorldPosition
	end
	return CastFX.handPosition(character, side or "Right")
end

function WeaponFX.sample(curve: NumberSequence, t: number): number
	local kps = curve.Keypoints
	if t <= 0 then
		return kps[1].Value
	end
	for i = 2, #kps do
		local a, b = kps[i - 1], kps[i]
		if t <= b.Time then
			local k = (t - a.Time) / math.max(b.Time - a.Time, 1e-4)
			return a.Value + (b.Value - a.Value) * k
		end
	end
	return kps[#kps].Value
end

-- A tween on a NumberValue (seconds elapsed) that previews can pause.
function WeaponFX.drive(seconds: number, onStep: (number) -> (), onDone: (() -> ())?)
	local value = Instance.new("NumberValue")
	value.Value = 0
	value.Changed:Connect(onStep)
	local tween = TweenService:Create(value, TweenInfo.new(math.max(seconds, 0.01), Enum.EasingStyle.Linear), { Value = seconds })
	TechniqueVFX.waves[tween] = true
	tween.Completed:Once(function()
		TechniqueVFX.waves[tween] = nil
		value:Destroy()
		if onDone then
			onDone()
		end
	end)
	tween:Play()
end

-- Fade a part out (ease In: holds, then goes), then destroy it.
function WeaponFX.fadeOut(part: Instance, seconds: number, delay: number?, goal: { [string]: any }?)
	local g = goal or {}
	if part:IsA("BasePart") and g.Transparency == nil then
		g.Transparency = 1
	end
	local tween = TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, delay or 0), g)
	TechniqueVFX.waves[tween] = true
	tween.Completed:Once(function()
		TechniqueVFX.waves[tween] = nil
		part:Destroy()
	end)
	tween:Play()
end

-- A Neon afterimage of the body's current pose (weapon included), left in place.
function WeaponFX.ghost(character: Model?, color: Color3, transparency: number, hold: number, fade: number)
	if not character then
		return
	end
	for _, source in character:GetDescendants() do
		if not source:IsA("BasePart") or source.Name == "HumanoidRootPart" or source.Transparency >= 0.95 then
			continue
		end
		if source.Size.Magnitude < 0.3 then
			continue -- hilts and joints
		end
		source.Archivable = true
		local g = source:Clone()
		if not g then
			continue
		end
		for _, child in g:GetChildren() do
			if not child:IsA("DataModelMesh") then
				child:Destroy()
			end
		end
		if g:IsA("MeshPart") then
			g.TextureID = ""
		end
		g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
		g.Massless = true
		g.Material = Enum.Material.Neon
		g.Color = color
		g.Transparency = transparency
		g.CFrame = source.CFrame
		g.Parent = TechniqueVFX.folder
		WeaponFX.fadeOut(g, fade, hold, { Transparency = 1, Size = g.Size * 1.06 })
	end
end

-- Rays that stop on world geometry only (walls, rising ground): not
-- characters, enemies, effects or non-colliding decoration.
function WeaponFX.worldParams(character: Model?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local list: { Instance } = { workspace.CurrentCamera, TechniqueVFX.folder }
	if character then
		table.insert(list, character)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	for _, enemy in CollectionService:GetTagged("Enemy") do
		table.insert(list, enemy)
	end
	local temp = workspace.Terrain:FindFirstChild("TempVFX")
	if temp then
		table.insert(list, temp)
	end
	params.FilterDescendantsInstances = list
	return params
end

-- ------------------------------------------------------------ the held weapon

-- The held weapon's span in world space, read off its model's attachments
-- (WeaponModels contract): `Tip` is the point; the root is `Base` (the blade
-- starts at the guard), or in `full` mode the grip end (`butt` on a staff, else
-- `grip`), so a staff glows end to end and a spear along its whole shaft. With
-- no weapon it is a virtual blade off the right arm (a fist is not a sword,
-- but the effect keeps its place). Everything made on a rig rides the weapon
-- part, so it follows the swing and is gone with `release`.
export type Rig = {
	part: BasePart, -- the weapon part the attachments ride (the Hilt/HiltR joint part)
	from: Attachment, -- root end
	to: Attachment, -- point
	real: boolean, -- false: a virtual blade off the arm
	length: number, -- studs, root -> point
	at: (self: Rig, f: number) -> Vector3, -- world point `f` (0 root .. 1 point) along it now
	attach: (self: Rig, f: number, name: string?) -> Attachment, -- an attachment riding the weapon at `f`
	owned: { Instance },
}

function WeaponFX.rig(character: Model?, full: boolean?): Rig?
	if not character then
		return nil
	end
	local owned: { Instance } = {}
	local part: BasePart? = nil
	local from: Attachment? = nil
	local to: Attachment? = nil
	for _, child in character:GetChildren() do
		if not (child:IsA("Model") or child:IsA("Tool") or child:IsA("Accessory")) then
			continue
		end
		local tip = child:FindFirstChild("Tip", true) or child:FindFirstChild("tip", true)
		if tip and tip:IsA("Attachment") and tip.Parent and tip.Parent:IsA("BasePart") then
			local root: Instance? = nil
			if full then
				root = child:FindFirstChild("butt", true) or child:FindFirstChild("grip", true)
			end
			root = root or child:FindFirstChild("Base", true) or child:FindFirstChild("guard", true) or child:FindFirstChild("grip", true)
			if root and root:IsA("Attachment") then
				part, from, to = tip.Parent :: BasePart, root, tip
				break
			end
		end
	end
	local rig: any = { owned = owned }
	if part and from and to then
		rig.part, rig.from, rig.to, rig.real = part, from, to, true
	else
		local arm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
		if not (arm and arm:IsA("BasePart")) then
			return nil
		end
		local down = -arm.CFrame.UpVector
		local hand = arm.Position + down * (arm.Size.Y / 2)
		local function virtual(name: string, at: Vector3): Attachment
			local a = Instance.new("Attachment")
			a.Name = name
			a.Parent = arm
			a.WorldPosition = at
			table.insert(owned, a)
			return a
		end
		rig.part, rig.real = arm, false
		rig.from, rig.to = virtual("_RigFrom", hand + down * 0.6), virtual("_RigTo", hand + down * 4.2)
	end
	function rig:at(f: number): Vector3
		local a, b = self.from.WorldPosition, self.to.WorldPosition
		return a + (b - a) * f
	end
	function rig:attach(f: number, name: string?): Attachment
		local a = Instance.new("Attachment")
		a.Name = name or "_RigAt"
		a.Parent = self.part
		a.WorldPosition = self:at(f)
		table.insert(self.owned, a)
		return a
	end
	rig.length = (rig.to.WorldPosition - rig.from.WorldPosition).Magnitude
	return rig :: Rig
end

function WeaponFX.releaseRig(rig: Rig?, delay: number?)
	if not rig then
		return
	end
	task.delay(delay or 0, function()
		for _, inst in rig.owned do
			inst:Destroy()
		end
	end)
end

-- Anticipation on the weapon itself. `template` is the technique's `Charge`
-- part: its Attachments carry an `At` attribute (0 root .. 1 point) and are
-- moved onto the weapon at that fraction, with their emitters; Beams/Trails
-- find their own attachments (a Beam named `Glow` between `At` 0 and 1 draws
-- the blade wreathed in qi). Everything loops for `seconds` (the windup, to
-- Hit), then stops and cleans itself up; `onHit` (the Hit moment, cast start
-- + seconds) is left to the caller. Returns the rig, or nil without a template.
function WeaponFX.charge(character: Model?, template: Instance?, seconds: number, full: boolean?): Rig?
	if not (character and template) then
		return nil
	end
	local rig = WeaponFX.rig(character, full)
	if not rig then
		return nil
	end
	local holder = template:Clone()
	local list = holder:GetDescendants()
	local lives = 0.6
	for _, d in list do
		if d:IsA("Attachment") and type(d:GetAttribute("At")) == "number" then
			d.Parent = rig.part
			d.WorldPosition = rig:at(d:GetAttribute("At") :: number)
			table.insert(rig.owned, d)
		end
	end
	for _, d in list do
		if d:IsA("Beam") or d:IsA("Trail") then
			d.Parent = rig.part
			table.insert(rig.owned, d)
			;(d :: any).Enabled = true
		elseif d:IsA("ParticleEmitter") then
			lives = math.max(lives, d.Lifetime.Max)
			d.Enabled = true
		end
	end
	holder:Destroy()
	task.delay(seconds, function()
		for _, d in rig.owned do
			if d:IsA("ParticleEmitter") then
				d.Enabled = false
			end
			if d:IsA("Attachment") then
				for _, e in d:GetChildren() do
					if e:IsA("ParticleEmitter") then
						e.Enabled = false
					end
				end
			end
			if d:IsA("Beam") or d:IsA("Trail") then
				(d :: any).Enabled = false
			end
		end
		WeaponFX.releaseRig(rig, lives + 0.3)
	end)
	return rig
end

-- Seconds from Hit to Hit Stop of hit `index` at the cast's playback speed
-- (def.hits[i].stop - .time, the clip's own markers), else the whole active
-- window of the cast profile.
function WeaponFX.hitWindow(def: any, index: number?): number
	local h = type(def.hits) == "table" and def.hits[index or 1]
	local speed = if type(def.castSpeed) == "number" and def.castSpeed > 0 then def.castSpeed else 1
	if type(h) == "table" then
		local stop = h.stop or h.hitStop
		if type(h.time) == "number" and type(stop) == "number" and stop > h.time then
			return (stop - h.time) / speed
		end
	end
	local ok, phases = pcall(CastFX.phases, def)
	return if ok and type(phases) == "table" then phases.active else 0.1
end

-- Seconds after Hit when something travelling the line should land its hits so
-- every impact stays inside the active window (Hit -> Hit Stop) plus a little
-- slack: a damage number appears at Hit, so the hit it belongs to must not
-- trail it by more than a few frames. `arrival` is when the projectile front
-- reaches the target on its own clock, `travel` its full flight.
function WeaponFX.landing(arrival: number, travel: number, active: number): number
	local window = math.max(active, 0.1)
	return math.min(arrival * window / math.max(travel, 1e-3), window)
end

-- Fire a detached template part at a CFrame with its Body attachment raised.
function WeaponFX.burst(part: BasePart?, cframe: CFrame, bodyHeight: number?)
	if not part then
		return
	end
	local b = part:Clone()
	b.CFrame = cframe
	local body = b:FindFirstChild("Body")
	if body and body:IsA("Attachment") and bodyHeight then
		body.Position = Vector3.new(0, bodyHeight, 0)
	end
	b.Parent = TechniqueVFX.folder
	TechniqueVFX.emit(b)
	TechniqueVFX.cleanup(b)
end

return WeaponFX
