--!strict
-- Onboarding (the scripted first ten minutes) and the quest board.
--
-- Onboarding is a list of beats, one system each. Each beat has a one-line elder
-- line, a short objective, and a condition checked every second; meeting it moves
-- the player to the next beat. Nothing blocks play, and players who are already
-- past a beat (repeat players) skip straight through. After the last beat the
-- objective shows the top quest board goal instead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hotbar = require(ReplicatedStorage.Shared.Hotbar)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)

local questRemote = ReplicatedStorage.Remotes.QuestState :: RemoteEvent

type Beat = {
	id: string,
	elder: string,
	objective: string,
	done: (Player, PlayerData.Data) -> boolean,
}

local function stageIndex(data: PlayerData.Data): number
	return Realms.index(data.realm.major, data.realm.minor)
end

local function slotted(data: PlayerData.Data): number
	return Hotbar.techniqueCount(data.hotbar)
end

local function nearGate(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local gate = Config.Travel.SECT_GATE
	-- at the gate, or anywhere past it in the wilds
	return (root.Position - gate).Magnitude < 120 or (root.Position.Z > gate.Z and root.Position.Y < 100)
end

local Quests = {}

-- Called with (player, beatIndex, beatId) when a beat is completed, for analytics.
Quests.onBeat = {} :: { (Player, number, string) -> () }

Quests.Beats = {
	{
		id = "Circulate",
		elder = "Welcome home, disciple. This peak is yours. Circulate the qi already stirring in your dantian.",
		objective = "Tap Cultivate, then Circulate, and guide your qi out of the maze",
		done = function(_, data)
			return data.stats.circulationRuns >= 1
		end,
	},
	{
		id = "Breakthrough",
		elder = "Good. Your meridians brim with qi. Sit in meditation and break through!",
		objective = "Fill your realm bar, then meditate and tap Break Through",
		done = function(_, data)
			return data.stats.breakthroughs >= 1
		end,
	},
	{
		id = "Gate",
		elder = "Your dantian is spent. Step onto a teleport array and ride it to the Sect Gate, then gather qi in the wilds.",
		objective = "Stand on a teleport array, tap Travel, then Sect Gate",
		done = function(player, _)
			return nearGate(player)
		end,
	},
	{
		id = "FirstKill",
		elder = "Spirit wolves prowl beyond the gate. Strike them, and dodge when the ground glows red.",
		objective = "Defeat a spirit wolf",
		done = function(_, data)
			return data.stats.kills >= 1
		end,
	},
	{
		id = "Technique",
		elder = "Every beast you slay teaches you something. Defeat a few more; a technique manual awaits.",
		objective = "Defeat 3 enemies to earn a technique manual",
		done = function(_, data)
			return slotted(data) >= 2
		end,
	},
	{
		id = "Refine",
		elder = "Your dantian swells. Refine that qi at a glowing qi node, or back on your peak.",
		objective = "Circulate at a qi node or on your peak",
		done = function(_, data)
			return data.stats.circulationRuns >= (data.onboardingMark or 0) + 1
		end,
	},
	{
		id = "QC3",
		elder = "First kills grant insight. You will need it to reach Foundation. Now break through again.",
		objective = "Reach Qi Condensation 3",
		done = function(_, data)
			return stageIndex(data) >= 3
		end,
	},
	{
		id = "FreePlay",
		elder = "You walk the path on your own now. The quest board on the main peak holds your next goals.",
		objective = "",
		done = function()
			return false
		end,
	},
} :: { Beat }

local FREE_PLAY = #Quests.Beats
assert(Quests.Beats[3].id == "Gate", "GATE_BEAT must point at the Gate beat")

-- The teleport formation unlocks when the elder points you to the gate.
local GATE_BEAT = 3
function Quests.travelUnlocked(data: PlayerData.Data): boolean
	return data.onboardingStep >= GATE_BEAT - 1
end

-- The quest board: what to aim for next, most pressing first.
export type Goal = { name: string, detail: string, progress: string }
function Quests.goals(data: PlayerData.Data): { Goal }
	local goals: { Goal } = {}
	local stage = Realms.get(data.realm.major, data.realm.minor)
	local nextStage = Realms.after(stage.major, stage.minor)
	if nextStage then
		local major = nextStage.major ~= stage.major
		if data.insight < stage.insight then
			table.insert(goals, {
				name = "Gather insight",
				detail = `Insight from first kills, the Elder Wolf King and kill milestones opens the way to {nextStage.name}.`,
				progress = `{data.insight}/{stage.insight}`,
			})
		end
		table.insert(goals, {
			name = if major then `Face the tribulation: {nextStage.name}` else `Break through to {nextStage.name}`,
			detail = if major
				then `Fill your bar, then survive {if stage.tribulation then stage.tribulation.seconds else 30} seconds of heavenly lightning on the main peak.`
				else "Circulate raw qi from the wilds to fill your realm bar.",
			progress = `{math.floor(data.cultivation)}/{stage.bar}`,
		})
	end
	if data.stats.bossKills == 0 then
		table.insert(goals, {
			name = "Slay the Elder Wolf King",
			detail = "He rules the far end of the wilds. His first defeat yields a technique manual and insight.",
			progress = "0/1",
		})
	end
	for _, m in Pacing.Rewards.MILESTONES do
		if not data.milestones[tostring(m.kills)] then
			local reward = if m.manual then Techniques.Defs[m.manual].name else "insight"
			table.insert(goals, {
				name = `Slay {m.kills} enemies`,
				detail = `Reward: {reward}{if m.insight and m.manual then " and insight" else ""}.`,
				progress = `{data.stats.kills}/{m.kills}`,
			})
			break
		end
	end
	for id, def in Enemies.Defs do
		if not def.boss and not data.firstKills[id] then
			table.insert(goals, {
				name = `First {def.name}`,
				detail = "The first kill of each kind of beast grants insight.",
				progress = "0/1",
			})
		end
	end
	local owned = 0
	for _ in data.techniques.owned do
		owned += 1
	end
	if owned < #Techniques.Order then
		table.insert(goals, {
			name = "Learn every technique",
			detail = "Manuals come from kill milestones and the Elder Wolf King.",
			progress = `{owned}/{#Techniques.Order}`,
		})
	end
	return goals
end

local lastSent: { [Player]: string } = {}

local function push(player: Player, data: PlayerData.Data, repeatElder: boolean?)
	local beat = Quests.Beats[data.onboardingStep + 1] or Quests.Beats[FREE_PLAY]
	local objective = beat.objective
	if beat.id == "FreePlay" then
		local top = Quests.goals(data)[1]
		objective = if top then `{top.name} ({top.progress})` else ""
	end
	local payload = {
		step = data.onboardingStep,
		beat = beat.id,
		elder = beat.elder,
		objective = objective,
		travel = Quests.travelUnlocked(data),
		goals = Quests.goals(data),
		repeatElder = repeatElder,
	}
	-- only send when something visible changed
	local key = `{payload.step}|{objective}|{#payload.goals}`
	if lastSent[player] ~= key or repeatElder then
		lastSent[player] = key
		questRemote:FireClient(player, payload)
	end
end

local function advance(player: Player, data: PlayerData.Data)
	-- skip every beat already met (repeat players go straight through)
	while data.onboardingStep + 1 < FREE_PLAY do
		local index = data.onboardingStep + 1
		local beat = Quests.Beats[index]
		if not beat.done(player, data) then
			break
		end
		data.onboardingStep = index
		data.onboardingMark = data.stats.circulationRuns
		for _, fn in Quests.onBeat do
			task.spawn(fn, player, index, beat.id)
		end
	end
end

function Quests.check(player: Player)
	local data = PlayerData.get(player)
	if data then
		advance(player, data)
		push(player, data)
	end
end

-- The elder repeats your current beat's line, or the top goal in free play.
function Quests.talk(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local beat = Quests.Beats[data.onboardingStep + 1] or Quests.Beats[FREE_PLAY]
	if beat.id == "FreePlay" then
		local top = Quests.goals(data)[1]
		Cultivation.notify(player, if top then `Elder Qingyun: "{top.detail}"` else `Elder Qingyun: "Keep cultivating."`)
	else
		push(player, data, true)
	end
end

function Quests.start()
	local hub = workspace:WaitForChild("Hub")
	local elder = hub:WaitForChild("Elder")
	local talk = elder:FindFirstChild("TalkPrompt", true) :: ProximityPrompt?
	if talk then
		talk.Triggered:Connect(Quests.talk)
	end
	local board = hub:WaitForChild("QuestBoard")
	local read = board:FindFirstChild("ReadPrompt", true) :: ProximityPrompt?
	if read then
		read.Triggered:Connect(function(player)
			questRemote:FireClient(player, { openBoard = true })
		end)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(Quests.check, player)
				if not ok then
					warn(`Quests: {err}`)
				end
			end
		end
	end)
end

function Quests.forget(player: Player)
	lastSent[player] = nil
end

return Quests
