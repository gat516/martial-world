# Method auras

The visual a cultivation method gives you while you sit (meditating or
circulating), seen by everyone. It is how other players tell what you
cultivate and how good it is, so it should be the most covetable thing about
a method. Mechanics, data and the method list live in
[character.md](character.md); this doc is the art brief.

**Status:** Mortal auras built 2026-10-21 (vfx agent): every method has its
own aura, following this doc. Runtime `src/client/MethodAura.luau`, templates
`ReplicatedStorage.Effects.MethodAura.<MethodId>` (one Model per method),
builder `tools/vfx_specs/MethodAura.luau` (its header is the attribute
contract), Edit-mode preview `tools/aura_preview.luau`. Spirit, Earth and
Heaven looks are not built (no method uses those grades yet).

**Rework due (decided 2026-10-21, user):** the Mortal pass is mostly parts
(Neon and ForceField shells, discs and rings animated in code, ~20 textures,
about 1.5 loop emitters per aura) and reads thin. Auras are to be rebuilt as
layered emissions from the vfx library, modelled on Sol's RNG auras, with
parts only in support. The method is in [docs/vfx/style.md](../vfx/style.md)
("Auras"). **Reworked:** Blazing Heart, Flowing Spring, Thunder Pulse, Drifting
Cloud, Iron Marrow, Sect Breathing, Frost Lotus, Evergreen Root, Mountain Breath (2026-10-21, below):
every Mortal aura. Blazing Heart shows the bar for
size and quality, not a template: each method's rework starts from its own
idea and references, not from Blazing Heart's layers or textures.

Mortal means small and close but high in quality (user, 2026-10-21): within
about one body-width, a gentle loop, no screen dimming or towering shapes, and
an ignition that is a short, punchy flash and flare on and near the body.

The spirit root reveal (`src/client/RootFX.luau`, template
`Effects.RootPillar`) speaks the same language: each element's pillar carries
its methods' motifs (Fire's heart and flame crown, Water's pool and ripples,
Wood's roots and branches, Metal's gem and clang rings, Earth's rune stone
ring, Lightning's bolts, Wind's vortex, Ice's glass lotus); see
[spirit root](../character/spirit-root.md), "The reveal". A new element's reveal should
reuse its first method's motif.

## Per-method auras

Each method's brief, what's built, budget and gaps live in its own file:

| Method | Idea | File |
|---|---|---|
| Sect Breathing | the basics | [sect-breathing](../auras/sect-breathing.md) |
| Blazing Heart Sutra (Fire) | a heart that burns | [blazing-heart](../auras/blazing-heart.md) |
| Flowing Spring Scripture (Water) | water gathering into a still pool | [flowing-spring](../auras/flowing-spring.md) |
| Evergreen Root Canon (Wood) | an old tree, patient growth | [evergreen-root](../auras/evergreen-root.md) |
| Iron Marrow Art (Metal) | qi hammered into the bones | [iron-marrow](../auras/iron-marrow.md) |
| Mountain Breath Method (Earth) | deep, steady as stone | [mountain-breath](../auras/mountain-breath.md) |
| Thunder Pulse Manual (Lightning, rare) | sudden bursts | [thunder-pulse](../auras/thunder-pulse.md) |
| Drifting Cloud Scripture (Wind, rare) | qi drifting in on the wind | [drifting-cloud](../auras/drifting-cloud.md) |
| Frost Lotus Sutra (Ice, rare) | blooming cold and clear | [frost-lotus](../auras/frost-lotus.md) |

Designing a new method: [new method](../auras/new-method.md).

## How every aura is put together

