# Roster beasts: rig notes for animators

The Venom Serpent, Jade Python, Flame Raven and Thunder Ape templates (and the boss
Thunder Ape B, shipped in `assets/Enemies.rbxm`) live in
`ServerStorage._RosterBeasts` (staging, not shipped yet). They are built from Studio parts
by `build_<beast>.luau` and rigged by `rig_<beast>.luau` through `rig_core.luau`.

## Rules that hold on every rig

- Each model has an invisible `HumanoidRootPart` (the only anchored part, identity rotation,
  PrimaryPart), a `Humanoid` (R15, no display name) with an `Animator`, no scripts, and
  ModelStreamingMode Atomic.
- One Motor6D per moving segment, rooted at the HRP. Each Motor6D sits in its Part0 and
  hinges at the real pivot. **Every joint frame has identity rotation in model space at
  rest**, so at rest every joint turns about the same world axes.
- The beast faces **-Z**; its left is **-X**; up is **+Y**.
- Detail pieces are welded to their segment with WeldConstraints. Only segments have
  Motor6Ds, so in Moon Animator 2 and the Animation Editor you select a segment and its
  details move with it.
- Keyframes address poses by **part name** (Part1 of each Motor6D). Every segment name is
  unique in its model. `art/enemies/keyframe_test.luau` keys every joint on all four
  rigs and they all pass.

### Sign conventions (all joints, at rest)

| Axis | Positive rotation does |
|---|---|
| +X (pitch) | a part pointing forward (-Z) lifts its front; a part hanging down swings forward; a part pointing up leans back |
| +Y (yaw) | the part's front turns toward the beast's left (-X) |
| +Z (roll) | a part pointing to the beast's right (+X) rises; a part pointing left (-X) drops |

The ones you'll use most: **jaw open = -X**. **Left wing or flap up = -Z, right = +Z.**
Head down = -X.

### Motor6D names

Motor6Ds keep the `Joint*` names that the current `EnemyAnimator` drives
(`JointHead`, `JointTail`, `JointLegFL/FR/BL/BR`), so the beasts animate in game today.
Keyframed clips don't depend on Motor6D names because they key by part name. To name
each Motor6D after its part instead, pass `nameByPart = true` in the rig script's call
to `rig_core`. EnemyAnimator would then need its per-type pose tables first.

## Venom Serpent (13 joints)

A hooded cobra. The back two thirds lie on the ground in an S, and the front rears up
with the head level at player-head height.

| Joint | Moves (Part1) | Parent | Notes |
|---|---|---|---|
| JointRoot | Body | HumanoidRootPart | the ground segment under the neck; pivots at its middle |
| JointNeck | Neck1 | Body | base of the rearing column; +X leans it back |
| JointNeck2 | Neck2 | Neck1 | |
| JointNeck3 | Neck3 | Neck2 | carries the hood |
| JointHead | Skull | Neck3 | legacy: EnemyAnimator pitches it; +X nose up |
| JointJaw | Jaw | Skull | -X opens; the fangs are on the Skull and the tongue is on the Jaw |
| JointHoodL | HoodL | Neck3 | hinged at the hood's inner edge; flare = **-Y** (the outer edge swings forward) |
| JointHoodR | HoodR | Neck3 | flare = **+Y** |
| JointTail | Tail1 | Body | legacy: EnemyAnimator pitches it and wags it with yaw |
| JointTail2-5 | Tail2-Tail5 | the previous Tail | yaw for the S-sway; Tail5 carries the barb |

Tells (Neon, `Tell` attribute): EyeL/R, VenomSacL/R on the jowls, HoodSpotL/R.

### Venom Serpent poses (`src/client/EnemyPoses/VenomSerpent.luau`)

