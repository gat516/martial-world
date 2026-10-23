# Thunder Ape (testbed trial)

Boss (testbed trial): fight, phases, numbers, effects. Shared systems (AI states, wire, cues, attack mechanics, template contract): [enemies.md](../systems/enemies.md).

A 30-stud storm boss for Foundation 1 (`Config.Wilds.NEW_THUNDER_APE = TESTBED`; flip it to ship).
Body `ThunderApeB` (3.71x the roster ape; root box 14.8 x 14.8 x 16.3, so every reach below is measured from
its centre and starts past ~15 studs). No testbed zone: spawn it from the admin panel ("Spawn beasts"), which puts it just in front of the player, clear of its body.
3000 HP, FE1, weight 9 (a FE1 fist cannot shove it), walk 8, run 22 (the player walks 16; each phase x1.09),
aggro 90, leash 240, `resetOnEvade`. A fresh engagement opens with `challenge` (2.4 s entrance, no damage,
`pack.howl`). `def.rotate` picks the next pattern attack whose phase, range band and cooldown fit
(`rotateAttack`), so a boulder is skipped at melee; `chainOnly` attacks (`backhand`, `thunderPound`,
`challenge`) only start as a `followUp`, which now also searches `def.pattern`. Phases: `summonAt`
{0.66, 0.33} (the boss bar's ticks) call `def.phaseCall` (`phaseRoar`, `phaseStep`), which on resolving raises
the `Phase` model attribute (1-3), fires `enemyCue "phase"` and applies `phaseSpeed`.

| Attack | Kind | Windup / active / recover | Area (from centre) | Damage (500 HP player) | Phase |
|---|---|---|---|---|---|
| `clubSwing` -> `backhand` -> `thunderPound` | cone r30 110 deg / cone r30 120 deg / slam r15 at 18 ahead | .80/-/.45, .60/-/.45, .85/-/1.30 | | 50, 50, 110 | 1 |
| `poundWave` (cue only) | ring from the pound, r34, 0.45 s later, spares the slam's own circle | | | 55 | 2+ |
| `bodySlam` | lunge box 20 x 34 at 55/s | 1.10 / ~.62 / 1.10 | | 140 | 1 |
| `skyfallSlam` | leap r20 on the target, arc 26, range 22-55; `arrive` `skyfallSweep`, else `skyfallSlamSkid` | 1.20 / .75 / 1.10 | | 150 | 1 |
| `skyfallSweep` | cone r32 140 deg backhand on landing (target within 34, in front) | .50 / - / 1.00 | | 55 | 1 |
| `thunderRush` | charge box 14 x 24-64 at 95/s, pulls up 12 short of where the target stood; `arrive` `rushSwipe`, else `thunderRushSkid` | 1.20 / ~.5 / .90 | | 110 | 1 |
| `rushSwipe` | cone r30 110 deg at the end of the rush (target within 32, in front) | .40 / - / .90 | | 60 | 1 |
| `bound` | hop, no telegraph (an empty `bound` shape so the windup cue fires); landing mode `BoundMode` (never twice running; `BoundSide` +1/-1 says which way it travels across the body, so the windup leans into it): `over` past the target 22-28 (target within 50; flight .80, arc 24, turns in the air to face back), `flank` left or right 22-28 (.60, arc 11), `back` a retreat hop 14-20 farther away (target within 40; .55, arc 9), `short` a small hop round the target at the same distance (.42, arc 5) | .45 / per mode / .35 | | 0 | 1 |
| `boulderHurl` | spit r10 on the target, range 45-85 (flight always readable) | 1.7 / - / .90 (rip 0-.6, lift .6-1.0, rear back 1.0-1.25, release 1.25, flight to 1.7) | | 70 | 1 |
| `thunderLance` | `lance` box 8 x 90 | 1.4 / - / .90 | | 120 | 2+ |
| `thunderRoar` | howl, stun circle r42, stagger 0.9 s | 1.3 / - / 1.0 | | 0 | 2+ |
| `stormCall` | `storm`: 5 bolts (7 in P3), 0.45 s apart on where the target stands, r8, 0.9 s warning each (`stormBolt` telegraphs) | 1.2 / - / ~3.0 | | 70 each | 2+ |
| `judgment` | leap r28, arc 48, range 25-70, stuns 1.0 s only players its damage hit (`stun.onHit`) | 1.6 / 1.0 / 1.8 | | 190 | 3 |
| `phaseRoar` | howl, stun circle r34, stagger 0.8 s | 1.6 / - / 1.2 | | 0 | 66% / 33% |

Server additions: attack kinds `lance`, `bound`, `storm`; fields `stun.onHit`, `phase`, `chainOnly`, `phaseStep`,
`landMin/Max`, `bolts/boltsP3/boltWindup/boltInterval/boltRadius`, `wave`; def fields `rotate`, `phaseCall`,
`phaseSpeed`, `closeIn`. A leap's landing now hits with the leap's own attack (`landAttack`; `enemy.attack` has
already moved to the next pattern entry). `EnemyFX` windup cues now carry the telegraph's attack name, so
`stormBolt` and `poundWave` arrive as `cue.attack` (other windups are unchanged). Sounds
`SFX.Enemies.ThunderApe` voices (`Aggro`, `Attack_*`, `Death`, `Hurt`) reuse the King, boar and Thunder samples at low pitch (placeholders, not listened to); the effect sounds are listed under Effects below.
Poses: `EnemyPoses/ThunderApe.luau`, family `ThunderApeB` in `EnemyAnimator` (scale 3.71 applied once; the
module's loops divide speeds by its own `SCALE`). A storm call publishes its real recover as the `RecoverFor`
attribute for the pose's long channel; `bound` is treated like a leap (flight time from `active`, no active beat in recover).
Untested: all of it (feel, numbers, wall/ground checks for the flank bound, the wave's readability).

Animation QA (2026-10-22, animator; a motion probe, `art/enemies/motion_probe.luau`, plays each move
the way EnemyAnimator does and measures per frame). Found and fixed, worst first:
- The swinging fist went 6.8 studs into the ground in the club's and backhand's recovers (a free arm
  blended toward a planted one), and every rear-up from all fours sank the thighs 2.5-3.2 studs
  (the pound, the body slam, the roars, the stagger). Fixed in the pose module's plant blend.
- Every strike and leap stopped dead for a frame at its release (the 0.06 s keyed blend restarted
  from the frozen last windup frame). The family now has `seamless` (as the Jade Jiao): one
  attack's windup, dash and recover play straight on.
- Club and backhand stopped after the hit and restarted for the recover. The blow now carries
  through: one decelerating sweep past the target across the active beat, the forearm folding,
  the fist swinging back and reaching down to plant while the other arm lifts for the next blow.
- The body slam's hind feet hung 1.3-2.2 studs under the floor through the fall and the prone
  slide (now folded, drawn in under the hips as it pushes up); the death's kneel put the shins 3.4
  under (1.9 now); a back hop's landing flipped an elbow 85 degrees (the fists land with the feet).
Attack names, phase lengths, cue moments and the pose API are unchanged. Left: ClubSwing B (not the
default) still sinks its fist in its recover; the combo hand-offs (recover -> next windup) still
freeze the lifting arm for 0.06 s; the prone body and the pound's forearms brush 1.3-1.8 studs into
the floor; the rush's arrival (dash -> swipe windup) holds one frame. Untested in Play.

Effects (vfx agent): `Effects.ThunderApe` (49 templates, 127 emitters, 22 mesh waves; builder
`tools/vfx_specs/ThunderApe.luau`, installs `_G.buildThunderApeFX`), handler `EnemyFX/ThunderApe.luau` (gated to
`ThunderApeB`), sounds `SFX.Enemies.ThunderApe.<Name>` (30 effect sounds, played with `Sfx.play` at each peak from
where its cause is). Rebuilt on 2026-10-22 with the intent-first method (`.claude/skills/vfx-method/SKILL.md`; user: the effects
were technically fine but random). Each move has an intent, a ms beat sheet and a layer sheet (cause, role, library
asset and why) in the builder's header; one hero per beat, layers staggered 20-160 ms behind their cause. Cut from
the old set (58 templates): the `SkySigil` ground circles under the leaps (they redrew the telegraph), the lit crack
spreading under the roars (a roar is air and sound, it hits nothing; user's own example), the always-on
`AuraGround` formation, `AuraSigil`/`AuraMotes`/`AuraBack`, the body trail, and the shared `Impact` kit layered over
the ape's own impacts (its generic rings and scars doubled them). Storm blue-white (white-hot core, rim `B8F0FF`,
falloff `5BD8FF`) over an indigo `1B2547` or slate copy; violet only in phase 3 (runtime tint); dust and rock are lit
earth tones. No crowns or halos, no copy of the body, no flat discs. Everything is authored at the 30-stud body and
rescaled to each cue's `shape` (mesh waves too); held effects are refit to the cue's `seconds`.

Assets were found by searching the library for what each move causes (lightning, air, dust, debris, light, cracks):
crackle-arc flipbook 11492870634, bold arcs 76973563852665, forked bolt 914595092, discharge 528280947, electric
burst 7216850580, zigzag sparks 12517923720, star flash 12156297119, glint 13908198788, heavy smear crescent
88807999398470, air streaks 15107683952, dust 11989899750, breaking puff 71869624437521, rock chunks
130042646554310, cloud puffs 14050526759, crater 11705672210, carved cracks 7994630128, lightning cracks 301851161,
scorch 7216852679, wobbly sound ring 90387581951997, crackling ring 7150933366, air ring 15611866526, dust ring
16505105356, electric strip 10528782340 (beams and trails); meshes: swirling funnel 71849885439764 (the roar),
notched ring 129778117978668, shard ring 1726537151, swirl ring 73349240058321, blade ring 122007796695786, heaved
earth 89195313060285, spike flare 102470267627424, twister 117701979506507. The boulder keeps its stone mesh
(17608108317).

| Move | Intent | Anticipation | Peak (hero first) | Sounds |
|---|---|---|---|---|
| big windups | the ape's intent | `EyeGlint` on both eyes, 0-350 ms | - | voice: EnemySounds `Attack_*` |
| clubSwing / backhand / rushSwipe / skyfallSweep | a charged fist swept through the cone | `KnuckleCharge` on the swinging fist (arcs, denser in the last 25%, glint at 80%) | `SwingArc` smeared crescent on slate across the cone, tilted along the fist's path (hero); +40 arcs flung off; +60 grit; `LimbTrail` rides the fist 300 ms through the follow-through (the animation now carries past the target) | `SwingWhoosh` |
| thunderPound | both fists hammer the ground, the lightning discharges into the cracks | `KnuckleCharge` on both fists | `PoundImpact` shock ring on slate (hero), flash; +30 lit cracks over a carved crater, arcs in the cracks, heaved rock; +40 chunks; +60 dust wall; +250 settling dust | `PoundSlam`, +150 `PoundDebris` |
| poundWave (P2+) | the shock rolls on through the ground | `PoundWave`: a heaved shard ring, crackle and dust travelling r15 -> r34 over 0.45 s | `PoundWaveEnd`: dust and arcs burst off the ring | `PoundWave` |
| bodySlam | the whole weight thrown down the lane | `ChestCharge` on the chest | dash: `BowWave` (air rings off the chest, streaks), `SpeedShed`; land: `BellyImpact` dust cloud bursting out (hero), shock on slate, flash, chunks, settle | `BellySlam` |
| skyfallSlam | springs high, lands fists first | `Coil` at the hind feet from 50%, `KnuckleCharge` both fists | take-off `Launch`; flight `LimbTrail`s; land `SkyfallImpact` blade shock on slate (hero), flash, crater + lit cracks, ground forks, heaved rock, chunks, dust wall | `Launch`; `SkyfallLand`, +150 `PoundDebris` |
| judgment (P3) | leaps into the storm; the sky's bolt rides it down | `JudgeCloud` gathers over the landing (violet arcs in it from 50%), `Coil`, `KnuckleCharge`, `BodyCrackle`, the sky dims | take-off: a bolt from the cloud hits the ape (`BoltHit`); land: the cloud's bolt (code beam) + `JudgmentImpact` discharge ring (hero), spike flare, blade shock, crater, cracks, forks, chunks, dust wall | `JudgmentTakeoff`, `Launch`; `JudgmentBolt`, +100 `JudgmentQuake` |
| thunderRush | drops to all fours and charges like a storm front | `Coil` at fists and feet from 40%, `KnuckleCharge` | take-off `Launch`; dash `BowWave` (hero), `SpeedShed`, fist `LimbTrail`s; stop `Skid` at both fists | `RushLaunch`; `Skid` |
| bound | a hop | - | `Launch` at take-off (0.5x) and landing (0.7x) | `Launch`; `BoundLand` |
| skids (`*Skid`) | fists and feet plough as it turns | - | `Skid` at all four | `Skid` |
| boulderHurl | tears a boulder out, charges it, throws it | `BoulderRip` (cracks, plume) 0-600; the rock rides the fist shedding dust (no chunk particles on the throw: user, 2026-10-23); `BoulderCharge` arcs the last 250 ms | flight: dust trail, shadow; impact `BoulderImpact`: the rock crumbles apart (4x4 rock flipbook 126533699507957, boulder-sized dark pieces drawn over the dust, hero), a few small dark chips (626588936), a short dust burst (0.5 s), a small flash and discharge, shock on slate, crater | `BoulderRip`; `BoulderThrow`; `BoulderImpact` |
| thunderLance (P2+) | forges a javelin of lightning and hurls it | `LanceForm`: arcs drawn into the fist, the javelin grows from 300 ms, glint at 1250 | `LanceFlash` at the throw; `LanceBolt` in flight (hero: the tip rides the projectile and the 14-stud shaft trails behind it, `AuthoredLength` 14, so at release it reaches back to the fist) + `ScorchSpot`s; end `LanceFlash` + `BoltStrike` | `LanceCharge` (sped up to end at the throw; stops if the windup breaks); `LanceThrow`; `LanceImpact` |
| thunderRoar / phaseRoar / challenge | chest beats, a breath, then air, sound and lightning from the mouth | `ChestBeat` on each beat (air thumped off the chest, sparks), `Inhale` + `BodyCrackle` in the last 450 ms | `RoarBlast`: a translucent swirling funnel opening out of the mouth over an indigo copy (hero), sound rings +0/+80/+160, arcs +40; `RoarGround` +120: dust shoved out to the stun radius. phaseRoar: four storm bolts land round it | `ChestBeat`, `Inhale`; `RoarBlast` + `RoarCrackle` (+ `StormRaise` on phaseRoar) |
| stormCall | arms raised, the storm answers | `StormRaise` arcs climbing off the back, `KnuckleCharge`, the sky dims | a bolt leaves the back for the sky; each bolt: `BoltGather` cloud over the point (arcs from 55%), then the bolt out of it + `BoltStrike` (flash, discharge, scorch, sparks, dust) | `StormRaise`; `BoltStrike` |
| phase change | the storm surges out of the body | - | `PhaseSurge` arcs burst (hero), discharge, flash, air ring; tells flash white; aura rebuilt | `PhaseSurge` |
| hits | the blow on the player | - | `HitStorm` / `HitHeavy` (+ `StunArcs` 1 s after judgment) | `HitStorm` / `HitHeavy` |
| stagger | qi knocked out of the chest | - | `StaggerPop`, tells flicker | EnemySounds `Hurt` |
| death | the storm leaks out, then leaps back into the sky | `DeathLeak` arcs over the body, rates ramping 0.4x -> 2.8x, code bolts lancing out faster | 3050 ms `DeathRelease`: a twister rises round a bolt to the sky (hero), flash, discharge, rising arcs; `DeathGround` shock and dust; tells go slate | `DeathCrackle`; `DeathRelease`; voice EnemySounds `Death` |
| aura | the storm on the body | - | `AuraForearm` arcs, `AuraCloud` indigo wisps on shoulders and back; P2+ `AuraArcs` on fists and shoulders and arcs jumping between them; P3 violet, white eyes | - |

Layers per peak: swing 5 (+trail), pound 11, pound wave 3 + 2, belly slam 6, skyfall landing 12, judgment landing
13 (+ the bolt), rush dash 3 + trails, boulder impact 7, lance flight 4 (+ trails), roar 7 + 2, bolt strike 6 (+ the
bolt), phase surge 4, hits 3 / 4, death release 4 + 3. Sounds: 30 under `SFX.Enemies.ThunderApe` (library sounds:
they load in Studio; in-game permission is untested). Shakes ride the templates' ScreenEffects attributes when the
Game Module is present and fall back to `CombatEffects.shake`.

Checked in the sandbox (Edit mode, fake cues on the real body, noon, two review rounds): the pound peak and +400 ms,
the swing, the roar's funnel, the skyfall landing, the judgment cloud and landing, the storm bolt's cloud, the
phase surge, the death release; every cue fires without errors (`enemy_fx_smoke`, `stateful`). Not checked
visually (the 2026-10-23 fix pass checked the lance in flight and the boulder impact at 25-35 studs): the code bolts (beams fade before a still), rate-driven layers (coil dust, the rip's plume), trails,
dash layers, the boulder in flight, night, phones and the Game Module (add-on shakes).

Known gaps (effects):
- Dust and rock are earth-lit, so they read low on the grey testbed baseplate; they are meant for grass and stone.
- The judgment cloud is placed at the windup and does not follow a target that moves the landing (the server
  locks the circle with the telegraph, so it should match).
- Feel (shake strength, sound mix, timing at play speed) and phone cost are untested.

## Open work

Left after the 2026-10-21 build and the first Opus quality pass (moved from the former boss open-work list); take items off as they land. Joints, pivots and safe ranges are in the body's `art/enemies/<group>/RIGS.md`.

Body: `ThunderApeB`, 3.71x, about 30 studs tall.

**Animation** (`src/client/EnemyPoses/ThunderApe.luau`; part 1 is `130f0b5`). Done:
timings match `122e93b`, the boulder throw beats (release at 1.25 s, fist 2.7 studs
from the spawn point), gait touchdown pops, continuous secondary motion, and the
motion pass (A1, 2026-10-23; before and after numbers in its commit, rig notes in `art/enemies/beasts/rigs/thunder-ape-b.md`): the hips
lead and the skull trails every keyed move (no move turns as one block), every fist
under 560 studs/s and every one-frame joint step under 45 degrees, no fist parks inside
the boulder or club windups, skyfall and judgment land on long legs and compress
(1.5-2.2 studs), the combo hands off on all four fists, the solved chest-beat arm is in
the roars, Death and BodySlam C, and the club/backhand sweeps pass under the head
(forearm into beard 0.7, was 2.6). Left:
- **Recovers:** the fists slide up to about 7 studs along the ground in the pound
  recover. They should step.
- **Small clips:** the beard sits about 1-1.5 into the chest in the sweeps and leaps;
  SkyfallSweep's forearm grazes the skull (1.0); ClubSwing variants B and C (not the
  default) still clip and sink a shin (1.2).
- **Thunder Lance:** the solved throw arm (RIGS) is not swapped in; the throw keeps the
  extended javelin arm, which reads better.
- **Hand-offs to idle:** a backhand or club recover ends twisted on all fours for the next
  blow; if a combo is cut short, idle pulls it straight in a few frames.
- **Death:** ends 1.8 under the floor (lying shins), as before.
- **Arrivals and bounds (feel pass, 2026-10-22, `WEIGHTED_MOVES`):** posed. The rush's
  last strides draw the right arm back and brace, `RushSwipe` unwinds into a flat
  belly-height sweep, `SkyfallSweep` backhands from the landing crouch, and both skids
  brake, swing round head first with one arm stepping across, then settle (a left and a
  right version by the target's side). `Bound` has one pose set per `BoundMode`:
  `over` (counter-rise, deepest crouch, arms flung up, tuck and hang), `flank` (loads the
  far side, leans into the travel), `back` (rocks onto the fists and shoves off; feet
  land first, fists after), `short`. A head-leads-the-turn layer follows the root's turn
  rate in every move (strongest in the air), and leaps and bounds hang at the apex
  (`EnemyMotion`). The skyfall and judgment crouches no longer sink the thighs (the hind
  feet land under the hips). Left: feel in play, the blend of the arrival hand-off (the
  pose holds while `Attack` catches up with AIState), `BoundSide` (the lean's
  anticipation only shows when the server sends it), effects for the new moves.
- **Feel:** whether the combo still feels rushed, and whether the trailing head (0.1 s
  behind the chest in world aim) wobbles on fast turns in play, hasn't been judged.

**Effects** (`src/client/EnemyFX/ThunderApe.luau`, `tools/vfx_specs/ThunderApe.luau`).
Rebuilt intent-first on 2026-10-22 (49 templates, 30 effect sounds; the record and
every move's beats are in this doc, above). The shared
`Impact` kit, the leaps' ground sigils, the roar's ground crack, `AuraGround`, the
chest sigil flare and `DeathSoul` are gone. Left, all untested:
- feel at play speed, the sound mix and whether the library sounds play in-game;
- night, the 40-stud read and phone cost (the judgment landing is the heaviest
  beat: 13 layers plus the bolt);
- the code bolts, trails, dash layers and both drawers in flight (none freeze for
  an Edit-mode still), and Game Module playback (add-on shakes);
- the boulder still jumps from the animator's fist to the server's fire point
  `(7, 14, -2)` at hand-off.

**Drops:** the Thunder Ape and the fox reuse the Wolf King's drop pool as a placeholder.
