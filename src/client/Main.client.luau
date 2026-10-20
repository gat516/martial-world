--!strict
-- Client entry: wires the HUD, circulation minigame, breakthroughs, combat (with
-- telegraphs and enemy health bars), travel, the hotbar, the inventory
-- (items and arts), seed picker, garden view, build mode and meditation.

local Players = game:GetService("Players")

local Hud = require(script.Parent.Hud)
local CirculationMinigame = require(script.Parent.CirculationMinigame)
local BreakthroughView = require(script.Parent.BreakthroughView)
local CombatController = require(script.Parent.CombatController)
local TravelMenu = require(script.Parent.TravelMenu)
local Telegraphs = require(script.Parent.Telegraphs)
local EnemyBars = require(script.Parent.EnemyBars)
local EnemyAnimator = require(script.Parent.EnemyAnimator)
local Onboarding = require(script.Parent.Onboarding)
local DayNight = require(script.Parent.DayNight)
local WeatherFX = require(script.Parent.WeatherFX)
local HotbarView = require(script.Parent.HotbarView)
local Layout = require(script.Parent.Layout)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Inventory = require(script.Parent.Inventory)
local SeedPicker = require(script.Parent.SeedPicker)
local GardenView = require(script.Parent.GardenView)
local BuildMode = require(script.Parent.BuildMode)
local Meditation = require(script.Parent.Meditation)
local Rewards = require(script.Parent.Rewards)

local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Hud") :: ScreenGui

Hud.init(gui)
Menus.init(gui) -- before anything registers a window
Motion.buttons(gui)
for _, name in { "CultivatePrompt", "BreakthroughButton", "Toast", "ElderLine", "Objective" } do
	Motion.appear(gui:FindFirstChild(name, true) :: GuiObject)
end
CirculationMinigame.init(gui)
BreakthroughView.init(gui)
CombatController.init(gui)
TravelMenu.init(gui)
Telegraphs.init()
EnemyBars.init()
EnemyAnimator.init()
Onboarding.init(gui)
DayNight.init()
WeatherFX.init()
HotbarView.init(gui)
Layout.init(gui)
Inventory.init(gui)
SeedPicker.init(gui)
GardenView.init()
BuildMode.init(gui)
Meditation.init(gui)
Rewards.init()
