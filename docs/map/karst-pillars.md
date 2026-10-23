# Map: karst pillars
The karst pillars round the sect (`Map.Karst`): kit, kinds, look, collision, composition and clearances. Read it before adding or moving pillars, or when a view or zone layout must clear them.

Tall stone pillars (Zhangjiajie silhouettes, house rock style) standing on the
ground and piercing the cloud sea, under `Map.Karst` (place-only). Kit from
`art/karst/build_karst.py` (live Blender or headless, scene "Karst"; same column
method as `art/build_peak_pillar.py`: 2D-Voronoi columns with stacked segments
and narrow grooves, light smooth, decimation, 28 deg creases), plain colours,
lawn tops like the peaks' lawns (faceted slab, bevel, straight turf lip).
`art/karst/place_karst.luau` places it (seeded, re-runnable; stages `kit`,
`layout`; `_G.KARST_BLOCKOUT` builds gray cylinders under
`Workspace._KarstBlockout` instead). `art/karst/gen_blocks.py` writes its MESHES
and KINDS blocks from `Karst.json`.

- Kinds: Needle, Spire, Tower, Mesa, Twin, Arch, Broken, Leaning, Stub, Trio
  (near, 2-4.4k rock tris) and KarstFar_Spire/Tower/Twin (~500-650). Each
  pillar = the upper piece from the joint (the local deck clump's mid height,
  ~Y 320-390) to its lawn tops, one trunk per leg from the ground (terrain
  raycast, sunk 12) to the joint. The deck hides the joint; the trunk is the
  same stone a touch darker.
- Look follows the peaks: rock Material/MaterialVariant/Color read from
  `Peak_1.Pillar.PeakRock` (each pillar a step lighter or darker), lawns the
  terrain LeafyGrass colour, pines/bushes the peaks' own library models (Map
  Detailing Pine Tree 2/3, Stylized Bush (Green)) on the lawn and ledge spots
  from the JSON: every spot on hero groups, up to 3 pines on other near
  pillars, none past r 1400 or on far kinds.
- Collision: everything visual is CanCollide/CanQuery/CanTouch/CastShadow off,
  Box fidelity. Each trunk has an invisible `Collider` cylinder from the ground
  to 90 above it (players reach the feet from the wilds); none past r 2250.
- Groups compose themselves (`compose` in the script): the first member is the
  hero at the group centre; each other member keeps its preferred side but
  stands just clear of every pillar already placed (a sky gap of 8-30 studs),
  trying nearby bearings and then further out when a spot breaks a clearance.
  No two pillars clip.
- Lawns: the rock tucks in under each turf lip (the lip overhangs by about
  70% of its bevel), columns step out a few studs lower, and every step-back
  leaves a ledge at least 9 studs (or 30% of the section above) past the rock
  above it. The flush ring under each lip is kept out of decimation.
- Kit 48,084 tris in 28 meshes.
- Mist: `FX_KarstMist` attachments where the deck wraps the first two pillars
  of each hero group and on the hero's first lawn ledge, with a
  `MistWisps` clone when `ServerStorage.AmbientFX.MistWisps` exists.

Composition (deg from +X toward +Z, as the clouds; r from the origin):

```
                         N (-Z, 270)
          Far_266 r1950    NorthBack 262/1150 (low, behind the spire)
   WestMesa 232/1000 (Mesa 900 hero)          NorthEastFar 285/1450
   NorthWestFar 240/1420                 NorthEastGrove 310/820 (5, by the cloud tower)
 NorthWestPair 205/1180                                  Far_301 r2100, Far_338 r2250
W  WestTrio 182/880           [ MAIN PEAK ]          EastArch 355/880        E
 (180)   Far_172 r1900          8 spirit peaks r300     EastForest 18/1250 (7)  Far_008 r1950
   SouthWestField 146/1100                        EastSentinels 40/560 (Twin 860 hero)
   SouthWestPair 140/650 (Spire 800 hero)               SouthEastFar 62/1500   Far_050 r2150
   SouthWestFar 118/1380   [wilds x-420..330, z200..1250: no pillars]
          Far_133 r2050       SouthHorizon 92/1500 (ends the balcony's south view)
                         S (+Z, 90)
```

- Heroes (r 560-1000) frame the views: EastSentinels and SouthWestPair either
  side of the balcony's southern view and its cloud gap, WestMesa (the tallest,
  top 900) west, NorthEastGrove beside the lone cloud tower, EastArch, WestTrio.
  Middle groups of 3/5/7 fill the windows between spirit peaks at r 1100-1500;
  far silhouettes at r 1900-2250 melt into the horizon banks.
- Clearances (the script warns on any): 140 from each plateau centre, nothing
  within 9 deg of a spirit peak's bearing inside r 1000 (bridge views), nothing
  over the wilds box (zones, qi nodes, sect gate and its route), 150 from the
  teleport arrays, the deck gaps + 40. The plaza's north axis behind the spire
  stays empty to r 1100.
