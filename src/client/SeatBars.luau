--!strict
-- The seated cultivation view (Hud.Stack.SeatBars, art seat_mount.png): while
-- meditating it takes the vitals' place (Menus.setSeated), so the progress toward
-- the next breakthrough lives in the meditation view, not on the fighting HUD.
--   TitleCrest      the realm (Realm), on the same crest the vitals wear
--   CultivationBar  Cultivation / CultivationMax: the track up to the breakthrough
--                   mark (80% along, drawn in seat_mount.png)
--   OverflowBar     the same track past the mark: cultivation beyond the bar, up to
--                   CultivationCap (the server lets it run past and carries a share
--                   into the next stage), in a paler gold
--   DantianBar      raw qi in the dantian (RawQi / DantianCap), refined by Circulate
-- The cultivation line reads the numbers, or why a full bar can't break through yet
-- (BreakthroughBlock). Every attribute defaults to 0 / "" until the server sets it.

local Players = game:GetService("Players")

local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer

local READY = Color3.fromRGB(255, 226, 140)
local LIGHT = Color3.fromRGB(236, 242, 236)
local BLOCKED = Color3.fromRGB(255, 170, 140)
-- what stops a full bar (Cultivation.luau BreakthroughBlock; "bar" means not full)
local BLOCK_TEXT: { [string]: string } = {
	peak = "The peak of this path",
	method = "Your method can go no further",
}

local SeatBars = {}

local function num(name: string): number
	return tonumber(player:GetAttribute(name)) or 0
end

function SeatBars.init(gui: ScreenGui)
	local root = (gui:FindFirstChild("Stack") :: Instance):FindFirstChild("SeatBars") :: Frame
	local title = (root:FindFirstChild("TitleCrest") :: Instance):FindFirstChild("Title") :: TextLabel
	local cultivationBar = root:FindFirstChild("CultivationBar") :: Frame
	local overflowBar = root:FindFirstChild("OverflowBar") :: Frame
	local dantianBar = root:FindFirstChild("DantianBar") :: Frame
	local cultivationText = root:FindFirstChild("CultivationText") :: TextLabel
	local dantianText = root:FindFirstChild("DantianText") :: TextLabel

	local function show()
		title.Text = player:GetAttribute("Realm") or ""
		local value, max = num("Cultivation"), num("CultivationMax")
		local cap = math.max(num("CultivationCap"), max)
		local ready = player:GetAttribute("BreakthroughReady") == true
		local block = player:GetAttribute("BreakthroughBlock")
		local blockText = if typeof(block) == "string" then BLOCK_TEXT[block] else nil
		Hud.setBar(cultivationBar, math.max(0, value), max)
		Hud.setBar(overflowBar, math.max(0, value - max), cap - max)
		local numbers = `{math.floor(value)} / {math.floor(max)}`
		if ready then
			cultivationText.Text = `Ready to break through · {numbers}`
			cultivationText.TextColor3 = READY
		elseif blockText and max > 0 and value >= max then
			cultivationText.Text = `{blockText} · {numbers}`
			cultivationText.TextColor3 = BLOCKED
		else
			cultivationText.Text = if max > 0 then `Cultivation {numbers}` else ""
			cultivationText.TextColor3 = LIGHT
		end
		local raw, room = num("RawQi"), num("DantianCap")
		Hud.setBar(dantianBar, raw, room, dantianText, if room > 0 then `Dantian {math.floor(raw)} / {math.floor(room)}` else "")
	end
	for _, attr in { "Realm", "Cultivation", "CultivationMax", "CultivationCap", "BreakthroughReady", "BreakthroughBlock", "RawQi", "DantianCap" } do
		player:GetAttributeChangedSignal(attr):Connect(show)
	end
	show()
end

return SeatBars
