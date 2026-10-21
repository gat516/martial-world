--!nocheck
-- Promote the preserved, rigged King to the testbed-only ElderWolfKingB template.
-- Run in Edit mode in a disposable sandbox after importing a binary copy of
-- ServerStorage._RosterWolves.ElderWolfKing from the user's place. Never rebuild
-- that source: cloning preserves hand edits, animation saves, joints and attributes.
-- The source is already built at 2.4x; ScaleTo would scale it a second time.
--
-- This creates a fresh unmapped _StagingKingEnemies copy of ServerStorage.Enemies,
-- preserving every shipped template (including the old ElderWolfKing). It refuses
-- to replace an existing staging copy or B template. For another intentional run,
-- use a fresh sandbox or set _G.WOLF_KING_STAGING to a fresh unmapped folder name.
-- Export the result with tools/export_rbxm.luau, rootName "Enemies", to the binary
-- assets/Enemies.rbxm. Rojo applies that file; never insert B into the user's live
-- Rojo-managed Enemies folder by hand.
--
-- Axes: -Z forward, -X left, ground Y=0. The unchanged HRP is the PrimaryPart at
-- (0, 6.24, 0) with identity rotation; its Y is EnemyService's root height.

local SCALE = 2.4
local ROOT_HEIGHT = 2.6 * SCALE
local TARGET = "ElderWolfKingB"
local STAGING = _G.WOLF_KING_STAGING or "_StagingKingEnemies"
local MOUTH_POINT = Vector3.new(0, 2.7, -5.1) * SCALE -- between the lips at the snout tip

local ServerStorage = game:GetService("ServerStorage")
local sourceFolder = assert(ServerStorage:FindFirstChild("_RosterWolves"), "import the preserved _RosterWolves source first")
local source = assert(sourceFolder:FindFirstChild("ElderWolfKing"), "missing preserved ElderWolfKing")
local enemies = assert(ServerStorage:FindFirstChild("Enemies"), "missing shipped Enemies templates")
assert(not ServerStorage:FindFirstChild(STAGING), "staging already exists; preserve its edits and use a fresh sandbox/name")
assert(not enemies:FindFirstChild(TARGET), "B already exists in the shipped asset; inspect it before another promotion")
assert(source:IsA("Model"), "King source must be a Model")
assert(math.abs((source:GetAttribute("Scale") or 0) - SCALE) < 0.0001, "source must already be built and rigged at 2.4x")

local model = assert(source:Clone(), "King source must be Archivable")
model.Name = TARGET
local root = assert(model:FindFirstChild("HumanoidRootPart"), "missing King root")
assert(root:IsA("BasePart"), "King root must be a BasePart")
model.PrimaryPart = root
model:PivotTo(CFrame.new(0, ROOT_HEIGHT, 0))
model.WorldPivot = CFrame.new(0, ROOT_HEIGHT, 0)
model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

local function part(name)
	local found = assert(model:FindFirstChild(name), "missing King part " .. name)
	assert(found:IsA("BasePart"), name .. " must be a BasePart")
	return found
end

local function attachment(name, parent, point)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Attachment") and #existing:GetChildren() == 0, name .. " must be an empty Attachment; preserve and inspect its edits")
		return -- preserve an already-authored hook rather than replacing it
	end
	local hook = Instance.new("Attachment")
	hook.Name = name
	-- Identity world rotation at rest; the hook follows its segment during poses.
	hook.CFrame = parent.CFrame:ToObjectSpace(CFrame.new(point))
	hook.Parent = parent
end

attachment("Mouth", part("Skull"), MOUTH_POINT)
local chest = part("Chest")
attachment("Core", chest, chest.Position)
for _, leg in { "FL", "FR", "BL", "BR" } do
	local paw = part("Paw" .. leg)
	-- Hind Paw segments slope down to their separate welded Foot parts.
	local foot = if leg == "BL" or leg == "BR" then part("Foot" .. leg) else paw
	attachment("Paw" .. leg .. "_FX", paw, Vector3.new(foot.Position.X, 0, foot.Position.Z))
end
local seal = part("Seal")
attachment("SealFX", seal, seal.Position)

for _, name in { "EyeL", "EyeR", "MarkBrow", "CollarJadeL", "CollarJadeR", "Seal" } do
	part(name):SetAttribute("Tell", true)
end

if not model:FindFirstChild("HealthBar", true) then
	local spiritWolf = assert(enemies:FindFirstChild("SpiritWolf"), "missing SpiritWolf HealthBar donor")
	local donor = assert(spiritWolf:FindFirstChild("HealthBar", true), "missing donor HealthBar")
	local bar = donor:Clone()
	local cf, size = model:GetBoundingBox()
	bar.StudsOffset = Vector3.new(0, cf.Position.Y + size.Y / 2 - root.Position.Y + 1, 0)
	bar.Parent = root
end

local staging = enemies:Clone()
staging.Name = STAGING
model.Parent = staging
staging.Parent = ServerStorage
return ("Preserved ElderWolfKing as %s in ServerStorage.%s; seven empty FX hooks, original skeleton and shipped templates retained"):format(TARGET, STAGING)
