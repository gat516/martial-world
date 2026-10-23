--!strict
-- Small cultivation marks other screens put on their own art (roadmap 4 and
-- 3d; docs/ui/cultivation.md). Ready to wire: nothing uses them yet. Each is a
-- template in Cultivation.Templates, cloned into the caller's frame:
--
--   CultivationMarks.daoRing(parent, level)   -> Frame   the dao_ring with nine
--       notches; notch k shows a jade gem once level >= k, and level 10
--       (Weapons.MAX_LEVEL, mastered) lights all nine and reads "Max". Fills
--       its parent (put it in a square frame); setDao(ring, level) updates it.
--   CultivationMarks.tierFrame(icon, tier)            a technique tier frame
--       (tier_t1..tier_t4) over a skill icon; nil removes it. The frame is the
--       icon's child, sized so the art's hole sits just inside the icon's box.
--   CultivationMarks.bloodline(parent, "Pure" | "Inherited") -> ImageLabel
--   CultivationMarks.heavenMark(parent)       -> ImageLabel
--       Badges that fill their parent's height at the art's aspect.
--   CultivationMarks.preview()   a sample sheet in the middle of the screen for
--       a few seconds (client console).

local CultivationGui = require(script.Parent.CultivationGui)

export type Tier = number -- 1..4

local TIERS = {
	-- art, and the frame's size over the icon (the art's hole is 72-77% of it)
	{ image = "rbxassetid://114293655891061", x = 1.19, y = 1.21 },
	{ image = "rbxassetid://93470837190971", x = 1.21, y = 1.23 },
	{ image = "rbxassetid://131738116583360", x = 1.23, y = 1.25 },
	{ image = "rbxassetid://78544890559261", x = 1.27, y = 1.3 },
}
local BLOODLINES = {
	Pure = "rbxassetid://120447037577230",
	Inherited = "rbxassetid://92587004067417",
}
local NOTCHES = 9
local MASTERED = 10

local CultivationMarks = {}

local function fill(obj: GuiObject, parent: Instance)
	obj.AnchorPoint = Vector2.new(0.5, 0.5)
	obj.Position = UDim2.fromScale(0.5, 0.5)
	obj.Size = UDim2.fromScale(1, 1)
	obj.Parent = parent
end

function CultivationMarks.setDao(ring: Frame, level: number)
	for k = 1, NOTCHES do
		(ring:FindFirstChild(`Notch{k}`) :: GuiObject).Visible = level >= k
	end
	(ring:FindFirstChild("Level") :: TextLabel).Text = if level >= MASTERED then "Max" else tostring(math.floor(level))
end

function CultivationMarks.daoRing(parent: Instance, level: number): Frame
	local ring = CultivationGui.template("DaoRing") :: Frame
	fill(ring, parent)
	CultivationMarks.setDao(ring, level)
	return ring
end

function CultivationMarks.tierFrame(icon: GuiObject, tier: Tier?)
	local frame = icon:FindFirstChild("TierFrame") :: ImageLabel?
	local spec = tier and TIERS[tier]
	if not spec then
		if frame then
			frame:Destroy()
		end
		return
	end
	local made = frame or CultivationGui.template("TierFrame") :: ImageLabel
	made.Image = spec.image
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.Position = UDim2.fromScale(0.5, 0.5)
	made.Size = UDim2.fromScale(spec.x, spec.y)
	made.Parent = icon
end

function CultivationMarks.bloodline(parent: Instance, kind: "Pure" | "Inherited"): ImageLabel
	local badge = CultivationGui.template("Bloodline") :: ImageLabel
	badge.Image = BLOODLINES[kind]
	fill(badge, parent)
	return badge
end

function CultivationMarks.heavenMark(parent: Instance): ImageLabel
	local mark = CultivationGui.template("HeavenMark") :: ImageLabel
	fill(mark, parent)
	return mark
end

-- A row of every mark at real size in the middle of the screen, for a while.
function CultivationMarks.preview(seconds: number?)
	local canvas = CultivationGui.get():FindFirstChild("Canvas") :: Frame
	local old = canvas:FindFirstChild("MarksPreview")
	if old then
		old:Destroy()
	end
	local sheet = Instance.new("Frame")
	sheet.Name = "MarksPreview"
	sheet.BackgroundTransparency = 1
	sheet.AnchorPoint = Vector2.new(0.5, 0.5)
	sheet.Position = UDim2.fromScale(0.5, 0.5)
	sheet.Size = UDim2.fromOffset(900, 110)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 28)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = sheet
	local order = 0
	local function slot(width: number, height: number): Frame
		order += 1
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromOffset(width, height)
		f.LayoutOrder = order
		f.Parent = sheet
		return f
	end
	CultivationMarks.daoRing(slot(96, 94), 5)
	CultivationMarks.daoRing(slot(96, 94), MASTERED)
	for tier = 1, 4 do
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Image = "rbxassetid://86085933890312" -- a sample skill icon (the Iron Jian)
		fill(icon, slot(60, 60))
		CultivationMarks.tierFrame(icon, tier)
	end
	CultivationMarks.bloodline(slot(44, 46), "Pure")
	CultivationMarks.bloodline(slot(44, 46), "Inherited")
	CultivationMarks.heavenMark(slot(40, 47))
	sheet.Parent = canvas
	task.delay(seconds or 8, function()
		sheet:Destroy()
	end)
end

return CultivationMarks
