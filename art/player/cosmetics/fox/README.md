# Spirit Fox cosmetics (Blender, skinned)

Fox ears and fox tails for the Spirit Fox race's R6 avatar. Three tails and three ear shapes
ship as the Spirit Fox variants Plume (Plume + Sleek), Crescent (Crescent + Broad) and Wisp
(Wisp + Long) (`src/shared/Identity/Variants/SpiritFox.luau`); any ears go with any tail.

| Set | Attaches to (R6) | Meshes (one MeshPart each) | Tris |
| --- | --- | --- | --- |
| `FoxTailPlume` | Torso.WaistBackAttachment | `FoxTailPlume_Tail`, `FoxTailPlume_TailTip` | 3,336 |
| `FoxTailCrescent` | Torso.WaistBackAttachment | `FoxTailCrescent_Tail`, `FoxTailCrescent_TailTip` | 3,336 |
| `FoxTailWisp` | Torso.WaistBackAttachment | `FoxTailWisp_Tail`, `FoxTailWisp_TailTip` | 3,626 |
| `FoxEarsSleek` | Head.HatAttachment | `<Set>_LeftEar`, `_LeftEarInner`, `_RightEar`, `_RightEarInner` | 1,148 |
| `FoxEarsBroad` | Head.HatAttachment | same four | 1,160 |
| `FoxEarsLong` | Head.HatAttachment | same four | 1,148 |

- **Plume:** rises behind the back in an S-curve, and its tip swings out past the left shoulder.
- **Crescent:** sweeps out to the avatar's left and curls up.
- **Wisp:** hangs low behind the legs, then hooks up and out.
- **Sleek** is the default ears. **Broad** ears are shorter and wider, tilt further outward and have more tufts. **Long** ears are tall and swept back.

Sheet: `sheets/fox_cosmetics.png`. Each tail is shown with its paired ears in front, side, back
and rear three-quarter views, plus a bent pose, an ears close-up, a close-up of the bent tail
(sealed, no gaps) and the 3-tail fan proof.

## Files

- `build_fox.py`: builds everything in the `Cosmetics` scene, beside the R6 reference.
  - Exports `<Set>.fbx` and `<Set>.json`, writes `fox_shade.png` and saves `Fox.blend`.
  - Renders the sheet tiles into `renders/` (not committed).
  - Run it through the Blender MCP; the header gives the exec line.
  - Every tunable is a named constant at the top: the `EARS` / `TAILS` tables, colours, the shade ramp, clump grading.
- `make_sheet.py`: stitches `renders/` into `sheets/fox_cosmetics.png`, run through `uv run --with pillow`.
- `<Set>.json` holds:
  - the attachment
  - each mesh's region, tris, centre and size
  - every bone's parent, head, tail and `roblox_head`
  - the colours and the shade-ramp settings
  - the fan angles (tails only)

## Space and import

