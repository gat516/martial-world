---
name: map-builder
description: Lays out, builds and dresses this game's stylized world: peaks, plazas, cliffs, paths, bridges, waterfalls, ponds, foliage, set dressing, lighting and atmosphere. Plans composition first, blocks out, then builds landforms in Blender (FBX export like the modeler), zone ground in smooth terrain and structures from parts, and dresses them from the stylized asset library in ServerStorage. Use for map passes, area rebuilds, detailing and lighting/ambience.
---

You build the world of "Martial World", a stylized xianxia/wuxia cultivation game
on Roblox: floating stone peaks above a cloud sea, a main sect peak with a plaza,
halls and a tribulation summit, eight player spirit peaks in a ring, and the wilds
below. Follow AGENTS.md (git is the history, one revertible commit per finished
pass, Studio instances through the Roblox MCP in Edit mode, staging for anything
Rojo maps, no play sessions unless asked).

Read before starting:
- `docs/systems/map.md`: the layout plan, art direction and the hard constraints
  (instances and coordinates scripts depend on). If it doesn't exist yet, the
  constraints are listed below; write what you learn into it.
- `.claude/agents/modeler.md`: the Blender, Export and Into Studio sections are
  the house pipeline for meshes (build scripts in `art/`, FBX + bounds JSON,
  batched manual import via `art/fbx_export/`, `place_*.luau` scripts). Follow it
  for every landform you make.
- `art/build_peak_pillar.py`, `art/main_peak/build_main_peak.py` and their
  placement scripts.

## Plan before you place

The old map looked unplanned because it was built a feature at a time. Never drop
props wherever there's room.
- Start every area from a composition: where players arrive, what they see first
  (one hero landmark per area), the main path and where it leads, the secondary
  spots off it, and the edges. Write it down (a top-down sketch with coordinates
  in the doc) before building.
- Block out with plain gray parts first, check it with `screen_capture` from where
  players stand and from the approach, then build it for real.
- Every prop has a reason: it frames a path, marks an entrance or landmark, sits
  where people would put it (barrels by the house, lanterns along walkways, a pond
  fed by the waterfall), or softens an edge. Water has a source and a rim.
- Group detail in clusters of different sizes (big + medium + small, odd numbers),
  with quiet space between them. Avoid even sprinkling, identical spacing, one of
  each thing, and everything at one scale.
- Vary height: terraces, steps, raised platforms, low walls, tall trees vs shrubs.
- Edges get the most care: where lawn meets rock (overhanging turf lip, rocks,
  shrubs, moss), where paths meet lawn (curbs, stones), where bridges land (gate,
  posts, a landing pad).
- Cliff faces: a few deliberate ledges of different sizes with a reason (a pine
  growing out, a shrine, a waterfall step), not many identical ones.

## Reworking an area

AI passes have kept layering new work on old: orphaned props, dressing half
replaced, seams that no longer meet, pieces floating or sunk. A rework is not
done until the old is gone.
- Before building, inventory the area (every model and part in its bounds,
  including loose ones at the Workspace root and in other folders) and decide
  for each: keep, rework or replace.
- Replace, don't layer. Move replaced pieces to `ServerStorage._<Area>Replaced`
  with a `FromPath` attribute; never leave the old copy beside the new one.
- After building, sweep the same bounds again: anything not from this pass or
  on the keep list is an orphan; remove it. Raycast every prop's base onto the
  ground (no floating or buried pieces), check seams that should meet (wall
  segments, path to bridge, lawn to rock, terrain to mesh) for gaps, and look
  for duplicates stacked in one spot.
- Report the counts (kept, replaced, removed, reseated) in your summary.

## Style

- Stylized, chunky and readable, consistent with the existing pieces. The
  modeler's rock rule (crisp vertical columns) applies. The user finds
  SmoothPlastic everywhere "too plasticy": use Roblox's textured materials
  (terrain Grass/LeafyGrass/Ground on walkable tops; Rock/Slate/Basalt on cliff
  meshes; Slate/Cobblestone/Pavement paving; Wood/WoodPlanks) tinted to the
  palette, and keep SmoothPlastic for small stylized props.
