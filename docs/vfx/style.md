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

**No research by default (user, 2026-10-21, later).** Many effects are
already decent, and "emit it from the vfx library" is the method. Don't search
YouTube or tutorials when starting each new effect: work from the reference
library below, this doc and the effects in the game, and go straight to the
vfx library. New research only when the user asks, or when a look isn't
covered and can't be built otherwise.

**Every effect starts fresh (user, 2026-10-21).** An effect's look comes from
its own idea, never copied from earlier effects. Docs record
how tools behave (gotchas, techniques for getting a kind of look), not a house
style: no "use these textures", no recipes copied from the last build. What
one effect used is history in its system doc, not guidance for the next. The
first aura pass looked generic because it reused one technique's picks.

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

Every reference, with what to take from it and its layer breakdown, is in
[docs/reference/vfx/README.md](../reference/vfx/README.md). Read it before
researching; add to it after. Study a video with `tools/ref_frames.py` (a
frame grid, optionally of one time window); it is for looking, nothing from a
video goes in the game.

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

The remake rules (user, 2026-10-21: "the design of all of them are great ... remake
them in respect to our weapon models and hit / hit stop timings"):
- **A weapon technique comes off the weapon, not the hand.** The anticipation
  is a `Charge` part that rides the held model's `Base` -> `Tip` span (a dark
  beam under a bright one, motes along the edge, a glint at the point;
  `WeaponFX.charge`), the release flashes at the live `Tip`, trails and arcs
  sit on the real blade length. A staff or spear glows end to end (`full`).
  Fist and bare-hand techniques keep the hand.
- **The cast has three clocks, and every layer sits on one.** Windup (cast
  start -> `Hit`): the charge, a stream through the whole windup rather than
  one burst. Active (`Hit` -> `Hit Stop`): the release, the travel and every
  impact stack; a projectile's arrival is squeezed into this window
  (`WeaponFX.landing`) because the damage number shows at `Hit`. Recovery
  (after `Hit Stop`): the tail (embers, scars, smoke) keeps its own fade.
- **Dark under light, on every hit.** The impact stack carries an ink splat
  behind the white-hot star and a flipbook burst that opens and breaks up, so a
  hit reads on grass at noon; tier III+ adds a smoke flipbook tail.

### World events and anomalies

The loudest effects in the game. They are seen from across the map, so they
work at three distances: far (a pillar or sky circle above the horizon, the
sky tinting over that zone), mid (the formation turning, clouds spiralling in,
streaks raining), and close (the full stack with sparkles and debris at
ground level). Arrival plays an Enkidu-style descent: a formation array opens
in the sky, a pillar of light drives down into a ground circle, the clouds
around it swirl, gold streaks and glints fill the air. See
[world.md](../systems/world.md) for the event kinds.

The `world-fx` agent builds these (`.claude/agents/world-fx.md`). Looks the
user asked for (2026-10-21): the sky splitting open, clouds parting, violet
and purple cloud mist for treasure births, a striking light pillar, and the
circular cloud at `Workspace.Map.Clouds.Wisps` (a ring of `Cloud_WispArc`
meshes round the main peak) animated and recoloured per event. Every
placed piece is checked upright at several spots through the real event code
path; event effects have come out lying on their side before.

## Quality bar

- Put a reference frame next to your capture at the same moment. If yours has
  fewer layers, less contrast or less motion, it isn't done.
- Count layers per beat in the plan and the report.
- Read it at play speed, at 10 and 40 studs, on green grass at noon and at
  night. Daylight is where thin, single-layer effects disappear.
- Phones: most players are on phones. Keep each emitter's count modest and get
  richness from more kinds of layer, not more particles of one kind; turn
  ambient fields down before cutting layers.
