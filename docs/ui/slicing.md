# UI slicing and procedural art

How 9-slice and 3-slice art behaves in Roblox, and the legacy Pillow scripts. Read it
before setting a `SliceCenter`, cutting stretchable art or drawing bars and fills.
The art workflow itself (reference, Figma kit, Codex sheets, `tools/ui_assemble.py`) is in
the ui-designer agent and [overhaul-plan](overhaul-plan.md). Core: [ui](../systems/ui.md).

## Legacy Pillow art

- New frames, panels, buttons and ornaments come from generated sheets, not
  these scripts. They draw the existing older art and still suit bars, fills and
  procedural pieces.
- Scripts: `art/ui/draw_ui.py` (frames, panels, pills, vitals mount, plaques) and
  `art/ui/draw_icons.py` (item icons). Extend these; keep shared helpers
  (`gradient_rect`, `bevel_border`, `lozenge`, `spiral`, `corner_layer`).
- Run with `uv run --with pillow --with numpy python art/ui/draw_ui.py`.
- Draw at 4x and downsample (the scripts' `SS`). Icons: 128px, plain silhouette,
  soft top-light gradient, ink outline, one highlight.
- Before uploading, compose a preview PNG in the scratchpad (on a mid-grey
  background, at real in-game size) and look at it with Read.

## 9-slice

This has cropped our pills flat more than once.

- Roblox stretches all four edge strips along their length: top/bottom
  strips stretch sideways, left/right strips stretch up and down. Every curve
  and ornament must sit entirely inside the four corners. The edge strips may
  only hold lines that are identical along the stretch: the same in every
  column for top/bottom, the same in every row for left/right. Checking only
  the top strip isn't enough; the left/right strips are what broke.
- Pills and other stadium shapes: the round ends are the corners. Split them
  at the one row where the curve is vertical, the exact vertical centre, e.g.
  `Rect(72, 63, 440, 65)` on a 512x128 pill. Keep that row clear of
  ornaments: an end lozenge on it smears into a bar. Set `SliceScale` so that
  (top corner + bottom corner) x scale is about the button's height (0.28 for
  36-40px from a 128px source). Don't go much smaller, or the ends turn into a
  rounded rectangle.
- `SliceCenter` needs a margin on every side (no 0 or full-size edge), or
  Roblox clips the art.
- Run `uv run --with pillow python tools/check_slices.py` after drawing art or
  changing a `SliceCenter`. FAIL means the outline changes along an edge
  strip, so fix the art or the rect. "warn" means a colour gradient along a
  strip, which is fine unless it's an ornament. Put the intended
  `SliceCenter` and `SliceScale` in the drawing function's docstring.
- A local Pillow simulation of the slice doesn't match Roblox's renderer; it
  showed these pills as perfect while Roblox cropped them. The real check is in
  Studio: `screen_capture` with the element visible at its real size, then crop
  and enlarge that region with Pillow and Read it. Look at the ends and
  corners closely before calling art done.
- If an image can't be sliced cleanly, use `ScaleType.Stretch` at its native
  aspect ratio.
- **Plates with ornaments across their height (cloud caps, scroll ends) are never
  one 9-sliced image.** The curls cross the left/right edge strips and Roblox cuts
  them flat (the build catalog's tabs shipped this way, 2026-10-24, though the
  split cuts existed). Build them from the `SLICE3` `_capL` / `_mid` / `_capR`
  cuts (b660c99): caps at native aspect, only the middle stretches.
- Draw big panels large (1024px) and slice them down (`SliceScale` ~0.26-0.3);
  small sources scaled up look resized.
