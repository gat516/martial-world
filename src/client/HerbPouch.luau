--!strict
-- The herb pouch: harvested herbs, each with an Eat button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Hud = require(script.Parent.Hud)
local ListWindow = require(script.Parent.ListWindow)
local State = require(script.Parent.State)

local inventoryRemote = ReplicatedStorage.Remotes.InventoryAction :: RemoteFunction

local HerbPouch = {}

local window: Frame

local function render()
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
				onPress = function()
					local _, message = inventoryRemote:InvokeServer("eat", id)
					if message then
						Hud.toast(message)
					end
				end,
			})
		end
	end
	ListWindow.fill(window, "ItemTemplate", "EatButton", rows)
	if #rows == 0 and window.Visible then
		Hud.toast("Your pouch is empty. Harvest herbs from your beds.")
	end
end

function HerbPouch.init(gui: ScreenGui)
	window = gui:FindFirstChild("Bag") :: Frame
	ListWindow.bindClose(window)
	local button = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("BagButton") :: TextButton
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

return HerbPouch
