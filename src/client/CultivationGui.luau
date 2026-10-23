--!strict
-- The Cultivation ScreenGui (assets/Cultivation.rbxmx, docs/ui/cultivation.md):
-- the death-save prompt on a baseline canvas
-- (UiScale), plus templates that other screens clone (the foundation meter, the
-- Dao ring, technique tier frames, bloodline badges and the heaven mark).
-- Laid out at the desktop baseline (1920x1080); on a phone the canvas fits the
-- phone baseline (844x390) and every authored "Device" UIScale shrinks its
-- piece to PHONE_SCALE, which keeps its text at 11 px or more.

local Players = game:GetService("Players")

local UiScale = require(script.Parent.UiScale)

local PHONE_SCALE = 0.62

local CultivationGui = {}

local gui: ScreenGui? = nil

function CultivationGui.get(): ScreenGui
	local found = gui
	if found then
		return found
	end
	local screen = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Cultivation") :: ScreenGui
	gui = screen
	local canvas = screen:FindFirstChild("Canvas") :: Frame
	UiScale.fit(canvas)
	if UiScale.isPhone() then
		for _, inst in canvas:GetDescendants() do
			if inst:IsA("UIScale") and inst.Name == "Device" then
				inst.Scale = PHONE_SCALE
			end
		end
	end
	return screen
end

-- A piece on the canvas (DeathSave).
function CultivationGui.piece(name: string): Frame
	return (CultivationGui.get():FindFirstChild("Canvas") :: Frame):FindFirstChild(name) :: Frame
end

-- A fresh, visible clone of a template (Templates.<name>), not yet parented.
function CultivationGui.template(name: string): GuiObject
	local folder = CultivationGui.get():FindFirstChild("Templates") :: Folder
	local copy = (folder:FindFirstChild(name) :: GuiObject):Clone()
	copy.Visible = true
	return copy
end

return CultivationGui
