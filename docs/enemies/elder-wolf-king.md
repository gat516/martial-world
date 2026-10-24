# Elder Wolf King (testbed trial)

Boss (testbed trial): fight, phases, numbers, effects, animation QA. Shared systems (AI states, wire, cues, attack mechanics, template contract): [enemies.md](../systems/enemies.md).

User direction (2026-10-21): try the animation workflow on the wolf boss; make it
reasonably hard, with real risk of dying, and add fast reaction checks: a paw swipe
and a downward paw/claw strike. The big attacks keep longer, readable anticipation
and every move leaves an opening. This is a pass on the existing QC9 boss, not a
new enemy id.

`Config.Wilds.NEW_WOLF_KING = Config.TESTBED` gates the entire pass. The main game
keeps the older body, 1500 HP and old attack pattern. After the user fights and
approves the trial, set that flag to `true` to ship it.

The trial draws `ElderWolfKingB`: the already-rigged Studio-part roster King,
promoted from `_RosterWolves.ElderWolfKing` without changing its wolf-family
skeleton. Sources: `art/enemies/wolf_family/build_elder_wolf_king.luau`,
`rig_wolf_family.luau`, `promote_wolf_king.luau`; poses:
`src/client/EnemyPoses/WolfKing.luau`, registered only for that body in
`EnemyAnimator`. It shares the Spirit Wolf's hierarchy at 2.4x, with its own
`JointManeL/R` and `JointSeal`. Dark slate body, silver mane and crest, amber eyes
and brow, jade collar seal; its shoulders stand above a player. Its eventual home
is the Inner Wilds boss arena; the trial is on the separate testbed baseplate.
The promotion cloned the live roster rig instead of regenerating it: 146 parts,
26 motors, 119 welds, the original HealthBar and six Tell attributes. The root is
upright at (0, 6.24, 0), with rest feet at Y 0. There were no AnimSaves on the source.
Only the new B template was added to the binary asset; the old King and the other
shipped templates are retained. The promotion script refuses to replace an existing
staging folder or B template.

The opener is Royal Bite. The repeating pattern is Paw Swipe -> King's Rush ->
Claw Down -> Crownfall -> Royal Bite -> King's Leap (skipped when the target is
closer than 12: it's a gap closer). King's Leap lands in its slam circle and, if the
target is still within 18 and in front, rakes at once (`arrive` `kingRake`); a miss
skids round (`kingLeapSkid`). King's Rush now pulls up 4 short of where the target
stood (`WEIGHTED_MOVES`; 3 past without it) and ends in the same rake, or
`kingsRushSkid`. Pack Call interrupts the next attack at 65%
and 30% health, then resumes that attack; `thresholdOnly = true` keeps the call out
of the normal rotation. It calls two Spirit Wolves, capped at two owned wolves
alive. Those wolves arrive already targeting and cannot howl in another pack.

