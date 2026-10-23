BUILT (2026-10-22): the heavenly tribulation's storm wheel, strike seals, bolts, scorches and the survived finale. Read when you change how the tribulation looks or its client wiring.

# Heavenly tribulation — as built

Server: `src/server/Tribulation.luau` (unchanged by the look pass). Client:
`src/client/WorldFX/TribulationFX.luau`. Templates: `ReplicatedStorage.WorldFX.Tribulation`
(`assets/WorldFX.rbxm`), built by `tools/vfx_specs/Tribulation.luau`, whose header holds the
intent, beat sheet and the asset picked for each layer. Kit and rules:
[../world_events.md](../world_events.md).

## Wiring (no new remotes)

| Moment | Remote | Client |
|---|---|---|
| start | `Effect` "tribulationStart" (player, `Config.Tribulation.CENTER`, strikes) | `TribulationFX.start(center)`; `TribulationView.start(player, strikes)` (screen UI) |
| each strike's windup | `Telegraph` (shape, windup, nil, "Tribulation", startedAt) from `EnemyService.strike` | `TribulationFX.warn(center, radius, windup)`: its own listener on the Telegraph remote, filtered by source; the late-arrival correction is the same as Telegraphs' |
| each strike | `Effect` "bolt" (ground) | `TribulationFX.strike(ground)`; `TribulationView.strike()` |
| end | `Effect` "tribulationEnd" (player, survived) | `TribulationFX.finish(survived)`; `TribulationView.finish(player, survived)` |

`CombatController` dispatches the Effect kinds; if `WorldFX.Tribulation` is missing it falls
back to the old `CombatEffects.bolt` / `storm`. The danger-orange telegraph (Telegraphs.luau)
still says where and when; the seal is drawn under it in the storm's colour.

## What plays

- **Storm wheel (far, always):** 12 `Cloud_WispArc` clones in 4 rings (lengths 210-780, at
  112-184 above the platform, inner rings lower: a funnel), storm grey-indigo through the
  SurfaceAppearance tint, turning from the server clock (inner fastest) and breathing; an ink
  swirl disc (r 410) behind a storm swirl disc (r 280) on their undersides, turning; the eye
  118 above the platform (a spiral-core glow and a hard dot); dark billows rolling round the
  rim. Gathers over 4 s (arcs sink 80 studs and draw in from 1.4x).
- **Flicker (far):** every 0.5-1.6 s a sheet of cloud lightning and a branching arc flash at a
  random point inside the wheel (one re-flash in the curve, no strobe) and the storm swirl's
  lit copy flares; within 900 studs a jagged arc crawls the underside for 0.22 s. A rumble
  every 5-9 s.
- **Arena (close, within 320):** arcs crackling on the arena edge (r 35), static motes rising.
- **Seal (close):** the heavens' seal turning on the strike circle (sized to the server's
  radius), a double ring closing from 2.2 radii onto the radius exactly at the windup's end,
  the leader flickering from the eye down to it in the last 40%, arcs gathering at the eye
  end from half-way; a charge sound.
- **Strike:** a jagged 7-segment bolt from within 16 studs of the eye: plain white core,
  white bolt body with dark edges (reads on a bright sky), soft violet glow; 3 branches off
  the upper half; strike 60 ms, dim, re-strike at 110 ms, gone by 450 ms. Beams widen up to
  2.5x with camera distance (200-1000) so the stroke reads from the other peaks. Within 320:
  star and dot flash, spiky shock ring, electric ring, ground arcs, sparks, rock debris, dust
  and a crack sound; the scorch (dark crater, glowing cracks cooling over 1.6 s, embers, gone
  by 6 s). The storm's one PointLight jumps to each strike and decays. A soft cool grade
  pulse within 260 studs, never closer than 0.45 s apart; a small shake within 45.
- **Clear, survived:** the eye flares gold, a gold pillar (soft starry band and a core)
  drives down 0.3-1.0 s, holds, fades by 6 s; the arcs turn gold, are flung out to 2.8x and
  rise 140 over 5 s while everything fades; rays fan from the eye, gold motes fall for 3.5 s,
  a gold ring and rising motes on the platform; a gold grade pulse within 600; Clear sound.
  Cleaned up at 7 s.
- **Clear, failed:** the wheel unwinds (drifts out 35%, rises 40) and fades over 3 s.
- **Sky:** `SkyGrade` "Tribulation" darkens and cools the world near the peak (full within
  350 studs, none past 1600: tint, atmosphere colour, brightness 0.78, saturation -0.12);
  "TribulationClear" caps Atmosphere density/haze at 0.28/1.0 everywhere while it lasts (the
  far-read rule). Both turn gold and lift on a survived clear.

## Budget

Far (any client, incl. a phone 600-1300 away): 12 arcs (~17k tris), 2 SurfaceGui discs, ~10
huge billows, the eye's 2-3 particles, 1-2 flicker particles a second, and per bolt ~33 beams
for 0.45 s. Mid adds 1 beam at a time. Close adds ~20 particles/s (crackle, static) and per
strike ~50 burst particles, a 3-beam seal and a scorch. One PointLight. Updates every frame
within 1500 studs, ~5 Hz beyond.

## Known gaps

- A player who joins mid-trial sees no storm (the server publishes no state; the trial is
  30 s). A workspace attribute would fix it if it matters.
- The local phases (gather, strikes, clear) run from when each client got the remote; only
  the turning is on the server clock.
- Library sounds' in-game playback is untested; the user reviews the look in Studio. The
  preview was in the sandbox baseplate (default lighting, no map, no cloud plane), so the
  far read against the real sky and haze is unchecked.
- Clones per strike (no `fx.pool`); about one strike a second at most.
