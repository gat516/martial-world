--!strict
-- The Break Through button and the breakthrough effect: a column of light on
-- whoever broke through, seen by everyone nearby. The button shows while seated in
-- meditation with a full bar, or as Force Breakthrough when badly hurt with the
-- bar nearly full (the server also checks you're in combat, see Cultivation.luau).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Hud = require(script.Parent.Hud)
local Menus = require(script.Parent.Menus)
local State = require(script.Parent.State)
local Config = require(ReplicatedStorage.Shared.Pacing).Breakthrough

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

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

	-- motes rising up the column
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = SPARKLE
	motes.Color = ColorSequence.new(color)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new(0.9, 0)
	motes.Lifetime = NumberRange.new(1, 1.6)
	motes.Speed = NumberRange.new(14, 26)
	motes.SpreadAngle = Vector2.new(25, 25)
	motes.EmissionDirection = Enum.NormalId.Right -- the column's local X is world up
	motes.Rate = 0
	motes.Parent = column
	motes:Emit(if major then 90 else 45)
end

-- The local player's moment: a soft flash and the new realm's name on a title card.
local function titleCard(gui: ScreenGui, stageName: string, major: boolean)
	local flash = gui:FindFirstChild("Flash") :: Frame
	flash.BackgroundTransparency = if major then 0.15 else 0.45
	flash.Visible = true
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	task.delay(0.85, function()
		flash.Visible = false
	end)

	local banner = gui:FindFirstChild("Banner") :: Frame
	local title = banner:FindFirstChild("Title") :: TextLabel
	local kicker = banner:FindFirstChild("Kicker") :: TextLabel
	local rule = banner:FindFirstChild("Rule") :: Frame
	kicker.Text = if major then "MAJOR BREAKTHROUGH" else "BREAKTHROUGH"
	title.Text = stageName
	for _, label in { title, kicker } do
		label.TextTransparency = 1
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	end
	rule.Size = UDim2.fromOffset(0, 2)
	TweenService:Create(rule, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(0.5, 0, 0, 2) }):Play()
	banner.Visible = true
	task.delay(if major then 4 else 2.6, function()
		for _, label in { title, kicker } do
			TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
		task.wait(0.65)
		banner.Visible = false
	end)
end

function BreakthroughView.init(gui: ScreenGui)
	local button = (gui:FindFirstChild("Stack") :: Frame):FindFirstChild("BreakthroughButton") :: ImageButton
	local label = button:FindFirstChild("Label") :: TextLabel

	local function refresh()
		local value, max = player:GetAttribute("Cultivation") or 0, player:GetAttribute("CultivationMax") or 0
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seated = State.current.meditation ~= nil
		local hurt = humanoid ~= nil and humanoid.Health > 0 and humanoid.Health <= humanoid.MaxHealth * Config.FORCE_HEALTH_SHARE
		local forcible = hurt and max > 0 and value >= max * Config.FORCE_BAR_SHARE
		button.Visible = (if seated then max > 0 and value >= max else forcible) and not Menus.isOpen()
		label.Text = if seated then "Break Through" else "Force Breakthrough"
	end
	Menus.onChanged(refresh)
	player:GetAttributeChangedSignal("Cultivation"):Connect(refresh)
	player:GetAttributeChangedSignal("CultivationMax"):Connect(refresh)
	State.onChanged(function()
		refresh()
	end)
	local function watch(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.HealthChanged:Connect(refresh)
		refresh()
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end

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

	local breakthroughRemote = remotes.Breakthrough :: RemoteEvent
	breakthroughRemote.OnClientEvent:Connect(function(who: Player, stageName: string, major: boolean)
		playEffect(who, major)
		if who == player then
			titleCard(gui, stageName, major)
		elseif major then
			Hud.toast(`{who.DisplayName} broke through to {stageName}!`)
		end
	end)
end

return BreakthroughView
