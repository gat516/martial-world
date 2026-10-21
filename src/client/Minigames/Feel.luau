--!strict
-- What every circulation minigame shares: the run info the server sends, the
-- labels the runner gives each game, difficulty tuning from Config, and the
-- feel kit every game uses the same way: vibration, pops and bursts (drawn art,
-- art/ui/draw_ui.py minigames), a shake, the run's sounds, the qi pointer that
-- stands in for the mouse over a board, and the frozen camera behind it all.

local GuiService = game:GetService("GuiService")
local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Platform = require(script.Parent.Parent.Platform)

local Games = require(ReplicatedStorage.Shared.Config).Circulation.Games

export type Info = {
	id: string,
	game: string,
	duration: number, -- the time limit, seconds
	levels: number?, -- circulation runs: the levels to clear (the run ends once all are)
	difficulty: number, -- 0 easy .. 1 hard (below 0 on the first run)
	impurities: number, -- per level in a circulation run; for the whole drill in Practice Dao
	seed: number,
	title: string?, -- replaces the game's TITLE (Practice Dao: "Sword Forms")
	hint: string?, -- replaces the game's HINT / TOUCH_HINT
}

-- What the runner hands each game: the overlay's labels, plus
--   ready(): call once the first board is drawn; it plays the 3-2-1 count-in
--     (so the board is already there to look at) and returns when play starts.
--   hold(clear): the game's own cleanup; the runner calls it once the result
--     card has gone, so the final board stays under the result.
--   quit(): true once the player has left the run early; the game should end
--     on its next frame (a circulation run still pays for the levels cleared).
--   tapped(): call on every tap the player makes in play (a Practice Dao
--     drill swings the weapon on it).
export type Ui = {
	timer: TextLabel,
	score: TextLabel,
	flow: TextLabel,
	ready: () -> (),
	hold: (clear: () -> ()) -> (),
	quit: () -> boolean,
	tapped: () -> (),
}

export type Game = {
	TITLE: string,
	HINT: string,
	TOUCH_HINT: string?, -- shown instead of HINT on touch screens
	-- Plays a run on its stage and returns accuracy (0-1) and impurities purged;
	-- circulation games also return the levels cleared (accuracy is over those).
	play: (stage: Frame, info: Info, ui: Ui) -> (number, number, number?),
}

local Feel = {}

-- The game's `easy` values blended toward `hard` by difficulty.
function Feel.tune(name: string, difficulty: number): { [string]: number }
	local def = Games[name]
	local out = {}
	for key, easy in def.easy do
		local hard = def.hard[key] or easy
		out[key] = easy + (hard - easy) * difficulty
	end
	return out
end

function Feel.timer(label: TextLabel, t: number, duration: number)
	label.Text = string.format("%d", math.max(0, math.ceil(duration - t)))
end

function Feel.buzz(strength: number, seconds: number)
	pcall(function()
		if HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) then
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, strength)
			task.delay(seconds, function()
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
			end)
		end
	end)
end

-- The drawn effect art (art/ui/draw_ui.py minigames; ids in art/ui/assets.json).
local RING = "rbxassetid://93045970795871" -- mg_ring.png: a white glowing ring
local BURST = "rbxassetid://113102608182589" -- mg_burst.png: a spray of rays

-- A short-lived effect image centred on a point.
local function effect(parent: GuiObject, image: string, at: UDim2, color: Color3, size: number): ImageLabel
	local fx = Instance.new("ImageLabel")
	fx.Name = "Fx"
	fx.AnchorPoint = Vector2.new(0.5, 0.5)
	fx.BackgroundTransparency = 1
	fx.Image = image
	fx.ImageColor3 = color
	fx.Position = at
	fx.Size = UDim2.fromOffset(size, size)
	fx.ZIndex = 25
	fx.Parent = parent
	return fx
end

-- A glowing ring that pops outward from a point (hits, purges, jolts).
function Feel.pop(parent: GuiObject, at: UDim2, color: Color3, grow: number?)
	local size = grow or 90
	local ring = effect(parent, RING, at, color, size * 0.25)
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = UDim2.fromOffset(size, size), ImageTransparency = 1 }):Play()
	task.delay(0.4, ring.Destroy, ring)
end

