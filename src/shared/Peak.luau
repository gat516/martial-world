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

-- The peak model an instance belongs to (peaks carry a PeakIndex attribute).
function Peak.of(inst: Instance): Model?
	local node: Instance? = inst
	while node do
		if node:IsA("Model") and node:GetAttribute("PeakIndex") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- The deletable unit an instance is part of: a placed item or a starter piece.
function Peak.pieceOf(inst: Instance): Instance?
	local node: Instance? = inst
	while node do
		if node:GetAttribute("PlacedId") ~= nil or node:GetAttribute("StarterId") ~= nil then
			return node
		end
		if node:GetAttribute("PeakIndex") ~= nil then
			return nil
		end
		node = node.Parent
	end
	return nil
end

return Peak
