# Jade Jiao (boss, 37 joints, `build_jade_jiao.luau` / `rig_jade_jiao.luau`)

Part of [beasts/RIGS.md](../RIGS.md): read that file's shared rules first.


Template `JadeJiao`. **The body is the user's approved reference snake, part for part**:
`workspace.Folder.Model.JadePython` in the testbed place (the roster Jade Python ScaleTo'd
3.1746x), serialized read-only into `jade_python_ref.rbxm.b64` next to the build. The build
moves it into model space, splits its neck and tail tubes into the extra jointed pieces the
fight needs (cut square to each straight bone, every cut piece overlapping its neighbour by
1.11 studs like the reference's own joints), and adds the fight's extras hidden at rest.
`match_jade_jiao.luau` proves the rest look: every sampled point of the reference lies in a
Jiao part of the same colour and the other way round (0 misses of 175k / 206k), and every
point of the hood, fangs and tongue lies inside the reference's volume. Model attribute
`Scale = 3.175` (informational; the body is at full size, no further scaling). 220 parts.

**All numbers below are real studs in model space** (ground Y = 0, faces -Z, left is -X,
origin at the roster python's origin). No K factor any more: the old contract-unit numbers
(and `K = 3.17 / 1.9`) belong to the previous body and don't apply.

**Rest pose = the reference's**: the Body lies on the ground diagonally under the neck
(back end at x +6, right of the neck), the tail coils on the ground round the right, behind
and the left, ending in front-left of the body (tip at (-3.9, 1.0, -7.0)); the neck rises
in a strike S and holds the head level. **The tail segments do not point along +Z at rest**:
every joint frame is still identity in model space, but each segment's rest heading differs
(see the pivots), so a pose solver that sets absolute orientations must compose with each
segment's rest direction (rest bone = next pivot - this pivot).

HRP (the only anchored part, PrimaryPart, identity): **24.7 x 9.525 x 26.3 at (0, 6.35,
5.65)**, bottom 1.59 above the ground (Humanoid HipHeight 1.59), so the root height is 6.35.
It keeps the reference's height band and is widened to cover the coil's footprint (Body and
Tail parts, x -12.3..12.3, z -7.5..18.8). Model pivot = the HRP. HealthBar 13.26 over the HRP
centre (1 stud over the body's top at 18.61). Bounding box of the visible body 24.3 x 18.6
x 37.7 (the reference's).

| Joint | Moves (Part1) | Parent | Pivot (studs) | Notes |
|---|---|---|---|---|
| JointRoot | Body | HRP | (3.02, 3.25, -1.43) | the ground segment under the neck; bone (6.03, 3.17, 1.27) -> (0, 3.33, -4.13), 8.10 long |
| JointNeck | Neck1 | Body | (0, 3.33, -4.13) | lower half of the reference Neck1, rises forward |
| JointNeck2 | Neck2 | Neck1 | (0, 5.32, -6.83) | upper half of the reference Neck1 (new cut) |
| JointNeck3 | Neck3 | Neck2 | (0, 7.30, -9.52) | reference Neck2: the S's back-rising limb |
| JointNeck4 | Neck4 | Neck3 | (0, 11.11, -5.87) | reference Neck3: rises forward to the head; carries the hood |
| JointNeck5 | Neck5 | Neck4 | (0, 13.81, -9.37) | reference Neck4: short, nearly level, under the head |
| JointHead | Skull | Neck5 | (0, 14.60, -11.59) | horns, brow pearl, upper teeth, eyes ride the Skull |
| JointJaw | Jaw | Skull | (0, 13.15, -12.15) | -X opens; the ThroatSac rides the jaw |
| JointFangL/R | FangL/R | Skull | (-+0.85, 13.75, -18.53) | folded back (tip +Z) inside the snout block at rest; +X swings the tip down out through the lip (1.45 rad = down and a little forward, clear of the closed lip only once the jaw opens) |
| JointHoodL/R | HoodL/R | Neck4 | (-+2.05, 13.54, -10.13) | panels 5.0 long x 2.8 tall folded inside Neck4's core block along its sides, hinged at the head end; flare L -Y, R +Y (1.2 rad tested) turns the jade face and eye-spot to the front |
| JointBarbelL1/R1 | BarbelL1/R1 | Skull | (-+1.80, 13.67, -18.23) | at the snout's lower corners, droop back under the jaw line; **invisible until phase 3** (`PhaseReveal 3`) |
| JointBarbelL2/R2 | BarbelL2/R2 | Barbel*1 | (-+2.90, 12.67, -16.73) | second link; `P3BarbelL/R` ride it (also phase 3) |
| JointTongue | Tongue | Jaw | (0, 12.89, -12.89) | flat inside the jaw blocks under the mouth floor, 3.6 long forward; it has to lift above the jaw floor to show (jaw open, then -X/+X per taste; check against the jaw) |
| JointTongueTipL/R | TongueTipL/R | Tongue | (0, 12.71, -16.49) | fork, yaw -+0.4 at rest |
| JointTail | Tail1 | Body | (6.03, 3.17, 1.27) | reference Tail1, first half |
| JointTail2..18 | Tail2..18 | previous Tail | below | |

Tail pivots (Tail_i's pivot; the next one ends it): Tail2 (7.30, 3.10, 4.44), Tail3 (8.57,
3.02, 7.62), Tail4 (6.98, 2.94, 10.63), Tail5 (5.40, 2.86, 13.65), Tail6 (2.96, 2.77, 14.39),
Tail7 (0.53, 2.69, 15.13), Tail8 (-1.90, 2.60, 15.87), Tail9 (-4.02, 2.50, 14.81), Tail10
(-6.14, 2.39, 13.76), Tail11 (-8.25, 2.29, 12.70), Tail12 (-8.89, 2.16, 10.58), Tail13 (-9.52,
2.03, 8.47), Tail14 (-10.16, 1.90, 6.35), Tail15 (-9.63, 1.78, 4.23), Tail16 (-9.10, 1.65,
2.12), Tail17 (-8.57, 1.52, 0.00), Tail18 (-6.98, 1.33, -2.38); bone end (-5.38, 1.14, -4.77),
TailTipGem point (-3.90, 0.96, -7.00).

Lengths (bone, pivot to pivot):

- Neck1-5: 3.35, 3.34, 5.28, 4.42, 2.36 (18.75 from the ground to the head pivot).
- Body: 8.10.
- Tail1-4: 3.42 each. Tail5-7: 2.54. Tail8-10: 2.37. Tail11-13: 2.21. Tail14-16: 2.19.
  Tail17-18: 2.87. That's 47.3 to the last bone end, 50.0 to the tip gem.
- Whole spine, tip to head pivot: 76.9.

Each reference tail segment became 2-3 straight pieces (ref Tail1 -> 1-2, Tail2 -> 3-4,
Tail3 -> 5-7, Tail4 -> 8-10, Tail5 -> 11-13, Tail6 -> 14-16, Tail7 -> 17-18), so the rest bends
sit only at Tail3, 5, 8, 11, 14 and 17 (the reference's joints). Widths taper with the
reference: Body 6.7, Tail1-2 6.4, Tail3-4 5.9, Tail5-7 5.2, Tail8-10 4.6, Tail11-13 3.8,
Tail14-16 3.0, Tail17-18 2.2 (core width; the belly plate is 0.2 wider). The pivots sit on the
bone, about half the tube height above the ground: 3.2 at Tail1 falling to 1.3 at Tail18.

Rest heights: head pivot 14.60, skull centre 14.89 (old body: about 16.8), top of the horns
18.61, snout tip z -18.88 (the head reaches 18.9 ahead of the model origin, 24.5 ahead of the
HRP centre). Mouth attachment (0, 13.12, -18.51).

**Coil check** (`preview_jade_jiao.luau`, Body fixed, Tail1..18 laid on one constant-curvature
curve from Tail1's rest heading): no new contacts between non-adjacent segments at radius 9
and up; at 8 the tip (Tail16-18) reaches the Body and Tail1 (the curve closes on itself:
50 studs of tail is a full turn at radius 8); at 7 and below the tail overlaps its own first
half. Tail5-7 and Tail8-10 touch at every radius (pieces of one reference segment, the scute
on the middle piece meets the outer piece's padding; harmless). Pairs that already touch at
rest (i, i+2 within the reference's padded tubes) are excluded. A 280-degree ring of the
Body and the whole tail (58 studs) has a centreline radius of about 11.9; the Body and
Tail1..12 (40.9 studs) about 8.4.

Hooks (attachments): Mouth (Skull, under the snout tip), FangL_FX/FangR_FX (fang tips),
Throat (ThroatSac, under the jaw), Core (Body, 0.5 over its top at (3.0, 5.0, -1.4)),
Dive_FX (Body, the ground under the neck base, (0, 0, -4.13)), Ground_Body (ground under the
Body centre), Ground_Tail4/9/14 (ground under the segment middle), Coil_Tail3/6/9/12 (the
segment's belly height under its middle), TailTip_FX (Tail18, the tip gem point),
HoodL_FX/HoodR_FX (the eye-spots).

Tells (`Tell`, `TellBase`): EyeL/R, EyeSideL/R, BrowPearl, VeinGem2/3 (Neon, the
reference's), FangTipL/R and HoodSpotL/R (Neon, hidden at rest), and these reference parts
renamed so the fight's tells land on the approved look, **SmoothPlastic, coloured as before**
(tellRun lerps their colour, so they light without glowing at rest): ThroatSac (the
reference's cream `Throat` plate on the Jaw; the windup swell scales this block),
ScaleSeam1..9 (the jade scutes of ref Neck1, Neck3, Body, Tail2..7; new segments Neck1/2,
Neck4, Body, Tail3/4, 5-7, 8-10, 11-13, 14-16, 17/18 by centre), TailTipGem (the reference's
dark tail-tip wedge). VeinGem4 no longer exists (the reference has two gems; nothing reads it).
Hidden (Transparency 1, `PhaseReveal`): P2Crack1..6 (2) on the Body and Tail1..4 backs,
P3Fin1..5 (3) on Neck1..5, BarbelL1/L2/R1/R2 and P3BarbelL/R (3).

Gotchas: hood, fangs and tongue are inside other blocks at rest, so any pose that leaves them
half out shows a cut panel; flare the hood at least 0.6 rad before it reads. The ThroatSac is
a block on the Jaw (it opens with the jaw). Scutes span the cuts inside each reference segment,
so a sharp pitch at those joints lifts a scute edge (yaw is clean: the scutes sit on the bend
axis). No crown or halo exists.

The pose module was re-derived for this body (next section).

### Jade Jiao movement and poses (`src/client/EnemyPoses/JadeJiao.luau`, `Serpent.luau`)

Pose module in the WolfKing API (`JOINTS`, `loops` idle/walk/run/circle, `moves`, `durations`,
`sample`, `gaitRate`, `VARIANTS`, `VARIANT`, `setVariant`, `setAll`, `scaled`). **Real studs,
`SCALE = 1`** (the pivot table above is in the module). Registered by Template `JadeJiao`
(keyedBlend 0.2 s); `USES_HISTORY` makes EnemyAnimator feed `phase`, `speed`, `turn`, `time`,
`radius` (CoilRadius), `yawAt` (the TRAVEL heading history, velocity direction when faster than
2 studs/s, unwrapped), `wavePhase` (the wave's phase, advanced with the ground speed in every
state, not just the loops), `still` (seconds still), `travel` (studs since it started moving) and
`rested` (how long it was still before that). The circle loop isn't used for serpents (a snake
doesn't strafe; the walk/run follow the travel heading).

**Rest-direction composition.** Every bone's absolute orientation is `Ry(heading) * Rx(-up) *
Q^-1` with `Q` its rest direction (the coiled tail's rest headings unwrap from +0.84 at the Body
to -3.73 at Tail18). Neck: `Ry(Y) * Rx(E - eps)`, rest elevations 36.4, 36.4, 133.8, 37.6, 19.6
degrees, skull 0. Old-layout neck shapes in the move tables (`E`, `Y`) are remapped onto the new
bones (old bone 1 -> new 1-2, old 4+5 -> new 5); `N` gives new-layout elevations. Stance root
shifts `rx/ry/rz` are x1.1 studs.

**Slither (path following).** The spine lies on a sine-generated ground curve, heading
`th0 * cos(phase - k s)` (s = arc behind the neck base). Positions use the closed form in
Bessel functions, the curve's mean line is the server root's lane (x = 0), and the phase advances
at `k * v / J0(th0)` (the sliding speed), so the curve stays fixed on the ground and every belly
point slides along one groove. Walk: th0 0.9 rad, wavelength 30 arc studs (about half the
55-stud ground spine), lateral amplitude about +-3.9 studs; run (21): th0 0.72, wavelength 34.
No taper: the whole body is on the path. Turning: a bone at arc s takes the travel heading from
(s - 9.8) / v seconds ago (9.8 = neck base to root centre); bones ahead of the root extrapolate
the turn rate. The lower neck follows the path ahead, then the neck is solved (`Serpent.centre`)
so the head pivot stays on the lane and the skull keeps its aim. Locomotion necks (new layout):
walk 14, 24, 75, 26, 8, -2 (head pivot about 12.9 high), run 6, 12, 45, 18, 4, -4 (about 9.6).
**Measured** (`qa_jade_jiao.luau` skate, belly sideslip on the tail segments): walk 6 <= 0.7
studs/s, 12 <= 1.1, 21 <= 1.0, 24 <= 1.2 (the "Root" column there reads the HRP-fixed rest pivot
and is meaningless now). `slither_jade_jiao.luau` poses an anchored EditorOnly copy along a
curved track with belly traces for a visual check.

**Coil and uncoil.** Idle gathers the S it stopped in into the reference's resting coil over
1.2-4.5 s of `calm` (EnemyAnimator: seconds still and out of any keyed move, frozen through a
windup, restarted after any other keyed state; `rested` is capped by it), body first, tail last,
and raises the neck back into the strike S within a second of `still` (QA pass 2026-10-22: the
coil used to run on `still`, which counts attack time, so a recover popped the body into a coil
and the head dropped toward the walk neck for three seconds after every attack). Starting to
move from a coil, each bone leaves it once the head has travelled about 0.45 of its arc. A move
started from a coil unwinds it over the first 0.6 s of the windup. Attack stances sit on the
walk's S frozen at the current wave phase.

**Ring (JiaoCoil). Radius 11.9 studs** (`COIL_RADIUS`; the server's `coilRadius` should match):
the neck base sits on the server root's centre (0, 5.65) heading back, the centre on the left at
(-11.9, 5.65), and the Body plus the tail curl left round it (the whole 55.4 studs covers about
267 of the 280 degrees, so the free-tail arch is short). Inner clearance about 8.6 studs from the
centre. The neck hangs the head over the centre (`Serpent.reach`). The hold tightens 12% and the
squeeze another 7% (about 9.8 studs, above the 9-stud self-overlap limit).

**Checked** (`qa_jade_jiao.luau` moves): every move loads and poses; lowest point >= -0.25 except
PillarSlam's buried head (-0.72, intended) and Death (-0.34). Sunk (MireDive, Erupt/Emerge
windup): the highest point is 1.1 under the ground. Rear heights (skull): Molt 26.5, Ascension
27.7, DreadHiss 27.6, PillarSlam hang 25.4.

**Not done yet:** contact points against the re-fitted server areas (fang cone r 34, slam at
(0, 0, -27), sweep r 22, mouth for the lance/spray 24.2 ahead and 13.1 up) are unmeasured; the
coil ring's on-circle error and the free-tail arch weren't re-run; hood/fang/whisker clipping;
everything in Play (feel, the EnemyAnimator blend, phone cost).

**TailShove** (boss feel pass, 2026-10-22; attack `tailShove`, the throw that makes range for the
venom). Windup 0.70 / active 0.14 / recover 0.66 (the def's 0.70 / 0.80; the active plays at the start of the recover). The body twists
right (`ryaw` -0.42) with the neck in a tight drawn-back S and the head kept on the target, the
tail swings out to its right side and lifts (`ty` 1.6, `tup` 0.9: tip about 70 degrees round from
straight behind and 11 studs up at u 0.9), then the body unwinds (`ryaw` +0.3) and the tail whips
low to the front-right: tip at 139 degrees at contact (end of windup), 157 after the flick that
ends the active (the release). The neck is reared high (skull 21.8) and leans left (`Y` up to
0.52) out of the tail's way. Recover: the tail recoils the way it came, the head rears back (LBACK,
hood 0.85) at u 0.55-0.75 and it ends half reared, hood up (`TS_READY`), so a ranged windup
blends straight on. Measured by forward kinematics (bone capsules, `tools/frag` probe, not kept):
tail clears the neck by >= 0.9 and the Body by >= 2.9 studs on every frame, lowest point >= -0.1.
Learned: `ty` sweeps the tail counter-clockwise from above (behind -> right -> front), and bones 1-4
take only 0.25-1.0 of it, so the tail swings like a boom about the Body's back end; sweeping
it past about 160 degrees runs Tail10 through Neck3 (-4 studs at 180). **Never key a full `ty`
turn**: it is not the identity on bones 1-3 (they end turned about 1.6, 3.1, 4.7 rad, a knot at
the tail base, spun back by the next blend); the old TailSweep did this. Not checked: the tail
against the player at the def's cone, feel in Play.

**QA pass (2026-10-22)**, measured with a motion probe (each move played as EnemyAnimator does,
30 Hz, forward kinematics on the template; mouth, tail tip and Body speeds per frame):
- **TailSweep** is a 4 rad lash now, not a full circle: wind left and high (`ty` -1.55, `tup` 1.0:
  tip 99 degrees left, 20 up; body `ryaw` -0.2 with the tail, head dipped and looking away), hold
  0.40-0.45 s, then the body unwinds (`ryaw` +0.15) and the tail lashes behind and round the right,
  coming down (`ty` 2.4, `tup` 0.3: tip 124 degrees right, 7 up at contact; overshoot `ty` 2.7), then
  recoils to `ty` 1.3 and settles. Tail clear of the neck and Body by >= 2.9 studs on every key and
  mid-lash sample. Tip peak about 1000 studs/s in the last two frames (the lag catch-up), against
  1230 round the whole circle before. Variant B winds further (`ryaw` -0.5) and lashes to 2.1/2.45.
- **TailShove**'s whip takes 0.15 s with an accelerating ease (it was a 0.08 s `snap`, fastest at its
  start: 1000 studs/s at the tip); the cock holds 0.50-0.55 s. Tip peak 760.
- **PillarSlam**'s recover: buried still for 0.3 s, then trembling and hauling back (`SLAM_STRAIN`,
  rz -3.0), rips free at 0.86 s with the head tossed up, and settles over the last 0.3 s (it used to
  pop upright in the last 0.14 s).
- **Ring arch**: the free tail past the ring's end is weighted by arc length (it was whole bones, so a
  bone flipped between ring and arch whenever the tightening changed the coverage: an 82-degree
  one-frame pop at Tail17 on the squeeze; 49 degrees now, inside the deliberate 0.14 s squeeze snap).
- **Seamless phases** (`FAMILIES.JadeJiao.seamless`): no keyed blend between windup, dash and
  recover of one attack. The 0.2 s blend from the frozen last windup frame stopped every strike
  dead for a frame and smothered its overshoot (the fang strike went 321 -> 0 -> 7 studs/s).
- Gotchas: a strike that eases with `snap` reaches the hit pose about 0.05 s before contact and
  decelerates into it, which reads as "snap and hold"; a lash or swing should use `in` instead, so it
  is fastest at contact. The lag fade (`1 - smooth(0.8, 1, u)` in a windup) catches the tail tip up
  in the last 20% of the windup, which doubles the tip's speed there.
