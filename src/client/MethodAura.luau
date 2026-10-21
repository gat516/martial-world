--!strict
-- Cultivation method auras: while a player is seated (player attribute
-- `Meditating`, which covers circulation too) with a method active (`Method`,
-- nil = Sect Breathing, which has none), every client draws that method's
-- element aura around them. One shared template tinted with the element's
-- colour (Roots.Elements[].color) plus the element's accent:
--   Fire flame lotus and embers, Water a water ring and ripples, Wood a leaf
--   lotus and falling leaves, Metal orbiting needles and glints, Earth floating
--   stones and dust; rare (Lightning, Wind, Ice) add a wider second halo and
--   breath ring: a crackling ring, counter-turning swirls, a frost lotus and snow.
-- Every aura has a breathing ground halo, qi motes and a ring that rises from
-- the ground to the head on each breath. It fades in and out, swaps when the
-- method changes while seated, and goes with the character.
--
-- Template: ReplicatedStorage.Effects.MethodAura (builder and attribute notes in
-- tools/vfx_specs/MethodAura.luau). Emitters loop through TechniqueVFX.enable
-- (Game Module or plain fallback); the 3D pieces (halo, petals, rings, needles,
-- stones) are animated here from their Pulse/Spin/Bob/Tumble/Flicker attributes.
-- Mobile: auras draw only within RANGE of the camera, nearest MAX_AURAS first.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Methods = require(ReplicatedStorage.Shared.Methods)
local Roots = require(ReplicatedStorage.Shared.Roots)
local TechniqueVFX = require(script.Parent.TechniqueVFX)

local MethodAura = {}

-- Where clones go (this client only); previews point it at a workspace folder.
MethodAura.folder = workspace.CurrentCamera :: Instance
-- The template's parent (ReplicatedStorage.Effects); previews may point it at staging.
MethodAura.source = nil :: Instance?
-- The aura clock; previews swap it to hold a moment for a capture.
MethodAura.now = os.clock

local RANGE = 140 -- studs from the camera
local MAX_AURAS = 8 -- nearest seated players drawn at once
local REFRESH = 1 -- seconds between range checks
local LINGER = 5 -- seconds a stopped aura keeps its particles before it's destroyed
local REGROUND = 0.5 -- seconds between ground checks under a seated player
local CORE_MIX = 0.55
local DEEP_SAT = 1.6
local WHITE = Color3.new(1, 1, 1)

-- Method grade: more motes, brighter 3D. All starters are Mortal today; the
-- higher grades are the hook for stronger methods (and later a small extra
-- effect of their own, e.g. a ring that heals allies meditating nearby).
local GRADES: { [string]: { rate: number, glow: number } } = {
	Mortal = { rate = 1, glow = 0 },
	Spirit = { rate = 1.25, glow = 0.06 },
	Earth = { rate = 1.5, glow = 0.12 },
	Heaven = { rate = 1.8, glow = 0.18 },
}

type Anim = {
	part: BasePart,
	rel: CFrame,
	lo: number,
	hi: number,
	spin: number,
	bob: number,
	tumble: number,
	flicker: number,
	phase: number,
}

type Aura = {
	key: any,
	method: string,
	root: BasePart,
	model: Model,
	anims: { Anim },
	breaths: { BasePart },
	period: number,
	fadeIn: number,
	fadeOut: number,
	alpha: number,
	on: boolean,
	t0: number,
	nextBreath: number,
	nextGround: number,
	at: Vector3?,
	pivot: CFrame,
	stoppedAt: number?,
}

local auras: { [any]: Aura } = {} -- live, by Player (or a preview key)
local dying: { Aura } = {}

local function template(): Instance?
	local source = MethodAura.source or ReplicatedStorage:FindFirstChild("Effects")
	return source and source:FindFirstChild("MethodAura")
end

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function tint(root: Instance, color: Color3)
	local core = color:Lerp(WHITE, CORE_MIX)
	local h, sat, v = color:ToHSV()
	local deep = Color3.fromHSV(h, math.min(1, sat * DEEP_SAT + 0.08), v)
	for _, d in root:GetDescendants() do
		local which = d:GetAttribute("Tint")
		if which ~= "color" and which ~= "core" and which ~= "deep" then
			continue
		end
		local c = if which == "core" then core elseif which == "deep" then deep else color
		if d:IsA("BasePart") then
			d.Color = c
		elseif d:IsA("ParticleEmitter") then
			d.Color = ColorSequence.new(c)
		end
	end
