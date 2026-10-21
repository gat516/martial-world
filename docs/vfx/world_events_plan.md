# World events and sky anomalies: look pass (PLAN, not committed)

The world-fx agent's working plan, written down as it goes so a restart doesn't lose it.
Status: approved (section 10). Step 0 (groundwork, far-read test) and step 1 (treasure
birth) are built; Heaven Split is next, after the user's review in Studio.

## 1. What plays today (read from code, 2026-10-21)

| Event / anomaly | Code path | What players see now |
|---|---|---|
| Thousand-Year Ginseng (`GuardedHerb`) | `WorldEvents/GuardedHerb.luau` | `ItemTemplates.WorldTreasure` scaled x3: an 80-stud Neon cylinder, glass shell, orb, 7-stud Neon ring, one emitter, PointLight, all tinted the herb colour, plus the giant herb and the guardian. One Neon cylinder, so it isn't a pillar by the brief's bar. Its top is at Y ~250, under the cloud plane (top Y 440), so nobody on the peaks sees it. |
| Beast Surge | `WorldEvents/BeastSurge.luau` | No visuals, and no `at` (it covers the whole zone). |
| Auspicious Clouds / Violet Cloud Mist / Golden Auspicious Clouds | `WorldEvents/AuspiciousClouds.luau`, `client/WorldEventFX.luau`, `Effects.AuspiciousClouds` | The only event with a real look: wisp patterns descend and turn, a Column through the cloud plane and a Whirl on it, a seal and an unseal burst, a relic that bobs. |
| Auspicious Mist / Rainbow Aurora / Heaven Split (weather) | `client/WeatherFX.luau` | A violet or gold grade lean through `WeatherFX.adjust(k)`, mist particles round the camera, aurora made of 65 Neon slabs placed relative to the camera (a new set every time it starts), distant bolts. **Heaven Split has no split.** |
| Heavenly treasure birth | `server/Treasures.luau` | A `WorldTreasure` (the same Neon cylinder) appears with no arrival beat, and fades out when the weather ends. |

Other findings:
- **StreamingEnabled is on.** Treasure models in `Workspace.Wilds` don't reach a player on the
  peaks, so a treasure's far layer can't hang off the server model. It has to be published like
  `WorldEvents` (a workspace attribute) and drawn by the client.
- `ReplicatedStorage.vfx` (the Game Module) is **not in the place** right now, so
  `TechniqueVFX` runs its plain fallback. World FX drive their own emitters and beams from code
  anyway (sky-scale motion is code), but they keep Emit attributes for the plugin.
- Lighting: Atmosphere density 0.36, haze 1.8; Bloom threshold 1.35 (only Brightness > ~1.4
  blooms); the Skybox has celestial bodies off; there are no `Terrain.Clouds`.
- The earlier world-fx run left nothing behind: no `_StagingWorldFX`, no files, no commits.
  `ReplicatedStorage._StagingEffects` (4408 descendants) belongs to the aura session. Leave it
  alone.

## 2. Geography: where people watch from

- Peaks at Y 550-800, the plaza at (0, 648, 100), the cloud plane opaque from Y 440 out to
  +-2100. The wilds valley floor is at Y 3-8 (x -900..900, z 520..1440), with walls 80-124 tall.
- Event grounds (`Treasures.randomSpot`): WestField (-400, 1000) r55, NorthTerrace (300, 680)
  r48, EastFlat (470, 1120) r55, GravesField (0, 1750) r32, SouthFlat (360, 1928) r30.
- **From the sect** the wilds lie under a white floor 700-1900 studs away, deep in haze
  (capture: from (0, 660, 140) the karst at ~800 studs is almost washed out). The far layer
  is whatever pierces the cloud plane and stands on it, plus whatever hangs in the sky above
  it. For G1 seen from the plaza, the plane's horizon is 12 deg below eye level and a pillar
  topping out at Y 1400 reaches 42 deg above it. Height is cheap, so use it.
- **From the valley floor** the plane is far overhead in haze and reads as sky, and the
  walls hide everything outside the valley. There the far layer is the pillar plus a sky
  circle at Y 300-420, under the plane.
