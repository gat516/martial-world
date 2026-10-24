--!strict
-- The quest log (docs/ui/sect-board.md, "Quest log"): a compact list on the
-- left, the selected quest's detail on the right, in one centred window that
-- fits a landscape phone as authored. Chapter quests carry the quest scroll,
-- dailies and weeklies their seals, everything else the quest glyph.
--
-- API (client):
--   QuestLog.open(log)       open (or refresh) the log
--   QuestLog.update(quests)  re-render if open (keeps the selection by id)
--   QuestLog.close()
--   QuestLog.preview()
--
-- log = {
--   quests = { Quest },        -- in display order (server sorts)
--   selected = string?,        -- id to show first (default: the tracked one, else the first)
--   tracked = string?,         -- id the HUD objective line follows
--   onTrack = (id: string?) -> (),  -- Track pressed (nil: stop tracking)
-- }
-- Quest = {
--   id = string,
--   kind = "chapter" | "daily" | "weekly" | "spirit" | "other",
--   name = string,
--   giver = string?, place = string?,  -- "From <giver> · <place>"
--   description = string,
--   status = string?,                  -- the row's second line (default: the first open objective)
--   objectives = { { text = string, progress = number?, goal = number?, done = boolean? } },
--   rewards = { { kind = "contribution" | "stones" | "qi", amount = number } },
-- }

local Art = require(script.Parent.Art)
local Ui = require(script.Parent.Ui)

local QuestLog = {}

export type Objective = { text: string, progress: number?, goal: number?, done: boolean? }
export type Reward = { kind: string, amount: number }
export type Quest = {
	id: string,
	kind: string,
	name: string,
	giver: string?,
	place: string?,
	description: string,
	status: string?,
	objectives: { Objective },
	rewards: { Reward },
}
export type Log = {
	quests: { Quest },
	selected: string?,
	tracked: string?,
	onTrack: ((id: string?) -> ())?,
}

local GOLD = Color3.fromRGB(232, 190, 92)
local MUTED = Color3.fromRGB(196, 182, 150)
local CREAM = Color3.fromRGB(250, 236, 195)
local JADE = Color3.fromRGB(126, 214, 160)

local REWARD_ICON = {
	contribution = { "contribution_token", nil },
	stones = { "glyph_spirit_stone", JADE },
	qi = { "glyph_qi", JADE },
}

local current: Log? = nil
local selected: string? = nil
local trackConn: RBXScriptConnection? = nil

local function window(): Frame
	return Ui.window("QuestLog", function()
		current = nil
	end)
end

local function content(): Frame
	return window():FindFirstChild("Content") :: Frame
end

-- The kind badge: a seal with its live character, the quest scroll, or the glyph.
local SEAL_GROW = 80 / 72

local function paintIcon(icon: Frame, kind: string)
	local seal = icon:FindFirstChild("Seal") :: ImageLabel
	local scroll = icon:FindFirstChild("Scroll") :: ImageLabel
	local char = seal:FindFirstChild("Char") :: TextLabel
	scroll.Visible = kind == "chapter"
	seal.Visible = kind ~= "chapter"
	if kind == "daily" or kind == "weekly" then
		seal.Image = Art.Id[kind .. "_seal"]
		seal.ImageColor3 = Color3.new(1, 1, 1)
		-- the seal copies keep a clear margin (4 px round 72 px of art, art/ui/sized)
		-- so the stamp's edge isn't cut flat: the image is that much bigger than the badge
		seal.Size = UDim2.fromScale(SEAL_GROW, SEAL_GROW)
		seal.Position = UDim2.fromScale((1 - SEAL_GROW) / 2, (1 - SEAL_GROW) / 2)
		char.Text = if kind == "weekly" then "周" else "日"
	else
		-- the white quest glyph, tinted gold, at its own aspect (306x354)
		seal.Image = Art.Id.glyph_quest
		seal.ImageColor3 = GOLD
		seal.Size = UDim2.fromScale(0.62, 0.72)
		seal.Position = UDim2.fromScale(0.19, 0.14)
		char.Text = ""
	end
