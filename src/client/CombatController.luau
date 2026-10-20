--!strict
-- The player's combat kit: fist basic attack, three technique slots and dodge.
--
-- Basic attack: a four-hit chain played from ReplicatedStorage.Animations.Fists.
-- Swings come from the Strike button, or on their own while an enemy is in range
-- (auto-attack). Soft auto-aim turns the character toward the target; tapping or
-- clicking an enemy makes it the target.
-- Everything is predicted: the animation, dash and effects play at once, and the
-- client reports each action with its server-clock timestamp (GetServerTimeNow).
-- At impact the client casts the shared hitbox and flashes what it hit; the server
-- re-checks hits and owns damage (Combat.luau).
-- PC: 1/2/3 for techniques, Space to dodge, click an enemy to target it.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config).Combat
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local CirculationMinigame = require(script.Parent.CirculationMinigame)
local CombatEffects = require(script.Parent.CombatEffects)
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.State)

local remotes = ReplicatedStorage.Remotes
local attackRemote = remotes.Attack :: RemoteEvent
local dodgeRemote = remotes.Dodge :: RemoteEvent
local castRemote = remotes.Cast :: RemoteEvent
local effectRemote = remotes.Effect :: RemoteEvent
local fistAnimations = (ReplicatedStorage:WaitForChild("Animations") :: Folder):WaitForChild("Fists") :: Folder
local player = Players.LocalPlayer

local TAP_MAX_PIXELS = 12 -- a press that moves further is a drag (camera, thumbstick)
local TAP_MAX_SECONDS = 0.35
local DAMAGE_COLOR = Color3.fromRGB(255, 240, 200)
local HURT_COLOR = Color3.fromRGB(255, 90, 80)
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }

local CombatController = {}

local tracks: { AnimationTrack } = {}
local playing: AnimationTrack?
local chainIndex = 0
local lastSwing = -math.huge
local lastDodge = -math.huge
local readyAt: { [string]: number } = {} -- technique id -> os.clock() it's off cooldown
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

local function playAnimation(index: number)
	if playing then
		playing:Stop(0.05)
	end
	local track = tracks[index]
	if track then
		track:Play(0.05)
		playing = track
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

-- The character's root, if it can act right now.
local function myRoot(): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or CirculationMinigame.isRunning() then
		return nil
	end
	return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Soft auto-aim: turn to face the target on the flat. Returns the aim direction.
local function faceTarget(root: BasePart): Vector3
	local aimed = currentTarget(root.Position)
	local aimedRoot = aimed and rootOf(aimed)
	if aimedRoot then
		local look = Vector3.new(aimedRoot.Position.X, root.Position.Y, aimedRoot.Position.Z)
		if (look - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, look)
		end
	end
	local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
end

local function excludeMe(): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	return params
end

--[[ Basic attack ]]

function CombatController.swing()
	local now = os.clock()
	local root = myRoot()
	if now - lastSwing < Config.SWING_SECONDS or not root then
		return
	end
	chainIndex = if now - lastSwing > Config.CHAIN_RESET then 1 else chainIndex % #Config.FIST_DAMAGE + 1
	lastSwing = now
	faceTarget(root)
	playAnimation(chainIndex)

	local swingTime = workspace:GetServerTimeNow()
	task.delay(Config.HIT_DELAY, function()
		local hits: { Model } = {}
		if root.Parent and myRoot() then
			local cframe, size = Hitbox.box(root)
			for _, model in Hitbox.enemiesIn(cframe, size, excludeMe(), root.Position) do
				if #hits >= Config.MAX_TARGETS then
					break
				end
				table.insert(hits, model)
				CombatEffects.flash(model)
			end
		end
		attackRemote:FireServer(swingTime, hits)
	end)
end

--[[ Dodge ]]

