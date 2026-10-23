# Figma exports

Art exported from the Figma UI kit (file `9u6RPHLelUJF6aABm6mY7y`), not drawn
here. Ids are in `../assets.json`.

Source: the frame `Export / Roblox HUD (vitals)` (node 29:156) on the kit's
Example page, built from kit parts at the Roblox `Stack.Vitals` box's 1x size
(520x65): the `Bar/Vitals Mount` body fill, gilt stroke and inner rail, the
`Bar/Fill` rim colour, and instances of `ruby_stud`, `gold_stud`,
`ruby_marker`, `curl_diamond_L/R` and `Button/Round`. The bar windows are
vectors (2026-10-23, after the user's pre-reskin HUD): health and the seated
track come to a short point at both ends (depth 19/64 of the height), each tip
under a `ruby_stud` cap with a small `gold_stud` outside it on the frame; qi,
guard and dantian have rounded (stadium) ends. Each window is the bar frame's box in
`assets/Hud.rbxmx` (the troughs and rims sit 1.2 px outside it), so each image
fits its box exactly with `ScaleType.Stretch` (no slicing). Moving a bar means
moving its window here too. The fills themselves are `art/ui/hud_fill_*.png`
(`draw_vitals.py`).

| File | Use |
| --- | --- |
| `hud_vitals_plate.png` | `Vitals.Plate` (behind the bars): the notched body, guard tray and the bars' dark troughs |
| `hud_vitals_rims.png` | `Vitals.Mount` (over the bars): rims, health segment cuts, the ruby caps on health's points, studs, guard seal |
| `hud_seat_plate.png` | `SeatBars.Plate`: the same body and tray with the track and dantian troughs |
| `hud_seat_rims.png` | `SeatBars.Mount`: the pointed track rim with ruby caps and the breakthrough mark, dantian rim, studs |
| `hud_realm_plaque.png` | `Vitals.Crest` and `SeatBars.TitleCrest` (text is live on top) |
| `hud_round_seal.png` | `Cooldowns.Dash` / `Strike` chips (glyphs are the kit cuts `element_wind`, `weapon_sword`) |

To re-export: move or edit the sheet's children in Figma, export the sheet at
scale 2 with the Figma MCP's `download_assets` twice (as it is, and with the
sheet's fill set to black; set it back after), then run
`uv run --with pillow --with numpy python tools/figma_hud_export.py light.png dark.png`.
A changed PNG needs a new upload (`upload_image`) and the id swapped everywhere.
