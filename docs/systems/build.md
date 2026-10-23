# Build mode and spirit peaks

## Purpose
Every player gets a spirit peak for the session and can decorate it: buy build
items with Spirit Stones and place, move or store them. Some items have gameplay
benefits (meditation seats, garden plots, garden boosters).

## Design intent
- Your peak is home: it follows you across servers (the layout is saved in a
  peak-local frame, so it loads the same on any peak).
- Placement that feels good on every device: a ghost that's green or red with
  the reason, grid / free / attachment-point snapping, precision presets.
- The server is the authority on every placement.
- Realm gates on some items (`realm` field) give progression a cosmetic payoff;
  reaching Foundation also swaps the peak's realm tier (`ServerStorage.PeakTiers`).

## Key files
- `src/shared/BuildItems.luau`: every item (cost, category, placement rules,
  limits, `realm` unlock, `meditation`/`garden` benefits); `unlocked`.
- `src/shared/Placement.luau`: the shared placement check (bounds, support,
  overlap via a spatial hash, reserved zones, restricted geometry).
- `src/shared/Peak.luau`: peak-local frame helpers, `pieceOf`.
- `src/server/Build.luau`: buy/place/store/move, support chains (storing a piece
  stores what rests on it), starter pieces.
- `src/server/Peaks.luau`: peak assignment, layout apply/undo, the owner sign and
  realm tier (`applyRealm`).
- Client: `BuildMode.luau` (placing, moving, storing, input per device),
  `BuildCatalog.luau` (catalog / Spirit Market shop; kit look in
  [herbarium](../ui/herbarium.md#the-garden-and-build-windows-kit-restyle-2026-10-23)), `MyPeak.luau`,
  `MarketRange.luau` (closes the market windows once you walk out of
  `MARKET_RANGE` of the stall).
- Models: `ReplicatedStorage.BuildKit`, `ServerStorage.PeakTiers`.

## Themed sets and the peak score (UI ready, content pending)
- `BuildItems.Sets` lists the roadmap's six sets (Mortal Courtyard, Jade Pavilion,
  Cloud Palace, Herb House, Library and Training, Formations). An item joins one with
  `set = "<id>"`. The catalog adds a set tab (its C2 medallion on a catalog tab, under
  a "Sets" heading) for every set that has at least one item, and the detail panel
  shows "<set> set" and the medallion. No item has a set yet, so nothing shows.
- Window placement (`BuildCatalog.open`): the Spirit Market sits centred, 34 px
  clear of the screen's top and bottom (`BuildBar` Size 0.96 x (1, -68), max
  1000x520), so its title plaque, which rides 25 px above the window, stays on
  screen; in build mode the window sits 8 px off the bottom with 90 px kept above it
  (`BUILD_TOP`), so the plaque clears the build banner (it used to cover the
  banner's tabs on phones). On a narrow screen the banner drops its "Build mode ·
  <peak>" tag when the full banner would reach Roblox's top-left buttons
  (`BuildMode.refreshBanner`, `Platform.topbar`). Catalog tiles have 4 px above the
  first row so the 5% hover swell isn't cropped.
- Art (2026-10-23, "inventory / shop buttons are still clipping on pc"): the category
  tabs, set tabs, the Owned toggle and the Herbalist's Buy/Sell tabs are three-part
  plates (`Art` + `Selected` frames of `CapL`/`Mid`/`CapR`), not one 9-sliced image,
  which Roblox cropped flat at the cloud caps. Then "i don't like how small the
  inventory buttons are / how it gets covered by the ornaments": the caps are the house
  plaque's ([ribbons](../ui/ribbons.md)): `ruby` idle, `gold` chosen (and the label
  turns gold, `BuildCatalog.setSelected`, `HerbShop.refresh`), pointed ends with a
  stud, 26 px wide at 40 px tall instead of cloud caps taking half the tab. The tab
  column is 152 px (catalog from x 158), every tab 140x40 (set tabs 44), the label box
  exactly the plain middle (84 px; TextScaled 11-15): the widest label, "Cultivation"
  (65 px at 15), has 11.7 px each side; centred to 0.00 px; 2.5 px clear of the column
  on hover. A set tab's medallion (32 px) sits on the plate's left end, its name
  beside it on the middle, two lines at 10-13. Tiles per row: 5 at 1920x1080 and
  1366x768, 3 at 844x390 (was 4), 2 at 667x375. The tile badge is the jade tag in three
  parts (`ornament_tag_jade_*_h40`). Tiles and the detail well are `item_slot_h184`
  9-sliced at its one middle row and column (Rect(92,91,93,92); SliceScale 0.45 on
  tiles, 0.85 on the well) so only plain bar stretches; the owned count (`xN`) moved
  from the top-right, where the badge ran into it, to the preview's bottom-right.
  Every other image is a display-sized copy ([ui](ui.md), "Display-sized copies").
- The peak-score gauge (C2 `peak_meter`, under the category tabs) shows the player
  attributes `PeakScore` and `PeakScoreCap` (the fill is score/cap) and stays hidden
  until the server sets `PeakScore`, and on windows whose body is under 300 px tall
  (phones), where it cut the tab list to two and a half tabs. The score itself (more items count, adding to
  meditation and garden up to a cap) is roadmap §6 and not built.

## Data flow
`BuildAction("buy" | "place" | "store" | "move", args)` with a peak-local pivot,
yaw and mode -> `Placement.check` on the server -> `data.decor` counts and
`data.peak.placed` records -> pieces built on the peak. Peaks applies the saved
layout on join and undoes it on leave.

## Tuning knobs
- `Config.Build`: radius and height limits, `MAX_ITEMS`, `PRECISION` presets,
  rate limit, `GROUND`, `RESERVED` zones, restricted names, Spirit Market range.
- Per item in `BuildItems.luau`.

## Known gaps
- Peak tiers exist only for Foundation (`TIER_BY_MAJOR`).
- No set pieces and no peak score yet (the catalog is ready for both, above).
