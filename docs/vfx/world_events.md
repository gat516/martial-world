The world-event look pass for world-fx agents: what is built (the WorldFX kit, treasure births), the user's decisions, where people watch from, the far-read rule, budget, placement checks and build order, plus an index of per-event files (built state or plan). Read at the start of any world-fx task, then only the file for your event.

# World events and sky anomalies: look pass

Approved by the user 2026-10-21 (decisions below). Built: step 0 (groundwork, far-read test)
and step 1 (treasure birth). Next: Heaven Split, after the user's review in Studio. The
as-built behaviour, files and tuning are in [event-fx.md](../world/event-fx.md) (treasure birth,
"World FX kit"), gaps in [world.md](../systems/world.md) "Known gaps"; this page is the design and what's left.

## Status

| Event / anomaly | Code path | State | File |
|---|---|---|---|
| Heavenly treasure birth (during Auspicious Mist / Rainbow Aurora / Heaven Split) | `server/Treasures.luau`, `client/WorldFX/TreasureFX.luau` | **Built** (step 1, 2026-10-21) | [treasure_birth.md](world_events/treasure_birth.md) |
| Heaven Split (weather) | `client/WeatherFX.luau` | Plan. Today a grade lean and distant bolts; **no split** | [heaven_split.md](world_events/heaven_split.md) |
| Auspicious Mist (weather) | `client/WeatherFX.luau` | Plan. Today a violet grade lean (`WeatherFX.adjust(k)`) and mist particles round the camera | [auspicious_mist.md](world_events/auspicious_mist.md) |
| Rainbow Aurora (weather) | `client/WeatherFX.luau` | Plan. Today 65 Neon slabs placed relative to the camera, a new set each start | [rainbow_aurora.md](world_events/rainbow_aurora.md) |
| Auspicious Clouds / Violet Cloud Mist / Golden Auspicious Clouds | `WorldEvents/AuspiciousClouds.luau`, `client/WorldEventFX.luau`, `Effects.AuspiciousClouds` | Existing look (wisp patterns descend and turn, a Column through the cloud plane and a Whirl on it, seal and unseal bursts, a bobbing relic); kit lift is plan | [auspicious_clouds.md](world_events/auspicious_clouds.md) |
| Thousand-Year Ginseng (`GuardedHerb`) | `WorldEvents/GuardedHerb.luau` | Plan. Today `ItemTemplates.WorldTreasure` x3 as a beacon (80-stud Neon cylinder, glass shell, orb, ring, one emitter, PointLight, herb-tinted), top at Y ~250 under the cloud plane, so the peaks can't see it | [ginseng.md](world_events/ginseng.md) |
| Beast Surge | `WorldEvents/BeastSurge.luau` | Plan. No visuals and no `at` (covers the whole zone) | [beast_surge.md](world_events/beast_surge.md) |
| Heavenly tribulation (storm wheel, seals, bolts, clear) | `server/Tribulation.luau`, `client/WorldFX/TribulationFX.luau`, `WorldFX.Tribulation` | **Built** (2026-10-22) | [tribulation.md](world_events/tribulation.md) |
| Rain, Storm, Windy (weather) | `client/WeatherFX.luau` | Plan, only if cheap: Storm and Rain clone in a `Terrain.Clouds` template and tween it (Storm cover ~0.8, dark indigo; Rain ~0.55, grey) so the sky over the peaks goes overcast; Windy gets nothing new. The place has no `Terrain.Clouds` today | (this line) |

## Decisions (user, 2026-10-21)

1. World effects live in their own file: `assets/WorldFX.rbxm` mapped to
   `ReplicatedStorage.WorldFX`, staged in `ReplicatedStorage._StagingWorldFX`, exported with
   `tools/export_rbxm.luau`. vfx and world-fx no longer share a binary. The Auspicious Clouds
   pieces stay in `Effects` (the server reads `Effects.AuspiciousClouds.Relics`) until one
   coordinated move in a quiet window: one Effects.rbxm export while no vfx agent runs, plus
   path changes in `WorldEvents/AuspiciousClouds.luau` and `WorldEventFX`.
2. While an anomaly animates its copy of `Map.Clouds.Wisps`, the client hides the real ring
   locally, so the ring itself seems to come alive.
3. The Neon `WorldTreasure` pillar is retired for treasures, and the claim waits ~7 s for the
   landing (built).
4. Screen effects stay gentle: a soft white flash when the heavens tear; an impact frame or
   shake only near a landing.
5. The sky may thin its haze server-wide when haze eats the pillars. The far-read test showed
   it does past ~800 studs, so it applies to every anomaly with a far layer (built in
   SkyGrade, below).
