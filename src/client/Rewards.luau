--!strict
-- Reward banners (StarterGui.Rewards, roadmap 3c): one API, Rewards.show(spec), with
-- four tiers. docs/ui/rewards.md has the contract, layout and art.
--   small   a floating number or short line that rises and fades (spec.text, an
--           optional icon key or image, a colour, and `at`: a world point or a
--           screen point in 0-1 scale; default just above the bottom stack).
--   feed    a row in the reward feed (spec.key, spec.amount). Gaining the same thing
--           again while its row is up adds to it and pops the count ("x23" -> "x24"),
--           so fast farming reads as one climbing number. Rows fade a few seconds
--           after their last gain; the oldest go first when the feed is full.
--   banner  a ribbon across the top: kicker, title, tag, subtitle, in a jade,
--           gold or crimson style (the region entry banner, notable gains,
--           onboarding objectives). One at a time, queued; cleared by a menu.
--   card    one card, three jobs (spec.kind): "boss" victory (crimson card, boss
--           rays), "quest" complete (gold and jade card with the crest), and
--           "milestone" (a breakthrough or bloodline: the quest card with the
--           milestone rays; "rank", a sect rank-up, shows the rank crest). It shows reward tiles, stat deltas, the new unlock and
--           one line of flavour. Skippable (click or tap after a beat), closes by
--           itself, and queues one at a time; it waits while another window is open.
-- Fed by the server's Effect events: "stones", "loot", "insight", "manual",
-- "weapon", "method" (feed rows, and tiles on a boss card opened just before),
-- "boss" (the victory card), and "reward" (a whole spec table, for systems that
-- pick their own tier). Rewards.preview(tier, kind) shows sample content.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Items = require(ReplicatedStorage.Shared.Items)
local Methods = require(ReplicatedStorage.Shared.Methods)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)
local SelfCard = require(script.Parent.SelfCard)
local SlotArt = require(script.Parent.SlotArt)
local UiScale = require(script.Parent.UiScale)

