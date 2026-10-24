# Herbarium and the garden windows

Part of [UI](../systems/ui.md); the garden itself is [garden](../systems/garden.md),
building is [build](../systems/build.md). Composed from the Codex cuts directly in Studio; there
is no Figma mock of these screens (the old kit file hit its MCP limit at the start of
this pass, 2026-10-23).

## The Herbarium (ready to wire)
The collection book of roadmap §5 / Phase B. The herb tiers and the collection
record don't exist yet, so nothing in the game opens it; the system that owns the
record calls it.

### API (`src/client/Herbarium.luau`)
```lua
Herbarium.open({ entries = { Entry, ... }, title = "Herbarium"? })
Herbarium.close()
Herbarium.isOpen()
Herbarium.preview() -- sample book, from the client console in play:
-- require(game.Players.LocalPlayer.PlayerScripts.Client.Herbarium).preview()

type Entry = {
	herb: string,          -- Herbs.Defs id: name, rarity and art come from the defs
	tier: number,          -- 1-5: I bronze, II silver, III gold, IV jade, V violet
	discovered: boolean,
	harvested: number?,    -- total ever harvested
	largest: number?,      -- the biggest size seen (×)
	mutations: { string }?,-- Herbs.Mutations ids seen on this herb
	name: string?,         -- overrides the def's name (a herb not in Herbs.Defs yet)
}
```
Entries show in the order given (sort by tier, then Herbs.Order). It registers with
`Menus`, so opening it closes other windows and hides the gameplay HUD.

### What the real system must provide
- A per-player record per herb: discovered, harvest count, largest size, mutations
  seen (the server knows all of these at harvest time, `Garden.luau`).
- A `tier` per herb (Herbs.luau gains it with the Phase B herb tiers).
- Undiscovered herbs as entries too (`discovered = false`), so the book shows the
  gaps; their name stays hidden, their tier shows.
- Rewards for completing a page or tier are not drawn yet (open question in the
  roadmap: cosmetic only, or foundation experiences).

### Layout
`StarterGui.Herbarium` (`assets/Herbarium.rbxmx`): `Canvas` (fitted by `UiScale`) >
`Window` (the open book: `UIAspectRatioConstraint` 1024:562, max 1000x549, 0.94x0.86 of
the canvas, so 611x335 on an 844x390 phone) > `Book`, `LeftPage`/`RightPage` (equal
461-px-wide frames centred on each paper, grids of 3x2 cards), `TitlePlaque` (the gold house
plaque on the top edge, 50 tall, fitted to the title by `Ribbon.fit`, style `gold_curl`,
22 px; see [ribbons](ribbons.md)), `Close` (close seal on the top-right corner), `PrevButton` /
`NextButton` (navy back seals with the gold chevron, half over the side edges, dimmed
at the ends), `Footer` (page and discovered count on the bottom cover edge) and the
hidden `CardTemplate`.

