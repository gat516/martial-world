# Animation reference

Reference rigs and animations for beast animation. Study them for timing,
weight, arcs and how each attack reads (anticipation, release, follow-through);
don't ship them. The models and animations aren't ours, so nothing from these
files goes into `ServerStorage.Enemies`, `assets/` or a published animation.

## `beartiger.rbxm`

Two quadruped rigs, each a `Model` with `HumanoidRootPart`, 23 MeshParts joined
by Motor6Ds (`Torso`, `Waist`, `Waist2`, `Head`, `Jaw`, eyes, `Left/Right`
`Shoulder`/`Arm`/`Hand` for the front legs, `Thigh`/`Ankle`/`Foot` for the back
legs, plus `Plane.0xx` fur and tail pieces) and an `AnimSaves` folder of
KeyframeSequences. The keys are baked (one per frame), so curves can be read off
the poses directly.

**White Tiger Rigged** (fast, agile predator):

| Animation | Length | Loop |
|---|---|---|
| Idle | 3.00s | yes |
| Sleeping | 3.00s | yes |
| Walk | 1.33s | yes |
| Run | 0.98s | yes |
| Roar | 2.00s | yes |
| Pounce | 1.25s | no |
| Bite | 1.33s | no |
| Grip | 0.92s | no |
| Claw Swipes | 3.22s | no |
| Lightning Blitz | 1.60s | no |
| Posture Broken | 0.73s | no |
| Half HP Pain | 1.17s | yes |
| Invisibility 1 / 2, Invisibility/Pain | 1.08 / 1.17 / 1.97s | yes |
| Death | 1.17s | no |

**Bear Rigged** (heavy bruiser):

| Animation | Length | Loop |
|---|---|---|
| Idle | 4.00s | yes |
| Walk | 1.33s | yes |
| Run | 1.00s | yes |
| Left / Right Claw Swipe | 1.00s | no |
| Slamming Claw Swipe | 1.50s | no |
| Uppercutting Claw Swipe | 1.50s | no |
| Forward Slam | 1.33s | no |
| Guardbreak | 1.23s | no |

To watch them, ask the user to insert the file into Studio under an unmapped
folder (e.g. `ServerStorage._AnimRef`, never a Rojo-mapped instance) and play a
sequence on the rig in Edit mode, or read the Pose CFrames per Keyframe through
the MCP. Remove `_AnimRef` when done.
