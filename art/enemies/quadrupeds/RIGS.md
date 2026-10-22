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
- Poses live in `src/client/EnemyPoses/StoneTortoise.luau` (Wolf.luau's format, **unit space**: authored on this 1x rig, EnemyAnimator scales the translations by 1.76 once with `scaled`; header lists the moves, timings and move-name map). Its own planter (the legs have no middle joint, so `Quadruped.plant` doesn't apply): a planted foot is held at rest + `reach` (x, y = lift, z); the leg swings from the hip toward it, stays world-upright, and slides along its axis (JointLeg translation) for the rest, the ankle levels the foot. Author the shell/neck/head/tail, the legs follow. QA: `qa_stone_tortoise_poses.luau` (config on `Enemies.StoneTortoiseB`, scale 1.76; run it through `loadstring` of the 8767 file server after `push_src`).
- **Tested clean:** shell root y +0.62 / pitch +0.35 (stomp peak, hind feet planted, fore legs hanging at `JointLegF*` +0.3 / `JointFootF*` -0.65) and y -0.77 (shell on the ground: belly bottom y 0.85 at rest, so -0.8 sinks it); neck z -0.45 (bite) to +2.3; jaw -0.5 at neck z -0.4 (more, with head pitch below about -0.1, sinks the jaw into the ground), jaw -0.36 at neck +0.5 (-0.45 clips the shell's lip); tail up (-0.3) in a deep tuck (a drooping tail sinks).
- **A lifted foot goes into the belly.** The foot's inner edge (x 1.9) is under the belly (x to 2.7, bottom y 0.85) and the foot top is 0.75, so any swing lift past about 0.1 clips unless the foot steps out: the walk steps out 0.55 (hind 1.5x) with lift 0.38. The turn shuffle still merges the hind swing foot about 0.5 deep (hidden from the side).
- Feet drawn into the rim (tuck, death) are lifted 0.9 and pulled in 0.2 (`reachAll(-0.2, 0.9, 0)`): the foot ends inside the shell mass, which the QA allows for those poses only.

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

## NineTailFoxB (boss body, Scale 2.13, 56 joints, 195 parts)

Template `NineTailFoxB` in `assets/Enemies.rbxm` (testbed-only gate). Scripts: `build_nine_tail_fox_boss.luau`, `rig_nine_tail_fox_boss.luau`, `nine_tail_fox_boss_tails.luau` (shared tail numbers and look), `qa_nine_tail_fox_boss.luau` (tail stress poses), `preview_nine_tail_fox_boss.luau` (posed copies for captures), `promote_nine_tail_fox_boss.luau`.

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

Rebuilt 2026-10-21: the first tails were four nested cylinders per tail and read as telescope tubes (rejected). **The kinematics did not change**: same pivots, `ExtendAxis`, `ExtendMax` and formula, so pose code written against the first body still works. Only the parts on each segment changed (no cylinders anywhere). Final studs, length x width across the fan x depth through it:

| Segment (Motor6D) | Parts | Look | At rest | As it extends |
|---|---|---|---|---|
| `Tail<i>` (JointTail<i>) | stem 6.0 x 1.11 x 1.11, `Tail<i>FurA` tuft on the inner edge | gold | first 3.0 studs show, the rest is inside the brush | stays put |
| `Tail<i>Mid` (JointTail<i>Mid) | neck 5.4 x 0.75 x 0.75, `MidFurA` / `MidFurB` tufts flaring toward the tip | gold to cream | hidden | slides out from under the stem's tuft and flares into the brush |
| `Tail<i>Tip` (JointTail<i>Tip) | brush 4.26 x 1.33 x 1.64, fluff tufts `FurC` / `FurD` (about 1.95 across), `TipEnd` flick (1.6 long, flat on the outer edge, sloping to a point) | cream | the main visible body of the tail | moves out with its neck |
| `Tail<i>Whip` (JointTail<i>Whip) | `Tail<i>Whip` lance 3.86 x 0.27 (Neon Tell, offset 0.22 toward the outer edge), tip spindle `WhipFurA` / `WhipFurB` (2.66 long, 0.98 x 0.89), `Tail<i>Flame` ball 1.15 + `Tail<i>FlameTip` tongue 1.95 (Neon Tells) | cream tip, azure foxfire | only the flame shows, past the brush's point | the spindle and flame run ahead of the brush; the lance glows in the gap past e = 0.62 (about 1.9 studs at full) |

"Outer edge" = away from the fan's centre (tails 6-9 toward +X, 1-5 toward -X): the brush end, spindle and flame tongue keep a flat face there, so every tail ends in a flick curling outward.

| Joint | Moves | Parent | Pivot | Sign convention |
|---|---|---|---|---|
| JointTail<i> | Tail<i> (stem, tuft) | Tail | the tail root (every tail hinges at the hub, e.g. tail 5 at (0, 7.19, 5.15)) | fan with roll `-t*k`, `t=(i-5)/4`; pitch -0.25 (forward) to +0.5 (swept back) |
| JointTail<i>Mid | Tail<i>Mid (neck, tufts) | Tail<i> | 6.21 along the axis (tail 5: (0, 12.28, 8.71)) | slides along `ExtendAxis`; curl by small rotations |
| JointTail<i>Tip | Tail<i>Tip (brush, fluff, flick) | Tail<i>Mid | 7.28 along the axis (tail 5: (0, 13.15, 9.32)) | same |
| JointTail<i>Whip | Tail<i>Whip (lance, spindle, flame) | Tail<i>Tip | 8.34 along the axis (tail 5: (0, 14.02, 9.93)) | same |

Extension (translation): `Transform = rotation * CFrame.new(ExtendAxis * ExtendMax * e)`, `e` a fraction 0..1, rotation LAST so the hinge stays at the parent's mouth at every extension. `ExtendAxis` is the unit tail direction in the parent frame at rest (identical for Mid, Tip and Whip of a tail):

| Tail | ExtendAxis | Tail | ExtendAxis |
|---|---|---|---|
| 1 | (-0.745, 0.386, 0.544) | 6 | (0.279, 0.903, 0.327) |
| 2 | (-0.713, 0.628, 0.313) | 7 | (0.457, 0.691, 0.560) |
| 3 | (-0.457, 0.691, 0.560) | 8 | (0.713, 0.628, 0.313) |
| 4 | (-0.279, 0.903, 0.327) | 9 | (0.745, 0.386, 0.544) |
| 5 | (0, 0.819, 0.573) | | |

`ExtendMax` (full travel, studs): **Mid 3.90, Tip 3.90, Whip 4.90**, so full extension adds 12.71 studs. Each segment's offset from rest along the axis at extension e: neck `3.90e`, brush `7.80e`, lance/flame `12.71e`.

- Reach from the tail root to `TailTip<i>_FX` (the flame ball's centre, 0.16 past the old lance end): **8.87 at rest, 15.2 at half, 21.6 at full**. The flame tongue reaches 1.95 further: about 10.8 at rest and 23.5 at full. The joint-chain lance end the pose module uses without `configure` is still 8.72 / 21.43.
- Safe rotations (qa_nine_tail_fox_boss: no gaps, no exposed back ends, nothing through the body):
  - `JointTail<i>`: pitch -0.25 .. +0.5 at any extension; roll up to `-t * 0.55` for fan spread; narrow fan up to `+t * 0.4`. Plunge (odd tails pitched +1.0 at full extension) plants the flames about 1 stud above the ground; 1.15 with a splayed roll (`-t * 0.9`) sinks 8 into the floor (meant for the eruption only).
  - Mid / Tip / Whip curl: the pose module's default S curve (`shp`, curl 0.6: Mid pitch 0.042, Tip 0.054, Whip 0.12 with rolls up to 0.03 / 0.036 / 0.06, scaled by `1 - 0.45e`) is clean at every extension. **At rest the Whip curl only tilts the flame, and the hidden lance runs 5 studs behind its hinge**: Whip pitch beyond about 0.12 (or roll beyond about 0.06) at e < 0.3 pushes the lance through the brush (curl x1.5 at rest: 0.22 out). Let the Whip curl grow with extension instead: at e >= 0.5 up to 0.2, at full up to 0.22 (0.5 bends still keep everything joined, the lance's back end shows about 0.05). Mid / Tip up to 0.1 / 0.12 at any extension.
- Detail parts carry a `Segment` attribute and are welded to their segment; names are unique so clips can key every joint.

### Tells, attachments and template

- Neon Tells (`Tell=true`, `TellBase` = original colour, pale azure #7FD8FF): `EyeL`, `EyeR`, `BrowMark`, `ChestMark` (neon disc under a cream cover so only the crescent shows), `Tail<i>Flame` (ball), `Tail<i>FlameTip` (tongue) and `Tail<i>Whip` (the lance), all with `TailIndex = i`. The tail flames are saturated azure #3C93E6 (the user's reference colour; pale tints bloom to white) until the vfx repaints them by phase.
- Attachments (identity world rotation, ride their segment): `Mouth` (Head, snout tip), `Core` (Chest), `Throat` (Neck), `PawFL_FX`, `PawFR_FX`, `PawBL_FX`, `PawBR_FX` (ground under each paw), `TailRoot_FX` (Tail), `TailBase<i>_FX` (Tail<i>, at the root), `TailTip<i>_FX` (Tail<i>Whip, at the flame ball's centre, rides the extension).
- Template: HumanoidRootPart (invisible, identity rotation, PrimaryPart, Y 5.54), R15-type Humanoid with Animator, `HealthBar` on the HRP about 1 stud above the top (tail tips), identity-rotation WorldPivot, Atomic streaming, attribute `Scale = 2.13`, no scripts.

### Checks run

`check_rig.luau`: clean (195 parts). `keyframe_test.luau`: keyable (56 joints). `qa_nine_tail_fox_boss.luau`: 18 tail poses (rest curl at e 0 / 0.25 / 0.5 / 0.75 / 1, straight, curl x1.5, fan, narrow, swept, raised, plunges, bends); numbers above. Captured at rest, half and full extension, fanned and plunged (behind, 3/4 and side).

### Animating NineTailFoxB (`src/client/EnemyPoses/NineTailFox.luau`)

- The module is unit space (old roster fox, pivots = the tables above / 2.13); `NineTailFox.scaled(pose, 2.13)` multiplies the JointRoot translation AND every tail slide. Call `NineTailFox.configure(model)` once with the template: it reads `ExtendAxis`/`ExtendMax`, the pivots and the `TailTip<i>_FX` lance end, so a rebuilt tail needs no edit. Tail formula: `Transform = rotation * CFrame.new(ExtendAxis * ExtendMax * e)`.
- **The legs are straight at rest** (hip to paw pivot = full leg length), so ANY body drop bends the elbows and hocks hard: 0.2 unit of drop is already about 0.8 rad of elbow bend, the deep crouches reach -2.0. Gaits therefore stay at a root drop of about 0.26 (walk) / 0.3 (run); a crouch of more than about 0.5 unit clips the head and neck into the forearms (0.4-0.7 studs) and the hind knee balls into the hips (0.5-0.9).
- Planting: stance paws are IK-placed by `plantLegs` with a reach that slides at exactly the ground speed; swing paws are IK-placed on their arc too and then lifted with `solveLeg(clear)` (so lift-off and touchdown meet the stance exactly). A planted leg far past its reach drops the whole root by the shortfall and the drop jumps when that leg lifts, so the gait keeps a crouch baseline larger than any shortfall (this is what keeps skate under 0.2 studs/s mean).
- Rolled body: after a roll of about 1.5 (Death) the body's left is down, so a tail leaning left points into the floor; fan the tails in (negative fan, about -1.1) to lie them along the ground. Pitching a tail then sweeps it about a vertical axis, so a height solve needs roll, not pitch.
- Plunge solver: `NineTailFox.groundQ(i, pose, az, e, tipY)` iterates pitch (height) and yaw (azimuth) on the posed body (the root tilt makes them interact); the lance end lands within 0.0-0.4 studs of the floor. Plunges forward must keep az at 40 degrees or more off the facing line or the sleeve passes through the chest and neck.
- Whip bend: at extension below 0.3 keep the whip pitch within 0.12 and roll within 0.06 (the module clamps it); the other bends stay inside 0.1 / 0.1 / 0.22 at full extension.
- A tail 21 studs long swung round a flipping body sweeps through the floor even with an 8-stud arc: MoonLeap flares the tails on take-off, snaps them short for the inversion and flares again for the landing (lowest part 0.08 above the floor with the 8-stud arc).
- Tools: `gait_fox.luau` (per-paw skate, contact, root bounce), `qa_nine_tail_fox_poses.luau` (one move or loop per call, optional variant), `qa_quadruped_poses.luau` config `NineTailFox`.
- **Tail floor guard (2026-10-21 pass):** `configure` now reads every visible tail part's box per segment plus the real pivots, and `tailLow(i, pose, q)` returns the lowest point of the whole tail (brush, fluff, spindle, flame tongue), not just the flame centre. Every move's floor guard eases a tail toward its safe shape until all of its parts clear 0.03 unit; plunging tails (`ground`) still guard only the lance end, so their flames stab into the floor on purpose (Rootfire, NineTailFall show about -0.55 there in the QA, expected). Before this the brush and flame sank 0.7-1.2 studs in Intro, Stagger, VeilBreak, MournfulScream and Death (tail 4 base -0.96).
- **Follow-through spring:** moves (not loops) add a stateless damped-spring correction to Root, Chest, Neck, Head, Jaw, ears and the tail hub (`SPRING` table: delay, Hz, damping, gain, cap). The keyed pose without overlays is sampled on a 0.05 s grid back 0.5 s across phase boundaries; the correction saturates at `cap` (0.07 rad root .. 0.35 ears) so a rear-to-slam snap can't fold the head into the floor (uncapped, VeilBreak's slam put the head 1.2 studs into the ground). Cost about 0.6 ms a frame per fox. Overlay-driven phases (`keepOverlay`, the pounce bound) skip it.
- **Head guard:** after the legs plant, `guardHead` tests Neck/Head/Jaw boxes against the fore legs (box pairs that already touch at rest are ignored) and lifts the neck and head by the least amount that clears them (bisection, slack 0.02). It runs in every move and in walk/run/circle. It removed the neck/forearm clips in run, circle, FangDance, TailLance, LanceFan, MournfulScream and most of VeilBreak. It cannot fix clips where the forearm folds up into the neck (Intro curl, Pounce coil, NineTailFall recover, Death).
- **QA config:** tails are now checked against the body (tail-vs-tail is skipped, the fan nests by design) and the allowances are tight: knee/hips and elbow/chest 0.3, neck/forearm 0. `_G.QP_MERGEOK` overrides them.
- **Still open (numbers from qa_nine_tail_fox_poses, studs):** hind knee into hips walk 0.48, run 0.68, Pounce 0.78, Death 0.87, MoonLeap 0.59; Intro curl paw/thigh 0.89, play-bow paw/paw 0.40, Hips/hind paw 0.31; FoxfireVolley tails through ears and head up to 0.75 (windup 0.8-0.9); Rootfire plunging tails 1, 9 through the chest 1.7 (recover) and tail 5 through the ears 0.86; NineTailFall tail 1 through the chest 1.44 and hips 0.88, head/forearm 0.34; TailSweep tail 8 through the left ear 0.35; Pounce forearm/neck 0.35 and lower-leg range -2.08; Death hind paw in hips 0.72. The walk is unchanged (still the quick bent-legged glide). B/C variants not re-run.

## StoneTortoiseB (the user's reference body, 1.76x, brought in 2026-10-22)

`assets/Enemies.rbxm` template `StoneTortoiseB`: the user's `StoneTortoise_R` kept as it looks, 13.3 x 13.9 x 22.0 studs, 86 parts, 14 joints with the names and hierarchy above. Brought in by `art/enemies/beasts/bring_in_wave1.luau`. Attribute `Scale = 1.76`. The numbers in the table above are at 1x: multiply every translation by 1.76.

- Pivot, root: the pivot is the `HumanoidRootPart` (identity rotation, Y 4.23 = the root height, feet on Y 0). The root is 13.32 x 8.46 x 21.97, invisible, centred on the body's X/Z bounds, so the shell's pivot is 1.48 studs behind it; `JointRoot` is at root-relative (0, 0, +1.48).
- Mouth (beak tip) is 10.84 studs in front of the root centre (Z -10.84, 3.44 up from the ground).
- Rest pivots, ground-up (Y) and relative to the shell's pivot (X, Z): JointNeck (0, 3.97, -5.82); JointHead (0, 4.23, -8.64); JointJaw (0, 3.44, -8.72); JointLeg F (+-4.58, 3.70, -4.76), B (+-4.58, 3.70, +4.93); JointFoot (+-4.85, 1.32, same Z); JointTail (0, 3.00, +6.87); JointTailTip (0, 2.20, +8.37; its frame is rotated at rest).
- Neck slide at 1.76x: full tuck z +4.05 (1x 2.3), half in +1.06 (0.6), stretched -0.70 (-0.4). Stomp windup: root +0.97 up (1x 0.55), pitch +0.32 unchanged, hind legs `CFrame.new(0, 0.60, 0) * pitch(-0.32)` (1x 0.34). Shell-guard tuck: root -0.88, legs translated up 0.88 (1x 0.5).
- Tells (Neon, `Tell`, `TellBase`): `SeamTell1`, `SeamTell-1`, `SeamTellFront`, `SeamTellBack`, `SeamTellCrack11/-11/12/-12`, `SeamTellCrackCap` (renamed from `Seam*`/`Crack*`), `EyeL`, `EyeR`, `BrowMark`.
- Attachments: `Mouth` (Head), `Core` (Shell centre, 7.68 up), `NeckBase_FX` (Shell, at the front lip, 3.97 up), `FootFL_FX`, `FootFR_FX`, `FootBL_FX`, `FootBR_FX` (on each foot, at Y 0 under it).
- `HealthBar` 1 stud over the top. check_rig clean, keyframe_test keyable (14 joints).
