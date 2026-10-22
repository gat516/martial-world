--!strict
-- The shared impact kit for enemy effects (not a beast: no EnemyType is named
-- Impact). Every ground blow, landing, explosion, skid, wolf roar and boss
-- projectile layers these on top of the beast's own element effects, so a hit
-- has weight: a shockwave, dust and debris, a contact flash, and for landings
-- and explosions a burst and a scar that fades. docs/systems/telegraphs.md,
-- "Impact". Templates: ReplicatedStorage.Effects.EnemyImpact, built by
-- tools/vfx_specs/EnemyImpact.luau (authored at radius 10 in neutral colours;
-- each emitter's `Role` attribute is painted here from the element palette).
--
--   Impact.ground(at, o)    a blow on the ground: Contact + Shock + Dust, and
--                           with o.scar / o.burst / o.rocks the heavier layers.
--                           o = { radius, element, palette?, look?, scar?,
--                           burst?, rocks?, contact? (default true), dust?
--                           (count factor, default 1), shake? (amount), reach?
--                           (shake radius, default radius + 50) }
--   Impact.explode(at, o)   a projectile or lobbed shot landing: Contact + Burst
--                           + a small Shock + Dust + Scar (o as above).
--   Impact.takeoff(at, o)   a jump leaving the ground: Shock (no contact
--                           flash) and Dust thrown out.
--   Impact.swipe(at, look, o)  a cone blow raking the ground: a dust fan along
--                           `look` and the contact flash.
--   Impact.roar(mouth, floor, o)  a normal wolf's howl: sound rings and breath
--                           from the jaws (mouth: CFrame, -Z out of the jaws),
--                           dust and grit blown forward off the ground.
--                           o = { element, scale?, seconds? }
--   Impact.skid(feet, look, o)  dust sprayed from planted feet while a body
--                           skids round (feet: { Vector3 } ground points,
--                           look: the way it was travelling). o = { element,
--                           scale?, seconds? (repeats over it) }
--   Impact.shot(o) -> handle  rides a projectile: o = { radius, element, core?
--                           (false: trail only, e.g. a boulder) }.
--                           handle.move(position, velocity), handle.stop()
--   Impact.shake(at, amount, reach)  camera shake falling off with the local
--                           character's distance from `at`.
--   Impact.floor(position, ignore)   ground under a point (skips characters,
--                           enemies, effects).
-- Elements: thunder, venom, fox, moon, earth (or o.palette, a table with any
-- of core, color, dark, dust, rock).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TechniqueVFX = require(script.Parent.Parent.TechniqueVFX)

export type Palette = { core: Color3, color: Color3, dark: Color3, dust: Color3, rock: Color3 }
export type Options = {
	radius: number?,
	element: string?,
	palette: { [string]: Color3 }?,
	look: CFrame?,
	scar: boolean?,
	burst: boolean?,
	rocks: boolean?,
	contact: boolean?,
	dust: number?,
	shake: number?,
	reach: number?,
	scale: number?,
	seconds: number?,
	core: boolean?,
}

local WHITE = Color3.new(1, 1, 1)
local AUTHORED = 10

local PALETTES: { [string]: Palette } = {
	thunder = {
		core = Color3.fromRGB(236, 250, 255),
		color = Color3.fromRGB(91, 216, 255),
		dark = Color3.fromRGB(27, 37, 71),
		dust = Color3.fromRGB(160, 162, 170),
		rock = Color3.fromRGB(88, 90, 98),
	},
	venom = {
		core = Color3.fromRGB(230, 255, 190),
		color = Color3.fromRGB(155, 255, 74),
		dark = Color3.fromRGB(20, 42, 20),
		dust = Color3.fromRGB(140, 128, 96),
		rock = Color3.fromRGB(82, 70, 52),
	},
	fox = {
		core = Color3.fromRGB(255, 244, 214),
		color = Color3.fromRGB(255, 196, 90),
		dark = Color3.fromRGB(34, 42, 58),
		dust = Color3.fromRGB(196, 184, 168),
		rock = Color3.fromRGB(96, 88, 80),
	},
	moon = {
		core = Color3.fromRGB(242, 248, 255),
		color = Color3.fromRGB(150, 200, 238),
		dark = Color3.fromRGB(30, 38, 54),
		dust = Color3.fromRGB(180, 174, 160),
		rock = Color3.fromRGB(96, 92, 86),
	},
	earth = {
		core = Color3.fromRGB(255, 246, 224),
		color = Color3.fromRGB(255, 214, 150),
		dark = Color3.fromRGB(40, 32, 26),
		dust = Color3.fromRGB(200, 184, 152),
		rock = Color3.fromRGB(110, 96, 78),
	},
}

local Impact = {}

local function paletteOf(o: Options?): Palette
	local base = PALETTES[(o and o.element) or "earth"] or PALETTES.earth
	local over = o and o.palette
	if not over then
		return base
	end
	return {
		core = over.core or base.core,
		color = over.color or base.color,
		dark = over.dark or base.dark,
		dust = over.dust or base.dust,
		rock = over.rock or base.rock,
	}
end

local function colorFor(role: string, p: Palette): ColorSequence?
	if role == "core" then
		return ColorSequence.new(WHITE, p.core)
	elseif role == "color" then
		return ColorSequence.new(p.core, p.color)
	elseif role == "dark" then
		return ColorSequence.new(p.dark)
	elseif role == "dust" then
		return ColorSequence.new(p.dust)
	elseif role == "rock" then
		return ColorSequence.new(p.rock)
	elseif role == "cool" then
		-- a burning crack: white-hot, the element, then cooling to dark
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE),
			ColorSequenceKeypoint.new(0.15, p.color),
			ColorSequenceKeypoint.new(1, p.dark),
		})
	end
	return nil
