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
| Spirit Root | panel: the root's card and exact numbers (same text as the Self card), root pills, the reform choice; a seal dot while a choice waits | root tested |
| Practice | Practice Dao drill (`CirculationMinigame.practice`); dimmed with an m:ss countdown while resting, a tap toasts the wait | from `Pacing.DaoPractice.FROM`, until the equipped class's Dao is mastered |
| Rise | stand up | always |

- Square tiles in the top-right tiles' style (drawn icons from
  `art/ui/draw_ui.py` `meditation_art`), at least 50 px on phones; a QC1 player
  sees two (Circulate, Rise), so the calm-screen intent holds.
- The panel (`Hud.MeditationPanel`, `src/client/MeditationMenu.luau`) is a
  small window centred on screen, like the other windows (all three pages share
  it): the tiles and the HUD step aside while it's open and its seal closes it.
  Rows come from `List.RowTemplate`; the list grows with its rows up to its
  `UISizeConstraint` (160 px, so it fits a phone in landscape) and then
  scrolls. `fitList` sets the canvas from the layout (`AutomaticCanvasSize`
  is off: it ignored the self-sizing rows, so the Spirit Root page showed only
  its first row).
- Comprehending moved here from the Arts pane. The pane still shows the
  bottleneck and its cost; its button reads "Meditate to comprehend" unseated
  and still works when seated. Shared logic: `src/client/Bottleneck.luau`.
- **Calm view.** The lotus at the right end above the vitals (`Stack.CalmToggle`)
  folds the tiles away and fades the rest of the HUD (bars, hotbar, top-right
  tiles, objective, buffs) via `Menus.setCalm` and `Motion.setShown`. It also
  comes on by itself after `CALM_AFTER` (20 s) seated without input. A tap that
  isn't a camera drag, any key, the lotus again, opening a menu or standing up
  brings everything back. Passive cultivation keeps running.

**Practice Dao (built).** The Practice tile (`CultivatePrompt.Practice`, crossed
jian, `icon_practice` in `meditation_art`) runs a 20 s drill with the equipped
weapon, played on a circulation minigame titled "<Class> Forms"
(`CirculationMinigame.practice()` -> `CultivationAction "practiceStart" /
"practiceFinish" / "practiceCancel"`, server `src/server/DaoPractice.luau`).
The hint comes from the run kind (Pulse's qi wording would read wrong). Scored like a circulation run; pays up to `XP_SHARE` (25%) of the current Dao
level's XP, then a 5 min cooldown (`data.daoPracticeReadyUnix`, pushed as
`daoPracticeReady`). Leaving early costs nothing and starts no cooldown. Unlocks
at QC7 (`Pacing.DaoPractice.FROM`), never XP for sitting.

**Root actions (built).** Under the root card the Spirit Root page lists the
pills the player holds, each with Absorb (`InventoryAction "use"`, refused unless
seated; refusals toast): Marrow Washing Pill ("Raise your root one grade"; at
Heaven grade it says "Your root is at its purest." and has no button) and Root
Rebirth Pill ("Reform as another element"). Holding neither, the note adds one
quiet line: "Rare pills can purify or reform your root." While a reformed element
is pending (`root.pending`), the page shows two rows instead, the current root
("Return to <old>", lacquer) over the new one ("Keep <new>", jade), and calls
`CultivationAction("root", keepNew)` (see [character](character.md)). The Spirit
Root tile wears the seal dot (`Root.Badge`) until the choice is made.

## Known gaps
- `server/Meditation.luau` still reads the multipliers via the Config aliases.
