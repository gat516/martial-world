--!strict
-- The leaderboard window (ready to wire; no leaderboard system exists yet,
-- roadmap 9 "Goals that don't end"). A centred window in the Events screen with
-- board tabs, a scrolling list of rows and your own row pinned under it. The top
-- three ranks sit in gold, silver and bronze medals with the number live in the
-- ring; each row shows the player's path crest. docs/ui/leaderboards.md.
--
-- API:
--   Leaderboards.show(data)   open (or refresh) the window
--     data = {
--       boards = { { id = "realm", title = "Realm" }, ... },   -- the tabs, in order
--       board = "realm",                                        -- the selected tab
--       rows = { { rank = 1, name = "Wei Lan", path = "orthodox", value = "QC 9" }, ... },
--       you = { rank = 42, name = "You", path = "rogue", value = "QC 3" }?,
--       onTab = function(id) end?,  -- a tab was pressed (fetch, then show again)
--       theme = "blood"?,           -- default: the viewer's own path's skin
--     }
--   Leaderboards.close(), Leaderboards.isOpen()
--   Leaderboards.preview(theme?)  sample boards (client console in play)
-- Paths: "orthodox", "rogue", "blood" (or nil: no crest). The Blood Sect crest
-- shows only to a viewer who has found the demon path (their player attribute
-- Path == "blood"); to everyone else a blood-path player shows the rogue crest,
-- so the board never gives the secret away.

local Players = game:GetService("Players")

local Menus = require(script.Parent.Parent.Menus)
local Gui = require(script.Parent.Gui)
local Themes = require(script.Parent.Themes)

local player = Players.LocalPlayer

local MEDALS = {
	"rbxassetid://118278181741651", -- gold
	"rbxassetid://133977245487252", -- silver
	"rbxassetid://102816114690471", -- bronze
}
local CRESTS = {
	orthodox = "rbxassetid://133668296455751",
	rogue = "rbxassetid://134858771424186",
	blood = "rbxassetid://117704084413433",
}
local VISIBLE_ROWS = 6.6 -- rows that fit the list (the last one peeks, so it reads as scrolling)
local ROW_GAP = 4 -- baseline px, the list's UIListLayout padding

export type Row = { rank: number, name: string, path: string?, value: string }
export type Data = {
	boards: { { id: string, title: string } }?,
	board: string?,
	rows: { Row },
	you: Row?,
	onTab: ((string) -> ())?,
	theme: string?,
}

local Leaderboards = {}

local window: Frame? = nil
local current: Data? = nil

local function knowsBlood(): boolean
	return player:GetAttribute("Path") == "blood"
end

local function crestOf(path: string?): string?
	if path == "blood" and not knowsBlood() then
		return CRESTS.rogue
	end
	return if path then CRESTS[path] else nil
end

local function fillRow(row: Frame, data: Row, theme: Themes.Theme)
	local cells = row:FindFirstChild("Cells") :: Frame
	local medal = cells:FindFirstChild("Medal") :: ImageLabel
	medal.Visible = data.rank >= 1 and data.rank <= 3
	if medal.Visible then
		medal.Image = MEDALS[data.rank]
	end
	(cells:FindFirstChild("Rank") :: TextLabel).Text = tostring(data.rank);
	(cells:FindFirstChild("Player") :: TextLabel).Text = data.name
	local crest = cells:FindFirstChild("Crest") :: ImageLabel
	local id = crestOf(data.path)
	crest.Visible = id ~= nil
	crest.Image = id or ""
	local value = cells:FindFirstChild("Value") :: TextLabel
	value.Text = data.value
	value.TextColor3 = theme.accent
	Themes.tintRow(row, theme)
end

local function build(): Frame
	if window then
		return window
	end
	local w = Gui.place("Board", "Board") :: Frame
	w.Visible = false
	Menus.register(w)
	local close = w:FindFirstChild("Close") :: ImageButton
	close.Activated:Connect(function()
		Menus.close(w)
	end)
	window = w
	return w
