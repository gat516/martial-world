# Codex sheets: every piece of UI art the roadmap needs

Written 2026-10-22 for the Figma UI kit ([overhaul-plan](overhaul-plan.md), "UI kit in Figma").
Each sheet is one Codex conversation. Paste the **shared rules**, attach the reference images,
then paste the sheet. The pieces are cut by `ui_assemble.py`, swapped into the kit's Figma
components and uploaded to Roblox. Everything else (bars, pills, panels, tabs, toggles,
simple glyphs) is already built as vectors in the kit and needs no art.

Sheets are ordered by the roadmap's order of work: **A** is needed now (dialogue, prompts,
HUD, windows), **B** next (rewards, quests, sect), **C** later (garden, building, Halls,
masters, events, tribulation, rifts, leaderboards). Done so far: the first ornament sheet
(`art/ui/codex/ornaments_source.png` on `ui-assemble`).

Attach to every conversation:
1. `docs/reference/ui/dialogue_prompt_reference.webp` (on `progression-bible`).
2. `docs/reference/ui/hud_vitals_reference.webp` (red and blue bars, ruby studs, plaques).
3. The first ornament sheet, as the style to match.

## Shared rules (paste first, every time)
```text
You are making UI art for a Roblox xianxia (Chinese cultivation fantasy) game. Match the attached references and the attached ornament sheet exactly: warm brushed gold with dark-gold outlines, soft light from the upper left, xiangyun cloud scrolls, deep midnight-navy lacquer (#192129), dark brown lacquer plaques (#2a1a12), ruby accents (#c8202e), cream (#faecc3).

Rules for every sheet:
1. Flat pure magenta #FF00FF background, nothing else painted behind the pieces.
2. Every piece fully isolated, with wide magenta gaps; nothing touches another piece or the image edge.
3. No text, letters or numbers anywhere, unless the sheet says so. Leave text areas empty.
4. Front-on, flat game-UI style: no perspective, no cast or drop shadows, nothing glowing outside a piece's outline (except the light-effect sheet).
5. Panels, buttons, banners and cards: ornate detail at the corners and ends only; plain straight borders and a calm, empty middle, so they can be stretched in the middle.
6. Pieces in a set (sizes, colours, states) share the same ornament size, border thickness and end shapes.
7. Crisp edges, no blur or noise. Output the largest image you can (1536 x 1024).
```

## A. Needed now

### A1. Ornaments, part 2
```text
Row 1: a plaque end ornament: a double S-scroll gold curl attached to a gold diamond stud with a dark centre (left-facing only). A small version of the same.
Row 2: a long thin gold divider rule with a small diamond in the centre; a gold divider rule with small cloud-curl ends; a short vertical divider.
Row 3: a faint ink-wash cloud pattern for panel backgrounds: soft swirling xiangyun clouds in pale grey-blue, low contrast, no outlines. A second one, wider.
Row 4: a red square seal stamp (chinese chop), empty middle; a round red seal stamp, empty middle.
```

### A2. Response buttons and prompt banner
```text
Row 1: a long dialogue response button (about 9:1): dark navy pill, thin gold edge, ornate cloud-scroll end caps on both ends, a long PLAIN middle, an empty round icon space at the left end.
Row 2: the same button highlighted: brighter gold edges, a soft inner gold glow inside the outline, a small gold arrow at the right end.
Row 3: the interaction prompt banner from the reference (the dark banner that tucks behind the round key plate and extends right, gold cloud flourishes at its top and bottom right, angled right end), long, with a plain middle. No key plate.
Row 4: a round brass hold-to-confirm ring track the size of the key plate, empty inside.
```

### A3. Window chrome (inventory, character, techniques, settings)
```text
Row 1: one large ornate window corner (top-left only): gold fretwork with a cloud scroll, heavier than a panel corner, for big windows. A matching small corner.
Row 2: a window title crest that sits on the top edge of a window: a wide brown lacquer plate with gold scroll ends and a cloud flourish above it, empty middle.
Row 3: a round close seal: gold ring, ruby lacquer face, empty middle. A round back-arrow seal in navy and gold, empty middle.
Row 4: a gold scrollbar thumb (vertical, with small end caps); a gold slider knob (a small diamond on a ring); a checkbox frame (square gold border, empty) and a gold check mark.
```

### A4. Portraits
One image per character, all with identical framing: a shoulders-up bust facing slightly
left, on the misty navy backdrop from the reference, square, no frame.
```text
1. Elder Qingyun, the sect elder (calm, old, long white beard, dark robe, topknot).
2. The Herbalist.
3. The weapon rack keeper.
4. A plain unnamed silhouette (dark figure on the backdrop).
5. The "???" silhouette: dark head and shoulders with a cream question mark.
```
Masters get portraits once they are cast (roadmap 3d).

