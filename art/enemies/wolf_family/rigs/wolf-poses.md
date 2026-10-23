# Procedural poses (`src/client/EnemyPoses/Wolf.luau`)

Part of [wolf_family/RIGS.md](../RIGS.md): read that file's shared rules first.


Combat pass (2026-10-21). EnemyAnimator can't play clips yet, so the wolf family's
animation is a pose module: Transforms by motor name, sampled per frame. Its format
(documented at the top of the file) is the fixed format for every later beast's
`EnemyPoses/<Family>.luau`:

- `Wolf.moves[Move][Phase]` with phases `windup` / `active` / `recover`: a designed
  `duration`, `keys` `{ t = 0..1, pose, ease, plant = { "FL", ... }, reach = { FL =
  Vector3 } }`, an optional `overlay(u, secs, input)` for fast shakes and wiggles,
  `mirror` (play mirrored by `input.side`) and `air` (the client lifts the body).
- `Wolf.loops.idle/walk/run/circle(phase, speed, input)`, with `Wolf.gaitRate` giving
  the phase speed that keeps planted paws from skating.
- `Wolf.sample(move, phase, u, input)`, `Wolf.scaled(pose, scale)` (JointRoot studs
  for the King 2.4 and Shadow-Mane 1.15), `Wolf.plant(pose, legs, reach)`.
- Only shared joints are keyed, plus JointCrest (Spirit Wolf and King; a body without
  it just skips it). Manes, seal and forelock are left to per-body overlay tables.

**Planting.** A planted paw stays on its rest spot plus the key's `reach`: a two-joint
solve in the leg's plane sets the shoulder/hip and the elbow/knee, then the wrist/hock
levels the paw, so the paw is flat on Y 0 whatever the root, spine and pitch do. If a
leg can't reach without stretching past its rest length, the root drops. So a pose
authors the root, spine, head, tail and paw offsets; the legs follow. Moves outside
the air phases also floor-clamp every unplanted paw. The gait loops instead swing the
upper legs from the cycle and solve only the middle joint (stance paws on the ground,
swing paws lifted a set clearance).

**QA:** `wolf_family/qa_wolf_poses.luau` samples every move phase and loop, poses the
template by forward kinematics (nothing in the place moves) and reports each paw's
lowest point, sinking, joint gaps, clipping between segments, merges at folded joints
and middle-joint range. `_G.WOLF_POSE_PREVIEW` leaves anchored posed copies in
`Workspace._WolfPoses` (EditorOnly, on a plate at X -200 to -420, Y 400, Z 3100).

### Learned on this rig (pose module pass)

- **The hind knee closes on -X.** The shin slants back from the knee to the hock, so
  near rest a compressing hind leg (a crouch, a sit, a landing) bends the knee
  negative, and the hip goes positive. The old "+X bends the shin forward (crouch)"
  holds only with the hip swung back: a crouch with the paws planted where they stood
  is hip about +0.5, knee -0.6 to -0.95. The brief's "hind knees +0.6" coil is this.
- **Elbows:** in a crouch with the forepaws planted, the forearm comes forward under
  the chest (elbow +1.0 to +1.25, clean). In swing it folds back (-0.3 to -1.3, clean).
- **Crouches need the paws to move.** Root -0.55 with the paws on their rest spots jams
  the shins into the hips and the hocks into the thighs (0.18 to 0.21). Forepaws 0.3
  forward and hind paws 0.4 to 0.6 back clears them. A landing squash at root -0.4
  clears with forepaws 0.3 forward and the paws 0.25 to 0.3 wide.
- **Merges that remain (by design, under 0.22):** the elbow ball into the chest bib with
  the forelegs swung +0.95 or more (pounce dash, leap flight); the hock ball into the
  thigh in the deepest coil and the howl sit (0.15 to 0.19); the forearm touches the
  neck by 0.1 at the pounce launch. The modeler's old QA leap pose, run through the same
  check, puts the forepaws 0.27 to 0.4 into the skull, so keep forelegs at or under
  +1.05 with 0.06 to 0.08 of outward roll when the head is level.
- **Gallop:** the hind legs must reach forward less than they drive back (0.65x) and
  roll out 0.22 when forward, or the hind shins enter the hips (0.3) and the hind paws
  hit the forepaws. A spine arch past 0.1 drops the chest onto the reaching hind shins.
