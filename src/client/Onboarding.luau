--!strict
-- Onboarding and quest board UI: the objective tracker under the top-right tiles,
-- the elder's one-line guidance (shown once per beat, never blocking), a gentle
-- pulse on the button the current beat is about, the Travel button appearing when
-- the formation is taught, and the quest board window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ListWindow = require(script.Parent.ListWindow)

local questRemote = ReplicatedStorage.Remotes.QuestState :: RemoteEvent

local ELDER_SECONDS = 7
local PULSE_SCALE = 1.12

-- Which button each beat is about.
local FOCUS = {
	Circulate = "CultivateButton",
	Breakthrough = "BreakthroughButton",
	Gate = "TravelButton",
	FirstKill = "AttackButton",
	Refine = "CultivateButton",
}

local Onboarding = {}

local gui: ScreenGui
local lastBeat: string? = nil
local lastElder = ""
local elderToken = 0
local pulsing: { button: GuiButton, scale: UIScale, tween: Tween }? = nil
local goals: { any } = {}

local function findButton(name: string): GuiButton?
	return gui:FindFirstChild(name, true) :: GuiButton?
end

-- A gentle swell on the button the current beat is about (a short-lived UIScale,
-- since the buttons are art rather than coloured backgrounds).
local function pulse(name: string?)
	if pulsing then
		pulsing.tween:Cancel()
		pulsing.scale:Destroy()
		pulsing = nil
	end
	local button = name and findButton(name)
	if button then
		local scale = Instance.new("UIScale")
		scale.Name = "OnboardingPulse"
		scale.Parent = button
		local tween = TweenService:Create(scale, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Scale = PULSE_SCALE,
		})
		pulsing = { button = button, scale = scale, tween = tween }
		tween:Play()
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
		window.Visible = true
		renderBoard()
		return
	end
	goals = state.goals or {}
	local objective = gui:FindFirstChild("Objective", true) :: Frame
	(objective:FindFirstChild("Text") :: TextLabel).Text = state.objective
	objective.Visible = state.objective ~= ""

	local travel = findButton("TravelButton")
	if travel then
		travel.Visible = state.travel
	end

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
	pulse(FOCUS[state.beat])

	local window = gui:FindFirstChild("QuestBoardWindow") :: Frame
	if window.Visible then
		renderBoard()
	end
end

function Onboarding.init(screenGui: ScreenGui)
	gui = screenGui
	ListWindow.bindClose(gui:FindFirstChild("QuestBoardWindow") :: Frame)
	local travel = findButton("TravelButton")
	if travel then
		travel.Visible = false -- until the server says it's taught
	end
	questRemote.OnClientEvent:Connect(onState)
end

return Onboarding
