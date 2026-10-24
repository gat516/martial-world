--!strict
-- The hold fill on a world-prompt card (WorldPrompts): a lit line that runs once
-- round the card's whole outline, clockwise from the top centre, as a hold
-- fills. Authored in the card's `Hold` frame (StarterGui.Prompts.Board.List.Card,
-- tools/build_prompts.luau) as nine pieces that trace the rounded outline:
--   TopR, Right, Bottom, Left, TopL  straight runs (Frames, the line's thickness)
--   TR, BR, BL, TL                   corners: an r x r clip holding a 2r ring (a
--                                    round Frame with an Inner UIStroke) whose
--                                    stroke UIGradient has a hard edge; turning
--                                    it sweeps the quarter arc open
-- Each piece fills in turn by its share of the outline's length, so the line
-- moves at one speed round straights and corners alike, at any card width.
-- The radius and thickness are read off the pieces (TR's size, TopR's height).

local PromptHold = {}

local HALF_PI = math.pi / 2

-- corner name -> the screen angle its sweep starts at (degrees, clockwise from +x)
local CORNER_START = { TR = -90, BR = 0, BL = 90, TL = 180 }

local function sweep(corner: Frame, f: number, start: number)
	local ring = corner:FindFirstChild("Ring") :: Frame
	local stroke = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
	local gradient = stroke:FindFirstChildOfClass("UIGradient") :: UIGradient
	corner.Visible = f > 0
	-- the hard edge's opaque side covers screen angles (c - 180, c); see the header
	gradient.Rotation = start + 90 * math.clamp(f, 0, 1) + 90
end

local function run(piece: Frame, f: number, length: number, vertical: boolean)
	local n = math.clamp(f, 0, 1) * length
	piece.Visible = n > 0.25
	local size = piece.Size
	piece.Size = if vertical
		then UDim2.new(0, size.X.Offset, 0, n)
		else UDim2.new(0, n, 0, size.Y.Offset)
end

-- Show progress p (0..1) on a card of size (w, h) in authored pixels.
function PromptHold.set(hold: Frame, p: number, w: number, h: number)
	local tr = hold:FindFirstChild("TR") :: Frame
	local r = math.min(tr.Size.X.Offset, h / 2, w / 2)
	local arc = HALF_PI * r
	local halfTop = math.max(w / 2 - r, 0)
	local side = math.max(h - 2 * r, 0)
	local bottom = math.max(w - 2 * r, 0)
	-- the outline in order, clockwise from the top centre
	local order: { { any } } = {
		{ "TopR", halfTop },
		{ "TR", arc },
		{ "Right", side },
		{ "BR", arc },
		{ "Bottom", bottom },
		{ "BL", arc },
		{ "Left", side },
		{ "TL", arc },
		{ "TopL", halfTop },
	}
	local total = 0
	for _, piece in order do
		total += piece[2]
	end
	local at = math.clamp(p, 0, 1) * total
	for _, piece in order do
		local name: string, length: number = piece[1], piece[2]
		local f = if length > 0 then math.clamp(at / length, 0, 1) else (if at > 0 then 1 else 0)
		at -= length
		local inst = hold:FindFirstChild(name) :: Frame
		local start = CORNER_START[name]
		if start then
			sweep(inst, f, start)
		else
			run(inst, f, length, name == "Right" or name == "Left")
		end
	end
end

return PromptHold
