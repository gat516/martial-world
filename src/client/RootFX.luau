--!strict
-- The spirit root reveal pillar (Effect "root", fired to everyone by
-- src/server/Roots.luau as (player, element, grade, first)). On a reveal a
-- column of the element's colour shoots from the Testing Stone into the sky and
-- fades (~3 s), with the element's own accent (embers, droplets, leaves, glints,
-- rock motes, arcs, wind swirls, frost); rare roots (Roots.Elements[].rare) go
-- taller and add a ground shockwave, a burst and ring in the sky and a brief
-- tint of the sky for anyone nearby. A re-touch (`first` false) only glows on
-- the stone. Grade makes the column a little thicker and brighter.
--
-- Template: ReplicatedStorage.Effects.RootPillar (builder and layout notes in
-- tools/vfx_specs/RootPillar.luau). Played through TechniqueVFX (Game Module
-- emit, MeshWaves, plain-emitter fallback); the column itself is tweened here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Roots = require(ReplicatedStorage.Shared.Roots)
local TechniqueVFX = require(script.Parent.TechniqueVFX)

local RootFX = {}

-- Where clones go (this client only). Edit-mode previews point it at a
-- workspace folder, since screen captures swap the camera.
RootFX.folder = workspace.CurrentCamera :: Instance
-- The template's parent (ReplicatedStorage.Effects); previews may point it at staging.
RootFX.source = nil :: Instance?
-- The column's clock; previews swap it to hold a moment for a capture.
RootFX.now = os.clock

local FAR = 1200 -- beyond this the camera doesn't draw it at all
local FLASH_RANGE = 250 -- rare roots tint the sky for cameras this close
local WHITE = Color3.new(1, 1, 1)
local LINGER = 5.3 -- seconds before a reveal clone is destroyed
local GLIMPSE_LINGER = 2
local CORE_MIX = 0.55 -- core colour: element colour mixed this far toward white
local DEEP_SAT = 1.6 -- deep colour (sheath, shaft, sky): saturation boost, so pale roots still tint

-- Grade steps: column width, core/sheath brightness, accent counts.
local GRADES = {
	Spirit = { width = 1, bright = 0, count = 1 },
	Earth = { width = 1.15, bright = 0.06, count = 1.2 },
	Heaven = { width = 1.3, bright = 0.12, count = 1.4 },
}

local function template(): Instance?
	local source = RootFX.source or ReplicatedStorage:FindFirstChild("Effects")
	return source and source:FindFirstChild("RootPillar")
end

-- The stone's top centre, or the player's feet when the stone isn't there.
local function originOf(who: Player?): CFrame?
	local hub = workspace:FindFirstChild("Hub")
	local stone = hub and hub:FindFirstChild("TestingStone")
	if stone then
		local origin = stone:FindFirstChild("PillarOrigin", true)
		if origin and origin:IsA("Attachment") then
			return CFrame.new(origin.WorldPosition)
		end
	end
	local character = who and who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		return CFrame.new(root.Position - Vector3.new(0, 3, 0))
	end
	return nil
end

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function tint(root: Instance, color: Color3)
	local core = color:Lerp(WHITE, CORE_MIX)
	local h, sat, v = color:ToHSV()
	local deep = Color3.fromHSV(h, math.min(1, sat * DEEP_SAT + 0.08), v)
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in list do
		local which = d:GetAttribute("Tint")
		if which ~= "color" and which ~= "core" and which ~= "deep" then
			continue
		end
		local c = if which == "core" then core elseif which == "deep" then deep else color
		if d:IsA("BasePart") then
			d.Color = c
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			(d :: any).Color = ColorSequence.new(c)
		end
	end
end

-- More accent particles at higher grades (EmitCount bursts and Rate streams
-- marked `Scaled`).
local function scaleCounts(root: Instance, k: number)
	if math.abs(k - 1) < 1e-3 then
		return
	end
	for _, d in root:GetDescendants() do
		if not d:IsA("ParticleEmitter") then
			continue
		end
		local count = d:GetAttribute("EmitCount")
		if type(count) == "number" then
			d:SetAttribute("EmitCount", math.round(count * k))
		end
		if d:GetAttribute("Scaled") and d.Rate > 0 then
			d.Rate *= k
		end
	end
end

local function place(model: Instance, at: CFrame)
	if model:IsA("Model") then
		model:PivotTo(at)
	end
end

-- Destroys `inst` after `seconds` on RootFX.now (so previews can hold a moment).
local function expire(inst: Instance, seconds: number)
	local t0 = RootFX.now()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not inst.Parent or RootFX.now() - t0 >= seconds then
			conn:Disconnect()
			inst:Destroy()
		end
	end)
end

local function glimpse(proto: Instance, at: CFrame, color: Color3)
	local source = proto:FindFirstChild("Glimpse")
	if not source then
		return
	end
	local copy = source:Clone() :: Model
	tint(copy, color)
	copy.WorldPivot = CFrame.new()
	place(copy, at)
	copy.Parent = RootFX.folder
	TechniqueVFX.emit(copy)
	expire(copy, GLIMPSE_LINGER)
end

-- A brief sky tint for nearby cameras (rare roots only).
local function skyFlash(at: Vector3, color: Color3)
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - at).Magnitude > FLASH_RANGE then
		return
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.TintColor = WHITE:Lerp(color, 0.35)
	grade.Brightness = 0.08
	grade.Parent = game:GetService("Lighting")
	TweenService:Create(grade, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TintColor = WHITE,
		Brightness = 0,
	}):Play()
	Debris:AddItem(grade, 0.8)
