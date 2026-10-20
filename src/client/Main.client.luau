--!strict
-- Client entry: wires the HUD, herb pouch, seed picker, garden view and build mode.

local Players = game:GetService("Players")

local Hud = require(script.Parent.Hud)
local HerbPouch = require(script.Parent.HerbPouch)
local SeedPicker = require(script.Parent.SeedPicker)
local GardenView = require(script.Parent.GardenView)
local BuildMode = require(script.Parent.BuildMode)

local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Hud") :: ScreenGui

Hud.init(gui)
HerbPouch.init(gui)
SeedPicker.init(gui)
GardenView.init()
BuildMode.init(gui)
