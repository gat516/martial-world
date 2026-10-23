# Map: cloud sea
The cloud sea under the peaks (`Map.Clouds`: plane, wisps, mounds, banks, budget, mist spots). Read it before adding or moving clouds, or when an effect must sit on the cloud plane.

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
- Karst pillars rise from the ground through the deck around the sect (see
  [karst-pillars](karst-pillars.md)). The ground below is in [under-sect](under-sect.md) and
  [wilds](wilds.md) (`Workspace.Wilds` is Rojo-mapped: staging only).
