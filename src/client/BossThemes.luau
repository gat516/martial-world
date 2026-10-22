--!strict
-- Per-boss health bar themes (BossBars.luau reads these). Key = enemy def id.
-- Adding a boss = one entry here; any def without one uses `default`.
--   title      line under the name, shown in the intro ("Sovereign of the Silver Peaks")
--   ornament   the boss's original frame art, shown whole (art/ui/draw_boss_bars.py,
--              1024x256, bar window in the middle; never crop it); a v2 frame in
--              FRAMES below replaces it once uploaded
--   fill       { top, bottom } of the health gradient, saturated so it reads
--              hard against the dark window; phaseFill is the colour
--              it shifts toward as phases pass (lerped by phase / phases)
--   trail      delayed-damage trail colour (pale)
--   glow       faint static halo behind the bar (tints bossbar_glow.png)
--   tint       ornament colour at rest; phaseTint what it warms to in the last phase
--   name/titleColor  text colours; crack  the crack overlay colour; flare  the flash
--   phases     optional override of the thresholds; default is def.summonAt
--              (health fractions where the fight changes, ticks + flare + cracks)
--   omens      { [tier]: { lines } } for the five danger tiers (EnemyBars STYLES:
--              below/even/above/far/deadly); a missing tier falls back to default.
--              One is picked at random per fight. Keep lines under ~26 characters.
local Themes = {}

-- ASSET IDS: the per-boss v2 frames (art/ui/draw_boss_bars.py v2_*), keyed by
-- def id. Paste each uploaded rbxassetid:// here (and record it in
-- art/ui/assets.json). While a value still starts with "PASTE-ID:" the bar
-- uses that theme's original `ornament` frame instead.
Themes.FRAMES = {
	ElderWolfKing = "PASTE-ID:bossbar2_wolf.png",
	NineTailFox = "PASTE-ID:bossbar2_fox.png",
	ThunderApe = "PASTE-ID:bossbar2_ape.png",
	JadeJiao = "PASTE-ID:bossbar2_jiao.png",
}

export type Theme = {
	title: string,
	ornament: string,
	fill: { Color3 },
	phaseFill: { Color3 },
	trail: Color3,
	glow: Color3,
	tint: Color3,
	phaseTint: Color3,
	name: Color3,
	titleColor: Color3,
	crack: Color3,
	flare: Color3,
	phases: { number }?,
	omens: { [string]: { string } },
}

local c = Color3.fromRGB

Themes.default = {
	title = "Calamity of the Wilds",
	ornament = "rbxassetid://130685924906772",
	fill = { c(236, 66, 52), c(136, 16, 20) },
	phaseFill = { c(255, 120, 60), c(170, 40, 20) },
	trail = c(255, 236, 200),
	glow = c(255, 190, 110),
	tint = c(255, 255, 255),
	phaseTint = c(255, 214, 190),
	name = c(242, 224, 176),
	titleColor = c(214, 196, 160),
	crack = c(255, 226, 170),
	flare = c(255, 236, 200),
	omens = {
		below = { "It is no match for you", "A beast, nothing more", "You stand at ease" },
		even = { "A worthy foe stirs", "Its qi matches yours", "Neither of you yields", "Steel your heart" },
		above = { "Its qi presses on you", "Your meridians tighten", "A heavy aura stirs", "Its gaze weighs on you" },
		far = { "Your dao heart trembles", "Killing intent chills you", "Your qi falters", "Its pressure crushes you" },
		deadly = { "Heaven forbids this fight", "Death walks here", "Your soul would scatter", "Flee, or become ash" },
	},
} :: Theme

-- Moon-silver on ink-slate; gold is the warning colour; spirit-cyan ghosts; jade seal.
Themes.ElderWolfKing = {
	title = "Sovereign of the Silver Peaks",
	ornament = "rbxassetid://108424250959271",
	fill = { c(120, 214, 255), c(22, 92, 178) },
	phaseFill = { c(255, 214, 120), c(190, 120, 40) },
	trail = c(240, 250, 255),
	glow = c(110, 235, 240),
	tint = c(255, 255, 255),
	phaseTint = c(255, 226, 160),
	name = c(232, 240, 250),
	titleColor = c(150, 214, 222),
	crack = c(255, 224, 150),
	flare = c(210, 250, 255),
	omens = {
		below = { "The wind carries its scent", "A low growl in the dark", "Something watches the ridge", "Your steps grow quiet" },
		even = { "The hair on your neck rises", "A chill brushes your spine", "You feel eyes on you", "Your breath turns shallow" },
		above = { "Goosebumps crawl up your arms", "The hair on your neck stands on end", "Cold sweat beads on your back", "Your body wants to run" },
		far = { "Something ancient has your scent", "Your body knows it is prey", "Your legs forget how to move", "A chill sinks into your bones" },
		deadly = { "Heaven forbids this fight", "Your blood screams: flee", "The pack master has chosen you", "Prey does not leave its jaws" },
	},
} :: Theme

