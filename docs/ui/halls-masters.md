# Halls, masters and lineage

Ready-to-wire screens for player Halls and the master and disciple ties
([roadmap](../roadmap.md) 3b "Sect structure and contribution", [3d "Relationships"](../roadmap/relationships.md)).
None of these systems exist yet: each screen is a GUI template in `StarterGui.Sect`
(`assets/Sect.rbxmx`) plus a client module in `src/client/Sect/` with a `.preview()`.
Shared window anatomy, scaling and the sect board: [sect board](sect-board.md).

Previews, from the client console in play (`Client.Sect.<Module>`):
`HallCrest.preview()`, `HallPanel.preview()`, `Lineage.preview()`,
`Lineage.previewCeremony()`.

## Hall crest (`HallCrest`)
A crest is three layers from sheet C3: a **shield** (`shield_round`, `_kite`, `_banner`,
`_hexagon`, `_lotus`: gold outline, navy fill), an optional **border ring**
(`crest_ring_cloud`, `_dragon`, `_plain`) centred on the shield's hole at 98 % of it,
and an **emblem** (`emblem_sword`, `_peak`, `_lotus`, `_crane`, `_tortoise`, `_flame`) on
the ring's hole at 80 % (or on the shield's at 66 % without a ring). Holes are measured
in the PNGs (`Art.Hole`), so the kite's and banner's higher centres and the dragon
ring's raised hole are honoured.
- `HallCrest.compose(crest, { shield, ring?, emblem })` paints any `Crest` instance
  (template `Templates.Crest`: `Shield`, `Ring`, `Emblem`, all ScaleType Fit). The
  Hall panel, a Hall banner or a nameplate badge use the same call.
- `HallCrest.openBuilder({ name?, spec?, onConfirm = (spec) -> () })`: the builder
  window. Left: the live preview (160 px), the Hall's name, **Confirm**
  (`response_button_hi` with a checkmark). Right: three picker rows, Shield (5),
  Border (None + 3), Emblem (6), as 56 px option tiles (`tile_neutral`, the picked one
  `tile_gold`) with the piece at 64 %. A tap repaints the preview; Confirm returns the
  spec (`ring` nil for none) and closes.
- **The real system provides:** who may edit the crest (the Hall's founder or master),
  saving the spec on the Hall, and a name check. A Blood Sect Hall can later swap in
  the C6 `blood_` pieces.

## Hall panel (`HallPanel`, a stub)
`HallPanel.open({ name, crest, allegiance = "sect" | "blood" | "independent", cap,
goal = { text, progress, target }?, members = { { name, realm, role?, online? } } })`.
- Left column (centred): the crest (150 px), the Hall's name (Merriweather 18), and
  "Sect Hall · 14 / 30 members".
- Right: **Shared goal** heading with "340 / 500", the goal's text, and a bar (the
  `objective_banner` trough with a gold gradient fill in its navy band, x 1.54h to
  W - 1.56h, y 0.33h to 0.82h, eased on change); then **Members** with "3 here now" and
  a scrolling list (name in cream online, grey away; realm; role in gold).
- Read-only. Invite, furnish, the Hall's board and leaving come with the Hall system.

## Masters and lineage (`Lineage`)
### The lineage window
`Lineage.open({ master, seat, address, court, teachers })`:
```
master   = { epithet = "Turtle Saint", title = "Peak Lord of Black Tortoise Peak",
             teaches = "shield arts · earth", portrait = "elder_qingyun" | nil }
seat     = 1..9                      -- the player's seat in the court
address  = "Brother" | "Sister" | "Sibling"   -- the player's own choice (roadmap 3d)
court    = { name = "First Court", seats = { { name?, you? } x9 } }  -- nil name = empty
teachers = { { name = "The Crane Sage", since = "since Foundation 1" } }  -- up to two
```
- **Lineage card** (`lineage_card`, 480x148): the master's gray silhouette in the
  portrait window (measured hole 51,47 to 278,273 of 1024x316), "The Turtle Saint",
  their title and what they teach, and the **epithet plaque** (the gold house
  plaque, [ribbons](ribbons.md), 26 tall, fitted to the text, at most 244 wide) centred on
  the card's ribbon slot with the player's epithet in cream (Builder Sans Bold 13):
  "Second Brother of the Turtle Saint" (`Lineage.epithet(seat, address, epithet)`).
