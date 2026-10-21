--!strict
-- Circulation runs, full screen and one thumb. The server picks which minigame
-- each run plays (Minigames/: Maze, Thread, Pulse, Gather), along with its length,
-- difficulty and impurity count; this runs the shared frame around it: the
-- overlay with the game's title and hint, a 3-2-1 count-in, the game itself on
-- its own stage, and a graded result once the server has scored the report.
-- The same runner plays Practise Dao drills (CirculationMinigame.practise):
-- server DaoPractice picks the game and scores it for weapon Dao XP.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Controls = require(script.Parent.Controls)
local Hud = require(script.Parent.Hud)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)
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
local BEAT = 0.6 -- seconds per count-in number

local GRADES = {
	{ score = 0.9, name = "Perfect", color = Color3.fromRGB(255, 225, 140) },
	{ score = 0.72, name = "Excellent", color = Color3.fromRGB(150, 245, 200) },
	{ score = 0.5, name = "Good", color = Color3.fromRGB(200, 230, 255) },
	{ score = 0, name = "Rough", color = Color3.fromRGB(230, 180, 170) },
}
local FIZZLE = Color3.fromRGB(232, 190, 92)

local CirculationMinigame = {}

local overlay: Frame
local running = false
local quitting = false -- the player left the current run early

local function find(name: string): any
	return overlay:FindFirstChild(name, true)
end

-- 3-2-1 over the freshly drawn board: each number pops large and settles.
local function countIn()
	local label = find("Countdown") :: TextLabel
	local pop = label:FindFirstChild("Pop") :: UIScale
	label.Visible = true
	for _, n in COUNT_IN do
		label.Text = n
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0
		pop.Scale = 1.5
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, BEAT - 0.25), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.wait(BEAT)
	end
	label.Visible = false
end

-- Shows the picked game's stage and labels and plays it. The game draws its
-- first board, then calls ui.ready() for the count-in.
local function play(info: Feel.Info, hold: { () -> () }): (number, number)
	local minigame = GAMES[info.game] or GAMES.Maze
	local stageName = if GAMES[info.game] then info.game else "Maze"
	for name in GAMES do
		(find(name) :: Frame).Visible = name == stageName
	end
	(find("Title") :: TextLabel).Text = info.title or minigame.TITLE
	local hint = if Platform.isTouch() and minigame.TOUCH_HINT then minigame.TOUCH_HINT else minigame.HINT;
	(find("Hint") :: TextLabel).Text = hint
	local counted = false
	local ui: Feel.Ui = {
		timer = find("Timer") :: TextLabel,
		score = find("Accuracy") :: TextLabel,
		flow = find("Flow") :: TextLabel,
		ready = function()
			if not counted then
				counted = true
				countIn()
			end
		end,
		hold = function(clear)
			table.insert(hold, clear)
		end,
		quit = function()
			return quitting
		end,
	}
	ui.flow.Text = ""
	ui.score.Text = ""
	ui.timer.Text = string.format("%d", info.duration)
	local accuracy, purged = minigame.play(find(stageName) :: Frame, info, ui)
	ui.flow.Text = ""
	return accuracy, purged
end

-- The graded card pops in over the final board, holds, and fades away.
local function showResult(grade: string, detail: string, color: Color3)
	local card = find("Result") :: ImageLabel
	local gradeLabel = card:FindFirstChild("Grade") :: TextLabel
	local detailLabel = card:FindFirstChild("Detail") :: TextLabel
	local pop = card:FindFirstChild("Pop") :: UIScale
	gradeLabel.Text = grade
	gradeLabel.TextColor3 = color
	detailLabel.Text = detail
	card.Visible = true
	pop.Scale = 0.85
	Motion.fadeIn(card)
	TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.wait(RESULT_SECONDS)
	TweenService:Create(pop, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.94 }):Play()
	Motion.fadeOut(card)
	task.wait(0.16)
	card.Visible = false
end

local function gradeFor(score: number): typeof(GRADES[1])
	for _, g in GRADES do
		if score >= g.score then
			return g
		end
	end
	return GRADES[#GRADES]
end

-- The server actions for each kind of run.
local KINDS = {
	circulation = { start = "start", finish = "finish", cancel = "cancel", left = "You stopped circulating. Your raw qi is untouched." },
	dao = { start = "practiceStart", finish = "practiceFinish", cancel = "practiceCancel", left = "You set your weapon down. Nothing was lost." },
}

local function run(kind: string)
	local actions = KINDS[kind]
	if running then
		return
	end
	running = true
	local ok, info = remote:InvokeServer(actions.start)
	if not ok then
		Hud.toast(info or "You can't do that right now")
		running = false
		return
	end

	Controls.lock("Circulation")
	overlay.Visible = true
	local hold: { () -> () } = {}
	quitting = false
	local accuracy, purged = play(info, hold)
	if quitting then
		-- left early: nothing refined, nothing spent
		remote:InvokeServer(actions.cancel, info.id)
		Hud.toast(actions.left)
	else
		local done, result = remote:InvokeServer(actions.finish, info.id, accuracy, purged)
		if done then
			local grade = gradeFor(result.score)
			local detail = if kind == "dao" then `+{result.gain} {result.dao} XP` else `+{result.gain} cultivation`
			if result.deviation then
				detail ..= "\nQi deviation! Let it settle."
			elseif result.full then
				detail ..= "\nYour realm bar is full!"
			end
			showResult(grade.name, detail, grade.color)
		else
			showResult("Fizzled", result or "The run fizzled", FIZZLE)
		end
	end
	quitting = false
	overlay.Visible = false
	for _, clear in hold do
		clear()
	end
	Controls.unlock("Circulation")
	running = false
end

function CirculationMinigame.start()
	run("circulation")
end

-- A Practise Dao drill with the equipped weapon (the meditation menu's tile).
function CirculationMinigame.practise()
	run("dao")
end

function CirculationMinigame.isRunning(): boolean
	return running
end

-- Leave the current run early (the overlay's Leave button, gamepad B). The
-- game ends on its next frame; no qi is spent.
function CirculationMinigame.quit()
	if running then
		quitting = true
	end
end

-- Started from the cultivation seat (Meditation.luau), never on its own.
function CirculationMinigame.init(gui: ScreenGui)
	overlay = gui:FindFirstChild("Circulation") :: Frame
	Menus.register(overlay, { minigame = true, close = CirculationMinigame.quit })
	-- the Leave pill at the header's right corner (Column.Header.Title.Leave)
	local leave = overlay:FindFirstChild("Leave", true) :: GuiButton
	leave.Activated:Connect(CirculationMinigame.quit)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonB then
			CirculationMinigame.quit()
		end
	end)
end

return CirculationMinigame
