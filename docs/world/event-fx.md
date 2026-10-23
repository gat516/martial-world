# World: event and treasure effects
How world events and heavenly treasures are drawn on clients: the Auspicious Clouds kinds (WorldEventFX), the treasure birth sequence (TreasureFX) and the shared WorldFX kit (templates, SkyGrade, preview). Read it for world-fx or vfx work on events, anomalies and treasures. Design decisions are in [world](../systems/world.md) "Design intent"; the look recipe in [style](../vfx/style.md).

- `src/client/WorldEventFX.luau` draws the AuspiciousClouds kinds from the
  `WorldEvents` attribute: it clones `Effects.AuspiciousClouds` (`assets/Effects.rbxm`,
  built by `tools/vfx_specs/AuspiciousClouds.luau`) locally at the event's `at`: the
  def's `look.pattern` Model (`Vortex`, `Mist`, `Spiral`: turning layers of
  Cloud_WispArc wisps) plus the shared `Ring` (scaled to `radius`), `Column` and
  `Whirl` (light column and a whirl of wisps on the cloud plane, seen from the peaks)
  and `Eye` (the seal round the relic, the unseal burst, the glow), tinted from
  `look.color`/`look.accent`. Wisps descend over 8 s, turn every frame (one
  BulkMoveTo), pour into the relic over the 4 s before `ends - condenseSeconds`,
  when the seal shatters, and rise and fade when the entry goes. It also bobs and
  turns the server's relic (the Model named after the def id in `Workspace.Wilds`).
  `Effects.AuspiciousClouds.Relics.Manual`/`Sword` are the server's relic templates
  (`CoreHeight` 5/6, disabled `ClaimPrompt`, `Label` billboard).
- Heavenly treasure birth (TreasureFX, 2026-10-21), coloured by the anomaly (violet for
  Auspicious Mist, pearl for Rainbow Aurora, gold for Heaven Split). The opaque cloud
  plane splits the audience, so it plays above and below it: 0-2 s a glint and a
  `SkyRift` tear open at Y 1150, 140 studs to one side of the spot (seen from the peaks),
  and a glint and faint seam appear in the cloud ceiling (seen from the valley); 2-6.5 s
  the `Meteor` arcs down out of the high rift, and where it crosses the plane the ceiling
  rift (24 under the plane, beams x2.2) tears wide and rains light; 6.5 s impact: Landing
  flash, glint, lens, shock ring and rays, the `LightPillar` drives down in 0.6 s, a gentle
  white pulse within 150 studs and a small camera shake within 80; then the `SkyCircle`
  (r 110, 40 under the plane) opens ring by ring, the rifts heal over 3 s, two `CloudRing`
  layers settle down from above at Y 70 and 130 and turn, and the `GroundCircle` sigil,
  mist and light play round the treasure. When it leaves the attribute (claimed, or the
  weather ended) the pillar pulls up into the sky, the circle shrinks out and the arcs
  fling outward over 2.5 s. The pillar's colour layers widen, brighten and turn additive
  with camera distance (300-1200 studs) so the hue survives the haze, and thin out within
  ~80-320 studs so it isn't a wall of light. While any treasure is up `SkyGrade` caps
  Atmosphere density at 0.28 and haze at 1.0 (`TreasureClear`), and within 120-340 studs of
  one the air leans to the anomaly's colour (`TreasureNear`). Layers by camera distance:
  far always (pillar beams, puncture, sky circle, rifts, arcs), mid within 650 (streaks,
  motes, flow, arc mist, rift flicker, shards, rain), close within 300 (ground sigil
  emitters, mist bank, light). Joining mid-birth skips the bursts and fades in over 1.5 s.
- World FX kit (2026-10-21): templates in `ReplicatedStorage.WorldFX` (binary
  `assets/WorldFX.rbxm`, built by `tools/worldfx_build.luau`, staged in
  `ReplicatedStorage._StagingWorldFX`; `_G.worldfxStage.begin/finish/synced`). Runtime in
  `src/client/WorldFX/`: `Kit.luau` (clone, upright `place` that keeps the pivot rotation
  and honours `WorldY`, palette `paint` by `Tint`/`TintMix` attributes, beam width and fade
  from the authored values, `emit` honouring `EmitCount`/`EmitDelay` without the Game
  Module, one-BulkMoveTo `move`/`flush`, a replaceable `now` clock) and `SkyGrade.luau`
  (DayNight calls `SkyGrade.adjust(k)` right after `WeatherFX.adjust(k)`; contributions
  lean tint, atmosphere colour, density/haze caps, brightness, exposure, saturation and
  contrast, each with a weight; pulses go on `Lighting.WorldFXGrade`, a clone of
  `WorldFX.Grade`, never on DayNight's grade). `Kit.planeY()` reads the cloud plane's top
  from `Map.Clouds.Plane` (it was at Y ~339.6 on 2026-10-21, not the 440 [map](../systems/map.md) gives;
  `PlaneOffset` attributes sit relative to it). Templates: `Grade`; `LightPillar`
  (Core/Body/Haze/Flow beams to world Y 1400, rising Streaks and Motes in the lower 400
  studs, a Puncture ring and billows just above the cloud plane, a Landing burst);
  `SkyRift` (a 150-long jagged crack: per segment a white-hot Lip, a coloured Glow and a
  dark nebula Void, revealed from the middle by each beam's `Seg`; a Glint and Lens at the
  eye, Flicker, Shards and a Rain of light falling); `Meteor` (head Glow, Halo, Sparks
  and a Tail trail); `SkyCircle` (rings turning on a disc's underside: a meander ring, a
  hexagram array, a glyph ring and a star over an ink disc, by each ImageLabel's `Speed`);
  `GroundCircle` (an ornate sigil and rune circle on an ink disc, core Halo/Flare and a
  PointLight, Motes, Twinkles, Petals, a mist Bank over a dark Under layer); `CloudRing`
  (two counter-turning layers of three `Cloud_WispArc` clones, tinted through a
  SurfaceAppearance with the cloud ramp as ColorMap and `AlphaMode` TintMask, each with a
  coloured mist Puff). Emitters with a `Layer` attribute ("far", "mid", "close") are
  switched by camera distance. Preview:
  `tools/worldfx_preview.luau` (`_G.worldfxPreview`: fresh module copies pointed at the
  staging templates and a fake clock, `spots(n, seed)` from the real EventGrounds,
  `pillar`, `look`, lighting presets `day`/`night`/`mist`/`clear`, `clear`); everything
  goes in `Workspace._WorldFxPreview`.
