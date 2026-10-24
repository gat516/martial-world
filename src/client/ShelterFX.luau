--!strict
-- The party shelter's qi thread (docs/systems/combat.md "Realm pressure"): a faint
-- jade stream flowing from the stronger member (the patron) to the player they
-- shelter, shown while the sheltered one is in combat. Every client draws every pair
-- it sees. Reads the server's player attributes ShelteredBy (the patron's UserId) and
-- InCombat.
-- Physical, never camera-facing (docs/reference/approved/README.md, rejected list):
-- two ribbons of the onboarding guide's Stream beam (ReplicatedStorage.Effects.Guide.
-- Stream) crossed along the line between the two chests, one lying flat and one
-- standing, so it reads as a thin cord from any side. Their attachments sit in
-- Terrain and are re-aimed every frame along the line (attached to the root parts,
-- the ribbons would twist as the characters turn). Thin, mostly transparent, faded
-- out at both bodies and only flowing, so it's a thread of qi, not a laser. All of it
-- is short-lived runtime clones, gone when the shelter or the fight ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShelterFX = {}

local POLL = 0.25 -- seconds between checks of who shelters whom
local CHEST = Vector3.new(0, 0.6, 0) -- above the root part, about the heart
local WIDTH = 0.32
local SPEED = 0.6 -- texture flow, patron toward the sheltered (studs/s per TextureLength)
local TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.15, 0.72),
	NumberSequenceKeypoint.new(0.5, 0.6),
	NumberSequenceKeypoint.new(0.85, 0.72),
	NumberSequenceKeypoint.new(1, 1),
})
local JADE = ColorSequence.new(Color3.fromRGB(150, 240, 196), Color3.fromRGB(120, 226, 180))

type Thread = {
	patron: Player,
	from: BasePart, -- the patron's root
	to: BasePart, -- the sheltered player's root
	parts: { Instance },
	pairs: { { a0: Attachment, a1: Attachment, standing: boolean } },
}
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
		for _, inst in t.parts do
			inst:Destroy()
		end
	end
end

-- An attachment's X axis is where a beam's width does not go: up for the flat
-- ribbon, sideways for the standing one.
local function aim(t: Thread)
	local a, b = t.from.Position + CHEST, t.to.Position + CHEST
	local along = b - a
	if along.Magnitude < 0.05 then
		return
	end
	along = along.Unit
	local side = along:Cross(Vector3.yAxis)
	side = if side.Magnitude > 0.05 then side.Unit else Vector3.xAxis
	for _, p in t.pairs do
		local x = if p.standing then side else Vector3.yAxis
		local frame = CFrame.fromMatrix(Vector3.zero, x, along:Cross(x).Unit)
		p.a0.WorldCFrame = frame + a
		p.a1.WorldCFrame = frame + b
	end
end

local function make(player: Player, patron: Player, from: BasePart, to: BasePart): Thread?
	local source = template()
	if not source then
		return nil
	end
	local t: Thread = { patron = patron, from = from, to = to, parts = {}, pairs = {} }
	for _, standing in { false, true } do
		local a0 = Instance.new("Attachment")
		a0.Name = "ShelterThread"
		a0.Parent = workspace.Terrain
		local a1 = Instance.new("Attachment")
		a1.Name = "ShelterThread"
		a1.Parent = workspace.Terrain
		local beam = source:Clone()
		beam.Name = "ShelterThread"
		beam.FaceCamera = false
		beam.Width0, beam.Width1 = WIDTH, WIDTH
		beam.Transparency = TRANSPARENCY
		beam.Color = JADE
		beam.TextureSpeed = SPEED
		beam.CurveSize0, beam.CurveSize1 = 0, 0
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Enabled = true
		beam.Parent = a0
		table.insert(t.pairs, { a0 = a0, a1 = a1, standing = standing })
		table.insert(t.parts, a0)
		table.insert(t.parts, a1)
	end
	aim(t)
	return t
end

local function update()
	for _, player in Players:GetPlayers() do
		local id = player:GetAttribute("ShelteredBy")
		local patron = if type(id) == "number" and player:GetAttribute("InCombat") == true
			then Players:GetPlayerByUserId(id)
			else nil
		local to, from = rootOf(player), patron and rootOf(patron)
		local t = threads[player]
		if not (patron and from and to) then
			drop(player)
		elseif not t or t.patron ~= patron or t.from ~= from or t.to ~= to then
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
	RunService.RenderStepped:Connect(function()
		for _, t in threads do
			aim(t)
		end
	end)
end

return ShelterFX
