# Ghost cosmetics (Blender, skinned)

Accessories for the Ghost race's R6 avatar: a lingering cultivation spirit, sorrowful and elegant,
never horror (brief: `../briefs/ghost.md`, reference panel 8 of `docs/reference/race_cosmetics.png`).
The wisps are the hero: pale, fading silk that reads at game distance. The talisman is the face's
identity mark and stays flat on the brow.

The user kept all three directions as variants (2026-10-23, "looks good, get everything in"), each
with its own talisman:

| Variant | Talisman | Wisps |
| --- | --- | --- |
| Sleeves | `GhostTalismanStrip`: a long torn strip, set off centre so one eye shows | `GhostSleeveL` + `GhostSleeveR`: spectral bell sleeves, a broad drape and a smaller ribbon streaming back |
| Train | `GhostTalismanBanner`: the reference's swallowtail banner with a dark cord across the top | `GhostTrain`: the lower body. A sash on the lower back, a broad tail that flows back level, sinks and curls up, and two side sheets |
| Stole | `GhostTalismanSeal`: a small square seal tilted on the brow | `GhostStole`: celestial floating silk. A halo hoop behind the head, and an end floating out over each arm |

Any talisman works with any wisp set.

| Set | Attaches to (R6) | Meshes (one MeshPart each) | Tris |
| --- | --- | --- | --- |
| `GhostTalismanStrip` | Head.FaceFrontAttachment | `_Paper`, `_Ink` | 1,260 |
| `GhostTalismanBanner` | Head.FaceFrontAttachment | `_Paper`, `_Ink`, `_Cord` | 1,520 |
| `GhostTalismanSeal` | Head.FaceFrontAttachment | `_Paper`, `_Ink` | 696 |
| `GhostSleeveL` | Left Arm.LeftGripAttachment | `_Wisp`, `_Spirit` (the cuff) | 1,992 |
| `GhostSleeveR` | Right Arm.RightGripAttachment | `_Wisp`, `_Spirit` | 1,992 |
| `GhostTrain` | Torso.WaistCenterAttachment | `_Wisp`, `_Spirit` (the sash) | 3,270 |
| `GhostStole` | Torso.BodyBackAttachment | `_Wisp` | 4,208 |

Mesh names are `<Set>_<Region>`, unique across the seven files.

## Size against the body (printed on the sheet, in each JSON under `proportions`)

The R6 head mesh is 1.20 wide and 1.02 tall, an arm is 1 x 2, the torso 2 x 2, a leg 2 tall.

| Piece | Size | Ratio |
| --- | --- | --- |
| Strip talisman | 0.62 h x 0.34 w | 61% head height, 28% head width |
| Banner talisman | 0.56 h x 0.42 w | 55% head height, 35% head width |
| Seal talisman | 0.32 x 0.32 | 31% head height, 27% head width |
| Sleeve cuff | 1.50 tall at the back | 75% of arm length, opening 166% of arm width |
| Sleeve drape | 2.72 long | 136% of arm length, 76% of arm width |
| Train tail | 4.61 long | 230% of leg height, 82% of torso width |
| Train side sheets | | 166% of leg height; the set spans 158% of torso width |
| Stole hoop | top 2.35 above the shoulders | 118% of torso height |
| Stole ends | 4.01 long | 200% of torso height; the set spans 290% of torso width |

Sheet: `sheets/ghost_directions.png` (`make_sheet.py`), one row per variant. Columns: front, side,
back, rear 3/4, bent, the R6 run pose, the game camera at 12 studs (back and front), talisman
close-ups (front, the seat from the side, lifted 25 degrees), and a solid render without the fade.

## Files

- `build_ghost.py` builds everything in the `Cosmetics` scene beside the R6 reference.
  - Exports `<Set>.fbx` + `<Set>.json` and the ramps, renders `renders/` (not committed) and saves
    `Ghost.blend`.
  - Run it in the race's window: `tools/blender_live.sh run ghost art/player/cosmetics/ghost/build_ghost.py
    RENDER=True EXPORT=True`. Globals persist in a live window, so pass both every time.
  - Every tunable is a named constant at the top: `TALISMANS` (shape, place, tilt, tear, curl,
    glyph strokes), the ribbon tables (`SLEEVE_RIBBONS`, `TRAIN_RIBBONS`, `STOLE_RIBBONS`: path,
    width, bow, wave, twist, split, bones), `CUFF`, `SASH`, colours and ramps.
- `make_sheet.py`: stitches the sheet, `uv run --with pillow python3 -I art/player/cosmetics/ghost/make_sheet.py`.
- `<Set>.json`: attachment, each mesh's region, tris, centre and size, every bone (parent, head,
  tail, `roblox_head`), colours, ramp settings, proportions and the run-swing check.

## Space and import

Same contract as the fox (`../../../../docs/character/player-accessories.md`):
- **Attachment space.** Each FBX sits in its attachment's space: the origin is the attachment point.
- **Blender axes.** X is the avatar's left, -Y its front, Z up.
- **Roblox mapping.** A Blender point `(x, y, z)` is `(-x, z, y)` in the attachment's Roblox
  frame, so mesh `Size = (bx, bz, by)` and CFrame `CFrame.new(-cx, cz, cy)`, no rotation.
  `roblox_head` in the JSON uses this mapping.

Attachments in avatar space (R6 rest pose): FaceFrontAttachment `(0, -0.6, 2.5)`, LeftGripAttachment
`(1.5, 0, -0.5)`, RightGripAttachment `(-1.5, 0, -0.5)`, WaistCenterAttachment `(0, 0, 0)`,
BodyBackAttachment `(0, 0.5, 1)`.

## Colour, shade and fade (recolour contract)

| Region material | Meshes | Default (linear) | Texture |
| --- | --- | --- | --- |
| `Ghost_Paper` | `_Paper` | faded parchment (0.79, 0.62, 0.32) | `fox_shade.png` |
| `Ghost_Ink` | `_Ink` | vermilion (0.52, 0.025, 0.015) | `fox_shade.png` (V = 1, flat) |
| `Ghost_Cord` | `_Cord` | dark indigo (0.025, 0.03, 0.08) | `fox_shade.png` (V = 1, flat) |
| `Ghost_Spirit` | `_Spirit` (cuffs, sash) | pale blue-white (0.60, 0.78, 0.95) | `ghost_fade.png` |
| `Ghost_Wisp` | `_Wisp` (every ribbon) | pale cyan (0.42, 0.78, 0.90) | `ghost_fade.png` |

- **Paper** uses the shared shade ramp: `fox_shade.png` here is byte-identical to the fox's, so reuse
  `rbxassetid://124559907609415`. V runs 1 in the middle of the paper to 0.2 at its torn edges, so
  the edges read aged and darker.