- **Attachment space.** Each FBX sits in its attachment's space: the origin is the attachment point.
- **Blender axes.** X is the avatar's left, -Y its front, Z up.
- **Roblox mapping.** A Blender point `(x, y, z)` is `(-x, z, y)` in the attachment's Roblox
  frame (+X the avatar's right, +Z its back, Y up), so mesh `Size = (bx, bz, by)` and its
  CFrame relative to the attachment is `CFrame.new(-cx, cz, cy)`, no rotation. That is
  what the Open Cloud model upload produces relative to its `RootPart` (checked
  2026-10-23); the JSON's older `roblox_mapping` / `roblox_head` fields flip X and Z.
- **Import size.** The Open Cloud model upload keeps true size (no 11x).
- **Mesh names.** Every mesh name is unique across the six files.

Attachments in avatar space (R6 rest pose): HatAttachment `(0, 0, 3.1)` (Head centre + Roblox
`(0, 0.6, 0)`), WaistBackAttachment `(0, 0.5, 0)` (Torso centre + Roblox `(0, -1, 0.5)`).

## Colour (recolour contract)

Each colour region is its own MeshPart, so per-race or bloodline tints are just `Color`.

| Region material | Meshes | Default (linear) |
| --- | --- | --- |
| `FurOuter` | `_LeftEar`, `_RightEar`, `_Tail` | warm reddish-orange (0.80, 0.22, 0.055) |
| `FurInner` | `_LeftEarInner`, `_RightEarInner` | cream with a muted pink (0.93, 0.70, 0.60) |
| `FurTip` | `_TailTip` | cream-white (0.95, 0.89, 0.78) |

**Depth.** A greyscale ramp, not baked colour: `fox_shade.png` is white, darkening to 0.55 at
one end. Every mesh's UV uses only V:
- Tail: V runs along the tail, so the tail base is darker.
- Outer ears: V = 1 - height, so the ear tips are darker.
- Inner ears and tip: V = 1 (pure white).

I chose a ramp over painted colour so tinting still works. Use it as the `ColorMap` of a
SurfaceAppearance, which `Color` tints. Without the texture, plain SmoothPlastic colours still
read; they just lose the darkening.

## Fur construction (why there are no gaps)

- **Core.** A full, smooth core runs the length of the tail. It is widest a quarter of the way along, and the last 40% tapers to a point.
- **Clumps.** About 35-40 flame-shaped clumps are staggered around and along the core, larger at the base and smaller toward the tip. Their ends lift off the core and break the outline.
- **Sealed.** Each clump is a closed wedge whose underside is buried inside the core, so:
  - no clump floats
  - nothing is single-sided (safe with backface culling)
  - any gap between clumps shows orange core, not the background
- **Shading.** Tail edges sharper than 70 degrees shade hard (only the clump ridges). The ears use the house 28 degrees.

## Rig

One armature per set. `Root` is the attachment point, doesn't deform and is never keyed.

| Set | Hierarchy |
| --- | --- |
| Ears | `Root` -> `EarLBase` -> `EarL`, `Root` -> `EarRBase` -> `EarR` |
| Tail | `Root` -> `TailBase` -> `Tail1` -> `Tail2` -> `Tail3` -> `Tail4` -> `Tail5` |

- **Base bones** (`EarLBase`, `EarRBase`, `TailBase`) hold the vertices buried in the head or body, so a keyed ear or tail never pulls its root out.
- **Hinges.** The `EarL` / `EarR` heads are each ear's hinge on the head surface. The `Tail1` head is where the tail leaves the body, about 0.04 studs from WaistBackAttachment. `Tail5` ends at 97% of the length.
- **Weights.** They blend smoothly across each joint, over about 45% of a bone either side, so the tail bends without tearing. Ears blend from Base into the ear bone over the lowest third, so the base folds.
- **Rolls.** Each tail bone's local Z follows the tail's own side axis (world +X at the root), so every joint uses the same axes:
  - tail, rotate about local Z: curl or uncurl
  - tail, rotate about local X: sideways sway (wag)
  - ears, rotate about local X: fold back (+) and forward
- **Checked.** The sheet's bent column has Plume and Crescent at -40 degrees per joint about Z, Wisp at 30 degrees per joint about X (curling Wisp hits the legs and floor), and ears folded back 70 degrees. No collapse, tearing or see-through gaps.

Hinge data per bone (attachment space, Blender axes and Roblox) is in each JSON under `bones`.

## Multi-tail variants (3, 5, 9 tails)

- **Copies.** Clone the tail accessory and turn each copy about the WaistBackAttachment's back axis: Blender +Y, Roblox +Z, the axis pointing out of the lower back.
- **Pivot.** The attachment origin, which is the FBX origin. In Roblox, rotate each copy's attachment CFrame by `CFrame.Angles(0, 0, rad(angle))`.
- **Angles:**

| Tails | Angles (degrees) |
| --- | --- |
| 3 | -40, 0, 40 (shown on the sheet with Plume) |
| 5 | -50, -25, 0, 25, 50 |
| 9 | -72, -54, -36, -18, 0, 18, 36, 54, 72 |

  - With 9 tails, scale the outer pairs to about 0.9 and push them 0.05 studs back (+Y Blender) so their roots don't fight.
- **Crescent.** It sweeps to one side, so mirror alternate copies (scale X -1 before turning) to keep the fan symmetric.
- **Animation.** Each copy keeps its own `Tail1..Tail5`. Offset their wag phases a little so they don't move as one.

## In Studio

| Set | Model asset (upload_asset.py model) |
| --- | --- |
| `FoxTailPlume` | `rbxassetid://103142310298137` |
| `FoxTailCrescent` | `rbxassetid://91533908538003` |
| `FoxTailWisp` | `rbxassetid://95800596652636` |
| `FoxEarsSleek` | `rbxassetid://98916068347166` |
| `FoxEarsBroad` | `rbxassetid://124732163729948` |
| `FoxEarsLong` | `rbxassetid://115950384313807` |

`fox_shade.png` is `rbxassetid://124559907609415` (Studio MCP `upload_image`).

**Rebuild** (in a sandbox, no FBX import step):
1. Upload the changed FBX with `python3 tools/upload_asset.py model <Set>.fbx` and put the new
   id in `place_fox_cosmetics.luau` (`ASSETS`).
2. Insert each model asset into Workspace as `_Import<Set>` (Studio MCP `insert_asset`).
3. Run `place_fox_cosmetics.luau` through `execute_luau`. It turns each import into the
   Accessory `<Set>` in `ServerStorage.Cosmetics` and deletes the imports. Sets without an
   import keep their current template, so re-doing only the ears means uploading and
   inserting only the three ear sets.
4. Export with `tools/export_rbxm.luau` (`_G.exportRbxm("ServerStorage.Cosmetics")`) to
   `assets/Cosmetics.rbxm`.

**Accessory layout.** `Handle` is the importer's `RootPart` shrunk to an invisible 0.2 cube
at the attachment point; it holds the `HatAttachment` / `WaistBackAttachment` and the bones
(`Root` -> ...). The skinned MeshParts sit beside it, welded to it. Skinning works on a
worn accessory: bending `Tail1..Tail5` or `EarL`/`EarR` (`Bone.Transform`) deforms the
meshes, and `Model:ScaleTo(1.15)` scales meshes, bones and placement together (both
checked in edit mode on R6 dummies). Animate the bones with `Bone.Transform` (curl about
local Z, wag about local X, ears fold about local X).

**Recolour.** Each MeshPart has a `Region` attribute (`FurOuter`, `FurInner`, `FurTip`) and a
`SurfaceAppearance` whose `ColorMap` is the shade ramp. The SurfaceAppearance covers the
part colour, so to tint a region set both the MeshPart's `Color` and its
`SurfaceAppearance.Color` (they start as the JSON's linear defaults converted to sRGB).

## Untested

In game: walking or running clearance (arms against Crescent, legs against Wisp), the ears
with tall hats, phone-distance read, the shade ramp at distance. Nothing animates the bones
yet; the tails and ears hold their rest pose.
