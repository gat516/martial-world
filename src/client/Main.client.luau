--!strict
-- Client entry: wires the HUD, circulation minigame, breakthroughs, combat (with
-- telegraphs and enemy health bars), travel, herb pouch,
-- seed picker, garden view and build mode.

local Players = game:GetService("Players")

local Hud = require(script.Parent.Hud)
local CirculationMinigame = require(script.Parent.CirculationMinigame)
local BreakthroughView = require(script.Parent.BreakthroughView)
local CombatController = require(script.Parent.CombatController)
local TravelMenu = require(script.Parent.TravelMenu)
local Telegraphs = require(script.Parent.Telegraphs)
local EnemyBars = require(script.Parent.EnemyBars)
local TechniqueMenu = require(script.Parent.TechniqueMenu)
local Onboarding = require(script.Parent.Onboarding)
local HerbPouch = require(script.Parent.HerbPouch)
local SeedPicker = require(script.Parent.SeedPicker)
local GardenView = require(script.Parent.GardenView)
local BuildMode = require(script.Parent.BuildMode)

local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Hud") :: ScreenGui

Hud.init(gui)
CirculationMinigame.init(gui)
BreakthroughView.init(gui)
CombatController.init(gui)
TravelMenu.init(gui)
Telegraphs.init()
EnemyBars.init()
TechniqueMenu.init(gui)
Onboarding.init(gui)
HerbPouch.init(gui)
SeedPicker.init(gui)
GardenView.init()
BuildMode.init(gui)
