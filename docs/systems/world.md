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
- `src/server/Treasures.luau`: treasures in the wilds' zones when weather with
  `treasures` starts; first claim keeps it.
- Placing event and treasure templates: keep the template's pivot rotation
  (`CFrame.new(spot) * template:GetPivot().Rotation`). `WorldTreasure`'s pivot is
  its `Ring`, a cylinder turned upright, so a bare `CFrame.new(spot)` lays the
  pillar on its side (AGENTS.md, "Luau pitfalls").
- `src/server/QiNodes.luau`: wilds qi nodes (raw qi + stones, per-player cooldown).
- `src/client/DayNight.luau`, `src/client/Music.luau` (zone music).
- `assets/AmbientFX.rbxm` (`ServerStorage.AmbientFX`), `tools/ambient_fx_build.luau`.

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
- Event and treasure spots come from the zone discs (`Treasures.randomSpot`), not
  the planned per-zone event grounds, and nothing on arrival makes it a contest
  beyond first claim.
- Only the Auspicious Clouds varieties have a timer `weight`, so they are the only
  events that start on their own (the timer rolls every 20-35 min).
- Qi node prompts get their key and style set in code (TODO in QiNodes.luau) until
  `assets/Wilds.rbxmx` carries them.
