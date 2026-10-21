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
