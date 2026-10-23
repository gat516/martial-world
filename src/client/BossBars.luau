--!strict
-- The screen health bar for the boss you're fighting (Play.BossBar), themed per
-- boss (BossThemes.luau; fallback `default`). EnemyBars decides which boss it
-- is for and calls show / hide / setHealth / setTier.
--   BossBar (CanvasGroup, top centre, 560x104 box, 0.44 of the width, so
--   smaller on phones) > Body > Plate (kit art behind the bar), Bar (Trail,
--   Fill > Sheen, Flare), Mount (kit art over the bar: name plaque, trough
--   rim, slanted cuts, gold cap, ruby end gem), Cracks, Pips, NameLabel,
--   TitleLabel, OmenLabel, RealmLabel. Plate and Mount are exported from the
--   Figma kit (docs/ui/boss-bars.md); the fills are slanted 9-slices whose
--   45-degree end matches the trough's.
-- It must stay out of the way of the fight: no screen darkening, no looping
-- pulses, small and short hit/phase feedback.
--   Intro: the bar fades in, the fill sweeps up, the name and realm rise in;
--     under the bar the theme's title shows, then the omen (picked from the
--     theme's pool for the danger tier), and both fade out fully.
--   Hits: the fill drops at once, the trail drains after it; a hit of BIG_HIT or
--     more gives a small nudge and flash.
--   Phases (def.summonAt, or theme.phases): a gold pip on the top rim for each;
--     crossing one flashes the bar, nudges it, dims the pip, leaves a crack at
--     that point and warms the colours for the rest of the fight.

local TweenService = game:GetService("TweenService")

local Enemies = require(game:GetService("ReplicatedStorage").Shared.Enemies)
local Realms = require(game:GetService("ReplicatedStorage").Shared.Realms)
local Themes = require(script.Parent.BossThemes)

local BIG_HIT = 0.05 -- fraction of max health that shakes the bar
local SLICE_H = 64 -- source height of the slanted fill art (bossbar_fill/sheen.png)
local PIP = "rbxassetid://103441340188755" -- kit gold_stud cut
local CRACK = "rbxassetid://85815494954691" -- kit crack_split cut
local PIP_Y = -5 / 24 -- pip centre on the plate's top rim (y 35 in the 560x104 box), in bar heights from the bar's top (y 40)
local PIP_SIZE = 0.6 -- pip height in bar heights
local CRACK_SIZE = 1.9 -- crack size in bar heights
local CRACK_REST = 0.15 -- crack transparency once it has settled
local TITLE_HOLD = 1.8 -- seconds the title shows in the intro before the omen
local OMEN_HOLD = 2.6 -- seconds the omen shows before it fades out

local TRAIL = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.45)
local QUAD = Enum.EasingStyle.Quad
local OUT = Enum.EasingDirection.Out

type Refs = {
	frame: CanvasGroup,
	scale: UIScale,
	body: Frame,
	bar: Frame,
	trail: ImageLabel,
	fill: ImageLabel,
	gradient: UIGradient,
	flare: ImageLabel,
	cracks: Frame,
	pips: Frame,
	mount: ImageLabel,
	name: TextLabel,
	title: TextLabel,
	realm: TextLabel,
	omen: TextLabel,
	slanted: { ImageLabel },
	home: { [TextLabel]: UDim2 },
}

local BossBars = {}
local r: Refs? = nil
local styles: { [string]: any } = {}

local model: Model? = nil
local theme: Themes.Theme = Themes.default
local phases: { number } = {}
local phaseIdx = 0
local lastFrac = 1
local tier = "even"
local omens: { [string]: string } = {}
local token = 0 -- bumped on every show/hide so stale delayed steps stop
local live: { Tween } = {}
local shakeToken = 0
local intro = false

local function tween(inst: Instance, props: { [string]: any }, time: number, delay: number?, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or QUAD, dir or OUT, 0, false, delay or 0), props)
	table.insert(live, t)
	t:Play()
	return t
end

local function stopLive()
	for _, t in live do
		t:Cancel()
	end
	table.clear(live)
end

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, math.clamp(t, 0, 1))
end

local function phaseT(): number
	return if #phases > 0 then phaseIdx / #phases else 0
end

