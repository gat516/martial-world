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
  first-come: the first to claim keeps the prize.
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
  (more and bigger ambient packs via `Spawner.boost`).
- `src/server/Treasures.luau`: treasures in the wilds' zones when weather with
  `treasures` starts; first claim keeps it.
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
- No world event has a timer `weight` yet, so events only start from weather or admin.
- Qi node prompts get their key and style set in code (TODO in QiNodes.luau) until
  `assets/Wilds.rbxmx` carries them.
