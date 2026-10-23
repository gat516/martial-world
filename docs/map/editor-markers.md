# Map: editor-only markers and the POI tour
Planning aids (`_EditorMarkers`, `EditorOnly`), the `POI` tag, the POI tour (`T()`), hand-pass flags and the POI audit. Read it before tagging POIs, flagging a hand pass or auditing a dressing pass. Core rules: [map](../systems/map.md).

Decided 2026-10-21. Planning aids are for reviewing in Studio and never part of the game.
- **Where they go:** everything editor-only lives under `Workspace._EditorMarkers`
  (place-only Folder) or carries the CollectionService tag `EditorOnly`: gray blockouts
  (`_EditorMarkers._InnerBlockout`), floating POI labels (`_EditorMarkers.POILabels`),
  route strips, "later" markers. `src/server/EditorOnly.server.luau` destroys the folder
  and every `EditorOnly` instance as the server starts (and prints how many it removed),
  and `ReplicatedFirst.EditorOnly` (`src/first/EditorOnly.client.luau`) destroys any copy
  that reaches a client, now or later: a Studio playtest once showed the blockout labels
  with only the server script in place. Every part in them is Anchored, CanCollide/CanQuery/CanTouch off, so
  Edit-mode raycasts (spawns, treasures, audits) ignore them. Never leave a label, disc or
  blockout anywhere else; build nothing there at runtime.
- **POI tag:** every point of interest carries the tag `POI` with attributes `PoiName`,
  `Kind` and `Zone` (`Sect`, `Inner`, `Middle`, `Outer`), and optionally `LabelNote`
  (a route length, "(later)", a realm gate). Kinds: `Landmark` (a POI model), `BossRing`,
  `Lair` (a `Wilds.Zones` disc), `QiNode`, `Cache`, `WeaponRack`, `Array`, `EventGround`,
  `Find` (small finds between pockets), `Later` (flyer/climber spots stubbed for later).
  The tag sits on the POI's root Model or Part (`Map.Ground.Wilds<Zone>.POIs.*`,
  `Map.Markers.ManualCaches.Cache_*`, `Plaza.WeaponRack`, `Map.Markers.TeleportHome.*`, and in
  `assets/Wilds.rbxmx` on `Wilds.QiNodes.QiNode*` and `Wilds.Zones.*`). Every new POI a pass
  makes gets the tag in the same pass, so the tour and labels always cover everything.
- **Tour and labels** (`tools/poi_tour.luau`; its Studio copy is the ModuleScript
  `ServerStorage._EditorTools.PoiTour`, paste the file in again after editing it). In the
  command bar: `local T = require(game.ServerStorage._EditorTools.PoiTour)`, then `T()`
  prints every POI with a number, `T(12)` or `T("Wolf Den")` selects it and puts the camera
  where a player would stand looking at it, `T.labels()` rebuilds one floating label per POI
  ("#n Name", "Kind · Zone · note"), coloured by kind. Re-run `T.labels()` after adding or
  moving POIs.
- **Hand-pass flags** (decided 2026-10-21): builds that are hard for an AI to assemble
  (buildings, roofs, stairs, bridges, arches, walk-through or walk-under things, tight fits
  to terrain or rock, canopy near structures) get a second pass and then the tag
  `NeedsHandPass` with `HandPassReason` and `HandPassStatus` ("open"/"done") on their root
  model. `T.handpass()` lists them, `T.handpass(n)` frames one, and `T.labels()` gives each an
  orange "⚑" label (`_EditorMarkers.HandPassLabels`). Every pass report ends with the open
  list. Flagged so far: the Inner POIs ShrineTerrace, OldStoneGate, QiSpringShrine,
  HunterCamp, BambooHollow, FallenGiant, WolfDen, BorderBridge (and BorderBridge_Old), and
  the Borderlands' BorderGate, BrokenPagoda, FallenOutpost, DeserterCamp, AshenHollow,
  RuinedCourtyard, DrownedShrine, SerpentGrotto, Caravan.
- **Labels stay readable:** each kind has its own MaxDistance and size (finds 250 studs
  and small, caches and nodes 300, lairs 350, landmarks 500, boss rings 550, event grounds
  650), big things claim their spot first, and a label that would sit on another rises
  until clear.
- **Audit after a dressing pass:** a POI or cache must be visible and reachable from where
  players walk: open standing ground within 8 studs, a clear line to it through visual
  meshes (not only colliders), not inside a tent, rock or trunk, not buried or floating.
  The first audit (2026-10-21) fixed four caches, a qi node inside a bush and a tree, the
  Wolf Den's eight ring stones and 155 Middle dressing pieces placed hundreds of studs from
  their spots, and ten floating lanterns (see [wilds](wilds.md) "POI audit").
