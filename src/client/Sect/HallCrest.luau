--!strict
-- Hall crests (docs/ui/halls-masters.md, "Hall crest"): a shield shape, an
-- optional border ring and an emblem, layered from the C3 cuts. The builder
-- window lets a Hall's founder pick each part, see the crest, and confirm.
--
-- API (client):
--   HallCrest.compose(crest: Frame, spec)  paint any Crest instance (template
--                                          Canvas.Templates.Crest) from a spec
--   HallCrest.openBuilder(opts)            pick, preview, confirm
--   HallCrest.preview()
--
-- spec = { shield = "round" | "kite" | "banner" | "hexagon" | "lotus",
--          ring = "cloud" | "dragon" | "plain" | nil,
--          emblem = "sword" | "peak" | "lotus" | "crane" | "tortoise" | "flame" }
-- opts = { name = string?, spec = spec?, onConfirm = (spec) -> () }

local Art = require(script.Parent.Art)
local Ui = require(script.Parent.Ui)

local HallCrest = {}

export type Spec = { shield: string, ring: string?, emblem: string }

HallCrest.SHIELDS = { "round", "kite", "banner", "hexagon", "lotus" }
HallCrest.RINGS = { "none", "cloud", "dragon", "plain" }
HallCrest.EMBLEMS = { "sword", "peak", "lotus", "crane", "tortoise", "flame" }
HallCrest.DEFAULT = { shield = "round", ring = "cloud", emblem = "crane" } :: Spec

-- How big each layer sits inside the one below, as a share of that layer's hole.
local RING_IN_SHIELD = 0.98
local EMBLEM_IN_RING = 0.8
local EMBLEM_IN_SHIELD = 0.66

-- Where a piece drawn ScaleType.Fit in a box puts its hole, in the box's scale
-- units: centre and the hole's smaller side.
local function holeIn(key: string, boxPos: Vector2, boxSize: number): (Vector2, number)
	local size = Art.Size[key]
	local hole = Art.Hole[key]
	local aspect = size.X / size.Y
	local w, h = boxSize * math.min(1, aspect), boxSize * math.min(1, 1 / aspect)
	local x0, y0 = boxPos.X - w / 2, boxPos.Y - h / 2
	local centre = Vector2.new(x0 + hole.centre.X * w, y0 + hole.centre.Y * h)
	return centre, math.min(hole.size.X * w, hole.size.Y * h)
end

function HallCrest.compose(crest: Frame, spec: Spec)
	local shieldKey = "shield_" .. spec.shield
	local shield = crest:FindFirstChild("Shield") :: ImageLabel
	local ring = crest:FindFirstChild("Ring") :: ImageLabel
	local emblem = crest:FindFirstChild("Emblem") :: ImageLabel
	shield.Image = Art.Id[shieldKey]
	local centre, holeSize = holeIn(shieldKey, Vector2.new(0.5, 0.5), 1)
	local emblemCentre, emblemSize = centre, holeSize * EMBLEM_IN_SHIELD
	local hasRing = spec.ring ~= nil and spec.ring ~= "none"
	ring.Visible = hasRing
	if hasRing then
		local ringKey = "crest_ring_" .. (spec.ring :: string)
		local ringSize = holeSize * RING_IN_SHIELD
		ring.Image = Art.Id[ringKey]
		ring.Position = UDim2.fromScale(centre.X, centre.Y)
		ring.Size = UDim2.fromScale(ringSize, ringSize)
		local c, s = holeIn(ringKey, centre, ringSize)
		emblemCentre, emblemSize = c, s * EMBLEM_IN_RING
	end
	emblem.Image = Art.Id["emblem_" .. spec.emblem]
	emblem.Position = UDim2.fromScale(emblemCentre.X, emblemCentre.Y)
	emblem.Size = UDim2.fromScale(emblemSize, emblemSize)
end

local function window(): Frame
	return Ui.window("HallCrest")
end

local function fillOptions(group: Frame, choices: { string }, prefix: string, pick: string, onPick: (string) -> ())
	local options = group:FindFirstChild("Options") :: Frame
	Ui.clearRows(options)
	local tiles: { [string]: ImageButton } = {}
	for i, choice in choices do
		local tile = Ui.clone("OptionTile") :: ImageButton
		tile.Name = "Row"
		tile.LayoutOrder = i
		local piece = tile:FindFirstChild("Piece") :: ImageLabel
		local label = tile:FindFirstChild("Label") :: TextLabel
		if choice == "none" then
			piece.Visible = false
			label.Visible = true
		else
			piece.Image = Art.Id[prefix .. choice]
		end
		tile.Image = Art.Id[if choice == pick then "tile_gold" else "tile_neutral"]
		tiles[choice] = tile
		tile.Activated:Connect(function()
			for c, t in tiles do
				t.Image = Art.Id[if c == choice then "tile_gold" else "tile_neutral"]
			end
			onPick(choice)
		end)
		tile.Parent = options
	end
end

export type BuilderOptions = { name: string?, spec: Spec?, onConfirm: ((spec: Spec) -> ())? }

local confirmConn: RBXScriptConnection? = nil

function HallCrest.openBuilder(opts: BuilderOptions)
	local w = window()
	local content = w:FindFirstChild("Content") :: Frame
	local left = content:FindFirstChild("Left") :: Frame
	local pickers = content:FindFirstChild("Pickers") :: Frame
	local base = opts.spec or HallCrest.DEFAULT
	local spec: Spec = { shield = base.shield, ring = base.ring or "none", emblem = base.emblem }
	local preview = left:FindFirstChild("Preview") :: Frame
	local function repaint()
		HallCrest.compose(preview, spec)
	end
	(left:FindFirstChild("HallName") :: TextLabel).Text = opts.name or ""
	fillOptions(pickers:FindFirstChild("Shield") :: Frame, HallCrest.SHIELDS, "shield_", spec.shield, function(c)
		spec.shield = c
		repaint()
	end)
	fillOptions(pickers:FindFirstChild("Ring") :: Frame, HallCrest.RINGS, "crest_ring_", spec.ring or "none", function(c)
		spec.ring = c
		repaint()
	end)
	fillOptions(pickers:FindFirstChild("Emblem") :: Frame, HallCrest.EMBLEMS, "emblem_", spec.emblem, function(c)
		spec.emblem = c
		repaint()
	end)
	repaint()
	if confirmConn then
		confirmConn:Disconnect()
	end
	confirmConn = (left:FindFirstChild("Confirm") :: GuiButton).Activated:Connect(function()
		local chosen: Spec = { shield = spec.shield, ring = if spec.ring == "none" then nil else spec.ring, emblem = spec.emblem }
		if opts.onConfirm then
			opts.onConfirm(chosen)
		end
		Ui.close(w)
	end)
	if not w.Visible then
		Ui.open(w)
	end
end

function HallCrest.preview()
	HallCrest.openBuilder({
		name = "Azure Cloud Hall",
		spec = { shield = "kite", ring = "dragon", emblem = "tortoise" },
		onConfirm = function(spec)
			print("HallCrest.preview: confirm", spec.shield, spec.ring, spec.emblem)
		end,
	})
end

return HallCrest
