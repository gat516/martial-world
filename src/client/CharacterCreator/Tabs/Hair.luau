--!strict
-- Hair step: up to Rules.MAX_HAIRS hair accessories by catalog id, one field
-- each (the server checks each is hair and hands back a copy to preview), and a
-- colour from HairColors. A new character starts with the player's own Roblox
-- hair (the server's "defaults", which also give the preview their skin); an
-- edit starts with the slot's saved hairs.

local Hair = {}

local MAX_DIGITS = 19

local HINT = "Paste the ID from a hair accessory's catalog page."
local EMPTY_HINT = "Optional: another hair to layer."

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

	components.section(page, "Hair asset IDs", 1)
	local fields = {}
	local token = 0 -- one hair load at a time across the fields (the server rate-limits them)

	local function idle(slot: number)
		fields[slot].setStatus(if slot == 1 then HINT else EMPTY_HINT, "info")
	end

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
		fields[slot] = field
		idle(slot)
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
					idle(slot)
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
					field.setStatus(`That hair is already in field {other}.`, "error")
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

	-- Hair colour
	local order = 2 + rules.MAX_HAIRS
	components.section(page, "Hair colour", order)
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
		preview.tintHair(colorOf(current), rules.tintHair)
	end
	paint()
	state:onChanged(function(key)
		if key == "HairColor" then
			paint()
		end
	end)

	local avatar: any = nil -- the avatar defaults, asked for once
	local handle = {}
	-- Starts the fields over: `hairs` are the slot's saved hairs ({ id,
	-- accessory }), or nil for a new character (the avatar's own).
	function handle.reset(hairs: { { id: number, accessory: Accessory } }?)
		token += 1
		preview.clearHairs()
		for slot = 1, rules.MAX_HAIRS do
			fields[slot].input.Text = ""
			idle(slot)
			state:set(`Hair{slot}`, nil)
		end
		local function fill(list: { any }, note: string)
			for slot, hair in list do
				local field = fields[slot]
				if field and hair.accessory then
					field.input.Text = tostring(hair.id)
					wear(slot, hair.id, hair.accessory)
					field.setStatus(note, "ok")
				end
			end
			paint()
		end
		if hairs then
			fill(hairs, "Saved hair.")
			return
		end
		local mine = token
		task.spawn(function()
			if avatar == nil then
				local ok, result = ctx.bridge.getDefaults()
				avatar = if ok then result else false
			end
			if mine ~= token or not avatar then
				return
			end
			preview.setSkin(avatar.skin)
			fill(avatar.hairs, "Your avatar's hair.")
		end)
	end
	return handle
end

return Hair
