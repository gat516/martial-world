# Modeling checks

Measuring a body or prop against its reference, for the maker and for a fresh critic agent
that judges one composite image plus a printout. Enemy bodies are Studio parts; props and
terrain meshes come from Blender. These sit on top of `art/enemies/check_rig.luau` (rig
contract, floating and unjointed parts) and `keyframe_test.luau` (keyable joints).

All of it runs in a sandbox Studio in Edit mode. Serve the worktree yourself
(`python3 -m http.server 8783 --bind 127.0.0.1` from the repo root) and load with
`loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8783/tools/<tool>.luau?" .. os.clock()))()`.

## References

- The user's approved bodies are the reference: the testbed reference row
  (`workspace.Folder.Model` in the user's place, not in sandboxes) and the copies kept in git,
  e.g. `art/enemies/beasts/jade_python_ref.rbxm.b64` (load it into an EditorOnly Workspace
  folder and pass its path to `model_shot`, as the validation below did).
- Images go in `docs/reference/enemies/<enemy>/` (none exist yet). Any image path works.

## 1. `tools/model_shot.luau`: the standard shots

`_G.modelShot.stage({ source, scale?, rig?, fov?, at? })` places one anchored, inert clone
alone in a closed mid-grey box (Neon, so the backdrop is one flat tone) under flat noon light
with post effects off and the HUD hidden, and returns `screen_capture` arguments:

| preset | what it shows |
|---|---|
| `front` | level, square-on from the front (the model faces -Z), filling the frame |
| `side` | level, from the model's left: its front on screen left |
| `34` | front-left and a little above, filling the frame |
| `34_40` | the same direction, as big as the body looks 40 studs away through the player's 70-degree camera: the "reads at 40 studs" test |

- `source`: an Enemies def id (its `body` is used), a template name in `ServerStorage.Enemies`
  or `ServerStorage.WeaponModels`, or a dotted path (`Workspace.X.Y`).
- `rig` (default true) stands a 5-stud R6 off the model's front-right corner for size
  (`Workspace.Rig` when the place has one, else six grey blocks). Use `rig = false` for a
  fidelity capture, or the R6 joins the silhouette.
- `fov` (default 30) is set on the Studio camera while staged; `screen_capture` uses it. Use 15
  for fidelity captures (flatter, close to a drawn or orthographic reference).
- `_G.modelShot.sheet({ source })` stands four clones turned 0/90/180/270 in a row (front,
  right side, back, left side, left to right) for one all-sides capture.
- `_G.modelShot.cleanup()` removes the set and restores lighting, HUD and FOV (kept as `_ms_*`
  attributes, so it works after `_G` resets). Restaging doesn't restore in between: flipping
  `ShowDevelopmentGui` back and forth in one call left the HUD over the next capture.
- Bring the sandbox window to the front before capturing (`screen_capture` shows whichever
  Studio is in front: [previewing](../vfx/toolkit/previewing.md)). Two or three captures a
  model, never more. Captures come back as JPEGs under the session's `tool-results/`; copy
  the ones you score into your scratchpad.

## 2. `tools/fidelity_check.py`: silhouette against the reference

```
uv run --with pillow --with numpy python3 -I tools/fidelity_check.py REF.png CAPTURE.jpg [--out X.png] [--fit height|box] [--tol 28] [--largest] [--no-flip] [--json]
```
It cuts both silhouettes out (alpha if the image has it, else the border colour flood-filled
inward), scales the build to the reference's height with the ground lines matched, and
writes one composite: reference | build | overlay (grey shared, blue missing from the build,
red extra in the build). It tries the reference mirrored too and keeps the better fit.

What the numbers mean:
- **IoU** (overlap over union): 1.0 is the same outline. Measured so far (validation below):
  the reference rebuilt from its own parts 0.999; the same body with a cobra hood painted on
  0.90 (top band 0.74); a different design of the same animal 0.63; a different animal 0.26.
  One added feature barely moves the overall number, so **read the bands**: a band well under
  the others is where the build drifted. As a rule of thumb, a build that should match a
  reference wants every band above about 0.9.
- **missing / extra**: the share of the reference's area the build lacks or adds. Extra high
  and missing low means the build is bulkier; the other way round, thinner.
- **height bands** (top / middle / bottom thirds) say where: head and crest, body, legs.
  **length bands** (left / centre / right thirds of the reference's width) say which end:
  on a side view, head, body, tail.
- **width/height**: the two boxes' proportions. Different numbers mean a body too long or
  too short, whatever the outline.
- `--fit box` stretches the build onto the reference's box, to score shape alone.
- Matching angles matters more than anything: a capture from another angle or pose scores
  low whatever the build. Rest poses only (hidden parts that unfold in a pose, like a folded
  hood, don't show).

## 3. `tools/parts_audit.luau`: what a capture hides

`return _G.partsAudit({ target = "ServerStorage.Enemies.JadeJiao", budget = 150 })` (a
folder audits every model in it; read-only). Over visible parts it lists:
- **loose**: parts joined to each other but not to the body (an accent stuck only to
  another accent: `check_rig` misses these). **floating**: one part touching nothing.
- **kissing**: a part that only touches face to face (under 0.02 overlap): it reads stuck on
  and shows a slit when it moves.
- **hidden**: wholly inside other parts at rest: wasted budget, unless a pose brings it out
  (check RIGS.md).
- **zfight**: faces within 5 mm, facing the same way, overlapping, in different colours or
  materials, and not buried in a third part. Same-colour pairs only appear as a count.
- the part count against the budget, and `check_rig`'s lines when the model has an HRP
  (`rig = false` skips it).

Blocks, wedges, balls and cylinders are tested exactly; MeshParts, unions and corner wedges
as their boxes (counted in the header).

## 4. `art/rig/silhouette_render.py`: Blender silhouettes

`silhouette_render.render_silhouettes(objs, out_dir, prefix)` renders white-on-black
orthographic `front`, `side` and `34` views of the given meshes (the same views as
`model_shot`, with the model facing -Y), framed by the bounding sphere so every run frames
alike. Score them with `fidelity_check.py` before exporting the FBX. It renders in a temporary
scene and leaves the working scene alone. Not yet run in Blender.

## Validation (2026-10-23, side views, fov 15)

| build | reference | IoU | notes |
|---|---|---|---|
| JadeJiao | the user's JadePython (`jade_python_ref.rbxm.b64`) | 0.999 | rest silhouette matches |
| SpiritWolfB | `art/enemies/spirit_wolf/preview/rest_side.png` (the Blender wolf) | 0.63 | extra 50%: B is the bulkier block build; legs band 0.47 |
| SpiritWolfB | the JadePython capture (control) | 0.26 | different animal |
| JadeJiao capture with a hood painted on | JadePython | 0.90 | top band 0.74, other bands 0.9+: the hood shows up where it is |

parts_audit: JadeJiao 202 visible parts (budget 150), 20 hidden at rest (hood, fangs,
tongue: the windup pieces) and 7 z-fights on the skull and snout that come from the
reference itself; SpiritWolfB 89 visible (budget 80), 3 hidden in the closed jaw and 9
z-fights (crest tells, paws and claws, nose).