The card (`herb_card`, 565x869): the herb's icon (or glyph in its colour) in the art
window, the tier shield on the window's top-left corner with a live numeral, the name
(Merriweather, ink brown), the rarity gem and word, a diamond divider, "Harvested n"
and "Largest ×n", and one row of mutation ribbons (what doesn't fit is clipped).
Undiscovered: `herb_card_empty`, a grey question glyph, "Undiscovered", the tier
shield greyed. Phone cards are about 81x125: the gem moves to the art window's
top-right corner, the rarity word and divider go, the name gets two lines (floor 9 px)
and one stat line shows (the largest size when known).

Measured (Edit view): desktop page 450x482, cards 132x204, page margins left/right
13.7/13.7 and top/bottom 25.2/25.2; phone page 275x295, cards 81x125, margins 8.4/8.4
and 15.4/15.4; both pages' cards the same size.

## The garden and build windows (kit restyle, 2026-10-23)
Same behaviour as before; the look moved onto the kit:
- **Chrome** (Herbalist, seed picker, build catalog): the `panel_frame` body with the
  A3 `window_corner_small` on all four corners (`Corners` frame; the other three are
  mirrored copies, `ornament_window_corner_small_tr/bl/br.png`), placed so the
  corner's rail lies on the panel's rim band (rows 40-66 of the 1024 source): 76 px
  wide at SliceScale 0.3, 66 px at 0.26. The A3 title crest (310x51, title centred on
  its plate band at 63.6 % height) and the A3 close seal with a live "×".
- **Herbalist** (`Hud.HerbShop`): C2 catalog tabs for Buy/Sell (SliceScale =
  height/140, so the cloud ends never stretch), rows with the herb in a B2 item slot,
  the rarity gem before the name, Fredoka numbers; Sell everything is the C1 crimson
  ribbon. Row buttons stay the solid kit buttons (ribbons at 36 px were too busy).
- **Seed picker** (`Hud.SeedPicker`): a grid of C1 seed packets (100x91): art on the
  paper, rarity gem and seed count either side, name and grow time in ink below.
  Tapping a packet plants it. `SeedPicker.luau` fills it (no longer `ListWindow`).
- **Planting bar**: the seed in a B2 item slot; Change seed carries the white
  `glyph_plant` tinted jade.
- **Plant tag**: rarity gem before the rarity, mutations as C1 tag ribbons that wrap,
  an hourglass (`glyph_rush`) before the growth bar, `glyph_harvest` before "Ready".
- **Build catalog**: catalog tabs, tiles on the B2 item slot (selected:
  `item_slot_selected` under the tile's content), the lock glyph on locked tiles,
  benefit badges as small jade ribbons, set tabs with their C2 medallion, the set
  medallion and "<set> set" line in the detail panel, and the C2 peak-score gauge
  under the tabs ([build](../systems/build.md)). The tab list (a clipping
  ScrollingFrame) pads 6 px left and right and 4 px top and bottom, so a tab's 5 %
  hover growth (`Motion.buttons`) isn't cropped.

Shared garden art lives in `src/client/HerbArt.luau`: `paint(swatch, id)` (icon or
glyph in a Swatch), `gem(image, rarity)`, `tagStyle(mutation)` (its Ribbon style), `Tiers`. Rarity gems
follow the Inventory's ladder (`Rarity.gem`, see [inventory](inventory.md)): Common
bronze, Uncommon silver, Rare jade, Epic violet, Legendary gold. Mutation ribbons follow the mutation's worth: Windswept and
Dewy bronze, Auspicious jade, Thunderstruck crimson, Golden gold, Rainbow and
Heavenlit violet.

Measured at 1616x784 and in an 844x390 frame: Herbalist header and footer 44/44,
list 30/30, rows 4/4 inside the list, row parts centred on the row (dy 0); seed
packets 6/6 from the list edges, packet art and text centred (dx 0); build header
56/56, body 26/26, catalog grid 25.3/25.3 (5 columns) on PC and 5.3/5.3 (4 columns)
on the phone; title crests centred (dx 0) on every window.

Mutation tags are three-part ribbons (`Ribbon.STYLES` `tag_<colour>`, the C1 SLICE3
cuts sized to 48 px with a clear margin), fitted to their text by `Ribbon.fit`
(`HerbArt.tagStyle`); the cloud ends never stretch. `tools/ui_lint.py` checks them as
shown.

## Art (ids in `art/ui/assets.json`, `codex/cut/ornament_*`)
C1 `herbarium_book`, `herb_card`, `herb_card_empty`, `herb_tier_1`..`5`, `tag_*`,
`seed_packet`; C2 `catalog_tab(_selected)`, `set_*`, `peak_meter`; B2 `gem_*`,
`item_slot(_selected)`; A3 `window_corner_small` (+ mirrors), `title_crest`,
`close_seal`, `back_seal`; A1 `chevron`, `divider_diamond`; A5/A6 white
`glyph_plant`, `glyph_harvest`, `glyph_rush`, `glyph_lock`, `glyph_question`. Missing
art is requested in [codex-sheets](codex-sheets.md), sheet C1b.

## Untested
Not played: the Herbarium's `preview()` and page turns, the seed picker's packet
taps, set tabs (no item has a set yet) and the peak gauge (no server sets the
attribute yet) were only seen in Edit-mode previews.