-- Kit cuts (art/ui/assets.json, "codex/cut/ornament_*.png")
local ART = {
	card_boss = "rbxassetid://139872711040576",
	card_quest = "rbxassetid://120119552621110",
	rays_boss = "rbxassetid://95676207958916",
	rays_milestone = "rbxassetid://80839452828081",
	coin = "rbxassetid://91563334675271",
	emblem_peak = "rbxassetid://102118062177874",
	emblem_lotus = "rbxassetid://113579784709637",
	glyph_stone = "rbxassetid://76651936131955",
	glyph_qi = "rbxassetid://106989489487468",
	glyph_insight = "rbxassetid://98394523996866",
}
local TILES = {
	neutral = { tile = "rbxassetid://121233995525578" },
	grey = { tile = "rbxassetid://133101112606015", gem = "rbxassetid://100159022686196" },
	jade = { tile = "rbxassetid://77864281472596", gem = "rbxassetid://75556176975753" },
	violet = { tile = "rbxassetid://135960798811647", gem = "rbxassetid://123797664259882" },
	gold = { tile = "rbxassetid://138359555176757", gem = "rbxassetid://103434738704063" },
}
-- rarities and grades onto the kit's tile edges: the Inventory's ladder (Rarity.luau),
-- bronze, silver, jade, violet, gold
local TIER_OF = {
	Common = "neutral",
	Uncommon = "grey",
	Rare = "jade",
	Epic = "violet",
	Legendary = "gold",
	Mortal = "neutral",
	Spirit = "jade",
	Earth = "violet",
	Heaven = "gold",
}
-- Three-part ribbons: images, cap aspect ratios, and the height (0-1) of the body's
-- centre, where the title sits.
type Strip = { images: { string }, ratios: { number }, centre: number }
local STRIPS: { [string]: Strip } = {
	crimson = {
		images = { "rbxassetid://121316271063702", "rbxassetid://128154077838383", "rbxassetid://108527414387394" },
		ratios = { 242 / 151, 244 / 151 },
		centre = 76 / 151,
	},
	jade = {
		images = { "rbxassetid://107068274389031", "rbxassetid://72502727273386", "rbxassetid://124632452296572" },
		ratios = { 242 / 151, 244 / 151 },
		centre = 76 / 151,
	},
	gold = { -- the navy-and-gold objective banner
		images = { "rbxassetid://138264404301051", "rbxassetid://88637856112299", "rbxassetid://121398639569390" },
		ratios = { 233 / 125, 233 / 125 },
		centre = 72 / 125,
	},
}
-- Card layout per job, in fractions of the card art (measured in the PNGs: the boss
-- card's header strip is rows 46-96 of 596, its interior 102-558; the quest card's
-- crest ring is centred on row 90 of 652 and its interior ends at 632).
type Kind = {
	art: string,
	ratio: number,
	rays: string?,
	raysAt: Vector3?, -- the rays' centre (x, y in the card) and size (in card heights)
	ribbon: string,
	crest: string?,
	ribbonY: number,
	ribbonH: number,
	bodyTop: number,
	bodyBottom: number,
}
local KINDS: { [string]: Kind } = {
	boss = {
		art = ART.card_boss,
		ratio = 1024 / 596,
		rays = ART.rays_boss,
		raysAt = Vector3.new(0.5, 0.45, 1.35), -- a burst behind the whole card
		ribbon = "crimson",
		ribbonY = 71 / 596,
		ribbonH = 0.17,
		bodyTop = 0.22,
		bodyBottom = 0.93,
	},
	quest = {
		art = ART.card_quest,
		ratio = 1024 / 652,
		ribbon = "jade",
		crest = ART.emblem_peak,
		ribbonY = 0.315,
		ribbonH = 0.15,
		bodyTop = 0.395,
		bodyBottom = 0.95,
	},
	rank = { -- a sect rank-up: the quest card with the rank crest (spec.crest)
		art = ART.card_quest,
		ratio = 1024 / 652,
		rays = ART.rays_milestone,
		raysAt = Vector3.new(0.5, 0.12, 1.1),
		ribbon = "jade",
		crest = ART.emblem_peak,
		ribbonY = 0.315,
		ribbonH = 0.15,
		bodyTop = 0.395,
		bodyBottom = 0.95,
	},
	milestone = {
		art = ART.card_quest,
		ratio = 1024 / 652,
		rays = ART.rays_milestone,
		raysAt = Vector3.new(0.5, 0.12, 1.1), -- a soft glow rising from the crest
		ribbon = "crimson",
		crest = ART.emblem_lotus,
		ribbonY = 0.315,
		ribbonH = 0.15,
		bodyTop = 0.395,
		bodyBottom = 0.95,
	},
}

local GOLD = Color3.fromRGB(214, 172, 92)
local STONE_COLOR = Color3.fromRGB(200, 235, 255)
local QI_COLOR = Color3.fromRGB(120, 235, 180)
local CREAM = Color3.fromRGB(250, 236, 195)

local ENTRY_LIFE = 3.5 -- seconds a feed row stays after its last gain
local ENTRY_STEP = 34 -- feed row height plus padding, for the visible cap
local CARD_COLLECT = 1.5 -- seconds after a boss card that rewards join it
local CARD_MIN = 1.0 -- seconds before a click can close a card
local CARD_LIFE = 7 -- a card closes by itself after this
local RAY_SPEED = 10 -- degrees per second
local RAYS_ALPHA = 0.2
local BANNER_HOLD = 2.6
local BANNER_QUEUE_MAX = 3
local FLOAT_RISE = 40 -- baseline px a small float rises
local FLOAT_LIFE = 1.1

