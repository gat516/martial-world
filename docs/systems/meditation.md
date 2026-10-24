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
- `src/client/MeditationMenu.luau`: the Comprehend (Practice > Technique) / Method / Spirit Root panel;
  `src/client/Bottleneck.luau`: bottleneck checks and the comprehend call.
- `src/client/Controls.luau`: named movement locks (meditation, circulation);
  `stowsWeapon()` tells weapon presentation to stow through sitting/get-up and
  any overlapping circulation lock, unless every lock keeps the weapon (the drill).
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
  `TAP_DRIFT`, `TAP_SECONDS` (what counts as a tap that ends the calm view),
  `LOTUS_GAP` (px from the last seated tile to the lotus).

## The meditation menu (built 2026-10-21)
**Self is what you are; meditation is what you work on.** The Self card is
read-only (realm, root, method, equipped weapon, mastery). Everything that
changes your inner self happens seated. Sitting swaps the vitals for the
cultivation bars (`Hud.Stack.SeatBars`, `src/client/SeatBars.luau`: realm,
progress to the breakthrough lozenge and the overflow past it, the dantian;
decided 2026-10-22, the progress bar lives here, not on the fighting HUD), with
one row of tiles above them (`Hud.Stack.CultivatePrompt`, `src/client/Meditation.luau`):

| Tile | Does | Appears when |
|---|---|---|
| Circulate | refine raw qi (the circulation minigame) | bar not full |
| Break Through | `CultivationAction "breakthrough"` (`BreakthroughView.attempt`) | bar full (replaces Circulate) |
| Method | panel: owned methods (qi, reaches, blurb); Use switches (`CultivationAction "method"`) | you own one (Foundation) |
| Spirit Root | panel: the root's card and exact numbers (same text as the Self card), root pills, the reform choice; a seal dot while a choice waits | root tested |
| Practice | swaps the row for the Practice tiles (below); a seal dot while a technique is at a bottleneck | either Practice action exists (a bottleneck, or the Dao drill is unlocked) |
| Rise | stand up | always |

**Practice row (decided 2026-10-21).** The user folded Comprehend under
Practice: "practice would open up a row of icons: practice technique, practice
weapon dao, and a back button". Tapping Practice swaps the main row for these
tiles in the same row (`CultivatePrompt.PracticeTechnique`, `.PracticeDao`,
`.Back`, with a small pop); the lotus follows the row's end.

| Tile | Does | When it can't |
|---|---|---|
| Technique (`PracticeTechnique`, the gourd) | panel: techniques at a bottleneck, the weapon Dao they need and their stone cost, Comprehend (`InventoryAction "comprehend"`) | dimmed; toasts "No technique is at a bottleneck yet." |
| Weapon Dao (`PracticeDao`, crossed jian) | Practice Dao drill (`CirculationMinigame.practice`); an m:ss countdown while resting, a tap toasts the wait | dimmed; toasts the stage it opens at, or that the Dao is mastered |
| Back (`icon_back`) | back to the main row | always |

Both actions stay on the Practice row even when unavailable (dimmed), so the
row keeps its shape. The main row comes back after a drill, when the panel
opens (it shows again when the panel closes), on Back, on standing, and when
neither action exists any more. The onboarding guide keys are
`PracticeTechnique` and `PracticeDao` (server `Quests.luau`); until the Practice
row is open the client points at Practice instead (`Guide.luau` `FOLDED`).