Authored in real studs for VenomSerpentB (1.40x, the roster body x 1.4; `SCALE = 1`), model space
with the ground at Y 0 and the HRP centre at x/z 0. Joint pivots at 1.40x (the roster's x 1.4):
Root (0.63, 0.89, 0.07); Neck (0, 0.91, -0.84), Neck2 (0, 2.45, -1.96), Neck3 (0, 4.13, -2.45), Head
(0, 5.67, -2.52); Tail (1.26, 0.87, 0.98), Tail2 (1.12, 0.81, 3.22), Tail3 (-0.56, 0.73, 4.76), Tail4
(-1.82, 0.63, 6.72), Tail5 (-0.98, 0.50, 8.68), tail end (1.17, 0.26, 9.84); mouth (0, 6.06, -4.84).
Bones: Neck 1.9, Neck2 1.75, Neck3 1.54 long; the head to the mouth 2.33. The module checks out
against the rig to 0.004 studs. The pose maths is `Serpent.luau`'s (absolute orientations per bone).

- **Neck angles** (stance keys e1..e4, degrees): e1..e3 are the bones' elevations above horizontal
  (rest 54 / 73.7 / 87.4, 90 vertical, past 90 leans back); e4 is the HEAD's absolute pitch (0 = the
  rest, level; + noses up). Y headings are absolute per bone (+ turns left); the module adds Z leans
  (roll about the forward axis, + tips the bone toward the beast's left).
- **A near-vertical column cannot sway by yaw** (heading about the vertical only twists it). The
  idle's lateral S and the "keep the head over the lane" correction are Z leans (up to ~0.25 rad).
- **The gooseneck**: the skull sits at an 87 degree elbow to Neck3, baked into the geometry. The head
  joint's local angle is `e4 - (e3 - 87.4)`, so laying the neck forward with a level head needs a huge
  hinge angle (a wedge of sky). Keep every neck joint's relative bend within about 0.55 rad
  (e1 - 54, (e2 - e1) - 19.7, (e3 - e2) - 13.7, e4 - (e3 - 87.4)); the strike keeps Neck3 at 50-60
  degrees and the head down instead of stretching it flat. The death lies at 0.8 rad on the head joint.
- **Hood**: flare 0..1.15 rad (L = -Y, R = +Y). The plate meets the skull more as the head pitches up
  (box-overlap depth at flare 1.0: 0.27 level, 0.40 at +0.3 rad) and the jaw as it pitches down. The
  moves keep the hood at 0.8 or less when the head is more than 0.3 rad off level.
- **Death on its side buries a hood**: rolling the neck past about 1.2 rad pushes one hood plate 0.5 to
  2 studs under the floor. The death collapses forward and rolls only 0.1-0.3 rad.
- **Neck1 sinks** when its elevation drops under about 35 degrees without lifting the front: the walk and
  strikes add `bp` (front lift about the rear end) 0.05-0.1.
- The Body is a 2.2 stud rigid block, so the slither lays it on the chord of the wave (Serpent.lay); with
  wavelength 10.5 and heading amplitude 0.8 (0.65 at a run) the belly sideslip stays under 2 studs/s up
  to 9 studs/s.
- Tongue and sacs have no joints: a tongue flick is a jaw tick, the sacs swell through the VFX.
- Checking the slither: `qa_venom_serpent_poses.luau` takes a Body block's position, not
  `Part0 * C0`: for JointRoot that is the static rest pivot and fakes a sideslip.

## Jade Python (14 joints, elite)

A thick horned python lying in a loose coil, with the front raised in a strike S.

| Joint | Moves (Part1) | Parent | Notes |
|---|---|---|---|
| JointRoot | Body | HumanoidRootPart | ground segment under the neck |
| JointNeck | Neck1 | Body | the S: Neck1 rises forward, Neck2 back, Neck3 forward |
| JointNeck2 | Neck2 | Neck1 | |
| JointNeck3 | Neck3 | Neck2 | |
| JointNeck4 | Neck4 | Neck3 | short and nearly level, under the head |
| JointHead | Skull | Neck4 | legacy; horns, brow pearl and upper teeth ride the Skull |
| JointJaw | Jaw | Skull | -X opens; the throat plate rides the jaw |
| JointTail | Tail1 | Body | legacy; its yaw swings the whole coil |
| JointTail2-7 | Tail2-Tail7 | the previous Tail | the coil curls round to the front left; Tail7 is the tip |

Tells: EyeL/R and EyeSideL/R (amber; they wrap the corner so they read from the front
and the side), BrowPearl, VeinGem2/3 on the neck's back (jade).

## Flame Raven (16 joints)

A low hoverer. The body sits at about player-head height (Y 5.6) and the talons hang to
Y 3.3. **HRP**: 2.4 x 3 x 3 centred at Y 5, so HipHeight is 3.5. The Humanoid holds it
up, and the root sits where a grounded player's melee box reaches. The wings are spread in
a shallow V at rest, which is the top of a flap.

| Joint | Moves (Part1) | Parent | Notes |
|---|---|---|---|
| JointRoot | Body | HumanoidRootPart | pivots at the body centre: hover bob, dive tilt (-X noses down) |
| JointNeck | Neck | Body | |
| JointHead | Skull | Neck | legacy |
| JointJaw | Jaw | Skull | the lower beak; -X opens |
| JointCrest | Crest | Skull | the ember crest; -X stands it upright (flare) |
| JointShoulderL / R | UpperWingL / R | Body | flap: **L up = -Z, R up = +Z**; sweep back = +Y on L, -Y on R (measured; first notes had it reversed) |
| JointElbowL / R | ForeWingL / R | UpperWing | same signs as the shoulder |
| JointWristL / R | WingTipL / R | ForeWing | the primaries; same signs |
| JointTail | Tail | Body | the fan; +X lifts it |
| JointLegBL / BR | LegL / R | Body | legacy back-leg names: EnemyAnimator swings them (talons forward in its dash pose) |
| JointAnkleL / R | TalonL / R | Leg | +X curls the toes forward |

The wings have no legacy name. A pitch swing would row them, so they hold their spread
until EnemyAnimator learns a flap (roll at the shoulders).
Tells: the EyeL/R, the Crest, and the 8 primary tips (WingTip*Primary*Tip).

### FlameRavenB (the user's reference body, 1.0x, brought in 2026-10-22)

`assets/Enemies.rbxm` template `FlameRavenB`: the user's `FlameRaven` kept as it looks, 15.0 x 5.5 x 7.1 studs, 87 parts, the 16 joints above. Built by `bring_in_flame_raven.luau`. No Tell parts were added (the source's: `EyeL/R`, `Crest`, `WingTip{L,R}Primary1..4Tip`, all with `TellBase`).

