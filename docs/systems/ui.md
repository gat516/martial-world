# UI and HUD

## Purpose
Everything on screen: vitals, hotbar, windows, world prompts, reward feed,
cursor, settings and the admin panel.

## Design intent
- Mobile-first and one layout per session (`Platform` decides touch vs mouse once).
- One menu at a time (`Menus`); opening a window hides the gameplay HUD, keeping
  the top-right tiles to switch or close. The top-left is always Roblox's chat.
- Short, snappy motion (0.1-0.25 s) on windows, prompts, buttons and bars.
- World prompts are drawn in our own style, one target in focus at a time: on their
  target with mouse, keyboard or gamepad; on touch in a fixed column above the right
  end of the vitals and hotbar (`Prompts.Dock`, mirrors `Hud.Stack`'s box), so they
  are in thumb reach wherever the camera points.
- UI work goes through the `ui-designer` subagent (AGENTS.md). GUIs are authored in
  Studio via MCP and exported to `assets/Hud.rbxmx`, `Rewards.rbxmx`, `Prompts.rbxmx`;
  scripts only find and fill them.

## Key files (all `src/client/`)
- `Hud.luau`: vitals (health, qi, cultivation bars, realm crest), buffs, toasts.
- `Layout.luau`: device-specific layout flips; `Platform.luau`.
- `Menus.luau`: the one-window rule and what hides while a window is open.
- `Motion.luau`: shared tweens; uses the `Motion` UIScale authored on frames.
- `HotbarView.luau`, `Inventory.luau`, `SlotArt.luau`, `ListWindow.luau`.
- `WorldPrompts.luau` (custom ProximityPrompt drawing, `StarterGui.Prompts.Board`, touch `Prompts.Dock`).
- `Rewards.luau` (feed and boss victory card, `StarterGui.Rewards`).
- `Onboarding.luau`, `TravelMenu.luau`, `HerbShop.luau`, `BuildCatalog.luau`,
  `SeedPicker.luau`, `PlantingBar.luau`, `PlantTag.luau`.
- `BreakthroughView.luau`, `Meditation.luau` (seated row), `CirculationMinigame.luau`.
- `Cursor.luau`, `ShiftLock.luau` (Alt), `LockOn.luau` reticle and hint.
- `Settings.luau` (volumes, Auto combat, lock hint), `AdminPanel.luau` (F2, admins on PC).
- `State.luau`: the latest `PlayerState` snapshot with change listeners.

## Data flow
Fast values come from player attributes (`Realm`, `Cultivation`,
`CultivationMax`, `RawQi`, `DantianCap`, `Stones`), refreshed every second by
the server. Everything else comes from the `PlayerState` snapshot into `State`.
Toasts arrive over `Notify`; rewards and combat feedback over `Effect`.

## Tuning knobs
- Layout and look live in the authored GUI assets; timings in each module's
  constants (e.g. Motion, BreakthroughView).

## Known gaps
- None tracked here; check `git log` for the latest UI work.
