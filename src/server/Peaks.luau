--!strict
-- Peak ownership and layouts. Each player gets a free spirit peak for the session;
-- their saved layout (removed starter pieces, placed items, planted beds) is applied
-- on join and undone on leave so the next owner starts from the default peak.
-- Also the peak tier (Config.Build.TIERS: look, build radius, item caps) and the
-- peak score (Pacing.PeakScore) that adds to meditation and garden growth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Peak = require(ReplicatedStorage.Shared.Peak)
local PlayerData = require(script.Parent.PlayerData)

local peaksFolder = workspace.Map.Sect.SpiritPeaks
local stashFolder = ServerStorage.PeakStash
local catalog = ReplicatedStorage.BuildCatalog
-- tier looks by template name (Config.Build.TIERS), plus the OwnerSign billboard
local tierFolder = ServerStorage.PeakTiers
-- place-only meshes per tier (library MeshParts Rojo can't sync), merged into the tier on apply
local tierModels = ServerStorage.PeakTierModels
local Realms = require(ReplicatedStorage.Shared.Realms)
local BuildItems = require(ReplicatedStorage.Shared.BuildItems)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local BuildConfig = Config.Build

type Starter = { inst: Instance, parent: Instance }

-- The starter garden fence was one piece ("Garden/Fence", a whole GardenFence); it is now separate
-- Fence segments "Garden/Fence_1".."Garden/Fence_N". Saved layouts that removed the old id keep working.
local LEGACY_FENCE = "Garden/Fence"
local FENCE_SEGMENT = "^Garden/Fence_%d+$"

local Peaks = {}

-- peak -> StarterId -> where the piece lives by default
local starters: { [Model]: { [string]: Starter } } = {}
local owners: { [Player]: Model } = {}
local scores: { [Player]: number } = {} -- peak score, already capped at the tier's scoreCap

for _, peak in peaksFolder:GetChildren() do
	if peak:IsA("Model") then
		local index = {}
		for _, d in peak:GetDescendants() do
			local id = d:GetAttribute("StarterId")
			if type(id) == "string" then
				index[id] = { inst = d, parent = d.Parent :: Instance }
			end
		end
		starters[peak] = index
	end
end

function Peaks.ownedBy(player: Player): Model?
	return owners[player]
end

function Peaks.ownerOf(peak: Model): Player?
	for player, p in owners do
		if p == peak then
			return player
		end
	end
	return nil
end

-- Where you arrive home: standing on the peak's teleport array, facing the plateau.
function Peaks.homeCFrame(peak: Model): CFrame?
	local array = peak:FindFirstChild("TeleportArray") :: Model?
	if not array then
		return nil
	end
	local at = array:GetPivot().Position + Vector3.new(0, Config.Spawn.HEIGHT, 0)
	local centre = Peak.frame(peak).Position
	return CFrame.lookAt(at, Vector3.new(centre.X, at.Y, centre.Z))
end

function Peaks.starter(peak: Model, id: string): Starter?
	local s = starters[peak]
	return s and s[id]
end

function Peaks.stashStarter(peak: Model, id: string)
	local s = Peaks.starter(peak, id)
	if s then
		s.inst.Parent = stashFolder:FindFirstChild(peak.Name)
	end
end

function Peaks.spawnPlaced(peak: Model, rec: PlayerData.Placed): Instance?
	local template = catalog:FindFirstChild(rec.i)
	if not template then
		return nil
	end
	local item = template:Clone() :: Model
	item:PivotTo(Peak.frame(peak) * CFrame.new(rec.x, rec.y, rec.z) * CFrame.Angles(0, math.rad(rec.r), 0))
	item:SetAttribute("PlacedId", rec.u)
	item:SetAttribute("ItemId", rec.i)
	item:SetAttribute("PlaceMode", rec.m) -- wall, ceiling or socket (nil: floor), for clients
	if item:HasTag("HerbPlot") then
		item:SetAttribute("PlotId", rec.u)
	end
	item.Parent = peak:FindFirstChild("Placed")
	return item
end

-- The owner's peak tier, from their realm.
function Peaks.tierOf(player: Player): Peak.Tier
	local data = PlayerData.get(player)
	return if data then Peak.tierAt(data.realm.major, data.realm.minor) else BuildConfig.TIERS[1]
end

-- Score of the build pieces standing on a peak (placed copies and starter pieces
-- still out); only the first PER_ITEM copies of one item count.
local function scoreOn(peak: Model): number
	local rules = Pacing.PeakScore
	local copies: { [string]: number } = {}
	local total = 0
	for _, d in peak:GetDescendants() do
		local id = d:GetAttribute("ItemId")
		if type(id) == "string" and (d:GetAttribute("PlacedId") or d:GetAttribute("StarterId")) then
			local def = BuildItems.Defs[id]
			local n = (copies[id] or 0) + 1
			copies[id] = n
			if def and n <= rules.PER_ITEM then
				total += Peak.itemScore(def)
			end
		end
	end
	return total
end

-- Recount the owner's peak score and publish it with the tier (PeakScore,
-- PeakScoreCap and PeakTier player attributes, for the build catalog).
function Peaks.refreshScore(player: Player)
	local peak = owners[player]
	if not peak then
		scores[player] = nil
		return
	end
	local tier = Peaks.tierOf(player)
	local score = scoreOn(peak)
	scores[player] = math.min(score, tier.scoreCap)
	local data = PlayerData.get(player)
	if data and score > data.stats.peakBest then
		data.stats.peakBest = score -- the heart-demon trial reads it
	end
	player:SetAttribute("PeakScore", score)
	player:SetAttribute("PeakScoreCap", tier.scoreCap)
	player:SetAttribute("PeakTier", tier.id)
