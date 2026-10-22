# Guard animations (player, R6)

`Guard.rbxm` holds a Folder `Guard` with three KeyframeSequences. They key only
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

## Publishing

1. In Studio, insert `art/player/guard/Guard.rbxm` (Insert from file).
2. Put an R6 rig in the workspace, open the Animation Editor, and load each
   KeyframeSequence from the `Guard` folder (right-click it > Open in Animation
   Editor, or File > Import).
3. Check priority, Loop and the `Contact` marker on GuardParry, then Publish to
   Roblox (Animation Editor menu > Save to Roblox).
4. Paste the three asset ids back to the main session.
