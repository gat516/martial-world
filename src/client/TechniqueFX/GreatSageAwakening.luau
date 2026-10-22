--!strict
-- Great Sage Awakening from its tier templates (ReplicatedStorage.Effects.
-- GreatSageAwakening, built from tools/vfx_specs/GreatSageAwakening.luau).
--
-- The animation (117310636316384, a marked copy of 92849379287075; 1.75 s, staff): the staff is raised and
-- twirled flat over the head (~5 turns a second, 0.2-1.0 s, the spin is all
-- on the Hilt joint), then brought down so one end strikes the ground ~5
-- studs ahead at the hit (1.15-1.25) and sweeps on to the left.
--
-- windup() (cast start -> Hit; needs CombatEffects.windup to call it, see
-- the module table at the bottom): gold arcs of light trail both ends of the
-- spinning staff, a seal grows on the ground under the feet, motes rise into
-- the spinning disc, III+ a wind swirl climbs the body.
-- cast() (at Hit, caster and observers): the staff end slams the ground with
-- an impact; an awakening burst opens from the feet to def.radius (3D torus,
-- a pillar of gold light, dust), an impact on every enemy the front reaches;
-- then the buff aura holds on the caster for def.seconds: a golden circlet
-- round the head, gold flame wisps rising off the body, the staff leaving
-- gold arcs on every swing; II+ cloud puffs at the feet and motes, III+
-- fiery golden eyes, IV a turning halo behind the back and one soft light.
-- It ends with a puff when the buff runs out (or the caster dies).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local TechniqueVFX = require(Client.TechniqueVFX)
local CastFX = require(Client.CastFX)
local WeaponFX = require(script.Parent.WeaponFX)

local GreatSageAwakening = {}

-- Clip seconds, from the animation's markers (Skill_GreatSageAwakening,
-- 117310636316384): Twirl "start" 0.167, Twirl "end" 1.0, Hit 1.15, Hit Stop 1.25.
local DEFAULT_HIT = 1.15 -- when def.hits is missing
local HIT, TWIRL_START = 1.15, 0.167
local FADE_IN, FADE_OUT = 0.25, 0.45

-- Edit-mode previews set this to hold a frame (the driver stops moving parts).
GreatSageAwakening.frozen = false

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

-- Windup seconds (cast start -> the strike) from the live cast profile, else
-- from def.hits and def.castSpeed.
function GreatSageAwakening.windupSeconds(def: any): number
	local ok, phases = pcall(CastFX.phases, def)
	if ok and type(phases) == "table" and type(phases.windup) == "number" and phases.windup > 0 then
		return phases.windup
	end
	local t = DEFAULT_HIT
	if type(def.hits) == "table" and type(def.hits[1]) == "table" and type(def.hits[1].time) == "number" then
		t = def.hits[1].time
	end
	local speed = if type(def.castSpeed) == "number" and def.castSpeed > 0 then def.castSpeed else 1
	return t / speed
end

local function bone(character: Model, name: string): BasePart?
	local aliases = {
		Torso = { "Torso", "UpperTorso" },
		Head = { "Head" },
		HumanoidRootPart = { "HumanoidRootPart" },
		Feet = { "HumanoidRootPart" },
	}
	for _, n in aliases[name] or { name } do
		local p = character:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

-- The held weapon's ends: the `Tip` and `Base` attachments of the weapon
-- model (ServerStorage.WeaponModels contract), or nil without a weapon.
local function weaponEnds(character: Model?): (Attachment?, Attachment?)
	if not character then
		return nil, nil
	end
	local tip, base
	for _, d in character:GetDescendants() do
		if d:IsA("Attachment") then
			if d.Name == "Tip" and not tip then
				tip = d
			elseif d.Name == "butt" then
				base = d -- the staff's far end (Base is only the grip side of the head)
			elseif d.Name == "Base" and not base then
				base = d
			end
		end
	end
	return tip, base
end

