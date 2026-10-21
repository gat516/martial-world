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
- Event and anomaly arrivals are the game's loudest effects, readable from
  across the map: a formation array opening in the sky, a light pillar driving
  down into a ground circle, clouds spiralling in, gold streaks and glints in
  the air (the user's Enkidu "Enuma Elish" reference, 2026-10-21). Recipe in
  [docs/vfx/style.md](../vfx/style.md), "World events and anomalies".
- World-event look pass (plan approved 2026-10-21, `docs/vfx/world_events_plan.md`):
  every event and anomaly is composed from one shared kit (light pillar, sky circle, sky
  crack, cloud rings from the wisp arcs, ground circle, sky grade), recoloured and timed per
  event. Decisions: world effects live in their own file (`ReplicatedStorage.WorldFX`, not
  `Effects`); while an anomaly animates its copy of `Map.Clouds.Wisps` the client hides
  the real ring locally; treasures lose the Neon pillar and their claim waits ~7 s for the
  landing; screen effects stay gentle (a soft white flash when the heavens tear, an impact
  frame or shake only near a landing); the sky clears (Atmosphere density and haze capped)
  while a far layer is up; Beast Surge is a crimson vortex at the valley centre; Ginseng
  publishes a guarded/free `state`; tribulation clouds are not part of it.
- Far read (tested 2026-10-21): from the peaks the event grounds are 1000-1900 studs
  away. At the default Atmosphere (density 0.36) only an additive white core survives that
  distance; colour needs density ~0.28 and haze ~1.0, which `WorldFX.SkyGrade` applies,
  weighted by the event's phase, whenever a far layer is up.
- Ambience is client-side and in step across clients via the server clock.
- Day/night: DayNight blends hourly keyframes (soft warm day with blue distance
  haze, golden hour before the ~18:00 sunset, violet dusk, a desaturated indigo
  night lifted by exposure so dim phones still read paths). It owns the per-hour
  Lighting values and zeroes the place's environment scales: the engine refreshes
  sky light in steps as the clock turns, which made the night pulse and the day sky
  flicker. A steady cool fill on OutdoorAmbient (`SKY_FILL` in DayNight, scaled by
  each key's `sky`) stands in for it, so reflections no longer pick up the skybox.
  Shadows, bloom size/threshold and the Sky stay as set in the place (GlobalShadows
  on, no shadow-casting point lights).
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
  - Inner Wilds set (2026-10-21; map anchors in brackets). "Scale Rate with area"
    means multiply every emitter's Rate by placed area / authored area.
    - `WaterfallMist` [`FX_FallMist`]: upright slab on the fall's face, front face
      out from the cliff; 12x24x2 authored. Hero fall (Jade Veil, ~40 tall): about
      20x38x3, Rates x2.6. Trickles: 4x14, Rates x0.3.
    - `PlungeBillow`: white billows rolling up and out at a hero fall's foot, on
      top of `WaterfallSpray` + `WaterKit.WaterfallFoam` [`FX_FallSpray`]; flat on
      the pool, front face away from the cliff, 16x2x8. Trickles skip it; at a
      trickle use `WaterfallSpray` alone, shrunk to the water's width.
    - `SpiritMotes` [`FX_Fireflies` at the shrine, the hollow]: jade-gold motes
      rising slowly plus twinkles, 20x6x20. Half rate by day, so they read in
      daylight; add a `Fireflies` clone for the night in gardens and the hollow.
    - `ShrineIncense` [`FX_ShrineIncense`]: one thin curling smoke ribbon and
      glowing tips; put the 0.4 part at the stick tips, one per censer.
    - `QiSpring` [`FX_QiSpring`]: jade motes, curling qi wisps and faint rings
      off a spring pool; flat on the water, 16x1x16, scale Rate with area.
    - `DenMist` [`FX_DenMist`]: low cold blue-grey mist; centre ~3 above the
      floor, 40x2x40, front face is the drift. Particles are squashed flat and
      kept level so they don't cut hard lines into the ground. Thicker at night.
    - `BambooLight`: slender leaves drifting down, dust motes and soft slanted
      light shafts. Size it to the open air under the canopy (30x16x30); tilt
      the part 10-25 degrees toward the sun to slant the shafts (they follow its
      down axis). Shafts and motes fade at night (DayScale 1, NightScale 0.1).
      Shafts need dark canopy or stems behind them; against open sky they vanish.
    - `LotusMere`: pink petals floating flat on the water, golden pollen,
      small ripples; ~0.1 above the surface, 30x0.2x30, scale Rate with area.
      Add a `Fireflies` clone over the mere for night.
    - `RimVeil`: a slow bank of big cloud billows (radius 20-32, ~9 alive) for
      the outer side of the valley walls, so flyers see cloud past the crest
      instead of the walls' backs. 20-40 studs outside the backs, centred at
      about crest height (lower and the wall hides it), 10+ off rock, one per
      ~80 studs of wall (~30 for the Inner ring, ~270 particles in all, few on
      screen at once). The existing `FX_RimMist` clones (`MistWisps`, 70x10x30
      at Y 24) sit too low to hide anything from the air; keep them as foot
      mist or replace them with `RimVeil`.
    - Preview: `Workspace._FxPreview` (place-only, over the cloud sea): a hero
      fall at (3550, 200, 3700), shrine (3640, 3700), spring (3720, 3700), den
      mist (3800, 3700), bamboo (3620, 3790), mere (3740, 3790), wall + veil
      (3850, 3790). Cameras: fall (3565, 214, 3762) to (3550, 216, 3690); shrine
      (3632, 206, 3712); bamboo (3655, 215, 3800); mere (3725, 208, 3815); veil
      from the air (3850, 400, 3900) to (3850, 280, 3700). Edit mode doesn't run
      the emitters' Rate between MCP calls, so emit by hand to see them.
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
  Emitters tagged `NightFX` scale their authored Rate in DayNight's night step,
  between their `DayScale` (default 0) and `NightScale` (default 1) attributes.
- Ambient sound (2026-10-21): positional soundscapes from templates in
  `SoundService.Ambience` (`assets/SoundGroups/Ambience.rbxm`, built by
  `tools/ambient_sounds_build.luau`), played client-side by
  `src/client/AmbientSounds.luau` through the `Ambience` SoundGroup, which the
  Settings sound slider scales with SFX. Design: looped beds plus sparse random
  one-shots so nothing drones; one-shot calls are random slices of long field
  recordings (birds, frogs), so a call rarely repeats.
  - **Anchor contract (for map passes).** An anchor is any Part, Attachment or
    Model in Workspace (inside `Workspace.Map` is fine; it may stream) tagged
    `AmbientSound`, with attributes:
    - `Sound` (string, required): the template name below.
    - `Volume` (number, default 1): multiplies every layer.
    - `Radius` (number, default the template's): audible range in studs; every
      layer's roll-off scales with it. Use it to size a trickle or a big grove.
    - `DayOnly` / `NightOnly` (bool): fade the whole anchor with night.
    The sound comes from the anchor's position (part centre, attachment, model
    pivot); one-shots scatter around it. Only the 10 nearest anchors within
    range play, so a few well-placed anchors beat many: one per waterfall, one
    per pool or stream reach, one per ~100 studs of grove, wall or valley floor.
    Invisible, anchored, non-colliding, `CanQuery` off parts are the easy way.
  - **Templates** (Radius in studs; L = loop bed, S = random one-shot):

    | Template | Layers | Radius | Where |
    |---|---|---|---|
    | `WaterfallHero` | L heavy churn + L wide roar | 220 | Jade Veil, Twin-Jade: at the plunge pool |
    | `WaterfallTrickle` | L small fall | 80 | den, Bamboo Hollow and other trickles |
    | `Stream` | L stream flow | 60 | along streams, one per ~60 studs |
    | `PoolLap` | L small waves | 40 | pool and mere edges |
    | `BambooGrove` | L leaf rustle, S bamboo knocks, S gusts | 90 | Bamboo Sea, groves |
    | `RimWind` | L low blustery wind | 260 | wall crests, rims |
    | `HighWind` | L whistling gusts | 400 | lookouts, high places |
    | `DayBirds` | L light birds, S calls (day only) | 150 | open valley, groves |
    | `NightInsects` | L crickets, S owl (night only) | 150 | open valley |
    | `MereFrogs` | L frog chorus (night), S croaks | 100 | Lotus Mere, marshy edges |
    | `DenWind` | L hollow wind, S distant wolf howl (45-130 s) | 150 | Wolf Den |
    | `ShrineBells` | S chimes, S deep bronze bell (45-100 s), S hand bell | 120 | Shrine Terrace, wayside shrines |
    | `Campfire` | L crackle | 45 | Hunter's Camp fire |
    | `QiSpring` | L low resonant hum, S sparkle | 60 | Qi Spring, qi nodes |

    Day birds and night insects usually go together: put a `DayBirds` and a
    `NightInsects` anchor at the same spot. `ValleyBed` is not for anchors: it
    plays flat and quiet (wind, distant birds by day, insects by night) under
    the zone music whenever the camera is down in the Wilds.
  - Layer attributes (on the template's Sounds; tune in the builder):
    `DayOnly`/`NightOnly`, and for one-shots `MinGap`/`MaxGap` (seconds),
    `Scatter` (studs), `Jitter` (speed spread), `Slice` (seconds of a long file).
  - Preview: `Workspace._SoundPreview` (place-only), one labelled ball per
    template in a row at Z 3900, X 3600-3900, Y 200 (`RimWind` at Y 240). The
    script only runs in Play, so the loops need a Play session; walk or fly the
    camera along the row.

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
  `treasures` starts; first claim keeps it. Each birth is published in the workspace
  attribute `HeavenlyTreasures` (JSON `{ key, at, color, weather, born }`) and drawn by
  every client (`src/client/WorldFX/TreasureFX.luau`), since streaming keeps the server
  model from players on the peaks. The server model (`WorldTreasure` without its Neon
  `Pillar` and `Ring`: the orb, prompt and label) is parented only at `born + Treasures.LAND`
  (7 s), so the claim waits for the landing.
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
  emitters, mist bank, light). Joining mid-birth skips the bursts and fades in over 1.5 s. `Treasures.randomSpot` (also used by
  GuardedHerb and AuspiciousClouds) is `src/server/EventGrounds.luau`'s `randomSpot`: a
  random point within 0.9 of a random `Workspace.Wilds.EventGrounds` disc's `Radius`
  (`assets/Wilds.rbxmx`; tagged `POI`, Kind `EventGround`), raycast to the ground,
  skipping water, up to 8 tries; it falls back to the `Wilds.Zones` beast discs only when
  no event ground exists. EventGrounds has no dependencies so Edit-mode previews can place
  effects through it (it takes an optional `Random` for reproducible spots).
  Grounds: the Inner valley's three planned ones (West Field (-400, 1000) r 55, North
  Terrace (300, 680) r 48, East Flat (470, 1120) r 55; [map](map.md) "Inner Wilds rework")
  and two interim ones in the Ruined Borderlands (Graves Field (0, 1750) r 32, South Flat
  (360, 1928) r 30) until that zone is reworked.
- Placing event and treasure templates: keep the template's pivot rotation
  (`CFrame.new(spot) * template:GetPivot().Rotation`). `WorldTreasure`'s pivot is
  its `Ring`, a cylinder turned upright, so a bare `CFrame.new(spot)` lays the
  pillar on its side (AGENTS.md, "Luau pitfalls").
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
  from `Map.Clouds.Plane` (it was at Y ~339.6 on 2026-10-21, not the 440 map.md gives;
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
- `src/server/QiNodes.luau`: wilds qi nodes (raw qi + stones, per-player cooldown).
- `src/client/DayNight.luau`, `src/client/Music.luau` (zone music),
  `src/client/AmbientSounds.luau` (positional ambience and the valley bed).
- `assets/SoundGroups/Ambience.rbxm` (`SoundService.Ambience`), `tools/ambient_sounds_build.luau`.
- `assets/AmbientFX.rbxm` (`ServerStorage.AmbientFX`), `tools/ambient_fx_build.luau`.
- `assets/WaterKit.rbxm` (`ServerStorage.WaterKit`), `tools/water_kit_build.luau`
  (`_G.waterKit`: build, dress, rimPart, rimAlong, surfaceFX, rockRipples),
  `src/client/StylizedWater.luau`, `src/shared/WaterSurface.luau`,
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
- Ambient sound: layer volumes, roll-off, gaps and slices in
  `tools/ambient_sounds_build.luau` (rebuild and re-export); `MAX_ACTIVE`, fades
  and the Wilds box for the valley bed at the top of `AmbientSounds.luau`.
- `Pacing.Income.NODE_SHARE`, `NODE_COOLDOWN`; `Config.Economy.NODE_STONES`.

## Known gaps
- Event arrivals other than the treasure birth don't have the sky-to-ground descent
  from [style.md](../vfx/style.md) yet (plan: `docs/vfx/world_events_plan.md`, next
  Heaven Split). GuardedHerb still uses the Neon `WorldTreasure` pillar as its beacon.
- Treasure birth is untested in play: phone frame rate with three or four births at
  once, the meteor and rift timing against the server's 7 s landing, the SkyGrade clear-up
  fighting Auspicious Mist's own denser violet haze (the cap wins while treasures are up,
  so the weather's thick mist look is thinner then), how the pearl (Rainbow Aurora)
  pillar reads up close in bright daylight (it blows out to white), and SurfaceAppearance
  tinting on the wisp arcs on low-end phones.
- The cloud plane's top is at Y ~339.6 in the place, while map.md and
  `tools/vfx_specs/AuspiciousClouds.luau` (`PlaneTop` 440) assume 440; the Auspicious
  Clouds Column and Whirl may sit 100 studs off the plane. WorldFX reads it from the map.
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
- Ambient sound is untested in play: levels against the zone music, the
  frog/bird slices (a slice may land on a quiet stretch), and phone voice count.
  No anchors are placed in `Workspace.Map` yet (map-builder's pass). No incense
  hush layer at the shrine; the night-insect bed is a canyon cricket recording
  that may carry faint distant traffic.