| Attack (`name`) | Kind | Windup / active / server recover | Start range | Locked area | Damage (def vs `Pacing.BeastBaseline` QC9's 330 HP; share of a QC9 player) | Cooldown |
|---|---|---|---|---|---|---|
| Royal Bite (`royalBite`) | cone | 0.90 / 0.16 / 1.00 | 14 | r 15, 100 deg | 64 (19%) | 2.3 s |
| Paw Swipe (`pawSwipe`) | cone | 0.45 / 0.12 / 0.75 | 11 | r 12, 95 deg | 34 (10%) | 1.6 s |
| King's Rush (`kingsRush`) | charge | 1.00 / lane / 1.00 | 30 | 7-wide lane, 12-30 long | 82 (25%) | 3.1 s |
| Claw Down (`clawDown`) | slam | 0.55 / 0.12 / 0.85 | 11 | r 4.5 at local (1.7, 0, -7) | 46 (14%) | 1.8 s |
| Crownfall (`crownfall`) | slam | 1.25 / 0.18 / 1.25 | 14 | r 13 at local (0, 0, -3.5) | 104 (32%) | 2.9 s |
| King's Leap (`kingLeap`, heavy telegraph) | leap | 1.10 / 0.70 flight (arc 16) / 1.00 (the skid) | 12-42 | r 14 on where the target stood, telegraph runs to touchdown | 86 (26%) | 3.2 s |
| King's Rake (`kingRake`, `arrive`) | cone | 0.50 / - / 0.90 | 18 on landing | r 16, 120 deg | 40 (12%) | - |
| Engage roar (`roar`, `pack.howl`) | howl | 1.00 / 0.10 / 0.80 | first engagement (`ENGAGE_RESET`), held until the target is within 24 | no damage; staggers players within 18 studs for 0.8 s (`stun`, `PlayerStun`; circle telegraphed; a dodge evades it). Doesn't consume the pattern | 0 | - |
| Pack Call (`packCall`) | summon | 1.20 / 0.10 / 1.00 | threshold | no damage, but the howl stuns players within 20 studs for 1.0 s (`stun`, `PlayerStun`; the circle is telegraphed; a dodge evades it) | 0 | 2.6 s |

Live, the curve scales the defs to the QC9 player (215 HP, power 2.14): damage x0.65 (bite 42),
health x1.0 (1900), so the shares and hits to kill above hold.

Cooldowns start with the windup; the server always completes the attack and recover
before starting the next one. Stationary attacks hit **at windup end**. Their active
animation is the first part of server recover, not extra damage delay: the windup
reaches contact and the active phase follows through. The rush hits each player as
the dash front arrives, stops three studs beyond the locked target position, and
runs at 50 studs/s (up to 0.60 s plus the mover's 0.10 s settling allowance).
`DashSeconds` times the moving pose. Slam `offset` values are facing-local ground
studs; the downward strike's circle is under the right forepaw. The offsets are
locked with the telegraph, so the attack cannot track a late dodge.

Health 1900, QC9, weight 7, walk/run 5/20 (run raised from 14: the player walks at 16, so 14 could never close; King's Rush stays a 50/s dash), aggro 55, leash 110. Rewards, drops and
respawn remain the existing boss's. The quick checks punish slow reactions without
the damage of the big commitments; Crownfall punishes ignoring a long tell. These
are starting values for the user's playtest, not measured difficulty.

`shareTurns = true` makes the King reserve the same damaging-attack slot as its
wolves; it keeps its root planted against crowd nudges during windup and recover.
`resetOnEvade = true` sends it home when no eligible player remains, heals and
resets its pattern/thresholds there, and dismisses owned wolves on abandonment,
death or despawn. Its wolves are temporary encounter adds, not arena residents.
The testbed zone `WolfKingTrial` spawns one at (0, 648.6, -300), away from the wolf
and boar pairs and the spawn pad. Fight at QC9 for the intended comparison; the
test kit gives equipment but does not change the player's realm.

Effects: `src/client/EnemyFX/ElderWolfKing.luau`, gated to `ElderWolfKingB`; standard
`windup`, `strike`, `dash`, `land`, `skid`, `hit`, `stagger`, `death` cues plus `ready`
and `aggro` (the aura). Every windup's `seconds` covers only the windup. Body hooks:
`Mouth` (Skull), `Core` (Chest), `PawFL_FX`/`PawFR_FX`/`PawBL_FX`/`PawBR_FX` (the
paws), `EyeL`/`EyeR`, `Neck`. No new remotes.

The King's effect set, `Effects.ElderWolfKing` (30 templates, 86 emitters, 21 mesh
waves; builder `tools/vfx_specs/ElderWolfKing.luau`, installs
`_G.buildElderWolfKingFX`), was rebuilt on 2026-10-22 with the intent-first method
(`.claude/skills/vfx-method/SKILL.md`). Each move has an intent, a ms beat sheet and a layer sheet
(cause, role, library asset and why) in the builder's header, one hero per beat, and
layers staggered behind their cause. The old set (28 templates, ~190 emitters) layered
the shared `Impact` kit on top of its own impacts, redrew the danger area with a gold
ground `Marker` and turning formation arrays, and popped most layers on one frame. All
of that was cut.

Look: moon-silver qi (white core, pale-blue rim) on ink and slate. The King's gold
shows only on the first frame of a move (eyes, raised claws). Anything that hits the
ground throws warm grey dust and debris. No crown or halo, no copy of the body, no
always-on ground circle (user, 2026-10-21).

Shapes come from library flipbooks and meshes found by searching for what each move
causes (air, dust, debris, light):
- a dust puff opening into a ring (12360899465)
- a star burst (13580358178)
- air wisps (12094495797)
- a twinkle (102648375149008)
- a spirit flame (81332883799807)
- rising smoke (17703378809)
- swirl-ring and twisting-column meshes as 3D shocks (`MeshWave` models, played by
  `TechniqueVFX.emit`; the handler scales them with the template)

| Move | Intent | Anticipation | Peak (hero first) | Sound at the peak |
|---|---|---|---|---|
| every windup | the King's intent | `EyeGlint` on both eyes, 0-350 ms | - | voice: EnemySounds `Attack` |
| Royal Bite | draws breath, snaps its jaws on the space in front | `BiteTell`: breath pulled into the jaws, maw glow on ink, fang glints in the last 250 ms | `BiteSnap`: two dark-rimmed crescents slam shut (hero), +30 ms air ring shoved forward, +50 spray | `BiteSnap` |
| Paw Swipe | a quick foreleg sweep across the cone | `SwipeTell` on the left paw: star and gold claws, loudest on its first frame (short tell) | `SwipeSlash` 12 studs ahead: a brushed crescent sweeps across on a slate copy (hero), +20 claw rake, +50 wind, +60 grit | `SwipeSlash` |
| Claw Down | the right paw rises and is driven into the ground | `ClawRaise` from 50% of the windup | `ClawStrike` on the locked circle: three claw gouges carved, qi burning in them (hero), flash, +30 ground shock, pebbles, dust | `ClawStrike` |
| Crownfall | rears and slams both forepaws down | `CrownfallTell` on both forepaws: motes and air pulled in, glow accelerating, qi flames on the claws in the last 250 ms; a rising charge sound timed to end on contact (stops if interrupted) | `CrownfallImpact`: shockwave ring on a slate ring (hero), flash, carved crater with a lit crack cooling (fades over 6 s), Craters rocks, +30 pebbles, +60 dust wall, +250 settling smoke | `CrownfallImpact`, +150 `CrownfallRumble` |
| King's Rush | coils on its hind legs and bursts through the air | `Coil` on the hind paws: dust and grit kicked back from 30% | take-off `Launch` (dust burst behind, flat shock); dash `RushTrail` (air rings peel off the muzzle, speed lines, ink and moon ribbons, wake dust); stop: `Skid` from the forepaws | `Launch`; `Skid` |
| King's Leap | crouch, launch, the whole body lands | `Coil` on all four paws | take-off `Launch` at 1.3x; landing `LeapImpact`: a dust cloud bursting round the body (hero), shock ring on slate, flash, Craters rocks, pebbles. No crack (cracks are the paw slam's) | `Launch`; `LeapLand` |
| King's Rake | both forepaws rake the arrival cone | `SwipeTell` on both forepaws | two `SwipeSlash` 13 studs ahead, left then mirrored right +80 ms | `Rake` |
| Skids (`kingsRushSkid`, `kingLeapSkid`) | paws plough as the body swings round | - | `Skid` at all four paws | `Skid` |
| Engage roar | a blast of air and sound from the mouth | `RoarTell`: breath pulled in hard, maw glow | `RoarBlast`: three sound rings travel out of the mouth +0/+80/+160 on a slate ring (hero), +40 air swirl, +50 wind lines; `RoarGround` dust shoved ahead +120; the aura flares | `RoarBlast` |
| Pack Call (65%, 30%) | howls to the sky to call its spirit wolves | `HowlTell` (breath in, maw glow) and `HowlGather` (spirit motes rising in a ring round the King) | `HowlBlast`: the rings rise on an axis tilted 55 degrees up (hero); `ManeFlare` on the neck; `HowlGround` air shock over the stun radius with a dust skirt (dimmer, secondary); aura flared 3 s; the second call boosts counts | `HowlBlast` (a wolf howl) |
| Confirmed hits | the blow landing on a player | - | `HitClaw` (swipe, rake), `HitBite`, `HitHeavy` (the rest) | `HitClaw`/`HitBite`/`HitHeavy` |
| Stagger | qi knocked out of the chest | - | `Stagger` on the chest | `Hurt` (EnemySounds) |
| Death | qi leaks from the body, then the spirit breaks free | `DeathLeak` on the body, 0-850 ms | `DeathRelease` at 850 ms: a twisting column rises (hero), spirit flames, flash, ground shock, dust, motes rising ~3 s | `DeathRelease`, +300 `DeathRumble`; voice: EnemySounds `Death` |
| Aura (always on) | the King's qi | - | `AuraMane` (spirit flames, motes, embers below 70%), `AuraBreath` mist; health scales the rates and shifts the flames toward gold | - |

Layers per peak: Bite 7, Swipe 7, Claw Down 7, Crownfall 10 (+ Craters), Rush take-off
3 / dash 5, Leap landing 7 (+ Craters), Roar 9, Pack Call 8, hits 3, death 7.

Sounds: 18 under `SFX.Enemies.ElderWolfKing`: BiteSnap, SwipeSlash, ClawStrike,
CrownfallCharge, CrownfallImpact, CrownfallRumble, Launch, LeapLand, Skid, Rake,
RoarBlast, HowlBlast, HitClaw, HitBite, HitHeavy, Hurt, DeathRelease, DeathRumble.
They are library sounds: they load in Studio, but in-game permission is untested.

Shakes ride the templates' ScreenEffects attributes when the Game Module is present
(`TechniqueVFX.full`) and fall back to `CombatEffects.shake` otherwise. `Craters`
needs the Game Module too; the King's model is tagged `CraterIgnore` when its aura
starts. Held templates carry `AuthoredSeconds` and ground ones `AuthoredRadius`; the
handler refits them to the live windup and the locked circle. The telegraph is
unchanged and keeps the danger colour; no effect redraws the area.

Windup tasks cancel when the state or attack changes; rush release/dash cues dedupe,
and the trail stops on landing, interruption, death or its duration limit. Confirmed
hit flashes allow the same attack's immediate windup-to-contact state transition,
because its remote may arrive before the replicated phase update. Ground effects
stay at the locked point; body effects follow their attachment's part.

Known gaps (effects):
- Crownfall's circle sits under the King's chest (offset -3.5), so the body hides
  much of the impact from the side.
- The Craters rocks didn't show in Edit-mode previews; untested in play.
- Feel (shake strength, timing at play speed) and phone cost are untested.

## Animation QA (2026-10-22)

A motion probe over the real state timeline (`art/enemies/motion_probe.luau`, 30 Hz, plus
per-frame joint steps at 60 Hz) found the King's worst problems in the legs, not the poses:
- **Leg flips.** The shared one-joint leg solve picked between its two bends by a threshold,
  so a lower leg flipped 60-160 degrees in one frame at every footfall of the walk and gallop,
  every paw lift and plant in the attacks, the skids' steps and the death roll (keyed moves
  aren't smoothed, so these showed raw). The King now opts into `Quadruped`'s `steady` solver
  (`steady = true` in its spec; no other family changes): gait swings always take the natural
  fold, a foot being put down or picked up travels on a low arc from its authored spot to its
  plant (solved in full, levelled as it lands) instead of blending joint angles through the
  floor, a planted foot is only levelled after its solve, and the floor clamp lifts a dipping
  foot only as far as it dips. Worst one-frame steps: walk 60 -> 18, gallop 140 -> 60,
  attacks 85-160 -> under 55 (the rest are real fast lifts and the take-offs), death 118 -> 16.
- **A dead frame at every release.** The 0.06 s keyed blend restarted from the frozen contact
  frame. `seamlessStrike` on the King's family plays a stationary strike's windup straight
  into its recover (the dash phases keep the blend).
- **The rush's pawing never moved** (an overlay on planted shoulders that the plant solve
  undid): each forepaw now lifts, digs in ahead and drags back, left then right.

