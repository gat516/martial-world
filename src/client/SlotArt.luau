--!strict
-- Paints a framed slot (the hotbar's SlotTemplate, the Inventory's CellTemplate and
-- Preview) for a technique, an item, a weapon (or "Fist", bare hands), or nothing:
-- its icon or glyph, its name, the glow in its rarity, grade or technique color, and
-- the count in the corner. Empty slots fade back.
-- Also owns the weapon art (icons by model and by class, art/ui/assets.json), the
-- class glyphs and colours shared by weapon cells, art badges, the Inventory's
-- class rail and section headers, and the hotbar (classGlyph, classColor), the
-- weapon badge on technique slots (gate) and the rarity frame (tile, Rarity).
-- Weapons are drawn as their class glyph in their class colour, so a weapon and
-- the arts it unlocks wear the same mark.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Rarity = require(script.Parent.Rarity)
local State = require(script.Parent.State)

local SlotArt = {}

local WHITE = Color3.new(1, 1, 1)
local GATED_ICON = 0.6 -- icon transparency of a hotbar art whose weapon isn't in hand

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
	Fist = "rbxassetid://104207538401146",
	Sword = "rbxassetid://133108477410682",
	Saber = "rbxassetid://131762442903132",
	Greatsword = "rbxassetid://140142107031077",
	Guandao = "rbxassetid://132296972269637",
	Spear = "rbxassetid://102648443555194",
	Staff = "rbxassetid://76027373176155",
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

-- The rarity frame on an Inventory cell or preview (its Frame child): the kit
-- tile of its tier, the plain slot for Bare Fists. Hides the old glow. Call
-- after paint.
function SlotArt.tile(slot: GuiObject, id: string?)
	local frame = slot:FindFirstChild("Frame") :: ImageLabel
	frame.Image = Rarity.tile(Rarity.of(id).tier)
	frame.ImageColor3 = WHITE
	local glow = slot:FindFirstChild("Glow") :: ImageLabel?
	if glow then
		glow.Visible = false
	end
end

-- A weapon's illustrated icon (rewards, the character card); Weapons.FIST is bare
-- hands. Slots draw weapons as their class glyph instead (paint).
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
			glyph.Image = SlotArt.classGlyph(need)
			glyph.ImageColor3 = SlotArt.classColor(need)
			glyph.ImageTransparency = if missing and not always then 0.15 else 0
		end
	end
	if missing and not always then
		(slot:FindFirstChild("Icon") :: ImageLabel).ImageTransparency = GATED_ICON;
		(slot:FindFirstChild("Glow") :: ImageLabel).Visible = false
	end
	return missing
end

-- countText overrides the corner text ("" hides it).
function SlotArt.paint(slot: GuiObject, id: string?, count: number?, countText: string?)
	local icon = slot:FindFirstChild("Icon") :: ImageLabel
	local glyph = slot:FindFirstChild("Glyph") :: TextLabel
	local glow = slot:FindFirstChild("Glow") :: ImageLabel
	local corner = slot:FindFirstChild("CountLabel") :: TextLabel
	local name = slot:FindFirstChild("NameLabel") :: TextLabel?
	local frame = slot:FindFirstChild("Frame") :: ImageLabel
	local technique = id and Techniques.Defs[id]
	local item = id and Items.Defs[id]
	local weapon = id and not technique and not item and (Weapons.Defs[id] ~= nil or id == Weapons.FIST)
	icon.Image = ""
	glyph.Text = ""
	glow.Visible = false
	corner.Text = countText or ""
	frame.ImageTransparency = if technique or item or weapon then 0 else 0.5
	if name then
		name.Text = if technique then technique.name elseif item then item.name elseif weapon and id then SlotArt.weaponName(id) else ""
	end
	if technique then
		icon.Image = technique.icon
		icon.ImageColor3 = technique.color:Lerp(WHITE, 0.35)
		icon.ImageTransparency = 0
		glow.ImageColor3 = technique.color
		glow.Visible = true
	elseif item then
		local empty = (count or 0) <= 0
		if item.icon then
			icon.Image = item.icon
			icon.ImageColor3 = WHITE
			icon.ImageTransparency = if empty then 0.6 else 0
		else
			glyph.Text = item.glyph
			glyph.TextColor3 = item.color:Lerp(WHITE, 0.45)
			glyph.TextTransparency = if empty then 0.6 else 0
		end
		glow.ImageColor3 = Items.rarityColor(item)
		glow.Visible = not empty
		if countText == nil then
			corner.Text = if count then `x{count}` else ""
		end
	elseif weapon and id then
		local classId = Weapons.classOf(id)
		icon.Image = SlotArt.classGlyph(classId)
		icon.ImageColor3 = SlotArt.classColor(classId)
		icon.ImageTransparency = 0
		glow.ImageColor3 = SlotArt.weaponColor(id)
		glow.Visible = true
		if countText == nil then
			corner.Text = if count and count > 1 then `x{count}` else ""
		end
	end
end

return SlotArt
