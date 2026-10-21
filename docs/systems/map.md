# Map: layout, art direction and constraints

## Purpose
The plan every map pass builds against: what each area is for, what players see
first, the palette and lighting mood, the assets to dress with, and the
instances and coordinates scripts depend on. `Workspace.Map` lives only in the
place file (not Rojo), so this doc and the commit bodies are its only history.

## World at a glance
Floating stone peaks above a cloud sea (deck tops Y ~405-455). The main sect
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
- **Zones in the same place, linked only by teleport arrays.** Each wilds zone is
  a small, dense area (a few hundred studs) far from the others in space, one per
  realm tier, opened by realm (`Regions` `realm`). Staying in one server keeps
  friends together and weather, treasures and world events server-wide. Keep
  the zone count low (2-3 to start) so 8 players don't spread too thin; add more
  only when the existing ones are full of content.
- **Arrays are the only way to travel** (`Shared.Gates`, `src/server/Travel.luau`).
  Players spawn on their own peak's array, respawn after death on the plaza's,
  arrive on the destination's, and can open the travel menu only while standing
  on one (any array, peaks included). Nothing teleports from anywhere.
- **Today:** the wilds are one continuous smooth-terrain field covering rings
  300-2200 around the origin (Inner, Middle, Outer). Each ring has one array
  (`Map.Markers.TeleportHome`), standing in for zone gates until the zones are
  rebuilt as separate areas.
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
3. **Zone edges:** cliffs, water or mist at the edge, plus an out-of-bounds
   return to the zone's array.
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
| Water | `#4E9FB2` | `#CFE6EA` (foam/rim) | `#2F6E80` | pools, falls |

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
- Edges get the most care: lawn-to-rock (turf lip, rocks, shrubs, moss),
  path-to-lawn (curb or stepping stones), bridge landings (posts, gate, pad).
- Cliffs: a few deliberate ledges of clearly different sizes, each with a reason
  (a pine, a shrine, a waterfall step). Never rows of same-size ledges.
- Mirror symmetry only on the ceremonial axis (plaza); everything else is
  asymmetric.

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
   z   62  |                 | garlands N-S at x+-16, z62..92     |
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
- Cliff faces (below Y 582): drop the 14 same-size `CLIFF_PINES` ledges. Use 4-5
  ledges of clearly different sizes: one big shrine ledge visible from a bridge,
  one waterfall step, two or three pine ledges in a cluster, plus a moss/vine band
  under the terrace lip. Rock gets warm gray with per-column value variation.
- Grass: lawns on the terrace, plaza ledge (Y 614) and mesa only, jade/sage per
  slab, an overhanging turf lip with rocks and shrubs breaking the edge.

## Spirit peak template
Peak-local frame (`Peak.frame`): origin at Plateau, "in" = toward the main peak
(bridge side), "out" = away from it. Plateau r 50, build space r 47, Y -30..+30.
Current layout on Peak_1: bridge gate at the inner rim (~44 in), garden grid
(60x60, 12 beds) in the middle, dwelling ~34 out, cave abode under the outer rim
(Y ~531), teleport array ~40 to one side, well/trough/name stele/spawn on the
other side.

- Arrival: from the bridge (first visit) or the teleport array (home). First
  view: through the bridge gate, across the garden, to the focal point.
- Focal point: the dwelling on a raised stone terrace (1-2 steps, low wall) with
  a signature tree behind it (one big pine or blossom tree, off-centre), so the
  view from the gate ends on house + tree. Moving starter pieces is allowed
  (changes the default layout); ids never change.
- Height: plateau lawn, garden sunk or edged by a one-step curb, dwelling terrace
  raised; the teleport array on its own small paved pad.
- Garden framing: a stone or wood curb around the grid, a path from gate to
  dwelling along one side (not through the beds), lanterns at the path's turns,
  a tool/barrel cluster by the trough and well (they belong together).
- Edges (r 47-56, outside build space): an overhanging turf lip, rock clusters
  and shrubs at three or four points (not all round), a low railing only where
  the drop faces the path. Keep starter-free dressing outside r 47 so it never
  blocks builds.
- Under-plateau gate (cave abode): give the cliff entrance a carved frame, a
  small ledge landing with two lanterns and a pine growing out beside it.
