# Map: wilds zones (Inner Wilds and Ruined Borderlands)
How the first two wilds zones are built today: boxes, the `art/wilds/` script order, the layout map, heroes, landforms, collision, lights, VFX points and encounter spaces. Read it before any wilds map pass. The Inner valley plan and its build log are in [inner-wilds-rework](inner-wilds-rework.md).

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
phases 3-4 (pockets, finds, water, POI pass, dressing) have since been built ([inner-wilds-rework](inner-wilds-rework.md)). Reference: a sandy path sunk between grass banks under
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

The map below is the layout before the rework (Inner before phase 2, Borderlands before the
(+220, 0, +700) move): use it for the Borderlands' internal layout and names, and
[inner-wilds-rework](inner-wilds-rework.md) for where things are now.

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
  `Treasures.randomSpot`; see [world](../systems/world.md));
  the Deserters' Camp is an outpost site for 3-5 enemies; ambush spots are the Hidden cleft,
  Giants Gully, the border gate, Bone Gully and the arena gate.
- POI audit (2026-10-21, see [editor-markers](editor-markers.md)): the Stone Rock Pack's
  "Single Stone" models keep their WorldPivot ~485 studs from the mesh, so every `PivotTo`
  dropped the stone far from its spot: the Wolf Den's eight ring stones lay scattered from
  (-939, 473) to (212, 1155) and 155 Middle dressing pieces (path stones, ground cover,
  shrubs, 4 colliding rocks) sat off their spots. All 163 were moved onto their intended
  spots (the pivot's X/Z) and grounded; 44 more (spirit-peak foliage, cache dressing) only
  had their pivots reset. `dress_wilds.luau` now pivots every kit model at its bounding
  box's bottom centre, as does the Studio `ServerStorage.WildsKit`. Also moved: four caches
  ([map](../systems/map.md) "Hard constraints", caches table), a tree and bush that hid QiNode2, the trunks round two caches
  (to `ServerStorage._InnerWildsReplaced`), and ten lamps and lanterns floating 1-5 studs
  up (QiSpringShrine's jade lamps, BambooHollow, BorderBridge, ShrineTerrace stair foot,
  Graves, BrokenPagoda).