-- Fill gradient and frame tint follow the phase (and instantly when silent).
local function dressPhase(animate: boolean)
	local refs = r :: Refs
	local t = phaseT()
	local top = lerpColor(theme.fill[1], theme.phaseFill[1], t)
	local bot = lerpColor(theme.fill[2], theme.phaseFill[2], t)
	refs.gradient.Color = ColorSequence.new(top, bot)
	local tint = lerpColor(theme.tint, theme.phaseTint, t)
	if animate then
		tween(refs.mount, { ImageColor3 = tint }, 0.4)
	else
		refs.mount.ImageColor3 = tint
	end
end

local function shake(strength: number)
	local refs = r :: Refs
	shakeToken += 1
	local mine = shakeToken
	local mag = 1 + 2 * math.clamp(strength, 0, 1) -- pixels; a nudge, not a quake
	task.spawn(function()
		for i = 1, 4 do
			if mine ~= shakeToken then
				return
			end
			local k = (1 - i / 5) * mag
			refs.body.Position = UDim2.fromOffset(math.random(-100, 100) / 100 * k, math.random(-100, 100) / 100 * k * 0.5)
			task.wait(0.03)
		end
		if mine == shakeToken then
			refs.body.Position = UDim2.new()
		end
	end)
end

-- The flare is the fill's own slanted shape, so a flash never spills past the trough.
local function flash(width: number, transparency: number, time: number, color: Color3?)
	local refs = r :: Refs
	refs.flare.ImageColor3 = color or Color3.new(1, 1, 1)
	refs.flare.Size = UDim2.fromScale(width, 1)
	refs.flare.ImageTransparency = transparency
	tween(refs.flare, { ImageTransparency = 1 }, time)
end

