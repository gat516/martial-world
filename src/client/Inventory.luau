--!strict
-- The Inventory window, with a tab each for herbs (eat them) and arts (every
-- technique you own, its level and XP, and a button to equip it into a free
-- slot or unequip it). Technique names live here; the HUD slots show only icons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Hud = require(script.Parent.Hud)
local ListWindow = require(script.Parent.ListWindow)
local State = require(script.Parent.State)

local inventoryRemote = ReplicatedStorage.Remotes.InventoryAction :: RemoteFunction
local techniqueRemote = ReplicatedStorage.Remotes.TechniqueAction :: RemoteFunction

type Tab = "Herbs" | "Arts"

local TAB_ON = { fill = Color3.fromRGB(232, 192, 92), text = Color3.fromRGB(16, 24, 28) }
local TAB_OFF = { fill = Color3.fromRGB(24, 34, 38), text = Color3.fromRGB(160, 182, 176) }
local EMPTY: { [Tab]: string } = {
	Herbs = "Your pouch is empty. Harvest herbs from your beds.",
	Arts = "You know no arts yet. Beasts in the wilds sometimes drop manuals.",
}

local Inventory = {}

local window: Frame
local tabButtons: { [Tab]: TextButton } = {}
local tab: Tab = "Herbs"

local function herbRows(): { ListWindow.Row }
	local rows: { ListWindow.Row } = {}
	for _, id in Herbs.Order do
		local count = State.current.herbs[id] or 0
		if count > 0 then
			local herb = Herbs.Defs[id]
			table.insert(rows, {
				color = herb.color,
				name = herb.name,
				detail = herb.blurb,
				count = count,
				buttonText = "Eat",
				onPress = function()
					local _, message = inventoryRemote:InvokeServer("eat", id)
					if message then
						Hud.toast(message)
					end
				end,
			})
		end
	end
	return rows
end

local function artRows(): { ListWindow.Row }
	local s = State.current.techniques
	local rows: { ListWindow.Row } = {}
	for _, id in Techniques.Order do
		local owned = s.owned[id]
		if owned then
			local def = Techniques.Defs[id]
			local slot = table.find(s.slots, id)
			local xp = if owned.level >= Techniques.MAX_LEVEL
				then "max level"
				else `{owned.xp}/{Techniques.xpToNext(owned.level)} xp`
			table.insert(rows, {
				color = def.color,
				name = if slot then `{def.name}  [{slot}]` else def.name,
				detail = `{def.blurb}  ({xp}, {def.cooldown}s)`,
				count = owned.level,
				countText = `Lv {owned.level}`,
				buttonText = if slot then "Unequip" else "Equip",
				onPress = function()
					local ok, message = techniqueRemote:InvokeServer(if slot then "unequip" else "equip", id)
					if not ok and message then
						Hud.toast(message)
					end
				end,
			})
		end
	end
	return rows
end

local function render()
	for name, button in tabButtons do
		local style = if name == tab then TAB_ON else TAB_OFF
		button.BackgroundColor3 = style.fill
		button.TextColor3 = style.text
	end
	local rows = if tab == "Herbs" then herbRows() else artRows()
	ListWindow.fill(window, "ItemTemplate", "EatButton", rows)
	local empty = window:FindFirstChild("Empty") :: TextLabel
	empty.Text = EMPTY[tab]
	empty.Visible = #rows == 0
end

function Inventory.init(gui: ScreenGui)
	window = gui:FindFirstChild("Inventory") :: Frame
	ListWindow.bindClose(window)
	local tabs = window:FindFirstChild("Tabs") :: Frame
	for _, name: Tab in { "Herbs" :: Tab, "Arts" :: Tab } do
		local button = tabs:FindFirstChild(`{name}Tab`) :: TextButton
		tabButtons[name] = button
		button.Activated:Connect(function()
			tab = name
			render()
		end)
	end
	local button = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("InventoryButton") :: TextButton
	button.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			render()
		end
	end)
	State.onChanged(function()
		if window.Visible then
			render()
		end
	end)
end

return Inventory