6. The Game Module is wanted, but the user inserts it from the vfx plugin. Build
   plugin-compatible and play through the fallback until it's in (it wasn't in the place on
   2026-10-21). World FX drive their own emitters and beams from code anyway (sky-scale
   motion is code) but keep Emit attributes for the plugin.
7. Beast Surge: the crimson vortex at the valley centre.
8. Ginseng: add a `state` field to the WorldEvents publish.
9. Tribulation clouds stayed out of this pass; they got their own pass on 2026-10-22
   ([tribulation.md](world_events/tribulation.md)), which also draws the bolts.

## Where people watch from

- Peaks at Y 550-800, the plaza at (0, 648, 100). The cloud plane is opaque **from both
  sides**; its top is at Y ~339.6 in the place (2026-10-21), not the 440 older docs give, so
  read it with `Kit.planeY()`. It reaches out to ±2100. The wilds valley floor is at Y 3-8
  (x -900..900, z 520..1440), walls 80-124 tall.
- Event grounds (`EventGrounds.randomSpot`): West Field (-400, 1000) r55, North Terrace
  (300, 680) r48, East Flat (470, 1120) r55, Graves Field (0, 1750) r32, South Flat
  (360, 1928) r30.
- **From the sect** the wilds lie under a white floor 700-1900 studs away, deep in haze. The
  far layer is whatever stands above the cloud plane plus whatever hangs in the sky. From the
  plaza the plane's horizon is 12° below eye level and a pillar topping out at Y 1400 over
  West Field reaches 42° above it: height is cheap, use it.
- **From the valley floor** the plane is overhead and reads as sky, and the walls hide
  everything outside the valley. There the far layer is the pillar plus a sky circle under
  the plane.
- **So most events play twice:** above the plane for the peaks, below it (in the cloud
  ceiling) for the valley. Treasure births do.
- **StreamingEnabled is on:** server models in `Workspace.Wilds` don't reach players on the
  peaks. A far layer is published as a workspace attribute (like `WorldEvents`,
  `HeavenlyTreasures`) and drawn by every client.
- Distances: far 300-1500 studs (the peaks, across the valley), mid 80-300, close under 80
  (design); treasure births switch layers at 650 (mid) and 300 (close). Close layers are only
  created or emitting while the camera is near (~250 studs in the design).

## Far read (step 0 test, 2026-10-21)

A bare LightPillar (white core 8 wide, violet body 50, accent haze 180, to Y 1400) at West
Field, captured from the plaza edge (0, 655, 120; ~1000 studs) and the far north spirit peak
(-114, 565, -277; ~1330 studs):
- Default day sky (Atmosphere density 0.36, haze 1.8): only the additive white core survives;
  every coloured layer fogs to the sky colour. In Auspicious Mist weather (+0.1 density, +1.4
  haze) nothing is visible. Colour with LightEmission 0 doesn't help: density decides it, not
  haze or brightness.
- Density 0.28, haze 1.0: body and haze read clearly by day from both spots and the world
  still looks hazy; at night they glow strongly. At night with the default 0.36 / 1.6 it
  reads, but dimly.
- **Rule:** while a far layer is up, SkyGrade caps density at ~0.28 and haze at ~1.0,
  weighted by the event's phase ("the sky clears as heaven opens").
- Up close (under ~150 studs) a 180-wide haze is a wall of light, so the pillar narrows and
  fades its haze and body near the camera. An alpha-blended body keeps its hue up close but
  vanishes at 1000 studs; an additive one reads far but washes white up close, so blend by
  camera distance (TreasureFX does).
- Lighting otherwise: Bloom threshold 1.35 (only Brightness > ~1.4 blooms); the Skybox has
  celestial bodies off.

## The shared kit

Every event is composed from one kit, recoloured and timed per event, not from one-off
builds. A piece is one template (`ReplicatedStorage.WorldFX.<Piece>`, built by
`tools/worldfx_build.luau`) plus runtime in `src/client/WorldFX/`; it takes a **palette**
(`core`, `color`, `accent`, `dark`), a **scale** and a **timeline**, and is animated from
`workspace:GetServerTimeNow()` so every client sees the same phase. `Kit.luau` holds spawn,
upright place, paint, phase and LOD helpers and one BulkMoveTo per frame for everything that
moves; `WorldEventFX` and `WeatherFX` call into it. The template contract (Tint/TintMix,
WorldY, PlaneOffset, `Layer` far/mid/close) is in `Kit.luau`'s header and event-fx.md.