### A5. Glyph sheet: interaction and dialogue (white)
```text
Exception to the rules: draw these as WHITE glyphs (pure white fill, no gold, no outline colour) on magenta, in a 4 x 4 grid, each centred in its cell, same stroke weight and rounded corners, simple bold shapes that read at 24 px.
Speech bubble, cloth bag, door with arrow (leave), rolled quest scroll, coin purse, bowing figure, sword, heart, lock, question mark, exclamation mark, open hand (give), sickle and leaf (harvest), hourglass (rush), seedling (plant), opening chest.
```

### A6. Glyph sheet: elements, weapons, stats (white)
```text
Same white-glyph grid rules, 4 x 4:
Metal, wood, water, fire, earth, lightning, wind, ice (spirit root elements); sword, spear, saber, fist, staff (weapon classes); spirit stone, qi swirl, insight (an eye or a lit lamp).
```

## B. Next: rewards, quests, sect

### B1. Reward cards (roadmap 3c: one card, three jobs)
```text
Row 1: a large ornate reward card frame, 3:2, crimson and gold (boss victory): heavy gold corners, a crimson lacquer header strip, empty middle.
Row 2: the same card in gold and jade (quest complete), with an empty round crest slot at the top centre.
Row 3: a slim objective banner, 8:1, navy and gold, light ornament (for quick onboarding objectives).
Row 4: a ribbon title banner with folded ends, empty, in crimson; the same in jade.
```
```text
Separate image, black background instead of magenta: a radial light-ray burst (pale gold rays fading out), square, to sit behind a reward card. A second one, soft and wide, for the milestone (breakthrough or bloodline) card.
```

### B2. Reward and item tiles
```text
Row 1: a square reward tile frame (gold border, small corner studs, empty dark middle), neutral; the same in four rarity edges: grey, jade, violet, gold.
Row 2: a rounded item-slot frame for the hotbar and inventory, neutral, plus a "selected" version with a brighter gold edge.
Row 3: a small round currency coin frame (gold rim, empty middle); a small diamond rarity gem in grey, jade, violet, gold.
```

### B3. Quest log and sect board (roadmap 3, 3b)
```text
Row 1: a wooden notice board header plaque (dark wood, gold trim, empty); a pinned paper notice (aged cream paper, red pin, empty); the same notice torn and defaced with dark ink smears (the demon chain's clue).
Row 2: three sect rank crests, each a gold-framed emblem with an empty centre: Outer Disciple (simple round, bronze-gold), Inner Disciple (hexagonal, gold with jade), Core Disciple (ornate, gold with a ruby).
Row 3: a contribution token (a jade-and-gold coin with a cloud motif); a quest scroll seal (a rolled scroll with a red wax seal); a daily-task seal and a weekly-task seal (round, different rims).
```

### B4. Character, foundation and combat (roadmap 1, 4)
```text
Row 1: a foundation crack overlay set for a small round meter: hairline crack, split crack, shattered, drawn in dark ink with faint gold edges, on magenta.
Row 2: a jade "deep foundation" glow ring (soft jade light, round, black background allowed for this one piece).
Row 3: a technique tier frame set T1 to T4 (square skill-slot frames getting more ornate: bronze, silver-gold, gold, gold with ruby and clouds); a Dao level ring (a round gold ring with nine small notches).
Row 4: two bloodline badges: Pure (gold, with a flame-and-cloud crest) and Inherited (silver-gold, with a lineage knot); a heaven-defying mark (a jagged gold-and-crimson seal with a lightning crack).
```
```text
Separate image, black background: a full-screen death-save vignette (dark crimson edges fading to transparent centre, faint heartbeat veins), 16:9. A round heartbeat ring (a crimson pulse ring), square.
```

