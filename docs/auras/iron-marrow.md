# Iron Marrow Art aura

Covers the Iron Marrow Art (Metal) method aura (template `Effects.MethodAura.IronMarrow`): its brief, what is built, its budget and gaps; read it when changing this aura, after the shared rules in [auras](../systems/auras.md).

## Brief
- **Idea:** qi hammered into the bones
- **Mortal aura (the brief):** a hard white-gold diamond core between the hands; on each exhale a clang: a thin metal ring snaps outward with sparks; a cold steel glint sweeps the outline
- **Higher grades:** the clang becomes a sunburst of blades behind you; Heaven: a radiant halo of swords
- **Refs:** sunburst_diamond_core (see [auras](../systems/auras.md#reference-images))

## What's built (Mortal; reworked: 13 loop emitters, 5 bone beams, one small gem part in support)
- **On the body:** a hard white-gold diamond between the hands: a small spinning Neon gem (support), a gold glow that swells with the breath, a white-hot dot, a long-armed star turning slowly, a dark iron halo behind it, the one PointLight; a small halo of soft gold rays turning behind the head and shoulders on a dark iron disc (the diamond's sunburst, kept small); gold bone lines along the arms and spine with star glints at the joints (they flash on every clang); a cold needle glint running over the arms and torso, a faint gold sheen inside the limbs; forge sparks spitting off the hands and falling
- **Ground / around:** a black spiked iron ring (the dark base; its spikes are blades), an ornate gold filigree ring turning the other way inside it, a molten gold glow, spiky gold spark-splashes popping on the floor, thin gold streaks rising round the seat like forge heat (thick on the inhale), metal filings lifting and tumbling
- **Breath beat:** the clang on each exhale: a spiky ring snaps out of the diamond with a star, sharp crack glints and a spark spray, a thin ring runs over the floor, bones and the gold ring flash. Every 2 or 3 breaths (0.3 s jitter, 1.3x swell) a heavier blow: gold rays fan out behind the body, a big clang ring, flash and star, a spark shower, a spiky ring over the ground, filings thrown out; limb glints and sparks surge
- **Ignition:** the first great blow: a white flash, a long star and an X glint at the diamond, rays behind, clang rings facing you and over the ground, a spiky gold burst and a thin ring on the floor, 30 sparks, steel shards thrown up; limb sparks and glints surge

## Budget (R6)
13 loop emitters, about 50 live particles (rising streaks 9/s at the peak, filings, limb sheen), 5 bone beams with 6 joint dots, one light, two SurfaceGui rings, one 0.34-stud gem part; its ignition adds ~50 particles for about a second, a pulse ~35.

## Known gaps
- Iron Marrow: previewed in Edit mode on the R6 rig (grass at noon and
  night) through the plain emitter fallback; play speed, R15, phones and
  the live sit / switch / breakthrough ignition are untested. The diamond
  is still a small Neon gem part (support); hidden, the glow, dot and
  star still read as the core.
