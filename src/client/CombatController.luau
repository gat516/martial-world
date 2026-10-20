--!strict
-- Predicted combat driven by the shared ActionRules state machine. Holding M1
-- requests another swing when legal; one short input buffer prioritises dodge,
-- then a technique, then a tapped basic. The Attack remote carries ordered
-- action starts and hit reports; the server uses the same action timelines.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config).Combat
local Rules = require(ReplicatedStorage.Shared.ActionRules)
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local Items = require(ReplicatedStorage.Shared.Items)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local ActionState = require(script.Parent.ActionState)
local Controls = require(script.Parent.Controls)
local Menus = require(script.Parent.Menus)
local CirculationMinigame = require(script.Parent.CirculationMinigame)
local BuildMode = require(script.Parent.BuildMode)
local CombatEffects = require(script.Parent.CombatEffects)
local Hud = require(script.Parent.Hud)
local LockOn = require(script.Parent.LockOn)
local Meditation = require(script.Parent.Meditation)
local Platform = require(script.Parent.Platform)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.State)

local remotes = ReplicatedStorage.Remotes
local attackRemote = remotes.Attack :: RemoteEvent
local effectRemote = remotes.Effect :: RemoteEvent
local animations = ReplicatedStorage:WaitForChild("Animations") :: Folder
local fistAnimations = animations:WaitForChild("Fists") :: Folder
local dashAnimations = animations:WaitForChild("Dash") :: Folder
local perfectAnimations = animations:WaitForChild("PerfectDodge") :: Folder
local player = Players.LocalPlayer

local TAP_MAX_PIXELS = 12 -- a press that moves further is a drag (camera, thumbstick)
local TAP_MAX_SECONDS = 0.35
local DAMAGE_COLOR = Color3.fromRGB(255, 240, 200)
local HURT_COLOR = Color3.fromRGB(255, 90, 80)

local CombatController = {}

local tracks: { AnimationTrack } = {}
local dashTracks: { [string]: AnimationTrack } = {} -- "Forward" / "Back" / "Left" / "Right"
local perfectTracks: { [string]: AnimationTrack } = {}
local perfectPlaying: AnimationTrack?
local idleFades: { [AnimationTrack]: {} } = {}
local dodgeVisual: { character: Model, sequence: number, started: number, style: string?, played: boolean }?
type Runtime = {
	action: Rules.Action,
	root: BasePart,
	character: Model,
	direction: Vector3,
	track: AnimationTrack?,
	stopped: RBXScriptConnection?,
	released: boolean,
	reported: boolean,
	suppressed: boolean,
	steer: ((number) -> ())?,
	finishDash: (() -> ())?,
}
local runtime: Runtime?
local sequence = 0
local readyCharacter: Model?
local synced = false
local focused = true
local held: { [InputObject]: boolean } = {}
local pending: { kind: string, id: string?, expires: number }?
local target: Model?
local advanceRuntime: (number) -> ()
local request: (string, string?) -> ()

local function clearInputs()
	table.clear(held)
	pending = nil
	ActionState.basicHeld = false
end

-- Visual recovery is independent of action recovery. Hold the outgoing pose
-- briefly, then fade its weight over idle/walk while the player is free to act.
local function fadeToIdle(track: AnimationTrack, seconds: number)
	if not track.IsPlaying then return end
	local token = {}
	idleFades[track] = token
	track:AdjustSpeed(0)
	task.delay(Config.POSE_HOLD_SECONDS, function()
		if idleFades[track] ~= token then return end
		track:Stop(seconds)
		task.delay(seconds, function()
			if idleFades[track] == token then idleFades[track] = nil end
		end)
	end)
end

local function clearIdleFades()
	for track in idleFades do
		track:Stop(Config.ACTION_CROSSFADE)
	end
	table.clear(idleFades)
end

local function stopPerfect(completed: boolean?)
	if perfectPlaying then
		if completed then
			fadeToIdle(perfectPlaying, Config.DODGE_IDLE_FADE)
		else
			perfectPlaying:Stop(Config.ACTION_CROSSFADE)
		end
		perfectPlaying = nil
	end
