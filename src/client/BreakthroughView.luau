--!strict
-- The Break Through button (shown when the realm bar is full) and the breakthrough
-- effect: a column of light on whoever broke through, seen by everyone nearby.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Hud = require(script.Parent.Hud)

local remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local COLUMN_HEIGHT = 80
local MINOR_COLOR = Color3.fromRGB(150, 255, 210)
local MAJOR_COLOR = Color3.fromRGB(255, 220, 120)
local FADE_SECONDS = 1.6

local BreakthroughView = {}

local function playEffect(who: Player, major: boolean)
	local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local color = if major then MAJOR_COLOR else MINOR_COLOR
	local base = root.Position - Vector3.new(0, 3, 0)

	local column = Instance.new("Part")
	column.Name = "BreakthroughColumn"
	column.Shape = Enum.PartType.Cylinder
	column.Anchored, column.CanCollide, column.CanQuery, column.CanTouch = true, false, false, false
	column.Material = Enum.Material.Neon
	column.Color = color
	column.Transparency = 0.25
	column.Size = Vector3.new(COLUMN_HEIGHT, 3, 3)
	column.CFrame = CFrame.new(base + Vector3.new(0, COLUMN_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	column.Parent = workspace

	local ring = Instance.new("Part")
	ring.Name = "BreakthroughRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.4
	ring.Size = Vector3.new(0.3, 4, 4)
	ring.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace

	local info = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(column, info, { Transparency = 1, Size = Vector3.new(COLUMN_HEIGHT, 8, 8) }):Play()
	TweenService:Create(ring, info, { Transparency = 1, Size = Vector3.new(0.3, 40, 40) }):Play()
	Debris:AddItem(column, FADE_SECONDS + 0.2)
	Debris:AddItem(ring, FADE_SECONDS + 0.2)
end

function BreakthroughView.init(gui: ScreenGui)
	local button = gui:FindFirstChild("BreakthroughButton") :: TextButton

	local function refresh()
		local value, max = player:GetAttribute("Cultivation") or 0, player:GetAttribute("CultivationMax") or 0
		button.Visible = max > 0 and value >= max
	end
	player:GetAttributeChangedSignal("Cultivation"):Connect(refresh)
	player:GetAttributeChangedSignal("CultivationMax"):Connect(refresh)
	refresh()

	local busy = false
	button.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local _, message = (remotes.CultivationAction :: RemoteFunction):InvokeServer("breakthrough")
		if message then
			Hud.toast(message)
		end
		busy = false
	end)

	(remotes.Breakthrough :: RemoteEvent).OnClientEvent:Connect(function(who: Player, stageName: string, major: boolean)
		playEffect(who, major)
		if who ~= player and major then
			Hud.toast(`{who.DisplayName} broke through to {stageName}!`)
		end
	end)
end

return BreakthroughView
