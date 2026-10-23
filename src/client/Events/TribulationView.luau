--!strict
-- The heavenly tribulation on screen (server: Tribulation.luau; sky and bolts:
-- WorldFX/TribulationFX). CombatController forwards the Effect events:
--   "tribulationStart" (player, center, strikes) -> TribulationView.start(player, strikes)
--   "bolt" (ground)                              -> TribulationView.strike()
--   "tribulationEnd" (player, survived)          -> TribulationView.finish(player, survived)
-- The challenger gets the Heaven's Decree card (how many strikes to endure),
-- then a small ring under the top centre counting the strikes left; each bolt
-- ticks it down with one short pop and spark, never a loop, and the screen is
-- never darkened. Everyone else gets the tribulation ribbon for a moment ("The
-- heavens descend on X"), unless a menu is open. At the end the challenger's
-- counter goes and the ribbon says how it went (the server's toasts carry the rest).
-- docs/ui/world-events.md, "Tribulation".

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Menus = require(script.Parent.Parent.Menus)
local Gui = require(script.Parent.Gui)

local player = Players.LocalPlayer

local DECREE_HOLD = 2.6 -- seconds the decree card stays up (high, off the character: bolts start at once)
local RIBBON_HOLD = 3.4
local LAST_FEW = 3 -- the count turns gold for the last strikes
local GOLD = Color3.fromRGB(236, 196, 104)
local CREAM = Color3.fromRGB(250, 236, 195)
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FLASH = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GLINT = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local TribulationView = {}

local active = false
local left: number? = nil
local decree: GuiObject? = nil
local counter: Frame? = nil

-- The ribbon through the herald queue.
local function ribbon(message: string, hold: number?)
	Gui.herald(function()
		local r = Gui.place("Ribbon", "Ribbon") :: Frame;
		(r:FindFirstChild("Label") :: TextLabel).Text = message
		r.Position = UDim2.fromOffset(0, -10)
		Gui.fadeIn(r)
		TweenService:Create(r, POP, { Position = UDim2.fromOffset(0, 0) }):Play()
		task.wait(hold or RIBBON_HOLD)
		Gui.fadeOut(r, function()
			r:Destroy()
		end)
		task.wait(0.2)
	end)
end

local function setCount(n: number, pop: boolean)
	local c = counter
	if not c then
		return
	end
	local ring = c:FindFirstChild("Ring") :: ImageLabel
	local count = ring:FindFirstChild("Count") :: TextLabel
	count.Text = tostring(math.max(0, n))
	count.TextColor3 = if n <= LAST_FEW then GOLD else CREAM
	if pop then
		local scale = c:FindFirstChild("Motion") :: UIScale
		scale.Scale = 1.14
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
		local flash = ring:FindFirstChild("Flash") :: ImageLabel
		flash.ImageTransparency = 0.35
		TweenService:Create(flash, FLASH, { ImageTransparency = 1 }):Play()
	end
end

local function showDecree(strikes: number?)
	local card = Gui.place("Decree", "Decree") :: ImageLabel
	decree = card
	local count = card:FindFirstChild("Count") :: TextLabel
	local unit = card:FindFirstChild("Unit") :: TextLabel
	if strikes then
		count.Text = tostring(strikes)
	else
		count.Text = "雷"
		unit.Text = "heavenly lightning gathers"
	end
	if Gui.isPhone() then
		-- the small card keeps the title and the count; the lines under them won't fit legibly
		for _, name in { "Kicker", "Body", "Footer" } do
			(card:FindFirstChild(name) :: TextLabel).Visible = false
		end
	end
	Gui.fadeIn(card)
	-- one gold glint across the top edge as it lands
	local glint = card:FindFirstChild("Glint") :: ImageLabel
	glint.Position = UDim2.fromScale(0.3, 0.111)
	glint.ImageTransparency = 0.15
	TweenService:Create(glint, GLINT, { Position = UDim2.fromScale(0.7, 0.111), ImageTransparency = 1 }):Play()
	task.delay(DECREE_HOLD, function()
		if decree == card then
			decree = nil
		end
		Gui.fadeOut(card, function()
			card:Destroy()
		end)
	end)
end

local function showCounter(strikes: number)
	if counter then
		counter:Destroy()
	end
	local c = Gui.place("StrikeCounter", "Counter") :: Frame
	counter = c
	setCount(strikes, false)
	Gui.fadeIn(c)
end

local function hideCounter()
	local c = counter
	counter = nil
	if c then
		Gui.fadeOut(c, function()
			c:Destroy()
		end)
	end
end

-- A tribulation began (every client hears it). strikes: how many bolts the
-- server will throw (nil from an older server: the decree shows no count and
-- the counter stays hidden).
function TribulationView.start(challenger: Player, strikes: number?)
	Gui.init()
	if challenger ~= player then
		if not Menus.isOpen() then
			ribbon(`The heavens descend on {challenger.DisplayName}`)
		end
		return
	end
	active = true
	left = strikes
	showDecree(strikes)
	if strikes then
		task.delay(DECREE_HOLD * 0.8, function()
			if active then
				showCounter(left or strikes)
			end
		end)
	end
end

-- A bolt landed (every client hears every bolt; only the challenger counts).
function TribulationView.strike()
	if not (active and left) then
		return
	end
	left = math.max(0, (left :: number) - 1)
	setCount(left :: number, true)
end

function TribulationView.finish(challenger: Player, survived: boolean)
	if challenger ~= player then
		return
	end
	active = false
	left = nil
	hideCounter()
	ribbon(if survived then "The heavens relent. You endured." else "The lightning overwhelmed you", 2.8)
end

-- Sample content in play (client console):
--   require(game.Players.LocalPlayer.PlayerScripts.Client.Events.TribulationView).preview()
-- Plays a short local tribulation: the decree, a counter ticking down, the end
-- ribbon; and a spectator's ribbon first. Nothing is sent to the server.
function TribulationView.preview(strikes: number?)
	local n = strikes or 6
	local spectator = {
		DisplayName = "Wei Lan",
	} :: any
	TribulationView.start(spectator, n)
	TribulationView.start(player, n)
	task.spawn(function()
		task.wait(DECREE_HOLD + 0.5)
		for _ = 1, n do
			task.wait(0.8)
			TribulationView.strike()
		end
		task.wait(0.6)
		TribulationView.finish(player, true)
	end)
end

return TribulationView
