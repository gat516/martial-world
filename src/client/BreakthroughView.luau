--!strict
-- Breaking through, and the breakthrough effect: a column of light on whoever
-- broke through, seen by everyone nearby. Seated with a full bar it's the
-- meditation menu's Break Through tile (Meditation calls attempt); standing, the
-- Force Breakthrough button shows when badly hurt with the bar nearly full (the
-- server also checks you're in combat, see Cultivation.luau).
-- The ready nudge: when BreakthroughReady turns true, a toast says so once; after
-- that it comes back only while the player is idle (no input for NUDGE_IDLE) and
-- standing, at most every NUDGE_EVERY seconds, until they break through.
-- The local player's own breakthrough also shows the title card
-- (StarterGui.Cultivation, docs/ui/cultivation.md).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CultivationGui = require(script.Parent.CultivationGui)
local Hud = require(script.Parent.Hud)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)
local State = require(script.Parent.State)
local Config = require(ReplicatedStorage.Shared.Pacing).Breakthrough

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local COLUMN_HEIGHT = 80
local MINOR_COLOR = Color3.fromRGB(150, 255, 210)
local MAJOR_COLOR = Color3.fromRGB(255, 220, 120)
local FADE_SECONDS = 1.6
local NUDGE_FIRST = 4 -- seconds after joining before a standing-ready nudge
local NUDGE_IDLE = 25 -- seconds without input before the nudge may repeat
local NUDGE_EVERY = 150 -- seconds between repeats

local BreakthroughView = {}

local busy = false

-- Ask the server to break through (seated, or forced); refusals toast why.
function BreakthroughView.attempt()
	if busy then
		return
	end
	busy = true
	local _, message = (remotes.CultivationAction :: RemoteFunction):InvokeServer("breakthrough")
	if message then
		Hud.toast(message)
	end
	busy = false
end

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

-- The local player's moment: the new realm's name on the kit's title crest
-- (Cultivation.Canvas.TitleCard), over milestone rays in the breakthrough's
-- colour and a short soft glow. No screen flash or darkening (user, 2026-10-22).
-- A major breakthrough holds longer and adds one glint on the crest.
local CARD_HOLD = { minor = 2.4, major = 3.4 }
local RAY_SPEED = 8 -- degrees per second
local GLOW_SETTLE = 0.6 -- the glow's transparency once its swell has passed
local cardToken = 0

local function titleCard(stageName: string, major: boolean)
	local card = CultivationGui.piece("TitleCard")
	local body = card:FindFirstChild("Body") :: Frame
	local rays = card:FindFirstChild("Rays") :: ImageLabel
	local glow = card:FindFirstChild("Glow") :: ImageLabel
	local glint = body:FindFirstChild("Glint") :: ImageLabel
	cardToken += 1
	local mine = cardToken
	local color = if major then MAJOR_COLOR else MINOR_COLOR;
	(body:FindFirstChild("Kicker") :: TextLabel).Text = if major then "MAJOR BREAKTHROUGH" else "BREAKTHROUGH";
	(body:FindFirstChild("Title") :: TextLabel).Text = stageName
	rays.ImageColor3 = color
	glow.ImageColor3 = color
	card.Visible = true
	Motion.fadeIn(card)
	local scale = body:FindFirstChild("Motion") :: UIScale
	scale.Scale = 0.88
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(0.35, function()
		if cardToken == mine then
			TweenService:Create(glow, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { ImageTransparency = GLOW_SETTLE }):Play()
		end
	end)
	if major then
		glint.ImageTransparency = 1
		glint.Size = UDim2.fromOffset(60, 54)
		local swell = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(glint, swell, { ImageTransparency = 0.1, Size = UDim2.fromOffset(140, 125) }):Play()
		task.delay(0.4, function()
			TweenService:Create(glint, TweenInfo.new(0.5), { ImageTransparency = 1, Size = UDim2.fromOffset(90, 80) }):Play()
		end)
	end
	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation = (rays.Rotation + RAY_SPEED * dt) % 360
	end)
	task.delay(if major then CARD_HOLD.major else CARD_HOLD.minor, function()
		if cardToken ~= mine then
			spin:Disconnect()
			return
		end
		Motion.fadeOut(card, function()
			spin:Disconnect()
			if cardToken == mine then
				card.Visible = false
			end
		end)
	end)
end

-- Show the title card with sample text (client console in play).
function BreakthroughView.previewCard(major: boolean?)
	titleCard(if major then "Foundation Establishment 1" else "Qi Condensation 4", major == true)
end

-- "You feel ready to break through": once on becoming ready, then now and then
-- while idle (see the header).
local function nudges()
	local lastInput = os.clock()
	local lastNudge = -math.huge
	local function ready(): boolean
		return player:GetAttribute("BreakthroughReady") == true
	end
	local function nudge()
		lastNudge = os.clock()
		-- the server says "Sit and meditate to break through" when the bar first fills
		if Hud.saidLately("break through", 10) then
			return
		end
		local seated = State.current.meditation ~= nil
		local how = if seated then "Break Through from your seat."
			elseif Platform.isTouch() then "Meditate to try."
			else "Meditate (M) to try."
		Hud.toast(`You feel ready to break through. {how}`)
	end
	UserInputService.InputBegan:Connect(function()
		lastInput = os.clock()
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			lastInput = os.clock()
		end
	end)
	local was = ready()
	player:GetAttributeChangedSignal("BreakthroughReady"):Connect(function()
		local now = ready()
		if now and not was then
			task.delay(1.5, nudge) -- after the server's own notice, if it sends one
		end
		was = now
	end)
	task.delay(NUDGE_FIRST, function()
		if ready() and lastNudge < 0 then
			nudge()
		end
		while true do
			task.wait(5)
			local seated = State.current.meditation ~= nil
			if ready() and not seated and not Menus.isOpen()
				and os.clock() - lastInput >= NUDGE_IDLE and os.clock() - lastNudge >= NUDGE_EVERY then
				nudge()
			end
		end
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
		button.Visible = not seated and forcible and not Menus.isOpen()
		label.Text = "Force Breakthrough"
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

	button.Activated:Connect(BreakthroughView.attempt)
	nudges()

	local breakthroughRemote = remotes.Breakthrough :: RemoteEvent
	breakthroughRemote.OnClientEvent:Connect(function(who: Player, stageName: string, major: boolean)
		playEffect(who, major)
		if who == player then
			titleCard(stageName, major)
		elseif major then
			Hud.toast(`{who.DisplayName} broke through to {stageName}!`)
		end
	end)
end

return BreakthroughView