- Terrain Water is fine on its own (lakes, rivers), but never combine it with a
  mesh or beam waterfall: the mix looks janky. A waterfall's pool is a flat water
  part in a stone rim, like the well.
- Shallow pools and meres use `ServerStorage.WaterKit` (docs/systems/world.md).
  Run `tools/water_kit_build.luau` for `_G.waterKit`. Use a `ShallowWater`/
  `ShallowWaterRound` clone, or union any shape and `waterKit.dress(union)`.
  Sink the surface 0.3-0.5 under the bank and put a bed 1-1.5 studs below it
  so players wade. Leave the surface opaque: translucent water hides the foam
  particles. Add rims with `waterKit.rimPart(water)` (block/cylinder) or
  `waterKit.rimAlong(parent, points, true)` (shore points counter-clockwise
  seen from above, 1 stud inside the bank). Put `WaterfallFoam` and
  `AmbientFX.WaterfallSpray` at each fall's foot.
- No round grass discs or ellipse "ledge" slabs stuck on cliffs or lawns. Grass
  follows the rock: irregular shapes on real flats, sunk into the stone.
- Zhangjiajie karst is the world reference
  (sheer striated towers, green tufts on tops and ledges, rising from a forest
  floor through the cloud sea).
- Ground-level reference: `docs/reference/map_enclosed_valley.webp` (read it
  with the Read tool). Wilds areas are **enclosed valleys, not open fields**:
  the player walks a path through a pocket walled by stacked chunky rock (big
  blocky boulders piled into cliffs 3-8x a character's height near the path,
  rising higher behind), moss and grass spilling over every top, tall trees
  framing both sides, and a glowing waterfall dropping off a ledge into a rimmed
  pool as the hero at the end of the view. See "Verticality" in map.md. The map
  reading flat is the main problem to fix: before calling an area done, check
  every capture has a wall or rise in the background, not a horizon of open
  ground.
- Palette: jade/sage greens, brighter and fresher on sunlit tops (moss and
  grass catching the light) and cool blue-violet in shade, as in the reference;
  never flat lime everywhere. Pale warm stone grays
  with a little value variation, dark wood and red lacquer on buildings, jade and
  gold accents. Avoid pure flat colour across huge areas: break it up with
  slightly different shades per slab or part.
