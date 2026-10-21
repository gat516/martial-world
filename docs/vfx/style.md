# VFX style and method

How this game's effects should look and how to get there. Applies to
techniques, auras, breakthroughs, world events and anomalies. The `vfx` agent
works from this doc; the plugin, library and Studio pipeline are in
[toolkit.md](toolkit.md).

Decided 2026-10-21 (user): effects are built the way Roblox VFX artists build
them, from the plugin's library emissions, layered thick, following reference
videos. Parts and meshes support the emissions; they are not the effect. The
first aura pass (part shells, Neon discs, code tweens, ~20 textures) was the
wrong direction. "3D first, sprites second" is retired.

**Scale follows progression (user, 2026-10-21).** Take the references'
craft (layering, contrast, motion, timing), not their size. Every technique
and method in the game today is a beginner one, so its effects stay small,
close and tasteful: a few well-made layers, not a screen-filling show.
Grandeur is earned: it grows with technique tier, method grade and realm, and
the big set pieces are reserved for breakthroughs, tribulation and world
events.

## What the references teach

The references are Roblox showcase effects (`docs/reference/vfx/`, the videos
below). Different games, same recipe:

1. **Many layers, one silhouette.** A single beat stacks 6 to 15 emitters: a
   white-hot flash, a star glint, a ring or two, streaks, sparkles, debris,
   smoke, and a sigil underneath. Each layer is simple; the stack reads as one
   bold shape.
2. **White-hot core, colour at the edges.** The centre of every bright thing
   is near-white (LightEmission 1, Brightness 2 to 10, so bloom catches it).
   The colour lives in the falloff, the rims and the secondary layers.
3. **Dark under light.** Bright white swirls sit on a black or deep-tint layer
   of the same shape (the ink vortex, the ink swirl dome). That contrast is
   what lets them read on a grey baseplate or green grass at noon. Never rely
   on brightness alone in daylight.
4. **Texture does the drawing.** Crescents, swirl strokes, star glints, speed
   lines, magic circles, shards and smoke puffs are hand-drawn textures on
   particles, beams and flat or curved meshes. The shape comes from the
   texture, the motion from Size/Transparency curves, rotation and speed.
5. **Everything moves.** Circles turn, rings expand, streaks fly radially in or
   out, sparkles twinkle (fast Transparency flicker), debris tumbles. Nothing
   bright stays still except the core.
6. **A shot has beats.** Anticipation (gather, circles stacking up, the world
   darkening), the climax (flash, white-out, impact frame, shake), the sustain
   (a loop if it stays), the tail (sparkles and smoke drifting off). Climaxes
   are short and huge; tails are long and quiet.
7. **The world reacts.** The big moments grade the screen: the sky darkens or
   tints, a ColorCorrection pulse, a white-out, an impact frame (inverted or
   tinted for one or two frames), camera shake. Sol's RNG cutscenes swap the
   whole world's mood for a few seconds.
8. **Rarer is louder.** Sol's RNG scales an aura from a ring of sparkles to a
   giant signature shape (crystal star, clock sigil, wings) with its own
   ambient field, ground sigil, title text and a cutscene on first roll. Each
   step up adds new layers, not just bigger ones.

### Reference index

