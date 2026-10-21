--!strict
-- Cultivation method auras: while a player is seated (player attribute
-- `Meditating`, which covers circulation too), every client draws the aura of
-- that player's method (`Method`; nil or "" = Sect Breathing, which has only a
-- faint mote on the breath). Each method has its own aura, built from its idea
-- (art brief: docs/systems/auras.md), living on the body first:
--   Blazing Heart   a white-hot heart that beats (lub-dub) on the breath, a
--                   flame mantle hugging the silhouette from behind, flames
--                   licking off the arms and torso, soot and embers, a fire
--                   swirl and a turning hui-wen sigil on the ground
--   Flowing Spring  a pool under you that ripples each breath, a pearl of
--                   water at the belly fed by streams of qi, a water ring
--                   turning round the figure; now and then a drop falls in
--   Evergreen Root  green meridian branches growing from the belly out along
--                   the arms over a few breaths, roots on the ground, leaves
--   Iron Marrow     a white-gold diamond between the hands under a small halo
--                   of rays, gold bones, a spiked iron ring; each exhale a
--                   clang (a spiky ring snaps out, sparks), now and then a
--                   heavier blow
--   Mountain Breath an amber low core, a carved rune ring under you that
--                   settles with each breath, slow lifting pebbles, dust
--   Thunder Pulse   dark, with violet cracks across the torso and arms that
--                   flare in irregular bursts, arcs from the hands to the ground
--   Drifting Cloud  a cloud you sit on, wind rings spiralling in on the inhale
--   Frost Lotus     a frost lotus opening a petal ring per breath, a rime
--                   outline, breath mist, flakes
-- Every aura breathes on one shared period (Thunder Pulse bursts instead).
-- Sitting down, switching method and breaking through play the method's
-- Ignite surge before it settles into its loop.
--
-- Template: ReplicatedStorage.Effects.MethodAura, one Model per method id
-- (builder and the full attribute contract in tools/vfx_specs/MethodAura.luau):
--   Ground  parts placed on the ground under the player (pivot, +Y up)
--   Body    parts with a `Point` attribute, following that body point
--   Limbs   ParticleEmitters cloned onto body parts named by `On`
--   Lines   Beams between body points (`From`/`To`), optionally jagged, dotted
--   Shell   a part copied round every body part (a translucent glowing skin:
--           the outline/body glow; Highlights aren't used because the map
--           already has hundreds and Roblox draws only 31)
--   Breath / Ignite  one-shot models
-- Parts animate from Pulse/Spin/Bob/Tumble/Turn/Flicker/Grow/Lift/Delay. Loop
-- emitters play through TechniqueVFX.enable (Game Module or plain fallback);
-- emitters breathe (`Breathe`), start primed (`Prime`) and swell (`Swell`).
-- Mobile: auras draw only within RANGE of the camera, nearest MAX_AURAS first
-- (named methods before Sect Breathing). Works on R6 and R15 (POINTS / LIMBS).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Methods = require(ReplicatedStorage.Shared.Methods)
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
local IGNITE = 1.8 -- seconds the ignition surge takes to settle
local FRESH = 2 -- an aura starting this soon after Meditating/Method changed ignites
-- Sitting down ignites when the player is all the way down: when the
-- Meditate.Sit track (1.6 s, no markers) is within SEAT_BLEND of its end (the
-- moment Meditation.luau fades into Loop), or Loop is already playing (a method
-- switch while seated ignites at once). SEAT_TIMEOUT covers a track that never
-- replicates.
local SEAT_BLEND = 0.2 -- Meditation.luau's BLEND
local SEAT_TIMEOUT = 2.6
local PUNCH = 1.2 -- seconds a pulse's surge takes to settle
local BURST_GAP = NumberRange.new(0.5, 2.6) -- "burst" rhythm: seconds between bursts
local BURST_DECAY = 0.16 -- seconds for a burst to fall to ~37%
local KICK = 0.3 -- seconds for a breath's kick (Kick attributes: a clang's glint) to fall to ~37%

-- Method grade sets how far the aura reaches, not its look. All starters are
-- Mortal today; Spirit and up only widen the ground pieces and add motes until
-- their own pieces (backdrop, manifestation) are built (auras.md, grade scale).
local GRADES: { [string]: { reach: number, rate: number, glow: number } } = {
	Mortal = { reach = 1, rate = 1, glow = 0 },
	Spirit = { reach = 1.8, rate = 1.3, glow = 0.06 },
	Earth = { reach = 3, rate = 1.6, glow = 0.12 },
	Heaven = { reach = 4.5, rate = 2, glow = 0.18 },
}