-- A spray of light that flares and spins out (Perfect hits, purges, clears).
function Feel.burst(parent: GuiObject, at: UDim2, color: Color3, size: number?)
	local full = size or 110
	local fx = effect(parent, BURST, at, color, full * 0.4)
	fx.Rotation = math.random(0, 359)
	local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(fx, info, { Size = UDim2.fromOffset(full, full), ImageTransparency = 1, Rotation = fx.Rotation + 40 }):Play()
	task.delay(0.45, fx.Destroy, fx)
end

-- Shakes a board for a moment (a wall touched, an impurity caught). Its
-- position comes back exactly; a shake already running is replaced.
local shaking: { [GuiObject]: { base: UDim2, conn: RBXScriptConnection } } = {}
function Feel.shake(frame: GuiObject, pixels: number?, seconds: number?)
	local strength, length = pixels or 6, seconds or 0.25
	local running = shaking[frame]
	local base = if running then running.base else frame.Position
	if running then
		running.conn:Disconnect()
	end
	local t = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		if t >= length then
			conn:Disconnect()
			shaking[frame] = nil
			frame.Position = base
			return
		end
		local fade = 1 - t / length
		frame.Position = base + UDim2.fromOffset(math.sin(t * 70) * strength * fade, math.cos(t * 53) * strength * 0.5 * fade)
	end)
	shaking[frame] = { base = base, conn = conn }
end

-- The run's sounds, Sounds under the Circulation overlay (Tick, Perfect, Purge,
-- Clear, Thud), played flat through SoundService.SFX so the sound slider scales
-- them. `pitch` scales the playback speed (a rising combo).
local soundFolder: Instance? = nil
function Feel.setSounds(folder: Instance)
	soundFolder = folder
end