- **Circle (crab-trot):** lateral leg roll up to 0.2 around a 0.06 outward stance; at
  0.3 the paws cross and collide.
- **Death:** rolled 1.4 about the hips and shifted 0.55 toward the side it falls to,
  the flank rests on Y 0 at a root drop of 0.95 (measured, not keyed by eye).

### Elder Wolf King B (`EnemyPoses/WolfKing.luau`)

The testbed boss uses the existing King's skeleton, including `JointManeL`,
`JointManeR` and `JointSeal`. It has its own pose module so its heavy gait and
attack tells do not change the Spirit Wolf. Every pose is authored in **unit
wolf space**: `EnemyAnimator` scales root translation by **2.4 once**, after
sampling, and advances gait phases at the scaled stride rate.

The module has the same `moves`, `durations`, `JOINTS`, `sample`, `loops`,
`gaitRate`, `scaled` and `plant` API as `Wolf`. It uses `Quadruped.new` for the
shared two-joint planting and gait solver, with the wolf pivots and the King's
wider, longer paw soles from `build_elder_wolf_king.luau`. Walk and circle use a
four-beat gait with a 72% stance; its stride clock uses that stance fraction when
matching paw travel to root speed. Run uses an asymmetric gallop. Rush strides use
elapsed seconds at 2.2 cycles per second, rather than forcing a fixed number
of strides into a short dash. The seal and manes trail the body in gait curves;
on attacks they hold their windup flare through contact and then swing through.

| Attack attribute | Pose move | Windup | Active | Pose recover | Server recover | Tell |
|---|---|---|---|---|---|---|
| `royalBite` | `RoyalBite` | 0.90 | 0.16 | 0.84 | 1.00 | high head, open jaw, braced forepaws |
| `kingsRush` | `KingsRush` | 1.00 | actual `DashSeconds`, at most 0.60 | 1.00 | 1.00 | low still coil, hind-leg push, gallop, wide skid |
| `crownfall` | `Crownfall` | 1.25 | 0.18 | 1.07 | 1.25 | both forepaws rise; broad ground impact and held squat |
| `pawSwipe` | `PawSwipe` | 0.45 | 0.12 | 0.63 | 0.75 | left shoulder and paw lift outward, then sweep diagonally inward |
| `clawDown` | `ClawDown` | 0.55 | 0.12 | 0.73 | 0.85 | right paw above the lowered head, then a downward drive |
| `packCall` | `PackCall` | 1.20 | 0.10 | 0.90 | 1.00 | all four paws planted, throat up, mane spread |

Stationary attacks reach their contact pose at the **end of windup**: this is
when the server hits and the `strike` cue fires. `active` is visual follow-through
at the beginning of the server's recover; `EnemyAnimator` subtracts it before
playing the pose recover. The two fast paw tells lift their attacking shoulder
immediately, with the other three paws planted. ClawDown's claw-tip target is
King-local `(1.7, 0, -7)`; the module converts it to unit space and accounts for
the toe's offset from the wrist. Crownfall has no airborne root movement: only
the front limbs lift while the rear paws support the body.

`EnemyAnimator` searches boss `def.pattern` for each attack's real timing. For
`ElderWolfKingB` only, it blends from the preceding state's transforms for 0.06 s,
then applies keyed poses directly from `StateAt`, so normal smoothing cannot
delay a fast release past its hit instant. Locomotion keeps normal smoothing.
Stagger (0.28 s) and mirrored death (2.6 s, `deathSeconds`) reuse the shared wolf keys with
King-specific mane and seal follow-through.

**Authored ranges, not newly validated:** the raised forepaws use upper-leg
pitch to 1.25, elbow pitch to 1.10 and compensating wrist pitch to -2.0; the
Crownfall root pitches to 0.32 and its impact drops 0.38 unit studs before
planting. These extend the earlier pose set. No numeric pose QA, Studio preview,
captures or playtests were run for this pass, at the user's instruction. Paw
clearance against the King's larger skull, shoulder pads and mane, the ClawDown
contact, death against the ground, phase blending, phone cost and readability
at 40 studs remain for review. No KeyframeSequences or uploaded clips were made;
the live game currently uses procedural poses.

##### King animation rework (stiffness pass)