Per move (intent, then what changed; timings and cue moments are unchanged):
- **Paw Swipe:** the chest rears up off the striking paw, then drives down and forward
  through the sweep; the head looks with the cocked paw and leads the sweep across.
- **Claw Down:** the mass rises over the hind legs as the paw goes up, then the forebody
  drives down onto the claw (the body used to stay still while only the arm moved).
- **Royal Bite:** the held rear keeps loading (higher, wider jaw, onto the haunches) instead
  of a dead hold, then drops.
- **Crownfall:** it reaches the top earlier, hangs there still rising, and drops in 80 ms
  (was 130 ms): the paws and jaw hit at 130-150 studs/s, up from 90.
- **Pack Call and the engage roar:** the windup draws breath (chest and head rising, jaw part
  open) and the jaw opens wide at the release, where the howl and its effects go out; the
  forepaws come down as the air goes out. They used to hold the jaw wide early and, for Pack
  Call, close it at the release.
- **Skids:** the inside forepaw's step reaches round with the bend it plants with.

## Motion pass (audit A3, 2026-10-23)

The audit found Paw Swipe, Claw Down, Crownfall, King's Leap and Pack Call turning as one
block, every hero stopping dead on the contact frame, no anticipation late in Claw Down,
Crownfall and the Leap, and the rush's arrival flipping an elbow 112 deg. Intent: each blow
starts in the hips and ripples out to the head, lands with its whole weight and settles;
nothing stops dead. What changed in `WolfKing.luau` (timings, cue moments, the left-forepaw
rake and the leap's hang unchanged):
- **One clock across the phases.** The secondary lags (jaw, ears, crest, manes, seal) read
  the move's keys back across phase edges instead of fading to zero at each edge, which is
  where every strike is; they fade out only at the end of the move.
- **Ripple** (the Nine-Tailed Fox's pattern) on Royal Bite, Paw Swipe, Claw Down,
  Crownfall, Pack Call, King's Leap and King's Rake: hips > chest > neck each read the keys
  a step (1/30 s) later than the one before (the hips lead by 3, Claw Down's short windup by
  1), the head moves with the neck (a step behind it pushed the ears and crest into the mane
  blades) except in the bite and the rake, the tail trails the hips a step a link, and each
  link's world rotation is filtered over a few steps. A free leg keeps its own world timing, so a paw still hits on
  its key. The Leap's leads ease out before touchdown so the landing crouch stays on it.
- **Planted paws stay put** (`keepFeet`): the planting solve ignores sideways error, so a
  turning chest skated the support forepaw 2.8 studs under the swipe; each planted upper
  leg now rolls until its paw is back on its spot.
- **Claw Down:** the held peak keeps rising (a lift, not a crunch, before the chop), the
  claw lands on the windup's end and rakes back 0.3 unit through the ground.
- **Crownfall:** the drop starts at 0.9 of the windup and the forepaws strike a frame
  before its end, the chest crashes onto them on it, the paws skid forward under the weight
  (the scar's gouge), and in the recover each forepaw steps back under the chest (left, then
  right) instead of sliding home. Its splayed forepaws plant with the wrists 0.03 unit high
  (as do the Leap's coil): rolled onto their spots, the forearms' edges dipped into the floor.
- **King's Leap:** the coil keeps sinking into the launch.
- **King's Rush:** each pawing scrape digs in and drags back in one stroke; the dash's
  last 0.3 s brakes into the skid's brace (strides shrink, the paws come down through the
  gallop's own solve, then plant), so the rake and the skid start from four planted paws;
  the launch blends into the gallop over 0.14 s (0.06 threw a forepaw 2.8 studs a frame).
- **Skids:** the stepping forepaw carries over the top of its step and lands on a longer ease.
- King's Rake's pose recover is 0.76 s (the server's 0.9 minus the active), as played.

Probe before -> after (`art/enemies/motion_audit.luau`): body or tail ONE BLOCK in five
moves -> none; heroes stopping dead in a recover in six moves -> none; anticipation (root /
chest, studs) Claw Down none/none -> still at the release/0.80, Crownfall 0.13/none ->
0.46/2.50, King's Leap none/none -> 0.44/0.34; rush > rake elbow 112 deg at the arrival ->
under 45 through the rake, paw stops 4 -> 0; the leap still dips 1.6 on landing.

Known gaps (animation): the gallop still steps a joint 50-70 degrees a frame at lift-off
(in the dash; a keyed move gets no loop smoothing); the head hangs still in model space just
after the Leap's take-off (it flies on the server's arc); Crownfall's slam swings a
shoulder 61 deg in one frame (a deliberate snap; 57 before); head speeds at contact are lower
than before (55-90 studs/s, from 120-200) because the head now trails and is filtered;
the bent hind paw's merge into the thigh and the raised forearm into the manes are rig
geometry, as before. Feel in Play, the hand-off from EnemyAnimator's blends at real frame
rates and phone cost (each keyed frame now samples the keys about 18 times, unplanted,
plus up to three planting passes) are untested.

## Known gaps
- The Elder Wolf King's animation was reworked (secondary motion, attack variants,
  2.6 s death; see `art/enemies/wolf_family/RIGS.md`, numeric pose QA only, known clips
  listed there). The trial is untested in play: fast tells on a moving camera and at latency, paw contact against
  the locked circles, the full cue path, shared slots with two wolves, abandonment
  reset, QC9 difficulty and phone cost need the user's testbed review. The test
  kit does not raise the player's realm; lower-realm fights are deliberately much
  harder. Do not ship the flag to the main game until that review is approved.

## Open work

Left after the 2026-10-21 build and the first Opus quality pass (moved from the former boss open-work list); take items off as they land. Joints, pivots and safe ranges are in the body's `art/enemies/<group>/RIGS.md`.

Body: Elder Wolf King.

**Animation** (`WolfKing.luau`, 2026-10-22): `KingLeap` (low coil, drive, stretched
apex and hang, forepaws touch first), `KingRake` (opens on the landing compression, left
paw cocked wide, rakes across), `KingLeapSkid` and `KingsRushSkid` (brace, the head leads
the live target yaw, hind end swings out, scrabble, square up), all checked numerically
(RIGS.md). The rake uses the LEFT forepaw only (effects that tell both forepaws should
follow it; the vfx still tells both). `kingsRushSkid` is sent since `12b2610`, and leaps
hang at the apex since `596ca4a`. Left: feel in play, phone cost of the extra
secondary-motion samples.
Done: ghosts and the always-on ground mandala and ink disc removed (`719fb5d`). The
server side of `kingLeap` (r14 slam, heavy telegraph) -> `kingRake` (or
`kingLeapSkid`) is in (2026-10-22), and `kingsRush` now ends in the same `kingRake`
(or `kingsRushSkid`).
Impact pass (2026-10-22): clawDown and crownfall layer moonlight shockwave, dust,
flash and (crownfall) a scar and rocks; new `kingLeap` (crouch tell and the
landing sigil, rush trail and take-off dust, a landing slam with burst, scar and
rocks), `kingRake` (both forepaws' tells, two slashes, a dust rake), and
`kingsRushSkid`/`kingLeapSkid` dust from all four paws.
Left: judge in play whether the rising light columns (Pack Call, Death) read. The
unused `AuraGround` template is still in `Effects.rbxm`; drop it on the next
rebuild. Open from earlier: its trial zone `WolfKingTrial` still auto-spawns,
while the other bosses spawn only from the admin panel.