-- Trails on both ends of the staff: each a ribbon from the end to a point a
-- little way in along the shaft. Returns a function that removes them.
local function staffTrails(character: Model?, source: Trail?): () -> ()
	local tip, base = weaponEnds(character)
	if not (source and tip and base) then
		return function() end
	end
	local made: { Instance } = {}
	local inward = math.min(num(source, "Inward", 1.4), (tip.WorldPosition - base.WorldPosition).Magnitude * 0.3)
	for _, pair in { { tip, base }, { base, tip } } do
		local e, other = pair[1], pair[2]
		local holder = e.Parent
		if not (holder and holder:IsA("BasePart")) then
			continue
		end
		local towards = (other.WorldPosition - e.WorldPosition)
		if towards.Magnitude < 0.1 then
			continue
		end
		local a0 = Instance.new("Attachment")
		a0.Name = "_GSA_Trail0"
		a0.Parent = holder
		a0.WorldPosition = e.WorldPosition
		local a1 = Instance.new("Attachment")
		a1.Name = "_GSA_Trail1"
		a1.Parent = holder
		a1.WorldPosition = e.WorldPosition + towards.Unit * inward
		local t = source:Clone()
		t.Attachment0, t.Attachment1 = a0, a1
		t.Enabled = true
		t.Parent = holder
		table.insert(made, a0)
		table.insert(made, a1)
		table.insert(made, t)
	end
	return function()
		for _, inst in made do
			if inst:IsA("Trail") then
				inst.Enabled = false
			end
		end
		task.delay(0.4, function()
			for _, inst in made do
				inst:Destroy()
			end
		end)
	end
end

