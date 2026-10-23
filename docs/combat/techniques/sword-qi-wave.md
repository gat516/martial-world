# Sword Qi Wave visuals

Covers the `SwordQiWave` technique effect (templates `SwordQiWave_T1..T4`, spec `tools/vfx_specs/SwordQiWave.luau`, `TechniqueFX.SwordQiWave`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md) (weapon-skill helpers: `BladeSkill`, `WeaponFX`, swing/cancel/punch/rend).

Templates `SwordQiWave_T1..T4`, authored at length 32 and width 5;
`TechniqueFX.SwordQiWave`. Fists.3 cuts flat across the front with the
**right** arm, so the release flashes on the live right hand at Hit: a star
flash, 3D swirl air rings thrown forward, a light shake. The blade (`Blade`)
is a horizontal crescent of Beams (core, edge and a camera-facing glow
layer) with a wake trail. It flies the line on the template's `TravelCurve`
over `TravelTime` (0.36 s), driven by a pausable tween registered in
`TechniqueVFX.waves`. A ray along the path stops it at a wall or rising
ground, and it bursts where it ends (`Terminal`: `impactBurst` +
`impactShockwave`, III+ a Craters ring). Each enemy on the line gets a cyan
`impactStack` plus a crescent cut flash when the blade's front reaches its
near side (`curveTime`), and `CombatEffects.flash`. Behind the blade a Neon
slit (`Cut`) is drawn on the ground and cools into an ink scar (`Scar`); II+
motes rise off it (`Path`). II adds an echo blade, release sparks, impact
swirl and dust; III a second echo, a second air ring, bubbles, rock kicks,
path cracks and the terminal crater; IV a gold core, three air rings, one
point light riding the blade, a sword-intent crescent and impact frames at
the release, and a quake on the first impact. Damage still lands on the
whole line at Hit. Remade 2026-10-21 on the jian and the Hit window: the
0.32 s windup is a `Charge` along the model's Base -> Tip (dark beam under a
cyan one, motes, a point glint) instead of a hand gather; the release (star,
the shared flare, air rings) bursts on the blade 0.8 of the way to the tip,
not on the hand, and the real edge draws its own ribbon, glow and motes
(`Edge`, `BladeSkill.edge`) through the cut; the crescent has an ink crescent
under it and crosses the line in 0.12 s (was 0.36), the echoes trailing, with
every impact squeezed into Hit 0.35 -> Hit Stop 0.467 (`WeaponFX.landing`; a
sandbox run with a jian landed them 0.02-0.03 s after the release and the
terminal at 0.13 s) instead of up to ~0.36 s after the damage number; every
cut gets a cyan crescent flipbook and the shared ink splat and star-burst
flipbook. QA pass 2026-10-21: the Neon `Cut` slit and ink `Scar` are a cut
carved into the ground under the blade's path (`Cut`/`CutKicks`,
`BladeSkill.rend`: carved crack, cyan seam cooling, puffs and chips, star
cracks at II+, a crack web and rock kicks at III+). Layers T1 / T4: charge
8 / 8, release 8 / 12, edge 3 / 4, blade 11, cut 9 / 15, impact 11 / 18,
terminal 11 / 18.

## Known gaps
- The blade stops visually at walls, but its damage box still reaches
  through them ([combat](../../systems/combat.md#known-gaps)).
