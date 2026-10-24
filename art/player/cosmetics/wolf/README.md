# Beast Folk (Wolf) cosmetics (Blender, skinned)

Wolf ears and wolf tails for the Beast Folk Wolf variant's R6 avatar. These are built the same way
as the approved fox set (`../fox/`, on its branch): same rig, recolour regions, sealed fur, ear
seating and checks. The user approved all three looks as variants (2026-10-23), and any ears go
with any tail. Prompt: `../briefs/wolf.md`. Reference: `docs/reference/race_cosmetics.png`, panel 1.

| Set | Attaches to (R6) | Meshes (one MeshPart each) | Tris | Size |
| --- | --- | --- | --- | --- |
| `WolfEarsSentinel` | Head.HatAttachment | `<Set>_LeftEar`, `_LeftEarInner`, `_RightEar`, `_RightEarInner` | 1,768 | 65% of head height, base 39% of head width |
| `WolfEarsRuff` | Head.HatAttachment | same four | 1,768 | 58% h, 37% w |
| `WolfEarsLance` | Head.HatAttachment | same four | 1,768 | 39% h (laid back), 38% w |
| `WolfTailBrush` | Torso.WaistBackAttachment | `WolfTailBrush_Tail`, `WolfTailBrush_TailTip` | 3,702 | 2.01 x torso height long, 0.77 x torso width thick |
| `WolfTailMane` | Torso.WaistBackAttachment | `WolfTailMane_Tail`, `WolfTailMane_TailTip` | 3,702 | 1.99 x, 0.98 x |
| `WolfTailBanner` | Torso.WaistBackAttachment | `WolfTailBanner_Tail`, `WolfTailBanner_TailTip` | 3,514 | 2.13 x, 0.73 x |

The head is 1.20 wide and 1.02 tall, and the torso is 1.87 x 2.00. The approved fox ears are
about 64% of head height with a base 40% of head width.

Looks (the sheet rows and the lineup):
- **A, cool:** Sentinel ears + Brush tail.
  - Sentinel: upright, a clean firm point, charcoal rims.
  - Brush: the reference, a full grey brush with a pale point.
- **B, tuff:** Ruff ears + Mane tail.
  - Ruff: shorter, splayed out to the sides, a battle notch in the outer rim and fur serrations near the base.
  - Mane: broader and flatter (a wide fan from behind) with shaggy flared clumps.
- **C, sleek:** Lance ears + Banner tail.
  - Lance: laid well back along the head, the tip sweeping back.
  - Banner: slim at the root, filling out into a long, full pale end.

Every tail leaves the lower back a little above the waist, carries back and arcs down to about
knee height. That arc is what clears the running legs. An R6 leg swung back 1 radian sweeps up to
its back face's line and reaches about 2.06 studs from the hip, so a tail hanging straight down
from the waist would clip it.

Sheets:
- `sheets/wolf_cosmetics.png`: one row per look. Front, side, back, rear three-quarter, bent,
  both running phases, game camera, where it leaves the back, and a bent close-up. Each tail's
  size against the torso and the running check are on the left. Under the rows is the lineup,
  one body per look.
- `sheets/wolf_ears.png`: front, side, back, fold, flick, three seating close-ups and two game
  camera shots, with each set's size against the head and its measured seat.

## Files

- `build_wolf.py`: builds everything in the `Cosmetics` scene beside the R6 reference.
  - Builds into the `WolfCosmetics` collection. `FoxCosmetics` is hidden, not deleted.
  - Exports `<Set>.fbx` and `<Set>.json`, writes `wolf_shade.png` and saves `Wolf.blend`.
  - Renders the sheet tiles into `renders/` (not committed).
  - Every tunable is a named constant at the top: the `EARS` / `TAILS` tables, tufts, colours, clump grading.
- `lineup.py`: lays the three looks out side by side in a `Lineup` scene (`tools/blender_lineup.py`) and renders the lineup strip.
- `make_sheet.py`: stitches the sheets (`ears` for the ear sheet), run through `uv run --with pillow`.
- `<Set>.json` holds:
  - the attachment
  - each mesh's region, tris, centre and size
  - every bone's parent, head, tail and `roblox_head`
  - the colours and the shade settings
  - `proportions` against the head or torso
  - the measured `seat` (ears)
  - `run_clearance` (tails)

## Space and import

- **Attachment space.** Each FBX sits in its attachment's space: the origin is the attachment point.
- **Blender axes.** X is the avatar's left, -Y its front, Z up.
- **Roblox mapping.** A Blender point `(x, y, z)` is `(-x, z, y)` in the attachment's Roblox frame.
  - Mesh `Size = (bx, bz, by)`.
  - Its CFrame relative to the attachment is `CFrame.new(-cx, cz, cy)`, no rotation.
  - The JSON's `roblox_head` already uses this mapping.
- **Mesh names.** Every mesh name is unique across the six files.
- **Import.** Done (In Roblox, below).

## Colour (recolour contract)

Each colour region is its own MeshPart. Materials are prefixed `Wolf_` so another race's rebuild
can't recolour them. The JSON's `region` gives the plain region name.

