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
