# UI and HUD

## Purpose
Everything on screen: vitals, hotbar, windows, world prompts, reward feed,
cursor, settings and the admin panel.

## Design intent
- Mobile-first and one layout per session (`Platform` decides touch vs mouse once).
- One menu at a time (`Menus`); opening a window hides the gameplay HUD (touch
  combat cluster, PC cooldown chips, vitals, hotbar; the inventory keeps the
  hotbar as a drop target). Windows sit centred with their own close seal, and
  the top-right tiles fade away while any window is open, on every device, and
  fade back when the last one closes (user decision, 2026-10-21: they poked out
  over the panels; it used to be touch-only for the big windows).
  Small panels too: a menu the player opens (like the meditation panel) goes
  in the centre of the screen, not docked at the bottom over the vitals and
  hotbar (user decision, 2026-10-21). The HUD steps aside while it's open, so
  the bottom has nothing to stay near.
- A ScrollingFrame whose rows size themselves (`AutomaticSize` Y) gets its
  `CanvasSize` from its `UIListLayout.AbsoluteContentSize` in script;
  `AutomaticCanvasSize` doesn't count those rows and leaves the list unscrollable.
- Scrolling lists say so (decided 2026-10-21: it wasn't obvious that the
  meditation panel's Spirit Root page scrolled to its pill rows). Every
  vertical ScrollingFrame in the Hud gets, from `ScrollHint`, an ink fade over
  its bottom edge and a small bobbing gold chevron seal straddling it, shown
  only while there's more below; they go at the end of the list or when it all
  fits. The scroll bar is drawn art too: a gold thumb with an ink outline
  (`TopImage`/`MidImage`/`BottomImage`, `ScrollBarImageColor3` white,
  thickness 6 in windows and 4 in the build bar). A new scrolling list needs
  nothing extra: `ScrollHint.init` picks up every ScrollingFrame in the Hud.
  The top-left is always Roblox's chat. On PC, shift lock switches off while
  any window (reward card and minigames included) is open, so the mouse is free,
  and comes back when it closes (`ShiftLock`; `TestbedAltMouseLock` in the testbed).
- Short, snappy motion (0.1-0.25 s) on windows, prompts, buttons and bars.
- The bottom-centre stack (user decision, 2026-10-22, from a Deepwoken-style
  reference in our own style): one gilded mount holding health, combat qi and
  the guard trough, with the realm crest above and the hotbar below; seated,
  the cultivation bars take its place. Details, the seated tiles and the
  breakthrough nudge: [vitals stack](../ui/hud-vitals.md).
- Inventory (weapons and arts by class, rarity frames, NEW badges, drag to equip, sort, filter and search): [inventory](../ui/inventory.md).
- Character window (`SelfCard`, the Self tile, the realm crest shortcut, the
  `RootReveal` card): every row has the same shape, gains in jade (decided
  2026-10-21). Layout, rows and room for later tabs:
  [character window](../character/character-window.md). Switching methods lives in
  the meditation menu ([meditation](meditation.md)).
- Top-right tiles (`Hud.Buttons`, right-aligned list): Cultivate, Self (once the
  root is tested), Inventory, Build (near your peak), Travel (in the sect),
  Settings. 56 px tiles 10 px apart, scaled 0.9 on touch (about 50 px thumb
  targets), 0.85 on PC; six tiles are about 350 px wide on a phone. Element seals are drawn in
  `art/ui/draw_icons.py` (`icon_Root<Element>`) and shown on the weapon badge disc.
  Layout and room for later rows and tabs: [character window](../character/character-window.md).
- Travel: the menu groups Sect grounds and the Wilds; locked arrays stay listed,
  greyed under a cinnabar 封 seal with "Opens at <realm>". A seal-and-name marker
  floats over arrays (others' peaks only up close) and the screen fades to ink
  with the destination's name while the trip runs; the fade always lifts (a
  refusal lifts it at once, and it times out on its own).
- Onboarding guide (`Guide`, see [onboarding](onboarding.md)): the server's
  `guide` pulses one control; first-session beats spotlight it under a gentle
  ink veil (`Hud.Guide`, art `guide_hole.png`, SliceCenter Rect(48, 48, 80, 80),
  SliceScale 0.5) with the elder's line in a note-panel callout beside it, other
  HUD controls ignoring taps until it's pressed. Walking goals get a chevron
  beam (`Hud.GuideTrail`, `guide_trail.png`), a bobbing gold arrow over the
  target (`Hud.GuideMarker`) and the same arrow at the screen edge when it's off
  screen (`guide_arrow.png`). Lessons that need more than a pulse (the root
  pill) use `point`: the same arrow bobbing beside the control
  (`Hud.Guide.Pointer`) with a short line in the callout, no veil. A guide can
  point into an open window (the pill's Absorb button) and scrolls it into
  view. Art in `art/ui/draw_ui.py guide`.
- World prompts are drawn in our own style, one target in focus at a time: on their
  target with mouse, keyboard or gamepad; on touch in a fixed column above the right
  end of the vitals and hotbar (`Prompts.Dock`, mirrors `Hud.Stack`'s box), so they
  are in thumb reach wherever the camera points. Each card is the kit's prompt banner
  behind a round key plate (live key letter, the action's glyph, a hold ring); see
  [dialogue](../ui/dialogue.md). With a mouse, cards take clicks
  only while the cursor is free; under shift lock or lock-on the centred mouse
  would otherwise sit on the board and swallow attacks and camera drags.
- UI work goes through the `ui-designer` subagent (AGENTS.md). GUIs are authored in
  Studio via MCP and exported to `assets/Hud.rbxmx`, `Rewards.rbxmx`, `Prompts.rbxmx`, `Dialogue.rbxmx`,
  `Veil.rbxmx` (full-screen, no safe insets, above everything),
  `CharacterCreator.rbxmx` (the join screen, see [character creator](character-creator.md)),
  `Events.rbxmx` (world events, tribulation, rifts, leaderboards; built by
  `tools/events_ui_build.luau`);
  scripts only find and fill them.
- Generated art (Codex, the UI overhaul) is never repainted: `tools/ui_assemble.py`
  cuts `art/ui/codex/<name>.png` (the names in its `PIECES` and `ICON_SHEETS`, the
  same list as the Codex brief) into `art/ui/codex/cut/`. It keys magenta or real
  alpha, trims, rejects pieces that touch the canvas edge or carry stray islands
  from a neighbour, downscales to 2x display size, tiles anything past 1024 px,
  splits icon sheets on a 4 x 3 grid, and writes `manifest.json` (sizes, tiles,
  flags) plus `contact_sheet.png`. The user approves the contact sheet before
  anything is uploaded. Run with `uv run --with pillow --with numpy`.
- Ornament sheets (many pieces on one magenta sheet) are cut by the same tool,
  found by shape and named from its `PIECE_SHEETS`; the first is documented in
  [dialogue ornaments](../ui/dialogue-ornaments.md).
- Templates that scripts clone live in a `Templates` Frame with `Visible = false`,
  never a Folder: GUI objects inside a Folder still draw.
- `tools/export_rbxmx.luau` also writes rig joints (Motor6D C0/C1), Humanoid,
  ViewportFrame lighting and camera, CanvasGroup fade and Shirt/Pants templates,
  and skips a child whose name matches a property the class lacks (a Frame's
  `Image` child once came out as a bogus `Image` property).

## Sub-docs
- [Vitals stack, seated bars and guard bar](../ui/hud-vitals.md)
- [Inventory windows](../ui/inventory.md)
- [Boss health bar](../ui/boss-bars.md)
- [Reward banners: floats, feed, banner, card; the toast](../ui/rewards.md)
- [Dialogue ornaments](../ui/dialogue-ornaments.md)
- [Dialogue screen and interaction prompts](../ui/dialogue.md)
- [Cultivation UI: seated tiles, meditation panel, breakthrough card, foundation meter, death-save, Dao ring, tier frames, bloodline marks](../ui/cultivation.md)
- [Character window](../character/character-window.md)
- [Herbarium and the garden windows](../ui/herbarium.md) (Herbalist, seed picker, planting bar, plant tag, build catalog look)
- [World events, tribulation and rifts](../ui/world-events.md) (`StarterGui.Events`)
- [Leaderboards, path crests and the Blood Sect skin](../ui/leaderboards.md)
- [Sect board, quest log, rank and contribution](../ui/sect-board.md) (ready to wire)
- [Halls, masters and lineage](../ui/halls-masters.md) (ready to wire)

## Key files (all `src/client/`)
- `Hud.luau`: vitals (health and combat qi bars with trails, the qi refusal
  flash, realm plaque `Crest`; no name plaque), buffs, toasts (`Hud.saidLately` tells whether a toast was
  just shown). `Hud.setBar` is the shared bar fill. The crest is a shortcut to
  the character window (`SelfCard`).
- `SeatBars.luau`: the seated cultivation, overflow and dantian bars.
- `Layout.luau`: device-specific layout flips; `Platform.luau`.
- Guard bar (`GuardBar.luau`, `Stack.Vitals.GuardBar`) and the touch
  `Play.BlockButton`: see [vitals stack](../ui/hud-vitals.md#guard-bar).
- `Menus.luau`: the one-window rule and what hides while a window is open.
- `Motion.luau`: shared tweens; uses the `Motion` UIScale authored on frames.
- `UiScale.luau`: baseline scaling for new screens. Lay a screen out once inside an
  authored `Canvas` frame (with a `UiScale` UIScale) at 1920x1080, or 844x390 for a
  phone layout; `UiScale.fit(canvas)` scales it to the screen and sizes the canvas to
  fill it in baseline units. `UiScale.isPhone()` (touch, short side under 600 px,
  decided once) picks the phone layout. Details in the module header and
  [overhaul-plan](../ui/overhaul-plan.md) "Resolution and scaling".
- `HotbarView.luau` (with the weapon slot), `Inventory.luau` (Weapons & Arts and Pouch tabs),
  `InventoryFilter.luau` (chip rail, sort, search), `Rarity.luau` (the rarity ladder and frames),
  `Fresh.luau` (NEW badges), `SlotArt.luau` (slot painting, class glyphs and colours,
  weapon art, the weapon badge), `ListWindow.luau`.
- `WorldPrompts.luau` (custom ProximityPrompt drawing, `StarterGui.Prompts.Board`, touch `Prompts.Dock`).
- `Rewards.luau` (reward banners, `StarterGui.Rewards`: `Rewards.show` with the small,
  feed, banner and card tiers; the boss victory, quest and milestone card), and
  `RegionBanner.luau` (the region entry banner on the banner tier). See
  [reward banners](../ui/rewards.md).
- `Dialogue.luau` (`Dialogue.open({speaker, portrait, lines, responses}) -> choice`,
  `StarterGui.Dialogue`, ready to wire) and `Glyphs.luau` (the kit's white action glyphs,
  shared with the prompts). See [dialogue](../ui/dialogue.md).
- `Events/` (`StarterGui.Events`, fitted by `UiScale`): `Gui` (slots, templates, the
  herald queue), `WorldEventView`, `TribulationView`, `RiftCard`, `Leaderboards`, `Themes`.
- `Sect/` (`SectBoard`, `QuestLog`, `SectRank`, `HallCrest`, `HallPanel`, `Lineage`,
  shared `Ui` and `Art`): the sect, quest, Hall and lineage windows in
  `StarterGui.Sect`, fitted by `UiScale` at the phone baseline. Not called by the game
  yet; each has a `.preview()`.
- Boss health bar: `BossBars.luau` drives `Play.BossBar`; themes in
  `BossThemes.luau`, boss pick in `EnemyBars.luau`. See [boss bar](../ui/boss-bars.md).
- `SelfCard.luau` (character window from the Self tile or the realm crest), `RootReveal.luau`
  (spirit root reveal card).
- `Onboarding.luau`, `Guide.luau` (spotlight, dim, walking path), `TravelMenu.luau` (with `GateMarkers.luau` over arrays and
  `Veil.luau`, the travel fade in `StarterGui.Veil`), `HerbShop.luau`, `BuildCatalog.luau`,
  `SeedPicker.luau`, `PlantingBar.luau`, `PlantTag.luau`.
- `CultivationGui.luau` (the `StarterGui.Cultivation` screen: breakthrough title card,
  death-save, templates), `FoundationMeter.luau`, `DeathSave.luau`, `CultivationMarks.luau`
  (Dao ring, tier frames, bloodline badges, heaven mark); see [cultivation UI](../ui/cultivation.md).
- `BreakthroughView.luau`, `Meditation.luau` (seated tiles, calm view),
  `MeditationMenu.luau` (its panel), `Bottleneck.luau`, `CirculationMinigame.luau`.
- `ScrollHint.luau` (the "more below" fade and chevron over every scrolling
  list, `Hud.ScrollHint`; art `draw_ui.py scroll`; `ScrollHint.reveal` scrolls a
  control into view).
- `Cursor.luau`, `ShiftLock.luau` (the existing main-game binding and reticle),
  `TestbedAltMouseLock.client.luau` (Alt toggle in the testbed only),
  `LockOn.luau` reticle and hint.
- `Settings.luau` (volumes, Auto combat, lock hint), `AdminPanel.luau` (F2, admins on PC).
- `State.luau`: the latest `PlayerState` snapshot with change listeners.
- `CharacterCreator/` (the join screen: nav, viewport dummy, parchment panel); see
  [character creator](character-creator.md).

## Data flow
Fast values come from player attributes (`Realm`, `Cultivation`,
`CultivationMax`, `CultivationCap`, `BreakthroughReady`, `BreakthroughBlock`,
`RawQi`, `DantianCap`, `Stones`, refreshed every second by the server; `Qi`,
`QiMax`, `QiDenied` from `CombatQi` as they change; see [combat](combat.md)).
Every reader defaults them to 0, false or "" until they arrive. Everything else comes from the `PlayerState` snapshot into `State`.
Toasts arrive over `Notify`; rewards and combat feedback over `Effect`
(`Effect "reward"` carries a whole `Rewards.show` spec)
(a gained weapon is Effect "weapon", a cultivation method Effect "method",
both shown in the reward feed).

## Tuning knobs
- Layout and look live in the authored GUI assets; timings in each module's
  constants (e.g. Motion, BreakthroughView).

## Known gaps
- Vitals, seat bar and hotbar gaps: [vitals stack](../ui/hud-vitals.md#known-gaps).
- Boss bar gaps: [boss bar](../ui/boss-bars.md#known-gaps).
