--!strict
-- The shared character-creator config (ReplicatedStorage.Shared.CharacterCreator),
-- gathered in one table so every client module reads it the same way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CC = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterCreator")

return {
	Rarities = require(CC:WaitForChild("Rarities")),
	-- races, variants and traits: Shared.Identity (Registry reads all of it)
	Races = require(ReplicatedStorage.Shared:WaitForChild("Identity"):WaitForChild("Races")),
	Registry = require(ReplicatedStorage.Shared:WaitForChild("Identity"):WaitForChild("Registry")),
	Surnames = require(CC:WaitForChild("Surnames")),
	Clothing = require(CC:WaitForChild("Clothing")),
	HairColors = require(CC:WaitForChild("HairColors")),
	SkinColors = require(CC:WaitForChild("SkinColors")),
	Products = require(CC:WaitForChild("Products")),
	Background = require(CC:WaitForChild("Background")),
	Rules = require(CC:WaitForChild("Rules")),
}
