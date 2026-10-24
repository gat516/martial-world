--!strict
-- Enemy health, Souls-style. Each regular enemy's overhead bar (its HealthBar
-- BillboardGui, Dead Cells style: Plate > Strip (NameLabel, RealmTag), Bar
-- (Aura, Back, Window > Trail/Fill, Rim), Omen; and Warning > Skull, Omen) shows
-- only while it's locked or for a while after it's hurt. The fill drops at once
-- and the trail drains after it, so each hit's size reads at a glance. The bar is
-- cut into ten talisman slips (10% of health each), drawn into the Rim art.
-- Its dressing follows the beast's danger to you: the realm gap between it and
-- the player picks a STYLES tier (thresholds in Pacing.Danger), re-picked when
-- the player breaks through. The top tier hides the bar and health entirely and
-- shows a pulsing skull seal whenever the beast is in range, as a warning.
-- Bosses skip the overhead bar: the boss you're fighting (locked, or the nearest
-- one hunting you) gets the themed screen bar, Play.BossBar (BossBars.luau,
-- BossThemes.luau), dressed with the same danger tiers (STYLES) as the overhead bars.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local LockOn = require(script.Parent.LockOn)
local BossBars = require(script.Parent.BossBars)
local Motion = require(script.Parent.Motion)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Realms = require(ReplicatedStorage.Shared.Realms)

local SHOW_AFTER_HURT = 8 -- seconds an overhead bar stays up after a hit
local BOSS_RANGE = 60 -- a boss this close that's after you takes the screen bar
local TRAIL = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.45)

local AURA_PULSE = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local SHEEN_SWEEP = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 1.2)
local SKULL_PULSE = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-- Danger tiers, picked by realm gap (Pacing.Danger). rim: the frame art (art/ui
-- draw_ui.py eb_rim); tag/omen: text colours; omens: flavour lines, one picked
-- per beast per tier (keep them under ~24 characters so they fit at 11px).
-- word/mark/markColor (cowed and sheltered, realm pressure): a short word on the omen
-- row, led by a small tinted glyph (ReplicatedStorage.PressureMarks.BarMark), so the
-- state reads in words, not only in the rim's colour.
type Style = {
	rim: string?,
	tag: Color3?,
	omen: Color3?,
	aura: boolean?,
	sheen: boolean?,
	skull: boolean?,
	omens: { string }?,
	word: string?,
	mark: string?,
	markColor: Color3?, -- the word's colour, and the glyph's tint unless markTint
	markTint: Color3?,
	markSize: Vector2?, -- the glyph's box when not the template's (centred on the row)
}
local STYLES: { [string]: Style } = {
	below = { rim = "rbxassetid://128483974781643", tag = Color3.fromRGB(176, 170, 160) },
	-- a full major below you: it fears you (realm pressure, Pacing.Pressure)
	cowed = {
		rim = "rbxassetid://128483974781643",
		tag = Color3.fromRGB(176, 170, 160),
		omen = Color3.fromRGB(196, 190, 178),
		omens = { "it fears you", "it shrinks back", "it dares not fight" },
		word = "Cowed",
		-- the kit's gold chevron pointing down: beneath you (sized/ornament_chevron_h20)
		mark = "rbxassetid://99764920719361",
		markColor = Color3.fromRGB(226, 186, 136),
		markTint = Color3.new(1, 1, 1),
		markSize = Vector2.new(15, 10),
	},
	-- above you, but a stronger party member nearby shelters you (Pacing.Shelter)
	sheltered = {
		rim = "rbxassetid://117466583392103",
		tag = Color3.fromRGB(176, 228, 196),
		omen = Color3.fromRGB(150, 214, 180),
		omens = { "strike as equals", "a friend has you" },
		word = "Sheltered",
		mark = "rbxassetid://70393328505917", -- the kit shield's silhouette (glyphs/shelter_shield)
		markColor = Color3.fromRGB(156, 240, 196),
	},
	even = { rim = "rbxassetid://117466583392103", tag = Color3.fromRGB(176, 228, 196) },
	above = {
		rim = "rbxassetid://132855087488496",
		tag = Color3.fromRGB(252, 222, 150),
		omen = Color3.fromRGB(240, 206, 146),
		omens = { "Its qi presses on you", "Your meridians tighten", "A heavy aura stirs", "Its gaze weighs on you" },
	},
	far = {
		rim = "rbxassetid://132091886354806",
		tag = Color3.fromRGB(222, 190, 255),
		omen = Color3.fromRGB(222, 176, 255),
		aura = true,
		sheen = true,
		omens = { "Your dao heart trembles", "Killing intent chills you", "Your qi falters", "Its pressure crushes you" },
	},
	deadly = {
		skull = true,
		omen = Color3.fromRGB(255, 118, 106),
		omens = { "Heaven forbids this fight", "Death walks here", "Your soul would scatter", "Flee, or become ash" },
	},
}
local MAJOR_TAGS = { QiCondensation = "QC", QiRefining = "QR", Foundation = "FE" }

