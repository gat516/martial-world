--!strict
-- Spirit roots (shared defs and tuning: Roots.luau, Pacing.Roots). The Testing
-- Stone in the hub (Workspace.Hub.TestingStone, its TestPrompt) rolls a
-- player's element once; touching it again shows the result again. Also raises
-- a root's grade and heals Water roots out of combat. The other perks are
-- applied where their systems live: Cultivation (speed, health, walk, jump),
-- Circulation (refining speed), Combat (damage dealt and taken), Garden (growth).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RootDefs = require(ReplicatedStorage.Shared.Roots)
local PlayerData = require(script.Parent.PlayerData)
local Cultivation = require(script.Parent.Cultivation)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

local rng = Random.new()

local Roots = {}

-- Called with (player, element) when a root is first revealed, for analytics.
Roots.onTested = {} :: { (Player, string) -> () }

local function publish(player: Player, data: PlayerData.Data)
	player:SetAttribute("Root", if RootDefs.tested(data.root) then data.root.element else nil)
	player:SetAttribute("RootGrade", if RootDefs.tested(data.root) then data.root.grade else nil)
end
Roots.publish = publish

-- Effect "root" (everyone): (player, element, grade, first). Clients draw the
-- pillar of the element's colour; `first` marks the reveal (the card, the elder).
function Roots.test(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local first = not RootDefs.tested(data.root)
	if first then
		data.root.element = RootDefs.roll(rng)
		publish(player, data)
		Cultivation.applyStats(player, data)
		Cultivation.pushState(player)
		for _, fn in Roots.onTested do
			task.spawn(fn, player, data.root.element)
		end
	end
	local def = RootDefs.Elements[data.root.element]
	effectRemote:FireAllClients("root", player, def.id, data.root.grade, first)
	if first then
		local line = if def.rare
			then `A {def.name} root! I have not seen one in a hundred years.`
			else `A {def.name} root. A fine foundation.`
		Cultivation.notify(player, `Elder Qingyun: "{line}" {def.blurb}`)
	else
		Cultivation.notify(player, `Your spirit root: {data.root.grade}-grade {def.name}. {def.blurb}`)
	end
end

-- Raise a tested root one grade (rare items, admin). Returns false at the top.
function Roots.raiseGrade(player: Player): (boolean, string?)
	local data = PlayerData.get(player)
	if not data or not RootDefs.tested(data.root) then
		return false, "Your root hasn't been tested yet."
	end
	local nextGrade = RootDefs.nextGrade(data.root.grade)
	if not nextGrade then
		return false, "Your root can grow no purer."
	end
	data.root.grade = nextGrade
	publish(player, data)
	Cultivation.applyStats(player, data)
	Cultivation.pushState(player)
	Cultivation.notify(player, `Your spirit root grows purer: {nextGrade}-grade {data.root.element}!`)
	return true, nil
end

function Roots.start()
	task.spawn(function()
		local stone = workspace:WaitForChild("Hub"):WaitForChild("TestingStone")
		local prompt = stone:WaitForChild("TestPrompt", 30) :: ProximityPrompt?
		if prompt then
			prompt.Triggered:Connect(Roots.test)
		else
			warn("Roots: Hub.TestingStone has no TestPrompt")
		end
	end)
	-- Water roots heal out of combat
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.get(player)
				local regen = if data then RootDefs.perk(data.root, "regen") else 0
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if regen > 0 and humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
					if not (Cultivation.inCombat and Cultivation.inCombat(player)) then
						humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * regen * dt)
					end
				end
			end
		end
	end)
end

return Roots