export type Item = { key: string, amount: number }
export type Stat = { name: string, from: any, to: any }
export type Spec = {
	tier: string, -- "small" | "feed" | "banner" | "card"
	-- small
	text: string?,
	icon: string?, -- a feed key ("stones", "qi", ...) or an image id
	color: Color3?,
	at: (Vector3 | Vector2)?,
	-- feed
	key: string?,
	amount: number?,
	-- banner and card
	title: string?,
	subtitle: string?,
	-- banner
	style: string?, -- "jade" | "gold" | "crimson"
	kicker: string?,
	kickerColor: Color3?,
	tag: string?, -- rich text
	tagColor: Color3?,
	hold: number?,
	-- card
	kind: string?, -- "boss" | "quest" | "milestone" | "rank"
	items: { Item }?,
	stats: { Stat }?,
	unlock: string?,
	flavour: string?,
	crest: (string | { image: string })?, -- image id for the crest slot (Sect rank-ups pass
	-- { image, emblem, hole }; only the image shows until the Crest has an Emblem child)
	life: number?,
}

type Look = {
	name: string,
	icon: string?,
	glyph: string?,
	color: Color3,
	tint: Color3?, -- for white kit glyphs
	coin: boolean?, -- currency: drawn in the coin frame
	tier: string?, -- tile edge for items
}
type Entry = { frame: GuiObject, count: number, last: number }

local Rewards = {}

local ready = false
local canvas: Frame
local feed: Frame
local entryTemplate: GuiObject
local floats: Frame
local floatTemplate: GuiObject
local banner: Frame
local card: Frame
local cardArt: ImageLabel
local list: Frame
local rewardTemplate: GuiObject
local entries: { [string]: Entry } = {}
local order = 0

local cardQueue: { Spec } = {}
local current: Spec? = nil
local tiles: { [string]: { frame: GuiObject, count: number } } = {}
local cardOpenedAt = 0
local collectSpec: Spec? = nil
local collectUntil = 0
local rayConn: RBXScriptConnection? = nil

local bannerQueue: { Spec } = {}
local bannerToken = 0
local bannerShowing = false

local function lookOf(key: string): Look?
	if key == "stones" then
		return { name = "Spirit Stones", icon = ART.glyph_stone, tint = STONE_COLOR, color = STONE_COLOR, coin = true }
	elseif key == "insight" then
		return { name = "Insight", icon = ART.glyph_insight, tint = GOLD, color = GOLD, coin = true }
	elseif key == "qi" then
		return { name = "Raw Qi", icon = ART.glyph_qi, tint = QI_COLOR, color = QI_COLOR, coin = true }
	elseif key == "contribution" then
		return { name = "Contribution", glyph = "功", color = GOLD, coin = true }
	elseif key:sub(1, 7) == "manual:" then
		local def = Techniques.Defs[key:sub(8)]
		return def and { name = `{def.name} manual`, glyph = "卷", color = GOLD, tier = "neutral" }
	elseif key:sub(1, 7) == "weapon:" then
		local id = key:sub(8)
		local def = Weapons.Defs[id]
		return def
			and {
				name = SlotArt.weaponName(id),
				icon = SlotArt.weaponIcon(id),
				color = SlotArt.weaponColor(id),
				tier = TIER_OF[def.grade] or "neutral",
			}
	elseif key:sub(1, 7) == "method:" then
		local def = Methods.Defs[key:sub(8)]
		if not def then
			return nil
		end
		local icon = SelfCard.rootIcon(def.element)
		return {
			name = def.name,
			icon = if icon ~= "" then icon else nil,
			glyph = "法",
			color = SelfCard.gradeColor(def.grade),
			tier = TIER_OF[def.grade] or "neutral",
		}
	end
	local item = Items.Defs[key]
	return item
		and {
			name = item.name,
			icon = item.icon,
			glyph = item.glyph,
			color = Items.rarityColor(item),
			tier = TIER_OF[item.rarity] or "neutral",
		}
end