end

local function stopRuntime(suppress: boolean, completed: boolean?)
	if suppress then
		stopPerfect()
		clearIdleFades()
	end
	local old = runtime
	runtime = nil
	if not old then
		return
	end
	if suppress then
		attackRemote:FireServer({ op = "cancel", character = old.character, sequence = old.action.sequence })
	end
	if old.stopped then
		old.stopped:Disconnect()
	end
	if old.track then
		if completed and not old.suppressed then
			fadeToIdle(old.track, if old.action.kind == "dodge" then Config.DODGE_IDLE_FADE else Config.ATTACK_IDLE_FADE)
		else
			old.track:Stop(Config.ACTION_CROSSFADE)
		end
	end
	if old.finishDash then
		old.finishDash()
	end
end

local function loadTracks(character: Model)
	clearInputs()
	stopRuntime(true)
	readyCharacter, synced = nil, false
	ActionState.current = Rules.new()
	dodgeVisual = nil
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	local nextTracks: { AnimationTrack } = {}
	local nextDashes: { [string]: AnimationTrack } = {}
	local nextPerfects: { [string]: AnimationTrack } = {}
	for i = 1, #Config.FIST_STEPS do
		local animation = fistAnimations:FindFirstChild(tostring(i)) :: Animation?
		if animation then
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = false
			nextTracks[i] = track
		end
	end
	for _, animation in dashAnimations:GetChildren() do
		if animation:IsA("Animation") and animation.AnimationId ~= "" then
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Action2
			track.Looped = false
			nextDashes[animation.Name] = track
		end
	end
	for _, animation in perfectAnimations:GetChildren() do
		if animation:IsA("Animation") and animation.AnimationId ~= "" then
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Action3
			track.Looped = false
			nextPerfects[animation.Name] = track
		end
	end
	if player.Character ~= character then
		for _, track in nextTracks do track:Destroy() end
		for _, track in nextDashes do track:Destroy() end
		for _, track in nextPerfects do track:Destroy() end
		return
	end
	for _, track in tracks do track:Destroy() end
	for _, track in dashTracks do track:Destroy() end
	for _, track in perfectTracks do track:Destroy() end
	tracks, dashTracks = nextTracks, nextDashes
	perfectTracks = nextPerfects
	readyCharacter = character
	humanoid.Died:Connect(function()
		if readyCharacter == character then
			clearInputs()
			stopRuntime(true)
			readyCharacter, synced = nil, false
		end
	end)
	attackRemote:FireServer({ op = "sync", character = character })
end

local function rootOf(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function distanceTo(model: Model, from: Vector3): number
	local root = rootOf(model)
	return if root then (root.Position - from).Magnitude else math.huge
end

-- The locked enemy; else the picked target if it's still alive and near;
-- otherwise the nearest enemy.
local function currentTarget(from: Vector3): Model?
	local locked = LockOn.target()
	if locked and Hitbox.alive(locked) then
		return locked
	end
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

-- The character's root, if it can act right now (not circulating, meditating
-- or building).
local function myRoot(): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not humanoid
		or character ~= readyCharacter
		or not synced
		or not focused
		or humanoid.Health <= 0
		or humanoid.Sit
		or Menus.isOpen()
		or UserInputService:GetFocusedTextBox() ~= nil
		or CirculationMinigame.isRunning()
		or Meditation.isActive()
		or BuildMode.isActive()
	then
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

