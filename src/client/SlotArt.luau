--!strict
-- Paints a slot (the hotbar's SlotTemplate and slots, the weapon slot, the drag ghost,
-- the Inventory's CellTemplate and Preview) for a technique, an item, a weapon (or
-- "Fist", bare hands), or nothing.
-- A slot is a plain ink well (Frame, art/ui/slot_plain.png) with its rarity in colour,
-- not ornament (user, 2026-10-23: the gold rarity tiles on every cell were "very very
-- tacky"): a thin tinted edge (Edge) and a faint wash rising from the bottom (Wash),
-- in the Rarity ladder's colour (bronze, silver, jade, violet, gold; ungraded and
-- empty slots get a dim neutral edge). On it:
--   items: their icon (or glyph), cropped to its drawn area and fitted in the slot's
--     Icon box (IconRects), so every icon centres with even padding;
--   arts: their glyph on a seal disc (Disc, art/ui/art_disc.png) in the art's colour;
--   weapons: the real model in the slot's Model ViewportFrame (WeaponView), or the
--     class glyph in the class colour where a slot has no viewport (and Bare Fists).
-- Also owns the weapon art (icons by model and by class, art/ui/assets.json), the
-- class glyphs and colours shared by art badges, the Inventory's class rail and
-- section headers, and the hotbar (classGlyph, classColor), and the weapon badge on
-- technique slots (gate).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local IconRects = require(script.Parent.IconRects)
local Rarity = require(script.Parent.Rarity)
local State = require(script.Parent.State)
local WeaponView = require(script.Parent.WeaponView)

local SlotArt = {}

local WHITE = Color3.new(1, 1, 1)
local GATED_ICON = 0.6 -- icon transparency of a hotbar art whose weapon isn't in hand
local NO_GRADE = Color3.fromRGB(150, 140, 120) -- the edge of ungraded things and empty slots
local EDGE_EMPTY = 0.55 -- edge transparency on an empty slot
local WASH = 0.35 -- the rarity wash's transparency (its art already fades to clear)
local DISC_DARK = 0.15 -- how far an art's disc tint leans to black
local ART_GLYPH = 0.55 -- how far an art's glyph leans to white on its disc
-- what fills the slot's Well (the icon box, authored per slot): items and models the
-- whole box (icons are cropped to their drawn area), an art's glyph the middle of
-- its disc, a class glyph a little less than the box
-- IconRects keeps a clear margin of 6% of the art each side (so a shrunk icon's
-- tips aren't cut flat by the quad's edge): the boxes grow by it, the art keeps its size
local RECT_MARGIN = 1.12
local FILL_ITEM = 1 * RECT_MARGIN
local FILL_ART = 0.6 * RECT_MARGIN
local FILL_GLYPH = 0.86 * RECT_MARGIN

-- art/ui/draw_icons.py; a weapon def's own icon wins over its model's
local MODEL_ICONS: { [string]: string } = {
	Jian = "rbxassetid://86085933890312",
	Dadao = "rbxassetid://124212742751085",
	Greatsword = "rbxassetid://139993149675749",
	Guandao = "rbxassetid://91007493859855",
	Spear = "rbxassetid://71808674278003",
	Staff = "rbxassetid://86834637733687",
}
local CLASS_ICONS: { [string]: string } = {
	Fist = "rbxassetid://83664160831695",
	Sword = MODEL_ICONS.Jian,
	Saber = MODEL_ICONS.Dadao,
	Greatsword = MODEL_ICONS.Greatsword,
	Guandao = MODEL_ICONS.Guandao,
	Spear = MODEL_ICONS.Spear,
	Staff = MODEL_ICONS.Staff,
}
-- White class glyphs (art/ui/glyphs, draw_class_glyphs.py), tinted by CLASS_COLORS
local CLASS_GLYPHS: { [string]: string } = {
	Fist = "rbxassetid://121264210892533",
	Sword = "rbxassetid://92216583348567",
	Saber = "rbxassetid://92852547529431",
	Greatsword = "rbxassetid://134500316582683",
	Guandao = "rbxassetid://98474731700076",
	Spear = "rbxassetid://126263695149867",
	Staff = "rbxassetid://118649402299519",
}
local CLASS_COLORS: { [string]: Color3 } = {
	Fist = Color3.fromRGB(240, 214, 176),
	Sword = Color3.fromRGB(120, 190, 255),
	Saber = Color3.fromRGB(250, 112, 96),
	Greatsword = Color3.fromRGB(250, 160, 70),
	Guandao = Color3.fromRGB(80, 220, 196),
	Spear = Color3.fromRGB(244, 132, 206),
	Staff = Color3.fromRGB(176, 222, 96),
	Any = Color3.fromRGB(222, 214, 196), -- universal arts
}
local FIST_NAME = "Bare Fists"
local FIST_COLOR = Color3.fromRGB(236, 196, 156)

