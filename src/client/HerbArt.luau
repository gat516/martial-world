--!strict
-- The garden's shared kit art (docs/ui/herbarium.md, "Art"): a herb drawn in a
-- kit item slot (its icon, or its glyph when it has none), the rarity gems
-- (through Rarity), the mutation tag ribbons and the herb tier badges. Every id
-- here is a cut from the Codex sheets B2 and C1 (art/ui/assets.json,
-- codex/cut/ornament_*).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Items = require(ReplicatedStorage.Shared.Items)
local Rarity = require(script.Parent.Rarity)

local HerbArt = {}

local WHITE = Color3.new(1, 1, 1)

-- Rarity gems come from the Inventory's ladder (Rarity.luau): Common bronze,
-- Uncommon silver, Rare jade, Epic violet, Legendary gold.

-- C1 mutation tags (ribbons with cloud ends). Slice: plain plate between
-- columns 89 and 281 of the 378x101 source.
HerbArt.Tags = {
	bronze = "rbxassetid://98060115715507",
	jade = "rbxassetid://101467676951805",
	crimson = "rbxassetid://111308532546306",
	violet = "rbxassetid://119756378140078",
	gold = "rbxassetid://100335366464739",
}
HerbArt.TAG_SLICE = Rect.new(96, 30, 276, 70)
HerbArt.TAG_HEIGHT = 101

-- A mutation's ribbon follows how much it's worth (Herbs.Mutations bonus):
-- the common weather marks are bronze, the rarest violet. Golden keeps gold.
HerbArt.MutationTag = {
	Windswept = "bronze",
	Dewy = "bronze",
	Auspicious = "jade",
	Thunderstruck = "crimson",
	Golden = "gold",
	Rainbow = "violet",
	Heavenlit = "violet",
} :: { [string]: string }

-- C1 tier badges I-V (bronze, silver, gold, jade, violet), shields with a navy
-- face. face: the face's centre and size as fractions of the image, for a numeral.
HerbArt.Tiers = {
	{ image = "rbxassetid://114223152322030", numeral = "I", face = Vector2.new(0.5, 0.45) },
	{ image = "rbxassetid://120192426371125", numeral = "II", face = Vector2.new(0.5, 0.45) },
	{ image = "rbxassetid://77064457614084", numeral = "III", face = Vector2.new(0.5, 0.45) },
	{ image = "rbxassetid://116072136932136", numeral = "IV", face = Vector2.new(0.5, 0.47) },
	{ image = "rbxassetid://94068302846931", numeral = "V", face = Vector2.new(0.5, 0.47) },
}

-- Draw a herb (or any item) in a Swatch: an item-slot ImageLabel with an Icon
-- (ImageLabel) and a Glyph (TextLabel) child. Herbs without an icon show their
-- glyph in the herb's colour.
function HerbArt.paint(swatch: Instance, id: string)
	local item = Items.Defs[id]
	local herb = Herbs.Defs[id]
	local icon = swatch:FindFirstChild("Icon") :: ImageLabel?
	local glyph = swatch:FindFirstChild("Glyph") :: TextLabel?
	local image = if item and item.icon then item.icon else ""
	if icon then
		icon.Image = image
		icon.Visible = image ~= ""
	end
	if glyph then
		glyph.Text = if item then item.glyph else ""
		glyph.TextColor3 = if herb then herb.color else WHITE
		glyph.Visible = image == ""
	end
end

-- Set a gem ImageLabel to a rarity ("Common".."Legendary").
function HerbArt.gem(image: ImageLabel, rarity: string)
	local r = Items.Rarities[rarity] or Items.Rarities.Common
	Rarity.gem(image, r.order)
end

-- The ribbon image for a mutation id (Herbs.Mutations key).
function HerbArt.tagFor(mutation: string): string
	return HerbArt.Tags[HerbArt.MutationTag[mutation] or "bronze"]
end

return HerbArt