-- Dash direction is captured when the buffered action actually starts.
local function startDash(current: Runtime)
	local root = current.root
	local humanoid = current.character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local move = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	local input = Controls.moveVector()
	local camera = workspace.CurrentCamera
	if move.Magnitude < 0.1 and input.Magnitude > 0.1 and camera then
		move = camera.CFrame:VectorToWorldSpace(input) * Vector3.new(1, 0, 1)
	end
	local direction = if move.Magnitude > 0.1 then move.Unit else -ActionState.facing
	local want = direction * Config.DODGE_SPEED
	local function steer(maxChange: number)
		if not root.Parent then return end
		local velocity = root.AssemblyLinearVelocity
		local change = want - velocity * Vector3.new(1, 0, 1)
		if change.Magnitude > maxChange then change = change.Unit * maxChange end
		local rise = math.min(0, Config.DODGE_MAX_RISE - velocity.Y)
		root:ApplyImpulse((change + Vector3.yAxis * rise) * root.AssemblyMass)
	end
	local right = root.CFrame.RightVector:Dot(direction)
	local side = if right > 0.38 then "Right" elseif right < -0.38 then "Left"
		elseif root.CFrame.LookVector:Dot(direction) < 0 then "Back" else "Forward"
	-- These clips are two lateral pairs: 1/2 duck left/right, 4/3 slip
	-- left/right. Forward diagonals use the duck; side/back diagonals the slip.
	local style: string? = nil
	if side == "Left" or side == "Right" then
		style = (if root.CFrame.LookVector:Dot(direction) > 0.35 then "Duck" else "Slip") .. side
	end
	dodgeVisual = {
		character = current.character, sequence = current.action.sequence,
		started = current.action.started, style = style, played = false,
	}
	current.track = dashTracks[side]
	current.steer = steer
	current.finishDash = function()
		current.steer, current.finishDash = nil, nil
		if not root.Parent then return end
		local velocity = root.AssemblyLinearVelocity
		local flat = velocity * Vector3.new(1, 0, 1)
		if flat.Magnitude > Config.DODGE_EXIT_SPEED then
			local excess = flat - flat.Unit * Config.DODGE_EXIT_SPEED
			root:ApplyImpulse(-excess * root.AssemblyMass)
		end
	end
	steer(Config.DODGE_SPEED * 2)
	LockOn.noteDodge()
	Sfx.play("Dodge")
	CombatEffects.dashTrail(current.character, root, Config.DODGE_SECONDS)
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

-- Timelines mirror the authored markers, including explicit windows for the
-- animations without markers. Stopping a track never advances its timeline.
local function release(current: Runtime)
	current.released = true
	if current.action.kind ~= "cast" or not current.action.id then return end
	local def = Techniques.Defs[current.action.id]
	attackRemote:FireServer({
		op = "hit", character = current.character, sequence = current.action.sequence,
		time = math.clamp(workspace:GetServerTimeNow(), Rules.hitAt(current.action), Rules.stopAt(current.action)),
	})
	local origin, direction = current.root.Position, current.direction
	local chain = if def.kind == "chain" then predictChain(origin, def) else nil
	CombatEffects.cast(current.character, def.id, origin, direction, chain)
	if chain then
		for _, model in chain do CombatEffects.flash(model, def.color) end
	end
	flashArea(def, origin, direction)
end

local function sweep(current: Runtime, now: number)
	if current.reported then return end
	local root = current.root
	local cframe, size = Hitbox.box(root)
	local hits: { Model } = {}
	for _, model in Hitbox.enemiesIn(cframe, size, excludeMe(), root.Position) do
		if #hits >= Config.MAX_TARGETS then break end
		table.insert(hits, model)
		CombatEffects.flash(model)
		Sfx.play("Hit", nil, 0.05)
	end
	if #hits > 0 then
		current.reported = true
		attackRemote:FireServer({
			op = "hit", character = current.character, sequence = current.action.sequence,
			time = math.clamp(now, Rules.hitAt(current.action), Rules.stopAt(current.action)), targets = hits,
		})
	end
end

advanceRuntime = function(now: number)
	local current = runtime
	if not current then return end
	if not current.root.Parent or current.character ~= player.Character then
		stopRuntime(true)
		return
	end
	local action = current.action
	if not current.suppressed and action.kind ~= "dodge" then
		if now >= Rules.hitAt(action) then
			-- If a slow frame crosses the whole hit window, take one final sweep.
			local first = not current.released
			if first then release(current) end
			if action.kind == "basic" and (first or now <= Rules.stopAt(action)) then
				sweep(current, now)
			end
		end
	end
	if now >= Rules.stopAt(action) and current.finishDash then current.finishDash() end
	if now >= Rules.endAt(action) then stopRuntime(false, true) end
