# Blazing Heart Sutra aura

Covers the Blazing Heart Sutra (Fire) method aura (template `Effects.MethodAura.BlazingHeart`): its brief, what is built, its budget and gaps; read it when changing this aura, after the shared rules in [auras](../systems/auras.md).

## Brief
- **Idea:** a heart that burns
- **Mortal aura (the brief):** an orange core in the chest that beats on the breath; short flame tongues licking up from shoulders and arms; embers rising; warm outline
- **Higher grades:** flames climb into a crown of fire above the head, then a burning lotus behind; Heaven: a phoenix silhouette
- **Refs:** red_flame_surge, purple_flame_outline (see [auras](../systems/auras.md#reference-images))

## What's built (Mortal; reworked: 17 loop emitters, no shell)
- **On the body:** white-hot heart core at the chest (glow that swells with the breath, a hard dot, a twinkling 4-point glint, the one PointLight); a flame mantle (library aura-flame flipbook) hugging the silhouette from behind on a darker soot copy of itself; realistic flipbook flames licking off the arms and torso; a small crown of licks off the head; black soot curling off the flame tips; embers and dark ash flecks. Flames, mantle and ground fire grow and shrink with the breath and drift slowly in size
- **Ground / around:** dark scorch disc, warm heat pool, a turning fire swirl, small flames on the rim; four hui-wen sigils: one on the ground turning against the swirl, three raised round the chest (added by the user, centred and level on the body axis) each turning its own way and drifting up, fading and starting again; all breathe in size and flash on the heartbeat and pulses
- **Breath beat:** a heartbeat: lub-dub glow at the chest with a glint and a spark puff, the mantle flares, a fire ring pulses out of the sigil. Every 1 or 2 breaths (about 5 or 10 s, a little late at random) the beat is a pulse instead: a lighter punch (flash and star at the heart, a starburst, embers, a few flame jets and flames, a ground ring, limb flames surging), the aura swelling into it
- **Ignition:** once fully seated: white flash and a chromatic star at the heart, a starburst flare, flame jets and flipbook flames roaring up round the body, a fire ring burning out over the ground, soot thrown low, an ember burst; limb flames surge

## Budget (R6)
17 loop emitters, about 60 live particles in the loop (limb flames 8/s per limb are the bulk), one light, one SurfaceGui sigil, no parts drawn; its ignition adds ~70 particles for about a second.

## Known gaps
- Blazing Heart: previewed in Edit mode on the R6 rig only, through the plain
  emitter fallback (the place has no `ReplicatedStorage.vfx` Game Module).
  Feel at play speed, R15, 8 seated auras on a phone and the live sit /
  switch / breakthrough ignition are untested. The library has no heart
  texture, so the heart is a glow, a dot and a glint, not a heart shape. The
  seated-moment ignition was checked on the preview rig (lit at Sit 1.40 /
  1.60 s), not on a live player or an observer's replicated tracks.
