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

## Breakdowns

Add one per reference as you break it down:

```
### <ref name>  (<source>, <timestamps used>)
Far read: <the one shape and colour seen from afar, world refs only>
Beat <name> (<t0>-<t1>s): <n> layers
1. <texture/look> | <carrier> | <motion> | <timing> | <colour> | dark base y/n
...
Our translation: <xianxia motif per layer, library ids that worked>
```

### Enkidu: Enuma Elish  (vgYRw8hRj0g, 0-27 s)
Far read: a gold pillar standing between a sky circle and a ground circle, on a darkened world.
Beat anticipation (0-5 s): 5 layers
1. world fades to black | grade | fade | 0-1.6 s | black | n/a
2. ground magic circle, stacked rings | flat textures | turning, opening outward | from 1.6 s | gold | no (black world is the base)
3. 4-point cross glint at the centre | particle | flare and hold | 1.6-5 s | white-gold | n
4. thin vertical beam rising from the circle | beam | grows up | 1.6-3 s | gold | n
5. gold flecks and sparks | particles | burst out, drift | throughout | gold | n
Beat descent (5-17 s): 7 layers
1. sky circle as a glowing rune globe overhead | flat and curved textures | turning | 3-17 s | gold-white | n
2. grey cloud funnel sweeping in radially | huge smoke particles or mesh | radial inward swirl | 5-17 s | grey-white | it is the dark base for the gold
3. fine vertical threads between sky and ground circles | many thin beams | flicker in | 8-10 s | gold | n
4. main pillar | beam stack | drives down | 11-13 s | white core, gold edge | n
5. ground circle brightening, second ring stacked | flat textures | turning | throughout | gold | n
6. gold streaks flying radially | particles | out | throughout | gold | n
7. glints | particles | twinkle | throughout | white | n
Beat climax (18-27 s): 3 layers
1. white-out with a greyscale inverted frame | grade | one cut | 18-20 s | white/grey | n/a
2. palette flip to orange fire explosion | big flame flipbooks | burst out | 21-27 s | orange | black smoke edges
3. radial speed streaks | particles | out | 21-27 s | yellow-white | n
Our translation: sky circle = formation array (meander/bagua rings, SurfaceGui images turning);
the cloud funnel = Cloud_WispArc rings spiralling in; threads = qi threads; the palette flip
is kept for treasure claims only. Library ids: none render-tested yet (world-events pass,
2026-10-21, plan stage).

### Celestial Rain  (rLwXdIO5Yro, 0-41 s)
Far read: one star glint in a night sky, then gold streaks raining down.
Beat violet orb (3-15 s): 4 layers
1. violet ground swirl | flat particle | turning | 5-17 s | violet-magenta | dark floor
2. violet orb with sparkle crown | particles | float, pulse | 6-9 s | violet-white | n
3. white-out bloom | particle and grade | flash | 11-12 s | white-violet | n
4. dark violet smoke slab with glints | smoke particles | billow, hold | 14-15 s | deep violet | yes, the smoke is the dark base
Beat gold burst (17-21 s): 3 layers
1. gold fire puff | flame flipbook | burst | 17 s | orange-gold | n
2. 4-point star glint, long arms | particle | flare | 17-21 s | white-gold | n
3. gold dust and floor light | particles | fall | 20 s | gold | n
Beat star rain (23-41 s): 5 layers
1. single star glint high in the sky | particle | twinkle | 23-27 s | white-gold | dark sky
2. star bursts into thin gold rays | beams or streak particles | out | 29 s | gold | n
3. arcs fanning down from the burst | curved streak particles or trails | fall in arcs | 32 s | gold | n
4. long straight streaks raining | long thin particles | fall | 35-41 s | gold-white | n
5. little glints where they land | particles | twinkle | 35-41 s | white | n
Our translation: the heavenly treasure's descent (omen glint, burst, arcs fanning down,
meteor landing in a cross glint). The violet orb over the swirl is the violet treasure's close
layer. Library ids: none render-tested yet.

### Genshin Skirk void rift  (Lw0gsWWTJME, 2-35 s)
Far read: a jagged vertical seam of white light.
Beat open (2-10 s): 5 layers
1. 4-point glint where the rift starts | particle | flare | 2-4 s | white-blue | n
2. jagged lips | mesh or beams | tear outward | 4-10 s | white-hot core, blue falloff | n
3. void inside: patterned star-sea | textured plane | widens with the lips | 4-30 s | deep indigo with light motifs | yes, it is the dark base
4. glassy shard edges | flat shards | jut, catch light | 7-30 s | pale blue | n
5. light bleeding over the scene | grade | brightens | 7-30 s | blue-white | n
Our translation: the SkyCrack kit piece (lips as FaceCamera beams, a dark star-sea band
behind them, a tip glint, shard particles), in gold for Heaven Split. Library ids: none
render-tested yet.