- Bridge landing: a paved pad inside the gate, two posts and lanterns on each
  side of the gate, rocks where the bridge meets the rim.
- Build every change on Peak_1, check it, then replicate to Peaks 2-8 by
  peak-local transform in one script; ids must match on all 8.

## Bridges between peaks
Rope bridges from the terrace bridgeheads (r 172.5) down to each peak's gate
(a ~28-stud drop over ~75 studs). Keep: dark wood planks with slight per-plank
shade change, rope sag, posts at both ends with gold caps and a lantern on the
peak end. Landings at both ends per the rules above. `SwayBridge` tags are free
(no code reads them).

## Cloud sea and ground
- Clouds are stylized cumulus meshes (`art/clouds/build_clouds.py`, run
  headless; `art/clouds/place_clouds.luau` lays them out, seeded and
  re-runnable from the kit in `ServerStorage.CloudKit`). Eight shapes (deck
  clumps A/B/C, DeckLong strip, Tower, Bank, Puff, WispArc) made of round
  billows with a flat base. A baked UV ramp (`CloudRamp.png`, the import's
  TextureID) gives every cloud cool shaded undersides and warm lit crowns.
  Fabric material keeps them matte (SmoothPlastic put shiny sun spots on
  every crown).
- Layers under `Map.Clouds`:
  - `Deck`: crowns with tops at Y 428-452 near the peaks, 416-440 to r 1150 and
    402-424 out to r 1800, plus a floor layer of flatter clumps ~30 lower
    (to r 1300) so the space between the crowns reads as more cloud.
  - Five deliberate holes in the deck (`GAPS`), one of them in the plaza's
    southern view at 100 deg, r 650. `UnderDeck` puts darker clumps ~70 lower
    in each hole (big + medium + small), so the holes show depth.
  - `Wisps`: two arcs and a puff around each spirit pillar (Y 430-515) and three
    stacked arcs around the main peak (Y 428-523).
  - `FallFoam`: puff clusters where the three main-peak falls (E, W, N) meet the
    sea.
  - `Banks`: mid-height clusters at 0/90/225 deg (r 430-620, Y 450-760) and a
    lone tower at 315 deg r 950. All of them are outside the bridges (r < 300)
    and the plateaus.
  - `Horizon`: banks at r 2100-2600 and towers at r 1500-1800. They mostly melt
    into the Atmosphere haze, so they show only when the haze is thin.
  - `Auspicious` (12 swirl clouds) and `Emitters` (20 CloudLineFog emitters)
    are kept from the old pass.
- Budget: ~300 parts, ~400k tris before LOD (RenderFidelity Automatic), 8
  unique meshes. Every cloud part is anchored, with CanCollide, CanQuery,
  CanTouch and CastShadow off, and CollisionFidelity Box. Players fall
  straight through the sea to the ground. The deck ceiling sits at Y 290-455,
  far above the ground route and the sect gate.
- Mist VFX spots (Attachments): `FX_PillarMist` x27 (pillar and main-peak
  wisps), `FX_FallMist` x3, `FX_BankMist` x3. Clone
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
  eight old hanging terrain columns at r ~212 (in front of the main rock's
  face, Y ~90-350) are left as they are: one shows in the slot view from the
  path and reads as floating (owner: main peak pass).
- Safety: `Regions` Sect ring is 0-410 (no ambient beasts under the peaks);
  the Ascension Array is a real array (any destination from it), and the gate
  array at (48, 6, 470) is a walk south. No fall damage exists.
- Peak roots (built in Blender, waiting for the FBX import): `Map.Ground.PeakRoots` (Zhangjiajie flared feet,
  `art/ground/build_roots.py` + `place_roots.luau`): one mesh cloned to all
  eight pillars, a separate one for the main rock with a notch at the array.
  Non-colliding, except a hull collider for the bottom ~40 studs.

## Asset catalogue
All under `ServerStorage.AssetLibrary` unless noted. Clone, don't move, the
originals; re-colour to the palette.

