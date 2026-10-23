# UI slicing and procedural art

How 9-slice and 3-slice art behaves in Roblox, and the legacy Pillow scripts. Read it
before setting a `SliceCenter`, cutting stretchable art or drawing bars and fills.
The art workflow itself (reference, Figma kit, Codex sheets, `tools/ui_assemble.py`) is in
the ui-designer agent and [overhaul-plan](overhaul-plan.md). Core: [ui](../systems/ui.md).

## The lint is the gate

Every cropping, flattening, off-screen and text-under-ornament complaint so far is
caught mechanically now. After any UI change (layout, art, a SliceCenter), before
showing it or committing:

1. In your sandbox (Edit mode), run `tools/ui_lint.luau` through `execute_luau`
   (paste the file, or serve `tools/` on loopback and `loadstring` it). It lays every
   ScreenGui in StarterGui and ReplicatedStorage out at 1920x1080, 1366x768, 844x390
   (with the notched phone's safe-area insets) and 667x375, opens every hidden
   window, card, template and state overlay as its own scene, and posts one JSON dump
   per GUI and size to the receiver (`tools/ensure_receiver.sh`) as
   `tools/frag/uilint_<W>x<H>_<gui>.xml`. Delete old dumps first.
2. `uv run --with pillow python3 -I tools/ui_lint.py [--frag DIR] [--gui NAME] [--all]`
   prints FAIL/WARN counts per GUI and every finding; exit 1 on any FAIL.

Then look at what it lists, not at the whole screen. The checks (docstring of
`tools/ui_lint.py`): **clip** (an element or its 1.05 hover box leaves its clipping
ancestor or the screen; scrolling content may run on along a scrolling axis, a UiScale
canvas is the screen), **edge-margin** (ornament tips reach the image's own edge with
less than a screen pixel of clear margin, so the quad's edge cuts them straight),
**slice** (an edge strip whose outline changes along it), **oversize** (art shown above
its source size), **text** (text that doesn't fit), **text-cap** (glyphs under a ribbon
cap's ornament, measured from the cap image itself), and the WARNs (centre, padding,
TextScaled on repeated tiles, unknown art ids, colour gradients in strips, ImageRect
cuts, cut PNGs touching their border).

Marks the lint reads (attributes; `tools/export_rbxmx.luau` keeps them):
- `LintIgnore` = `true` (skip the instance and everything in it) or a list of checks
  (`"clip,oversize"`, inherited by descendants), always with a `LintIgnoreReason`.
  Only for what is meant to be that way: radial-timer halves clipping their ring,
  light bursts running off a phone screen, soft washes upscaled, script-placed
  pointers parked off screen, the character creator (laid out by its controller).
- `LintMount` on a template = the path (from its ScreenGui) where code mounts it, so
  it's measured at its real size (`"Canvas.Board.Content.Notices"`). A template
  without one, parked in a `Templates` holder, is checked for its art only.
- `Device` UIScales use the phone scales in `DEVICE` (CultivationGui.luau,
  DeathScreen.luau): keep them in step.

## Edge margin: why ornaments looked cut flat

The cutter keeps a 2 px pad around each piece; shown at a fifth of its size that is
under half a screen pixel, and Roblox draws GUI images without mipmaps, so the outermost
display pixel samples the stud or curl itself and the quad's edge cuts it straight
(the cultivate tiles' corner studs and ruby badge, 2026-10-23). The fix is never a
repaint: a display-sized copy (`tools/ui_assemble.py --sized`, registry
`art/ui/sized/sized.json`) at about 2x its display height with a clear `margin` of at
least a screen pixel on every side that doesn't join another piece, and the element
grown by that margin so the art stays put. `tools/ui_margin.py` does it from the lint's
findings (plan, upload, `ids`, then `tools/ui_margin.luau` in Studio; read its
docstring). Images code swaps into the same element (rarity tiles, gems, studs,
medallions) are one family with one margin (`FAMILIES` there). Ribbon caps get their
margin on the outer end only (the band stays level with an unmargined middle); with
`--vertical` a whole ribbon (caps and middles) gets the same top and bottom margin and
its row grows to match. An image that already had a margin is compensated relative to
it. Icon crops keep a margin in `tools/icon_rects.py` (`PAD`). Not yet margined (still
edge-margin FAILs, 2026-10-23): the glyph family (`Glyphs.luau`, code swaps them
everywhere), the Sect crest composites (shields, rings, emblems: `Sect/Art.Size`/`Hole`
place the layers), the boss bar mounts (`BossThemes`), the Events windows' themed
corners (`Events/Themes` sets their aspect), and icons drawn to their own border.

## Export round-trip check

`tools/export_rbxmx.luau` writes only the properties in its list. A property missing
from it silently reverts when Rojo builds the file (a crop shipped when
`SizeConstraint` was missing). After every export:

1. In Studio: `_G.EXPORTCHECK = { target = "StarterGui.Hud", name = "Hud" }`, then run
   `tools/export_check.luau` (after `tools/export_rbxmx.luau`).
2. `python3 tools/export_check.py assets/Hud.rbxmx [--frag DIR]` (add
   `--root-name CharacterCreatorGui` for the creator, whose file renames its root).

It FAILs on any property that differs from the default live but is missing from the
file or written differently, on attributes, and on structure. Add a dropped property to
the exporter's `PROPS` and export again.

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
- `tools/ui_lint.py` checks every slice as shown (only the strips that actually
  stretch at that size). `uv run --with pillow python tools/check_slices.py` still
  checks the files on disk without Studio. FAIL means the outline changes along an edge
  strip, so fix the art or the rect. "warn" means a colour gradient along a
  strip, which is fine unless it's an ornament. Put the intended
  `SliceCenter` and `SliceScale` in the drawing function's docstring.
- A local Pillow simulation of the slice doesn't match Roblox's renderer; it
  showed these pills as perfect while Roblox cropped them. Run `ui_lint`, then look
  at what it lists: `screen_capture` with that element visible at its real size,
  crop and enlarge the region with Pillow and Read it.
- If an image can't be sliced cleanly, use `ScaleType.Stretch` at its native
  aspect ratio.
- **Plates with ornaments across their height (cloud caps, scroll ends) are never
  one 9-sliced image.** The curls cross the left/right edge strips and Roblox cuts
  them flat (the build catalog's tabs shipped this way, 2026-10-24, though the
  split cuts existed). Build them from the `SLICE3` `_capL` / `_mid` / `_capR`
  cuts (b660c99): caps at native aspect, only the middle stretches.
- Draw big panels large (1024px) and slice them down (`SliceScale` ~0.26-0.3);
  small sources scaled up look resized.
