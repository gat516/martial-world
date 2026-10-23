# World: ambient sound
Positional ambient soundscapes (`SoundService.Ambience`, `AmbientSounds.luau`): the anchor contract for map passes, the templates and where they go, layer attributes, preview. Read it when placing sound anchors or tuning ambience. Core: [world](../systems/world.md).

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
