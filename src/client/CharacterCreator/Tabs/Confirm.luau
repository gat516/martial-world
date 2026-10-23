--!strict
-- Confirm tab: a summary of every choice. A row still missing (the first name)
-- reads "Not chosen" in lacquer and opens that field when pressed. Enter World
-- is the footer's primary button on this step (Controller).

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
	for order, key in { "Shirt", "Pants", "Skin", "Hair ID", "Hair Color", "Race", "First Name", "Last Name" } do
		rows[key] = components.summaryRow(page, key, 1 + order)
	end
	local function refresh()
		local shirt = find(defs.Clothing.Shirt, state:get("Shirt"))
		local pants = find(defs.Clothing.Pants, state:get("Pants"))
		local color = find(defs.HairColors, state:get("HairColor"))
		local hairIds = state:hairIds()
		local race = defs.Races[player:GetAttribute("Race") or ""]
		local surname = defs.Surnames[player:GetAttribute("Surname") or ""]
		local name = rules.checkFirstName(state:get("FirstName"))

		rows.Shirt.set(if shirt then shirt.DisplayName else "-")
		rows.Pants.set(if pants then pants.DisplayName else "-")
		local skin = find(defs.SkinColors, state:get("SkinColor"))
		rows.Skin.set(if skin then skin.DisplayName else "-", skin and skin.Color)
		rows["Hair ID"].set(if #hairIds > 0 then table.concat(hairIds, ", ") else "None")
		rows["Hair Color"].set(if color then color.DisplayName else "-", color and color.Color)
		rows.Race.set(if race then race.DisplayName else "...", nil, race and race.Rarity, defs.Rarities)
		rows["First Name"].set(name or "Not chosen")
		rows["First Name"].setWarn(name == nil)
		rows["Last Name"].set(if surname then surname.DisplayName else "...", nil, surname and surname.Rarity, defs.Rarities)
	end
	refresh()
	state:onChanged(refresh)
	ctx.onAttribute("Race", refresh)
	ctx.onAttribute("Surname", refresh)
	-- the missing row is a shortcut to the field
	rows["First Name"].root.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if not rules.checkFirstName(state:get("FirstName")) then
				ctx.showMissing()
			end
		end
	end)
end

return Confirm
