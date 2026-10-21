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
- Charge windup: head and neck down about -0.3 total, one fore hoof pawing (`JointLegFL` +1.0, `JointLowerLegFL` -1.35, `JointHoofFL` +0.6) and the haunches loaded.

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