- Square kit tiles (`tile_neutral`, Break Through on `tile_gold`) with a cream
  glyph and a caption under each, at least 50 px on phones; a QC1 player
  sees two (Circulate, Rise), so the calm-screen intent holds; at most five show
  at once (Circulate or Break Through, Method, Spirit Root, Practice, Rise). The
  look of every piece here (tiles, lotus, panel, overlay, reveal card, title card)
  is in [cultivation UI](../ui/cultivation.md).
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
- **Calm view.** The lotus (`Stack.CalmToggle`) sits just past the last seated
  tile (Rise), level with the tiles; `Meditation.placeLotus` moves it to the
  row's end whenever tiles come and go (`LOTUS_GAP`), and it keeps that spot
  while the row is folded away so the same tap brings it back. (It used to be
  pinned to the stack's right end, where a full row put it over Rise.) It
  folds the tiles away and fades the rest of the HUD (bars, hotbar, top-right
  tiles, objective, buffs) via `Menus.setCalm` and `Motion.setShown`. It also
  comes on by itself after `CALM_AFTER` (20 s) seated without input. A tap that
  isn't a camera drag, any key, the lotus again, opening a menu or standing up
  brings everything back. Passive cultivation keeps running.

**Practice Dao (built).** The Weapon Dao tile on the Practice row
(`CultivatePrompt.PracticeDao`, crossed jian, `icon_practice` in
`meditation_art`) runs a 20 s drill with the equipped
weapon, played on its own minigame, Weapon Forms (`Minigames/Forms.luau`,
titled "<Class> Forms")
(`CirculationMinigame.practice()` -> `CultivationAction "practiceStart" /
"practiceFinish" / "practiceCancel"`, server `src/server/DaoPractice.luau`).
*Forms (decided 2026-10-21):* osu-style, not a fixed ring. Numbered strike
points pop up anywhere on the field in flowing strings (count restarts each
string, a long jump between strings, the odd quick double), so several are up
at once; tap the point itself as its approach ring closes. Purple points are
bad habits to strike and purge. Empty-field taps and early taps on a point are
strays. Touch/mouse aim with the tap, Space/Z/X strike at the mouse, gamepad A
strikes whatever is due. Tuning: `Config.Circulation.Games.Forms` (weight 0, so
circulation never picks it). Scored like a circulation run; pays up to `XP_SHARE` (25%) of the current Dao
level's XP, then a 5 min cooldown (`data.daoPracticeReadyUnix`, pushed as
`daoPracticeReady`). Leaving early costs nothing and starts no cooldown. Unlocks
at QC7 (`Pacing.DaoPractice.FROM`), never XP for sitting.

*Stance (decided 2026-10-21):* once the server starts the drill the character
gets up (Meditate `GetUp`) but stays in meditation: still locked in place, the
session and passive cultivation keep running, and the weapon stays in hand
(`Controls.lock("Meditation"/"Circulation", keepWeapon)`, so WeaponAnimator
shows it and its idle; while every lock keeps the weapon it also ignores
`ActionState.blocked`, which is true the whole time you meditate). Every tap in the drill plays the next strike of the
equipped class's chain (`Animations.Weapons.<Class>/1..n`, Fists bare-handed),
looping, hit or miss (Feel `ui.tapped`, which Forms and Pulse call). When the drill ends
the character sits back down (`Sit`, then `Loop`). Strikes replicate, so others
see the forms. Known gaps: the drill overlay sits over the screen centre and
may hide the character's swings; strikes are cosmetic only (no hit/miss
difference).

**Root actions (built).** Under the root card the Spirit Root page lists the
pills the player holds, each with Absorb (`InventoryAction "use"`, refused unless
seated; refusals toast): Marrow Washing Pill ("Raise your root one grade"; at
Heaven grade it says "Your root is at its purest." and has no button) and Root
Rebirth Pill ("Reform as another element"). Holding neither, the note adds one
quiet line: "Rare pills can purify or reform your root." While a reformed element
is pending (`root.pending`), the page shows two rows instead, the current root
("Return to <old>", lacquer) over the new one ("Keep <new>", jade), and calls
`CultivationAction("root", keepNew)` (see [spirit root](../character/spirit-root.md)). The Spirit
Root tile wears the seal dot (`Root.Badge`) until the choice is made.

## Known gaps
- `server/Meditation.luau` still reads the multipliers via the Config aliases.