- **Also taught by** (right): the other masters (a second at FE1, a third at FE5),
  or "No other teachers yet", and "First Court · 7 / 9 seats".
- **The court's nine seats** in a fan, built in code from `seat_plate` (three-part,
  128x24, the C3 `nine_seat_fan` is only the arrangement reference): seat 1 at the
  top centre, then 2 left and 3 right a row down, and so on outward (row 1's centres
  ±68 px for an 8 px gap, each later row 40 px further out, rows 26 px apart). Each
  plate holds its number (gold) and the holder's name (the player's in jade, empty
  seats "—").

### The ceremony (`Lineage.ceremony`)
`Lineage.ceremony({ master, disciple = { name, portrait? }, seat, address, onBow,
onDecline? })`: the `ceremony_frame` card (640x295, red and gold) with the master's
silhouette in the left medallion and the disciple's in the right (round CanvasGroups
centred on the measured holes, so the silhouettes' square shoulders are clipped to the
circle), their names and roles under them, and in the middle "Master and Disciple",
"Lin Yue bows to the Turtle Saint / and takes the second seat.", the epithet plaque
(28 tall, at most 300 wide; it settles 8 px down a beat after the card opens) and **Bow** (`response_button_hi` with the
bow glyph). Bow calls `onBow` and closes; the close seal declines (`onDecline`). The
cinematic beat around it (camera, tea or bow animation) is `vfx`'s; the card is the
moment's UI.

**The real system provides:** NPC master defs (epithet, title, specialty, portrait
key), the player's primary master, seat and chosen address, the court roster, other
teachers, the ceremony trigger for player masters (opt-in on both sides), and the
remotes behind Bow.

### "Disciple of X" on the Self card and nameplate
Not built here (another branch owns `SelfCard` and `Nameplates`); this is the contract
for them:
- **Nameplate title** (the gold italic line above the name band, already reserved): the
  primary master's tie, in this order of preference:
  1. a held seat: `Lineage.epithet(seat, address, epithet)`, "Second Brother of the
     Turtle Saint";
  2. a player master without seats: "Disciple of <master's name>";
  3. a player who is a master: "Master of <n> disciples" or their master title.
  A sect rank or Hall title (when those come) shares the same line; the player picks
  which one shows. One line, no new rows.
- **Self card:** one row of the existing shape (kind label in small gold capitals,
  then the thing, then the detail), kind **LINEAGE**: "Second Brother of the Turtle
  Saint", detail "First Court · also taught by the Crane Sage". Tapping it opens the
  lineage window. A master's own card shows "Master of Lin Yue, Bai Feng" instead. Hall
  membership is a separate **HALL** row with the crest (`HallCrest.compose` at row
  size) and the Hall's name.
- Inherited bloodlines show the B4 `bloodline_inherited` badge with "from the Turtle
  Saint" (the descendant's mark, roadmap 3d), on the bloodline row, not the lineage row.

## Checked (2026-10-23, numbers at phone scale 1.0, 844x390)
Windows centred on the screen (0 px), titles 0 px, labels 0.5 px, content padding
28/28. Crest builder: left column contents (preview, name, Confirm) centred on the
column (0 px) with 22/22 px above and below; picker block 14/14 px; option pieces on
their tiles (0 px). Hall panel left column 0 px across, 42/42 px vertically. Lineage
portrait and ribbon on their measured holes (0 px); the fan's seat 1 0 px off centre,
each mirrored pair 0 px asymmetric, row 1 gap 8 px; seat names 0.1 px off the plate
bodies' centres. Ceremony medallions on their holes (0 px), names centred under them
(0.1 px), the middle column on the card's centre (0 px).

**No Figma mock:** the kit's Starter plan was out of calls when these were built
(2026-10-23); composed directly in Studio from the cuts and reviewed by screenshot.
