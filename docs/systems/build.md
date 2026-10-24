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
  the peak itself grows a tier per major (look, room, item caps; below), and the
  pieces on it add up to a peak score that boosts meditation and garden growth.
  The score is the "your abode boosts your cultivation" lever for the mid-QR
  slowdown (roadmap §1).

## Key files
- `src/shared/BuildItems.luau`: every item (cost, category, placement rules,
  limits, `realm` unlock, `meditation`/`garden` benefits); `unlocked`.
- `src/shared/Placement.luau`: the shared placement check (bounds, support,
  overlap via a spatial hash, reserved zones, restricted geometry).
- `src/shared/Peak.luau`: peak-local frame helpers, `pieceOf`, tiers (`tierAt`,
  `tierById`, `limit`, `radius`) and `itemScore`.
- `src/server/Build.luau`: buy/place/store/move, support chains (storing a piece
  stores what rests on it), starter pieces.
- `src/server/Peaks.luau`: peak assignment, layout apply/undo, the owner sign and
  peak tier (`applyRealm`), the peak score (`refreshScore`, `meditationBonus`,
  `growthBonus`).
- Client: `BuildMode.luau` (placing, moving, storing, input per device),
  `BuildCatalog.luau` (catalog / Spirit Market shop; kit look in
  [herbarium](../ui/herbarium.md#the-garden-and-build-windows-kit-restyle-2026-10-23)), `MyPeak.luau`,
  `MarketRange.luau` (closes the market windows once you walk out of
  `MARKET_RANGE` of the stall).
- Models: `ReplicatedStorage.BuildKit`, `ServerStorage.PeakTiers`.

## Peak tiers (backend built; looks wait for the building pass)
`Config.Build.TIERS`: the owner's realm picks the last row whose `from` stage
they've reached (`Peak.tierAt`). A row for a third of a realm (say `from = "QR4"`)
slots in without code changes.

| Tier | From | Template | Radius | Max items | Herb Beds | Score cap |
|---|---|---|---|---|---|---|
| `QiCondensation` | QC1 | `QiCondensation` (not built: bare peak) | 47 | 120 | 16 | 60 |
| `QiRefining` | QR1 | `QiRefining` (not built: bare peak) | 56 | 160 | 20 | 150 |
| `Foundation` | FE1 | `Foundation` (lanterns, shrine, sky beam) | 66 | 200 | 24 | 250 |

- **Look:** `Peaks.applyRealm` (join and every breakthrough) clones the tier's
  template as the peak child `RealmTier` (attribute `Tier` = template name) and
  swaps it when the tier changes. A missing template falls back to the nearest
  earlier tier's, else none, so the real map and the testbed run with any subset.
- **Room:** the peak attribute `BuildRadius` (read by `Peak.radius`, used by
  `Placement`, `Build` move checks, the build-mode ring and wild herb spots). On
  the real map it is the tier's radius only when the shown template has a `Ground`
  child (new terraces to build on), else the base `RADIUS` 47, so the area never
  grows past the rock before the look exists. The testbed's flat arena always gets
  the tier radius.
- **Caps:** `maxItems` replaces the old flat 120; `limits` overrides an item's
  BuildItems `limit` (Herb Beds are the garden plot unlock). Server `Build.place`
  and the catalog both read them (`Peak.limit`; the client knows its tier from
  the `PeakTier` player attribute).
- Lowering a tier (admin realm set) keeps pieces already outside the smaller area;
  they just can't be moved back out there.

### Template contract (for the building pass)
- **Where:** `ServerStorage.PeakTiers.<template>`, a Model per tier named as in
  `TIERS.template` (`QiCondensation`, `QiRefining`, `Foundation`), exported to
  `assets/PeakTiers.rbxmx` (mapped in both projects). `OwnerSign` (the stele
  billboard) lives in the same folder; no tier may use that name. Library meshes
  Rojo can't sync go in `ServerStorage.PeakTierModels.<template>` (place-only; a
  stub folder in the testbed); their children are merged into the tier on apply.
- **Space:** author every part in **peak-local coordinates**: origin at the
  Plateau's centre, Y up, -Z (look) pointing outward from the map centre (the
  `Peak.frame` convention, the same frame saved layouts use). On apply each
  BasePart's CFrame is mapped with `frame:ToWorldSpace(part.CFrame)`, so rotations
  are kept exactly; the model is never `PivotTo`'d, so its `PrimaryPart` and
  `WorldPivot` don't matter (leave `PrimaryPart` nil). Stand cylinders up inside
  the model (AGENTS.md "Placing a cloned template"). Build it on a copy of a peak
  at the world origin with identity rotation and the parts' world CFrames are
  already peak-local.