local player = Players.LocalPlayer

local EnemyBars = {}

type Watched = {
	bar: BillboardGui,
	model: Model,
	lastHurt: number,
	boss: boolean,
	def: Enemies.Def?,
	tier: string?,
	omens: { [string]: string }, -- the line picked per tier, so it never flickers
	loops: { Tween },
	omenAt: { UDim2 }?, -- the omen row's authored position and size (a pressure mark shifts it)
	markAt: { UDim2 }?, -- the pressure mark's authored position and size
}
local watched: { [Model]: Watched } = {}

local shownBoss: Model? = nil

-- Enemy health is in attributes (EnemyService; enemies have no Humanoid).
local function health(model: Model): (number, number)
	local now, max = model:GetAttribute("Health"), model:GetAttribute("MaxHealth")
	return (if type(now) == "number" then now else 0), (if type(max) == "number" then max else 1)
end

local function fraction(model: Model): number
	local now, max = health(model)
	return math.clamp(now / math.max(max, 1), 0, 1)
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

local function playerStage(): Realms.Stage
	return Realms.byName(player:GetAttribute("Realm")) or Realms.Stages[1]
end

local function tierFor(gap: number): string
	local D = Pacing.Danger
	if gap >= D.DEADLY_AT then
		return "deadly"
	elseif gap >= D.FAR_AT then
		return "far"
	elseif gap >= D.ABOVE_AT then
		return "above"
	elseif gap <= D.BELOW_AT then
		return "below"
	end
	return "even"
end

