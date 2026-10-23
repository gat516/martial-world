# World: stylized shallow water (WaterKit)
The stylized shallow-water kit (`ServerStorage.WaterKit`): palette, templates, rims, foam, the `StylizedWater` animator, surface ripples and glints, preview. Read it when building or placing pools, meres or waterfall feet. Core: [world](../systems/world.md).

- Shallow water (lotus meres, the rimmed pools under waterfalls) is a stylized
  part, never terrain water: bright cyan cells split by white foam lines with a
  pale foam rim, as in `docs/reference/water_stylized_shallow.webp`. The palette
  follows the library waterfalls (Blue Waterfall's azure body and pale cyan
  splash), brighter than [map](../systems/map.md)'s muted water row: surface `#20AAE0`, depth
  blotches `#156AB6`, foam `#F2FCFF`, glints `#CFF6FF`. Templates are in
  `ServerStorage.WaterKit` (`assets/WaterKit.rbxm`, built by
  `tools/water_kit_build.luau`), placed by map passes:
  - `ShallowWater` (block) and `ShallowWaterRound` (upright cylinder): the
    surface part. Resize it to the pool and sink its top 0.3-0.5 under the
    bank; put a pool bed (sand or stone) 1-1.5 studs under the surface so
    players wade. No collision or queries (rays land on the bed). Opaque on
    purpose: a translucent surface is depth-sorted against the foam and splash
    particles by part centre and hides them. Three Top-face Textures that tile
    in studs, so any size keeps the pattern: `Depth` (70-stud blotches), `Cells`
    (22-stud cells and foam, the main read) and `Glints` (15-stud slivers),
    plus a `Glimmer` emitter of sun glints.
  - Any shape: union blocks/cylinders (Studio CSG) into one part and run
    `waterKit.dress(union)` (it copies the template's layers onto the face that
    points up; a union started from an upright cylinder faces up with Right).
  - `RimFoam`: one 16-stud rim segment (two flat Beams, `Foam` and a fainter
    `Lap` sliding the other way) with attachments `A0`/`A1`. Whole rims:
    `waterKit.rimPart(water)` round a block or cylinder, or
    `waterKit.rimAlong(parent, points, closed)` through shoreline points 0.06
    over the surface, 1 stud inside the bank. Walk the points
    counter-clockwise seen from above (bank on the right). Rim attachments point
    their X axis up: a non-FaceCamera Beam faces along its attachments' Axis,
    so identity attachments only lie flat along X.
  - `RockRipples`: rings spreading from a rock or post standing in the water;
    `waterKit.rockRipples(parent, surfacePoint, rockRadius)` sizes them.
  - `WaterfallFoam`: churned foam where a fall lands (a `Patch` decal, `Churn`
    foam blobs and `FoamRings` spreading out). Put it flat on the surface at
    the fall's foot together with `AmbientFX.WaterfallSpray` (spray, splash,
    droplets); map passes mark the spot `FX_FallSpray`.
  - `src/client/StylizedWater.luau` animates every part tagged `StylizedWater`:
    each Texture drifts by its `FlowU`/`FlowV` (studs/s) plus a slow
    `SwayU`/`SwayV` over `SwayPeriod`, times the script's `FLOW` (3) and `SWAY`
    (2.5), so one number retunes every placed pool (Cells flow ~1.2 studs/s, a
    cell passes in ~4 s). `Glints` layers also fade in and out (`GLINT_PULSE`,
    or a `Pulse` attribute). It runs from the server clock so clients agree, at
    30 Hz and only within 260 studs of the camera. Rim and foam beams scroll on
    the GPU (`TextureSpeed`). No server work.
  - Ripple rings and sun glints: `src/shared/WaterSurface.luau` samples the
    surface with rays, fills it with flat invisible boxes in a `WaterFX` folder
    under the water part (so particles stay on the water whatever its shape)
    and gives each a `Ripples` and `Glimmer` emitter rated by area
    (`RIPPLES_PER_100`, `GLINTS_PER_100`); the part's own `Glimmer` is turned
    off. The client rebuilds them on every water part at load. In Edit mode,
    `waterKit.surfaceFX(root)` builds them so the surface moves without Play
    (particles animate in Studio; Texture drift does not). Rerun it after
    resizing a pool. Built on `Workspace.Map`'s water and the preview.
  - Textures are drawn by `art/water/draw_water.py` (ids in
    `art/water/assets.json`). Preview: `Workspace._WaterPreview` (place-only),
    a sand island at (3240, 200, 3240) with a cloverleaf pool, a library Blue
    Waterfall off a cliff into it, rocks, lily pads and reeds.