Details in the builder header.
- **Body first.** `Body` parts follow named body points (`Chest`, `Belly`,
  `Lap` between the hands...), `Limbs` emitters are cloned onto the body parts
  themselves (they emit off the limb's surface), `Lines` are Beams between
  attachments made on the body parts (ZOffset keeps them in front of the
  limb), and `Shell` parts are copied round every body part as a glowing skin.
  R6 and R15 map through `POINTS` / `LIMBS` in MethodAura.
- **Outline glow is a Shell, not a Highlight.** Roblox draws only 31
  Highlights at once; when the auras were built the map's fern outlines used
  them all (since stripped, see Known gaps), and 8 auras would still take a
  quarter of the budget from combat feedback. ForceField shells read as a rim;
  Neon shells at ~0.85 transparency read as a tint.
- **Breath:** one 5 s period for every aura (`Breath` on the root), energy 0 at
  rest to 1 mid-breath; `Breath` models fire on the beat (`BreathAt`, default
  the exhale). Thunder Pulse sets `Rhythm = "burst"`.
- **Ignition:** an aura that starts within 2 s of `Meditating` or `Method`
  changing plays its `Ignite` model and a 1.8 s surge (pieces brighter and
  bigger, limb emitters `Surge`); the `Breakthrough` remote replays it.
  Walking up to someone already seated doesn't ignite. On a sit-down the whole
  aura waits until the player is all the way down (user, 2026-10-21): when the
  `Animations.Meditate.Sit` track (1.6 s, no animation events) is 0.2 s from
  its end, the moment `Meditation.luau` fades into `Loop`, or `Loop` is already
  playing; 2.6 s at most if the track never shows. A `Seated` marker on Sit
  would be cleaner. A method switch while seated and a breakthrough ignite at
  once.
- **Pulses:** a method Model with `PunchEvery = NumberRange(a, b)` fires its
  `Punch` model (a lighter ignition) on the breath's beat every a to b whole
  breaths (rolled each time), up to `PunchJitter` s late, in place of that
  beat's `Breath`; that breath's `Swell` is `PunchSwell` times larger, so the
  aura swells into the pulse and eases back. Limb emitters with
  `PunchSurge = n` emit n then. Blazing Heart (every 1 to 2 breaths, 0.6 s
  jitter, 1.4x swell), Flowing Spring (every 2 to 3, 0.4 s, 1.3x) and Iron Marrow (every 2 to 3, 0.3 s, 1.3x) use it.
- **Grade hook:** `GRADES` in MethodAura scales the `Ground` model (reach),
  `Scaled` emitter rates and brightness. Mortal = 1.
- **Emitter attributes** (added for Blazing Heart, usable by any aura):
  `Breathe = NumberRange(lo, hi)` scales an emitter's rate from lo at rest to
  hi at the breath's peak (Limbs emitters too; `Breathe = true` keeps the old
  curve), `Prime = n` emits n at once when the aura starts so slow ground loops
  show immediately, `Swell = k` grows an emitter's Size (Ground, Body or
  Limbs) by 1 + k with the breath, the beat and the surges, and `Drift = k`
  adds a slow wander of +-k so the size never sits still. Parts take
  `Rise = studs` with `RisePeriod` (drift up, fade at the top, start again),
  and `Kick` now also flashes on pulses.
- **Budget per aura:** one PointLight (none for Wind, Ice, Thunder, Sect),
  6 shell parts (R6), up to ~40 beams (Thunder's jagged cracks), a handful of
  emitters at 1 to 13 /s per limb. Sect Breathing auras rank after named
  methods for the 8 slots. Each method's own counts are in its file.
- **Palette for Neon:** bright pastels go white in Neon; ring and wave colours
  use the deeper shade of the element (violet, deep ice blue, burnt amber).

## Rules every aura follows

- **One method, one idea.** Each aura is built from the method's own idea (its
  name and blurb), not an element tint over a shared base. Two methods of the
  same element should still look nothing alike.
- **Grade sets the size, not the look.** The method decides what the aura is;
  its grade decides how far it reaches (table below). A Mortal aura stays on
  and close to the body; a Heaven one owns the screen.
- **Emissions first, parts in support.** Each aura is a thick stack of
  library emissions (core glow, glints, flames or petals or motes on the
  body, a turning ground sigil, an ambient field, the method's signature
  shape) like a Sol's RNG aura. It still centres on the body: the figure glows
  from inside and the signature grows out of it. Parts (a lit core, a carved
  ring) are fine as support, but the aura must read with them hidden.
- **It breathes.** Every aura follows the shared breath (inhale gathers,
  exhale releases), so a seated crowd feels calm, not noisy. Thunder Pulse is
  the one deliberate exception (sudden bursts).
- **It reads in daylight.** The references sit on dark backgrounds; ours sit on
  green grass at noon. Use a white-hot core with colour at the edges,
  `LightInfluence = 0`, and a dark or deep-tint layer under the bright shapes
  so they don't wash out ([style.md](../vfx/style.md)).
- **Ignition.** Sitting down, switching method and breaking through play a
  one-shot surge of the aura (ref: red flame surge, hair and robes lifting)
  before it settles into its loop. This is what makes switching feel like an
  event.
- **Budget.** Up to 8 auras draw at once (`MAX_AURAS`), on phones too. Get
  richness from many kinds of layer at modest rates rather than one heavy
  emitter; the nearest auras get the full stack, far ones drop the ambient
  field first. Works on R15 and R6 (emitters and beams hang off attachments
  that exist on both, or fall back to the torso).

Roblox pieces that match the reference looks (library textures on all of
them; search per method):

| Look | Build it with |
|---|---|
| Body glow | flame, wisp or glow emitters on each limb emitting off the surface (LockedToPart), plus a soft glow billboard on the torso; a shell part only as a faint extra. Not a `Highlight`, whose 31-on-screen budget is kept for combat feedback |
| Lit core (dantian, chest, between hands) | a white-hot glow emitter with a star glint on top, one `PointLight` |
| Meridians, constellations, cracks | textured `Beam`s between attachments on body parts, glint emitters at the joints |
| Signature shape (lotus, flame crown, blade fan) | library textures on flat or curved meshes and emitters, layered with a dark base |
| Ground figure | a turning sigil or formation texture flat on the ground, a ring emitter breathing out of it |
| Qi streaming inward | Splines add-on or particles with negative speed toward the core, streak textures |
| Ambient field | sparkles, petals, embers, snow by element, out to the grade's reach |
| Backdrop (mandala, sunburst, spirit) | large textures behind the player, Spirit grade and up |