function SlotArt.classIcon(classId: string): string
	local class = Weapons.Classes[classId]
	return (class and class.icon) or CLASS_ICONS[classId] or ""
end

-- The white glyph of a weapon class ("" for universal arts); tint it with classColor.
function SlotArt.classGlyph(classId: string): string
	return CLASS_GLYPHS[classId] or ""
end

function SlotArt.classColor(classId: string): Color3
	return CLASS_COLORS[classId] or CLASS_COLORS.Any
end

-- Put an image in an icon box, cropped to its drawn area (IconRects) and fitted,
-- so it sits centred in the box with even padding whatever margin its source has.
function SlotArt.setIcon(icon: ImageLabel, image: string)
	icon.Image = image
	icon.ScaleType = Enum.ScaleType.Fit
	local rect = IconRects[string.match(image, "%d+$") or ""]
	if rect then
		icon.ImageRectOffset = Vector2.new(rect[1], rect[2])
		icon.ImageRectSize = Vector2.new(rect[3], rect[4])
	else
		icon.ImageRectOffset = Vector2.zero
		icon.ImageRectSize = Vector2.zero
	end
end

-- The box a slot's icon, disc, glyph and model fill (its Well; old slots: itself).
function SlotArt.well(slot: Instance): Instance
	return slot:FindFirstChild("Well") or slot
end

local function fill(icon: GuiObject, share: number)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(share, share)
end

-- The rarity edge and wash of a slot: the tier's colour, or a dim neutral edge for
-- ungraded things (Bare Fists) and empty slots.
local function paintRarity(slot: GuiObject, id: string?, filled: boolean)
	local edge = slot:FindFirstChild("Edge") :: ImageLabel?
	local wash = slot:FindFirstChild("Wash") :: ImageLabel?
	local rarity = Rarity.of(id)
	local graded = filled and rarity.tier ~= nil
	if edge then
		edge.ImageColor3 = if graded then rarity.color else NO_GRADE
		edge.ImageTransparency = if filled then 0 else EDGE_EMPTY
	end
	if wash then
		wash.Visible = graded
		wash.ImageColor3 = rarity.color
		wash.ImageTransparency = WASH
	end
end

-- A weapon's illustrated icon (rewards, the character card); Weapons.FIST is bare
-- hands. Slots show the model instead (paint).
function SlotArt.weaponIcon(weaponId: string): string
	local def = Weapons.Defs[weaponId]
	if not def then
		return if weaponId == Weapons.FIST then CLASS_ICONS.Fist else ""
	end
	return def.icon or MODEL_ICONS[def.model] or SlotArt.classIcon(def.class)
end

function SlotArt.weaponName(weaponId: string): string
	local def = Weapons.Defs[weaponId]
	return if def then def.name elseif weaponId == Weapons.FIST then FIST_NAME else weaponId
end

function SlotArt.weaponColor(weaponId: string): Color3
	local def = Weapons.Defs[weaponId]
	local grade = def and Weapons.Grades[def.grade]
	return if grade then grade.color else FIST_COLOR
end

-- The equipped weapon id ("" for none): the state snapshot, else the player's
-- Weapon attribute.
function SlotArt.equipped(): string
	local weapons = (State.current :: any).weapons
	if weapons and type(weapons.equipped) == "string" then
		return weapons.equipped
	end
	local attribute = Players.LocalPlayer:GetAttribute("Weapon")
	return if type(attribute) == "string" then attribute else ""
end

-- The weapon class a technique needs, or nil for "Any".
function SlotArt.techniqueClass(id: string?): string?
	local technique = id and Techniques.Defs[id]
	local need = technique and (technique :: any).weapon
	return if type(need) == "string" and Weapons.Classes[need] then need else nil
end

