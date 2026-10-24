--!strict
-- One menu at a time. Every window (inventory, travel, seed picker, quest board,
-- build bar) and the circulation minigame registers here. Opening one closes
-- whichever was open; each closes by its own seal (the tiles that open them fade
-- away meanwhile).
-- A frame becoming visible by any route counts as opening it, so scripts may
-- still set Visible directly; Menus.open/close/toggle are the preferred path.
--
-- What shows while something is open (one rule, applied here):
--   Always: toasts, banners, the window itself.
--   A window: the top-right tiles fade away on every device (user decision,
--     2026-10-21: they poked out over the panels); every window closes by its
--     own seal, and the tiles come back when the last one closes. The gameplay
--     HUD goes too (Play: touch
--     cluster, buffs, objective, elder line; the vitals; the Dash and Strike
--     cooldown chips; the seated tiles; world prompts). The
--     hotbar stays only for windows that drop onto it (the inventory).
--   A minigame: everything but the minigame, tiles included.
--   Seated (Menus.setSeated, from Meditation): the cultivation bars
--     (Stack.SeatBars) take the vitals' place; health, qi and guard come back
--     on standing.
--   The calm view (Menus.setCalm, while meditating; nothing open): the gameplay
--     HUD, the tiles and the hotbar fade away for a clean view of the world.
--     Opening anything ends it.
-- Short screens (Platform.isSmall: phones, the device emulator): Roblox's menu
-- and chat buttons own the top-left corner, so a centred Hud window that would
-- reach above TOPBAR_CLEAR opens just below it instead, shorter if it has to be
-- (phone sweep, 2026-10-23: the herb shop, seed picker, quest board and Spirit
-- Market reached under the buttons). Windows that place themselves (Inventory,
-- the build catalog in build mode), auto-sized cards and canvas screens are left
-- alone.
-- Menus.openFrom(frame, back) opens a window from inside another (the Self card's
-- Settings and People seals, the Inventory's Herbarium tab): closing it by its own
-- seal runs `back`, which reopens the window it came from; being replaced by another
-- window drops it.

local ProximityPromptService = game:GetService("ProximityPromptService")

local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)

local Menus = {}

local TOPBAR_CLEAR = 62 -- Roblox's buttons end about 54 px down on a phone
local BOTTOM_GAP = 8
local homes: { [GuiObject]: { position: UDim2, size: UDim2 } } = {}

local function clearTopbar(frame: GuiObject)
	local parent = frame.Parent
	if not Platform.isSmall() or not (parent and parent:IsA("ScreenGui")) then
		return
	end
	if frame.AnchorPoint ~= Vector2.new(0.5, 0.5) and not homes[frame] then
		return -- it places itself
	end
	if frame.AutomaticSize ~= Enum.AutomaticSize.None then
		return
	end
	local home = homes[frame]
	if home then
		if frame.AnchorPoint ~= Vector2.new(0.5, 0.5) then
			return
		end
		frame.Position, frame.Size = home.position, home.size
	end
	local motion = frame:FindFirstChild("Motion")
	local k = if motion and motion:IsA("UIScale") and motion.Scale > 0 then motion.Scale else 1
	local origin = parent.AbsolutePosition.Y
	local height = frame.AbsoluteSize.Y / k
	local centre = frame.AbsolutePosition.Y + frame.AbsoluteSize.Y / 2 - origin
	if centre - height / 2 >= TOPBAR_CLEAR then
		return
	end
	if not home then
		homes[frame] = { position = frame.Position, size = frame.Size }
	end
	local fit = math.min(height, parent.AbsoluteSize.Y - TOPBAR_CLEAR - BOTTOM_GAP)
	if fit < height then
		frame.Size = UDim2.new(frame.Size.X, UDim.new(0, math.floor(fit)))
	end
	frame.Position = UDim2.new(frame.Position.X, UDim.new(0, math.floor(TOPBAR_CLEAR + fit / 2)))
end

export type Options = {
	close: (() -> ())?, -- how to close it (default: hide the frame)
	keepHotbar: boolean?, -- leave the hotbar up as a drop target
	minigame: boolean?, -- takes the whole screen (nothing opens over it)
}

