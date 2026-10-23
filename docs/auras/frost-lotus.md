# Frost Lotus Sutra aura

Covers the Frost Lotus Sutra (Ice, rare) method aura (template `Effects.MethodAura.FrostLotus`): its brief, what is built, its budget and gaps; read it when changing this aura, after the shared rules in [auras](../systems/auras.md).

## Brief
- **Idea:** blooming cold and clear
- **Mortal aura (the brief):** frost spreading on the ground in a lotus shape that opens a petal ring per breath; a rime outline; breath mist; a few flakes
- **Higher grades:** a crystal lotus blooms around you; Heaven: a giant ice lotus behind, snow falling across the area
- **Refs:** constellation_dantian_core (cold blue palette) (see [auras](../systems/auras.md#reference-images))

## What's built (Mortal; reworked: 11 loop emitters + 33 petal images, no light, no shell)
- **On the body:** a cold bud between the hands (a deep-blue halo under a white-hot dot and a twinkling glint); frost glints twinkling on the skin; cold vapour pouring off the arms and sinking to the ground
- **Ground / around:** a deep-blue cracked-ice disc (the dark base) with pale frost creeping out over it, a soft cold light filling the cup; a glass lotus of leaf-veined petals (flat library images, both faces, no Grow) in three rings, inner and upright first, then one more ring each breath, turning slowly; ice crystals growing and melting round the rim; frost petals lifting off it; diamond dust falling
- **Breath beat:** the exhale: breath mist from the mouth, a frost ring breaking out over the ground, a glint at the bud, a few petals lifting, the petals glinting. Every 2 or 3 breaths (0.5 s jitter, 1.3x swell) the beat is a bloom instead: a frost flash over the ice, a crown of ice (library crown mesh, ForceField) springing up and melting, crystals and petals thrown up, a flash and star at the bud; skin glints and vapour surge
- **Ignition:** a cold white flash, chromatic star and cross star at the bud, a crown of ice spikes bursting up round the body with a petal crown inside it (library meshes, ForceField waves), frost slamming out over the ground and a frost ring breaking, ice crystals springing up, glass shards and petals thrown up, a low cold puff; skin glints and vapour surge

## Budget (R6)
11 loop emitters, about 50 live particles (diamond dust and skin glints are the bulk), 33 petal parts with two SurfaceGuis each (moved, never resized: resizing a SurfaceGui's part re-renders it), no light, no shell; a bloom adds ~20 particles and a mesh wave, the ignition ~45 and two mesh waves.

## Known gaps
- Frost Lotus and Sect Breathing: previewed in Edit mode on an R6 rig (grass
  at noon and night) through the plain emitter fallback; play speed, R15,
  phones and the live sit / switch / breakthrough ignition are untested. The
  library has no lotus-petal texture, so the petals are a veined leaf image
  laid on flat parts in rings (they read as a glass lotus from the usual
  camera, edge-on from level). On a blocky R6 rig the seated arms hide most
  of what sits within ~2 studs of the body, which is why both ground figures
  reach about 3.5 studs out; slimmer avatars show more of them. Sect's taiji
  is a bold black-and-white image kept faint; its ignition surge brings it
  near full strength for a moment.
