--!strict
-- Appearance step: skin colour (one swatch per SkinColors entry; "Avatar" keeps
-- the player's own skin), then Shirt and Pants, one card per option in
-- Shared.CharacterCreator.Clothing. A tap selects and dresses the preview.
-- Every outfit card shows the same thing (user, 2026-10-23: one card showed the
-- raw clothing template, the others a glyph): a small live dummy in the card's
-- well wearing that piece with the other piece the player has chosen, in their
-- skin, framed on the torso (shirts) or the legs (pants). Same pattern as the
-- Inventory's weapon models (WeaponView): a static model in a ViewportFrame
-- redraws only when it changes. An option with no template yet (AssetId 0) shows
-- the bare body until it gets one.

local Look = require(script.Parent.Parent.Look)

local Appearance = {}

local FOV = 20
local YAW = math.rad(-14) -- the stage's three-quarter turn
-- what each card frames, in the dummy's space (feet at y 0, head top at 5): the
-- centre height and the studs of height kept in view
local FRAMING = {
	Shirt = { y = 3.25, height = 4.5 }, -- the head, torso and arms, clear of the edge
	Pants = { y = 1.4, height = 3.4 }, -- the hips and legs
}

type View = { dummy: Model, kind: string }

-- A dummy standing in a card's View, its camera framing the piece.
local function makeView(card: any, kind: string, templates: Instance): View
	local view = card.view :: ViewportFrame
	local world = view:FindFirstChild("World") :: WorldModel
	local dummy = (templates:FindFirstChild("Dummy") :: Model):Clone()
	dummy:PivotTo(dummy:GetPivot() * CFrame.Angles(0, YAW, 0))
	dummy.Parent = world
	-- a Camera saved inside a ViewportFrame is lost in the Rojo sync: made here
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	local frame = FRAMING[kind]
	local distance = (frame.height / 2) / math.tan(math.rad(FOV / 2))
	-- the dummy faces -Z, so the camera stands on that side
	camera.CFrame = CFrame.lookAt(Vector3.new(0, frame.y, -distance), Vector3.new(0, frame.y, 0))
	camera.Parent = view
	view.CurrentCamera = camera
	return { dummy = dummy, kind = kind }
end

local function wear(dummy: Model, kind: string, template: string)
	local clothing = dummy:FindFirstChild(kind)
	if clothing and clothing:IsA("Shirt") then
		clothing.ShirtTemplate = template
	elseif clothing and clothing:IsA("Pants") then
		clothing.PantsTemplate = template
	end
end

function Appearance.build(page: ScrollingFrame, ctx: any)
	local state, defs, components = ctx.state, ctx.defs, ctx.components
	local views: { { view: View, option: any } } = {}

	-- every card dummy in the stage dummy's skin
	local function paintBodies()
		for _, entry in views do
			ctx.preview.copyBodyTo(entry.view.dummy)
		end
	end

	-- every card wears its own piece and the chosen other piece
	local function dressCards()
		task.spawn(function() -- the catalog templates may still be loading
			local chosen = {
				Shirt = Look.template("Shirt", state:get("Shirt")),
				Pants = Look.template("Pants", state:get("Pants")),
			}
			for _, entry in views do
				local own = entry.view.kind
				local other = if own == "Shirt" then "Pants" else "Shirt"
				wear(entry.view.dummy, own, Look.template(own, entry.option.Id))
				wear(entry.view.dummy, other, chosen[other])
			end
		end)
	end

	-- Skin
	components.section(page, "Skin", 1)
	local skinGrid = components.grid(page, "SwatchGrid", 2, "SkinGrid")
	local skinName = components.note(page, "", 3, "SkinName")
	local swatches = {}
	for order, entry in defs.SkinColors do
		local shown = entry.Color or Color3.fromRGB(205, 170, 140) -- a neutral tone stands for the avatar's own
		swatches[entry.Id] = components.swatch(skinGrid, entry.Id, shown, order, function()
			state:set("SkinColor", entry.Id)
		end)
	end
	local function paintSkin()
		local current = state:get("SkinColor")
		for id, swatch in swatches do
			swatch.setSelected(id == current)
		end
		for _, entry in defs.SkinColors do
			if entry.Id == current then
				skinName.Text = entry.DisplayName
				ctx.preview.chooseSkin(entry.Color)
			end
		end
		paintBodies()
	end

	local painters = {}
	for index, kind in { "Shirt", "Pants" } do
		components.section(page, kind, 2 + index * 2)
		local grid = components.grid(page, "CardGrid", 3 + index * 2, kind .. "Grid")
		local cards = {}
		for order, option in defs.Clothing[kind] do
			local card = components.card(grid, {
				id = option.Id,
				caption = option.DisplayName,
				order = order,
				onClick = function()
					state:set(kind, option.Id)
				end,
			})
			cards[option.Id] = card
			table.insert(views, { view = makeView(card, kind, ctx.templates), option = option })
		end
		painters[kind] = function()
			for id, card in cards do
				card.setSelected(id == state:get(kind))
			end
			task.spawn(function() -- the catalog templates may still be loading
				ctx.preview.setClothing(kind, Look.template(kind, state:get(kind)))
			end)
			dressCards()
		end
	end

	state:onChanged(function(key)
		if key == "SkinColor" then
			paintSkin()
		elseif painters[key] then
			painters[key]()
		end
	end)

	local handle = {}
	-- repaint everything from the state (the creator starting on a look)
	function handle.reset()
		paintSkin()
		painters.Shirt()
		painters.Pants()
	end
	handle.reset()
	return handle
end

return Appearance