### Sol's RNG Equinox cutscene  (2qKeyCPI9Mw, 1-11 s)
Far read: the screen split by one hard diagonal seam, black against white.
Beat cut (1-11 s): 4 layers
1. hard diagonal split, black and white halves | screen overlay | slides | 1-11 s | B/W | the black half
2. star glint on the seam | particle | holds, twinkles | 1-11 s | white or black | n
3. thin and thick rings | overlays | slide and scale | 2-11 s | B/W | n
4. bars rising like a level meter | overlays | rise | 3-10 s | B/W | n
Our translation: the crack's opening beat (one hard seam first, a glint at its tip). The
screen overlays aren't used. Library ids: none.

### Perfect World: Nine Tribulations trailer  (yLzAvZX3NAw, 15, 57, 83 s)
Far read: a shaft of light through a dark cloud deck; a dark cloud vortex with a gold eye.
Beat light through clouds (15 s): 3 layers
1. dark cloud deck | volumetric clouds | slow drift | hold | blue-grey | yes
2. one shaft of light through a hole | god-ray | still | hold | white | n
3. lit patch on the sea below | light | still | hold | white | n
Beat vortex (57 s): 3 layers
1. dark storm-cloud spiral | clouds | turning | hold | blue-black | yes
2. gold eye at the centre | glow | pulse | hold | gold | n
3. debris rocks orbiting | meshes | orbit | hold | dark | n
Beat starburst (83 s): 2 layers
1. white starburst | glow and rays | flare | hold | white | n
2. horizontal lens streak | streak | holds | hold | white-blue | n
Our translation: Heaven Split's light curtains through the cloud deck; Beast Surge's
dark vortex with a lit eye; the lens streak on every landing glint. Library ids: none.

### Xianwu Heaven EP24 violet mist treasure  (ls-W1takBAo, 204-362 s)
Far read: a magenta-violet fog bank with a hard rolling top, over dark ground at night.
Beat mist bank (204-300 s): 4 layers
1. fog bank rolling over the ground | volumetric fog | rolls forward | 278 s | magenta-violet | dark ground and cliff behind it
2. inside the mist: flat violet world | grade | holds | 222-302 s | magenta | n
3. star motes | particles | drift | 315 s | blue-violet | dark violet ground
4. trees and figures fading into it | grade | depth fade | throughout | violet | n
Beat treasure (342 s): 3 layers
1. lotus of light on a rock | mesh | still, glows | 342 s | pink-white | dark rock
2. halo flare at its heart | glow | pulse | 342 s | pink-white | n
3. ring of light round it | glow ring | holds | 342 s | pink | n
Our translation: the violet treasure's mist bank (flat squashed particles with a hard top) and
a local SkyGrade (violet atmosphere within ~120); the lotus is the treasure's close-layer core.
Library ids: none render-tested yet.

### 紫气东来 animation  (H928UBpssGE, 0 s)
Far read: a lilac sky with deep violet curl clouds.
Beat title still (0 s): 4 layers
1. lilac sky wash | grade | still | n/a | lilac | n
2. ruyi curl clouds | stylized cloud shapes | still | n/a | deep violet with light rims | no
3. red sun disc | flat disc | still | n/a | vermilion | n
4. cranes | silhouettes | still | n/a | white | n
Our translation: Auspicious Mist's "violet qi from the east" (a violet band of wisp arcs and
ruyi curl puffs drifting in from the east, with the violet grade). Library ids: none.

### Wolf Claws Slash  (9yNr853ziDo, 0-5.3 s)
Beat rake (0.3-0.7 s): 3 layers
1. three tapered streaks, parallel | one textured sprite | grows along its length while sweeping diagonally | 0.3 s | white core | n
2. the same streaks wider | sprite | as 1 | 0.3 s | colour falloff (red, yellow, violet, cyan per variant) | n
3. second set crossing the first | sprite | sweeps the other diagonal | +0.15 s | as 1-2 | n
Our translation (Spirit Wolf pounce hit, enemies.md): one three-streak texture, white core over a pale-blue rim over a slate copy for daylight, plus a glint and a few sparks; one diagonal only at ring 1.

### Ground Slam  (834aKXq3c-c, 3-14 s)
Beat landing (3-5 s): 7 layers
1. white-out | screen | flash | 1 frame | white | n
2. dome shell | translucent mesh | swells and fades | 0.5 s | orange-white | n
3. flat shockwave ring | ground texture | expands | 0.4 s | white-orange | n
4. rock slabs | parts (Craters-style ring) | pop up tilted outward, sink | 1-3 s | grey | they are the dark base
5. ground glow decal | flat texture | flares, then browns to a scorch | 3 s | orange to brown | y (scorch)
6. speed rays | thin streak particles | shoot out radially | 0.3 s | white-gold | n
7. sparks | particles | burst out, fall | 0.5 s | gold | n
Our translation (Spirit Wolf leap landing, enemies.md): flash, flat ring over a slate dust ring, low dust spray, rock chips, a dark crack decal that holds 0.6 s; no dome or slabs at ring 1 (they are for bigger beasts).