end

local function tryStart(kind: string, id: string?): boolean
	local root = myRoot()
	if not root then return false end
	local character = player.Character :: Model
	if kind == "basic" and character:FindFirstChildOfClass("Tool") then return false end
	if kind == "cast" and (not id or not State.current.techniques.owned[id] or not table.find(State.current.hotbar, id)) then
		return false
	end
	local now = workspace:GetServerTimeNow()
	advanceRuntime(now)
	local action = Rules.start(ActionState.current, kind, id, now, sequence + 1)
	if not action then return false end
	sequence += 1
	stopRuntime(false)
	stopPerfect()
	clearIdleFades()
	local direction = if kind == "dodge" then root.CFrame.LookVector * Vector3.new(1, 0, 1) else faceTarget(root)
	direction = if direction.Magnitude > 0.01 then direction.Unit else Vector3.zAxis
	ActionState.facing = direction
	local current: Runtime = {
		action = action, root = root, character = character, direction = direction,
		released = false, reported = false, suppressed = false,
	}
	runtime = current
	attackRemote:FireServer({
		op = "begin", character = character, sequence = sequence, time = now,
		kind = kind, id = id, aim = direction,
	})
	if kind == "dodge" then
		startDash(current)
	else
		current.track = tracks[action.profile.animation]
		if kind == "basic" then Sfx.play("Swing") end
	end
	local track = current.track
	if track then
		track:Play(Config.ACTION_CROSSFADE, 1, action.profile.speed)
		current.stopped = track.Stopped:Connect(function()
			if runtime == current then
				current.suppressed = true
				attackRemote:FireServer({ op = "cancel", character = character, sequence = action.sequence })
			end
		end)
	end
	return true
end

local priorities = { basic = 1, cast = 2, dodge = 3 }
request = function(kind: string, id: string?)
	if not myRoot() then return end
	local now = workspace:GetServerTimeNow()
	if pending and pending.expires > now and priorities[pending.kind] > priorities[kind] then return end
	if tryStart(kind, id) then
		pending = nil
	else
		pending = { kind = kind, id = id, expires = now + Config.INPUT_BUFFER }
	end
end

function CombatController.swing() request("basic", nil) end
function CombatController.dodge() request("dodge", nil) end
function CombatController.cast(id: string) request("cast", id) end

function CombatController.cooldown(id: string): (number, number)
	local def = Techniques.Defs[id]
	if not def then return 0, 1 end
	return math.max(0, (ActionState.current.ready[id] or 0) - workspace:GetServerTimeNow()), def.cooldown
end

local function bindButtons(gui: ScreenGui)
	local dodgeButton = gui:FindFirstChild("DodgeButton", true) :: TextButton
	dodgeButton.Activated:Connect(CombatController.dodge)
	local overlay = dodgeButton:FindFirstChild("Cooldown") :: Frame
	RunService.RenderStepped:Connect(function()
		local remaining = ActionState.current.dodgeReady - workspace:GetServerTimeNow()
		overlay.Visible = remaining > 0
		overlay.Size = UDim2.fromScale(1, math.clamp(remaining / Config.DODGE_COOLDOWN, 0, 1))
	end)
end

--[[ Targeting by tap/click ]]

-- Pick before starting an attack so its windup faces the clicked enemy.
local function pickAt(position: Vector2): boolean
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, camera }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	local model = hit and Hitbox.enemyOf(hit.Instance)
	if model then
		target = model
		LockOn.pick(model)
		return true
	end
	return false
end

