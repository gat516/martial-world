--!strict
-- Onboarding and quest board UI: the objective tracker under the top-right tiles
-- (with the objective's reward, when it has one),
-- the elder's one-line guidance (shown once per beat, never blocking), his
-- conversation on the dialogue screen when the player talks to him, the
-- server's guide (Guide: a pulsing or spotlit control, a path to walk), the
-- Travel button appearing when the formation is taught, and the quest board.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dialogue = require(script.Parent.Dialogue)
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
	if window:GetAttribute("Mode") == "Pavilion" then
		return -- SectView has borrowed the window for the Pavilion
	end
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

local function openBoard()
	local window = gui:FindFirstChild("QuestBoardWindow") :: Frame
	window:SetAttribute("Mode", nil);
	(window:FindFirstChild("Title") :: TextLabel).Text = "Quest Board"
	renderBoard()
	Menus.open(window)
end

-- The elder's conversation (Quests.talk): his lines, then the player's reply,
-- the quest board in free play, and Farewell.
local function talk(t: any)
	local responses: { Dialogue.Response } = { { text = t.reply, icon = "talk", highlight = true } }
	local boardAt: number? = nil
	if t.board then
		table.insert(responses, { text = "What should I aim for next?", icon = "quest" })
		boardAt = #responses
	end
	table.insert(responses, { text = "Farewell.", icon = "leave", cancel = true })
	-- walking away from him ends the conversation (a little past his prompt's reach)
	local hub = workspace:FindFirstChild("Hub")
	local elder = hub and hub:FindFirstChild("Elder") :: PVInstance?
	local prompt = elder and elder:FindFirstChild("TalkPrompt", true) :: ProximityPrompt?
	local choice = Dialogue.open({
		speaker = "Elder Qingyun",
		portrait = "elder_qingyun",
		lines = t.lines,
		responses = responses,
		near = elder,
		range = if prompt then prompt.MaxActivationDistance + 4 else nil,
	})
	if choice and choice == boardAt then
		openBoard()
	end
end

local function onState(state: any)
	if state.sect or state.sectRankUp then
		return -- the sect board's own payloads (SectView)
	end
	if state.openBoard then
		openBoard()
		return
	end
	if state.talk then
		task.spawn(talk, state.talk)
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
