# Palm Strike visuals

Covers the `PalmStrike` technique effect (templates `PalmStrike_T1..T4`, spec `tools/vfx_specs/PalmStrike.luau`; no `TechniqueFX` module, `CombatEffects` plays it); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md).

Templates `PalmStrike_T1..T4`, authored at radius 9, rescaled to
`def.radius`. Fists.4 strikes with the **left** hand (`def.hand`), which
`CombatEffects` finds on the live character (R6 arm tip, R15 grip
attachment), for observers too. Windup (caster only): qi motes and a charge
glow ride the swinging hand (II+ Spline wisps curve in, III+ a seal closes
on it). At Hit: a flash from the palm, a streak drops from it to the ground
and splashes, and the gold shockwave opens from the feet (the gameplay
centre) to the radius by Hit Stop, with dust kicked along the ground.
Each enemy inside the radius gets an impact as the front reaches it: star
flash, spiky ring, sparks, drawn in front of it, plus `CombatEffects.flash`.
II adds an echo ring, rays and impact dust; III a seal, cracks, a spinning
SimpleMeshVFX shell, a Craters rock ring erupting with the wave and rock
kicks on the first three targets; IV a crater, a dome shell, a nimbus halo
behind the head, one point light, ScreenEffects impact frames and an
Explosion shake on the first impact. Remade 2026-10-21 for the Hit window
(bare hand, so the anchors stay on the live left palm): the windup qi is a
stream through the whole 0.38 s (the hand gather's `Gather` runs on
`Rate` + `EmitDuration`, scaled by `TechniqueVFX.fit`), the palm release
gets the shared flare (cross glint, star-burst flipbook over ink, sparks) and
a cross glint on the release flash, and every impact picks up the shared ink
splat and star-burst flipbook (smoke flipbook tail at III+). The wave front
was already fitted to Hit -> Hit Stop, so the sandbox run landed impacts
0.04-0.05 s after the release. Layers T1 / T4: windup 2 / 4, release 9 / 13,
ground 3 / 8, impact 8 / 14.

## Known gaps
- Fists.4's `Hit Stop` marker is at 0.45 s but `FIST_STEPS[4].hitStop` is
  0.50, so the active phase (which follows Config) runs ~0.05 s past the
  marker; see [combat](../../systems/combat.md#known-gaps).
