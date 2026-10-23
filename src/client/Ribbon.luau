--!strict
-- Three-part title ribbons and name plaques (cap, plain middle, cap) that fit
-- their text (docs/ui/ribbons.md). The middle is sized from the text's bounds
-- plus even padding, so the text always sits on the plain band and never under a
-- cap; the caps keep their true aspect. Too long: the ribbon grows to its max
-- width, then the text shrinks a little, then it truncates.
--
-- Authored shape (any screen):
--   Holder (Frame, any AnchorPoint; its height is authored, its width is set here)
--     Art (Frame, Size 1,0,1,0; optional, else the caps sit on the holder itself)
--       CapL, Mid, CapR (ImageLabels; with or without a horizontal UIListLayout)
--     <label> (TextLabel, AnchorPoint 0.5,0.5; centred here on the middle's band)
--
-- Sizes are in the holder's own units (baseline pixels inside a UiScale canvas):
-- absolute size divided by every UIScale on and above the holder, so a Motion pop
-- in progress doesn't skew it.

local TextService = game:GetService("TextService")

local Ribbon = {}

export type Style = {
	capL: string,
	mid: string,
	capR: string,
	ratioL: number, -- cap width / height, from the PNGs
	ratioR: number,
	centre: number, -- the plain band's centre, 0-1 of the height
	band: number, -- the plain band's height, 0-1
	-- clear share of the images' height above and below the art (display-sized
	-- copies keep a margin so their tips aren't cut flat, art/ui/sized): the Art
	-- frame grows by it so the art fills the holder's height; ratios, centre and
	-- band are of the whole image
	margin: number?,
}

-- Cut from the house plaques (art/ui/plaque/derive.py): pointed, bevelled ends with
-- a diamond stud, a dark lacquer middle. The caps are display-sized copies with a
-- clear margin at the outer end (art/ui/sized), so the point isn't cut flat; the
-- ratios are those copies' sizes. The inner band is rows 23-72 of 96 (ruby)
-- and 23-88 of 112 (gold); both centre on 0.5 within a quarter pixel.
Ribbon.STYLES = {
	ruby = {
		capL = "rbxassetid://72601847318806",
		mid = "rbxassetid://120248080624596",
		capR = "rbxassetid://131307493204435",
		ratioL = 66 / 96,
		ratioR = 66 / 96,
		centre = 0.5,
		band = 50 / 96,
	},
	ruby_curl = {
		capL = "rbxassetid://107883713716005",
		mid = "rbxassetid://120248080624596",
		capR = "rbxassetid://113538297333791",
		ratioL = 126 / 96,
		ratioR = 126 / 96,
		centre = 0.5,
		band = 50 / 96,
	},
	gold = {
		capL = "rbxassetid://138442834914617",
		mid = "rbxassetid://99954964250094",
		capR = "rbxassetid://123625769072581",
		ratioL = 67 / 96,
		ratioR = 67 / 96,
		centre = 0.5,
		band = 66 / 112,
	},
	gold_curl = {
		capL = "rbxassetid://74457213778141",
		mid = "rbxassetid://99954964250094",
		capR = "rbxassetid://71807443800914",
		ratioL = 147 / 104,
		ratioR = 147 / 104,
		centre = 0.5,
		band = 66 / 112,
	},
	-- The mutation tags (art/ui/codex/c1/mutation_tags, SLICE3 cuts, sized to 48 px of
	-- art with a 4 px clear margin so the end studs aren't cut flat): a gilt rim and
	-- a coloured fill, its plain band rows 13-43 of 56.
	tag_bronze = {
		capL = "rbxassetid://137005527629130",
		mid = "rbxassetid://85227427905076",
		capR = "rbxassetid://113863411948649",
		ratioL = 65 / 56,
		ratioR = 53 / 56,
		centre = 0.5,
		band = 30 / 56,
		margin = 4 / 56,
	},
	tag_jade = {
		capL = "rbxassetid://128782698499602",
		mid = "rbxassetid://83799941832305",
		capR = "rbxassetid://96717712530591",
		ratioL = 65 / 56,
		ratioR = 53 / 56,
		centre = 0.5,
		band = 30 / 56,
		margin = 4 / 56,
	},
	tag_crimson = {
		capL = "rbxassetid://132793539047568",
		mid = "rbxassetid://82720329502106",
		capR = "rbxassetid://97069778488255",
		ratioL = 60 / 56,
		ratioR = 52 / 56,
		centre = 0.5,
		band = 30 / 56,
		margin = 4 / 56,
	},
	tag_violet = {
		capL = "rbxassetid://101588361388733",
		mid = "rbxassetid://71894795781302",
		capR = "rbxassetid://129517930723679",
		ratioL = 65 / 56,
		ratioR = 59 / 56,
		centre = 0.5,
		band = 30 / 56,
		margin = 4 / 56,
	},
	tag_gold = {
		capL = "rbxassetid://126824681512637",
		mid = "rbxassetid://115218224574664",
		capR = "rbxassetid://110080354440062",
		ratioL = 71 / 56,
		ratioR = 64 / 56,
		centre = 0.5,
		band = 30 / 56,
		margin = 4 / 56,
	},
} :: { [string]: Style }

export type Options = {
	style: (string | Style)?, -- a STYLES name or a Style; nil keeps the authored images
	label: string?, -- the text label's name (default "Title")
	textSize: number, -- preferred text size, in the holder's units
	minTextSize: number?, -- shrink no further than this, then truncate (default 85 % of textSize)
	pad: number?, -- room between the text and each cap, as a fraction of the height (default 0.4)
	minMid: number?, -- the plain middle's least width, in the holder's units (default 1.6 x height)
	maxWidth: number?, -- the whole ribbon's greatest width (default: no limit)
	height: number?, -- the holder's height, when it can't be read yet
}

type Fit = { text: string, opts: Options, height: number }

local fits: { [Instance]: Fit } = {}
local widths: { [string]: number } = {}

local function scaleAbove(obj: Instance): number
	local s = 1
	local node: Instance? = obj
	while node and not node:IsA("LayerCollector") do
		for _, child in node:GetChildren() do
			if child:IsA("UIScale") then
				s *= child.Scale
			end
		end
		node = node.Parent
	end
	return s
end

-- The holder's height in its own units.
function Ribbon.height(holder: GuiObject): number
	local s = scaleAbove(holder)
	local h = if s > 0 then holder.AbsoluteSize.Y / s else 0
	if h <= 0 then
		h = holder.Size.Y.Offset
	end
	return h
end

-- The text's width at a size (cached; GetTextBoundsAsync can yield the first time).
function Ribbon.textWidth(text: string, font: Font, size: number): number
	local key = `{font.Family}|{font.Weight.Name}|{font.Style.Name}|{size}|{text}`
	local known = widths[key]
	if known then
		return known
	end
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = font
	params.Size = size
	params.Width = 100000
	local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	local w = if ok then (bounds :: Vector2).X else #text * size * 0.55
	widths[key] = w
	return w
end

local function styleOf(opts: Options): Style?
	local s = opts.style
	if type(s) == "string" then
		return Ribbon.STYLES[s]
	end
	return s :: Style?
end

local function setRatio(cap: ImageLabel, ratio: number)
	local c = cap:FindFirstChildOfClass("UIAspectRatioConstraint")
	if c then
		c.AspectRatio = ratio
	end
end

export type Result = { width: number, mid: number, textSize: number, truncated: boolean }

local function apply(holder: GuiObject, fit: Fit): Result
	local opts = fit.opts
	local h = fit.height
	local art = (holder:FindFirstChild("Art") or holder) :: GuiObject
	local capL = art:FindFirstChild("CapL") :: ImageLabel
	local mid = art:FindFirstChild("Mid") :: ImageLabel
	local capR = art:FindFirstChild("CapR") :: ImageLabel
	local label = holder:FindFirstChild(opts.label or "Title") :: TextLabel
	local style = styleOf(opts)
	local ratioL, ratioR, centre, band
	local grow = 1 -- the Art frame's height over the holder's
	if style then
		ratioL, ratioR, centre, band = style.ratioL, style.ratioR, style.centre, style.band
		local vm = style.margin or 0
		if vm > 0 and art ~= holder then
			grow = 1 / (1 - 2 * vm)
			art.AnchorPoint = Vector2.zero
			art.Size = UDim2.new(art.Size.X, UDim.new(grow, 0))
			art.Position = UDim2.new(art.Position.X, UDim.new(-vm * grow, 0))
			-- the image's fractions on the holder
			centre, band = (centre - vm) * grow, band * grow
		end
	else
		local cl = capL:FindFirstChildOfClass("UIAspectRatioConstraint")
		local cr = capR:FindFirstChildOfClass("UIAspectRatioConstraint")
		ratioL = if cl then cl.AspectRatio else capL.Size.X.Offset / h
		ratioR = if cr then cr.AspectRatio else capR.Size.X.Offset / h
		centre, band = label.Position.Y.Scale, label.Size.Y.Scale
	end

	-- whole pixels, so the seams and the two paddings come out even on screen
	local capLW, capRW = math.round(h * grow * ratioL), math.round(h * grow * ratioR)
	local pad = math.round(h * (opts.pad or 0.4))
	local minMid = opts.minMid or h * 1.6
	local maxMid = if opts.maxWidth then math.max(minMid, opts.maxWidth - capLW - capRW) else math.huge
	local font = label.FontFace
	local size = opts.textSize
	local floor = opts.minTextSize or math.floor(size * 0.85)
	local text = fit.text
	local tw = Ribbon.textWidth(text, font, size)
	while tw + 2 * pad > maxMid and size > floor do
		size -= 1
		tw = Ribbon.textWidth(text, font, size)
	end
	local truncated = tw + 2 * pad > maxMid
	if fits[holder] ~= fit then
		-- a newer fit started while this one measured; it wins
		return { width = holder.Size.X.Offset, mid = mid.Size.X.Offset, textSize = label.TextSize, truncated = false }
	end
	if style then
		capL.Image = style.capL
		mid.Image = style.mid
		capR.Image = style.capR
	end
	setRatio(capL, ratioL)
	setRatio(capR, ratioR)
	local midW = math.floor(math.clamp(math.ceil(tw + 2 * pad), minMid, maxMid))
	if (midW - math.ceil(tw)) % 2 == 1 then
		-- an odd leftover can't split evenly round centred text; give the middle one more pixel
		midW += 1
	end
	local total = capLW + midW + capRW

	holder.Size = UDim2.new(0, total, holder.Size.Y.Scale, holder.Size.Y.Offset)
	capL.Size = UDim2.new(0, capLW, 1, 0)
	mid.Size = UDim2.new(0, midW, 1, 0)
	capR.Size = UDim2.new(0, capRW, 1, 0)
	if not art:FindFirstChildOfClass("UIListLayout") then
		capL.AnchorPoint, mid.AnchorPoint, capR.AnchorPoint = Vector2.zero, Vector2.zero, Vector2.zero
		capL.Position = UDim2.new()
		mid.Position = UDim2.fromOffset(capLW, 0)
		capR.Position = UDim2.fromOffset(capLW + midW, 0)
	end
	local flex = mid:FindFirstChildOfClass("UIFlexItem")
	if flex then
		flex.FlexMode = Enum.UIFlexMode.None
	end

	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0, capLW + midW / 2, centre, 0)
	label.Size = UDim2.new(0, midW - 2 * pad, band, 0)
	label.TextScaled = false
	label.TextSize = size
	label.TextWrapped = false
	label.TextTruncate = if truncated then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		limit.MinTextSize = 1
		limit.MaxTextSize = math.max(size, 1)
	end
	label.Text = text
	return { width = total, mid = midW, textSize = size, truncated = truncated }
end

-- Fit a ribbon to its text (and set the text). May yield the first time a text is
-- measured. Refits by itself if the holder's height changes later.
function Ribbon.fit(holder: GuiObject, text: string, opts: Options): Result
	local old = fits[holder]
	local fit: Fit = {
		text = text,
		opts = opts,
		height = opts.height or Ribbon.height(holder),
	}
	fits[holder] = fit
	local label = holder:FindFirstChild(opts.label or "Title")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
	if not old then
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			local f = fits[holder]
			if not f or f.opts.height then
				return
			end
			local h = Ribbon.height(holder)
			if h > 0 and math.abs(h - f.height) > 0.5 then
				f.height = h
				apply(holder, f)
			end
		end)
		holder.Destroying:Connect(function()
			fits[holder] = nil
		end)
	end
	return apply(holder, fit)
end

return Ribbon