local entries: { [GuiObject]: Options } = {}
local current: GuiObject? = nil
local calm = false
local seated = false
local screen = false
local listeners: { () -> () } = {}
local backs: { [GuiObject]: () -> () } = {} -- Menus.openFrom: what a close by its own seal reopens

local play: GuiObject
local vitals: GuiObject
local seatBars: GuiObject
local hotbar: GuiObject
local tiles: GuiObject
local chips: GuiObject -- PC only: Dash and Strike cooldown chips over the hotbar

local function update(fade: boolean?)
	local entry = current and entries[current]
	local any = entry ~= nil
	if any then
		calm = false
	end
	local function show(obj: GuiObject, shown: boolean)
		Motion.setShown(obj, shown and not calm, fade)
	end
	show(play, not any)
	show(vitals, not any and not seated)
	show(seatBars, not any and seated)
	show(hotbar, not any or (entry :: Options).keepHotbar == true)
	show(chips, not any and not Platform.isTouch())
	-- the top-right tiles always fade (they're what the player just pressed)
	Motion.setShown(tiles, not any and not calm, true)
	ProximityPromptService.Enabled = not any
	for _, fn in listeners do
		task.spawn(fn)
	end
end

local function closeFrame(frame: GuiObject)
	local entry = entries[frame]
	if entry and entry.close then
		entry.close()
	else
		Motion.close(frame)
	end
end

function Menus.register(frame: GuiObject, options: Options?)
	entries[frame] = options or {}
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			if current == frame then
				return
			end
			local previous = current
			if previous and entries[previous].minigame and not entries[frame].minigame then
				frame.Visible = false -- nothing opens over a minigame
				return
			end
			current = frame
			if not entries[frame].minigame then
				clearTopbar(frame)
			end
			Motion.popWindow(frame)
			if previous then
				closeFrame(previous)
			end
			update()
		elseif current == frame then
			current = nil
			local back = backs[frame]
			backs[frame] = nil
			update()
			if back then
				task.defer(back)
			end
		else
			backs[frame] = nil -- replaced by another window: no way back
		end
	end)
	if frame.Visible then
		current = frame
		update()
	end
end

function Menus.open(frame: GuiObject)
	backs[frame] = nil
	Motion.open(frame)
end

-- Open frame from inside another window; closing it by its own seal runs back.
function Menus.openFrom(frame: GuiObject, back: () -> ())
	Menus.open(frame)
	backs[frame] = back
end

function Menus.close(frame: GuiObject)
	if frame.Visible then
		closeFrame(frame)
	end
end

function Menus.toggle(frame: GuiObject)
	if frame.Visible then
		Menus.close(frame)
	else
		Menus.open(frame)
	end
end

-- Whether a menu is open (that one, or any when no frame is given). A full
-- screen (Menus.setScreen) counts as open too, so combat and prompts stay shut.
function Menus.isOpen(frame: GuiObject?): boolean
	if frame then
		return current == frame
	end
	return current ~= nil or screen
end

-- A full screen over the game, such as the character screen: it has its own
-- GUI and hides the Hud itself, so this only makes Menus.isOpen() true.
function Menus.setScreen(on: boolean)
	screen = on
end

-- The open menu, if any.
function Menus.current(): GuiObject?
	return current
end

-- The calm view: fade the HUD away (or bring it back). Ignored while a menu is open.
function Menus.setCalm(on: boolean)
	if on and current then
		return
	end
	if on ~= calm then
		calm = on
		update(true)
	end
end

function Menus.isCalm(): boolean
	return calm
end

-- Seated in meditation: the cultivation bars stand in for the vitals.
function Menus.setSeated(on: boolean)
	if on ~= seated then
		seated = on
		update(true)
	end
end

-- Called whenever what's open changes (or the calm view starts or ends).
function Menus.onChanged(fn: () -> ())
	table.insert(listeners, fn)
end

function Menus.init(gui: ScreenGui)
	local stack = gui:FindFirstChild("Stack") :: Frame
	play = gui:FindFirstChild("Play") :: Frame
	vitals = stack:FindFirstChild("Vitals") :: Frame
	seatBars = stack:FindFirstChild("SeatBars") :: Frame
	hotbar = stack:FindFirstChild("Hotbar") :: Frame
	tiles = gui:FindFirstChild("Buttons") :: Frame
	chips = stack:FindFirstChild("Cooldowns") :: Frame
	update()
end

return Menus
