# Twin Phoenix Cannon visuals

Covers the `TwinPhoenixCannon` technique effect (templates `TwinPhoenixCannon_T1..T4`, spec `tools/vfx_specs/TwinPhoenixCannon.luau`, `TechniqueFX.TwinPhoenixCannon`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md) (weapon-skill helpers: `BladeSkill`, `WeaponFX`, swing/cancel/punch/rend).

Templates `TwinPhoenixCannon_T1..T4`, authored at length 18
and width 6; `TechniqueFX.TwinPhoenixCannon`. The skill animation throws
two overhand forward punches, right fist at `Hit "1"`/`Release "1"` (0.30)
and left at `Hit "2"` (0.833); each fist is fully extended ~0.03 s later,
where its release plays on the live hand. `cast()` runs at the first hit
and schedules the second from `def.hits` at the cast's playback rate. Each
blast is a phoenix: a Neon fire head with swept-back Beam wings and a
burning tail (`BlastR` crimson, `BlastL` gold and a size up) flying the line
on its `TravelCurve` (~0.26 s), stopped by walls or rising ground, with a
muzzle flash and 3D air rings off the fist (`FistR/L`), a fire impact on
every enemy its front reaches (`ImpactR/L`: impact stack plus flame flare),
an explosion where it ends (`TerminalR/L`) and a burn line cooling to a
char mark (`BurnR/L`, `CharR/L`). Between the blasts gold qi gathers in the
left fist (`Gather`, everyone sees it). II adds flame feathers off the
wings, release sparks, embers off the burn line and impact swirl/dust; III
a rune "cannon seal" at each fist, 2 air rings, impact bubbles and rock
kicks, a terminal Craters ring and a small shake; IV 3 air rings, white-gold
heads, the one light riding the golden bird and a fire dome with a spike
crown and an Explosion quake at its terminal. Damage lands on the server's
hit times. Remade 2026-10-21 for the hit windows: each bird flies in 0.15 s
(0.17 s gold) and every impact is squeezed into that blow's Hit -> Hit Stop
window (`WeaponFX.hitWindow`/`landing`, floor 0.1 s) instead of trailing the
damage number by up to 0.28 s. Layers added: a spiky flame-aura flipbook
`Plume` streaming back off each bird's head, a `FistFlame` flipbook on the
charging fist through the windup (and the left fist between the blasts), a
coloured fire-flipbook `MuzzleFire` over an ink splat at each release, an
ink splat and fire-flipbook `Bloom` (II+ a smoke flipbook) at each terminal,
and the shared hit stack's ink splat and star-burst flipbook on every
impact. The windup is a stream through 0.30 s, not one burst. Layers per
beat for one bird (T1 / T4): windup 6 / 9, release 6 / 10, travel 10 / 11,
impact 11 / 18, terminal 13 / 21, tail 2 / 3. QA pass 2026-10-21: a cast cut
short between the blasts drops the left-fist gather at once
(`WeaponFX.onCancel`; the second bird was already dropped with the track),
and the golden finisher's terminal lands with a hit-pause punch at III+.
The burnt streak is still a Neon line (not a rend).
