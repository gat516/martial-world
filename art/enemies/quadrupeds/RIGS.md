# Quadruped roster rigs (animator notes)

Templates are in `ServerStorage._RosterQuadrupeds`: `StoneBoar_R`, `StoneTortoise_R`, `NineTailFox_R`.
They're built by `build_<name>.luau` and rigged by `rig_<name>.luau` (through `rig_lib.luau`).
Each one is a Humanoid (R15 type, with an `Animator`) and a Motor6D tree hanging from `HumanoidRootPart`.
They open in Moon Animator 2 and the Roblox Animation Editor as-is. `art/enemies/keyframe_test.luau` reports every joint keyable.

## Conventions (all three rigs)

- The model faces **-Z**. Its left side is **-X**, and the ground is at Y = 0.
- Every joint frame has **identity rotation in model space** at rest, so an angle means the same thing on every joint:
  - **+X (pitch)** swings a hanging leg **forward**, tips a forward-pointing head or jaw **up** (+ closes the jaw, - opens it) and tips a backward-pointing tail **down**.
  - **+Y (yaw)** turns a head toward the beast's **left** (-X) and a tail toward its **right**.
  - **+Z (roll)** tilts an upright part toward the beast's **left** (-X). On a hanging leg it swings the foot toward +X, which is inward for a left leg and outward for a right leg.
- Translations are in model space: +Y is up, +Z is backward.
- Every Motor6D is named `Joint<Part1>`, sits on its Part0 and has its pivot at the real hinge. There are two legacy exceptions, kept for `EnemyAnimator`:
  - `JointRoot` (HRP to the body root)
  - `JointLeg{FL,FR,BL,BR}` (moves `UpperLeg*`)
- `JointHead` and `JointTail` keep their legacy meaning.
- Detail parts are WeldConstraints to their segment, so they follow the segment and are never keyed on their own. Only segments (the Part1 of a motor) have keyable names, and those names are unique within each model.
- Nothing in the templates is anchored, the HRP included. `JointRoot` is the only joint off the HRP.

## Safe ranges (stress-posed and checked: no gaps or stray parts, drift < 0.001)

| Joint group | Tested range | Past it |
|---|---|---|
| `JointLeg*` (hips/shoulders) pitch | -1.0 .. +1.0 | the upper-leg block corners swing out of the body |
| `JointLowerLeg*` pitch | -1.35 .. +1.05 | the leg folds through itself |
| foot (`JointHoof*`, `JointPaw*`, `JointFoot*`) pitch | -0.8 .. +1.1 | use it to keep a planted foot flat |
| `JointNeck` + `JointHead` yaw | up to 0.8 combined | |
| `JointJaw` pitch | -0.55 (open) .. 0 | positive closes the jaw into the head |
| `JointEarL/R` pitch | -0.6 .. +0.4 | |
| `JointRoot` translate Y | -0.6 .. +0.7 | the feet sink or float unless the legs compensate |

A lowered root sinks the feet unless the legs bend to match. `plant_feet.luau` solves a planted leg's middle and foot joints for a pose and prints the angles to use.

## StoneBoar_R (21 joints)

| Joint | Moves | Parent | Notes |
|---|---|---|---|
| JointRoot | Hips | HumanoidRootPart | body root, pivot (0, 3.3, 1.2) |
| JointChest | Chest (front mass, shields, front plates) | Hips | spine bend, pivot (0, 3.5, 1.0) |
| JointNeck | Neck | Chest | |
| JointHead | Head (skull, snout, tusks, eyes, brows) | Neck | the tusks ride the head: aim them with the head |
| JointJaw | Jaw (lower tusks, mouth) | Head | - opens |
| JointEarL / R | EarL / EarR | Head | - pins the ears back |
| JointLegFL / FR | UpperLegFL / FR | Chest | |
| JointLowerLegFL / FR | LowerLegFL / FR | UpperLeg | the elbow |
| JointHoofFL / FR | HoofFL / FR | LowerLeg | the wrist |
| JointLegBL / BR | UpperLegBL / BR | Hips | |
| JointLowerLegBL / BR | LowerLegBL / BR | UpperLeg | the knee: - folds the shank back |
| JointHoofBL / BR | HoofBL / BR | LowerLeg | the hock |
| JointTail | Tail | Hips | + drops it, - lifts it |
| JointTailTip | TailTip (with the tuft) | Tail | |