-- Cast start -> Hit: the twirl. Played on the caster's client by
-- CombatEffects.windup when it hands off to this module; observers only see
-- it if the server relays the cast start (see the docs' known gaps).
function GreatSageAwakening.windup(CombatEffects: any, def: any, level: number, character: Model): boolean
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local template = TechniqueVFX.template(def.id, level)
	if not template then
		return false
	end
	local seconds = GreatSageAwakening.windupSeconds(def)
	-- motes and a dark-under-gold beam along the whole staff while it spins
	WeaponFX.charge(character, template:FindFirstChild("Charge"), seconds, true)
	local feet = CastFX.groundAt(root.Position)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	-- the ground seal and the rising motes, under the caster's feet
	local twirl = TechniqueVFX.part(def.id, level, "Twirl", CFrame.lookAt(feet, feet + look))
	-- the staff trails light at the animation's `Twirl "start"` marker and
	-- hold through the downswing to the strike, where the buff's arcs take over
	local stopTrails = function() end
	local stopped = false
	if twirl then
		TechniqueVFX.fit(twirl, nil, twirl:GetAttribute("AuthoredWindup") :: number?, seconds)
		local arc = twirl:FindFirstChild("Arc") :: Trail?
		task.delay(TWIRL_START / HIT * seconds, function()
			if not stopped then
				stopTrails = staffTrails(character, arc)
			end
		end)
		TechniqueVFX.emit(twirl)
		TechniqueVFX.cleanup(twirl)
	end
	-- qi into the right hand that holds the spin
	local function handAt(): CFrame
		local hand = CastFX.handPosition(character, def.hand or "Right")
		return if hand then CFrame.new(hand) else root.CFrame * CFrame.new(0, 2.5, -0.5)
	end
	local gather = TechniqueVFX.part(def.id, level, "Windup", handAt())
	if gather then
		TechniqueVFX.fit(gather, nil, gather:GetAttribute("AuthoredWindup") :: number?, seconds)
		TechniqueVFX.emit(gather)
		TechniqueVFX.cleanup(gather)
	end
	local started = os.clock()
	local follow
	follow = RunService.RenderStepped:Connect(function()
		if os.clock() - started > seconds or not root.Parent then
			follow:Disconnect()
			stopped = true
			stopTrails()
			return
		end
		if gather and gather.Parent then
			gather.CFrame = handAt()
		end
	end)
	return true
end

type Held = { part: BasePart, bone: BasePart, offset: CFrame, show: number, spin: number, pulse: number }

-- The buff aura on the caster for `seconds`: emitters moved onto the body,
-- held MeshParts (circlet, halo) driven on the body every frame.
-- `auraPart`, `fade` and `staff` are taken off the template before it is
-- emitted (the aura's emitters run on Rate, not EmitCount).
local function aura(auraPart: BasePart, fade: BasePart?, staff: BasePart?, character: Model, seconds: number)
	local arc = staff and staff:FindFirstChild("BuffArc") :: Trail?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local moved: { Instance } = {}
	local emitters: { ParticleEmitter } = {}
	local held: { Held } = {}
	local lights: { PointLight } = {}
	for _, child in auraPart:GetChildren() do
		local boneName = child:GetAttribute("Bone")
		local target = if type(boneName) == "string" then bone(character, boneName) else nil
		if not target then
			continue
		end
		if child:IsA("Attachment") then
			child.Parent = target
			table.insert(moved, child)
		elseif child:IsA("ParticleEmitter") then
			-- volume emitters fill the body part itself
			child.Parent = target
			table.insert(moved, child)
		elseif child:IsA("BasePart") then
			local offset = child:GetAttribute("Offset")
			table.insert(held, {
				part = child,
				bone = target,
				offset = if typeof(offset) == "CFrame" then offset else CFrame.identity,
				show = num(child, "Show", 0.2),
				spin = math.rad(num(child, "Spin", 0)),
				pulse = num(child, "Pulse", 0),
			})
			child.Transparency = 1
			child.Parent = TechniqueVFX.folder
		end
	end
	for _, inst in moved do
		local list = inst:GetDescendants()
		table.insert(list, inst)
		for _, d in list do
			if d:IsA("ParticleEmitter") then
				table.insert(emitters, d)
				d.Enabled = true
			elseif d:IsA("PointLight") then
				table.insert(lights, d)
			end
		end
	end
	for _, h in held do
		TweenService:Create(h.part, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = h.show }):Play()
	end
	for _, l in lights do
		local goal = l.Brightness
		l.Brightness = goal * 3
		TweenService:Create(l, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = goal }):Play()
	end
	local stopTrails = staffTrails(character, arc)

	local started = os.clock()
	local done = false
	local driver: RBXScriptConnection
	local function finish(burst: boolean)
		if done then
			return
		end
		done = true
		driver:Disconnect()
		stopTrails()
		for _, e in emitters do
			e.Enabled = false
		end
		for _, h in held do
			TweenService:Create(h.part, TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		end
		for _, l in lights do
			TweenService:Create(l, TweenInfo.new(FADE_OUT), { Brightness = 0 }):Play()
		end
		local root = bone(character, "HumanoidRootPart")
		if burst and fade and root and root.Parent then
			TechniqueVFX.burstAt(fade, root.CFrame)
		end
		task.delay(1.2, function()
			for _, inst in moved do
				inst:Destroy()
			end
			for _, h in held do
				h.part:Destroy()
			end
			auraPart:Destroy()
			for _, p in { fade, staff } do
				if p then
					p:Destroy()
				end
			end
		end)
	end
	driver = RunService.Heartbeat:Connect(function()
		if not character.Parent or (humanoid and humanoid.Health <= 0) then
			finish(false)
			return
		end
		if GreatSageAwakening.frozen then
			return
		end
		local t = os.clock() - started
		if t >= seconds then
			finish(true)
			return
		end
		for _, h in held do
			if not h.bone.Parent then
				continue
			end
			local cf = h.bone.CFrame * h.offset * CFrame.Angles(0, h.spin * t, 0)
			h.part.CFrame = cf
			if h.pulse > 0 and t > FADE_IN then
				h.part.Transparency = h.show + h.pulse * (0.5 + 0.5 * math.sin(t * 4))
			end
		end
	end)
end

function GreatSageAwakening.cast(CombatEffects: any, def: any, level: number, character: Model?, origin: Vector3, dir: Vector3): boolean
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, 0, -1)
	local ground = CastFX.groundAt(origin)
	local copy, tier = TechniqueVFX.spawn(def.id, level, CFrame.lookAt(ground, ground + dir))
	if not copy then
		return false
	end
	local radius = if type(def.radius) == "number" then def.radius else 8
	local seconds = if type(def.seconds) == "number" then def.seconds else 8
	local authored = num(copy, "AuthoredRadius", 8)
	local scale = radius / authored
	for _, name in { "Windup", "Twirl" } do
		local p = TechniqueVFX.take(copy, name)
		if p then
			p:Destroy() -- played at cast start (windup)
		end
	end
	local impact = TechniqueVFX.take(copy, "Impact")
	local auraPart = TechniqueVFX.take(copy, "Aura")
	local fade = TechniqueVFX.take(copy, "Fade")
	local staff = TechniqueVFX.take(copy, "Staff")

	-- the staff end that struck (the one furthest forward: the staff whips
	-- through the strike, so the lower end flips within a few frames), else
	-- the authored spot ~5 studs ahead
	local slam = copy:FindFirstChild("Slam") :: BasePart?
	if slam then
		local tip, base = weaponEnds(character)
		local at = ground + dir * 4.8
		if tip and base then
			local function ahead(p: Vector3): number
				return (p - origin):Dot(dir)
			end
			local low = if ahead(tip.WorldPosition) > ahead(base.WorldPosition) then tip.WorldPosition else base.WorldPosition
			local flat = Vector3.new(low.X - origin.X, 0, low.Z - origin.Z)
			if flat.Magnitude > 1 and flat.Magnitude < 9 then
				at = Vector3.new(low.X, 0, low.Z)
			end
		end
		local floor = CastFX.groundAt(Vector3.new(at.X, origin.Y, at.Z))
		slam.CFrame = CFrame.lookAt(floor + Vector3.new(0, 0.15, 0), floor + Vector3.new(0, 0.15, 0) + dir)
	end
	-- the awakening flash on the body
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local bodyPart = copy:FindFirstChild("Body") :: BasePart?
	if bodyPart then
		local at = if root then root.Position else origin
		bodyPart.CFrame = CFrame.lookAt(at, at + dir)
	end
	-- the ground torus rolls out to the def's radius; the rock ring follows
	local wave = copy:FindFirstChild("GroundWave", true)
	if wave then
		local size = wave:GetAttribute("ToSize")
		if typeof(size) == "Vector3" then
			wave:SetAttribute("ToSize", Vector3.new(radius * 2, size.Y, radius * 2))
		end
	end
	local rocks = copy:FindFirstChild("RockRing", true)
	if rocks then
		rocks:SetAttribute("Radius", radius)
	end
	CastFX.keepCratersOffEnemies()
	TechniqueVFX.rescale(copy, scale)
	TechniqueVFX.emit(copy)
	local light = bodyPart and bodyPart:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = 3
		TweenService:Create(light, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	end
	if not TechniqueVFX.full and CastFX.nearCamera(origin, 45) then
		CombatEffects.shake((CombatEffects.SHAKE_BY_TIER[tier] or 0.2) * 0.8)
	end

	-- impacts: every enemy inside the radius as the front reaches it
	local front = copy:FindFirstChild("WaveFront", true)
	if impact then
		local targets = CastFX.targets({ kind = "circle", origin = origin, dir = dir, radius = radius, character = character })
		for _, target in targets do
			local arrival = if front and front:IsA("ParticleEmitter") then CastFX.frontTime(front, target.progress) else 0.1 * target.progress
			local travel = if front and front:IsA("ParticleEmitter") then front.Lifetime.Max else 0.1
			-- squeezed into the strike's Hit -> Hit Stop (the damage number shows at Hit)
			task.delay(WeaponFX.landing(arrival, travel, WeaponFX.hitWindow(def, 1)), function()
				CastFX.impactAt(impact, target, { Kick = 3, Quake = 1 })
				if target.model.Parent then
					CombatEffects.flash(target.model)
				end
			end)
		end
		task.delay(1, function()
			impact:Destroy()
		end)
	end

	-- the buff: the aura holds on the caster for def.seconds
	if character and auraPart then
		aura(auraPart, fade, staff, character, seconds)
	else
		for _, p in { auraPart, fade, staff } do
			if p then
				p:Destroy()
			end
		end
	end
	TechniqueVFX.cleanup(copy, 0.3)
	return true
end

return GreatSageAwakening
