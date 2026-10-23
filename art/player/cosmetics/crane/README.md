# Beast Folk (Crane) cosmetics (Blender, skinned)

A red crown crest, white-and-black head plumes and a tail fan for the Beast Folk Crane's R6
avatar, in three looks with their own silhouettes. Each look is two accessories: a head
piece (crest + plumes) and a fan. Cascade is the Crane variant's default
(`src/shared/Identity/Variants/BeastFolk.luau`). Scholar and Ascendant are built and
shipped for a later style picker. Any head piece goes with any fan.

| Set | Attaches to (R6) | Meshes (one MeshPart each) | Tris |
| --- | --- | --- | --- |
| `CraneHeadCascade` | Head.HatAttachment | `<Set>_Crest`, `<Set>_Plume`, `<Set>_PlumeAccent` | 1,730 |
| `CraneFanCascade` | Torso.WaistBackAttachment | `<Set>_Fan`, `<Set>_FanAccent` | 2,040 |
| `CraneHeadScholar` | Head.HatAttachment | as the head above | 1,496 |
| `CraneFanScholar` | Torso.WaistBackAttachment | as the fan above | 2,228 |
| `CraneHeadAscendant` | Head.HatAttachment | as the head above | 1,718 |
| `CraneFanAscendant` | Torso.WaistBackAttachment | as the fan above | 3,668 |

- **Cascade (soft, the default):** a raised crimson crown swept back, broad plumes draping
  over the nape like a mantle, and a long trailing train.
- **Scholar (elegant):** a low, flat crimson cap, streamer plumes trailing straight back
  with an upward flick, and a compact, domed half-fan behind the hips.
- **Ascendant (bold):** one tall flame-shaped crest feather, plumes sweeping up and back
  like folded wings, and a sunburst fan rising behind the back.

Sheet: `sheets/crane_cosmetics.png`. Each look gets front, side, back, rear three-quarter
and bent views, plus close-ups of the plume seating, the crest seating and the bent fan.
The row labels give each piece's size against the body part it sits on.

**Size against the body part** (head 1.2 x 1.2 x 1.02, torso 1.87 x 1.0 x 1.87 studs;
printed by every build into `renders/ratios.json`):

| Look | Crest above head (head heights) | Plumes: width (head widths) / reach behind (head depths) | Fan: width (torso widths) / height (torso heights) / reach behind (torso depths) |
| --- | --- | --- | --- |
| Cascade | 0.18 | 0.84 / 0.57 (they hang 1.62 head heights tall) | 1.08 / 0.67 / 1.76 |
| Scholar | 0.12 | 0.62 / 1.28 | 1.22 / 0.35 / 1.23 |
| Ascendant | 0.52 | 1.96 / 1.01 | 1.88 / 0.82 / 1.21 |

## Files

- `build_crane.py` builds everything in the `Cosmetics` scene beside the R6 reference.
  - The `DIRECTIONS` table holds every feather. It also has the colours, the shade ramp
    and the bone joints.
  - It saves `Crane.blend` and prints the size ratios.
  - It renders the sheet tiles into `renders/` (not committed).
  - With `EXPORT=True` it writes `<Set>.fbx`, `<Set>.json` and `crane_shade.png`.
  - Run it in a visible window (`tools/blender_live.sh run crane ...`) or headless:
    `tools/blender_run.sh art/player/cosmetics/crane/build_crane.py EXPORT=True RENDER=True`.
- `make_sheet.py` stitches `renders/` into the sheet:
  `uv run --with pillow python3 -I art/player/cosmetics/crane/make_sheet.py`.
- `place_crane_cosmetics.luau` turns the imports into Accessories (In Studio, below).
- `<Set>.json` holds the attachment, each mesh's region, tris, centre and size, every
  bone's parent, head and tail, the colours and the shade ramp.

## Space and import

Same as the fox (`../fox/README.md`, Space and import):
- **Space.** Each FBX is in its attachment's space: the origin is the attachment point.
- **Axes.** Blender X is the avatar's left, -Y its front, Z up.
- **To Roblox.** A Blender point `(x, y, z)` is `(-x, z, y)` in the attachment's Roblox
  frame, with no rotation.
- **Scale.** The Open Cloud model upload keeps true size.
- **Names.** Mesh names are unique across all six files.

## Feathers (why there are no gaps)

- **Closed shapes.** Every feather is a closed, chunky shape: a six-point section with a
  raised ridge down the middle and slightly drooping vanes, swept along a bent centreline,
  so nothing is single-sided.
- **Tip shapes.** Feathers are full leaf shapes, rounded coverts or broad flight feathers
  with soft points. There are no needles: the first, thin pass read spiky.
- **Black tips.** A black-tipped feather is two meshes (the `FeatherMain` part and the
  `FeatherAccent` part) that meet at a shared cap inside the feather.
- **Roots.** Every root is buried in the head or torso, and a buried cushion of white
  feathers fills the base of each plume and fan, so the gaps between feathers near the
  body show feathers, not the background.
- **Crest seating.** The Cascade crown sits on a buried red dome, so its lifted feathers
  never show a gap underneath.
- **Fan depth.** Fans are cupped into shallow domes (a `cone` tilt per layer), so they
  have depth from the side and aren't flat cards. Their layers are pushed back one over
  the other.

## Colour (recolour contract)

