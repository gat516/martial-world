--!strict
-- Peak layout helpers shared by server and client.
-- Every peak is the same layout rotated around the MainPeak, so saved positions are
-- stored in a peak-local frame: origin at the Plateau centre, -Z (look) pointing
-- outward from the map centre. A layout saved on one peak loads the same on any other.

local Config = require(script.Parent.Config)

local Peak = {}

function Peak.frame(peak: Model): CFrame
	local c = (peak:FindFirstChild("Plateau") :: BasePart).Position
	return CFrame.lookAt(c, c + Vector3.new(c.X, 0, c.Z).Unit)
end

function Peak.inBounds(localPos: Vector3): boolean
	local b = Config.Build
	return Vector2.new(localPos.X, localPos.Z).Magnitude <= b.RADIUS and localPos.Y >= b.MIN_Y and localPos.Y <= b.MAX_Y
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
