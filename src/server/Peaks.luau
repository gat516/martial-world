--!strict
-- Peak ownership and layouts. Each player gets a free spirit peak for the session;
-- their saved layout (removed starter pieces, placed items, planted beds) is applied
-- on join and undone on leave so the next owner starts from the default peak.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Peak = require(ReplicatedStorage.Shared.Peak)
local PlayerData = require(script.Parent.PlayerData)

local peaksFolder = workspace.Map.Sect.SpiritPeaks
local stashFolder = ServerStorage.PeakStash
local catalog = ReplicatedStorage.BuildCatalog
local tiers = ServerStorage.PeakTiers
local Realms = require(ReplicatedStorage.Shared.Realms)

-- Peak visuals per major realm, beyond the bare rock every peak starts with.
local TIER_BY_MAJOR = { Foundation = "Foundation" }

type Starter = { inst: Instance, parent: Instance }

local Peaks = {}

-- peak -> StarterId -> where the piece lives by default
local starters: { [Model]: { [string]: Starter } } = {}
local owners: { [Player]: Model } = {}

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
	if item:HasTag("HerbPlot") then
		item:SetAttribute("PlotId", rec.u)
	end
	item.Parent = peak:FindFirstChild("Placed")
	return item
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
		Peaks.stashStarter(peak, id)
	end
	for _, rec in data.peak.placed do
		Peaks.spawnPlaced(peak, rec)
	end
end

-- The owner's realm on their peak: a floating name sign over the stele, and the
-- major realm's tier (Foundation: hovering formation ring, lanterns, floating
-- pavilion and a sky beam), so everyone can see who is strongest from afar.
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
			local made = (tiers:FindFirstChild("OwnerSign") :: BillboardGui):Clone()
			made.Parent = cap
			sign = made
		end
		local nameLabel = (sign :: BillboardGui):FindFirstChild("NameLabel") :: TextLabel
		local realmLabel = (sign :: BillboardGui):FindFirstChild("RealmLabel") :: TextLabel
		nameLabel.Text = player.DisplayName
		realmLabel.Text = stage.name
	end

	local wanted = TIER_BY_MAJOR[stage.major]
	local current = peak:FindFirstChild("RealmTier")
	if current and current:GetAttribute("Tier") ~= wanted then
		current:Destroy()
		current = nil
	end
	if wanted and not current then
		local tier = (tiers:FindFirstChild(wanted) :: Model):Clone()
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
	end
end

-- Undo the owner's layout so the peak is back to its default for the next player.
function Peaks.release(player: Player)
	local peak = owners[player]
	if not peak then
		return
	end
	owners[player] = nil
	for _, item in (peak:FindFirstChild("Placed") :: Folder):GetChildren() do
		item:Destroy()
	end
	for _, s in starters[peak] do
		if s.inst.Parent ~= s.parent then
			s.inst.Parent = s.parent
		end
		if s.inst:HasTag("HerbPlot") then
			for _, attr in { "Herb", "PlantedAt", "GrowSeconds" } do
				s.inst:SetAttribute(attr, nil)
			end
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