end

local function render(data: Data)
	local w = build()
	local theme = Themes.get(data.theme or (if knowsBlood() then "blood" else nil))
	Themes.apply(w, theme)
	-- tabs
	local tabs = w:FindFirstChild("Tabs") :: Frame
	local proto = tabs:FindFirstChild("Tab") :: TextButton
	for _, child in tabs:GetChildren() do
		if child:IsA("TextButton") and child ~= proto then
			child:Destroy()
		end
	end
	for i, b in data.boards or {} do
		local tab = proto:Clone()
		tab.Name = b.id
		tab.LayoutOrder = i
		tab.Text = b.title
		tab.Visible = true
		local selected = b.id == data.board
		tab.TextColor3 = if selected then theme.accent else theme.dim;
		(tab:FindFirstChild("Underline") :: ImageLabel).Visible = selected;
		(tab:FindFirstChild("Underline") :: ImageLabel).ImageColor3 = theme.frameTint
		tab.Activated:Connect(function()
			if data.onTab and b.id ~= data.board then
				data.onTab(b.id)
			end
		end)
		tab.Parent = tabs
	end
	-- rows
	local list = w:FindFirstChild("List") :: ScrollingFrame
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local rowHeight = (list.Size.Y.Scale * (w.Parent :: Frame).Size.Y.Offset) / VISIBLE_ROWS - ROW_GAP
	for i, r in data.rows do
		local row = Gui.clone("Row") :: Frame
		row.Name = `Row{i}`
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, rowHeight)
		fillRow(row, r, theme)
		row.Parent = list
	end
	-- baseline units (the canvas's UIScale applies to CanvasSize too)
	list.CanvasSize = UDim2.fromOffset(0, #data.rows * (rowHeight + ROW_GAP) - ROW_GAP)
	list.CanvasPosition = Vector2.zero
	-- you
	local slot = w:FindFirstChild("You") :: Frame
	slot:ClearAllChildren()
	if data.you then
		local you = Gui.clone("RowYou") :: Frame
		you.Size = UDim2.fromScale(1, 1)
		fillRow(you, data.you, theme)
		you.Parent = slot
	end
end

function Leaderboards.show(data: Data)
	current = data
	render(data)
	Menus.open(build())
end

function Leaderboards.close()
	if window then
		Menus.close(window)
	end
end

function Leaderboards.isOpen(): boolean
	return window ~= nil and Menus.isOpen(window)
end

-- Sample boards in play (client console):
--   require(game.Players.LocalPlayer.PlayerScripts.Client.Events.Leaderboards).preview()
--   ...preview("blood") for the Blood Sect skin.
function Leaderboards.preview(theme: string?)
	local names = { "Wei Lan", "Bai Xue", "Old Man Qiu", "Lin Feng", "Su Mei", "Zhao Tian", "Han Yu", "Gu Qing", "Mo Chen" }
	local paths = { "orthodox", "rogue", "orthodox", "blood", "orthodox", "rogue", "orthodox", "orthodox", "rogue" }
	local function rows(board: string): { Row }
		local out = {}
		for i, n in names do
			local value = if board == "realm" then `QC {10 - i}` elseif board == "herbarium" then `{60 - i * 4} herbs` elseif board == "peak" then `{900 - i * 70} m` else `{2000 - i * 150}`
			table.insert(out, { rank = i, name = n, path = paths[i], value = value })
		end
		return out
	end
	local function open(board: string)
		Leaderboards.show({
			boards = {
				{ id = "realm", title = "Realm" },
				{ id = "herbarium", title = "Herbarium" },
				{ id = "peak", title = "Tallest Peak" },
				{ id = "garden", title = "Garden" },
			},
			board = board,
			rows = rows(board),
			you = { rank = 42, name = player.DisplayName, path = if theme == "blood" then "blood" else "orthodox", value = "QC 3" },
			onTab = open,
			theme = theme,
		})
	end
	open("realm")
end

return Leaderboards
