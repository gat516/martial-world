# Roster beasts: rig notes for animators

The Venom Serpent, Jade Python, Flame Raven and Thunder Ape templates live in
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