-- Realm line and omen colours follow the danger tier (EnemyBars.STYLES).
local function pickOmen(): string
	if omens[tier] then
		return omens[tier]
	end
	local pool = (theme.omens[tier] or Themes.default.omens[tier]) :: { string }
	local line = pool[math.random(#pool)]
	omens[tier] = line
	return line
end

-- One intro line under the bar: rise in, hold, fade fully out.
local function sweepLine(label: TextLabel, delay: number, hold: number)
	local refs = r :: Refs
	local home = refs.home[label]
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	label.Position = home + UDim2.fromOffset(0, 4)
	tween(label, { Position = home, TextTransparency = 0, TextStrokeTransparency = 0 }, 0.3, delay)
	tween(label, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.4, delay + 0.3 + hold)
end

local function dressTier(sweepOmen: boolean, delay: number)
	local refs = r :: Refs
	local style = styles[tier] or {}
	local tagColor = style.tag or theme.titleColor
	refs.realm.TextColor3 = tagColor
	refs.omen.TextColor3 = style.omen or tagColor
	refs.omen.Text = pickOmen()
	if sweepOmen then
		sweepLine(refs.omen, delay, OMEN_HOLD)
	end
end

-- A square box `size` bar heights tall, centred at (x, y) in bar units.
local function barSquare(inst: GuiObject, x: number, y: number, size: number)
	inst.AnchorPoint = Vector2.new(0.5, 0.5)
	inst.Position = UDim2.fromScale(x, y)
	inst.SizeConstraint = Enum.SizeConstraint.RelativeYY
	inst.Size = UDim2.fromScale(size, size)
end

-- Gold studs on the plate's top rim, one per phase threshold.
local function buildPips()
	local refs = r :: Refs
	refs.pips:ClearAllChildren()
	refs.cracks:ClearAllChildren()
	for i, at in phases do
		local pip = Instance.new("ImageLabel")
		pip.Name = `Pip{i}`
		pip.BackgroundTransparency = 1
		pip.Image = PIP
		barSquare(pip, at, PIP_Y, PIP_SIZE)
		pip.ZIndex = 10
		pip.ImageTransparency = 1
		pip.Parent = refs.pips
		tween(pip, { ImageTransparency = 0 }, 0.25, 0.5 + i * 0.08)
	end
end

-- A crossed threshold leaves a crack in the bar where its pip sits.
local function crackAt(i: number, animate: boolean)
	local refs = r :: Refs
	local at = phases[i]
	if not at or refs.cracks:FindFirstChild(`Crack{i}`) then
		return
	end
	local crack = Instance.new("ImageLabel")
	crack.Name = `Crack{i}`
	crack.BackgroundTransparency = 1
	crack.Image = CRACK
	crack.ImageColor3 = theme.crack
	crack.Rotation = (i % 2 == 0) and 90 or 0
	barSquare(crack, at, 0.5, CRACK_SIZE)
	crack.ZIndex = 9
	crack.ImageTransparency = if animate then 0 else CRACK_REST
	crack.Parent = refs.cracks
	if animate then
		crack.Size = UDim2.fromScale(CRACK_SIZE * 0.6, CRACK_SIZE * 0.6)
		tween(crack, { Size = UDim2.fromScale(CRACK_SIZE, CRACK_SIZE) }, 0.18, 0, Enum.EasingStyle.Back)
		tween(crack, { ImageTransparency = CRACK_REST }, 0.4, 0.2)
	end
end

local function dressPips(animate: boolean)
	local refs = r :: Refs
	for i in phases do
		local pip = refs.pips:FindFirstChild(`Pip{i}`) :: ImageLabel?
		if pip then
			local crossed = i <= phaseIdx
			local color = if crossed then Color3.fromRGB(96, 90, 84) else Color3.new(1, 1, 1)
			if animate then
				tween(pip, { ImageColor3 = color }, 0.3)
			else
				pip.ImageColor3 = color
			end
		end
		if i <= phaseIdx then
			crackAt(i, animate)
		else
			local crack = refs.cracks:FindFirstChild(`Crack{i}`)
			if crack then
				crack:Destroy()
			end
		end
	end
end

local function applyTheme(def: Enemies.Def?)
	local refs = r :: Refs
	local id = if def then def.id else ""
	theme = (Themes :: any)[id] or Themes.default
	local list = theme.phases or (def and def.summonAt) or {}
	phases = table.clone(list)
	table.sort(phases, function(a, b)
		return a > b
	end)
	refs.mount.Image = theme.mount or Themes.MOUNT
	refs.trail.ImageColor3 = theme.trail
	refs.name.TextColor3 = theme.name
	refs.title.TextColor3 = theme.titleColor
	refs.name.Text = if def then def.name else "Boss"
	refs.title.Text = theme.title
	local stage = if def and def.realm then Realms.ofBeast(def.realm) else nil
	refs.realm.Text = if stage then stage.name else ""
end

local function phaseOf(frac: number): number
	local n = 0
	for _, at in phases do
		if frac <= at then
			n += 1
		end
	end
	return n
end

-- The slanted fills keep a 45-degree end at any size: slice scale = bar height / source height.
local function fitSlices()
	local refs = r :: Refs
	local scale = math.max(refs.bar.AbsoluteSize.Y, 1) / SLICE_H
	for _, img in refs.slanted do
		img.SliceScale = scale
	end
end

function BossBars.init(frame: CanvasGroup, tierStyles: { [string]: any })
	local body = frame:WaitForChild("Body") :: Frame
	local bar = body:WaitForChild("Bar") :: Frame
	local fill = bar:WaitForChild("Fill") :: ImageLabel
	local refs: Refs = {
		frame = frame,
		scale = frame:WaitForChild("Motion") :: UIScale,
		body = body,
		bar = bar,
		trail = bar:WaitForChild("Trail") :: ImageLabel,
		fill = fill,
		gradient = fill:WaitForChild("UIGradient") :: UIGradient,
		flare = bar:WaitForChild("Flare") :: ImageLabel,
		cracks = body:WaitForChild("Cracks") :: Frame,
		pips = body:WaitForChild("Pips") :: Frame,
		mount = body:WaitForChild("Mount") :: ImageLabel,
		name = body:WaitForChild("NameLabel") :: TextLabel,
		title = body:WaitForChild("TitleLabel") :: TextLabel,
		realm = body:WaitForChild("RealmLabel") :: TextLabel,
		omen = body:WaitForChild("OmenLabel") :: TextLabel,
		slanted = {},
		home = {},
	}
	for _, name in { "Trail", "Fill", "Flare" } do
		table.insert(refs.slanted, bar:WaitForChild(name) :: ImageLabel)
	end
	table.insert(refs.slanted, fill:WaitForChild("Sheen") :: ImageLabel)
	-- authored positions, so a show that interrupts an intro never drifts them
	for _, label in { refs.name, refs.title, refs.realm, refs.omen } do
		refs.home[label] = label.Position
	end
	r = refs
	styles = tierStyles
	bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitSlices)
	fitSlices()
	frame.Visible = false
end

function BossBars.active(): Model?
	return model
end

-- A boss takes the screen bar: play the intro.
function BossBars.show(boss: Model, def: Enemies.Def?, dangerTier: string, frac: number)
	local refs = r
	if not refs then
		return
	end
	token += 1
	stopLive()
	model = boss
	tier = dangerTier
	omens = {}
	intro = true
	lastFrac = frac
	applyTheme(def)
	phaseIdx = phaseOf(frac)

	refs.frame.Visible = true
	refs.frame.GroupTransparency = 1
	refs.scale.Scale = 0.96
	refs.body.Position = UDim2.new()
	refs.fill.Size = UDim2.fromScale(0, 1)
	refs.trail.Size = UDim2.fromScale(0, 1)
	refs.flare.ImageTransparency = 1
	refs.omen.TextTransparency = 1
	refs.omen.TextStrokeTransparency = 1
	dressPhase(false)
	buildPips()
	dressPips(false)

	tween(refs.frame, { GroupTransparency = 0 }, 0.25)
	tween(refs.scale, { Scale = 1 }, 0.25)
	tween(refs.fill, { Size = UDim2.fromScale(frac, 1) }, 0.6, 0.1, Enum.EasingStyle.Quint)
	tween(refs.trail, { Size = UDim2.fromScale(frac, 1) }, 0.6, 0.1, Enum.EasingStyle.Quint)
	-- name and realm rise in and stay
	for _, step in { { refs.name, 0.15 }, { refs.realm, 0.3 } } do
		local label, delay = step[1] :: TextLabel, step[2] :: number
		local home = refs.home[label]
		label.Position = home + UDim2.fromOffset(0, 4)
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
		tween(label, { Position = home, TextTransparency = 0, TextStrokeTransparency = 0 }, 0.3, delay)
	end
	-- under the bar: the title, then the omen, each fading out fully
	sweepLine(refs.title, 0.4, TITLE_HOLD)
	dressTier(true, 0.4 + 0.3 + TITLE_HOLD + 0.4)
	local mine = token
	task.delay(0.7, function()
		if mine == token then
			intro = false
		end
	end)
end

function BossBars.hide()
	local refs = r
	if not refs or not model then
		return
	end
	model = nil
	token += 1
	local mine = token
	stopLive()
	tween(refs.frame, { GroupTransparency = 1 }, 0.25)
	task.delay(0.3, function()
		if mine == token and r then
			refs.frame.Visible = false
		end
	end)
end

-- The boss's health changed (after show).
function BossBars.setHealth(frac: number)
	local refs = r
	if not refs or not model then
		return
	end
	local delta = lastFrac - frac
	lastFrac = frac
	if intro then
		-- the sweep is still running; just let it land on the new value
		refs.fill.Size = UDim2.fromScale(frac, 1)
		refs.trail.Size = UDim2.fromScale(frac, 1)
		return
	end
	refs.fill.Size = UDim2.fromScale(frac, 1)
	if frac >= refs.trail.Size.X.Scale then
		refs.trail.Size = refs.fill.Size
	else
		local t = TweenService:Create(refs.trail, TRAIL, { Size = refs.fill.Size })
		t:Play()
	end
	if delta > 0 then
		local big = math.clamp(delta / (BIG_HIT * 3), 0, 1)
		flash(frac, if delta >= BIG_HIT then 0.6 else 0.88, if delta >= BIG_HIT then 0.18 else 0.1)
		if delta >= BIG_HIT then
			shake(big)
		end
	end
	-- phase change: a tick was crossed
	local idx = phaseOf(frac)
	if idx > phaseIdx then
		phaseIdx = idx
		flash(1, 0.5, 0.3, theme.flare)
		shake(0.6)
		dressPhase(true)
		dressPips(true)
		tween(refs.name, { TextColor3 = Color3.new(1, 1, 1) }, 0.1)
		tween(refs.name, { TextColor3 = theme.name }, 0.3, 0.1)
	elseif idx < phaseIdx then
		-- healed back above a threshold
		phaseIdx = idx
		dressPhase(true)
		dressPips(false)
	end
end

-- The danger tier changed mid-fight (the player broke through).
function BossBars.setTier(newTier: string)
	if not r or not model or newTier == tier then
		return
	end
	tier = newTier
	dressTier(true, 0)
end

return BossBars