Numeric QA: `wolf_family/qa_wolf_king_poses.luau` (King template, poses scaled 2.4x,
every move variant and loop; `_G.WOLF_POSE_ONLY = "ClawDown"` for one move,
`_G.WK_VARIANT = "B"` for one variant). Run one or two moves per `execute_luau` call
(a full run drops the connection). Push edited modules first (`tools/push_src.luau`).

- **Variants.** Each attack has "A" (original) plus "B"/"C" with identical phase
  durations. Switch with `WolfKing.VARIANT.ClawDown = "B"`, `WolfKing.setVariant(move, v)`
  or `WolfKing.setAll(v)` (only moves that have it). Shipped defaults: RoyalBite B
  (haunch-sit hammer), KingsRush B (pawing), Crownfall B (tall rear-up), PackCall B
  (rear-up howl), PawSwipe A, ClawDown A. C: RoyalBite head-whip, PawSwipe stamp-cock
  with tremble, ClawDown hook (draw back first), Crownfall slow squat then late rise,
  KingsRush head-low shudder, PackCall pulsed howl.
- **Secondary motion** (`secondary` in `WolfKing.sample`): neck, head, jaw, ears, crest,
  tail chain, manes and seal each lag the body by their own amount (0.04-0.18 s,
  faded to 0 at every phase boundary so contact is never late), tremble while a
  windup is held, and ring down after impact (SETTLE per move). `weightOverlay` adds
  root breathing, a crunch before contact and an impact dip BEFORE planting, so the
  legs compress with it. Cost: each keyed sample runs the sampler 13 times.
- **Locomotion:** idle breathes (chest leads head), shifts weight over the paws, looks
  about, flicks the tail and ears on separate clocks. Walk holds the head high with
  chest dips on forepaw footfalls and opposed shoulder/hip sway. Run slams the body
  down each footfall; head, ears, tail trail with phase offsets.
- **Death** is 2.6 s (`Family.deathSeconds` in EnemyAnimator): a thrown-back hit held
  u 0.1-0.3 (burst key for the effect), reeling sway, the roll, a bounce, rest. **Roar**
  (aggro) exists as a move (1.0 / 0.1 / 0.8, held rear-up from u 0.5) but nothing plays
  it: EnemyAnimator has no engage attribute. (Since then the `roar` attack, `pack.howl`, plays it.)