-- Foxfire and tail-magic.
Themes.NineTailFox = {
	title = "Matriarch of the Foxfire Mists",
	ornament = "rbxassetid://115218564552084",
	fill = { c(255, 160, 70), c(196, 58, 32) },
	phaseFill = { c(190, 140, 255), c(96, 52, 190) },
	trail = c(255, 240, 220),
	glow = c(255, 140, 90),
	tint = c(255, 255, 255),
	phaseTint = c(226, 200, 255),
	name = c(255, 226, 196),
	titleColor = c(214, 186, 255),
	crack = c(190, 200, 255),
	flare = c(255, 214, 170),
	omens = {
		below = { "A sweet scent drifts by", "Foxfire flickers, then fades", "Silk rustles somewhere near", "You hear soft laughter" },
		even = { "The air shimmers faintly", "Foxfire at the edge of sight", "Her smile lingers in your mind", "Is that a shadow, or a tail?" },
		above = { "The air shimmers with foxfire", "Your eyes cannot be trusted", "Her whisper coils in your ear", "Your qi stirs against your will" },
		far = { "Her gaze unravels your qi", "You cannot tell dream from waking", "Nine tails, and none are real", "Your heart beats to her will" },
		deadly = { "Heaven forbids this fight", "Her beauty is your grave", "Your soul follows her fire", "Look away, or be hers" },
	},
} :: Theme

-- Jade scales and deep water: a flood dragon, horned and whiskered, coiling.
Themes.JadeJiao = {
	title = "Flood Dragon of the Jade Abyss",
	ornament = "rbxassetid://118897029575199",
	fill = { c(110, 236, 190), c(14, 120, 100) },
	phaseFill = { c(190, 255, 244), c(40, 170, 170) },
	trail = c(240, 255, 236),
	glow = c(110, 230, 190),
	tint = c(255, 255, 255),
	phaseTint = c(200, 255, 236),
	name = c(214, 250, 230),
	titleColor = c(150, 226, 200),
	crack = c(200, 255, 236),
	flare = c(200, 255, 236),
	omens = {
		below = { "Ripples cross still water", "The pool is deeper than it looks", "A scale glints in the reeds", "Mist curls off the water" },
		even = { "The water holds its breath", "Something vast turns below", "Your footing feels like a shore", "A cold current brushes you" },
		above = { "The tide rises around your feet", "Its coils stir the depths", "The air grows heavy with rain", "Jade eyes open in the water" },
		far = { "The flood answers its call", "You are a leaf on its river", "Its coils could drown a valley", "The rain will not stop" },
		deadly = { "Heaven forbids this fight", "The abyss has opened its jaws", "Rivers rise to bury you", "Flee, or join the drowned" },
	},
} :: Theme

-- Storm and lightning: static, ozone, brute weight, a light touch of wildness.
Themes.ThunderApe = {
	title = "Thunderlord of the Storm Crags",
	ornament = "rbxassetid://75169654856352",
	fill = { c(120, 176, 255), c(40, 64, 206) },
	phaseFill = { c(255, 240, 150), c(230, 150, 40) },
	trail = c(255, 250, 210),
	glow = c(140, 200, 255),
	tint = c(255, 255, 255),
	phaseTint = c(255, 244, 200),
	name = c(230, 240, 255),
	titleColor = c(160, 200, 255),
	crack = c(255, 250, 190),
	flare = c(220, 240, 255),
	omens = {
		below = { "Distant thunder rolls", "The clouds gather slowly", "A drumbeat in the hills", "Dust trembles on the ground" },
		even = { "Static prickles your skin", "The air tastes of metal", "Your hair lifts on end", "The wind smells of rain" },
		above = { "The air tastes of lightning", "The ground shudders beneath it", "Sparks crawl over your arms", "Thunder beats in your chest" },
		far = { "Each step cracks the earth", "The sky grows heavy above you", "Its roar shakes your bones", "Lightning answers its call" },
		deadly = { "Heaven forbids this fight", "The storm has chosen you", "You stand under the thunder", "Flee, or be struck down" },
	},
} :: Theme

return Themes
