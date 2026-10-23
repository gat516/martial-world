# StoneTortoise_R (14 joints)

Part of [quadrupeds/RIGS.md](../RIGS.md): read that file's shared rules first.


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
## StoneTortoiseB (the user's reference body, 1.76x, brought in 2026-10-22)

`assets/Enemies.rbxm` template `StoneTortoiseB`: the user's `StoneTortoise_R` kept as it looks, 13.3 x 13.9 x 22.0 studs, 86 parts, 14 joints with the names and hierarchy above. Brought in by `art/enemies/beasts/bring_in_wave1.luau`. Attribute `Scale = 1.76`. The numbers in the table above are at 1x: multiply every translation by 1.76.

- Pivot, root: the pivot is the `HumanoidRootPart` (identity rotation, Y 4.23 = the root height, feet on Y 0). The root is 13.32 x 8.46 x 21.97, invisible, centred on the body's X/Z bounds, so the shell's pivot is 1.48 studs behind it; `JointRoot` is at root-relative (0, 0, +1.48).
- Mouth (beak tip) is 10.84 studs in front of the root centre (Z -10.84, 3.44 up from the ground).
- Rest pivots, ground-up (Y) and relative to the shell's pivot (X, Z): JointNeck (0, 3.97, -5.82); JointHead (0, 4.23, -8.64); JointJaw (0, 3.44, -8.72); JointLeg F (+-4.58, 3.70, -4.76), B (+-4.58, 3.70, +4.93); JointFoot (+-4.85, 1.32, same Z); JointTail (0, 3.00, +6.87); JointTailTip (0, 2.20, +8.37; its frame is rotated at rest).
- Neck slide at 1.76x: full tuck z +4.05 (1x 2.3), half in +1.06 (0.6), stretched -0.70 (-0.4). Stomp windup: root +0.97 up (1x 0.55), pitch +0.32 unchanged, hind legs `CFrame.new(0, 0.60, 0) * pitch(-0.32)` (1x 0.34). Shell-guard tuck: root -0.88, legs translated up 0.88 (1x 0.5).
- Tells (Neon, `Tell`, `TellBase`): `SeamTell1`, `SeamTell-1`, `SeamTellFront`, `SeamTellBack`, `SeamTellCrack11/-11/12/-12`, `SeamTellCrackCap` (renamed from `Seam*`/`Crack*`), `EyeL`, `EyeR`, `BrowMark`.
- Attachments: `Mouth` (Head), `Core` (Shell centre, 7.68 up), `NeckBase_FX` (Shell, at the front lip, 3.97 up), `FootFL_FX`, `FootFR_FX`, `FootBL_FX`, `FootBR_FX` (on each foot, at Y 0 under it).
- `HealthBar` 1 stud over the top. check_rig clean, keyframe_test keyable (14 joints).