- **Wisps** use `ghost_fade.png` (RGBA, 4 x 128, V only). Value goes 0.78 at the root to 1.0 at the
  tip, and alpha goes 0.85 to 0.12 from a quarter of the way along. V is 0 where a ribbon leaves the
  body and 1 at its tip. The stole's hoop fades halfway toward its top. In Roblox, use it as the
  SurfaceAppearance `ColorMap` with `AlphaMode = Transparency`. That is the fade the brief asks for.
  The cuff and sash sit near V 0.1, so they stay mostly opaque.
- To tint a region, set both the MeshPart's `Color` and `SurfaceAppearance.Color`.
- Glyphs and cord are their own meshes, so they recolour (red or dark ink, per the brief).

## Construction (why there are no gaps)

- **Talismans.** Each is a closed slab dropped onto the head's real surface: a ray along +Y onto the R6 mesh at
  every vertex. The back face is 0.016 inside the head and the front 0.022 out, so it sits flush with no gap
  from any side. Torn edges come from an outline nibbled
  inward (deeper at the bottom and corners); the bottom curls up to 0.035 off the face. Ink
  strokes are closed bands whose backs are buried in the paper, brush-tapered at both ends. The
  build asserts if any point misses the face.
- **Ribbons.** They are closed lens-section sweeps (nothing single-sided). Their roots start inside the
  body or the cuff and stay flat where they leave it, and the edges billow back further out (`BOW`).
  The width swells softly along the length (`WAVE`), and the ends are round, not spiky. A split end
  (`SPLIT`) gives two round tongues that grow out of the ribbon's own width, with no seam.
- **Cuffs.** Each is a solid ring with its inner wall inside the arm. On the body side it is pressed flat
  against the arm's inner face (x 1.03), where the torso and leg sit flush with the arm.
- **Sash.** A closed band on the torso's back face, half sunk in.
- **Clearance.** Checked against the R6 run swing (limbs 57 degrees each way, 17 phases). Sleeves ride their arm.
  No vertex enters an arm, leg or the torso. The only exception is the left sleeve's drape tip, which dips 0.09
  under the floor at full forward swing while held rigid; a bend of the drape bones clears it. Each
  JSON has `run_clearance`.

## Rig

One armature per set. `Root` is the attachment point, doesn't deform and is never keyed.

| Set | Hierarchy |
| --- | --- |
| Talismans | `Root` -> `TalismanBase` -> `Talisman` |
| Sleeves | `Root` -> `WispBase` -> `WispA1..WispA4` (drape), `WispBase` -> `WispB1..WispB3` (ribbon) |
| Train | `Root` -> `WispBase` -> `WispTail1..5`, `WispL1..4`, `WispR1..4` |
| Stole | `Root` -> `WispBase` -> `WispHoopL1..3`, `WispHoopR1..3`, `WispTrailL1..4`, `WispTrailR1..4` |

- **`TalismanBase`** holds the pinned top band. `Talisman`'s hinge runs across the paper 0.09-0.10
  below its top. Rotating it about its local X lifts the paper off the face (flutter). Weights blend
  over 0.12 studs below the pin.
- **`WispBase`** holds the buried roots, the cuffs and the sash. Each chain starts where its ribbon
  leaves the body and ends at 97% of its length. Weights blend smoothly over 45% of a bone either side of each joint.
- **Rolls.** Each wisp bone's local Z is the ribbon's face normal. Rotate about local X to bend a ribbon across
  its face (billow), and about local Z to sway it edgewise.
- **The hoop** is one mesh driven from both ends. Its top blends 50/50 between `WispHoopL3` and `WispHoopR3`.
- **Checked on the sheet:** every wisp joint bent 22 degrees and the talisman lifted 25 degrees. No tearing.
- **Sway script.** These names fit the planned sway script's pattern (chains `<Name>1..n`). It will need
  to treat `Wisp*` chains like tails: slow drift with lag down the chain.

## In Studio

Not imported yet (a separate agent). Follow the fox README's rebuild steps: upload each FBX with
`python3 tools/upload_asset.py model <Set>.fbx`, upload `ghost_fade.png` with the MCP's
`upload_image` (or reuse the fox ramp for the paper), insert as `_Import<Set>`, and turn each into
an Accessory with a 0.2 invisible Handle at its attachment. Sleeves are two accessories (one per
arm). Then record the asset ids here.

## Untested

Everything in game: transparency sorting of the ribbons against each other, the fade at distance,
hats or hair against the stole's hoop, and sleeves against tools held in the right hand. Nothing
animates the bones yet; mist or particles on the wisps are for `vfx`.
