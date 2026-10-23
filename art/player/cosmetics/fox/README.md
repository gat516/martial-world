# Spirit Fox cosmetics (Blender, skinned)

Fox ears and fox tails for the Spirit Fox race's R6 avatar. Three tails and three ear shapes
ship as the Spirit Fox variants Plume (Plume + Sleek), Crescent (Crescent + Broad) and Wisp
(Wisp + Long) (`src/shared/Identity/Variants/SpiritFox.luau`); any ears go with any tail.

| Set | Attaches to (R6) | Meshes (one MeshPart each) | Tris |
| --- | --- | --- | --- |
| `FoxTailPlume` | Torso.WaistBackAttachment | `FoxTailPlume_Tail`, `FoxTailPlume_TailTip` | 2,834 |
| `FoxTailCrescent` | Torso.WaistBackAttachment | `FoxTailCrescent_Tail`, `FoxTailCrescent_TailTip` | 3,274 |
| `FoxTailWisp` | Torso.WaistBackAttachment | `FoxTailWisp_Tail`, `FoxTailWisp_TailTip` | 4,374 |
| `FoxEarsSleek` | Head.HatAttachment | `<Set>_LeftEar`, `_LeftEarInner`, `_RightEar`, `_RightEarInner` | 1,768 |
| `FoxEarsBroad` | Head.HatAttachment | same four | 1,768 |
| `FoxEarsLong` | Head.HatAttachment | same four | 1,768 |

- **Tails** (remade 2026-10-23 to match the approved cute ears): soft, plump and rounded, each a
  fat core ending in a big round cream tip, with big soft fur clumps. Never thin, tall or hooked
  (that read "creepy"). Three clearly different silhouettes:
  - **Plume** (cute): a plump ball, curled up and over on the lower back, cream tip on top.
  - **Crescent** (cute): a round S that rises behind and flops over the left shoulder; from the
    front its cream tip peeks over the shoulder.
  - **Wisp** (bold): a long full brush sweeping back, out to the right and up, with soft
    flame-like points and a longer soft tip.

| Tail | Length | / torso height | Girth (fur included) | / torso width |
| --- | --- | --- | --- | --- |
| Plume | 2.49 | 1.25 | 1.66 | 0.89 |
| Crescent | 4.34 | 2.17 | 1.66 | 0.89 |
| Wisp | 4.20 | 2.10 | 1.69 | 0.90 |

  Length runs along the centreline from where the tail leaves the back to the end of the tip;
  girth is the widest full section. The R6 torso mesh is 1.87 wide and 2.00 tall, the legs 1.93
  (measured from the rig, `body_bbox()`); each JSON carries these under `proportions`.
- **Clearing the body.** Every tail leaves the back above the waist, rising, so it clears the
  legs' back swing. The build checks each tail against the R6 run swing (legs and arms 57
  degrees each way, both phases; JSON `run_clearance`): nothing goes deeper than 0.12 studs,
  and only a few vertices near the root touch, at the very end of the swing (Wisp's right arm
  grazes it by 0.03).
- **Ears** are three cute sets, told apart by silhouette alone, all short, chunky and thick
  front to back (a rounded cup with a deep rim). Inside, a few soft cream fur tufts of mixed
  sizes, each coming to a slight point; the base ones curl over the rim (smooth round lumps read
  as pebbles or teeth):
  - **Broad** (cute, approved 2026-10-23): a round dome peak, no point.
  - **Sleek** (cute, alert): a stubby soft triangle with a gentle point, a small notch in the
    outer rim and a darker tip.
  - **Long** (cute, sleepy): round, the top two-thirds flopping down and outward (100 degrees),
    readable from behind at game distance. The name is historical (it is wired into the
    variants); it's no longer long.

