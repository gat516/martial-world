--!strict
-- Qi accumulates every second at a rate boosted by eaten-herb buffs and by the
-- spirit aura of mature herbs left growing in the player's beds.
-- Also owns the PlayerState push the HUD renders from.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Cultivation
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local PlayerData = require(script.Parent.PlayerData)

local stateRemote = ReplicatedStorage.Remotes.PlayerState :: RemoteEvent

local Cultivation = {}

function Cultivation.aura(data: PlayerData.Data, now: number): number
	local total = 0
	for _, plot in data.peak.plots do
		local herb = Herbs.Defs[plot.herb]
		if herb and now - plot.planted >= herb.growSeconds then
			total += herb.aura
		end
	end
	return total
end

local function buffTotal(data: PlayerData.Data, kind: string): number
	local total = 0
	for _, b in data.buffs do
		if b.kind == kind then
			total += b.amount
		end
	end
	return total
end

function Cultivation.rate(data: PlayerData.Data, now: number): number
	return Config.BASE_RATE * (1 + buffTotal(data, "QiRate")) * (1 + Cultivation.aura(data, now))
end

function Cultivation.pushState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local now = os.time()
	stateRemote:FireClient(player, {
		qi = data.qi,
		rate = Cultivation.rate(data, now),
		aura = Cultivation.aura(data, now),
		herbs = data.herbs,
		seeds = data.seeds,
		buffs = data.buffs,
		decor = data.decor,
	})
end

local function applyWalkSpeed(player: Player, data: PlayerData.Data)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.BASE_WALKSPEED + buffTotal(data, "WalkSpeed")
	end
end

-- Eat a herb from the pouch: raw Qi now, plus its timed buffs.
function Cultivation.eat(player: Player, herbId: string): (boolean, string?)
	local data = PlayerData.get(player)
	local herb = Herbs.Defs[herbId]
	if not (data and herb) then
		return false, "Unknown herb"
	end
	if (data.herbs[herbId] or 0) < 1 then
		return false, "You have none left"
	end
	data.herbs[herbId] -= 1
	if data.herbs[herbId] <= 0 then
		data.herbs[herbId] = nil
	end
	data.qi += herb.eat.qi or 0
	local now = os.time()
	for _, b in herb.eat.buffs or {} do
		-- eating the same herb again refreshes its buff instead of stacking it
		local existing
		for _, active in data.buffs do
			if active.source == herbId and active.kind == b.kind then
				existing = active
			end
		end
		if existing then
			existing.expires = math.max(existing.expires, now + b.seconds)
		else
			table.insert(data.buffs, { source = herbId, kind = b.kind, amount = b.amount, expires = now + b.seconds })
		end
	end
	applyWalkSpeed(player, data)
	Cultivation.pushState(player)
	return true, `Ate {herb.name}: {herb.blurb}`
end

function Cultivation.watch(player: Player)
	player.CharacterAdded:Connect(function()
		local data = PlayerData.get(player)
		if data then
			task.defer(applyWalkSpeed, player, data)
		end
	end)
end

task.spawn(function()
	local sinceRefresh = 0
	while true do
		local dt = task.wait(1)
		local now = os.time()
		sinceRefresh += dt
		for _, player in Players:GetPlayers() do
			local data = PlayerData.get(player)
			if data then
				local expired = false
				for i = #data.buffs, 1, -1 do
					if data.buffs[i].expires <= now then
						table.remove(data.buffs, i)
						expired = true
					end
				end
				data.qi += Cultivation.rate(data, now) * dt
				player:SetAttribute("Qi", math.floor(data.qi))
				if expired then
					applyWalkSpeed(player, data)
				end
				if expired or sinceRefresh >= Config.STATE_REFRESH_SECONDS then
					Cultivation.pushState(player)
				end
			end
		end
		if sinceRefresh >= Config.STATE_REFRESH_SECONDS then
			sinceRefresh = 0
		end
	end
end)

return Cultivation
