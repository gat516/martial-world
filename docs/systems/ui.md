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
  The top-left is always Roblox's chat. On PC, shift lock switches off while
  any window (reward card and minigames included) is open, so the mouse is free,
  and comes back when it closes (`ShiftLock`).
- Short, snappy motion (0.1-0.25 s) on windows, prompts, buttons and bars.
- Seated: the meditation menu, a row of square tiles above the vitals that
  appear only when relevant (Circulate or Break Through, Method, Spirit Root,
  Practice, Rise; Practice swaps in its own tiles: Technique, Weapon Dao,
  Back), a small panel for Comprehend / Method / Spirit
  Root (root pills and the reform choice live on its Spirit Root page), and
  the lotus calm toggle that fades the HUD for a clean view (`Menus.setCalm`;
  also after 20 s idle; a tap brings it back). See [meditation](meditation.md).
  The standing Force Breakthrough pill (`Stack.BreakthroughButton`) is the only
  breakthrough button outside the seat.
- The circulation overlay has a Leave pill at its header's right corner
  (`Circulation.Column.Header.Title.Leave`) that ends the run early for free.
- Weapons live in the Inventory's Weapons tab: Bare Fists first (choosing them
  puts the weapon away), then owned weapons with their grade glow and a cinnabar
  佩 seal on the equipped one; Equip/Unequip go through `WeaponAction`. With no
  weapon chosen the pane lists every class's Dao comprehension (level and XP bar);
  a chosen weapon shows its own class's row. Arts that need a weapon class wear a
  small round class badge in the Arts grid; on the hotbar the badge (and a dimmed
  icon) shows only while that class isn't in hand, and the slot still casts so
  the server can say "Requires a sword". Weapon and class icons live in
  `SlotArt` (drawn in `art/ui/draw_icons.py`; a def's own `icon` wins), so Spirit
  grades share their model's art and differ by glow colour.
- Technique icons are flat white glyphs tinted by the technique's colour; the
  class weapon skills' are drawn in `art/ui/draw_techniques.py`.
- A chosen art in the Inventory shows its tier, level and XP bar (a `DaoList`
  row cloned from `RowTemplate`). At a bottleneck (XP full at level 3, 6 or 9) the
  bar turns cinnabar and reads "Bottleneck", the grid's "Lv" turns the same
  colour, two cost rows (insight and Spirit Stones icons, "need · you have") show
  up, and the Secondary button becomes Comprehend (jade). While it can't run it
  stays lacquer and dimmed and its caption is the reason ("Meditate to
  comprehend", "Need insight", "Need stones"); a tap toasts the longer reason.
  Comprehending belongs to the seated Practice row's Technique tile; the button
  here still works while seated (`Bottleneck` holds the shared logic). Success is the
  server's notify. While the Inventory is open, tapping a hotbar slot shows that
  art or item in the detail pane instead of casting or holding it, so arts on the
  hotbar can be comprehended too.
- Sort and filter (`InventoryFilter`): once the Arts or Weapons tab holds 3 or
  more entries, a square sort button closes the tab row. It opens a small menu of
  class chips (All, Any for universal arts, then only the classes the player has)
  over three sort pills (Arts: Level, Name, Bottleneck; Weapons: Grade, Class,
  Name) and a caption naming the view ("Sword arts, highest level first"). Taps
  apply at once; the button again, a tap outside or a tab switch closes it. While
  a class is chosen the button turns gold wearing that class's icon. Unfiltered,
  the Arts grid lists only arts off the hotbar; a class filter lists every art of
  that class, hotbar ones included (slot number on PC, not draggable). Weapons keep
  the equipped one first, then Bare Fists. The choice lasts the session, per tab.
- Character window (`SelfCard`): the Self tile (`Buttons.SelfButton`, between
  Cultivate and Inventory) opens the Self card (realm and stage bar, then a
  scrolling list of rows: Spirit Root, Cultivation Method from Foundation, Weapon
  Dao); tapping the realm crest over the vitals is a shortcut to it. Every row
  has the same shape: a seal, its kind in small gold capitals, the name (grade or
  level on the right) and its effects, one line each, gains in jade (decided
  2026-10-21; details in [character](character.md)). Switching methods lives in
  the meditation menu ([meditation](meditation.md)). The tile shows and
  the crest is tappable only once the root is tested. The tiles fade away while it's
  open, like every window. The spirit root reveal (`RootReveal`) is a small
  centre card on the first test, closed by a tap or by itself, after which the
  tile pops in, swells once and wears a seal dot until opened.
- Top-right tiles (`Hud.Buttons`, right-aligned list): Cultivate, Self (once the
  root is tested), Inventory, Build (near your peak), Travel (in the sect),
  Settings. 56 px tiles 10 px apart, scaled 0.9 on touch (about 50 px thumb
  targets), 0.85 on PC; six tiles are about 350 px wide on a phone. Element seals are drawn in
  `art/ui/draw_icons.py` (`icon_Root<Element>`) and shown on the weapon badge disc.
  Layout and room for later rows and tabs: [character](character.md).
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
  screen (`guide_arrow.png`). Art in `art/ui/draw_ui.py guide`.
- World prompts are drawn in our own style, one target in focus at a time: on their
  target with mouse, keyboard or gamepad; on touch in a fixed column above the right
  end of the vitals and hotbar (`Prompts.Dock`, mirrors `Hud.Stack`'s box), so they
  are in thumb reach wherever the camera points. With a mouse, cards take clicks
  only while the cursor is free; under shift lock or lock-on the centred mouse
  would otherwise sit on the board and swallow attacks and camera drags.
- UI work goes through the `ui-designer` subagent (AGENTS.md). GUIs are authored in
  Studio via MCP and exported to `assets/Hud.rbxmx`, `Rewards.rbxmx`, `Prompts.rbxmx`,
  `Veil.rbxmx` (full-screen, no safe insets, above everything);
  scripts only find and fill them.

## Key files (all `src/client/`)
- `Hud.luau`: vitals (health, qi, cultivation bars, realm crest), buffs, toasts.
  The crest is a shortcut to the character window (`SelfCard`).
- `Layout.luau`: device-specific layout flips; `Platform.luau`.
- `Menus.luau`: the one-window rule and what hides while a window is open.
- `Motion.luau`: shared tweens; uses the `Motion` UIScale authored on frames.
- `HotbarView.luau`, `Inventory.luau` (Pouch, Arts, Weapons tabs), `InventoryFilter.luau`
  (sort button and menu for Arts and Weapons), `SlotArt.luau`
  (slot painting, weapon art, the weapon badge), `ListWindow.luau`.
- `WorldPrompts.luau` (custom ProximityPrompt drawing, `StarterGui.Prompts.Board`, touch `Prompts.Dock`).
- `Rewards.luau` (feed and boss victory card, `StarterGui.Rewards`).
- `SelfCard.luau` (character window from the Self tile or the realm crest), `RootReveal.luau`
  (spirit root reveal card).
- `Onboarding.luau`, `Guide.luau` (spotlight, dim, walking path), `TravelMenu.luau` (with `GateMarkers.luau` over arrays and
  `Veil.luau`, the travel fade in `StarterGui.Veil`), `HerbShop.luau`, `BuildCatalog.luau`,
  `SeedPicker.luau`, `PlantingBar.luau`, `PlantTag.luau`.
- `BreakthroughView.luau`, `Meditation.luau` (seated tiles, calm view),
  `MeditationMenu.luau` (its panel), `Bottleneck.luau`, `CirculationMinigame.luau`.
- `Cursor.luau`, `ShiftLock.luau` (Alt), `LockOn.luau` reticle and hint.
- `Settings.luau` (volumes, Auto combat, lock hint), `AdminPanel.luau` (F2, admins on PC).
- `State.luau`: the latest `PlayerState` snapshot with change listeners.

## Data flow
Fast values come from player attributes (`Realm`, `Cultivation`,
`CultivationMax`, `RawQi`, `DantianCap`, `Stones`), refreshed every second by
the server. Everything else comes from the `PlayerState` snapshot into `State`.
Toasts arrive over `Notify`; rewards and combat feedback over `Effect`
(a gained weapon is Effect "weapon", a cultivation method Effect "method",
both shown in the reward feed).

## Tuning knobs
- Layout and look live in the authored GUI assets; timings in each module's
  constants (e.g. Motion, BreakthroughView).

## Known gaps
- None tracked here; check `git log` for the latest UI work.
