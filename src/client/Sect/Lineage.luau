--!strict
-- Masters and lineage (docs/ui/halls-masters.md, "Masters and lineage"): the
-- lineage window (the primary master's card with the player's epithet ribbon,
-- the other teachers, and the court's nine numbered seats in a fan) and the
-- master and disciple ceremony card. Portraits are gray silhouettes
-- (portrait_* cuts), never painted.
--
-- API (client):
--   Lineage.open(lineage)           open (or refresh) the lineage window
--   Lineage.ceremony(ceremony)      show the ceremony card (Bow / decline)
--   Lineage.epithet(seat, address, masterEpithet) -> "Second Brother of the Turtle Saint"
--   Lineage.close()
--   Lineage.preview(), Lineage.previewCeremony()
--
-- lineage = {
--   master = Master,                 -- the primary master (cohort and seat)
--   seat = number,                   -- 1-9, the player's seat in the court
--   address = "Brother" | "Sister" | "Sibling",  -- the player's own choice
--   court = { name = string, seats = { Seat } },  -- "First Court"; nine entries, in seat order
--   teachers = { { name = string, since = string } },  -- up to two more masters
-- }
-- Master = { epithet = string, title = string?, teaches = string?, portrait = string? }
--   epithet: "Turtle Saint"; portrait: a portrait_* key ("elder_qingyun"), nil = unnamed silhouette
-- Seat = { name = string?, you = boolean? }  -- name nil = empty seat
-- ceremony = { master = Master, disciple = { name = string, portrait = string? },
--              seat = number, address = string, onBow = () -> (), onDecline = (() -> ())? }

local Art = require(script.Parent.Art)
local Ui = require(script.Parent.Ui)
local Motion = require(script.Parent.Parent.Motion)

local Lineage = {}

export type Master = { epithet: string, title: string?, teaches: string?, portrait: string? }
export type Seat = { name: string?, you: boolean? }
export type LineageData = {
	master: Master,
	seat: number,
	address: string,
	court: { name: string, seats: { Seat } },
	teachers: { { name: string, since: string } },
}
export type Ceremony = {
	master: Master,
	disciple: { name: string, portrait: string? },
	seat: number,
	address: string,
	onBow: () -> (),
	onDecline: (() -> ())?,
}

local ORDINALS = { "First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth" }

-- The fan: seat 1 at the top centre, then 2 left and 3 right one row down, and
-- so on outward (the C3 nine_seat_fan reference). In the Fan frame's offsets.
local FAN_FIRST = 68 -- row 1's centres sit this far either side (plates are 128 wide: an 8 px gap)
local FAN_DX = 40 -- each further row steps this much further out
local FAN_DY = 26 -- row pitch (plates are 24 tall)

local GOLD = Color3.fromRGB(232, 190, 92)
local CREAM = Color3.fromRGB(250, 236, 195)
local MUTED = Color3.fromRGB(150, 144, 132)
local JADE = Color3.fromRGB(126, 214, 160)

function Lineage.epithet(seat: number, address: string, masterEpithet: string): string
	return `{ORDINALS[seat] or tostring(seat)} {address} of the {masterEpithet}`
end

local function portraitId(key: string?): string
	return Art.Id["portrait_" .. (key or "unnamed_silhouette")] or Art.Id.portrait_unnamed_silhouette
end

local function window(): Frame
	return Ui.window("Lineage")
end

local function fanPosition(seat: number): UDim2
	if seat == 1 then
		return UDim2.new(0.5, 0, 0, 0)
	end
	local row = seat // 2
	local side = if seat % 2 == 0 then -1 else 1
	return UDim2.new(0.5, side * (FAN_FIRST + (row - 1) * FAN_DX), 0, row * FAN_DY)
end

function Lineage.open(data: LineageData)
	local w = window()
	local content = w:FindFirstChild("Content") :: Frame
	local card = content:FindFirstChild("Card") :: ImageLabel;
	(card:FindFirstChild("Portrait") :: ImageLabel).Image = portraitId(data.master.portrait)
	local main = card:FindFirstChild("Main") :: Frame;
	(main:FindFirstChild("MasterName") :: TextLabel).Text = `The {data.master.epithet}`;
	(main:FindFirstChild("MasterTitle") :: TextLabel).Text = data.master.title or "";
	(main:FindFirstChild("Teaches") :: TextLabel).Text = if data.master.teaches then `Teaches {data.master.teaches}` else "";
	((card:FindFirstChild("Ribbon") :: Frame):FindFirstChild("Label") :: TextLabel).Text =
		Lineage.epithet(data.seat, data.address, data.master.epithet)

	local side = content:FindFirstChild("Side") :: Frame
	local teachers = side:FindFirstChild("Teachers") :: Frame
	Ui.clearRows(teachers)
	for i, t in data.teachers do
		local row = Ui.clone("Teacher") :: Frame
		row.Name = "Row"
		row.LayoutOrder = i;
		(row:FindFirstChild("TeacherName") :: TextLabel).Text = t.name;
		(row:FindFirstChild("Since") :: TextLabel).Text = t.since
		row.Parent = teachers
	end
	(side:FindFirstChild("None") :: TextLabel).Visible = #data.teachers == 0
	local filled = 0
	for _, s in data.court.seats do
		if s.name then
			filled += 1
		end
	end
	(side:FindFirstChild("Court") :: TextLabel).Text = `{data.court.name} · {filled} / 9 seats`

	local fan = content:FindFirstChild("Fan") :: Frame
	Ui.clearRows(fan)
	for i = 1, 9 do
		local s = data.court.seats[i] or {}
		local plate = Ui.clone("SeatPlate") :: Frame
		plate.Name = "Row"
		plate.Position = fanPosition(i);
		(plate:FindFirstChild("Num") :: TextLabel).Text = tostring(i)
		local name = plate:FindFirstChild("SeatName") :: TextLabel
		name.Text = s.name or "—"
		name.TextColor3 = if s.you then JADE elseif s.name then CREAM else MUTED
		plate.Parent = fan
	end
	if not w.Visible then
		Ui.open(w)
	end
end

function Lineage.close()
	Ui.close(window())
end

local bowConn: RBXScriptConnection? = nil
local declined: (() -> ())? = nil
local bowed = false

local function ceremonyFrame(): Frame
	return Ui.window("Ceremony", function()
		if not bowed and declined then
			declined()
		end
		declined = nil
	end)
end

function Lineage.ceremony(c: Ceremony)
	local frame = ceremonyFrame()
	bowed = false
	declined = c.onDecline;
	-- portraits sit in round CanvasGroups so the silhouette's square foot is clipped to the medallion
	((frame:FindFirstChild("MasterMedallion") :: CanvasGroup):FindFirstChild("Portrait") :: ImageLabel).Image =
		portraitId(c.master.portrait);
	((frame:FindFirstChild("DiscipleMedallion") :: CanvasGroup):FindFirstChild("Portrait") :: ImageLabel).Image =
		portraitId(c.disciple.portrait);
	(frame:FindFirstChild("MasterName") :: TextLabel).Text = `The {c.master.epithet}`;
	(frame:FindFirstChild("DiscipleName") :: TextLabel).Text = c.disciple.name
	local middle = frame:FindFirstChild("Middle") :: Frame;
	(middle:FindFirstChild("Line") :: TextLabel).Text =
		`{c.disciple.name} bows to the {c.master.epithet}\nand takes the {string.lower(ORDINALS[c.seat] or "")} seat.`;
	((middle:FindFirstChild("Ribbon") :: Frame):FindFirstChild("Label") :: TextLabel).Text =
		Lineage.epithet(c.seat, c.address, c.master.epithet)
	local bow = middle:FindFirstChild("Bow") :: GuiButton
	if bowConn then
		bowConn:Disconnect()
	end
	bowConn = bow.Activated:Connect(function()
		bowed = true
		c.onBow()
		Ui.close(frame)
	end)
	if not frame.Visible then
		Ui.open(frame)
	end
	-- the ribbon settles in a beat after the card
	local ribbon = middle:FindFirstChild("Ribbon") :: Frame
	ribbon.Size = UDim2.fromOffset(120, 28)
	task.delay(0.15, function()
		Motion.tween(ribbon, { Size = UDim2.fromOffset(250, 28) }, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
	end)
end

local SAMPLE_MASTER: Master = {
	epithet = "Turtle Saint",
	title = "Peak Lord of Black Tortoise Peak",
	teaches = "shield arts · earth",
	portrait = "elder_qingyun",
}

function Lineage.preview()
	Lineage.open({
		master = SAMPLE_MASTER,
		seat = 2,
		address = "Brother",
		court = {
			name = "First Court",
			seats = {
				{ name = "Bai Feng" },
				{ name = "Lin Yue", you = true },
				{ name = "Wen Shu" },
				{ name = "Zhao Ming" },
				{ name = "Qiu Lan" },
				{ name = "He Yun" },
				{ name = "Song Li" },
				{},
				{},
			},
		},
		teachers = { { name = "The Crane Sage", since = "since Foundation 1" } },
	})
end

function Lineage.previewCeremony()
	Lineage.ceremony({
		master = SAMPLE_MASTER,
		disciple = { name = "Lin Yue" },
		seat = 2,
		address = "Sister",
		onBow = function()
			print("Lineage.previewCeremony: bow")
		end,
		onDecline = function()
			print("Lineage.previewCeremony: declined")
		end,
	})
end

return Lineage
