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
| JointShoulderL / R | UpperWingL / R | Body | flap: **L up = -Z, R up = +Z**; sweep back = -Y on L, +Y on R |
| JointElbowL / R | ForeWingL / R | UpperWing | same signs as the shoulder |
| JointWristL / R | WingTipL / R | ForeWing | the primaries; same signs |
| JointTail | Tail | Body | the fan; +X lifts it |
| JointLegBL / BR | LegL / R | Body | legacy back-leg names: EnemyAnimator swings them (talons forward in its dash pose) |
| JointAnkleL / R | TalonL / R | Leg | +X curls the toes forward |

The wings have no legacy name. A pitch swing would row them, so they hold their spread
until EnemyAnimator learns a flap (roll at the shoulders).
Tells: the EyeL/R, the Crest, and the 8 primary tips (WingTip*Primary*Tip).

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

Template `JadeJiao`, model attribute `Scale = 3.17`: built directly at **3.17x the roster
Jade Python** (the user's reference size), not via `ScaleTo`. The build is authored in the
fight sheet's contract units (about 1.9x the python) and lifted by **K = 3.17 / 1.9 = 1.668**
about the model origin before export, so **multiply every contract number below by K**.
Rest pose: the neck rears in an S, the hood is folded flat on the neck sides, the tail lies
straight back along +Z. Faces -Z, left is -X, every joint frame is identity at rest, rotation
about X is pitch. HRP (the only anchored part) = (7, 12, 14) x K = 11.7 x 20.0 x 23.4 centred
(0, 10.84, -2.50), bottom 0.83 above the ground, Humanoid HipHeight 0.83. Bounding box
about 15.7 wide x 23 tall (horns) x 115 long (whiskers and tail included); 177 parts.

Pivots below are in contract units; the real pivot is the value x K.

| Joint | Moves (Part1) | Parent | Pivot (contract units) | Notes |
|---|---|---|---|---|
| JointRoot | Body | HRP | (0, 1.9, 2.5) | hover, sink (y -6 x K = -10 for a burrow), whole-body pitch |
| JointNeck | Neck1 | Body | (0, 1.9, -1.0) | +X leans the column forward/down, -X rears it back |
| JointNeck2..5 | Neck2..Neck5 | previous Neck | (0,4.3,-3.8) (0,6.6,-2.8) (0,8.6,-5.0) (0,9.6,-7.0) | same sign; widths 3.8 3.5 3.2 2.9 2.6 |
| JointHead | Skull | Neck5 | (0, 10.0, -8.6) | -X nose up, +X nose down |
| JointJaw | Jaw | Skull | head frame (0,-1.6,0.5) | -X opens |
| JointFangL/R | FangL/R | Skull | root on the palate, x +-0.95, y 8.4, z -12.1 about | folded back at rest (tip +Z). **+X swings the tip down and forward** (+1.57 rad points the tip straight down, about +2.2 down and forward) |
| JointHoodL/R | HoodL/R | Neck4 | on the neck side, x +-1.5, y 9.1, z -6.4 | panel extends back (+Z) from the hinge; flare = **-Y on L, +Y on R**, about 1.2 rad gives about 6 x 5 contract studs facing front |
| JointBarbelL1/R1 | BarbelL1/R1 | Skull | snout side (+-1.55,-0.3,-3.6 in head frame) | sweep: yaw, L -Y out; hidden at rest by sweeping back; first link |
| JointBarbelL2/R2 | BarbelL2/R2 | Barbel*1 | end of link 1 | second link; `P3BarbelL/R` ride it |
| JointTongue | Tongue | Jaw | floor of the mouth | -X lowers, yaw sways |
| JointTongueTipL/R | TongueTipL/R | Tongue | tongue end | yaw +-0.4 at rest (fork); close with yaw toward 0 |
| JointTail | Tail1 | Body | (0, 1.9, 6.0) | pitch (X) lifts, yaw (Y) curls |
| JointTail2..18 | Tail2..18 | previous Tail | end of the previous segment | segment centreline lengths (contract units): Tail1-6 3.0, Tail7-12 2.8, Tail13-16 2.5, Tail17 2.2, Tail18 2.0; total 49, tip at z 55; widths taper 3.6 to 0.8; pivot height = half the next segment's width + 0.1 |

Segment lengths in studs: Tail1-6 5.0, Tail7-12 4.7, Tail13-16 4.2, Tail17 3.7, Tail18 3.3
(x K, rounded). Body: z -1.0 to 6.0 contract (11.7 studs long), 6.3 wide. Neck widths x K:
6.3 5.8 5.3 4.8 4.3. Skull about 9 x 7.3 x 5.3.

Coil: yaw each Tail_k by (length_k / radius) about Y at its pivot (the contracts' radius 8
is x K in studs: 13.3 centreline radius, 26.7 across, because the body is K times thicker).
Check at that curl (Tail1..12 per-joint yaw = length/8): `preview_jade_jiao.luau` reports
no overlap between non-adjacent segments (adjacent ones overlap by design, hidden under the
knuckle balls). Segments are cylinders with a ball on each start pivot, so bends close up
cleanly without slits.

Hooks (attachments): Mouth (Skull), FangL_FX/FangR_FX (on the fang tips), Throat (on the
ThroatSac), Core, Dive_FX, Ground_Body, Ground_Tail4/9/14, Coil_Tail3/6/9/12 (belly edge
under the segment), TailTip_FX, HoodL_FX/HoodR_FX (on the eye-spots).
Tells (Neon, `Tell`, `TellBase`): EyeL/R, EyeSideL/R, BrowPearl, ThroatSac, FangTipL/R,
HoodSpotL/R, ScaleSeam1..9, TailTipGem, VeinGem2..4. Hidden (Transparency 1, `PhaseReveal`):
P2Crack1..6 (2), P3Fin1..5, P3BarbelL/R (3).
Gotchas: the hood is flat slabs, so at rest it is a square plate on the neck side (it is
not a flare); the hood hinges at the front edge so flare swings the rear edge out.
No crown or halo exists. The `Scale` attribute is informational (the roster-python ratio);
the body is already at full size.
