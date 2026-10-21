# Map: layout, art direction and constraints

## Purpose
The plan every map pass builds against: what each area is for, what players see
first, the palette and lighting mood, the assets to dress with, and the
instances and coordinates scripts depend on. `Workspace.Map` lives only in the
place file (not Rojo), so this doc and the commit bodies are its only history.

## World at a glance
Floating stone peaks above a cloud sea (a flat cloud plane, top Y 440). The main sect
peak sits at the origin; eight player spirit peaks ring it at radius 300 (plateaus
Y 553.5, every 45 deg from 22.5 deg, `Peak_1` at (114.8, 553.5, 277.2)), each
linked by a rope bridge to the main peak's ring terrace (Y 582). The wilds lie
far below on the ground (`Workspace.Wilds`, Y ~0-10, south of the sect gate at
(0, 9, 500)). Axes below: +X east, -Z north (the summit is north of the plaza).

## World structure
Decided 2026-10-20. One place holds the hub and every zone; separate places are
only for instanced party content.

- **Hub server, 8 players.** The 8-player cap matches the 8 spirit peaks. The
  sect (main peak, plaza, spirit peaks) is where everyone keeps returning: peaks,
  market, elder, quest board, world events and tribulations people can watch.
- **Zones in the same place, linked by arrays and, between neighbours, a walkable
  gorge or bridge.** Each wilds zone is a dense walled area far from the others in
  space (the Inner Wilds valley is ~1800 x 920), one per
  realm tier, opened by realm (`Regions` `realm`). Staying in one server keeps
  friends together and weather, treasures and world events server-wide. Keep
  the zone count low (2-3 to start) so 8 players don't spread too thin; add more
  only when the existing ones are full of content.
  Adjacent zones may also join on foot through a gorge gate and a bridge (decided
  2026-10-21: the Inner Wilds and the Ruined Borderlands stay one continuous walk over
  the border river); zones that aren't neighbours only connect by arrays.
- **Arrays carry all long travel** (`Shared.Gates`, `src/server/Travel.luau`).
  Players spawn on their own peak's array, respawn after death on the plaza's and
  arrive on the destination's. On the sect's safe ground the Travel button rides
  to the sect's arrays (My Peak, Main Peak, Sect Gate) from anywhere; out in the
  wilds you travel only from an array (its prompt), and the wilds arrays answer
  only from the Sect Gate's array or another wilds array.
- **Today:** the wilds are one continuous smooth-terrain field covering rings
  300-2200 around the origin (Inner, Middle, Outer). Each ring has one array
  (`Map.Markers.TeleportHome`), standing in for zone gates until the zones are
  rebuilt as separate areas. The Inner and Middle arrays stand in their built
  zones (see "Wilds zones"); the Outer one is still out on its ring.
- **What to build with** (`.claude/agents/map-builder.md`): meshes for the
  landmarks people look at (peaks, cliffs, spires, floating islands), smooth
  terrain for the ground people walk on in wild zones (exact collision for the
  ground raycasts, recoloured with MaterialVariants to the palette), parts for
  halls, houses, walls, gates and stairs (curved roofs as meshes).
- **Point-of-interest density:** something to do every 20-30 seconds of travel
  at the player's speed, in clusters with quiet space between, and one landmark
  per zone visible from its arrival array. Kinds: qi nodes, beast lairs, herbs,
  ruins/steles giving insight, meditation spots with a local bonus, hermit
  NPCs, small trials, secret-realm entrances, vistas.
- **Sword flight at Foundation Establishment:** free movement inside a zone,
  never between zones (that stays the arrays). Server-checked speed, landing
  forced in suppression zones (lairs, sect grounds), streaming requested ahead.
- **Separate places for instanced content:** secret realms, dungeons and trials,
  entered as a party (reserved server), a queue (`MemoryStoreService`) or an open
  public server. Saves must finish before leaving and load safely on arrival
  (session locking), and players always return to a hub server.
- **Later realm tiers may move to another place we own.** From about the third
  zone on, teleporting into a separate place is allowed (a "you've moved up"
  moment), at the cost of splitting friends across realms and a save handoff.
  Decide when zone 3 is close; zones 1-2 stay in this place.

### Zone shape: walled valleys, detailed pockets, open event grounds
Decided 2026-10-21. Only the spirit gate front was detailed to the target
standard, and an open field can never be finished (every direction needs
something to look at, and the horizon makes it read flat). So the terrain
funnels players, not teleports:
- **A spine and pockets.** Each zone is a walled valley a few hundred studs
  across: one main path from the arrival array, and 3-5 side pockets off it (a
  hollow, a waterfall pool, a ruin, a lair, a cache). Each pocket gets the spirit
  gate front's level of detail; cliff walls close every other view and are the
  zone edge (no invisible walls). Exploring means leaving the spine for a pocket.
- **Open event grounds.** Each zone also keeps 2-3 open, flat-ish grounds
  (meadows, clearings, a terrace) away from the arrival array and at different
  distances from it, deliberately lighter on dressing so world events,
  auspicious phenomena and treasures have room to land and players room to
  fight over them. They are the places `Treasures.randomSpot` and event kinds
  pick; keep them clear of trees and rock clusters and reachable by more than
  one route.
- **Events are races.** A world event or auspicious phenomenon is announced and
  visible from afar (light pillar, clouds), so everyone runs for it at once; the
  routes to each event ground should be about equal from the zone's array, with
  a riskier shortcut (a cleft, a climb, a lair) to reward knowing the zone. See
  [world](world.md).
- **Dense with POIs.** Well past the "every 20-30 seconds" minimum: small finds
  between the big pockets (steles, herb patches, a hermit's camp, cave mouths,
  meditation rocks, vistas) and things found only off the path or by climbing.
- **Room to grow, and flight.** Players will fly (sword flight at Foundation,
  later real flight), so zones stay expandable: free space around each one so
  walls can move out or open onto new pockets (nothing scripts depend on sits
  against a wall); wall tops and backs look finished from above (a dressed rim,
  then mist or a drop); and each zone plans a vertical layer of cliff-top
  ledges, high caves and floating rocks with POIs only flyers or climbers reach.
  Each zone records its flight ceiling and bounds.
