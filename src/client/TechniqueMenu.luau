--!strict
-- The Arts window: every technique you own, its level and XP, and a button to
-- equip it into a free slot or unequip it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Hud = require(script.Parent.Hud)
local ListWindow = require(script.Parent.ListWindow)
local State = require(script.Parent.State)

local remote = ReplicatedStorage.Remotes.TechniqueAction :: RemoteFunction

local TechniqueMenu = {}

local window: Frame

local function render()
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
					local ok, message = remote:InvokeServer(if slot then "unequip" else "equip", id)
					if not ok and message then
						Hud.toast(message)
					end
				end,
			})
		end
	end
	ListWindow.fill(window, "ItemTemplate", "EatButton", rows)
end

function TechniqueMenu.init(gui: ScreenGui)
	window = gui:FindFirstChild("Techniques") :: Frame
	ListWindow.bindClose(window)
	local button = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("ArtsButton") :: TextButton
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

return TechniqueMenu
