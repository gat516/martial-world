---
name: mesh-pipeline
description: The house pipeline for meshes from Blender to Studio - a re-runnable build script in art/ run through the Blender MCP, FBX plus bounds JSON export, the FBX axis and size remap, the batched manual import through art/fbx_export/, and the place_*.luau script that sizes, styles and places the imports. Use for any landform, prop or weapon mesh.
user-invocable: false
---

# Blender to Studio

The house examples are `art/build_peak_pillar.py`,
`art/main_peak/build_main_peak.py` and their `place_*.luau` scripts. Copy their
patterns.

## Build in Blender (Blender MCP)

- Start with `get_addon_status` and `get_scene_info`. `execute_blender_code`
  runs Python with full bpy, and `look` shows the result. Look often, at a small
  `max_size`.
- The model is a script, `art/<thing>/build_<thing>.py`, run through the MCP.
  Don't sculpt by hand in the session: the script is the source of truth,
  re-runnable and reviewable in git. Put tunables at the top as named constants
  with comments. Edit it in place with the current file read; never rewrite it from
  memory (that makes a different asset), and never delete a failing line to clear
  an error.
- 1 Blender unit = 1 stud. Document the origin and axes in the script header
  (the peaks use X right, Y outward, Z up, origin at the plateau centre).
- Make one mesh object per Roblox material, since each becomes one MeshPart.
  Surfaces players must walk smoothly (stairs) get an invisible ramp mesh, and
  the visible treads don't collide.
- Fit the model around existing gameplay geometry (floors, doors, bridges,
  spawn pads). Read their positions from Studio first and cut or align exactly.
- One agent at a time on the live Blender (modeler, "Which Blender"). Never
  evaluate modifiers on a scene that isn't the active one (that crashed Blender).
- Libraries and generation: `search_assets` / `import_asset` (Poly Haven,
  Sketchfab, Poly Pizza), or `generate_3d` (one object; takes minutes and may
  cost the user a credit, so ask first). Imports arrive at arbitrary scale, so
  size them from the reported bounding box. Check the licence before an asset
  goes in the game. A generated model is only a proportion guide: keep it in a
  hidden collection that isn't exported and build the real mesh by script (its
  dense, soft mesh would redesign the reference). The exception: for an organic or
  complex shape that primitives build badly, ask the main session for an `asset-generator` base mesh (local
  Pixal3D, from a reference image) instead of fighting it.
- In shader code, look nodes up by type, never by name, and read enum
  identifiers instead of hardcoding them. Localized Blender installs differ.
- Blender here is 5.1: snippets from before 4.1 break (`use_auto_smooth` is
  gone), so look APIs up in it (`visual-gate` 0c).

## Export

- Export the FBX next to the script (`art/<thing>/<Thing>.fbx`), plus a JSON with
  each mesh's triangle count, centre and size in Blender axes, and every anchor
  point the game needs (decor spots, ledges, grips).
- Roblox's FBX import comes in oversized (about 11x for these files) and remaps
  axes, so never trust imported sizes. Blender +X becomes mesh -X, and +Y becomes
  mesh +Z. Relative to the model pivot:
  `Size = (bx, bz, by)` and `CFrame = CFrame.Angles(0, math.pi, 0) * CFrame.new(-cx, cz, cy)`.
- Save the `.blend` when the model is done.

## Import (a manual step, so batch it)

Scripts and the MCP can't import FBX.
1. Copy every FBX that needs (re)importing into `art/fbx_export/`, a flat drop
   folder of copies. The sources stay beside their build scripts.
2. Stop and ask the user to import everything in it:
   - File > Import 3D, and select all the files in
     `\\wsl.localhost\Ubuntu\home\cj\roblox\martial-world\art\fbx_export\`.
   - Keep the defaults, but don't merge meshes: placement finds parts by mesh
     name.
   - Import each file once.

   Don't poll Studio while you wait.
3. When the user says the imports are in, check that every expected mesh is
   there exactly once. Run the placement scripts, delete the import containers,
   and empty `art/fbx_export/`.

## Place: `art/<thing>/place_<thing>.luau`

Run it in Edit through `execute_luau`. It:
- finds the imported MeshParts by name, and asserts loudly if one is missing or
  imported twice
- sets Size and CFrame from the JSON, kept as a generated `MESHES` block between
  BEGIN and END markers
- sets Material, Color, Anchored, CanCollide/CanQuery/CanTouch, CastShadow and
  CollisionFidelity per part: `PreciseConvexDecomposition` for walkable or
  climbable rock, `Hull` or `Box` for far or simple parts
- builds or replaces the template, clones it into place and deletes the import
  container
- wraps everything in one `ChangeHistoryService` recording, so Ctrl+Z undoes it

When the template sits in a Rojo-mapped folder of a Rojo-connected place, the
script targets a staging copy (the `studio-export` skill).

## Pivots

Scripts clone and place templates. Leave `PrimaryPart` nil, and set an
identity-rotation `WorldPivot` at the ground point (bottom centre), with
cylinders stood up inside the model. Placement keeps the pivot rotation:
`CFrame.new(spot) * template:GetPivot().Rotation`. Never use
`PivotTo(CFrame.new(spot))` alone: it laid light pillars on their side.

Check library models you reuse too. Some keep their WorldPivot hundreds of studs
from the mesh ("Single Stone" in the Stone Rock Pack: about 485). Re-pivot them
at their bounding box's bottom centre before placing.

## Records

Geometry placed outside Rojo's mapped folders lives only in the place file. List
the Studio-side changes in the commit body and remind the user to save the
place. Commit the build script, FBX, JSON and `.blend` together.
