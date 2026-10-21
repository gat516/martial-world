--!strict
-- A small R6 eating gesture, layered after Animator on every observer.
-- Server-confirmed consumption only; the morsel survives inventory/tool removal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Items = require(ReplicatedStorage.Shared.Items)
local ActionState = require(script.Parent.ActionState)
local template = ReplicatedStorage:WaitForChild("HerbMorsel") :: Model
local HerbAnimator = {}

type Joint = { motor: Motor6D, original: CFrame? }
type Eating = {
	character: Model,
	humanoid: Humanoid,
	shoulder: Joint,
	neck: Joint?,
	started: number,
	prop: Model,
	hidden: { [BasePart]: number },
}
local active: { [Model]: Eating } = {}

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function restoreJoint(joint: Joint?)
	if joint and joint.original then
		if joint.motor.Parent then
			joint.motor.Transform = joint.original
		end
		joint.original = nil
	end
end

local function clear(eating: Eating)
	restoreJoint(eating.shoulder)
	restoreJoint(eating.neck)
	for part, transparency in eating.hidden do
		if part.Parent then
			part.LocalTransparencyModifier = transparency
		end
	end
	eating.prop:Destroy()
	active[eating.character] = nil
end

local function busy(character: Model, humanoid: Humanoid): boolean
	return humanoid:GetAttribute("ActionBusy") == true
		or (character == Players.LocalPlayer.Character and ActionState.phase() ~= "free")
end

local function play(character: Model, id: string, started: number)
	if not character or not character:IsDescendantOf(workspace) then return end
	local item = Items.Defs[id]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = character:FindFirstChild("Torso")
	local shoulder = torso and torso:FindFirstChild("Right Shoulder")
	local neck = torso and torso:FindFirstChild("Neck")
	if not item or item.category ~= "Herb" or not humanoid or humanoid.Health <= 0
		or not shoulder or not shoulder:IsA("Motor6D") or not shoulder.Part1
		or busy(character, humanoid)
		or workspace:GetServerTimeNow() - started >= Items.HERB_EAT_SECONDS then
		return
	end
	local old = active[character]
	if old then clear(old) end
	local prop = template:Clone()
	prop:ScaleTo(0.45)
	for _, part in prop:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "Tint" then
			part.Color = item.color
		end
	end
	prop:PivotTo(shoulder.Part1.CFrame * CFrame.new(0, -shoulder.Part1.Size.Y / 2, 0))
	prop.Parent = workspace
	active[character] = {
		character = character, humanoid = humanoid, started = started, prop = prop,
		shoulder = { motor = shoulder },
		neck = if neck and neck:IsA("Motor6D") then { motor = neck } else nil,
		hidden = {},
	}
end

function HerbAnimator.isEating(): boolean
	local character = Players.LocalPlayer.Character
	return character ~= nil and active[character] ~= nil
end

-- Remove our previous layer before Animator evaluates the next frame. This also
-- prevents accumulation on joints that the current track doesn't key.
local function beforeAnimation()
	for _, eating in active do
		restoreJoint(eating.shoulder)
		restoreJoint(eating.neck)
	end
end

local function animate()
	local now = workspace:GetServerTimeNow()
	for character, eating in active do
		local t = now - eating.started
		local motor = eating.shoulder.motor
		local arm, torso = motor.Part1, motor.Part0
		if t >= Items.HERB_EAT_SECONDS or not character:IsDescendantOf(workspace)
			or eating.humanoid.Health <= 0 or not motor.Parent or not arm or not torso
			or busy(character, eating.humanoid) then
			clear(eating)
			continue
		end
		local lift = smooth(t / 0.32) * (1 - smooth((t - 0.69) / 0.36))
		local nibble = math.sin(math.clamp((t - 0.32) / 0.36, 0, 1) * math.pi * 4)
		-- Rotate the shoulder-to-palm vector toward the mouth in torso axes.
		-- R6 shoulders have rotated C0/C1 bases: solve in body space first.
		local palm = Vector3.new(0, -arm.Size.Y / 2, 0)
		local rest = (palm - motor.C1.Position).Unit
		local target = Vector3.new(-0.9, 0.35 + nibble * 0.035, -0.7).Unit
		local axis = rest:Cross(target)
		local rotation = CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(rest:Dot(target), -1, 1)))
		local goal = motor.C0.Rotation:Inverse() * rotation * motor.C1.Rotation
		eating.shoulder.original = motor.Transform
		motor.Transform = motor.Transform:Lerp(goal, lift)
		local neck = eating.neck
		if neck then
			local n = neck.motor
			neck.original = n.Transform
			local nod = CFrame.Angles(math.rad(-7 + nibble * 2) * lift, 0, 0)
			n.Transform = n.C0.Rotation:Inverse() * nod * n.C0.Rotation * n.Transform
		end
	end
end

local function draw()
	for character, eating in active do
		-- Tools can arrive after the event or disappear when the last herb is
		-- consumed. Remember only parts we actually hide and restore on exit.
		for _, child in character:GetChildren() do
			if child:IsA("Tool") or child.Name == "HeldWeapon" then
				for _, part in child:GetDescendants() do
					if part:IsA("BasePart") then
						if eating.hidden[part] == nil then
							eating.hidden[part] = part.LocalTransparencyModifier
						end
						part.LocalTransparencyModifier = 1
					end
				end
			end
		end
		-- An unequipped Tool must not stay hidden if someone equips it later.
		for part, transparency in eating.hidden do
			if not part:IsDescendantOf(character) then
				if part.Parent then part.LocalTransparencyModifier = transparency end
				eating.hidden[part] = nil
			end
		end
		local t = workspace:GetServerTimeNow() - eating.started
		if t >= Items.HERB_BITE_SECONDS then
			eating.prop.Parent = nil
		else
			local motor = eating.shoulder.motor
			local arm, torso = motor.Part1, motor.Part0
			if arm and torso then
				local armFrame = torso.CFrame * motor.C0 * motor.Transform * motor.C1:Inverse()
				local palm = armFrame:PointToWorldSpace(Vector3.new(0, -arm.Size.Y / 2, 0))
				eating.prop:PivotTo(CFrame.new(palm) * torso.CFrame.Rotation)
			end
		end
	end
end

function HerbAnimator.init()
	ReplicatedStorage.Remotes.Effect.OnClientEvent:Connect(function(kind, character, id, started)
		if kind == "herbEat" then play(character, id, started) end
	end)
	RunService.PreAnimation:Connect(beforeAnimation)
	RunService.PreSimulation:Connect(animate)
	RunService:BindToRenderStep("HerbEating", Enum.RenderPriority.Character.Value + 1, draw)
end

return HerbAnimator
