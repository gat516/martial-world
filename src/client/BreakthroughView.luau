--!strict
-- Breaking through, and the breakthrough effect: a column of light on whoever
-- broke through, seen by everyone nearby. Breakthroughs are seated only: the
-- meditation menu's Break Through tile (Meditation calls attempt).
-- The qi surge (server QiSurge, Pacing.Surge): while the server's SurgeReady is
-- true, PC shows the standing pill (`Stack.BreakthroughButton`, "M to qi surge":
-- M surges instead of meditating, Meditation's binding; a click fires it too) and
-- touch shows `Play.SurgeButton` in the combat cluster instead (Layout places it),
-- popping in. Both wear the surge flame. Every client plays an ember column and
-- motes on a player whose SurgeUntil is set, for as long as it lasts.
-- The ready nudge: when BreakthroughReady turns true, a toast says so once; after
-- that it comes back only while the player is idle (no input for NUDGE_IDLE) and
-- standing, at most every NUDGE_EVERY seconds, until they break through.
-- The local player's own breakthrough also shows the Rewards milestone card
-- (docs/ui/rewards.md).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Gates = require(ReplicatedStorage.Shared.Gates)
local Hud = require(script.Parent.Hud)
local Layout = require(script.Parent.Layout)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Rewards = require(script.Parent.Rewards)
local State = require(script.Parent.State)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer

local COLUMN_HEIGHT = 80
local MINOR_COLOR = Color3.fromRGB(150, 255, 210)
local MAJOR_COLOR = Color3.fromRGB(255, 220, 120)
local SURGE_COLOR = Color3.fromRGB(255, 150, 90)
local FADE_SECONDS = 1.6
local NUDGE_FIRST = 4 -- seconds after joining before a standing-ready nudge
local NUDGE_IDLE = 25 -- seconds without input before the nudge may repeat
local NUDGE_EVERY = 150 -- seconds between repeats

local BreakthroughView = {}

local busy = false

-- Ask the server to break through (seated only); refusals toast why.
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

-- Fire the qi surge (CultivationAction "surge"); refusals toast why.
function BreakthroughView.surge()
	if busy then
		return
	end
	busy = true
	local _, message = (remotes.CultivationAction :: RemoteFunction):InvokeServer("surge")
	if message then
		Hud.toast(message)
	end
	busy = false
end

function BreakthroughView.surgeReady(): boolean
	return player:GetAttribute("SurgeReady") == true
end

local function playEffect(who: Player, major: boolean, tint: Color3?)
	local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local color = tint or if major then MAJOR_COLOR else MINOR_COLOR
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

-- A surging player: the breakthrough burst in ember, then motes streaming off them
-- until SurgeUntil passes or clears (short-lived, nothing persistent).
local function watchSurge(who: Player)
	local motes: ParticleEmitter? = nil
	local function clear()
		if motes then
			motes:Destroy()
			motes = nil
		end
	end
	local function changed()
		clear()
		local ends = who:GetAttribute("SurgeUntil")
		if typeof(ends) ~= "number" then
			return
		end
		local left = ends - workspace:GetServerTimeNow()
		local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if left <= 0 or not root then
			return
		end
		playEffect(who, false, SURGE_COLOR)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "QiSurgeMotes"
		emitter.Texture = SPARKLE
		emitter.Color = ColorSequence.new(SURGE_COLOR)
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(0.6, 0)
		emitter.Lifetime = NumberRange.new(0.6, 1)
		emitter.Speed = NumberRange.new(4, 8)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, 10, 0)
		emitter.Rate = 30
		emitter.Parent = root
		Debris:AddItem(emitter, left + 0.5)
		motes = emitter
	end
	who:GetAttributeChangedSignal("SurgeUntil"):Connect(changed)
	who.CharacterRemoving:Connect(clear)
	changed()
end

-- The local player's moment: the milestone card (Rewards), with what changed from
-- the stage before (health, power, combat qi, passive cultivation) and any travel
-- array the new stage opens. The subtitle also carries the foundation grade the
-- stage just left earned (Cracked/Steady/Solid/Deep, server Foundation).
local function milestoneCard(stageName: string, major: boolean, grade: string?)
	local stage = Realms.byName(stageName)
	local before: Realms.Stage? = nil
	if stage then
		local i = Realms.index(stage.major, stage.minor)
		before = Realms.Stages[i - 1]
	end
	local stats = {}
	if stage and before then
		local function add(name: string, from: number, to: number, fmt: string)
			if to ~= from then
				table.insert(stats, { name = name, from = string.format(fmt, from), to = string.format(fmt, to) })
			end
		end
		add("Health", before.health, stage.health, "%d")
		add("Power", before.power, stage.power, "%.2f")
		add("Combat qi", before.combatQi, stage.combatQi, "%d")
		add("Passive", before.passive, stage.passive, "%.2f/s")
	end
	local unlock: string? = nil
	if stage then
		for _, gate in Gates.List do
			local need = Gates.required(gate)
			if need and need.key == stage.key then
				unlock = `The {gate.name} array is open`
			end
		end
	end
	Rewards.show({
		tier = "card",
		kind = "milestone",
		title = if major then "Major Breakthrough" else "Breakthrough",
		subtitle = if type(grade) == "string" then `{stageName}  ·  {grade} foundation` else stageName,
		stats = stats,
		unlock = unlock,
		flavour = if major then "A new realm opens before you." else "Your qi settles at a new depth.",
		life = if major then 7 else 5,
	})
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
	local touchButton = (gui:FindFirstChild("Play") :: Frame):FindFirstChild("SurgeButton") :: GuiButton
	Motion.appear(touchButton)

	-- the qi surge: the server decides when it's ready (SurgeReady); the pill on PC,
	-- the cluster button on touch
	local function refresh()
		local seated = State.current.meditation ~= nil
		local ready = BreakthroughView.surgeReady() and not seated and not Menus.isOpen()
		local touch = Platform.isTouch()
		button.Visible = ready and not touch
		touchButton.Visible = ready and touch and Layout.clusterShown()
	end
	Menus.onChanged(refresh)
	player:GetAttributeChangedSignal("SurgeReady"):Connect(refresh)
	State.onChanged(function()
		refresh()
	end)
	refresh()

	button.Activated:Connect(BreakthroughView.surge)
	touchButton.Activated:Connect(BreakthroughView.surge)
	nudges()

	for _, who in Players:GetPlayers() do
		task.spawn(watchSurge, who)
	end
	Players.PlayerAdded:Connect(watchSurge)

	local breakthroughRemote = remotes.Breakthrough :: RemoteEvent
	breakthroughRemote.OnClientEvent:Connect(function(who: Player, stageName: string, major: boolean, grade: string?)
		playEffect(who, major)
		if who == player then
			milestoneCard(stageName, major, grade)
		elseif major then
			Hud.toast(`{who.DisplayName} broke through to {stageName}!`)
		end
	end)
end

return BreakthroughView
