# Thunder Ape B (boss, 23 joints, 139 parts, 3.71x)

Part of [beasts/RIGS.md](../RIGS.md): read that file's shared rules first.


Template `ThunderApeB` (`build_thunder_ape.luau` then `rig_thunder_ape.luau`, 3.71x of the
Thunder Ape above (the size of the user's reference row), model attribute `Scale = 3.71`). The 18 joints above are unchanged in
name, parent, sign and unit-space pivot. **Pose in unit space (scale 1); the template is
already scaled, and every pivot below x 3.71 is the real one** (the `JointPivot` attributes on
the segments are the scaled values). Hump about 25 studs, tallest crest tuft 30.7; bbox 30.2 x 30.7 x 23.9.
HRP 14.84 x 14.84 x 16.32 centred at Y 11.87, HipHeight 4.45, HealthBar offset 20.8 over the HRP.

New joints (identity rotation at rest, pivots in unit space before scaling):

| Joint | Moves (Part1) | Parent | Pivot | Sign |
|---|---|---|---|---|
| JointMane1 | Mane1 (front tuft, plus its two side tufts and base) | Chest | (0, 7.17, -0.47) | +X leans it back, -X forward |
| JointMane2 | Mane2 (middle, tallest) | Chest | (0, 6.90, 0.39) | same |
| JointMane3 | Mane3 (rear tuft) | Chest | (0, 6.64, 1.25) | same |
| JointBrow | Brow (shelf, ridge, two side wings) | Skull | (0, 6.40, -2.65) | +X lifts the brow's front (raised, surprised), -X drops it over the eyes (rage). Small angles (about 0.25 max) |
| JointBeard | Beard (main wedge, two side tufts, tip) | Jaw | (0, 5.15, -2.70) | +X swings the hanging beard forward, -X back. It follows the jaw, so add on top of the jaw's own swing |

The head sits 0.45 higher than the old ape (skull centre Y 5.9; JointHead pivot unchanged
at (0, 5.6, -1.6)), so the chest drum shows under the beard. The brow is no longer a Skull
detail and the old Beard detail is now a segment, so keys on `Skull`/`Jaw` carry neither.
The crest tufts are no longer Chest details (`Crest*` parts are gone; `Mane*` replace
them). Mane segments lean back by default at rest (the wedge's own pitch), so 0 is
the rest tilt.

Knuckle plates (`KnucklePlateL/R`, spikes, studs, cracks) ride the **Fingers** segments, so
they open with `JointFingersFL/FR`.

Tells (Neon, `Tell = true`; `TellBase` = the original colour, 5BD8FF): `EyeL/R`, `ChestSigil1` (ring), `ChestSigil2` (boss), `ChestSigil3..5`
(three bolts across the drum), `ChestBoltL1..3` / `ChestBoltR1..3` (beside the head),
`ForeArmFLBolt1..3` / `ForeArmFRBolt1..3`, `KnuckleL1..3` / `KnuckleR1..3` (on the plates),
`BackBolt1..3` (down the back under the crest). `ChestSigilDisc` (dark) is not a tell.

Attachment hooks (Y up at rest; positions in unit space, world, at rest):

| Hook | On | Position |
|---|---|---|
| Core | Chest | (0, 4.86, -1.97): drum centre, front face |
| Mouth | Skull | (0, 5.40, -3.25) |
| FistL_FX / FistR_FX | HandFL / HandFR | (-/+2.6, 0, -2.6): ground under the knuckle line |
| FootBL_FX / FootBR_FX | FootBL / FootBR | (-/+1.4, 0, 1.9): under the heel |
| BackTop | Chest | (0, 7.02, 0.53): top of the hump |
| ShoulderL_FX / ShoulderR_FX | UpperArmFL / FR | (-/+2.2, 6.5, -0.8) |
| ChestBeatL_FX / ChestBeatR_FX | Chest | (-/+0.85, 4.99, -1.88): where the fists land on a beat |

Hooks ride their segment, so they move with it when posed (FistX_FX leaves the ground when
the fist lifts). Beating: the arms are the front legs, so a beat is the shoulders swung in
(+X up and forward) with the elbows bent so the fists meet the chest at the drum.
## Thunder Ape B poses (`src/client/EnemyPoses/ThunderApe.luau`)

Procedural pose module, same API as `WolfKing.luau` (`sample`, `moves`, `durations`, `loops`,
`JOINTS` (the 23), `gaitRate`, `scaled`, `plant`, `VARIANTS`, `VARIANT`, `setVariant`,
`setAll`) plus `.BEATS` and `.SCALE`. It poses in unit space; **register it with
`scale = 3.71`** (the gait loops divide speeds by `ThunderApe.SCALE` themselves, and
`scaled()` multiplies the root translation). Built on `Quadruped.new`: the arms are the "front
legs" (shoulder, elbow, wrist = the fist, `fold = +1`, `knee = -1`), the legs the hind ones.
Checks: `gait_ape.luau` (skate per limb), `qa_thunder_ape_poses.luau` (sunk, gaps, clipping,
ranges per key), `contacts_ape.luau` (fists against the areas, chest beats against
`ChestBeat*_FX`), `continuity_ape.luau` (phase-boundary jumps and per-frame pops). Run in a
sandbox after `tools/push_src.luau`; `_G.APE_ONLY`, `_G.APE_KEYS`, `_G.APE_BRIEF` limit the QA.

Variants (identical phase lengths, contact stays at the end of the windup). Default in bold.

| Move | Variants |
|---|---|
| ClubSwing | **A** overhead club (arm over the head, diagonal sweep), B low hook (wide crouch, flat sweep), C corkscrew spin |
| ThunderPound | A tall rise, **B** tallest rear-up with a hang at the top, C spring-slam (leaves the ground) |
| BodySlam | A rear up and tip, B shorter lunge, **C** chest beat at the top, then the fall |
| SkyfallSlam | A crouch and spring, B twisting spring, **C** long coil, fists dug in, shaking |
| StormCall | **A** arms in a V, B alternating pumps, C wide fists clenched, leaning far back |

Gotchas found while building it:
- **Arms are exactly straight at rest** (reach 4.44, vertical drop 4.35), so a planted arm has no
  slack: root pitch above 0 raises the shoulders and the solver drops the whole body
  (pitch 0.2 costs 0.7 unit). Rear-ups (pitch above about 0.3) plant HIND only; a crouch with
  fists planted wants pitch about 0 and the fists forward (y -1.1 needs `fz` about -1.2 for an
  elbow of 1.1; nose-down pitch folds the elbow past 2 rad and sinks the forearm).
- A planted fist follows the shoulder when the torso twists (`support()` in K adds the shoulder's
  shift to the reach); without it a 0.8 rad twist drops the body 1.5 units.
- Quadruped.samplePhase blends plant WEIGHTS and a half-weight two-joint solve overshoots (an
  elbow flipped 1.5 rad in one frame). `plantedSample` solves both ends of a key pair with their
  own plants and blends the solved poses. Between two keys that are both planted it is a live solve.
- Arm lag (elbow, wrist, fingers) is only for follow-through (not windups, so beats and peaks hit
  their marks) and only on arms that are free through the whole key pair.
- Gait floor clamp off (`plantLegs(.., air = true)`): its re-solve flipped a nearly straight swing
  knee for one frame at 4 studs/s walk (1.96 rad).
- Euler angles of a blended shoulder read as jumps near +-pi/2; compare with axis-angle.
- The beard rides the jaw and head: `mk` adds `0.6 * jaw` and `-0.6 * min(0, head)` to it so it
  clears the chest drum.
- Chest beat arm (solved offline, torso-relative so it works at any rear-up): upper arm along the
  torso (+0.19), out +0.06, yaw -0.8, elbow 1.78, wrist 1.65 puts the fist centre 4 studs off the
  hook along the plate normal (measured 2.5 to 4 studs from `ChestBeat*_FX` at each beat time).
- Safe ranges seen: shoulder -0.7 to 3.5 world pitch (overhead about 3.0), elbow up to 1.9 planted
  (clips are small up to 2.2), hind knee -1.4, jaw 0 to 1.05, brow +-0.25, beard +-0.4.
- Forearms and fists clip the beard in every chest-high sweep and chest beat (1 to 3 studs deep on
  a 28 stud body); thighs dip 0.5 to 1.8 studs into the ground in the deepest Judgment crouch.

Animation pass 2 (partial, see the commit; the per-move rework is unfinished):
- Timings live in `TIMING` (one line per move, the def's `122e93b` values; keys are fractions so a
  def change is a one-line change). `BOULDER_RELEASE = 1.25`: the right fist sits about 3.6 studs
  from the server's spawn point (root + (7, 14, -2)) at that frame.
- Gait touchdowns: three causes of the 0.6-0.8 rad pops, all fixed in `finishGait`. (1) The root
  drop jumped when the limiting limb entered or left stance: each limb's weight now ramps over the
  first and last 35% of its stance. (2) The swing's end angles came from a lookup built with the
  body level, so they missed the stance solve whenever the body pitched or rolled (circle 0.36 rad):
  a swing limb now blends into the live planted solve over its last 60% and out of it over its
  first 40%. (3) Near full extension a planted elbow is hypersensitive (a 0.05 unit rise of the
  shoulder swung it 0.25 rad): stance limbs never stretch past 0.985 of their length, the fist lifts
  off instead (`STRETCH`, via the new `rig.reachShort(.., stretch)` and `plantLegs(.., noDrop)`).
  Gallop spikes 0.53-0.64 -> 0.24-0.32 (what is left is the fist's stop at touchdown), walk 0.25
  -> 0.08-0.14, circle 0.36-0.49 -> 0.15 (and 0.02-0.09 the other way).
- `continuity_ape.luau` now reports SPIKES (a joint's step on one frame minus the mean of its
  neighbours' steps), not the raw step: a fast swing is not a pop. It also runs the circle both ways.
- The inOut ease is a sine in this module (peak speed 1.6x the mean, not the cubic's 3x).
- Free-arm follow-through is read off the planted pose a moment earlier and weighted by how free
  the arm is (it popped 0.6 rad at recover starts when an arm changed plant); it now also runs in
  windups except the roars and the boulder throw. The tufts, beard, brow and head drift on the wall
  clock in every keyed move and the chest breathes before planting, so no held pose is frozen.
- Chest beat arm solved against the rig with no clipping (torso-relative, with the head at +0.1):
  upper arm 0.19 behind the torso line, out 1.22, yaw -0.48, elbow 1.83, wrist 1.15. The current
  `hitArm` clips the jaw and skull 2.5 studs; swap it in with the roar rework.
- Thunder Lance throw arm solved toward the spawn point (16 ahead, 3.5 up): world pitch -0.07,
  out 0.56, yaw 0.58, elbow 1.53, wrist 1.2 with the root at (-0.45, -0.02, yaw 0.1) misses by 1.5.

Feel pass (2026-10-22, arrivals, skids, bound modes, landings):
- New moves: `RushSwipe`, `SkyfallSweep` (arrivals, stationary contact at the end of the
  windup), `ThunderRushSkid`, `SkyfallSlamSkid` (recover only; variant `L` turns left, picked by
  `input.side < 0`; `ThunderRush`'s own recover is the same skid). `Bound` has variants `flank`
  (default), `over`, `back`, `short`, picked by `input.mode` (the server's `BoundMode`).
- `motionLayer` (in `blendKeys`, before planting): the spine (0.55), head (0.6) and hips (-0.2) take
  `clamp(yawRate * 0.12, +-0.4) * phase.lead` (lead 0.6 by default, 1.6 in bound flights), and a
  phase with `lean` rolls the root toward `input.vel` (and loads the far side in the windup when
  `BoundSide` is sent). EnemyAnimator passes `yawRate`, `vel`, `mode`, `boundSide` for families with
  `motion = true`. QA scripts don't pass them: probe them by hand (a 4 rad/s turn in a planted windup
  costs about 0.5 studs of thigh sink, within range).
- **Lifted landing key** (`lifted(reach, y, tags)`): plant the landing limbs a moment before touchdown
  with their spots raised by y, then the contact key at y 0. Gotcha: `plantLegs` re-solves a planted
  middle joint onto the ground, so a raised spot only aims the limb; `liftPlanted` re-runs
  `rig.solveLeg` with `clear = y` (and a little curl) so the limb really reaches for the ground.
- Gotcha: a planted leg solved nearly straight (knee near 0) flips solver branch for a frame (a 1.2
  rad knee pop on the `over` landing). Keep the pre-landing root low enough (-0.3 unit) that the
  knees stay bent.
- Gotcha: an arm that lifts off in a windup and is then whipped by the free-arm lag reads the planted
  wrist for 0.1 s, then snaps (1 rad). Lift the fist planted-and-raised first, and list the move in
  `EXACT_ARMS`.
- Gotcha: root yaw past about 0.6 with the hind feet planted sinks the shins up to 0.9 studs (the
  leg plane no longer contains the foot spot). Put sweep twist in the spine (support() follows it).
- Hind feet under the hips (hz 0.15-0.2) in the deep landing crouches: the thighs no longer sink
  (they sank 0.6 at hz 0.5 with the root at -1.1).
- Safe ranges seen: head yaw 0.5 with the spine at 0.4 the other way; spine yaw 0.65 planted; root
  yaw 0.55 planted. The rush's gallop at 95 studs/s is averaged over three frames (a fist touchdown
  popped an elbow 0.6 rad in one frame).

Motion QA (2026-10-22, `art/enemies/motion_probe.luau`: every move played as EnemyAnimator plays it,
per-frame FK on the template; the static checks above missed all of these):
- **A plant change between two keys** (`plantedSample`, the cross-plant blend). Each end's root drop
  now counts a limb planted at one end only by how near that end is (a rear-up from all fours
  dropped the root for the planted arms of the pitched torso and sank the thighs 2.5-3.2 studs),
  the limbs planted at both ends are re-planted after the blend, and a changing limb that would dip
  under the floor bends its middle joint only (the solver's foot levelling snapped a wrist 88
  degrees). No floor clamp at either end any more: it re-solved a free arm passing near the ground
  onto its other bend.
- **Gotcha: a free arm blended toward a planted one swings through the ground.** The knuckle-walk
  arm plants with the shoulder back (-0.5 to -0.9) and the elbow bent (1.1-1.7); a free arm is
  authored forward. The joint blend passes through "straight down" and the fist went 6.8 studs under
  in the combo's recovers. Fold the free arm first (elbow 1.7, shoulder near 0 world), then a
  planted key with its spot raised (`lifted`), and give that key an authored elbow near the planted
  solve's (the solver takes the bend nearest the authored one; a blend from 1.7 toward 0 crossed
  between its two bends).
- **Arm lag** reads at most a quarter of the phase back (it read 0.17 s back in a 0.33 s recover and
  held the forearm straight while the shoulder swung) and fades out while the arm reaches down to
  plant (weight cubed, and gone by 35% of a planting key pair).
- `splitOut(h, total)` splits one decelerating sweep across a phase boundary (the club's contact ->
  overshoot runs 0.26 s across its 0.12 s active beat), so the fist keeps moving through the hit.
  A key at u 0.97 holding the contact pose to 1 is a dead frame at the release; key contact at 1.
- A hop landing with the fists still reaching (raised 0.15-0.9) flipped the planted elbow 50-85
  degrees in the recover's first frames once `seamless` stopped blending over it: land them together.
- Free hind legs hanging straight from dropped hips go under the floor (the body slam's fall and
  prone slide, 1.3-2.2 studs): fold the knees (-0.5 to -0.9) whenever the hips drop with the feet up.
- Safe: kneeling sag root -1.0 with HIND planted at R_REAR (-1.4 put the shins 3.4 studs under).
- Still under the floor at the prone and pound contacts: elbow tufts and the beard tip 1.3-1.8
  studs (lying on the ground), the pound's forearms 1.3-1.6.