end

local function firstOpen(quest: Quest): string
	for _, o in quest.objectives do
		if not o.done then
			return if o.goal then `{o.progress or 0} / {o.goal} · {o.text}` else o.text
		end
	end
	return "Ready to hand in"
end

local function paintTrack(quest: Quest, log: Log)
	local track = ((content():FindFirstChild("Detail") :: Frame):FindFirstChild("Footer") :: Frame):FindFirstChild("Track") :: ImageButton
	local label = track:FindFirstChild("Label") :: TextLabel
	local on = log.tracked == quest.id
	label.Text = if on then "Tracking" else "Track"
	label.TextColor3 = if on then JADE else CREAM
	if trackConn then
		trackConn:Disconnect()
	end
	trackConn = track.Activated:Connect(function()
		log.tracked = if log.tracked == quest.id then nil else quest.id
		if log.onTrack then
			log.onTrack(log.tracked)
		end
		paintTrack(quest, log)
	end)
end

local function showDetail(quest: Quest?, log: Log)
	local detail = content():FindFirstChild("Detail") :: Frame
	detail.Visible = quest ~= nil
	if not quest then
		return
	end
	local head = detail:FindFirstChild("Head") :: Frame
	local icon = head:FindFirstChild("Icon") :: Frame
	paintIcon(icon, quest.kind);
	(head:FindFirstChild("QuestTitle") :: TextLabel).Text = quest.name
	local from = {}
	if quest.giver then
		table.insert(from, `From {quest.giver}`)
	end
	if quest.place then
		table.insert(from, quest.place)
	end
	(head:FindFirstChild("Giver") :: TextLabel).Text = table.concat(from, " · ")

	local scroll = detail:FindFirstChild("Scroll") :: ScrollingFrame;
	(scroll:FindFirstChild("Description") :: TextLabel).Text = quest.description
	local objectives = scroll:FindFirstChild("Objectives") :: Frame
	Ui.clearRows(objectives)
	for i, o in quest.objectives do
		local row = Ui.clone("Objective") :: Frame
		row.Name = "Row"
		row.LayoutOrder = i
		local done = o.done == true;
		(row:FindFirstChild("Check") :: ImageLabel).Visible = done;
		(row:FindFirstChild("Bullet") :: TextLabel).Visible = not done
		local line = row:FindFirstChild("Line") :: TextLabel
		line.Text = o.text
		line.TextColor3 = if done then MUTED else CREAM;
		(row:FindFirstChild("Count") :: TextLabel).Text = if o.goal and not done then `{o.progress or 0} / {o.goal}` else ""
		row.Parent = objectives
	end
	Ui.fitCanvas(scroll)
	scroll.CanvasPosition = Vector2.zero

	local rewards = (detail:FindFirstChild("Footer") :: Frame):FindFirstChild("Rewards") :: Frame
	Ui.clearRows(rewards)
	for i, r in quest.rewards do
		local chip = Ui.clone("RewardChip") :: Frame
		chip.Name = "Row"
		chip.LayoutOrder = i
		local spec = REWARD_ICON[r.kind] or REWARD_ICON.contribution
		local img = chip:FindFirstChild("Icon") :: ImageLabel
		img.Image = Art.Id[spec[1]]
		if spec[2] then
			img.ImageColor3 = spec[2]
			img.Size = UDim2.fromOffset(20, 20)
		end
		(chip:FindFirstChild("Amount") :: TextLabel).Text = `+{Ui.formatNumber(r.amount)}`
		chip.Parent = rewards
	end
	paintTrack(quest, log)
end

local function paintRow(row: ImageButton, on: boolean)
	local plate = row:FindFirstChild("Plate") :: Frame
	local suffix = if on then "catalog_tab_selected_" else "catalog_tab_";
	(plate:FindFirstChild("CapL") :: ImageLabel).Image = Art.Id[suffix .. "capL"];
	(plate:FindFirstChild("Mid") :: ImageLabel).Image = Art.Id[suffix .. "mid"];
	(plate:FindFirstChild("CapR") :: ImageLabel).Image = Art.Id[suffix .. "capR"]
