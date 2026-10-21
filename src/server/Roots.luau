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

-- Why a root can't be raised a grade right now, or nil.
function Roots.cantRaise(data: PlayerData.Data): string?
	if not RootDefs.tested(data.root) then
		return "Your root hasn't been tested yet."
	end
	if not RootDefs.nextGrade(data.root.grade) then
		return "Your root can grow no purer."
	end
	return nil
end

-- Why a root can't be reformed right now, or nil.
function Roots.cantReroll(data: PlayerData.Data): string?
	if not RootDefs.tested(data.root) then
		return "Your root hasn't been tested yet."
	end
	if data.root.pending ~= "" then
		return "Your root is still reforming. Keep the new element or return to the old first."
	end
	return nil
end

-- Raise a tested root one grade (Marrow Washing Pill, admin). Returns false at the top.
function Roots.raiseGrade(player: Player): (boolean, string?)
	local data = PlayerData.get(player)
	local why = if data then Roots.cantRaise(data) else "Still loading"
	if not data or why then
		return false, why
	end
	local nextGrade = RootDefs.nextGrade(data.root.grade) :: string
	data.root.grade = nextGrade
	publish(player, data)
	Cultivation.applyStats(player, data)
	Cultivation.pushState(player)
	Cultivation.notify(player, `Your spirit root grows purer: {nextGrade}-grade {data.root.element}!`)
	return true, nil
end

-- Reform the root as another element (Root Rebirth Pill). The new element waits
-- in `pending` until the player keeps it or returns to the old (Roots.choose).
-- Each element keeps its own grade (one never held is at STARTING_GRADE), and
-- returning to the old costs nothing, so a reroll can't leave a root weaker.
function Roots.reroll(player: Player): (boolean, string?)
	local data = PlayerData.get(player)
	local why = if data then Roots.cantReroll(data) else "Still loading"
	if not data or why then
		return false, why
	end
	local new = data.root.element
	for _ = 1, 20 do
		new = RootDefs.roll(rng)
		if new ~= data.root.element then
			break
		end
	end
	data.root.pending = new
	Cultivation.pushState(player)
	local def = RootDefs.Elements[new]
	local grade = RootDefs.gradeOf(data.root, new)
	Cultivation.notify(player, `Your root dissolves and reforms: a {grade}-grade {def.name} root! {def.blurb} Keep it, or return to {data.root.grade}-grade {data.root.element}.`)
	return true, nil
end

-- CultivationAction "root": keep the pending element (keepNew) or return to the old.
function Roots.choose(player: Player, keepNew: any): (boolean, string?)
	local data = PlayerData.get(player)
	if not data or data.root.pending == "" then
		return false, "Your root isn't reforming."
	end
	if keepNew == true then
		RootDefs.switch(data.root, data.root.pending)
	end
	data.root.pending = ""
	publish(player, data)
	Cultivation.applyStats(player, data)
	Cultivation.pushState(player)
	local def = RootDefs.Elements[data.root.element]
	Cultivation.notify(player, `Your spirit root settles: {data.root.grade}-grade {def.name}. {def.blurb}`)
	if keepNew == true then
		effectRemote:FireAllClients("root", player, def.id, data.root.grade, false)
	end
	return true, nil
end

function Roots.start()
	task.spawn(function()
		local stone = workspace:WaitForChild("Hub"):WaitForChild("TestingStone")
		local prompt = stone:FindFirstChild("TestPrompt", true) :: ProximityPrompt?
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
