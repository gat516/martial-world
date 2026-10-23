# Venom Serpent (13 joints)

Part of [beasts/RIGS.md](../RIGS.md): read that file's shared rules first.


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
## VenomSerpentB (the user's reference body, 1.40x, brought in 2026-10-22)

`assets/Enemies.rbxm` template `VenomSerpentB`: the user's row body `workspace.Folder.Model.VenomSerpent`, 5.13 x 7.00 x 15.93 studs, 84 parts, the 13 joints above. The old roster `VenomSerpent` template is a 17-part, joint-less stand-in (4.6 x 5.6 x 5.4), so it does not match; `VenomSerpentB` is the row body, kept exactly. Attribute `Scale = 1.40`.

- Pivot, root: the pivot is the `HumanoidRootPart` (identity rotation, Y 2.379 = root height, feet/coil on Y 0). The root is 5.13 x 4.76 x 15.93, invisible, centred on the body's X/Z bounds.
- Mouth is 7.09 studs in front of the root centre (Z -7.09, 5.66 up), the head at player height.
- Rest pivots root-relative (X, Y up from the root, Z): JointRoot (0.67, -1.49, -2.25); JointNeck (0.04, -1.47, -3.16); JointHead (0.04, 3.29, -4.84). The rest of the table above applies; full numbers via `joint:GetPivot`-style reads of `Part0.CFrame * C0`.
- Tells (Neon): `EyeL`, `EyeR`, `VenomSacL`, `VenomSacR`, `HoodSpotL`, `HoodSpotR`.
- Attachments: `Mouth` (Skull), `SacL_FX`, `SacR_FX` (on the sacs), `TailTip_FX` (Tail5, at the barb tip, on the ground).
- `HealthBar` 1 stud over the top. check_rig clean, keyframe_test keyable (13 joints).