| Material (region) | Meshes | Default (linear) |
| --- | --- | --- |
| `Wolf_FurOuter` (`FurOuter`) | `_LeftEar`, `_RightEar`, `_Tail` | mid charcoal grey (0.20, 0.205, 0.22) |
| `Wolf_FurInner` (`FurInner`) | `_LeftEarInner`, `_RightEarInner` | muted cream (0.80, 0.74, 0.62) |
| `Wolf_FurTip` (`FurTip`) | `_TailTip` | near-white (0.88, 0.87, 0.84) |

**Shade ramp.** `wolf_shade.png` uses the fox's settings, so it is byte-identical to
`fox_shade.png`. Reuse the uploaded ramp, `rbxassetid://124559907609415`. It runs on UV V:
- tail: darker toward the root
- outer ears: darker toward the tips, and darkest on the front rim around the cream (`RIM_DARK`), the reference's charcoal rims
- inner ears and the tail tip: V = 1 (white)

## Fur and seating

- **Tail fur.**
  - A full core runs the length of the tail.
  - About 30 clumps are graded big at the root to small at the tip (`CLUMP_GRADE` 1.40 to 0.55).
  - Each clump is a closed wedge buried in the core: no floating shells and no see-through gaps.
  - The end is a soft long point (`CAP`).
- **Ear seating.** As on the fox:
  - The base is sunk about 0.10 studs under the head surface, measured along the surface normal.
  - Feet past the head's rounded edge are pulled in.
  - Measured on every set: the base sits 0.093 to 0.110 deep, with 0 vertices hanging off the head.
- **Inner fur.**
  - The fox's tuft layout, shorter, a touch fatter and curling less, so the cream stays inside the grey cup.
  - The cushion covers 56% of the ear's width (`INNER_SPAN`; the fox's is 66%), which leaves a wider charcoal rim.

## Rig

Same as the fox. One armature per set. `Root` is the attachment point; it doesn't deform and is
never keyed.

| Set | Hierarchy |
| --- | --- |
| Ears | `Root` -> `EarLBase` -> `EarL`, `Root` -> `EarRBase` -> `EarR` |
| Tail | `Root` -> `TailBase` -> `Tail1` -> `Tail2` -> `Tail3` -> `Tail4` -> `Tail5` |

- **Rolls.** Tail bones' local Z follows the tail's side axis.
  - Tail: rotate about local X to sway, about local Z to lift or tuck.
  - Ears: rotate about local Z to fold back, about local X to flick out.
- **Bent check.** The sheet shows the tails at -16 degrees sway per joint, the ears folded 60
  degrees and flicked 35 degrees.

## In Roblox

`assets/Cosmetics/Wolf.rbxm` is the Folder `Wolf` (mapped into `ReplicatedStorage.Cosmetics`) with
the six Accessories, built by `place_wolf_cosmetics.luau` (the fox's script with the wolf's sets and
colours). Beast Folk Wolf wears look A, `WolfEarsSentinel` + `WolfTailBrush`
(`src/shared/Identity/Variants/BeastFolk.luau`); B and C wait for a style picker.

| Set | Model asset (upload_asset.py model, 2026-10-23) |
| --- | --- |
| `WolfEarsSentinel` | `rbxassetid://113657184040034` |
| `WolfEarsRuff` | `rbxassetid://110825140385163` |
| `WolfEarsLance` | `rbxassetid://99712108208240` |
| `WolfTailBrush` | `rbxassetid://83511268782093` |
| `WolfTailMane` | `rbxassetid://83228390208191` |
| `WolfTailBanner` | `rbxassetid://108213896664267` |

The shade ramp is the shared `rbxassetid://124559907609415`.

**Rebuild** (in a sandbox, no FBX import step):
1. Upload the changed FBX with `python3 tools/upload_asset.py model <Set>.fbx` and put the new id in
   `ASSETS` in `place_wolf_cosmetics.luau`.
2. Insert each model asset into Workspace as `_Import<Set>` (Studio MCP `insert_asset`).
3. Run `place_wolf_cosmetics.luau` through `execute_luau`. Sets without an import keep their
   current template.
4. Export the folder (`_G.exportRbxm("ReplicatedStorage.Cosmetics.Wolf")`, `tools/export_rbxm.luau`)
   to `assets/Cosmetics/Wolf.rbxm`.

Checked in a sandbox (2026-10-23) on R6 dummies from the creator's `Dummy` template, one per look:
handles sit exactly on their attachments, every mesh centre matches the JSON, bending the
`Tail1..5` and `EarL`/`EarR` bones deforms the meshes, the ear bases sit flush on the head from a
close side view at head height, and `ScaleTo(1.15)` keeps everything on its attachment.

## Not done here

- **Untested in game:**
  - the tails during the real run animation (the measured swing is the R6 default, 1 radian)
  - sitting, where the tail dips to knee height behind
  - the ears with tall hats
  - Lance's low profile at phone distance
  - the creator preview's copies
- **Budget.** The ear pairs are 1,768 tris, over the ~1,500 budget, the same as the fox's tufted ears.
