# Weather, world events, treasures and ambience

## Purpose
A living world shared by the whole server: weather moods with small blessings,
heavenly treasures that fall during auspicious skies, world events that pull
everyone to one spot, and a day/night cycle.

Detail files (read only what your task needs):
| File | Covers | Read it when |
|---|---|---|
| [event-fx](../world/event-fx.md) | how events and treasures are drawn: Auspicious Clouds (WorldEventFX), the treasure birth (TreasureFX), the WorldFX kit and SkyGrade | world-fx or vfx work on events, anomalies, treasures |
| [ambient-fx](../world/ambient-fx.md) | `ServerStorage.AmbientFX` templates, sizing, mounting, `NightFX`, preview | placing or authoring ambient effects |
| [water](../world/water.md) | the stylized shallow-water kit (`ServerStorage.WaterKit`) | building or placing pools, meres, fall feet |
| [ambient-sound](../world/ambient-sound.md) | `SoundService.Ambience` templates and the anchor contract | placing sound anchors, tuning ambience |

For the setting and where each zone, beast and event ground is, see
[world-overview](../world-overview.md).

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
- World-event look pass (plan approved 2026-10-21, `docs/vfx/world_events.md`, one file per event in `docs/vfx/world_events/`):
  every event and anomaly is composed from one shared kit (light pillar, sky circle, sky
  crack, cloud rings from the wisp arcs, ground circle, sky grade), recoloured and timed per
  event. Decisions: world effects live in their own file (`ReplicatedStorage.WorldFX`, not
  `Effects`); while an anomaly animates its copy of `Map.Clouds.Wisps` the client hides
  the real ring locally; treasures lose the Neon pillar and their claim waits ~7 s for the
  landing; screen effects stay gentle (a soft white flash when the heavens tear, an impact
  frame or shake only near a landing); the sky clears (Atmosphere density and haze capped)
  while a far layer is up; Beast Surge is a crimson vortex at the valley centre; Ginseng
  publishes a guarded/free `state`. Tribulation clouds came later, in their own pass
  ([tribulation](../vfx/world_events/tribulation.md)).
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
  (`assets/AmbientFX.rbxm`, built by `tools/ambient_fx_build.luau`), placed by map
  passes: one invisible, anchored, non-colliding Part each (the emission volume).
  Catalogue and mounting rules: [ambient-fx](../world/ambient-fx.md).
- Shallow water (meres, the rimmed pools under waterfalls) is a stylized part, never
  terrain water, from `ServerStorage.WaterKit` (`assets/WaterKit.rbxm`); see
  [water](../world/water.md).
- Ambient sound (2026-10-21) is positional, client-side, from templates in
  `SoundService.Ambience`, played at map anchors tagged `AmbientSound`; see
  [ambient-sound](../world/ambient-sound.md).

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
- `src/client/WorldEventFX.luau` draws the AuspiciousClouds kinds; details in
  [event-fx](../world/event-fx.md).
- `src/server/Treasures.luau`: treasures on the wilds' event grounds when weather with
  `treasures` starts; first claim keeps it. Each birth is published in the workspace
  attribute `HeavenlyTreasures` (JSON `{ key, at, color, weather, born }`) and drawn by
  every client (`src/client/WorldFX/TreasureFX.luau`), since streaming keeps the server
  model from players on the peaks. The server model (`WorldTreasure` without its Neon
  `Pillar` and `Ring`: the orb, prompt and label) is parented only at `born + Treasures.LAND`
  (7 s), so the claim waits for the landing.
- Heavenly treasure birth (`src/client/WorldFX/TreasureFX.luau`, 2026-10-21): see
  [event-fx](../world/event-fx.md).
- `Treasures.randomSpot` (also used by
  GuardedHerb and AuspiciousClouds) is `src/server/EventGrounds.luau`'s `randomSpot`: a
  random point within 0.9 of a random `Workspace.Wilds.EventGrounds` disc's `Radius`
  (`assets/Wilds.rbxmx`; tagged `POI`, Kind `EventGround`), raycast to the ground,
  skipping water, up to 8 tries; it falls back to the `Wilds.Zones` beast discs only when
  no event ground exists. EventGrounds has no dependencies so Edit-mode previews can place
  effects through it (it takes an optional `Random` for reproducible spots).
  Grounds: the Inner valley's three planned ones (West Field (-400, 1000) r 55, North
  Terrace (300, 680) r 48, East Flat (470, 1120) r 55; [inner-wilds-rework](../map/inner-wilds-rework.md))
  and two interim ones in the Ruined Borderlands (Graves Field (0, 1750) r 32, South Flat
  (360, 1928) r 30) until that zone is reworked.
- Placing event and treasure templates: keep the template's pivot rotation
  (`CFrame.new(spot) * template:GetPivot().Rotation`). `WorldTreasure`'s pivot is
  its `Ring`, a cylinder turned upright, so a bare `CFrame.new(spot)` lays the
  pillar on its side (AGENTS.md, "Luau pitfalls").
- World FX kit (2026-10-21): `ReplicatedStorage.WorldFX` (`assets/WorldFX.rbxm`, built by
  `tools/worldfx_build.luau`), runtime in `src/client/WorldFX/` (`Kit.luau`, `SkyGrade.luau`),
  preview `tools/worldfx_preview.luau`; see [event-fx](../world/event-fx.md).
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
  from [style.md](../vfx/style.md) yet (plan: `docs/vfx/world_events.md`, next
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
  events that start on their own (the timer rolls every 20-35 min). The
  [testbed](testbed.md) has no timer and no rolled weather.
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
