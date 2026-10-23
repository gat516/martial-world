# Map build checks

Each of these lessons cost a map pass real time. Check them before calling an
area done. Placement mechanics are in the `mesh-pipeline` skill, and tags and
markers in [editor-markers](editor-markers.md).

## Placing

- **Library pivots lie.** Some AssetLibrary models keep their WorldPivot far from
  the mesh: "Single Stone" in the Stone Rock Pack is about 485 studs off, Wide_L
  trees 54, pines 36-38, cliff masses 33. `PivotTo(spot)` then drops the mesh
  somewhere else; the Wolf Den's ring stones ended up 1,000 studs away.
  - Pivot every kit clone at its bounding box's bottom centre, keeping its
    rotation (`dress_wilds.luau` `add` does this).
  - After a placement run, scan for single-part models whose part is more than
    40 studs from the pivot.
- **Root everything, not just the centre.** Seat objects from several rays under
  their base, sink them a little, and tilt flat ones to the slope. Keep buildings
  level and fill the ground under them.
- **"Floating" checks need care.**
  - A ray cast from inside terrain hits nothing, so a sunk part reads as
    floating. Only flag gaps where the ray actually hit something below.
  - Some lanterns only looked like they floated: they stood on non-colliding
    meshes (pavilion floors, crates) that CanQuery-off raycasts ignore. Check
    for any part under the footprint before you lower a prop.
- **Event and treasure spots skip water.** Raycasts hit terrain water by default
  (the serpent marsh lair was 37% water). Spot pickers check
  `hit.Material ~= Water` and retry.
- **Prefabs that dig their own water sink on a re-run** if you seat them on the
  lowest ground under their middle, because the carve lowers it. Sample the
  footprint's rim instead.

## POIs

- **Every POI must be visible and reachable. This check is required.** Caches
  have ended up inside boulder piles, tree trunks, behind crates and once inside
  a tent.
  - Test each POI and cache from 24 approach spots: 12 bearings, at 5 and 8
    studs.
  - Each spot needs ground, a free 2x4.6x2 standing box and a clear ray from eye
    height (ground + 4.5) to the target.
  - Count colliders (prompt line of sight) and visual meshes separately: set
    CanQuery on nearby parts for the visual ray, then restore it.
  - Fewer than about 12 clear spots means moving the POI or the dressing.
  - Then capture it from a clear spot. A camera placed blindly lands inside a
    trunk.
- **Judge every POI against a player and its world.**
  - Prefab finds came out too small for 80-120 stud walls. Scale until it reads
    from the path: doors and steps a 5-stud player fits, steles taller than a
    person.
  - Ask why it is there: a fisherman's boat stood in a forest. Move or swap
    anything whose story doesn't fit its spot.
- **Tags go on parts.** Put gameplay tags and attributes on parts (caches,
  prompts, sound and FX anchors, a `POIAnchor`), never only on a Model.
  Ungrouping drops the Model's tags and attributes.

## Clearance

- **Clearance before you call a pocket done.** No wall rock, karst collider, tree
  or dressing may overlap any of these:
  - a pocket's footprint or a pool
  - a fall's drop line, seen from the valley
  - a path's walking width
  - a POI's view from its path

  A giant overhung the Twin-Jade pool and swallowed its fall. Check every
  pocket, pool, fall, path and event ground after any wall or pocket change, and
  fix or flag every hit.
- **Keep bamboo and trees out of water and fall drops.** A clump at a fall's foot
  or on a pool's rim hides both.
- **Karst trunk colliders are wider than the meshes** (r up to 96 round
  SouthEastFar). Keep pools, paths and pockets outside them, or players hit an
  invisible wall.

## Walls and ground

- **Walls are a few giant library rocks, not piles.**
  - "Stylized Cliff Terrain Rock" scaled to 80-120 studs is one cliff face, and
    medium ones cover seams and feet. Fewer pieces means fewer seams and
    triangles, and the moss holds up at scale.
  - Keep each a separate named model in `Map.Ground.WildsInner.Walls` (the user
    moves and scales them), never merged or welded.
  - No script or raycast depends on wall geometry. Spawns, discs and nodes stay
    40+ studs off wall feet.
  - Check for gaps with rays from the valley side at several heights.
- **Library rocks with a SurfaceAppearance ignore part Color.** Tint them with
  `SurfaceAppearance.Color`: the Cliff Terrain Rocks need about `#706858` to sit
  with the house warm greys. Check the tint in haze, day and dusk, from the
  valley floor.
- **Library rock families don't mix.** Cliff Rock Pack I and the Fantasy rocks
  read brown and plain beside the moss-capped Cliff Terrain Rocks. Capture a
  test before using them.
- **New ground gets a base terrain pass before anyone looks at it.** Walls on
  bare Ground or Slate, old pools or fissures read as an unfinished game. Lay
  grass up to the wall feet and raise it into them (`terrain_valley_base.luau`).

## Working with the user's edits and Studio

- **The user's Studio edits are the source of truth.** They ungroup and move
  things by hand.
  - Never assume a prefab's model structure in a later pass. Rescan the area by
    tags (`POI`, `POIAnchor`, `ManualCache`, `AmbientSound`, `NeedsHandPass`)
    and positions.
  - Never move something they moved back to its planned spot.
- **Aerial captures don't work over the wilds.** The cloud plane (Y 440) and the
  haze white out any camera above about Y 300, and the dense canopy hides views
  at eye height. Check sightlines with the blockout from eye height on the spine,
  and verify the numbers by raycast.
- **Name collisions in hand-edited XML.** When editing `.rbxmx` text, a pattern
  like a CFrame can match two instances (a zone disc and an event ground at the
  same spot). Anchor each edit to the item's Name block.
- **Big MCP calls time out.** Walk big folders (all of AssetLibrary) in chunks
  and yield with `task.wait()`.
- **After updating `_EditorTools.PoiTour.Source`**, load it with `loadstring`:
  `require` caches the old module in Edit.
