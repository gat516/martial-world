# Boss health bar

Covers the boss bar (`BossBars`, `BossThemes`, `EnemyBars`): the design rules, the kit
frame and its art, themes, intro and hit feedback; read it when changing a boss's bar or
adding a boss theme.

## Rules (user, 2026-10-21)
The first version (600x150, a pulsing screen vignette and halo, a lingering omen, big
shakes) blocked the fight, and slimmer rebuilds from cropped or new generic Pillow art
were rejected. Show the frame art whole, never cropped; no screen darkening and no looping
pulses; small, short hit and phase feedback; smaller on phones.

## Design (2026-10-23, slim pass; user: "lighter slant, straight cuts, smaller on phones with the name only")
`BossBars.luau` drives `Play.BossBar`: a plain Frame (not a CanvasGroup: its render
texture softened the whole bar, "looks kinda low res") at the top centre, laid out
on a 560x104 box (`UIAspectRatioConstraint` 5.385, `MaxSize` 560x104). PC: 0.44 of the
width, so the full 560x104. Phones (`UiScale.isPhone()`, decided once): 0.36 of the Hud's
safe-area width, about 270x50 on an 844x390 phone (iPhone 13 landscape), showing only the
name and the bar: the phone mount has no plaque (at that width the plaque held the name
to 11 px, so the ornament went and the name stands as live text across the band, 0.7x0.3
of the box, 15 px on an 844 phone, 13 px on a 667 one), the realm line is hidden, and the
intro's title and omen get a larger label (0.9x0.28 of the box) so they stay readable
while they show.
Height: the bar sits up in the top bar's row (y 12, level with the top-right tiles)
whenever it clears the tiles and Roblox's own top-bar buttons by 8 px, else at its
authored y 64 under the row (`placeLift`, tweened 0.22 s). PC always clears them. On a
phone the tiles fold down to Inventory and Settings in combat (`TileFold`, the player's
`InCombat` attribute), which frees the room; the lift reads the fold's end state, so it
moves with the fold. Toasts treat the bar as an obstacle and go under it. Top to bottom:
- the kit's name plaque (brown lacquer plate with `curl_diamond` scroll ends) with the
  boss name live on it (`NameLabel`, Merriweather, max 18 px);
- the bar: a dark navy plate with a thin gilt rim (the vitals mount's body), a trough
  whose right end leans 15 degrees from vertical, straight segment cuts every tenth, a
  small gold diamond cap on the left end and the kit ruby stud (30 px) as the matching
  cap on the plate's right end. The trough ends 3 px clear of the ruby on every row
  (x 519.4 at the top, 513.0 at the bottom), so a full bar shows whole;
- under the bar: the title, then the omen, on one centred row (`TitleLabel`, `OmenLabel`),
  in the intro only, and on PC the realm right-aligned under the bar's end (`RealmLabel`).
Phase thresholds are gold studs (`gold_stud` cut) on the plate's top rim (`Pips`, made at
runtime); a crossed one dims and leaves a kit crack (`crack_split` cut) at its spot
(`Cracks`, over the frame). The fill, trail and hit flash are slanted 9-slices
(`bossbar_fill.png`, sheen `bossbar_sheen.png`; `art/ui/draw_boss_bars.py`) with the same
15-degree end; `BossBars.fitSlices` keeps `SliceScale` at bar height / source height.
Fades go piece by piece (`fadeArt`: the plate, mount, trail, fill and sheen images and the
cracks; on hide also the pips and labels), with the same 0.25 s timing as before.

Instance tree: `BossBar > Body > Plate` (behind), `Bar` (Trail, Fill > Sheen, Flare),
`Mount` (over the bar), `Cracks`, `Pips`, the four labels. Plate and Mount fill the box
(Stretch) plus a 4 px clear margin above it (Position y -4/104, Size y 108/104: the
plaque's scroll tips reached the image's top edge), so moving the bar means moving it in
the art too. `Bar`, `Pips` and `Cracks` sit at 28..519.4 x 40..64.

## Art
All of it is drawn at display size: Roblox draws GUI images without mipmaps, so the old
2x sources (a 1024x190 frame shown at 560, a 64 px fill shown 24 tall) looked soft. PC
pieces are 1:1 with the 560x104 box; phones get a half-size set (`*_phone.png`) that
`BossBars` swaps in (`ART`, `Themes.MOUNT_PHONE`).

The frame comes from the Figma UI kit (file `WNgoTL6QGdTEBy693Me8Y8`, Example page): the
sheet `Export / Roblox Boss Bar` (node 35:177) holds `Plate` and `Mount` at the box's 1x
size, built from kit parts (`Bar/Vitals Mount` body fill and gilt, `curl_diamond_L/R`, the
title plaque's plate, `gold_stud`, `ruby_stud`); `Boss Bar / preview` (node 35:194) shows
the bosses. The sheet matches the shipped art (15-degree Body, Trough and Rim, vertical
cuts every 49.14, the ruby 30 wide centred on (534, 52), the square socket removed).
The PNGs are made by `tools/boss_bar_reshape.py` from the sheet's last 45-degree export
(`git show 3d6d826:art/ui/figma/boss/bossbar_plate.png`, `..._mount.png`): it re-lays the
body, gilt and trough from that export's own columns along the new outline, redraws the
1 px rim and the cuts, places the kit's `ornament_ruby_stud` cut, and writes
`art/ui/figma/boss/bossbar_plate.png`, `bossbar_mount.png` (560x108) and `*_phone.png`
(280x54; the phone mount without the plaque), each with its top margin. To re-export from Figma instead (the sheet is current
now): export the sheet at scale 2 twice with `download_assets` (as is, and with the
sheet's fill set to black; set it back after), run `uv run --with pillow --with numpy
python tools/figma_boss_export.py light.png dark.png`, then resize to the sizes above with
the same margin. The fills: `uv run --with pillow --with numpy python
art/ui/draw_boss_bars.py 15` writes `bossbar_fill/sheen.png` (64x24) and `*_phone.png`
(40x12) and prints their `SliceCenter`s (one middle row, so nothing stretches along the
slanted strip). A changed PNG needs a new upload; ids in `art/ui/assets.json`,
`BossThemes.MOUNT`/`MOUNT_PHONE` and `BossBars.ART`. The pip and crack are the kit cuts
`art/ui/codex/cut/ornament_gold_stud.png` and `ornament_crack_split.png` (from
`ui-assemble`).

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
end pieces around the gold cap and the ruby end cap, the middle and the plaque left clear
(the request still describes the old square socket; update it before it is generated). A
motif frame needs both sizes (`mount`, `mountPhone`).
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
- Previewed in Studio's edit view (review stage) at 1920x1080 and 844x390 with the wolf
  fill; linted at 1920x1080, 1366x768, 844x390 and 667x375 (the phone layout is a script
  switch, so it was linted with the same properties set by hand). The intro, fades,
  trail, flashes, crack pop-in and phase colour shift are untested in play, as are the
  fox, jiao and ape fights and a real phone.
- The boss bar keeps a slanted trough end while the vitals HUD uses pointed ends (user,
  2026-10-23); they stay different on purpose.
- The lift and the tile fold are untested in play (the stage shows their end state).
