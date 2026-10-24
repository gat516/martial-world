# Beast Folk (Serpent) cosmetics (Blender, fins skinned)

Fin crests and face scale plates for the Serpent variant of Beast Folk, from the user's prompt
(`../briefs/serpent.md`) and panel 4 of `docs/reference/race_cosmetics.png`. The look is a
river spirit: cold, refined, slightly dangerous. The fins are the hero silhouette; the plates
are the close-up detail. The user kept all three directions as variants (2026-10-23, "looks
good, get everything in"). Any fins go with any plates.

| Direction | Mood | Fins | Plates |
| --- | --- | --- | --- |
| Veil | subtle, elegant | small rounded leaf fins behind the ear, four short gold ribs in one broad web with a lobed edge, flared out | slim temple-to-cheek crescent of round scales |
| Sovereign | ceremonial (the concept sheet) | upswept fan: four gold spines standing past a scalloped web | two-lobed leaf (temple lobe, waist, cheek lobe) of pointed scales ending in a point |
| Fang | fierce | level barbed blades thrown back and out like swept horns, hooked spines well past a short web | short temple blade swept back toward the fin, and a cheek fang |

## Sets

All attach to `Head.HatAttachment`.

| Set | Meshes (one MeshPart each) | Tris | Bones |
| --- | --- | --- | --- |
| `SerpentFinsVeil` | `<Set>_LeftFin`, `_LeftFinSpines`, `_RightFin`, `_RightFinSpines` | 1,544 | yes |
| `SerpentFinsSovereign` | same four | 1,544 | yes |
| `SerpentFinsFang` | same four | 1,152 | yes |
| `SerpentScalesVeil` | `<Set>_LeftScales`, `_LeftSeam`, `_RightScales`, `_RightSeam` | 1,188 | none (rigid) |
| `SerpentScalesSovereign` | same four | 1,908 | none |
| `SerpentScalesFang` | same four | 1,656 | none |

Every mesh name is unique across the six files.

## Size against the head

R6 head mesh: 1.20 wide, 1.20 deep, 1.02 tall. Ratios are of that box (also in each JSON under
`ratios_to_head`, and on the sheet):

| Direction | Fin height | Fin rise over the head top | Fin trails behind the head | Span tip to tip | Plate height | Plate width |
| --- | --- | --- | --- | --- | --- | --- |
| Veil | 0.41 | -0.31 (below the top) | 0.23 | 1.62 | 0.66 | 0.28 |
| Sovereign | 0.82 | 0.46 | 0.05 | 1.79 | 0.88 | 0.40 |
| Fang | 0.50 | 0.12 | 0.26 | 2.10 | 0.87 | 0.48 |

No fin is taller than the head, and the spines are chunky (0.04-0.06 stud root radius): the
first pass had needle spines and a fan 1.1x the head's height, the tall-and-thin look that read
"creepy" on the fox ears.

## Colour (recolour contract)

Materials are `Serpent_<Region>`, so another race's rebuild can't recolour them. Each region
is its own MeshPart, tinted by `Color`; the JSON `region` field holds the bare region name.

| Region | Meshes | Default (linear) | In Roblox |
| --- | --- | --- | --- |
| `Scale` | `_LeftScales`, `_RightScales` | deep jade-teal (0.014, 0.085, 0.072) | SmoothPlastic |
| `Seam` | `_LeftSeam`, `_RightSeam` | glowing teal (0.10, 0.95, 0.78) | Neon (the glow between the scales) |
| `FinWeb` | `_LeftFin`, `_RightFin` | sea teal (0.08, 0.55, 0.52) | Transparency about 0.35 |
| `FinSpine` | `_LeftFinSpines`, `_RightFinSpines` | gilded gold (0.80, 0.52, 0.16) | SmoothPlastic |

**Shade ramp.** `serpent_shade.png` is byte-for-byte `fox_shade.png` (same settings), so use
the shared `rbxassetid://124559907609415`. UV V only: the fin webbing darkens toward its root,
each scale darkens where it tucks under the row above, and the spines and seams are white.

## Construction (why there are no gaps)

- **Plates.** A solid, tight patch of small closed scales (seven-point outlines with a raised
  centre and walls down to an outline buried 0.05 inside the head), laid brick-wise along a
  curve on the head so every tip covers the join below it. Under them a glowing `Seam` band,
  buried at the bottom too, shows only in the hairline gaps. Every vertex is placed by a ray
  cast onto the R6 head, so the patch hugs it (about 0.04 studs proud).
- **Fins.** Gilded spines are closed tapered tubes. The webbing is one closed sheet (both faces
  and a rim) running between them, so it is never single-sided. All spines and the web start
  inside a gilded knuckle half sunk into the head, which hides the root.
- **Face.** Plates stay off the face decal (from about 50 degrees round the head from the face
  centre).

## Rig (fins)

One armature per fin set: `Root` -> `FinLBase` -> `FinL` -> `FinLTip` (and R). `Root` is the
attachment point and doesn't deform.

- `FinLBase` holds the buried knuckle, so a keyed fin never pulls its root out.
- `FinL`'s head is the hinge on the head surface; `FinLTip` takes the outer half.
- Weights blend from FinL into FinLTip over 35-65% of the fin's length.
- Rolls: local Z is the fin's normal. Rotate about local X to flare the fin out from the head
  (+) or fold it in; about local Z to sweep it up or down in its own plane.
- Checked on the sheet: FinL flared 30 degrees, tips a further 20. No tearing.
- **In Roblox the sign flips:** the importer re-frames the bones, so `Bone.Transform = CFrame.Angles(math.rad(-30), 0, 0)` on `FinL` / `FinR` flares the fin out (both sides take the same sign) and +X folds it onto the head.

Hinge positions per bone (Blender and Roblox) are in each JSON under `bones`.

## Space and import

- Each FBX is in HatAttachment space: the origin is the attachment point.
- A Blender point `(x, y, z)` is Roblox `(-x, z, y)` from the attachment, so mesh
  `Size = (bx, bz, by)` and `CFrame = CFrame.new(-cx, cz, cy)`, no rotation (each JSON's
  `roblox_center` is already mapped).
- The fin sets import like the fox ears (skinned, the importer's RootPart becomes the Handle).
- **The plate sets have no armature.** They are rigid meshes, so the place script makes its own
  invisible 0.2 Handle at HatAttachment and welds the four MeshParts to it.

## Files

- `build_serpent.py`: builds everything in the `Cosmetics` scene beside the R6 reference.
  - Tunables are named constants at the top: `FINS`, `PLATES`, colours, the ramp.
  - Exports `<Set>.fbx` + `<Set>.json`, writes the ramp and saves `Serpent.blend`.
  - Renders the sheet tiles and `renders/ratios.json` into `renders/` (not committed).
  - Builds the `Lineup` scene (one R6 body per direction) with `tools/blender_lineup.py`.
  - Run: `tools/blender_live.sh open serpent`, then
    `tools/blender_live.sh run serpent art/player/cosmetics/serpent/build_serpent.py EXPORT=True RENDER=True`.
    Pass both flags: globals persist between runs in one window.
- `make_sheet.py`: stitches the tiles, the ratios and the lineup into `sheets/serpent_cosmetics.png`
  (`uv run --with pillow python3 -I art/player/cosmetics/serpent/make_sheet.py`).

## In Studio

`assets/Cosmetics/Serpent.rbxm` (`ReplicatedStorage.Cosmetics.Serpent`) holds the six Accessories
(AccessoryType Hat). The Beast Folk Serpent variant wears Sovereign
(`SerpentFinsSovereign` + `SerpentScalesSovereign`, `src/shared/Identity/Variants/BeastFolk.luau`);
Veil and Fang wait for a style picker. They replace the part-built `SerpentScales` /
`SerpentTail` in `BeastFolk.rbxm`, now unused.

| Set | Model asset (upload_asset.py model) |
| --- | --- |
| `SerpentFinsVeil` | `rbxassetid://110117735613413` |
| `SerpentFinsSovereign` | `rbxassetid://73675592443421` |
| `SerpentFinsFang` | `rbxassetid://133891447016938` |
| `SerpentScalesVeil` | `rbxassetid://127532799973901` |
| `SerpentScalesSovereign` | `rbxassetid://137171599768106` |
| `SerpentScalesFang` | `rbxassetid://101289195663998` |

Shade ramp: the shared `rbxassetid://124559907609415`.

**Accessory layout.** `Handle` is an invisible 0.2 cube at HatAttachment holding the
`HatAttachment` (and, on fins, the bones). Each region is a MeshPart welded to it with a
`Region` attribute: `Scale` and `FinSpine` SmoothPlastic, `FinWeb` SmoothPlastic at 0.35
transparency (no shadow), `Seam` Neon. All but the Seam carry a SurfaceAppearance with the
ramp; the Seam has none so it keeps its glow. To tint a region set both `MeshPart.Color` and
`SurfaceAppearance.Color`.

**Rebuild** (in a sandbox, no FBX import step):
1. Upload the changed FBX with `python3 tools/upload_asset.py model <Set>.fbx` and put the new
   id in `place_serpent_cosmetics.luau` (`ASSETS`).
2. Insert each model asset into Workspace as `_Import<Set>` (Studio MCP `insert_asset`).
3. Run `place_serpent_cosmetics.luau` through `execute_luau` (paste it, or serve the worktree
   with `tools/serve.sh <port>` and `loadstring(HttpService:GetAsync(url))()`). Fins: the
   importer's RootPart becomes the Handle. Plates: the importer gives loose MeshParts and no
   RootPart, so the script recovers the attachment frame from each part and its JSON
   `roblox_center` (`PLATE_CENTERS`, update it if a plate JSON changes) and makes its own Handle.
   Sets without an import keep their current template. Sandbox only.
4. Export the folder: `_G.exportRbxm("ReplicatedStorage.Cosmetics.Serpent")`
   (`tools/export_rbxm.luau`) posted to the receiver, then move the file to
   `assets/Cosmetics/Serpent.rbxm`.

**Checked in the sandbox** (2026-10-23) on R6 dummies from `CharacterCreatorGui.Templates.Dummy`,
one per direction wearing its fins and plates: every Handle's attachment lands exactly on
`Head.HatAttachment`; `FinL`/`FinR` at -30 degrees and the tips at a further -20 flare the fins
out (tips move 0.24-0.28 studs) and the skinned meshes follow; the plates sit on the head wall
with the seam showing only between scales, no gap at the side close-up; after `ScaleTo(1.15)`
every mesh size, offset and bone scales by exactly 1.15 with the attachment still exact.

## Untested

Untested in game: the translucent webbing and Neon seams under game lighting, the read at phone
distance, the fins with hair accessories (they're rooted at the side of the head, so tall or
wide hair may cover the roots), and the plates against custom face decals. Nothing animates the
fin bones yet (the planned shared accessory script would drive `FinL`/`FinR`).
