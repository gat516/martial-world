# Figma exports

Art exported from the Figma UI kit (file `9u6RPHLelUJF6aABm6mY7y`), not drawn
here. Ids are in `../assets.json`.

Source: the frame `Export / Roblox HUD (vitals)` (node 29:156) on the kit's
Example page, built from kit parts at the Roblox `Stack.Vitals` box's 1x size
(520x65): the `Bar/Vitals Mount` body fill, gilt stroke and inner rail, the
`Bar/Fill` rim colour and health `Segment cuts`, and instances of
`ruby_stud`, `gold_stud`, `ruby_marker`, `curl_diamond_L/R` and `Button/Round`.
Bar positions in it match the bar frames in `assets/Hud.rbxmx`, so each image
fits its box exactly with `ScaleType.Stretch` (no slicing).

| File | Use |
| --- | --- |
| `hud_vitals_plate.png` | `Vitals.Plate` and `SeatBars.Plate` (behind the bars): the notched body and guard tray |
| `hud_vitals_rims.png` | `Vitals.Mount` (over the bars): bar rims, health segment cuts, ruby gems, studs, guard seal |
| `hud_seat_rims.png` | `SeatBars.Mount`: one track rim with the breakthrough mark, dantian rim, studs |
| `hud_realm_plaque.png` | `Vitals.Crest` and `SeatBars.TitleCrest` (text is live on top) |
| `hud_round_seal.png` | `Cooldowns.Dash` / `Strike` chips (glyphs are the kit cuts `element_wind`, `weapon_sword`) |

To re-export: move or edit the sheet's children in Figma, export the sheet at
scale 2 with the Figma MCP's `download_assets` twice (as it is, and with the
sheet's fill set to black; set it back after), then run
`uv run --with pillow --with numpy python tools/figma_hud_export.py light.png dark.png`.
A changed PNG needs a new upload (`upload_image`) and the id swapped everywhere.
