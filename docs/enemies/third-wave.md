# Third bestiary wave: Blood Centipede, Flame Raven, Blood Bat (testbed)

Blood Centipede, Flame Raven and Iron-Winged Blood Bat (testbed): fights, numbers, effects. Their mechanics (`slow`, `patch`, `leech`, `slot`, burrow, flier height, `perch`, `embers`) are in enemies.md "Attack mechanics". Shared systems (AI states, wire, cues, attack mechanics, template contract): [enemies.md](../systems/enemies.md).

Three more regular beasts on bodies already in `assets/Enemies.rbxm` (templates
`BloodCentipede`, `FlameRavenB`, `BloodBat`; RIGS.md has each rig), behind
`Config.Wilds.NEW_CENTIPEDE`, `NEW_RAVEN`, `NEW_BAT` (all
`= TESTBED`; none has an old def, so each exists only while its flag is on, and none is in an
ambient pack yet). Testbed zones: `CentipedeSolo` (180, 0), `RavenSolo`
(-180, -160), `BatSwarm` (4 bats, 180, -160), all Y 648.6. They fit
realms and regions like this: Centipede QC6 (Ruined Borderlands), Raven
QC8 and Bat QC8 (deep Borderlands). Numbers are first guesses; the
user retunes them. A beast of each element is an affinity: centipede earth-blood, raven fire,
bat wind-blood. On 2026-10-22 the user cut the Frost Spider (FE1, ice trapper) and the Golden Toad (QC3,
bog ambusher; its rebuild still looked bad); their bodies, fights, effects and sounds are
gone, but the mechanics they used (`slow`, `patch`, the snare `pull`) stay for later beasts.
The same day the user asked for a modeling pass on the Centipede and Bat bodies (the first
builds read as weak). The Centipede is rebuilt (128 parts, same 43 joints and names, crimson
and bone with roof-tile plates, bigger hooked pincers, two-piece legs; RIGS.md has the moved leg,
pincer and antenna pivots). Open: the animator re-QAs the leg ripple (neighbouring legs pass
through each other, as on the old body) and the pincer close (the hooks cross at a full slam),
and its effects are still tuned to the old bone-and-rust palette. The Bat is rebuilt (48 parts, same 13
joints, names and pivots; a real three-finger iron hand with scalloped crimson skin, taller
ears, a rust pug snout and chest bib; Mouth, Core and the wing-tip attachments moved onto the
new geometry). Open: in Stagger, and briefly in the Death flail, the longer hand passes into
the body; scaling Stagger's wing yaw to 0.7x clears it (a pose-module change for the
animator), and `poses_blood_bat.md` still has the old skin-tilt numbers.

| Beast | Attack (`name`) | Kind | Windup / active / recover | Range | Area | Damage |
|---|---|---|---|---|---|---|
| Centipede (QC6, 320 HP) | `pincerSnap` (opener) | cone | 0.6 / - / 0.9 | 14 | r 11, 60 deg | 18 |
| | `coilSweep` | cone | 0.9 / - / 1.0 | 10 | r 12, 200 deg | 22 |
| | `burrowDive` | burrow, then `erupt` | 0.5 / up to 30 studs at 40/s / 0.1 | 8-32 | lane 5 wide | 0 |
| | `erupt` (followUp) | slam, stagger | 0.7 / - / 1.1 | chained | circle r 6.5 | 30 |
| Raven (QC8, 260 HP) | `talonDive` (opener) | charge, arrive `talonRake`, perch 1.5 | 0.8 / up to 20 studs at 34/s / 1.2 | 10-24 | lane 3 | 20 |
| | `talonRake` (arrive) | cone | 0.35 / - / 1.0 | 9 | r 8, 100 deg | 24 |
| | `emberFan` | barrage embers | 1.0 / - / 0.9 | 8-24 | 3 circles r 3.5 | 18 each |
| | `windGust` | cone, knock 10, then hop back 8 | 0.5 / - / 0.7 | 9 | r 10, 70 deg | 8 |
| Bat (QC8, 60 HP, swarm of 4) | `bloodDive` (opener) | charge, leech 0.5, hop away | 0.6 / up to 14 studs at 30/s / 0.8 | 6-16 | lane 2.5 | 12 |
| | `sonicShriek` | howl + stagger 0.6 s, `slot` | 1.0 / - / 0.8 | 10 | circle r 10 | 0 |

