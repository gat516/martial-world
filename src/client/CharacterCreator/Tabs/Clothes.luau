--!strict
-- Clothes tab: exactly two sections, Shirt and Pants, one card per option in
-- Shared.CharacterCreator.Clothing. A tap selects and dresses the preview.

local Clothes = {}

local GLYPHS = { Shirt = "衣", Pants = "裤" } -- placeholder art on cards with no image

-- Card image: the option's own Thumbnail, else Roblox's catalog thumbnail of
-- its asset, else "" (the placeholder glyph shows).
local function imageFor(option: any): string
	if option.Thumbnail ~= "" then
		return option.Thumbnail
	elseif option.AssetId > 0 then
		return `rbxthumb://type=Asset&id={option.AssetId}&w=150&h=150`
	end
	return ""
end

local function optionById(list: { any }, id: string): any
	for _, option in list do
		if option.Id == id then
			return option
		end
	end
	return list[1]
end

function Clothes.build(page: ScrollingFrame, ctx: any)
	local state, defs, components = ctx.state, ctx.defs, ctx.components
	local templates: { [any]: string } = {}

	local function dress(kind: string)
		local option = optionById(defs.Clothing[kind], state:get(kind))
		-- the remote may hand numeric keys back as strings
		local template = if option.AssetId > 0
			then templates[option.AssetId] or templates[tostring(option.AssetId)] or ""
			else ""
		ctx.preview.setClothing(kind, template)
	end

	for index, kind in { "Shirt", "Pants" } do
		components.sectionHeader(page, kind, index * 2 - 1)
		local grid = components.grid(page, "CardGrid", index * 2, kind .. "Grid")
		local cards = {}
		for order, option in defs.Clothing[kind] do
			cards[option.Id] = components.card(grid, {
				id = option.Id,
				caption = option.DisplayName,
				image = imageFor(option),
				glyph = GLYPHS[kind],
				order = order,
				onClick = function()
					state:set(kind, option.Id)
				end,
			})
		end
		local function paint()
			for id, card in cards do
				card.setSelected(id == state:get(kind))
			end
		end
		paint()
		state:onChanged(function(key)
			if key == kind then
				paint()
				dress(kind)
			end
		end)
	end

	task.spawn(function()
		templates = ctx.bridge.fetchTemplates()
		dress("Shirt")
		dress("Pants")
	end)
end

return Clothes
