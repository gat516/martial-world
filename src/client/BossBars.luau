--!strict
-- The screen health bar for the boss you're fighting (Play.BossBar), themed per
-- boss (BossThemes.luau; fallback `default`). EnemyBars decides which boss it
-- is for and calls show / hide / setHealth / setTier.
--   BossBar (CanvasGroup, top centre, 4:1, max 400x100)
--   > Body > Glow, Bar (Back, Trail, Fill, Slips, Ticks, Cracks, Flare),
--   Ornament (the boss's whole frame art: name plate, bar window, realm plaque),
--   NameLabel, TitleLabel, RealmLabel, OmenLabel.
-- It must stay out of the way of the fight: no screen darkening, no looping
-- pulses, small and short hit/phase feedback.
-- Same visual language as the regular overhead bars: ten talisman slips on the
-- bar, a realm tag, danger-tier colours (EnemyBars.STYLES, Pacing.Danger).
--   Intro: the bar fades in, the fill sweeps up, the name and realm rise in;
--     under the name the theme's title shows, then the omen (picked from the
--     theme's pool for the danger tier), and both fade out fully.
--   Hits: the fill drops at once, the trail drains after it; a hit of BIG_HIT or
--     more gives a small nudge and flash.
--   Phases (def.summonAt, or theme.phases): a tick on the bar for each; crossing
--     one flashes the bar, nudges it, spreads faint cracks and warms the
--     colours for the rest of the fight.

local TweenService = game:GetService("TweenService")

local Enemies = require(game:GetService("ReplicatedStorage").Shared.Enemies)
local Realms = require(game:GetService("ReplicatedStorage").Shared.Realms)
local Themes = require(script.Parent.BossThemes)

local BIG_HIT = 0.05 -- fraction of max health that shakes the bar
local CRACK_W = 1024 -- cracks image width, for the spread crop
local CRACK_H = 56
local GLOW_REST = 0.88 -- the halo behind the bar: faint and static
local TITLE_HOLD = 1.8 -- seconds the title shows in the intro before the omen
local OMEN_HOLD = 2.6 -- seconds the omen shows before it fades out

local TRAIL = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.45)
local QUAD = Enum.EasingStyle.Quad
local OUT = Enum.EasingDirection.Out

