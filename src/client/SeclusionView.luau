--!strict
-- The secluded state on screen (docs/systems/seclusion.md, docs/ui/cultivation.md
-- "Seclusion"): Cultivation Canvas.Seclusion, a slim lacquer plaque under the top
-- bar while the player is secluded. The timer is the hero; beside it what has
-- gathered so far (finds and the garden once there are any: "Tended", or the number
-- of plants that took a mutation); under it the tempering line ("Tempering Qi
-- Condensation 5 · 2:41") and "Rise to leave". Hidden while a window is open or the
-- calm view is on. Reads the player attributes Seclusion.luau publishes:
--   Secluded, SeclusionSince (os.time), SeclusionTempering (stage name, "" none),
--   SeclusionTemperAt (os.time it settles), SeclusionTempered (stages mended),
--   SeclusionFinds, SeclusionTended, SeclusionMutations.
-- The plaque's Stones chip and the streak's pips are hidden (no trickle, no streak);
-- SeclusionView.paintStreak stays for Rewards.luau until the plaque is slimmed.

local Players = game:GetService("Players")

local CultivationGui = require(script.Parent.CultivationGui)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)

local player = Players.LocalPlayer

local GEM_JADE = "rbxassetid://139500197356694"
local GEM_GREY = "rbxassetid://82455700461918"
local JADE = Color3.fromRGB(130, 230, 185)
local DIM = Color3.fromRGB(215, 205, 180)
local PIPS = 7
local PENDING = 0.55 -- a pending pip
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
	local stones = root:FindFirstChild("Stones", true) :: Frame
	local finds = root:FindFirstChild("Finds", true) :: Frame
	local garden = root:FindFirstChild("Garden", true) :: Frame
	local streak = root:FindFirstChild("Streak", true) :: Frame
	root.Visible = false
	-- no stone trickle or streak since the 2026-10-24 rework: the stones chip hides and the
	-- streak row's label carries the tempering line (until the ui-designer's slim plaque)
	stones.Visible = false;
	(streak:FindFirstChild("Pips") :: Frame).Visible = false

	local function paint()
		local since = player:GetAttribute("SeclusionSince")
		local elapsed = if type(since) == "number" and since > 0 then workspace:GetServerTimeNow() - since else 0
		time.Text = clock(elapsed)
		local found = player:GetAttribute("SeclusionFinds") or 0
		finds.Visible = found > 0;
		(finds:FindFirstChild("Count") :: TextLabel).Text = tostring(found)
		local mutations = player:GetAttribute("SeclusionMutations") or 0
		garden.Visible = mutations > 0 or player:GetAttribute("SeclusionTended") == true;
		(garden:FindFirstChild("Count") :: TextLabel).Text = if mutations > 0 then tostring(mutations) else "Tended"
		local label = streak:FindFirstChild("Label") :: TextLabel
		local tempering = player:GetAttribute("SeclusionTempering")
		local tempered = player:GetAttribute("SeclusionTempered") or 0
		if type(tempering) == "string" and tempering ~= "" then
			local left = math.max(0, (player:GetAttribute("SeclusionTemperAt") or 0) - workspace:GetServerTimeNow())
			label.Text = `Tempering {tempering}  ·  {clock(left)}`
			label.TextColor3 = JADE
		elseif tempered > 0 then
			label.Text = if tempered == 1 then "An old foundation mended" else `{tempered} old foundations mended`
			label.TextColor3 = JADE
		else
			label.Text = "Absorb a herb or pill to temper"
			label.TextColor3 = DIM
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

	for _, name in { "Secluded", "SeclusionTempering", "SeclusionTempered", "SeclusionFinds", "SeclusionTended", "SeclusionMutations" } do
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
