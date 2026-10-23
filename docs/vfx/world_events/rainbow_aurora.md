PLAN (not built): Rainbow Aurora, replacing the camera-relative Neon slabs with world-fixed beams. Read when you build Rainbow Aurora (step 3).

# Rainbow Aurora (anomaly, global) — plan

Today (`client/WeatherFX.luau`): 65 Neon slabs in long curved bands placed relative to the
camera, a new set every time it starts. Its treasures are pearl and built
([treasure_birth.md](treasure_birth.md); the pearl pillar blows out to white up close in
daylight, world.md known gaps). Kit and rules: [../world_events.md](../world_events.md).

Replace the slabs with world-fixed Beams, about 10 beams and a few emitters:
- **Rainbow:** 5 colour Beams, each one curved arc (CurveSize0/1) spanning the sky south of
  the main peak, a soft gradient texture, LightEmission 1, shimmer (TextureSpeed) and a slow
  width breath. Anchored over the sect, not around the camera, so everyone sees the same arc
  in the same place.
- **Aurora curtains:** 3-4 ray-texture Beams high in the north, colours cycling slowly.
- `WispsRing` in pearl white with prismatic rims (accent emitters).
- Treasures: pearl pillar with a rainbow outer haze.
