--!strict
-- The Herbarium's record (docs/ui/herbarium.md; the book itself is the client's
-- Herbarium.luau). Per player and herb: how many were harvested in all, the
-- largest size seen and the mutations seen (data.herbarium.herbs). A herb is
-- discovered the first time it's harvested from a plot, gathered wild or taken
-- from a world event; each discovery pays Pacing.Herbarium DISCOVER stones by tier.
-- Discovering every herb of a tier (Herbs.Order) completes that tier's page, once:
-- TIER stones and a Home foundation experience, "home:book:<tier>" (Foundation).
-- The record goes to the client in the PlayerState push (`herbarium`). Callers grant
-- the herb right after recording, which pushes state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local PlayerData = require(script.Parent.PlayerData)
local Foundation = require(script.Parent.Foundation)
local Cultivation = require(script.Parent.Cultivation)

local Herbarium = {}

-- Every herb of `tier`, in book order.
function Herbarium.tierHerbs(tier: number): { string }
	local list = {}
	for _, id in Herbs.Order do
		if Herbs.Defs[id].tier == tier then
			table.insert(list, id)
		end
	end
	return list
end

local function completeTier(player: Player, data: PlayerData.Data, tier: number)
	local book = data.herbarium
	local key = tostring(tier)
	if book.tiers[key] then
		return
	end
	for _, id in Herbarium.tierHerbs(tier) do
		if not book.herbs[id] then
			return
		end
	end
	book.tiers[key] = true
	local stones = Pacing.Herbarium.TIER[tier] or 0
	data.stones += stones
	Foundation.earn(player, "Home", `home:book:{tier}`)
	Cultivation.notify(player, `Herbarium: the tier {Herbs.TierNumerals[tier] or tier} page is complete! +{stones} Spirit Stones`)
end

-- Note `count` of herb `id` harvested at `size` with `mutations`.
function Herbarium.record(player: Player, id: string, count: number, size: number?, mutations: { string }?)
	local data = PlayerData.get(player)
	local herb = Herbs.Defs[id]
	if not (data and herb) then
		return
	end
	local book = data.herbarium
	local entry = book.herbs[id]
	local new = entry == nil
	if not entry then
		entry = { n = 0, l = 0, m = {} }
		book.herbs[id] = entry
	end
	entry.n += math.max(0, count)
	local s = math.floor((size or 1) * 100 + 0.5) / 100
	if s > entry.l then
		entry.l = s
	end
	for _, m in mutations or {} do
		if Herbs.Mutations[m] and not table.find(entry.m, m) then
			table.insert(entry.m, m)
		end
	end
	if new then
		local stones = Pacing.Herbarium.DISCOVER[herb.tier] or 0
		data.stones += stones
		Cultivation.notify(player, `New in your Herbarium: {herb.name}! +{stones} Spirit Stones`)
		completeTier(player, data, herb.tier)
	end
end

return Herbarium
