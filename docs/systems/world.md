# Weather, world events, treasures and ambience

## Purpose
A living world shared by the whole server: weather moods with small blessings,
heavenly treasures that fall during auspicious skies, world events that pull
everyone to one spot, and a day/night cycle.

## Design intent
- Weather is one shared event at a time, always returning to Clear between
  events. Rare phenomena (Auspicious Mist, Rainbow Aurora, Heaven Split) boost
  passive cultivation or circulation and drop treasures; rain and storms change
  the garden.
- World events are announced, visible from the peaks (pillars of light), and
  first-come: the first to claim keeps the prize. They should feel like a race:
  everyone sees it at once, runs for it and competes on arrival. Each zone keeps
  open event grounds for them (decided 2026-10-21, [map](map.md) "Zone shape").
- Ambience is client-side and in step across clients via the server clock.
- Day/night: DayNight blends hourly keyframes (soft warm day with blue distance
  haze, golden hour before the ~18:00 sunset, violet dusk, a desaturated indigo
  night lifted by exposure so dim phones still read paths). It owns the per-hour
  Lighting values, including a multiplier on the place's environment scales that
  fades sky light out at night (its stepped refresh made the night pulse); shadows,
  bloom size/threshold and the Sky stay as set in the place (GlobalShadows on, no
  shadow-casting point lights).
  Lamps (lights under `Map.Sect.Ambience`, or inside a model named in
  `Config.Ambience.LAMP_MODELS`) dim by day and brighten and reach further at night.
- Ambient world effects are templates in `ServerStorage.AmbientFX`
  (`assets/AmbientFX.rbxm`, built by `tools/ambient_fx_build.luau`), placed by
  map passes. Each is one invisible, anchored, non-colliding Part (the emission
  volume): move, rotate and resize it to fit.
  - `Fireflies`: fireflies + spirit motes over a lawn or garden (24x5x24;
    raise Rate with area). Night only (spirit motes keep a fifth by day).
  - `LanternGlow`, `JadeLampGlow`, `BrazierGlow`: halo, flame flicker (and
    embers/smoke) for the `_Templates` FX_StoneLantern / FX_JadeLamp /
    FX_Brazier. Pivot them on the flame:
    `glow:PivotTo(lamp:GetPivot() * CFrame.new(glow:GetAttribute("MountOffset")))`.
    No lights of their own (the lamp models carry those).
  - `MistWisps`: low drifting mist for cliff edges and the cloud-sea surface;
    the part's front face is the drift direction. Keep it just off the rock:
    particles have no soft edges and cut hard lines where they cross geometry.
  - `WaterfallSpray` (flat on the plunge pool where the water lands, front face
    away from the cliff) and `WaterfallLip` (thin strip on the top edge, front
    face out over the drop).
  - `FallingPetals`, `FallingLeaves`: under a flowering tree's canopy.
- Shallow water (lotus meres, the rimmed pools under waterfalls) is a stylized
  part, never terrain water: bright cyan cells split by white foam lines with a
  pale foam rim, as in `docs/reference/water_stylized_shallow.webp`. The palette
  follows the library waterfalls (Blue Waterfall's azure body and pale cyan
  splash), brighter than map.md's muted water row: surface `#20AAE0`, depth
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
  - `WaterfallFoam`: churned foam where a fall lands (a `Patch` decal, `Churn`
    foam blobs and `FoamRings` spreading out). Put it flat on the surface at
    the fall's foot together with `AmbientFX.WaterfallSpray` (spray, splash,
    droplets); map passes mark the spot `FX_FallSpray`.
  - `src/client/StylizedWater.luau` animates every part tagged `StylizedWater`:
    each Texture drifts by its `FlowU`/`FlowV` (studs/s) plus a slow
    `SwayU`/`SwayV` over `SwayPeriod`, from the server clock so clients agree,
    at 30 Hz and only within 260 studs of the camera. It scales `Glimmer`'s Rate
    once by surface area (`GlimmerPer100`). Rim and foam beams scroll on the GPU
    (`TextureSpeed`). No server work.
  - Textures are drawn by `art/water/draw_water.py` (ids in
    `art/water/assets.json`). Preview: `Workspace._WaterPreview` (place-only),
    a sand island at (3240, 200, 3240) with a cloverleaf pool, a library Blue
    Waterfall off a cliff into it, rocks, lily pads and reeds.
  Emitters tagged `NightFX` scale their authored Rate in DayNight's night step,
  between their `DayScale` (default 0) and `NightScale` (default 1) attributes.