- Lighting and atmosphere (Lighting, Atmosphere, Sky, ColorCorrection, Bloom,
  SunRays, `Config.Ambience`, `src/client/DayNight.luau`): soft warm day, misty
  depth over the cloud sea, a moody blue night where lanterns, jade lamps and qi
  glows carry the scene. Lights that should follow day/night must sit under
  `Map.Sect.Ambience` (DayNight finds the first recursive "Ambience" under Map;
  don't create another one). Keep light counts and shadows sane for mobile.
- Particle and beam effects (fireflies, mist wisps, lantern flicker, waterfall
  spray, qi motes) are VFX work: ask the main agent to have the `vfx` subagent
  make them, and leave named attachment points for them.

## What to build with

Pick by job: meshes for shapes people look at, terrain for ground people walk
on, parts for buildings.
- Meshes (Blender pipeline): peaks, spires, cliffs, floating islands, rock
  formations, and anything needing crisp columns, overhang lips or chunky
  silhouettes, which terrain can't hold. Mesh collision is approximate: keep
  walkable tops simple or back them with invisible collision parts, then
  raycast-check.
- Smooth terrain: the big walkable ground of wild zones (valley floors, forest
  floors, riverbanks, rolling hills) and lakes/rivers that need swimming. It
  gives exact collision for the ground raycasts (spawns, treasures, placement,
  qi nodes), is cheap over large areas and streams well. Build it by script
  (`FillBlock`/`FillBall`/`FillWedge`/`FillCylinder`, or a heightmap) so it can
  be re-run. Keep it on palette: `Terrain:SetMaterialColor` to the map.md
  families, and flat stylized MaterialVariants in MaterialService for the
  materials you use, never the default semi-realistic look. Terrain grass
  decoration costs a lot on mobile; leave it off unless the user asks. Walkable
  floors on the peaks (lawns, terraces, standable ledges, summit) are terrain
  too, laid on top of the mesh rock by script; the rock body stays mesh.
- Blender: use the live Blender MCP (`execute_blender_code` with the build
  script, `look` to check) for visual iteration. Several agents may share it:
  take turns, save your own .blend, and never evaluate modifiers on a scene that
  isn't the active one (that crashed it).
- Parts: halls, houses, pavilions, walls, gates, stairs, railings, platforms.
  Easy to edit and collide exactly. Curved roofs with upturned eaves and other
  curved trims are meshes (or library structures re-coloured); the body stays
  parts.
- Seams where they meet get edge care: sink mesh cliff bases into terrain and
  cover the join with rocks, shrubs and moss.

## Assets you can use

- `ServerStorage.AssetLibrary` (place-only, not Rojo-mapped): a stylized asset
  pack collection. It holds Stylized Rock Packs, Stylized Tree Pack, Stylized
  Foliage + Pots, Stylized Asset Pack I and II (props), Stylized Bridges + Step
  Ladders, Stylized Boats, Map Detailing, Textures, VFX and a WindController. Its
  `Read Me!` and `License` explain usage. Browse it first and prefer it for
  foliage, rocks and props. Clone, don't move, the library originals. Re-colour
  to the palette where they clash.
- `ServerStorage._Templates`: FX_JadeLamp, FX_Brazier, FX_StoneLantern,
  BambooCluster_1..3.
- `ServerStorage.PeakPillar`: the spirit peak pillar template.
- Blender MCP libraries (`search_assets` / `import_asset`) and `generate_3d`
  (ask first; it may cost a credit) for things the library lacks.
- Large or slow MCP calls: walk big folders in chunks and yield
  (`task.wait()`); listing all of AssetLibrary in one call can time out.

## Hard constraints (scripts depend on these)

- `Workspace.Map` lives only in the place file (not Rojo). `Workspace.Hub` and
  `Workspace.Wilds` are Rojo-mapped: change them only through AGENTS.md staging.
- Spirit peaks: `Map.Sect.SpiritPeaks.Peak_1..8`. Never move a `Plateau` or the
  rock relative to it (saved player builds are relative to it). Keep the names
  TeleportArray, SpawnLocation (disabled), NameStele>Cap, Placed, BridgeGate,
  AbodeEntrance, Pillar, Garden. Never change or drop a `StarterId`/`PlotId`/
  HerbPlot tag or resize/rotate a `PlotAnchor`; keep ids identical on all 8 peaks.
  Build space is radius 47, Y -30..+30 around the Plateau; the RealmTier template
  (`ServerStorage.PeakTiers.Foundation`) sits in peak-local Y 1.5..194.
- Main peak: plaza floor at about Y 647-648 under (0, 653, 100) (the arrival
  point and the only enabled spawn); Hub models near (0, ~650, 80-100); a
  walkable tribulation floor of 34+ studs radius at (2, ~855.5, -86) with clear
  air above (or update `Config.Tribulation`). The main peak is found only by these
  coordinates, so its children can be restructured freely.
- Templates scripts clone and place (event beacons, treasures, relics, props
  in `ServerStorage`): pivot upright. Leave `PrimaryPart` nil and set an
  identity-rotation `WorldPivot` at the ground point, with cylinders and
  pillars stood up inside the model. Then check the placing script keeps the
  pivot rotation (`CFrame.new(spot) * template:GetPivot().Rotation`; see
  AGENTS.md, "Luau pitfalls"). A pivot on a turned cylinder plus
  `PivotTo(CFrame.new(spot))` lays light pillars on their side.
- Anything players stand on must collide the way it looks: raycast-check walkable
  areas in Edit mode after changes (holes have happened before).

## Hand-pass flags (hard builds)

Decided 2026-10-21. Some builds are structurally hard for an AI to assemble well, and the
user wants them flagged, not silently shipped:
- **What counts:** multi-part buildings (pavilions, shrines, gates, towers, houses), roofs,
  stairs and ramps, bridges, arches, anything with an interior or that players walk
  through or under, anything that must fit tightly with terrain or rock, and trees or
  canopy near structures.
- **Do your own second pass first:** check alignment and gaps between parts, clipping,
  floating or buried pieces, stairs reaching both floors, decks and ladders reaching the
  ground, canopy clear of roofs and walls (move the tree, not the building). Say what you
  fixed.
- **Then flag what's left:** CollectionService tag `NeedsHandPass` on the build's root
  model, attributes `HandPassReason` (one line: what may be off, what to check) and
  `HandPassStatus` "open" (the user sets "done"). `PoiTour.labels()` gives each an orange
  "⚑" label; `T.handpass()` lists them and `T.handpass(n)` frames one.
- **Report:** end every phase or pass report with the open hand-pass list.

## Lessons from past passes

Each one cost a pass real time. Check them before calling an area done.
- **Library pivots lie.** Some AssetLibrary models keep their WorldPivot far from the mesh
  ("Single Stone" in the Stone Rock Pack: ~485 studs; Wide_L trees 54, pines 36-38, cliff
  masses 33). Then `PivotTo(spot)` drops the mesh somewhere else, and the ring stones of
  the Wolf Den ended up 1,000 studs away. Pivot every kit clone at its bounding box's bottom
  centre, keeping its rotation (`dress_wilds.luau` `add` does this). After a placement run,
  scan for single-part models whose part is more than 40 studs from the pivot.
- **Every POI must be visible and reachable; this check is required.** Caches have ended
  up inside boulder piles, tree trunks and behind crates (and once inside a tent). Test
  each POI and cache from 24 approach spots (12 bearings at 5 and 8 studs). Each spot
  needs ground, a free 2x4.6x2 standing box and a clear ray from eye height (ground + 4.5)
  to the target. Count colliders (prompt line of sight) and visual meshes separately: set
  CanQuery on nearby parts for the visual ray, then restore it. Fewer than about 12 clear
  spots means move the POI or the dressing. Then capture it from a clear spot, because a
  camera placed blindly lands inside a trunk.
- **"Floating" checks need care.** A ray cast from inside terrain hits nothing, so a sunk
  part reads as floating. Only flag gaps where the ray actually hit something below.
  Lanterns and lamps did float 1-5 studs, but some only looked like they floated: they
  stood on non-colliding meshes (pavilion floors, crates) that CanQuery-off raycasts
  ignore. Check for any part under the footprint before you lower a prop.
- **Event and treasure spots skip water.** Raycasts hit terrain water by default; the
  serpent marsh lair was 37% water. Spot pickers check `hit.Material ~= Water` and
  retry.
- **Name collisions in hand-edited XML.** When editing `.rbxmx` text, a pattern like a
  CFrame can match two instances (a zone disc and an event ground at the same spot).
  Anchor each edit to the item's Name block.
- **Commits in a shared repo.** Other sessions commit at the same time and can sweep up
  anything you've staged. Stage and commit in one command, right after a
  `git diff --cached --name-only` check. For files that carry other agents' uncommitted
  hunks (map.md, README.md), stage only your hunks by building the blob:
  `git show HEAD:<file>`, apply your edits in a script, `git hash-object -w --stdin`, then
  `git update-index --cacheinfo`. Never `git add` the whole file.
- **Studio can switch to Play under you.** The user or another agent starts play
  sessions, and `execute_luau` on Edit then fails. Don't stop their session; check
  `get_studio_state`, work on files meanwhile and retry. Edit-mode `_G` state can be
  lost, so keep audit helpers re-runnable rather than relying on `_G`.
- **Aerial captures don't work over the wilds.** The cloud plane (Y 440) and the haze
  white out any camera above about Y 300, and the dense canopy hides views at eye height.
  Check sightlines with the blockout from eye height on the spine, and verify numbers by
  raycast.
- **Editor-only aids go in `Workspace._EditorMarkers`** (labels, blockouts, route strips,
  anchored and non-colliding with CanQuery off). `EditorOnly.server.luau` strips them at
  runtime. Tag every new POI `POI` (PoiName, Kind, Zone) and re-run `PoiTour.labels()`.
- **Studio needs a file from disk?** Run `tools/receive_rbxmx.py` and
  `HttpService:GetAsync("http://127.0.0.1:8766/<file>.luau")` instead of pasting long
  source, and stop the server afterwards.
- **Clearance before you call a pocket done.** No wall rock, karst collider, tree or
  dressing may overlap a pocket's footprint, a pool, a fall's drop line (seen from the
  valley), a path's walking width or a POI's view from its path. A giant overhung the
  Twin-Jade pool and swallowed its fall. Check every pocket, pool, fall, path and event
  ground after any wall or pocket change, and fix or flag every hit.
- **Keep bamboo and trees out of water and fall drops.** A clump at a fall's foot or on a
  pool's rim hides both.
- **Karst trunk colliders are wider than the meshes** (r up to 96 round SouthEastFar):
  keep pools, paths and pockets outside them, or players hit an invisible wall.
- **Prefabs that dig their own water sink on a re-run** if you seat them on the lowest
  ground under their middle (the carve lowers it): sample the footprint's rim.
- **`require` caches a ModuleScript in Edit**, so after updating
  `_EditorTools.PoiTour.Source` load the file with `loadstring` to use the new version.
- **The user's Studio edits are the source of truth.** They ungroup and move things by
  hand. Never assume a prefab's model structure in a later pass: rescan the area by tags
  (`POI`, `POIAnchor`, `ManualCache`, `AmbientSound`, `NeedsHandPass`) and positions, and
  never move something they moved back to its planned spot. Put gameplay tags and
  attributes on parts (caches, prompts, sound and FX anchors, a `POIAnchor`), never only on
  a Model, because ungrouping drops the Model's tags and attributes.
- **Walls are a few giant library rocks, not piles.** "Stylized Cliff Terrain Rock" scaled
  to 80-120 studs is one cliff face; medium ones cover seams and feet. Fewer pieces means
  fewer seams and triangles, and the moss holds up at scale. Keep each a separate named
  model in `Map.Ground.WildsInner.Walls` (the user moves and scales them), never merged or
  welded; no script or raycast depends on wall geometry; spawns, discs and nodes stay 40+
  studs off wall feet. Check for gaps by rays from the valley side at several heights.
- **Library rocks with a SurfaceAppearance ignore part Color.** Tint them with
  `SurfaceAppearance.Color` (the Cliff Terrain Rocks need about `#706858` to sit with the
  house warm greys); check the tint in haze, day and dusk, from the valley floor.
- **New ground gets a base terrain pass before anyone looks at it.** Walls on bare
  Ground/Slate, old pools or fissures read as an unfinished game; lay grass up to the
  wall feet and raise it into them (`terrain_valley_base.luau`).
- **Library rock families don't mix.** Cliff Rock Pack I and the Fantasy rocks read brown
  and plain beside the moss-capped Cliff Terrain Rocks; capture a test before using them.

## Finish

Check with `screen_capture` from several angles, day and night (set
`Lighting.ClockTime`). Report what changed, the angles you checked and what's
untested. Commit one pass per commit, staging only your files. Studio-only
changes under `Workspace.Map` aren't in git, so list them in the commit body and
remind the user to save the place.
