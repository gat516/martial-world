--!strict
-- The game is R6 only, which the published experiences set in Game Settings. A local,
-- unpublished place (the test build, agent sandboxes) has no experience settings and
-- spawns R15, so there an R6 StarterCharacter stands in. Avatar clothes and accessories
-- still load onto it (StarterPlayer.LoadCharacterAppearance).

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

if game.PlaceId ~= 0 or StarterPlayer:FindFirstChild("StarterCharacter") then
	return
end

local rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
rig.Name = "StarterCharacter"
rig.Parent = StarterPlayer

-- anyone who spawned before this ran is still R15
for _, player in Players:GetPlayers() do
	if player.Character then
		task.spawn(player.LoadCharacter, player)
	end
end
