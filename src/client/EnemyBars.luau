--!strict
-- Enemy health, Souls-style. Each enemy's overhead bar (its HealthBar
-- BillboardGui: Back > Fill, with a Trail chip beneath) shows only while it's
-- locked or for a while after it's hurt. The fill drops at once and the trail
-- drains after it, so each hit's size reads at a glance.
-- Bosses skip the overhead bar: the boss you're fighting (locked, or the nearest
-- one hunting you) fills the screen bar, Play.BossBar (NameLabel, Bar > Fill, Trail).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local LockOn = require(script.Parent.LockOn)
local Motion = require(script.Parent.Motion)

local SHOW_AFTER_HURT = 8 -- seconds an overhead bar stays up after a hit
local BOSS_RANGE = 60 -- a boss this close that's after you takes the screen bar
local TRAIL = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.45)

local player = Players.LocalPlayer

local EnemyBars = {}

type Watched = { bar: BillboardGui, humanoid: Humanoid, lastHurt: number, boss: boolean }
local watched: { [Model]: Watched } = {}

local bossBar: GuiObject?
local bossFill: GuiObject?
local bossTrail: GuiObject?
local bossName: TextLabel?
local shownBoss: Model? = nil

local function fraction(humanoid: Humanoid): number
	return math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
end

-- Fill drops at once; the trail catches up after a beat (and jumps up on a heal).
local function setBar(fill: GuiObject, trail: GuiObject?, value: number)
	fill.Size = UDim2.fromScale(value, 1)
	if trail then
		if value >= trail.Size.X.Scale then
			trail.Size = fill.Size
		else
			Motion.tween(trail, { Size = fill.Size }, TRAIL)
		end
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local humanoid = model:WaitForChild("Humanoid", 5) :: Humanoid?
	local bar = model:FindFirstChild("HealthBar", true) :: BillboardGui?
	local fill = bar and bar:FindFirstChild("Fill", true) :: GuiObject?
	if not (humanoid and bar and fill) then
		return
	end
	local trail = bar:FindFirstChild("Trail", true) :: GuiObject?
	local def = Enemies.Defs[model:GetAttribute("EnemyType") :: string? or ""]
	local entry: Watched = { bar = bar, humanoid = humanoid, lastHurt = -math.huge, boss = def ~= nil and def.boss == true }
	watched[model] = entry
	bar.Enabled = false
	local last = humanoid.Health
	local function show()
		if humanoid.Health < last then
			entry.lastHurt = os.clock()
		end
		last = humanoid.Health
		setBar(fill, trail, fraction(humanoid))
		if shownBoss == model and bossFill then
			setBar(bossFill, bossTrail, fraction(humanoid))
		end
	end
	humanoid.HealthChanged:Connect(show)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(show)
	show()
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			watched[model] = nil
		end
	end)
end

-- The boss the screen bar is for: the locked one, else the nearest one hunting you.
local function activeBoss(): Model?
	local locked = LockOn.target()
	if locked and watched[locked] and watched[locked].boss then
		return locked
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local best, bestDist = nil, BOSS_RANGE
	for model, entry in watched do
		local state = model:GetAttribute("AIState")
		if entry.boss and Hitbox.alive(model) and state ~= "idle" and state ~= "return" then
			local d = (model:GetPivot().Position - root.Position).Magnitude
			if d < bestDist then
				best, bestDist = model, d
			end
		end
	end
	return best
end

local function updateBoss()
	if not (bossBar and bossFill) then
		return
	end
	local boss = activeBoss()
	if boss ~= shownBoss then
		shownBoss = boss
		if boss then
			local entry = watched[boss]
			local def = Enemies.Defs[boss:GetAttribute("EnemyType") :: string? or ""]
			if bossName then
				bossName.Text = if def then def.name else boss.Name
			end
			local value = fraction(entry.humanoid)
			bossFill.Size = UDim2.fromScale(value, 1)
			if bossTrail then
				bossTrail.Size = bossFill.Size
			end
		end
		bossBar.Visible = boss ~= nil
	end
end

function EnemyBars.init(gui: ScreenGui)
	local play = gui:FindFirstChild("Play") :: Frame
	bossBar = play:FindFirstChild("BossBar") :: GuiObject?
	if bossBar then
		bossBar.Visible = false
		Motion.appear(bossBar)
		bossFill = bossBar:FindFirstChild("Fill", true) :: GuiObject?
		bossTrail = bossBar:FindFirstChild("Trail", true) :: GuiObject?
		bossName = bossBar:FindFirstChild("NameLabel", true) :: TextLabel?
	end
	for _, model in CollectionService:GetTagged("Enemy") do
		task.spawn(watch, model)
	end
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(watch)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local locked = LockOn.target()
		for model, entry in watched do
			entry.bar.Enabled = not entry.boss
				and entry.humanoid.Health > 0
				and (model == locked or now - entry.lastHurt < SHOW_AFTER_HURT)
		end
		updateBoss()
	end)
end

return EnemyBars
