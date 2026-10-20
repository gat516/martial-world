--!strict
-- Paints a framed slot (the hotbar's SlotTemplate, the Inventory's CellTemplate and
-- Preview) for a technique, an item, or nothing: its icon or glyph, its name, the
-- glow in its rarity or technique color, and the count in the corner. Empty slots
-- fade back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Techniques = require(ReplicatedStorage.Shared.Techniques)

local SlotArt = {}

local WHITE = Color3.new(1, 1, 1)

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
	icon.Image = ""
	glyph.Text = ""
	glow.Visible = false
	corner.Text = countText or ""
	frame.ImageTransparency = if technique or item then 0 else 0.5
	if name then
		name.Text = if technique then technique.name elseif item then item.name else ""
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
	end
end

return SlotArt
