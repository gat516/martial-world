--!strict
-- Per-boss health bar themes (BossBars.luau reads these). Key = enemy def id.
-- Adding a boss = one entry here; any def without one uses `default`.
--   title      intro line under the bar ("Sovereign of the Silver Peaks")
--   emblem     the medallion in the frame's left socket (art/ui/draw_boss_bars.py
--              bossbar_emblem_*.png, drawn for 24px); see ASSET IDS below.
--   fill       { top, bottom } of the health gradient, saturated so it reads hard
--              against the near-black backing; phaseFill is the colour it
--              shifts toward as phases pass (lerped by phase / phases)
--   trail      delayed-damage trail colour (pale, near white)
--   tint       frame colour at rest; phaseTint what it warms to in the last phase
--   name/titleColor  text colours; crack  the crack overlay colour; flare  the flash
--   phases     optional override of the thresholds; default is def.summonAt
--              (health fractions where the fight changes, ticks + flare + cracks)
--   omens      { [tier]: { lines } } for the five danger tiers (EnemyBars STYLES:
--              below/even/above/far/deadly); a missing tier falls back to default.
--              One is picked at random per fight. Keep lines under ~26 characters.
local Themes = {}

-- ASSET IDS: paste each uploaded rbxassetid:// here (and record it in
-- art/ui/assets.json). Every boss bar image id lives in this file: the two
-- below and each theme's `emblem`. A value still starting with "PASTE-ID:" is
-- a placeholder; BossBars hides that image (the bar then shows only its
-- backing, trail and fill, and a missing emblem falls back to the default's).
Themes.ART = {
	frame = "rbxassetid://138795396175478", -- Body.Frame, the 9-sliced rim
	gloss = "rbxassetid://99818947891977", -- Bar.Gloss, the channel bevel
}

export type Theme = {
	title: string,
	emblem: string,
	fill: { Color3 },
	phaseFill: { Color3 },
	trail: Color3,
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
	emblem = "rbxassetid://137597767183814",
	fill = { c(236, 66, 52), c(136, 16, 20) },
	phaseFill = { c(255, 120, 60), c(170, 40, 20) },
	trail = c(255, 236, 200),
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
	emblem = "rbxassetid://95837482059535",
	fill = { c(120, 214, 255), c(22, 92, 178) },
	phaseFill = { c(255, 214, 120), c(190, 120, 40) },
	trail = c(240, 250, 255),
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
	emblem = "rbxassetid://136055338533795",
	fill = { c(255, 160, 70), c(196, 58, 32) },
	phaseFill = { c(190, 140, 255), c(96, 52, 190) },
	trail = c(255, 240, 220),
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

-- Venom green and jade scales: cold-blooded, coiled, patient.
Themes.JadeJiao = {
	title = "Coiled Terror of the Jade Marsh",
	emblem = "rbxassetid://102132008384241",
	fill = { c(130, 232, 90), c(18, 116, 58) },
	phaseFill = { c(214, 255, 70), c(110, 150, 20) },
	trail = c(240, 255, 210),
	tint = c(255, 255, 255),
	phaseTint = c(226, 255, 170),
	name = c(214, 250, 200),
	titleColor = c(170, 226, 150),
	crack = c(214, 255, 120),
	flare = c(200, 255, 190),
	omens = {
		below = { "Scales whisper on stone", "Something sheds its skin", "The reeds hold their breath", "A slow hiss in the damp" },
		even = { "A cold eye tracks you", "The air turns damp and still", "It has not blinked once", "You feel measured, not hunted" },
		above = { "Cold coils tighten around you", "Venom beads in the air", "Its tongue tastes your fear", "The ground slithers beneath you" },
		far = { "Your limbs grow slow and cold", "It waits for the venom to work", "You are already in its coils", "Patience is its sharpest fang" },
		deadly = { "Heaven forbids this fight", "One bite and you are stone", "It swallows light, then you", "Flee, or be digested" },
	},
} :: Theme

-- Storm and lightning: static, ozone, brute weight, a light touch of wildness.
Themes.ThunderApe = {
	title = "Thunderlord of the Storm Crags",
	emblem = "rbxassetid://132316172976874",
	fill = { c(120, 176, 255), c(40, 64, 206) },
	phaseFill = { c(255, 240, 150), c(230, 150, 40) },
	trail = c(255, 250, 210),
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