Sounds reuse existing ids pitched, picked by description and unheard
(`SFX.Enemies.BloodCentipede`, `FlameRaven`, `BloodBat`). Untested in
play: all of it. Specifically the centipede's dive
lane on uneven ground, the perch drop reading as a landing, three or four bats' phone cost and
whether overlapping shriek and dive windups feel fair (one slot at a time), the `slow` strength,
and every number.


## Realm variants
Tiers and knobs: [enemies](../systems/enemies.md#realm-variants-2026-10-23); young below the
beast's realm, elite from 3 stages up, apex from 6 (or a major realm up).
- **Blood Centipede** (QC6): young never burrows; from elite, staying close after the pincers
  draws the coil sweep.
- **Flame Raven** (QC8): young has no ember fan; from elite the gust's hop back ends in the fan.
- **Blood Bat** (QC8): young bats don't shriek; elite and apex drink 75% of what they deal.

## Effects: Blood Centipede
Handler `EnemyFX/BloodCentipede.luau` on `BeastKit`; template
`ReplicatedStorage.Effects.BloodCentipede` (builder `tools/vfx_specs/BloodCentipede.luau`),
gated by `Template` = the template name. Smoke test: `tools/enemy_fx_smoke.luau` (fires cues
at the real bodies in a sandbox).

| Beast / beat | Layers (templates) |
|---|---|
| Centipede windup | EyeGlint (red); seams and pincer Tells light front to back (`K.tell` sweep) |
| pincerSnap / coilSweep | CrescentSnap (two blood crescents, flecks) at the Mouth; SweepArc (flat crescent on slate, dust fan) + `Impact.swipe` |
| burrowDive / `Burrowed` | dash: DiveBurst; while `Burrowed`: plates fade, BurrowMound (earth hump, dirt, chips) rides the ground under the root and CrackStamp (crack + rust glow) is stamped along the lane every 0.14 s; the plates return when it clears |
| erupt | Eruption (scar, rust glow, dust column, chips, flash, ring) + `Impact.ground` (rocks, shake 0.3 within 30) |
| hit / stagger / death | BloodHit (splatter, drops, pop); StaggerFlash; Death (bone dust, red motes, glint) |

`Burrowed` is set only for the dive and cleared by erupt (BossAttacks), the client hides the body. Untested in play.


## Effects: Flame Raven and Blood Bat
Handlers `EnemyFX/FlameRaven.luau` (Template `FlameRavenB`) and `BloodBat.luau`;
templates `Effects.FlameRaven` (10, 34 emitters) and `Effects.BloodBat` (8, 15
emitters; the swarm gets 1 to 3 emitters a beat, the single shrieker plays
`Impact.roar`).

| Beast / beat | Layers (templates) |
|---|---|
| Raven windup | EyeGlint (gold); the eight primaries and Crest Tells dim -> gold; TipFlare (soot base, flame glow, sparks) on both wing tips and the crest |
| talonDive | dash: EmberTrail on both wing tips for 0.6 s (smoke, flame, embers); land: small EmberBurst under the talons; skid: `Impact.skid` fire palette |
| talonRake / windGust | FlameSlash (3-claw on soot, sparks, glint) at Talons_FX; GustBlast (wind streaks, dust fan, sparks) + `Impact.swipe` r10 |
| emberFan | each windup cue with a `shape` lobs an ember (`BeastKit.lob`) from the Mouth to land at the windup's end (+0.15 s per extra cue); the barrage sends one cue, so the handler lobs one ember to each circle in `shape.parts`. EmberBurst (scorch, rings, flame, sparks, flash) + `Impact.explode` |
| hit / hop / stagger / death | HitFlame; WingPuff; StaggerFlash; Death (feathers go to ash: ash, embers, glint) |
| Bat windup | EyeGlint (crimson); WingEdgeTell, MouthTell, ChestCore dim -> flare |
| bloodDive | dash: DiveStreak (2 emitters) on the Core; `leech` cue: a LeechMote trail flies from the target's torso to the bat's Core in 0.5 s, then ChestFlash |
| sonicShriek | `Impact.roar` (crimson/pale palette) from 40% of the windup |
| hit / hop / stagger / death | BiteHit (3); HopPuff (2); StaggerFlash (1); Death (feathers, blood mist) |

The perch (root 1.5 studs lower after a dive) needs nothing: effects ride the body and
read the root's ground. The emberFan sends one windup for all three circles (`shape.parts`). Untested in play.
