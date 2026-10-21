--!strict
-- The teleport formation menu. The Travel button shows only once the elder has
-- taught the formation and while you stand on a teleport array (Shared.Gates);
-- stepping off closes the menu. Every button in the menu's List named after a
-- gate id travels there; the array you're standing on hides its own button.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gates = require(ReplicatedStorage.Shared.Gates)
local Hud = require(script.Parent.Hud)
local ListWindow = require(script.Parent.ListWindow)
local Menus = require(script.Parent.Menus)
local MyPeak = require(script.Parent.MyPeak)

local remote = ReplicatedStorage.Remotes.TravelAction :: RemoteFunction
local player = Players.LocalPlayer

local CHECK_SECONDS = 0.25

local TravelMenu = {}

local taught = false

-- The gate id of the array the character stands on, or nil. Someone else's peak
-- array counts as an array but not as "Peak" (that one still takes you home).
local function standingOn(): (boolean, string?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, nil
	end
	for _, tagged in CollectionService:GetTagged(Gates.TAG) do
		if Gates.on(tagged, root.Position) then
			local id = tagged:GetAttribute("Gate")
			if id == "Peak" and not MyPeak.owns(tagged.Parent) then
				return true, nil
			end
			return true, if typeof(id) == "string" then id else nil
		end
	end
	return false, nil
end

-- Onboarding calls this with the server's word on whether travel is taught.
function TravelMenu.setTaught(on: boolean)
	taught = on
end

function TravelMenu.init(gui: ScreenGui)
	local window = gui:FindFirstChild("TravelMenu") :: Frame
	Menus.register(window)
	ListWindow.bindClose(window)
	local button = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("TravelButton") :: TextButton
	button.Visible = false
	button.Activated:Connect(function()
		Menus.toggle(window)
	end)
	local list = window:FindFirstChild("List") :: Frame
	local buttons: { [string]: GuiButton } = {}
	for _, gate in Gates.List do
		local destination = list:FindFirstChild(gate.id) :: GuiButton?
		if destination then
			buttons[gate.id] = destination
			destination.Activated:Connect(function()
				local ok, message = remote:InvokeServer(gate.id)
				if ok then
					Menus.close(window)
				elseif message then
					Hud.toast(message)
				end
			end)
		end
	end

	task.spawn(function()
		while true do
			local on, here = false, nil
			if taught then
				on, here = standingOn()
			end
			button.Visible = on
			if not on and window.Visible then
				Menus.close(window)
			end
			for id, destination in buttons do
				destination.Visible = id ~= here
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return TravelMenu
