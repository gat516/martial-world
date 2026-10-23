# Player cosmetics

The Blender replacements (skinned, three tail and three ear variants) are in
[`fox/`](fox/README.md); they replace the part-built prototypes below once imported.

`assets/Cosmetics.rbxm` (binary) is the folder `Cosmetics` with two rigged
Accessory prototypes for players who have the fox trait (the Spirit Fox race).
Built from plain parts by `build_fox_cosmetics.luau`; colours are plain
SmoothPlastic (fox orange, cream inner ear, dark ear tips, white tail tip).
It isn't mapped in the project files yet: map it to `ServerStorage.Cosmetics`
in both `default.project.json` and `test.project.json`.

| Accessory | Handle attachment | Attaches to (R6) | Parts |
| --- | --- | --- | --- |
| `FoxEars` | `HatAttachment` | Head.HatAttachment | 13 (Handle + 6 wedges per ear) |
| `FoxTail` | `WaistBackAttachment` | Torso.WaistBackAttachment | 6 (Handle + 5 ellipsoids) |

Attach with `humanoid:AddAccessory(template:Clone())`. The Handles are invisible
0.2 cubes. Every part is unanchored, Massless, with CanCollide, CanQuery and
CanTouch off. The ears stand about 0.7 studs clear of a normal hair accessory,
and their bases sit just inside the head top, so they also work on a bald head.
Very tall hair can still hide them.

## Joints (for animators)

All joints are Motor6Ds parented to their Part0. At rest each joint frame has no
rotation relative to the Handle (C0 and C1 point at the hinge), so `Transform`
rotates about the character's own axes: X pitches (tail up and down, ear folds
back), Y yaws (tail wag side to side), Z rolls (ear flicks outward). The
character faces -Z and its left is -X.

| Joint | Part0 -> Part1 | Moves | Hinge |
| --- | --- | --- | --- |
| `EarL` | Handle -> `LeftEar` | left ear (and its inner/tip pieces, welded) | ear base |
| `EarR` | Handle -> `RightEar` | right ear | ear base |
| `Tail1` | Handle -> `TailSeg1` | whole tail from the root | lower back |
| `Tail2` | TailSeg1 -> `TailSeg2` | | |
| `Tail3` | TailSeg2 -> `TailSeg3` | | |
| `Tail4` | TailSeg3 -> `TailSeg4` | | |
| `Tail5` | TailSeg4 -> `TailSeg5` | white tip | |

Every keyed part has a unique name. For a wag, put the same small yaw on each
`Tail` joint, with a delay down the chain. Keep the yaw to about ±0.35 rad per
joint, or the tip swings into the legs. The tail segments are ellipsoids that
overlap heavily, so bends up to about 0.4 rad per joint leave no gaps. Ear
twitches look right up to about 0.5 rad.

Scaling: `Model:ScaleTo` on the character scales the accessories, their joints
and the ellipsoid meshes cleanly (checked at 1.15: no joint gaps, same placement
relative to the head and torso).

## Rebuild

Run `build_fox_cosmetics.luau` in Edit mode through the Studio MCP
(`execute_luau`). It replaces `ServerStorage.Cosmetics.FoxEars` and `.FoxTail`.
The tunables are at the top. Then export the folder with
`tools/export_rbxm.luau` (`_G.exportRbxm("ServerStorage.Cosmetics")`) to
`assets/Cosmetics.rbxm`. Once the file is mapped, build in an unmapped staging
copy, as AGENTS.md describes.
