--!strict
-- The game's own walk (ReplicatedStorage.Animations.Walk, user 2026-10-24) in
-- place of Roblox's default walk. It's swapped into the default Animate script's
-- `walk` entry on every spawn, so Animate keeps doing what it already does: idle,
-- the walk with its speed scaling, jumps, falls, climbing and sitting, and the
-- blends between them. Nothing else changes:
--   - running is Sprint's own Run track (Movement priority, over the walk);
--   - a weapon class with its own Walk clip (Greatsword, Guandao, Spear, Staff)
--     still lays it over this one (WeaponAnimator); Fist, Sword and Saber use it;
--   - attacks, casts, dodges and the guard play at Action priority, above all of it.
-- The owner's client changes its own Animate; the tracks it plays replicate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local BaseWalk = {}

local function apply(character: Model)
	local walk = (ReplicatedStorage:WaitForChild("Animations") :: Folder):FindFirstChild("Walk")
	if not (walk and walk:IsA("Animation") and walk.AnimationId ~= "") then
		return
	end
	local animate = character:WaitForChild("Animate", 10)
	local entry = animate and animate:WaitForChild("walk", 10)
	if not entry or player.Character ~= character then
		return
	end
	-- Animate reloads an entry when one of its Animations changes
	for _, animation in entry:GetChildren() do
		if animation:IsA("Animation") and animation.AnimationId ~= walk.AnimationId then
			animation.AnimationId = walk.AnimationId
		end
	end
end

function BaseWalk.init()
	player.CharacterAdded:Connect(apply)
	if player.Character then
		task.spawn(apply, player.Character)
	end
end

return BaseWalk
