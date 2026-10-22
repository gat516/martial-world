--!strict
-- Guarding and perfect parries on the client: hold right click, L2 or the touch
-- Block button. The guard goes up only between actions and while free to act
-- (the server checks the same), drops when an action starts, and comes back up
-- by itself while the input is still held. Raising it again within
-- PARRY_RECOVER of the last raise can block but never parry. Attacks and casts
-- don't start while it's up (CombatController.tryStart); a dodge does.
-- Server: src/server/Guard.luau. Meter: src/shared/GuardRules.luau.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GuardRules = require(ReplicatedStorage.Shared.GuardRules)
local ActionState = require(script.Parent.ActionState)
local BuildMode = require(script.Parent.BuildMode)
local CombatEffects = require(script.Parent.CombatEffects)
local GuardBar = require(script.Parent.GuardBar)
local GuardFX = require(script.Parent.GuardFX)
local Sfx = require(script.Parent.Sfx)

local remotes = ReplicatedStorage.Remotes
local attackRemote = remotes.Attack :: RemoteEvent
local effectRemote = remotes.Effect :: RemoteEvent
local animations = ReplicatedStorage:WaitForChild("Animations") :: Folder
local player = Players.LocalPlayer

local RAISE_FADE = 0.08 -- the guard pose blends in this fast; the clip itself starts in guard
local LOWER_FADE = 0.15
local REFUSED_WAIT = 0.25 -- after the server refuses a raise, wait this long before asking again
local MIN_UP = 0.25 -- a tap keeps the guard pose up this long (the parry window outlives the press anyway)
local PARRY_COLOR = Color3.fromRGB(255, 236, 190)

local GuardController = {}

local meter = GuardRules.new()
local held = false -- the input is down
local up = false -- predicted: the guard is raised
local retryAt = 0
local raisedAt = 0
local guardCharacter: Model?
local tracks: { [string]: AnimationTrack } = {} -- "Hold", "Parry", "Impact" from Animations.Guard

local function loadTracks(character: Model)
	for _, track in tracks do
		track:Destroy()
	end
	table.clear(tracks)
	local folder = animations:FindFirstChild("Guard")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not (folder and animator) then
		return
	end
	for _, animation in folder:GetChildren() do
		if animation:IsA("Animation") and animation.AnimationId ~= "" then
			local track = animator:LoadAnimation(animation)
			track.Looped = animation.Name == "Hold"
			track.Priority = if animation.Name == "Hold" then Enum.AnimationPriority.Action else Enum.AnimationPriority.Action2
			tracks[animation.Name] = track
		end
	end
end

local function play(name: string, fade: number)
	local track = tracks[name]
	if track then
		track:Play(fade)
	end
end

local function setUp(value: boolean, notify: boolean)
	if up == value then
		return
	end
	up = value
	ActionState.guarding = value
	local now = workspace:GetServerTimeNow()
	GuardRules.setUp(meter, value, now)
	local character = player.Character
	if value then
		raisedAt = now
		play("Hold", RAISE_FADE)
	else
		local hold = tracks.Hold
		if hold then
			hold:Stop(LOWER_FADE)
		end
	end
	if character then
		GuardFX.hold(character, value)
	end
	if notify and character then
		attackRemote:FireServer({ op = "guard", character = character, on = value, time = now })
	end
end

local function canRaise(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil
		and humanoid.Health > 0
		and not humanoid.Sit
		and not ActionState.blocked
		and not BuildMode.isActive()
		and ActionState.phase() == "free"
		and not ActionState.crowdLocked()
end

local function onInput(_, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		held = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		held = false
	end
	-- right click still turns the camera when the mouse isn't locked
	return Enum.ContextActionResult.Pass
end

local function onEffect(kind: string, ...: any)
	local args = { ... }
	if kind == "guardMeter" then
		if args[1] ~= player.Character then
			return
		end
		meter.stored, meter.at = args[2], args[3]
		if not args[4] and up then
			-- refused or broken: lower without telling the server again
			setUp(false, false)
			retryAt = workspace:GetServerTimeNow() + REFUSED_WAIT
		end
		meter.up = up
	elseif kind == "guardEarly" then
		-- testbed only: a blocked hit says how long before it the guard went up
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and type(args[1]) == "number" then
			CombatEffects.number(root.Position, string.format("early %.2fs", args[1]), Color3.fromRGB(200, 220, 255), 16)
		end
	elseif kind == "guard" then
		local character, outcome, from = args[1], args[2], args[3]
		if typeof(character) ~= "Instance" or not character:IsA("Model") or typeof(from) ~= "Vector3" then
			return
		end
		local mine = character == player.Character
		if outcome == "parried" then
			GuardFX.parry(character, from, mine)
		elseif outcome == "blocked" then
			GuardFX.blocked(character, from)
		elseif outcome == "broken" then
			GuardFX.guardBreak(character, mine)
		end
		if not mine then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if outcome == "parried" then
			play("Parry", 0.05)
			GuardBar.flash("parry")
			Sfx.play("Parry")
			if root then
				CombatEffects.number(root.Position, "Parry!", PARRY_COLOR, 20)
			end
		elseif outcome == "blocked" then
			play("Impact", 0.05)
			GuardBar.flash("blocked")
			Sfx.play("Block", nil, 0.08)
		elseif outcome == "broken" then
			GuardBar.flash("break")
			Sfx.play("GuardBreak")
			held = false -- press again to guard after a break
		end
	end
end

-- Other players' guards, for their held-guard visuals.
local function watch(other: Player)
	if other == player then
		return
	end
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		local function sync()
			GuardFX.hold(character, humanoid:GetAttribute("Guarding") == true)
		end
		humanoid:GetAttributeChangedSignal("Guarding"):Connect(sync)
		sync()
	end
	other.CharacterAdded:Connect(onCharacter)
	if other.Character then
		task.spawn(onCharacter, other.Character)
	end
end

function GuardController.init(gui: ScreenGui)
	GuardBar.init(gui)
	ContextActionService:BindActionAtPriority("Guard", onInput, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	local button = gui:FindFirstChild("BlockButton", true) :: GuiObject?
	if button then
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				held = true
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				held = false
			end
		end)
	end
	UserInputService.WindowFocusReleased:Connect(function()
		held = false
	end)
	effectRemote.OnClientEvent:Connect(onEffect)

	player.CharacterAdded:Connect(function(character)
		setUp(false, false)
		held = false
		meter = GuardRules.new()
		guardCharacter = character
		character:WaitForChild("Humanoid"):WaitForChild("Animator")
		if guardCharacter == character then
			loadTracks(character)
		end
	end)
	if player.Character then
		guardCharacter = player.Character
		task.spawn(function()
			local character = player.Character :: Model
			character:WaitForChild("Humanoid"):WaitForChild("Animator")
			if guardCharacter == character then
				loadTracks(character)
			end
		end)
	end
	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Players.PlayerAdded:Connect(watch)

	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		if up and not canRaise() then
			setUp(false, true)
		elseif up and not held and now - raisedAt >= MIN_UP then
			setUp(false, true)
		elseif not up and held and now >= retryAt and canRaise() then
			setUp(true, true)
		end
	end)
	RunService.RenderStepped:Connect(function()
		GuardBar.set(GuardRules.value(meter, workspace:GetServerTimeNow()), up)
	end)
end

return GuardController