- **Gotchas learned:** root YAW or large root roll with planted hind paws breaks the
  planting (the two-joint solve is in the leg's plane only) and merges the hind paw
  into the thigh by 0.6-1.1; keep root yaw under ~0.05 and turn with the spine and
  neck. A raised forepaw at pitch 1.1+ goes through the neck and skull unless rolled
  outward 0.5-0.65 (left negative, right positive). Remaining: the raised lower leg
  still clips ManeL/ManeR (0.6-1.2) and Neck (0.6) in PawSwipe, ClawDown, Crownfall and
  the Rush launch; PawBL/UpperLegBL "merge" of 0.3-0.9 shows in every bent hind pose
  including walk (a rig geometry issue, not a pose one); Crownfall elbows reach 1.34.

##### King run (bounding gallop, replaces the old trot-like gallop)

The old run turned over 0.9-1.0 cycles/s with paws sweeping +-0.6 rad on a 72-100% duty:
hind paws skated at 50-65% of the ground speed (measured), with only a trace of
suspension, so it read as jogging in place. `gallop` now is a rotary four-beat bound
(BL, BR, FL, FR at cycle offsets 0 / 0.1 / 0.5 / 0.6, each paw down 32% of the cycle)
at `0.9 + 0.014 * speed` cycles/s (1.10 at 14, 1.18 at 20: real rate, not divided by
the 2.4 scale). A stance paw is PLANTED through `rig.plantLegs` with a reach that slides
back at exactly the ground speed, so there is no skating by construction; swing paws
reach 20-30% past the touchdown angle, and the body rises (about 0.1 unit) in the
23% flight. Measure with `wolf_family/gait_king.luau` (`_G.GAIT = { loop = "run",
speeds = { 14, 20 } }`): at 9, 14, 20 and 24 studs/s, stance skate means are within
+-2 studs/s, stance paws stay at Y 0 to 0.07, stride 12.8 / 16.9 studs, root bounce
0.9 / 1.3 studs. King's Rush strides use the same gallop at speed 50, rate 2.2.
Known: swing forelegs fold to elbow -1.4 to -1.7, hind knees to 1.7-1.9, and the hind
paw merges 0.5-1.1 into the thigh as both hind legs gather; EnemyAnimator switches
walk to run at 8.5 studs/s (`runFrom`). The King's testbed run speed is now 20.

##### King's Leap, Rake and the skids (boss feel pass, 2026-10-22)

New moves in `WolfKing.luau` for the contract's `kingLeap` -> arrive `kingRake`, miss ->
`kingLeapSkid`, and `kingsRushSkid` (the rush's overshoot). Designed timing (the defs win):
KingLeap windup 1.10 / dash 0.70 (`air`, arc 16) / recover 1.00; KingRake 0.50 / 0.14 / 0.76 (server recover 0.90); the skids
are recovers timed by the parent attack's recover. The server keeps `Attack` = the parent and
puts the skid's name in `AttackName` during the recover (the King skids for any miss; the Spirit Wolf only when the
target ends up more than 60 degrees off its nose); EnemyAnimator has to read `AttackName` for the skid move.

- **KingLeap:** set (u 0.2) and gather into a low coil (root -0.4 unit, hind paws 0.6 back,
  forepaws 0.12 ahead), held from 0.62 with a tremble, a tail-tip twitch and a hip shimmy at
  0.78-0.96. Dash: hind legs drive (still planted) to 0.1, off the ground by 0.2 (hind legs thrown
  back, forelegs folded), the apex stretch at 0.44 and a hang to 0.62 (forelegs reaching, manes
  flared wide), falling by 0.86 (nose down, head up on the target, claws out, tail up), and at 1.0
  the forepaws are planted (they meet Y 0 whatever the arc does at the very end). The slam
  resolves at that touchdown.
- **KingRake** opens on the landing: absorbed by u 0.16 (chest dropped on the forelegs, head
  up, jaw open, mane and seal flung forward), held to 0.34, up onto the right forepaw with the
  left paw cocked high and wide and the chest twisted away by 0.68, raked across at 0.97
  (contact = end of windup), follow-through in the active. A landing ring-down runs in this
  windup (`SETTLE_WINDUP`).
  `kingsRush` also arrives into `kingRake` (same pose): there the landing compression reads as
  the braking plant out of the gallop, blended over the 0.06 s keyed blend. Not checked in play.
- **Skids** (mirror, authored for the target on the right): brace (forepaws 0.5 ahead, chest
  reared back against the slide, hind paws swung 0.2-0.4 out to the outside of the turn),
  scrabble (BL, then BR lifted about 0.4 studs, then the inside forepaw steps round), square up
  by 0.76, stand. The leap skid lands first (LAND_CRUSH by 0.08, the skid from 0.22).
- **Turning:** no pose yaws the root (the server owns it and turns during the crouch, in the air
  or through these skids). `leadOverlay` turns the chest 0.22, neck 0.3 and head 0.2 rad toward
  the live `input.targetYaw` (clamped at 1.4), rolls the head away 0.2, flares the inside mane
  0.5 and lays the crest flat, so the head leads and everything unwinds as the server's yaw lands.
  `WolfKing.LEAD` lists the moves; EnemyAnimator passes `targetYaw` and `side` for any module with
  a `LEAD` table.

Measured (`qa_wolf_king_poses.luau`, scaled 2.4): planted paws at 0, nothing sunk past -0.05 studs
(the bent forearm's edge in the coil and the landing) except the dash's falling frames (u 0.8-0.9,
forepaws up to 0.35 under the virtual floor while the arc still holds the body several studs up).
Clips are at or under the rig's existing levels (KingsRush's launch puts the forearm 0.78 into
the neck): forearm into mane up to 0.52 in the dash, Crest/Mane up to 0.66 in the skids, ear into
mane up to 0.55, plus the PawB/UpperLegB merge (up to 1.0) every bent hind pose already shows.

Learned on this body:
- **Raised or reaching forelegs vs the manes:** folding the manes in (Z toward the neck) makes it
  worse (1.1 at the apex). Flaring them out 0.5 with pitch -0.3 and rolling the forelegs out 0.3
  clears them (0.0), and the flare reads in flight. The same flare clears the rake's paw (0.93 ->
  0.11), so the PawSwipe "fold the mane in" trick isn't used for KingRake.
