# Dialogue ornaments

The first generated ornament sheet is `art/ui/codex/ornaments_filled_source.png`
(Codex, 1536 x 1024, sheet A of [codex-sheets](codex-sheets.md) on `progression-bible`):
filled xiangyun clouds, fine gold corners and an empty key plate, eleven isolated
pieces on near-magenta. No text is baked into the art.

`tools/ui_assemble.py ornaments_filled_source` cuts it (its `PIECE_SHEETS` list names the
pieces in reading order). It keys by hue, not one colour, because the generator's
magenta drifts and has dark flecks; it despills the magenta tint the generator puts on
outlines and highlights; it finds each piece by shape, so pieces may sit anywhere on
the sheet. Cuts are full resolution, `art/ui/codex/cut/ornament_<name>.png`, with
sizes and source boxes in `art/ui/codex/manifest.json`, and a review sheet in
`art/ui/codex/contact_sheet.png`.

Pieces, rows left to right:
1. `name_scroll`, `double_cloud`, `single_cloud`, `cloud_wisp`.
2. `panel_corner`, `portrait_corner` (both top-left; mirror for the others).
3. `scroll_stud`, `ruby_stud`, `gold_stud`.
4. `keyplate` (empty tile), `chevron`.

They are mounted in the Figma UI kit's ornament components (corner sets mirrored), so
the kit's frames, buttons and bars use them. Not yet uploaded to Roblox or previewed in
Studio. The thin dark-red line between the panel corner's rails is in the generated art.

## Sheet A1
`art/ui/codex/sheet_a1.png` (sheet A1 of codex-sheets): `plaque_end`, `plaque_end_small`,
`divider_diamond`, `divider_cloud`, `divider_vertical`, `inkwash_a`, `inkwash_b`,
`seal_square`, `seal_round`. Codex also redrew the plaque end alone at large size,
`art/ui/codex/a1/plaque_end_large.png` (cut as `plaque_end_large`; the cutter caps every piece at
1024 px, Roblox's texture limit). The ink-wash clouds were generated
lilac against the magenta; the despill turns them blue-lavender and they are opaque,
so the kit shows them at 14 % opacity. In the Figma kit the large plaque end (and a
mirrored copy) is the title plaque's ends, `inkwash_b` is the panel pattern, and the
dividers and seals are new components.

Codex then redrew every A1 piece alone at full size (`art/ui/codex/a1/*.png`). Those are
listed after `sheet_a1` in `PIECE_SHEETS`, so they win: the grey-blue ink clouds, the red
chop-style seals (open centre), the redesigned vertical divider and sharper dividers and
small plaque end. The kit uses them; the sheet cuts are the fallback.

## Sheet A2 and three-part pieces
Codex delivers one piece per file now (`art/ui/codex/a2/*.png`); the cutter picks up any
one-piece file in a sheet folder automatically, named after the file, so no
`PIECE_SHEETS` entry is needed. A2: `response_button`, `response_button_hi`,
`prompt_banner`, `hold_ring`.

Buttons and banners (`SLICE3` in the cutter) are also cut, from the full-resolution art,
into `_capL`, `_mid` (a 32 px strip from the plain middle) and `_capR`. The split is where
the shape and smoothed brightness stop matching the centre column, because generated
middles carry painted texture and glow. Caps never stretch; the strip is stretched to fit
the label (in Figma an image fill set to stretch, in Roblox a `ScaleType.Stretch` image or
a `SliceCenter` over the three parts). In the kit, `Button/Response` and the new
`Frame/Prompt Banner` are built this way; the left response cap holds the icon ring and
the prompt's key letter is live text on the key plate. The red ribbon tip at each
button's right end is in the generated art.

## Sheet A3: window chrome
Three multi-piece sheets under `art/ui/codex/a3/`, named in `PIECE_SHEETS`: `controls`
(`scroll_thumb`, `slider_knob`, `checkbox`, `checkmark`), `corners` (`window_corner`,
`window_corner_small`, both top-left; mirror for the rest) and `title_and_seals`
(`title_crest`, `close_seal`, `back_seal`; the seals' faces are empty for a live glyph).
The title crest has a cloud in the middle of its top edge, so it is cut in five parts
(`capL`, `midL`, `centre`, `midR`, `capR`; the two strips stretch equally). In the kit:
`Frame/Window`, `Frame/Title Crest`, `Button/Back Seal`, `Button/Checkbox`, `Button/Slider`,
and `Button/Close Seal` reskinned with the new art.

## Sheet A4: portraits are gray silhouettes
NPC portraits are never shown painted (user, 2026-10-22: the painted busts looked bad).
Each NPC is a flat gray silhouette of its figure, on transparency, so the Portrait frame
supplies the backdrop. Codex's painted busts in `art/ui/codex/a4/` are only the source for
the shape. `tools/ui_silhouette.py` makes them (`ui_assemble.py` skips the `a4` folder):
`uv run --with rembg --with onnxruntime --with pillow --with numpy --with scipy python tools/ui_silhouette.py`.
It masks the figure with rembg (the first run downloads a 179 MB model), fills robe
holes, squares off the shoulders below 60 % height, and writes
`art/ui/codex/cut/portrait_<name>.png` in gray `#767A84`: `elder_qingyun`, `herbalist`,
`weapon_rack_keeper`, `unnamed_silhouette`, `unknown_silhouette` (the "???" figure loses
its question mark; add it back as live text if it is wanted). In the kit they are the
`Ornament/Portraits/*` components, and a row of `Frame/Portrait` instances shows each in
its frame. A new NPC's portrait goes the same way: a Codex bust with A4's framing, then
the silhouette tool.
