# Inventory windows

Covers the Inventory window (Weapons & Arts and Pouch tabs), the rarity ladder,
NEW badges, dragging weapons and arts to the hotbar, the class glyphs, the bottleneck
and Comprehend controls, and sort, filter and search; read it when working on
`Inventory`, `InventoryFilter`, `Rarity`, `Fresh`, `SlotArt` or `HotbarView`. General
HUD rules are in [ui](../systems/ui.md).

Rebuilt 2026-10-23 after the user's review ("I don't know which weapon is for which",
"so hard to tell what's common, what's rare", "I can't easily find a weapon or the
arts I want", "I don't need equip buttons if I can just drag it down").

## Layout (`StarterGui.Hud.Inventory`, 760x500 max, centred; touch: fills the space above the hotbar)

- Left column (60 %): a tab row (**Weapons & Arts**, **Pouch**, each with a crimson
  NEW count) and the **Search** box; a chip **Rail** (All, then one chip per section)
  and the **Sort** button; then the **Grid**, a scrolling list of sections.
- Weapons & Arts sections, one per weapon class: the class glyph, name and Dao level
  in the class colour, a gold rule, the class's weapons (Bare Fists under Fist), a
  short gold split, then the arts that need that class. Order: the class in hand,
  then **Universal arts** (any weapon), then the other classes in `Weapons.ClassOrder`.
  Every owned art is listed, hotbar ones too (their slot number shows on PC).
- Pouch sections, one per kind (spirit herbs, pills, cores, heavenly treasures);
  items on the hotbar are listed too.
- Cells (72x94): the rarity tile (64x62) with the icon centred on the tile's hole,
  the name under it (two lines, PC and touch), the class glyph top-left on arts,
  `Lv n` (cinnabar at a bottleneck) or `xN` bottom-right, the slot number bottom-left
  (keyboards), the cinnabar 佩 seal top-right on the weapon in hand, and a crimson
  NEW tag top-right. The chosen cell wears the kit's selected-slot ring (the same
  ring as the hotbar's held slot).