- **Risk to test first:** heavy Atmosphere haze over 1000 studs may wash out even Brightness
  6 beams. Plan: test it on a bare pillar first (build step 0). If it washes out, events thin
  the haze (the sky clears while heaven opens) as part of their grade.

## 3. References (frame grids under `docs/reference/vfx/world/`)

Rows and full per-beat breakdowns are in `docs/reference/vfx/README.md` ("World events and
anomalies", "Breakdowns"). Summary:

| Grid | What reads far (one shape, one colour) | Close-up detail to take |
|---|---|---|
| `enkidu_enuma_elish_grid.png` (user's ref, vgYRw8hRj0g) | a gold pillar standing between a sky circle and a ground circle, on a darkened world | the world goes black first; a stacked ground sigil; a 4-point cross glint where the pillar lands; fine vertical threads of light between sky and ground circles (8-10 s); a grey cloud funnel sweeping in radially; gold flecks everywhere; a greyscale inverted white-out (18 s), then the palette flips to orange |
| `celestial_rain_showcase_grid.png` (rLwXdIO5Yro) | a single star glint in the sky, then gold streaks raining down | a violet orb over a violet ground swirl; a white-out; a dark violet smoke slab with a glint, flipping to a gold burst; a star bursting into gold arcs that fan down (29-38 s); long thin streaks falling; the landing is a cross glint. **This is the treasure descent.** |
| `genshin_void_rift_sky_grid.png` (Lw0gsWWTJME) | a jagged vertical seam of white light | the rift opens out of a 4-point glint; white-hot glassy lips with blue falloff; the inside is a dark patterned star-sea (dark under light); shard-like edges. **This is the sky crack's shape.** |
| `sols_rng_equinox_cutscene_grid.png` (2qKeyCPI9Mw) | the screen cut by one hard diagonal seam, black against white | a star glint sitting on the seam; thin rings and bars sliding past; pure graphic contrast. The crack's opening beat: a hard seam, then a glint at its tip. |
| `perfect_world_nine_tribulations_grid.png` (yLzAvZX3NAw) | one shaft of light breaking through a dark cloud deck (15 s); a storm-cloud vortex with a gold eye (57 s) | a starburst with a horizontal lens streak (83 s); smoky violet and gold nebula; gold particle ribbons |
| `xianwu_violet_mist_treasure_grid.png`, `..._zoom.png` (ls-W1takBAo, 262-362 s) | a magenta-violet fog bank with a hard rolling top, standing over dark ground at night | inside the mist the world goes flat violet (a strong local grade); blue-violet motes like stars; the treasure is a glowing lotus with a pink flare at its heart, on a rock. **This is the violet mist for treasure births.** |
| `violet_qi_from_east_anim_grid.png` (H928UBpssGE, title frame) | a lavender sky with deep violet ruyi (xiangyun) curl clouds | the palette for 紫气东来: lilac wash, violet curls, a red sun disc, cranes |
| (style.md index) Megumin, Holy Aura | stacked circles rising; a light shaft from above | |

Library casting notes (from contact sheets in the scratchpad; I'll recheck them at build time
with the live search for `bagua`, `taiji`, `lotus`, `talisman`, `cloud`). Possible picks:
- Pillar body: soft vertical bands (9841273413), a gradient band (2382169232), a glow column
  (9841273244), a ray curtain fanning down (245996148).
- Glints: 4-point star (3060556198), lens streak (14684195806), burst (243728206), thin
  sliver (11226108137, 7886908733; the latter is a crack core line).
- Rings: Chinese meander/key ring (16511732405), gold sigil (565056459), ornate rings
  (87153714607286, 13399941667), glyph ring (129093523368188), hex formation (102790439571584),
  ruyi-cloud ring (100397289227468, opaque black background, additive only).
- Clouds: the ruyi cloud column (74110461210620, black background), wispy stroke (9345352897),
  soft puff (1084987899), smoke flipbook (17703378809).
- Vortex: smoke vortex (321556991), dark smoke vortex (341277531, a dark base), soft swirl
  (15249897265).
- Crack flicker: lightning flipbook (135959774229843), cracks (301851161).
Per style.md, none of these are carried over from the AuspiciousClouds build. Each layer is
picked against its own reference.

## 4. The shared kit

Each kit piece is one template plus one runtime module. A piece takes a **palette**
(`core`, `color`, `accent`, `dark`), a **scale** and a **timeline**, and is animated on the
client from `workspace:GetServerTimeNow()`. Events get their identity by composing,
colouring and timing these pieces, not from one-off builds.

Templates: `ReplicatedStorage.WorldFX.<Piece>` (see section 8 for the file question).
Runtime: `src/client/WorldFX/` (new): `Kit.luau` (spawn, place, palette, phase and LOD helpers,
one BulkMoveTo per frame for everything that moves), one module per piece,
`SkyGrade.luau`, and a `Treasure.luau` drawer. `WorldEventFX` and `WeatherFX` call into it.

Every template is authored upright (section 9): `PrimaryPart` nil, identity `WorldPivot` at
the ground or anchor point, cylinders stood up inside, beam attachments with their axes set
on purpose.

### 4.1 LightPillar (ground to sky)
| Layer | Carrier | Motion | Distance |
|---|---|---|---|
| Core | FaceCamera Beam, white, Brightness ~6, LightEmission 1, width 3-6 | width shimmer (2 Hz, +-10%) | far |
| Body | FaceCamera Beam, `color`, soft-edged band texture, width 18-40, Transparency fading out with height | texture scrolls upward (TextureSpeed) | far |
| Outer haze | FaceCamera Beam, `accent`, very wide (60-90), faint | breathes over 6 s | far (it's what reads through haze) |
| Plane puncture | flat glow disc (SurfaceGui or flat beam pair) on Y 440 plus a ring of 4-6 Cloud_WispArc pushed out from the hole, tinted | arcs turn and ripple | far (from the peaks it reads as a glowing hole in the cloud sea) |
| Rising streaks | emitter on a tall thin Box, speed lines upward | 6-10/s | mid |
| Qi helix | 2-3 small wisp parts with Trails orbiting up the shaft (BulkMoveTo) | spiral up, loop | mid |
| Ground ring + shock ring | see GroundCircle | | close |
| Top | see SkyCircle | | far |

Height: from the ground to world Y ~1400 (fixed world height like the Column's `WorldY`).
Sizes S/M/L by `scale` (treasure / event / anomaly). Beats: `drive` (the beams grow from the
top down over 0.6-1 s, with a flash at the landing), `sustain`, `flare` (a 0.3 s width x2 and
brightness pulse), `collapse` (it pulls up into the sky circle).

### 4.2 SkyCircle (formation array overhead)
2-4 concentric rings, each an ImageLabel on a SurfaceGui (Top and Bottom faces) on an
invisible flat part, turning through `ImageLabel.Rotation`. That is cheap (no part movement)
and, per the toolkit, steadier than turning particles. `SurfaceGui.Brightness` > 1 so it
blooms; `LightInfluence` 0. Rings counter-rotate. A dark tint disc behind the bright rings
gives dark under light, which matters by day. Radius 80-400. Beats: `open` (rings scale in
from 0, one after another, 0.4 s apart: the Megumin stacking), `turn`, `shatter` (scale out
and fade, with shard particles), `shrink` (down to a glint). Also used flat on the ground (see
GroundCircle) and as the treasure's omen.

### 4.3 SkyCrack (the heavens splitting)
Geometry in front of the skybox, a jagged polyline of 8-14 segments:
| Layer | Carrier | Motion |
|---|---|---|
| Lips | per segment, FaceCamera Beam: a white-hot core (narrow) and a colour glow (wide, soft) | it draws from the origin outward, segment by segment; the width breathes |
| Void | a band behind the lips: wide Beams with a dark star-sea texture (indigo or black with motes) | widens as the crack opens (the dark under light from the Genshin rift) |
| Light spill | curtain Beams fanning down from crack points (ray texture), long enough to reach the cloud plane or the ground | sway, flicker |
| Edge flicker | lightning-flipbook particles along the segments | bursts every 0.5-2 s |
| Shards | falling shard particles from the lips | slow fall, spin |
| Tip glint | 4-point star plus lens streak at the origin and each growing end | it opens out of the glint, as in the Equinox and Genshin refs |
| Clouds parting | Cloud_WispArc pieces placed along both sides, drifting outward perpendicular to the crack, lit underneath in the crack colour | they push apart as it opens and close in as it heals |
Shape is data (points in a table), so one template serves a sky-scale crack (1600 long) or a
small one over a treasure (150 long). Beats: `glint` (1 s), `tear` (2-4 s), `breathe`,
`heal` (it closes from the ends inward, last glint, out).

### 4.4 CloudRing / CloudVortex (from the user's wisp arcs)
Cloud_WispArc clones (`ServerStorage.CloudKit.Cloud_WispArc`, the same mesh and texture as
`Map.Clouds.Wisps`) in rings of 3-12, layered by radius and height. Each layer can turn, breathe
(a scale pulse), drift inward or outward, descend or rise, ripple, and tilt slightly. One
BulkMoveTo per frame for all of them; scale changes only when they're asked for.
- **Colour variants without new meshes:** violet mist, gold, white, storm grey-indigo,
  jade, crimson. A textured MeshPart ignores `Color` (WorldEventFX already works round this
  by dropping the ramp texture). Better: swap the texture for a `SurfaceAppearance` whose
  ColorMap is the same ramp (131820708134549) and tint it with `SurfaceAppearance.Color`, which
  keeps the shaded underside and lit crown. The fallback, if MCP can't write the ColorMap, is
  the current trick (drop the texture, colour the Fabric).
- Each arc carries 1-2 huge, slow, soft particles in the variant colour (mist), so the
  colour still reads through haze, plus a flat glow beam underneath for coloured underlight.
- **The map's ring:** an exact copy of `Map.Clouds.Wisps` (11 arcs, the positions read in
  Studio) as a template `WispsRing`, so an anomaly can bring the ring round the main peak to
  life: it turns, breathes, rises, tints, splits apart. The map copy stays untouched in the
  place. Question for the user: while a copy plays, should the client hide the originals
  locally, so the ring itself seems to come alive rather than a second ring appearing over it?
- Budget: the arc is 1400 tris whatever its size; at most ~12 arcs per event, ~24 on screen.

### 4.5 GroundCircle (where it lands)
A ground sigil as SurfaceGui rings on a flat part 0.2 above the ground (Top face, part up =
world up), turning, on a dark ink disc (dark base, so it reads on green grass at noon).
Landing burst: a flat shock ring (VelocityPerpendicular, Size curve to the radius), a dust ring
(Box, Front, SpreadAngle (5, 180)), radial gold streaks, debris (Craters add-on only when the
Game Module is present, else plain emitters), a 4-point glint. Sustain: slow rising motes,
petals or leaves by event, low mist hugging the circle (squashed flat, kept level).

### 4.6 SkyGrade (the world reacts, blended with DayNight)
- **How it combines with DayNight:** DayNight samples its keyframe and then calls
  `WeatherFX.adjust(k)` on it every frame before writing Lighting. I extend that chain rather
  than writing Lighting myself: DayNight calls `SkyGrade.adjust(k)` after `WeatherFX.adjust`,
  and SkyGrade applies every active contribution from world events and treasure births:
  `tint`, `atmoColor`, `atmoDecay`, `density`/`haze` deltas, `brightness` and `exposure`
  multipliers, `saturation`/`contrast` deltas. Each contribution has a weight =
  (event phase strength) x (camera-distance falloff: full inside `inner`, 0 past `outer`; or
  global). So the Violet Mist turns the world violet only near it, and Heaven Split dims the
  whole sky. DayNight still owns the per-hour values; contributions are offsets and lerps on
  its keyframe, exactly like weather.
- **Pulses** (white-out, impact frame, a tinted flash) go on a second ColorCorrectionEffect of
  our own (a `WorldFX.Grade` template that the client clones into Lighting once), never on
  DayNight's `ColorCorrection`. The thunder flash already rides `k.brightness`; that stays.
- Optional cheap sky tool: a `Terrain.Clouds` template cloned in for overcast (Cover/Density/
  Color tweened). There are none in the place today.

## 5. Per-event design: layers, beats and timelines

Distances: far 300-1500 studs (the peaks, across the valley), mid 80-300, close under 80. The
close layer is only created or emitting while the camera is within ~250 studs.

### 5.1 Heavenly treasure birth (Treasures, during Auspicious Mist / Rainbow Aurora / Heaven Split)
Identity by the anomaly: **violet** (Auspicious Mist), **pearl-white with prismatic rims**
(Rainbow Aurora), **gold** (Heaven Split). The item's colour is the core accent. The
user's three asks meet here: violet mist from the wisp ring, the sky splitting, a light pillar.

Server change (`Treasures.luau`): publish `workspace.HeavenlyTreasures` (JSON
`[{ key, at, color, weather, born, claimed? }]`) on spawn, claim and fade. Keep the server
model minimal (orb, prompt, label), with the prompt enabled at `born + LAND` (~7 s) so the
claim waits for the landing. The Neon `WorldTreasure` pillar is retired (it's in
`ItemTemplates.rbxmx`; changing it is a property edit in that file). A treasure that has been
claimed drops out of the attribute and the client plays the collapse.

| t (s from born) | Beat | Far | Mid | Close |
|---|---|---|---|---|
| 0-2 | Omen | a star glint and a small SkyCrack (150 long, the anomaly colour) tearing at Y ~1100 over the spot; Heaven Split: the treasure leaves the big crack instead | | |
| 2-6 | Descent | a meteor: a bright head plus a long Trail, arcing down from the crack to the spot, punching the cloud plane (a puncture flash, then arcs blown outward) | gold or violet arcs fanning down (Celestial Rain), streaks falling | |
| 6-7 | Impact | the pillar drives down (LightPillar `drive`); SkyCircle opens at the top | the shock ring rolls out; the mist bank billows up | white flash, 4-point glint, dust and shock ring, ground circle stamps; impact-frame pulse within 150 and a shake within 80 (if the user OKs screen effects) |
| 7-end | Sustain | the pillar (M), SkyCircle turning at Y ~1100, the puncture ring on the plane, a violet or gold haze on the cloud sea | **CloudRing of 6 wisp arcs** in the anomaly colour circling at Y 60-160 round the spot, slowly breathing and sinking; rising streaks; motes | the treasure orb in a lotus of light on the ground circle; violet mist bank (Xianwu) within r 60, with a local SkyGrade (violet atmosphere, within 120); sparkles, petals |
| claim | Collapse | the pillar pulls up into the SkyCircle, which shrinks to a glint and goes out | the arc ring flings outward and fades | burst, petals |
| weather ends | Fade | everything fades over 4 s | | |

Layer count at sustain: far 6 (core, body, haze, puncture disc, puncture arcs, sky circle),
mid 4 (arc ring, streaks, helix, mist bank top), close 8 (ground circle, ink base, orb glow,
lotus, motes, sparkles, petals, ground mist). Peak: 7-8 at the impact beat.

### 5.2 Heaven Split (anomaly, global)
The big set piece. A sky-scale SkyCrack over the sect.
- Placement: a crack about 1600 long, centred about (0, 1500, -700), north of the summit,
  running roughly east-west and tilted, so it fills the sky above the plaza's northward view
  and the spirit peaks see it from the side. The valley can't see above the plane, so there
  the read is light curtains pouring through the cloud deck onto the event grounds, plus the
  treasures' pillars.

| t | Beat | Far (everyone in the sect) | Mid / close |
|---|---|---|---|
| 0-8 (FADE) | Omen | SkyGrade: exposure down, saturation down, a dim gold-indigo lean; a gust; the bolts double in rate; one glint where the crack will open | |
| 8-12 | Tear | the crack draws out of the glint in both directions; a white flash (Grade pulse, global but soft); thunder; edge flicker | the clouds part: the main peak's `WispsRing` copy is pushed outward and lit gold underneath |
| 12-end | Sustain | the crack breathes; gold light curtains fan down onto the peaks; golden streaks rain slowly; the void inside drifts | on the peaks: gold motes falling (a camera-local emitter, like the weather's); treasures fall out of the crack (5.1 descent) |
| last 8 | Heal | it closes from the ends; a last glint; the grade eases back | the ring settles back |

Layers: crack lips (2 per segment), void, curtains (6-10 beams), flicker, shards, tip
glints, parting clouds (6-8 arcs), grade, motes: 9 kinds.

### 5.3 Auspicious Mist (anomaly, global): 紫气东来, violet qi from the east
- Far: the `WispsRing` round the main peak turns violet (SurfaceAppearance tint) and slowly
  turns and breathes. A violet qi river comes from the east: a band of 6-8 violet arcs and huge
  soft violet particles drifting west across the sky at Y 600-900, from X +1500 towards the
  peaks over the first 30 s, then settling around the ring. The violet grade lean stays
  (it exists), and gets stronger near the ring.
- Mid: ruyi curl puffs (cloud swirl texture) along the river; violet motes.
- Close (round the camera, the existing `Mist` emitter): it stays, recoloured with a
  dark-violet base particle under the lilac one, so it reads by day.
- Its treasures are violet (5.1).

### 5.4 Rainbow Aurora (anomaly, global)
Replace the 65 Neon slabs with world-fixed Beams:
- Rainbow: 5 colour Beams, each one curved arc (CurveSize0/1) spanning the sky south of the
  main peak, a soft gradient texture, LightEmission 1, shimmer (TextureSpeed) and a slow width
  breath. It is anchored over the sect, not around the camera, so everyone sees the same arc
  in the same place.
- Aurora curtains: 3-4 ray-texture Beams high in the north, colours cycling slowly.
- `WispsRing` in pearl white with prismatic rims (accent emitters).
- Treasures: pearl pillar with a rainbow outer haze (5.1).
About 10 beams and a few emitters, where today there are 65 parts.

### 5.5 Auspicious Clouds, Violet Cloud Mist, Golden Auspicious Clouds (world events)
Keep the existing look (the user likes the wisp patterns) and lift it with the kit. These
are additions at runtime from the WorldFX templates, so `Effects.AuspiciousClouds` doesn't
change and Effects.rbxm isn't exported:
- Arrival (Enkidu descent, 0-8 s): the SkyCircle opens over the spot at Y ~1100 (rings in the
  def's colours: white and jade bagua for Vortex, a violet ruyi ring for Mist, a gold
  sword-array ring for Spiral), the LightPillar drives down (it replaces the Column's role at
  far; the old Column stays as the mid layer or is hidden, to be decided at the side-by-side),
  then the existing wisps descend.
- Sustain: the pillar and sky circle turn; the plane puncture ring sits on the Whirl.
  Violet Cloud Mist adds the violet mist bank and the local violet grade (5.1 close layer).
  Golden adds gold rays and sword glints.
- Unseal: the existing burst plus a pillar flare, the sky circle shattering, and a white-out
  pulse within 120.
- Depart: the pillar collapses into the sky.

### 5.6 Thousand-Year Ginseng (world event)
Identity: jade and gold life qi, earth, roots. The guarded/free state is the far signal.
- Server: GuardedHerb stops cloning `WorldTreasure` as a beacon (the client draws it). The
  framework publishes a small `state` per running event (`run.setState("guarded"|"free")`,
  included in the `WorldEvents` JSON).
- Far: a jade LightPillar (L), with a SkyCircle of leaf and root patterns. While guarded, a
  vermilion seal ring turns round the pillar's base and the sky circle; when the guardian falls
  the seal shatters and the pillar flares and turns pure jade-gold. From the peaks you can see
  that it's free.
- Mid: a jade-white CloudRing turning slowly at Y 100-200; spiralling jade motes.
- Close: a ground circle of leaves and roots on an ink base; pollen motes; falling leaves; the
  herb's glow. Gather: the pillar pulls down into the herb, then a leaf burst.

### 5.7 Beast Surge (world event, zone-wide)
Identity: crimson ink, unrest. It has no `at`, so the def gets a `look.at` (valley centre,
about (0, 5, 980)).
- Far (from the sect): a dark crimson CloudVortex (storm-grey arcs with crimson underlight)
  turning on the cloud plane above the valley; red glints flickering in it.
- Mid / in the valley: a crimson SkyGrade (lower saturation, red lean, darker) while the
  camera is inside the Inner Wilds box; a slow storm-grey arc ring under the plane at Y 300-400.
- Close: none. The beasts are the close layer.

### 5.8 Rain, Storm, Windy (small, only if cheap)
- Storm and Rain: a `Terrain.Clouds` template cloned in and tweened (Storm cover ~0.8, dark
  indigo; Rain ~0.55, grey). The sky over the peaks goes overcast for very little cost. That's
  the only change.
- Windy: nothing new.

## 6. Budget (top phase)

| Case | Far | Mid | Close (within 250) |
|---|---|---|---|
| One treasure | 3 beams, 2 SurfaceGuis (sky circle), 4-6 arcs, ~20 huge particles | 6 arcs, ~40 particles | ~150 particles, 1 PointLight on the orb |
| Heaven Split (crack + 4 treasures) | crack ~30 beams, curtains 8, parting arcs 8, ~40 particles; plus 4 x the treasure far layer | camera-local motes ~30 | the nearest treasure only |
| Auspicious Clouds + kit | existing build + 3 beams, 2 SurfaceGuis, 4 arcs | existing | existing |

A phone 600 studs from a treasure renders its far layer only: about 3 beams, 1-2
SurfaceGuis, 6-10 arcs (~12k tris) and ~20 slow particles per treasure. Mid and close
emitters are disabled past 300 and 250, and everything past 1500 updates at 4 Hz, like
WorldEventFX already does. One PointLight per event, and only while the camera is close.

## 7. Placement checks (upright, every time)
- Templates: `PrimaryPart` nil, identity `WorldPivot` at the ground point; pillar parts stood
  up inside; flat parts with up = world up; beam attachment axes set explicitly.
- Placement: `CFrame.new(spot) * template:GetPivot().Rotation * CFrame.Angles(0, yaw, 0)`.
- Test: in Edit mode, spawn each look at 3 spots from the real `Treasures.randomSpot` (moving
  its pure part into a module with no dependencies, `src/server/EventGrounds.luau`, so a
  preview can require it without pulling in PlayerData), through the real WorldEventFX /
  Treasure drawer `_create`, at 3 yaws. Capture each from the side at eye level: upright
  pillars, flat ground rings, level clouds.
- Captures per look: far (the plaza (0, 660, 140) and a peak top, e.g. Peak_4), mid (~200
  studs), close (~40), at noon and at night.
- Preview tool: `tools/worldfx_preview.luau` (`_G.worldfxPreview`): fake an entry at a
  server time offset, step the update to a given phase and freeze it, park the camera nearby
  first (Edit-mode particles only simulate near the camera).

## 8. File: WorldFX in its own binary (for the user)
Proposal: `assets/WorldFX.rbxm` mapped to `ReplicatedStorage.WorldFX`. All the new kit
templates go there, staged in `ReplicatedStorage._StagingWorldFX`, and exported with
`tools/export_rbxm.luau`.
- For: world-fx and vfx stop sharing one binary, so they can work and export at the same
  time; the far-layer templates are big and change on their own schedule.
- Against: one more mapping; the Auspicious Clouds pieces stay in `Effects` (the server reads
  `Effects.AuspiciousClouds.Relics`) until one coordinated move. That move means one
  Effects.rbxm export while no vfx agent is running, plus path changes in
  `WorldEvents/AuspiciousClouds.luau` and `WorldEventFX`.
- Recommendation: create WorldFX now and build the whole pass there; move AuspiciousClouds
  later in a quiet window. Nothing in this plan needs an Effects.rbxm export.

## 9. Build order (one commit per finished look)
0. **Groundwork** (one commit): the WorldFX file and mapping (if approved), `SkyGrade` and the
   DayNight hook, `WorldFX/Kit.luau`, the `EventGrounds` split, the preview tool. Then the
   **far-read test**: a bare LightPillar at G1, captured from the plaza and a peak, by day and
   at night. That settles the haze question before anything else is built on it.
1. **Treasure birth** (the user's first ask, and the earlier run's target): LightPillar,
   SkyCircle, a small SkyCrack, CloudRing (violet), GroundCircle, violet mist and grade; the
   Treasures attribute and the landing delay.
2. **Heaven Split**: the sky-scale SkyCrack, parting clouds via `WispsRing`, curtains, and
   treasures falling from the crack.
3. **Auspicious Mist** (violet qi from the east plus the WispsRing in violet) and
   **Rainbow Aurora** (beam rainbow).
4. **Auspicious Clouds x3**: the kit layered onto the existing build.
5. **Thousand-Year Ginseng**: the pillar, the seal state, the herb's close layer.
6. **Beast Surge**: the crimson vortex and the zone grade.
7. **Storm / Rain** overcast, if there's time.

## 10. Decisions (user, 2026-10-21; the plan was approved with these picks)
1. World effects live in their own file: `assets/WorldFX.rbxm` mapped to
   `ReplicatedStorage.WorldFX`, staged in `ReplicatedStorage._StagingWorldFX`. The vfx and
   world-fx agents no longer share a binary.
2. While an anomaly animates its copy of `Map.Clouds.Wisps`, the client hides the real ring
   locally, so the ring itself seems to come alive.
3. The Neon `WorldTreasure` pillar is retired for treasures, and the claim waits ~7 s for
   the landing.
4. A soft white flash when the heavens tear; an impact frame or shake only near a landing,
   kept gentle.
5. Heaven Split may thin the haze server-wide if haze eats the pillars. The far-read test
   (below) showed that it does, at any distance past ~800 studs.
6. The Game Module is wanted, but the user inserts it from the vfx plugin. Build
   plugin-compatible and play through the fallback until it's in.
7. Beast Surge: the crimson vortex at the valley centre.
8. Ginseng: add a `state` field to the WorldEvents publish.
9. Tribulation clouds stay out of this pass.

## 11. Far-read test (step 0, 2026-10-21)
A bare LightPillar (white core 8 wide, violet body 50, accent haze 180, to Y 1400) at West
Field (-400, 1000), captured from the plaza edge (0, 655, 120; ~1000 studs) and the far
north spirit peak (-114, 565, -277; ~1330 studs):
- Default day sky (density 0.36, haze 1.8): only the additive white core survives; every
  coloured layer fogs to the sky colour. In Auspicious Mist weather (+0.1 density, +1.4
  haze) nothing is visible at all.
- Colour with LightEmission 0 doesn't help: a near-opaque violet slab still fogs out. The
  Atmosphere density is what decides it, not haze or brightness.
- Density 0.28, haze 1.0: the violet body and haze read clearly by day from both spots, and
  the world still looks hazy. At night they glow strongly. At night with the default
  0.36 / 1.6 it reads, but dimly.
- So: while a far layer is up, SkyGrade caps density at ~0.28 and haze at ~1.0, weighted by
  the event's phase ("the sky clears as heaven opens"). That's decision 5, applied to every
  anomaly that drops treasures, not only Heaven Split, since their pillars are the far layer.
- Up close (under ~150 studs) the 180-wide haze is a wall of light, so the pillar narrows and
  fades its haze and body near the camera.
- Upright: the LightPillar placed through `Kit.place` at three `EventGrounds.randomSpot`
  spots (seed 7: East Flat, West Field, South Flat) with three yaws stood vertical in
  side captures; top at Y 1400, puncture on the plane at Y 441 each time.

## 12. Treasure birth as built (step 1, 2026-10-21)
What changed from the plan, found while building:
- The cloud plane is opaque from below too and sits at Y ~339.6 in the place, not 440, so
  the birth plays twice: a high rift for the peaks and a rift in the cloud ceiling for the
  valley, which tears wide when the meteor punches through. The sky circle hangs under the
  ceiling (40 below), where both the valley and the pillar's foot can see it.
- An alpha-blended violet body keeps its hue up close but vanishes at 1000 studs; an
  additive one reads far but washes white up close. TreasureFX blends between them by
  camera distance (Body brightness 1.6 to 6, Haze 1.2 to 10, LightEmission up to 1, width
  up to x1.8).
- A full SurfaceAppearance tint turned the arcs a flat saturated purple; TintMix 0.55 with
  AlphaMode TintMask keeps the cloud ramp's shading.
- The violet mist bank and local grade are in (GroundCircle Bank/Under, SkyGrade
  TreasureNear). The "violet mist from the wisp ring" for the whole sky is Auspicious Mist's
  (step 3), with the Wisps ring copy.
