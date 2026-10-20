--!strict
-- Keeps each enemy's overhead health bar (its HealthBar BillboardGui) in step
-- with its Humanoid.

local CollectionService = game:GetService("CollectionService")

local EnemyBars = {}

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local humanoid = model:WaitForChild("Humanoid", 5) :: Humanoid?
	local bar = model:FindFirstChild("HealthBar", true) :: BillboardGui?
	local fill = bar and bar:FindFirstChild("Fill", true) :: Frame?
	if not (humanoid and fill) then
		return
	end
	local function show()
		fill.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1), 1)
		if humanoid.Health <= 0 and bar then
			bar.Enabled = false
		end
	end
	humanoid.HealthChanged:Connect(show)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(show)
	show()
end

function EnemyBars.init()
	for _, model in CollectionService:GetTagged("Enemy") do
		task.spawn(watch, model)
	end
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(watch)
end

return EnemyBars
