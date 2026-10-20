--!strict
-- The player's combat kit: fist basic attack, techniques (cast from the hotbar,
-- HotbarView.luau) and dodge.
--
-- Basic attack: a five-hit chain played from ReplicatedStorage.Animations.Fists.
-- PC swings on M1 (unless an item is held out: then M1 uses it). Touch swings
-- from the Strike button, or on its own in Auto mode while the target is in range
-- (auto-attack, LockOn.luau). The locked enemy (LockOn) is always the target;
-- without one, soft auto-aim turns the character toward the nearest enemy, and
-- tapping or clicking an enemy makes it the target.
-- Everything is predicted: the animation, dash and effects play at once, and the
-- client reports each action with its server-clock timestamp (GetServerTimeNow).
-- Impacts are timed by animation markers: a swing's hitbox is live from the "Hit"
-- marker to the "Hit Stop" marker, and a technique goes off at "Hit". The client
-- flashes what it hit; the server re-checks hits and owns damage (Combat.luau).
-- PC: hotbar keys for techniques, Q to dash, click an enemy to target it.
-- Mobile: hotbar slots for techniques, the Dash button beside Strike.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config).Combat
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local Items = require(ReplicatedStorage.Shared.Items)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
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
local dodgeRemote = remotes.Dodge :: RemoteEvent
local castRemote = remotes.Cast :: RemoteEvent
local effectRemote = remotes.Effect :: RemoteEvent
local animations = ReplicatedStorage:WaitForChild("Animations") :: Folder
local fistAnimations = animations:WaitForChild("Fists") :: Folder
local dashAnimations = animations:WaitForChild("Dash") :: Folder
local player = Players.LocalPlayer

local TAP_MAX_PIXELS = 12 -- a press that moves further is a drag (camera, thumbstick)
local TAP_MAX_SECONDS = 0.35
local DAMAGE_COLOR = Color3.fromRGB(255, 240, 200)
local HURT_COLOR = Color3.fromRGB(255, 90, 80)

local CombatController = {}

local tracks: { AnimationTrack } = {}
local dashTracks: { [string]: AnimationTrack } = {} -- "Forward" / "Back" / "Left" / "Right"
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
	table.clear(dashTracks)
	for _, animation in dashAnimations:GetChildren() do
		-- an Animation left without an id is a placeholder; skip it
		if animation:IsA("Animation") and animation.AnimationId ~= "" then
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Action2
			track.Looped = false
			dashTracks[animation.Name] = track
		end
	end
end

local function playAnimation(index: number): AnimationTrack?
	if playing then
		playing:Stop(0.05)
	end
	local track = tracks[index]
	if track then
		track:Play(0.05)
		playing = track
	end
	return track
end

-- Runs `hit` at the track's "Hit" marker and `stop` at its "Hit Stop" marker. If
-- the track ends or is cut off first, whatever hasn't run yet runs then, so an
-- attack is never lost (and an animation without markers lands when it ends).
local function onMarkers(track: AnimationTrack?, hit: () -> (), stop: (() -> ())?)
	local stage = 0
	local connections: { RBXScriptConnection } = {}
	local function advance(to: number)
		while stage < to do
			stage += 1
			if stage == 1 then
				hit()
			elseif stop then
				stop()
			end
		end
		if stage >= 2 then
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end
	if not track then
		advance(2)
		return
	end
	table.insert(connections, track:GetMarkerReachedSignal("Hit"):Connect(function()
		advance(1)
	end))
	table.insert(connections, track:GetMarkerReachedSignal("Hit Stop"):Connect(function()
		advance(2)
	end))
	table.insert(connections, track.Stopped:Connect(function()
		advance(2)
	end))
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
		or humanoid.Health <= 0
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
	local track = playAnimation(chainIndex)
	Sfx.play("Swing")

	-- The hitbox is cast every frame from "Hit" to "Hit Stop"; the swing is reported
	-- once, as soon as it's hit all it can or when the window closes.
	local swingTime = workspace:GetServerTimeNow()
	local hits: { Model } = {}
	local reported = false
	local window: RBXScriptConnection?
	local function report()
		if window then
			window:Disconnect()
			window = nil
		end
		if not reported then
			reported = true
			attackRemote:FireServer(swingTime, hits)
		end
	end
	local function sweep()
		if not (root.Parent and myRoot()) then
			return
		end
		local cframe, size = Hitbox.box(root)
		for _, model in Hitbox.enemiesIn(cframe, size, excludeMe(), root.Position) do
			if #hits >= Config.MAX_TARGETS then
				break
			end
			if not table.find(hits, model) then
				table.insert(hits, model)
				CombatEffects.flash(model)
				-- on contact, not when the server's damage number arrives a ping later
				Sfx.play("Hit", nil, 0.05)
			end
		end
		if #hits >= Config.MAX_TARGETS then
			report()
		end
	end
	onMarkers(track, function()
		sweep()
		if not reported then
			window = RunService.Heartbeat:Connect(sweep)
		end
	end, report)
end

--[[ Dodge ]]

