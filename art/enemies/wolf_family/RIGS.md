# Wolf family rigs: animator notes

Spirit Wolf B (`ServerStorage.Enemies.SpiritWolfB`), Elder Wolf King B
(`ServerStorage.Enemies.ElderWolfKingB`, from the `_RosterWolves.ElderWolfKing`
body) and Shadow-Mane Wolf (`ServerStorage._RosterWolves`). All three share one skeleton: the same
joint names, hierarchy and pivots, the King at 2.4x and the Shadow-Mane at 1.15x the
Spirit Wolf. A clip made on one plays on the others as long as it only keys the shared
joints, and the extras are named so they don't clash.

Built by `spirit_wolf_b/build_spirit_wolf_b.luau` + `spirit_wolf/rig_wolf.luau` and
`wolf_family/run_all.luau` (build + `rig_wolf_family.luau`). Re-running them rebuilds the
template, so make animations in a copy, never by hand edits on the template.

## Opening the rig

- Humanoid (RigType R15, a custom rig) with an Animator. HumanoidRootPart is the root
  and the PrimaryPart, unanchored in the template. Anchor the HRP of your working copy
  in Moon Animator 2 or the Animation Editor.
- Exactly one Motor6D leaves the HRP: `JointRoot` to `Hips`. Everything else hangs from it.
- Clips key poses by **part name** (Part1), not by motor name. Every Part1 is unique.
- Every part except the segments is a welded detail (WeldConstraint to its segment). You
  can't key a detail; it rides its segment.

## Axes and signs (the same on every joint)

Every joint frame has identity rotation in model space at rest. The wolf faces -Z; its
left is -X. So, for a rotation `CFrame.Angles(x, y, z)` on any joint:

- **+X (pitch)**: the front of the part tips up. Head and neck: nose up. Legs: the foot
  swings forward. Tail: the tail tip drops. Ears: tips pinned back. Jaw: **negative X
  opens the mouth.** Crest/Mane (dorsal): +X lays it flat, -X bristles it up.
- **+Y (yaw)**: turns to the wolf's left. Tail: the tip swings to the wolf's right.
- **+Z (roll)**: tops lean to the wolf's left. Left-side flaps (EarL, ManeL): -Z flares
  them up and out, +Z droops them. Right side (EarR, ManeR): +Z flares, -Z droops.

## Shared joints (all three)

| Motor6D | Moves (Part1) | Parent (Part0) | Hinge | Notes |
|---|---|---|---|---|
| JointRoot | Hips | HumanoidRootPart | over the hips | whole-body bob, crouch (translate Y), lunge pitch |
| JointSpine | Chest | Hips | waist | arch or hunch, ~±0.2 rad |
| JointNeck | Neck | Chest | base of the neck | |
| JointHead | Skull | Neck | back of the skull | EnemyAnimator drives this one |
| JointJaw | Jaw | Skull | jaw hinge under the ear | -X opens; up to -0.8 reads as a roar |
| JointEarL / JointEarR | EarL / EarR | Skull | ear base | +X pins back |
| JointLegFL / FR | UpperLegFL / FR | Chest | shoulder | EnemyAnimator drives these |
| JointElbowFL / FR | LowerLegFL / FR | UpperLeg | elbow | negative X folds the forearm back |
| JointWristFL / FR | PawFL / FR | LowerLeg | wrist | |
| JointLegBL / BR | UpperLegBL / BR | Hips | hip | EnemyAnimator drives these |
| JointKneeBL / BR | LowerLegBL / BR | UpperLeg | knee | positive X bends the shin forward (crouch) |
| JointHockBL / BR | PawBL / BR | LowerLeg | hock | negative X with a bent knee keeps the foot flat |
| JointTail | TailBase | Hips | tail root | EnemyAnimator drives this |
| JointTail2 | TailMid | TailBase | | |
| JointTail3 | TailTip | TailMid | | the brush on the King and Shadow-Mane rides this |

## Extras per body

