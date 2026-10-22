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

Uploaded with `python3 tools/upload_animation.py art/player/guard/clips/*.rbxm`
(group 772472600, testbed universe granted Use), in `Animations.Guard`:

| Clip | Animation | Id |
|---|---|---|
| GuardHold | `Guard.Hold` | rbxassetid://78908975484990 |
| GuardParry | `Guard.Parry` | rbxassetid://123895539094624 |
| GuardImpact | `Guard.Impact` | rbxassetid://136933091358616 |

Ids are immutable: after changing a clip, re-upload it and swap the id.