-- The stage of the party member sheltering you (the server's ShelteredBy), or nil.
local function patronStage(): Realms.Stage?
	local id = player:GetAttribute("ShelteredBy")
	local patron = if type(id) == "number" then Players:GetPlayerByUserId(id) else nil
	return if patron then Realms.byName(patron:GetAttribute("Realm")) else nil
end

-- Overhead bars (not bosses) also read "cowed" (a full major below you: it fears
-- you) and "sheltered" (above you, within your shelter's reach); bosses keep the
-- five tiers BossThemes has lines for.
local function tierOfDef(def: Enemies.Def?): string
	if not (def and def.realm) then
		return "even"
	end
	local beast = Realms.ofBeast(def.realm)
	local mine = playerStage()
	local patron = patronStage()
	if patron and Realms.majorIndex(beast.major) > Realms.majorIndex(mine.major) then
		-- sheltered: you fight it at its own stage, capped at your patron's
		if Realms.index(beast.major, beast.minor) <= Realms.index(patron.major, patron.minor) then
			if not def.boss then
				return "sheltered"
			end
			mine = beast
		else
			mine = patron
		end
	end
	local gap = Realms.index(beast.major, beast.minor) - Realms.index(mine.major, mine.minor)
	-- a higher major realm suppresses the player's blows (Pacing.Suppression):
	-- one major up reads at least "far", two "deadly", however few stages apart;
	-- a lower major (whose blows are suppressed) reads "below"
	local majors = Realms.majorIndex(beast.major) - Realms.majorIndex(mine.major)
	if majors >= 2 then
		gap = math.max(gap, Pacing.Danger.DEADLY_AT)
	elseif majors == 1 then
		gap = math.max(gap, Pacing.Danger.FAR_AT)
	elseif majors < 0 then
		if not def.boss then
			return "cowed"
		end
		gap = math.min(gap, Pacing.Danger.BELOW_AT)
	end
	return tierFor(gap)
end

local function loop(entry: Watched, inst: Instance, props: { [string]: any }, info: TweenInfo)
	local tween = TweenService:Create(inst, info, props)
	table.insert(entry.loops, tween)
	tween:Play()
end

-- Dress a regular beast's bar for its danger to the player (on spawn and when the
-- player's realm changes). Bosses and bars without the Plate layout are left alone.
local function restyle(entry: Watched)
	local plate = entry.bar:FindFirstChild("Plate") :: Frame?
	local warning = entry.bar:FindFirstChild("Warning") :: Frame?
	local def = entry.def
	if entry.boss or not (plate and warning and def and def.realm) then
		return
	end
	local tier = tierOfDef(def)
	if tier == entry.tier then
		return
	end
	entry.tier = tier
	local style = STYLES[tier]
	for _, tween in entry.loops do
		tween:Cancel()
	end
	table.clear(entry.loops)

	local omen = ""
	if style.omens and #style.omens > 0 then
		omen = entry.omens[tier] or style.omens[math.random(#style.omens)]
		entry.omens[tier] = omen
	end

	plate.Visible = not style.skull
	warning.Visible = style.skull == true
	if style.skull then
		local skull = warning:FindFirstChild("Skull") :: ImageLabel
		local pulse = skull:FindFirstChild("Pulse") :: UIScale
		local label = warning:FindFirstChild("Omen") :: TextLabel
		label.Text = omen
		if style.omen then
			label.TextColor3 = style.omen
		end
		pulse.Scale = 1
		skull.ImageTransparency = 0
		loop(entry, pulse, { Scale = 1.1 }, SKULL_PULSE)
		loop(entry, skull, { ImageTransparency = 0.18 }, SKULL_PULSE)
		return
	end

	local strip = plate:FindFirstChild("Strip") :: ImageLabel
	local bar = plate:FindFirstChild("Bar") :: Frame
	local nameLabel = strip:FindFirstChild("NameLabel") :: TextLabel
	local tag = strip:FindFirstChild("RealmTag") :: TextLabel
	nameLabel.Text = def.name
	tag.Text = `{MAJOR_TAGS[beast.major] or beast.major} {beast.minor}`
	if style.tag then
		tag.TextColor3 = style.tag
	end
	local rim = bar:FindFirstChild("Rim") :: ImageLabel
	if style.rim then
		rim.Image = style.rim
	end
	local label = plate:FindFirstChild("Omen") :: TextLabel
	label.Visible = omen ~= ""
	label.Text = omen
	if style.omen then
		label.TextColor3 = style.omen
	end
	-- cowed / sheltered: the mark, then the word in its colour, then the short line
	local mark = plate:FindFirstChild("PressureMark") :: ImageLabel?
	if style.word and not mark then
		local marks = ReplicatedStorage:FindFirstChild("PressureMarks")
		local template = marks and marks:FindFirstChild("BarMark") :: ImageLabel?
		if template then
			local fresh = template:Clone()
			fresh.Name = "PressureMark"
			fresh.Parent = plate
			mark = fresh
		end
	end
	if mark then
		entry.markAt = entry.markAt or { mark.Position, mark.Size }
		local home = entry.markAt :: { UDim2 }
		local size = style.markSize
		mark.Visible = style.word ~= nil
		mark.Image = style.mark or mark.Image
		mark.ImageColor3 = style.markTint or style.markColor or mark.ImageColor3
		if size then
			mark.Size = UDim2.fromOffset(size.X, size.Y)
			mark.Position = home[1] + UDim2.fromOffset(0, (home[2].Y.Offset - size.Y) / 2)
		else
			mark.Position, mark.Size = home[1], home[2]
		end
	end
	entry.omenAt = entry.omenAt or { label.Position, label.Size }
	local at = entry.omenAt :: { UDim2 }
	label.RichText = style.word ~= nil
	if style.word and mark then
		local gap = mark.Position.X.Offset + mark.Size.X.Offset + 4 - at[1].X.Offset
		label.Position = at[1] + UDim2.fromOffset(gap, 0)
		label.Size = at[2] - UDim2.fromOffset(gap, 0)
		label.Visible = true
		local word = `<font color="#{(style.markColor or Color3.new(1, 1, 1)):ToHex()}">{style.word}</font>`
		label.Text = if omen ~= "" then `{word} · {omen}` else word
	else
		label.Position, label.Size = at[1], at[2]
	end
	local aura = bar:FindFirstChild("Aura") :: ImageLabel
	aura.Visible = style.aura == true
	if style.aura then
		aura.ImageTransparency = 0.55
		loop(entry, aura, { ImageTransparency = 0.05 }, AURA_PULSE)
	end
	local sheen = bar:FindFirstChild("Sheen", true) :: ImageLabel?
	if sheen then
		sheen.Visible = style.sheen == true
		if style.sheen then
			local window = bar:FindFirstChild("Window") :: Frame
			sheen.Position = UDim2.fromOffset(-sheen.Size.X.Offset, 0)
			loop(entry, sheen, { Position = UDim2.fromOffset(window.Size.X.Offset, 0) }, SHEEN_SWEEP)
		end
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	-- the bar rides the client-only body EnemyMotion builds
	local body = model:WaitForChild("Body", 10)
	local bar = body and body:FindFirstChild("HealthBar", true) :: BillboardGui?
	local fill = bar and bar:FindFirstChild("Fill", true) :: GuiObject?
	if not (bar and fill) then
		return
	end
	local trail = bar:FindFirstChild("Trail", true) :: GuiObject?
	-- a realm variant's own name ("Elite Spirit Wolf") and realm (Enemies.forModel)
	local def = Enemies.forModel(model)
	local entry: Watched = {
		bar = bar,
		model = model,
		lastHurt = -math.huge,
		boss = def ~= nil and def.boss == true,
		def = def,
		omens = {},
		loops = {},
	}
	watched[model] = entry
	bar.Enabled = false
	restyle(entry)
	local last = health(model)
	local function show()
		local now = health(model)
		if now < last then
			entry.lastHurt = os.clock()
		end
		last = now
		setBar(fill, trail, fraction(model))
		if shownBoss == model then
			BossBars.setHealth(fraction(model))
		end
	end
	model:GetAttributeChangedSignal("Health"):Connect(show)
	model:GetAttributeChangedSignal("MaxHealth"):Connect(show)
	show()
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			for _, tween in entry.loops do
				tween:Cancel()
			end
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
	local boss = activeBoss()
	if boss ~= shownBoss then
		shownBoss = boss
		if boss then
			local def = Enemies.Defs[boss:GetAttribute("EnemyType") :: string? or ""]
			BossBars.show(boss, def, tierOfDef(def), fraction(boss))
		else
			BossBars.hide()
		end
	end
end

function EnemyBars.init(gui: ScreenGui)
	local play = gui:FindFirstChild("Play") :: Frame
	local bossBar = play:FindFirstChild("BossBar") :: Frame?
	if bossBar then
		BossBars.init(bossBar, STYLES)
	end
	for _, model in CollectionService:GetTagged("Enemy") do
		task.spawn(watch, model)
	end
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(watch)
	-- a breakthrough makes the same beast read less threatening; a shelter starting or
	-- ending changes how the beasts above you read
	local function restyleAll()
		for _, entry in watched do
			restyle(entry)
		end
		if shownBoss then
			BossBars.setTier(tierOfDef(Enemies.Defs[shownBoss:GetAttribute("EnemyType") :: string? or ""]))
		end
	end
	player:GetAttributeChangedSignal("Realm"):Connect(restyleAll)
	player:GetAttributeChangedSignal("ShelteredBy"):Connect(restyleAll)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local locked = LockOn.target()
		for model, entry in watched do
			-- a deadly beast's skull warns whenever it's in range (MaxDistance)
			entry.bar.Enabled = not entry.boss
				and Hitbox.alive(model)
				and (entry.tier == "deadly" or model == locked or now - entry.lastHurt < SHOW_AFTER_HURT)
		end
		updateBoss()
	end)
end

return EnemyBars
