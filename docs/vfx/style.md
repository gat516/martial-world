How this game's effects should look and the rules for getting there (techniques, auras, breakthroughs, enemy attacks, world events). Every vfx and world-fx agent reads all of it; tools are in [toolkit.md](toolkit.md), plain-word notes in [translator.md](translator.md), the method in `.claude/agents/vfx.md`.

# VFX style and method

## User decisions

- **Library emissions, layered (2026-10-21).** Effects are built the way Roblox VFX artists
  build them: the plugin's library emissions, layered thick, following references. Parts and
  meshes support the emissions; they are not the effect. The first aura pass (part shells,
  Neon discs, code tweens, ~20 textures) was the wrong direction; "3D first, sprites second"
  is retired.
- **Scale follows progression (2026-10-21).** Take the references' craft (layering, contrast,
  motion, timing), not their size. Every technique and method today is a beginner one, so
  its effects stay small, close and tasteful: a few well-made layers, not a screen-filling
  show. Grandeur grows with technique tier, method grade and realm; the big set pieces are
  reserved for breakthroughs, tribulation and world events.
- **No research by default (2026-10-21).** Many effects are already decent, and "emit it from
  the vfx library" is the method. Work from the reference library, this doc and the effects
  in the game, and go straight to the vfx library. No YouTube or tutorial searches unless the
  user asks, or a look isn't covered and can't be built otherwise.
