--!strict
-- Hair tab: up to Rules.MAX_HAIRS hair accessories by catalog id, one field each
-- (the server checks each is hair and hands back a copy to preview), and a
-- colour from HairColors. The fields start filled with the player's own Roblox
-- hair (the server's "defaults"), which also gives the preview their skin.

local Hair = {}

local MAX_DIGITS = 19

local HINT = "Paste the ID from a hair accessory's catalog page."
local EMPTY_HINT = "Optional. Paste another hair's ID to layer it."

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

	-- Hair Asset IDs: one field per slot
	components.sectionHeader(page, "Hair Asset IDs", 1)
	local fields = {}
	local token = 0 -- one hair load at a time across the fields (the server rate-limits them)

	local function wear(slot: number, id: number, accessory: Accessory)
		preview.setHair(slot, accessory)
		preview.tintHair(colorOf(state:get("HairColor")), rules.tintHair)
		state:set(`Hair{slot}`, id)
	end

	for slot = 1, rules.MAX_HAIRS do
		local field = components.textField(page, {
			name = `HairField{slot}`,
			placeholder = if slot == 1 then "1234567890" else "Empty",
			order = 1 + slot,
			action = "Apply",
		})
		field.setStatus(if slot == 1 then HINT else EMPTY_HINT, "info")
		fields[slot] = field
		local box: TextBox = field.input

		box:GetPropertyChangedSignal("Text"):Connect(function()
			local digits = box.Text:gsub("%D", ""):sub(1, MAX_DIGITS)
			if digits ~= box.Text then
				box.Text = digits
			end
		end)

		local function apply()
			local key = `Hair{slot}`
			if box.Text == "" then
				-- an emptied field takes that hair off
				if state:get(key) then
					preview.setHair(slot, nil)
					state:set(key, nil)
					field.setStatus("Hair removed.", "ok")
				else
					field.setStatus(if slot == 1 then HINT else EMPTY_HINT, "info")
				end
				return
			end
			local id, why = rules.parseAssetId(box.Text)
			if not id then
				field.setStatus(why, "error")
				return
			end
			if id == state:get(key) then
				field.setStatus("That hair is already on.", "ok")
				return
			end
			for other = 1, rules.MAX_HAIRS do
				if other ~= slot and state:get(`Hair{other}`) == id then
					field.setStatus(`That hair is already in slot {other}.`, "error")
					return
				end
			end
			token += 1
			local mine = token
			field.setBusy(true)
			field.setStatus("Loading hair...", "info")
			local ok, result = ctx.bridge.loadHair(id)
			field.setBusy(false)
			if mine ~= token then
				return -- a newer request took over
			end
			if ok then
				wear(slot, id, result)
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
	end

	-- Start from the player's own avatar: their skin, and their hairs in the fields.
	task.spawn(function()
		local ok, avatar = ctx.bridge.getDefaults()
		if not ok then
			return
		end
		preview.setSkin(avatar.skin)
		for slot, hair in avatar.hairs do
			local field = fields[slot]
			if field and not state:get(`Hair{slot}`) and field.input.Text == "" then
				field.input.Text = tostring(hair.id)
				wear(slot, hair.id, hair.accessory)
				field.setStatus("Your avatar's hair.", "ok")
			end
		end
	end)

	-- Hair Color
	local order = 2 + rules.MAX_HAIRS
	components.sectionHeader(page, "Hair Color", order)
	local grid = components.grid(page, "SwatchGrid", order + 1, "ColorGrid")
	local caption = components.note(page, "", order + 2, "ColorName")
	local swatches = {}
	for index, entry in defs.HairColors do
		swatches[entry.Id] = components.swatch(grid, entry.Id, entry.Color, index, function()
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
