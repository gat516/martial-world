# Blood Centipede (128 parts, 43 joints, `build_blood_centipede.luau` / `rig_blood_centipede.luau`)

Part of [beasts/RIGS.md](../RIGS.md): read that file's shared rules first.


QC6 earth-blood demon centipede, rebuilt 2026-10-22 (the first body read as weak). A long, low
armoured line of overlapping crimson shingles with a fringe of jointed legs, led by a broad flat
head and a pair of big curved bone pincers (the hero shape). Palette: black-red belly and maw
(`2A1014`), deep crimson slab rims and head capsule (`3C0E12`), crimson caps, head shield, femurs
and pincer bases (`A0242A`), bone claws, pincer shafts and hooks, brow ridges, rear spine tips and
antenna tips (`D9CAA6`), and dim neon Tells (`6A1A12`) that `BeastKit.tell` flares.

Body 15.6 studs nose to rear spines (-7.6..8.0; the pincer hooks reach about -9.4, the antennae
-8.7), 6.5 wide with the legs out (3.35 at the head shield), 2.67 at the head crest, 2.4 at the
collar cap tapering to 1.8 at Seg12, 2.91 at the antenna tips (the burrow's sink 3.4 still buries
everything: BurrowDive ends at top -0.57, Erupt starts at -0.33). Standalone export:
`art/enemies/beasts/export/BloodCentipede.rbxm` (template `BloodCentipede`; the main session merges
it into `Enemies.rbxm`). Faces -Z. The line runs Skull (front) -> Collar -> Seg1..12 -> Tail.

**Plates.** Each plate (Collar, Seg<i>, Tail) is a shingle in its own frame tilted 0.06 rad (back
edge up): the segment part is a wide WedgePart slab (thin at the front, 0.38-0.5 thick at the back)
that overhangs the plate behind by 0.28; `<seg>Cap` is a narrower, taller crimson wedge on it (the
ridge, so the side view is a sawtooth); `<seg>Belly` is the black block under it, reaching 0.12
under each neighbour. `SeamTell<i>` lies on the slab slope in the trough just behind the plate in
front's overhang (`CoreGlow` is the collar's, under the head shield's back edge). Skull: `Skull`
(the dark capsule; eyes and maw on its front), `SkullShield` (broad crimson wedge, thin at the
nose), `SkullCrest`, bone `BrowL/R`. Pincers: `Jaw<side>` (crimson base), `Jaw<side>Shaft`,
`Jaw<side>Hook`, `PincerTell<side>` on the base's top. Legs: `Leg<side><i>` (crimson femur, out and
up to a knee 0.3 above the slab underside) and `Leg<side><i>Claw` (bone wedge tapering to the foot,
which trails the hip by 0.45). Tail: `Tail`, `TailCap`, `TailBelly`, `SpineL/R` and `SpineTipL/R`
(the rear spines, raked up and out).

**HRP** (the hit volume): 3.2 x 2.5 x 15.6, centred at (0, 1.3, 0.2), so z -7.6..8.0 covers the
whole line (pincers and antennae excluded); bottom 0.05 above the ground, HipHeight 0.05. Model
pivot = the HRP centre, identity rotation. Health bar 1 stud over the top (3.91).

| Joint | Moves | Parent | Pivot (rest, model space) | Notes |
|---|---|---|---|---|
| JointRoot | Collar (the root plate) | HRP | (0, 1.3, -4.9) | unchanged |
| JointHead | Skull | Collar | (0, 1.4, -5.4) | unchanged; pitch nods the head; carries eyes, shield, crest, brows, maw |
| JointJawL/R | JawL/R (base, shaft, hook, tell) | Skull | (+-1.0, 1.18, -6.95) | **moved** from (+-0.95, 1.0, -7.1); yaw closes it: JawL closes with -Y, JawR with +Y |
| JointAntL/R | AntL/R (with tip) | Skull | (+-0.72, 1.84, -6.95) | **moved** from (+-0.7, 2.2, -6.9); yaw sweeps, pitch lifts (-X = down) |
| JointSeg1..12 | Seg<i> plate | Seg<i-1> (Seg1: Collar) | (0, 1.2, -4.3 + 0.8 (i-1)) | unchanged (the pose module's NODE table) |
| JointLegL<i> / JointLegR<i> | femur + claw | Seg<i> | (+-(w/2 - 0.12), yb - 0.1, plate front + 0.42) | **moved** inboard and up: under the slab rim, e.g. Leg1 (+-1.43, 1.40, -3.88), Leg12 (+-0.95, 1.05, 4.92) (was (+-(w/2+0.1), 0.95, plate centre)); w = 3.1 -> 2.15, yb = 1.5 -> 1.15 from Seg1 to Seg12. Y swings it fore/aft, Z lifts: a left leg lifts with -Z, a right leg with +Z |
| JointTail | Tail (end plate + spines) | Seg12 | (0, 1.2, 5.3) | unchanged |

Sign conventions are the shared ones above (X pitch, Y yaw, Z roll). Jaws: the hooks rest about
1.1 apart at the tips; about 0.5 rad each way closes them (the hooks then cross a little in front of
the maw, which reads as the bite). Legs now leave the body higher and further in, so the same lift
raises a foot a little more than before.

**Tells** (Neon, `Tell = true`, dim `6A1A12` at rest): `EyeL/R` (capsule front, turned 0.35 rad
out), `PincerTellL/R` (on the pincer bases' tops), `SeamTell1..12` (in each plate's trough),
`CoreGlow` (the collar's trough, under the head shield).

**FX attachments**: `Mouth` (Skull, (0, 1.1, -8.3), between the pincers where they close; it was
-7.8, moved forward with the longer pincers), `Core` (Seg3, on the back), `Seg6_FX` (Seg6, on the
back), `TailTip_FX` (Tail, (0, 1.2, 8.19), behind the spines).

Gotchas: every segment, leg and detail has a unique name. Plates and bellies overlap their
neighbours, so a bend of up to about 0.25 rad per joint shows no gap. The pose QA
(`qa_blood_centipede_poses.luau`, `_G.CP_TARGET = "_RosterBeasts"` for the staging body) is clean on
the new body: no sunk, gap, clip or merge flags over 547 poses (only the known 0.263 clamped step in
a hard run turn). Its new LEGCLIP pass shows the leg ripple swings neighbouring legs through each
other (depth up to 0.47, on the old body too, up to 0.43), and femurs graze the neighbouring slab
undersides by up to 0.19 when they swing far fore/aft (hidden under the plate rims). Checks:
`check_rig.luau` clean, `keyframe_test.luau` keyable (43 joints).
