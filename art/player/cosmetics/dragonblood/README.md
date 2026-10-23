# Dragonblood cosmetics (Blender, skinned)

Antler horns and short scaled tails for the Dragonblood race's R6 avatar. The user kept all three
directions as variants (2026-10-23). Any horns go with any tail.

**Intent.** Noble, bloodline-awakened dragon cultivators. The antler silhouette is the hero: it
rises from the temples and sweeps up and back over the hair, and it reads as "dragon, regal" from
40 studs. The tail is the quieter second voice: short and sturdy, with deep green scales, a
cream spine ridge and a cream tuft. Every end is soft and rounded, never spiky.

| Direction | Horns | Tail | Mood |
| --- | --- | --- | --- |
| A | `DragonHornsAntler`: the approved part-built DragonHorns remodelled. The beams splay in a wide V from the temples (the tips sit well outside the head's sides), with two long, capsule-like tines a side. Ivory beam, pale gold tines and tip. | `DragonTailTuft`: back and a little down, the tuft flowing up and out | regal (the approved look) |
| B | `DragonHornsCelestial`: an eastern dragon antler. The beam runs long and low back over the head and lifts at the end, with three short tines standing up like a crown. Pale jade with gold tips. | `DragonTailRising`: rises behind the back in a slow arc into a tall plume | noble, celestial |
| C | `DragonHornsCub`: a young dragon's horn. Short and chunky, it curls back at a round tip and has one fat forward tine (a soft Y). Ivory and gold. | `DragonTailStub`: stubby and thick, flicks out to the side into a short, fat flame of a tuft | cute |

## Size against the body part

The R6 head mesh is 1.20 wide and 1.02 tall; the torso is 1.87 by 1.87. Each JSON carries these
numbers under `proportions`.

| Set | Size | Tris |
| --- | --- | --- |
| Antler | 1.31 above the head (129% of head height); 0.34 across where it leaves the head (28% of head width); 2.27 tip to tip (190%) | 2,652 a pair |
| Celestial | 0.92 above the head (90%); root 0.35 (29%); span 1.47 (122%); reaches 1.1 behind the head | 3,240 a pair |
| Cub | 0.74 above the head (73%); root 0.42 (35%); span 1.29 (108%) | 2,064 a pair |
| Tuft | reaches 2.60 behind the back (139% of torso height); 1.31 wide (70% of torso width) | 5,544 |
| Rising | reaches 1.98 behind the back (106%); 0.93 wide (50%); stands about 1.9 above the waist | 5,544 |
| Stub | reaches 1.44 behind the back (77%); 1.23 wide (66%) | 4,828 |

**Legs.** Each tail leaves the back at the torso's lower edge, raised so its underside clears
the hips. A leg can swing back 35 degrees (Stub: 30) before it touches the tail. The few
centimetres at the root, where a swung R6 leg's top corner passes through the torso anyway, are
not counted. The JSON key is `leg_swing_back_clear_deg`.

Sheet: `sheets/dragonblood_directions.png` (`make_sheet.py`). It has one row per direction:
- the whole body from the front, side, back and rear three-quarter
- the horns close, from the front three-quarter
- a bent pose: horns tipped back 15 degrees, the tail curled 20-22 degrees per joint (Stub swayed 25 degrees sideways)
- two close-ups of the horn root, from the side and the back
- a close-up of the bent tail
- the game camera at 12 studs

The size ratios are printed in each row's label.

## Construction (why there are no gaps)

- **Horns.** Each beam is a closed, tapered tube along a smooth curve. It starts 0.3 studs inside
  the head and passes out through its surface, so the footprint can't show a gap from any side.
  Soft knuckles swell where the tines leave the beam. The tines are closed tubes rooted at the
  beam's centre line. Every tip ends in a hemisphere.
  - **Colour seam.** The gold `HornTip` piece starts as a sleeve 1.5% fatter than the ivory
    body, just before the seam (`SEAM_OVERLAP`, `SEAM_SLEEVE`). The body's end cap sits inside
    it, so no light line or crack shows where the colours meet.
- **Tail core.** A smooth, slightly flattened tube. Its root sits inside the torso, and it tapers
  toward the tuft.
- **Scales.** Flat shingle plates in staggered rows. Each plate's underside is buried in the
  core, and its rounded end lifts only 5% off the core, so each row overlaps the next and the
  surface stays smooth. They stop where the fur takes over.
- **Ridge.** Rounded cream fins along the spine, buried at the foot, their peaks leaning toward the
  tip, shrinking toward the tuft.
- **Tuft.** It grows out of the tail rather than being stuck on the end:
  - The fur clumps (closed wedges, the fox's construction) start among the last scales.
  - Clumps are short and lie flat at the root, then grow longer toward the end.
  - They run together over a cream tuft core into one flame-shaped plume that closes to a point.

## Colour (recolour contract)

Each colour region is its own mesh, which becomes one MeshPart. Its material carries the
region's name.

| Region | Meshes | Default (linear) |
| --- | --- | --- |
| `Horn` | `<Set>_LeftHorn`, `_RightHorn` | ivory (0.855, 0.776, 0.604); Celestial pale jade (0.36, 0.52, 0.36) |
| `HornTip` | `<Set>_LeftHornTip`, `_RightHornTip` | pale gold (0.672, 0.402, 0.077); Celestial warm gold (0.75, 0.48, 0.10) |
| `Scales` | `<Tail>_Tail` | deep green (0.04, 0.16, 0.085) |
| `Ridge` | `<Tail>_TailRidge` | cream (0.83, 0.75, 0.58) |
| `Tuft` | `<Tail>_TailTuft` | cream-white (0.88, 0.84, 0.73) |

The materials are shared by region, so each set's own defaults are in its JSON `colors`.

`dragon_shade.png` is a greyscale ramp on UV V (white, darkening to 0.58). Each region uses it differently:
- horns: V runs along the beam, so the root is darker; the tines are lighter
- scales and ridge: V runs along the tail, so the root is darker
- tuft: white throughout

Use it as a SurfaceAppearance `ColorMap` tinted by Color, as on the fox. Set both
`MeshPart.Color` and `SurfaceAppearance.Color` to recolour.

## Rig

There is one armature per set. `Root` is the attachment point; it doesn't deform and is never
keyed.

| Set | Hierarchy |
| --- | --- |
| Horns | `Root` -> `HornLBase` -> `HornL`, `Root` -> `HornRBase` -> `HornR` |
| Tail | `Root` -> `TailBase` -> `Tail1` -> `Tail2` -> `Tail3` -> `Tail4` -> `Tail5` |

- **Horns.** `HornXBase` runs from the buried root to where the beam leaves the head, and holds
  the buried vertices. `HornX` is the rest of the horn, rigid, with its hinge at the head
  surface. Local Z is world +X: rotating about it tips the horn forward (+) or back (-). Keep
  twitches under about 0.2 rad.
- **Tail.** Bones follow the tail's own frame, as on the fox: local Z curls and uncurls, local X
  sways sideways. Weights blend across about 45% of a bone on either side of each joint.
  `Tail1`'s head is where the tail leaves the back. `Tail5` ends at 97% of the length.

Every bone's head and tail, in attachment space, is in each JSON under `bones`.

## Space and export

Each FBX is in its attachment's space:

| Sets | Attachment | Avatar position |
| --- | --- | --- |
| Horns | `HatAttachment` | (0, 0, 3.1) |
| Tails | `WaistBackAttachment` | (0, 0.5, 0) |

- **Axes.** In Blender, X is the avatar's left, -Y its front and Z up. A Blender point
  `(x, y, z)` is Roblox `(-x, z, y)` from the attachment. A mesh's Size is `(bx, bz, by)` and
  its CFrame is `CFrame.new(-cx, cz, cy)`, with no rotation.
- **Mesh names.** Every mesh name is unique across the six files.

## Files

- **`build_dragonblood.py`** builds all six sets in the `Cosmetics` scene, beside the R6
  reference. It exports `<Set>.fbx` + `<Set>.json`, writes `dragon_shade.png`, saves
  `Dragonblood.blend` and renders the sheet tiles into `renders/` (not committed).
  - Run it in its own window: `tools/blender_live.sh open dragonblood`, then
    `tools/blender_live.sh run dragonblood art/player/cosmetics/dragonblood/build_dragonblood.py RENDER=True EXPORT=True`.
  - Pass both flags every time: globals persist between runs in one window.
  - Every tunable is a named constant at the top: the `HORNS` and `TAILS` tables, the colours,
    the seam sleeve and the shade ramp.
- **`make_sheet.py`** stitches the tiles: `uv run --with pillow python3 -I art/player/cosmetics/dragonblood/make_sheet.py`.

## Not done yet

- **Studio.** Nothing is uploaded or placed. The import step follows the fox:
  - Upload each FBX with `tools/upload_asset.py model`, and the shade ramp with `upload_image`.
  - Insert each upload as `_Import<Set>`.
  - Write a `place_dragonblood_cosmetics.luau` (from the fox's) that builds the Accessories,
    with a `Region` attribute on each MeshPart.
  - Export the result to `assets/Cosmetics/`.
  - Name the variants in the race's `Cosmetics`.
- **Replacing the placeholder.** The Studio-part `DragonHorns` placeholder stays in
  `assets/Cosmetics/Spirits.rbxm` until this replaces it.
- **Untested in game:** how the wide V of Antler sits with tall hats and hair, its phone-distance
  read, running clearance and `ScaleTo(1.15)`.
- **Animation.** Nothing animates the bones yet.