-- Body points: [name] = { R6 part, offset as a fraction of its size, R15 part, fraction }.
local V = Vector3.new
local POINTS: { [string]: { any } } = {
	Head = { "Head", V(0, 0, 0), "Head", V(0, 0, 0) },
	Crown = { "Head", V(0, 0.5, 0), "Head", V(0, 0.5, 0) },
	Mouth = { "Head", V(0, -0.2, -0.5), "Head", V(0, -0.2, -0.5) },
	Neck = { "Torso", V(0, 0.5, 0), "UpperTorso", V(0, 0.5, 0) },
	Chest = { "Torso", V(0, 0.22, -0.5), "UpperTorso", V(0, 0.1, -0.5) },
	ChestL = { "Torso", V(-0.3, 0.32, -0.5), "UpperTorso", V(-0.3, 0.25, -0.5) },
	ChestR = { "Torso", V(0.3, 0.32, -0.5), "UpperTorso", V(0.3, 0.25, -0.5) },
	Belly = { "Torso", V(0, -0.28, -0.5), "LowerTorso", V(0, 0, -0.5) },
	SideL = { "Torso", V(-0.45, -0.3, -0.5), "LowerTorso", V(-0.45, 0, -0.5) },
	SideR = { "Torso", V(0.45, -0.3, -0.5), "LowerTorso", V(0.45, 0, -0.5) },
	Dantian = { "Torso", V(0, -0.3, 0), "LowerTorso", V(0, 0, 0) },
	LShoulder = { "Left Arm", V(0, 0.4, 0), "LeftUpperArm", V(0, 0.35, 0) },
	RShoulder = { "Right Arm", V(0, 0.4, 0), "RightUpperArm", V(0, 0.35, 0) },
	LElbow = { "Left Arm", V(0, 0, 0), "LeftLowerArm", V(0, 0.4, 0) },
	RElbow = { "Right Arm", V(0, 0, 0), "RightLowerArm", V(0, 0.4, 0) },
	LHand = { "Left Arm", V(0, -0.45, 0), "LeftHand", V(0, 0, 0) },
	RHand = { "Right Arm", V(0, -0.45, 0), "RightHand", V(0, 0, 0) },
	LHip = { "Left Leg", V(0, 0.4, 0), "LeftUpperLeg", V(0, 0.4, 0) },
	RHip = { "Right Leg", V(0, 0.4, 0), "RightUpperLeg", V(0, 0.4, 0) },
	LKnee = { "Left Leg", V(0, 0, 0), "LeftLowerLeg", V(0, 0.4, 0) },
	RKnee = { "Right Leg", V(0, 0, 0), "RightLowerLeg", V(0, 0.4, 0) },
	LFoot = { "Left Leg", V(0, -0.45, 0), "LeftFoot", V(0, 0, 0) },
	RFoot = { "Right Leg", V(0, -0.45, 0), "RightFoot", V(0, 0, 0) },
}
-- Limb groups for Limbs emitters (`On` = "Arms,Torso"): R6 parts, R15 parts.
local LIMBS: { [string]: { { string } } } = {
	Head = { { "Head" }, { "Head" } },
	Torso = { { "Torso" }, { "UpperTorso", "LowerTorso" } },
	Arms = { { "Left Arm", "Right Arm" }, { "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" } },
	Hands = { { "Left Arm", "Right Arm" }, { "LeftHand", "RightHand" } },
	Legs = { { "Left Leg", "Right Leg" }, { "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" } },
}

type Piece = {
	part: BasePart,
	rel: CFrame,
	size: Vector3,
	point: string?,
	body: BasePart?,
	pulsed: boolean,
	lo: number,
	hi: number,
	spin: number,
	bob: number,
	tumble: number,
	turn: number,
	flicker: number,
	grow: NumberRange?,
	growIn: boolean,
	kick: number,
	hidden: boolean,
	images: { ImageLabel },
	lift: number,
	rise: number,
	risePeriod: number,
	delay: number,
	phase: number,
	light: PointLight?,
	lightBase: number,
}

type Line = {
	beams: { Beam },
	shape: NumberSequence,
	lo: number,
	hi: number,
	flicker: number,
	kick: number,
	delay: number,
	jag: number,
	a0: Attachment,
	a1: Attachment,
	mids: { Attachment },
	dots: { ImageLabel },
}

-- An emitter whose rate follows the breath: `Breathe = true` (the old curve,
-- faster on the inhale) or a NumberRange `lo..hi` rate multiplier at rest..peak.
type Breather = { emitter: ParticleEmitter, rate: number, lo: number?, hi: number? }

-- An emitter whose Size breathes (`Swell`: fraction at the breath's peak,
-- `Drift`: a slow wander), e.g. a heart core, flames, a mantle, a ground swirl.
type Sweller = { emitter: ParticleEmitter, size: NumberSequence, swell: number, drift: number, phase: number }

type Aura = {
	key: any,
	method: string,
	root: BasePart,
	character: Model,
	model: Model,
	pieces: { Piece },
	lines: { Line },
	breathers: { Breather },
	swellers: { Sweller },
	punch: Model?,
	punchEvery: NumberRange?,
	punchJitter: number,
	punchSwell: number,
	punchIn: number,
	punching: boolean,
	punchDue: number?,
	punchedAt: number,
	waiting: boolean,
	sawSit: boolean,
	breathAt: number,
	kickedAt: number,
	limbEmitters: { ParticleEmitter },
	owned: { Instance }, -- attachments / emitters put on the character, destroyed with the aura
	points: { [string]: Attachment },
	breath: Model?,
	ignite: Model?,
	burst: boolean,
	period: number,
	fadeIn: number,
	fadeOut: number,
	alpha: number,
	on: boolean,
	t0: number,
	lastPhase: number,
	nextBurst: number,
	lastBurst: number,
	ignitedAt: number,
	nextGround: number,
	at: Vector3?,
	pivot: CFrame,
	yaw: CFrame,
	stoppedAt: number?,
}