end

-- What the peak score adds to the meditation multiplier on the owner's peak.
function Peaks.meditationBonus(player: Player): number
	return (scores[player] or 0) * Pacing.PeakScore.MEDITATION
end

-- The peak score's share of the tier's cap, 0..1: how much decorating lifts the
-- garden aura's cap (Pacing.Aura.DECOR).
function Peaks.decorShare(player: Player): number
	local cap = Peaks.tierOf(player).scoreCap
	return if cap > 0 then math.clamp((scores[player] or 0) / cap, 0, 1) else 0
end

-- What the peak score adds to the growth speed of the owner's plants.
function Peaks.growthBonus(player: Player): number
	return (scores[player] or 0) * Pacing.PeakScore.GROWTH
end

-- The template a tier shows: its own, else the nearest earlier tier's that exists.
local function templateFor(tier: Peak.Tier): (Model?, Peak.Tier?)
	local list = BuildConfig.TIERS
	for i = table.find(list, tier) or 1, 1, -1 do
		local t = tierFolder:FindFirstChild(list[i].template)
		if t and t:IsA("Model") then
			return t, list[i]
		end
	end
	return nil, nil
end

-- Assign a free peak. Called before the character spawns so they spawn at home.
function Peaks.assign(player: Player): Model?
	for _, peak in peaksFolder:GetChildren() do
		if peak:IsA("Model") and peak:GetAttribute("Owner") == "" and starters[peak] then
			peak:SetAttribute("Owner", tostring(player.UserId))
			peak:SetAttribute("OwnerName", player.DisplayName)
			owners[player] = peak
			player:SetAttribute("Peak", peak.Name)
			player:SetAttribute("PeakFrame", Peak.frame(peak))
			player.RespawnLocation = peak:FindFirstChild("SpawnLocation") :: SpawnLocation
			return peak
		end
	end
	return nil
end

function Peaks.applyLayout(player: Player, data: PlayerData.Data)
	local peak = owners[player]
	if not peak then
		return
	end
	for id in data.peak.removed do
		if id == LEGACY_FENCE then
			-- the garden fence used to be one starter piece; whoever stored it already has the whole
			-- fence (a GardenFence item), so all of its segments stay stashed
			for segment in starters[peak] do
				if segment:match(FENCE_SEGMENT) then
					Peaks.stashStarter(peak, segment)
				end
			end
		else
			Peaks.stashStarter(peak, id)
		end
	end
	for _, rec in data.peak.placed do
		Peaks.spawnPlaced(peak, rec)
	end
