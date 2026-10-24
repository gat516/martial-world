--!strict
-- Fate step: the race the server drew for this slot (the player's Race and
-- RaceVariant attributes) with a paid Change, then the race's free looks (one
-- arrow picker per Races.Looks slot, e.g. Spirit Fox's tail and ears; hidden
-- when the race has none), then the clan (Surname) with a paid Change, a note
-- that they stay with the slot, and the odds link (user, 2026-10-23). A reroll
-- that changes the race resets the looks to that race's defaults. The paid
-- Change buttons show only while Rules.PAID_REROLLS is on (off for now, user
-- 2026-10-24). The first-character screen (Tabs/Begin) builds these same rows
-- on its own page: opts.order offsets the rows, opts.note replaces the note
-- (false: none), opts.looks = false leaves the looks to Edit look, opts.inline
-- shows each rarity beside its value at the value's size.

local MarketplaceService = game:GetService("MarketplaceService")

local Fate = {}

local function rerollFlow(ctx: any, row: any, kind: string)
	if row.isBusy() then
		return
	end
	row.setBusy(true)
	row.setStatus(nil)
	local result, info = ctx.bridge.requestReroll(kind)
	if result == "prompted" then
		-- the attribute changes if the purchase goes through
		local done = false
		local connection
		connection = MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, productId)
			if productId == info then
				done = true
				connection:Disconnect()
			end
		end)
		local deadline = os.clock() + 60
		while not done and os.clock() < deadline do
			task.wait(0.1)
		end
		if not done then
			connection:Disconnect()
		end
	elseif result == "error" then
		row.setStatus(info)
	end
	row.setBusy(false)
end

export type Options = { order: number?, note: (string | boolean)?, looks: boolean?, inline: boolean? }

function Fate.build(page: ScrollingFrame, ctx: any, opts: Options?)
	local state, defs, components = ctx.state, ctx.defs, ctx.components
	local registry = defs.Registry
	local base = if opts and opts.order then opts.order else 0
	local paid = defs.Rules.PAID_REROLLS == true
	local withLooks = not (opts and opts.looks == false)
	local inline = opts ~= nil and opts.inline == true

	-- the rows say "Race" and "Clan" themselves; only the looks get a heading
	local race = components.fateRow(page, "RaceRow", base + 1)
	race.setPrice(defs.Products.RerollRace.RobuxPrice)
	race.setPaid(paid)
	race.button.Activated:Connect(function()
		task.spawn(rerollFlow, ctx, race, "Race")
	end)

	-- the race's free looks: rows are made per race, under their own heading
	local lookSection = components.section(page, "Look", base + 2)
	local lookRows: { any } = {}
	local shownFor: string? = nil

	local function raceId(): string?
		return ctx.player:GetAttribute("Race")
	end

	local buildLooks: () -> ()

	local function paintLooks()
		-- a race change sets RaceLook before the rows are rebuilt for it
		if shownFor ~= raceId() then
			buildLooks()
			return
		end
		if not withLooks then
			return
		end
		local picks = registry.lookPicks(raceId(), state:get("RaceLook")) -- defaults fill any gap
		local slots = registry.looks(raceId())
		for i, slot in slots do
			local row = lookRows[i]
			for index, option in slot.Options do
				if option.Id == picks[slot.Id] then
					row.set(option.DisplayName, index, #slot.Options, slot.DisplayName)
				end
			end
		end
	end

	function buildLooks()
		local id = raceId()
		if shownFor == id then
			return
		end
		if not withLooks then
			lookSection.Visible = false
			shownFor = id
			return
		end
		shownFor = id
		for _, row in lookRows do
			row.root:Destroy()
		end
		table.clear(lookRows)
		local slots = registry.looks(id)
		lookSection.Visible = #slots > 0
		for i, slot in slots do
			table.insert(
				lookRows,
				components.arrowRow(page, "Look_" .. slot.Id, base + 2 + i, function(delta: number)
					local picks = registry.lookPicks(raceId(), state:get("RaceLook"))
					local current = 1
					for index, option in slot.Options do
						if option.Id == picks[slot.Id] then
							current = index
						end
					end
					picks[slot.Id] = slot.Options[(current - 1 + delta) % #slot.Options + 1].Id
					state:set("RaceLook", picks)
				end)
			)
		end
		paintLooks()
	end

	-- "Beast Folk (Wolf)": a race with variants shows the drawn one, in its rarity
	local function paintRace()
		local key = raceId()
		local def = registry.race(key)
		local variant = def and registry.variant(key, ctx.player:GetAttribute("RaceVariant"))
		local rarity = (variant or def) and defs.Rarities[(variant or def).Rarity]
		race.set("Race", if def then registry.label(key, ctx.player:GetAttribute("RaceVariant")) else "Drawing...", rarity, inline)
		buildLooks()
	end
	ctx.onAttribute("Race", function(_, changed: boolean)
		if changed then
			-- a new race starts on its own defaults
			state:set("RaceLook", registry.lookPicks(raceId(), nil))
		end
		paintRace()
	end)
	ctx.onAttribute("RaceVariant", paintRace)

	local clan = components.fateRow(page, "ClanRow", base + 20)
	clan.setPrice(defs.Products.RerollSurname.RobuxPrice)
	clan.setPaid(paid)
	ctx.onAttribute("Surname", function(key: string?)
		local def = key and defs.Surnames[key]
		clan.set("Clan", if def then def.DisplayName else "Drawing...", def and defs.Rarities[def.Rarity], inline)
	end)
	clan.button.Activated:Connect(function()
		task.spawn(rerollFlow, ctx, clan, "Surname")
	end)

	local note = if opts and opts.note ~= nil
		then opts.note
		else "Your race and clan are drawn for this slot and stay with it. Looks are free to change."
	if type(note) == "string" then
		components.note(page, note, base + 21, "FateNote")
	end
	local link = components.link(page, "See the odds of every race and clan", base + 22, ctx.openOdds)

	state:onChanged(function(key)
		if key == "RaceLook" then
			paintLooks()
		end
	end)

	local handle = { link = link }
	function handle.reset()
		buildLooks()
		paintLooks()
	end
	return handle
end

return Fate