-- The frame (coin or rarity tile), icon or glyph, gem, name and count on a feed row
-- or a card tile.
local function paint(frame: GuiObject, look: Look, count: number)
	local holder = (frame:FindFirstChild("Badge") or frame:FindFirstChild("Tile")) :: ImageLabel
	local tier = TILES[look.tier or "neutral"] or TILES.neutral
	holder.Image = if look.coin then ART.coin else tier.tile
	local gem = holder:FindFirstChild("Gem") :: ImageLabel?
	if gem then
		gem.Image = (tier :: any).gem or ""
		gem.Visible = not look.coin and (tier :: any).gem ~= nil
	end
	local icon = holder:FindFirstChild("Icon") :: ImageLabel
	local glyph = holder:FindFirstChild("Glyph") :: TextLabel
	icon.Image = look.icon or ""
	icon.ImageColor3 = look.tint or Color3.new(1, 1, 1)
	icon.Visible = look.icon ~= nil
	glyph.Text = look.glyph or ""
	glyph.TextColor3 = look.color
	glyph.Visible = look.icon == nil
	local name = frame:FindFirstChild("NameLabel", true) :: TextLabel
	name.Text = look.name
	if holder.Name == "Badge" then
		name.TextColor3 = if look.coin then CREAM else look.color
	end
	(frame:FindFirstChild("CountLabel", true) :: TextLabel).Text = `x{count}`
end

