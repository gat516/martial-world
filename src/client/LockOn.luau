--!strict
-- Souls-style lock-on. A locked enemy holds the camera and the character's
-- facing: the camera sits behind you on the line to the target, you turn to face
-- it and strafe, and every attack and technique aims at it (CombatController).
-- The reticle (Play.LockReticle) sits on its chest; the soft-aim ground ring
-- hides meanwhile.
--
-- PC: middle mouse or T toggles; flicking the mouse sideways switches target.
--   A "T Lock" hint (Play.LockHint) sits beside the enemy a press would lock,
--   until Settings turns it off (LockOn.setHint).
--   Toggling with nothing to lock recentres the camera behind you.
-- Gamepad: R3 toggles; flicking the right stick switches.
-- Touch: the Lock button toggles; a sideways swipe on the right of the screen,
--   or tapping an enemy, switches.
-- Touch Auto mode (a Settings toggle, on by default; LockOn.setAuto): locks the
--   nearest enemy, closes in and strikes (CombatController's auto-attack), so the
--   player only dashes and casts. It holds back while the target winds up an
--   attack and for a moment after a dash. Unlocking by hand keeps it from
--   re-locking until no enemy is near.
--
-- The lock lets go when the target is out of range or out of sight too long, when
-- you can't act (meditating, circulating, a menu is open) or die. A dead target
-- hands the lock to the next enemy nearby.
-- The camera is written after Roblox's camera module each frame, so shift lock,
-- zoom and the module's own state pick up once the lock lets go; the release
-- blends back over RELEASE_SECONDS rather than jumping. While locked the view
-- narrows by LOCK_FOV_NARROW degrees, eased in and out.
-- Big targets push the camera back: the lock's distance range and the scroll-out
-- limit (Player.CameraMaxZoomDistance) grow with the target's size, so a boss
-- like the Thunder Ape fits on screen; both go back to normal on release.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config).Combat
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local CirculationMinigame = require(script.Parent.CirculationMinigame)
local ActionState = require(script.Parent.ActionState)
local Controls = require(script.Parent.Controls)
local Layout = require(script.Parent.Layout)
local Meditation = require(script.Parent.Meditation)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)

local player = Players.LocalPlayer

local CAMERA_SHARPNESS = 10 -- higher follows the ideal framing more tightly
local CAMERA_RISE = 0.3 -- camera height above you, per stud of distance
local LOOK_BIAS = 0.4 -- how far toward the target the camera looks (0 you, 1 it)
local RECENTER_SECONDS = 0.25
local RING_SPIN = 30 -- degrees per second
local LOCK_FOV_NARROW = 5 -- degrees the view tightens while locked
local FOV_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_SECONDS = 0.3
local DISTANCE_MIN, DISTANCE_MAX = 8, 24 -- lock camera distance range for a person-sized target
local SIZE_MIN, SIZE_MAX = 1.0, 1.8 -- the range for a big target, per stud of its size

local LockOn = {}

local target: Model? = nil
local movementFacing = false -- running keeps camera lock but uses native movement-facing rotation
local auto = Platform.isTouch()
local autoHeld = false -- unlocked by hand in Auto: don't re-lock until nobody's near
local lastDodge = -math.huge
local unseenFor = 0
local flick = 0 -- PC: sideways mouse travel waiting to switch
local stickArmed = true -- gamepad: the stick went back to centre since the last flick
local lastSwitch = -math.huge
local recenterLeft = 0
local cameraFrame: CFrame? = nil -- our smoothed camera, while locked
local baseFov: number? = nil -- the field of view before the lock narrowed it
local releaseFrom: CFrame? = nil -- the lock's last framing, blended out of on release
local releaseLeft = 0
local nearDistance, farDistance = DISTANCE_MIN, DISTANCE_MAX -- the current target's range
-- PC: the camera's mouse mode underneath this frame's lock-on override. Restore
-- it before the next camera update so Alt/zoom/RMB can change the native mode
-- without the camera mistaking our temporary LockCenter for its own state.
local mouseOverrideFrom: Enum.MouseBehavior? = nil

local reticle: ImageLabel
local reticleScale: UIScale?
local ring: GuiObject?
local lockButton: GuiButton?
local hint: GuiObject?
local hintOn = true
local hintFor: Model? = nil -- the enemy a press would lock, refreshed a few times a second
local hintCheckAt = 0