- **Every effect starts fresh (2026-10-21).** An effect's look comes from its own idea, never
  copied from earlier effects. Docs record how tools behave and techniques for getting a kind
  of look, not a house style: no "use these textures", no recipes copied from the last build.
  What one effect used is history in its system doc, not guidance. (The first aura pass
  looked generic because it reused one technique's picks.)
- **Every layer is caused; one hero (2026-10-22).** Effects were often technically fine but
  felt random: layers added because they looked cool, no clear start, peak and end, nothing
  tied to the action, everything popping on the same frame. So every effect starts from an
  intent (what is happening, what the player should feel, its gameplay job) and a beat sheet
  in ms. Each layer must answer what caused it, where it comes from, where its energy goes and
  why it lasts that long, or it is cut. The action decides shape, origin, direction and
  timing; the theme (element, motif) decides colour and texture only. One hero layer sells the
  moment; the rest support it, smaller, dimmer and staggered 30-150 ms behind their cause.
  Subtract before you add.

## What the references teach

Roblox showcase effects ([reference library](../reference/vfx/README.md)), different games,
same recipe:

1. **Many layers, one silhouette.** A big beat can stack 6 to 15 emitters (white-hot flash,
   star glint, a ring or two, streaks, sparkles, debris, smoke, a sigil underneath), each
   simple and caused by the moment, reading as one bold shape with one hero. The count follows
   from the causes, never the other way round.
2. **White-hot core, colour at the edges.** The centre of every bright thing is near-white
   (LightEmission 1, Brightness 2 to 10, so bloom catches it); colour lives in the falloff,
   rims and secondary layers.
3. **Dark under light.** Bright swirls sit on a black or deep-tint layer of the same shape
   (the ink vortex, the ink swirl dome). That contrast is what reads on a grey baseplate or
   green grass at noon; never rely on brightness alone in daylight.
4. **Texture does the drawing.** Crescents, swirl strokes, star glints, speed lines, magic
   circles, shards and smoke puffs are hand-drawn textures on particles, beams and flat or
   curved meshes. Shape comes from the texture, motion from Size/Transparency curves,
   rotation and speed.
5. **Everything moves.** Circles turn, rings expand, streaks fly radially, sparkles twinkle
   (fast Transparency flicker), debris tumbles. Nothing bright stays still except the core.
6. **A shot has beats.** Anticipation (gather, circles stacking, the world darkening), climax
   (flash, white-out, impact frame, shake), sustain (a loop if it stays), tail (sparkles and
   smoke drifting off). Climaxes are short and huge; tails long and quiet.
7. **The world reacts.** Big moments grade the screen: the sky darkens or tints, a
   ColorCorrection pulse, a white-out, an impact frame (inverted or tinted for 1-2 frames),
   camera shake. Sol's RNG cutscenes swap the whole world's mood for a few seconds.
8. **Rarer is louder.** Sol's RNG scales an aura from a ring of sparkles to a giant signature
   shape (crystal star, clock sigil, wings) with its own ambient field, ground sigil, title
   text and a first-roll cutscene. Each step up adds new layers, not just bigger ones.

Read the reference library before researching and add to it after. `tools/ref_frames.py`
makes a frame grid of a video (optionally one time window); it is for looking only, nothing
from a video goes in the game.

## Our version: xianxia and wuxia

| Their piece | Ours |
|---|---|
| magic circle, clock sigil | bagua and taiji circles, talisman seals, rune rings with characters, a formation array (several rings turning against each other) |
| anime swirl strokes | ink-wash brush strokes: black ink swirls with a white or gold stroke on top; ink splashes for impacts |
| crystal star, wings | a lotus (petals of light), a sword array (flying swords in a ring or fan), a phoenix or dragon outline of streaks |
| light shaft, halo | heavenly light pillar, a halo ring of characters, a crown of qi flames |
| feathers, sparkles | petals, falling leaves, jade motes, gold dust, snow, embers by element |
| smoke | cloud sea puffs, mist, incense smoke curling up |
| world goes dark | the sky dims and tints by element, clouds part, distant lightning for tribulation |

Palette ties colour to meaning (`src/shared/Techniques.luau`, method elements, realm colours;
enemy element palette in `.claude/agents/vfx.md`): gold and white for the heavens, jade for
qi, vermilion for talismans, black ink for contrast.

## Recipes

### A beat (any moment), back to front
1. **Ground:** a turning sigil or ring flat on the floor (VelocityPerpendicular or a flat
   textured part).
2. **Dark base:** the ink or deep-tint layer behind the bright shape.
3. **Main shape:** the signature texture (swirl, crescent, lotus, pillar).
4. **Core:** a white-hot glow and a star glint at the centre.
5. **Motion:** streaks or speed lines, radial in (gather) or out (release).
6. **Detail:** sparkles, debris, petals, embers, dust.
7. **Air:** a smoke or cloud puff that outlives the rest.
8. **Screen:** shake, impact frame, colour pulse (ScreenEffects), big moments only.

### Auras (seated, looping)
Modelled on Sol's RNG, scaled by method grade ([auras.md](../systems/auras.md) grade ladder):
- **Always:** a loop of emissions on and around the body breathing with the shared breath, a
  ground figure (the method's sigil or motif), and an ambient field (sparkles, petals, embers)
  out to the grade's reach.
- **Signature:** one big shape that is the method's idea, made of library textures (Blazing
  Heart's crown of flame, Frost Lotus's glass lotus, Iron Marrow's blade fan), growing with
  grade.
- **Ignition:** sitting down or switching plays a short surge: a flash and the signature
  unfolding. Dimming the world is for high grades only; a Mortal ignition stays on and near
  the body. Small still has to be cool (user, 2026-10-21): the sit-down is a punchy,
  satisfying moment and the loop an aura players want to show off. Small in size, high in
  quality.
- Parts are fine for what textures can't do (a core with a PointLight, a carved stone ring),
  but the aura must still read with them hidden.

### Techniques
Anticipation in the striking limb, release flash, travel, impact stack, tail, synced to the
animation's markers ([toolkit/animation-sync.md](toolkit/animation-sync.md)). Tiers add
layers: tier I is a clean 4-6 layer stack, tier IV adds the screen and the world.

Remake rules (user, 2026-10-21: "the design of all of them are great ... remake them in
respect to our weapon models and hit / hit stop timings"):
- **A weapon technique comes off the weapon, not the hand.** The anticipation is a `Charge`
  part riding the held model's `Base` -> `Tip` span (a dark beam under a bright one, motes
  along the edge, a glint at the point; `WeaponFX.charge`); the release flashes at the live
  `Tip`; trails and arcs sit on the real blade length. A staff or spear glows end to end
  (`full`). Fist and bare-hand techniques keep the hand.
- **Three clocks; every layer sits on one.** Windup (cast start -> `Hit`): the charge, a
  stream through the whole windup rather than one burst. Active (`Hit` -> `Hit Stop`): the
  release, the travel and every impact stack; a projectile's arrival is squeezed into this
  window (`WeaponFX.landing`) because the damage number shows at `Hit`. Recovery (after
  `Hit Stop`): the tail (embers, scars, smoke) keeps its own fade.
- **Dark under light on every hit:** an ink splat behind the white-hot star and a flipbook
  burst that opens and breaks up, so a hit reads on grass at noon; tier III+ adds a smoke
  flipbook tail.
- **Land where the blade lands (QA pass, 2026-10-21).** On the long weapon clips `Hit` fires
  as the swing starts, blade still raised. What belongs to the cut (the flare, a claw, the
  slam's bite and crack) plays at the swing's peak inside that hit's Hit -> Hit Stop window
  (`WeaponFX.swing`), facing the swing, not the root. Anything a cast leaves running registers
  with `WeaponFX.onCancel`, so a dodge or stun clears it.
- **Ground cracks are carved, not drawn (user, 2026-10-21: the Neon crack "is kinda eh").** A
  dark carved crack with the element's qi burning in it and cooling, debris and dust kicked up
  along it as it opens, a shock at the bite. Never a flat Neon strip.
- **Oomph (user, 2026-10-21: "stuff just needs more oomph").** Every release and hit has a
  white-hot frame, a shock ring and a dark base; big hits at II+/III+ add a hit-pause punch
  (`CombatEffects.punch`) and a harder shake. Tier I stays clean; punch and impact frames are
  earned.

### World events and anomalies
The loudest effects, built by `world-fx` (`.claude/agents/world-fx.md`;
[world_events.md](world_events.md); event kinds in [world.md](../systems/world.md)). Seen
from across the map, so they work at three distances: far (a pillar or sky circle above the
horizon, the sky tinting over that zone), mid (the formation turning, clouds spiralling in,
streaks raining), close (the full stack with sparkles and debris at ground level). Arrival is
an Enkidu-style descent: a formation array opens in the sky, a pillar of light drives down
into a ground circle, the clouds around it swirl, gold streaks and glints fill the air.
Looks the user asked for (2026-10-21): the sky splitting open, clouds parting, violet and
purple cloud mist for treasure births, a striking light pillar, and the ring of
`Cloud_WispArc` meshes round the main peak (`Workspace.Map.Clouds.Wisps`) animated and
recoloured per event. Every placed piece is checked upright at several spots through the real
event code path; event effects have come out lying on their side before.

## Quality bar

- Every layer has a cause, one hero leads, starts are staggered, exactly one peak frame. Score
  readability, hierarchy, timing, causality and fit 1-5 on the same frozen moments each round,
  and fix the three worst.
- Put a reference frame next to your capture at the same moment. Less contrast, less motion or
  a weaker silhouette means not done; fewer layers is fine when the cut ones had no cause.
- Count layers per beat in the plan and the report.
- Read it at play speed, at 10 and 40 studs, on green grass at noon and at night. Daylight is
  where thin, single-layer effects disappear.
- Phones (most players): modest counts per emitter, richness from more kinds of layer, not
  more particles of one kind; turn ambient fields down before cutting layers. Numbers in
  [toolkit.md](toolkit.md), "Budget".
