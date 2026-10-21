--!strict
-- Paints a framed slot (the hotbar's SlotTemplate, the Inventory's CellTemplate and
-- Preview) for a technique, an item, a weapon (or "Fist", bare hands), or nothing:
-- its icon or glyph, its name, the glow in its rarity, grade or technique color, and
-- the count in the corner. Empty slots fade back.
-- Also owns the weapon art (icons by model and by class, art/ui/assets.json) and the
-- weapon badge on technique slots (gate).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
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
	Spear = "rbxassetid://70542848898137",
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
local FIST_NAME = "Bare Fists"
local FIST_COLOR = Color3.fromRGB(236, 196, 156)

function SlotArt.classIcon(classId: string): string
	local class = Weapons.Classes[classId]
	return (class and class.icon) or CLASS_ICONS[classId] or ""
end

-- A weapon's icon; Weapons.FIST is bare hands.
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

-- The weapon badge on a technique slot (its WeaponBadge child, if it has one).
-- always: show the class of every class art (Arts cells). Otherwise (hotbar) show it
-- only while that class isn't in hand, and dim the slot. Returns whether the
-- technique's weapon is missing. Call after paint.
function SlotArt.gate(slot: GuiObject, id: string?, always: boolean): boolean
	local need = SlotArt.techniqueClass(id)
	local missing = need ~= nil and need ~= Weapons.classOf(SlotArt.equipped())
	local badge = slot:FindFirstChild("WeaponBadge") :: ImageLabel?
	if badge then
		badge.Visible = if always then need ~= nil else missing
		if need then
			(badge:FindFirstChild("Icon") :: ImageLabel).Image = SlotArt.classIcon(need)
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
		icon.Image = SlotArt.weaponIcon(id)
		icon.ImageColor3 = WHITE
		icon.ImageTransparency = 0
		glow.ImageColor3 = SlotArt.weaponColor(id)
		glow.Visible = true
		if countText == nil then
			corner.Text = if count and count > 1 then `x{count}` else ""
		end
	end
end

return SlotArt
