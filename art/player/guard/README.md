# Guard animations (player, R6)

`Guard.rbxm` holds a Folder `Guard` with three KeyframeSequences; `clips/` has
each one as its own `.rbxm` for uploading. They key only
Neck (Head pose), Left and Right Shoulder (arm poses) and a small RootJoint lean
(at most 0.1 rad pitch, 0.16 rad twist). Legs are unkeyed, so walking plays
underneath. They are authored for the R6 rig, bare-handed or with a weapon in the
right hand: right forearm raised across the chest, left hand braced beside it,
chin tucked, slight forward lean.

| Clip | Length | Loop | Priority | Markers |
|---|---|---|---|---|
| GuardHold | 1.2 s | yes | Action | none (first frame is the guard pose; fade in 0.08 s in code) |
| GuardParry | 0.40 s | no | Action2 | `Contact` at 0.07 s (the deflect snap) |
| GuardImpact | 0.25 s | no | Action2 | none |

GuardParry and GuardImpact start and end on exactly the GuardHold pose.
Guard break needs no clip (the existing stagger plays).

## Published

Uploaded with `python3 tools/upload_asset.py animation art/player/guard/clips/*.rbxm`
(group 772472600, testbed universe granted Use), in `Animations.Guard`:

| Clip | Animation | Id |
|---|---|---|
| GuardHold | `Guard.Hold` | rbxassetid://78908975484990 |
| GuardParry | `Guard.Parry` | rbxassetid://123895539094624 |
| GuardImpact | `Guard.Impact` | rbxassetid://136933091358616 |

Ids are immutable: after changing a clip, re-upload it and swap the id.

## Per-class guards: Fist, Sword, Saber

