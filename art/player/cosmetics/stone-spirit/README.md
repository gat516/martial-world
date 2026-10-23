# Stone Spirit cosmetics (Blender, rigged)

These are floating jade-veined rock shards and stone plates for the Stone Spirit race's R6
avatar. The brief is `../briefs/stone-spirit.md` and the concept is panel 5 of
`docs/reference/race_cosmetics.png`.

There are three directions, and all three are kept as variants (user, 2026-10-23: "looks good, get
everything in"). Each direction is worn as a whole set of three accessories. The sets aren't made
to be mixed: Orbit's or Fist's shards would cut through Peak's pauldrons.

| Variant | Hero | Accessories (one FBX + JSON each) |
| --- | --- | --- |
| Peak | two big stacked-stone pauldrons with floating chips | `StonePeakPlateL`, `StonePeakPlateR`, `StonePeakShards` (5-shard crescent behind the head) |
| Orbit | a full ring of six shards circling the shoulders | `StoneOrbitShards`, `StoneOrbitBracerL`, `StoneOrbitBracerR` (quiet forearm bracers) |
| Fist | heavy stone gauntlets over the forearms and fists | `StoneFistGauntletL`, `StoneFistGauntletR` (a floating chip each), `StoneFistShards` (3 shards high over the shoulders) |

| Accessory | Attaches to (R6) | Meshes | Tris |
| --- | --- | --- | --- |
| `StonePeakPlateL` / `R` | Left/Right Arm `Left/RightShoulderAttachment` | `_Rock`, `_Jade`, `_Chip1`, `_Chip2` | 692 each |
| `StonePeakShards` | Torso `NeckAttachment` | `_Shard1..5` + `_Shard1..5Jade` | 770 |
| `StoneOrbitShards` | Torso `NeckAttachment` | `_Shard1..6` + `_Shard1..6Jade` | 924 |
| `StoneOrbitBracerL` / `R` | Left/Right Arm `Left/RightGripAttachment` | `_Rock`, `_Jade` | 236 each |
| `StoneFistGauntletL` / `R` | Left/Right Arm `Left/RightGripAttachment` | `_Rock`, `_Jade`, `_Chip1` | 588 each |
| `StoneFistShards` | Torso `NeckAttachment` | `_Shard1..3` + `_Shard1..3Jade` | 462 |

Mesh names are `<Accessory>_<part>` and unique across all nine files.

## Size against the body

Sizes are measured from the R6 mesh: the arm is 0.94 wide, 1.00 deep and 2.00 long, and the head
is 1.20 wide and 1.02 tall. Each JSON carries its own numbers under `proportions`.

| Piece | Size | Ratio |
| --- | --- | --- |
| Peak pauldron | 1.42 w x 1.64 d, rises 0.75 over the arm top | 151% arm width, 164% arm depth, rise 80% of arm width |
| Peak shards | 0.42-0.76 each, arc 2.50 across | 42-75% head height, 63% of shoulder width (4.0) |
| Orbit shards | 0.53-0.86 each, ring 5.06 across | 52-84% head height, 126% of shoulder width |
| Orbit bracer | 1.26 w x 1.31 d x 0.81 long | 135% arm width, 41% arm length |
| Fist gauntlet | 1.54 w x 1.59 d x 1.39 long | 165% arm width, 69% arm length |
| Fist shards | 0.47-0.55 each, ring 3.44 across | 46-54% head height, 86% of shoulder width |

Sheet: `sheets/stone_spirit_directions.png`, with one row per variant. Its columns are front,
side, back, both three-quarter views, the game camera at 12 studs, a motion pose (arms swung 70
and -45, ring turned 40 and shards bobbed) and low close-ups of the arm piece's seating.

## Build rules

- **Stone.** Every rock is the convex hull of a few dozen jittered points on a (super)ellipsoid:
  crisp, faceted, chunky, flat-shaded past the house 28 degree crease, never a noise blob. The
  pauldron is three overlapping hulls (main slab, a lip down the outer arm, a crest on top), so it
  reads as stacked stone. The sleeves (bracers, gauntlets) use boxy hulls that fully contain the
  arm block.
- **Jade veins.** These are zigzag crack walks projected onto the rock surface. Each one is a
  closed strip, 0.10-0.14 studs wide (wide enough to read at game distance), standing 0.03 off the
  stone and sunk 0.05 into it, so nothing is single-sided.
- **Seating.** Plates and sleeves are flush with the arm's inner face (x >= 1.03), so they never
  enter the torso. Pauldron undersides are clamped onto a plane under the arm top and sunk into it,
  with no gap from any side. Arm pieces are on the arm's own attachments, so they swing with it.
- **Clearance.** The build checks that every shard clears the head and both arms across a -60 to
  +100 degree arm swing (walking and a raised tool hold). It reports `problems` per set, and all
  are empty.
- **Budget.** Each set is 236-924 tris.

## Rig

There is one armature per accessory. `Root` is the attachment point, doesn't deform and is never
keyed. Every vertex is weighted 1.0 to one bone: rock doesn't bend.

| Accessory | Hierarchy |
| --- | --- |
| Plates, bracers, gauntlets | `Root` -> `Plate` (rock + veins), `Root` -> `Chip1`, `Chip2` |
| Shards | `Root` -> `Orbit` (head at the ring centre, Y along the ring's axis) -> `Shard1..N` (head at each shard's centre) |

- **Orbit.** Rotate the `Orbit` bone about its own Y to spin the ring (Orbit, Fist). Peak's arc
  sits behind the head, so sway it about +-20 degrees instead of spinning it. Orbit's ring is
  tilted 10 degrees, with the front higher.
- **Bob.** Translate each `ShardN` or `ChipN` along its own Y (up), and tumble it with a little
  rotation. Offset the phases.
- The JSONs carry this under `orbit`, plus every bone's parent, head, tail and `roblox_head`.

## Space and colour

- **Attachment space.** Each FBX is in its attachment's space. A Blender point `(x, y, z)` is
  Roblox `(-x, z, y)` from the attachment, so mesh `Size = (bx, bz, by)` and its CFrame relative
  to the attachment is `CFrame.new(-cx, cz, cy)` (as on the fox).
- **Attachment points.** In Blender avatar space they are: NeckAttachment `(0, 0, 2)`,
  Left/RightShoulderAttachment `(+-1.5, 0, 2)` (arm top) and Left/RightGripAttachment
  `(+-1.5, 0, 0)` (arm bottom). Blender +X is the avatar's left.
- **Regions.** There are two, each its own MeshPart with a `Region` attribute:

| Region | Material | Roblox | Default (linear) |
| --- | --- | --- | --- |
| `Rock` | `Stone_Rock` | SmoothPlastic | dark basalt slate (0.075, 0.08, 0.088) |
| `Jade` | `Stone_Jade` | Neon | jade green (0.04, 0.88, 0.42) |

- **Shading.** `stone_shade.png` is a greyscale ramp on UV V (rock undersides darker), used on
  the Rock parts as a SurfaceAppearance ColorMap tinted by Color, as on the fox. To recolour
  rock, set both the MeshPart's `Color` and its `SurfaceAppearance.Color`.
- **Jade in Roblox** is plain Neon with no SurfaceAppearance (one would replace the glow), so
  recolour it with the MeshPart's `Color` alone. Its colour is sRGB `(0.10, 0.75, 0.30)`, not
  the converted Blender green: Neon pushed that (0.22, 0.95, 0.68) to cyan in the sandbox.

## Files

- `build_stone_spirit.py`: builds every set beside the R6 reference in scene `Cosmetics`
  (collection `StoneSpiritCosmetics`, one child collection per variant). It writes the FBX, JSON,
  `stone_shade.png` and `StoneSpirit.blend`, and renders the sheet tiles into `renders/` (not
  committed). Run it in a visible window:
  `tools/blender_live.sh run stone-spirit art/player/cosmetics/stone-spirit/build_stone_spirit.py EXPORT=True RENDER=True`.
  Pass both flags, because globals persist between runs in one window. Every tunable (`PLATES`,
  `SHARDS`, vein widths, colours) is a named constant at the top.
- `make_sheet.py`: stitches the tiles into the sheet. Run it with
  `uv run --with pillow python3 -I art/player/cosmetics/stone-spirit/make_sheet.py`.
- Lineup: `tools/blender_lineup.py` with
  `LOOKS = [[["StonePeakPlateL", "StonePeakPlateR", "StonePeakShards"], ["StoneOrbitShards", "StoneOrbitBracerL", "StoneOrbitBracerR"], ["StoneFistGauntletL", "StoneFistGauntletR", "StoneFistShards"]]]`
  and `SCENE = "Lineup"`. Set `SCENE` explicitly: the build's own `SCENE = "Cosmetics"` persists in
  the window, and the lineup tool deletes and replaces the scene it names.

## In Roblox

The nine accessories are in `ReplicatedStorage.Cosmetics.StoneSpirit`
(`assets/Cosmetics/StoneSpirit.rbxm`). Stone Spirit wears them through its `Style` look (Peak,
the default, Orbit, Fist), each option the three accessories of its set
(`src/shared/Identity/Races.luau`). Uploaded model assets (2026-10-23):

| Accessory | Asset |
| --- | --- |
| `StonePeakPlateL` | `rbxassetid://92669054322581` |
| `StonePeakPlateR` | `rbxassetid://97682972584791` |
| `StonePeakShards` | `rbxassetid://74609701843949` |
| `StoneOrbitShards` | `rbxassetid://106334816334151` |
| `StoneOrbitBracerL` | `rbxassetid://83150393363152` |
| `StoneOrbitBracerR` | `rbxassetid://132340835437575` |
| `StoneFistGauntletL` | `rbxassetid://70562460080742` |
| `StoneFistGauntletR` | `rbxassetid://95537660485688` |
| `StoneFistShards` | `rbxassetid://138619509712287` |

Shade ramp: `rbxassetid://89749165133866` (`stone_shade.png`, Studio MCP `upload_image`).

**Rebuild** (in a sandbox, no FBX import step), as Dragonblood's:
1. Upload the changed FBX with `python3 tools/upload_asset.py model <Set>.fbx` and put the new
   id in `place_stone_spirit_cosmetics.luau` (`ASSETS`).
2. Insert each model asset into Workspace as `_Import<Set>` (Studio MCP `insert_asset`).
3. Run `place_stone_spirit_cosmetics.luau` through `execute_luau` (serve the worktree with
   `tools/serve.sh <port>` and `loadstring(HttpService:GetAsync(url))()`). It builds each
   import into the Accessory `<Set>` in `ReplicatedStorage.Cosmetics.StoneSpirit`, asserts
   every mesh is there exactly once, and deletes the imports. Sandbox only: never build
   inside the Rojo-mapped Cosmetics folder in a connected place.
4. Export: `_G.exportRbxm("ReplicatedStorage.Cosmetics.StoneSpirit")` (`tools/export_rbxm.luau`)
   posted to the receiver as `/StoneSpiritCosmetics.rbxm`, then move the file to
   `assets/Cosmetics/StoneSpirit.rbxm`.

**Accessory layout:** `Handle` is an invisible 0.2 cube at the attachment point (the importer's
`RootPart`), holding one Attachment named like the R6 one it wears on and the bones. Every
R6 body attachment used here is unrotated, so the meshes need no turn. AccessoryType:
Shoulder (plates), Back (shards), Unknown (bracers, gauntlets). The skinned MeshParts are
welded to the Handle, each with a `Region` attribute.

**Checked in the sandbox (edit mode, R6 dummies, all three styles worn with
`Humanoid:AddAccessory`):**
- Every Handle sits exactly on its body attachment, and every mesh centre and size matches
  the JSON within 0.001.
- `Bone.Transform` moves the skinned meshes (a Peak shard and a pauldron lifted).
- The gauntlet stays put on the arm through a 70 degree shoulder swing.
- After `Model:ScaleTo(1.15)`, the Peak pauldron's mesh sizes, offsets and bone positions
  measure 1.15x exactly, and its Handle stays on the shoulder attachment.

## Untested

In game:
- the arm pieces on the grip attachment while a weapon is held (the gauntlets cover the fist)
- shards in front of the face at the game camera
- bone motion (nothing drives the bones yet)
- Neon jade at distance and its bloom on phones
- the creator preview's rigid copies of the arm pieces and the Fate step's Style arrows