| Ears | Visible height | Height / head height | Base width (at the head surface) | Base / head width |
| --- | --- | --- | --- | --- |
| Broad | 0.65 | 64% | 0.49 | 41% |
| Sleek | 0.53 | 52% (was 65%) | 0.45 | 38% |
| Long | 0.56 | 55% (was 63%) | 0.49 | 41% |

  No fox ear stands taller than the approved Broad dome (user, 2026-10-23: "those tall ears are
  a bit tall"). The R6 head mesh is 1.20 wide and 1.02 tall (`head_bbox()`); each JSON carries
  these under `proportions`.
- **Seating.** Every ear's base is sunk 0.1 under the head's real surface along its normal (a ray
  cast onto the R6 mesh), fading out over the lowest 30% of the ear. Any lower-ear vertex (or its
  foot) past the head's round outline is first pulled in toward the ear's centre, so nothing
  hangs beside the head with air under it (a vertical sink left the outer-back corner only 0.023
  deep on the head's rounded edge: a dark gap the user saw). The build measures it (JSON `seat`):
  every base-ring vertex and base-edge midpoint is 0.093 to 0.106 under the surface, shell and
  inner fur, and no vertex hangs off the head below its top.

Sheets (`make_sheet.py`):
- `sheets/fox_cosmetics.png`: one row per tail (worn with Broad ears) with front, side, back,
  rear three-quarter, a bent pose, running from the side and in the other phase, the game
  camera at 12 studs, where it leaves the back and a bent close-up; each row's size against the
  torso and the run check; the approved cute ears along the bottom.
- `sheets/fox_ears.png` (`ears`): one row per ear set with front, side, back, fold back 60,
  flick out 35, seating close-ups, the game camera at 12 studs, and before | after pairs (tufts,
  game camera from behind, front).
- `sheets/fox_ears_seat.png` (`seat`, after `seat_sheet.py`): the three ear sets side by side,
  one head each, close up at eye level just above the head all round the base, with the
  measured seat numbers.

## Files

- `build_fox.py`: builds everything in the `Cosmetics` scene, beside the R6 reference.
  - Exports `<Set>.fbx` and `<Set>.json`, writes `fox_shade.png` and saves `Fox.blend`.
  - Renders the sheet tiles into `renders/` (not committed).
  - Run it through the Blender MCP; the header gives the exec line.
  - Every tunable is a named constant at the top: the `EARS` / `TAILS` tables, colours, the shade ramp, clump grading.
- `make_sheet.py`: stitches `renders/` into the sheets, run through `uv run --with pillow`.
- `seat_sheet.py`: lays the ear sets out side by side (one R6 body each, the race-cosmetics
  `tools/blender_lineup.py`) and renders the seating close-ups.
- `<Set>.json` holds:
  - the attachment
  - each mesh's region, tris, centre and size
  - every bone's parent, head, tail and `roblox_head`
  - the colours and the shade-ramp settings
  - the fan angles, `proportions` against the torso and `run_clearance` (tails)
  - `proportions` against the head and the measured `seat` (ears)

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

- **Core.** A full, smooth core runs the length of the tail, plump almost to the end, which
  closes in a round cap (a dome on Plume and Crescent, a longer soft point on Wisp) instead of a
  point.
- **Clumps.** 16 to 30 big soft clumps are staggered around and along the core, larger at the
  base and smaller toward the tip, with lengths varied so they never line up in even
  pinecone rows. Each ends in a rounded lobe (cute) or a soft point (Wisp) that lifts off the
  core and breaks the outline.
- **Sealed.** Each clump is a closed lobe whose underside is buried inside the core, so:
  - no clump floats
  - nothing is single-sided (safe with backface culling)
  - any gap between clumps shows orange core, not the background
- **Shading.** Tail edges sharper than 70 degrees shade hard (only the clump ridges). The ears
  use the house 28 degrees; the inner fur is smooth all over (harder read as crumpled stone).

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
  - ears, rotate about local Z (world +X): fold forward (+) and back (-)
  - ears, rotate about local X (world +Y): flick sideways (+ is outward on the left ear and
    inward on the right; `pose(flick=)` signs it per side)
- **Checked.** The sheet's bent column curls Plume 14 and Crescent 12 degrees per joint about Z
and sways Wisp -20 degrees per joint about X. The ear sheet folds each ear back 60 degrees
about local Z and flicks it out 35 degrees about local X. No collapse, tearing or see-through
gaps.

Hinge data per bone (attachment space, Blender axes and Roblox) is in each JSON under `bones`.

## Multi-tail variants (3, 5, 9 tails)

- **Copies.** Clone the tail accessory and turn each copy about the WaistBackAttachment's back axis: Blender +Y, Roblox +Z, the axis pointing out of the lower back.
- **Pivot.** The attachment origin, which is the FBX origin. In Roblox, rotate each copy's attachment CFrame by `CFrame.Angles(0, 0, rad(angle))`.
- **Angles:**

| Tails | Angles (degrees) |
| --- | --- |
| 3 | -40, 0, 40 (built as `FoxFan` with Plume, not on the sheet) |
| 5 | -50, -25, 0, 25, 50 |
| 9 | -72, -54, -36, -18, 0, 18, 36, 54, 72 |

  - With 9 tails, scale the outer pairs to about 0.9 and push them 0.05 studs back (+Y Blender) so their roots don't fight.
- **Crescent and Wisp.** They sweep to one side, so mirror alternate copies (scale X -1 before turning) to keep the fan symmetric.
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

All six ids above are older builds: the remade tails and the reworked ears (2026-10-23) still
need uploading and placing.

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
local Z, wag about local X, ears fold about local Z and flick about local X).

**Recolour.** Each MeshPart has a `Region` attribute (`FurOuter`, `FurInner`, `FurTip`) and a
`SurfaceAppearance` whose `ColorMap` is the shade ramp. The SurfaceAppearance covers the
part colour, so to tint a region set both the MeshPart's `Color` and its
`SurfaceAppearance.Color` (they start as the JSON's linear defaults converted to sRGB).

## Untested

In game: the run clearance with Roblox's real run animation (checked only against a 57 degree
limb swing in Blender), the ears with tall hats, phone-distance read, the shade ramp at
distance, and the ear seat in flick and fold poses (the inner fur lifts up to 0.05 under the
ear). Nothing animates the bones yet; the tails and ears hold their rest pose.