Built by `build_guard_clips.luau` (load it into a ModuleScript in a sandbox
Studio and call `build()`, `qa()`, `play()`): poses are written as Torso-space
targets (right-hand point, blade direction, left-hand point or "palm on the
spine N studs up the blade") and solved into joint rotations through the rig's
real C0/C1, so the files are ordinary keyframes that open in Moon Animator and
the Animation Editor. `<Class>/<Class>.rbxm` holds a Folder `<Class>` with the
four KeyframeSequences; `<Class>/clips/` has each as its own `.rbxm` for
uploading.

Every clip keys Torso (RootJoint), Head (Neck), Left and Right Arm, and for
weapons the weapon joint under Right Arm (`HiltR` for the jian, `Hilt` for the
dadao), the same Motor6D the M1 clips key to angle the blade. Legs are unkeyed,
so walking plays underneath. Hold is Action and loops (2.0 s breath); Parry,
ParryAlt and Impact are Action2 and start and end on exactly the Hold pose, so
Parry, Hold, ParryAlt, Hold chain at 0.3-0.4 s intervals and auto-parries
alternate sides. `Contact` is the deflect snap (the parry flash and sound go
there).

- **Fist**: cross hands (shizi shou), wrists crossed in front of the chest.
  Parry: the right palm catches and leads the strike out to the right while the
  torso turns into it, the left palm guards the centre. ParryAlt: the same with
  the left palm, out to the left. Impact: the crossed wrists are driven in
  toward the chest, the body leans back.
- **Sword (jian)**: hanging guard, hand high on the right, blade slanting down
  across the front of the body (edge out), left sword-finger arched above the
  head. Parry: a wrist flick (tiao) that whips the tip up and out to the right.
  ParryAlt: the blade sweeps flat to the left and wraps past the left side
  (lan). Impact: the blade is shoved back and up, the torso gives.
- **Saber (dadao)**: spine-braced block, blade diagonal up and to the left
  across the front, edge out, the left palm pressing its back. Parry: a heavy
  beat-aside to the right (big torso turn, the left hand lets go and swings
  back). ParryAlt: a heavy beat down and to the left with the palm still on the
  spine. Impact: blade and arms shoved back, palm stays on the spine.

| Class | Clip | Length | Priority | Contact | Id |
|---|---|---|---|---|---|
| Fist | FistGuardHold | 2.00 s loop | Action | | rbxassetid://108492729753096 |
| Fist | FistGuardParry | 0.34 s | Action2 | 0.07 s | rbxassetid://71662429635317 |
| Fist | FistGuardParryAlt | 0.34 s | Action2 | 0.07 s | rbxassetid://93556726100571 |
| Fist | FistGuardImpact | 0.25 s | Action2 | | rbxassetid://124944232562174 |
| Sword | SwordGuardHold | 2.00 s loop | Action | | rbxassetid://92408659576565 |
| Sword | SwordGuardParry | 0.34 s | Action2 | 0.07 s | rbxassetid://91170775084983 |
| Sword | SwordGuardParryAlt | 0.34 s | Action2 | 0.07 s | rbxassetid://105266736550165 |
| Sword | SwordGuardImpact | 0.25 s | Action2 | | rbxassetid://79710207509640 |
| Saber | SaberGuardHold | 2.00 s loop | Action | | rbxassetid://78611505969526 |
| Saber | SaberGuardParry | 0.40 s | Action2 | 0.08 s | rbxassetid://108317786546976 |
| Saber | SaberGuardParryAlt | 0.40 s | Action2 | 0.08 s | rbxassetid://90144539728419 |
| Saber | SaberGuardImpact | 0.25 s | Action2 | | rbxassetid://80482065051311 |

Uploaded with `python3 tools/upload_asset.py animation art/player/guard/<Class>/clips/*.rbxm`
(testbed universe granted Use); lengths and markers re-read from the uploaded
assets with `tools/anim_markers.luau`.

Checked numerically on a stock R6 rig with the real Jian/Dadao models, stepped
at 60 fps through each clip with the Animator (keys play back within 0.001 rad):
the blade stays at least 0.24 studs off the head and torso in every frame (jian
closest at the ParryAlt wrap, 0.15 s), the wrist (weapon joint) turns at most
48 degrees (jian) / 57 degrees (dadao). Known contact: the fist's crossed arms
overlap each other by up to 0.3 studs at the wrists (rigid R6 arms crossing) and
graze the round head's lower edge by up to 0.11; the dadao's spine passes
through the left palm by about 0.2 (the palm grips it). The flung-back left
hand in the saber Parry follow-through and the fist's outer palms don't reach
their targets fully (arm length), which is intended. Not yet seen in Play.

## Heavy two-handers (Greatsword, Guandao)

Per-class guards that block and parry with the weapon itself. Each class folder
holds `<Class>.rbxm` (a Folder `<Class>` with four KeyframeSequences) and
`clips/` (one `.rbxm` per clip, uploaded). Built and checked by
`build_heavy_guards.luau` (sandbox Studio, Edit mode; poses are authored in
torso space: torso lean/turn, head, where the right fist grips and where the
weapon points, and where the off hand goes, solved onto the rigid R6 arms).

Keyed joints: Torso (lean at most 0.15 rad pitch, turn up to 0.48 rad in a
parry's follow-through, 0.12 at rest), Head, Right Arm, Left Arm and the
weapon joint (`Right Arm > HiltR` for the Greatsword, `Right Arm > Hilt` for
the Guandao), which angles the weapon about the fist like the Greatsword M1
clips do. Legs are unkeyed, so walking plays underneath. Every Parry, ParryAlt
and Impact starts and ends on exactly the Hold clip's first frame. Parry and
ParryAlt deflect to opposite sides and are back within a hair of Hold by
0.28 s, so Parry > ParryAlt chains at ~0.3 s.

| Clip | Length | Loop | Priority | Markers |
|---|---|---|---|---|
| `<Class>GuardHold` | 1.6 s | yes | Action | none (slow breath at 0.8 s) |
| `<Class>GuardParry` | 0.40 s | no | Action2 | `Contact` at 0.08 s |
| `<Class>GuardParryAlt` | 0.40 s | no | Action2 | `Contact` at 0.08 s |
| `<Class>GuardImpact` | 0.25 s | no | Action2 | none (peak shove at 0.04 s) |

### Greatsword

Hold: blade slanted across the front of the body (fist low right, tip up past
the left of the head), flat to the threat, the left fist braced on the back of
the flat beside the face. Parry: the tip cocks further in (0.035 s), then a
two-handed beat swings the flat out to the right (left hand drops onto the
grip under the right fist) with the torso turning right; follow-through to
0.15 s. ParryAlt: the tip comes upright, then the flat beats across to the
left with the off hand still shoving on it, torso turning left. Impact: the
flat is driven back toward the chest and the body rocks back (0.04 s), then
rebounds.

| Clip | Id |
|---|---|
| GreatswordGuardHold | rbxassetid://132876958523754 |
| GreatswordGuardParry | rbxassetid://104088898384264 |
| GreatswordGuardParryAlt | rbxassetid://93862158483825 |
| GreatswordGuardImpact | rbxassetid://106912893883212 |

### Guandao

Hold: haft crosswise in front of the chest, blade end high on the right (about
4 studs out, head height), butt low left, the crescent's flat to the front;
the off hand slides along the haft to where it can reach. Parry: the blade end
winds back (0.035 s), then the upper haft and blade heel sweep the blow out to
the right with the torso turning right. ParryAlt: the butt end sweeps forward
and out to the left, torso turning left. Impact: the haft is driven back toward
the chest, the body rocks back and rebounds.

| Clip | Id |
|---|---|
| GuandaoGuardHold | rbxassetid://94910534495435 |
| GuandaoGuardParry | rbxassetid://117756534049087 |
| GuandaoGuardParryAlt | rbxassetid://118221648664022 |
| GuandaoGuardImpact | rbxassetid://123203381343876 |

Checked numerically (every key plus in-betweens at quarter steps): the grip
anchor stays on the fist (Guandao under 0.001 stud; Greatsword up to 0.13 in
the fast beat in-betweens, since the HiltR pivot sits 0.38 from the grip and
the joints interpolate separately), no weapon part enters the torso or head
box beyond 0.13 (the Greatsword pommel brushing the hip in the beats), arms
sink into the torso about as much as the generic guard's (0.2-0.3, the R6
shoulder overlap), the Greatsword brace fist touches the flat (under 0.07 into
the blade, up to 0.2 against a 1.3-stud head box at the cheek), the Guandao off
hand stays within 0.27 of the haft axis (it lets go for 0.05 s while the
Greatsword left hand moves to the grip), every weapon point stays above the
floor, and each clip plays through an Animator with every keyed Transform
arriving. Untested: the look (user review), feel in play, blending with the
class idle/walk and M1 clips, and other clients' view.