local function character(): Model?
	return player.Character
end

local function myRoot(): BasePart?
	local c = character()
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function myHumanoid(): Humanoid?
	local c = character()
	return c and c:FindFirstChildOfClass("Humanoid")
end

-- Whether the player can fight right now (a lock only lives while they can).
local function canAct(): boolean
	local humanoid = myHumanoid()
	return humanoid ~= nil
		and humanoid.Health > 0
		and not CirculationMinigame.isRunning()
		and not Meditation.isActive()
		and not Menus.isOpen()
end

-- Where the reticle sits and the camera looks: a little above the target's middle.
local function chestOf(model: Model): Vector3
	local cframe, size = model:GetBoundingBox()
	return cframe.Position + Vector3.yAxis * size.Y * 0.1
end

local function sightParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character() :: Instance, workspace.CurrentCamera }
	params.IgnoreWater = true
	return params
end

-- Nothing solid between the camera and the enemy (other enemies don't block).
local function visible(model: Model): boolean
	local from = workspace.CurrentCamera.CFrame.Position
	local to = chestOf(model)
	local hit = workspace:Raycast(from, to - from, sightParams())
	return hit == nil or hit.Instance:IsDescendantOf(model) or Hitbox.enemyOf(hit.Instance) ~= nil
end

local function candidates(range: number): { Model }
	local root = myRoot()
	local found: { Model } = {}
	if not root then
		return found
	end
	for _, model in CollectionService:GetTagged("Enemy") do
		if model:IsA("Model") and Hitbox.alive(model) and not model:GetAttribute("Burrowed") and (model:GetPivot().Position - root.Position).Magnitude <= range then
			table.insert(found, model)
		end
	end
	return found
end

-- The enemy the player most likely means: near the middle of the view and close.
-- Falls back to the nearest one in sight when none is in front of the camera.
local function bestTarget(range: number): Model?
	local root = myRoot()
	if not root then
		return nil
	end
	local camera = workspace.CurrentCamera
	local look = camera.CFrame.LookVector
	local best, bestScore = nil, math.huge
	local nearest, nearestDist = nil, math.huge
	for _, model in candidates(range) do
		if visible(model) then
			local toIt = chestOf(model) - camera.CFrame.Position
			local angle = math.deg(math.acos(math.clamp(look:Dot(toIt.Unit), -1, 1)))
			local dist = (model:GetPivot().Position - root.Position).Magnitude
			if angle < 50 and angle + dist * 0.6 < bestScore then
				best, bestScore = model, angle + dist * 0.6
			end
			if dist < nearestDist then
				nearest, nearestDist = model, dist
			end
		end
	end
	return best or nearest
end

local function nearestTo(range: number): Model?
	local root = myRoot()
	local best, bestDist = nil, math.huge
	for _, model in candidates(range) do
		local d = (model:GetPivot().Position - (root :: BasePart).Position).Magnitude
		if d < bestDist and visible(model) then
			best, bestDist = model, d
		end
	end
	return best
end

-- The lock camera's distance range for a target: the normal range, or one scaled
-- to the target's height (or half its length, for long bodies) when that's bigger.
local function distanceRange(model: Model): (number, number)
	local _, size = model:GetBoundingBox()
	local extent = math.max(size.Y, math.max(size.X, size.Z) * 0.5)
	return math.max(DISTANCE_MIN, extent * SIZE_MIN), math.max(DISTANCE_MAX, extent * SIZE_MAX)
end

-- Let the player scroll out as far as the target's range, never less than normal.
local function setZoomLimit(far: number?)
	local base = StarterPlayer.CameraMaxZoomDistance
	player.CameraMaxZoomDistance = math.max(base, far or 0)
end

local function snapReticle()
	reticle.Visible = false -- placed on the next frame, then shown
	if reticleScale then
		reticleScale.Scale = 1.6
		Motion.tween(reticleScale, { Scale = 1 }, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
	end
	reticle.ImageTransparency = 1
	Motion.tween(reticle, { ImageTransparency = 0 }, TweenInfo.new(0.12))
end

local function releaseMouse()
	local previous = mouseOverrideFrom
	mouseOverrideFrom = nil
	if previous and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = previous
	end
end

local function setTarget(model: Model?)
	if model == target then
		return
	end
	local was = target
	target = model
	unseenFor = 0
	flick = 0
	local camera = workspace.CurrentCamera
	if model then
		nearDistance, farDistance = distanceRange(model)
		setZoomLimit(farDistance)
		if not was then
			cameraFrame = camera.CFrame
			releaseLeft = 0
			baseFov = baseFov or camera.FieldOfView
			Motion.tween(camera, { FieldOfView = (baseFov :: number) - LOCK_FOV_NARROW }, FOV_TWEEN)
		end
		snapReticle()
	else
		reticle.Visible = false
		releaseFrom = cameraFrame
		releaseLeft = if cameraFrame then RELEASE_SECONDS else 0
		cameraFrame = nil
		if baseFov then
			Motion.tween(camera, { FieldOfView = baseFov }, FOV_TWEEN)
			baseFov = nil
		end
		releaseMouse()
		setZoomLimit(nil)
	end
end

-- The locked enemy, if any.
function LockOn.target(): Model?
	return target
end

function LockOn.setMovementFacing(on: boolean)
	movementFacing = on
end

function LockOn.isAuto(): boolean
	return auto
end

-- CombatController reports dashes so Auto doesn't walk straight back in.
function LockOn.noteDodge()
	lastDodge = os.clock()
end

-- Switch the lock to a tapped/clicked enemy (while locked, or in Auto).
function LockOn.pick(model: Model)
	if (target or auto) and Hitbox.alive(model) then
		autoHeld = false
		setTarget(model)
	end
end

function LockOn.toggle()
	if target then
		setTarget(nil)
		autoHeld = auto
		return
	end
	if not canAct() then
		return
	end
	local found = bestTarget(Config.LOCK_RANGE)
	if found then
		autoHeld = false
		setTarget(found)
	elseif not Platform.isTouch() then
		recenterLeft = RECENTER_SECONDS
	end
end

-- Lock the next enemy to the left (-1) or right (1) of the current one on screen.
local function switch(dir: number)
	local current = target
	if not current or os.clock() - lastSwitch < 0.2 then
		return
	end
	local camera = workspace.CurrentCamera
	local here = camera:WorldToViewportPoint(chestOf(current))
	local best, bestScore = nil, math.huge
	for _, model in candidates(Config.LOCK_RANGE) do
		if model ~= current then
			local point, onScreen = camera:WorldToViewportPoint(chestOf(model))
			local dx = point.X - here.X
			if onScreen and dx * dir > 10 and visible(model) then
				local score = math.abs(dx) + math.abs(point.Y - here.Y) * 2
				if score < bestScore then
					best, bestScore = model, score
				end
			end
		end
	end
	if best then
		lastSwitch = os.clock()
		setTarget(best)
	end
end

-- The PC "T Lock" hint on or off (the Settings toggle).
function LockOn.setHint(on: boolean)
	hintOn = on
end

-- Auto mode on or off (the Settings toggle). Only a change does anything, so
-- re-applying the same settings never drops a lock.
function LockOn.setAuto(on: boolean)
	if on == auto then
		return
	end
	auto = on
	autoHeld = false
	if not on and target then
		setTarget(nil)
	end
end

--[[ Per frame ]]

-- Let go, or hand the lock on, when the target can't be held any more.
local function validate(dt: number)
	local current = target
	if not current then
		return
	end
	if not canAct() then
		setTarget(nil)
		return
	end
	if not Hitbox.alive(current) then
		-- Auto hands on only to enemies close enough to walk to
		setTarget(nearestTo(if auto then Config.AUTO_LOCK_RANGE else Config.LOCK_RANGE))
		return
	end
	local root = myRoot() :: BasePart
	if (current:GetPivot().Position - root.Position).Magnitude > Config.LOCK_BREAK_RANGE then
		setTarget(nil)
		return
	end
	unseenFor = if visible(current) then 0 else unseenFor + dt
	if unseenFor > Config.LOCK_LOS_SECONDS then
		setTarget(nil)
	end
end

local function updateAuto()
	if not auto or target or not canAct() then
		return
	end
	local near = nearestTo(Config.AUTO_LOCK_RANGE)
	if autoHeld then
		autoHeld = near ~= nil
	elseif near then
		setTarget(near)
	end
end

-- Auto: walk in to striking range when the player isn't steering, unless the
-- target is winding up (that's the cue to dash) or a dash just ended.
local function approach(root: BasePart, humanoid: Humanoid, current: Model)
	if not auto or not ActionState.canApproach() or os.clock() - lastDodge < Config.AUTO_APPROACH_PAUSE then
		return
	end
	local state = current:GetAttribute("AIState")
	if state == "windup" or state == "dash" then
		return
	end
	if Controls.moveVector().Magnitude > 0.1 then
		return
	end
	local offset = (current:GetPivot().Position - root.Position) * Vector3.new(1, 0, 1)
	if offset.Magnitude > Config.AUTO_RANGE - 1.5 then
		humanoid:Move(offset.Unit)
	end
end

local function updateCamera(dt: number, root: BasePart, current: Model)
	local camera = workspace.CurrentCamera
	-- the camera module has already placed the camera this frame: keep its focus and zoom
	local focus = camera.Focus.Position
	local distance = math.clamp((camera.CFrame.Position - focus).Magnitude, nearDistance, farDistance)
	local chest = chestOf(current)
	local flat = (chest - focus) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 1 then
		flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	flat = flat.Unit
	local position = focus - flat * distance + Vector3.yAxis * distance * CAMERA_RISE
	local desired = CFrame.lookAt(position, focus:Lerp(chest, LOOK_BIAS))
	local from = cameraFrame or camera.CFrame
	local smoothed = from:Lerp(desired, 1 - math.exp(-CAMERA_SHARPNESS * dt))
	cameraFrame = smoothed

	-- keep walls between you and the camera from hiding you
	local final = smoothed
	local hit = workspace:Raycast(focus, smoothed.Position - focus, sightParams())
	if hit and not Hitbox.enemyOf(hit.Instance) then
		final = smoothed.Rotation + hit.Position + (focus - hit.Position).Unit * 0.5
	end
	camera.CFrame = final

	-- Movement owns character facing. Auto approach also respects action locks.
	local humanoid = myHumanoid()
	if humanoid and not movementFacing then
		approach(root, humanoid, current)
	end

	-- PC: the mouse stays put while locked so flicks can switch (ShiftLock hides the cursor)
	if not Platform.isTouch() then
		mouseOverrideFrom = UserInputService.MouseBehavior
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		local delta = UserInputService:GetMouseDelta()
		flick = flick * math.exp(-8 * dt) + delta.X
		if math.abs(flick) > Config.LOCK_FLICK_PIXELS then
			switch(math.sign(flick))
			flick = 0
		end
	end
end

-- Ease from the lock's framing into wherever the camera module now puts the camera.
local function blendOut(dt: number)
	releaseLeft = math.max(0, releaseLeft - dt)
	local from = releaseFrom
	if not from then
		return
	end
	local camera = workspace.CurrentCamera
	local t = 1 - releaseLeft / RELEASE_SECONDS
	local eased = 1 - (1 - t) ^ 3 -- cubic out
	camera.CFrame = from:Lerp(camera.CFrame, eased)
end

local function recenter(dt: number, root: BasePart)
	recenterLeft -= dt
	local camera = workspace.CurrentCamera
	local focus = camera.Focus.Position
	local distance = (camera.CFrame.Position - focus).Magnitude
	local back = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if back.Magnitude < 0.01 then
		return
	end
	local position = focus - back.Unit * distance + Vector3.yAxis * distance * CAMERA_RISE
	local alpha = 1 - math.exp(-20 * dt)
	camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(position, focus), alpha)
end

local function placeReticle(dt: number, current: Model)
	local play = reticle.Parent :: GuiObject
	local point, onScreen = workspace.CurrentCamera:WorldToScreenPoint(chestOf(current))
	reticle.Visible = onScreen and play.Visible
	if onScreen then
		reticle.Position = UDim2.fromOffset(point.X - play.AbsolutePosition.X, point.Y - play.AbsolutePosition.Y)
	end
	if ring then
		ring.Rotation = (ring.Rotation + RING_SPIN * dt) % 360
	end
end

-- PC: the key hint beside whichever enemy a press would lock, while nothing is.
local function updateHint()
	if not hint then
		return
	end
	local play = hint.Parent :: GuiObject
	local wanted = hintOn and not Platform.isTouch() and target == nil and play.Visible and canAct()
	if not wanted then
		hintFor = nil
	elseif os.clock() >= hintCheckAt then
		hintCheckAt = os.clock() + 0.25
		hintFor = bestTarget(Config.LOCK_RANGE)
	end
	local model = hintFor
	if model and not Hitbox.alive(model) then
		model = nil
	end
	local point, onScreen = Vector3.zero, false
	if model then
		point, onScreen = workspace.CurrentCamera:WorldToScreenPoint(chestOf(model))
	end
	hint.Visible = model ~= nil and onScreen
	if hint.Visible then
		hint.Position = UDim2.fromOffset(point.X - play.AbsolutePosition.X + 28, point.Y - play.AbsolutePosition.Y)
	end
end

local function updateButtons()
	if not lockButton then
		return
	end
	local useful = target ~= nil or #candidates(Config.LOCK_RANGE) > 0
	lockButton.Visible = Platform.isTouch() and Layout.clusterShown() and useful
	local lockOn = lockButton:FindFirstChild("On") :: GuiObject?
	if lockOn then
		lockOn.Visible = target ~= nil
	end
end

local function step(dt: number)
	validate(dt)
	updateAuto()
	local root = myRoot()
	local current = target
	if root and current then
		updateCamera(dt, root, current)
		placeReticle(dt, current)
	elseif releaseLeft > 0 then
		blendOut(dt)
	elseif root and recenterLeft > 0 then
		recenter(dt, root)
	end
	updateButtons()
	updateHint()
end

--[[ Input ]]

local function bindInput()
	ContextActionService:BindAction("LockOn", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			LockOn.toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseButton3, Enum.KeyCode.T, Enum.KeyCode.ButtonR3)

	-- gamepad: a flick of the right stick switches, then it must come back to centre
	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 and target then
			local x = input.Position.X
			if stickArmed and math.abs(x) > 0.7 then
				stickArmed = false
				switch(math.sign(x))
			elseif math.abs(x) < 0.3 then
				stickArmed = true
			end
		end
	end)

	-- touch: a sideways swipe on the right of the screen (the left is the thumbstick)
	local swipes: { [InputObject]: { start: Vector3, used: boolean } } = {}
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch and not processed then
			local width = workspace.CurrentCamera.ViewportSize.X
			if input.Position.X > width * 0.35 then
				swipes[input] = { start = input.Position, used = false }
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local swipe = swipes[input]
		if swipe and not swipe.used and target then
			local delta = input.Position - swipe.start
			if math.abs(delta.X) > Config.LOCK_SWIPE_PIXELS and math.abs(delta.X) > math.abs(delta.Y) * 1.2 then
				swipe.used = true
				switch(math.sign(delta.X))
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		swipes[input] = nil
	end)