- Right column (detail pane, plain words): the tile preview; name; grade gem and
  label ("Spirit grade", "Rare"); class glyph and kind ("Sword · weapon", "Sword art",
  "Universal art", "Spirit herb"); where it is ("In your hand", "On your hotbar,
  slot 3", "Not on your hotbar. Drag it onto a slot to use it."); what goes with it
  (a weapon's arts; an art's required weapon and whether it is in hand); what it does
  (for weapons with the grade multiplier); then the Dao row (weapons, or every class
  with nothing chosen) or the art's level row, cost rows and buttons. Items keep
  Eat/Use and Hold; arts keep Add to / Remove from hotbar and Comprehend at a
  bottleneck. Weapons have **no buttons**.
- Measured 2026-10-23 (PC 760x500 window; phone 705x320 window on a 750x390 safe
  area): content padding 22 left and right in both columns, tab row and search share
  centre y 52, rail chips and sort centre y 100, tab/search/sort/section right edges
  all at the column edge, gaps of 8 between cells, the divider centred between the
  columns (14.5 / 13.5), cell icons within 0.2 px of the tile hole centre, the
  preview's titles block centred on the preview, grid and detail bottoms equal.
- Figma: no mock. The kit file hit its Starter call limit mid-task (the kit has since
  moved to `WNgoTL6QGdTEBy693Me8Y8`), so this was composed from the cuts and checked in
  Studio; the uploaded class_* and tech_* frames sit on the kit's Example page.

## Rarity ladder (`Rarity.luau`)

| Tier | Frame (kit tile) | Gem | Items (`Items.Rarities`) | Weapons and arts (`Weapons.Grades`) |
| --- | --- | --- | --- | --- |
| 1 | `tile_neutral` (bronze) | `gem_grey` tinted bronze | Common | Mortal |
| 2 | `tile_grey` (silver) | `gem_grey` | Uncommon | |
| 3 | `tile_jade` | `gem_jade` | Rare | Spirit |
| 4 | `tile_violet` | `gem_violet` | Epic | Earth |
| 5 | `tile_gold` | `gem_gold` | Legendary | Heaven |

Bare Fists have no grade and use the plain kit `item_slot`. The rarity and grade
colours were changed to match their frames (Common bronze, Uncommon silver,
Rare/Spirit jade, Epic/Earth violet, Legendary/Heaven gold), so the text, the reward
toasts and the frames agree. Arts gained a `grade` (Techniques defs; nil = Mortal):
the starter and kill-milestone basics are Mortal; Twin Phoenix Cannon (first boss),
Moonflash Draw (60 kills) and the boss-pool class arts are Spirit.

## Class glyphs and colours (`SlotArt.classGlyph`, `SlotArt.classColor`)

One mark per weapon class, white and tinted: weapons are drawn as their class glyph
in their class colour on their rarity tile, and the same glyph marks arts (cell
badge, hotbar badge), section headers, rail chips, the detail pane and Dao rows.
Fist ivory, Sword azure, Saber red, Greatsword orange, Guandao teal, Spear rose,
Staff green; universal arts a neutral cream. Glyphs: `art/ui/glyphs/class_*.png`
(`art/ui/draw_class_glyphs.py`): the kit's white weapon cuts for Fist, Sword, Saber,
Spear and Staff, padded square; Greatsword and Guandao are white silhouettes of
their item icons until Codex draws them (codex-sheets "Class glyphs and art icons").
Every class art on the hotbar now wears its badge (not only while unarmed); the
slot still dims while the class isn't in hand.

## Weapons: drag, no buttons

- While the Inventory is open a **weapon slot** (`Stack.Hotbar.WeaponSlot`, slot
  size, captioned "Weapon", 2 gaps left of slot 1) shows the weapon in hand on its
  grade tile. It hides with the window, so the fighting HUD doesn't grow.
- Drag a weapon cell (or Bare Fists) onto the weapon slot or any hotbar slot:
  equip. Drag the weapon off the weapon slot: put it away. Touch fallback: choose
  the weapon, then tap the weapon slot (tapping it with the weapon in hand chosen
  puts it away) or any hotbar slot. With no weapon chosen, tapping the weapon slot
  shows the weapon in hand.
- Every route calls `WeaponAction` ("equip" / "unequip"); the server checks
  ownership and busy state as before. Arts and items drag as before (onto a slot,
  between slots, off the bar); choosing an art or item that isn't on the bar and
  tapping a hotbar slot places it there; otherwise tapping a slot shows it here.

## NEW badges (`Fresh.luau`)

Kept in the profile: `PlayerData.seen` (id -> os.time() first seen), sent in the
state snapshot. Anything the player holds that isn't in it is NEW. Hovering a cell,
choosing it, pressing it on touch, dragging it, or having it on the hotbar marks it
seen at once (client) and in a batch about a second later (`InventoryAction "seen"`,
server-validated: only ids the player holds). The server forgets ids the player no
longer holds, so finding one again is NEW again. Profile data rather than a client
setting because the profile already persists across sessions and devices, and a
client-only list would lose unseen drops on rejoin. Counts: each tab's crimson tag
and the Inventory tile's seal (`Buttons.InventoryButton.NewDot`) count NEW things
not on the hotbar. A v9 profile counts everything it owned as seen (migration 9).

## Sort, filter and search (`InventoryFilter.luau`)

- Sort button cycles **New** (NEW first, then most recently first seen), **Grade**
  (best tier first, arts by level next) and **Alphabetical**. Ties fall back to
  grade, then name. The weapon in hand stays first in its row.
- The rail's chip shows one section; All (or the chip again) shows all. Pouch chips
  are the kinds of item (their first item's icon).
- Sort and filter are saved per tab in the profile (`PlayerData.inventoryView`,
  `InventoryAction "view"`), the same persistence as NEW, so the window reopens as
  the player left it on any device. No saved choice: New and All.
- Search matches name, class or kind, grade label ("spirit", "rare", "sword");
  it clears when the window opens.

## Arts at a bottleneck

A chosen art shows its tier, level and XP bar (a `DaoList` row cloned from
`RowTemplate`). At a bottleneck (XP full at level 3, 6 or 9) the bar turns cinnabar
and reads "Bottleneck", the cell's "Lv" turns the same colour, two cost rows
(insight and Spirit Stones icons, "need · you have") show up, and the Secondary button
becomes Comprehend (jade). While it can't run it stays lacquer and dimmed and its
caption is the reason ("Meditate to comprehend", "Need insight", "Need stones"); a
tap toasts the longer reason. Comprehending belongs to the seated Practice row's
Technique tile; the button here still works while seated (`Bottleneck` holds the
shared logic). Success is the server's notify.

Technique icons are flat white glyphs tinted by the technique's colour; the class
weapon skills' are drawn in `art/ui/draw_techniques.py`. Twin Phoenix Cannon,
Dragon-Piercing Thrust and Great Sage Awakening read poorly at hotbar size; a Codex
request for a matching art-icon set is in codex-sheets.

## Known gaps

- Not playtested: drags, taps, NEW clearing, sort persistence and the touch layout
  were previewed only as static Studio layouts with sample data.
- On a phone the grid shows about one section row at a time (scrolls).
- `hud-compact` reskinned the hotbar slots; the weapon slot was cloned from this
  branch's `SlotTemplate` and gets its tile from code, so it fits either skin.
