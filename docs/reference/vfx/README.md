# VFX reference library

Every reference an effect has been built from, with what was learned from it,
so the next effect starts here instead of researching again. The `vfx` and
`world-fx` agents read this first, research only what it doesn't cover, and add
a row (and a breakdown) for every reference they use. Seated-aura stills from
the user are described in [auras.md](../../systems/auras.md) "References".

- Stills and frame grids live next to this file (`world/` for sky-scale
  events). Name them for what they show, not the video id.
- Videos are cached in `~/.cache/ref_frames` by `tools/ref_frames.py` (not in
  the repo), so re-gridding a listed video is instant and needs no download.
  Pass the URL as usual.
- A **breakdown** is the layer list per beat (texture, carrier, motion, timing,
  colour, dark base) with timestamps. Write it once, here, and reuse it; the
  plan for a new effect can then say "Enkidu sky circle, layers 1-4" instead
  of re-deriving it.

## Effects (techniques, hits, auras)

| Ref | Source | What to take from it |
|---|---|---|
| `vortex_impact_ink_rings.webp` | [vortex short](https://www.youtube.com/shorts/0H9MIjJNO-Q) | a beam streak lands, a flat vortex opens: black swirl under white swirl strokes, a cyan accent, a green inner dome, black and white cube debris, 4-point glints; it collapses to a thin ring |
| `slash_dome_ink_swirl.png` | user still | a slash wrapped in a dome of curved white swirl strokes with a dark ink layer behind, smoke in the middle |
| `star_glint_blade.png` | user still | a single 4-point glint with a lens ring at the tip of a blade: one layer, perfectly timed, sells a whole move |
| - | [Megumin explosion](https://www.youtube.com/watch?v=c_6YHwMt2cU) | anticipation as stacked magic circles rising one above another, light streaks shooting up, smoke ring, then a white-out, a pillar and a dome, then smoke filling the screen |
| - | [Holy Aura](https://www.youtube.com/shorts/TC4Ryp9e0Kk) | an aura: ground magic circle, a light shaft from above, a halo ring at the head, overexposed glow on the body, sparkles and feathers drifting |
| - | [Sol's RNG Luminosity](https://www.youtube.com/shorts/5bDNR9zqt4M) | a rare aura: a huge crystal star of textured shards with a white core, rays, a ground sigil, title text, snow-like sparkles; the cutscene darkens the world first |
| `aura_clock_sigil_crystal_trees.png` | user still | a rare aura as a scene: a turning clock sigil overhead, a glowing ground circle, crystal trees, orbiting dark orbs, star field |
| - | [Sol's RNG Tomorrow](https://www.youtube.com/watch?v=pGb_klAsJB8) | the roll cutscene: the world fades to black, glyphs and a star burst on screen, white-out, then the aura on the player |
| `fire_aura_smoke_outline.png` | [video](https://www.youtube.com/watch?v=T9jHZv8NOtQ) | flames hugging the silhouette with black smoke at the tips (auras.md) |
| `fire_aura_swirl_ground.png` | [video](https://www.youtube.com/watch?v=aBfd3qMOz_k) | a flame outline over a turning fire swirl on the ground (auras.md) |

## World events and anomalies (`world/`)

| Ref | Source | What to take from it |
|---|---|---|
| `world/enkidu_enuma_elish_grid.png` | [Enkidu: Enuma Elish](https://www.youtube.com/watch?v=vgYRw8hRj0g) | a world-scale event: a golden magic circle in the sky, a light pillar down to a ground circle, a cloud vortex, gold streaks and glints everywhere, a palette flip at the climax |

The world-events pass (2026-10-21) gathered more grids in `world/`
(Excalibur light pillar, Sol's RNG Equinox cutscene, Genshin void rift sky,
Perfect World nine tribulations, violet qi from the east, a Xianwu violet mist
treasure, a celestial rain showcase); their rows and breakdowns are added with
that pass's plan.

## Breakdowns

None written down yet. Add one per reference as you break it down:

```
### <ref name>  (<source>, <timestamps used>)
Far read: <the one shape and colour seen from afar, world refs only>
Beat <name> (<t0>-<t1>s): <n> layers
1. <texture/look> | <carrier> | <motion> | <timing> | <colour> | dark base y/n
...
Our translation: <xianxia motif per layer, library ids that worked>
```
