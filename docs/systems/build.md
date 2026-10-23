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
- The peak-score gauge (C2 `peak_meter`, under the category tabs) shows the player
  attributes `PeakScore` and `PeakScoreCap` (the fill is score/cap) and stays hidden
  until the server sets `PeakScore`. The score itself (more items count, adding to
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