local auras: { [any]: Aura } = {} -- live, by Player (or a preview key)
local dying: { Aura } = {}
local changed: { [Player]: number } = {} -- when Meditating/Method last changed
local satAt: { [Player]: number } = {} -- when Meditating last changed (a sit-down)

local function template(): Instance?
	local source = MethodAura.source or ReplicatedStorage:FindFirstChild("Effects")
	return source and source:FindFirstChild("MethodAura")
end

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function isR15(character: Model): boolean
	return character:FindFirstChild("UpperTorso") ~= nil
end

-- The attachment for a named body point (made once per aura), or an
-- Attachment of that name inside the aura model (ground anchors).
local function pointAttachment(aura: Aura, name: string): Attachment?
	local existing = aura.points[name]
	if existing then
		return existing
	end
	local spec = POINTS[name]
	if spec then
		local r15 = isR15(aura.character)
		local body = aura.character:FindFirstChild(if r15 then spec[3] else spec[1])
		if not (body and body:IsA("BasePart")) then
			body = aura.character:FindFirstChild(if r15 then "UpperTorso" else "Torso")
		end
		if body and body:IsA("BasePart") then
			local a = Instance.new("Attachment")
			a.Name = "Aura_" .. name
			a.Position = body.Size * (if r15 then spec[4] else spec[2])
			a.Parent = body
			table.insert(aura.owned, a)
			aura.points[name] = a
			return a
		end
		return nil
	end
	for _, d in aura.model:GetDescendants() do
		if d.Name == name and d:IsA("Attachment") then
			aura.points[name] = d
			return d
		end
	end
	return nil
end

-- World position of a body point ("Lap" = between the hands).
local function pointAt(aura: Aura, name: string): Vector3
	if name == "Lap" then
		local l, r = pointAttachment(aura, "LHand"), pointAttachment(aura, "RHand")
		if l and r then
			return (l.WorldPosition + r.WorldPosition) / 2 + Vector3.new(0, 0.25, 0)
		end
		name = "Belly"
	end
	local a = pointAttachment(aura, name)
	return if a then a.WorldPosition else aura.root.Position
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
	aura.yaw = CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
	aura.pivot = CFrame.new(ground + Vector3.new(0, 0.05, 0)) * aura.yaw
	aura.at = aura.root.Position
	aura.model:PivotTo(aura.pivot)
end

local function pieceOf(part: BasePart, index: number, glow: number): Piece
	local pulse = part:GetAttribute("Pulse")
	local grow = part:GetAttribute("Grow")
	local point = part:GetAttribute("Point")
	local light = part:FindFirstChildOfClass("PointLight")
	local pulsed = typeof(pulse) == "NumberRange"
	if pulsed then
		part.Transparency = 1
	end
	-- a SurfaceGui image (rune, frost) breathes with the part; the part may stay hidden
	local images = {}
	for _, d in part:GetDescendants() do
		if d:IsA("ImageLabel") then
			d.ImageTransparency = 1
			table.insert(images, d)
		end
	end
	return {
		part = part,
		rel = part.CFrame,
		size = part.Size,
		point = if type(point) == "string" then point else nil,
		body = nil,
		pulsed = pulsed,
		lo = if pulsed then math.max(0, (pulse :: NumberRange).Min - glow) else 1,
		hi = if pulsed then math.max(0, (pulse :: NumberRange).Max - glow) else 1,
		spin = math.rad(num(part, "Spin", 0)),
		bob = num(part, "Bob", 0),
		tumble = math.rad(num(part, "Tumble", 0)),
		turn = math.rad(num(part, "Turn", 0)),
		flicker = num(part, "Flicker", 0),
		grow = if typeof(grow) == "NumberRange" then grow else nil,
		growIn = part:GetAttribute("GrowIn") == true,
		kick = num(part, "Kick", 0),
		hidden = part:GetAttribute("Hidden") == true,
		images = images,
		lift = num(part, "Lift", 0),
		rise = num(part, "Rise", 0),
		risePeriod = math.max(0.5, num(part, "RisePeriod", 6)),
		delay = num(part, "Delay", 0),
		phase = index * 1.7,
		light = light,
		lightBase = if light then light.Brightness else 0,
	}
end

local function addBreather(aura: Aura, e: ParticleEmitter)
	local breathe = e:GetAttribute("Breathe")
	if typeof(breathe) == "NumberRange" then
		table.insert(aura.breathers, { emitter = e, rate = e.Rate, lo = breathe.Min, hi = breathe.Max })
	elseif breathe then
		table.insert(aura.breathers, { emitter = e, rate = e.Rate })
	end
