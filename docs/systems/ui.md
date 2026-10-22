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
  screen (`guide_arrow.png`). Lessons that need more than a pulse (the root
  pill) use `point`: the same arrow bobbing beside the control
  (`Hud.Guide.Pointer`) with a short line in the callout, no veil. A guide can
  point into an open window (the pill's Absorb button) and scrolls it into
  view. Art in `art/ui/draw_ui.py guide`.
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
- Guard bar (`GuardBar.luau`, `Play.GuardBar`): a posture-style bar on the
  Stack's top edge (Layout copies the Stack's size onto it). Art `guard_rim`,
  `guard_fill`, `guard_seal`, `guard_cracks`, drawn by `art/ui/draw_guard.py`.
  The fill drains toward the centre seal and warms toward red below 0.3; shown
  only while the guard is held or not full, fading out when full and idle.
  `GuardBar.set(ratio, active)` every frame (GuardController);
  `GuardBar.flash` "parry" (pale-gold pop), "blocked" (shake), "break" (red
  cracks, then hidden for `BREAK_HIDE`). `Play.BlockButton` ("Guard", 擋) is the
  touch-only guard button above Dash, placed by `Layout.apply` (not yet checked
  against the Lock button's arc on a phone); GuardController binds it.
- `Menus.luau`: the one-window rule and what hides while a window is open.
- `Motion.luau`: shared tweens; uses the `Motion` UIScale authored on frames.
- `HotbarView.luau`, `Inventory.luau` (Pouch, Arts, Weapons tabs), `InventoryFilter.luau`
  (sort button and menu for Arts and Weapons), `SlotArt.luau`
  (slot painting, weapon art, the weapon badge), `ListWindow.luau`.
- `WorldPrompts.luau` (custom ProximityPrompt drawing, `StarterGui.Prompts.Board`, touch `Prompts.Dock`).
- `Rewards.luau` (feed and boss victory card, `StarterGui.Rewards`).
- Boss health bar: `BossBars.luau` drives `Play.BossBar` (a CanvasGroup, top centre,
  `FitWithinMaxSize` 4:1, 0.44 of the width, max 400x100, so smaller on phones).
  The design is the original one (55e39fb), toned down (user, 2026-10-21): the
  first version (600x150, a pulsing screen vignette and halo, a lingering omen,
  big shakes) blocked the fight; slimmer rebuilds from cropped or new generic
  art were rejected. Rules: show each boss's frame art whole, never cropped; no
  screen darkening and no looping pulses; small, short hit and phase feedback.
  `BossThemes.luau` holds one table per boss def id (`ElderWolfKing`,
  `NineTailFox`, `JadeJiao`, `ThunderApe`, plus `default`). `EnemyBars.luau` picks
  the boss (locked, else the nearest hunting you within `BOSS_RANGE`) and the
  danger tier (`Pacing.Danger`, `STYLES`, re-picked on breakthrough). A theme is a
  title line, a frame image (1024x256, bar hole at x168-856 y110-146, name plate
  above, realm plaque below; `art/ui/draw_boss_bars.py`, ids `bossbar_*` in
  `assets.json`), saturated fill colours (top-light vertical gradient), a pale
  trail, a static glow colour, a phase colour, and omen pools per tier (random
  per fight, short lines). Adding a boss is one table entry (an unlisted boss
  gets `default`).
  Intro: the bar fades in, the fill sweeps up, name and realm rise in; the
  theme title shows under the name (`TITLE_HOLD`), then the omen (`OMEN_HOLD`),
  and both fade out fully (a breakthrough mid-fight shows the new omen once).
  The halo behind the bar is faint and static (`GLOW_REST`). The bar has ten
  talisman slips, a tick at each phase threshold (`def.summonAt`, or
  `theme.phases`), a trail, and a 1-3px nudge and quick flash on hits of
  `BIG_HIT` (5%) or more. Crossing a threshold flashes the bar, nudges it,
  spreads faint cracks from the centre, warms the fill and frame colours and
  greys the tick.
  v2 frames (user, 2026-10-21): each of the four bosses gets its own slender
  frame (`bossbar2_wolf/fox/ape/jiao.png`, `draw_boss_bars.py v2_*`; run it with
  `v2` to redraw only these), in the language of the user's references: a long
  thin bar, a thin dark rim hugging it with shaped ends, small organic accents
  growing out of the rim and one small motif at top-centre; the name is plain
  stroked text above (no plaque), no emblem or medallion ("tacky"), smooth
  rather than pixel art. One family, never a recolour: wolf in dark iron with
  arrow tips, frost tufts, tiny fangs and icicles and a fur crest; fox in black
  lacquer with gold lines, hook-curl ends, foxfire wisps and a curled tail; ape
  in rough dark bronze with notched blunt ends, faint lightning hairlines and a
  storm cloud; jiao in jade with fine scales, swept fins, whisker curls and a
  flaming pearl. They use a longer window (`V2_WIN` 64,112 to 960,144), so
  `BossBars` switches the Bar, name, realm, title and omen to `V2_LAYOUT` when a
  v2 frame is shown (realm small at the bar's right end below it; title, then
  omen, on one row under the middle). Their ids go in the `ASSET IDS` block at
  the top of `BossThemes.luau` (`Themes.FRAMES`, keyed by def id) and in
  `assets.json`; while one is still a `PASTE-ID:` placeholder that boss keeps its
  original frame and layout.
  Gaps: the v2 frames and the layout switch are not uploaded or seen in Studio
  yet; the fox, jiao and
  ape bars are untested until those bosses are in play; the phase cracks are
  one shared image.
- `SelfCard.luau` (character window from the Self tile or the realm crest), `RootReveal.luau`
  (spirit root reveal card).
- `Onboarding.luau`, `Guide.luau` (spotlight, dim, walking path), `TravelMenu.luau` (with `GateMarkers.luau` over arrays and
  `Veil.luau`, the travel fade in `StarterGui.Veil`), `HerbShop.luau`, `BuildCatalog.luau`,
  `SeedPicker.luau`, `PlantingBar.luau`, `PlantTag.luau`.
- `BreakthroughView.luau`, `Meditation.luau` (seated tiles, calm view),
  `MeditationMenu.luau` (its panel), `Bottleneck.luau`, `CirculationMinigame.luau`.
- `ScrollHint.luau` (the "more below" fade and chevron over every scrolling
  list, `Hud.ScrollHint`; art `draw_ui.py scroll`; `ScrollHint.reveal` scrolls a
  control into view).
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