| Ref | What to take from it |
|---|---|
| `vortex_impact_ink_rings.webp`, [vortex short](https://www.youtube.com/shorts/0H9MIjJNO-Q) | a beam streak lands, a flat vortex opens: black swirl under white swirl strokes, a cyan accent, a green inner dome, black and white cube debris, 4-point glints; it collapses to a thin ring |
| `slash_dome_ink_swirl.png` | a slash wrapped in a dome of curved white swirl strokes with a dark ink layer behind, smoke in the middle |
| `star_glint_blade.png` | a single 4-point glint with a lens ring at the tip of a blade: one layer, perfectly timed, sells a whole move |
| [Megumin explosion](https://www.youtube.com/watch?v=c_6YHwMt2cU) | anticipation as stacked magic circles rising one above another, light streaks shooting up, smoke ring, then a white-out, a pillar and a dome, then smoke filling the screen |
| [Holy Aura](https://www.youtube.com/shorts/TC4Ryp9e0Kk) | an aura: ground magic circle, a light shaft from above, a halo ring at the head, overexposed glow on the body, sparkles and feathers drifting |
| [Sol's RNG Luminosity](https://www.youtube.com/shorts/5bDNR9zqt4M) | a rare aura: a huge crystal star of textured shards with a white core, rays, a ground sigil, title text, snow-like sparkles; the cutscene darkens the world first |
| `aura_clock_sigil_crystal_trees.png` | a rare aura as a scene: a turning clock sigil overhead, a glowing ground circle, crystal trees, orbiting dark orbs, star field |
| [Sol's RNG Tomorrow](https://www.youtube.com/watch?v=pGb_klAsJB8) | the roll cutscene: the world fades to black, glyphs and a star burst on screen, white-out, then the aura on the player |
| [Enkidu: Enuma Elish](https://www.youtube.com/watch?v=vgYRw8hRj0g) | a world-scale event: a golden magic circle in the sky, a light pillar down to a ground circle, a cloud vortex, gold streaks and glints everywhere, a palette flip at the climax |

Study a video with `tools/ref_frames.py` (a frame grid, optionally of one
time window); it is for looking, nothing from a video goes in the game.

## Our version: xianxia and wuxia

Same recipe, our motifs. Swap the anime and fantasy pieces for these:

| Their piece | Ours |
|---|---|
| magic circle, clock sigil | bagua and taiji circles, talisman seals, rune rings with characters, a formation array (several rings turning against each other) |
| anime swirl strokes | ink-wash brush strokes: black ink swirls with a white or gold stroke on top; splashes of ink for impacts |
| crystal star, wings | a lotus (petals of light), a sword array (flying swords in a ring or fan), a phoenix or dragon outline of streaks |
| light shaft, halo | heavenly light pillar, a halo ring of characters, a crown of qi flames |
| feathers, sparkles | petals, falling leaves, jade motes, gold dust, snow, embers by element |
| smoke | cloud sea puffs, mist, incense smoke curling up |
| world goes dark | the sky dims and tints by element, clouds part, lightning in the distance for tribulation |

Palette: tie colour to meaning (`src/shared/Techniques.luau`, method elements,
realm colours). Gold and white for the heavens, jade for qi, vermilion for
talismans, black ink for contrast.

## Recipes

### A beat (any moment)

Build the stack, roughly back to front:
1. **Ground:** a sigil or ring flat on the floor (VelocityPerpendicular or a
   flat textured part), turning.
2. **Dark base:** the ink or deep-tint layer behind the bright shape.
3. **Main shape:** the signature texture (swirl, crescent, lotus, pillar).
4. **Core:** a white-hot glow and a star glint at the centre.
5. **Motion:** streaks or speed lines, radial in (gather) or out (release).
6. **Detail:** sparkles, debris, petals, embers, dust.
7. **Air:** a smoke or cloud puff that outlives the rest.
8. **Screen:** shake, impact frame, colour pulse (ScreenEffects) for big ones.

### Auras (seated, looping)

Model on Sol's RNG, scaled by method grade (the grade ladder in
[auras.md](../systems/auras.md)):
- **Always:** a loop of emissions on and around the body that breathes with
  the shared breath, a ground figure (the method's sigil or motif), and an
  ambient field (sparkles, petals, embers) out to the grade's reach.
- **Signature:** one big shape that is the method's idea, made of library
  textures: Blazing Heart's crown of flame, Frost Lotus's glass lotus, Iron
  Marrow's blade fan. It grows with grade.
- **Ignition:** sitting down or switching plays a short surge: a flash and
  the signature unfolding. Dimming the world around you is for high grades
  only; a Mortal ignition stays on and near the body. Small still has to be
  cool (user, 2026-10-21): the sit-down is a punchy, satisfying moment and the
  loop is an aura players want to show off. Small in size, high in quality.
- Parts are fine for what textures can't do (a core with a PointLight, a
  carved stone ring), but the aura must still read with them hidden.

### Techniques

Anticipation in the striking limb, release flash, travel, impact stack, tail.
Sync to the animation's markers ([toolkit.md](toolkit.md)). Tiers add layers:
tier I is a clean 4 to 6 layer stack, tier IV adds the screen and the world.

### World events and anomalies

The loudest effects in the game. They are seen from across the map, so they
work at three distances: far (a pillar or sky circle above the horizon, the
sky tinting over that zone), mid (the formation turning, clouds spiralling in,
streaks raining), and close (the full stack with sparkles and debris at
ground level). Arrival plays an Enkidu-style descent: a formation array opens
in the sky, a pillar of light drives down into a ground circle, the clouds
around it swirl, gold streaks and glints fill the air. See
[world.md](../systems/world.md) for the event kinds.

## Quality bar

- Put a reference frame next to your capture at the same moment. If yours has
  fewer layers, less contrast or less motion, it isn't done.
- Count layers per beat in the plan and the report.
- Read it at play speed, at 10 and 40 studs, on green grass at noon and at
  night. Daylight is where thin, single-layer effects disappear.
- Phones: most players are on phones. Keep each emitter's count modest and get
  richness from more kinds of layer, not more particles of one kind; turn
  ambient fields down before cutting layers.
