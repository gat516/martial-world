--!strict
-- Hair tab: a hair accessory by catalog id (the server checks it's hair and
-- hands back a copy to preview), and a colour from HairColors.

local Hair = {}

local MAX_DIGITS = 19

local HINT = "Paste the ID from a hair accessory's catalog page."

function Hair.build(page: ScrollingFrame, ctx: any)
	local state, defs, components, preview = ctx.state, ctx.defs, ctx.components, ctx.preview
	local rules = defs.Rules

	local function colorOf(id: string): Color3
		for _, entry in defs.HairColors do
			if entry.Id == id then
				return entry.Color
			end
		end
		return defs.HairColors[1].Color
	end

	-- Hair Asset ID
	components.sectionHeader(page, "Hair Asset ID", 1)
	local field = components.textField(page, {
		name = "HairField",
		placeholder = "1234567890",
		order = 2,
		action = "Apply",
	})
	field.setStatus(HINT, "info")
	local box: TextBox = field.input

	box:GetPropertyChangedSignal("Text"):Connect(function()
		local digits = box.Text:gsub("%D", ""):sub(1, MAX_DIGITS)
		if digits ~= box.Text then
			box.Text = digits
		end
	end)

	local token = 0
	local function apply()
		local id, why = rules.parseAssetId(box.Text)
		if not id then
			field.setStatus(why, "error")
			return
		end
		if id == state:get("HairId") then
			field.setStatus("That hair is already on.", "ok")
			return
		end
		token += 1
		local mine = token
		field.setBusy(true)
		field.setStatus("Loading hair...", "info")
		local ok, result = ctx.bridge.loadHair(id)
		if mine ~= token then
			return -- a newer request took over
		end
		field.setBusy(false)
		if ok then
			preview.setHair(result)
			preview.tintHair(colorOf(state:get("HairColor")), rules.tintHair)
			state:set("HairId", id)
			field.setStatus("Hair applied.", "ok")
		else
			field.setStatus(result, "error")
		end
	end
	field.action.Activated:Connect(function()
		if field.action.Active then
			task.spawn(apply)
		end
	end)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			task.spawn(apply)
		end
	end)

	-- Hair Color
	components.sectionHeader(page, "Hair Color", 3)
	local grid = components.grid(page, "SwatchGrid", 4, "ColorGrid")
	local caption = components.note(page, "", 5, "ColorName")
	local swatches = {}
	for order, entry in defs.HairColors do
		swatches[entry.Id] = components.swatch(grid, entry.Id, entry.Color, order, function()
			state:set("HairColor", entry.Id)
		end)
	end
	local function paint()
		local current = state:get("HairColor")
		for id, swatch in swatches do
			swatch.setSelected(id == current)
		end
		for _, entry in defs.HairColors do
			if entry.Id == current then
				caption.Text = entry.DisplayName
			end
		end
	end
	paint()
	state:onChanged(function(key)
		if key == "HairColor" then
			paint()
			preview.tintHair(colorOf(state:get("HairColor")), rules.tintHair)
		end
	end)
end

return Hair