- **Ground:** walkable terraces that extend the build area go in a child named
  `Ground` (Model or Folder). Its parts count as natural ground for `terrain`-only
  items, and its presence unlocks the tier's `radius`. Keep them within that
  radius and clear of the reserved zones (teleport array, bridge gate, abode
  entrance) and the stele. Anything else that collides blocks placement ("something
  in the way").
- **Content:** geometry, lights and effects only; no scripts, no `ItemId`,
  `StarterId` or `HerbPlot` (tier pieces aren't storable or scored). Each tier
  is a whole look (it replaces the lower tier's, not stacks on it), so carry over
  what should stay.
- **Radius per tier:** 47 / 56 / 66 (tune in `TIERS`); a bigger template needs
  its radius raised in the same commit.

## Peak score (built, untuned)
- Every build piece standing on your peak (placed copies and starter pieces still
  out) scores points: BuildItems `score`, else `Pacing.PeakScore.BY_CATEGORY`
  (Structures 6, Cultivation 5, Garden 3, Furniture 2, Lighting 2, Decor 1,
  Nature 1) plus `GATED` by the item's realm gate (QC +2, QR +4, FE +6). Only the
  first `PER_ITEM` (5) copies of an item count, so spamming buckets doesn't pay.
- The score counts up to the tier's `scoreCap` (60 / 150 / 250) and adds
  `MEDITATION` (0.004) per point to the meditation multiplier on your peak and
  `GROWTH` (0.002) per point to your plants' growth speed: at the QR cap +0.6 on
  `ON_PEAK` 2.5 and +30% growth; at the FE cap +1.0 and +50%.
- `Peaks.refreshScore` recounts after every successful build action and on
  `applyRealm`, and sets the `PeakScore`, `PeakScoreCap` and `PeakTier` player
  attributes; the catalog's peak-score gauge shows them. It also keeps the highest
  uncapped score in `data.stats.peakBest`, and each place counts in `data.stats.placed`,
  for the heart-demon trial's builder or wanderer question ([heart-demon](heart-demon.md)).

## Themed sets (UI ready, content pending)
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
  (phones), where it cut the tab list to two and a half tabs. The score is above.

## Data flow
`BuildAction("buy" | "place" | "store" | "move", args)` with a peak-local pivot,
yaw and mode -> `Placement.check` on the server -> `data.decor` counts and
`data.peak.placed` records -> pieces built on the peak. Peaks applies the saved
layout on join and undoes it on leave.

## Tuning knobs
- `Config.Build`: base radius and height limits, `TIERS` (per-tier look, radius,
  max items, item limits, score cap), `TIER_GROUND`, `PRECISION` presets,
  rate limit, `GROUND`, `RESERVED` zones, restricted names, Spirit Market range.
- Per item in `BuildItems.luau` (`score` overrides its peak-score points).
- `Pacing.PeakScore`: points per category and realm gate, copies that count,
  meditation and growth per point.

## Known gaps
- Only the Foundation tier has a look; QC and QR show the bare peak until the
  building pass makes `QiCondensation` and `QiRefining`. No template has `Ground`
  yet, so on the real map every tier builds within the base 47 studs.
- Tier change is shown only by the look and the catalog numbers; no
  "your peak grew" moment yet.
- No set pieces yet (the catalog is ready, above). Score numbers are untuned.