- **Bamboo is its own biome.** Bamboo grows only in pure, dense groves with a
  reason (a hero bamboo-forest pocket in the Inner Wilds, the hidden hollow,
  round steles, shrines or water), with a clear edge or a short transition of
  shoots and sparse culms. Never single clumps mixed into pine or broadleaf
  forest (today `dress_wilds.luau`'s `bambooAt` noise field does exactly that).
- **Rework passes remove what they replace.** Past AI passes layered new work on
  old (orphaned props, half-replaced dressing, misaligned seams, floating or sunk
  pieces). Every rework of an area starts with an inventory of what is there and
  ends with a sweep: every piece in the area either belongs to the new pass or is
  deliberately kept; replaced pieces go to `ServerStorage._<Area>Replaced` with a
  `FromPath` attribute (as `_WildsReplaced`), not left in place; seams that
  should meet (wall segments, path to bridge, lawn to rock) are checked for
  gaps; props are raycast onto the ground. See `.claude/agents/map-builder.md`.

### Still to do, in rough order
1. ~~**Gate UI** (`ui-designer`): TravelMenu buttons for `InnerWilds`,
   `MiddleWilds`, `OuterWilds` (TravelMenu wires any List button named after a
   gate id) showing the realm each opens at and a locked state; a prompt or glow
   on arrays so players find them; a fade while the destination streams in.~~
   Done: wilds buttons with realm locks, `GateMarkers` billboards, the `Veil`
   fade. A glow or particle on the arrays themselves is left for `vfx`.
2. **Zone separation** (`map-builder`): rebuild each wilds zone as its own
   bounded area far apart, with its array, landmark and POIs; switch `Regions`
   from rings to per-zone bounds, and update `Music.luau` (copies the layout),
   `Spawns`, qi nodes, treasures and world-event locations to match.
3. **Zone edges:** tall stacked-rock cliff walls with waterfalls (see
   "Verticality"), so each zone is an enclosed valley; mist where a wall can't
   go, plus an out-of-bounds return to the zone's array.
4. **Combat tag:** `Combat.inCombat` (taking damage within `IN_COMBAT_SECONDS`)
   already blocks travel. Also count dealing damage and being targeted by a
   beast, so hitting and running to an array doesn't work.
5. **Array discovery:** wilds arrays unlock on first visit (saved per player),
   on top of the realm requirement.
6. **Quiet empty zones:** no zone spawns or AI ticks where no player is.
7. **World events and treasures** pick a zone someone is in.
8. **Cross-place travel:** party/queue/open entry, data handoff, return to hub.
9. **Sword flight.**

## Art direction
Stylized, chunky, readable; shape carries detail. Plain colours on
SmoothPlastic (the modeler's rules: crisp vertical rock columns, grass only as
slabs with one overhanging turf lip). Never one flat colour over a big area:
vary each slab or part a step either way inside its family.

| Family | Base | Light | Dark | Use |
|---|---|---|---|---|
| Lawn (jade/sage) | `#6E8F5A` | `#83A36A` | `#56744A` | lawns, ledges; turf lip `#4A6340`, moss `#4E6B45` |
| Rock (warm gray) | `#7A7570` | `#8E8983` | `#615D59` | cliffs; deep base/shadow `#4D4A47` |
| Paving | `#B3AA9A` | `#C2B9A8` | `#9A9183` | plaza, paths; curbs `#8A8274` |
| Wood | `#5A3F2E` | `#6E4F3A` | `#3F2C21` | posts, rails, bridges, fences |
| Lacquer | `#9B2D26` | `#B23A30` | `#74201C` | columns, gates, lantern bodies |
| Roof | `#33403F` | `#43524F` | `#262F2F` | tiled roofs (slate teal, not black) |
| Jade | `#5FAE96` | `#8FD4BC` | `#3E7F6C` | lamps, runes, inlays |
| Gold | `#C29A48` | `#DDBA68` | `#8E6E30` | trims, caps, finials |
| Water | `#4E9FB2` | `#CFE6EA` (foam/rim) | `#2F6E80` | pool rims, wet stone; the water itself is brighter (WaterKit `#20AAE0`, foam `#F2FCFF`, after the library falls, [world](world.md)) |

### Verticality: walls and water
Decided 2026-10-21, from the reference `docs/reference/map_enclosed_valley.webp`.
The map reads flat: the wilds are rolling ground under open sky, so every view
ends in a horizon. Ground-level areas should feel like **enclosed valleys**:
- **Walls:** each pocket is ringed by cliffs of big stacked, chunky, blocky
  boulders (meshes in the house rock style, or library rocks sized up and
  piled), 15-40 studs high near the path and rising higher behind, with grass
  and moss spilling over every top and a few trees growing out of ledges. A
  player at the path should see a wall or rise behind most things they look at.
  Walls are also the zone edges (step 3 below), so they replace invisible
  boundaries.
- **Waterfalls:** the hero of most pockets. A bright white-cyan fall drops from
  a notch or overhang in the wall into a pool with a stone rim (a flat water
  part, never terrain water with a mesh fall). Several zones should have more
  than one: a big hero fall plus small trickles down other walls. Spray and mist
  are `vfx` (`FX_FallSpray`, `FX_FallMist`).
- **Framing layers:** foreground (tall grass and bushes by the path), mid (path,
  boulders, crates and props), background (the wall and its fall), with tall
  trees on both sides framing the view.
- **Light:** sunlit tops bright fresh green, shade sides cool blue-violet, pale
  warm stone; bloom on water. The sky stays a clear saturated blue in the day.
- Terrain grass decoration (the reference's big blades) stays off for mobile
  unless the user asks; fake it with grass clumps from the library by paths.

Today's problems to undo: lime grass `#57A83A`-ish with a hard edge, cool
blue-gray rock with no value change, pure red/yellow neon garland lanterns on the
plaza, a floating 125x1x117 gray slab (`MainPeak.Part` at (-72, 721, 90)).

Lighting: `src/client/DayNight.luau` (`KEYS`) drives Lighting, Atmosphere,
ColorCorrection, Bloom and SunRays at runtime, so tune the mood there, not on the
Lighting instances (those are only the Edit-mode look).
- Day: soft and warm (tint ~`#FFFAF4`), mist that thickens with distance over the
  cloud sea (Atmosphere density ~0.24, haze ~0.7), peaks fade to blue-gray.
- Dusk/dawn: peach/rose atmosphere, low sun rays.
- Night: moody blue (ambient ~`#262C52`, outdoor ~`#424E84`), lanterns (`#FFB56B`),
  jade lamps (`#7FE0C0`) and qi glows (`#9FD8FF`) carry the scene. Light pools
  should mark paths, entrances and focal points, not be sprinkled.
- Budget (mobile): GlobalShadows stays off; PointLight/SpotLight `Shadows=false`,
  Range <= 16; about 40 lights in view on the plaza and <= 8 per spirit peak;
  fake distant glow with Neon parts and bloom instead of more lights.
- Lights that follow day/night go under `Map.Sect.Ambience` (the first recursive
  "Ambience" under Map). Particles and beams are `vfx` work: leave named
  Attachments (`FX_<What>`, e.g. `FX_FallSpray`, `FX_Fireflies`, `FX_LanternFlicker`).

## Composition rules
- Every area starts from a written plan: arrival point, the one hero landmark,
  the main path and where it ends, two or three secondary spots, the edges.
- Block out in gray parts, `screen_capture` from where players stand and from the
  approach, then build for real.
- Props have a reason (frame a path, mark an entrance, sit where people would put
  them, soften an edge). Water has a source and a rim.
- Clusters of odd numbers and mixed scale (big + medium + small) with quiet space
  between; no even sprinkling, identical spacing or one-of-each.
- Vary height: terraces, steps, plinths, low walls, tall trees over shrubs.
  On the ground, enclose: every view from the path ends in a wall, a rise or a
  waterfall, not open horizon (see "Verticality").
- Edges get the most care: lawn-to-rock (turf lip, rocks, shrubs, moss),
  path-to-lawn (curb or stepping stones), bridge landings (posts, gate, pad).
- Cliffs: a few deliberate ledges of clearly different sizes, each with a reason
  (a pine, a shrine, a waterfall step). Never rows of same-size ledges.
- Mirror symmetry only on the ceremonial axis (plaza); everything else is
  asymmetric.

## Editor-only markers and the POI tour
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
  their spots, and ten floating lanterns (see "Wilds zones").

## Main peak
Found by coordinates only; children may be restructured freely.

```
            N (-Z)
   z -140  .  .  spire cluster (tips 684..812)  .  .
   z  -86  .  .  [Tribulation disc r30 @ Y855, (2,-86)] .
   z  -60  ----- mesa back (Y614 ledge / spire feet) -----
   z  -34  +-----------------------------------------------+  plaza floor Y648.6
           | PavW(-76,-14) [HALL TERRACE +1.2 x+-58]  PavE(76,-14) |
           |  Brazier(-58,4)  JadeLamp(+-30,5)  Brazier(58,4) |
   z   14  +-WEST COURT +0.6-+   Gong(30,26)    +-EAST COURT +0.6-+
   z   30  | Stele(-69,30)   |                  | PortalRing(73,44)|
   z   50  | benches, pots   W  [Cauldron(0,50)] W  bench, pots    |
   z   62  |       TestingStone(-34,64) garlands N-S at x+-16, z62..92 |
   z   80  | SeedMarket(-72,83) Elder(-24,80)  QuestBoard(24,80)  |
   z   91  |                 |           SpiritMarket(40,96) TA(70,91)
   z  100  |  planter(-90,104)  * PlazaSpawn (0,648.3,100)        |
   z  111  +-----------------+    lanterns x+-10.5 @ z 104/78/22, x+-19 @ z 50
   z  115  +-----------------[ balcony (0,130) ]------------+
   z  139      FlightWest (-55) \       / FlightEast (55)
                         down to ring terrace Y582
   ring terrace r~185 Y582, bridgeheads r172.5 @ 22.5+45k deg
            x -100 ............ 0 ............ +100
```

- Arrival: PlazaSpawn facing north. First view: the procession axis, cauldron,
  main hall, and the spire cluster rising behind it with the tribulation disc on
  top. Hero landmark: the hall + spire read as one silhouette; keep the axis clear
  of clutter between spawn and hall (garlands stay high and thin).
- Main path: ProcessionPath (x=0) spawn -> cauldron -> hall steps. Secondary
  spots off it: west court (Elder, Stele, SeedMarket), east court (QuestBoard,
  SpiritMarket, TeleportArray, PortalRing), the hall's flanking pavilions, the
  south balcony overlooking the stairs. Each court gets its own paving inset and a
  low wall/planter edge so it reads as a room, not a scatter.
- Plaza floor (built, `art/main_peak/build_plaza.luau`, re-runnable, parts under
  `Plaza.Layout`): PlazaFloor stays the walking surface (top Y 648.6) under the
  spawn and the Hub models. A hall terrace (x -58..58, z -31..8, +1.2, two
  risers on the front and sides) carries the hall's own platform; the
  pavilions flank it on the floor. Side courts (x -97..-45 and 47..97,
  z 14..111) are one 0.6 step up in a darker paving with a curb, and a low
  stone wall on the inner edge with openings toward the axis. Stele,
  SeedMarket, PortalRing, TeleportArray_Plaza and the planters sit on the
  courts (each keeps its pre-pass pivot in a `PlazaOrigin` attribute so the
  script re-seats it the same way). Garlands hang north-south along the axis
  (not across it) in lacquer red and paper, no neon. Lamps (template clones
  named StoneLantern/JadeLamp/Brazier so DayNight scales them, each with one
  shadowless PointLight): axis pairs at z 104/78/50/22, jade lamps at the hall
  porch, lanterns at the court openings, braziers at the pavilions; 26 lights
  on the plaza.
- Grand stairs: the south balcony is the plaza's "front door" view out over the
  cloud sea and spirit peaks; flights land on the ring terrace with gate posts
  and a lantern pair at each foot.
- Ring terrace (Y 582): a walking ring with eight bridgeheads. Each bridgehead
  gets a small paved landing, two posts and a lantern; between them, lawn with
  shrub clusters and a few pines grouped near the spire side, open toward the
  cloud views.
- Tribulation summit: a set piece seen from below (players are teleported up
  and back down to the plaza array, `Tribulation.luau`). Disc, posts and SkySteps stay; add a crisp rim and a few
  wind-bent pines on the shoulder spires. Keep air above it clear.
- Waterfalls: today four identical falls at the cardinals, fed by bare
  "Spring" discs lying on the terrace lawn next to the path (the "random pond").
  Replace with two falls of different sizes with visible sources: a large one
  from a spring at the spire foot (north-west), stepping down the mesa onto a
  rimmed pool on the terrace, then out through a notch in the terrace rim over
  the cliff; a smaller one on the east from a cleft in the mesa. Pools get a stone
  rim, reeds/lilypads and a footbridge or stepping stones where the path crosses.
  Leave `FX_FallSpray`/`FX_Mist` attachments at each base.
- Landform (built, `art/main_peak/build_main_peak.py` -> `MainPeakRock.fbx`,
  placed by `place_main_peak.luau`; floors by `terrain_main_peak.luau`):
  - Rock: crisp vertical Voronoi stone columns everywhere, the spirit pillars'
    rock. Each region (towers, mesa, cliff ring, the foot below the clouds) is
    split per column into three value tones (`MainRock<Region>1..3`), placed in
    textured Rock tinted to the rock family. The old lumpy `MainRockBase` is gone:
    the cliff columns run down to the ground (`MainRockFoot1..3`, Hull collision).
  - Towers: every tower above the massif is a bundle of column prisms (Voronoi
    cells of its cross-section) in stacked segments; outer columns stop lower,
    so tops are irregular crowns stepping up. Summit flat top Y 791 at (2, -90)
    (the SkySteps' first stone stands on it); two slender column towers at the
    back (767, 750) stay under it, and the air above the tribulation disc is clear.
  - Cliff ledges: five irregular shelves of column stumps (`LEDGES`): a big
    shrine ledge under the south balcony (0, 547, 194), a waterfall step in the
    rim notch's chute (-184, 535, -19), and a big/medium/small pine cluster on the
    south-west face (-127, 547, 143), (-159, 528, 111), (-161, 505, 120). All
    shelves are bare stone (the pines stand sunk in the stumps): their terrain
    grass basins leaked out between the stumps as green cubes and drips, so
    `terrain_main_peak.luau` no longer writes them (`SHELF_BASINS`). The 14 old
    disc ledges and their 12 floating pines are gone.
  - Waterfall sources in the rock: one rim notch at 186 deg (cap r 176) and two
    mesa-wall grooves, west at (-102, z -16) spanning 585-612 and 616-639 (the
    614 ledge is the step), east at (102, z -6) spanning 585-604.
  - Floors are smooth Terrain: terrace Grass with the ring walk in Cobblestone
    (surface Y 582; only the top voxel layer droops 1.5 past the rim), the plaza
    ledge Grass (Y ~614.5; only over the rock's sunk ledge flat, its lower
    voxel layers terrain Rock so the lip never shows a green band). The rock under them is
    sunk 1.5; where the voxels round off at the rim the stone shows as a narrow
    rim band. Grass (the material with blades) stays two voxels clear of paving,
    the ring walk and the rim: those borders are LeafyGrass, and anything paved
    on the terrace (bridgeheads, the stair foot pads, found at run time) gets
    Cobblestone under it and a 4-stud cobble apron. No turf-lip mesh (it floated
    where the terrain edge differed) and no moss band (`MainMoss`, retired: it
    hung as a dark green sheet under the sunk rim rock). The terrace's lower
    voxel layers near the rim are terrain Rock, so crevices in the cliff face
    show stone. Terrain surface rule (measured): a voxel over full voxels renders at
    centre + 4 x occupancy.
- Grand stairs (`art/main_peak/build_grand_stairs.luau`, re-runnable): each
  flight climbs the mesa's south wall toward the balcony in three runs with two
  landings (606, 628), a lacquer paifang and lantern pair at the foot pad
  (x +-98..106), lacquer posts, lanterns and potted plants on the landings, a
  stone balustrade on the outer side and a curb on the wall side. Open under
  the flights (a sloped slab and corbels against the cliff). Treads don't
  collide; an invisible ramp on each flight's nosing line does (checked by
  raycast along three lines per flight, no gaps or steps over 1.2).
- Terrain colours (global, `Terrain:SetMaterialColor`, set by
  `terrain_main_peak.luau`; spirit peaks share them): Grass `#7E9C63`,
  LeafyGrass `#66804F`, Ground `#7A6A55`, Mud `#5E5244`, Rock `#7A7570`,
  Slate `#7A746D` (was `#8A847D`, pale at night), Basalt `#615D59`, Cobblestone `#A39A8B`, Pavement `#B3AA9A`,
  Sand `#B9AC8F`. Terrain decoration (grass blades) is a manual Studio toggle
  (not scriptable through the MCP).

## Spirit peak template
Peak-local frame (`Peak.frame`): origin at Plateau, "in" = +Z toward the main peak
(bridge side), "out" = -Z, +X right looking out. Plateau r 50, build space r 47,
Y -30..+30. Lawn top local -1.5 (world 552).

```
            out (-Z)
   z -52  .  .  rim behind the house (low shrubs; the abode facade is below)
   z -46  .   [TERRACE x+-17, z -25.6..-45.5, top -0.5]  SignatureTree (33,-31)
   z -34  .     DWELLING (0,-34) on it, planters at the front corners
   z -21  +--fence--[gap x+-4.5]--fence--+      well/trough (38,-9..-1)
          |  12 beds, x +-28, z -20..32   |      spawn (39,8) (disabled)
   z   8  TP array (-39,8)                       stele (37,26)
          |    stepping-stone aisle x=0   |
   z  33  +--fence--[gap x+-4.5]--fence--+
   z  39  forecourt, jade lamps (+-6,39)
   z  44  BRIDGE GATE (flank walls x +-6..13); bridge lands z ~50 (x +-11)
            in (+Z, toward the main peak)
   stairs' head (-47,-7) on the left rim -> cliff stairs -> abode porch (0,-25,-60)
```

As built (2026-10-21, approved on Peak_1 and rolled out to all 8 peaks):
- Lawn: the `PeakGrass` mesh (the user chose it over a smooth-terrain lawn, which
  showed a slab edge, grass blades and lumps over the rim), on Material
  LeafyGrass (MaterialService overrides it with the stylized "Grass II" variant,
  the same one terrain lawns use) tinted `6E8F5A`, so it reads as the main peak's
  terrain green. Top local -1.7..-1.2 (it rolls gently); invisible `LawnCollider`
  boxes 0.3 under it close the mesh-collision holes. PeakRock/PeakRockBase are
  Slate `7A7570`/`615D59`. The cliff ledges are bare rock shelves
  (`LEDGE_TURF = False` in `art/build_peak_pillar.py`: no green ledge discs).
  No terrain on the peak tops.
- Focal point: the dwelling on `Pillar.Terrace`, a 1-stud stone terrace (under
  Pillar on purpose: `Config.Build.GROUND` counts Pillar as natural ground), with
  a front step, a side step toward the well and planters at the front corners.
  The view from the gate runs up a stepping-stone aisle (`Dressing.Path`, Slate
  flagstones 0.06 proud, the rest sunk) between the beds and ends on house +
  signature tree.
- Plants (`Dressing.Plants`, library "Stylized Foliage + Pots" bushes, ferns and
  leaf tufts, and one "Stylized Tree (Dark Green)" pine), in clusters with quiet
  lawn between: Signature (the tree, a bush, ferns, a tuft, a standing stone),
  LeftFront (the pine outside the garden's front-left corner framing the gate
  view, a bush, a fern, a tuft, a stone), StairHead (bush, tallest standing
  stone, fern, column stub), Landing (left: fern, tuft, stone, stub; right: one
  fern), Stele (two tufts), Back (bushes, a fern on the rim behind the house),
  Trough (one fern). Starter foliage (Bush, StandingStone, PineTree, SpiritTree
  pieces; their `Foliage/...@x,z` ids differ per peak and are kept) is moved into
  these slots by ItemId. Nothing on vertical faces, nothing over the lawn's
  bevelled lip (the flat top ends about r 44-48).
- Rocks: only `Dressing.Stones`, two little groups of hexagonal Slate column
  stubs sunk a stud into the lawn (stair head, bridge landing), plus the starter
  standing stones. No library boulders.
- Garden fence: 16 `Fence` segments (`Garden/Fence_1..16`,
  `art/spiritpeak/garden_fence.luau`, each run seated on the lowest of its three
  post spots); the catalogue Fence (`art/spiritpeak/fence_model.luau`) is a
  knee-high two-rail Wood run, one post per joint (the +Z end post and its cap
  tuck inside the neighbour's), pivot height and +-6.7 snap edges unchanged.
- BridgeGate sits on the lawn (its flank walls and pillar bases used to float
  ~0.8); no lanterns on the flank walls (they were wider than the walls). The
  flank walls are Slate `7E776B` (were Pavement, whose "Stylized Pavement II"
  override has a metalness map and renders the sides near black).
- Lights: 8 per peak (gate lanterns are the Bridge's; jade lamps; dwelling and
  porch stone lanterns; abode spirit stone; well), no shadows.
- `Peak_N.Dressing` holds all non-piece dressing (no StarterId/ItemId, never
  colliding, CanQuery off): Plants, Stones, Path (`dress_spirit_peaks.luau`),
  Planters, Abode (porch lanterns) and FX (invisible FX_* placeholders sized like
  the `ServerStorage.AmbientFX` templates, for the vfx agent).
- Scripts, in rebuild order (all in `art/spiritpeak/` unless noted; Edit mode via
  the MCP): pillar import + `art/place_peak_pillar.luau` (`peaks = {...}` limits
  the swap; extra Pillar children such as Terrace move across);
  `rollout_peaks.luau` (copies Peak_1's Terrace, starter poses except beds and
  Foliage, and Planters/Abode/FX into other peaks by Peak.frame);
  `fence_model.luau` + `garden_fence.luau`; `dress_spirit_peaks.luau`;
  `fix_overhangs.luau` (pulls back anything hanging over a terrace or wall
  edge); `strict_seat.luau` (rays over every unit's whole footprint, lowers
  anything floating; run dry to check); `recolor_peaks.luau` (palette pass on the
  peaks' plain parts: flagstones and terrace stone in warm mid grays, since sunlit
  Slate tops read far paler than their tint; dwelling walls Plaster cream, roofs
  dark Slate, abode hall walls Slate; also the catalogue Dwelling). Then raycast
  the lawn for holes.

Not done yet: the doc's raised garden curb and lantern-lit path turns. The
starter PineTree (BuildCatalog `PineTree`, a sparse realistic tree) and the
brown starter standing stones are catalogue models, left as they are.

## Bridges between peaks
Rope bridges from the terrace bridgeheads (r 172.5) down to each peak's gate
(a ~28-stud drop over ~75 studs). Keep: dark wood planks with slight per-plank
shade change, rope sag, posts at both ends with gold caps and a lantern on the
peak end. Landings at both ends per the rules above. `SwayBridge` tags are free
(no code reads them).

As seated (`art/spiritpeak/seat_bridges.luau`, re-runnable, run it after any
rebuild of the main peak's terrace or the spirit pillars; nothing else moves the
bridges, `strict_seat.luau` skips them):
- Terrace end: the `Bridgehead` (14x0.6x8 paving, top Y 582.05, Slate: the
  Pavement override's sides render near black) on a `Plinth` of rock-tone stone
  inset 0.25 under it, down into the sunk rim rock (580.5). They were a thin slab
  hanging a stud over the rock.
- Peak end: a stone `Landing` (11 wide, from just past the last plank to just
  inside the end posts, top on the posts' feet ~0.2 over the lawn, up to 6.5 deep
  into the lawn's bevel). The last plank and the posts hung over the bevel.
- Deck: the first plank's inner edge meets the Bridgehead top, the last plank's
  outer edge meets the Landing (a linear vertical shear; hangers keep their tops
  on the chains). Walk-checked along three lines per bridge: the only dips are
  the plan gaps between the pitched planks (0.4) and between the Bridgehead and
  the first plank (0.7), too narrow to step into.

## Cloud sea and ground
- Clouds are stylized cumulus meshes (`art/clouds/build_clouds.py`, run
  headless; `art/clouds/place_clouds.luau` lays them out, seeded and
  re-runnable from the kit in `ServerStorage.CloudKit`). Eight shapes (deck
  clumps A/B/C, DeckLong strip, Tower, Bank, Puff, WispArc) made of round
  billows with a flat base. A baked UV ramp (`CloudRamp.png`, the import's
  TextureID) gives every cloud cool shaded undersides and warm lit crowns.
  Fabric material keeps them matte (SmoothPlastic put shiny sun spots on
  every crown).
- The cloud sea is a flat white plane with a sparse set of hero clouds on it
  (cut for frame rate: the old dense deck was ~290 cloud parts, ~400k tris and
  20 big fog emitters). Don't bring the dense deck back; add a few hero clouds
  where a view needs them instead.
- Layers under `Map.Clouds`:
  - `Plane`: 9 slabs (3x3 of 1400 x 2 x 1400, Part sizes cap at 2048), top at
    Y 440, Fabric (matte), off-white (246, 248, 252), opaque. It covers
    +-2100 studs and the Atmosphere haze takes the edge. It hides every peak's
    foot and Peak_8's fall end (Y ~382). Its top is just over the lowest
    main-peak fall end (`Ring.WestFall.CloudFall`, Y ~438), so that fall drops
    into it. The five old deck holes are gone (the plaza's southern view is
    plane now).
  - `Wisps`: one arc hugging each spirit pillar at the plane (Y 436-446) and
    three stacked arcs around the main peak (Y 436, 458, 482).
  - `FallFoam`: one big puff at each waterfall end within 30 studs of the
    plane (now only WestFall's CloudFall).
  - `Mounds`: 40 low clouds (16 deck clumps, 24 puffs) squashed so they bulge
    15-50 studs over the plane, base sunk 6 under it. Ten loose clusters
    (`MOUND_CLUSTERS`, big + medium + small): four of 5 framing the peaks
    (r 430-480), two of 4 on the plaza sightlines (r 760-820), and four of 3
    thinning toward the haze (r 900-1300). There is open flat plane between
    clusters. They stay off the main peak (r < 202), the pillars (66 + 25),
    waterfall ends near the plane (90) and the plaza's southern view
    (100 deg, r 650, radius 150).
  - `KarstWisps`: a sparse ring pattern at the foot of each karst group within
    r 1500 (`KARST_ARCS` picks 0-3 arcs per group; stacked, spiral, offset
    rings, broken crescent or a single arc). Each group is seeded by its name,
    so every one is different and re-runs match. Only `COLLARS` (EastSentinels,
    WestMesa) get a mid-height collar of squashed puffs.
  - `KarstBands`: thin arcs (1-2) or a small puff collar (3-5) on about a
    third of the single karst pillars (`BAND_CHANCE`, seeded by pillar name).
    Each sits 60-80% of the way up and must clear the plane (19 pillars now).
  - `SpotRings`: free ring patterns (2-3 arcs) at the five spots where the
    user's hand-placed rings were. The one round Far_133 sits at Y 680 with a
    collar.
  - `Sprinkle`: 3 lone puffs and 1 free wisp over open plane, clear of the
    karst, the mound clusters and the peaks.
  - `HandPlaced`: any `Wisps` model the user drops at the Workspace root is
    moved here on the next run and never cleared. This runs before the kit
    stage, which would otherwise take their Cloud_* meshes for a fresh import
    and delete them. It is empty now.
  - `Banks`: mid-height clusters at 0/90/225 deg (r 430-620, Y 450-760) and a
    lone tower at 315 deg r 950. All of them are outside the bridges (r < 300)
    and the plateaus.
  - `Auspicious` (12 swirl clouds) are kept from the old pass. Of the 20
    `Emitters` (CloudLineFog, rate 1.2 each), 6 are kept and lifted onto the
    plane (`EMITTER_KEEP` in the script).
- Budget: ~185 parts, ~172k tris of cloud meshes (before LOD) plus the 12
  swirls, 6 emitters. The arcs are 1400 tris each whatever their size, so
  they are most of it. A lower-poly WispArc would be the next saving.
  `ServerStorage.CloudKit.Cloud_WispArc` stays as a template for runtime
  effects.
  Every cloud part is anchored, with CanCollide, CanQuery, CanTouch and
  CastShadow off, Massless, CollisionFidelity Box, RenderFidelity Automatic,
  DoubleSided off. The plane doesn't block raycasts, and players fall straight
  through it to the ground. From the ground the plane is a solid white ceiling
  at Y 440.
- Mist VFX spots (Attachments): `FX_PillarMist` x11 (pillar and main-peak
  wisps) plus one per `KarstWisps` ring, `FX_FallMist` x1, `FX_BankMist` x3. Clone
  `ServerStorage.AmbientFX.MistWisps` there.
- The sky's own clouds come from the painted skybox (lighting). Terrain Clouds
  stay off: volumetric clouds would clash with it.
- Distant karst silhouettes at r 800+ (far, Hull collision, low tris) give the
  horizon layers. The ground and wilds are a later pass (Wilds is Rojo-mapped:
  staging only).

## Under-sect ground
The floor under the sect (r < ~470, Y ~4-25), so a disciple who falls off a peak
lands in a forest instead of the void, and the pillars stand on something when
seen from the wilds. Smooth terrain from `art/ground/terrain_ground.luau`
(re-runnable; it only writes the columns that had no terrain, saved as
`Map.Ground.GroundFillMask`, in the band Y -40..48, and never sets material
colours). Decor near the peaks is re-seated by `art/ground/reseat_decor.luau`;
knoll rocks come from `art/ground/dress_sect_roots.luau` (`Map.Ground.SectRoots`).

```
            N (-Z)          Peak_4 / Peak_5 feet, ridge "spoke" at x 0
   (-268,-213) knoll+rocks        (-43,-344) K        (210,-265) K
   (-345,41) K   Peak_6/7   [ MAIN PEAK ROCK r~226 ]   Peak_2/3   (340,-41) K
                               | Ascension Array (0,5,236): TravelGate "SectFoot"
   (-214,268) knoll+rocks      | paved path x~0, Y 5, through the slot
            Peak_8  (x -13..25 at z 280)  Peak_1       (262,211) K
                       knoll (46,338) +rocks
            ======= sect wall z~377, gatehouse (0,~5,410) =======
                            S (+Z): gate (0, 9, 500)
   K = flat pocket kept clear for karst pillars (~40-45 across)
```

- Arrival: walking in through the gatehouse, or falling from a peak. First
  view from the gate: the path running north into the slot between Peak_8 and
  Peak_1, ending on the Ascension Array at the main peak's foot (hero: the main
  peak's wall rising out of the forest).
- Ground: a relaxed membrane from the surrounding wilds heights, easing down to
  a rolling floor (~Y 8, Grass/LeafyGrass by noise). Every rock base (spirit
  pillars and the main rock, outline raycast at Y 12) gets a Mud/Ground apron
  up to +5 that buries the mesh seam. Only stylized materials (Grass,
  LeafyGrass, Ground, Mud, Pavement have MaterialService overrides; Rock and
  Slate still look default).
- Old terrain spires (Slate/Rock, at r ~415-460, tops Y 300-480) whose bases
  hung at Y ~46-120 are joined down to the floor in their own material. The
  eight old hanging terrain columns at r ~212 in front of the main rock's face
  (Y ~48-400, nobody's) were deleted.
- Safety: `Regions` Sect ring is 0-410 (no ambient beasts under the peaks);
  the Ascension Array is a real array (any destination from it), and the gate
  array at (48, 6, 470) is a walk south. No fall damage exists.
- Peak roots: `Map.Ground.PeakRoots` (`art/ground/build_roots.py` +
  `place_roots.luau`, kit in `ServerStorage.PeakRootsKit`): a sleeve round each
  rock base stepping out per 2D-Voronoi cell, the spirit pillar's vertical
  column look, flaring up to ~10 studs at the floor. One mesh cloned to all
  eight pillars, a separate one for the main rock. No flare toward the slots
  between neighbouring pillars and the main rock, and none in front of the
  Ascension Array (the path and array squeeze between Peak_8, Peak_1 and the
  main rock there). Non-colliding; an invisible hull collider (*Foot) covers
  y 0-40.

## Wilds zones: Inner Wilds and Ruined Borderlands
The first two wilds zones as one walk south from the sect gate (`TeleportHome_Gate`
"SectGate" (48, 6, 470)): the Inner Wilds (`Regions` InnerWilds, box x -1020..1020, z
470..1560, "Bamboo and old stone, where young beasts hunt"), a walled valley, down to the
gorge gate (x ~175..262, z ~1450) and the border river (terrain water Y 0, z ~1566-1610),
then over the stone bridge (x 212) into the Ruined Borderlands (MiddleWilds, box x
-320..620, z 1560..2060, "Dead villages. The beasts here have eaten cultivators."). The
Borderlands moved there as one block by (+220, 0, +700) on 2026-10-21 (rework phase 1);
its built box is now x -200..500, z 1612..1960. Since phase 2 the Inner layout and terrain
cover the whole valley (box x -1000..1000, z 500..1460): the plan's spine, arms, loops,
cross paths and shortcuts, Old Stone Hill under the Bamboo Sea, the GateRidge, the Wolf
Den crag and cave, Giants Gully, the hollow, the knolls for the Shrine Terrace, the camp
and the hermitage, flats for the three event grounds, the Lotus Mere floor and the fall
pools, and a berm rising into every wall. The old border river, the old Inner dressing
(1,775 pieces) and the nine old Inner POIs went to `ServerStorage._InnerWildsReplaced`;
until phases 3-4 the valley is bare terrain. Reference: a sandy path sunk between grass banks under
layered-canopy trees, pale rounded boulders, blue/white flowers on the path edge, blue haze.

Scripts (`art/wilds/`, Studio Edit mode, in this order; each is re-runnable and seeded):
1. `wilds_layout.luau` sets `_G.WILDS_LAYOUT`: path splines, ridges, terraces, gullies,
   caves, pools, flats and POI footprints for both zones. Change the layout here. The
   Middle table keeps its pre-move coordinates and the end of the file shifts all of them
   (and the bridge) by `Middle.offset` (220, 700). `poi_wilds.luau` builds the Middle's
   POIs at their literal old coordinates, sampling the ground at the moved spot, then moves
   each POI by the offset; `_G.WILDS_POI.only = { "Bridge", ... }` rebuilds single
   builders and keeps the rest (rename or remove the old model first). Every POI it
   builds is tagged `POI`. `terrain_valley_base.luau` (run before `terrain_wilds.luau`)
   lays the valley's base floor and carves the border river, which `terrain_wilds.luau`
   keeps clear of.
2. `terrain_wilds.luau` rewrites the terrain in each box to absolute target heights
   (re-runs give the same ground), feathered 36 studs at the box edge and kept away from
   the river and the gate's paving; zone discs stay flat at their disc height out past
   Radius + 6 and qi nodes at their base; then carves the caves. Paths are Sand (Mud ruts
   and edges in the Middle), banks Grass/LeafyGrass (Inner) or Ground/Mud with sparse
   LeafyGrass (Middle), slopes over ~45 deg bare Ground. It also fills the old 4-8 stud
   fissures (down to Y -18) that crossed the Middle ring inside its box. Material colours
   are never set (they are global). The path splines are saved to
   `Map.Ground.WildsLayout` (StringValue, JSON).
3. `dress_wilds.luau` builds `ServerStorage.WildsKit` (named clones of the AssetLibrary
   pieces used; the crystal "Stylized Rock IV" with rainbow ore is never used) and
   rebuilds `Map.Ground.Wilds<Zone>.Dressing` (Trees, Bamboo, Rocks, Shrubs, GroundCover,
   PathEdge, Colliders): a jittered 9-stud grid read against the layout (noise groves with
   gaps, a ring of trees round each clearing, framing a few steps off the paths, sized-up
   rocks sunk into steep ground as cliff faces, outcrops of big + small rocks on rocky
   ridges), then a walk along every path (flower and clover runs, bushes, a big + medium +
   small boulder cluster every 40-75 studs), then a clean-up that removes colliding rocks
   and trees reaching into a path, a zone disc or a qi node's 8 studs.
4. `poi_wilds.luau` rebuilds `Map.Ground.Wilds<Zone>.POIs` (one Model per POI).
Old ring dressing that stood inside the boxes (7 Inner, 8 Middle) was moved to
`ServerStorage._WildsReplaced` (attribute `FromPath` = old location).

```
INNER WILDS (z down = south)                x ->
 z560  OldStoneHill ridge (bamboo, outcrops)      GateRidge  MeadowNorth ridge     EastRim
        Bamboo Hollow (-128,598) <- Hidden cleft      |   gate (48,470) / paving to z590
 z600  DenNorth ridge   WolfPocket(0,600) Old Stone Gate (-4,642)  QiNode1 (60,545)
 z650  WOLF DEN crag+cave (-318,652)  West path -> QiNode2 (-170,700)   East path ->
       WolfDen clearing (-240,660) = boss ring     Steles (-28,684)  Fallen Giant over
 z700        BoarField (-160,780)  WestSpur         trunk          Giants Gully (150,690)
 z780  WestRim   WestLoop -> Shrine Terrace (-58,826) HERO     EastHills    BoarMeadow (230,690)
 z850                    ShrineBack                EastBank path  QiNode3 + Qi Spring (266,844)
 z866  ~~~~~~~~~~~~~ border river ~~~~~ stone bridge x -8, z 866-910 ~~~~~~~~~~~~~~~~
RUINED BORDERLANDS
 z925  Border wall + gate piers (-6,928), Watchtower (28,936)
 z960  Ashen Hollow village (-72,962) around QiNode4    East road -> Caravan (116,976)
       West road -> Serpent Fen pools + Serpent Bones (-300..-336, 960..1000)
 z1040 Bone Gully   Cultivators' Graves (-162,1062)   Ruined Courtyard + QiNode5 (120,1040)
       Serpent Grotto cave (-322,1066)                Marsh: Drowned Shrine (176,958)
 z1100 WestBluff   FALLEN OUTPOST = BossArena (0,1100), wall ring r 60, gate north
                                                  EastBluff   Deserters' Camp (184,1142)
 z1172 Broken Pagoda on its mound (0,1172) HERO     SouthBluff
```

- Heroes: Inner, the weathered pavilion on the cliff-edged Shrine Terrace at the end of
  the trunk's long view, stone stair up from the path, lanterns, an old wide tree; Middle,
  the Broken Pagoda (three leaning tiers, burned) behind the arena, seen down the road from
  the bridge and through the arena gate.
- Landforms (smooth terrain + sized-up rocks): ridges and rims break each zone into
  pockets and are cut into clefts where a path crosses; Old Stone Hill holds the hidden
  hollow; the Wolf Den crag (top ~26) with a carved cave heading west; Giants Gully, a dry
  ravine the east path dips through; the Middle's bluffs close the arena basin; the Grotto
  crag with the Serpent Grotto cave; Bone Gully west of the arena; fen and marsh pools.
- Collision: foliage and debris never collide or take queries (spawn/treasure raycasts
  pass through); trees > 28 studs get one invisible `TrunkCollider`; rocks >= 6 studs
  collide (Hull); POI walls, pillars, steps, tents, carts, logs and the bridge deck
  collide. The bridge arch mesh is visual; an invisible ten-slab hump deck carries players.
- Lights (15 Inner, 7 Middle, `Shadows` off, Range 12-14): stone lanterns are Models named
  `StoneLantern`, the camp pole `Lantern` (`Config.Ambience.LAMP_MODELS`), so DayNight scales
  them; the Middle's are cold jade "ghost" lanterns. Campfire embers carry their own light.
- VFX points for `vfx` (Attachments on invisible anchors, sized to the area): Inner
  `FX_ShrineIncense`, `FX_Fireflies` (shrine, hollow), `FX_DenMist`, `FX_Campfire`,
  `FX_QiSpring`; Middle `FX_AshDrift`, `FX_GhostLights`, `FX_MarshMist`, `FX_ArenaMist`,
  `FX_PagodaEmbers`, `FX_GrottoMist`, `FX_Campfire`, `FX_CampSmoke`.
- Encounter spaces (visual only; spawns still come from `Wilds.Zones`): boss arenas are
  the Wolf Den clearing (Inner, ringed by standing stones at r 44, den cave west) and the
  Fallen Outpost (Middle, the existing BossArena disc inside a walled ring with a north
  gate); world events and treasures land on the event grounds (`Wilds.EventGrounds`,
  `Treasures.randomSpot`; see [world](world.md));
  the Deserters' Camp is an outpost site for 3-5 enemies; ambush spots are the Hidden cleft,
  Giants Gully, the border gate, Bone Gully and the arena gate.
- POI audit (2026-10-21, see "Editor-only markers and the POI tour"): the Stone Rock Pack's
  "Single Stone" models keep their WorldPivot ~485 studs from the mesh, so every `PivotTo`
  dropped the stone far from its spot: the Wolf Den's eight ring stones lay scattered from
  (-939, 473) to (212, 1155) and 155 Middle dressing pieces (path stones, ground cover,
  shrubs, 4 colliding rocks) sat off their spots. All 163 were moved onto their intended
  spots (the pivot's X/Z) and grounded; 44 more (spirit-peak foliage, cache dressing) only
  had their pivots reset. `dress_wilds.luau` now pivots every kit model at its bounding
  box's bottom centre, as does the Studio `ServerStorage.WildsKit`. Also moved: four caches
  (Hard constraints table), a tree and bush that hid QiNode2, the trunks round two caches
  (to `ServerStorage._InnerWildsReplaced`), and ten lamps and lanterns floating 1-5 studs
  up (QiSpringShrine's jade lamps, BambooHollow, BorderBridge, ShrineTerrace stair foot,
  Graves, BrokenPagoda).

### Inner Wilds rework: the walled valley (proposed 2026-10-21, not built)
Plan approved in direction; walls are built from scaled-up library cliff rocks, one
test stretch first (below). It turns the Inner Wilds into a walled valley per "Zone
shape" and "Verticality": one spine from the array, seven detailed pockets, three open
event grounds, a find every 6-10 seconds on foot between them, walls with waterfalls as
the edge, and a vertical layer for flyers stubbed in. The user asked for about twice the
first draft's size (2026-10-21): the valley floor is ~1800 x 920. Only the sect-gate
front (z 470-600, x -60..110, `Map.Ground.SectGate` ApproachLamps/ApproachArch plus 52
dressing pieces) is at the target standard and is kept as is. The gray blockout of all
of this (wall crests, falls, pockets, lairs, event grounds with route lengths, finds,
"later" spots, routes, bounds) is `Workspace._EditorMarkers._InnerBlockout`, labelled and
hidden at runtime.

**Frame and growth.** Valley floor x -900..900, z 520..1440, Y ~3-8. Zone bounds x
-1020..1020, z 470..1560, Y < 140: the band between the walls and the bounds (60-120
studs) is the growth band, where walls can move out or open into new pockets later.
Nothing scripts read (zone discs, qi nodes, arrays, cache anchors, event grounds) sits
within 40 studs of a wall's foot. Flight ceiling (sword flight, later) Y 420, just under
the cloud plane (top Y 440), so flyers can climb round the karst towers and reach the
"later" ledges (decided 2026-10-21). That needs `Regions`' `SectHeights` ("safe above Y
150") limited to the sect area itself (rings 0-470), done in the same change as the box
bounds below; the wilds boxes then reach up to Y 420. Past the bounds or the ceiling the
player is turned back, and past the growth band returned to the array.

**Why south, and what it moves (done 2026-10-21, phase 1).** The sect (r < 470) is north and the karst groups frame
east and west, so the valley grows east-west to the karst and south over today's
Ruined Borderlands box. The Borderlands move as one block by (+220, 0, +700) to x
-200..500, z 1612..1960, south of the SouthHorizon karst group, so the river, bridge and
gorge stay one continuous walk (the user's choice). What moves with it:
- `Wilds.Zones` SerpentMarsh (380, 1640), SerpentFen (-80, 1660), BossArena (220, 1800);
  `Wilds.QiNodes` QiNode4 (160, 1660), QiNode5 (340, 1740); `Wilds.EventGrounds`
  GravesFieldGround (0, 1750), SouthFlatGround (360, 1928) (all `assets/Wilds.rbxmx`,
  staging).
- `TeleportHome_Middle` to (234, 1662) and `Spawns.Ambient.SAFE`'s Middle entry with it;
  `cache_greatsageawakening` to (-77, 1779) (id unchanged).
- `Map.Ground.WildsMiddle` (POIs and dressing) by the same offset, re-grounded; the
  Middle's terrain and layout (`wilds_layout.luau` Middle coordinates + offset) rebuilt at
  the new box; the old Middle box and the old river (z 860-940) become valley floor.
- `Music.luau`: `MARSH_SOUTH` 880 to 1560, `BOSS_CENTER` (0, 1100) to (220, 1800).
- `Regions`: the rings no longer fit (the valley's corners reach r ~1700, the moved
  Borderlands r ~1600-2000, inside today's Outer ring). Add box bounds: InnerWilds x
  -1020..1020, z 470..1560; MiddleWilds x -320..620, z 1560..2060, both below Y 420 and
  checked before the Outer ring; in the same change `SectHeights` (`above = 150`) gets
  the sect's ring (0-470) so it no longer covers the wilds' sky. This is the "Zone
  separation" step. The user is open to moving anything else the layout needs.
- `art/karst/place_karst.luau`: its wilds clearance box and array spots.
- Old ring dressing in the new footprint goes to `ServerStorage._InnerWildsReplaced`:
  `Map.Ground.InnerRing` (Rocks 4, Trees 3, BambooForest 1 container models),
  `MiddleRing` (DeadTrees 7, RuinedVillages 2), `OuterRing.SealedRuins` (10).
- Karst stays where it is and becomes part of the valley (ground colliders to Y ~92):
  SouthWestField (x -862..-999, z 546..721) is the NW corner, SouthWestPair and
  EastSentinels (x 432..482, z 461..580) back the north wall, SouthWestFar (x -605..-733, z
  1207..1287) stands inside the SW (the Three Pillars pocket), SouthEastFar (x 661..791, z
  1307..1404) is the SE corner with the Twin-Jade Falls, and SouthHorizon (x -280..175, z
  1402..1596) closes the south behind the Shrine Terrace. The gorge gate passes east of
  it at x ~220, the one slot wide enough.

```
INNER WILDS VALLEY (proposed; z down = south, x right; A = Inner array (18,676))
z470          sect wall, gate front (kept), Gate array (48,470), QiNode1 (60,545)
z560  [SW Field karst]=NW WALL==V6======(gate gap)==NE WALL==[EastSentinels]==NE WALL==
       P2 BAMBOO SEA + HOLLOW (-300,630)   A    G2 NORTH TERRACE (300,680) r48   P5 HUNTER'S
W  P1 WOLF DEN (-580,780)  <-- West arm --+-- East arm -->  boar wallow   CAMP (660,650)  E
A   V1                   QiNode2 (-170,700) |  P3 FALLEN GIANT RAVINE (300,800)            A
L        WolfPocket (-170,880)        spine |  Giants Gully x~305, z 760..1060 (G3 cut)    L
L  G1 WEST FIELD (-400,1000) r55  <-- cross west --+-- cross east -->   BoarField (330,1000)  L
        P7 LOTUS MERE (-260,1170)           |   G3 EAST FLAT (470,1120) r55  P4 TWIN-JADE
   P6 THREE PILLARS [SW Far karst]          |                            SPRING (580,1210)
z1400 ==SW WALL=====  [SouthHorizon karst] SHRINE TERRACE + JADE VEIL FALLS (-40,1360) HERO
                                 gorge gate (220,1450) -> bridge -> river -> Borderlands
```

**Arrival and spine.** Players arrive on `TeleportHome_Inner` (18, 6.6, 676, kept, facing
south) or walk in through the gate front past the Old Stone Gate (217 studs, 14 s, from
the Sect Gate array). First view south down the spine: the SouthHorizon karst towers
rising out of the valley's far end, 700 studs away, with the Shrine Terrace and the Jade
Veil Falls at their feet (the zone hero). The spine (10 wide) runs from the court to the
shrine stair (666 studs, 42 s), framed by the Bamboo Sea west and the GateRidge east.
The GorgeRoad leaves it at (-10, 1250) east to the gorge gate, the bridge and the river.

**Paths** (about 5,000 studs): Spine; GorgeRoad (442); WestArm to the Wolf Den (553);
WestLoop south past G1 to the Three Pillars (350); SouthWest back east along the south
wall (618); EastArm past the Fallen Giant to the Hunter's Camp (710); EastLoop south to
Twin-Jade (410); SouthEast back to the gorge gate (472); CrossWest and CrossEast at z
~1000-1150 linking the loops to the spine; LotusLane (194); NorthFoot under the north
wall to G2.

**Walls (the zone edge): giant library cliff rocks** (decided 2026-10-21, replacing a
modeler kit). The AssetLibrary's "Stylized Cliff Terrain Rock" (Stylized Cliff Rock Pack
II: one mesh in five proportions, blue-grey with moss caps from its SurfaceAppearance)
scaled up a lot: one rock 80-120 studs tall is a cliff face on its own; a few medium
ones (the low 23/27-tall proportions at 20-35 studs) blend the giants into the ground and
cover their seams, small ones (7-10) scatter at the foot. The moss and texture hold up
at that scale; Cliff Rock Pack I and the Fantasy rocks read brown and plain beside them,
so they stay out of walls. Clones are pivoted at their bottom centre, scaled with
`ScaleTo`, sunk 10-20% of their height into the lowest ground under them, Hull
collision. Check contact by rays: from the valley side at heights 4, 15, 30 every 10
studs, every ray must hit the wall (only a notch may be open above its lip). Test
stretch (for review, `Walls.TestStretch_South`): 14 pieces along x -210..105 at the
SouthHorizon karst's foot, with a corner arm north to z ~1300 and the Jade Veil notch at
x ~-12 (lip top Y ~46, `FX_JadeVeilLip` anchor). The user places, resizes and edits
pieces by hand. Each piece stays a separate named model (`Wall_<Side><nn>_<Role>`,
attribute `WallPiece` = source proportion) in one folder,
`Map.Ground.WildsInner.Walls`, never merged or welded, and no script or raycast depends
on wall geometry (terrain scripts don't read it; spawns and event grounds stay 40+ studs
off).

Built (2026-10-21): the whole ring, 284 pieces in eight segment folders under
`Map.Ground.WildsInner.Walls` (`TestStretch_South` 14, `NorthWest` 55, `NorthEast` 18,
`NorthEast2` 26, `East` 49, `SouthEast` 29, `SouthWest` 43, `West` 50): 70 giants
(82-124 tall), 60 back-row rocks (40-60, stepping down outward), 58 seam covers on the
valley side (24-38), 75 small foot rocks, the test stretch's 5 foot rocks and notch lip,
15 rim pines (Map Detailing Pine Tree 2/3) on
giant tops and 14 `MistWisps` clones on the backs (`Wall_<Seg>_FX_RimMist<nn>`, Y 24, front
face outward). `art/wilds/build_walls_inner.luau` built them (seeded; it skips any segment
folder that exists, so hand edits survive; delete a folder to rebuild it). Crest lines:
NorthWest (-790,556)..(-620,522)..(-400,505)..(-112,502); NorthEast (152,500)..(386,500)
up to EastSentinels; NorthEast2 (545,600)..(700,590)..(840,640); East
(840,640)..(900,800)..(905,1000)..(880,1180)..(800,1262) to SouthEastFar; SouthEast
(618,1425)..(420,1450)..(262,1452); the test stretch x -210..105 at SouthHorizon's foot;
SouthWest (-212,1448)..(-500,1440)..(-760,1400); West (-760,1400)..(-860,1250)..(-900,1000)
..(-872,742) to SouthWestField. Openings: the sect-gate front (x -112..152 on the north)
and the gorge gate (x ~175..262 on the south). The north walls sit at z ~500, not the
planned ~550, until the rework moves the old Inner layout: there everything scripts read
keeps 48+ studs off a rock (Wolf Den disc 48, CrescentSweep cache 53, QiNode1 51); their
back rows touch the sect wall and five back rocks that clipped it were removed. Checks:
every segment's valley-side rays (heights 4, 15, 30, every 10 studs) hit rock with no
fills needed, no piece floats, and 88 old dressing pieces that the rocks clipped (old
ring rocks, trees, bamboo, glowing pools, boundary fog, Inner trees, colliders and rocks)
went to `ServerStorage._InnerWildsReplaced`. When the rework lays out the pockets, P5
Hunter's Camp moves ~50 south of the planned (660, 650) to clear the NorthEast2 feet.

Colour pass (2026-10-21, after the user found rock, moss and ground "three different games"):
- The rocks' look comes from their SurfaceAppearance (Overlay ColorMap), so the part Color
  does nothing; `SurfaceAppearance.Color` tints it. Every wall rock is tinted warm grey
  around `#706858` (a step either way per rock, kept in a `Tint` attribute). That brings
  the icy white-blue down to the house rock family (the karst's `#7A7570`) and quiets the
  moss to a deeper green next to the grass. Don't raise it much: lighter tints read icy
  again under the wilds' haze.
- `art/wilds/terrain_valley_base.luau` gives the new footprint (bounds, outside the built
  Inner and Borderlands boxes, the sect-gate front and r 480) a base floor: LeafyGrass and
  Grass by noise, Ground on slopes, rising 10 studs into the wall feet over 80 studs,
  feathered 36 studs into the built boxes; it filled the old pools and fissures. Global
  terrain material colours are unchanged (Grass `#7E9C63`, LeafyGrass `#66804F`, Ground
  `#7A6A55`).
- The old ring boundary fog emitters inside the bounds went to `_InnerWildsReplaced`. The
  tall pale "panels" seen past the walls are the far karst trunks (Far_008, Far_050) in
  haze, not blockout parts; they are the karst pass's to restyle.

**Stylized shallow water.** The Lotus Mere and every fall pool use one reusable template
the `vfx` agent is building: a flat water part with a cartoon surface (bright cyan cells,
white foam lines, a pale foam rim where it meets sand or stone), matching the waterfall
assets in ServerStorage (reference `docs/reference/water_stylized_shallow.webp`). The map
pass only places and sizes it on a flat sunk floor with a sand or stone rim; it never
builds water itself. Shallow water is walkable (a collider floor under it, no swimming).
Only the border river stays terrain water, seen at the gorge gate.

**Waterfalls** (each into a flat water part in a stone rim, never terrain water; spray,
lip, mist as `FX_FallSpray`/`FX_FallLip`/`FX_FallMist` for `vfx`): Jade Veil Falls (hero)
off the Shrine Cliff (-12, 1352) into a pool beside the spine's end; Twin-Jade Falls off
the SouthEastFar foot (625, 1245) into the Qi Spring pool; the den trickle down the West
wall (-868, 790); the Bamboo Hollow trickle down the north wall (-330, 560); a trickle on
the East wall (902, 960).

**Pockets (each detailed to the gate-front standard, one hero each).**
| Pocket | Centre | What it is | Hero | Script pieces |
|---|---|---|---|---|
| P1 Wolf Den Hollow | (-580, 780) | boss pocket: ring of standing stones r 44, den crag and cave against the West wall, a rock gate on the WestArm (ambush) | den crag with the trickle | `WolfDen` disc moves here (boss ring), `cache_dragonpierce` (-610, 750) |
| P2 Bamboo Sea + Bamboo Hollow | (-300, 630) | the hero bamboo forest (~250 x 150) on and round Old Stone Hill, the Hidden trail winding through it in filtered light to the hollow's spring | the spring under the north wall trickle, the weiqi table | `cache_crescentsweep` (-330, 600) |
| P3 Fallen Giant Ravine | (300, 800) | Giants Gully runs south from here; the fallen giant spans it as the EastArm's bridge | the giant | gully floor is the G3 shortcut |
| P4 Twin-Jade Spring | (580, 1210) | Qi Spring shrine at the fall pool under the SouthEastFar karst | Twin-Jade Falls | `QiNode3` moves to (545, 1195) |
| P5 Hunter's Camp | (660, 650) | camp on a rise in the NE, ladder up to a lookout (V4) | the lookout | `cache_rampagingtiger` (650, 660), 40+ off the wall |
| P6 Three Pillars Hermitage (new) | (-560, 1170) | a hermit's cliff dwelling at the SouthWestFar karst feet, ledge stair up the pillar (V7) | the three karst towers | new qi node (-520, 1150), a hermit NPC spot |
| P7 Lotus Mere (new) | (-260, 1170) | a shallow, walkable mere: a flat stylized water part (the `vfx` shallow-water template) over a sand floor sunk ~1 stud, with lotus, a stilt pavilion and a beached boat; no terrain water, no fall into it | the pavilion on the water | new qi node (-200, 1120) |
| Hero: Shrine Terrace | (-40, 1360) | weathered pavilion on the Shrine Cliff at SouthHorizon's foot, stair from the spine | Jade Veil Falls | `cache_heavensplitter` (-90, 1370) |

**Event grounds (open, flat, dressed light: grass, a few low rocks at the edge, no trees
or rock clusters inside).** Three distances; two near-equal routes each and one riskier
shortcut (lengths from the array along the planned paths, at walking speed 16):
| Ground | Centre, radius | Route A | Route B | Shortcut (risk) |
|---|---|---|---|---|
| G2 North Terrace (near) | (300, 680) r 48, at the EastSentinels' feet | EastArm then up the meadow 322 (20 s) | NorthFoot under the wall 326 | 285, along the GateRidge crest (narrow, drops either side) |
| G1 West Field (mid) | (-400, 1000) r 55 | WestArm then down the WestLoop 665 (42 s) | spine then CrossWest 663 | 531, through the Bamboo Sea's edge past the moved WolfPocket |
| G3 East Flat (far) | (470, 1120) r 55 | EastArm, EastLoop, back west 925 (58 s) | spine then CrossEast 914 | 718, down Giants Gully past the moved BoarField lair (jump-down) |
`Wilds.EventGrounds` gets these three in place of today's two interim Inner grounds.

**Lairs, nodes, caches (moved in phase 2).** `Wilds.Zones` WolfDen (-580, 780) (the boss
ring), WolfPocket (-170, 880) on the G1 shortcut, BoarMeadow (420, 790) by the boar
wallow, BoarField (370, 1040) where Giants Gully opens (the G3 shortcut). QiNode1 (60,
545) and QiNode2 (-170, 700) stay; QiNode3 (574, 1201) by the Qi Spring shrine; new
QiNode6 (-200, 1120) at the Lotus Mere and QiNode7 (-520, 1150) at the Three Pillars.
Event grounds `Wilds.EventGrounds` WestFieldGround (G1, -400, 1000, r 55),
NorthTerraceGround (G2, 300, 680, r 48), EastFlatGround (G3, 470, 1120, r 55), with their
route lengths in `LabelNote`. Caches move with their pockets in phase 3; ids never
change.

**Finds between the pockets (a cluster each, big + medium + small, tagged `POI` Kind
`Find`).** Spine: F1 Stele grove (-29, 684, the kept Steles), F2 wayside earth-god shrine
(-5, 790), F3 meditation rock facing the falls (25, 900), F4 ruined tea stall and
milestone (-35, 1010), F5 old well (15, 1150), F6 lantern stair foot (-15, 1280).
GorgeRoad: F7 ferryman's hut (180, 1532, at the crossing), F8 river jetty through the gate (250, 1470).
WestArm: F9 herb patch (-110, 700), F10 abandoned cart (-260, 735), F11 claw-marked tree
and bones (-450, 760). WestLoop: F12 snare line (-240, 895, on the CutWest beast trail), F13 half-buried pagoda
finial (-530, 1080). SouthWest: F14 woodcutter's clearing (-330, 1320), F15 stone bridge
over a dry creek (-180, 1320). EastArm: F16 herb patch (110, 725), F17 GateRidge vista
notch (150, 665, climb), F18 boar wallow (420, 790), F19 collapsed watch post (580,
760). EastLoop: F20 moss stele circle (610, 880), F21 Fox Hole cave mouth (700, 1000).
SouthEast: F22 charcoal kiln (-292, 1366, by the woodcutter), F23 sword in the rock (300, 1350). CrossWest:
F24 lone pine with a meditation mat (-220, 960), F25 herbalist's drying racks (-585,
1148, by the hermit's hut). CrossEast: F26 toppled statue head (200, 1150), F27 spirit-beast skeleton (380,
1170). LotusLane: F28 fisherman's boat (178, 1556, on the river bank). Bamboo Sea: F29 turtle stele at the
Hidden trail (-200, 650), F30 weiqi table (-330, 600). Gully: F31 old armour and a sword
(310, 920, shortcut reward). That is 31 finds plus 7 pockets and 3 grounds on ~5,000
studs of path: something new every 100-150 studs (6-10 s).

**POI prefabs (built 2026-10-21).** The pocket landmarks and the 31 finds are self-contained
prefabs in `ServerStorage.InnerWildsPrefabs`, built by `art/wilds/build_poi_prefabs.luau`
(seeded, re-runnable; `_G.POI_PREFABS = { only = {...} }` or `{ group = "landmarks" | "finds" }`;
needs `tools/water_kit_build.luau` first). Previews stand on grass slabs in
`Workspace._PoiStaging` (place-only; landmarks in two rows at z 3080 and 3250 from x 4080 every
160, finds in four rows at z 3370/3445/3520/3592 from x 4050 every 100; slabs are dug where a
prefab asks for terrain to be cleared). Ten landmark prefabs: WolfDen (den crag and cave),
WolfDenRing (ring stones r 44, ground each child), WolfDenRockGate, BambooHollow (spring pool),
FallenGiant (log bridge, invisible deck and limb ramp), TwinJadeSpring (pool and shrine),
HuntersCamp (tent, fire, lookout tower with a TrussPart ladder), ThreePillarsHermitage (hut,
cleft stair to a landing), LotusMere (unioned WaterKit mere, pavilion on a pier, boardwalk) and
ShrineTerrace; finds `F01_SteleGrove`..`F31_GullyArmour` by the numbers above. Conventions for
the placer: identity `WorldPivot` at the ground point, approach side -Z, bases reach 1-2 below the
pivot; attributes PoiName, Kind, Zone, PlannedSpot, Pocket, Footprint, Note, Points (the named
spots), tag `POI`; Attachments on invisible anchors for `CacheSpot`, `PromptSpot`, `QiNodeSpot`,
`HermitSpot`, `AmbushSpot_n`, `LedgeUp`, `FX_*` (vfx) and `SND_*` (ambient sound points);
`TerrainCarve` parts mark where to dig terrain (pools, the mere's sand shore, the wallow, the dry
creek); `ReseatChildren` on spread-out prefabs. Library clones are re-pivoted at their bottom
centre, so no far pivots. Every CacheSpot/PromptSpot/QiNodeSpot passed the 24-spot visibility
check on the staging slabs (12+ clear) except the Shrine Terrace's two (9: they sit on the raised
terrace, seen from the stair top and forecourt) and the vista notch (10, a narrow crest ledge).
Hand-pass flags (tag `NeedsHandPass`) on WolfDen, BambooHollow, FallenGiant, TwinJadeSpring,
HuntersCamp, ThreePillarsHermitage, LotusMere, ShrineTerrace, F04, F06, F07, F08, F13, F15, F19,
F21.

**Vertical layer (later; anchor Parts tagged `POI` Kind `Later`, LabelNote "(later)").**
V1 Eagle Ledge on a SouthWestField pillar (-880, ~70, 640); V2 Water Curtain Cave behind
the Jade Veil Falls (-25, ~30, 1385); V3 Drifting Stele, a floating rock over the gully
(305, ~100, 900), flight only; V4 Hunter's Lookout on the NE wall (760, ~60, 605), ladder;
V5 floating islets with qi motes over Twin-Jade (620, 100-130, 1180), flight only; V6
Sect View ledge on the NW wall (-400, ~55, 560); V7 hermit's high cell on a SouthWestFar
ledge (-640, ~80, 1240), climb; V8 Sentinel Gap ledge on EastSentinels (430, ~90, 620),
flight only.

**Bamboo is its own biome.** It grows only in deliberate pure groves: the Bamboo Sea
(P2, dense, tall, a path winding through, light filtering down), and small groves with a
reason (the Bamboo Hollow, the Stele grove, round the Shrine Terrace, by the Twin-Jade
pool and the Lotus Mere). Each grove has a clear edge or a short transition (young
shoots, a few culms, low bushes), never single clumps among the pines.
`dress_wilds.luau` drops its noise sprinkle (`bambooAt`'s `math.noise(x / 70, z / 70) >
0.32`) and reads the grove list from the layout; clumps come from the modeler's
`_Templates` bamboo (BambooCluster_1..16).

**What happens to the existing pieces** (replaced pieces go to
`ServerStorage._InnerWildsReplaced` with `FromPath`):
- Kept: the gate front and its 52 dressing pieces; `TeleportHome_Inner`, `TeleportHome_Gate`;
  QiNode1-2; POIs OldStoneGate, Steles, FallenGiant, QiSpringShrine, HunterCamp,
  BambooHollow, ShrineTerrace, WolfDen (moved to their pockets and reworked);
  BorderBridge (moved to the new gorge, x ~220).
- Moved: the four Inner lairs, QiNode3, four Inner caches, the Middle as a block (above).
- Replaced: all `WildsInner.Dressing` outside the gate front (about 1,770 pieces, rebuilt
  by `dress_wilds.luau` against the new layout: the 144 bamboo unions that render as loose
  planks, the even canopy of 386 trees and their colliders, 256 rocks, 548 path edge,
  97 shrubs, 36 ground cover); the old ring dressing in the footprint.
- Removed: `Map.Markers.TideSpawns` and `TideRally` (no code reads them; user approved).
- Scripts to update with the build: `wilds_layout.luau` (paths, pockets, grounds, groves,
  the Middle offset), `terrain_wilds.luau` (bounds, old river fill, new river at z
  ~1480-1560), `dress_wilds.luau` (bamboo rule, rim and wall-foot dressing), `poi_wilds.luau`
  (new pockets and finds, `POI` tags), `Regions`, `Music.luau`, `Shared.Spawns`,
  `place_karst.luau` clearances.

**Prefab updates and ungrouping (2026-10-21).** `art/wilds/swap_prefabs_inner.luau` swaps any
placed pocket or find whose structure no longer matches its prefab (`_G.SWAP_DRY = true` lists
them first), keeping the copy's exact pivot and its tags and attributes. It re-seats the cache,
redoes the reseats, the Lotus shore fix and the terrain carves, and moves the old copy to
`_InnerWildsReplaced`; run `ambience_inner.luau` and `T.labels()` after it. Every POI model also
holds a `POIAnchor` part (tag `POIAnchor`, the POI's attributes) so the tour, labels and
hand-pass list survive the user ungrouping it (Ctrl+U drops a Model's tags and attributes).
Game scripts find nothing through the pocket or find models: caches by the `ManualCache` tag on
their `CacheAnchor` part, qi nodes by the `QiNode` tag on their Crystal (`Workspace.Wilds`),
ambient sounds by the `AmbientSound` tag on each anchor part. Things not to ungroup or move:
- anything under `Workspace.Wilds` (zone discs, qi nodes, event grounds: Rojo-managed, edit
  `assets/Wilds.rbxmx`);
- the TravelGate arrays (`Map.Markers.TeleportHome.*`, `SectGate.AscensionArray`: the tag and
  `Gate` attribute live on the array Model);
- the cache models (`Map.Markers.ManualCaches.Cache_*`: moving the whole model is fine, the
  `CacheAnchor` part must stay with its pedestal);
- lamp models named `StoneLantern`/`Lantern` (DayNight finds their lights by model name);
- `Map.Sect.SpiritPeaks.*` and `Map.Sect.Ambience`.

**POI pass (2026-10-21, done by the agent at the user's request).** Order after phase 3:
`water_inner.luau`, `poi_pass_inner.luau` (clears the blocked-by list), `group_poi_parts.luau`
(groups and roots every object), `poi_scale_sense.luau` (scale and sense), `ambience_inner.luau`,
`T.labels()`.
- **Grouping:** inside every pocket, find, water group, prefab and staging copy, small pieces
  that touch a bigger object go inside it (moss on a stele, a tent's ropes, a cart's load, a
  log's fungus; plants, rim stones and water stay their own), then objects go into function
  groups: `Rocks`, `Foliage`, `Props`, `Structure`, `Roof`, `Stair`, `Apron`, `Lanterns`
  (lamp models keep their names), `Water`, `PoolRim`, `FX`, `Sound`, `Markers`. Each group is
  pivoted at its bottom centre; nothing is left loose beside the groups and the `POIAnchor`.
  `_G.groupPoiParts(model)` can be called by the prefab builder too.
- **Rooting:** every object is seated on what is under it (five rays under its base, sunk
  0.4 stud for props, 8-15% of the height for rocks and rim stones), tilted to the slope
  (fully for flat stones, logs and crates, at most 8 degrees for upright things, never for
  plants), with a small random yaw on loose stones; buildings, stairs and roofs stay level and
  the ground is filled up under them where they hovered.
- **Blocks cleared:** seven wall seam rocks that stood in the Bamboo Hollow, the Fox Hole and
  in front of the den and East trickles; Wall_SouthEast26_Giant moved off the gorge
  approach; Wall_S11_CornerFoot shrunk off the GorgeRoad; the Twin-Jade notch giants pulled
  back and lowered (68/74 tall, to the sides) so the pool, falls and shrine stand open; the
  prefab's bamboo off the pool rim and the fall foot; an old dead tree in the Wolf Den; the
  camp lantern off the trail end; the hermitage 18 studs off the SouthWestFar collider.
  Falls now drop in front of the rock under their lip (`frontPush`), and the Bamboo Hollow
  trickle falls from the north wall face. The wall ray check still finds no gaps.
- **Scale:** WolfDen 1.4, WolfDenRockGate 1.3, HuntersCamp 1.3, hermitage 1.15, ShrineTerrace
  1.25 (moved 10 studs forward of the cliff); finds 1.2-2.5 (steles and moss circle 1.8,
  earth-god shrine 1.8, sword in the rock and turtle stele 2.0, pagoda finial 2.0, statue head
  and beast skeleton 2.5, fox hole 1.8, ferryman's hut 1.5 with a 7-stud door). Each POI keeps
  its factor in `AppliedScale`.
- **Sense (moved):** F05 Old Well beside the tea stall (-2, 1040); F07 Ferryman's Hut to the
  river crossing past the gorge gate (180, 1532); F28 Fisherman's Boat on trestles on the
  river bank by the hut (178, 1556) instead of the forest; F08 jetty on the bank east of the
  bridge; F22 Charcoal Kiln beside the woodcutter's clearing (-292, 1366); F12 Snare Line
  across the CutWest beast trail (-240, 895); F25 Drying Racks beside the hermit's hut
  (-585, 1148). QiNode3 and QiNode7 follow their pockets' node spots.
- **Prompts and caches:** HeavenSplitter at the shrine stair's head (14 of 24 approach
  spots), the Twin-Jade, F03 and F04 prompt spots moved to open ground (24 of 24), F18's lifted
  out of its hollow; the other caches 24 of 24.
- **Still open** (`T.handpass()`): structure fits not checked piece by piece (stele grove,
  earth-god shrine, tea stall, pagoda finial, dry creek bridge, vista, watch post, kiln, lone
  pine, the border bridge, the fallen giant, the den ring and gate), the toppled statue head
  (reads as loose blocks at 2.5x), and the Borderlands POIs.

**Inventory of the Inner box before the rework** (x -450..430, z 470..900, Y < 300;
1,867 models and loose parts): `Map.Ground.WildsInner.Dressing` 1,827 (Trees 386,
Colliders 360, PathEdge 548, Rocks 256, Bamboo 144, Shrubs 97, GroundCover 36);
`WildsInner.POIs` 9; `Map.Markers` ManualCaches 4, TeleportHome 2, TideSpawns 13,
TideRally 5; `Wilds.Zones` 4 (WolfPocket, WolfDen, BoarMeadow, BoarField); `Wilds.QiNodes`
3. No loose pieces at the Workspace root or in `Hub`. Terrain (20-stud samples): Grass
565, LeafyGrass 327, Water 92, Ground 88, Mud 40, Sand 31, Pavement 7; floor Y 3-8,
ridges to Y 26. The wider footprint is flat terrain (Y 1-6) with scattered pools and old
fissures to Y -20.

## Asset catalogue
All under `ServerStorage.AssetLibrary` unless noted. Clone, don't move, the
originals; re-colour to the palette.

| Need | Pieces |
|---|---|
| Lanterns, lamps | `_Templates.FX_StoneLantern`, `FX_JadeLamp`, `FX_Brazier`; `Stylized Asset Pack I/Stylized Wooden Props I/Stone Lamps` (Stone Lamp 1 4x7, Stone Lamp 2 4x16); `Stylized Asset Pack I/Stylized Props/Stylized Lamp Post` (2x16); `Map Detailing`: Lanterns 1/2/3 (hanging strings ~15 tall), Lantern 1/3/4 (small), Latern 2; Inno `Wood_Iron_Assets/Lantern_Pole`, `Lantern` |
| Rocks | `Stylized Rock Packs`: Cliff Rock Pack I (Cliff Rock I-III, 10-17 wide), Cliff Rock Pack II (Cliff Terrain Rock 45-70 wide: big edge masses), Fantasy Rocks (Rock I-V, 10-20), Stone Rock Pack (Single Stone 1-5 wide, standing stones); Inno `Customizable_Assets/Rocks` (Rock_01..Rocks_07, Presets 01-06 clusters 30-46 wide) |
| Shrubs, ground cover | `Stylized Foliage + Pots/Stylized Bushes` (Green 7-34 wide; Orange for autumn accents only); `Plants + Pots` (Ferns, Leaf, Reeds, Mush, Pot & Flower); Inno Foliage (Bush1/Bush2), Clovers 01-03, Flowers (Blue/Pink/White/Yellow beds), Mushrooms; Map Detailing Bush Pink/White/Yellow flowers (6x5x9) |
| Trees | Inno `Pine_Trees` Variation_01-06 (4 sizes each, 33-45 wide, 57-75 tall: the best chunky pines); Map Detailing Pine Tree 1-5, Tree 3 realistic, Tree 2 realistic, Small Tree 1-3; `Stylized Tree Pack` (Light/Dark Green 43 tall, Wide, Orange, Wind Physics); `_Templates.BambooCluster_1..3` (old single-part unions, ~45 tall); `_Templates.BambooCluster_4..16` (Models, `art/bamboo/`, `BambooKind` attribute: 4 Grove dense clump, 5 Sparse 4 culms, 6 Single tall culm, 7 Arching wind-bent, 8 Young with shoots, 9 Stumps cut, 10 Dry gold accent, 11 Thicket low oval row, 12-14 Stand A/B/C 16x16 tiles that butt into a continuous grove (turn by 90 deg), 15 Giant 78-96 tall for the hero grove, 16 Edge 16x8 border strip, tall side +Z, shoots toward -Z; multi-part, so recolour per part, not `c.Color`); `Tree Log Stumps` |
| Fences, rails | Stylized Wooden Props II `Stylized Fence` (Full Fence, Fence Pillar 7 tall); `Stylized Props/Bamboo Fence (modular)`; Inno `Fences/Fence_01..03` (7x4); Map Detailing Asset Pack Fence1-3; `Lighting Fence` |
| Paths, edging | `Textures` (Pavement I-III, Tiles, Ground I/II, Grass I/II, Wood Planks; reference swatches for colours); Map Detailing Pebble, Stone (8x1x8 stepping), Inno Logs |
| Water edges | `ServerStorage.WaterKit` (stylized shallow water, never terrain water: `ShallowWater` block / `ShallowWaterRound` surfaces, `waterKit.dress` for unions, `RimFoam` and `waterKit.rimPart`/`rimAlong` rims, `WaterfallFoam` at a fall's foot with `AmbientFX.WaterfallSpray`; see [world](world.md)); LilyPads (W Flower 7 wide), Inno Lilypads 01-06, Reeds; `VFX`: Blue Waterfall (28x80, the colour reference for water), WaterFall Main (26x62), Stylized Rock Formation Waterfall (87x74), Map Detailing Stylized waterfall 2/3, Water Fountain, Wells (Clean Blue, Mossy Green) |
| Bridges, stairs | `Stylized Bridges + Step Ladders` (Bridge I/II 108 long, Step Ladder I/II); Inno `Stone_Bridges/Bridge_Regular` (38 long arch, good for pool crossings), `Bridge_Wood`; Map Detailing Bridge, Pier |
| Props | `Stylized Props`: barrels, crates, sacks, hay, trough, buckets, table + chairs, ladders, cart wheels; Wooden Props I: Pushing Cart, Strong Box; Props II: logs, LogPile, bench; Map Detailing: Gong, Wood Sign 1/2, Display, Market shop, Whistling board, Candles, Book Podium, Bell Pillar, Stone Statue |
| Structures | Map Detailing: Tori Gate (with/without sign, 36x30), Temple Structure (36x32), Shop House, Smith House, House 1-3; `Stylized Market Tent`; VFX Shrine Statue, Portal |
| Clouds | own meshes in `ServerStorage.CloudKit` (`art/clouds/`); Props II `Stylized Clouds` (22-28 wide swirl puffs, used as `Map.Clouds.Auspicious`); Map Detailing `Clouds_01..09` (flat side-profile strips, unused) |

Avoid: Map Detailing modern props (traffic cones, hydrants, mail box, AC unit,
stop sign, street lights), palm trees, Castle/Medieval_House, Dummy.

## Hard constraints
From a read-only audit of the code (2026-10-20); code refs inline.
- `Workspace.Map` is place-only. `Workspace.Hub` (`assets/Hub.rbxmx`) and
  `Workspace.Wilds` (`assets/Wilds.rbxmx`) are Rojo-mapped: AGENTS.md staging.
- Spirit peaks: `Map.Sect.SpiritPeaks.Peak_1..8` (Models; folder name read in
  `Peaks.luau`, `MyPeak.luau`, `Peak.luau`). Attributes Owner, OwnerName,
  PeakName. `Plateau` (invisible 100x100 cylinder, PrimaryPart) is the frame
  origin for saved layouts, build bounds (`Config.Build` RADIUS 47, Y -30..30,
  PEAK_RADIUS 60), RealmTier and wild herb spots: never move it or the rock
  relative to it.
- Keep names TeleportArray (home spawn, reserved r 9), SpawnLocation (disabled),
  NameStele>Cap (owner sign), Placed (Folder), BridgeGate (reserved r 9),
  AbodeEntrance (reserved r 7), Pillar and Plateau (GROUND names), Garden.
  Restricted names: Bridge, BridgeGate, CaveAbode, NameStele, TeleportArray,
  Pillar, Garden. Free to restyle: GardenAnchor, DwellingAnchor, AbodeInterior,
  Accent, Foliage, Props, CliffDecor, Well, Trough, Dwelling.
- Starter pieces: descendants with `StarterId` (+`ItemId`); ids identical on all
  8 peaks and never changed (saved data stores removed ids; `PeakStash` holds
  stashed ones). Moving them is fine.
- Beds `Garden.Beds.Bed_K`: tag HerbPlot, attrs PlotId, ItemId, BedIndex, Soil,
  Round; child `PlotAnchor` never resized or rotated. Losing a PlotId deletes
  saved plantings.
- RealmTier `ServerStorage.PeakTiers.Foundation` (`assets/PeakTiers.rbxmx`:
  Lantern1-8 at r 47 y 7, a thin jade SkyBeam with a gold SkyBeamCore from y 75
  to 344) plus the place-only `ServerStorage.PeakTierModels.Foundation`
  (`Pavilion`: the plaza Temple mesh on an inverted Slate rock island, top y 56,
  spike bottom ~y 32, spirit stone, gold finial, roots, fern tufts), which
  `Peaks.applyRealm` merges into the clone. Library MeshParts live place-only
  because Rojo can't sync MeshIds (they arrive as gray boxes). Peak-local X/Z
  +-49, all non-colliding with CanQuery off; re-check clipping if the plateau
  surface changes.
- Teleport arrays (`Shared.Gates`): every array players travel through is tagged
  `TravelGate` with a `Gate` attribute: `Plaza.TeleportArray_Plaza` "MainPeak"
  (66, 649.5, 92; also the death respawn), `Markers.TeleportHome.TeleportHome_Gate`
  "SectGate" (48, 6, 470), `TeleportHome_Inner` "InnerWilds" (18, 4.2, 676; a
  clearing east of the trunk past the Old Stone Gate, facing south down the path),
  `TeleportHome_Middle` "MiddleWilds" (234, 1.4, 1662; between the road and the east
  road past the Border Gate, facing south toward the arena; moved with the Borderlands), `TeleportHome_Outer`
  "OuterWilds", each peak's `TeleportArray` "Peak". Arrivals land 4
  above the pivot facing its LookVector; travel works within 12 studs flat of the
  pivot. Arrays are `ModelStreamingMode` Atomic. Moving one moves where players
  arrive; keep the tag and attribute on any rebuild. `SectGate.AscensionArray`
  (0, 5.1, 236) is tagged with Gate "SectFoot", an id not in `Gates.List`: you
  can leave from it (the way out for anyone who fell under the sect) but it is
  never a destination, and its marker reads "Teleport Array".
- Main peak: PlazaSpawn (0, 648.3, 100)
  is the only enabled spawn (players are moved straight onto an array); plaza floor at Y ~647-648 under it. Hub: Elder
  (-24.2, 652.7, 80), QuestBoard (24, 652.15, 80), SpiritMarket (40, 650.1, 96)
  (MARKET_RANGE 24); prompts by name (MarketPrompt, Herbalist).
- TestingStone (spirit-root reveal, `Roots.luau`): `Hub.TestingStone` at
  (-34, 648.6, 64) on the plaza floor west of the axis, 19 studs N-W of the
  Elder, step facing the spawn. Stone > TestPrompt (found recursively) and
  Stone > PillarOrigin (top centre, Y 654.85) for the root pillar vfx; keep the
  air above it clear. Built by `art/main_peak/build_testing_stone.luau` into a
  staging clone, then spliced into `assets/Hub.rbxmx`.
- Tribulation: `Config.Tribulation.CENTER` (2, 857, -86), ARENA_RADIUS 34; the
  floor raycast from CENTER+20 down 60 (CanCollide parts only) must hit the
  walkable floor (TopSurface, Y 855.3) (`Tribulation.luau`). Effect parts above
  the floor (TribulationLightning) must stay CanCollide off.
  Keep a walkable floor >= 34 radius at Y ~855.5 with clear air, or update Config.
- Day/night lights: `DayNight.luau` scales only Lights under the first recursive
  "Ambience" under Map (`Map.Sect.Ambience`). Never add another "Ambience".
- Regions (`Regions.luau`): the sect is ring 0-410 on the ground (the under-sect floor
  included) and ring 0-470 above Y 150 (only over the sect, so flyers in the wilds keep
  their region); InnerWilds box x -1020..1020, z 470..1560 and MiddleWilds box x
  -320..620, z 1560..2060, both below Y 420 (the wilds' flight ceiling under the cloud
  plane); Outer still the ring 1600-2200. `Music.luau` copies the Borderlands line
  (`MARSH_SOUTH` 1560) and the boss arena centre (220, 1800).
  SECT_GATE (0, 9, 500).
- Wilds zones and qi nodes (positions in `assets/Wilds.rbxmx`) are leash and
  spawn homes; ground raycasts (spawns reject Water, treasures, placement) need
  real collision under them.
- Event grounds (`Wilds.EventGrounds`, parts with a `Radius` attribute, in
  `assets/Wilds.rbxmx`) are where `Treasures.randomSpot` drops treasures and world
  events; keep them flat, open (no trees or rock clusters inside) and on real
  collision, and move them with the zone reworks (staging).
- Weapon racks and manual caches (`src/server/WorldCaches.luau`, design in
  `docs/systems/weapons.md`): found only by CollectionService tag, anywhere
  under Workspace. Each anchor is an invisible BasePart (Transparency 1,
  anchored, CanCollide/CanQuery/CanTouch off); the server parents the prompt
  (`ItemTemplates.RackPrompt`/`CachePrompt`, 10 studs) to it, so the anchor is
  where the prompt shows. Moving anchors is fine; renaming a `Cache` id or a
  rack's `Weapon` re-opens it for everyone who claimed it (`data.caches`).
  - `WeaponRack` (attr `Weapon`, optional `Cache`, default `rack:<Weapon>`):
    `Plaza.WeaponRack` in the west court, a lacquered rack against the court's
    west balustrade (x -93, z 50..72, floor 649.2) facing the axis, with a chest
    and crates at its south end. One `RackAnchor_<Weapon>` (1 stud cube) per
    weapon at (-92, 652.7, z): IronJian 52.9, IronDadao 55.8, IronGreatsword
    58.6, IronGuandao 63.4, IronSpear 66.2, BambooStaff 69.1. The weapons on it
    are part props (non-colliding).
  - `ManualCache` (attrs `Cache` unique id, `Manual` technique id and/or
    `Weapon`, optional `Realm` stage key like "QC3"): `Map.Markers.ManualCaches.
    Cache_<Manual>`, each a small Slate pedestal (or a log at the camp) with a
    red cloth, a 1x0.2x1 `CacheAnchor` on top (the server rests
    `WeaponModels.ManualScroll` on it, so keep ~1.5 studs clear above), an
    `FX_CacheGlow` attachment on the cap for `vfx`, and a little dressing.
    Harder spots hold the stronger manuals:
    | Manual | Cache id | Realm | Anchor | Spot |
    |---|---|---|---|---|
    | CrescentSweep | cache_crescentsweep | - | (-126, 8.05, 620) | in the bamboo at the south foot of Old Stone Hill's boulders, by the end of the Hidden trail (Inner) |
    | RampagingTiger | cache_rampagingtiger | - | (313, 8.7, 628) | hunter's camp rise, beside the tent's south end, 17 studs off the camp's back (Inner, east) |
    | HeavenSplitter | cache_heavensplitter | - | (-100, 9.6, 816) | west foot of the Shrine Terrace's boulders, off the WestLoop (Inner, deep) |
    | DragonPierce | cache_dragonpierce | QC3 | (-302, 8.0, 685) | in front of the wolf den crag's south boulders (Inner, wolves) |
    | GreatSageAwakening | cache_greatsageawakening | - | (-77, 7.2, 1779) | at the SerpentGrotto's mouth, end of the Grotto trail (Middle, moved with the zone) |
    Re-seat the pedestals if the wilds terrain is re-run. The bamboo hollow, the
    WolfDenCave and the grotto are filled by BoulderPile hull colliders, so caches
    sit just outside them. The 2026-10-21 audit moved four that were unreachable or
    hidden: HeavenSplitter sat inside a boulder pile and a tree trunk, DragonPierce
    inside a boulder pile, GreatSageAwakening in the filled grotto (1 of 24 approach
    spots could see it), RampagingTiger half behind the camp's crates. After any
    dressing change re-run the audit (see "Editor-only markers and the POI tour"):
    each cache needs open standing spots within 8 studs with a clear line to the
    scroll, through visual meshes as well as colliders.
- Free (no code reads them): `Map.Markers.*` (except the tagged TeleportHome arrays and ManualCaches), `Map.Clouds`, `Map.Ground`, tags
  SwayBridge, WindShake, SkyLantern. Place-only: `ReplicatedStorage.BuildCatalog`,
  `ReplicatedStorage.HerbModels`, `ServerStorage.PeakStash`.
- Collision matches looks: raycast-check walkable areas in Edit mode after every
  change. Meshes follow `.claude/agents/modeler.md` (build script in `art/`, FBX +
  bounds JSON, batched import via `art/fbx_export/`, `place_*.luau`).

## Passes (in order)
1. **Collision holes** (done, `fcc1119`): spirit-peak lawns backed by
   `Pillar.LawnCollider` boxes (`art/lawn_collider.py`); main peak terrace,
   ledges, bridges and the rebuilt plaza raycast-checked with no holes. Not yet
   walked in play.
2. **Main peak landform** (`art/main_peak/build_main_peak.py`): warm rock with
   per-column value variation, lawns as jade slabs with turf lips, the 4-5
   planned cliff ledges instead of 14, terrace notches and mesa cleft for the
   two waterfalls, spring pools with rims. Delete the stray sky slab.
3. **Plaza rebuild**: block out hall terrace and courts in gray, capture from
   spawn and the stairs, then pave, wall and dress; recolour garland lanterns to
   lacquer/gold; group planters, lanterns and benches per court.
4. **Ring terrace, waterfalls and bridgeheads**: pools, falls (asset library
   waterfalls re-coloured), landings, pine clusters, VFX attachments.
5. **Spirit peak template**: Peak_1 focal terrace, signature tree, garden curb
   and path, edges, abode gate, bridge landing; replicate to Peaks 2-8.
6. **Lighting and night**: retune `DayNight.luau` KEYS to the palette above, place
   path/entrance lights under `Map.Sect.Ambience`, hand fireflies, mist, spray
   and lantern flicker to `vfx`.
7. **Detailing and distance**: moss, small rocks, flowers at edges; drifting
   clouds and far karst silhouettes; final day/night captures from spawn, the
   balcony, a bridge, a spirit peak gate and the summit.

## Known gaps
- Other WildsKit models had smaller pivot offsets (Wide_L 54 studs, Pine_A/C 36-38,
  CliffMass_2/3 33), so the current Inner and Middle trees and cliff masses stand up to
  that far from where the layout put them (their colliders follow them). Fixed in the kit;
  the dressing is only right after `dress_wilds.luau` is re-run (the Inner rework).
- No named attachment points for map VFX exist yet.
- The wilds read flat: low ridges and rims under open sky, no tall walls and no
  waterfalls on the ground. Needs a walls-and-water pass (see "Verticality").
- Wilds: only the Inner and Middle boxes south of the sect gate are built (see "Wilds
  zones"); the rest of those rings and the Outer Wastes still carry the old sprinkled
  ring dressing (zone separation, step 2 above). `art/karst/place_karst.luau`'s array
  clearance list still has the Inner/Middle arrays' old spots (524, -367), (-403, -1108).
- Under the sect: the path and array clearing have no lights or dressing yet;
  `FX_` attachment points for mist/fireflies there are still to place.