### B5. Boss bar beast motifs (the boss bars, [boss-bars](boss-bars.md))
The boss bar is the kit's frame: a long dark navy plate with a thin gold rim, a small gold
diamond cap on the left end, and on the right a square gold-rimmed socket that holds a ruby
star stud (it hides the bar's slanted end). Each boss gets its own motif **at the two ends
only**: the long middle of the bar (where the health shows) and the brown name plaque above
its centre must stay clear. Attach a screenshot of the current bar (the Figma kit's
`Boss Bar / preview` frame, Example page) with the shared references.
```text
Four rows, one per beast. Each row has two pieces, both drawn large (about 400 px tall) and front-on: a LEFT END piece, an ornament that wraps around an empty diamond-shaped space where a small gold diamond stud will sit (about 1:1, motif reaching up and down beyond the bar's height, nothing reaching right into the bar), and a RIGHT END piece, a square socket frame with an empty square middle where a ruby star stud will sit, its motif growing from the frame's top, bottom and outer (right) side, nothing on its left side (the bar runs into it there). Same warm brushed gold, dark-gold outlines and upper-left light as the reference; each beast adds its own material and motif:
Row 1, Elder Wolf King: dark iron and moon-silver with gold edges; frost-white fur tufts, two small curved fangs, a few icicle points.
Row 2, Nine-Tailed Fox: black lacquer with fine gold line-work; curling orange foxfire wisps and one soft curled fox tail.
Row 3, Jade Jiao (a horned flood dragon): jade with fine overlapping scales; a swept fin, a whisker curl and a small cloud of water spray.
Row 4, Thunder Ape: rough dark bronze with notched edges; a small storm cloud and two thin forked lightning bolts in pale gold.
Plain magenta inside the empty diamond and square spaces. No text, no faces or eyes, no crowns or halos, no glow outside the outlines.
```
After cutting: compose each pair onto a copy of the `Export / Roblox Boss Bar` sheet's
Mount in Figma (node 35:181), export it as `bossbar_mount_<beast>.png` with
`tools/figma_boss_export.py`, upload it and set that boss's `mount` in `BossThemes.luau`.

### B6. Meditation glyphs (white; the seated tiles, [cultivation](cultivation.md))
The seated tiles use the A5/A6 glyphs where one fits (qi swirl for Circulate, insight for
Technique, quest scroll for Method) and the older Pillow icons for the rest (Break Through,
Rise, Practice, Weapon Dao, Back, the death-save seal). This sheet replaces those stand-ins.
```text
Same white-glyph grid rules as A5, 3 x 3:
Break through (an arrow rising through a cracked ring), rise (a figure standing up from a meditation cushion), practice (two crossed jian), weapon Dao drill (a single jian with three motion arcs), return (a curved back arrow), calm view (a lotus flower, front-on), circulation (a qi swirl running round a small dantian circle), foundation (three stacked stones), survive (a heart inside a rising flame).
```

## C. Later: garden, building, Halls, masters, events

### C1. Herbarium and garden (roadmap 5)
```text
Row 1: an open book, two-page spread, lacquer cover with gold corners, aged pages, empty (wide).
Row 2: a herb entry card frame (paper, gold border, an empty art window at the top, empty text area); an empty-entry silhouette frame (greyed).
Row 3: tier badges I to V as empty frames (small shields getting more ornate: bronze, silver, gold, jade, violet).
Row 4: mutation tags (a small ribbon tag, empty) in five colours; a seed packet tile frame.
```

### C2. Building (roadmap 6)
```text
Row 1: a catalog tab plate (brown lacquer, gold edge, empty) and its selected version.
Row 2: six set emblems as gold-framed round medallions with a simple scene inside: courtyard, jade pavilion, cloud palace, herb house, library, formation array.
Row 3: a peak-score meter frame (a vertical mountain-shaped gauge, gold outline, empty inside).
```

### C3. Halls and masters (roadmap 3b, 3d)
```text
Row 1: five empty crest shield shapes (round, kite, banner, hexagon, lotus) in gold outline with plain dark fill.
Row 2: three crest border styles (cloud ring, dragon ring, plain double ring), and six emblems to go inside (sword, peak, lotus, crane, tortoise, flame), gold.
Row 3: a lineage card frame (portrait window at the left, an epithet ribbon slot, gold corners); a seat plate (a small gold plaque, empty) and nine of them arranged in a fan.
Row 4: an epithet ribbon (long, folded ends, empty) in gold, and a master/disciple ceremony frame (wide, red and gold, with two empty portrait medallions).
```

### C4. World events, tribulation and rifts (roadmap 7, 9)
```text
Row 1: a wide event scroll banner (unrolling paper with gold rod ends, empty), 6:1; a countdown ring (gold ring with tick marks, empty middle).
Row 2: event map pins (a gold pin with an empty round head) in gold, jade, crimson, violet; an off-screen direction chip (a small gold arrow plate).
Row 3: the "Heaven's decree" card: a black-and-gold card with lightning-thread corners and an empty middle (tribulation); a tribulation warning ribbon (black and crimson, lightning edges, empty).
Row 4: a secret-realm rift card frame (violet and gold, swirling portal motif at the top, empty middle); a rift modifier tag (small violet plate, empty).
```

### C5. Leaderboards and paths (roadmap 9)
```text
Row 1: rank medals 1, 2, 3 (gold, silver, bronze round medals with a cloud ring, empty centre, no numbers).
Row 2: a leaderboard row frame (long, plain middle, gold ends), and its "you" highlight version.
Row 3: three path crests: Orthodox Sect (a jade peak in a gold ring), Rogue (a lone sword in a bronze ring), Blood Sect (a crimson drop in a black-and-crimson ring; for the demon path only, never shown before it is found).
```

### C6. Blood Sect variant (the demon path, roadmap 9)
```text
The same ornament set as the first ornament sheet (clouds, corners, studs, key plate, chevron), redrawn in the Blood Sect's look: blackened iron and dark crimson instead of gold, jagged thorned scrolls instead of soft clouds, a deep red glow allowed inside outlines.
```

## Light effects (one sheet, black background)
```text
Exception: pure black background (no magenta), soft light allowed.
A 4-point sparkle; a soft round glow; a lens glint (a short horizontal streak); a ring shockwave; a rising qi wisp (soft cyan-white); a gold dust cluster.
```
These are keyed by brightness, not by colour.
