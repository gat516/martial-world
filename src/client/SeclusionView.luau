--!strict
-- The secluded state on screen (docs/systems/seclusion.md, docs/ui/cultivation.md
-- "Seclusion"): Cultivation Canvas.Seclusion, a slim lacquer plaque under the top
-- bar while the player is secluded. The timer is the hero; beside it what has
-- gathered so far (stones; finds and the garden once there are any: "Tended", or
-- the number of plants that took a mutation); under it the
-- streak's day pips and "Rise to leave". Hidden while a window is open or the calm
-- view is on. Reads the player attributes Seclusion.luau publishes:
--   Secluded, SeclusionSince (os.time), SeclusionStones, SeclusionFinds,
--   SeclusionTended, SeclusionMutations, SeclusionStreak (days held before this
--   seclusion counts), SeclusionToday (today already counts).
-- SeclusionView.paintStreak is shared with the seclusion card (Rewards.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pacing = require(ReplicatedStorage.Shared.Pacing)
local CultivationGui = require(script.Parent.CultivationGui)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)

local player = Players.LocalPlayer

local GEM_JADE = "rbxassetid://139500197356694"
local GEM_GREY = "rbxassetid://82455700461918"
local JADE = Color3.fromRGB(130, 230, 185)
local DIM = Color3.fromRGB(215, 205, 180)
local PIPS = 7
local PENDING = 0.55 -- today's pip before the hour that keeps the streak
local EMPTY = 0.35

local SeclusionView = {}

-- Fill a Streak row (Pips.Pip1..7, Label): `days` lit, an optional pending pip after
-- them, the label as given.
function SeclusionView.paintStreak(streak: Instance, days: number, pending: boolean, label: string, labelColor: Color3?)
	local pips = streak:FindFirstChild("Pips") :: Frame
	for k = 1, PIPS do
		local pip = pips:FindFirstChild(`Pip{k}`) :: ImageLabel
		local lit = k <= days
		local wait = pending and k == days + 1
		pip.Image = if lit or wait then GEM_JADE else GEM_GREY
		pip.ImageTransparency = if lit then 0 elseif wait then PENDING else EMPTY
	end
	local text = streak:FindFirstChild("Label") :: TextLabel
	text.Text = label
	text.TextColor3 = labelColor or JADE
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, seconds // 60 % 60, seconds % 60
	return if h > 0 then string.format("%d:%02d:%02d", h, m, s) else string.format("%d:%02d", m, s)
end

function SeclusionView.init()
	local root = CultivationGui.piece("Seclusion")
	local time = root:FindFirstChild("Time", true) :: TextLabel
	local stones = (root:FindFirstChild("Stones", true) :: Frame):FindFirstChild("Count") :: TextLabel
	local finds = root:FindFirstChild("Finds", true) :: Frame
	local garden = root:FindFirstChild("Garden", true) :: Frame
	local streak = root:FindFirstChild("Streak", true) :: Frame
	root.Visible = false
	local minSeconds = Pacing.Seclusion.STREAK_MIN_HOURS * 3600

	local function paint()
		local since = player:GetAttribute("SeclusionSince")
		local elapsed = if type(since) == "number" and since > 0 then workspace:GetServerTimeNow() - since else 0
		time.Text = clock(elapsed)
		stones.Text = tostring(player:GetAttribute("SeclusionStones") or 0)
		local found = player:GetAttribute("SeclusionFinds") or 0
		finds.Visible = found > 0;
		(finds:FindFirstChild("Count") :: TextLabel).Text = tostring(found)
		local mutations = player:GetAttribute("SeclusionMutations") or 0
		garden.Visible = mutations > 0 or player:GetAttribute("SeclusionTended") == true;
		(garden:FindFirstChild("Count") :: TextLabel).Text = if mutations > 0 then tostring(mutations) else "Tended"
		local held = math.min(player:GetAttribute("SeclusionStreak") or 0, PIPS)
		if player:GetAttribute("SeclusionToday") == true then
			SeclusionView.paintStreak(streak, held, false, `Day {held}`)
		elseif elapsed >= minSeconds then
			SeclusionView.paintStreak(streak, math.min(held + 1, PIPS), false, `Day {held + 1}`)
		else
			local left = math.ceil((minSeconds - elapsed) / 60)
			SeclusionView.paintStreak(streak, held, true, `Day {held + 1}  ·  {left}m left`, DIM)
		end
	end

	local function refresh()
		local show = player:GetAttribute("Secluded") == true and not Menus.isOpen() and not Menus.isCalm()
		if show then
			paint()
		end
		if show ~= root.Visible then
			Motion.setShown(root, show, true)
		end
	end

	for _, name in { "Secluded", "SeclusionStones", "SeclusionFinds", "SeclusionTended", "SeclusionMutations", "SeclusionStreak", "SeclusionToday" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	Menus.onChanged(function()
		task.defer(refresh)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if root.Visible then
				paint()
			end
			refresh() -- also catches the calm view turning on or off
		end
	end)
	refresh()
end

return SeclusionView
