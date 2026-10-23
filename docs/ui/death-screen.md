# Death screen

What the player sees between dying and reforming (`StarterGui.DeathScreen`,
`assets/DeathScreen.rbxmx`, `src/client/DeathScreen.luau`, lines in
`src/client/DeathLines.luau`). Built 2026-10-23 without a reference image, from kit
cuts already in the game; the bar was "calm and readable, not tacky".

## Look
- A soft crimson `death_vignette` (the DeathSave cut) over the screen edges at 0.3
  transparency; its centre is clear. It fades in over 0.5 s.
- In the middle, a little above centre (42 % down): an ink-wash band (`region_wash`)
  behind three lines and one ornament:
  - **Title** (Merriweather Bold 48, cream, black stroke): the cause, e.g. "Slain by the
    Spirit Wolf". `TextScaled` with a 48 max, so the longest beast names still fit.
  - the kit's gold cloud **Divider** (`divider_cloud`, 440x35);
  - **Flavour** (Merriweather Italic 28): one line, wraps on a narrow screen;
  - **Countdown** (Builder Sans Bold 22, gold): "Reforming at the main peak in 4",
    then "Reforming at the main peak..." ("Reforming in 4" in the testbed, which
    respawns on its pad).
- No flash, no blackout, no looping motion. The text block pops in with `Motion.fadeIn`
  and fades out when the new character arrives.
- While it's up, any open window closes, a pending DeathSave prompt is cancelled and the
  HUD fades away (`Menus.setCalm`); it all comes back on respawn.

## Layout
`DeathScreen` (ScreenGui, DisplayOrder 8, IgnoreGuiInset, ScreenInsets None,
ResetOnSpawn off): `Vignette` (full screen, outside the canvas) and `Canvas` with the
authored `UiScale` (fitted by `UiScale.fit`, desktop baseline 1920x1080, phone 844x390).
`Canvas.Panel` (1000x250, AnchorPoint 0.5, at 0.5/0.42) holds the `Device` UIScale
(1 on desktop, 0.72 on a phone: title about 35 px, flavour 20, countdown 16 on an
844x390 screen) and `Body` (with the `Motion` UIScale the fade pops) holding `Wash`
(1280x320) and `Lines` (a centred vertical list, 12 px gaps: `Title`, `Divider`,
`Flavour`, `Countdown`).

Measured in edit view (1616x784, scale 0.726): wash, title, divider, flavour and
countdown centres all at x = 808.0 (the screen centre); the text block (264 to 394.5)
is centred on the wash (329.3). Phone canvas (844x390 at scale 1, Device 0.72): every
centre at the canvas centre x (808.0), the text block (292.9 to 428.8) centred on the
wash (360.8), 164 px below the canvas top; the 720 px line width leaves 62 px a side.

## Causes
The server decides (`Combat.died`, called from `Humanoid.Died` in `Main.server.luau`)
and sends `Effect "died"` with `{ cause, source, poisoned, respawn, hub }`:
- `fall`: the root is gone or within 50 studs of `FallenPartsDestroyHeight`;
- `tribulation`: the last hurt was the tribulation (its strikes are non-lethal today,
  so this waits for a lethal tribulation);
- `enemy` with `source` = the enemy's def id: the last hurt landed within
  `IN_COMBAT_SECONDS` (6 s);
- `unknown`: anything else (a reset, a stale hurt).

The client turns `enemy` into `boss` (the def has `boss`), `poison` (poison was still
in the player; poison itself never kills) or `beast`, with the def's `name`.

## Lines
`DeathLines.luau` is data only: `Titles[cause]` (`{name}` is the killer), `Flavour[cause]`
plus a `general` pool, and the countdown strings. A known cause uses its own flavour
65 % of the time and a general line otherwise; the last 4 titles and flavours are
skipped, so it rarely repeats. Keep lines under about 50 characters (one line on a
phone). To add a cause: a server case in `Combat.died`, a client case in
`DeathScreen`'s `resolve`, and its pools here.

## Preview
In play, from the client console:
`require(game.Players.LocalPlayer.PlayerScripts.Client.DeathScreen).preview("boss")`
(cause: `beast`, `boss`, `poison`, `fall`, `tribulation`, `unknown`, or an enemy id).
It closes by itself after 5 s. Rebuild by hand in Studio (no builder script), then export.

## Known gaps
- Players who die while meditating: the calm view is cleared on respawn, which is what
  Meditation does when you stand anyway.
- No sound yet (a low gong would suit it).
