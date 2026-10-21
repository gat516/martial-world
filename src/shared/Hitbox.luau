--!strict
-- Attack hitboxes (one per weapon class), shared so the client's predicted hits and the server's check
-- use the same box. Enemies are models tagged "Enemy" with a Health attribute above 0
-- (no Humanoid: EnemyService owns health).

local Config = require(script.Parent.Config).Combat

local Hitbox = {}

-- A weapon class's M1 box (Config.Combat.CLASSES) in front of the root,
-- reaching hitbox.Z studs, grown by `grow` on every side. nil class = Fist.
function Hitbox.box(root: BasePart, grow: number?, class: string?): (CFrame, Vector3)
	local entry = Config.CLASSES[class or "Fist"] or Config.CLASSES.Fist
	local size = entry.hitbox
	local g = grow or 0
	return root.CFrame * CFrame.new(0, 0, -size.Z / 2), size + Vector3.one * (g * 2)
end

function Hitbox.alive(model: Instance?): boolean
	if not (model and model:IsA("Model") and model:HasTag("Enemy") and model:IsDescendantOf(workspace)) then
		return false
	end
	local health = model:GetAttribute("Health")
	return type(health) == "number" and health > 0
end

-- The enemy model a part belongs to, if any.
function Hitbox.enemyOf(part: Instance): Model?
	local node: Instance? = part
	while node and node ~= workspace do
		if node:IsA("Model") and node:HasTag("Enemy") then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- Living enemies whose parts overlap the box, nearest to `from` first.
function Hitbox.enemiesIn(cframe: CFrame, size: Vector3, params: OverlapParams, from: Vector3): { Model }
	local found: { Model } = {}
	local seen: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(cframe, size, params) do
		local model = Hitbox.enemyOf(part)
		if model and not seen[model] and Hitbox.alive(model) then
			seen[model] = true
			table.insert(found, model)
		end
	end
	table.sort(found, function(a, b)
		return (a:GetPivot().Position - from).Magnitude < (b:GetPivot().Position - from).Magnitude
	end)
	return found
end

return Hitbox
