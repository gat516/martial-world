User notes in plain words ("messy", "weak", "floaty") mapped to their usual causes and Roblox property fixes. vfx and world-fx agents use it for every user note and every own review round (`.claude/agents/vfx.md`, "Review").

# VFX translator: plain words to fixes

1. Restate the note as a cause ("messy: three layers peak on the same frame and two of them
   aren't caused by the roar").
2. **Subtract first:** what to remove or quiet before adding anything.
3. Change only what that cause needs, rebuild from the spec, look at the same moments from
   the same camera, and report the change in one plain sentence.

Keep the assets fixed while fixing a note (swapping textures every round makes rounds
impossible to compare); change an asset only when the note is about its shape.

| They say | Usual causes | Fixes (Roblox) |
|---|---|---|
| **messy, random, noisy, too busy** | Layers with no cause; no clear hero; everything peaks on the same frame; too many hues | Run the causality check and cut what fails. Pick one hero and drop the others in size, brightness (`Brightness`, `LightEmission`) and count. Stagger starts by 30–150 ms. One hue plus one accent plus white. |
| **doesn't feel sequential, all at once, no build-up** | No anticipation; layers start together; timers drift from the animation | Drive the phases from animation markers. Give the anticipation 20–40% of the effect, moving inward and growing. Start each layer after the one that causes it (`EmitDelay` or spec `from`). |
| **weak, no impact, no oomph, soft** | Eased-in peak; no white-hot frame; peak spread over many frames; nothing reacts | Make the peak instant: full size and brightness on frame 1, with `Size` and `Transparency` keys at 0 and around 0.05. Add a near-white core flash for 1–3 frames, a ring that expands fast and then slows, and dust or debris where it lands. On big hits, a hit-pause (`CombatEffects.punch`) and a short shake. |
| **floaty, slow, sluggish** | Linear curves; long lifetimes; gravity off on debris; slow speed early | Ease out: fast early, slow late (front-load the `Size` keys). Shorten `Lifetime`. Debris gets `Acceleration` down and `Drag`. Burst speed high with `Drag` 3–8 so particles shoot out and stop. |
| **stiff, static, lifeless** | No variation; nothing rotates; identical particles | Add `NumberRange` spread of ±20–40% on Lifetime, Speed, Rotation and RotSpeed. Rings and sigils turn. Sparkles flicker (a jagged `Transparency` sequence). |
| **cheap, flat, plasticky** | Neon parts doing a texture's job; a single layer; no value range; two-point fades | Move the shape onto a library texture or flipbook and keep the part only as support. Build the value from a white core to a saturated middle to a dark edge, with a dark base under the bright shape. Give hero layers 4+ key curves. |
| **can't see it, washed out (daylight)** | Brightness alone; nothing dark behind it; thin shape | A dark or slate copy of the same shape behind it (`LightEmission` 0, `LightInfluence` 1). A bolder silhouette or bigger hero, not more particles. Check on grass at noon. |
| **white mush, blown out, glowy blob** | Everything glows; overlapping additive sprites; the core is too big | Put smoke and dust on `LightEmission` 0 with `LightInfluence` up. Shrink the core. Fewer and larger overlaps. Push colour into the rims and lower the brightness of the secondaries. |
| **muddy, dirty, grey** | Dark layers in front of bright ones; low saturation in the middle tones; smoke too thick | Order the layers (`ZOffset`) so the bright layers sit in front. Thin the smoke (higher `Transparency`, fewer). Saturate the middle of the colour ramp. |
| **lingers, too long, drags** | A tail with no gameplay job; `Lifetime.Max` too long | Shorten the dissipation and break it up (shrink, `Transparency` to 1, speed falling off). Nothing stays without a job. |
| **too much, over the top, distracting** | Above its scale tier; screen effects on small moments; fills the screen | Back to the scale rule in [style.md](style.md): cut screen effects and the world grade, shrink the reach, and keep the craft. |
| **too small, underwhelming (for a big moment)** | One layer carries the moment; no environment reaction; no feel layer | Add an environment layer (one light flash, ground dust or a scorch) and, if the tier earns it, a feel layer. Make the hero bigger before adding new elements. |
| **doesn't fit, wrong element, generic** | The theme drives the shape instead of the action; another beast's palette; a stock texture | Let the action decide shape, origin and direction, and the theme only colour and texture. Use the element palette in `.claude/agents/vfx.md`. Choose textures with that element's shape language. |
| **wrong place, comes from nowhere** | The emitter isn't on the cause; it isn't oriented to it | Put the emitter on an Attachment at the mouth, the contact point or the blade tip, aimed away from the cause. |
| **laggy (phones)** | Many large overlapping transparent sprites; high rates; lights per hit | Fewer and better-shaped particles; budget in [toolkit.md](toolkit.md); no per-hit lights. |

## Shape and blend at a glance

- Jagged shapes read as electric or dangerous, round ones as soft or magical,
  tapered ones as motion.
- `LightEmission` near 1 for energy, fire cores and sparks. Near 0, with
  `LightInfluence` up, for smoke, dust and debris. Dark smoke behind bright
  fire gives contrast; making everything glow gives white mush.
- A good hero still reads in grayscale.
