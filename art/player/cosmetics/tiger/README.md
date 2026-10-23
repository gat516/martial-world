# Beast Folk (Tiger) cosmetics (Blender, skinned)

Tiger ears, tails and whiskers for the Beast Folk Tiger's R6 avatar. The user kept all three
directions as variants (2026-10-23). Any ears, tail and whiskers can be worn together, and the
whiskers can be left off.

| Direction | Mood | Ears | Tail | Whiskers |
| --- | --- | --- | --- | --- |
| Cub | cute | `TigerEarsRound`: plump round domes | `TigerTailCurl`: thick, hangs low, curls up into a white-then-dark tip | `TigerWhiskersMarks`: three short strands |
| Feral | aggressive | `TigerEarsPinned`: pinned flat out and back, almond peak | `TigerTailLash`: long, held level off the hips, whips up into a dark point | `TigerWhiskersFine`: three long strands, slightly drooped |
| Regal | proud | `TigerEarsTufted`: upright, flat-round top, fur fringe on the outer rim | `TigerTailCrown`: rises at the avatar's left in a high question-mark arc | `TigerWhiskersCurl`: two strands curling up at the tip |

Sheet: `sheets/tiger_cosmetics.png`, one row per direction. It shows front, side, back, rear
three-quarter, a bent pose, the ear backs close up, the face close up, the ear seating close up
and the bent tail close up. Each piece's size is printed next to its row.

## Sizes (against the part each attaches to)

