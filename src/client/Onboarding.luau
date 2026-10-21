--!strict
-- Onboarding and quest board UI: the objective tracker under the top-right tiles
-- (with the objective's reward, when it has one),
-- the elder's one-line guidance (shown once per beat, never blocking), the
-- server's guide (Guide: a pulsing or spotlit control, a path to walk), the
-- Travel button appearing when the formation is taught, and the quest board.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guide = require(script.Parent.Guide)
local ListWindow = require(script.Parent.ListWindow)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local TravelMenu = require(script.Parent.TravelMenu)

local questRemote = ReplicatedStorage.Remotes.QuestState :: RemoteEvent

local ELDER_SECONDS = 7

local Onboarding = {}

local gui: ScreenGui
local lastBeat: string? = nil
local lastElder = ""
local elderToken = 0
local goals: { any } = {}

local function showElder(line: string)
	local frame = gui:FindFirstChild("ElderLine", true) :: Frame
	if Guide.spotlit() then
		return -- the spotlight carries the line beside its control
	end
	(frame:FindFirstChild("Line") :: TextLabel).Text = line
	frame.Visible = true
	elderToken += 1
	local token = elderToken
	task.delay(ELDER_SECONDS, function()
		if token == elderToken then
			frame.Visible = false
		end
	end)
end

local function renderBoard()
	local window = gui:FindFirstChild("QuestBoardWindow") :: Frame
	local rows: { ListWindow.Row } = {}
	for _, g in goals do
		table.insert(rows, {
			color = Color3.fromRGB(232, 190, 92),
			name = g.name,
			detail = g.detail,
			count = 0,
			countText = g.progress,
			hideButton = true,
			onPress = function() end,
		})
	end
	ListWindow.fill(window, "ItemTemplate", "EatButton", rows)
end

local function onState(state: any)
	if state.openBoard then
		local window = gui:FindFirstChild("QuestBoardWindow") :: Frame
		renderBoard()
		Menus.open(window)
		return
	end
	goals = state.goals or {}
	local objective = gui:FindFirstChild("Objective", true) :: Frame
	-- a rewarded objective (Quests) carries its reward after it
	local line = if state.reward then `{state.objective} · Reward: {state.reward}` else state.objective;
	(objective:FindFirstChild("Text") :: TextLabel).Text = line
	objective.Visible = state.objective ~= ""

	TravelMenu.setTaught(state.travel)

	local newBeat = state.beat ~= lastBeat or state.elder ~= lastElder
	local first = lastBeat == nil
	lastBeat, lastElder = state.beat, state.elder
	-- the guide first, so a spotlight can carry the line beside its control
	Guide.set(state.guide, if state.lesson then state.lesson.elder else state.elder)
	if newBeat then
		-- returning players in free play don't need the farewell line every join
		if not (first and state.beat == "FreePlay") then
			showElder(state.elder)
		end
	elseif state.repeatElder then
		showElder(state.elder)
	end
	-- a first-encounter lesson (Quests.Lessons): its line, once
	if state.lesson then
		showElder(state.lesson.elder)
	end

	local window = gui:FindFirstChild("QuestBoardWindow") :: Frame
	if window.Visible then
		renderBoard()
	end
end

function Onboarding.init(screenGui: ScreenGui)
	gui = screenGui
	Guide.init(gui)
	local board = gui:FindFirstChild("QuestBoardWindow") :: Frame
	Menus.register(board)
	ListWindow.bindClose(board)
	questRemote.OnClientEvent:Connect(onState)
end

return Onboarding
