# Thunder Pulse Manual aura

Covers the Thunder Pulse Manual (Lightning, rare) method aura (template `Effects.MethodAura.ThunderPulse`): its brief, what is built, its budget and gaps; read it when changing this aura, after the shared rules in [auras](../systems/auras.md).

## Brief
- **Idea:** sudden bursts
- **Mortal aura (the brief):** dark idle with glowing purple-white cracks across the torso and arms that flare irregularly; arcs jump from hands to the ground on a burst; ozone sparks
- **Higher grades:** arcs fill the space and strike the ground around you; Heaven: a thunder dragon coiled behind
- **Refs:** dark_lightning_cracks (see [auras](../systems/auras.md#reference-images))

## What's built (Mortal; reworked: 8 loop emitters + ~40 beams; the dark shell the only part)
- **On the body:** a faint dark tint over the body (support); jagged lightning cracks across chest, belly and arms, each a thin white core (re-jagged every burst) over a wide violet glow band; dark smoke tendrils curling off the head, shoulders and arms; a violet charge glow on the skin and short arcs (bolt sprites) crackling on it, both flaring on a burst; tiny zigzag ozone sparks; a violet node where the chest cracks meet
- **Ground / around:** a dark storm pool under you, a scorched rubble ring round a lightning-crack web (two SurfaceGui images) that flashes on a burst, an electric ring crackling at the rim and small arcs crawling on the ground, both spiking on a burst
- **Breath beat:** irregular bursts (0.5 to 2.6 s apart): a flash, spark and radial arcs at the chest crack, bolts (white core in a crawling bolt-texture glow) from both hands to the ground with spark splashes where they land, a snap ring and a crack-web flash on the ground, the skin crackles
- **Ignition:** a bolt strikes the crown (two branching bolts), a white and chromatic flash there, radial lightning at the chest, arcs filling the space round the body, an electric ring and a crack web blasting over a scorched rubble ring, dark smoke thrown low, zigzag sparks; skin arcs surge

## Budget (R6)
8 loop emitters (4 on the ground and chest node, 4 limb kinds), about 25 live particles at rest (smoke tendrils are the bulk), spiking on each burst; ~40 beams (9 cracks of 2-3 core segments plus a glow each, 2 hand bolts of 4 segments plus a glow); no light, two SurfaceGui images, the dark shell; a burst adds ~15 particles, the ignition ~45 for about half a second.

## Known gaps
- Thunder Pulse: previewed in Edit mode on an R6 rig (grass at noon and
  night) through the plain emitter fallback; play speed, R15, phones and the
  live sit / switch / breakthrough ignition are untested, and how the
  irregular bursts feel next to a calm seated crowd. The ignition bolt is a
  square sprite whose top edge can show for its 0.28 s. The dark shell is
  kept as a faint tint (support); it reads without it.
