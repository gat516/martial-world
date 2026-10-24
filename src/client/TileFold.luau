--!strict
-- The top-right tiles (Hud.Buttons) fold down to Inventory and Settings while the
-- player is in combat, so the boss bar can reach the top of the screen (user,
-- 2026-10-23: "during combat, we make those top right icons go away other than
-- some important ones"). Cultivate, Self, Build and Travel fold away; Travel is
-- refused while combat tagged anyway (server Travel).
-- The signal is the player attribute `InCombat` that server Combat publishes (hurt
-- or dealing damage within IN_COMBAT_SECONDS).
-- A fold shrinks the tile to a point: height to 0 and width to minus the list's
-- padding, which takes exactly the room the tile and its gap had (a tile at
-- -padding lays out like a hidden one), so the row re-flows smoothly with no pop at
-- the end. The height going to 0 (with ClipsDescendants) keeps the negative-width
-- tile from drawing anything. Visible stays with the
-- modules that own it (SelfCard, TravelMenu, Menus via Motion.setShown); this only
-- touches each tile's size, clipping and Interactable.
-- Build sits at the very left of the row (user 2026-10-23: "build just straight up
-- disappears ... reorder it at the very left so that it cleanly disappears"), then
-- Cultivate and Self, then the admin-only tile (it never folds, so it slides right
-- to Inventory as the others go), Inventory, Travel and Settings.
-- On a touch phone the realm plaque over the vitals (Stack.Vitals.Crest) fades away
-- for the fight too (user's pick, 2026-10-23: the vitals sat big over the
-- character), and comes back with the tiles.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)

local TileFold = {}

local FOLDS = { "CultivateButton", "SelfButton", "BuildButton", "TravelButton" }
local FOLD_OUT = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FOLD_IN = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Tile = { button: GuiButton, size: UDim2, tween: Tween? }

local tiles: { Tile } = {}
local crest: GuiObject? -- phone only
local gap = 0
local folded = false

local function apply(fold: boolean, animate: boolean)
	folded = fold
	if crest then
		Motion.setShown(crest, not fold, animate)
	end
	for _, tile in tiles do
		local button = tile.button
		if tile.tween then
			tile.tween:Cancel()
			tile.tween = nil
		end
		local target = if fold then UDim2.fromOffset(-gap, 0) else tile.size
		button.ClipsDescendants = true
		button.Interactable = not fold
		if animate and button.Visible then
			local tween = TweenService:Create(button, if fold then FOLD_OUT else FOLD_IN, { Size = target })
			tile.tween = tween
			tween.Completed:Once(function(state)
				if state == Enum.PlaybackState.Completed and not folded then
					button.ClipsDescendants = false -- badges may poke past the frame
				end
			end)
			tween:Play()
		else
			button.Size = target
			button.ClipsDescendants = fold
		end
	end
end

-- True while the tiles are folded down for combat.
function TileFold.folded(): boolean
	return folded
end

function TileFold.init(gui: ScreenGui)
	local row = gui:FindFirstChild("Buttons") :: Frame
	local layout = row:FindFirstChildWhichIsA("UIListLayout") :: UIListLayout
	gap = layout.Padding.Offset
	for _, name in FOLDS do
		local button = row:FindFirstChild(name) :: GuiButton?
		if button then
			table.insert(tiles, { button = button, size = button.Size })
		end
	end
	if Platform.isTouch() and Platform.isSmall() then
		local stack = gui:FindFirstChild("Stack")
		local vitals = stack and stack:FindFirstChild("Vitals")
		crest = vitals and vitals:FindFirstChild("Crest") :: GuiObject?
	end
	local player = Players.LocalPlayer
	local function sync(animate: boolean)
		local fight = player:GetAttribute("InCombat") == true
		if fight ~= folded then
			apply(fight, animate)
		end
	end
	player:GetAttributeChangedSignal("InCombat"):Connect(function()
		sync(true)
	end)
	sync(false)
end

return TileFold