| Piece | State | Notes |
|---|---|---|
| `Grade` + `SkyGrade.luau` | built | below |
| `LightPillar` (ground to sky) | built | Core/Body/Haze/Flow beams to world Y 1400, Streaks and Motes, Puncture ring and billows on the plane, Landing burst. Design: sizes S/M/L by scale (treasure / event / anomaly; a treasure uses 0.6); beats `drive` (beams grow top-down over 0.6-1 s, flash at the landing), `sustain`, `flare` (0.3 s width x2 and brightness pulse), `collapse` (pulls up into the sky circle); core width shimmer 2 Hz ±10%, body texture scrolling up, haze breathing over 6 s; a qi helix (2-3 wisps with Trails spiralling up) is planned, not built |
| `SkyCircle` (formation array) | built | rings as ImageLabels on SurfaceGuis turning by `Rotation` (cheaper than moving parts, steadier than turning particles), counter-rotating, `SurfaceGui.Brightness` > 1 to bloom, `LightInfluence` 0, a dark ink disc behind for dark under light. Radius 80-400. Beats `open` (rings scale in one after another, 0.4 s apart: the Megumin stacking), `turn`, `shatter` (scale out, fade, shard particles), `shrink` (to a glint). Also used flat on the ground and as a treasure's omen |
| `SkyRift` (small crack, 150 long) | built | per segment a white-hot Lip, coloured Glow and dark nebula Void revealed from the middle by `Seg`; Glint and Lens at the eye; Flicker, Shards, Rain of light. The sky-scale crack is Heaven Split's ([heaven_split.md](world_events/heaven_split.md)) |
| `Meteor` | built | head Glow, Halo, Sparks, Tail trail |
| `GroundCircle` (where it lands) | built | sigil and rune circle on an ink disc 0.2 above ground (part up = world up), core Halo/Flare, PointLight, Motes, Twinkles, Petals, mist Bank over a dark Under layer. Design for landings: flat shock ring (VelocityPerpendicular, Size curve to the radius), dust ring (Box, Front, SpreadAngle (5, 180)), radial streaks, debris (Craters only with the Game Module, else plain emitters), 4-point glint; sustain motes, petals or leaves by event, low level mist |
| `CloudRing` | built | two counter-turning layers of three `Cloud_WispArc` clones, each with a coloured mist Puff |
| `CloudVortex`, `WispsRing` | plan | below |

**Cloud pieces** (`ServerStorage.CloudKit.Cloud_WispArc`, the mesh and texture of
`Map.Clouds.Wisps`): rings of 3-12 arcs layered by radius and height; each layer can turn,
breathe (scale pulse), drift in or out, descend or rise, ripple and tilt slightly. One
BulkMoveTo per frame; scale changes only when asked for.
- Colour without new meshes (violet mist, gold, white, storm grey-indigo, jade, crimson): a
  textured MeshPart ignores `Color`, so tint through a `SurfaceAppearance` whose ColorMap is
  the cloud ramp (131820708134549) with `SurfaceAppearance.Color`, keeping the shaded
  underside and lit crown. A full tint turned the arcs flat saturated purple; **TintMix 0.55
  with AlphaMode TintMask** keeps the shading (built). Fallback if the ColorMap can't be
  written: drop the texture and colour the Fabric (what WorldEventFX does).
- Each arc carries 1-2 huge, slow, soft particles in the variant colour, so colour reads
  through haze, plus a flat glow beam underneath for coloured underlight.
- **`WispsRing` (plan):** an exact copy of `Map.Clouds.Wisps` (11 arcs, positions read in
  Studio) as a template, so an anomaly can bring the ring round the main peak to life: turn,
  breathe, rise, tint, split apart. The map copy stays untouched in the place; the client
  hides it locally while the copy plays (decision 2).
- **`CloudVortex` (plan):** storm arcs turning on the cloud plane (Beast Surge).
- Budget: the arc is 1400 tris whatever its size; at most ~12 arcs per event, ~24 on screen.

**SkyGrade** (built): DayNight samples its keyframe, calls `WeatherFX.adjust(k)`, then
`SkyGrade.adjust(k)`, which applies each active contribution (`tint`, `atmoColor`,
`densityCap`/`hazeCap`, `brightness`, `exposure`, `saturation`, `contrast`) with a weight =
phase strength x camera-distance falloff (full inside `inner`, 0 past `outer`; or global).
So a violet mist turns the world violet only near it, and Heaven Split can dim the whole sky.
DayNight still owns the per-hour values. Pulses (white-out, impact frame, tinted flash) go on
`Lighting.WorldFXGrade`, a clone of `WorldFX.Grade`, never on DayNight's `ColorCorrection`;
the thunder flash keeps riding `k.brightness`.

