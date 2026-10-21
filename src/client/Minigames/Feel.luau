--!strict
-- What every circulation minigame shares: the run info the server sends, the
-- labels the runner gives each game, difficulty tuning from Config, and small
-- bits of feel (vibration, pop rings).

local HapticService = game:GetService("HapticService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Games = require(ReplicatedStorage.Shared.Config).Circulation.Games

export type Info = {
	id: string,
	game: string,
	duration: number,
	difficulty: number, -- 0 easy .. 1 hard (below 0 on the first run)
	impurities: number,
	seed: number,
	title: string?, -- replaces the game's TITLE (Practise Dao: "Sword Forms")
}

-- What the runner hands each game: the overlay's labels, plus
--   ready(): call once the first board is drawn; it plays the 3-2-1 count-in
--     (so the board is already there to look at) and returns when play starts.
--   hold(clear): the game's own cleanup; the runner calls it once the result
--     card has gone, so the final board stays under the result.
--   quit(): true once the player has left the run early; the game should end
--     on its next frame (its returned score is ignored).
export type Ui = {
	timer: TextLabel,
	score: TextLabel,
	flow: TextLabel,
	ready: () -> (),
	hold: (clear: () -> ()) -> (),
	quit: () -> boolean,
}

export type Game = {
	TITLE: string,
	HINT: string,
	TOUCH_HINT: string?, -- shown instead of HINT on touch screens
	-- Plays a run on its stage and returns accuracy (0-1) and impurities purged.
	play: (stage: Frame, info: Info, ui: Ui) -> (number, number),
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

-- A ring that pops outward from a point (hits, purges, jolts).
function Feel.pop(parent: GuiObject, at: UDim2, color: Color3, grow: number?)
	local ring = Instance.new("Frame")
	ring.Name = "Pop"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = at
	ring.Size = UDim2.fromOffset(20, 20)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 16
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = ring
	ring.Parent = parent
	local size = grow or 90
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = UDim2.fromOffset(size, size) }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	task.delay(0.4, ring.Destroy, ring)
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

-- Fade a freshly spawned piece in from nothing (its fill and its outline).
function Feel.fadeIn(frame: Frame, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fill = frame.BackgroundTransparency
	frame.BackgroundTransparency = 1
	TweenService:Create(frame, info, { BackgroundTransparency = fill }):Play()
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		local line = stroke.Transparency
		stroke.Transparency = 1
		TweenService:Create(stroke, info, { Transparency = line }):Play()
	end
end

return Feel
