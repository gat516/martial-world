# ShadowManeWolfB (the user's reference body, 1.63x, brought in 2026-10-22)

Part of [wolf_family/RIGS.md](../RIGS.md): read that file's shared rules first.


`assets/Enemies.rbxm` template `ShadowManeWolfB`: the user's `ShadowManeWolf` kept as it looks, 6.5 x 9.1 x 21.3 studs, 106 parts, 26 motors (the shared skeleton plus JointMane, JointManeL/R and JointForelock; hocks `JointHockBL/BR` have a rotated frame at rest). Built by `art/enemies/beasts/bring_in_wave1.luau`. Attribute `Scale = 1.63` (the source carried a stale 1.15). `Wolf.scaled` multiplies JointRoot's translation by 1.63 once.

- Pivot, root: the pivot is the `HumanoidRootPart` (identity rotation, Y 4.866 = root height, feet on Y 0). The root is 6.53 x 8.42 x 21.25, centred on the body's X/Z bounds; the hips' `JointRoot` is at root-relative (0, 0.47, +2.16).
- Mouth is 10.48 studs in front of the root centre (Z -10.48, 5.15 up from the ground).
- Rest pivots root-relative (X, Y up from the root, Z): JointSpine (0, 0.75, 0.66); JointNeck (0, 1.03, -4.11); JointHead (0, 1.03, -6.17); JointMane (0, 2.15, -3.08); JointLegFL/FR (+-1.31, -0.28, -3.27); JointLegBL/BR (+-1.31, -0.19, 3.09). Ground-up: legs hip 4.59 / 4.68, elbow and knee 2.53, wrist 0.60, hock 1.16.
- Tells (Neon violet): `EyeL`, `EyeR`, and new thin bands `ManeTell1..3` (across the three dorsal mane wedges, Segment Mane) and `TailBrushTell` (across the brush, Segment TailTip), all with `TellBase`.
- Attachments: `Mouth` (Skull), `Core` (Chest), `PawFL_FX`, `PawFR_FX`, `PawBL_FX`, `PawBR_FX` (on each paw, at Y 0), `ManeTop_FX` (Mane, top of the mane, 8.50 up).
- `HealthBar` 1 stud over the top. check_rig clean, keyframe_test keyable (26 joints).
## Shadow Mane Wolf B: poses (`src/client/EnemyPoses/ShadowMane.luau`)

Animator pass (2026-10-22). Same pose API as `Wolf.luau`; its own leg solver, because this body's
legs are shorter and set forward of the Spirit Wolf's. The header comment lists every move with
its seconds and the `FAMILIES` move-name map; `qa_shadow_mane_poses.luau` is the numeric QA
(`_G.WOLF_POSE_SUMMARY = true` for one line per move phase; run it in a task.spawn, it takes ~2 minutes).

- **Unit space.** Pivots are the template's studs / 1.63 (hip 2.82, elbow and knee 1.55, wrist 0.37,
  hock 0.71; JointRoot (0, 3.28, 1.84)); `scaled(pose, 1.63)` multiplies the root translation once.
  The user's `newShadowManeWolfrest` / `...shadowWindup` models are already in unit space. The
  windup intent read from them: root -0.45, spine +0.08, neck -0.3, head +0.25, jaw -0.3, ears +0.5,
  tail -0.25 / -0.15 / +0.2, shoulders +0.45 / +0.3 with elbows -0.65 / -0.55, hips -0.35 / -0.25
  with knees +0.6 / +0.5 and hocks -0.3 / -0.25. The module reproduces the crouch (root, spine, neck,
  head, jaw, ears, tail) and lets the planting solver set the legs.
- **Paw soles** (measured on the geometry, claws included, relative to the pivot, unit space): front
  y -0.367, z -0.976 to +0.195, x +-0.32; hind y -0.712, z -1.068 to +0.029, x +-0.30. The toes run about
  a unit ahead of the pivots. A sole model that ignores this (a +-0.4 box) lets unplanted hind paws
  sink half a stud while the numbers say they are fine.
- **Which way the legs bend here.** A planted crouch bends the front elbow POSITIVE (+0.7 to +1.2) and
  the hind knee NEGATIVE (-0.3 to -0.7), the opposite of the signs in the shared table above. Author
  lifted or tucked legs with the same signs where they blend into or out of a plant: the floor clamp
  (`plant < 1` and a sole under the floor) re-solves the middle joint, and an authored sign opposite to
  the planted solution flips the branch (a 1.5 to 2.3 rad pop in one frame). Swing and air tucks
  (elbow -0.9, knee +0.5 with the hip forward) are fine when nothing is planted around them.
- **Hock frames are rotated** (C0 about X by 2.17 rad). A pitch on `JointHockBL/BR` still adds as a
  plain X pitch (same axis), so the solver's leveling works; a roll or yaw on a hock would not.
- **Fur.** JointMane -X lifts, +X streams back. ManeL/ManeR: -Z / +Z flare up and out (spread); their X
  pitch below about 0.3 (laid forward) swings them into the shoulder blocks and the forelock, so
  `fur()` floors the strand pitch at 0.3. A raised forepaw sweeps through its own side's strands: the
  module sweeps those strands back (A(0.8, 0, -+0.3)) while the paw is up (folding them down made the
  clip worse). Ears pinned past about 0.5 clip into the neck strands (cap 0.5).
- **Tested ranges** (clean: no gap, clip, sink): root drop to -1.0 studs (unit) in the shadow-step
  load; hind knee to -1.15 with hock +0.55 in the skid scrabble; front elbow to +1.2 planted; spine
  yaw 0.34 / -0.42 in the lash with the forepaws unplanted. Planted forepaws cannot follow a spine yaw
  past about 0.25 (the root drops 1.7 studs to reach the old spots): unplant them or shorten the twist.
- **Known tolerances:** hind lower leg / paw merges to 0.3 when the hind legs fold (skid, gallop);
  gallop and fast-walk swing elbows reach -1.4 to -1.8 (the swing fold); the lash whip leaves the right
  strands 0.18 into the upper foreleg. All are RANGE / MERGE notes with no gap, sink or large clip.
- **Gait calibration** (forward kinematics of the stance paw pivots): the walk's stance paws move at
  0.83 (1.5 studs/s) to 0.67 (5+) of the body speed at the nominal stride, so `gaitRate` divides by that
  sweep factor; the gallop measures 1.0 to 1.2 (touchdown frames included).