| Need | Pieces |
|---|---|
| Lanterns, lamps | `_Templates.FX_StoneLantern`, `FX_JadeLamp`, `FX_Brazier`; `Stylized Asset Pack I/Stylized Wooden Props I/Stone Lamps` (Stone Lamp 1 4x7, Stone Lamp 2 4x16); `Stylized Asset Pack I/Stylized Props/Stylized Lamp Post` (2x16); `Map Detailing`: Lanterns 1/2/3 (hanging strings ~15 tall), Lantern 1/3/4 (small), Latern 2; Inno `Wood_Iron_Assets/Lantern_Pole`, `Lantern` |
| Rocks | `Stylized Rock Packs`: Cliff Rock Pack I (Cliff Rock I-III, 10-17 wide), Cliff Rock Pack II (Cliff Terrain Rock 45-70 wide: big edge masses), Fantasy Rocks (Rock I-V, 10-20), Stone Rock Pack (Single Stone 1-5 wide, standing stones); Inno `Customizable_Assets/Rocks` (Rock_01..Rocks_07, Presets 01-06 clusters 30-46 wide) |
| Shrubs, ground cover | `Stylized Foliage + Pots/Stylized Bushes` (Green 7-34 wide; Orange for autumn accents only); `Plants + Pots` (Ferns, Leaf, Reeds, Mush, Pot & Flower); Inno Foliage (Bush1/Bush2), Clovers 01-03, Flowers (Blue/Pink/White/Yellow beds), Mushrooms; Map Detailing Bush Pink/White/Yellow flowers (6x5x9) |
| Trees | Inno `Pine_Trees` Variation_01-06 (4 sizes each, 33-45 wide, 57-75 tall: the best chunky pines); Map Detailing Pine Tree 1-5, Tree 3 realistic, Tree 2 realistic, Small Tree 1-3; `Stylized Tree Pack` (Light/Dark Green 43 tall, Wide, Orange, Wind Physics); `_Templates.BambooCluster_1..3`; `Tree Log Stumps` |
| Fences, rails | Stylized Wooden Props II `Stylized Fence` (Full Fence, Fence Pillar 7 tall); `Stylized Props/Bamboo Fence (modular)`; Inno `Fences/Fence_01..03` (7x4); Map Detailing Asset Pack Fence1-3; `Lighting Fence` |
| Paths, edging | `Textures` (Pavement I-III, Tiles, Ground I/II, Grass I/II, Wood Planks; reference swatches for colours); Map Detailing Pebble, Stone (8x1x8 stepping), Inno Logs |
| Water edges | LilyPads (W Flower 7 wide), Inno Lilypads 01-06, Reeds; `VFX`: Blue Waterfall (28x80), WaterFall Main (26x62), Stylized Rock Formation Waterfall (87x74), Map Detailing Stylized waterfall 2/3, Water Fountain, Wells (Clean Blue, Mossy Green) |
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
  "SectGate" (48, 6, 470), `TeleportHome_Inner`/`_Middle`/`_Outer` "InnerWilds"/
  "MiddleWilds"/"OuterWilds", each peak's `TeleportArray` "Peak". Arrivals land 4
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
- Tribulation: `Config.Tribulation.CENTER` (2, 857, -86), ARENA_RADIUS 34; the
  floor raycast from CENTER+20 down 60 (CanCollide parts only) must hit the
  walkable floor (TopSurface, Y 855.3) (`Tribulation.luau`). Effect parts above
  the floor (TribulationLightning) must stay CanCollide off.
  Keep a walkable floor >= 34 radius at Y ~855.5 with clear air, or update Config.
- Day/night lights: `DayNight.luau` scales only Lights under the first recursive
  "Ambience" under Map (`Map.Sect.Ambience`). Never add another "Ambience".
- Regions: Y >= 150 is the safe sect; rings Sect 0-410 (the under-sect floor
  included), Inner 410-900, Middle 900-1600, Outer 1600-2200 (`Regions.luau`).
  SECT_GATE (0, 9, 500).
- Wilds zones and qi nodes (positions in `assets/Wilds.rbxmx`) are leash and
  spawn homes; ground raycasts (spawns reject Water, treasures, placement) need
  real collision under them.
- Free (no code reads them): `Map.Markers.*` (except the tagged TeleportHome arrays), `Map.Clouds`, `Map.Ground`, tags
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
- No named attachment points for map VFX exist yet.
- The wilds look beyond the under-sect floor is unplanned beyond keeping Wilds
  anchors (separate pass).
- Under the sect: the path and array clearing have no lights or dressing yet;
  `FX_` attachment points for mist/fireflies there are still to place.