| Body | Motor6D | Moves (Part1) | Parent | Notes |
|---|---|---|---|---|
| Spirit Wolf B | JointCrest | Crest (the dorsal spikes) | Chest | -X bristles for a windup |
| Elder Wolf King | JointCrest | Crest (silver dorsal blades) | Chest | -X bristles |
| Elder Wolf King | JointManeL / JointManeR | ManeL / ManeR (each side's mane blades) | Neck | sway with Y, flare with Z (signs above) |
| Elder Wolf King | JointSeal | Seal (the jade seal and its ring) | Neck | hinged at the collar; X swings it fore and aft. The Seal is a Neon tell |
| Shadow-Mane | JointMane | Mane (dorsal mane and shoulder drapes) | Chest | -X lifts it, +X streams it back |
| Shadow-Mane | JointManeL / JointManeR | ManeL / ManeR (each side's neck strands) | Neck | sway and flare like the King's |
| Shadow-Mane | JointForelock | Forelock | Skull | -X lifts it |

## Spirit Wolf B: tells and FX attachments

Combat pass (2026-10-21). Joints, names and axes are unchanged; the body is 90 parts
(89 + the HRP).

| Tell part | Segment (rides) | Notes |
|---|---|---|
| EyeL / EyeR | Skull | red Neon, `Tell = true` |
| TellCrest1 / TellCrest2 / TellCrest3 | Crest (JointCrest) | Neon caps down the leading edges of the three big crest spikes (Crest1, Crest, Crest3), dim slate-blue `#3A4A66` at rest; the client FX brightens them on windups. They sit a little wider than each spike, so the edge reads as a line side-on too. Bristling the crest (-X on JointCrest) tips them up toward the camera |

Empty FX attachments (identity world rotation at rest, so they turn with their part):

| Attachment | Parent part | Model-space position | For |
|---|---|---|---|
| Mouth | Skull | (0, 2.7, -4.9), the muzzle tip between the lips | breath, bite, howl. It rides the Skull, not the Jaw, so it stays put when the jaw opens |
| Core | Chest | (0, 2.55, -0.5), the Chest centre | auras, hit flashes |
| PawBL_FX / PawBR_FX | PawBL / PawBR | (-0.75, 0, 1.95) / (0.75, 0, 1.95), on the ground under each hind foot | stomps, dust on the pounce |

## Things to know

- **Pose modules own their named joints every frame.** EnemyAnimator selects them by
  the live enemy's `Template`: `SpiritWolfB` uses `Wolf.luau`; `ElderWolfKingB` uses
  `WolfKing.luau`. Each module's `JOINTS` list includes the root, spine, neck, jaw,
  ears, complete legs and tail chain; the King adds both manes and the seal. A clip
  played alongside the poser would fight it on those joints. Bodies without a
  registered module still use only the generic head, tail and upper-leg pose.
- **Tested ranges** (no gaps, nothing separates): legs ±0.85 rad at the shoulder and hip,
  elbows and knees ±0.8, a 0.6-stud crouch on JointRoot, the jaw to -0.8, the neck and
  head to 0.35 yaw, the tail chain to 0.6 each, and a full leap stretch (forelegs +1.2,
  hind legs -1.0). The hind thighs have a rounded haunch on the hip axis, so they swing
  cleanly at any angle; the forelegs' block tops sit inside the chest.
- The King's scale is 2.4x: translations on JointRoot are in studs, so scale them up
  (a 0.5 crouch on the Spirit Wolf is 1.2 on the King). Rotations transfer unchanged.
- Tell parts (the Spirit Wolf's eyes and crest edges, the King's brow mark, collar jade
  and seal) carry the `Tell` attribute; they flare in the client FX, not through the clip.
- The Spirit Wolf B's back is a cylinder over the chest and over the hips (no shoulder
  bevels any more), and it has no shoulder balls, hind claws, small teeth, chin block or
  leg tufts: none of those were keyable, so no clip keyed them.

## Procedural poses (`src/client/EnemyPoses/Wolf.luau`)

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
elapsed seconds at three cycles per second, rather than forcing a fixed number
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
Stagger (0.28 s) and mirrored death (0.60 s) reuse the shared wolf keys with
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

#### King animation rework (stiffness pass)

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
  it: EnemyAnimator has no engage attribute.
- **Gotchas learned:** root YAW or large root roll with planted hind paws breaks the
  planting (the two-joint solve is in the leg's plane only) and merges the hind paw
  into the thigh by 0.6-1.1; keep root yaw under ~0.05 and turn with the spine and
  neck. A raised forepaw at pitch 1.1+ goes through the neck and skull unless rolled
  outward 0.5-0.65 (left negative, right positive). Remaining: the raised lower leg
  still clips ManeL/ManeR (0.6-1.2) and Neck (0.6) in PawSwipe, ClawDown, Crownfall and
  the Rush launch; PawBL/UpperLegBL "merge" of 0.3-0.9 shows in every bent hind pose
  including walk (a rig geometry issue, not a pose one); Crownfall elbows reach 1.34.

#### King run (bounding gallop, replaces the old trot-like gallop)

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

#### King's Leap, Rake and the skids (boss feel pass, 2026-10-22)

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

## ShadowManeWolfB (the user's reference body, 1.63x, brought in 2026-10-22)

`assets/Enemies.rbxm` template `ShadowManeWolfB`: the user's `ShadowManeWolf` kept as it looks, 6.5 x 9.1 x 21.3 studs, 106 parts, 26 motors (the shared skeleton plus JointMane, JointManeL/R and JointForelock; hocks `JointHockBL/BR` have a rotated frame at rest). Built by `art/enemies/beasts/bring_in_wave1.luau`. Attribute `Scale = 1.63` (the source carried a stale 1.15). `Wolf.scaled` multiplies JointRoot's translation by 1.63 once.

- Pivot, root: the pivot is the `HumanoidRootPart` (identity rotation, Y 4.866 = root height, feet on Y 0). The root is 6.53 x 8.42 x 21.25, centred on the body's X/Z bounds; the hips' `JointRoot` is at root-relative (0, 0.47, +2.16).
- Mouth is 10.48 studs in front of the root centre (Z -10.48, 5.15 up from the ground).
- Rest pivots root-relative (X, Y up from the root, Z): JointSpine (0, 0.75, 0.66); JointNeck (0, 1.03, -4.11); JointHead (0, 1.03, -6.17); JointMane (0, 2.15, -3.08); JointLegFL/FR (+-1.31, -0.28, -3.27); JointLegBL/BR (+-1.31, -0.19, 3.09). Ground-up: legs hip 4.59 / 4.68, elbow and knee 2.53, wrist 0.60, hock 1.16.
- Tells (Neon violet): `EyeL`, `EyeR`, and new thin bands `ManeTell1..3` (across the three dorsal mane wedges, Segment Mane) and `TailBrushTell` (across the brush, Segment TailTip), all with `TellBase`.
- Attachments: `Mouth` (Skull), `Core` (Chest), `PawFL_FX`, `PawFR_FX`, `PawBL_FX`, `PawBR_FX` (on each paw, at Y 0), `ManeTop_FX` (Mane, top of the mane, 8.50 up).
- `HealthBar` 1 stud over the top. check_rig clean, keyframe_test keyable (26 joints).
