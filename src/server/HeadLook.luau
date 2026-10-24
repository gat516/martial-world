--!strict
-- Where each player is looking, for everyone else's screen (docs/systems/combat.md,
-- HeadLook): the owner's client sends its head pitch and yaw over the Look remote
-- a few times a second, only when they change; this clamps them and puts them on
-- the character as one attribute, Look = Vector2(pitch, yaw) in radians, which
-- every other client eases its copy of that head toward. Cosmetic only: nothing
-- in combat or aiming reads it. Pattern from the husspotato7 reference.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MAX_RATE = 8 -- writes per second per player at most (clients send at most 5)
local MAX_PITCH = math.rad(55)
local MAX_YAW = math.rad(100)
local STEP = 0.02 -- radians: the attribute is rounded to this, so tiny jitters don't replicate

local HeadLook = {}

local lastAt: { [Player]: number } = {}

local function onLook(player: Player, pitch: any, yaw: any)
	if typeof(pitch) ~= "number" or typeof(yaw) ~= "number" or pitch ~= pitch or yaw ~= yaw then
		return
	end
	local now = os.clock()
	if now - (lastAt[player] or 0) < 1 / MAX_RATE then
		return
	end
	lastAt[player] = now
	local character = player.Character
	if not character then
		return
	end
	local p = math.floor(math.clamp(pitch, -MAX_PITCH, MAX_PITCH) / STEP + 0.5) * STEP
	local y = math.floor(math.clamp(yaw, -MAX_YAW, MAX_YAW) / STEP + 0.5) * STEP
	character:SetAttribute("Look", Vector2.new(p, y))
end

function HeadLook.start()
	(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Look") :: RemoteEvent).OnServerEvent:Connect(onLook)
	Players.PlayerRemoving:Connect(function(player)
		lastAt[player] = nil
	end)
end

return HeadLook
