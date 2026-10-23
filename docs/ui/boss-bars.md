# Boss health bar

Covers the boss bar (`BossBars`, `BossThemes`, `EnemyBars`): the design rules, the kit
frame and its art, themes, intro and hit feedback; read it when changing a boss's bar or
adding a boss theme.

## Rules (user, 2026-10-21)
The first version (600x150, a pulsing screen vignette and halo, a lingering omen, big
shakes) blocked the fight, and slimmer rebuilds from cropped or new generic Pillow art
were rejected. Show the frame art whole, never cropped; no screen darkening and no looping
pulses; small, short hit and phase feedback; smaller on phones.

## Design (2026-10-23, kit pass; user: "looking great")
`BossBars.luau` drives `Play.BossBar`: a CanvasGroup at the top centre (y 64), 0.44 of the
screen's width, laid out on a 560x104 box (`UIAspectRatioConstraint` 5.385, `MaxSize`
560x104), so about 371x69 on a landscape phone. Top to bottom:
- the kit's name plaque (brown lacquer plate with `curl_diamond` scroll ends) with the
  boss name live on it (`NameLabel`, Merriweather, max 18 px);
- the bar: a dark navy plate with a thin gilt rim (the vitals mount's body), a trough
  whose right end is cut at 45 degrees, slanted segment cuts every tenth, a small gold
  diamond cap on the left end, and on the right a square gold-rimmed socket holding the
  kit's ruby star. The socket hides the whole slant (user, 2026-10-23: the ruby alone left
  the diagonal showing); measured in the art, the slant's corners sit 2.1 to 11.3 px (at
  1x) inside its opaque area;
- under the bar: the title, then the omen, on one centred row (`TitleLabel`, `OmenLabel`),
  and the realm right-aligned under the bar's end (`RealmLabel`).
Phase thresholds are gold studs (`gold_stud` cut) on the plate's top rim (`Pips`, made at
runtime); a crossed one dims and leaves a kit crack (`crack_split` cut) at its spot
(`Cracks`, over the frame). The fill, trail and hit flash are slanted 9-slices
(`bossbar_fill.png`, sheen `bossbar_sheen.png`; `art/ui/draw_boss_bars.py`), so the
draining edge keeps the trough's 45-degree cut; `BossBars.fitSlices` keeps `SliceScale` at
bar height / 64.

Instance tree: `BossBar > Body > Plate` (behind), `Bar` (Trail, Fill > Sheen, Flare),
`Mount` (over the bar), `Cracks`, `Pips`, the four labels. Plate and Mount fill the box
(Stretch), so moving the bar means moving it in the Figma sheet too. Bar window, measured
in `bossbar_plate.png`: x 27.3..524.5, y 39.4..64.0 of 560x104; `Bar` sits at 28..524 x
40..64.

## Art
Exported from the Figma UI kit (file `9u6RPHLelUJF6aABm6mY7y`, Example page): the sheet
`Export / Roblox Boss Bar` (node 35:177) holds `Plate` and `Mount` at the box's 1x size,
built from kit parts (`Bar/Vitals Mount` body fill and gilt, `curl_diamond_L/R`, the title
plaque's plate, `gold_stud`, `ruby_stud`). `Boss Bar / preview` (node 35:194) shows all four
bosses. To re-export: export the sheet at scale 2 twice with `download_assets` (as is, and
with the sheet's fill set to black; set it back after), then
`uv run --with pillow --with numpy python tools/figma_boss_export.py light.png dark.png`
(writes `art/ui/figma/boss/bossbar_plate.png`, `bossbar_mount.png`, 1024x190). A changed
PNG needs a new upload; ids in `art/ui/assets.json` and `BossThemes.MOUNT`. The pip and
crack are the kit cuts `art/ui/codex/cut/ornament_gold_stud.png` and
`ornament_crack_split.png` (from `ui-assemble`).

## Themes
`BossThemes.luau` holds one table per boss def id (`ElderWolfKing`, `NineTailFox`,
`JadeJiao`, `ThunderApe`, plus `default`): the title line, fill gradient and the colour it
warms to as phases pass, trail, frame tint, text, crack and flash colours, optional
thresholds, omen pools per danger tier (`EnemyBars.STYLES`, `Pacing.Danger`; random per
fight, short lines) and an optional `mount` (a beast-motif frame). Adding a boss is one
table entry (an unlisted boss gets `default`). `EnemyBars.luau` picks the boss (locked,
else the nearest hunting you within `BOSS_RANGE`) and the danger tier.

Beast motifs (the kit's flair rule: each boss bar keeps the frame, studs and gems but
carries its beast) are requested as Codex sheet B5 in [codex-sheets](codex-sheets.md):
end pieces around the gold cap and the ruby socket, the middle and the plaque left clear.
Until they are cut and composed, every boss wears the shared mount and differs by fill
colour, title and omens.

## Intro and feedback
Intro: the bar fades in from 0.96 scale, the fill sweeps up, name and realm rise in, the
pips fade in; the title shows under the bar (`TITLE_HOLD`), then the omen (`OMEN_HOLD`),
and both fade out fully (a breakthrough mid-fight shows the new omen once). Hits: the fill
drops, the trail drains after it; a hit of `BIG_HIT` (5%) or more gives a 1-3 px nudge and
a quick flash in the fill's shape. Crossing a threshold flashes the trough, nudges the bar,
dims its pip, cracks the frame there, flashes the name and warms the fill and frame
colours. The region banner stays quiet while a boss bar is up (both use the top centre).

## Known gaps
- Previewed in Studio's edit view at 560x104 and at 288 and 371 px wide (wolf and fox
  fills, crossed pips and cracks); the intro, trail, flashes, crack pop-in and phase
  colour shift are untested in play, as are the fox, jiao and ape fights.
- The vitals HUD (`hud-compact`) has since moved from 45-degree slants to pointed ends with
  gentler cuts; the boss bar keeps the 45-degree trough the user approved. Align them if
  the user wants one shape.
- On a phone the realm line is about 10 px tall.
