--!strict
-- Where world events and heavenly treasures land: a random spot on open ground in
-- one of the wilds' event grounds (Workspace.Wilds.EventGrounds: flat clearings kept
-- free of trees and rocks, each a disc with a Radius attribute; docs/systems/map.md).
-- Falls back to the beast zones (Wilds.Zones) only if no event ground exists. Never
-- on water.
--
-- No dependencies on purpose: Edit-mode previews (tools/worldfx_preview.luau)
-- require this module to place effects through the same code path the game uses.
-- Treasures.randomSpot re-exports it for the event kinds.

local EventGrounds = {}

local function discs(wilds: Instance, folderName: string): { BasePart }
	local list = {}
	local folder = wilds:FindFirstChild(folderName)
	for _, disc in (if folder then folder:GetChildren() else {}) do
		if disc:IsA("BasePart") then
			table.insert(list, disc)
		end
	end
	return list
end

-- A ground point (raycast hit) within 0.9 of a random ground's radius, or nil after
-- 8 misses. `rng` lets previews pick reproducible spots.
function EventGrounds.randomSpot(rng: Random?): Vector3?
	local wilds = workspace:FindFirstChild("Wilds")
	if not wilds then
		return nil
	end
	local grounds = discs(wilds, "EventGrounds")
	if #grounds == 0 then
		grounds = discs(wilds, "Zones")
	end
	if #grounds == 0 then
		return nil
	end
	local function roll(): number
		return if rng then rng:NextNumber() else math.random()
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { grounds[1].Parent :: Instance, wilds:FindFirstChild("Enemies") :: Instance }
	for _ = 1, 8 do
		local ground = grounds[math.clamp(math.floor(roll() * #grounds) + 1, 1, #grounds)]
		local radius = ((ground:GetAttribute("Radius") :: number?) or 20) * 0.9
		local a, r = roll() * math.pi * 2, math.sqrt(roll()) * radius
		local at = ground.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local hit = workspace:Raycast(at + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), params)
		if hit and hit.Material ~= Enum.Material.Water then
			return hit.Position
		end
	end
	return nil
end

return EventGrounds