type Refs = {
	frame: CanvasGroup,
	scale: UIScale,
	body: Frame,
	glow: ImageLabel,
	bar: Frame,
	trail: Frame,
	fill: Frame,
	gradient: UIGradient,
	slips: Frame,
	ticks: Frame,
	cracks: ImageLabel,
	flare: Frame,
	ornament: ImageLabel,
	name: TextLabel,
	title: TextLabel,
	realm: TextLabel,
	omen: TextLabel,
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

-- Fill gradient and ornament tint follow the phase (and instantly when silent).
local function dressPhase(animate: boolean)
	local refs = r :: Refs
	local t = phaseT()
	local top = lerpColor(theme.fill[1], theme.phaseFill[1], t)
	local bot = lerpColor(theme.fill[2], theme.phaseFill[2], t)
	refs.gradient.Color = ColorSequence.new(top, bot)
	local tint = lerpColor(theme.tint, theme.phaseTint, t)
	if animate then
		tween(refs.ornament, { ImageColor3 = tint }, 0.4)
	else
		refs.ornament.ImageColor3 = tint
	end
end

-- Cracks spread outward from the centre of the bar with each phase.
local function setCracks(amount: number, animate: boolean)
	local refs = r :: Refs
	local w = CRACK_W * amount
	local props = {
		Size = UDim2.fromScale(amount, 1),
		ImageRectSize = Vector2.new(w, CRACK_H),
		ImageRectOffset = Vector2.new((CRACK_W - w) / 2, 0),
		ImageTransparency = if amount > 0 then 0.45 else 1,
	}
	if animate then
		tween(refs.cracks, props, 0.4)
	else
		for k, v in props do
			(refs.cracks :: any)[k] = v
		end
	end
end

-- The halo stays faint and still; it warms a touch with each phase.
local function dressGlow()
	local refs = r :: Refs
	refs.glow.ImageColor3 = theme.glow
	refs.glow.ImageTransparency = GLOW_REST - 0.06 * phaseT()
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

local function flash(width: number, transparency: number, time: number, color: Color3?)
	local refs = r :: Refs
	refs.flare.BackgroundColor3 = color or Color3.new(1, 1, 1)
	refs.flare.Size = UDim2.fromScale(width, 1)
	refs.flare.BackgroundTransparency = transparency
	tween(refs.flare, { BackgroundTransparency = 1 }, time)
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

local function buildTicks()
	local refs = r :: Refs
	for _, child in refs.ticks:GetChildren() do
		child:Destroy()
	end
	for i, at in phases do
		local tick = Instance.new("Frame")
		tick.Name = `Tick{i}`
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(at, 0.5)
		tick.Size = UDim2.new(0, 2, 0, 0)
		tick.BackgroundColor3 = theme.flare
		tick.BorderSizePixel = 0
		tick.ZIndex = 8
		tick.Parent = refs.ticks
		local stroke = Instance.new("UIStroke") -- internals only: a dark edge on a bar mark
		stroke.Color = Color3.fromRGB(6, 8, 12)
		stroke.Thickness = 1
		stroke.Parent = tick
		local tall = tick
		tween(tall, { Size = UDim2.new(0, 2, 1, 4) }, 0.25, 0.6 + i * 0.08)
	end
end

local function dressTicks(animate: boolean)
	local refs = r :: Refs
	for i, at in phases do
		local tick = refs.ticks:FindFirstChild(`Tick{i}`) :: Frame?
		if tick then
			local crossed = i <= phaseIdx
			local color = if crossed then Color3.fromRGB(70, 66, 62) else theme.flare
			if animate and crossed then
				tween(tick, { BackgroundColor3 = color, BackgroundTransparency = 0.35 }, 0.3)
			else
				tick.BackgroundColor3 = color
				tick.BackgroundTransparency = if crossed then 0.35 else 0
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
	-- the per-boss v2 frame once uploaded, else the original art
	local v2 = (Themes.FRAMES :: { [string]: string })[id]
	refs.ornament.Image = if v2 and string.match(v2, "^rbxassetid://%d+$") then v2 else theme.ornament
	refs.glow.ImageColor3 = theme.glow
	refs.trail.BackgroundColor3 = theme.trail
	refs.cracks.ImageColor3 = theme.crack
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

function BossBars.init(frame: CanvasGroup, tierStyles: { [string]: any })
	local body = frame:WaitForChild("Body") :: Frame
	local bar = body:WaitForChild("Bar") :: Frame
	local fill = bar:WaitForChild("Fill") :: Frame
	local ornament = body:WaitForChild("Ornament") :: ImageLabel
	local refs: Refs = {
		frame = frame,
		scale = frame:WaitForChild("Motion") :: UIScale,
		body = body,
		glow = body:WaitForChild("Glow") :: ImageLabel,
		bar = bar,
		trail = bar:WaitForChild("Trail") :: Frame,
		fill = fill,
		gradient = fill:WaitForChild("UIGradient") :: UIGradient,
		slips = bar:WaitForChild("Slips") :: Frame,
		ticks = bar:WaitForChild("Ticks") :: Frame,
		cracks = bar:WaitForChild("Cracks") :: ImageLabel,
		flare = bar:WaitForChild("Flare") :: Frame,
		ornament = ornament,
		name = body:WaitForChild("NameLabel") :: TextLabel,
		title = body:WaitForChild("TitleLabel") :: TextLabel,
		realm = body:WaitForChild("RealmLabel") :: TextLabel,
		omen = body:WaitForChild("OmenLabel") :: TextLabel,
		home = {},
	}
	-- authored positions, so a show that interrupts an intro never drifts them
	for _, label in { refs.name, refs.title, refs.realm, refs.omen } do
		refs.home[label] = label.Position
	end
	r = refs
	styles = tierStyles
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
	refs.flare.BackgroundTransparency = 1
	refs.omen.TextTransparency = 1
	refs.omen.TextStrokeTransparency = 1
	dressPhase(false)
	dressGlow()
	setCracks(if phaseIdx > 0 and #phases > 0 then phaseIdx / #phases else 0, false)
	buildTicks()
	dressTicks(false)

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
		setCracks(phaseIdx / math.max(#phases, 1), true)
		dressGlow()
		dressTicks(true)
		tween(refs.name, { TextColor3 = Color3.new(1, 1, 1) }, 0.1)
		tween(refs.name, { TextColor3 = theme.name }, 0.3, 0.1)
	elseif idx < phaseIdx then
		-- healed back above a threshold
		phaseIdx = idx
		dressPhase(true)
		setCracks(if #phases > 0 then phaseIdx / #phases else 0, true)
		dressGlow()
		dressTicks(false)
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