end

local function render(log: Log)
	local list = content():FindFirstChild("List") :: ScrollingFrame
	Ui.clearRows(list)
	local byId: { [string]: Quest } = {}
	for _, q in log.quests do
		byId[q.id] = q
	end
	if not (selected and byId[selected]) then
		selected = log.selected or log.tracked or (log.quests[1] and log.quests[1].id)
	end
	local rows: { [string]: ImageButton } = {}
	for i, quest in log.quests do
		local row = Ui.clone("QuestRow") :: ImageButton
		row.Name = "Row"
		row.LayoutOrder = i
		paintIcon(row:FindFirstChild("Icon") :: Frame, quest.kind);
		(row:FindFirstChild("QuestName") :: TextLabel).Text = quest.name;
		(row:FindFirstChild("Sub") :: TextLabel).Text = quest.status or firstOpen(quest)
		paintRow(row, quest.id == selected)
		rows[quest.id] = row
		row.Activated:Connect(function()
			if selected and rows[selected] then
				paintRow(rows[selected], false)
			end
			selected = quest.id
			paintRow(row, true)
			showDetail(quest, log)
		end)
		row.Parent = list
	end
	Ui.fitCanvas(list);
	(content():FindFirstChild("Empty") :: TextLabel).Visible = #log.quests == 0
	showDetail(if selected then byId[selected] else nil, log)
end

function QuestLog.open(log: Log)
	current = log
	selected = nil
	render(log)
	local w = window()
	if not w.Visible then
		Ui.open(w)
	end
end

function QuestLog.update(quests: { Quest })
	local log = current
	if log then
		log.quests = quests
		render(log)
	end
end

function QuestLog.close()
	Ui.close(window())
end

function QuestLog.preview()
	QuestLog.open({
		tracked = "bridge",
		quests = {
			{
				id = "bridge",
				kind = "chapter",
				name = "The ruined bridge",
				giver = "Elder Qingyun",
				place = "Ruined Borderlands",
				description = "The old crossing over the gorge fell in a single night. Travellers whisper of claw marks on the stones. Find out what broke it.",
				objectives = {
					{ text = "Reach the ruined bridge", done = true },
					{ text = "Search the far bank", progress = 1, goal = 3 },
					{ text = "Report to the elder" },
				},
				rewards = { { kind = "contribution", amount = 80 }, { kind = "stones", amount = 120 }, { kind = "qi", amount = 300 } },
			},
			{
				id = "wolves",
				kind = "daily",
				name = "Thin the ash wolves",
				giver = "The sect board",
				description = "Five ash wolves prowl the Borderland road. Drive them off before the courier passes.",
				objectives = { { text = "Ash wolves", progress = 2, goal = 5 } },
				rewards = { { kind = "contribution", amount = 40 } },
			},
			{
				id = "store",
				kind = "weekly",
				name = "Fill the storehouse",
				giver = "The sect board",
				description = "The storehouse runs low before the beast tide. Every core helps.",
				objectives = { { text = "Beast cores delivered", progress = 8, goal = 20 } },
				rewards = { { kind = "contribution", amount = 150 }, { kind = "stones", amount = 60 } },
			},
			{
				id = "garden",
				kind = "daily",
				name = "Tend the sect garden",
				giver = "Herbalist Mei",
				description = "Water the sect's spirit plots once.",
				status = "Ready to hand in",
				objectives = { { text = "Water the plots", done = true } },
				rewards = { { kind = "contribution", amount = 20 } },
			},
			{
				id = "spirit",
				kind = "spirit",
				name = "A lost spirit",
				place = "Misty Pines",
				description = "A small light drifts between the pines at dusk, as if looking for something.",
				objectives = { { text = "Follow the light" } },
				rewards = { { kind = "qi", amount = 40 } },
			},
		},
		onTrack = function(id)
			print("QuestLog.preview: track", id)
		end,
	})
end

return QuestLog
