--!strict
-- Fist basic attack: a four-hit chain played from ReplicatedStorage.Animations.Fists.
-- Swings come from the Strike button, or on their own while an enemy is in range
-- (auto-attack). Soft auto-aim turns the character toward the target; tapping or
-- clicking an enemy makes it the target.
-- Hits are predicted: at impact the client casts the shared hitbox, flashes what it
-- hit right away, and reports every swing (hit or miss) with its server-clock
-- timestamp. The server re-checks the hit before dealing damage (Combat.luau).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config).Combat
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local CirculationMinigame = require(script.Parent.CirculationMinigame)

local attackRemote = ReplicatedStorage.Remotes.Attack :: RemoteEvent
local fistAnimations = (ReplicatedStorage:WaitForChild("Animations") :: Folder):WaitForChild("Fists") :: Folder
local player = Players.LocalPlayer

local FLASH_SECONDS = 0.12
local TAP_MAX_PIXELS = 12 -- a press that moves further is a drag (camera, thumbstick)
local TAP_MAX_SECONDS = 0.35

local CombatController = {}

local tracks: { AnimationTrack } = {}
local playing: AnimationTrack?
local chainIndex = 0
local lastSwing = -math.huge
local target: Model? -- picked by tapping/clicking; cleared when it dies or leaves range

local function loadTracks(character: Model)
	table.clear(tracks)
	playing = nil
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	for i = 1, #Config.FIST_DAMAGE do
		local animation = fistAnimations:FindFirstChild(tostring(i)) :: Animation?
		if animation then
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = false
			tracks[i] = track
		end
	end
end

local function rootOf(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function distanceTo(model: Model, from: Vector3): number
	local root = rootOf(model)
	return if root then (root.Position - from).Magnitude else math.huge
end

-- The picked target if it's still alive and near, otherwise the nearest enemy.
local function currentTarget(from: Vector3): Model?
	if target and Hitbox.alive(target) and distanceTo(target, from) <= Config.AIM_RANGE then
		return target
	end
	target = nil
	local best, bestDist = nil, Config.AIM_RANGE
	for _, model in CollectionService:GetTagged("Enemy") do
		if model:IsA("Model") and Hitbox.alive(model) then
			local d = distanceTo(model, from)
			if d <= bestDist then
				best, bestDist = model, d
			end
		end
	end
	return best
end

local function canAct(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and not CirculationMinigame.isRunning()
end

-- Predicted hit feedback, shown before the server confirms.
local function flash(model: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	task.delay(FLASH_SECONDS, highlight.Destroy, highlight)
end

function CombatController.swing()
	local now = os.clock()
	if now - lastSwing < Config.SWING_SECONDS or not canAct() then
		return
	end
	local character = player.Character :: Model
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	chainIndex = if now - lastSwing > Config.CHAIN_RESET then 1 else chainIndex % #Config.FIST_DAMAGE + 1
	lastSwing = now

	-- soft auto-aim: face the target on the flat
	local aimed = currentTarget(root.Position)
	local aimedRoot = aimed and rootOf(aimed)
	if aimedRoot then
		local look = Vector3.new(aimedRoot.Position.X, root.Position.Y, aimedRoot.Position.Z)
		if (look - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, look)
		end
	end

	if playing then
		playing:Stop(0.05)
	end
	local track = tracks[chainIndex]
	if track then
		track:Play(0.05)
		playing = track
	end

	local swingTime = workspace:GetServerTimeNow()
	task.delay(Config.HIT_DELAY, function()
		local hits: { Model } = {}
		if root.Parent and canAct() then
			local cframe, size = Hitbox.box(root)
			local params = OverlapParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character }
			for _, model in Hitbox.enemiesIn(cframe, size, params, root.Position) do
				if #hits >= Config.MAX_TARGETS then
					break
				end
				table.insert(hits, model)
				flash(model)
			end
		end
		attackRemote:FireServer(swingTime, hits)
	end)
end

-- Tap or click an enemy to make it the target (and swing at it).
local function pickAt(position: Vector2)
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	local node: Instance? = hit and hit.Instance
	while node and node ~= workspace do
		if node:IsA("Model") and node:HasTag("Enemy") then
			target = node
			CombatController.swing()
			return
		end
		node = node.Parent
	end
end

function CombatController.init(gui: ScreenGui)
	player.CharacterAdded:Connect(loadTracks)
	if player.Character then
		task.spawn(loadTracks, player.Character)
	end

	local button = gui:FindFirstChild("AttackButton") :: TextButton
	button.Activated:Connect(CombatController.swing)

	local pressStarts: { [InputObject]: { at: number, position: Vector3 } } = {}
	UserInputService.InputBegan:Connect(function(input, processed)
		local kind = input.UserInputType
		if not processed and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
			pressStarts[input] = { at = os.clock(), position = input.Position }
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local start = pressStarts[input]
		pressStarts[input] = nil
		if
			start
			and os.clock() - start.at <= TAP_MAX_SECONDS
			and (input.Position - start.position).Magnitude <= TAP_MAX_PIXELS
		then
			pickAt(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	RunService.Heartbeat:Connect(function()
		if not Config.AUTO_ATTACK or not canAct() then
			return
		end
		local root = (player.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
		local aimed = root and currentTarget(root.Position)
		if root and aimed and distanceTo(aimed, root.Position) <= Config.AUTO_RANGE then
			CombatController.swing()
		end
	end)
end

return CombatController