function CombatController.dodge()
	local now = os.clock()
	local root = myRoot()
	if now - lastDodge < Config.DODGE_COOLDOWN or not root then
		return
	end
	lastDodge = now
	dodgeRemote:FireServer(workspace:GetServerTimeNow())

	local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	local move = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	local dir = if move.Magnitude > 0.1 then move.Unit else (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	push.PrimaryTangentAxis = Vector3.xAxis
	push.SecondaryTangentAxis = Vector3.zAxis
	push.PlaneVelocity = Vector2.new(dir.X, dir.Z) * Config.DODGE_SPEED
	push.MaxForce = math.huge
	push.Parent = root
	CombatEffects.flyingSword(root, Config.DODGE_SECONDS)
	task.delay(Config.DODGE_SECONDS, function()
		push:Destroy()
		attachment:Destroy()
	end)
end

--[[ Techniques ]]

-- Client-side guess at the chain's targets, for the predicted visual only.
local function predictChain(origin: Vector3, def: Techniques.Def): { Model }
	local hits: { Model } = {}
	local seen: { [Model]: boolean } = {}
	local from, reach = origin, def.range :: number
	while #hits < (def.jumps :: number) + 1 do
		local best, bestDist = nil, reach
		for _, model in CollectionService:GetTagged("Enemy") do
			if model:IsA("Model") and not seen[model] and Hitbox.alive(model) then
				local d = distanceTo(model, from)
				if d <= bestDist then
					best, bestDist = model, d
				end
			end
		end
		if not best then
			break
		end
		table.insert(hits, best)
		seen[best] = true
		from, reach = best:GetPivot().Position, def.jumpRange :: number
	end
	return hits
end

-- Predicted hit flashes for the area techniques.
local function flashArea(def: Techniques.Def, origin: Vector3, dir: Vector3)
	local cframe, size
	if def.kind == "line" then
		local length = def.length :: number
		cframe = CFrame.lookAt(origin, origin + dir) * CFrame.new(0, 0, -length / 2)
		size = Vector3.new(def.width :: number, 12, length)
	elseif def.kind == "circle" then
		local r = def.radius :: number
		cframe, size = CFrame.new(origin), Vector3.new(r * 2, 16, r * 2)
	else
		return
	end
	for _, model in Hitbox.enemiesIn(cframe, size, excludeMe(), origin) do
		CombatEffects.flash(model)
	end
end

function CombatController.cast(slot: number)
	local id = State.current.techniques.slots[slot]
	local def = id and Techniques.Defs[id]
	if not def then
		Hud.toast("This slot is empty. Learn techniques from manuals.")
		return
	end
	local root = myRoot()
	local now = os.clock()
	if not root or now < (readyAt[def.id] or 0) then
		return
	end
	readyAt[def.id] = now + def.cooldown
	local dir = faceTarget(root)
	playAnimation(def.animation)
	local chain = if def.kind == "chain" then predictChain(root.Position, def) else nil
	CombatEffects.cast(player.Character, def.id, root.Position, dir, chain)
	if chain then
		for _, model in chain do
			CombatEffects.flash(model, def.color)
		end
	end
	flashArea(def, root.Position, dir)
	castRemote:FireServer(def.id, workspace:GetServerTimeNow(), dir)
end

-- Labels, colors and cooldown overlays for the technique and dodge buttons.
local function bindButtons(gui: ScreenGui)
	local buttons: { TextButton } = {}
	for slot = 1, Techniques.SLOTS do
		local button = gui:FindFirstChild(`Technique{slot}`) :: TextButton
		buttons[slot] = button
		button.Activated:Connect(function()
			CombatController.cast(slot)
		end)
	end
	State.onChanged(function(s)
		for slot, button in buttons do
			local def = Techniques.Defs[s.techniques.slots[slot] or ""]
			local label = button:FindFirstChild("NameLabel") :: TextLabel
			label.Text = if def then def.name else ""
			local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
			stroke.Color = if def then def.color else Color3.fromRGB(70, 80, 80)
		end
	end)
	local dodgeButton = gui:FindFirstChild("DodgeButton") :: TextButton
	dodgeButton.Activated:Connect(CombatController.dodge)

	local function showCooldown(button: GuiObject, remaining: number, total: number)
		local overlay = button:FindFirstChild("Cooldown") :: Frame
		overlay.Visible = remaining > 0
		overlay.Size = UDim2.fromScale(1, math.clamp(remaining / total, 0, 1))
		local text = button:FindFirstChild("CooldownLabel") :: TextLabel?
		if text then
			text.Visible = remaining > 0
			text.Text = string.format("%d", math.ceil(remaining))
		end
	end
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for slot, button in buttons do
			local def = Techniques.Defs[State.current.techniques.slots[slot] or ""]
			if def then
				showCooldown(button, (readyAt[def.id] or 0) - now, def.cooldown)
			else
				showCooldown(button, 0, 1)
			end
		end
		showCooldown(dodgeButton, lastDodge + Config.DODGE_COOLDOWN - now, Config.DODGE_COOLDOWN)
	end)
end

--[[ Targeting by tap/click ]]

-- Tap or click an enemy to make it the target (and swing at it).
local function pickAt(position: Vector2)
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, camera }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	local model = hit and Hitbox.enemyOf(hit.Instance)
	if model then
		target = model
		CombatController.swing()
	end
end

local function bindTapTargeting()
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
end

--[[ Server effects ]]

local function onEffect(kind: string, ...: any)
	local args = { ... }
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if kind == "damage" then
		CombatEffects.number(args[1], tostring(args[2]), DAMAGE_COLOR)
	elseif kind == "hurt" then
		if character and root then
			CombatEffects.flash(character, HURT_COLOR)
			CombatEffects.number(root.Position, `-{args[1]}`, HURT_COLOR, 18)
		end
	elseif kind == "perfect" then
		local refund = args[1] :: number
		for id, t in readyAt do
			readyAt[id] = t - refund
		end
		if root then
			CombatEffects.number(root.Position, "Perfect dodge!", Color3.fromRGB(170, 225, 255), 20)
		end
	elseif kind == "qi" then
		CombatEffects.number(args[1], `+{args[2]} qi`, Color3.fromRGB(120, 235, 180), 20)
	elseif kind == "cast" then
		local caster = args[1] :: Player
		CombatEffects.cast(caster.Character, args[2], args[3], args[4], args[5])
	end
end

function CombatController.init(gui: ScreenGui)
	player.CharacterAdded:Connect(loadTracks)
	if player.Character then
		task.spawn(loadTracks, player.Character)
	end

	local strike = gui:FindFirstChild("AttackButton") :: TextButton
	strike.Activated:Connect(CombatController.swing)
	bindButtons(gui)
	bindTapTargeting()

	-- Space dodges instead of jumping; 1/2/3 cast
	ContextActionService:BindActionAtPriority("Dodge", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			CombatController.dodge()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local slot = table.find(KEYS, input.KeyCode)
		if slot then
			CombatController.cast(slot)
		end
	end)

	effectRemote.OnClientEvent:Connect(onEffect)

	RunService.Heartbeat:Connect(function()
		local root = myRoot()
		if not Config.AUTO_ATTACK or not root then
			return
		end
		local aimed = currentTarget(root.Position)
		if aimed and distanceTo(aimed, root.Position) <= Config.AUTO_RANGE then
			CombatController.swing()
		end
	end)
end

return CombatController