end

-- The method's aura model at the origin (identity pivot), or nil.
local function build(proto: Instance, def: Methods.Def): Model?
	local element = Roots.Elements[def.element]
	local accents = proto:FindFirstChild("Accents")
	local accent = accents and accents:FindFirstChild(def.element)
	local base = proto:FindFirstChild("Base")
	if not (element and accent and base) then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "MethodAura_" .. def.id
	base:Clone().Parent = model
	if element.rare and proto:FindFirstChild("Rare") then
		(proto :: any).Rare:Clone().Parent = model
	end
	for _, shared in { "Lotus", "Orbit" } do
		local piece = proto:FindFirstChild(shared)
		if piece and accent:GetAttribute(shared) then
			local copy = piece:Clone()
			-- an element can make a shared piece flicker (lightning's ring)
			local flicker = accent:GetAttribute("Flicker")
			if type(flicker) == "number" then
				for _, d in copy:GetDescendants() do
					if d:IsA("BasePart") then
						d:SetAttribute("Flicker", flicker)
					end
				end
			end
			copy.Parent = model
		end
	end
	accent:Clone().Parent = model
	tint(model, element.color)
	model.WorldPivot = CFrame.new()
	return model
end

local function anims(model: Model, glow: number): { Anim }
	local list = {}
	for i, d in model:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local pulse = d:GetAttribute("Pulse")
		if typeof(pulse) ~= "NumberRange" then
			continue
		end
		table.insert(list, {
			part = d,
			rel = d.CFrame,
			lo = math.max(0, pulse.Min - glow),
			hi = math.max(0, pulse.Max - glow),
			spin = math.rad(num(d, "Spin", 0)),
			bob = num(d, "Bob", 0),
			tumble = math.rad(num(d, "Tumble", 0)),
			flicker = num(d, "Flicker", 0),
			phase = i * 1.7,
		})
		d.Transparency = 1
	end
	return list
end

local function scaleRates(model: Model, k: number)
	if math.abs(k - 1) < 1e-3 then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") and d:GetAttribute("Scaled") then
			d.Rate *= k
		end
	end
end

-- The ground under a seated root (characters excluded), or below the hips.
local function groundAt(root: BasePart): Vector3
	local ignore: { Instance } = { MethodAura.folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	if root.Parent then
		table.insert(ignore, root.Parent)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	if hit then
		return hit.Position
	end
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	return root.Position - Vector3.new(0, hip + root.Size.Y / 2, 0)
end

local function placeAura(aura: Aura)
	local ground = groundAt(aura.root)
	local look = aura.root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	aura.pivot = CFrame.new(ground + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, yaw, 0)
	aura.at = aura.root.Position
	aura.model:PivotTo(aura.pivot)
end

local function start(key: any, root: BasePart, methodId: string): Aura?
	local def = Methods.Defs[methodId]
	local proto = template()
	if not (def and proto and def.element ~= "") then
		return nil
	end
	local model = build(proto, def)
	if not model then
		return nil
	end
	local grade = GRADES[def.grade] or GRADES.Mortal
	scaleRates(model, grade.rate)
	local now = MethodAura.now()
	local breaths = {}
	for _, d in model:GetDescendants() do
		if d.Name == "Breath" and d:IsA("BasePart") then
			table.insert(breaths, d)
		end
	end
	local aura: Aura = {
		key = key,
		method = methodId,
		root = root,
		model = model,
		anims = anims(model, grade.glow),
		breaths = breaths,
		period = math.max(1, num(proto, "Breath", 5)),
		fadeIn = math.max(0.05, num(proto, "FadeIn", 1.2)),
		fadeOut = math.max(0.05, num(proto, "FadeOut", 1)),
		alpha = 0,
		on = true,
		t0 = now,
		nextBreath = now + 0.6, -- the first breath once the halo is half in
		nextGround = now + REGROUND,
		at = nil,
		pivot = CFrame.new(),
	}
	placeAura(aura)
	model.Parent = MethodAura.folder
	TechniqueVFX.enable(model)
	auras[key] = aura
	return aura
end

local function stop(key: any)
	local aura = auras[key]
	if not aura then
		return
	end
	auras[key] = nil
	aura.on = false
	aura.stoppedAt = MethodAura.now()
	TechniqueVFX.disable(aura.model)
	table.insert(dying, aura)
end

local function step(aura: Aura, now: number, dt: number, parts: { BasePart }, frames: { CFrame })
	if aura.on then
		aura.alpha = math.min(1, aura.alpha + dt / aura.fadeIn)
		if now >= aura.nextGround then
			aura.nextGround = now + REGROUND
			local at = aura.at
			if aura.root.Parent and (not at or (aura.root.Position - at).Magnitude > 0.3) then
				placeAura(aura)
			end
		end
		if now >= aura.nextBreath then
			aura.nextBreath = now + aura.period
			for _, b in aura.breaths do
				TechniqueVFX.emit(b)
			end
		end
	else
		aura.alpha = math.max(0, aura.alpha - dt / aura.fadeOut)
	end
	local t = now - aura.t0
	-- 0 at the start of each breath (brightest, as the ring leaves), 1 halfway
	local b = 0.5 - 0.5 * math.cos(2 * math.pi * ((now - aura.nextBreath) / aura.period))
	local a = aura.alpha
	for _, anim in aura.anims do
		local cf = aura.pivot
		if anim.spin ~= 0 then
			cf *= CFrame.Angles(0, anim.spin * t, 0)
		end
		if anim.bob ~= 0 then
			cf *= CFrame.new(0, anim.bob * math.sin(t * 1.3 + anim.phase), 0)
		end
		cf *= anim.rel
		if anim.tumble ~= 0 then
			cf *= CFrame.Angles(anim.tumble * t, anim.tumble * 0.7 * t, 0)
		end
		table.insert(parts, anim.part)
		table.insert(frames, cf)
		local tr = anim.lo + (anim.hi - anim.lo) * b
		if anim.flicker > 0 then
			tr = math.min(1, tr + anim.flicker * math.random())
		end
		anim.part.Transparency = 1 - (1 - tr) * a
	end
end

local function frame(dt: number)
	local now = MethodAura.now()
	local parts, frames = {}, {}
	for _, aura in auras do
		step(aura, now, dt, parts, frames)
	end
	for i = #dying, 1, -1 do
		local aura = dying[i]
		step(aura, now, dt, parts, frames)
		if now - (aura.stoppedAt or now) >= LINGER then
			aura.model:Destroy()
			table.remove(dying, i)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- The method a player's aura should show, or nil.
local function wanted(player: Player): (string?, BasePart?)
	if player:GetAttribute("Meditating") ~= true then
		return nil, nil
	end
	local method = player:GetAttribute("Method")
	if type(method) ~= "string" or not Methods.Defs[method] then
		return nil, nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
		return nil, nil
	end
	return method, root
end

local function refresh()
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local list = {}
	for _, player in Players:GetPlayers() do
		local method, root = wanted(player)
		if method and root then
			local d = (root.Position - eye).Magnitude
			if d <= RANGE then
				table.insert(list, { player = player, method = method, root = root, d = d })
			end
		end
	end
	table.sort(list, function(x, y)
		return x.d < y.d
	end)
	local keep: { [Player]: boolean } = {}
	for i, w in list do
		if i > MAX_AURAS then
			break
		end
		keep[w.player] = true
		local aura = auras[w.player]
		if aura and (aura.method ~= w.method or aura.root ~= w.root) then
			stop(w.player) -- method switched or respawned: fade the old one out
			aura = nil
		end
		if not aura then
			start(w.player, w.root, w.method)
		end
	end
	for key in auras do
		if typeof(key) == "Instance" and key:IsA("Player") and not keep[key] then
			stop(key)
		end
	end
end

-- Previews (Edit mode, no players): an aura on a stand-in rig under `key`.
function MethodAura.preview(key: any, root: BasePart, methodId: string)
	stop(key)
	return start(key, root, methodId)
end

function MethodAura.stopPreview(key: any)
	stop(key)
end

-- Steps every aura once (previews drive this when Heartbeat isn't wanted).
MethodAura.step = frame

function MethodAura.init()
	RunService.Heartbeat:Connect(frame)
	local function watch(player: Player)
		player:GetAttributeChangedSignal("Meditating"):Connect(refresh)
		player:GetAttributeChangedSignal("Method"):Connect(refresh)
		player.CharacterRemoving:Connect(function()
			stop(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(stop)
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH)
		end
	end)
end

return MethodAura
