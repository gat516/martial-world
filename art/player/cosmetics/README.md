# Player cosmetics

`assets/Cosmetics/` is mapped to `ReplicatedStorage.Cosmetics` (the creator
preview runs on the client). It holds one binary file per set, and each file is
a Folder of rigged Accessory prototypes. Traits looks up an accessory id through
every set. Sets: `Fox.rbxm` (Spirit Fox, below) and `BeastFolk.rbxm` (the Beast
Folk variants, further down).

## Fox (`assets/Cosmetics/Fox.rbxm`)

Built from plain parts by `build_fox_cosmetics.luau`. The colours are plain
SmoothPlastic: fox orange, a cream inner ear, dark ear tips and a white tail tip.

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
(`execute_luau`). The script still targets `ServerStorage.Cosmetics.FoxEars`
and `.FoxTail` (from before the move), so move the results into
`ReplicatedStorage.Cosmetics.Fox` and export that Folder with
`tools/export_rbxm.luau` to `assets/Cosmetics/Fox.rbxm`.

## Beast Folk (`assets/Cosmetics/BeastFolk.rbxm`)

The Folder `BeastFolk` (mapped into `ReplicatedStorage.Cosmetics`) holds eight
rigged Accessories, two per Beast Folk variant, as listed in
`src/shared/Identity/Variants/BeastFolk.luau`. They are built by
`build_beastfolk_cosmetics.luau` in the fox set's shape language: plain
SmoothPlastic, invisible 0.2 Handles, and every part unanchored and Massless with
CanCollide, CanQuery and CanTouch off. Each set has one loud piece: the wolf's
tall grey ears, the tiger's banded tail, the crane's red cap and plume, and the
serpent's long tail.

| Accessory | Attaches (R6) | Parts | Look |
| --- | --- | --- | --- |
| `WolfEars` | HatAttachment | 13 | upright grey ears 0.6 x 1.3, warm cream inner, charcoal tip |
| `WolfTail` | WaistBackAttachment | 9 | bushy grey brush that arcs out and hangs down, cream belly lobes |
| `TigerEars` | HatAttachment | 11 | short round orange discs on a stem, black rim, white inner, white spot on the back |
| `TigerTail` | WaistBackAttachment | 13 | long slim S-curve, five black bands, black tip |
| `CraneCrest` | HatAttachment | 10 | flat red cap pressed into the hair, three black-tipped white plumes and two black ones swept back |
| `CraneTail` | WaistBackAttachment | 12 | white rump with a fan of five black-tipped white feathers, outer ones lifted |
| `SerpentScales` | FaceFrontAttachment | 11 | five jade diamonds per side on the temple and cheek, flat on the head wall |
| `SerpentTail` | WaistBackAttachment | 15 | long tapering jade tail with a dark dorsal line, drooping, tip curling to the right |

(Part counts include the Handle.)

### Joints

Same conventions as the fox (Motor6Ds parented to Part0, identity frames at rest,
X pitches, Y yaws, Z rolls). The part and joint names match the fox's, so a clip
keyed on `LeftEar`/`RightEar` or `TailSeg1..n` drives any race:

| Accessory | Joints | Notes |
| --- | --- | --- |
| `WolfEars`, `TigerEars` | `EarL` (Handle -> `LeftEar`), `EarR` (-> `RightEar`) | hinge at the ear base; inner, tip, rim, stem and spot pieces are welded |
| `WolfTail` | `Tail1..5` (Handle -> `TailSeg1` -> ... -> `TailSeg5`) | `TailBelly3..5` are welded to their segment |
| `TigerTail` | `Tail1..7` (`TailSeg1..7`) | `TailBand1..5` are welded to segments 2-6; `TailSeg7` is the black tip |
| `SerpentTail` | `Tail1..7` (`TailSeg1..7`) | `TailDorsal1..7` are welded to their segment |
| `CraneCrest` | `Plume` (Handle -> `CrestPlume`) | the whole plume sways from its root; the crown is welded to the Handle |
| `CraneTail` | `Tail1` (Handle -> `TailSeg1`, the rump), `Feather1..5` (`TailSeg1` -> `TailFeather1..5`) | yaw the outer feathers outward to spread the fan; tips are welded |
| `SerpentScales` | none | flat, welded to the Handle |

Safe ranges: tail joints take about ±0.35 rad of yaw each, and fan feathers
about ±0.4 rad. Bending a drooping tail forward (negative X pitch on `Tail1`)
brings it into the legs.

### Clearances (checked numerically)

- **Walk:** the stock R6 walk (`rbxassetid://180426354`) swings the legs back to
  about Z 1.5 behind the waist at hip height. So every tail runs out level
  (above Y 0) until about Z 1.6 before it droops. Worst limb penetration over
  the clip is 0.01 to 0.05, all at the hip root; FoxTail measures 0.27.
- **Hair:** the head pieces stand clear of a normal hair (hair box top 0.30 above
  HatAttachment). The wolf ear tops are at 1.34, the tiger's at about 0.7, the
  crane plume's at about 1.1. Very tall hair hides the tiger ears and the crane
  cap.
- **Scale:** after the character's `ScaleTo(1.15)`, every part sits at exactly
  1.15x its distance from its attachment, with no joint gaps.

### Rebuild

Run `build_beastfolk_cosmetics.luau` in Edit mode (execute_luau, or `loadstring`
it from a served checkout). It replaces `ReplicatedStorage.Cosmetics.BeastFolk`.
Then load `tools/export_rbxm.luau` and post
`_G.exportRbxm("ReplicatedStorage.Cosmetics.BeastFolk")` to the receiver
(`/BeastFolk.rbxm`), and move the file to `assets/Cosmetics/BeastFolk.rbxm`. In a
Rojo-connected place, build in an unmapped staging folder and export it under
the name `BeastFolk` instead.