end

local function reveal(proto: Instance, at: CFrame, def: Roots.Element, gradeName: string)
	local grade = GRADES[gradeName] or GRADES.Spirit
	local height = if def.rare then num(proto, "RareHeight", 210) else num(proto, "Height", 120)
	local rise = num(proto, "Rise", 0.45)
	local hold = num(proto, "Hold", 1.5) + (if def.rare then 0.4 else 0)
	local fade = num(proto, "Fade", 1.1)
	local widthK = num(proto, "Width", 1) * grade.width * (if def.rare then 1.2 else 1)

	local effect = Instance.new("Model")
	effect.Name = "RootPillar_" .. def.id
	local pillar = (proto :: any).Pillar:Clone() :: Model
	pillar.Parent = effect
	local accent = proto:FindFirstChild("Accents") and (proto :: any).Accents:FindFirstChild(def.id)
	if accent then
		accent:Clone().Parent = pillar
	end
	if def.rare and proto:FindFirstChild("Rare") then
		(proto :: any).Rare:Clone().Parent = effect
	end
	tint(effect, def.color)
	scaleCounts(effect, grade.count)
	-- the top pieces (crown glow, sky burst) sit where the column ends
	for _, d in effect:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Top") then
			d.CFrame = CFrame.new(0, height, 0)
		end
	end
	effect.WorldPivot = CFrame.new()
	effect:PivotTo(at)

	local column = (pillar :: any).Column :: BasePart
	local sheath = (pillar :: any).Sheath :: BasePart
	local base = (pillar :: any).Base :: BasePart
	local shaft = base:FindFirstChild("Shaft") :: Beam?
	local top = base:FindFirstChild("A1") :: Attachment?
	local columnWidth, sheathWidth = column.Size.Y * widthK, sheath.Size.Y * widthK
	local columnFade = math.max(0, num(column, "Fade", 0.05) - grade.bright)
	local sheathFade = math.max(0, num(sheath, "Fade", 0.72) - grade.bright)
	local shaftSeq = shaft and shaft.Transparency
	local shaftW0, shaftW1 = 0, 0
	if shaft then
		shaftW0, shaftW1 = shaft.Width0 * widthK, shaft.Width1 * widthK
		shaft.Enabled = true
	end

	local function set(h: number, w: number, alpha: number)
		h = math.max(h, 0.05)
		column.Size = Vector3.new(h, columnWidth * w, columnWidth * w)
		column.CFrame = at * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		column.Transparency = 1 - (1 - columnFade) * alpha
		sheath.Size = Vector3.new(h, sheathWidth * (0.6 + 0.4 * w), sheathWidth * (0.6 + 0.4 * w))
		sheath.CFrame = column.CFrame
		sheath.Transparency = 1 - (1 - sheathFade) * alpha
		if shaft and top and shaftSeq then
			top.Position = Vector3.new(0, h, 0)
			shaft.Width0, shaft.Width1 = shaftW0 * w, shaftW1 * w
			local kps = {}
			for _, k in shaftSeq.Keypoints do
				table.insert(kps, NumberSequenceKeypoint.new(k.Time, 1 - (1 - k.Value) * alpha))
			end
			shaft.Transparency = NumberSequence.new(kps)
		end
	end
	set(0.05, 1, 0)
	effect.Parent = RootFX.folder

	TechniqueVFX.emit(effect)
	if def.rare then
		task.delay(rise, skyFlash, at.Position + Vector3.new(0, height * 0.5, 0), def.color)
	end

	-- rise (fast, eased out), hold with a slow breathing, then thin and fade
	local t0 = RootFX.now()
	local total = rise + hold + fade
	local linger = math.max(total, LINGER) -- streams run ~2 s, their particles live up to ~2.8 s
	local done = false
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = RootFX.now() - t0
		if t >= linger or not effect.Parent then
			conn:Disconnect()
			effect:Destroy()
			return
		end
		if t >= total then
			if not done then
				done = true
				column.Transparency, sheath.Transparency = 1, 1
				if shaft then
					shaft.Enabled = false
				end
			end
		elseif t < rise then
			local k = t / rise
			local eased = 1 - (1 - k) ^ 4
			set(height * eased, 1 + 0.25 * (1 - k), math.min(1, k * 3))
		elseif t < rise + hold then
			local breathe = 1 + 0.06 * math.sin((t - rise) * 9)
			set(height, breathe, 1)
		else
			local k = (t - rise - hold) / fade
			set(height * (1 + 0.15 * k), 1 - 0.85 * k, (1 - k) ^ 2)
		end
	end)
end

-- Plays the reveal (or the re-touch glow) for `who`. Exposed for previews.
function RootFX.play(who: Player?, element: string, gradeName: string, first: boolean, at: CFrame?)
	local def = Roots.Elements[element]
	local proto = template()
	local origin = at or originOf(who)
	if not (def and proto and origin) then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - origin.Position).Magnitude > FAR then
		return
	end
	if first then
		reveal(proto, origin, def, gradeName)
	else
		glimpse(proto, origin, def.color)
	end
end

function RootFX.init()
	(ReplicatedStorage.Remotes.Effect :: RemoteEvent).OnClientEvent:Connect(function(kind: string, ...)
		if kind ~= "root" then
			return
		end
		local who, element, gradeName, first = ...
		RootFX.play(who, element, gradeName, first == true)
	end)
end

return RootFX
