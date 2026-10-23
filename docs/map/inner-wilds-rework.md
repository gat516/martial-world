# Map: Inner Wilds rework, the walled valley
The Inner Wilds walled-valley plan (proposed 2026-10-21) and its build log. Phases 1-4 (Borderlands move, layout and terrain, walls, POI prefabs, pockets, finds, water, POI pass, dressing) are built as noted in each section; anything not marked built is still the proposal. Read it for any Inner Wilds pocket, wall, water, find or POI work.

Plan approved in direction; walls are built from scaled-up library cliff rocks, one
test stretch first (below). It turns the Inner Wilds into a walled valley per [map](../systems/map.md) "Zone
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
  separation" step ([map](../systems/map.md) "Still to do" step 2). The user is open to moving anything else the layout needs.
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
ring), WolfPocket (-170, 880) on the G1 shortcut, GateWolves (-36, 488) (2 Spirit Wolves,
r 18: the onboarding FirstKill target on the lawn west of the gate road, in front of the
NorthWest karst foot, 86 studs west of the Sect Gate array and in view from it; added
2026-10-21; dressed with a three-boulder cluster, `WildsInner.Dressing.GateWolves`), BoarMeadow (420, 790) by the boar
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

**Phase 3 as built (2026-10-21; stopped for the user's own POI pass).** Run in Edit mode,
in this order, after `terrain_wilds.luau`: `water_inner.luau` (builds the Twin-Jade notch
rocks), `place_pockets_inner.luau`, `water_inner.luau` again, `place_finds_inner.luau`,
`ambience_inner.luau` (needs `tools/water_kit_build.luau` first for `_G.waterKit`).
- Pockets (`Map.Ground.WildsInner.Pockets`): the POI builder's prefabs from
  `ServerStorage.InnerWildsPrefabs` (WolfDen at (-700, 786), WolfDenRing round the boss
  disc, WolfDenRockGate on the WestArm at (-480, 760), BambooHollow under the north wall
  at (-330, 590), FallenGiant over the gully, HuntersCamp at (660, 702), the hermitage at
  (-566, 1176), LotusMere, ShrineTerrace at (-62, 1325) in front of the Shrine Cliff,
  TwinJadeSpring under the Twin-Jade falls). Each is seated on the lowest ground round its
  footprint's rim, digs its own `TerrainCarve` discs, keeps its POI tag and is flagged
  `NeedsHandPass`. The terrain knolls and the den cave they replace came out of the layout.
- Finds (`Map.Ground.WildsInner.Finds`): F01-F31 at their planned spots, front toward the
  nearest path, pushed off paths and out of pockets, tagged `POI` (structural ones
  `NeedsHandPass`).
- Water (`Map.Ground.WildsInner.Water`): the Jade Veil falls through the test stretch's
  notch into a WaterKit pool; the Twin-Jade notch (three giants, a lip and seams, 25 studs
  in front of the SouthEastFar karst, whose trunk collider is r 96) with two ribbons into
  the TwinJadeSpring prefab's pool; trickles down the West wall (den), the East wall and
  the north wall into the Bamboo Hollow's spring; the Lotus Mere's water is the prefab's.
  Every fall foot has WaterKit foam, `WaterfallSpray`, `WaterfallMist` (PlungeBillow at the
  hero falls) and AmbientSound anchors.
- Caches sit on their pocket's `CacheSpotAnchor`; QiNode3, 6 and 7 on the prefabs'
  `QiNodeSpotAnchor`s (Wilds.rbxmx).
- FX and sound (`Map.Ground.WildsInner.FX`, plus the prefabs' own `FX_*`/`SND_*` anchors):
  AmbientFX clones with Rate scaled by area (den and ring mist, bamboo light, qi spring,
  lotus, fireflies, incense, lantern and fire glows, small glows), 33 `RimVeil` banks past
  the wall backs, and `AmbientSound` anchors (`Sound` = template) for falls, pools, the
  river, bamboo, the den, the shrine and hermitage bells, the camp, the mere, birds and
  insects in pairs over open ground, rim wind along the crests and high wind at the flyer
  spots. Left for `vfx`: anchors without a template (DenEyes, FoxEyes, Dragonflies,
  LookoutFlag, SpireGlint, SwordGlint) and sounds without one (BoarGrunt, SwordHum,
  BannerFlap, ClothFlap, WoodCreak, the prefabs' SND_Wind).
- Clearance check (report only, the user is doing a POI pass before any rock or tree
  moves): wall seams overlap the Bamboo Hollow and the Fox Hole; the SouthWestFar and
  SouthEastFar karst colliders reach into the hermitage and the Twin-Jade spring; seam
  rocks stand in front of the den, east and Bamboo trickles; a giant overhangs the
  Twin-Jade pocket (user report); Wall_SouthEast26_Giant blocks the SouthEast path at the
  gorge gate, Wall_S11_CornerFoot the GorgeRoad, the Twin-Jade notch giants the end of the
  SouthEast path; an old MiddleRing dead tree stands in the Wolf Den. Each is tagged
  `NeedsHandPass` with what blocks it (`T.handpass()`).

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

**Phase 4: dressing (2026-10-21).** `dress_wilds.luau` re-run over the whole valley
(about 6,300 pieces, 11,000 parts: 996 trees with 929 trunk colliders, 208 bamboo stands, 786
rocks, 1,844 shrubs, 411 ground cover, 1,921 path-edge pieces).
- Bamboo grows only in the layout's `groves` (the Bamboo Sea's four circles round Old Stone
  Hill, small groves behind the steles, by the shrine, the Lotus Mere and the Twin-Jade
  spring): dense `Stand`/`Giant` templates (BambooCluster_12-15) in the Sea, `Clump`/`Accent`
  ones (4-7, 10) in the small groves, `Edge` ones (8, 9, 11, 16) in a 10-stud band round each.
  The noise sprinkle is gone; template Models keep their own colours.
- Nothing grows inside a placed pocket, find or water group (their box + 6, trees + 16), a
  wall rock's footprint or a karst trunk collider; the event grounds are clearings with low
  cover only; trees stand well back from the spine (the hero view to the Shrine Cliff).
- The forest is an open one for this size (tree chance about half the old box's), so
  pockets and walls read from the paths and from the air.

**Inventory of the Inner box before the rework** (x -450..430, z 470..900, Y < 300;
1,867 models and loose parts): `Map.Ground.WildsInner.Dressing` 1,827 (Trees 386,
Colliders 360, PathEdge 548, Rocks 256, Bamboo 144, Shrubs 97, GroundCover 36);
`WildsInner.POIs` 9; `Map.Markers` ManualCaches 4, TeleportHome 2, TideSpawns 13,
TideRally 5; `Wilds.Zones` 4 (WolfPocket, WolfDen, BoarMeadow, BoarField); `Wilds.QiNodes`
3. No loose pieces at the Workspace root or in `Hub`. Terrain (20-stud samples): Grass
565, LeafyGrass 327, Water 92, Ground 88, Mud 40, Sand 31, Pavement 7; floor Y 3-8,
ridges to Y 26. The wider footprint is flat terrain (Y 1-6) with scattered pools and old
fissures to Y -20.
