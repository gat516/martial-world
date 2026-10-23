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

-- C1 mutation tags: three-part ribbons with cloud ends (Ribbon.STYLES tag_<colour>,
-- fitted to their text by Ribbon.fit; the ornate ends never stretch).
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
	{ image = "rbxassetid://118421304712620", numeral = "I", face = Vector2.new(0.5, 0.45) },
	{ image = "rbxassetid://120306832740653", numeral = "II", face = Vector2.new(0.5, 0.45) },
	{ image = "rbxassetid://112312489278714", numeral = "III", face = Vector2.new(0.5, 0.45) },
	{ image = "rbxassetid://126064220173046", numeral = "IV", face = Vector2.new(0.5, 0.47) },
	{ image = "rbxassetid://88138698814874", numeral = "V", face = Vector2.new(0.5, 0.47) },
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

-- The Ribbon style of a mutation's tag.
function HerbArt.tagStyle(mutation: string): string
	return "tag_" .. (HerbArt.MutationTag[mutation] or "bronze")
end

return HerbArt
