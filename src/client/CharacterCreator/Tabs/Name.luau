--!strict
-- Name step (Identity when editing): the first name, then the race and clan the
-- server drew for this slot (the player's Race and Surname attributes), each
-- with a paid Change, and a link to the odds of every race and clan.
-- The first name is the one required field of a new character, so Enter World
-- sits right under it in the footer. Once a slot is named the name is locked
-- (edit shows it read-only); rerolls still work there.

local MarketplaceService = game:GetService("MarketplaceService")

local Name = {}

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

function Name.build(page: ScrollingFrame, ctx: any)
	local state, defs, components = ctx.state, ctx.defs, ctx.components
	local rules = defs.Rules
	local locked = false

	components.section(page, "First name", 1)
	local field = components.textField(page, {
		name = "FirstNameField",
		placeholder = "Choose a first name",
		order = 2,
		counter = true,
	})
	local box: TextBox = field.input
	local max = rules.FIRST_NAME.MAX
	local function validate()
		local text = box.Text
		field.counter.Text = if locked then "" else `{utf8.len(text) or #text}/{max}`
		if locked then
			field.setStatus("A cultivator's name is set once.", "info")
			field.setNeed(false)
			return
		end
		if text:match("^%s*$") then
			field.setStatus(`Required: {rules.FIRST_NAME.MIN} to {max} letters.`, "need")
			field.setNeed(true)
			return
		end
		local name, why = rules.checkFirstName(text)
		if name then
			local family = defs.Surnames[ctx.player:GetAttribute("Surname") or ""]
			field.setStatus(`You will be known as {if family then family.DisplayName .. " " else ""}{name}.`, "ok")
			field.setNeed(false)
		else
			field.setStatus(why, "error")
			field.setNeed(true)
		end
	end
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if locked then
			return
		end
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
	-- Enter World with the name missing brings the player here
	ctx.registerField("FirstName", function()
		page.CanvasPosition = Vector2.zero
		if not ctx.isTouch then
			box:CaptureFocus()
		end
	end)

	components.section(page, "Fate", 3)
	local race = components.fateRow(page, "RaceRow", 4)
	race.setPrice(defs.Products.RerollRace.RobuxPrice)
	ctx.onAttribute("Race", function(key: string?)
		local def = key and defs.Races[key]
		race.set("Race", if def then def.DisplayName else "Drawing...", def and defs.Rarities[def.Rarity])
		validate()
	end)
	race.button.Activated:Connect(function()
		task.spawn(rerollFlow, ctx, race, "Race")
	end)

	local clan = components.fateRow(page, "ClanRow", 5)
	clan.setPrice(defs.Products.RerollSurname.RobuxPrice)
	ctx.onAttribute("Surname", function(key: string?)
		local def = key and defs.Surnames[key]
		clan.set("Clan", if def then def.DisplayName else "Drawing...", def and defs.Rarities[def.Rarity])
		validate()
	end)
	clan.button.Activated:Connect(function()
		task.spawn(rerollFlow, ctx, clan, "Surname")
	end)

	components.note(page, "Your race and clan are drawn for this slot and stay with it.", 6, "FateNote")
	components.link(page, "See the odds of every race and clan", 7, ctx.openOdds)

	local handle = {}
	-- mode "new": an empty, required field; "edit": the slot's name, locked
	function handle.reset(mode: string, firstName: string?)
		locked = mode == "edit"
		field.setLocked(locked)
		box.Text = if locked then firstName or "" else ""
		validate()
	end
	return handle
end

return Name
