# Player cosmetics

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

## Spirits (`assets/Cosmetics/Spirits.rbxm`)

The Folder `Spirits` (mapped into `ReplicatedStorage.Cosmetics`) holds one
Accessory per race, as named in `src/shared/Identity/Races.luau`. They are built
by `build_spirit_cosmetics.luau` in the fox and Beast Folk shape language: plain
SmoothPlastic, Neon only where something glows, invisible 0.2 Handles, and every
part unanchored and Massless with CanCollide, CanQuery and CanTouch off. Each is
one telling feature on a plain R6 cultivator, not a costume.

| Accessory | Race | Attaches (R6) | Parts | Look |
| --- | --- | --- | --- | --- |
| `StoneShards` | Stone Spirit | BodyBackAttachment | 21 | grey-brown stone shards (block body + wedge chisel cap, diamond-turned) on two shoulder crusts, 2 per shoulder leaning out and back, 2 between the shoulder blades; 3 shards carry flush Neon jade vein insets |
| `DragonHorns` | Dragonblood | HatAttachment | 11 | antler beams from the temples sweeping up and back, ivory to pale gold, two gold tines each |
| `DemonHorns` | Demonic Human | HatAttachment | 7 | short thick horns from the upper forehead, rising out and hooking forward, black to crimson tip; no tines |
| `GhostWisps` | Ghost | BodyBackAttachment | 10 | three Neon soul flames (core, tapered tongue leaning outward, faint shell): one over each shoulder beside the face, one on the upper back, plus one mist emitter |

(Part counts include the Handle.) Horns and flames are ellipsoids (Sphere
SpecialMesh), which scale with `ScaleTo`.

### Joints

Same conventions as the fox (Motor6Ds parented to Part0, identity frames at rest,
X pitches, Y yaws, Z rolls; the character faces -Z, its left is -X):

| Accessory | Joints | Notes |
| --- | --- | --- |
| `DragonHorns`, `DemonHorns` | `HornL` (Handle -> `LeftHorn`), `HornR` (-> `RightHorn`) | hinge at the horn root; `<Side>HornSeg2/3` and the dragon's `<Side>HornTine1/2` are welded |
| `GhostWisps` | `Wisp1` (Handle -> `WispL`), `Wisp2` (-> `WispR`), `Wisp3` (-> `WispBack`) | hinge at the flame core, so `Transform` translation bobs a flame; `<Wisp>Flame` and `<Wisp>Shell` are welded |
| `StoneShards` | none | rigid, welded to the Handle |

Safe ranges: a wisp bob of about ±0.2 studs in Y keeps the side flames above the
arm tops; don't move them inward (X toward 0) or they enter the head. Horn twitches
look right up to about 0.2 rad.

### Emitter

`GhostWisps.Handle.MistFX.Mist`: built-in smoke texture, pale blue, Rate 1.2,
Lifetime 2.5-3.5 s (about 3-4 particles alive), size 0.8 to 1.8, transparency
0.86 at its densest, drifting back and slowly up. No other race uses effects.

### Clearances (checked numerically)

- **Walk:** over the stock R6 walk (`rbxassetid://180426354`) and a ±1 rad
  limb-swing stress pose, the horns never touch a limb, and the wisps only
  graze the arm tops by 0.015 with their faint outer shell (the side flames sit
  over the shoulder centres, 0.4 above the torso top, just outside the face). The stone
  shards and crusts graze at most 0.07 to 0.1 studs, at their roots on the
  shoulder top, against a 1.2 cube standing in for the rounded head mesh and the
  arm top corners; the shoulder room between the head and the arms is only about
  0.4, so wider or more outward-leaning shards hit the arms.
- **Hair:** with Pal Hair (box top 0.15 above HatAttachment) the dragon horn tips
  stand at 1.31 and the demon horn tips at 1.04. Very tall hair can bury the
  demon horn roots.
- **Scale:** after the character's `ScaleTo(1.15)`, every part sits at exactly
  1.15x its distance from its body part, with no joint gaps.

### Rebuild

Run `build_spirit_cosmetics.luau` in Edit mode (execute_luau, or `loadstring`
it from a served checkout). It replaces `ReplicatedStorage.Cosmetics.Spirits`;
the tunables are at the top. Then load `tools/export_rbxm.luau`, post
`_G.exportRbxm("ReplicatedStorage.Cosmetics.Spirits")` to the receiver
(`/Spirits.rbxm`), and move the file to `assets/Cosmetics/Spirits.rbxm`. In a
Rojo-connected place, build in an unmapped staging folder and export it under
the name `Spirits` instead.