-- The weapon badge on a technique slot (its WeaponBadge child, if it has one):
-- every class art wears its class glyph in the class colour, so the hotbar and the
-- Inventory both say which weapon an art needs. inventory: never dim. Otherwise
-- (hotbar) the slot dims while that class isn't in hand. Returns whether the
-- technique's weapon is missing. Call after paint.
function SlotArt.gate(slot: GuiObject, id: string?, inventory: boolean): boolean
	local need = SlotArt.techniqueClass(id)
	local missing = need ~= nil and need ~= Weapons.classOf(SlotArt.equipped())
	local always = inventory
	local badge = slot:FindFirstChild("WeaponBadge") :: ImageLabel?
	if badge then
		badge.Visible = need ~= nil
		if need then
			-- a badge that is the glyph itself, or a ring holding it (the hotbar's)
			local glyph = (badge:FindFirstChild("Icon") :: ImageLabel?) or badge
			SlotArt.setIcon(glyph, SlotArt.classGlyph(need))
			glyph.ImageColor3 = SlotArt.classColor(need)
			glyph.ImageTransparency = if missing and not always then 0.15 else 0
		end
	end
	if missing and not always then
		local well = SlotArt.well(slot);
		(well:FindFirstChild("Icon") :: ImageLabel).ImageTransparency = GATED_ICON
		local disc = well:FindFirstChild("Disc") :: ImageLabel?
		if disc then
			disc.ImageTransparency = GATED_ICON
		end
	end
	return missing
end

-- countText overrides the corner text ("" hides it).
function SlotArt.paint(slot: GuiObject, id: string?, count: number?, countText: string?)
	local well = SlotArt.well(slot)
	local icon = well:FindFirstChild("Icon") :: ImageLabel
	local glyph = well:FindFirstChild("Glyph") :: TextLabel
	local disc = well:FindFirstChild("Disc") :: ImageLabel?
	local model = well:FindFirstChild("Model") :: ViewportFrame?
	local corner = slot:FindFirstChild("CountLabel") :: TextLabel
	local name = slot:FindFirstChild("NameLabel") :: TextLabel?
	local frame = slot:FindFirstChild("Frame") :: ImageLabel
	local technique = id and Techniques.Defs[id]
	local item = id and Items.Defs[id]
	local weapon = id and not technique and not item and (Weapons.Defs[id] ~= nil or id == Weapons.FIST)
	icon.Image = ""
	icon.Visible = true
	glyph.Text = ""
	if well ~= slot then
		fill(icon, FILL_ITEM)
	end
	corner.Text = countText or ""
	if disc then
		disc.Visible = false
	end
	local filled = (technique or item or weapon) and true or false
	frame.ImageTransparency = if filled then 0 else 0.35
	paintRarity(slot, id, filled)
	if name then
		name.Text = if technique then technique.name elseif item then item.name elseif weapon and id then SlotArt.weaponName(id) else ""
	end
	local shown = false -- whether the Model viewport shows a weapon
	if technique then
		SlotArt.setIcon(icon, technique.icon)
		icon.ImageTransparency = 0
		if disc then
			disc.Visible = true
			disc.ImageColor3 = technique.color:Lerp(Color3.new(), DISC_DARK)
			disc.ImageTransparency = 0
			icon.ImageColor3 = technique.color:Lerp(WHITE, ART_GLYPH)
			fill(icon, FILL_ART)
		else
			icon.ImageColor3 = technique.color:Lerp(WHITE, 0.35)
		end
	elseif item then
		local empty = (count or 0) <= 0
		if item.icon then
			SlotArt.setIcon(icon, item.icon)
			icon.ImageColor3 = WHITE
			icon.ImageTransparency = if empty then 0.6 else 0
		else
			glyph.Text = item.glyph
			glyph.TextColor3 = item.color:Lerp(WHITE, 0.45)
			glyph.TextTransparency = if empty then 0.6 else 0
		end
		if countText == nil then
			corner.Text = if count then `x{count}` else ""
		end
	elseif weapon and id then
		if model and id ~= Weapons.FIST then
			shown = WeaponView.show(model, id)
		end
		if not shown then
			local classId = Weapons.classOf(id)
			SlotArt.setIcon(icon, SlotArt.classGlyph(classId))
			icon.ImageColor3 = SlotArt.classColor(classId)
			icon.ImageTransparency = 0
			if well ~= slot then
				fill(icon, FILL_GLYPH)
			end
		end
		icon.Visible = not shown
		if countText == nil then
			corner.Text = if count and count > 1 then `x{count}` else ""
		end
	end
	if model and not shown then
		WeaponView.show(model, nil)
	end
end

return SlotArt