local function bindTapTargeting()
	local pressStarts: { [InputObject]: { at: number, position: Vector3 } } = {}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch then
			pressStarts[input] = { at = os.clock(), position = input.Position }
		elseif kind == Enum.UserInputType.MouseButton1 then
			local holding = player.Character and player.Character:FindFirstChildOfClass("Tool")
			if not holding and myRoot() then
				pickAt(Vector2.new(input.Position.X, input.Position.Y))
				held[input] = true
				ActionState.basicHeld = true
				CombatController.swing()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		held[input] = nil
		ActionState.basicHeld = next(held) ~= nil
		local start = pressStarts[input]
		pressStarts[input] = nil
		if start and myRoot() and os.clock() - start.at <= TAP_MAX_SECONDS
			and (input.Position - start.position).Magnitude <= TAP_MAX_PIXELS then
			if pickAt(Vector2.new(input.Position.X, input.Position.Y)) then CombatController.swing() end
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		focused = false
		table.clear(pressStarts)
		clearInputs()
		stopRuntime(true)
	end)
	UserInputService.WindowFocused:Connect(function() focused = true end)
end

--[[ Server effects ]]

local function playPerfect(dodgeSequence: number)
	local visual = dodgeVisual
	if not visual or visual.played or visual.character ~= player.Character or visual.sequence ~= dodgeSequence
		or sequence ~= dodgeSequence or not myRoot() then
		return
	end
	if workspace:GetServerTimeNow() > visual.started + Config.DODGE_SECONDS + Config.PERFECT_ANIMATION_GRACE then
		return
	end
	local track = visual.style and perfectTracks[visual.style]
	if not track then return end
	visual.played = true
	local current = runtime
	if current and current.action.sequence == dodgeSequence then
		-- Swap only the pose. Dash motion, invulnerability and recovery keep
		-- their original deadlines; stopping this track must not cancel them.
		if current.stopped then
			current.stopped:Disconnect()
			current.stopped = nil
		end
		if current.track then current.track:Stop(0.04) end
		current.track = nil
	end
	stopPerfect()
	clearIdleFades()
	perfectPlaying = track
	track:Play(0.04, 1, 1)
	task.delay(Config.PERFECT_ANIMATION_SECONDS, function()
		if perfectPlaying == track then stopPerfect(true) end
	end)
end

-- Short clips can end before gameplay recovery does. Catch their last pose
-- before the Animator drops the track's weight; the action/fade owns release.
local function holdClipEnd(track: AnimationTrack?, dt: number)
	if not track or not track.IsPlaying or track.Speed <= 0 or track.Length <= 0 then return end
	local lastPose = math.max(0, track.Length - 0.001)
	if track.TimePosition + dt * track.Speed >= lastPose then
		track.TimePosition = lastPose
		track:AdjustSpeed(0)
	end
end

