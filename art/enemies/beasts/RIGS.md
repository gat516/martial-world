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

## Per-model files
Read only the one you're working on.
- [Jade Jiao (boss, 37 joints, `build_jade_jiao.luau` / `rig_jade_jiao.luau`)](rigs/jade-jiao.md)
- [Thunder Ape B (boss, 23 joints, 139 parts, 3.71x)](rigs/thunder-ape-b.md)
- [Blood Centipede (128 parts, 43 joints, `build_blood_centipede.luau` / `rig_blood_centipede.luau`)](rigs/blood-centipede.md)
- [Blood Bat (Iron-Winged, 48 parts, 13 joints, `build_blood_bat.luau` / `rig_blood_bat.luau`)](rigs/blood-bat.md)
- [Venom Serpent (13 joints)](rigs/venom-serpent.md)
- [Flame Raven (16 joints)](rigs/flame-raven.md)