- **Pinned ears** past about 0.3 put the ears into the manes (0.5-0.8) with the neck low;
  keep 0.2-0.3 in crouches and landings.
- **Crest bristle vs a turning neck:** a neck yaw swings the inside mane into a bristled crest
  (1.3); lay the crest flat (+0.1 to +0.25) and flare the inside mane while the head leads.
- **The King's hind paw needs a deeper fold to lift:** the Spirit Wolf's scrabble angles (hip
  -0.35, knee -0.7) leave the King's bigger paw on the floor clamp; hip +0.3, knee -1.2, hock
  +0.6 lifts it about 0.4 studs.

##### King animation QA (2026-10-22): the steady leg solver

`WolfKing.luau` builds its rig with `Quadruped.new({ ..., steady = true })` (opt-in; Wolf.luau
has its own solver copy and the other Quadruped families don't set it). What it changes, and
why (measured with the motion probe and per-frame joint steps at 60 Hz):
- `solveLeg` (the gait's one-joint solve) always takes the natural-fold bend. The default picks
  the bend nearest the authored angle with a sign penalty, which jumps between the two bends
  when either crosses the threshold: the walk's forepaws flipped 60 deg a frame at every
  touchdown, the gallop's hocks 130.
- A partly planted foot (`0 < plant < 1`, a paw being put down or picked up) is no longer
  blended in joint angles (that swung the paw up to a metre through the floor, and the floor
  clamp then flipped between two equally near bends: 85-160 deg a frame in the swipe, claw,
  rake, crownfall, rush and skids). `stepToward` moves the foot pivot from where the authored
  pose holds it to its spot along a 0.3-unit arc, solves both joints in full, levels the foot
  by the plant weight, eases from a solve on the authored pose's bend side to the planted side
  when they differ, and near weight 0 returns to the authored angles (the in-plane solve can't
  hold a rolled or turned upper leg).
- A fully planted foot gets the two-joint solve and a level, not a second one-joint solve.
- The floor clamp (`raiseLeg`) turns the middle joint the least that lifts a dipping free foot
  back to the ground and turns the foot back by as much, instead of snapping it to rest height.
- Front legs plant with the elbow POSITIVE (lower leg forward: `knee = -1`) but swing folded
  NEGATIVE. Author a paw that lifts and replants (a skid step, a scrape) with a positive elbow,
  or the solve reverses the bend mid-step (the skid's step was 73 deg a frame).
- Not for other families as is: it changes how every transition between plant sets moves
  (the arc, the end blends), so a family that adopts it needs its own probe and pose QA pass.
  Its poses were tuned against the old blend. The gallop still steps up to 60 deg a frame at
  lift-off (stance planted on the knee side, swing on the fold side).

Safe ranges seen clean on the King with it (pose QA, scaled 2.4): a striking forepaw's chest
drop to -0.21 unit with pitch -0.1 (ClawDown; -0.26 pushed the hind paw 0.7 into the thigh and
the forearm 0.1 under the floor); a swipe's rear-up to pitch 0.05 / z 0.04 (0.09 / 0.1 put the
hind paws 0.75 into the thighs); neck yaw at contact to 0.07 (0.14 swung the inside mane 0.45
into the crest); howl and roar head-back to neck 0.48 / head 0.32 (0.52 / 0.36 put the crest
into the skull). Planted root yaw stays under 0.05 (above).
## Spirit Wolf B skids (`Wolf.luau`)

`PounceSkid` (recover 0.9, out of the pounce's airborne stretch) and `LeapSkid` (recover 1.1,
lands squashed first): the same brace, scrabble, step and square-up as the King's skids, mirror,
with the chest, neck and head leading the live `targetYaw` (`Wolf.LEAD`). Attack names
`pounceSkid` / `leapSkid` (the server's `<attack>Skid` for an overshoot). Measured
(`qa_wolf_poses.luau`, which now falls back to `ServerStorage.Enemies.SpiritWolfB` when there is
no `_StagingEnemies`, as in a sandbox): planted paws at 0, nothing sunk, lifted paws 0.23-0.25
(forepaw step 0.08), only the known merges (elbow ball into the chest bib 0.22, hock into thigh
0.22). The howl pose is unchanged (its ring is removed elsewhere; the `howl` cue carries the new
effect).
