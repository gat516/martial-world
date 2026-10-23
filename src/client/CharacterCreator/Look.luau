--!strict
-- Puts a whole look on the preview dummy at once (the slot screen showing a
-- slot's character, and the creator starting over). The tabs dress single
-- pieces as they change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bridge = require(script.Parent.Bridge)
local Defs = require(script.Parent.Defs)
local Preview = require(script.Parent.Preview)

local Look = {}

local function find(list: { any }, id: any): any
	for _, entry in list do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

-- The image a Shirt or Pants option wears ("" for none): its own Template, else
-- the catalog item's template the server looked up.
function Look.template(kind: string, id: string): string
	local option = find(Defs.Clothing[kind], id) or Defs.Clothing[kind][1]
	if option.Template then
		return option.Template
	elseif option.AssetId > 0 then
		local templates = Bridge.fetchTemplates()
		-- the remote may hand numeric keys back as strings
		return templates[option.AssetId] or (templates :: any)[tostring(option.AssetId)] or ""
	end
	return ""
end

function Look.hairColor(id: string?): Color3
	local entry = find(Defs.HairColors, id) or Defs.HairColors[1]
	return entry.Color
end

-- look: a slot's saved look (nil = the defaults); hairs: { { id, accessory } }
function Look.apply(look: { [string]: any }?, hairs: { { id: number, accessory: Accessory } })
	local shirt = look and look.Shirt or Defs.Clothing.Shirt[1].Id
	local pants = look and look.Pants or Defs.Clothing.Pants[1].Id
	Preview.setClothing("Shirt", Look.template("Shirt", shirt))
	Preview.setClothing("Pants", Look.template("Pants", pants))
	local skin = find(Defs.SkinColors, look and look.SkinColor or "")
	Preview.chooseSkin(skin and skin.Color)
	Preview.clearHairs()
	for slot, hair in hairs do
		Preview.setHair(slot, hair.accessory)
	end
	Preview.tintHair(Look.hairColor(look and look.HairColor), Defs.Rules.tintHair)
end

-- The race's look on the preview: what a fresh character of that race and
-- variant wears (its race, variant and innate traits' Cosmetics) and its size.
-- nil race = a plain body (an empty slot).
function Look.race(raceId: string?, variantId: string?)
	local registry = Defs.Registry
	local templates: { Accessory } = {}
	local scale = 1
	if raceId and registry.race(raceId) then
		local fresh = registry.fresh(raceId, variantId or "")
		local folder = ReplicatedStorage:FindFirstChild("Cosmetics")
		for id in registry.cosmetics(fresh) do
			local template = folder and folder:FindFirstChild(id, true)
			if template and template:IsA("Accessory") then
				table.insert(templates, template)
			end
		end
		scale = math.clamp(1 + registry.stat(fresh, "size"), 0.5, 2)
	end
	Preview.setRaceLook(templates, scale)
end

return Look