local function pop(frame: GuiObject)
	local scale = frame:FindFirstChild("Motion") :: UIScale?
	if scale then
		scale.Scale = 1.18
		Motion.tween(scale, { Scale = 1 }, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
	end
end

-- Fade a frame and everything drawn on it, then remove it.
local function fadeAway(frame: GuiObject, seconds: number)
	local info = TweenInfo.new(seconds)
	for _, obj in { frame, table.unpack(frame:GetDescendants()) } do
		if obj:IsA("ImageLabel") then
			TweenService:Create(obj, info, { ImageTransparency = 1 }):Play()
		elseif obj:IsA("TextLabel") then
			TweenService:Create(obj, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end
	task.delay(seconds + 0.05, function()
		frame:Destroy()
	end)
end

-- Small: floating numbers ------------------------------------------------------------

local function showSmall(spec: Spec)
	local frame = floatTemplate:Clone()
	local label = frame:FindFirstChild("Label") :: TextLabel
	local icon = frame:FindFirstChild("Icon") :: ImageLabel
	label.Text = spec.text or ""
	label.TextColor3 = spec.color or CREAM
	local look = spec.icon and lookOf(spec.icon)
	if look and look.icon then
		icon.Image = look.icon
		icon.ImageColor3 = look.tint or Color3.new(1, 1, 1)
		label.TextColor3 = spec.color or look.color
	elseif spec.icon and spec.icon:find("rbxassetid://", 1, true) then
		icon.Image = spec.icon
	else
		icon.Visible = false
	end
	-- where: a world point projected to the canvas, a screen point (0-1), or the
	-- default spot just above the bottom stack
	local at = spec.at
	local scale = (canvas:FindFirstChild("UiScale") :: UIScale).Scale
	local position = UDim2.fromScale(0.5, 0.62)
	if typeof(at) == "Vector3" then
		local camera = workspace.CurrentCamera
		local point, visible = camera:WorldToViewportPoint(at)
		if not visible then
			frame:Destroy()
			return
		end
		local inset = canvas.AbsolutePosition
		position = UDim2.fromOffset((point.X - inset.X) / scale, (point.Y - inset.Y) / scale)
	elseif typeof(at) == "Vector2" then
		position = UDim2.fromScale(at.X, at.Y)
	end
	position += UDim2.fromOffset(math.random(-24, 24), 0)
	frame.Position = position
	frame.Visible = true
	frame.Parent = floats
	local scaleObj = Instance.new("UIScale")
	scaleObj.Scale = 0.7
	scaleObj.Parent = frame
	TweenService:Create(scaleObj, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(frame, TweenInfo.new(FLOAT_LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = position - UDim2.fromOffset(0, FLOAT_RISE),
	}):Play()
	task.delay(FLOAT_LIFE - 0.4, fadeAway, frame, 0.4)
end

-- Feed ----------------------------------------------------------------------------

local function capacity(): number
	return math.max(1, math.floor((feed.AbsoluteSize.Y / (canvas:FindFirstChild("UiScale") :: UIScale).Scale + 4) / ENTRY_STEP))
end

local function dropOldest()
	local oldestKey, oldest = nil, math.huge
	for key, e in entries do
		if e.last < oldest then
			oldestKey, oldest = key, e.last
		end
	end
	if oldestKey then
		fadeAway(entries[oldestKey].frame, 0.35)
		entries[oldestKey] = nil
	end
end

local function feedGain(key: string, amount: number)
	local look = lookOf(key)
	if not look then
		return
	end
	local now = os.clock()
	local e = entries[key]
	if e then
		e.count += amount
		e.last = now
		paint(e.frame, look, e.count)
		pop(e.frame)
		return
	end
	local count = 0
	for _ in entries do
		count += 1
	end
	if count >= capacity() then
		dropOldest()
	end
	order += 1
	local frame = entryTemplate:Clone()
	frame.Name = "Entry"
	frame.LayoutOrder = order
	paint(frame, look, amount)
	frame.Visible = true
	frame.Parent = feed
	pop(frame)
	entries[key] = { frame = frame, count = amount, last = now }
end

-- Banner --------------------------------------------------------------------------

local function applyStrip(holder: Instance, style: string)
	local strip = STRIPS[style] or STRIPS.gold
	local art = holder:FindFirstChild("Art") :: Frame
	local capL = art:FindFirstChild("CapL") :: ImageLabel
	local capR = art:FindFirstChild("CapR") :: ImageLabel
	capL.Image = strip.images[1];
	(art:FindFirstChild("Mid") :: ImageLabel).Image = strip.images[2]
	capR.Image = strip.images[3];
	(capL:FindFirstChildOfClass("UIAspectRatioConstraint") :: UIAspectRatioConstraint).AspectRatio = strip.ratios[1];
	(capR:FindFirstChildOfClass("UIAspectRatioConstraint") :: UIAspectRatioConstraint).AspectRatio = strip.ratios[2]
	local title = holder:FindFirstChild("Title") :: TextLabel
	title.Position = UDim2.fromScale(0.5, strip.centre)
end

local function glint(holder: Instance, delay: number)
	local g = holder:FindFirstChild("Glint") :: ImageLabel?
	if not g then
		return
	end
	g.Position = UDim2.fromScale(-0.1, 0.5)
	g.ImageTransparency = 1
	local info = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, false, delay)
	TweenService:Create(g, info, { Position = UDim2.fromScale(1.1, 0.5) }):Play()
	TweenService:Create(g, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay), { ImageTransparency = 0.2 }):Play()
	TweenService:Create(g, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, delay + 0.35), { ImageTransparency = 1 }):Play()
end

local nextBanner: () -> ()

