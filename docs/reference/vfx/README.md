Index of every VFX reference an effect has been built from (stills and frame grids here, `world/` for sky-scale events), with what to take from each. vfx and world-fx agents read it before planning; per-beat layer breakdowns are in [breakdowns.md](breakdowns.md), read the ones your effect uses.

# VFX reference library

- Research only what this doesn't cover, and for every reference you use add a row here and
  a breakdown in [breakdowns.md](breakdowns.md), in the same commit as the effect.
  Seated-aura stills from the user are described in [auras.md](../../systems/auras.md)
  "Reference images" and each aura's file in `docs/auras/`.
- Name stills and grids for what they show, not the video id. Videos are cached in
  `~/.cache/ref_frames` by `tools/ref_frames.py` (not in the repo), so re-gridding a listed
  video is instant; pass the URL as usual.

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
| `claw_slash_streaks_grid.webp` | [Wolf Claws Slash short](https://www.youtube.com/shorts/9yNr853ziDo) | a claw rake: three tapered parallel streaks with a white core and a coloured falloff, a first diagonal set then a second crossing it, ~0.3 s each; no ground, no smoke: the streak texture is the whole effect |
| `ground_slam_dome_rocks_grid.webp` | [Ground Slam (Studio)](https://www.youtube.com/watch?v=834aKXq3c-c) | a landing: white-out flash, a translucent dome and flat shockwave ring, a ring of rock slabs tilting out, a glowing ground decal that browns into a scorch, thin speed rays and sparks shooting off |

## World events and anomalies (`world/`)

| Ref | Source | What to take from it |
|---|---|---|
| `world/enkidu_enuma_elish_grid.png` | [Enkidu: Enuma Elish](https://www.youtube.com/watch?v=vgYRw8hRj0g) | a world-scale event: a golden magic circle in the sky, a light pillar down to a ground circle, a cloud vortex, gold streaks and glints everywhere, a palette flip at the climax |
| `world/celestial_rain_showcase_grid.png` | [Celestial Rain](https://www.youtube.com/watch?v=rLwXdIO5Yro) | a treasure descent: a star glint in the sky bursts into gold arcs that fan down, long streaks rain, the landing is a cross glint; also a violet orb over a violet ground swirl, a white-out, a dark violet smoke slab flipping to a gold burst |
| `world/genshin_void_rift_sky_grid.png` | [Genshin Skirk void rift](https://www.youtube.com/watch?v=Lw0gsWWTJME) | a rift tearing open out of a 4-point glint: white-hot glassy lips with blue falloff, a dark patterned star-sea inside (dark under light), shard edges |
| `world/sols_rng_equinox_cutscene_grid.png` | [Sol's RNG Equinox cutscene](https://www.youtube.com/watch?v=2qKeyCPI9Mw) | the screen cut by one hard diagonal seam, black against white, with a star glint on the seam; thin rings and bars sliding past: a split as pure graphic contrast |
| `world/perfect_world_nine_tribulations_grid.png` | [Perfect World: Nine Tribulations trailer](https://www.youtube.com/watch?v=yLzAvZX3NAw) | a shaft of light breaking through a dark cloud deck; a storm-cloud vortex with a gold eye; a starburst with a horizontal lens streak; violet and gold nebula |
| `world/xianwu_violet_mist_treasure_grid.png`, `world/xianwu_violet_mist_treasure_zoom.png` | [Xianwu Heaven EP24](https://www.youtube.com/watch?v=ls-W1takBAo) (262-362 s) | a treasure birth in violet mist: a magenta-violet fog bank with a hard rolling top over dark ground; inside it the world goes flat violet; blue-violet star motes; the treasure is a glowing lotus with a pink flare at its heart |
| `world/violet_qi_from_east_anim_grid.png` | [紫气东来 animation](https://www.youtube.com/watch?v=H928UBpssGE) (title frame, 0 s) | the palette for violet qi from the east: a lilac sky wash, deep violet ruyi curl clouds, a red sun disc, cranes; the rest of the video is ink landscape, not effects |

Looked at and not kept: an "Excalibur Morgan" Roblox showcase
([QTtSiu-RsNM](https://www.youtube.com/watch?v=QTtSiu-RsNM), a close-up beam
attack, no pillar) and a JJS "Sky Shatter" moveset
([TdDXLvyGx1M](https://www.youtube.com/watch?v=TdDXLvyGx1M), no sky crack; only a
thin cyan beam beside a black sun, which shows that a thin bright pillar reads).

Breakdowns exist for: Enkidu, Celestial Rain, Genshin void rift, Sol's RNG Equinox, Perfect World, Xianwu violet mist, 紫气东来, Wolf Claws Slash, Ground Slam.