## Budget (top phase)

| Case | Far | Mid | Close |
|---|---|---|---|
| One treasure | 3 beams, 2 SurfaceGuis (sky circle), 4-6 arcs, ~20 huge particles | 6 arcs, ~40 particles | ~150 particles, 1 PointLight on the orb |
| Heaven Split (crack + 4 treasures) | crack ~30 beams, curtains 8, parting arcs 8, ~40 particles; plus 4 x the treasure far layer | camera-local motes ~30 | the nearest treasure only |
| Auspicious Clouds + kit | existing build + 3 beams, 2 SurfaceGuis, 4 arcs | existing | existing |
| Tribulation | 12 arcs, 2 SurfaceGuis, ~12 huge particles, flicker 1-2/s, ~33 beams per bolt for 0.45 s | 1 crawling arc beam | ~20 particles/s, ~50 per strike, seal and scorch; 1 PointLight |

A phone 600 studs from a treasure renders its far layer only: about 3 beams, 1-2 SurfaceGuis,
6-10 arcs (~12k tris) and ~20 slow particles per treasure. Mid and close emitters switch off
by camera distance, and everything past 1500 updates at 4 Hz, like WorldEventFX. One
PointLight per event, and only while the camera is close.

## Placement checks (upright, every time)

- Templates: `PrimaryPart` nil, identity `WorldPivot` at the ground point; pillar parts stood
  up inside; flat parts with up = world up; beam attachment axes set explicitly.
- Placement: `CFrame.new(spot) * template:GetPivot().Rotation * CFrame.Angles(0, yaw, 0)`
  (`Kit.place`).
- Test in Edit mode at 3 spots from the real `EventGrounds.randomSpot` (no dependencies, so a
  preview can require it; it takes an optional `Random`) through the real drawer at 3 yaws,
  each captured from the side at eye level: upright pillars, flat ground rings, level clouds.
- Captures per look: far (the plaza (0, 660, 140) and a peak top, e.g. Peak_4), mid (~200
  studs), close (~40), at noon and at night.
- Preview tool: `tools/worldfx_preview.luau` (`_G.worldfxPreview`): fresh module copies on the
  staging templates and a fake clock, `spots(n, seed)`, `pillar`, `look`, lighting presets
  `day`/`night`/`mist`/`clear`, `clear`; everything in `Workspace._WorldFxPreview`. Park the
  camera nearby first (Edit-mode particles only simulate near it).

## References and library notes

Rows and per-beat breakdowns are in [reference/vfx/README.md](../reference/vfx/README.md)
("World events and anomalies", "Breakdowns"); each event file names the ones it uses. Library
candidates noted at plan time (from contact sheets; re-check with a live search, e.g.
`bagua`, `taiji`, `lotus`, `talisman`, `cloud`, and pick each layer against its own reference,
not from earlier builds):
- Pillar body: soft vertical bands (9841273413), gradient band (2382169232), glow column
  (9841273244), ray curtain fanning down (245996148).
- Glints: 4-point star (3060556198), lens streak (14684195806), burst (243728206), thin sliver
  (11226108137, 7886908733; the latter a crack core line).
- Rings: meander/key ring (16511732405), gold sigil (565056459), ornate rings (87153714607286,
  13399941667), glyph ring (129093523368188), hex formation (102790439571584), ruyi-cloud
  ring (100397289227468, opaque black background, additive only).
- Clouds: ruyi cloud column (74110461210620, black background), wispy stroke (9345352897),
  soft puff (1084987899), smoke flipbook (17703378809).
- Vortex: smoke vortex (321556991), dark smoke vortex (341277531, a dark base), soft swirl
  (15249897265).
- Crack flicker: lightning flipbook (135959774229843), cracks (301851161).

## Build order (one commit per finished look)

0. ~~Groundwork: WorldFX file and mapping, SkyGrade and the DayNight hook, Kit, the
   EventGrounds split, the preview tool, the far-read test.~~ Done.
1. ~~Treasure birth.~~ Done.
2. **Heaven Split**: sky-scale crack, parting clouds via `WispsRing`, curtains, treasures
   falling from the crack.
3. **Auspicious Mist** (violet qi from the east, WispsRing in violet) and **Rainbow Aurora**
   (beam rainbow).
4. **Auspicious Clouds x3**: the kit layered onto the existing build.
5. **Thousand-Year Ginseng**: the pillar, the seal state, the herb's close layer.
6. **Beast Surge**: the crimson vortex and the zone grade.
7. **Storm / Rain** overcast, if there's time.
