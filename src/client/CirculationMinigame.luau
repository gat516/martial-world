--!strict
-- Circulation runs, full screen and one thumb. The server picks which minigame
-- each run plays (Minigames/: Maze, Thread, Pulse, Gather), along with its length,
-- difficulty and impurity count; this runs the shared frame around it: the
-- overlay with the game's title and hint, a 3-2-1 count-in, the game itself on
-- its own stage, and a graded result once the server has scored the report.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Controls = require(script.Parent.Controls)
local Hud = require(script.Parent.Hud)
local Menus = require(script.Parent.Menus)
local Feel = require(script.Parent.Minigames.Feel)

local remote = ReplicatedStorage.Remotes.CultivationAction :: RemoteFunction

local GAMES: { [string]: Feel.Game } = {
	Maze = require(script.Parent.Minigames.Maze),
	Thread = require(script.Parent.Minigames.Thread),
	Pulse = require(script.Parent.Minigames.Pulse),
	Gather = require(script.Parent.Minigames.Gather),
}

local RESULT_SECONDS = 2.6
local COUNT_IN = { "3", "2", "1" }

local GRADES = {
	{ score = 0.9, name = "Perfect", color = Color3.fromRGB(255, 225, 140) },
	{ score = 0.72, name = "Excellent", color = Color3.fromRGB(150, 245, 200) },
	{ score = 0.5, name = "Good", color = Color3.fromRGB(200, 230, 255) },
	{ score = 0, name = "Rough", color = Color3.fromRGB(230, 180, 170) },
}

local CirculationMinigame = {}

local overlay: Frame
local running = false

local function countIn()
	local label = overlay:FindFirstChild("Countdown") :: TextLabel
	label.Visible = true
	for _, n in COUNT_IN do
		label.Text = n
		label.TextTransparency = 0
		label.Size = UDim2.fromOffset(260, 160)
		TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(200, 120),
			TextTransparency = 0.6,
		}):Play()
		task.wait(0.75)
	end
	label.Visible = false
end

-- Shows the picked game's stage and labels, counts in, and plays it.
local function play(info: Feel.Info): (number, number)
	local minigame = GAMES[info.game] or GAMES.Maze
	local stageName = if GAMES[info.game] then info.game else "Maze"
	for name in GAMES do
		(overlay:FindFirstChild(name) :: Frame).Visible = name == stageName
	end
	(overlay:FindFirstChild("Title") :: TextLabel).Text = minigame.TITLE;
	(overlay:FindFirstChild("Hint") :: TextLabel).Text = minigame.HINT
	local ui: Feel.Ui = {
		timer = overlay:FindFirstChild("Timer") :: TextLabel,
		score = overlay:FindFirstChild("Accuracy") :: TextLabel,
		flow = overlay:FindFirstChild("Flow") :: TextLabel,
	}
	ui.flow.Text = ""
	ui.score.Text = ""
	ui.timer.Text = string.format("%d", info.duration)
	countIn()
	local accuracy, purged = minigame.play(overlay:FindFirstChild(stageName) :: Frame, info, ui)
	ui.flow.Text = ""
	return accuracy, purged
end

local function showResult(text: string, color: Color3?)
	local result = overlay:FindFirstChild("Result") :: TextLabel
	result.Text = text
	result.TextColor3 = color or Color3.fromRGB(232, 190, 92)
	result.Visible = true
	result.Size = UDim2.fromOffset(300, 100)
	TweenService:Create(result, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(360, 130),
	}):Play()
	task.wait(RESULT_SECONDS)
	result.Visible = false
end

local function gradeFor(score: number): typeof(GRADES[1])
	for _, g in GRADES do
		if score >= g.score then
			return g
		end
	end
	return GRADES[#GRADES]
end

function CirculationMinigame.start()
	if running then
		return
	end
	running = true
	local ok, info = remote:InvokeServer("start")
	if not ok then
		Hud.toast(info or "You can't circulate right now")
		running = false
		return
	end

	Controls.lock("Circulation")
	overlay.Visible = true
	local accuracy, purged = play(info)
	local done, result = remote:InvokeServer("finish", info.id, accuracy, purged)
	if done then
		local grade = gradeFor(result.score)
		local lines = `{grade.name}\n+{result.gain} cultivation`
		if result.deviation then
			lines ..= "\nQi deviation! Let it settle."
		elseif result.full then
			lines ..= "\nYour realm bar is full!"
		end
		showResult(lines, grade.color)
	else
		showResult(result or "The run fizzled")
	end
	overlay.Visible = false
	Controls.unlock("Circulation")
	running = false
end

function CirculationMinigame.isRunning(): boolean
	return running
end

-- Started from the cultivation seat (Meditation.luau), never on its own.
function CirculationMinigame.init(gui: ScreenGui)
	overlay = gui:FindFirstChild("Circulation") :: Frame
	Menus.register(overlay, { minigame = true, close = function() end })
end

return CirculationMinigame