function Feel.sound(name: string, pitch: number?)
	local template = soundFolder and soundFolder:FindFirstChild(name)
	if not (template and template:IsA("Sound")) then
		return
	end
	local sound = template:Clone()
	sound.SoundGroup = SoundService:FindFirstChild("SFX") :: SoundGroup?
	sound.PlaybackSpeed *= (pitch or 1) * (1 + (math.random() - 0.5) * 0.04)
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(6, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	sound:Play()
end

-- The mouse, in GUI space (the space AbsolutePosition and input positions use).
function Feel.mouse(): Vector2
	return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
end

local function inside(area: GuiObject, at: Vector2): boolean
	local from, size = area.AbsolutePosition, area.AbsoluteSize
	return at.X >= from.X and at.Y >= from.Y and at.X <= from.X + size.X and at.Y <= from.Y + size.Y
end

-- The pointer over a board, on mouse: the OS arrow hides over `area` and, in
-- "qi" style, the overlay's Pointer (a jade reticle, mg_pointer.png) draws at
-- the mouse instead, so it's always clear where you point; "hidden" style
-- shows nothing (the bowl is the cursor). Call step() every frame; it returns
-- the mouse (GUI space) while it's over the area, else nil. stop() puts the
-- arrow back. Touch screens have no pointer: step() always returns nil.
export type Pointer = { step: () -> Vector2?, stop: () -> () }
local pointerImage: ImageLabel? = nil
function Feel.setPointer(image: ImageLabel)
	pointerImage = image
end

function Feel.pointer(area: GuiObject, style: "qi" | "hidden"): Pointer
	local touch = Platform.isTouch()
	local hid = false
	local image = if style == "qi" then pointerImage else nil
	local function show(over: boolean)
		if over ~= hid then
			hid = over
			UserInputService.MouseIconEnabled = not over
		end
		if image then
			image.Visible = over
		end
	end
	return {
		step = function(): Vector2?
			if touch then
				return nil
			end
			local at = Feel.mouse()
			local over = area.Visible and inside(area, at)
			show(over)
			if over and image then
				local parent = image.Parent :: GuiObject
				local local_ = at - parent.AbsolutePosition
				image.Position = UDim2.fromOffset(local_.X, local_.Y)
			end
			return if over then at else nil
		end,
		stop = function()
			show(false)
		end,
	}
end

-- A faint qi line between two points on a board (in the board's scale
-- coordinates times its pixel size): the tether from the spark or bead to a
-- pointer it can't reach. `line` is a 9-sliced round-capped image anchored at
-- its centre; thickness in pixels.
function Feel.line(line: ImageLabel, from: Vector2, to: Vector2, thickness: number)
	local d = to - from
	local length = d.Magnitude
	local mid = (from + to) / 2
	line.Position = UDim2.fromOffset(mid.X, mid.Y)
	line.Size = UDim2.fromOffset(length + thickness, thickness)
	line.Rotation = math.deg(math.atan2(d.Y, d.X))
	line.SliceScale = thickness / 128
end

-- Holds the camera still for a run, so nothing moves behind the board (a drag
-- no longer turns the view, the wheel no longer zooms). Returns the restore,
-- which puts the camera back exactly (type, subject, field of view, and its
-- framing unless the character has since moved) and is safe to call twice.
-- The runner restores it on every way out; a death mid-run restores it at once.
function Feel.freezeCamera(): () -> ()
	local camera = workspace.CurrentCamera
	local saved = {
		kind = camera.CameraType,
		subject = camera.CameraSubject,
		fov = camera.FieldOfView,
		frame = camera.CFrame,
	}
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rootAt = root and root.Position
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = saved.frame
	local done = false
	local died: RBXScriptConnection? = nil
	local function restore()
		if done then
			return
		end
		done = true
		if died then
			died:Disconnect()
		end
		local now = workspace.CurrentCamera
		local subject = saved.subject
		if not (subject and subject:IsDescendantOf(workspace)) then
			local char = Players.LocalPlayer.Character
			subject = char and char:FindFirstChildOfClass("Humanoid")
		end
		local nowRoot = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local stayed = rootAt and nowRoot and (nowRoot.Position - rootAt).Magnitude < 3
		if stayed then
			now.CFrame = saved.frame
		end
		now.FieldOfView = saved.fov
		now.CameraSubject = subject
		now.CameraType = if saved.kind == Enum.CameraType.Scriptable then Enum.CameraType.Custom else saved.kind
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		died = humanoid.Died:Connect(restore)
	end
	return restore
end

-- A word that floats up from a point and fades (Perfect, Miss...).
function Feel.judge(template: TextLabel, at: UDim2, text: string, color: Color3)
	local label = template:Clone()
	label.Name = "Judge"
	label.Text = text
	label.TextColor3 = color
	-- rises from just above the point, staying close so it never drifts out of
	-- the field into the header
	label.Position = at - UDim2.fromOffset(0, 8)
	label.Visible = true
	label.Parent = template.Parent
	local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { Position = at - UDim2.fromOffset(0, 30), TextTransparency = 1, TextStrokeTransparency = 1 })
		:Play()
	task.delay(0.65, label.Destroy, label)
end

-- Swapping one board for the next (a maze escaped, a meridian cleared): the
-- field's Veil darkens over VEIL_IN seconds, the game swaps the board while it's
-- dark, then the Veil lifts.
Feel.VEIL_IN = 0.15
local VEIL_OUT = 0.22

function Feel.veilIn(field: GuiObject)
	local veil = field:FindFirstChild("Veil") :: Frame?
	if veil then
		TweenService:Create(veil, TweenInfo.new(Feel.VEIL_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 0,
		}):Play()
	end
end

function Feel.veilOut(field: GuiObject)
	local veil = field:FindFirstChild("Veil") :: Frame?
	if veil then
		veil.BackgroundTransparency = 0
		TweenService:Create(veil, TweenInfo.new(VEIL_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
	end
end

-- Fade a freshly spawned piece in from nothing (an image, or a frame's fill
-- and outline).
function Feel.fadeIn(piece: GuiObject, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if piece:IsA("ImageLabel") then
		local shown = piece.ImageTransparency
		piece.ImageTransparency = 1
		TweenService:Create(piece, info, { ImageTransparency = shown }):Play()
		return
	end
	local fill = piece.BackgroundTransparency
	piece.BackgroundTransparency = 1
	TweenService:Create(piece, info, { BackgroundTransparency = fill }):Play()
	local stroke = piece:FindFirstChildOfClass("UIStroke")
	if stroke then
		local line = stroke.Transparency
		stroke.Transparency = 1
		TweenService:Create(stroke, info, { Transparency = line }):Play()
	end
end

return Feel
