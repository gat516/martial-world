--!strict
-- Sect rank and contribution on screen (docs/ui/sect-board.md, "Rank and
-- contribution"). The rank crest (crest_outer / crest_inner / crest_core with the
-- sect's emblem in its empty centre) and the contribution counter live in the
-- board's status row; the rank-up moment is the shared Rewards card, not a card
-- of our own.
--
-- API (client):
--   SectRank.set({ rank = "Outer", contribution = 1240, week = 120, weekCap = 400 })
--       paints the board's status row; contribution counts up from the last value
--   SectRank.paintCrest(crest: ImageLabel, rank)  -- any RankCrest instance
--   SectRank.rankUp(rank, line?)  -- the milestone card through Rewards.show
--   SectRank.preview()

local Rewards = require(script.Parent.Parent.Rewards)
local Art = require(script.Parent.Art)
local Ui = require(script.Parent.Ui)

local SectRank = {}

export type Rank = "Outer" | "Inner" | "Core"

SectRank.RANKS = {
	Outer = { name = "Outer Disciple", crest = "crest_outer", order = 1 },
	Inner = { name = "Inner Disciple", crest = "crest_inner", order = 2 },
	Core = { name = "Core Disciple", crest = "crest_core", order = 3 },
}

-- The sect's emblem in every rank crest (the official sect; the Blood Sect would
-- pass its own).
SectRank.EMBLEM = "emblem_peak"

export type State = {
	rank: Rank,
	contribution: number,
	week: number?, -- earned this week
	weekCap: number?, -- the weekly cap (progression.md: contribution can't inflate)
}

local shown: number? = nil

-- Put a rank's crest art on a RankCrest instance (an ImageLabel with an Emblem
-- child) and centre the emblem on that crest's hole.
function SectRank.paintCrest(crest: ImageLabel, rank: Rank)
	local def = SectRank.RANKS[rank]
	local key = def.crest
	crest.Image = Art.Id[key]
	local emblem = crest:FindFirstChild("Emblem") :: ImageLabel
	emblem.Image = Art.Id[SectRank.EMBLEM]
	-- The crest is drawn Fit in a square box: map the hole (fractions of the
	-- image) into the box.
	local size = Art.Size[key]
	local hole = Art.Hole[key]
	local aspect = size.X / size.Y
	local w, h = math.min(1, aspect), math.min(1, 1 / aspect)
	local x0, y0 = (1 - w) / 2, (1 - h) / 2
	emblem.Position = UDim2.fromScale(x0 + hole.centre.X * w, y0 + hole.centre.Y * h)
	local d = math.min(hole.size.X * w, hole.size.Y * h) * 0.72
	emblem.Size = UDim2.fromScale(d, d)
end

-- The board's status row: crest, rank name, contribution and the week's share.
function SectRank.set(state: State)
	local board = Ui.canvas():FindFirstChild("Board") :: Frame
	local status = (board:FindFirstChild("Content") :: Frame):FindFirstChild("Status") :: Frame
	SectRank.paintCrest(status:FindFirstChild("RankCrest") :: ImageLabel, state.rank);
	(status:FindFirstChild("RankName") :: TextLabel).Text = SectRank.RANKS[state.rank].name
	local box = status:FindFirstChild("Contribution") :: Frame
	local amount = box:FindFirstChild("Amount") :: TextLabel
	Ui.countTo(amount, shown or state.contribution, state.contribution)
	shown = state.contribution
	local week = box:FindFirstChild("Week") :: TextLabel
	week.Visible = state.weekCap ~= nil
	if state.weekCap then
		week.Text = `{Ui.formatNumber(state.week or 0)} / {Ui.formatNumber(state.weekCap)} this week`
	end
end

-- The rank-up moment: the shared Rewards card (kind "rank", roadmap 3c), never a
-- card of our own. Only the crest image shows until the card's Crest gets an
-- Emblem child (docs/ui/sect-board.md).
function SectRank.rankUp(rank: Rank, line: string?)
	local def = SectRank.RANKS[rank]
	Rewards.show({
		tier = "card",
		kind = "rank",
		title = def.name,
		subtitle = "The sect raises you in rank",
		flavour = line,
		crest = { image = Art.Id[def.crest], emblem = Art.Id[SectRank.EMBLEM], hole = Art.Hole[def.crest] },
	})
end

-- Sample content: the board's status row through all three ranks, the counter
-- ticking up, then the rank-up card.
function SectRank.preview()
	local board = Ui.window("Board")
	Ui.open(board)
	task.spawn(function()
		SectRank.set({ rank = "Outer", contribution = 180, week = 60, weekCap = 400 })
		task.wait(1.2)
		SectRank.set({ rank = "Outer", contribution = 300, week = 180, weekCap = 400 })
		task.wait(1.2)
		SectRank.set({ rank = "Inner", contribution = 300, week = 180, weekCap = 400 })
		task.wait(1.2)
		SectRank.set({ rank = "Core", contribution = 1240, week = 400, weekCap = 400 })
		SectRank.rankUp("Core", "The inner peaks are open to you.")
	end)
end

return SectRank
