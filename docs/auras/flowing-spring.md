# Flowing Spring Scripture aura

Covers the Flowing Spring Scripture (Water) method aura (template `Effects.MethodAura.FlowingSpring`): its brief, what is built, its budget and gaps; read it when changing this aura, after the shared rules in [auras](../systems/auras.md).

## Brief
- **Idea:** water gathering into a still pool
- **Mortal aura (the brief):** a mirror-still pool disc under you, one ripple per breath; droplet streams drawn inward to a soft blue core in the belly; cool blue body glow
- **Higher grades:** the pool widens with lotus pads and the streams come from farther away; Heaven: a waterfall of qi pouring into you from above
- **Refs:** meridians_qi_inflow, constellation_dantian_core (see [auras](../systems/auras.md#reference-images))

## What's built (Mortal; reworked: 13 loop emitters, no parts drawn)
- **On the body:** a pearl of water at the belly (a water-ball orb that swells with the breath, a white-hot heart, a small glint, the one PointLight); a ring of water strokes turning round the figure from behind on a darker ink-blue copy of itself; water-curl flipbooks lifting off the arms and torso and water wisps off the arms; streaks of qi streaming in from all round to the pearl, fast on the inhale, almost none at rest
- **Ground / around:** a pool under the seat: a deep ink-blue water blob (dark base), a pale water surface over it, a round caustics image drifting (the one SurfaceGui), small water-ring ripples popping across it, a swirl turning inward, bubbles rising
- **Breath beat:** the exhale: a ripple and a breaking ring cross the pool, a few drops hop off it, the pearl glints. Every 2 or 3 breaths (0.4 s jitter, 1.3x swell) a pulse: a drop of qi falls from above into the pool, a splash crown round the seat, a big ripple, the pearl flashes, the curls surge
- **Ignition:** the pool springs up: a white flash, a star and a water orb at the pearl, water columns and a splash crown round the body, a ripple wave and a breaking ring over the ground, drops thrown up, the pool darkening under it; curls and wisps surge

## Budget (R6)
13 loop emitters, about 40 live particles (limb curls 2.2/s per limb, inflow 6/s on the inhale), one light, one SurfaceGui (caustics), no parts drawn; its ignition adds ~40 particles for about a second, a pulse ~25.

## Known gaps
- Flowing Spring: previewed in Edit mode on the R6 rig (grass at noon and
  night) through the plain emitter fallback; play speed, R15, phones and the
  live sit / switch / breakthrough ignition are untested. The caustics disc
  has a hard round edge (UICorner on the image), softened only by the dark
  water blob around it.
