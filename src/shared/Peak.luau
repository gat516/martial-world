--!strict
-- Peak layout helpers shared by server and client.
-- Every peak is the same layout rotated around the MainPeak, so saved positions are
-- stored in a peak-local frame: origin at the Plateau centre, -Z (look) pointing
-- outward from the map centre. A layout saved on one peak loads the same on any other.

local Config = require(script.Parent.Config)
local Pacing = require(script.Parent.Pacing)
local Realms = require(script.Parent.Realms)

local Peak = {}

export type Tier = typeof(Config.Build.TIERS[1])

-- The peak tier for a realm: the last Config.Build.TIERS row whose `from` stage
-- the realm has reached (the first row below that).
function Peak.tierAt(major: string, minor: number): Tier
	local at = Realms.index(major, minor)
	local tiers = Config.Build.TIERS
	local best = tiers[1]
	for _, tier in tiers do
		local from = Realms.ByKey[tier.from]
		if from and at >= Realms.index(from.major, from.minor) then
			best = tier
		end
	end
	return best
end

function Peak.tierById(id: any): Tier?
	for _, tier in Config.Build.TIERS do
		if tier.id == id then
			return tier
		end
	end
	return nil
end

-- How many of an item a peak of this tier holds (nil: no cap but the tier's maxItems).
function Peak.limit(tier: Tier?, def: { id: string, limit: number? }): number?
	local override = tier and tier.limits[def.id]
	return override or def.limit
end

-- A peak's build radius: the BuildRadius attribute the server sets from its tier.
function Peak.radius(peak: Instance?): number
	local r = peak and peak:GetAttribute("BuildRadius")
	return if type(r) == "number" then r else Config.Build.RADIUS
end

-- Peak-score points one build item is worth (Pacing.PeakScore).
function Peak.itemScore(def: { category: string, score: number?, realm: { major: string, minor: number }? }): number
	if def.score then
		return def.score
	end
	local rules = Pacing.PeakScore
	local gate = def.realm and rules.GATED[def.realm.major] or 0
	return (rules.BY_CATEGORY[def.category] or 0) + gate
end

function Peak.frame(peak: Model): CFrame
	local c = (peak:FindFirstChild("Plateau") :: BasePart).Position
	return CFrame.lookAt(c, c + Vector3.new(c.X, 0, c.Z).Unit)
end

-- `radius` is the peak's (Peak.radius), the base radius when left out.
function Peak.inBounds(localPos: Vector3, radius: number?): boolean
	local b = Config.Build
	return Vector2.new(localPos.X, localPos.Z).Magnitude <= (radius or b.RADIUS) and localPos.Y >= b.MIN_Y and localPos.Y <= b.MAX_Y
end

function Peak.snap(n: number, step: number): number
	return math.floor(n / step + 0.5) * step
end

-- Peaks are the direct children of this folder. (Their sub-models also carry a
-- PeakIndex attribute, so that attribute can't identify a peak.)
local PEAKS_FOLDER = "SpiritPeaks"

local function isPeak(node: Instance): boolean
	local parent = node.Parent
	return node:IsA("Model") and parent ~= nil and parent.Name == PEAKS_FOLDER
end

-- The peak model an instance belongs to.
function Peak.of(inst: Instance): Model?
	local node: Instance? = inst
	while node do
		if isPeak(node) then
			return node :: Model
		end
		node = node.Parent
	end
	return nil
end

-- The storable unit an instance is part of: a placed item or a starter piece.
function Peak.pieceOf(inst: Instance): Instance?
	local node: Instance? = inst
	while node and not isPeak(node) do
		if node:GetAttribute("PlacedId") ~= nil or node:GetAttribute("StarterId") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

return Peak
