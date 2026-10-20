--!strict
-- The teleport formation menu: your peak, the main peak, or the sect gate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = require(script.Parent.Hud)
local ListWindow = require(script.Parent.ListWindow)

local remote = ReplicatedStorage.Remotes.TravelAction :: RemoteFunction

local TravelMenu = {}

function TravelMenu.init(gui: ScreenGui)
	local window = gui:FindFirstChild("TravelMenu") :: Frame
	ListWindow.bindClose(window)
	local button = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("TravelButton") :: TextButton
	button.Activated:Connect(function()
		window.Visible = not window.Visible
	end)
	local list = window:FindFirstChild("List") :: Frame
	for _, where in { "Peak", "MainPeak", "SectGate" } do
		local destination = list:FindFirstChild(where) :: TextButton
		destination.Activated:Connect(function()
			local ok, message = remote:InvokeServer(where)
			if ok then
				window.Visible = false
			elseif message then
				Hud.toast(message)
			end
		end)
	end
end

return TravelMenu
