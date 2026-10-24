--!strict
-- The sect on this client (server Sect; docs/systems/sect.md): wires the sect
-- screens (src/client/Sect: SectBoard, QuestLog, SectRank) to the server's view.
--   QuestState { sect = view, open = bool }  the board, quest log, rank and the
--       Pavilion's stock; `open` opens the board (its Read prompt, from QC5)
--   QuestState { sectRankUp = { rank, line, items } }  the rank card
-- Actions go up on CultivationAction ("sect", op, arg); the server answers with a
-- fresh view (and says any refusal as a toast).
--   Board    an offered notice: take it; a done one: claim it (the promotion
--            notice promotes); a taken one opens it in the quest log; the
--            Pavilion notice opens the Pavilion.
--   Pavilion no Pavilion page exists in the Sect screens yet: it borrows the
--            HUD's QuestBoardWindow (a ListWindow, retitled "Sect Pavilion",
--            attribute Mode = "Pavilion" so Onboarding leaves it alone) until a
--            ui-designer builds one (docs/systems/sect.md "Known gaps").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ListWindow = require(script.Parent.ListWindow)
local Menus = require(script.Parent.Menus)
local SectBoard = require(script.Parent.Sect.SectBoard)
local QuestLog = require(script.Parent.Sect.QuestLog)
local SectRank = require(script.Parent.Sect.SectRank)
local Ui = require(script.Parent.Sect.Ui)

local questRemote = ReplicatedStorage.Remotes.QuestState :: RemoteEvent
local actionRemote = ReplicatedStorage.Remotes.CultivationAction :: RemoteFunction

local SectView = {}

local gui: ScreenGui
local view: any = nil
local CONTRIBUTION = Color3.fromRGB(232, 190, 92)
local LOCKED = Color3.fromRGB(120, 112, 98)

local function call(op: string, arg: any?)
	task.spawn(function()
		actionRemote:InvokeServer("sect", op, arg)
	end)
end

local function pavilionWindow(): Frame
	return gui:FindFirstChild("QuestBoardWindow") :: Frame
end

local function renderPavilion()
	local window = pavilionWindow()
	local rows: { ListWindow.Row } = {}
	for _, s in (view and view.stock or {}) :: { any } do
		table.insert(rows, {
			color = if s.why then LOCKED else CONTRIBUTION,
			name = s.name,
			detail = if s.why then `{s.detail} ({s.why})` else s.detail,
			count = 0,
			countText = `{s.cost} contribution`,
			buttonText = "Buy",
			hideButton = s.why ~= nil,
			onPress = function()
				call("buy", s.id)
			end,
		})
	end
	ListWindow.fill(window, "ItemTemplate", "EatButton", rows)
	local title = window:FindFirstChild("Title") :: TextLabel
	local purse = if view then view.status.contribution else 0
	title.Text = `Sect Pavilion · {purse} contribution`
end

local function openPavilion()
	local window = pavilionWindow()
	window:SetAttribute("Mode", "Pavilion")
	renderPavilion()
	Menus.open(window)
end

local function logOf(selected: string?): QuestLog.Log
	local tracked = if view.tracked ~= "" then view.tracked else nil
	return {
		quests = view.quests,
		selected = selected,
		tracked = tracked,
		onTrack = function(id: string?)
			call("track", id or "")
		end,
	}
end

local function openLog(selected: string?)
	if view then
		QuestLog.open(logOf(selected))
	end
end

local function boardOf(): SectBoard.Board
	return {
		tasks = view.tasks,
		status = view.status,
		onTake = function(id: string)
			call("take", id)
		end,
		onClaim = function(id: string)
			if id == "promotion" then
				call("promote")
			else
				call("claim", id)
			end
		end,
		onSelect = function(task: SectBoard.Task)
			if task.kind == "pavilion" then
				openPavilion()
			elseif task.state == "taken" then
				openLog(if task.kind == "daily" then `daily:{task.id}` else task.id)
			end
		end,
	}
end

local function isOpen(name: string): boolean
	local window = Ui.canvas():FindFirstChild(name) :: GuiObject?
	return window ~= nil and window.Visible
end

local function onState(state: any)
	if state.sectRankUp then
		local r = state.sectRankUp
		SectRank.rankUp(r.rank, r.line, r.items)
		return
	end
	if not state.sect then
		return
	end
	view = state.sect
	if state.open then
		SectBoard.open(boardOf())
		return
	end
	if isOpen("Board") then
		SectBoard.open(boardOf()) -- re-renders in place
	end
	if isOpen("QuestLog") then
		QuestLog.update(view.quests)
	end
	local window = pavilionWindow()
	if window.Visible and window:GetAttribute("Mode") == "Pavilion" then
		renderPavilion()
	end
end

function SectView.init(screenGui: ScreenGui)
	gui = screenGui
	questRemote.OnClientEvent:Connect(onState)
end

-- Open the quest log from anywhere (nothing calls it yet: a HUD entry is a UI gap).
function SectView.openLog()
	openLog(nil)
end

return SectView
