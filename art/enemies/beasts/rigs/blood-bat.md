# Blood Bat (Iron-Winged, 48 parts, 13 joints, `build_blood_bat.luau` / `rig_blood_bat.luau`)

Part of [beasts/RIGS.md](../RIGS.md): read that file's shared rules first.


A small swarm flier (wind-blood), rebuilt 2026-10-22 (the first body read as "kind of eh"). The
hero is the wing: three dark-iron finger bones (`5E6470`) fanning from a high wrist, thin dark
crimson skin (`6E161E`) between them and a sawtooth (scalloped) trailing edge, the classic bat
"M" from the front. Second read: big ears with crimson insides (`8E2229`) over a pug face (rust
snout, two bone fangs `E8DEC8`, slanted red eyes, rust cheek tufts). Body black-red fur
(`2A1517`) with a rust mantle, chest bib and jaw (`7A3B36`). Tells are dim neon (`9E1824`, eyes
`C2202C`) until `BeastKit.tell` flares them. Wingspan 5.85 (bounding box 5.85 x 2.94 x 2.64),
body 1.3 long, ears to Y 6.35. 47 body parts + the HRP (the old body was 39 + 1). Standalone
export `art/enemies/beasts/export/BloodBat.rbxm` (template `BloodBat`; the main session merges it
into `Enemies.rbxm`). Faces -Z.

**Flier convention** (matches the Flame Raven, `workspace.Folder.Model.FlameRaven` in the
testbed): the model is built in place at hover height, the pivot is the HRP centre (not the
ground) with identity rotation, and the HRP floats with HipHeight = its bottom. **HRP** 2.6 x
2.4 x 2.6 centred at (0, 4.6, -0.2), bottom 3.4 (the raven's is 2.4 x 3 x 3 at Y 5, bottom
3.5), so a grounded player's melee box reaches it. Body centre Y 4.6, feet down to Y 3.7.
Root centre to the mouth (`Mouth` attachment) at rest: 1.3 studs forward (z -1.5 vs -0.2).

Every joint name, parent and pivot is unchanged by the rebuild:

| Joint | Moves (Part1) | Parent | Pivot | Notes |
|---|---|---|---|---|
| JointRoot | Body (+ Mantle, Chest, ChestCore, TailMembrane) | HRP | (0, 4.6, 0) | hover bob, banking (roll Z) |
| JointHead | Skull (+ Snout, eyes, fangs, cheeks) | Body | (0, 4.95, -0.6) | -X nods down |
| JointJaw | Jaw (+ MouthTell) | Skull | (0, 4.5, -0.65) | -X opens; reveals MouthTell |
| JointEarL / R | EarL / R (+ EarLB / EarRB, EarInL / R) | Skull | (+-0.38, 5.3, -0.85) | roll Z flicks them: a left ear tilts out with +Z, a right ear with -Z |
| JointWingL / R | WingL / R (upper arm + WingLSkin / WingRSkin) | Body | (+-0.5, 4.75, -0.2) | shoulder, **flap roll Z: L up = -Z, R up = +Z** |
| JointWingL2 / R2 | WingL2 / R2 (forearm + Skin, WingEdgeTell, WingClaw) | WingL / R | (+-1.2, 5.1, -0.4) | elbow, same signs |
| JointWingL3 / R3 | WingL3 / R3 (the hand: 3rd finger + Finger4, Finger5, Skin, Skin2) | WingL2 / R2 | (+-2.0, 5.3, -0.65) | wrist, same signs; pitch X sweeps it back/forward |
| JointLegL / R | LegL / R (+ FootL / R) | Body | (+-0.3, 4.2, 0.4) | small hanging feet; +X swings the foot forward |

Wing joints are the Flame Raven's convention (shoulder/elbow/wrist, roll about Z lifts), so
one flap cycle can drive both: at rest the wings sit about 25 degrees up (half spread);
a full downstroke is about 0.8 rad past rest on the shoulder, with the elbow and finger
lagging a beat. Yaw (Y) at the shoulder sweeps a wing back (L: +Y, R: -Y; measured).

**The hand is now big and trails back**: the 3rd finger runs out to the tip (+-2.81, 4.57,
-0.30), the 4th out and back, the 5th straight back to the forearm skin's far corner (about
(+-1.5, 5.3, 0.9)). The skins: `WingXSkin` (upper arm, a Part, thin on Y), `WingX2Skin` (forearm,
a right-triangle WedgePart), `WingX3Skin` and `WingX3Skin2` (the hand, WedgeParts; a wedge's
normal is its RightVector, not UpVector). They rest at elevations +0.50, +0.30 (outer edge up)
and -0.70 / -0.70 (outer edge down), each at or past the old +0.45 / +0.25 / -0.61, so the Flap
floor/ceil (shoulder >= 0.34, elbow >= 0.54, finger <= 0.74) still hold. Measured with
`qa_fliers_poses.luau` (now reading every `Wing*Skin*` part): every live move and loop keeps
>= 0.36. The arm skins billow slightly up toward the trailing edge so the usual camera (above,
in front) sees their tops.

**Tells** (Neon, `Tell = true`): `EyeL/R`, `MouthTell` (on the jaw top, inside the mouth,
visible when it opens), `WingEdgeTellL/R` (a strip on the iron forearm bone of WingL2/R2),
and `ChestCore` (the chest glow, set in the rust chest bib under the chin).

**FX attachments**: `Mouth` (Skull, (0, 4.6, -1.5), between the fangs), `Core` (Body, the
ChestCore's front, (0, 4.3, -0.77); was (0, 4.65, -0.95)), `WingTipL_FX` / `WingTipR_FX`
(WingL3 / WingR3, the 3rd finger's tip, (+-2.81, 4.57, -0.30); was (+-2.45, 4.85, 0.1)).

Gotchas: the membranes are 0.06 thick sheets, so they go edge-on from a level camera when
the wings are near flat; keep a V of 0.3 rad or more. Ears are forward-facing triangles
(two wedges) and read from the front. **The long hand meets the body when a wing is swept
far back**: the Stagger's COCK sweep (yaw 0.8 / 0.7 / 0.5 with the wing raised) puts the
wrist over the back and Finger4 / Skin2 / Finger5 into the Body and Mantle (QA: Stagger 42
samples, Death a few during the flail). Scaling the wing yaw to 0.7x in Stagger clears all of
it (probed). The raised forearm still brushes an ear for one or two samples in the dive, skid
and shriek recover, as on the old body. Checks: `check_rig.luau` clean (48 parts),
`keyframe_test.luau` keyable (13 joints).