local function showBanner(spec: Spec)
	bannerToken += 1
	local token = bannerToken
	bannerShowing = true
	local ribbon = banner:FindFirstChild("Ribbon") :: Frame
	applyStrip(ribbon, spec.style or "gold")
	local kicker = banner:FindFirstChild("Kicker") :: TextLabel
	local tag = banner:FindFirstChild("Tag") :: TextLabel
	local subtitle = banner:FindFirstChild("Subtitle") :: TextLabel
	kicker.Text = spec.kicker or ""
	kicker.TextColor3 = spec.kickerColor or GOLD
	kicker.Visible = spec.kicker ~= nil;
	(ribbon:FindFirstChild("Title") :: TextLabel).Text = spec.title or ""
	tag.Text = spec.tag or ""
	tag.TextColor3 = spec.tagColor or CREAM
	tag.Visible = spec.tag ~= nil
	subtitle.Text = spec.subtitle or ""
	-- a phone's subtitle would render too small to read; the title and tag carry it
	subtitle.Visible = spec.subtitle ~= nil and not (Platform.isTouch() and Platform.isSmall())
	banner.Visible = true
	Motion.fadeIn(banner)
	glint(ribbon, 0.2)
	task.delay(spec.hold or BANNER_HOLD, function()
		if token ~= bannerToken then
			return
		end
		Motion.fadeOut(banner, function()
			if token == bannerToken then
				banner.Visible = false
				bannerShowing = false
				task.delay(0.15, nextBanner)
			end
		end)
	end)
end

nextBanner = function()
	if bannerShowing or Menus.isOpen() or #bannerQueue == 0 then
		return
	end
	showBanner(table.remove(bannerQueue, 1) :: Spec)
end

-- A window, minigame or card takes the screen: clear the banner out of its way.
local function clearBanner()
	if bannerShowing then
		bannerToken += 1
		bannerShowing = false
		banner.Visible = false
	end
end

-- Card ----------------------------------------------------------------------------

local nextCard: () -> ()

local function addTile(key: string, amount: number)
	local look = lookOf(key)
	if not look then
		return
	end
	local tile = tiles[key]
	if tile then
		tile.count += amount
		paint(tile.frame, look, tile.count)
		pop(tile.frame)
		return
	end
	local frame = rewardTemplate:Clone()
	frame.Name = "Reward"
	order += 1
	frame.LayoutOrder = order
	paint(frame, look, amount)
	frame.Visible = true
	frame.Parent = list
	pop(frame)
	tiles[key] = { frame = frame, count = amount }
	list.Visible = true
end

-- A reward arriving just after a boss kill joins that boss's card (open or queued).
local function cardGain(key: string, amount: number)
	local spec = collectSpec
	if not spec or os.clock() > collectUntil or not lookOf(key) then
		return
	end
	local items = spec.items or {}
	spec.items = items
	local found = false
	for _, item in items do
		if item.key == key then
			item.amount += amount
			found = true
		end
	end
	if not found then
		table.insert(items, { key = key, amount = amount })
	end
	if current == spec then
		addTile(key, amount)
	end
end

local function statsText(stats: { Stat }): string
	local parts = {}
	for _, s in stats do
		table.insert(parts, `{s.name}  {s.from} <font color="#fff1c8">→</font> {s.to}`)
	end
	return table.concat(parts, "     ")
end

local function closeCard()
	if not current then
		return
	end
	current = nil
	Motion.close(card)
	feed.Visible = true
	if rayConn then
		rayConn:Disconnect()
		rayConn = nil
	end
	task.delay(0.35, nextCard)
end

