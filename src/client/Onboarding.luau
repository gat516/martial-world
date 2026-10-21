--!strict
-- Onboarding and quest board UI: the objective tracker under the top-right tiles,
-- the elder's one-line guidance (shown once per beat, never blocking), a gentle
-- pulse on the button the current beat is about, the Travel button appearing when
-- the formation is taught, and the quest board window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ListWindow = require(script.Parent.ListWindow)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local TravelMenu = require(script.Parent.TravelMenu)

local questRemote = ReplicatedStorage.Remotes.QuestState :: RemoteEvent

local ELDER_SECONDS = 7

-- Which button each beat is about.
local FOCUS = {
	Circulate = "CultivateButton",
	Breakthrough = "Breakthrough", -- the seated Break Through tile
	Root = "TravelButton",
	Gate = "TravelButton",
	FirstKill = "AttackButton",
	Refine = "CultivateButton",
}

local Onboarding = {}

local gui: ScreenGui
local lastBeat: string? = nil
local lastElder = ""
local elderToken = 0
local pulsing: GuiButton? = nil
local goals: { any } = {}

local function findButton(name: string): GuiButton?
	return gui:FindFirstChild(name, true) :: GuiButton?
end

-- A gentle swell on the button the current beat is about.
local function pulse(name: string?)
	if pulsing then
		Motion.stopPulse(pulsing)
		pulsing = nil
	end
	local button = name and findButton(name)
	if button then
		Motion.pulse(button)
		pulsing = button
	end
end

local function showElder(line: string)
	local frame = gui:FindFirstChild("ElderLine", true) :: Frame
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
	(objective:FindFirstChild("Text") :: TextLabel).Text = state.objective
	objective.Visible = state.objective ~= ""

	TravelMenu.setTaught(state.travel)

	if state.beat ~= lastBeat or state.elder ~= lastElder then
		local first = lastBeat == nil
		lastBeat, lastElder = state.beat, state.elder
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
	pulse(FOCUS[state.beat])

	local window = gui:FindFirstChild("QuestBoardWindow") :: Frame
	if window.Visible then
		renderBoard()
	end
end

function Onboarding.init(screenGui: ScreenGui)
	gui = screenGui
	local board = gui:FindFirstChild("QuestBoardWindow") :: Frame
	Menus.register(board)
	ListWindow.bindClose(board)
	questRemote.OnClientEvent:Connect(onState)
end

return Onboarding
