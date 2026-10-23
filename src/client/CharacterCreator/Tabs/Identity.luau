--!strict
-- Identity tab: the race and last name the server rolled (shown from the
-- player's Race and Surname attributes, with a paid Change button each). The
-- first name is typed on the pedestal under the preview (NamePlate.luau). No
-- suggestions and no free reroll: the first roll happened on join. Under each block, the full list of races or last names
-- with rarity and chance (user, 2026-10-23). For a race with variants (Beast
-- Folk), its rollable variants with rarity and chance too, and pickers for any
-- race or variant the player may choose (Bridge.getChoices; hidden when none).

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
	local defs, components = ctx.defs, ctx.components
	local rules = defs.Rules

	-- Race
	components.sectionHeader(page, "Race", 1)
	local race = components.identityBlock(page, "RaceBlock", "Change Race", 2)
	race.change.setPrice(defs.Products.RerollRace.RobuxPrice)
	-- the race and, for races with variants (Beast Folk), the variant: "Beast Folk (Wolf)"
	local function paintRace(changed: boolean)
		local player = ctx.player
		local key = player:GetAttribute("Race")
		local variantKey = player:GetAttribute("RaceVariant")
		local def = defs.Registry.race(key)
		local variant = defs.Registry.variant(key, variantKey)
		local shown = variant or def
		race.set({
			title = if def then defs.Registry.label(key, variantKey) else "Unknown",
			note = if variant then `{def.Description} {variant.Description}` elseif def then def.Description else "Your race is drawn when you arrive.",
			rarity = shown and shown.Rarity,
			rarities = defs.Rarities,
			icon = shown and (if shown.Icon ~= "" then shown.Icon else def.Icon),
		})
		if changed then
			race.reveal()
		end
	end
	ctx.onAttribute("Race", function(_, changed: boolean)
		paintRace(changed)
	end)
	ctx.player:GetAttributeChangedSignal("RaceVariant"):Connect(function()
		paintRace(true)
	end)
	race.change.button.Activated:Connect(function()
		task.spawn(rerollFlow, ctx, race, "Race")
	end)

	-- Pickers: only when the server says the player may pick a race or variant
	-- (Availability Select, or Unlock with Requires met). Nothing is pickable by
	-- default, so they normally stay hidden.
	local pickers = {
		Race = { header = components.sectionHeader(page, "Choose Race", 10), grid = components.grid(page, "CardGrid", 11, "RaceChoices") },
		Variant = { header = components.sectionHeader(page, "Choose Variant", 20), grid = components.grid(page, "CardGrid", 21, "VariantChoices") },
	}
	local picking = false
	local function paintPicker(kind: string, ids: { string })
		local picker = pickers[kind]
		for _, child in picker.grid:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		local raceKey = ctx.player:GetAttribute("Race")
		local current = if kind == "Race" then raceKey else ctx.player:GetAttribute("RaceVariant")
		for order, id in ids do
			local def = if kind == "Race" then defs.Registry.race(id) else defs.Registry.variant(raceKey, id)
			if def then
				local card = components.card(picker.grid, {
					id = id,
					caption = def.DisplayName,
					image = def.Icon or "",
					glyph = string.sub(def.DisplayName, 1, 1),
					order = order,
					onClick = function()
						if picking or id == current then
							return
						end
						picking = true
						race.setStatus(nil)
						local ok, message = ctx.bridge.choose(kind, id)
						if not ok then
							race.setStatus(if type(message) == "string" then message else "You can't choose that")
						end
						picking = false
					end,
				})
				card.setSelected(id == current)
			end
		end
		local shown = #ids > 0
		picker.header.Visible = shown
		picker.grid.Visible = shown
	end
	local asked = 0
	local function refreshChoices()
		asked += 1
		local mine = asked
		task.spawn(function()
			local ok, choices = ctx.bridge.getChoices()
			if mine ~= asked then
				return -- a newer refresh is on its way
			end
			local ids = if ok and type(choices) == "table" then choices else {}
			paintPicker("Race", ids.races or {})
			paintPicker("Variant", ids.variants or {})
		end)
	end
	paintPicker("Race", {})
	paintPicker("Variant", {})

	-- The player's race's variants with rarity and roll chance (only the ones the
	-- roll can give: Released + Roll), rebuilt when the race changes.
	local variantRows: { Instance } = {}
	local variantHeader: Frame? = nil
	local function paintVariants()
		for _, row in variantRows do
			row:Destroy()
		end
		variantRows = {}
		if variantHeader then
			variantHeader:Destroy()
			variantHeader = nil
		end
		local raceKey = ctx.player:GetAttribute("Race")
		local pool = if type(raceKey) == "string" then defs.Registry.variantPool(raceKey, "Roll") else {}
		if next(pool) == nil then
			return
		end
		variantHeader = components.sectionHeader(page, `{defs.Registry.race(raceKey).DisplayName} Variants`, 50)
		local mine = ctx.player:GetAttribute("RaceVariant")
		local keys = {}
		for key in pool do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			if pool[a].Weight ~= pool[b].Weight then
				return pool[a].Weight < pool[b].Weight
			end
			return pool[a].DisplayName < pool[b].DisplayName
		end)
		for index, key in keys do
			local row = components.summaryRow(page, pool[key].DisplayName, 50 + index)
			local chance = rules.chance(pool, key)
			local text = if chance >= 1 then `{math.floor(chance + 0.5)}%` else `{math.floor(chance * 10 + 0.5) / 10}%`
			row.set(if key == mine then `{text}  (yours)` else text, nil, pool[key].Rarity, defs.Rarities)
			table.insert(variantRows, row.root)
		end
	end
	local function onIdentityChanged()
		paintVariants()
		refreshChoices()
	end
	ctx.player:GetAttributeChangedSignal("Race"):Connect(onIdentityChanged)
	ctx.player:GetAttributeChangedSignal("RaceVariant"):Connect(onIdentityChanged)
	paintVariants()
	refreshChoices()
	-- only the races the roll can give right now (Availability: Released + Roll)
	oddsList(ctx, page, "All Races", defs.Registry.racePool("Roll"), "Race", 100)

	-- Last Name
	components.sectionHeader(page, "Last Name", 300)
	local surname = components.identityBlock(page, "SurnameBlock", "Change Last Name", 301)
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
	oddsList(ctx, page, "All Last Names", defs.Surnames, "Surname", 400)
end

return Identity