end

function LockOn.init(gui: ScreenGui)
	local play = gui:FindFirstChild("Play") :: Frame
	reticle = play:FindFirstChild("LockReticle") :: ImageLabel
	reticle.Visible = false
	reticleScale = reticle:FindFirstChildOfClass("UIScale")
	ring = reticle:FindFirstChild("Ring") :: GuiObject?
	lockButton = play:FindFirstChild("LockButton") :: GuiButton?
	hint = play:FindFirstChild("LockHint") :: GuiObject?
	if hint then
		hint.Visible = false
		Motion.appear(hint)
	end
	if lockButton then
		lockButton.Activated:Connect(LockOn.toggle)
	end
	bindInput()
	player.CharacterAdded:Connect(function()
		setTarget(nil)
	end)
	-- Give the native camera back its latest mode before it processes this
	-- frame's shift lock / first-person / mouse-drag state. Lock-on reapplies
	-- its override afterwards; unlocking never restores a lock-start snapshot.
	RunService:BindToRenderStep("LockOnMouseRelease", Enum.RenderPriority.Camera.Value - 1, releaseMouse)
	-- after Roblox's camera module (Camera), before the hit shake (Camera + 2)
	RunService:BindToRenderStep("LockOn", Enum.RenderPriority.Camera.Value + 1, step)
end

return LockOn
