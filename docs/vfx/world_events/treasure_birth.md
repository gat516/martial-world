Heavenly treasure births as built (step 1, 2026-10-21): identity, server publish, beats, layers and what changed from the plan. Read when you touch TreasureFX or reuse its pieces for another event.

# Heavenly treasure birth (built)

Full as-built behaviour, timings and files: [event-fx.md](../../world/event-fx.md) ("Heavenly
treasure birth", "World FX kit"); known gaps in [world.md](../../systems/world.md). Runtime:
`src/client/WorldFX/TreasureFX.luau` (beat constants at the top). Shared kit and rules:
[../world_events.md](../world_events.md).

**Identity** by the anomaly: violet (Auspicious Mist), pearl-white with prismatic rims
(Rainbow Aurora), gold (Heaven Split); the item's colour is the core accent. The user's three
asks meet here: violet mist from the wisp ring, the sky splitting, a light pillar.
References: Celestial Rain (the descent), Genshin void rift and Sol's Equinox (the rift),
Xianwu violet mist (the mist bank and lotus), Enkidu (the pillar between circles).

**Server** (`Treasures.luau`): publishes `workspace.HeavenlyTreasures` (JSON
`[{ key, at, color, weather, born }]`) on spawn, claim and fade. The server model is only
the orb, prompt and label (`WorldTreasure` without its Neon `Pillar` and `Ring`), parented at
`born + Treasures.LAND` (7 s) so the claim waits for the landing. A claimed treasure drops out
of the attribute and the client plays the collapse.

**Beats** (seconds from `born`, server clock):

| t | Beat | Above the plane (peaks) | Below the plane (valley) / close |
|---|---|---|---|
| 0-2 | Omen | star glint; `SkyRift` tears open at Y 1150, 140 studs to one side of the spot | glint and faint seam in the cloud ceiling |
| 2-6.5 | Descent | `Meteor` arcs down out of the high rift | where it crosses the plane the ceiling rift (24 under the plane, beams x2.2) tears wide in 0.35 s and rains light |
| 6.5 | Impact | `LightPillar` drives down in 0.6 s | Landing flash, glint, lens, shock ring and rays; gentle white pulse within 150 studs, small shake within 80 |
| after | Sustain | pillar, puncture ring on the plane, rifts heal over 3 s | `SkyCircle` (r 110, 40 under the plane) opens ring by ring over 1.4 s; two `CloudRing` layers settle from above at Y 70 and 130 and turn (4 s); `GroundCircle` sigil, mist bank and light round the treasure |
| gone | Collapse | pillar pulls up into the sky | circle shrinks out, arcs fling outward, 2.5 s |

Joining mid-birth skips the bursts and fades in over 1.5 s. Layers by camera distance: far
always (pillar beams, puncture, sky circle, rifts, arcs), mid within 650 (streaks, motes,
flow, arc mist, rift flicker, shards, rain), close within 300 (ground sigil emitters, mist
bank, light); past 1500, a few updates a second. The pillar is the anomaly size x0.6.

**Changed from the plan while building:**
- The cloud plane is at Y ~339.6 and opaque from below too, so the birth plays twice (high
  rift for the peaks, ceiling rift for the valley) and the sky circle hangs under the ceiling
  where both the valley and the pillar's foot see it.
- The pillar's colour layers blend by camera distance (300-1200 studs): Body brightness 1.6
  to 6, Haze 1.2 to 10, LightEmission up to 1, width up to x1.8, and thin out within ~80-320
  studs.
- Arc tint: TintMix 0.55 with AlphaMode TintMask.
- SkyGrade: `TreasureClear` caps density 0.28 / haze 1.0 while any treasure is up;
  `TreasureNear` leans the air to the anomaly colour within 120-340 studs (the violet mist
  bank's local grade). The whole-sky "violet mist from the wisp ring" is Auspicious Mist's.

Design numbers from the plan, kept for retuning: layer count at sustain far 6 (core, body,
haze, puncture disc, puncture arcs, sky circle), mid 4 (arc ring, streaks, helix, mist bank
top), close 8 (ground circle, ink base, orb glow, lotus, motes, sparkles, petals, ground
mist); peak 7-8 at impact. Planned but not built: the qi helix on the pillar, a lotus of
light under the orb, an impact frame (only a pulse and shake shipped).