end

local function addSweller(aura: Aura, e: ParticleEmitter)
	local swell, drift = num(e, "Swell", 0), num(e, "Drift", 0)
	if swell ~= 0 or drift ~= 0 then
		table.insert(aura.swellers, { emitter = e, size = e.Size, swell = swell, drift = drift, phase = math.random() * 2 * math.pi })
	end
end

-- Ground and Body parts that move or breathe (Body parts always follow).
local function collectPieces(aura: Aura, glow: number)
	local index = 0
	for _, groupName in { "Ground", "Body" } do
		local group = aura.model:FindFirstChild(groupName)
		if not group then
			continue
		end
		for _, d in group:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				addBreather(aura, d)
				addSweller(aura, d)
			end
			if not d:IsA("BasePart") then
				continue
			end
			index += 1
			local piece = pieceOf(d, index, glow)
			local moves = piece.point or piece.pulsed or #piece.images > 0 or piece.spin ~= 0 or piece.bob ~= 0 or piece.tumble ~= 0
				or piece.turn ~= 0 or piece.grow or piece.lift ~= 0 or piece.rise ~= 0
			if moves then
				table.insert(aura.pieces, piece)
			end
		end
	end
end

-- Shells (children named Shell*): one copy per body part, a little larger
-- (`Pad` studs), following it.
local SHELL_GROUPS = { "Head", "Torso", "Arms", "Legs" }
local function collectShell(aura: Aura, glow: number)
	local r15 = isR15(aura.character)
	for _, shell in aura.model:GetChildren() do
		if not (shell:IsA("BasePart") and string.sub(shell.Name, 1, 5) == "Shell") then
			continue
		end
		local pad = num(shell, "Pad", 0.25)
		local holder = Instance.new("Model")
		holder.Name = shell.Name .. "s"
		holder.Parent = aura.model
		for _, group in SHELL_GROUPS do
			for _, partName in LIMBS[group][if r15 then 2 else 1] do
				local body = aura.character:FindFirstChild(partName)
				if not (body and body:IsA("BasePart")) then
					continue
				end
				local copy = shell:Clone()
				copy.Name = partName
				local size = body.Size
				if partName == "Head" then
					-- heads are drawn smaller than their box (R6 mesh): a round shell
					local d = math.min(size.Y, size.Z) * 1.25 + pad
					copy.Shape = Enum.PartType.Ball
					size = Vector3.new(d, d, d)
				else
					size += Vector3.new(pad, pad, pad)
				end
				copy.Size = size
				copy.CFrame = body.CFrame
				copy.Parent = holder
				local piece = pieceOf(copy, #aura.pieces + 1, glow)
				piece.rel = CFrame.identity
				piece.body = body
				table.insert(aura.pieces, piece)
			end
		end
		shell:Destroy()
	end
end

local function makeDot(aura: Aura, at: Attachment, size: number, color: Color3, image: string): ImageLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "AuraDot"
	gui.Size = UDim2.fromScale(size, size)
	gui.StudsOffset = Vector3.new(0, 0, 0.75) -- camera space: drawn just in front of the limb
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Adornee = at
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Image = image
	label.ImageColor3 = color
	label.ImageTransparency = 1
	label.Parent = gui
	gui.Parent = aura.model
	return label
end

local function rejag(line: Line)
	if line.jag <= 0 or #line.mids == 0 then
		return
	end
	local from, to = line.a0.WorldPosition, line.a1.WorldPosition
	local n = #line.mids + 1
	for i, mid in line.mids do
		local off = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * line.jag
		mid.WorldPosition = from:Lerp(to, i / n) + off
	end
end

local function collectLines(aura: Aura, glow: number)
	local folder = aura.model:FindFirstChild("Lines")
	if not folder then
		return
	end
	local dotted: { [Attachment]: boolean } = {}
	for _, beam in folder:GetChildren() do
		if not beam:IsA("Beam") then
			continue
		end
		local from, to = beam:GetAttribute("From"), beam:GetAttribute("To")
		local a0 = type(from) == "string" and pointAttachment(aura, from)
		local a1 = type(to) == "string" and pointAttachment(aura, to)
		if not (a0 and a1) then
			continue
		end
		local pulse = beam:GetAttribute("Pulse")
		local lo = if typeof(pulse) == "NumberRange" then pulse.Min else 0
		local hi = if typeof(pulse) == "NumberRange" then pulse.Max else 0
		local line: Line = {
			beams = {},
			shape = beam.Transparency,
			lo = math.max(0, lo - glow),
			hi = math.max(0, hi - glow),
			flicker = num(beam, "Flicker", 0),
			kick = num(beam, "Kick", 0),
			delay = num(beam, "Delay", 0),
			jag = num(beam, "Jag", 0),
			a0 = a0,
			a1 = a1,
			mids = {},
			dots = {},
		}
		-- a jagged line is a chain of beams through mid attachments on a0's part
		local segs = math.max(1, math.floor(num(beam, "Segs", 1)))
		local chain = { a0 }
		local holder = a0.Parent
		if segs > 1 and holder and holder:IsA("BasePart") then
			for i = 1, segs - 1 do
				local mid = Instance.new("Attachment")
				mid.Name = "Aura_Mid"
				mid.Parent = holder
				table.insert(aura.owned, mid)
				table.insert(line.mids, mid)
				table.insert(chain, mid)
			end
		end
		table.insert(chain, a1)
		for i = 1, #chain - 1 do
			local b = beam:Clone()
			b.Attachment0, b.Attachment1 = chain[i], chain[i + 1]
			b.Enabled = true
			b.Transparency = NumberSequence.new(1)
			b.Parent = aura.model
			table.insert(line.beams, b)
		end
		local dot = beam:GetAttribute("Dots")
		local image = beam:GetAttribute("DotImage")
		local dotColor = beam:GetAttribute("DotColor")
		local color = if typeof(dotColor) == "Color3" then dotColor else beam.Color.Keypoints[1].Value
		beam:Destroy()
		rejag(line)
		if type(dot) == "number" and dot > 0 then
			for _, a in { a0, a1 } do
				if not dotted[a] then
					dotted[a] = true
					table.insert(line.dots, makeDot(aura, a, dot, color, if type(image) == "string" then image else "rbxassetid://9841273544"))
				end
			end
		end
		table.insert(aura.lines, line)
	end
end

local function collectLimbs(aura: Aura)
	local folder = aura.model:FindFirstChild("Limbs")
	if not folder then
		return
	end
	local r15 = isR15(aura.character)
	for _, e in folder:GetChildren() do
		if not e:IsA("ParticleEmitter") then
			continue
		end
		local on = e:GetAttribute("On")
		for group in string.gmatch(if type(on) == "string" then on else "Torso", "[^,%s]+") do
			local names = LIMBS[group]
			for _, partName in (if names then names[if r15 then 2 else 1] else {}) do
				local body = aura.character:FindFirstChild(partName)
				if body and body:IsA("BasePart") then
					local copy = e:Clone()
					copy.Name = "Aura_" .. e.Name
					copy.Enabled = false -- activate() lights them
					copy.Parent = body
					table.insert(aura.owned, copy)
					table.insert(aura.limbEmitters, copy)
					addBreather(aura, copy)
					addSweller(aura, copy)
				end
			end
		end
	end
	folder:Destroy()
end

local function scaleRates(model: Instance, k: number)
	if math.abs(k - 1) < 1e-3 then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") and d:GetAttribute("Scaled") then
			d.Rate *= k
		end
	end
end

-- Moves a one-shot model's Point holders onto their body points, then emits it.
local function fire(aura: Aura, model: Model?)
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local point = d:GetAttribute("Point")
			if type(point) == "string" then
				local rel = d:GetAttribute("Rel")
				d.CFrame = CFrame.new(pointAt(aura, point)) * aura.yaw * (if typeof(rel) == "CFrame" then rel else CFrame.identity)
			end
		end
	end
	TechniqueVFX.emit(model)
end

local function exhale(aura: Aura)
	aura.kickedAt = MethodAura.now()
	fire(aura, aura.breath)
end

local function surgeLimbs(aura: Aura, attribute: string)
	for _, e in aura.limbEmitters do
		local n = e:GetAttribute(attribute)
		if type(n) == "number" and n > 0 then
			e:Emit(n)
		end
	end
end

local function ignite(aura: Aura)
	aura.ignitedAt = MethodAura.now()
	fire(aura, aura.ignite)
	surgeLimbs(aura, "Surge")
end

-- Breaths until the next pulse (the method's `PunchEvery` range, whole breaths).
local function rollPunch(aura: Aura): number
	local every = aura.punchEvery
	if not every then
		return math.huge
	end
	return math.random(math.max(1, math.floor(every.Min)), math.max(1, math.floor(every.Max)))
end

-- A pulse: a lighter ignition (`Punch` model, limb `PunchSurge`) on the beat.
local function punch(aura: Aura)
	local now = MethodAura.now()
	aura.punchedAt = now
	aura.kickedAt = now
	fire(aura, aura.punch)
	surgeLimbs(aura, "PunchSurge")
end

-- Lights the loop: Ground/Body emitters on (primed), limb emitters on.
local function activate(aura: Aura)
	for _, groupName in { "Ground", "Body" } do
		local group = aura.model:FindFirstChild(groupName)
		if group then
			TechniqueVFX.enable(group)
			-- `Prime = n`: slow loops (a ground sigil every few seconds) start
			-- with n particles instead of waiting out their first interval
			for _, d in group:GetDescendants() do
				local prime = d:GetAttribute("Prime")
				if d:IsA("ParticleEmitter") and type(prime) == "number" and prime > 0 then
					d:Emit(prime)
				end
			end
		end
	end
	for _, e in aura.limbEmitters do
		e.Enabled = true
	end
end

local sitIds: { Sit: string, Loop: string }? = nil
local function meditateIds(): { Sit: string, Loop: string }
	if not sitIds then
		local folder = ReplicatedStorage:FindFirstChild("Animations")
		folder = folder and folder:FindFirstChild("Meditate")
		local sit = folder and folder:FindFirstChild("Sit")
		local loop = folder and folder:FindFirstChild("Loop")
		sitIds = {
			Sit = if sit and sit:IsA("Animation") then sit.AnimationId else "",
			Loop = if loop and loop:IsA("Animation") then loop.AnimationId else "",
		}
	end
	return sitIds :: any
end

-- Is the character all the way down (see SEAT_BLEND)?
local function seated(aura: Aura, now: number): boolean
	if now - aura.t0 >= SEAT_TIMEOUT then
		return true
	end
	local humanoid = aura.character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return true
	end
	local ids = meditateIds()
	local sitting = false
	for _, track in animator:GetPlayingAnimationTracks() do
		local id = track.Animation and track.Animation.AnimationId
		if id == ids.Loop and ids.Loop ~= "" then
			return true
		elseif id == ids.Sit and ids.Sit ~= "" then
			aura.sawSit = true
			if track.Length > 0 and track.TimePosition >= track.Length - SEAT_BLEND then
				return true
			end
			sitting = true
		end
	end
	return aura.sawSit and not sitting
end

-- `fresh` ignites; `waitSeat` holds the whole aura (and its ignition) until
-- the player is all the way down (a sit-down, not a method switch).
local function start(key: any, root: BasePart, methodId: string, fresh: boolean, waitSeat: boolean?): Aura?
	local def = Methods.Defs[methodId]
	local proto = template()
	local source = proto and proto:FindFirstChild(methodId)
	local character = root.Parent
	if not (def and proto and source and character and character:IsA("Model")) then
		return nil
	end
	local grade = GRADES[def.grade] or GRADES.Mortal
	local model = source:Clone() :: Model
	model.Name = "MethodAura_" .. methodId
	model.WorldPivot = CFrame.new()
	local ground = model:FindFirstChild("Ground")
	if ground and ground:IsA("Model") and grade.reach ~= 1 then
		ground.WorldPivot = CFrame.new()
		ground:ScaleTo(grade.reach)
	end
	scaleRates(model, grade.rate)
	-- keep the one-shots aside so enabling the loop doesn't start their emitters
	local breath = model:FindFirstChild("Breath") :: Model?
	local burst = model:GetAttribute("Rhythm") == "burst"
	local now = MethodAura.now()
	local aura: Aura = {
		key = key,
		method = methodId,
		root = root,
		character = character,
		model = model,
		pieces = {},
		lines = {},
		breathers = {},
		swellers = {},
		punch = model:FindFirstChild("Punch") :: Model?,
		punchEvery = (function()
			local v = source:GetAttribute("PunchEvery")
			return if typeof(v) == "NumberRange" then v else nil
		end)(),
		punchJitter = num(source, "PunchJitter", 0),
		punchSwell = num(source, "PunchSwell", 1),
		punchIn = 0,
		punching = false,
		punchDue = nil,
		punchedAt = -math.huge,
		waiting = fresh and waitSeat == true,
		sawSit = false,
		breathAt = math.clamp(num(source, "BreathAt", 0.5), 0.01, 0.99),
		kickedAt = -math.huge,
		limbEmitters = {},
		owned = {},
		points = {},
		breath = breath,
		ignite = model:FindFirstChild("Ignite") :: Model?,
		burst = burst,
		period = math.max(1, num(proto, "Breath", 5)),
		fadeIn = math.max(0.05, num(proto, "FadeIn", 1.2)),
		fadeOut = math.max(0.05, num(proto, "FadeOut", 1)),
		alpha = 0,
		on = true,
		t0 = now,
		lastPhase = 0,
		nextBurst = now + 0.8,
		lastBurst = -math.huge,
		ignitedAt = -math.huge,
		nextGround = now + REGROUND,
		at = nil,
		pivot = CFrame.new(),
		yaw = CFrame.identity,
	}
	collectPieces(aura, grade.glow)
	collectShell(aura, grade.glow)
	collectLimbs(aura)
	placeAura(aura)
	model.Parent = MethodAura.folder
	collectLines(aura, grade.glow)
	aura.punchIn = rollPunch(aura)
	auras[key] = aura
	if not aura.waiting then
		activate(aura)
		if fresh then
			ignite(aura)
		end
	end
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
	for _, groupName in { "Ground", "Body" } do
		local group = aura.model:FindFirstChild(groupName)
		if group then
			TechniqueVFX.disable(group)
		end
	end
	for _, e in aura.limbEmitters do
		e.Enabled = false
	end
	table.insert(dying, aura)
end

local function destroy(aura: Aura)
	aura.model:Destroy()
	for _, inst in aura.owned do
		inst:Destroy()
	end
end

-- 0..1: the breath (inhale gathers to 1 at mid-breath, exhale releases) or,
-- for "burst" auras, a spike at each burst decaying fast.
local function energy(aura: Aura, now: number): number
	if aura.burst then
		if aura.on and now >= aura.nextBurst then
			aura.lastBurst = now
			aura.nextBurst = now + BURST_GAP.Min + math.random() * (BURST_GAP.Max - BURST_GAP.Min)
			for _, line in aura.lines do
				rejag(line)
			end
			if aura.alpha > 0.5 then
				exhale(aura)
			end
		end
		return math.exp(-(now - aura.lastBurst) / BURST_DECAY)
	end
	local phase = ((now - aura.t0) / aura.period) % 1
	local at = aura.breathAt
	if phase < aura.lastPhase then -- a new breath: is this one a pulse?
		aura.punchIn -= 1
		aura.punching = aura.punchIn <= 0
	end
	if aura.on and aura.lastPhase < at and phase >= at and aura.alpha > 0.5 then
		-- the breath's beat (the exhale's release unless BreathAt says otherwise);
		-- every `PunchEvery` breaths it is a pulse instead, up to `PunchJitter` late
		if aura.punching and aura.punch then
			aura.punchDue = now + math.random() * aura.punchJitter
			aura.punchIn = rollPunch(aura)
		else
			exhale(aura)
		end
	end
	local due = aura.punchDue
	if due and now >= due then
		aura.punchDue = nil
		punch(aura)
	end
	aura.lastPhase = phase
	return 0.5 - 0.5 * math.cos(2 * math.pi * phase)
end

local function ramp(aura: Aura, now: number, delay: number): number
	if delay <= 0 then
		return 1
	end
	return math.clamp((now - aura.t0 - delay) / aura.fadeIn, 0, 1)
end

local function step(aura: Aura, now: number, dt: number, parts: { BasePart }, frames: { CFrame })
	if aura.waiting then
		-- sitting down: nothing shows until the player is all the way down
		if not (aura.on and seated(aura, now)) then
			return
		end
		aura.waiting = false
		aura.t0 = now
		aura.lastPhase = 0
		aura.alpha = 0.35
		activate(aura)
		ignite(aura)
	end
	if aura.on then
		aura.alpha = math.min(1, aura.alpha + dt / aura.fadeIn)
		if now >= aura.nextGround then
			aura.nextGround = now + REGROUND
			local at = aura.at
			if aura.root.Parent and (not at or (aura.root.Position - at).Magnitude > 0.3) then
				placeAura(aura)
			end
		end
	else
		aura.alpha = math.max(0, aura.alpha - dt / aura.fadeOut)
	end
	local e = energy(aura, now)
	local s = math.clamp(1 - (now - aura.ignitedAt) / IGNITE, 0, 1)
	s = s * s
	local kick = math.exp(-(now - aura.kickedAt) / KICK)
	-- a pulse's surge (1 at the pulse, settling over PUNCH seconds)
	local pz = math.clamp(1 - (now - aura.punchedAt) / PUNCH, 0, 1)
	pz = pz * pz
	for _, b in aura.breathers do
		local lo, hi = b.lo, b.hi
		if lo and hi then
			b.emitter.Rate = b.rate * (lo + (hi - lo) * e) * (1 + 2 * s + 0.8 * pz)
		else
			b.emitter.Rate = b.rate * (0.2 + 1.3 * e + 2 * s)
		end
	end
	-- Swell/Drift emitters grow with the breath (more on a pulse's breath, so
	-- the aura swells into each pulse and eases back), the beat, the surges,
	-- and wander slowly so the size never sits still
	local grow = 1 + 0.6 * s + 0.15 * pz
	local amp = if aura.punching then aura.punchSwell else 1
	local tt = now - aura.t0
	for _, w in aura.swellers do
		local k = (1 + w.swell * amp * (e + 0.8 * kick) + w.drift * math.sin(tt * 0.45 + w.phase)) * grow
		local kps = {}
		for _, p in w.size.Keypoints do
			table.insert(kps, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
		end
		w.emitter.Size = NumberSequence.new(kps)
	end
	local t = now - aura.t0
	local a = aura.alpha
	local yaw = aura.yaw
	for _, piece in aura.pieces do
		local cf: CFrame
		local body = piece.body
		if body then
			cf = body.CFrame
		elseif piece.point then
			cf = CFrame.new(pointAt(aura, piece.point)) * yaw
		else
			cf = aura.pivot
		end
		if piece.spin ~= 0 then
			cf *= CFrame.Angles(0, piece.spin * t, 0)
		end
		local dy = piece.lift * e
		-- `Rise`: drifts up that far over `RisePeriod` seconds, fading in at the
		-- bottom and out at the top, then starts again (a layer replaced)
		local riseFade = 1
		if piece.rise ~= 0 then
			local u = ((t + piece.phase * piece.risePeriod) / piece.risePeriod) % 1
			dy += piece.rise * u
			riseFade = math.sin(math.pi * u)
		end
		if piece.bob ~= 0 then
			dy += piece.bob * math.sin(t * 1.3 + piece.phase)
		end
		if dy ~= 0 then
			cf *= CFrame.new(0, dy, 0)
		end
		cf *= piece.rel
		if piece.turn ~= 0 then -- spin in place about the upright axis
			local frame = if piece.point then yaw else aura.pivot.Rotation
			cf = CFrame.new(cf.Position) * frame * CFrame.Angles(0, piece.turn * t, 0) * piece.rel.Rotation
		end
		if piece.tumble ~= 0 then
			cf *= CFrame.Angles(piece.tumble * t, piece.tumble * 0.7 * t, 0)
		end
		table.insert(parts, piece.part)
		table.insert(frames, cf)
		local grow = piece.grow
		if grow then
			local g = if piece.growIn then 1 - e else e
			local k = (grow.Min + (grow.Max - grow.Min) * g) * (1 + 0.35 * s + 0.25 * piece.kick * kick + 0.12 * pz)
			piece.part.Size = piece.size * k
		end
		local on = a * ramp(aura, now, piece.delay) * riseFade
		if piece.pulsed then
			local op = 1 - (piece.hi - (piece.hi - piece.lo) * e)
			op = math.min(1, op * (1 + 1.5 * s) + (1 - op) * piece.kick * math.max(kick, pz))
			if piece.flicker > 0 then
				op *= 1 - piece.flicker * math.random()
			end
			if not piece.hidden then
				piece.part.Transparency = 1 - op * on
			end
			for _, image in piece.images do
				image.ImageTransparency = 1 - op * on
			end
		end
		if piece.light then
			piece.light.Brightness = piece.lightBase * on * (0.55 + 0.45 * e + 1.5 * s)
		end
	end
	for _, line in aura.lines do
		local op = 1 - (line.hi - (line.hi - line.lo) * e)
		op = math.min(1, op * (1 + 1.5 * s) + (1 - op) * line.kick * kick + 0.5 * s)
		if line.flicker > 0 then
			op *= 1 - line.flicker * math.random()
		end
		op *= a * ramp(aura, now, line.delay)
		local kps = {}
		for _, k in line.shape.Keypoints do
			table.insert(kps, NumberSequenceKeypoint.new(k.Time, 1 - (1 - k.Value) * op))
		end
		local seq = NumberSequence.new(kps)
		for _, b in line.beams do
			b.Transparency = seq
		end
		for _, dot in line.dots do
			dot.ImageTransparency = 1 - op
		end
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
			destroy(aura)
			table.remove(dying, i)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- The method a player's aura should show (Sect Breathing when none), or nil.
local function wanted(player: Player): (string?, BasePart?)
	if player:GetAttribute("Meditating") ~= true then
		return nil, nil
	end
	local method = player:GetAttribute("Method")
	if type(method) ~= "string" or not Methods.Defs[method] then
		method = Methods.BASIC
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
		return nil, nil
	end
	return method :: string, root
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
				-- named methods first: Sect Breathing's mote never takes a slot from one
				local rank = d + (if method == Methods.BASIC then RANGE * 2 else 0)
				table.insert(list, { player = player, method = method, root = root, d = rank })
			end
		end
	end
	table.sort(list, function(x, y)
		return x.d < y.d
	end)
	local keep: { [Player]: boolean } = {}
	local now = MethodAura.now()
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
			local fresh = now - (changed[w.player] or -math.huge) <= FRESH
			local sitting = now - (satAt[w.player] or -math.huge) <= FRESH
			start(w.player, w.root, w.method, fresh, sitting)
		end
	end
	for key in auras do
		if typeof(key) == "Instance" and key:IsA("Player") and not keep[key] then
			stop(key)
		end
	end
end

-- Previews (Edit mode, no players): an aura on a stand-in rig under `key`,
-- igniting at once unless `quiet`; `sitDown` waits for the rig's Sit track to
-- finish like a real sit-down.
function MethodAura.preview(key: any, root: BasePart, methodId: string, quiet: boolean?, sitDown: boolean?)
	stop(key)
	return start(key, root, methodId, not quiet, sitDown)
end

function MethodAura.stopPreview(key: any)
	stop(key)
end

-- Replays the ignition surge on a live aura (breakthroughs; previews).
function MethodAura.ignite(key: any)
	local aura = auras[key]
	if aura and not aura.waiting then -- a waiting aura ignites when seated anyway
		ignite(aura)
	end
end

-- Steps every aura once (previews drive this when Heartbeat isn't wanted).
MethodAura.step = frame

function MethodAura.init()
	RunService.Heartbeat:Connect(frame)
	local function watch(player: Player)
		local function mark()
			changed[player] = MethodAura.now()
			refresh()
		end
		player:GetAttributeChangedSignal("Meditating"):Connect(function()
			satAt[player] = MethodAura.now()
			mark()
		end)
		player:GetAttributeChangedSignal("Method"):Connect(mark)
		player.CharacterRemoving:Connect(function()
			stop(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		stop(player)
		changed[player] = nil
		satAt[player] = nil
	end)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local breakthrough = remotes and remotes:FindFirstChild("Breakthrough")
	if breakthrough and breakthrough:IsA("RemoteEvent") then
		breakthrough.OnClientEvent:Connect(function(who: Player)
			MethodAura.ignite(who)
		end)
	end
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH)
		end
	end)
end

return MethodAura
