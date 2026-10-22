--!strict
-- Guarding and perfect parries on the client: hold right click, L2 or the touch
-- Block button. The guard goes up only between actions and while free to act
-- (the server checks the same), drops when an action starts, and comes back up
-- by itself while the input is still held. Raising it again within
-- PARRY_RECOVER of the last raise can block but never parry. Attacks and casts
-- don't start while it's up (CombatController.tryStart); a dodge does.
-- While it's up without a lock-on you turn to the most pressing beast within
-- FACE_RANGE (one winding up first, else the nearest; Movement applies
-- ActionState.guardFacing), and the facing goes to the server with each raise
-- and as it turns (op "guardLook"), so the front arc is judged on what you see.
-- Clips come per weapon class (Animations.Guard.<WeaponClass>, "Fist" while
-- the weapon is stowed), each of Hold, Parry, ParryAlt and Impact falling back
-- to the generic Animations.Guard clip when the class has no id for it. A chain
-- of parries alternates Parry and ParryAlt and climbs in pitch and punch; the
-- blow that closes it (or the chain running dry, "chainEnd") lands a finisher.
-- Server: src/server/Guard.luau. Meter: src/shared/GuardRules.luau.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GuardConfig = require(ReplicatedStorage.Shared.Config).Combat.GUARD
local GuardRules = require(ReplicatedStorage.Shared.GuardRules)
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local ActionState = require(script.Parent.ActionState)
local BuildMode = require(script.Parent.BuildMode)
local CombatEffects = require(script.Parent.CombatEffects)
local GuardBar = require(script.Parent.GuardBar)
local GuardFX = require(script.Parent.GuardFX)
local LockOn = require(script.Parent.LockOn)
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
local FINISH_COLOR = Color3.fromRGB(255, 214, 120)
local CHAIN_PITCH = 0.07 -- each chained parry's cue plays this much higher...
local CHAIN_PITCH_MAX = 1.35 -- ...up to this
local CLIPS = { "Hold", "Parry", "ParryAlt", "Impact" }
local LOOK_EVERY = 0.1 -- at most this often, while guarding, the facing goes to the server...
local LOOK_TURN = math.cos(math.rad(8)) -- ...once it has turned this far
local WINDUP_PULL = 20 -- a beast winding up or dashing counts this many studs nearer when picking whom to face

local GuardController = {}

local meter = GuardRules.new()
local held = false -- the input is down
local up = false -- predicted: the guard is raised
local retryAt = 0
local raisedAt = 0
local seq = 0 -- numbers guard ops; the server echoes the latest in guardMeter
local raiseSeq = 0 -- the op that last raised the guard
local sentLook: Vector3? = nil
local sentLookAt = 0
local guardCharacter: Model?
local tracks: { [string]: AnimationTrack } = {} -- the clip set in use: Hold, Parry, ParryAlt, Impact
local trackSets: { [string]: { [string]: AnimationTrack } } = {} -- loaded sets by class, this character
local trackClass: string? = nil
local classConnections: { RBXScriptConnection } = {}

-- The class whose clips play: the weapon's, or Fist while it's stowed.
local function classOf(character: Model): string
	if character:GetAttribute("WeaponStowed") == true then
		return "Fist"
	end
	local class = character:GetAttribute("WeaponClass")
	return if type(class) == "string" and class ~= "" then class else "Fist"
end

local function clip(folder: Instance?, name: string): Animation?
	local found = folder and folder:FindFirstChild(name)
	return if found and found:IsA("Animation") and found.AnimationId ~= "" then found else nil
end

-- One class's tracks: its own clip, else (ParryAlt) its own Parry, else the
-- generic Animations.Guard clip of that name (ParryAlt: generic Parry).
local function loadSet(animator: Animator, class: string): { [string]: AnimationTrack }
	local generic = animations:FindFirstChild("Guard")
	local own = generic and generic:FindFirstChild(class)
	local set: { [string]: AnimationTrack } = {}
	for _, name in CLIPS do
		local animation = clip(own, name)
			or (if name == "ParryAlt" then clip(own, "Parry") else nil)
			or clip(generic, name)
			or (if name == "ParryAlt" then clip(generic, "Parry") else nil)
		if animation then
			local track = animator:LoadAnimation(animation)
			track.Looped = name == "Hold"
			track.Priority = if name == "Hold" then Enum.AnimationPriority.Action else Enum.AnimationPriority.Action2
			set[name] = track
		end
	end
	return set
end