- **Hover convention** (same as the Blood Bat): the pivot is the `HumanoidRootPart` centre at **Y 5.0**, identity rotation, and the Humanoid holds it up with `HipHeight 3.5` (= the root's bottom). The talons hang to Y 3.25. Not a ground pivot.
- **Root** is sized to the body, not the wingspan: 4.4 x 3.0 x 7.12 (head to tail fan), centred on the body in Z, so its centre is 0.47 behind the old pivot; `JointRoot` is at root-relative (0, 0.60, -0.37). Root centre to the beak (`Mouth`): 3.46 studs forward (Z -3.46, ground Y 6.80).
- **Wings** (roll about Z lifts, the Blood Bat's convention):

| Raven joint | Bat joint | Moves | Rest pivot (root-relative) | Axes |
|---|---|---|---|---|
| JointShoulderL / R | JointWingL / R | UpperWingL / R | (+-0.75, 1.15, -0.10) | flap roll Z: L up = -Z, R up = +Z; sweep back = +Y on L, -Y on R (measured; first notes had it reversed) |
| JointElbowL / R | JointWingL2 / R2 | ForeWingL / R | (+-2.55, 1.75, 0.10) | same signs |
| JointWristL / R | JointWingL3 / R3 | WingTipL / R (the primaries) | (+-4.05, 2.40, 0.35) | same signs |

  A shared flap cycle keyed on shoulder/elbow/wrist maps one to one onto the bat's WingX / WingX2 / WingX3 (same signs, same lag order), scaled by the span (raven pivots are about 2x the bat's). The raven rests spread in a shallow V (about the top of a flap); the bat at about 25 degrees up. Other joints: JointNeck (0, 1.05, -0.75), JointHead (0, 1.85, -1.20), JointJaw (0, 1.80, -2.10), JointCrest (0, 2.50, -1.65), JointTail (0, 0.30, +1.30), JointLegBL/BR (+-0.45, -0.25, +0.40), JointAnkleL/R (+-0.45, -1.15, +0.20).
- **Attachments**: `Mouth` (Skull, beak tip), `Core` (Body, chest, 5.68 up), `WingTipL_FX` / `WingTipR_FX` (on WingTipL/R, outer tip, X +-7.49 from the root, Y 7.97), `Talons_FX` (Body, between the talons at their lowest point, Y 3.25), `Crest_FX` (Crest, the top, Y 8.28).
- `HealthBar` 1 stud over the top. check_rig clean, keyframe_test keyable (16 joints).

## Thunder Ape (18 joints, elite brute)

A knuckle-walker. The arms are its front legs and the legs its back legs, so the
current trot gait reads as a knuckle-walk.

| Joint | Moves (Part1) | Parent | Notes |
|---|---|---|---|
| JointRoot | Hips | HumanoidRootPart | pivots at the hips: rearing up = +X |
| JointSpine | Chest | Hips | torso and hump; +X rears the chest |
| JointHead | Skull | Chest | legacy; the head sits low between the shoulders |
| JointJaw | Jaw | Skull | -X opens; the beard rides the jaw |
| JointLegFL / FR | UpperArmFL / FR | Chest | shoulders (legacy front legs); +X swings the arm forward and up (overhead is about +2.7 with the root reared) |
| JointElbowFL / FR | ForeArmFL / FR | UpperArm | +X bends the forearm forward and up |
| JointWristFL / FR | HandFL / FR | ForeArm | the fist |
| JointFingersFL / FR | FingersFL / FR | Hand | the curled fingers, hinged at the knuckle line; +X opens them forward |
| JointLegBL / BR | ThighBL / BR | Hips | hips (legacy back legs) |
| JointKneeBL / BR | ShinBL / BR | Thigh | |
| JointAnkleBL / BR | FootBL / BR | Shin | |

The HRP is 4 tall, so EnemyAnimator strides it at scale 2: a slow, heavy gait.
Tells: EyeL/R, ChestBoltL/R (beside the low head, and fully shown when it rears up), and
ForeArm*Bolt on the front of each forearm.

## Thunder Ape B (boss, 23 joints, 139 parts, 3.71x)

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

## Windup poses

`poses.luau` holds a starting windup pose for each beast's main attack, keyed by Motor6D
name. Use them as reference for the clips, not as final keys:
- serpent spit: the column draws back, the hood flares, nose up, jaw open
- python strike: the S folds back, head cocked, jaw wide
- raven dive: wings swept up and back, head down, talons forward
- ape double-fist slam: rears up on its legs with both fists overhead

## Tools

- `preview_beasts.luau`: the lineup on the plate at (300, 400, 3000) in
  `Workspace._RosterPreviewBeasts` (tagged EditorOnly, everything anchored), with rest and
  windup FK poses. `solo.luau` drops the other models below the plate for clear side views.
- `drift_beasts.luau`: an engine pose test on parented clones (rest, windup, stress). It
  checks that every segment follows its joint and every welded piece stays on its segment.
- `art/enemies/check_rig.luau`: floating and unjointed parts.
- `art/enemies/keyframe_test.luau`: keys every joint.

## Jade Jiao (boss, 37 joints, `build_jade_jiao.luau` / `rig_jade_jiao.luau`)

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

## Blood Centipede (101 parts, 43 joints, `build_blood_centipede.luau` / `rig_blood_centipede.luau`)

Low grave-dweller, bone-white plates edged dull red. Body 15.4 studs skull to cerci
(16.1 with the pincers, antennae to 17.1), 5.7 wide with the legs out, 3.0 tall at the
antenna tips (plates 2.1 at the collar tapering to 1.8). Standalone export:
`art/enemies/beasts/export/BloodCentipede.rbxm` (template `BloodCentipede`; Modeler A merges
it into `Enemies.rbxm`). Faces -Z. The line runs Skull (front) -> Collar -> Seg1..12 -> Tail.

**HRP** (the hit volume): 3.2 x 2.5 x 16.1, centred at (0, 1.3, -0.05), so z -8.1..8.0
covers the whole line; bottom 0.05 above the ground, HipHeight 0.05. Model pivot = the HRP
centre, identity rotation. Health bar 1 stud over the top (3.99).

| Joint | Moves | Parent | Pivot (rest, model space) | Notes |
|---|---|---|---|---|
| JointRoot | Collar (the root plate) | HRP | (0, 1.3, -4.9) | bone, red skirt, CoreGlow |
| JointHead | Skull | Collar | (0, 1.4, -5.4) | pitch nods the head; carries eyes, brow, maw |
| JointJawL/R | JawL/R (pincer, with tip) | Skull | (+-0.95, 1.0, -7.1) | yaw closes it: JawL closes with -Y, JawR with +Y |
| JointAntL/R | AntL/R (with tip) | Skull | (+-0.7, 2.2, -6.9) | whips; yaw sweeps, pitch lifts (-X = down) |
| JointSeg1..12 | Seg<i> plate | Seg<i-1> (Seg1: Collar) | (0, 1.2, front edge of the plate: -4.3 + 0.8 (i-1)) | a chain: rotating one carries every plate behind it; yaw is the slither wave, pitch a hump |
| JointLegL<i> / JointLegR<i> | one leg each | Seg<i> | on the plate's side, (+-(w/2+0.1), 0.95, plate centre) | single part, pivot at the body; X swings it fore/aft, Z lifts: a left leg lifts with -Z, a right leg with +Z |
| JointTail | Tail (final plate + cerci) | Seg12 | (0, 1.2, 5.3) | yaw sways the cerci |

Sign conventions are the shared ones above (X pitch, Y yaw, Z roll). Jaws: pincers rest
slightly apart, tips ~0.6 from the midline; about 0.5 rad each way is a full close. Legs point out and
down at about 45 degrees, so a roll of 0.4 rad (in the lift direction) lifts a foot clear of the ground; ripple them
with a phase lag of about 0.3 s per segment along the chain.

**Tells** (Neon, `Tell = true`): `EyeL/R` (skull front), `PincerTellL/R` (on the jaw bases),
`SeamTell1..12` (a strip across each plate's front on top), `CoreGlow` (red ball in the
collar seam, riding the Collar).

**FX attachments**: `Mouth` (Skull, ahead of the maw), `Core` (Seg3, on the back),
`Seg6_FX` (Seg6, on the back), `TailTip_FX` (Tail, behind the cerci).

Gotchas: every segment, leg and detail has a unique name. Plates overlap their neighbours
by 0.1 so a bend of up to about 0.25 rad per joint shows no gap; sharper bends open a slit
on the outside of the curve (spread the wave across more segments). Legs are 0.34 thick and
read as sticks head-on; they fan out of the skirt, so keep the swing small. Checks:
`check_rig.luau` clean, `keyframe_test.luau` keyable (43 joints).

## VenomSerpentB (the user's reference body, 1.40x, brought in 2026-10-22)

`assets/Enemies.rbxm` template `VenomSerpentB`: the user's row body `workspace.Folder.Model.VenomSerpent`, 5.13 x 7.00 x 15.93 studs, 84 parts, the 13 joints above. The old roster `VenomSerpent` template is a 17-part, joint-less stand-in (4.6 x 5.6 x 5.4), so it does not match; `VenomSerpentB` is the row body, kept exactly. Attribute `Scale = 1.40`.

- Pivot, root: the pivot is the `HumanoidRootPart` (identity rotation, Y 2.379 = root height, feet/coil on Y 0). The root is 5.13 x 4.76 x 15.93, invisible, centred on the body's X/Z bounds.
- Mouth is 7.09 studs in front of the root centre (Z -7.09, 5.66 up), the head at player height.
- Rest pivots root-relative (X, Y up from the root, Z): JointRoot (0.67, -1.49, -2.25); JointNeck (0.04, -1.47, -3.16); JointHead (0.04, 3.29, -4.84). The rest of the table above applies; full numbers via `joint:GetPivot`-style reads of `Part0.CFrame * C0`.
- Tells (Neon): `EyeL`, `EyeR`, `VenomSacL`, `VenomSacR`, `HoodSpotL`, `HoodSpotR`.
- Attachments: `Mouth` (Skull), `SacL_FX`, `SacR_FX` (on the sacs), `TailTip_FX` (Tail5, at the barb tip, on the ground).
- `HealthBar` 1 stud over the top. check_rig clean, keyframe_test keyable (13 joints).

## Blood Bat (Iron-Winged, 40 parts, 13 joints, `build_blood_bat.luau` / `rig_blood_bat.luau`)

A small swarm flier (wind-blood). Wingspan about 4.9 studs (5.2 bounding box), body 1.5 long,
ears to Y 6.3. Standalone export `art/enemies/beasts/export/BloodBat.rbxm` (template
`BloodBat`; Modeler A merges it into `Enemies.rbxm`). Faces -Z.

**Flier convention** (matches the Flame Raven, `workspace.Folder.Model.FlameRaven` in the
testbed): the model is built in place at hover height, the pivot is the HRP centre (not the
ground) with identity rotation, and the HRP floats with HipHeight = its bottom. **HRP** 2.6 x
2.4 x 2.6 centred at (0, 4.6, -0.2), bottom 3.4 (the raven's is 2.4 x 3 x 3 at Y 5, bottom
3.5), so a grounded player's melee box reaches it. Body centre Y 4.6, feet down to Y 3.7.
Root centre to the mouth (`Mouth` attachment) at rest: 1.3 studs forward (z -1.5 vs -0.2).

| Joint | Moves (Part1) | Parent | Pivot | Notes |
|---|---|---|---|---|
| JointRoot | Body | HRP | (0, 4.6, 0) | hover bob, banking (roll Z) |
| JointHead | Skull | Body | (0, 4.95, -0.6) | -X nods down |
| JointJaw | Jaw | Skull | (0, 4.5, -0.65) | -X opens; reveals MouthTell |
| JointEarL / R | EarL / R | Skull | (+-0.38, 5.3, -0.85) | roll Z flicks them: a left ear tilts out with +Z, a right ear with -Z |
| JointWingL / R | WingL / R | Body | (+-0.5, 4.75, -0.2) | shoulder, **flap roll Z: L up = -Z, R up = +Z** |
| JointWingL2 / R2 | WingL2 / R2 | WingL / R | (+-1.2, 5.1, -0.4) | elbow, same signs |
| JointWingL3 / R3 | WingL3 / R3 | WingL2 / R2 | (+-2.0, 5.3, -0.65) | the wingtip finger, same signs; pitch X sweeps it back/forward |
| JointLegL / R | LegL / R | Body | (+-0.3, 4.2, 0.4) | small hanging feet; +X swings the foot forward |

Wing joints are the Flame Raven's convention (shoulder/elbow/wrist, roll about Z lifts), so
one flap cycle can drive both: at rest the wings sit about 25 degrees up (half spread);
a full downstroke is about 0.8 rad past rest on the shoulder, with the elbow and finger
lagging a beat. Yaw (Y) at the shoulder sweeps a wing back (L: +Y, R: -Y; measured). The three membrane skins rest at signed elevations +0.45, +0.25 and -0.61 (the finger skin slopes down): keep shoulder >= 0.34, elbow >= 0.54, finger <= 0.74 (pose_bat: Flap floor/ceil).

**Tells** (Neon, `Tell = true`): `EyeL/R`, `MouthTell` (on the jaw top, inside the mouth,
visible when it opens), `WingEdgeTellL/R` (a strip on the metal leading bone of WingL2/R2),
and `ChestCore` (the red chest glow, on the Body).

**FX attachments**: `Mouth` (Skull), `Core` (Body, chest front), `WingTipL_FX` (WingL3),
`WingTipR_FX` (WingR3).

Gotchas: the membranes are 0.07 thick sheets, so they go edge-on from a level camera when
the wings are near flat; keep a V of 0.3 rad or more. Ears are forward-facing triangles
(two wedges) and read from the front. Checks: `check_rig.luau` clean, `keyframe_test.luau`
keyable (13 joints).
