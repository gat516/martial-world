--!strict
-- One menu at a time. Every window (inventory, travel, seed picker, quest board,
-- build bar) and the circulation minigame registers here. Opening one closes
-- whichever was open; pressing a window's own tile again closes it.
-- A frame becoming visible by any route counts as opening it, so scripts may
-- still set Visible directly; Menus.open/close/toggle are the preferred path.
--
-- What shows while something is open (one rule, applied here):
--   Always: toasts, banners, the window itself.
--   A window: the top-right tiles stay on PC (to switch or close); on touch the
--     windows that fill the screen (inventory, Spirit Market, Herbalist) hide
--     them and close by their own seal. The gameplay HUD goes (Play: touch
--     cluster, buffs, objective, elder line; the vitals; the Dash and Strike
--     cooldown chips; the seated tiles; world prompts). The
--     hotbar stays only for windows that drop onto it (the inventory).
--   A minigame: everything but the minigame, tiles included.
--   The calm view (Menus.setCalm, while meditating; nothing open): the gameplay
--     HUD, the tiles and the hotbar fade away for a clean view of the world.
--     Opening anything ends it.

local ProximityPromptService = game:GetService("ProximityPromptService")

local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)

local Menus = {}

export type Options = {
	close: (() -> ())?, -- how to close it (default: hide the frame)
	keepHotbar: boolean?, -- leave the hotbar up as a drop target
	minigame: boolean?, -- takes the whole screen, tiles included
	coversTiles: boolean?, -- on touch it fills the screen, so the tiles hide
}

local entries: { [GuiObject]: Options } = {}
local current: GuiObject? = nil
local calm = false
local listeners: { () -> () } = {}

local play: GuiObject
local vitals: GuiObject
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
	show(vitals, not any)
	show(hotbar, not any or (entry :: Options).keepHotbar == true)
	show(chips, not any and not Platform.isTouch())
	show(tiles, not (entry and (entry.minigame or (entry.coversTiles and Platform.isTouch()))))
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
			Motion.popWindow(frame)
			if previous then
				closeFrame(previous)
			end
			update()
		elseif current == frame then
			current = nil
			update()
		end
	end)
	if frame.Visible then
		current = frame
		update()
	end
end

function Menus.open(frame: GuiObject)
	Motion.open(frame)
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

-- Whether a menu is open (that one, or any when no frame is given).
function Menus.isOpen(frame: GuiObject?): boolean
	if frame then
		return current == frame
	end
	return current ~= nil
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

-- Called whenever what's open changes (or the calm view starts or ends).
function Menus.onChanged(fn: () -> ())
	table.insert(listeners, fn)
end

function Menus.init(gui: ScreenGui)
	local stack = gui:FindFirstChild("Stack") :: Frame
	play = gui:FindFirstChild("Play") :: Frame
	vitals = stack:FindFirstChild("Vitals") :: Frame
	hotbar = stack:FindFirstChild("Hotbar") :: Frame
	tiles = gui:FindFirstChild("Buttons") :: Frame
	chips = stack:FindFirstChild("Cooldowns") :: Frame
	update()
end

return Menus