-- Switch to the clips for the character's current class; a held guard swaps
-- straight into the new Hold.
local function applyClass(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local class = classOf(character)
	if class == trackClass then
		return
	end
	for _, track in tracks do
		if track.IsPlaying then
			track:Stop(RAISE_FADE)
		end
	end
	trackClass = class
	local set = trackSets[class]
	if not set then
		set = loadSet(animator, class)
		trackSets[class] = set
	end
	tracks = set
	local hold = tracks.Hold
	if up and hold then
		hold:Play(RAISE_FADE)
	end
end

local function loadTracks(character: Model)
	for _, connection in classConnections do
		connection:Disconnect()
	end
	table.clear(classConnections)
	for _, set in trackSets do
		for _, track in set do
			track:Destroy()
		end
	end
	table.clear(trackSets)
	tracks, trackClass = {}, nil
	applyClass(character)
	local function reapply()
		if guardCharacter == character then
			applyClass(character)
		end
	end
	table.insert(classConnections, character:GetAttributeChangedSignal("WeaponClass"):Connect(reapply))
	table.insert(classConnections, character:GetAttributeChangedSignal("WeaponStowed"):Connect(reapply))
end

local function play(name: string, fade: number)
	local track = tracks[name]
	if track then
		track:Play(fade)
	end
end

local function flat(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else nil
end

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
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
		Sfx.play("GuardRaise")
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
		seq += 1
		if value then
			raiseSeq = seq
		end
		local root = myRoot()
		local look = root and flat(root.CFrame.LookVector)
		sentLook, sentLookAt = look, now
		attackRemote:FireServer({ op = "guard", character = character, on = value, time = now, seq = seq, look = look })
	end
end

-- Half a beast's footprint, so a big boss counts from its edge (cached per model).
local reach: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local function reachOf(model: Model): number
	local r = reach[model]
	if not r then
		local size = model:GetExtentsSize()
		r = math.max(size.X, size.Z) / 2
		reach[model] = r
	end
	return r
end

-- Which way to face while guarding: toward the beast that's winding up or
-- dashing at you, else the nearest, within FACE_RANGE of its edge. Nil with a
-- lock (LockOn faces the target) or nothing near.
local function threatFacing(root: BasePart): Vector3?
	if GuardConfig.FACE_RANGE <= 0 or LockOn.target() then
		return nil
	end
	local best: Vector3?, bestScore = nil, math.huge
	for _, model in CollectionService:GetTagged("Enemy") do
		if model:IsA("Model") and Hitbox.alive(model) and not model:GetAttribute("Burrowed") then
			local offset = model:GetPivot().Position - root.Position
			local dir = flat(offset)
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude - reachOf(model)
			if dir and distance <= GuardConfig.FACE_RANGE then
				local state = model:GetAttribute("AIState")
				local score = distance - (if state == "windup" or state == "dash" then WINDUP_PULL else 0)
				if score < bestScore then
					best, bestScore = dir, score
				end
			end
		end
	end
	return best
end

-- Turn toward the threat while guarding, and keep the server's copy of the
-- facing fresh (Guard.look).
local function updateFacing(dt: number)
	local root = myRoot()
	local character = player.Character
	if not (up and root and character) then
		ActionState.guardFacing = nil
		return
	end
	local want = threatFacing(root)
	if want then
		local current = ActionState.guardFacing or flat(root.CFrame.LookVector) or want
		local alpha = 1 - math.exp(-GuardConfig.FACE_TURN * dt)
		local blended = current:Lerp(want, alpha)
		ActionState.guardFacing = if blended.Magnitude > 0.05 then blended.Unit else want
	else
		ActionState.guardFacing = nil
	end
	local now = workspace:GetServerTimeNow()
	local look = ActionState.guardFacing or flat(root.CFrame.LookVector)
	if look and now - sentLookAt >= LOOK_EVERY and (not sentLook or look:Dot(sentLook) < LOOK_TURN) then
		sentLook, sentLookAt = look, now
		attackRemote:FireServer({ op = "guardLook", character = character, time = now, look = look })
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
		-- a "down" answering an op older than our last raise is stale (we
		-- lowered and raised again before it came back), not a refusal
		local answered = if type(args[5]) == "number" then args[5] else math.huge
		if not args[4] and up and answered >= raiseSeq then
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
		-- chain parries: the blow's place in the chain, and whether it closed it
		local n = if type(args[4]) == "number" then math.max(1, math.floor(args[4])) else 1
		local closing = args[5] == true and n >= 2
		local mine = character == player.Character
		if outcome == "parried" then
			GuardFX.parry(character, from, mine, n, closing)
		elseif outcome == "chainEnd" then
			if n >= 2 then
				GuardFX.finisher(character, from, mine, n)
			end
		elseif outcome == "blocked" then
			GuardFX.blocked(character, from)
		elseif outcome == "broken" then
			GuardFX.guardBreak(character, mine)
		end
		if not mine then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local function finisherBeat()
			-- a lower, heavier echo of the clash and the guard's thud under it
			Sfx.play("Parry", nil, nil, 0.78)
			task.delay(0.06, function()
				Sfx.play("Block", nil, nil, 0.85)
			end)
			GuardBar.flash("parry")
			if root then
				CombatEffects.number(root.Position, `Deflect x{n}!`, FINISH_COLOR, 28)
			end
		end
		if outcome == "parried" then
			-- alternate sides down a chain: Parry, ParryAlt, Parry...
			play(if n % 2 == 0 then "ParryAlt" else "Parry", 0.05)
			GuardBar.flash("parry")
			Sfx.play("Parry", nil, nil, math.min(1 + CHAIN_PITCH * (n - 1), CHAIN_PITCH_MAX))
			if closing then
				finisherBeat()
			elseif root then
				CombatEffects.number(root.Position, if n == 1 then "Parry!" else `x{n}`, PARRY_COLOR, 20 + math.min(n - 1, 5))
			end
		elseif outcome == "chainEnd" then
			if n >= 2 then
				finisherBeat()
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
	RunService.RenderStepped:Connect(function(dt)
		updateFacing(dt)
		GuardBar.set(GuardRules.value(meter, workspace:GetServerTimeNow()), up)
	end)
end

return GuardController