end

local function scaleSequence(sequence: NumberSequence, k: number): NumberSequence
	local points = {}
	for _, key in sequence.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(key.Time, key.Value * k, key.Envelope * k))
	end
	return NumberSequence.new(points)
end

local function scaleRange(range: NumberRange, k: number): NumberRange
	return NumberRange.new(range.Min * k, range.Max * k)
end

-- Paint every Role and scale sizes, speeds, offsets, waves and add-on radii by k;
-- multiply EmitCounts by `count`.
local function prepare(copy: BasePart, p: Palette, k: number, count: number)
	if math.abs(k - 1) > 1e-3 then
		copy.Size *= k
	end
	for _, d in copy:GetDescendants() do
		local role = d:GetAttribute("Role")
		local seq = if type(role) == "string" then colorFor(role, p) else nil
		if d:IsA("ParticleEmitter") then
			if seq then
				d.Color = seq
			end
			if math.abs(k - 1) > 1e-3 then
				d.Size = scaleSequence(d.Size, k)
				d.Speed = scaleRange(d.Speed, k)
				d.Acceleration *= k
			end
			local n = d:GetAttribute("EmitCount")
			if type(n) == "number" and math.abs(count - 1) > 1e-3 then
				d:SetAttribute("EmitCount", math.max(1, math.round(n * count)))
			end
		elseif d:IsA("Trail") then
			if seq then
				d.Color = seq
			end
		elseif d:IsA("Model") and d:GetAttribute("MeshWave") then
			local mesh = d:FindFirstChild("Mesh")
			if seq and mesh and mesh:IsA("BasePart") then
				mesh.Color = seq.Keypoints[#seq.Keypoints].Value
			end
			if math.abs(k - 1) > 1e-3 then
				for _, name in { "FromSize", "ToSize", "FromOffset", "ToOffset" } do
					local v = d:GetAttribute(name)
					if typeof(v) == "Vector3" then
						d:SetAttribute(name, v * k)
					end
				end
			end
		elseif d:IsA("Attachment") and math.abs(k - 1) > 1e-3 then
			d.Position *= k
			for _, name in { "Radius" } do
				local v = d:GetAttribute(name)
				if type(v) == "number" then
					d:SetAttribute(name, v * k)
				end
			end
			local size = d:GetAttribute("Size")
			if typeof(size) == "Vector3" then
				d:SetAttribute("Size", size * math.clamp(k, 0.6, 2.5))
			end
		end
	end
end

local function template(name: string): BasePart?
	local effects = ReplicatedStorage:FindFirstChild("Effects")
	local folder = effects and effects:FindFirstChild("EnemyImpact")
	local found = folder and folder:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

local function make(name: string, frame: CFrame, p: Palette, k: number, count: number?): BasePart?
	local base = template(name)
	if not base then
		return nil
	end
	local copy = base:Clone()
	prepare(copy, p, k, count or 1)
	copy.CFrame = frame
	return copy
end

local function play(name: string, frame: CFrame, p: Palette, k: number, count: number?): BasePart?
	local copy = make(name, frame, p, k, count)
	if not copy then
		return nil
	end
	copy.Parent = TechniqueVFX.folder
	TechniqueVFX.emit(copy)
	TechniqueVFX.cleanup(copy, 0.3)
	return copy
end

local function flatLook(look: Vector3?): CFrame
	if look then
		local f = Vector3.new(look.X, 0, look.Z)
		if f.Magnitude > 1e-3 then
			return CFrame.lookAt(Vector3.zero, f.Unit)
		end
	end
	return CFrame.Angles(0, math.random() * math.pi * 2, 0)
end

function Impact.floor(position: Vector3, ignore: { Instance }?): Vector3
	local exclude: { Instance } = {}
	for _, i in ignore or {} do
		table.insert(exclude, i)
	end
	local wilds = workspace:FindFirstChild("Wilds")
	local enemies = wilds and wilds:FindFirstChild("Enemies")
	if enemies then
		table.insert(exclude, enemies)
	end
	if workspace.CurrentCamera then
		table.insert(exclude, workspace.CurrentCamera)
	end
	table.insert(exclude, TechniqueVFX.folder)
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else position
end

-- Camera shake by distance: full `amount` at the impact, nothing past `reach`.
function Impact.shake(at: Vector3, amount: number, reach: number)
	if amount <= 0 or reach <= 0 then
		return
	end
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local from = if hrp and hrp:IsA("BasePart") then hrp.Position elseif workspace.CurrentCamera then workspace.CurrentCamera.CFrame.Position else nil
	if not from then
		return
	end
	local d = (from - at).Magnitude
	if d >= reach then
		return
	end
	local falloff = (1 - d / reach) ^ 1.5
	local ok, effects = pcall(require, script.Parent.Parent.CombatEffects)
	if ok then
		(effects :: any).shake(amount * falloff)
	end
end

local function rest(o: Options?): (Palette, number, number, CFrame)
	local radius = (o and o.radius) or AUTHORED
	return paletteOf(o), radius, radius / AUTHORED, flatLook(o and o.look and o.look.LookVector)
end

function Impact.ground(at: Vector3, o: Options?)
	local p, radius, k, face = rest(o)
	local base = CFrame.new(at + Vector3.new(0, 0.15, 0)) * face
	local dust = (o and o.dust) or 1
	-- big areas don't need proportionally huge puffs: dust grows slower than the ring
	local dk = k ^ 0.8
	play("Shock", base, p, k)
	play("Dust", base, p, dk, dust * math.clamp(k ^ 0.5, 0.6, 1.6))
	if not (o and o.contact == false) then
		play("Contact", CFrame.new(at + Vector3.new(0, radius * 0.2, 0)) * face, p, math.min(k, 1.6) ^ 0.8)
	end
	if o and o.burst then
		play("Burst", base, p, dk)
	end
	if o and o.scar then
		play("Scar", base, p, k)
	end
	if o and o.rocks and TechniqueVFX.full then
		play("Rocks", base, p, k)
	end
	if o and o.shake then
		Impact.shake(at, o.shake, o.reach or radius + 50)
	end
end

function Impact.explode(at: Vector3, o: Options?)
	local p, radius, k, face = rest(o)
	local base = CFrame.new(at + Vector3.new(0, 0.15, 0)) * face
	play("Contact", CFrame.new(at + Vector3.new(0, radius * 0.25, 0)) * face, p, k)
	play("Burst", base, p, k)
	play("Shock", base, p, k * 0.8)
	play("Dust", base, p, k, ((o and o.dust) or 1) * 0.7)
	if not (o and o.scar == false) then
		play("Scar", base, p, k * 0.8)
	end
	if o and o.rocks and TechniqueVFX.full then
		play("Rocks", base, p, k)
	end
	if o and o.shake then
		Impact.shake(at, o.shake, o.reach or radius + 45)
	end
end

function Impact.takeoff(at: Vector3, o: Options?)
	local p, _, k, face = rest(o)
	local base = CFrame.new(at + Vector3.new(0, 0.15, 0)) * face
	play("Shock", base, p, k * 0.8)
	play("Dust", base, p, k ^ 0.8, (o and o.dust) or 1)
	if o and o.shake then
		Impact.shake(at, o.shake, o.reach or (o.radius or AUTHORED) + 40)
	end
end

-- A cone blow raking the ground: dust fanned along `look` from `at` (the cone's
-- apex on the ground), the Skid spray scaled up, and the contact flash at the
-- middle of the cone.
function Impact.swipe(at: Vector3, look: Vector3, o: Options?)
	local p, radius, _, _ = rest(o)
	local face = flatLook(look)
	local k = math.max(1, radius / 8)
	for i, angle in { -0.5, 0, 0.5 } do
		local turn = face * CFrame.Angles(0, angle, 0)
		local spot = at + turn.LookVector * radius * 0.45
		task.delay((i - 1) * 0.04, function()
			play("Skid", CFrame.new(spot + Vector3.new(0, 0.15, 0)) * turn, p, k, 1.2)
		end)
	end
	play("Contact", CFrame.new(at + face.LookVector * radius * 0.5 + Vector3.new(0, radius * 0.15, 0)) * face, p, math.clamp(radius / 14, 0.5, 1.4))
	if o and o.shake then
		Impact.shake(at, o.shake, o.reach or radius + 40)
	end
end

function Impact.roar(mouth: CFrame, floor: Vector3, o: Options?)
	local p = paletteOf(o)
	local k = (o and o.scale) or 1
	local seconds = o and o.seconds
	local function fit(copy: BasePart)
		local authored = copy:GetAttribute("AuthoredSeconds")
		if not (seconds and type(authored) == "number" and authored > 0) then
			return
		end
		local f = math.clamp(seconds / authored, 0.6, 2)
		for _, d in copy:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				for _, name in { "EmitDelay", "EmitDuration" } do
					local v = d:GetAttribute(name)
					if type(v) == "number" and v > 0 then
						d:SetAttribute(name, v * f)
					end
				end
			end
		end
	end
	local rings = make("Roar", mouth, p, k)
	if rings then
		fit(rings)
		rings.Parent = TechniqueVFX.folder
		TechniqueVFX.emit(rings)
		TechniqueVFX.cleanup(rings, 0.3)
	end
	local look = flatLook(mouth.LookVector)
	local dust = make("RoarDust", CFrame.new(floor + Vector3.new(0, 0.15, 0) + look.LookVector * 1.5 * k) * look, p, k)
	if dust then
		fit(dust)
		dust.Parent = TechniqueVFX.folder
		TechniqueVFX.emit(dust)
		TechniqueVFX.cleanup(dust, 0.3)
	end
end

function Impact.skid(feet: { Vector3 }, look: Vector3, o: Options?)
	local p = paletteOf(o)
	local k = (o and o.scale) or 1
	local face = flatLook(look)
	local seconds = math.clamp((o and o.seconds) or 0.3, 0.1, 1)
	local bursts = math.clamp(math.round(seconds / 0.12), 1, 4)
	for i = 0, bursts - 1 do
		task.delay(i * seconds / bursts, function()
			for _, foot in feet do
				play("Skid", CFrame.new(foot + Vector3.new(0, 0.15, 0)) * face, p, k, if i == 0 then 1 else 0.6)
			end
		end)
	end
end

export type ShotHandle = { move: (Vector3, Vector3) -> (), stop: () -> () }

function Impact.shot(o: Options?): ShotHandle?
	local p = paletteOf(o)
	local radius = (o and o.radius) or 1
	local copy = make("Shot", CFrame.new(), p, radius)
	if not copy then
		return nil
	end
	if o and o.core == false then
		for _, name in { "Core", "Glint", "Halo", "Dark" } do
			local e = copy:FindFirstChild(name)
			if e then
				e:Destroy()
			end
		end
	end
	local placed = false
	local stopped = false
	return {
		move = function(position: Vector3, velocity: Vector3)
			if stopped then
				return
			end
			copy.CFrame = if velocity.Magnitude > 0.1 then CFrame.lookAt(position, position + velocity) else CFrame.new(position)
			if not placed then
				placed = true
				copy.Parent = TechniqueVFX.folder
				for _, d in copy:GetDescendants() do
					if d:IsA("ParticleEmitter") or d:IsA("Trail") then
						d.Enabled = true
					end
				end
			end
		end,
		stop = function()
			if stopped then
				return
			end
			stopped = true
			for _, d in copy:GetDescendants() do
				if d:IsA("ParticleEmitter") or d:IsA("Trail") then
					d.Enabled = false
				end
			end
			task.delay(0.5, function()
				copy:Destroy()
			end)
		end,
	}
end

return Impact
