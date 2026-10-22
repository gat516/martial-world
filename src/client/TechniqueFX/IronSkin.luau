--!strict
-- Iron Skin from its tier template (ReplicatedStorage.Effects.IronSkin, built
-- from tools/vfx_specs/IronSkin.luau). Called by CombatEffects.cast at Hit (the
-- caster's own and relayed casts alike); the windup stream is the template's
-- `Windup` part, played by CombatEffects.windup.
--
-- At Hit the golden bell snaps out round the body (flash, flare, ring, a gold
-- ground ring), then the plating holds for def.seconds: emitters moved onto the
-- body parts named by their `Bone` attribute (plate glints over soot, gleams
-- off the arms, a turning seal under the feet at III+, a halo over the head at
-- IV) and a pulsing ForceField shell (II+). It lets go with a ring and dust
-- (`Fade`), or stops at once if the caster dies.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local TechniqueVFX = require(Client.TechniqueVFX)
local CastFX = require(Client.CastFX)

local IronSkin = {}

local FADE_IN, FADE_OUT = 0.2, 0.4

local function bonePart(character: Model, name: string): BasePart?
	local aliases: { [string]: { string } } = { Torso = { "Torso", "UpperTorso" }, HumanoidRootPart = { "HumanoidRootPart" } }
	for _, n in aliases[name] or { name } do
		local p = character:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

function IronSkin.cast(CombatEffects: any, def: any, level: number, character: Model?, origin: Vector3, dir: Vector3): boolean
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, 0, -1)
	local ground = CastFX.groundAt(origin)
	local copy, tier = TechniqueVFX.spawn(def.id, level, CFrame.lookAt(ground, ground + dir))
	if not copy then
		return false
	end
	local seconds = if type(def.seconds) == "number" then def.seconds else 4
	local windup = TechniqueVFX.take(copy, "Windup")
	if windup then
		windup:Destroy() -- played at cast start (CombatEffects.windup)
	end
	local auraPart = TechniqueVFX.take(copy, "Aura")
	local fade = TechniqueVFX.take(copy, "Fade")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local body = copy:FindFirstChild("Body") :: BasePart?
	if body then
		local at = if root then root.Position else origin + Vector3.new(0, 3, 0)
		body.CFrame = CFrame.lookAt(at, at + dir)
	end
	-- the ground ring: authored at r 4, kept at the caster's feet
	TechniqueVFX.emit(copy)
	TechniqueVFX.cleanup(copy, 0.3)
	if not TechniqueVFX.full and CastFX.nearCamera(origin, 45) then
		CombatEffects.shake((CombatEffects.SHAKE_BY_TIER[tier] or 0.2) * 0.4)
	end
	if not (character and auraPart) then
		for _, p in { auraPart, fade } do
			if p then
				p:Destroy()
			end
		end
		return true
	end

	-- the plating: emitters and held parts go onto their bones
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local moved: { Instance } = {}
	local emitters: { ParticleEmitter } = {}
	local held: { { part: BasePart, bone: BasePart, offset: CFrame, show: number, pulse: number } } = {}
	for _, child in auraPart:GetChildren() do
		local boneName = child:GetAttribute("Bone")
		local target = if type(boneName) == "string" then bonePart(character, boneName) else nil
		if not target then
			continue
		end
		if child:IsA("Attachment") or child:IsA("ParticleEmitter") then
			child.Parent = target
			table.insert(moved, child)
		elseif child:IsA("BasePart") then
			local offset = child:GetAttribute("Offset")
			local show = child:GetAttribute("Show")
			local pulse = child:GetAttribute("Pulse")
			table.insert(held, {
				part = child, bone = target, offset = if typeof(offset) == "CFrame" then offset else CFrame.identity,
				show = if type(show) == "number" then show else 0.7, pulse = if type(pulse) == "number" then pulse else 0,
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
			end
		end
	end
	for _, h in held do
		TweenService:Create(h.part, TweenInfo.new(FADE_IN), { Transparency = h.show }):Play()
	end
	local started = os.clock()
	local done = false
	local driver: RBXScriptConnection
	local function finish(burst: boolean)
		if done then
			return
		end
		done = true
		driver:Disconnect()
		for _, e in emitters do
			e.Enabled = false
		end
		for _, h in held do
			TweenService:Create(h.part, TweenInfo.new(FADE_OUT), { Transparency = 1 }):Play()
		end
		local r = bonePart(character, "HumanoidRootPart")
		if burst and fade and r and r.Parent then
			TechniqueVFX.burstAt(fade, r.CFrame)
		end
		task.delay(2.5, function()
			for _, inst in moved do
				inst:Destroy()
			end
			for _, h in held do
				h.part:Destroy()
			end
			auraPart:Destroy()
			if fade then
				fade:Destroy()
			end
		end)
	end
	driver = RunService.Heartbeat:Connect(function()
		if not character.Parent or (humanoid and humanoid.Health <= 0) then
			finish(false)
			return
		end
		local t = os.clock() - started
		if t >= seconds then
			finish(true)
			return
		end
		for _, h in held do
			if h.bone.Parent then
				h.part.CFrame = h.bone.CFrame * h.offset
				if h.pulse > 0 and t > FADE_IN then
					h.part.Transparency = h.show + h.pulse * (0.5 + 0.5 * math.sin(t * 5))
				end
			end
		end
	end)
	return true
end

return IronSkin