- The Neon tells are the shoulder cracks, the back crack and the eyes, all on Chest and Head.
- Empty effect Attachments (no joint of their own, they ride their part): `TuskTip` on Head at (0, 4.05, -5.85), centred between the tusk points; `Core` on Chest at its centre (0, 3.4, -0.6); `HoofFL_FX` / `HoofFR_FX` on HoofFL / HoofFR at ground level under the fore hooves, (-1.15, 0, -1.35) / (1.15, 0, -1.35).
- Poses live in `src/client/EnemyPoses/Boar.luau` (Wolf.luau's format; planting from the shared `Quadruped.luau`). QA: `qa_quadruped_poses.luau`.
- **Leg bends (tested):** the fore middle joint juts forward as it folds (`JointLowerLegF*` -, the shank goes back); the hind one juts back like a hock (`JointLowerLegB*` +, the shank comes forward). The rest geometry already slants that way. Fold-backs the other way work for the solver but look wrong on a hoofed animal.
- **The head sits right over the fore legs.** Pitching it down with `JointNeck`/`JointHead` alone swings the jowl back into the elbows and the brow into the chest. Slide the neck forward with it: `JointNeck = CFrame.new(0, 0, -0.3) * pitch` (the neck overlaps the chest by 0.55 at rest, so no gap opens up to about -0.5). Head down -0.3 total, the gore hook up +0.5 with yaw 0.4, and a 0.8 combined yaw all clear with a 0.3-0.55 slide (more slide for more yaw).
- **Fore leg forward swing:** past about 0.65 the elbow ball rises under the chest (it shows as a raised knee at the chest front, fine), and the shank reaches the low jowl, a real clip. The RIGS paw hint (+1.0) clips with the head down: the shipped paw is `JointLegFL` +0.6, `JointLowerLegFL` -1.3, `JointHoofFL` +0.5 with the neck slid 0.45. Gallop fore swing stays near 0.5.
- **Root crouch:** the fore legs are dead straight at rest, so any shoulder rise (root pitch +, chest pitch +) or fore hoof reach forward makes the planted legs drop the root. A root pitch of +0.06 with a -0.3 drop puts the load on the haunches (hind compress ~0.37, fore ~0.15). The hind knee ball rises 0.2-0.35 into the hips' underside in any crouch; it stays inside the body.
- **Death:** roll it about the ground line under the left hooves' outer edge (x -1.6), not by lerping to a rolled root, or the body passes through the ground mid-roll. Full roll 1.45 plus a 0.06 drop puts the flank on the ground; rolling past 1.45 sinks the chest. Keep head yaw at 0 when it lies on its side: 0.1 rad sinks the long head 0.3.

## StoneTortoise_R (14 joints)

| Joint | Moves | Parent | Notes |
|---|---|---|---|
| JointRoot | Shell (shell, crag, moss, seams) | HumanoidRootPart | pivot (0, 2.4, 0) |
| JointNeck | Neck | Shell | **retracts by translation**: `CFrame.new(0, 0, z)` |
| JointHead | Head (beak, brows, eyes) | Neck | |
| JointJaw | Jaw | Head | - opens |
| JointLegF/BL, F/BR | UpperLeg* | Shell | single-segment legs |
| JointFootF/BL, F/BR | Foot* (claws) | UpperLeg | the ankle |
| JointTail | Tail | Shell | |
| JointTailTip | TailTip | Tail | |

- The neck retracts and extends along Z:
  - z = +2.3 is the full tuck: the face peeks out of the shell's front lip.
  - z = +0.6 is half in (the stomp windup).
  - z = -0.4 is stretched out for a bite.
  - Don't go past +2.3, or the face sinks behind the rim. Keep head yaw at 0 while it's tucked.
- To tuck the legs into the shell, translate them up (`JointLeg*` = `CFrame.new(0, 0.5, 0)`), so a shell-down drop of -0.5 on `JointRoot` keeps the feet on the ground.
- On the hind legs, pair translation with pitch to counter a rear-up. In the stomp windup the root is +0.55 up and pitched +0.32, and the hind legs are `CFrame.new(0, 0.34, 0) * pitch(-0.32)`.
- The Neon tells are the jade seams and cracks on the Shell, plus the eyes and brow mark on the Head.

## NineTailFox_R (38 joints)

| Joint | Moves | Parent | Notes |
|---|---|---|---|
| JointRoot | Hips | HumanoidRootPart | pivot (0, 3.1, 1.2) |
| JointChest | Chest | Hips | |
| JointNeck | Neck (with ruff and bib) | Chest | |
| JointHead | Head (snout, eyes, brow mark) | Neck | |
| JointJaw | Jaw (with chin) | Head | - opens |
| JointEarL / R | EarL / EarR (with inner ear) | Head | add roll ±0.3 to flare them out |
| JointLeg* / JointLowerLeg* / JointPaw* | the legs, like the boar's | Chest / Hips | |
| JointTail | Tail (the gold root block) | Hips | **moves the whole fan**: sway, lift, droop |
| JointTail1..9 | Tail1..Tail9 (gold bases) | Tail | 1 is the far left, 5 the centre, 9 the far right |
| JointTail1Tip..9Tip | Tail<i>Tip (cream brush, foxfire flame) | Tail<i> | the curl |

- Fan the tails out with roll, weighted by position: `t = (i - 5) / 4`, tail i gets roll `-t * k`.
  - k = 0.3 is the windup spread.
  - k = 0.55 is the widest: the outer tails reach horizontal. Past that they droop into the hind legs.
- Pitch on `JointTail<i>` runs from -0.25 (forward over the back) to +0.5 (swept back for a leap). Tips curl over ±0.6.
- The odd-numbered tails sit further back at rest (the fan has depth), so the same roll on neighbouring tails doesn't stack them.
- The Neon tells are the eyes and brow mark (pale azure) and the nine tail flames (a deeper azure, so they don't bloom white at rest). The flare on windup belongs to vfx.

## Tools here

| Script | What it does |
|---|---|
| `poses_quadrupeds.luau` | WINDUP / STRETCH / CROUCH pose tables, Motor6D name to Transform |
| `preview_quadrupeds.luau` | rest and windup rows in `Workspace._RosterPreviewQuadrupeds` (anchored, EditorOnly) |
| `qa_quadrupeds.luau` | static rig checks; every pose on a parented clone (drift, joint gaps, floating parts, feet); the shared keyframe test |
| `shot_quadrupeds.luau` | one posed copy on its own plate for captures |
| `plant_feet.luau` | solves planted legs for a pose |
| `qa_quadruped_poses.luau` | numeric QA for a pose module in `src/client/EnemyPoses/` (feet, sinking with the culprit segment, gaps, clipping, range); the boar's config |

## NineTailFoxB (boss body, Scale 2.13, 56 joints, 132 parts)

Template `NineTailFoxB` in `assets/Enemies.rbxm` (testbed-only gate). Scripts: `build_nine_tail_fox_boss.luau`, `rig_nine_tail_fox_boss.luau`, `nine_tail_fox_boss_tails.luau` (shared tail numbers), `qa_nine_tail_fox_boss.luau`, `promote_nine_tail_fox_boss.luau`.

- **Scale 2.13** (model attribute `Scale`), matching the user's `NineTailFox_R` reference row: bbox about 15.8 x 16.5 x 20.5 (reference 14.9 x 16.4 x 22.0), HRP at Y 5.54 (= 2.6 x 2.13), shoulder about 6.7, head top about 9.8. Built at 2.4x coordinates then `ScaleTo(2.13 / 2.4)` in the rig script, so do not scale it again; EnemyAnimator multiplies pose translations by `Scale`. Pose unit space = the old roster fox.
- Faces -Z, left is -X. Every joint frame is identity at rest, so pitch is rotation about X, yaw Y, roll Z. All pivots below are world coordinates at rest, ground Y 0.
- No crown, halo or head motif. Colours: cream, gold saddle, deep gold-brown paws, ink stockings and ear backs, azure foxfire tells.

### Body joints

| Joint | Moves | Parent | Pivot | Notes |
|---|---|---|---|---|
| JointRoot | Hips | HumanoidRootPart | (0, 5.77, 1.95) | the whole body bobs and pitches here |
| JointChest | Chest (ruff-less torso front, chest crescent) | Hips | (0, 5.77, 0.89) | spine bend |
| JointNeck | Neck (with Ruff and tufts) | Chest | (0, 6.39, -3.02) | |
| JointHead | Head (snout, brow, eyes, cheeks) | Neck | (0, 7.63, -4.62) | |
| JointJaw | Jaw, Chin | Head | (0, 7.19, -5.86) | + pitch opens |
| JointEarL / R | EarL / EarR (inner, back) | Head | (+-0.84, 8.83, -5.15) | roll +-0.3 flares |
| JointLegFL / FR | UpperLegF* | Chest | (+-0.98, 5.59, -2.66) | |
| JointLowerLegFL / FR | LowerLegF* | UpperLegF* | (+-0.98, 3.28, -2.66) | |
| JointPawFL / FR | PawF* | LowerLegF* | (+-0.98, 0.71, -2.66) | |
| JointLegBL / BR | UpperLegB* | Hips | (+-1.02, 6.04, 3.37) | |
| JointLowerLegBL / BR | LowerLegB* | UpperLegB* | (+-1.02, 3.28, 3.02) | knee |
| JointPawBL / BR | PawB* | LowerLegB* | (+-1.02, 1.42, 3.99) | hock |
| JointTail | Tail (gold hub) | Hips | (0, 6.83, 4.26) | moves the whole fan |

### Tails (36 motors, i = 1 far left .. 9 far right, 5 centre)

Each tail is four nested straight sleeves along its own axis, narrower each step (final studs, lengths x diameter): `Tail<i>` base 6.2 x 2.66 (gold), `Tail<i>Mid` 7.1 x 2.22 (gold to cream), `Tail<i>Tip` 7.1 x 1.77 (cream brush), `Tail<i>Whip` 7.5 x 0.71 (thin lance). Fur wedges are welded to the base and tip; `Tail<i>Flame` (Neon Tell, `TailIndex=i`) is welded at the whip end. Rest sleeve overlaps: mid 85% inside the base, tip 85% inside the mid, whip 95% inside the tip.

| Joint | Moves | Parent | Pivot | Sign convention |
|---|---|---|---|---|
| JointTail<i> | Tail<i> (base, fur) | Tail | the tail root (every tail hinges at the hub, e.g. tail 5 at (0, 7.19, 5.15)) | fan with roll `-t*k`, `t=(i-5)/4`; pitch -0.25 (forward) to +0.5 (swept back) |
| JointTail<i>Mid | Tail<i>Mid | Tail<i> | the base's mouth (tail 5: (0, 12.28, 8.71)) | slides along `ExtendAxis`; curl by small rotations |
| JointTail<i>Tip | Tail<i>Tip | Tail<i>Mid | the mid's mouth (tail 5: (0, 13.15, 9.32)) | same |
| JointTail<i>Whip | Tail<i>Whip | Tail<i>Tip | the tip's mouth (tail 5: (0, 14.02, 9.93)) | same |

Extension (translation): `Transform = rotation * CFrame.new(ExtendAxis * e)` with rotation LAST so the hinge stays at the parent's mouth at every extension. `ExtendAxis` is the unit tail direction in the parent frame at rest (identical for Mid, Tip and Whip of a tail):

| Tail | ExtendAxis | Tail | ExtendAxis |
|---|---|---|---|
| 1 | (-0.745, 0.386, 0.544) | 6 | (0.279, 0.903, 0.327) |
| 2 | (-0.713, 0.628, 0.313) | 7 | (0.457, 0.691, 0.560) |
| 3 | (-0.457, 0.691, 0.560) | 8 | (0.713, 0.628, 0.313) |
| 4 | (-0.279, 0.903, 0.327) | 9 | (0.745, 0.386, 0.544) |
| 5 | (0, 0.819, 0.573) | | |

`ExtendMax` (full travel, studs): Mid 3.90, Tip 3.90, Whip 4.90, so full extension adds 12.7 studs. Odd tails sit further back (larger +Z component) so the fan has depth.

- Reach from the tail root to the lance end: **8.72 at rest, 21.43 fully extended** (the brief's 10 / 24 at 2.4x; everything scales with 2.13). Half extension (e = 0.5) gives 15.1.
- At full extension each sleeve still overlaps its parent by 30% of its own length (minimum 0.30; the brief's floor is 0.25). Do not exceed `ExtendMax`. Take `e` as a fraction 0..1 of `ExtendMax`, not studs.
- Safe rotations (QA clean: no poke-through, no body hits, drift under 0.001):
  - `JointTail<i>`: pitch -0.25 .. +0.5 at any extension; roll up to `-t * 0.55` for fan spread at any extension (the outer tails then reach roughly horizontal; beyond that they droop into the hind legs); narrow fan up to `+t * 0.4`.
  - Mid / Tip / Whip curl: at rest and half extension up to +-0.1 / +-0.12 / 0.2 rad (the S curve) is invisible; at full extension keep bends under about 0.1 / 0.1 / 0.22 rad. Bends of 0.3 / 0.3 / 0.5 at full extension still keep the 30% overlap, but the child edge pokes about 0.9 studs past its parent's wall.
  - Plunge (rootfire eruption, tails 1,3,5,7,9 down): base pitch +1.0 with full extension plants the lance ends about 1 stud above the ground, clear of the hind legs. Pitch 1.7 with full extension sinks 8 studs below the floor and slices through the hind thighs, so scale the pitch down as extension rises (about 1.15 rad max at e = 1, larger only at lower extension) and keep the fan splayed (roll outward) so the odd tails clear `UpperLegB*`.
  - Low rest fan (roll `-t*0.55`) puts the outer tail tips about 5.1 above the ground; nothing in the tails reaches the floor in any rest, swept, raised or fanned pose.
- Detail parts carry a `Segment` attribute and are welded to their segment; names are unique so clips can key every joint.

### Tells, attachments and template

- Neon Tells (`Tell=true`, `TellBase` = original colour, pale azure #7FD8FF): `EyeL`, `EyeR`, `BrowMark`, `ChestMark` (neon disc under a cream cover so only the crescent shows), `Tail1Flame` .. `Tail9Flame` (`TailIndex`).
- Attachments (identity world rotation, ride their segment): `Mouth` (Head, snout tip), `Core` (Chest), `Throat` (Neck), `PawFL_FX`, `PawFR_FX`, `PawBL_FX`, `PawBR_FX` (ground under each paw), `TailRoot_FX` (Tail), `TailBase<i>_FX` (Tail<i>, at the root), `TailTip<i>_FX` (Tail<i>Whip, at the lance end, rides the extension).
- Template: HumanoidRootPart (invisible, identity rotation, PrimaryPart, Y 5.54), R15-type Humanoid with Animator, `HealthBar` on the HRP about 1 stud above the top (tail tips), identity-rotation WorldPivot, Atomic streaming, attribute `Scale = 2.13`, no scripts.

### Checks run

`check_rig.luau`: clean (132 parts). `keyframe_test.luau`: keyable (56 joints). `qa_nine_tail_fox_boss.luau`: 16 tail stress poses (rest, full, fanned, narrow, swept, raised, plunge, bends); reach, overlap and drift numbers above. Not checked by capture; the user reviews the look in Studio.
