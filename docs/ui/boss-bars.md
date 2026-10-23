# Boss health bar

Covers the boss bar (`BossBars`, `BossThemes`, `EnemyBars`): the toned-down design rules, themes, intro and hit feedback, and the v2 per-boss frames; read it when changing a boss's bar or adding a boss theme.

`BossBars.luau` drives `Play.BossBar` (a CanvasGroup, top centre,
`FitWithinMaxSize` 4:1, 0.44 of the width, max 400x100, so smaller on phones).
The design is the original one (55e39fb), toned down (user, 2026-10-21): the
first version (600x150, a pulsing screen vignette and halo, a lingering omen,
big shakes) blocked the fight; slimmer rebuilds from cropped or new generic
art were rejected. Rules: show each boss's frame art whole, never cropped; no
screen darkening and no looping pulses; small, short hit and phase feedback.
`BossThemes.luau` holds one table per boss def id (`ElderWolfKing`,
`NineTailFox`, `JadeJiao`, `ThunderApe`, plus `default`). `EnemyBars.luau` picks
the boss (locked, else the nearest hunting you within `BOSS_RANGE`) and the
danger tier (`Pacing.Danger`, `STYLES`, re-picked on breakthrough). A theme is a
title line, a frame image (1024x256, bar hole at x168-856 y110-146, name plate
above, realm plaque below; `art/ui/draw_boss_bars.py`, ids `bossbar_*` in
`assets.json`), saturated fill colours (top-light vertical gradient), a pale
trail, a static glow colour, a phase colour, and omen pools per tier (random
per fight, short lines). Adding a boss is one table entry (an unlisted boss
gets `default`).

## Intro and feedback
Intro: the bar fades in, the fill sweeps up, name and realm rise in; the
theme title shows under the name (`TITLE_HOLD`), then the omen (`OMEN_HOLD`),
and both fade out fully (a breakthrough mid-fight shows the new omen once).
The halo behind the bar is faint and static (`GLOW_REST`). The bar has ten
talisman slips, a tick at each phase threshold (`def.summonAt`, or
`theme.phases`), a trail, and a 1-3px nudge and quick flash on hits of
`BIG_HIT` (5%) or more. Crossing a threshold flashes the bar, nudges it,
spreads faint cracks from the centre, warms the fill and frame colours and
greys the tick.

## v2 frames
v2 frames (user, 2026-10-21): each of the four bosses gets its own slender
frame (`bossbar2_wolf/fox/ape/jiao.png`, `draw_boss_bars.py v2_*`; run it with
`v2` to redraw only these), in the language of the user's references: a long
thin bar, a thin dark rim hugging it with shaped ends, small organic accents
growing out of the rim and one small motif at top-centre; the name is plain
stroked text above (no plaque), no emblem or medallion ("tacky"), smooth
rather than pixel art. One family, never a recolour: wolf in dark iron with
arrow tips, frost tufts, tiny fangs and icicles and a fur crest; fox in black
lacquer with gold lines, hook-curl ends, foxfire wisps and a curled tail; ape
in rough dark bronze with notched blunt ends, faint lightning hairlines and a
storm cloud; jiao in jade with fine scales, swept fins, whisker curls and a
flaming pearl. They use a longer window (`V2_WIN` 64,112 to 960,144), so
`BossBars` switches the Bar, name, realm, title and omen to `V2_LAYOUT` when a
v2 frame is shown (realm small at the bar's right end below it; title, then
omen, on one row under the middle). Their ids go in the `ASSET IDS` block at
the top of `BossThemes.luau` (`Themes.FRAMES`, keyed by def id) and in
`assets.json`; a `PASTE-ID:` placeholder would keep that boss on its
original frame and layout. All four are uploaded and wired.

## Known gaps
- The v2 frames and the layout switch are not seen in Studio yet; the fox,
  jiao and ape bars are untested until those bosses are in play; the phase
  cracks are one shared image.
