# Leaderboards, path crests and the Blood Sect skin

The leaderboard window lives in the Events screen ([world events UI](world-events.md),
`StarterGui.Events`, slot `Board`). Ready to wire: no leaderboard system exists yet
(roadmap 9, "Goals that don't end": realm, Herbarium, tallest peak, best garden).

## Window
Centred, 720x600 on the desktop baseline and 600x350 on the phone, registered with
`Menus` (one window at a time; the HUD steps aside). Built from kit pieces:
- body: the house note panel (`note_panel.png`, 9-slice Rect(64, 64, 448, 192), SliceScale
  0.5) with `window_corner_small` at each corner (mirrored copies in `art/ui/events/`);
- the title crest (`title_crest`, five-part: the cloud centre keeps its shape, the two
  strips stretch equally) straddling the top edge with "Rankings" live on it;
- the kit's `close_seal` at the top-right corner with a live ×;
- board tabs as live text (selected in gold with a cloud-divider underline, others dim),
  equal widths and gaps;
- column heads (RANK, CULTIVATOR, PATH, VALUE) aligned with the row cells;
- a scrolling list of `leaderboard_row`s (three-part: the cloud caps keep their aspect)
  sized so about 6.6 fit (the last one peeks, so it reads as a list that scrolls);
- under a cloud divider, your own row in `leaderboard_row_you` (the lit gold version),
  always shown, however far down you are.

Each row: the rank (Fredoka One) centred in a `medal_gold`/`_silver`/`_bronze` ring for the
top three (the number is live text in the ring's centre) and plain beyond; the name; the
player's path crest; the value, right-aligned, in the theme's accent.

## Paths
Crests `path_orthodox` (a jade peak in gold), `path_rogue` (a lone sword in bronze) and
`path_blood` (a crimson drop in black and crimson). **The Blood Sect crest shows only to a
viewer who has found the demon path** (their player attribute `Path == "blood"`). To anyone
else a blood-path player shows the rogue crest, so the board never gives the secret away
(roadmap 9, "The demon secret": nothing says "demon" in the UI).

## API (`src/client/Events/Leaderboards.luau`)
```lua
Leaderboards.show({
	boards = { { id = "realm", title = "Realm" }, ... },  -- tabs, in order
	board = "realm",                                       -- selected tab
	rows = { { rank = 1, name = "Wei Lan", path = "orthodox", value = "QC 9" }, ... },
	you = { rank = 42, name = "You", path = "rogue", value = "QC 3" }, -- optional
	onTab = function(id) end,  -- fetch that board, then show again
	theme = "blood",           -- optional; default: the viewer's own path's skin
})
Leaderboards.close(); Leaderboards.isOpen()
Leaderboards.preview()          -- sample boards; preview("blood") for the skin
```
The leaderboard system must provide: the boards, the top rows per board (rank, display
name, path, a formatted value), the viewer's own row, and a way to open the window (a
button or an NPC; none yet). Paths need a saved `Path` player attribute
(`"orthodox"`, `"rogue"`, `"blood"`).

## Blood Sect skin (`src/client/Events/Themes.luau`)
A theme other components can opt into: `Themes.default` (the kit's gold) and
`Themes.blood` (codex sheet C6: blackened iron and crimson, thorned scrolls), each with
corner ids and their aspect, a stud id, panel and frame tints and text colours, plus
`Themes.bloodPieces` (the C6 name scroll and studs). `Themes.apply(window, theme)` skins a
window whose parts are named `CornerTL/TR/BL/BR`, `Body`, `Crest` (with `Title`), `Rule`,
`Divider` and `Stud`; `Themes.tintRow(row, theme)` skins a row's frame. Pieces with a C6
version are swapped (`blood_panel_corner`, `blood_ruby_stud`); gold pieces without one (the
crest, rows, dividers) are tinted crimson-copper with `ImageColor3`. The leaderboard uses
it: the window takes the blood skin automatically for a viewer on the demon path.
The rest of C6 (`blood_name_scroll`, `blood_double_cloud`, `blood_keyplate`, ...) is cut
on `ui-assemble` for later Blood Sect screens (the outpost board, the blood garden).

## Previews and checks
Previewed in the sandbox's Edit view at both baselines (`tools/events_ui_preview.luau`),
including the blood skin. Untested in play and on a phone.
