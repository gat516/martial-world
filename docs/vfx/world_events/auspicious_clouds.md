PLAN (not built): lifting the three Auspicious Clouds world events with the WorldFX kit while keeping their existing look. Read when you work on Auspicious Clouds, Violet Cloud Mist or Golden Auspicious Clouds (step 4).

# Auspicious Clouds, Violet Cloud Mist, Golden Auspicious Clouds — plan

Today: the only event with a real look (`WorldEvents/AuspiciousClouds.luau`,
`client/WorldEventFX.luau`, `Effects.AuspiciousClouds`, spec
`tools/vfx_specs/AuspiciousClouds.luau`): wisp patterns descend and turn, a Column through the
cloud plane and a Whirl on it, a seal and an unseal burst, a relic that bobs. The spec assumes
the plane at 440 (`PlaneTop`); it's at ~339.6, so the Column and Whirl may sit 100 studs off
(world.md known gaps). Kit and rules: [../world_events.md](../world_events.md). Reference:
Enkidu (descent).

Keep the existing look (the user likes the wisp patterns) and lift it with the kit. These are
runtime additions from the WorldFX templates, so `Effects.AuspiciousClouds` doesn't change
and Effects.rbxm isn't exported (moving these pieces into WorldFX is a later coordinated
move, decision 1).
- **Arrival** (Enkidu descent, 0-8 s): the SkyCircle opens over the spot at Y ~1100, in the
  def's colours: white and jade bagua for Vortex, a violet ruyi ring for Mist, a gold
  sword-array ring for Spiral. The LightPillar drives down, taking the Column's far role (the
  old Column stays as the mid layer or is hidden: decide at a side-by-side with the user).
  Then the existing wisps descend.
- **Sustain:** pillar and sky circle turn; the plane puncture ring sits on the Whirl. Violet
  Cloud Mist adds the violet mist bank and local violet grade (the treasure's close layer).
  Golden adds gold rays and sword glints.
- **Unseal:** the existing burst plus a pillar flare, the sky circle shattering, and a
  white-out pulse within 120.
- **Depart:** the pillar collapses into the sky.

Budget: existing build + 3 beams, 2 SurfaceGuis, 4 arcs far; mid and close as existing.
