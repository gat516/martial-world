--!strict
-- The Hall panel stub (docs/ui/halls-masters.md, "Hall panel"): a Hall's crest,
-- name and allegiance, its shared goal, and the members list. Read-only for now;
-- Hall actions (invite, furnish, leave) come with the Hall system.
--
-- API (client):
--   HallPanel.open(hall)  open (or refresh)
--   HallPanel.close()
--   HallPanel.preview()
--
-- hall = {
--   name = string,
--   crest = HallCrest.Spec,
--   allegiance = "sect" | "blood" | "independent",
--   cap = number,                       -- member cap (10-30)
--   goal = { text = string, progress = number, target = number }?,
--   members = { { name = string, realm = string, role = string?, online = boolean? } },
-- }

local HallCrest = require(script.Parent.HallCrest)
local Motion = require(script.Parent.Parent.Motion)
local Ui = require(script.Parent.Ui)

local HallPanel = {}

export type Member = { name: string, realm: string, role: string?, online: boolean? }
export type Hall = {
	name: string,
	crest: HallCrest.Spec,
	allegiance: string,
	cap: number,
	goal: { text: string, progress: number, target: number }?,
	members: { Member },
}

local ALLEGIANCE = { sect = "Sect Hall", blood = "Blood Sect Hall", independent = "Independent Hall" }
local CREAM = Color3.fromRGB(250, 236, 195)
local OFFLINE = Color3.fromRGB(150, 144, 132)

local function window(): Frame
	return Ui.window("Hall")
end

function HallPanel.open(hall: Hall)
	local w = window()
	local content = w:FindFirstChild("Content") :: Frame
	local left = content:FindFirstChild("Left") :: Frame
	local right = content:FindFirstChild("Right") :: Frame
	HallCrest.compose(left:FindFirstChild("Crest") :: Frame, hall.crest);
	(left:FindFirstChild("HallName") :: TextLabel).Text = hall.name;
	(left:FindFirstChild("Allegiance") :: TextLabel).Text =
		`{ALLEGIANCE[hall.allegiance] or "Hall"} · {#hall.members} / {hall.cap} members`

	local goal = right:FindFirstChild("Goal") :: Frame
	goal.Visible = hall.goal ~= nil
	if hall.goal then
		local g = hall.goal;
		(goal:FindFirstChild("GoalText") :: TextLabel).Text = g.text;
		(goal:FindFirstChild("Count") :: TextLabel).Text = `{Ui.formatNumber(g.progress)} / {Ui.formatNumber(g.target)}`
		local fill = ((goal:FindFirstChild("Bar") :: Frame):FindFirstChild("Track") :: Frame):FindFirstChild("Fill") :: Frame
		local share = if g.target > 0 then math.clamp(g.progress / g.target, 0, 1) else 0
		Motion.ease(fill, { Size = UDim2.fromScale(share, 1) })
	end

	local list = right:FindFirstChild("Members") :: ScrollingFrame
	Ui.clearRows(list)
	local online = 0
	for i, m in hall.members do
		local row = Ui.clone("MemberRow") :: Frame
		row.Name = "Row"
		row.LayoutOrder = i
		local name = row:FindFirstChild("PlayerName") :: TextLabel
		name.Text = m.name
		name.TextColor3 = if m.online then CREAM else OFFLINE;
		(row:FindFirstChild("Realm") :: TextLabel).Text = m.realm;
		(row:FindFirstChild("Role") :: TextLabel).Text = m.role or ""
		if m.online then
			online += 1
		end
		row.Parent = list
	end
	Ui.fitCanvas(list);
	(right:FindFirstChild("Online") :: TextLabel).Text = `{online} here now`
	if not w.Visible then
		Ui.open(w)
	end
end

function HallPanel.close()
	Ui.close(window())
end

function HallPanel.preview()
	HallPanel.open({
		name = "Azure Cloud Hall",
		crest = { shield = "kite", ring = "dragon", emblem = "tortoise" },
		allegiance = "sect",
		cap = 30,
		goal = { text = "Fill the hall storehouse before the beast tide", progress = 340, target = 500 },
		members = {
			{ name = "Lin Yue", realm = "Foundation Establishment 2", role = "Hall Master", online = true },
			{ name = "Bai Feng", realm = "Qi Refining 7", role = "Elder", online = true },
			{ name = "Wen Shu", realm = "Qi Refining 4", role = "Member", online = false },
			{ name = "Zhao Ming", realm = "Qi Condensation 9", role = "Member", online = true },
			{ name = "Qiu Lan", realm = "Qi Refining 1", role = "Member", online = false },
			{ name = "He Yun", realm = "Qi Condensation 6", role = "Member", online = false },
		},
	})
end

return HallPanel
