--!strict
-- Testbed only: a stand-in player next to the spawn pad, so a lone tester can
-- see how another player looks (its namecard, docs/systems/nameplates.md). An
-- R6 body built from a HumanoidDescription, in the ranger outfit, anchored in
-- place, tagged NameplateTarget with a first name, last name and a title.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clothing = require(ReplicatedStorage.Shared.CharacterCreator.Clothing)

local SPOT = CFrame.new(10, 652.6, 32) * CFrame.Angles(0, math.rad(200), 0) -- beside the spawn pad, facing it
local NAME = { FirstName = "Wei", Surname = "Li", Title = "Disciple of the Azure Peak" }

local TestbedDummy = {}

function TestbedDummy.start()
	local description = Instance.new("HumanoidDescription")
	local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType.R6)
	description:Destroy()
	if not ok or not model then
		warn("TestbedDummy: couldn't build the stand-in", model)
		return
	end
	local dummy = model :: Model
	dummy.Name = "Test Disciple"
	local shirt = Instance.new("Shirt")
	shirt.ShirtTemplate = Clothing.Shirt[1].Template or ""
	shirt.Parent = dummy
	local pants = Instance.new("Pants")
	pants.PantsTemplate = Clothing.Pants[1].Template or ""
	pants.Parent = dummy
	for key, value in NAME do
		dummy:SetAttribute(key, value)
	end
	local root = dummy:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true
	end
	dummy:PivotTo(SPOT)
	dummy:AddTag("NameplateTarget")
	dummy.Parent = workspace
end

return TestbedDummy