## Key files
- `src/shared/Weather.luau`, `src/server/WeatherService.luau` (pick, set,
  `bonus(kind)`, `onChanged`), `src/client/WeatherFX.luau`.
- `src/shared/WorldEvents.luau` (defs, triggers, `MAX_RUNNING`, timer),
  `src/server/WorldEvents/init.luau` (framework: start, locate, announce,
  finish, publish to the `WorldEvents` workspace attribute) and kinds:
  `GuardedHerb.luau` (a giant herb under a guardian beast), `BeastSurge.luau`
  (more and bigger ambient packs via `Spawner.boost`), `AuspiciousClouds.luau`
  (Auspicious Clouds, Violet Cloud Mist, Golden Auspicious Clouds: clouds in the
  def's `look` gather around a sealed relic, a technique manual or a sword
  inheritance from `Effects.AuspiciousClouds.Relics`, at a wilds spot; meditating
  inside the ring uses the def's multiplier through `Meditation.addSite`;
  `condenseSeconds` before the end the seal breaks and the first claim learns a
  technique from the def's pool, or insight, and ends the event; the clouds are
  drawn client-side from the published position).
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
- `src/server/Treasures.luau`: treasures on the wilds' event grounds when weather with
  `treasures` starts; first claim keeps it. `Treasures.randomSpot` (also used by
  GuardedHerb and AuspiciousClouds) picks a random point within 0.9 of a random
  `Workspace.Wilds.EventGrounds` disc's `Radius` (`assets/Wilds.rbxmx`; tagged `POI`,
  Kind `EventGround`), raycasts to the ground and skips water, retrying up to 8 times;
  it falls back to the `Wilds.Zones` beast discs only when no event ground exists.
  Today's grounds are interim spots in the built boxes (Inner: Boar Meadow (230, 690)
  r 40, West Field (-160, 780) r 38; Middle: Graves Field (-220, 1050) r 32, South
  Flat (140, 1228) r 30) until the zone reworks place the planned ones ([map](map.md)).
- Placing event and treasure templates: keep the template's pivot rotation
  (`CFrame.new(spot) * template:GetPivot().Rotation`). `WorldTreasure`'s pivot is
  its `Ring`, a cylinder turned upright, so a bare `CFrame.new(spot)` lays the
  pillar on its side (AGENTS.md, "Luau pitfalls").
- `src/server/QiNodes.luau`: wilds qi nodes (raw qi + stones, per-player cooldown).
- `src/client/DayNight.luau`, `src/client/Music.luau` (zone music).
- `assets/AmbientFX.rbxm` (`ServerStorage.AmbientFX`), `tools/ambient_fx_build.luau`.
- `assets/WaterKit.rbxm` (`ServerStorage.WaterKit`), `tools/water_kit_build.luau`
  (`_G.waterKit`: build, dress, rimPart, rimAlong), `src/client/StylizedWater.luau`,
  `art/water/`.

## Data flow
WeatherService sets `Weather`/`WeatherEnds` on workspace and runs `onChanged`
hooks (Treasures, Garden, WorldEvents triggers). Clients read the attributes to
draw. World events start from a weather trigger, the timer, or the admin
dashboard, and end when claimed or after `minutes`.

## Tuning knobs
- `Weather.luau`: weight, minutes, bonus, treasures, garden effects, visuals.
- `WorldEvents.luau`: per-event minutes, triggers, kind settings; `MAX_RUNNING`, `TIMER_MINUTES`.
- `Config.Ambience` (day length, lights, particles), `Config.Garden.WILD_*`.
- `Pacing.Income.NODE_SHARE`, `NODE_COOLDOWN`; `Config.Economy.NODE_STONES`.

## Known gaps
- Nothing on arrival makes an event a contest beyond first claim. Event grounds are
  picked at random, not by where players are (map.md "Still to do" step 7).
- Only the Auspicious Clouds varieties have a timer `weight`, so they are the only
  events that start on their own (the timer rolls every 20-35 min).
- Stylized water: ground raycasts (Treasures, Spawner) skip only terrain water,
  so they can pick a shallow pool's bed under a `StylizedWater` part; check the
  tag there if treasures or beasts in pools look wrong. No wading slow-down,
  splash footsteps or ripples round a wading player yet. The rim needs points
  by hand for unions (`rimAlong`).
- Qi node prompts get their key and style set in code (TODO in QiNodes.luau) until
  `assets/Wilds.rbxmx` carries them.
