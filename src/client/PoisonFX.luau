--!strict
-- Poison on characters: any character with `PoisonStacks` > 0 until
-- `PoisonUntil` (server time, set by PlayerPoison) gets a pulsing green
-- Highlight, rising bubbles and drips off the torso (more with more stacks)
-- and, for the local player, a thin green tint at the screen edge. Watches
-- characters through their attributes, so it works as they stream in and out.
-- Cheap on phones: one Highlight and two small emitters per poisoned
-- character, one frame-less gradient for the screen edge, no per-frame work
-- unless someone is poisoned.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VENOM = Color3.fromRGB(155, 255, 74)
local VDEEP = Color3.fromRGB(60, 150, 44)
local DOT = "rbxassetid://9841273544"
local RING = "rbxassetid://9841273159"

type Active = {
	character: Model,
	highlight: Highlight,
	bubbles: ParticleEmitter,
	drips: ParticleEmitter,
	stacks: number,
}

local PoisonFX = {}
local active: { [Model]: Active } = {}
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local connection: RBXScriptConnection? = nil
local screen: ScreenGui? = nil
local edge: { Frame } = {}

local function poisoned(character: Model): number
	local stacks, untilAt = character:GetAttribute("PoisonStacks"), character:GetAttribute("PoisonUntil")
	if type(stacks) ~= "number" or stacks <= 0 then
		return 0
	end
	if type(untilAt) == "number" and workspace:GetServerTimeNow() > untilAt then
		return 0
	end
	return stacks
end

local function torsoOf(character: Model): BasePart?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	return if torso and torso:IsA("BasePart") then torso else nil
end

local function ensureScreen()
	if screen then
		return
	end
	local player = Players.LocalPlayer
	local gui = player and player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return
	end
	local sg = Instance.new("ScreenGui")
	sg.Name = "PoisonEdge"
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 5
	sg.Parent = gui
	-- four thin gradient strips along the edges
	local specs = {
		{ UDim2.new(1, 0, 0.14, 0), UDim2.new(0, 0, 0, 0), 90 },
		{ UDim2.new(1, 0, 0.14, 0), UDim2.new(0, 0, 0.86, 0), 270 },
		{ UDim2.new(0.08, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0 },
		{ UDim2.new(0.08, 0, 1, 0), UDim2.new(0.92, 0, 0, 0), 180 },
	}
	for _, spec in specs do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = VENOM
		f.BorderSizePixel = 0
		f.Size = spec[1]
		f.Position = spec[2]
		f.BackgroundTransparency = 1
		f.Active = false
		local g = Instance.new("UIGradient")
		g.Rotation = spec[3]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		f.Parent = sg
		table.insert(edge, f)
	end
	screen = sg
end

local function attach(character: Model, stacks: number)
	local torso = torsoOf(character)
	if not torso then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "PoisonHighlight"
	highlight.FillColor = VENOM
	highlight.OutlineColor = VDEEP
	highlight.FillTransparency = 0.8
	highlight.OutlineTransparency = 0.5
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = character
	highlight.Parent = character
	local a = Instance.new("Attachment")
	a.Name = "PoisonFX"
	a.Parent = torso
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = RING
	bubbles.Color = ColorSequence.new(Color3.fromRGB(226, 255, 182), VENOM)
	bubbles.LightEmission = 1
	bubbles.LightInfluence = 0
	bubbles.Lifetime = NumberRange.new(0.6, 1.0)
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.SpreadAngle = Vector2.new(25, 25)
	bubbles.Shape = Enum.ParticleEmitterShape.Cylinder
	bubbles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.55) })
	bubbles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 1) })
	bubbles.Rate = 0
	bubbles.Parent = a
	local drips = Instance.new("ParticleEmitter")
	drips.Texture = DOT
	drips.Color = ColorSequence.new(VENOM)
	drips.LightEmission = 1
	drips.LightInfluence = 0
	drips.Lifetime = NumberRange.new(0.5, 0.9)
	drips.Speed = NumberRange.new(0.5, 2)
	drips.EmissionDirection = Enum.NormalId.Bottom
	drips.SpreadAngle = Vector2.new(30, 30)
	drips.Acceleration = Vector3.new(0, -30, 0)
	drips.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.15) })
	drips.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	drips.Rate = 0
	drips.Parent = a
	active[character] = { character = character, highlight = highlight, bubbles = bubbles, drips = drips, stacks = stacks }
end

local function detach(character: Model)
	local item = active[character]
	if not item then
		return
	end
	active[character] = nil
	item.highlight:Destroy()
	local a = item.bubbles.Parent
	if a then
		a:Destroy()
	end
end

local function step()
	local any = false
	local localCharacter = Players.LocalPlayer and Players.LocalPlayer.Character
	local localStacks = 0
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 5)
	for character in pairs(watched) do
		if character.Parent then
			local stacks = poisoned(character)
			if stacks > 0 then
				any = true
				if not active[character] then
					attach(character, stacks)
				end
				local item = active[character]
				if item then
					item.stacks = stacks
					item.highlight.FillTransparency = 0.82 - 0.1 * stacks * pulse
					item.highlight.OutlineTransparency = 0.55 - 0.15 * pulse
					item.bubbles.Rate = 4 + stacks * 4
					item.drips.Rate = 2 + stacks * 2
				end
				if character == localCharacter then
					localStacks = stacks
				end
			elseif active[character] then
				detach(character)
			end
		else
			detach(character)
		end
	end
	if localStacks > 0 then
		ensureScreen()
	end
	local strength = if localStacks > 0 then 0.55 - 0.1 * localStacks - 0.08 * pulse else 1
	for _, f in edge do
		f.BackgroundTransparency = strength
	end
	if not any and next(active) == nil and localStacks == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function start()
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
end

local function watch(character: Instance)
	if not character:IsA("Model") or watched[character] then
		return
	end
	watched[character] = true
	local function check()
		if poisoned(character) > 0 then
			start()
		end
	end
	character:GetAttributeChangedSignal("PoisonStacks"):Connect(check)
	character:GetAttributeChangedSignal("PoisonUntil"):Connect(check)
	check()
end

local function watchPlayer(player: Player)
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

function PoisonFX.init()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return PoisonFX
