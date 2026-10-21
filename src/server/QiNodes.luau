--!strict
-- Qi nodes in the wilds (parts tagged "QiNode" with a GatherPrompt): holding the
-- prompt pours raw qi into the dantian (and drops a few Spirit Stones), once per node per player every so often.
-- Circulation runs are also allowed within a node's Radius (see Circulation.luau).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config).Economy
local Income = require(ReplicatedStorage.Shared.Pacing).Income
local Realms = require(ReplicatedStorage.Shared.Realms)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

-- node -> player -> os.clock() of their last gather
local gathered: { [Instance]: { [Player]: number } } = {}

local QiNodes = {}

local function gather(node: BasePart, player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local byPlayer = gathered[node] or {}
	gathered[node] = byPlayer
	local now = os.clock()
	local wait = Income.NODE_COOLDOWN - (now - (byPlayer[player] or -math.huge))
	if wait > 0 then
		Cultivation.notify(player, `This node's qi is still gathering ({math.ceil(wait)}s).`)
		return
	end
	local stage = Cultivation.stage(data)
	local room = stage.dantian - data.rawQi
	if room <= 0 then
		Cultivation.notify(player, "Your dantian is full. Circulate to refine it.")
		return
	end
	byPlayer[player] = now
	local amount = math.min(room, math.floor(Realms.nodeQi(stage) * Cultivation.methodSpeed(data) + 0.5))
	data.rawQi += amount
	local stones = math.random(Economy.NODE_STONES[1], Economy.NODE_STONES[2])
	data.stones += stones
	Cultivation.markActive(player)
	Cultivation.pushState(player)
	effectRemote:FireClient(player, "qi", node.Position, amount)
	effectRemote:FireClient(player, "stones", node.Position + Vector3.new(0, 2, 0), stones)
end

local function watch(node: Instance)
	if not node:IsA("BasePart") then
		return
	end
	local prompt = node:FindFirstChild("GatherPrompt") :: ProximityPrompt?
	if prompt then
		-- Gathering is F everywhere, like herb beds, and drawn by the client's
		-- WorldPrompts. TODO: set both on the node prompts in assets/Wilds.rbxmx
		-- (it has uncommitted edits right now) and drop these lines.
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.Triggered:Connect(function(player)
			gather(node, player)
		end)
	end
end

function QiNodes.start()
	for _, node in CollectionService:GetTagged("QiNode") do
		watch(node)
	end
	CollectionService:GetInstanceAddedSignal("QiNode"):Connect(watch)
end

function QiNodes.forget(player: Player)
	for _, byPlayer in gathered do
		byPlayer[player] = nil
	end
end

return QiNodes