local function openCard(spec: Spec)
	local kind = KINDS[spec.kind or "boss"] or KINDS.boss
	current = spec
	for _, t in tiles do
		t.frame:Destroy()
	end
	table.clear(tiles)

	cardArt.Image = kind.art;
	(cardArt:FindFirstChildOfClass("UIAspectRatioConstraint") :: UIAspectRatioConstraint).AspectRatio = kind.ratio
	local crest = cardArt:FindFirstChild("Crest") :: ImageLabel
	local crestSpec = spec.crest
	crest.Image = (if type(crestSpec) == "table" then crestSpec.image else crestSpec) or kind.crest or ""
	crest.Visible = kind.crest ~= nil
	local ribbon = cardArt:FindFirstChild("Ribbon") :: Frame
	ribbon.Position = UDim2.fromScale(0.5, kind.ribbonY)
	ribbon.Size = UDim2.fromScale(0.74, kind.ribbonH)
	applyStrip(ribbon, kind.ribbon);
	(ribbon:FindFirstChild("Title") :: TextLabel).Text = spec.title or ""
	local body = cardArt:FindFirstChild("Body") :: Frame
	body.Position = UDim2.fromScale(0.5, kind.bodyTop)
	body.Size = UDim2.fromScale(0.84, kind.bodyBottom - kind.bodyTop)

	local function line(name: string, value: string?)
		local label = body:FindFirstChild(name) :: TextLabel
		label.Text = value or ""
		label.Visible = value ~= nil and value ~= ""
	end
	line("Subtitle", spec.subtitle)
	line("Stats", if spec.stats and #spec.stats > 0 then statsText(spec.stats) else nil)
	line("Unlock", spec.unlock)
	line("Flavour", spec.flavour)
	list.Visible = false
	for _, item in spec.items or {} do
		addTile(item.key, item.amount)
	end
	(cardArt:FindFirstChild("Hint") :: TextLabel).Text = if Platform.isTouch() then "Tap to continue" else "Click to continue"

	local rays = card:FindFirstChild("Rays") :: ImageLabel
	rays.Image = kind.rays or ""
	rays.Visible = kind.rays ~= nil
	local at = kind.raysAt or Vector3.new(0.5, 0.45, 1.35)
	rays.Position = UDim2.fromScale(at.X, at.Y)
	rays.Size = UDim2.fromScale(at.Z, at.Z)
	feed.Visible = false -- the card shows the tiles; the feed would sit on it on a phone
	cardOpenedAt = os.clock()
	Menus.open(card)
	glint(ribbon, 0.25)
	if kind.rays and not rayConn then
		rays.ImageTransparency = 1
		TweenService:Create(rays, TweenInfo.new(0.4), { ImageTransparency = RAYS_ALPHA }):Play()
		rayConn = RunService.RenderStepped:Connect(function(dt)
			rays.Rotation = (rays.Rotation + RAY_SPEED * dt) % 360
		end)
	end
	local opened = cardOpenedAt
	task.delay(spec.life or CARD_LIFE, function()
		if cardOpenedAt == opened and current == spec then
			closeCard()
		end
	end)
end

nextCard = function()
	if current or #cardQueue == 0 then
		return
	end
	-- wait while another window or minigame has the screen
	local open = Menus.current()
	if open and open ~= card then
		return
	end
	openCard(table.remove(cardQueue, 1) :: Spec)
end

-- The API ---------------------------------------------------------------------------

function Rewards.show(spec: Spec)
	if not ready then
		return
	end
	if spec.tier == "small" then
		showSmall(spec)
	elseif spec.tier == "feed" then
		if spec.key then
			feedGain(spec.key, spec.amount or 1)
		end
	elseif spec.tier == "banner" then
		table.insert(bannerQueue, spec)
		while #bannerQueue > BANNER_QUEUE_MAX do
			table.remove(bannerQueue, 1)
		end
		nextBanner()
	elseif spec.tier == "card" then
		if spec.kind == "boss" then
			collectSpec, collectUntil = spec, os.clock() + CARD_COLLECT
		end
		table.insert(cardQueue, spec)
		nextCard()
	end
end

local function gain(key: string, amount: number)
	feedGain(key, amount)
	cardGain(key, amount)
end

-- Sample content for each tier and job (testbed and client console only).
function Rewards.preview(tier: string?, kind: string?)
	tier = tier or "card"
	if tier == "small" then
		Rewards.show({ tier = "small", text = "+12", icon = "qi" })
		Rewards.show({ tier = "small", text = "+3", icon = "stones", at = Vector2.new(0.56, 0.58) })
	elseif tier == "feed" then
		for _, key in { "stones", "qi", "insight" } do
			Rewards.show({ tier = "feed", key = key, amount = math.random(1, 30) })
		end
	elseif tier == "banner" then
		local style = kind or "jade"
		Rewards.show({
			tier = "banner",
			style = style,
			kicker = if style == "gold" then "OBJECTIVE COMPLETE" else "YOU HAVE ENTERED",
			title = if style == "gold" then "Sit on your peak" else "Azure Cloud Sect",
			tag = if style == "crimson" then "Foundation 1  ·  Beyond your cultivation" else "Safe ground",
			subtitle = "Sample banner",
		})
	else
		local k = kind or "boss"
		if k == "boss" then
			Rewards.show({
				tier = "card",
				kind = "boss",
				title = "Victory",
				subtitle = "Elder Wolf King defeated",
				items = { { key = "qi", amount = 45 }, { key = "stones", amount = 120 } },
				flavour = "The forest breathes easier tonight.",
			})
		elseif k == "quest" then
			Rewards.show({
				tier = "card",
				kind = "quest",
				title = "Quest Complete",
				subtitle = "The Herbalist's Errand",
				items = { { key = "stones", amount = 60 }, { key = "insight", amount = 2 }, { key = "contribution", amount = 40 } },
				flavour = "The Herbalist nods: \"You may yet be useful.\"",
			})
		else
			Rewards.show({
				tier = "card",
				kind = "milestone",
				title = "Breakthrough",
				subtitle = "Qi Condensation 4",
				stats = { { name = "Health", from = 140, to = 165 }, { name = "Power", from = "1.20", to = "1.32" } },
				unlock = "New: the Inner Wilds array is open",
				flavour = "Your qi settles at a new depth.",
			})
		end
	end
end

function Rewards.init()
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Rewards") :: ScreenGui
	canvas = gui:WaitForChild("Canvas") :: Frame
	UiScale.fit(canvas)
	feed = canvas:FindFirstChild("Feed") :: Frame
	entryTemplate = feed:FindFirstChild("EntryTemplate") :: GuiObject
	floats = canvas:FindFirstChild("Floats") :: Frame
	floatTemplate = floats:FindFirstChild("FloatTemplate") :: GuiObject
	banner = canvas:FindFirstChild("Banner") :: Frame
	card = canvas:FindFirstChild("Card") :: Frame
	cardArt = card:FindFirstChild("Art") :: ImageLabel
	list = cardArt:FindFirstChild("List", true) :: Frame
	rewardTemplate = list:FindFirstChild("RewardTemplate") :: GuiObject
	banner.Visible = false
	card.Visible = false
	Menus.register(card, { close = closeCard })
	Menus.onChanged(function()
		if Menus.isOpen() then
			clearBanner()
		else
			nextCard()
			nextBanner()
		end
	end)
	ready = true;

	(ReplicatedStorage.Remotes.Effect :: RemoteEvent).OnClientEvent:Connect(function(kind: string, ...)
		local args = { ... }
		if kind == "stones" then
			gain("stones", args[2])
		elseif kind == "loot" then
			gain(args[1], args[2])
		elseif kind == "insight" then
			gain("insight", args[1])
		elseif kind == "manual" then
			gain(`manual:{args[1]}`, 1)
		elseif kind == "weapon" then
			gain(`weapon:{args[1]}`, 1)
		elseif kind == "method" then
			gain(`method:{args[1]}`, 1)
		elseif kind == "boss" then
			local qi = args[2] or 0
			Rewards.show({
				tier = "card",
				kind = "boss",
				title = "Victory",
				subtitle = `{args[1]} defeated`,
				items = if qi > 0 then { { key = "qi", amount = qi } } else {},
			})
		elseif kind == "reward" and type(args[1]) == "table" then
			Rewards.show(args[1])
		end
	end)

	UserInputService.InputBegan:Connect(function(input)
		local click = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		if click and current and card.Visible and os.clock() - cardOpenedAt >= CARD_MIN then
			closeCard()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for key, e in entries do
				if now - e.last > ENTRY_LIFE then
					fadeAway(e.frame, 0.35)
					entries[key] = nil
				end
			end
		end
	end)
end

return Rewards