| Region material | Meshes | Default (linear) |
| --- | --- | --- |
| `FeatherMain` | `_Plume`, `_Fan` | soft white (0.86, 0.87, 0.85) |
| `FeatherAccent` | `_PlumeAccent`, `_FanAccent` | ink black (0.022, 0.024, 0.032) |
| `Crest` | `_Crest` | muted crimson (0.50, 0.035, 0.04) |

- **Shading.** Depth comes from a greyscale ramp on UV V, not from baked colour.
  - V runs along each white feather, so feather roots are darker and each layer reads over
    the one behind it.
  - Accent and crest meshes sit at V = 1 (plain colour).
  - The cushions are darker still.
- **Shared image.** `crane_shade.png` is byte-identical to the fox's ramp (darkest 0.55,
  white by V 0.45), so both sets share one uploaded image.
- **In Roblox.** The ramp is the `ColorMap` of a SurfaceAppearance, which `Color` tints.

## Rig

One armature per set. `Root` is the attachment point, doesn't deform and is never keyed.

| Set | Hierarchy |
| --- | --- |
| Heads | `Root` -> `CrestBase` -> `Crest` |
| Cascade, Scholar heads | `Root` -> `PlumeBase` -> `Plume1` -> `Plume2` -> `Plume3` |
| Ascendant head | `Root` -> `PlumeLBase` -> `PlumeL1..3`, `Root` -> `PlumeRBase` -> `PlumeR1..3` (one chain per wing) |
| Fans | `Root` -> `FanBase` -> `Fan<S>` -> `Fan<S>Tip` for sectors `L2`, `L1`, `C`, `R1`, `R2` (L = the avatar's left) |

- **Base bones** (`CrestBase`, `Plume*Base`, `FanBase`) hold what's buried in the body, so
  keyed bones never pull a root out.
- **Plume weights** follow each feather's own length. Joints sit at 16%, 42%, 68% and 96%
  of it, with smooth blends across each joint, so every feather in a plume sways together.
- **Fan weights.**
  - Each feather blends between its two nearest sector bones by its angle in the fan.
  - Along its length it blends from `Fan<S>` to `Fan<S>Tip` at about 55%.
- **Bone axes.** Every bone's local Z is the feather's side axis (for fans, the fan's face
  normal).
  - Spread or close the fan: rotate a sector about local Z.
  - Flex the fan's tips: rotate the `Tip` bones about local X.
  - Sway the plumes about local X; lift or drop them about local Z.
- **Checked.** The sheet's bent column has the plumes swayed 14 degrees per joint, the
  crest bent back 25 degrees and the fan spread 9 degrees per sector step with flexed tips.
  Nothing tears or opens a gap.

## In Studio

| Set | Model asset (upload_asset.py model) |
| --- | --- |
| `CraneHeadScholar` | `rbxassetid://111896928683178` |
| `CraneFanScholar` | `rbxassetid://105134179617320` |
| `CraneHeadAscendant` | `rbxassetid://108288146158770` |
| `CraneFanAscendant` | `rbxassetid://83252334471138` |
| `CraneHeadCascade` | `rbxassetid://107220451005849` |
| `CraneFanCascade` | `rbxassetid://97458231345868` |

Shade ramp: `rbxassetid://124559907609415`, the fox's upload of the same image.

**Rebuild** (in a sandbox, no FBX import step):
1. Upload the changed FBX with `python3 tools/upload_asset.py model <Set>.fbx` and put
   the new id in `place_crane_cosmetics.luau` (`ASSETS`).
2. Insert each model asset into Workspace as `_Import<Set>` (Studio MCP `insert_asset`).
3. Run `place_crane_cosmetics.luau` through `execute_luau`.
   - It turns each import into the Accessory `<Set>` in `ReplicatedStorage.Cosmetics.Crane`
     and deletes the imports.
   - It creates the folders if they're missing. That's sandbox only: never build inside
     the Rojo-mapped Cosmetics folder in a connected place.
   - Sets without an import keep their current template.
4. Export the folder:
   - Serialize `ReplicatedStorage.Cosmetics.Crane` (`tools/export_rbxm.luau`).
   - Post it to the receiver as `/CraneCosmetics.rbxm`.
   - Move the file to `assets/Cosmetics/Crane.rbxm`.

**Accessory layout** (as the fox's):
- `Handle` is the importer's `RootPart`, shrunk to an invisible 0.2 cube at the
  attachment point. It holds the `HatAttachment` / `WaistBackAttachment` and the bones.
- The skinned MeshParts are welded to it. Each has a `Region` attribute and a
  SurfaceAppearance.
- To tint a region, set both the MeshPart's `Color` and its `SurfaceAppearance.Color`.

**Checked in the sandbox (edit mode, R6 dummies):**
- All three looks sit at their attachments, the fans behind the waist.
- Setting `Bone.Transform` on the fan sectors and plume chains deforms the meshes.
- After `Model:ScaleTo(1.15)`, Cascade's meshes, bones and offsets all measure exactly
  1.15x.

## Untested

- **Clearance in game:** running against the arms (Ascendant's wide fan) and the legs
  (Cascade's train). Neither has been checked against the walk clip.
- **Hair and hats:** the plumes and crest with tall hair or hats. The Scholar cap is low
  (0.12 head heights) and may hide under hair.
- **Read and preview:** the read at phone distance, and the creator preview's rigid copies.
- **Animation:** nothing animates the bones yet.