## Grade scale

| Grade | Reach | Adds |
|---|---|---|
| Mortal | on the body, ~1 body-width around | core, outline, the method's signature on the body, a small ground touch |
| Spirit | ~2× radius, rises to above the head | the signature spreads into the space round you (a full ground figure, things orbiting) |
| Earth | fills a ~15-stud circle, visible across a plaza | a backdrop: mandala, sunburst or sigil behind the player |
| Heaven | the screen; a column or sky effect seen from far away | a manifestation: the method's spirit or beast rising behind, a light pillar |

All current methods are Mortal (Sect Breathing aside). Their "higher grade"
lines in each method's file say where the method's family goes when a stronger version exists.

## Reference images

From the user, in `docs/reference/auras/`. The names in each method's Refs line
point here.

**On the body (Mortal and up)**

| | |
|---|---|
| ![constellation_dantian_core](../reference/auras/constellation_dantian_core.png) | **constellation_dantian_core**: glowing acupoints joined by thin lines, a sigil core in the belly, the body faintly see-through. |
| ![meridians_qi_inflow](../reference/auras/meridians_qi_inflow.webp) | **meridians_qi_inflow**: the meridian map lit with points, qi arrows streaming in from all sides. |
| ![sunburst_diamond_core](../reference/auras/sunburst_diamond_core.png) | **sunburst_diamond_core**: a hard bright diamond between the hands, a dark silhouette, rays bursting behind. |
| ![purple_flame_outline](../reference/auras/purple_flame_outline.png) | **purple_flame_outline**: flame hugging the silhouette like an outline, rising off the shoulders. |
| ![red_flame_surge](../reference/auras/red_flame_surge.png) | **red_flame_surge**: an upward surge, hair and robes lifting; the ignition moment. |
| ![fire_aura_smoke_outline](../reference/vfx/fire_aura_smoke_outline.png) | **fire_aura_smoke_outline** ([video](https://www.youtube.com/watch?v=T9jHZv8NOtQ)): realistic flames hugging the silhouette with black smoke at the tips and dark ash flecks; reads on a bright sky. Blazing Heart's loop. |
| ![fire_aura_swirl_ground](../reference/vfx/fire_aura_swirl_ground.png) | **fire_aura_swirl_ground** ([video](https://www.youtube.com/watch?v=aBfd3qMOz_k)): a flame outline over a turning fire swirl on the ground. Blazing Heart's ground. |
| ![dark_lightning_cracks](../reference/auras/dark_lightning_cracks.png) | **dark_lightning_cracks**: glowing cracks across a dark body, arcs, smoke tendrils. |

**Backdrops and manifestations (Earth and Heaven)**

| | |
|---|---|
| ![gold_mandala_backdrop](../reference/auras/gold_mandala_backdrop.webp) | **gold_mandala_backdrop**: a giant lotus mandala filling the space behind the figure. |
| ![spirit_manifest_green](../reference/auras/spirit_manifest_green.webp) | **spirit_manifest_green**: meridian lines on the body plus a spirit rising behind. |

**Other Roblox games (the bar to clear, not the target)**

| | |
|---|---|
| ![roblox_seated_blue_wisps](../reference/auras/roblox_seated_blue_wisps.webp) | **roblox_seated_blue_wisps**: a seated aura with wisps, motes and a ground ring. |
| ![roblox_bubble_skulls](../reference/auras/roblox_bubble_skulls.png) | **roblox_bubble_skulls**: a bubble shell with floating icons. |

## Known gaps

- Every Mortal aura is reworked; Spirit and up still wait (below).
- Only the Mortal column is built; the Spirit/Earth/Heaven looks (spreading
  figures, backdrops, manifestations) wait for methods of those grades.
- No refs yet for Mountain Breath or Drifting Cloud (built without one).
- Robes and hair can't lift (avatar clothing isn't ours to move); Drifting
  Cloud and the ignitions stand in with rising wisps and flames.
- Previewed in Edit mode on the R6 test rig only (grass at noon and night);
  R15 avatars and real accessories, phone performance with 8 auras, and the
  live sit / switch / breakthrough ignition are untested in play.
- Fixed 2026-10-21: the foliage pack's fern outlines (763 enabled
  Highlights in the map, AssetLibrary, `_BorderlandsReplaced` and
  `HerbModels`) filled Roblox's 31-highlight budget, so `CombatEffects`
  Highlights (Iron Skin glow, perfect-circulation rim, hit flash) mostly didn't
  render. They were stripped in Studio; 5 remain (4 in `BuildKit`, 1 in
  ServerStorage). Rule: map dressing and prop templates carry no Highlights.
  Not yet checked in play that the combat outlines now show.
- Per-method gaps (previews, untested ignition, missing textures) are in each method's file.
