--!strict
-- The screen health bar for the boss you're fighting (Play.BossBar), themed per
-- boss (BossThemes.luau; fallback `default`). EnemyBars decides which boss it
-- is for and calls show / hide / setHealth / setTier.
--   BossBar (CanvasGroup) > Body > Glow, Bar (Back, Trail, Fill, Slips, Ticks,
--   Cracks, Flare), Ornament, NameLabel, TitleLabel, RealmLabel, OmenLabel;
--   Play.BossVignette is the screen-edge darkening for the top danger tiers.
-- Same visual language as the regular overhead bars: ten talisman slips on the
-- bar, a realm tag, danger-tier dressing (EnemyBars.STYLES, Pacing.Danger) and an
-- omen line, just grander.
--   Intro: the frame pops in, the fill sweeps up, name, title, realm and the omen
--     (picked from the theme's pool for the danger tier) rise in one after another.
--   Hits: the fill drops at once, the trail drains after it; a hit of BIG_HIT or
--     more shakes the frame and flashes the fill.
--   Phases (def.summonAt, or theme.phases): a tick on the bar for each; crossing
--     one flares the bar, shakes it, and spreads cracks, warms the colours and
--     brightens the glow for the rest of the fight.

local TweenService = game:GetService("TweenService")

local Enemies = require(game:GetService("ReplicatedStorage").Shared.Enemies)
local Realms = require(game:GetService("ReplicatedStorage").Shared.Realms)
local Themes = require(script.Parent.BossThemes)

local BIG_HIT = 0.05 -- fraction of max health that shakes the bar
local CRACK_W = 1024 -- cracks image width, for the spread crop
local CRACK_H = 56
local TIER_RANK = { below = 0, even = 0, above = 1, far = 2, deadly = 3 }
local VIGNETTE = { far = Color3.fromRGB(70, 20, 110), deadly = Color3.fromRGB(110, 8, 14) }

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
	vignette: ImageLabel?,
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
local loops: { Tween } = {}
local live: { Tween } = {}
local shakeToken = 0
local intro = false

local function tween(inst: Instance, props: { [string]: any }, time: number, delay: number?, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or QUAD, dir or OUT, 0, false, delay or 0), props)
	table.insert(live, t)
	t:Play()
	return t
end

local function loopTween(inst: Instance, props: { [string]: any }, time: number)
	local t = TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), props)
	table.insert(loops, t)
	t:Play()
end

local function stopLoops()
	for _, t in loops do
		t:Cancel()
	end
	table.clear(loops)
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
		tween(refs.ornament, { ImageColor3 = tint }, 0.6)
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
		ImageTransparency = if amount > 0 then 0.12 else 1,
	}
	if animate then
		tween(refs.cracks, props, 0.7)
	else
		for k, v in props do
			(refs.cracks :: any)[k] = v
		end
	end
end

-- The halo's strength and pulse follow the danger tier and the phase.
local function dressGlow()
	local refs = r :: Refs
	for _, t in loops do
		if t.Instance == refs.glow then
			t:Cancel()
		end
	end
	local rank = TIER_RANK[tier] or 0
	local level = math.clamp(0.82 - 0.09 * rank - 0.2 * phaseT(), 0.12, 0.9)
	refs.glow.ImageColor3 = theme.glow
	refs.glow.ImageTransparency = level
	if rank >= 1 or phaseIdx > 0 then
		loopTween(refs.glow, { ImageTransparency = math.max(level - 0.2, 0.05) }, 1.3 - 0.2 * rank)
	end
end

