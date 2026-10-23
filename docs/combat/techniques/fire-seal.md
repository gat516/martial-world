# Fire Seal visuals

Covers the `FireSeal` technique effect (templates `FireSeal_T1..T4`, spec `tools/vfx_specs/FireSeal.luau`, `TechniqueFX.FireSeal`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md).

Templates `FireSeal_T1..T4`, authored at radius 8, a 0.214 s active
window and 4 s; `TechniqueFX.FireSeal`. Fists.4 strikes with the left hand.
Windup: qi gathers into the palm. At Hit the seal is thrown as a projectile
(a Neon core with a trail and a spinning ring, `Palm/Bolt`, `BoltRing`),
whose 0.24 s flight is fitted to the active window, and lands at the zone
centre (`def.offset` ahead, on the ground) with an impact stack and a torus
rolling out to the rim (`Land`, delayed by the flight). For `def.seconds` a
raised Neon `Rim` torus marks exactly `def.radius`, with a turning rune
glyph, flame tongues and embers (`Zone`, enabled/disabled by the runtime;
its held MeshParts carry `Show`/`Spin`/`Flicker`). Every `def.tick` a
`PulseRing` sweeps to the rim, the rim flares, and each enemy inside
(re-queried per tick, up to 4) gets a burn hit (`Impact`: flare, embers,
`impactShockwave` rings) and an orange `CombatEffects.flash`. At the end the
hold fades and `Finale` bursts. Ticks are counted on the client from the
cast time (k × tick, the first held until the landing), because the server's
ticks aren't sent. II adds a spinning `InnerSeal` and rim flares; III a
counter-rotating `CounterSeal` and second glyph, a `FlameWall` spike crown
on the rim, `PulseCrown` spikes per tick, a Craters rock ring, scorch and
shake at the landing, and a flame tongue under each burn hit; IV a flame
`Pillar` at the landing, the move's one PointLight, and a big finale with an
Explosion shake. Remade 2026-10-21 for the Hit window (bare hand, so the
anchor stays on the live left palm): the 0.5 s windup is a stream through
the whole windup (not one burst), the release on the palm gets the shared
flare (fire-orange cross glint, star-burst flipbook over ink, sparks), and
every burn hit and the landing carry the shared ink splat and star-burst
flipbook. The seal's flight was already fitted to Hit -> Hit Stop (0.14 s).
Layers T1 / T4: windup 2 / 4, palm 10 / 11, landing 11 / 22, zone 2 / 3,
burn hit 4 / 5, finale 4 / 7.

## Known gaps
- The tick visuals are timed on the client from the cast, not from
  the server's damage ticks (which aren't sent), and the first one waits for
  the seal to land (~0.24 s after the first damage tick).
