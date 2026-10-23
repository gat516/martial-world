# Map: main peak
The sect's main peak: plaza layout, courts, grand stairs, ring terrace, tribulation summit, waterfalls, landform and terrain colours. Read it before working on the plaza, the main peak or its scripts in `art/main_peak/`. Script-read coordinates are in [map](../systems/map.md) "Hard constraints".

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
