--!strict
-- The party shelter's qi thread (docs/systems/combat.md "Realm pressure"): a faint
-- jade stream between a sheltered player and the stronger member sheltering them,
-- shown while the sheltered one is in combat. Every client draws every pair it sees.
-- Reads the server's player attributes ShelteredBy (the patron's UserId) and
-- InCombat. Reuses the onboarding guide's Stream beam
-- (ReplicatedStorage.Effects.Guide.Stream), stood up to face the camera; the
-- attachments and beam are short-lived runtime clones, gone when it ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShelterFX = {}

local POLL = 0.25 -- seconds between checks
local WIDTH = 0.35
local TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.85),
	NumberSequenceKeypoint.new(0.5, 0.6),
	NumberSequenceKeypoint.new(1, 0.85),
})

type Thread = { beam: Beam, a0: Attachment, a1: Attachment, patron: Player }
local threads: { [Player]: Thread } = {}

local function template(): Beam?
	local effects = ReplicatedStorage:FindFirstChild("Effects")
	local guide = effects and effects:FindFirstChild("Guide")
	local stream = guide and guide:FindFirstChild("Stream")
	return if stream and stream:IsA("Beam") then stream else nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0) then
		return nil
	end
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function drop(player: Player)
	local t = threads[player]
	if t then
		threads[player] = nil
		t.beam:Destroy()
		t.a0:Destroy()
		t.a1:Destroy()
	end
end

local function make(player: Player, patron: Player, from: BasePart, to: BasePart): Thread?
	local source = template()
	if not source then
		return nil
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "ShelterThread"
	a0.Parent = from
	local a1 = Instance.new("Attachment")
	a1.Name = "ShelterThread"
	a1.Parent = to
	local beam = source:Clone()
	beam.Name = "ShelterThread"
	beam.FaceCamera = true
	beam.Width0, beam.Width1 = WIDTH, WIDTH
	beam.Transparency = TRANSPARENCY
	beam.CurveSize0, beam.CurveSize1 = 2, -2
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Enabled = true
	beam.Parent = from
	return { beam = beam, a0 = a0, a1 = a1, patron = patron }
end

local function update()
	for _, player in Players:GetPlayers() do
		local id = player:GetAttribute("ShelteredBy")
		local patron = if type(id) == "number" and player:GetAttribute("InCombat") == true
			then Players:GetPlayerByUserId(id)
			else nil
		local from, to = rootOf(player), patron and rootOf(patron)
		local t = threads[player]
		if not (patron and from and to) then
			drop(player)
		elseif not t or t.patron ~= patron or t.a0.Parent ~= from or t.a1.Parent ~= to then
			drop(player)
			threads[player] = make(player, patron, from, to)
		end
	end
	for player in threads do
		if not player.Parent then
			drop(player)
		end
	end
end

function ShelterFX.init()
	task.spawn(function()
		while true do
			task.wait(POLL)
			update()
		end
	end)
end

return ShelterFX
