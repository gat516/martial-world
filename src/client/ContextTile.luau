--!strict
-- The contextual tile (Hud.Buttons.ContextButton): one slot in the top-right row for
-- whatever the place offers (user-approved four-tile row, 2026-10-24: Inventory,
-- Cultivate, Self and this). Build on (or over) your own peak, Travel standing on a
-- teleport array or anywhere in the sect; hidden everywhere else. One slot, never
-- two tiles: when both apply, the higher rank wins (an array under your feet beats
-- your peak, your peak beats the sect at large), and the onboarding guide can ask
-- for one (`prefer`, its Travel beat starts on your own peak).
-- Providers (BuildMode, TravelMenu) say what they offer and when:
--   ContextTile.offer(key, activate)   once, at init
--   ContextTile.set(key, rank)         rank > 0 offers it, 0 withdraws it
--   ContextTile.prefer(key?)           the guide's pick while it points at it
-- The tile swaps its icon and caption to the winner and pops in when it appears or
-- swaps. Looks: the Build hammer and Travel gate glyphs the separate tiles wore, on
-- the same lacquer frame as the fixed tiles (a plain swap, picked by the critic,
-- 2026-10-24, over a jade-tinted frame: the tint dulled the gilt rim to olive, read
-- as disabled and echoed Cultivate's jade; the changing glyph says enough).

local Motion = require(script.Parent.Motion)

local ContextTile = {}

-- ranks: the sect at large < your own peak < an array under your feet
ContextTile.RANK_SECT = 1
ContextTile.RANK_PEAK = 2
ContextTile.RANK_ARRAY = 3

type Look = { image: string, offset: Vector2, size: Vector2, color: Color3, caption: string }

-- the glyphs and tints the old Build and Travel tiles carried (cropped to their drawn area)
local LOOKS: { [string]: Look } = {
	Build = {
		image = "rbxassetid://125043885705391",
		offset = Vector2.new(55, 24),
		size = Vector2.new(168, 185),
		color = Color3.new(0.92549, 0.94902, 0.92549),
		caption = "Build",
	},
	Travel = {
		image = "rbxassetid://136931524828358",
		offset = Vector2.new(0, 23),
		size = Vector2.new(256, 216),
		color = Color3.new(0.745098, 0.823529, 1),
		caption = "Travel",
	},
}

local button: GuiButton? = nil
local actions: { [string]: () -> () } = {}
local ranks: { [string]: number } = {}
local preferred: string? = nil
local shown: string? = nil

local function winner(): string?
	if preferred and (ranks[preferred] or 0) > 0 then
		return preferred
	end
	local best, bestRank = nil, 0
	for key, rank in ranks do
		if rank > bestRank then
			best, bestRank = key, rank
		end
	end
	return best
end

local function refresh()
	local tile = button
	if not tile then
		return
	end
	local key = winner()
	if key == shown then
		return
	end
	shown = key
	if key then
		local look = LOOKS[key]
		local icon = tile:FindFirstChild("Icon") :: ImageLabel
		icon.Image = look.image
		icon.ImageRectOffset = look.offset
		icon.ImageRectSize = look.size
		icon.ImageColor3 = look.color;
		(tile:FindFirstChild("Caption") :: TextLabel).Text = look.caption
		if tile.Visible then
			Motion.tap(tile) -- a swap in place (Travel to Build): a small dip and spring
		end
	end
	tile.Visible = key ~= nil
end

function ContextTile.init(gui: ScreenGui)
	local tile = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("ContextButton") :: GuiButton
	button = tile
	tile.Visible = false
	Motion.appear(tile)
	tile.Activated:Connect(function()
		local act = shown and actions[shown]
		if act then
			act()
		end
	end)
	refresh()
end

function ContextTile.offer(key: string, activate: () -> ())
	actions[key] = activate
end

function ContextTile.set(key: string, rank: number)
	if (ranks[key] or 0) ~= rank then
		ranks[key] = rank
		refresh()
	end
end

function ContextTile.prefer(key: string?)
	if preferred ~= key then
		preferred = key
		refresh()
	end
end

-- What the tile offers now ("Build", "Travel" or nil).
function ContextTile.current(): string?
	return shown
end

return ContextTile
