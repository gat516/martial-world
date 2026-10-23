# Demonic Human cosmetics (Blender, skinned)

Curved obsidian horns and a thin spaded whip tail, worn on the Demonic Human's R6 avatar.
They come from the user's prompt (`../briefs/demonic-human.md`) and panel 7 of
`docs/reference/race_cosmetics.png`. The user kept all three directions as variants ("looks good,
get everything in", 2026-10-23). Any horns go with any tail.

| Set | Variant | Attaches to (R6) | Meshes (one MeshPart each) | Tris |
| --- | --- | --- | --- | --- |
| `DemonHornsRam` | Ram | Head.HatAttachment | `<Set>_LeftHorn`, `_LeftHornVein`, `_RightHorn`, `_RightHornVein` | 2,372 |
| `DemonHornsSwept` | Swept | Head.HatAttachment | same four | 2,068 |
| `DemonHornsCrescent` | Crescent | Head.HatAttachment | same four | 2,052 |
| `DemonTailWhip` | Whip | Torso.WaistBackAttachment | `<Set>_Tail`, `_Spade`, `_TailVein` | 2,112 |
| `DemonTailHook` | Hook | Torso.WaistBackAttachment | same three | 2,280 |
| `DemonTailTrail` | Trail | Torso.WaistBackAttachment | same three | 2,184 |

**Intent.** Sinister but refined: "dark elegance and restrained menace", not a cartoon devil.
The horns are the hero, the read at game distance. They are thick, smooth, controlled curves
with hooked points, never tall needles. The tail is the secondary line and the crimson veins
are detail.

**Directions** (the sheet pairs them like this; in game they mix freely):

| Direction | Horns | Tail |
| --- | --- | --- |
| Ram (the reference) | rise back and out, then curl down beside the head, points hooking forward | arcs up behind the back, then falls in an S to the right, barbed arrowhead spade at knee height |
| Swept (aristocratic) | low and sleek, from the brow sweeping back past the head, tips lifting | rises behind the back into a question-mark hook, playing-card spade at shoulder height |
| Crescent (bold) | thick crescents rising out and curving in over the head (a "U" from the front) | streams back low behind the legs, sweeps aside, leaf-blade spade lifting at the end |

**Size against the body part** (R6 head mesh 1.20 wide x 1.02 tall; torso 1.87 wide x
2.0 tall; measured from the rig, and each JSON's `proportions` repeats them):

| Horns | Above head | / head height | Span | / head width | Base diameter | / head width |
| --- | --- | --- | --- | --- | --- | --- |
| Ram | 0.41 | 41% | 2.06 | 172% | 0.34 | 28% |
| Swept | 0.62 | 61% | 1.33 | 111% | 0.31 | 26% |
| Crescent | 0.70 | 69% | 1.78 | 149% | 0.40 | 33% |

| Tail | Length | / torso height | Thickness | / torso width | Spade length | / torso width | Running clearance |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Whip | 4.13 | 207% | 0.30 | 16% | 0.70 | 37% | 0.26 |
| Hook | 3.42 | 171% | 0.30 | 16% | 0.62 | 33% | 0.23 |
| Trail | 4.94 | 247% | 0.31 | 17% | 0.85 | 45% | 0.25 |

Running clearance is the smallest gap, in studs, between the tail at rest and R6 limb boxes
swinging 57 degrees (1 radian) each way about the hips and shoulders. Every whip leaves the back
about 0.8 studs above the waist so a leg kicked back passes under it. The first pass, which left
at 0.4, cleared by only 0.05.

Sheet: `sheets/demonic_human_directions.png` (`make_sheet.py`). It has one row per direction:
- front, side, back and rear three-quarter views
- the tail bent on its chain
- a horns close-up
- side and back seating close-ups at the horn root
- the game camera at 12 studs

## Files

- `build_demonic_human.py`: builds everything in the `Cosmetics` scene, beside the R6 reference.
  - Run it in a visible window: `tools/blender_live.sh run demonic-human <script> RENDER=True EXPORT=True SAVE_BLEND=True`.
    Pass all three flags: globals persist between runs in a window.
  - Writes `<Set>.fbx` and `<Set>.json`, `demonic_shade.png` (byte-identical to `fox_shade.png`)
    and `DemonicHuman.blend`.
  - Renders the tiles and `report.json` into `renders/` (not committed).
  - Tunables are named constants at the top: the `HORNS` / `TAILS` tables, colours, ridge and vein sizes.
- `make_sheet.py`: stitches `renders/` into the sheet (`uv run --with pillow python3 -I .../make_sheet.py`).
- Side-by-side view: `tools/blender_lineup.py` with
  `LOOKS = [[["DemonHornsRam", "DemonTailWhip"], ["DemonHornsSwept", "DemonTailHook"], ["DemonHornsCrescent", "DemonTailTrail"]]]`.
- `<Set>.json` holds:
  - the attachment
  - each mesh's region, tris, centre and size
  - every bone's parent, head, tail and `roblox_head`
  - colours, the shade ramp, `variant`, `mood` and `proportions`
  - horns: `seating`
  - tails: `limb_clearance_running` and `anchors`

## Space and import

Same as the fox (`../fox/README.md`, Space and import):
- **Attachment space.** Each FBX is in its attachment's space: the origin is the attachment point.
- **Blender axes.** X is the avatar's left, -Y its front, Z up.
- **Roblox mapping.** A Blender point `(x, y, z)` is `(-x, z, y)` in the attachment's Roblox
  frame, so mesh `Size = (bx, bz, by)` and its CFrame relative to the attachment is
  `CFrame.new(-cx, cz, cy)`. The JSON's `roblox_head` and anchor `roblox` fields already use this.
- **Upload.** Upload with `tools/upload_asset.py model` (true size).
- **Mesh names.** Every mesh name is unique across the six files.

## Colour (recolour contract)

| Region (material `Demon_<Region>`) | Meshes | Default (linear) |
| --- | --- | --- |
| `Horn` | `_LeftHorn`, `_RightHorn` | obsidian, a hint of crimson-black (0.030, 0.024, 0.028) |
| `HornVein` | `_LeftHornVein`, `_RightHornVein` | deep crimson (0.50, 0.02, 0.03) |
| `Tail` | `_Tail` | dark matte skin (0.034, 0.028, 0.034) |
| `Spade` | `_Spade` | obsidian (0.030, 0.024, 0.028) |
| `TailVein` | `_TailVein` (the whip's vein and the spade's inlay) | deep crimson (0.50, 0.02, 0.03) |

- **Ramp.** Shading is the shared greyscale ramp on UV V, used as a SurfaceAppearance `ColorMap`
  tinted by `Color` (set both `MeshPart.Color` and `SurfaceAppearance.Color`). The shared upload
  is `rbxassetid://124559907609415`.
- **Where it darkens.** Horns darken toward the points, and the whip toward its root. Veins and
  spade are white on the ramp (V = 1).
- **Bloodline glow.** A recolour could brighten the veins: set `TailVein` / `HornVein` to Neon, or
  give them a light colour.

## Construction (why there are no gaps)

- **Horns** are closed tubes along a Catmull-Rom path. Each is round-ended with a hooked point
  and has a slightly flattened section (`FLAT`).
  - **Ridges.** Narrow grooves cut around it (`RIDGES`) read as plates under the 28-degree crease.
  - **Seating.** The path starts inside the head. The build asserts that every root-ring vertex
    is at least 0.03 studs under the head surface (closest point on the R6 mesh). The actual
    minimum is 0.09 to 0.15, so the horn pierces the head and you see no gap from any side.
- **Veins** are closed diamond-section ridges whose underside is sunk into the surface they run
  on, tapering to a point at both ends. Horns have two or three each, with branches; the whip has
  one gentle spiral; the spade has a centre inlay on both faces.
- **Spade** is a closed slab with two bevelled tiers on each face. The whip's end runs 22% of the
  spade's length into it.

## Rig

One armature per set. `Root` is the attachment point, doesn't deform and is never keyed.

| Set | Hierarchy |
| --- | --- |
| Horns | `Root` -> `HornLBase` -> `HornL`, `Root` -> `HornRBase` -> `HornR` |
| Tail | `Root` -> `TailBase` -> `Tail1` -> `Tail2` -> `Tail3` -> `Tail4` -> `Tail5` |

- **Horn bones.** The base bones hold what's inside the head. The `HornL` / `HornR` heads sit
  where the horn leaves the head. Horns are rigid, but the bones allow a tilt or a recoil if
  something ever wants it.
- **Tail weights.** Same layout and weighting as the fox tail: smooth blends over 45% of a bone
  either side of each joint.
  - Local Z of every tail bone is the path's side normal: rotating about it curls, rotating
    about local X sways.
  - The spade and its inlay ride `Tail5`.
- **Checked.** The sheet's bent column shows Whip at -25, Hook at +20 (degrees per joint about
  local Z) and Trail swaying 18 about X, with no tearing.

## VFX hook

The purple flame wisp in the reference is an effect, not a mesh (it goes to `vfx`). Each tail
JSON's `anchors.vfx_wisp` is the point to attach it: on the whip just above the spade, riding
`Tail5`. It's given in attachment space (Blender `point` and Roblox `roblox`). The Studio import
should add an Attachment `VfxWisp` there, parented so it follows `Tail5`. `anchors.spade_tip` is
the spade's point.

## Not done yet

- **Studio import** (a separate agent):
  - upload the six FBX;
  - turn each into an Accessory as `place_fox_cosmetics.luau` does, with the `Region` attributes
    and SurfaceAppearances;
  - export `assets/Cosmetics/<Set>.rbxm`;
  - name them in the Demonic Human's `Cosmetics` (the race has no variants file yet).
- **Untested in game:** running clearance against real animations (checked only against limb
  boxes), horns with tall hats and hair, the read on a phone, and the near-black at distance.
- **Bones don't move yet:** nothing drives them; the shared sway script is planned.