local function shake(strength: number)
	local refs = r :: Refs
	shakeToken += 1
	local mine = shakeToken
	local mag = 2 + 7 * math.clamp(strength, 0, 1)
	task.spawn(function()
		for i = 1, 6 do
			if mine ~= shakeToken then
				return
			end
			local k = (1 - i / 7) * mag
			refs.body.Position = UDim2.fromOffset(math.random(-100, 100) / 100 * k, math.random(-100, 100) / 100 * k * 0.6)
			task.wait(0.035)
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

local function setOmenText(sweep: boolean, delay: number)
	local refs = r :: Refs
	local style = styles[tier] or {}
	local tagColor = style.tag or theme.titleColor
	refs.realm.TextColor3 = tagColor
	refs.omen.TextColor3 = style.omen or tagColor
	refs.omen.Text = pickOmen()
	local rest = if (TIER_RANK[tier] or 0) >= 1 then 0.12 else 0.35
	local mine = token
	if not sweep then
		refs.omen.TextTransparency = rest
		refs.omen.TextStrokeTransparency = rest
		return
	end
	refs.omen.TextTransparency = 1
	refs.omen.TextStrokeTransparency = 1
	refs.omen.Position = UDim2.new(0.5, -90, 0.8, 0)
	tween(refs.omen, { Position = UDim2.fromScale(0.5, 0.8), TextTransparency = 0, TextStrokeTransparency = 0 }, 0.55, delay, Enum.EasingStyle.Quint)
	-- calm tiers let the line fade after a few seconds; the heavy ones keep it
	tween(refs.omen, { TextTransparency = rest, TextStrokeTransparency = rest }, 0.8, delay + 3.2)
	if (TIER_RANK[tier] or 0) < 1 then
		task.delay(delay + 3.2 + 0.8, function()
			if mine == token and r then
				tween(refs.omen, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.5)
			end
		end)
	end
end

local function dressTier(sweepOmen: boolean, delay: number)
	local refs = r :: Refs
	dressGlow()
	setOmenText(sweepOmen, delay)
	local vig = refs.vignette
	if vig then
		local color = VIGNETTE[tier]
		for _, t in loops do
			if t.Instance == vig then
				t:Cancel()
			end
		end
		if color then
			vig.ImageColor3 = color
			vig.Visible = true
			tween(vig, { ImageTransparency = 0.62 }, 1.2)
			-- a slow pressure pulse
			task.delay(1.2, function()
				if r and model and vig.Visible then
					loopTween(vig, { ImageTransparency = 0.38 }, 1.6)
				end
			end)
		else
			tween(vig, { ImageTransparency = 1 }, 0.4)
		end
	end
	for _, t in loops do
		if t.Instance == refs.scale then
			t:Cancel()
		end
	end
	if (TIER_RANK[tier] or 0) >= 2 then
		loopTween(refs.scale, { Scale = 1.02 }, 1.6)
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
		tick.Size = UDim2.new(0, 3, 0, 0)
		tick.BackgroundColor3 = theme.flare
		tick.BorderSizePixel = 0
		tick.ZIndex = 8
		tick.Parent = refs.ticks
		local stroke = Instance.new("UIStroke") -- internals only: a dark edge on a bar mark
		stroke.Color = Color3.fromRGB(6, 8, 12)
		stroke.Thickness = 1
		stroke.Parent = tick
		local tall = tick
		tween(tall, { Size = UDim2.new(0, 3, 1, 12) }, 0.35, 0.9 + i * 0.12, Enum.EasingStyle.Back)
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
				tween(tick, { BackgroundColor3 = color, BackgroundTransparency = 0.35 }, 0.5)
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
	refs.ornament.Image = theme.ornament
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

function BossBars.init(frame: CanvasGroup, vignette: ImageLabel?, tierStyles: { [string]: any })
	local body = frame:WaitForChild("Body") :: Frame
	local bar = body:WaitForChild("Bar") :: Frame
	local fill = bar:WaitForChild("Fill") :: Frame
	r = {
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
		ornament = body:WaitForChild("Ornament") :: ImageLabel,
		name = body:WaitForChild("NameLabel") :: TextLabel,
		title = body:WaitForChild("TitleLabel") :: TextLabel,
		realm = body:WaitForChild("RealmLabel") :: TextLabel,
		omen = body:WaitForChild("OmenLabel") :: TextLabel,
		vignette = vignette,
	}
	styles = tierStyles
	frame.Visible = false
	if vignette then
		vignette.Visible = false
	end
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
	stopLoops()
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
	refs.scale.Scale = 0.88
	refs.body.Position = UDim2.new()
	refs.fill.Size = UDim2.fromScale(0, 1)
	refs.trail.Size = UDim2.fromScale(0, 1)
	refs.flare.BackgroundTransparency = 1
	dressPhase(false)
	setCracks(if phaseIdx > 0 and #phases > 0 then phaseIdx / #phases else 0, false)
	buildTicks()
	dressTicks(false)

	tween(refs.frame, { GroupTransparency = 0 }, 0.35)
	tween(refs.scale, { Scale = 1 }, 0.45, 0, Enum.EasingStyle.Back)
	tween(refs.fill, { Size = UDim2.fromScale(frac, 1) }, 0.9, 0.2, Enum.EasingStyle.Quint)
	tween(refs.trail, { Size = UDim2.fromScale(frac, 1) }, 0.9, 0.2, Enum.EasingStyle.Quint)
	-- name, title, realm rise in turn
	local rise = { { refs.name, 0.3 }, { refs.title, 0.55 }, { refs.realm, 0.8 } }
	for _, step in rise do
		local label, delay = step[1] :: TextLabel, step[2] :: number
		local home = label.Position
		label.Position = home + UDim2.fromOffset(0, 10)
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
		tween(label, { Position = home, TextTransparency = 0, TextStrokeTransparency = 0 }, 0.5, delay)
	end
	dressTier(true, 1.0)
	for _, t in loops do
		if t.Instance == refs.glow then
			t:Cancel() -- the intro flash owns the halo until dressGlow runs again below
		end
	end
	local mine = token
	task.delay(1.1, function()
		if mine == token then
			intro = false
		end
	end)
	-- the first flash of the halo
	refs.glow.ImageTransparency = 0.1
	tween(refs.glow, { ImageTransparency = 0.7 }, 1.0, 0.1)
	task.delay(1.15, function()
		if mine == token and model == boss then
			dressGlow()
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
	stopLoops()
	stopLive()
	tween(refs.frame, { GroupTransparency = 1 }, 0.35)
	if refs.vignette then
		tween(refs.vignette, { ImageTransparency = 1 }, 0.5)
	end
	task.delay(0.55, function()
		if mine == token and r then
			refs.frame.Visible = false
			if refs.vignette then
				refs.vignette.Visible = false
			end
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
		flash(frac, if delta >= BIG_HIT then 0.35 else 0.8, if delta >= BIG_HIT then 0.3 else 0.18)
		if delta >= BIG_HIT then
			shake(big)
		end
	end
	-- phase change: a tick was crossed
	local idx = phaseOf(frac)
	if idx > phaseIdx then
		phaseIdx = idx
		flash(1, 0.1, 0.9, theme.flare)
		shake(1)
		dressPhase(true)
		setCracks(phaseIdx / math.max(#phases, 1), true)
		dressGlow()
		dressTicks(true)
		refs.glow.ImageTransparency = 0
		tween(refs.name, { TextColor3 = Color3.new(1, 1, 1) }, 0.12)
		tween(refs.name, { TextColor3 = theme.name }, 0.7, 0.12)
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
