# Meditation

## Purpose
Sit still to multiply passive cultivation; also where breakthroughs and seated
circulation happen.

## Design intent
- Idle-safe: you can leave it running. Where you sit matters: anywhere x1.5,
  your own peak x2.5, plus the best meditation seat or artifact within range on
  your peak (BuildItems `meditation`), which gives building a progression payoff.
- Seated is a calm screen with the meditation menu (below): a row of tiles that
  only appear when they matter.
- Seated locks the character: no walking, jumping or turning to the camera.
  Only Rise, the Cultivate tile, M, or taking a hit ends it (a hit drops you out
  instantly, no get-up animation). The server also stands you up if you drift
  more than `MAX_DRIFT` from where you sat.

## Key files
- `src/server/Meditation.luau`: sessions, spot multiplier (`spotAt`, `bestItem`),
  1 s re-check; sets `Cultivation.meditation`.
- `src/client/Meditation.luau`: the M key / tile, animations
  (`Animations.Meditate`: Sit, Loop, GetUp), the seated tiles, the calm view, toasts.
- `src/client/MeditationMenu.luau`: the Comprehend / Method / Spirit Root panel;
  `src/client/Bottleneck.luau`: bottleneck checks and the comprehend call.
- `src/client/Controls.luau`: named movement locks (meditation, circulation);
  `isLocked()` also tells weapon presentation to stow through sitting/get-up and
  any overlapping circulation lock.
- `src/client/Movement.luau`: holds facing while seated.
- `src/shared/BuildItems.luau`: each item's `meditation` bonus.

## Data flow
Client fires `Meditate(true)` -> server records an anchor and spot (refused while
`ActionBusy` or deviated) -> `Cultivation.rate` multiplies by `spot.multiplier` ->
`pushState` carries `meditation = { multiplier, place }` to the HUD. Ending:
client fires `Meditate(false)`, or the server fires `Meditate(false)` to the client.

## Tuning knobs
- `Pacing.Meditation.ANYWHERE`, `ON_PEAK` (currently read through the
  `Config.Meditation` aliases).
- `Config.Meditation.ITEM_RANGE`, `MAX_DRIFT`; BuildItems `meditation` per item.
- `Meditation.luau`: `CALM_AFTER` (seconds before the HUD fades by itself),
  `TAP_DRIFT`, `TAP_SECONDS` (what counts as a tap that ends the calm view).

## The meditation menu (built 2026-10-21)
**Self is what you are; meditation is what you work on.** The Self card is
read-only (realm, root, method, equipped weapon, mastery). Everything that
changes your inner self happens seated, in one row of tiles above the vitals
(`Hud.Stack.CultivatePrompt`, `src/client/Meditation.luau`):

| Tile | Does | Appears when |
|---|---|---|
| Circulate | refine raw qi (the circulation minigame) | bar not full |
| Break Through | `CultivationAction "breakthrough"` (`BreakthroughView.attempt`) | bar full (replaces Circulate) |
| Comprehend | panel: techniques at a bottleneck, their insight and stone cost, Comprehend (`InventoryAction "comprehend"`) | a technique is at one (`Bottleneck.list`) |
| Method | panel: owned methods (qi, reaches, blurb); Use switches (`CultivationAction "method"`) | you own one (Foundation) |
| Spirit Root | panel: the root's card and exact numbers (same text as the Self card) | root tested |
| Rise | stand up | always |

- Square tiles in the top-right tiles' style (drawn icons from
  `art/ui/draw_ui.py` `meditation_art`), at least 50 px on phones; a QC1 player
  sees two (Circulate, Rise), so the calm-screen intent holds.
- The panel (`Stack.MeditationPanel`, `src/client/MeditationMenu.luau`) is a
  small window at the bottom of the stack: the tiles and the HUD step aside
  while it's open and its seal closes it. Rows come from `List.RowTemplate`;
  the list grows with its rows up to its `UISizeConstraint` and then scrolls.
- Comprehending moved here from the Arts pane. The pane still shows the
  bottleneck and its cost; its button reads "Meditate to comprehend" unseated
  and still works when seated. Shared logic: `src/client/Bottleneck.luau`.
- **Calm view.** The lotus at the right end above the vitals (`Stack.CalmToggle`)
  folds the tiles away and fades the rest of the HUD (bars, hotbar, top-right
  tiles, objective, buffs) via `Menus.setCalm` and `Motion.setShown`. It also
  comes on by itself after `CALM_AFTER` (20 s) seated without input. A tap that
  isn't a camera drag, any key, the lotus again, opening a menu or standing up
  brings everything back. Passive cultivation keeps running.

Still to come: Practise Dao (a short active drill with the equipped weapon for
Dao XP, with a cooldown, never XP for sitting).

**Root actions (server built, buttons to do).** The Spirit Root page offers the
pills the player holds: Marrow Washing Pill (raise grade) and Root Rebirth Pill
(reform the element), used with `InventoryAction "use"` (both refused unless
seated). After a rebirth the page shows both elements and the player keeps one:
`CultivationAction("root", keepNew)` (see [character](character.md)).

## Known gaps
- `server/Meditation.luau` still reads the multipliers via the Config aliases.
