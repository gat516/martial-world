--!strict
-- Confirm tab: a summary of every choice and the Enter World button, dimmed
-- with the reason while something (the first name) still blocks it.

local Confirm = {}

local function find(list: { any }, id: any): any
	for _, entry in list do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

function Confirm.build(page: ScrollingFrame, ctx: any)
	local state, defs, components = ctx.state, ctx.defs, ctx.components
	local rules = defs.Rules
	local player = ctx.player

	components.sectionHeader(page, "Your Character", 1)
	local rows = {}
	for order, key in { "Shirt", "Pants", "Hair ID", "Hair Color", "Race", "First Name", "Last Name" } do
		rows[key] = components.summaryRow(page, key, 1 + order)
	end
	local reason = components.note(page, "", 20, "Reason")
	reason.TextColor3 = ctx.theme.Color.Lacquer
	local enter = components.bigButton(page, "EnterWorld", "Enter World", 21)

	local busy = false
	local blocked: string? = nil
	local function refresh()
		local shirt = find(defs.Clothing.Shirt, state:get("Shirt"))
		local pants = find(defs.Clothing.Pants, state:get("Pants"))
		local color = find(defs.HairColors, state:get("HairColor"))
		local hairId = state:get("HairId")
		local race = defs.Races[player:GetAttribute("Race") or ""]
		local surname = defs.Surnames[player:GetAttribute("Surname") or ""]
		local name, why = rules.checkFirstName(state:get("FirstName"))

		rows.Shirt.set(if shirt then shirt.DisplayName else "-")
		rows.Pants.set(if pants then pants.DisplayName else "-")
		rows["Hair ID"].set(if hairId then tostring(hairId) else "None")
		rows["Hair Color"].set(if color then color.DisplayName else "-", color and color.Color)
		rows.Race.set(if race then race.DisplayName else "...", nil, race and race.Rarity, defs.Rarities)
		rows["First Name"].set(name or "Not chosen")
		rows["Last Name"].set(if surname then surname.DisplayName else "...", nil, surname and surname.Rarity, defs.Rarities)

		blocked = if not name
			then `First name: {why}. Set it on the Identity tab.`
			elseif not race or not surname then "Waiting for your race and family name..."
			else nil
		if not busy then
			reason.Text = blocked or ""
			enter.setEnabled(blocked == nil)
		end
	end
	refresh()
	state:onChanged(refresh)
	ctx.onAttribute("Race", refresh)
	ctx.onAttribute("Surname", refresh)

	enter.button.Activated:Connect(function()
		if busy then
			return
		end
		if blocked then
			ctx.gotoTab("Identity")
			return
		end
		busy = true
		enter.setLabel("Entering...")
		enter.setEnabled(false)
		local ok, message = ctx.enterWorld()
		busy = false
		enter.setLabel("Enter World")
		if not ok then
			refresh()
			reason.Text = if type(message) == "string" then message else "Something went wrong. Try again."
		else
			refresh()
		end
	end)
end

return Confirm
