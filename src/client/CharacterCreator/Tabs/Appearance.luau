--!strict
-- Appearance step: skin colour (one swatch per SkinColors entry; "Avatar" keeps
-- the player's own skin), then Shirt and Pants, one card per option in
-- Shared.CharacterCreator.Clothing. A tap selects and dresses the preview.

local Look = require(script.Parent.Parent.Look)

local Appearance = {}

local GLYPHS = { Shirt = "衣", Pants = "裤" } -- placeholder art on cards with no image

-- Card image: the option's own Thumbnail, else its Template image, else Roblox's
-- catalog thumbnail of its asset, else "" (the placeholder glyph shows).
local function imageFor(option: any): string
	if option.Thumbnail ~= "" then
		return option.Thumbnail
	elseif option.Template then
		return option.Template
	elseif option.AssetId > 0 then
		return `rbxthumb://type=Asset&id={option.AssetId}&w=150&h=150`
	end
	return ""
end

function Appearance.build(page: ScrollingFrame, ctx: any)
	local state, defs, components = ctx.state, ctx.defs, ctx.components

	-- Skin
	components.section(page, "Skin", 1)
	local skinGrid = components.grid(page, "SwatchGrid", 2, "SkinGrid")
	local skinName = components.note(page, "", 3, "SkinName")
	local swatches = {}
	for order, entry in defs.SkinColors do
		local shown = entry.Color or Color3.fromRGB(205, 170, 140) -- a neutral tone stands for the avatar's own
		swatches[entry.Id] = components.swatch(skinGrid, entry.Id, shown, order, function()
			state:set("SkinColor", entry.Id)
		end)
	end
	local function paintSkin()
		local current = state:get("SkinColor")
		for id, swatch in swatches do
			swatch.setSelected(id == current)
		end
		for _, entry in defs.SkinColors do
			if entry.Id == current then
				skinName.Text = entry.DisplayName
				ctx.preview.chooseSkin(entry.Color)
			end
		end
	end

	local painters = {}
	for index, kind in { "Shirt", "Pants" } do
		components.section(page, kind, 2 + index * 2)
		local grid = components.grid(page, "CardGrid", 3 + index * 2, kind .. "Grid")
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
		painters[kind] = function()
			for id, card in cards do
				card.setSelected(id == state:get(kind))
			end
			task.spawn(function() -- the catalog templates may still be loading
				ctx.preview.setClothing(kind, Look.template(kind, state:get(kind)))
			end)
		end
	end

	state:onChanged(function(key)
		if key == "SkinColor" then
			paintSkin()
		elseif painters[key] then
			painters[key]()
		end
	end)

	local handle = {}
	-- repaint everything from the state (the creator starting on a look)
	function handle.reset()
		paintSkin()
		painters.Shirt()
		painters.Pants()
	end
	handle.reset()
	return handle
end

return Appearance