local function onEffect(kind: string, ...: any)
	local args = { ... }
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if kind == "action" then
		local serverCharacter, acknowledged, accepted, snapshot = args[1], args[2], args[3], args[4]
		if serverCharacter ~= player.Character or serverCharacter ~= readyCharacter then return end
		if acknowledged == 0 then
			ActionState.current = snapshot
			synced = true
		elseif acknowledged == sequence then
			if not accepted then
				stopRuntime(false)
				pending = nil
			end
			ActionState.current = snapshot
		end
	elseif kind == "damage" then
		CombatEffects.number(args[1], tostring(args[2]), DAMAGE_COLOR)
		CombatEffects.sparks(args[1])
		CombatEffects.shake(0.12)
	elseif kind == "hurt" then
		if character and root then
			CombatEffects.flash(character, HURT_COLOR)
			CombatEffects.number(root.Position, `-{args[1]}`, HURT_COLOR, 18)
			CombatEffects.shake(0.35)
			Sfx.play("Hurt")
		end
	elseif kind == "perfect" then
		if args[3] ~= character then return end
		local refund = args[1] :: number
		for id, t in ActionState.current.ready do
			ActionState.current.ready[id] = t - refund
		end
		playPerfect(args[2])
		if character and root then
			CombatEffects.perfectDodge(character, root)
			Sfx.play("PerfectDodge")
			CombatEffects.number(root.Position, "Perfect dodge!", Color3.fromRGB(255, 224, 150), 20)
		end
	elseif kind == "qi" then
		CombatEffects.number(args[1], `+{args[2]} qi`, Color3.fromRGB(120, 235, 180), 20)
	elseif kind == "stones" then
		CombatEffects.number(args[1] + Vector3.new(0, 1.5, 0), `+{args[2]} spirit stones`, Color3.fromRGB(225, 240, 255), 18)
		Sfx.play("Pickup", nil, 0.1)
	elseif kind == "insight" then
		Hud.toast(`+{args[1]} insight: {args[2]}`)
	elseif kind == "manual" then
		local def = Techniques.Defs[args[1]]
		if def then
			Hud.toast(if args[2]
				then `Manual found: {def.name}! It's on your hotbar.`
				else `Manual found: {def.name}! Drag it onto your hotbar from the Inventory.`)
		end
	elseif kind == "loot" then
		local item = Items.Defs[args[1]]
		if item then
			local at = args[3] or (root and root.Position)
			if at then
				CombatEffects.number(at, `+{args[2]} {item.name}`, Items.rarityColor(item), 20)
			end
			Sfx.play("Pickup", nil, 0.1)
			if (Items.Rarities[item.rarity] or { order = 0 }).order >= 4 then
				Hud.toast(`You obtained a {item.name}!`)
			end
		end
	elseif kind == "used" then
		local item = Items.Defs[args[1]]
		if item and root then
			CombatEffects.sparks(root.Position)
			CombatEffects.number(root.Position, item.name, item.color, 16)
		end
	elseif kind == "bolt" then
		CombatEffects.bolt(args[1])
	elseif kind == "tribulationStart" then
		CombatEffects.storm(args[1], args[2])
	elseif kind == "tribulationEnd" then
		CombatEffects.storm(args[1], nil)
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

	local strike = gui:FindFirstChild("AttackButton", true) :: TextButton
	strike.InputBegan:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and myRoot() then
			held[input] = true
			ActionState.basicHeld = true
			CombatController.swing()
		end
	end)
	strike.Activated:Connect(function(input)
		-- Gamepad activation has no matching touch/mouse hold.
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			CombatController.swing()
		end
	end)
	bindButtons(gui)
	bindTapTargeting()

	-- Q dashes (Space stays jump; touch uses the Dash button)
	ContextActionService:BindActionAtPriority("Dodge", function(_, inputState)
		if BuildMode.isActive() then
			return Enum.ContextActionResult.Pass -- B cancels in build mode
		end
		if inputState == Enum.UserInputState.Begin then
			CombatController.dodge()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	effectRemote.OnClientEvent:Connect(onEffect)
	RunService.PreAnimation:Connect(function(dt)
		holdClipEnd(if runtime then runtime.track else nil, dt)
		holdClipEnd(perfectPlaying, dt)
	end)

	player.CharacterRemoving:Connect(function()
		clearInputs()
		stopRuntime(true)
		readyCharacter, synced = nil, false
		ActionState.current = Rules.new()
	end)
	RunService.Heartbeat:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		local root = myRoot()
		ActionState.blocked = root == nil
		if not root then
			clearInputs()
			stopRuntime(true)
			CombatEffects.markTarget(nil)
			return
		end
		local holding = player.Character and player.Character:FindFirstChildOfClass("Tool")
		if holding then
			clearInputs()
			if runtime and runtime.action.kind == "basic" then stopRuntime(true) end
		end
		advanceRuntime(now)
		if runtime and runtime.steer then runtime.steer(Config.DODGE_ACCEL * dt) end
		local aimed = currentTarget(root.Position)
		CombatEffects.markTarget(if LockOn.target() then nil else aimed)
		if pending then
			if pending.expires < now then
				pending = nil
			elseif tryStart(pending.kind, pending.id) then
				pending = nil
			end
		end
		local autoAttack = Config.AUTO_ATTACK and Platform.isTouch() and LockOn.isAuto()
			and aimed ~= nil and distanceTo(aimed :: Model, root.Position) <= Config.AUTO_RANGE
		if not pending and not holding and (ActionState.basicHeld or autoAttack) then
			tryStart("basic", nil)
		end
	end)
end

return CombatController
