--!strict
-- The sect board (docs/ui/sect-board.md): a notice board of pinned paper
-- notices for daily, weekly and chapter tasks, with the player's rank and
-- contribution above. Contribution is soft (roadmap 3b): the board only offers;
-- nothing here nags, counts down or pops up by itself.
--
-- API (client):
--   SectBoard.open(board)    open (or refresh) the board window
--   SectBoard.update(tasks)  re-render the notices if the board is open
--   SectBoard.close()
--   SectBoard.preview()      sample notices of every kind and state
--
-- board = {
--   tasks = { Task },          -- in the order to pin them (server sorts: the
--                              -- current wall first, then the rest)
--   status = SectRank.State?,  -- rank and contribution for the status row
--   onTake = (id) -> (),       -- an offered notice was taken
--   onClaim = (id) -> (),      -- a done notice's reward was claimed
--   onSelect = (task) -> (),   -- any other tap (e.g. open it in the quest log;
--                              -- a torn notice: the elder's hint)
-- }
-- Task = {
--   id = string,
--   kind = "daily" | "weekly" | "chapter" | "torn" | "promotion" | "pavilion" | "bonus" (the last three: the daily seal with 升 / 阁 / 赏),
--   title = string,            -- not shown on a torn notice
--   body = string,             -- one or two short lines (about 60 characters)
--   glyph = string?,           -- "fight" | "harvest" | "plant" | "give" | "quest" | "chest" | "qi" | "bow"
--   reward = number?,          -- contribution
--   progress = number?, goal = number?,
--   state = "offered" | "taken" | "done" | "claimed",
-- }

local Art = require(script.Parent.Art)
local SectRank = require(script.Parent.SectRank)
local Ui = require(script.Parent.Ui)
local Motion = require(script.Parent.Parent.Motion)

local SectBoard = {}

export type Task = {
	id: string,
	kind: string,
	title: string?,
	body: string,
	glyph: string?,
	reward: number?,
	progress: number?,
	goal: number?,
	state: string?,
}

export type Board = {
	tasks: { Task },
	status: SectRank.State?,
	onTake: ((id: string) -> ())?,
	onClaim: ((id: string) -> ())?,
	onSelect: ((task: Task) -> ())?,
}

local KIND_CHAR = { daily = "日", weekly = "周", promotion = "升", pavilion = "阁", bonus = "赏" } -- day, week, rise, pavilion, bounty: live text in the seal's empty face
local DIMMED = Color3.fromRGB(205, 198, 184) -- a claimed notice's paper
local INK_CREAM = Color3.fromRGB(250, 236, 195)

local current: Board? = nil
local lastState: { [string]: string } = {} -- id -> state, to stamp only on the change

local function window(): Frame
	return Ui.window("Board", function()
		current = nil
	end)
end

local function stamp(seal: ImageLabel, animate: boolean)
	seal.Visible = true
	if animate then
		seal.Size = UDim2.fromOffset(120, 120)
		seal.ImageTransparency = 1
		Motion.tween(seal, { Size = UDim2.fromOffset(72, 72), ImageTransparency = 0 }, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
	end
end

local function makeNotice(task: Task, order: number, board: Board): GuiObject
	if task.kind == "torn" then
		local torn = Ui.clone("Torn") :: ImageButton
		torn.Name = "Row"
		torn.LayoutOrder = order;
		(torn:FindFirstChild("Body") :: TextLabel).Text = task.body
		torn.Activated:Connect(function()
			if board.onSelect then
				board.onSelect(task)
			end
		end)
		return torn
	end

	local notice = Ui.clone("Notice") :: ImageButton
	notice.Name = "Row"
	notice.LayoutOrder = order
	local kind = notice:FindFirstChild("Kind") :: ImageLabel
	local scroll = notice:FindFirstChild("Scroll") :: ImageLabel
	local chapter = task.kind == "chapter"
	kind.Visible = not chapter
	scroll.Visible = chapter
	if not chapter then
		kind.Image = Art.Id[if task.kind == "weekly" then "weekly_seal" else "daily_seal"];
		(kind:FindFirstChild("Char") :: TextLabel).Text = KIND_CHAR[task.kind] or ""
	end
	local glyph = notice:FindFirstChild("Glyph") :: ImageLabel
	local glyphId = task.glyph and Art.Id["glyph_" .. task.glyph]
	glyph.Visible = glyphId ~= nil
	if glyphId then
		glyph.Image = glyphId
	end
	(notice:FindFirstChild("NoticeTitle") :: TextLabel).Text = task.title or "";
	(notice:FindFirstChild("Body") :: TextLabel).Text = task.body

	local footer = notice:FindFirstChild("Footer") :: Frame
	local reward = footer:FindFirstChild("Reward") :: TextLabel
	local token = footer:FindFirstChild("Token") :: ImageLabel
	reward.Visible = task.reward ~= nil
	token.Visible = task.reward ~= nil
	reward.Text = if task.reward then `+{Ui.formatNumber(task.reward)}` else ""

	local state = task.state or "offered"
	local progress = footer:FindFirstChild("Progress") :: TextLabel
	local action = footer:FindFirstChild("Action") :: ImageButton
	local actionLabel = action:FindFirstChild("Label") :: TextLabel
	progress.Visible = state == "taken" and task.goal ~= nil
	progress.Text = if task.goal then `{task.progress or 0} / {task.goal}` else ""
	action.Visible = state == "offered" or state == "done"
	if state == "done" then
		action.Image = Art.Id.tag_jade
		actionLabel.Text = "Claim"
		actionLabel.TextColor3 = INK_CREAM
		actionLabel.TextStrokeTransparency = 0
	else
		actionLabel.Text = "Take"
	end

	if state == "claimed" then
		notice.ImageColor3 = DIMMED
		stamp(notice:FindFirstChild("Stamp") :: ImageLabel, lastState[task.id] ~= nil and lastState[task.id] ~= "claimed")
	end
	lastState[task.id] = state

	local function press()
		if state == "offered" and board.onTake then
			board.onTake(task.id)
		elseif state == "done" and board.onClaim then
			board.onClaim(task.id)
		elseif board.onSelect then
			board.onSelect(task)
		end
	end
	notice.Activated:Connect(press)
	action.Activated:Connect(press)
	return notice
end

local function render(board: Board)
	local content = window():FindFirstChild("Content") :: Frame
	local list = content:FindFirstChild("Notices") :: ScrollingFrame
	Ui.clearRows(list)
	for i, task in board.tasks do
		makeNotice(task, i, board).Parent = list
	end
	(content:FindFirstChild("Empty") :: TextLabel).Visible = #board.tasks == 0
	Ui.fitCanvas(list)
	if board.status then
		SectRank.set(board.status)
	end
end

function SectBoard.open(board: Board)
	current = board
	local w = window()
	render(board)
	if not w.Visible then
		Ui.open(w)
	end
end

function SectBoard.update(tasks: { Task })
	local board = current
	if board then
		board.tasks = tasks
		render(board)
	end
end

function SectBoard.close()
	Ui.close(window())
end

-- Sample notices: every kind and state, and the torn clue. Taking, claiming and
-- selecting only print; nothing is granted.
function SectBoard.preview()
	local tasks: { Task } = {
		{ id = "p1", kind = "daily", title = "Thin the ash wolves", body = "Five ash wolves prowl the Borderland road.", glyph = "fight", reward = 40, progress = 2, goal = 5, state = "taken" },
		{ id = "p2", kind = "daily", title = "Herbs for the alchemy hall", body = "Bring three Spirit Grass to Herbalist Mei.", glyph = "harvest", reward = 30, state = "offered" },
		{ id = "p3", kind = "daily", title = "Tend the sect garden", body = "Water the sect's spirit plots once.", glyph = "plant", reward = 20, state = "done" },
		{ id = "p4", kind = "weekly", title = "Fill the storehouse", body = "Deliver twenty beast cores this week.", glyph = "give", reward = 150, progress = 8, goal = 20, state = "taken" },
		{ id = "p5", kind = "chapter", title = "The ruined bridge", body = "Find what broke the old crossing.", glyph = "quest", reward = 80, progress = 1, goal = 3, state = "taken" },
		{ id = "p6", kind = "daily", title = "Escort the courier", body = "See the courier safely to the outer gate.", glyph = "chest", reward = 25, state = "claimed" },
		{ id = "p7", kind = "torn", body = "...when the moon bl    s red,\nbeyond the br  ken wall\nwhere no disc  ple ret..." },
	}
	local board: Board
	board = {
		tasks = tasks,
		status = { rank = "Outer", contribution = 1240, week = 120, weekCap = 400 },
		onTake = function(id)
			print("SectBoard.preview: take", id)
		end,
		onClaim = function(id)
			for _, t in tasks do
				if t.id == id then
					t.state = "claimed"
				end
			end
			SectBoard.update(tasks)
		end,
		onSelect = function(t)
			print("SectBoard.preview: select", t.id)
		end,
	}
	SectBoard.open(board)
end

return SectBoard
