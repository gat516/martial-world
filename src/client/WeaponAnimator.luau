--!strict
-- The equipped weapon class's idle and walk on the local character, laid over
-- the default Animate script: Idle-priority idle while grounded, Movement-priority
-- walk while walking (not running: Sprint's run owns that). Jumps and falls
-- stay with Animate. Tracks played by the owner replicate, so other clients see
-- them too. Fist (nothing equipped) uses the default idle/walk.
-- Movement/combat control locks stow the model through WeaponAction and pause
-- these tracks; rooted attacks/casts still keep their weapon.
-- Clips: ReplicatedStorage.Animations.Weapons.<Class>.Idle / .Walk; the source
-- clips are flagged Action (and some Loop), so priority and looping are set here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sprint = require(script.Parent.Sprint)
local Controls = require(script.Parent.Controls)
local ActionState = require(script.Parent.ActionState)

local player = Players.LocalPlayer
local animations = ReplicatedStorage:WaitForChild("Animations") :: Folder

local BLEND = 0.2
local WALK_SPEED = 16 -- studs/s at the walk clips' playback rate

local WeaponAnimator = {}

local humanoid: Humanoid? = nil
local idle: AnimationTrack? = nil
local walk: AnimationTrack? = nil
local classConnection: RBXScriptConnection? = nil
local sentCharacter: Model? = nil
local sentStowed: boolean? = nil
local sending = false
local retryAt = 0

-- Report only presentation state, never combat authority. The server removes
-- the model for everyone; character identity rejects requests from an old life.
local function syncStowed(character: Model, stowed: boolean)
	if sending or os.clock() < retryAt then return end
	if character == sentCharacter and stowed == sentStowed then return end
	sending = true
	task.spawn(function()
		local ok, accepted = pcall(function()
			return ReplicatedStorage.Remotes.WeaponAction:InvokeServer("stow", character, stowed)
		end)
		if ok and accepted then
			sentCharacter, sentStowed = character, stowed
		else
			retryAt = os.clock() + 0.5
		end
		sending = false
	end)
end

local function clear()
	for _, track in { idle, walk } do
		if track then
			track:Stop(BLEND)
			track:Destroy()
		end
	end
	idle, walk = nil, nil
end

local function load(animator: Animator, folder: Instance?, name: string, priority: Enum.AnimationPriority): AnimationTrack?
	local animation = folder and folder:FindFirstChild(name)
	if not (animation and animation:IsA("Animation") and animation.AnimationId ~= "") then
		return nil
	end
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	track.Looped = true
	return track
end

local function applyClass(character: Model)
	clear()
	local h = humanoid
	local animator = h and h:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local class = character:GetAttribute("WeaponClass")
	local weapons = animations:FindFirstChild("Weapons")
	local folder = if type(class) == "string" and weapons then weapons:FindFirstChild(class) else nil
	idle = load(animator, folder, "Idle", Enum.AnimationPriority.Idle)
	walk = load(animator, folder, "Walk", Enum.AnimationPriority.Movement)
end

local function onCharacter(character: Model)
	if classConnection then
		classConnection:Disconnect()
		classConnection = nil
	end
	clear()
	humanoid = nil
	local h = character:WaitForChild("Humanoid") :: Humanoid
	h:WaitForChild("Animator")
	if player.Character ~= character then
		return
	end
	humanoid = h
	applyClass(character)
	classConnection = character:GetAttributeChangedSignal("WeaponClass"):Connect(function()
		applyClass(character)
	end)
end

local function setPlaying(track: AnimationTrack?, on: boolean)
	if not track then
		return
	end
	if on and not track.IsPlaying then
		track:Play(BLEND)
	elseif not on and track.IsPlaying then
		track:Stop(BLEND)
	end
end

local function step()
	local h = humanoid
	local character = player.Character
	if not h or not character or h.Parent ~= character then
		return
	end
	local root = h.RootPart
	local controlsBlocked = Controls.isLocked() or ActionState.blocked
		or h.Health <= 0 or h.Sit or (root ~= nil and root.Anchored)
	syncStowed(character, controlsBlocked)
	if not idle and not walk then return end
	local stowed = controlsBlocked or character:GetAttribute("WeaponStowed") == true
		or character:FindFirstChildOfClass("Tool") ~= nil
	local grounded = h.FloorMaterial ~= Enum.Material.Air and not stowed
	local speed = if root then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0
	local moving = grounded and speed > 1 and h.MoveDirection.Magnitude > 0.1
	local walking = moving and walk ~= nil and not Sprint.isRunning()
	setPlaying(walk, walking)
	if walking and walk then
		walk:AdjustSpeed(math.clamp(speed / WALK_SPEED, 0.5, 1.5))
	end
	-- a class without a walk falls back to the default walk while moving (an
	-- idle over it would freeze the legs)
	setPlaying(idle, grounded and not moving)
end

function WeaponAnimator.init()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService.Heartbeat:Connect(step)
end

return WeaponAnimator