function CombatController.dodge()
	local now = os.clock()
	local root = myRoot()
	if now - lastDodge < Config.DODGE_COOLDOWN or not root then
		return
	end
	lastDodge = now
	LockOn.noteDodge()
	dodgeRemote:FireServer(workspace:GetServerTimeNow())

	local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	local move = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	-- standing still dashes backward, away from whatever's in front
	local dir = if move.Magnitude > 0.1 then move.Unit else -(root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit

	-- Impulses are mass * change in velocity, so read the mass instead of guessing a
	-- force: one kick to full speed, then small capped top-ups each frame against
	-- the humanoid's ground friction. Upward speed is capped so a slope or an
	-- enemy's collider can't turn the dash into a launch.
	local want = dir * Config.DODGE_SPEED
	local function steer(maxChange: number)
		local mass = root.AssemblyMass
		local v = root.AssemblyLinearVelocity
		local change = want - v * Vector3.new(1, 0, 1)
		if change.Magnitude > maxChange then
			change = change.Unit * maxChange
		end
		local rise = math.min(0, Config.DODGE_MAX_RISE - v.Y)
		root:ApplyImpulse((change + Vector3.yAxis * rise) * mass)
	end
	steer(Config.DODGE_SPEED * 2)
	Sfx.play("Dodge")
	CombatEffects.dashTrail(player.Character :: Model, root, Config.DODGE_SECONDS)

	-- Pick the animation from the dash direction relative to facing; any sideways
	-- lean (diagonals included) counts as a side dash. The facing is held for the
	-- dash so the humanoid doesn't swing round to face the way it's going.
	local right = root.CFrame.RightVector:Dot(dir)
	local side = if right > 0.38
		then "Right"
		elseif right < -0.38 then "Left"
		elseif root.CFrame.LookVector:Dot(dir) < 0 then "Back"
		else "Forward"
	local dashTrack = dashTracks[side]
	if dashTrack then
		dashTrack:Play(0.05)
		humanoid.AutoRotate = false
	end

	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not root.Parent then
			connection:Disconnect()
			return
		end
		if os.clock() - started < Config.DODGE_SECONDS then
			steer(Config.DODGE_ACCEL * dt)
			return
		end
		connection:Disconnect()
		if dashTrack then
			humanoid.AutoRotate = true
		end
		-- bleed off the leftover speed so the dash doesn't carry into a slide
		local v = root.AssemblyLinearVelocity
		local flat = v * Vector3.new(1, 0, 1)
		if flat.Magnitude > Config.DODGE_EXIT_SPEED then
			local excess = flat - flat.Unit * Config.DODGE_EXIT_SPEED
			local rise = math.min(0, Config.DODGE_MAX_RISE - v.Y)
			root:ApplyImpulse((Vector3.yAxis * rise - excess) * root.AssemblyMass)
		end
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

-- Seconds left on a technique's cooldown, and its full length.
function CombatController.cooldown(id: string): (number, number)
	local def = Techniques.Defs[id]
	if not def then
		return 0, 1
	end
	return math.max(0, (readyAt[id] or 0) - os.clock()), def.cooldown
end

function CombatController.cast(id: string)
	local def = Techniques.Defs[id]
	if not (def and State.current.techniques.owned[id]) then
		return
	end
	local root = myRoot()
	local now = os.clock()
	if not root or now < (readyAt[def.id] or 0) then
		return
	end
	readyAt[def.id] = now + def.cooldown
	local dir = faceTarget(root)
	-- the technique goes off at the animation's "Hit" marker, from where you stand then
	onMarkers(playAnimation(def.animation), function()
		if not root.Parent then
			return
		end
		local origin = root.Position
		local chain = if def.kind == "chain" then predictChain(origin, def) else nil
		CombatEffects.cast(player.Character, def.id, origin, dir, chain)
		if chain then
			for _, model in chain do
				CombatEffects.flash(model, def.color)
			end
		end
		flashArea(def, origin, dir)
		castRemote:FireServer(def.id, workspace:GetServerTimeNow(), dir)
	end)
end

-- The Dash button and its cooldown overlay.
local function bindButtons(gui: ScreenGui)
	local dodgeButton = gui:FindFirstChild("DodgeButton", true) :: TextButton
	dodgeButton.Activated:Connect(CombatController.dodge)
	local overlay = dodgeButton:FindFirstChild("Cooldown") :: Frame
	RunService.RenderStepped:Connect(function()
		local remaining = lastDodge + Config.DODGE_COOLDOWN - os.clock()
		overlay.Visible = remaining > 0
		overlay.Size = UDim2.fromScale(1, math.clamp(remaining / Config.DODGE_COOLDOWN, 0, 1))
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
		LockOn.pick(model)
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
		-- PC: M1 swings, unless an item in hand takes the click
		local holding = player.Character and player.Character:FindFirstChildOfClass("Tool")
		if not processed and kind == Enum.UserInputType.MouseButton1 and not holding then
			CombatController.swing()
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
		local refund = args[1] :: number
		for id, t in readyAt do
			readyAt[id] = t - refund
		end
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
	strike.Activated:Connect(CombatController.swing)
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

	RunService.Heartbeat:Connect(function()
		local root = myRoot()
		local aimed = root and currentTarget(root.Position)
		-- the lock-on reticle replaces the soft-aim ring
		CombatEffects.markTarget(if LockOn.target() then nil else aimed)
		-- auto-attack is touch Auto mode; PC swings on M1
		if not Config.AUTO_ATTACK or not root or not (Platform.isTouch() and LockOn.isAuto()) then
			return
		end
		if aimed and distanceTo(aimed, root.Position) <= Config.AUTO_RANGE then
			CombatController.swing()
		end
	end)
end

return CombatController
