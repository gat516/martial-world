# Meditation

## Purpose
Sit still to multiply passive cultivation; also where breakthroughs and seated
circulation happen.

## Design intent
- Idle-safe: you can leave it running. Where you sit matters: anywhere x1.5,
  your own peak x2.5, plus the best meditation seat or artifact within range on
  your peak (BuildItems `meditation`), which gives building a progression payoff.
- Seated is a calm screen: only Circulate (or Break Through when the bar is
  full) and Rise.
- Seated locks the character: no walking, jumping or turning to the camera.
  Only Rise, the Cultivate tile, M, or taking a hit ends it (a hit drops you out
  instantly, no get-up animation). The server also stands you up if you drift
  more than `MAX_DRIFT` from where you sat.

## Key files
- `src/server/Meditation.luau`: sessions, spot multiplier (`spotAt`, `bestItem`),
  1 s re-check; sets `Cultivation.meditation`.
- `src/client/Meditation.luau`: the M key / tile, animations
  (`Animations.Meditate`: Sit, Loop, GetUp), the seated HUD row, toasts.
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

## Planned: the meditation menu (design, decided 2026-10-21)
**Self is what you are; meditation is what you work on.** The Self card is
read-only (realm, root, method, equipped weapon, mastery). Everything that
changes your inner self happens seated, in one small menu of tiles that appears
when you sit:

| Tile | Does | Appears when |
|---|---|---|
| Circulate | refine raw qi (today's minigame) | always |
| Break Through | today's button | bar full |
| Comprehend | break a technique bottleneck (moves here from the Arts pane, which keeps showing the bottleneck) | a technique is at one |
| Method | inspect and switch owned methods (`CultivationAction "method"`; not on the Self card) | Foundation |
| Spirit Root | inspect it; later raise grade / reroll | root tested |
| Practise Dao | a short active drill with the equipped weapon for Dao XP (later, not v1) | a second weapon class |

- Tiles only appear once they matter, so a QC1 player still sees one tile and the
  calm-screen intent holds. On phones: one row of 2-5 big tiles.
- **Hide the menu to just enjoy the view.** Meditation is also the AFK state, so
  one small toggle collapses the tiles and fades the rest of the HUD (bars,
  hotbar, tiles) for a clean view; tapping it (or anywhere) brings them back.
  Prefer a calm icon (a lotus or an eye) over a hamburger, which reads as an app
  menu; ui-designer's call. Idea: the HUD also fades by itself after ~20 s of no
  input while seated. Passive cultivation keeps running either way.
- Practise Dao must be an active drill with a cooldown (reuse the circulation
  minigames as weapon forms), never XP for sitting, so AFK can't farm it.

## Known gaps
- `server/Meditation.luau` still reads the multipliers via the Config aliases.
