# Crescent Moon Sweep visuals

Covers the `CrescentSweep` technique effect (templates `CrescentSweep_T1..T4`, spec `tools/vfx_specs/CrescentSweep.luau`, `TechniqueFX.CrescentSweep`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md) (weapon-skill helpers: `BladeSkill`, `WeaponFX`, swing/cancel/punch/rend).

Templates `CrescentSweep_T1..T4`, authored at radius 11;
`TechniqueFX.CrescentSweep`. A jade crescent cut out of the air: the clip
winds the guandao back low behind the left hip, then from Hit to Hit Stop
whips it round ~323 deg in one low spin (behind, right, front, left).
Windup: jade motes gather into the grip (II+ wisps, III+ a seal). At Hit a
flash on the blade tip. The `Sweep` part is turned round the caster on that
heading curve (`StartHeading` -126, `SweepDegrees` 323 over the active
window, then `FollowDegrees` of follow-through), so its radial Trails lay a
flat jade sheet with a bright moon edge at the blade's reach that closes into
a disc and fades. A ground torus rolls out to `def.radius`, a wispy swirl
ring spreads at knee height, dust is kicked outward and a jade-ink crescent
is scorched under the sweep. Each enemy in the circle gets a jade
`impactStack` and a crescent cut when the blade's heading passes it (one in
the arc the spin skips, behind-left, at Hit Stop). II adds an inner edge,
wave echo and rays, rising motes, impact swirl; III a spinning SimpleMeshVFX
swirl shell, a Craters ring erupting with the wave, impact bubbles and rock
kicks; IV a gold edge, a jade-gold moon rising behind the caster, one point
light on the sweep, impact frames at the release and a quake on the first
impact. Remade 2026-10-21 on the guandao and the Hit window: the 0.63 s
windup is a `Charge` along the whole pole (butt -> blade, `full`; dark beam
under a jade one, motes along the shaft, a glint on the blade) as it is
wound back; the release flash on the blade gets the shared flare (cross
glint, star-burst flipbook over ink, sparks); the sheet lies on a dark ink
sheet and the real blade draws its own ribbon, glow and motes (`Edge` on the
model's Base -> Tip) through the spin; every cut gets a crescent-moon
flipbook plus the shared ink splat and star-burst flipbook. Impacts already
fire as the heading passes (inside Hit 0.633 -> Hit Stop 0.75 plus the
follow-through). QA pass 2026-10-21: the `Sweep` sheet rides the real
guandao: its heading is the live point's heading round the caster (sampled,
it starts at -142 deg, not -126, and leads the authored curve by 15-20 deg
through the spin), never behind the authored curve, so a frozen relay pose
still sweeps; the shared flare (part `Flare`) plays where the spin is
fastest (`WeaponFX.swing`), facing it; impact frames from III; a hit-pause
punch at III+; shake 0.9 / 1.4 / 2.2 / 3.0. Layers T1 / T4: charge 8 / 8,
release 6 / 6, flare 6 / 7, sweep 4 / 5, edge 3 / 4, ground 6 / 11, impact
10 / 17.
