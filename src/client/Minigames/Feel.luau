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
}

-- The overlay labels shared by all games.
export type Ui = { timer: TextLabel, score: TextLabel, flow: TextLabel }

export type Game = {
	TITLE: string,
	HINT: string,
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
	label.Position = at - UDim2.fromOffset(0, 30)
	label.Visible = true
	label.Parent = template.Parent
	local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { Position = at - UDim2.fromOffset(0, 60), TextTransparency = 1, TextStrokeTransparency = 1 })
		:Play()
	task.delay(0.65, label.Destroy, label)
end

return Feel
