PLAN (not built): Heaven Split, the sky-scale crack over the sect, and the big SkyCrack kit piece it needs. Read when you build Heaven Split (step 2) or any large sky crack.

# Heaven Split (anomaly, global) — plan

Today (`client/WeatherFX.luau`): a grade lean and distant bolts; **no split**. Its treasures
are gold and already built ([treasure_birth.md](treasure_birth.md)); here they fall out of
the big crack instead of their own small rift. Kit and rules: [../world_events.md](../world_events.md).
References: Genshin void rift (lips, dark star-sea, shards), Sol's Equinox (one hard seam,
then a glint at its tip), Perfect World (light curtains through the cloud deck, lens
streak), Enkidu (dim world first).

## Placement

A crack about 1600 long, centred about (0, 1500, -700), north of the summit, running roughly
east-west and tilted, so it fills the sky above the plaza's northward view and the spirit
peaks see it from the side. The valley can't see above the plane, so there the read is light
curtains pouring through the cloud deck onto the event grounds, plus the treasures' pillars.

## Timeline

| t | Beat | Far (everyone in the sect) | Mid / close |
|---|---|---|---|
| 0-8 (FADE) | Omen | SkyGrade: exposure down, saturation down, a dim gold-indigo lean; a gust; bolts double in rate; one glint where the crack will open | |
| 8-12 | Tear | the crack draws out of the glint in both directions; a soft global white flash (Grade pulse, decision 4); thunder; edge flicker | the clouds part: the main peak's `WispsRing` copy is pushed outward and lit gold underneath |
| 12-end | Sustain | the crack breathes; gold light curtains fan down onto the peaks; golden streaks rain slowly; the void drifts | on the peaks gold motes falling (a camera-local emitter, like the weather's); treasures fall out of the crack |
| last 8 | Heal | it closes from the ends; a last glint; the grade eases back | the ring settles back |

Layers: crack lips (2 per segment), void, curtains (6-10 beams), flicker, shards, tip glints,
parting clouds (6-8 arcs), grade, motes: 9 kinds. Budget: crack ~30 beams, curtains 8,
parting arcs 8, ~40 particles, plus 4 x the treasure far layer; camera-local motes ~30; only
the nearest treasure's close layer.

## SkyCrack (sky-scale; the built `SkyRift` is the 150-long version)

Geometry in front of the skybox, a jagged polyline of 8-14 segments. Shape is data (points in
a table), so one template serves 1600 long or 150 long.

| Layer | Carrier | Motion |
|---|---|---|
| Lips | per segment, FaceCamera Beams: a narrow white-hot core and a wide soft colour glow | draws from the origin outward, segment by segment; width breathes |
| Void | a band behind the lips: wide Beams with a dark star-sea texture (indigo or black with motes) | widens as it opens (dark under light) |
| Light spill | curtain Beams fanning down from crack points (ray texture), long enough to reach the cloud plane or the ground | sway, flicker |
| Edge flicker | lightning-flipbook particles along the segments | bursts every 0.5-2 s |
| Shards | falling shard particles from the lips | slow fall, spin |
| Tip glint | 4-point star plus lens streak at the origin and each growing end | it opens out of the glint |
| Clouds parting | Cloud_WispArc pieces along both sides, drifting outward perpendicular to the crack, lit underneath in the crack colour | push apart as it opens, close in as it heals |

Beats: `glint` (1 s), `tear` (2-4 s), `breathe`, `heal` (closes from the ends inward, last
glint, out). The haze cap (density ~0.28, haze ~1.0) applies while it's up.
