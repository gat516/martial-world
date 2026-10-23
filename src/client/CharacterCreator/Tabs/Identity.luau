--!strict
-- Identity tab: the first name the player types (the one required field, so it
-- comes first, tagged Required and rimmed gold while empty), then the race and
-- last name the server rolled (shown from the player's Race and Surname
-- attributes, with a paid Change button each). No suggestions and no free
-- reroll: the first roll happened on join. At the bottom, the full list of races
-- and of last names with rarity and chance (user, 2026-10-23).

local MarketplaceService = game:GetService("MarketplaceService")

local Identity = {}

-- Every race or last name with its rarity and chance, rarest first, as rows
-- from `order` up (the player's own is marked).
local function oddsList(ctx: any, page: ScrollingFrame, title: string, defs: { [string]: any }, attribute: string, order: number)
	local components, rarities, rules = ctx.components, ctx.defs.Rarities, ctx.defs.Rules
	components.sectionHeader(page, title, order)
	local keys = {}
	for key in defs do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		if defs[a].Weight ~= defs[b].Weight then
			return defs[a].Weight < defs[b].Weight
		end
		return defs[a].DisplayName < defs[b].DisplayName
	end)
	local rows = {}
	for index, key in keys do
		rows[key] = components.summaryRow(page, defs[key].DisplayName, order + index)
	end
	local function paint(current: string?)
		for key, row in rows do
			local chance = rules.chance(defs, key)
			local text = if chance >= 1 then `{math.floor(chance + 0.5)}%` else `{math.floor(chance * 10 + 0.5) / 10}%`
			row.set(if key == current then `{text}  (yours)` else text, nil, defs[key].Rarity, rarities)
		end
	end
	ctx.onAttribute(attribute, function(key)
		paint(key)
	end)
end

local function rerollFlow(ctx: any, block: any, kind: string)
	local button = block.change
	if button.isBusy() then
		return
	end
	button.setBusy(true)
	block.setStatus(nil)
	local result, info = ctx.bridge.requestReroll(kind)
	if result == "prompted" then
		-- the attribute changes (and the card reveals) if the purchase goes through
		local done = false
		local connection
		connection = MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, productId)
			if productId == info then
				done = true
				connection:Disconnect()
			end
		end)
		task.delay(60, function()
			if not done then
				connection:Disconnect()
				button.setBusy(false)
			end
		end)
		while not done do
			task.wait(0.1)
		end
	elseif result == "error" then
		block.setStatus(info)
	end
	button.setBusy(false)
end

function Identity.build(page: ScrollingFrame, ctx: any)
	local state, defs, components = ctx.state, ctx.defs, ctx.components
	local rules = defs.Rules

	-- First Name
	components.sectionHeader(page, "First Name", 1, true)
	local field = components.textField(page, {
		name = "FirstNameField",
		placeholder = "Choose a first name",
		order = 2,
		counter = true,
	})
	local box: TextBox = field.input
	-- the family glyph on a keyplate before the name
	local familyGlyph = components.keyplate(field.root)
	ctx.onAttribute("Surname", function(key: string?)
		local def = key and defs.Surnames[key]
		familyGlyph.Text = if def then def.Glyph else ""
	end)
	local max = rules.FIRST_NAME.MAX
	local function validate()
		local text = box.Text
		field.counter.Text = `{utf8.len(text) or #text}/{max}`
		if text:match("^%s*$") then
			field.setStatus(`Required: {rules.FIRST_NAME.MIN} to {max} letters.`, "need")
			field.setNeed("need")
			return
		end
		local name, why = rules.checkFirstName(text)
		if name then
			local family = defs.Surnames[ctx.player:GetAttribute("Surname") or ""]
			field.setStatus(`You will be known as {if family then family.DisplayName .. " " else ""}{name}.`, "ok")
			field.setNeed(nil)
		else
			field.setStatus(why, "error")
			field.setNeed("error")
		end
	end
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local text = box.Text
		local length = utf8.len(text)
		if length and length > max then
			text = text:sub(1, (utf8.offset(text, max + 1) or (#text + 1)) - 1)
			box.Text = text
			return -- the change re-enters with the trimmed text
		end
		state:set("FirstName", text)
		validate()
	end)
	validate()
	-- Next, Enter World or a locked step bring the player here
	ctx.registerField("FirstName", function()
		page.CanvasPosition = Vector2.zero
		field.flash()
		if not ctx.isTouch then
			box:CaptureFocus()
		end
	end)

	-- Race
	components.sectionHeader(page, "Race", 100)
	local race = components.identityBlock(page, "RaceBlock", "Change Race", 101)
	race.change.setPrice(defs.Products.RerollRace.RobuxPrice)
	ctx.onAttribute("Race", function(key: string?, changed: boolean)
		local def = key and defs.Races[key]
		race.set({
			title = if def then def.DisplayName else "Unknown",
			note = if def then def.Description else "Your race is drawn when you arrive.",
			rarity = def and def.Rarity,
			rarities = defs.Rarities,
			icon = def and def.Icon,
		})
		if changed then
			race.reveal()
		end
	end)
	race.change.button.Activated:Connect(function()
		task.spawn(rerollFlow, ctx, race, "Race")
	end)
	oddsList(ctx, page, "All Races", defs.Races, "Race", 400)

	-- Last Name
	components.sectionHeader(page, "Last Name", 200)
	local surname = components.identityBlock(page, "SurnameBlock", "Change Last Name", 201)
	surname.change.setPrice(defs.Products.RerollSurname.RobuxPrice)
	ctx.onAttribute("Surname", function(key: string?, changed: boolean)
		local def = key and defs.Surnames[key]
		surname.set({
			title = if def then def.DisplayName else "Unknown",
			note = "Your family name, drawn when you arrived.",
			rarity = def and def.Rarity,
			rarities = defs.Rarities,
			glyph = def and def.Glyph,
		})
		if changed then
			surname.reveal()
		end
	end)
	surname.change.button.Activated:Connect(function()
		task.spawn(rerollFlow, ctx, surname, "Surname")
	end)
	oddsList(ctx, page, "All Last Names", defs.Surnames, "Surname", 500)
end

return Identity