Measured from the R6 rig: the head is 1.20 wide and 1.02 tall (the fox sheet's measure), the
torso is 2 tall and 1 deep. The approved cute fox ears stand 64% of head height. The rounded
tiger ears sit a little lower.

| Set | Size | Tris |
| --- | --- | --- |
| `TigerEarsRound` | 0.58 tall (57% of head height), 0.64 wide (53% of head width) | 1,512 a pair |
| `TigerEarsPinned` | 0.25 tall (25%), 0.76 wide (64%): low and wide on purpose | 1,416 |
| `TigerEarsTufted` | 0.68 tall (66%), 0.69 wide (58%) | 1,512 |
| `TigerTailCurl` | 4.1 long (206% of torso height), 1.05 thick with fur (105% of torso depth) | 4,870 |
| `TigerTailLash` | 5.2 long (260%), 0.82 thick (82%) | 5,238 |
| `TigerTailCrown` | 4.0 long (200%), 0.97 thick (97%) | 4,870 |
| `TigerWhiskersMarks` | span 127% of head width, 13% past the head's side | 756 |
| `TigerWhiskersFine` | span 146%, 23% past the side | 756 |
| `TigerWhiskersCurl` | span 140%, 20% past the side | 504 |

The tails are over the 4,000 target but under the 6,000 cap. Stripes need two clump rows each,
which adds clumps.

**Limb clearance.** Each JSON has `sizes.limb_clearance`. For each limb it gives the smallest gap
between the furred tail and that limb, with legs swung 50 degrees either way about the hips and
arms about the shoulders. It skips the first 0.6 studs, where every tail root sits above the
legs' hinge. Results:
- Lash: -0.02 at the legs (effectively clear).
- Crown: -0.1 at the legs, near the root.
- Curl: -0.24 at the legs, near the root. Being thick, it brushes the backs of the legs at full stride.
- Arms: all clear. Crown passes 0.05 from the left arm.

## Files

- `build_tiger.py` builds everything into the `Cosmetics` scene beside the R6 reference.
  - **Run:** `tools/blender_live.sh run tiger art/player/cosmetics/tiger/build_tiger.py RENDER=True EXPORT=True`
    or headless with `tools/blender_run.sh`. Globals persist in a live window, so pass both flags.
  - **Outputs:** `<Set>.fbx` and `<Set>.json`, `tiger_shade.png` and `Tiger.blend`.
    `renders/` holds the sheet tiles plus `sizes.json` (not committed).
  - **Tunables:** every one is a named constant at the top: the `EARS`, `TAILS` and `WHISKERS` tables, colours, clump layout and the clearance check.
- `make_sheet.py`: stitches `renders/` into `sheets/tiger_cosmetics.png`. Run it with `uv run --with pillow python3 -I art/player/cosmetics/tiger/make_sheet.py`.
- `<Set>.json` holds:
  - the attachment
  - each mesh's region, tris, centre, size and `roblox_center`
  - every bone's parent, head, tail and `roblox_head`
  - the colours and the shade ramp
  - `sizes`

## Space and import

- Each FBX is in its attachment's space; the attachment is the origin.
- Blender X is the avatar's left, -Y its front, Z up.
- A Blender point `(x, y, z)` is `(-x, z, y)` in the attachment's Roblox frame, so mesh
  `Size = (bx, bz, by)` and its CFrame from the attachment is `CFrame.new(-cx, cz, cy)`, with no rotation.
  This is the same as the fox.
- Attachments in avatar space:
  - **HatAttachment:** `(0, 0, 3.1)`
  - **WaistBackAttachment:** `(0, 0.5, 0)`
  - **FaceFrontAttachment:** `(0, -0.6, 2.5)`, which is Head centre + Roblox `(0, 0, -0.6)`
- Every mesh name is unique across the nine files.
- The import follows the fox pipeline (`docs/character/player-accessories.md`, step 4):
  upload each FBX with `tools/upload_asset.py model`, upload `tiger_shade.png` with `upload_image`,
  `insert_asset`, then run a `place_tiger_cosmetics.luau` adapted from the fox's. That step hasn't been done yet.

## Colour (recolour contract)

One MeshPart per colour region. Its material and `Region` attribute name the region.

| Region | Meshes | Default (linear) |
| --- | --- | --- |
| `FurOuter` | `_LeftEar`, `_RightEar`, `_Tail` | tiger orange (0.78, 0.25, 0.035) |
| `FurStripe` | `_LeftEarBack`, `_RightEarBack` (dark ear tip), `_TailStripe` (stripes and the dark end) | dark brown (0.045, 0.022, 0.014) |
| `FurTip` | `_LeftEarSpot`, `_RightEarSpot`, `_TailTip` (white band) | white (0.92, 0.89, 0.83) |
| `FurInner` | `_LeftEarInner`, `_RightEarInner` | pale cream (0.93, 0.82, 0.70) |
| `Whiskers` | `<Whiskers>_Whiskers` | dark brown (0.06, 0.035, 0.025), so they read on any skin tone |

**Shade ramp.** `tiger_shade.png` is a greyscale ramp on UV V, like the fox's:
- tails darken toward the root
- outer ears darken toward the tip
- everything else is white

Use it as a SurfaceAppearance `ColorMap`, tinted by `Color`.

## Construction

- **Tail.** Built the fox's way:
  - A smooth core plus about 70-80 closed, flame-shaped clumps.
  - Each clump's underside is buried in the core and its end lifts off it.
  - Clumps are graded big at the root and small at the tip.
  - Nothing is single-sided.
- **Stripes follow the clumps.**
  - `PATTERN` colours each clump row (O orange, S stripe, W white, D dark end).
  - Each stripe is two rows: the rows are staggered by half a clump, so a single dark row checkers with its orange neighbours.
  - The core under each stripe is dark too, so gaps don't flash orange.
- **Ears.** A solid cupped shell with cream tufts in the cup.
  - The back has a dark tip band from rim to rim.
  - A small, soft white dash straddles the band's lower edge.
  - Both are closed slabs sunk into the shell.
  - The first version, a white dot inside a dark oval, read as a pair of eyes from behind.
  - The base is sunk 0.1 under the head's surface across its whole footprint, conformed to the rounded top.
- **Whiskers.** Each cheek has one root point on the head's front face, sunk 0.05.
  - Each strand is one closed, tapered, rounded shape sticking straight out sideways, a little forward, fanned by angle.
  - The strands don't follow the face's curve.
  - Styles differ only in count, length and tip curl.

## Rig

| Set | Hierarchy | Move it |
| --- | --- | --- |
| Ears | `Root` -> `EarLBase` -> `EarL`, `Root` -> `EarRBase` -> `EarR` | ears fold back about local X |
| Tail | `Root` -> `TailBase` -> `Tail1..Tail5` | curl about local Z, wag about local X |
| Whiskers | `Root` -> `WhiskerL`, `Root` -> `WhiskerR` | twitch: small rotations; hinge at the cheek root |

- `Root` is the attachment point and doesn't deform.
- Base bones hold the buried vertices.
- Weights blend smoothly across each tail joint, and over the lowest third of each ear.
- The sheet's bent column shows:
  - Curl at -35 degrees per joint about Z.
  - Crown at -30 degrees per joint about Z.
  - Lash swaying 25 degrees per joint about X.
  - Ears folded back 50 degrees.

## Untested

- **In game:** the read at phone distance, and running clearance (Curl brushes the legs near the root).
- **Fit:** the whiskers with face accessories, the ears with tall hair.
- **Roblox import:** not done yet, including skinning after upload and `ScaleTo(1.15)`.
- **Animation:** nothing animates the bones yet.