end

-- The owner's realm on their peak: a floating name sign over the stele, and the
-- peak tier's look (Foundation: lanterns, a floating shrine pavilion and a sky
-- beam), so everyone can see who is strongest from afar. Also sets the peak's
-- BuildRadius and recounts the score (the cap is per tier).
function Peaks.applyRealm(player: Player, data: PlayerData.Data)
	local peak = owners[player]
	if not peak then
		return
	end
	local stage = Realms.get(data.realm.major, data.realm.minor)
	local stele = peak:FindFirstChild("NameStele")
	local cap = stele and stele:FindFirstChild("Cap") :: BasePart?
	if cap then
		local sign = cap:FindFirstChild("OwnerSign") :: BillboardGui?
		if not sign then
			local made = (tierFolder:FindFirstChild("OwnerSign") :: BillboardGui):Clone()
			made.Parent = cap
			sign = made
		end
		local nameLabel = (sign :: BillboardGui):FindFirstChild("NameLabel") :: TextLabel
		local realmLabel = (sign :: BillboardGui):FindFirstChild("RealmLabel") :: TextLabel
		nameLabel.Text = player.DisplayName
		realmLabel.Text = stage.name
	end

	local tierRow = Peak.tierAt(stage.major, stage.minor)
	local template, shown = templateFor(tierRow)
	local wanted = template and template.Name
	local current = peak:FindFirstChild("RealmTier")
	if current and current:GetAttribute("Tier") ~= wanted then
		current:Destroy()
		current = nil
	end
	if template and wanted and not current then
		local tier = template:Clone()
		local extra = tierModels:FindFirstChild(wanted)
		if extra then
			for _, child in extra:GetChildren() do
				child:Clone().Parent = tier
			end
		end
		-- the template is authored in peak-local coordinates around the plateau
		local frame = Peak.frame(peak)
		for _, d in tier:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = frame:ToWorldSpace(d.CFrame)
			end
		end
		tier.Name = "RealmTier"
		tier:SetAttribute("Tier", wanted)
		tier.Parent = peak
		current = tier
	end

	-- more room only where the look brings ground to build on (the testbed's arena is flat)
	local hasGround = current ~= nil and current:FindFirstChild(BuildConfig.TIER_GROUND) ~= nil
	local radius = if Config.TESTBED then tierRow.radius
		elseif hasGround and shown then shown.radius
		else BuildConfig.RADIUS
	peak:SetAttribute("BuildRadius", radius)
	Peaks.refreshScore(player)
end

-- Undo the owner's layout so the peak is back to its default for the next player.
function Peaks.release(player: Player)
	local peak = owners[player]
	if not peak then
		return
	end
	owners[player] = nil
	scores[player] = nil
	player:SetAttribute("PeakScore", nil)
	player:SetAttribute("PeakScoreCap", nil)
	player:SetAttribute("PeakTier", nil)
	peak:SetAttribute("BuildRadius", nil)
	for _, item in (peak:FindFirstChild("Placed") :: Folder):GetChildren() do
		item:Destroy()
	end
	for _, s in starters[peak] do
		if s.inst.Parent ~= s.parent then
			s.inst.Parent = s.parent
		end
		if s.inst:HasTag("HerbPlot") then
			s.inst:SetAttribute("Plants", nil)
		end
	end
	local tier = peak:FindFirstChild("RealmTier")
	if tier then
		tier:Destroy()
	end
	local stele = peak:FindFirstChild("NameStele")
	local sign = stele and stele:FindFirstChild("OwnerSign", true)
	if sign then
		sign:Destroy()
	end
	peak:SetAttribute("Owner", "")
	peak:SetAttribute("OwnerName", "")
end

return Peaks
