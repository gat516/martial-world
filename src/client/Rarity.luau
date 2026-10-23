--!strict
-- The rarity ladder every item, weapon and art sits on, shown by its frame (the
-- UI kit's reward tiles) and, in the Inventory's detail pane, a gem and a label.
--   tier 1 bronze  Common item     Mortal weapon or art
--   tier 2 silver  Uncommon item
--   tier 3 jade    Rare item       Spirit weapon or art
--   tier 4 violet  Epic item       Earth weapon or art
--   tier 5 gold    Legendary item  Heaven weapon or art
-- Items.Rarities[*].order and Weapons.Grades[*].tier pick the tier; their colours
-- match the frames. Bare Fists have no grade: the plain kit slot.
-- Images: art/ui/assets.json (codex/cut/ornament_tile_*, ornament_gem_*).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

export type Tier = { tile: string, gem: string, gemColor: Color3 }

local GEM_GREY = "rbxassetid://108721805932431"
local WHITE = Color3.new(1, 1, 1)

local TIERS: { Tier } = {
	-- the kit has no bronze gem: the grey one, tinted
	{ tile = "rbxassetid://88319270048737", gem = GEM_GREY, gemColor = Color3.fromRGB(226, 170, 112) },
	{ tile = "rbxassetid://87507886886715", gem = GEM_GREY, gemColor = WHITE },
	{ tile = "rbxassetid://136998144393835", gem = "rbxassetid://121793265149448", gemColor = WHITE },
	{ tile = "rbxassetid://109769132951760", gem = "rbxassetid://80848783636466", gemColor = WHITE },
	{ tile = "rbxassetid://116953659868130", gem = "rbxassetid://113499507353464", gemColor = WHITE },
}
-- Bare Fists and anything ungraded: the plain kit slot (the hotbar's frame)
local PLAIN_SLOT = "rbxassetid://107221511179183"
local PLAIN_COLOR = Color3.fromRGB(236, 214, 180)

local Rarity = {}

Rarity.PLAIN_SLOT = PLAIN_SLOT

export type Info = { tier: number?, label: string, color: Color3 }

-- The tier, a plain label ("Rare", "Spirit grade") and its colour.
function Rarity.of(id: string?): Info
	local item = id and Items.Defs[id]
	if item then
		local rarity = Items.Rarities[item.rarity]
		return { tier = rarity and rarity.order, label = item.rarity, color = Items.rarityColor(item) }
	end
	local weapon = id and Weapons.Defs[id]
	local technique = id and Techniques.Defs[id]
	local gradeId = if weapon then weapon.grade elseif technique then (technique :: any).grade or "Mortal" else nil
	local grade = gradeId and Weapons.Grades[gradeId]
	if grade then
		return { tier = grade.tier, label = `{grade.name} grade`, color = grade.color }
	end
	return { tier = nil, label = "No grade", color = PLAIN_COLOR }
end

-- The order to sort by, best first (0 = ungraded).
function Rarity.rank(id: string?): number
	return Rarity.of(id).tier or 0
end

-- The frame image for a tier (nil: the plain slot).
function Rarity.tile(tier: number?): string
	local t = tier and TIERS[tier]
	return if t then t.tile else PLAIN_SLOT
end

-- Paint a gem ImageLabel for a tier; hides it for ungraded things.
function Rarity.gem(label: ImageLabel, tier: number?)
	local t = tier and TIERS[tier]
	label.Visible = t ~= nil
	if t then
		label.Image = t.gem
		label.ImageColor3 = t.gemColor
	end
end

return Rarity
