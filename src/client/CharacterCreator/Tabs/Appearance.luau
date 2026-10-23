--!strict
-- Appearance step: skin colour (one swatch per SkinColors entry; "Avatar" keeps
-- the player's own skin), then Shirt and Pants, each one arrow picker over the
-- options in Shared.CharacterCreator.Clothing (user, 2026-10-23: the card grids
-- became arrows). The pick's name sits between the arrows with "1 / 3" under
-- it; the big preview character wears it. Arrows wrap around.

local Look = require(script.Parent.Parent.Look)

local Appearance = {}

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
		local options = defs.Clothing[kind]
		components.section(page, kind, 2 + index * 2)
		local function indexOf(id: string): number
			for i, option in options do
				if option.Id == id then
					return i
				end
			end
			return 1
		end
		local row = components.arrowRow(page, kind .. "Picker", 3 + index * 2, function(delta: number)
			local i = (indexOf(state:get(kind)) - 1 + delta) % #options + 1
			state:set(kind, options[i].Id)
		end)
		painters[kind] = function()
			local i = indexOf(state:get(kind))
			row.set(options[i].DisplayName, i, #options)
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
