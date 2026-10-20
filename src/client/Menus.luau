--!strict
-- Clears the gameplay HUD while a menu or minigame has the screen, and brings it
-- back when it closes. The HUD pieces scripts show and hide on their own (touch
-- buttons, buffs, objective, elder line) live in the Play frame, so hiding that
-- frame never fights them.
--   Inventory: hides Play and the vitals; the hotbar stays to take drops.
--   Other windows and build mode: hide Play and the whole bottom stack.
--   The circulation minigame: also hides the top-right tiles.

local Menus = {}

local WINDOWS = { "SeedPicker", "TravelMenu", "QuestBoardWindow", "BuildBar" }

function Menus.init(gui: ScreenGui)
	local play = gui:FindFirstChild("Play") :: Frame
	local stack = gui:FindFirstChild("Stack") :: Frame
	local vitals = stack:FindFirstChild("Vitals") :: Frame
	local tiles = gui:FindFirstChild("Buttons") :: Frame
	local inventory = gui:FindFirstChild("Inventory") :: Frame
	local minigame = gui:FindFirstChild("Circulation") :: Frame

	local function update()
		local window = false
		for _, name in WINDOWS do
			local frame = gui:FindFirstChild(name) :: GuiObject?
			if frame and frame.Visible then
				window = true
			end
		end
		local playing = minigame.Visible
		local any = window or playing or inventory.Visible
		play.Visible = not any
		stack.Visible = not (window or playing)
		vitals.Visible = not any
		tiles.Visible = not playing
	end

	for _, name in { "Inventory", "Circulation", table.unpack(WINDOWS) } do
		local frame = gui:FindFirstChild(name) :: GuiObject?
		if frame then
			frame:GetPropertyChangedSignal("Visible"):Connect(update)
		end
	end
	update()
end

return Menus
