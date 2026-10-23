# Vitals stack, seated bars and guard bar

Covers the bottom-centre HUD: the vitals mount (health, combat qi, guard trough), cooldown chips, the seated cultivation bars and meditation tiles, the breakthrough nudge and the guard bar; read it when working on `Hud`, `SeatBars`, `GuardBar` or that layout. General HUD rules are in [ui](../systems/ui.md).

## Vitals stack
The bottom-centre stack (user decision, 2026-10-22, from a Deepwoken-style
reference in our own style): one gilded mount (`Stack.Vitals`) holding three bars, top to
bottom: health (thick, ten segments), combat qi (the mana techniques spend;
bright azure, with its number) and the guard posture trough (always shown,
dim while full and idle, draining toward the lacquer seal in the middle),
with the realm crest above and the hotbar below. Compact pass (user,
2026-10-22, from a phone screenshot): the plate is notched (a full-width body
for health and qi, a narrower tab under its middle for the guard) and sits
right on the hotbar; the PC Dash/Strike cooldown chips (`Stack.Cooldowns`)
tuck into the left notch instead of a row of their own. Ornament is trimmed to
a gilt rim, end lozenges and small curls so the bars get the height, not the
frame. Fills are bright (crimson health, azure qi, lit pale-gold guard) and
authored full, so the edit view and the first frame read full. Every bar fill
(vitals and seated) wears `Sheen` (`fill_sheen.png`: top lip, soft inner glow,
darker belly) and, except the centre-draining guard, a soft bright leading
`Edge` (`fill_edge.png`), both white/black so the fill colour shows through. The
stack takes at most 39% of the screen's height (`Layout` HEIGHT_SHARE), 31% on
short screens (`Platform.isSmall`, SMALL_HEIGHT_SHARE; 45% once, which on a
landscape phone in the device emulator, which gets the PC layout, filled over
half the screen). Its box is aspect 3.758 with MaxSize 560x149, and
`Prompts.Dock` mirrors it.

Redrawn 2026-10-23 to the user's own reference image (the Figma kit's Example
page HUD is the target): on top the realm plaque (`Crest`, the character window shortcut); then the gold double-framed plate with glossy red
health (slanted segment cuts, red gems at the ends) and glossy sky-blue qi;
the tan guard trough in the tab with a red gem seal; and the PC Dash/Strike
chips as round dark gold-rimmed discs (a `Shade` clipped
in each `Cooldown`) under the plate's left end. Seated, the same plate style
with the realm plaque. No name plaque (user, 2026-10-22): a name row made the
stack too tall on phones and your own name tells you nothing, so it was cut and
the stack cropped to the top of the realm plaque (the stack's shares, aspect and
every child's Y scaled by 0.866 so nothing moved on screen).

Art (kit reskin, user, 2026-10-22): exported from the Figma kit, not drawn by
script. `art/ui/figma/` holds the Figma exports (source frame, pieces and the
re-export steps in its README): `Vitals.Plate` (ZIndex 0, behind the bars) is
the notched body and guard tray, `Vitals.Mount` (ZIndex 3, over the bars) the
bar rims, health segment cuts, ruby gems, studs and the guard seal, `Crest` the
kit's title plaque, and the Dash/Strike chips the kit's round seal with the
white `element_wind` / `weapon_sword` kit cuts. Seated uses the same plate, its
own rims (`hud_seat_rims.png`) and plaque. Each image is laid out on the
Vitals box's own bar positions and fills its box exactly (Stretch, no slicing),
so moving a bar means moving it in the Figma sheet too. Hotbar slots wear the
kit's `item_slot` cut (empty slots at half transparency, as before) and the held
slot's `Halo` is `item_slot_selected` with its middle keyed out
(`tools/key_inner.py`), drawn over the frame. `draw_vitals.ps1`'s
`vitals_mount`, `seat_mount`, `realm_plaque`, `vitals_chip` and `name_plaque`
are no longer used; `draw_vitals.py` still draws `fill_sheen`/`fill_edge`.
The seated tiles, lotus, Force Breakthrough pill and the touch prompt dock's
column sit just above the plate and moved down with it; the lotus is centred
on the tiles' frames, 14 px past the last tile (`Meditation` LOTUS_GAP). Cultivation and the dantian
left the fighting HUD: they show while seated, in the same spot
(`Stack.SeatBars`). Health and qi have a pale trail that lingers on a drop.
A cast refused for qi (`QiDenied` changes) flashes the qi bar red and shakes
the mount; hotbar arts the player can't pay for (`Qi < Techniques.qiCost`)
dim like weapon-gated ones and still cast.

## Breakthrough nudge
Breakthrough nudge: when `BreakthroughReady` turns true a toast says "You
feel ready to break through" once (skipped when the server just said so),
then again only while the player stands idle (no input for 25 s), at most
every 150 s (`BreakthroughView` NUDGE_*). No pulsing or central prompt.

## Seated bars and meditation tiles
Seated: the vitals give way to the cultivation bars (`Stack.SeatBars`, the
same notched plate with `hud_seat_rims.png`; `Menus.setSeated`): the realm on
the same crest the vitals wear (`TitleCrest`), one cultivation track with the
breakthrough mark inside it at 80% and the overflow (cultivation beyond the
bar, up to `CultivationCap`) as the paler stretch past the mark, and the
dantian (raw qi) in the tab under it. The cultivation line reads the numbers, "Ready to break
through" in gold, or what blocks a full bar (`BreakthroughBlock`: insight,
method, peak). Then the meditation menu, a row of square tiles above them that
appear only when relevant (Circulate or Break Through, Method, Spirit Root,
Practice, Rise; Practice swaps in its own tiles: Technique, Weapon Dao,
Back), a small panel for Comprehend / Method / Spirit
Root (root pills and the reform choice live on its Spirit Root page), and
the lotus calm toggle that fades the HUD for a clean view (`Menus.setCalm`;
also after 20 s idle; a tap brings it back). See [meditation](../systems/meditation.md).
The standing Force Breakthrough pill (`Stack.BreakthroughButton`) is the only
breakthrough button outside the seat.

- The circulation overlay has a Leave pill at its header's right corner
  (`Circulation.Column.Header.Title.Leave`) that ends the run early for free.

## Guard bar
Guard bar (`GuardBar.luau`, `Stack.Vitals.GuardBar`): the posture trough in
the vitals plate's tab, always shown. The fill drains toward the mount's centre
seal, warms toward red below 0.3 and sits at `IDLE_DIM` while full and not
held. `GuardBar.set(ratio, active)` every frame (GuardController);
`GuardBar.flash` "parry" (pale-gold flash), "blocked" (jolt and tick),
"break" (red `guard_cracks` over the trough, fill empty for `BREAK_HIDE`).
Per-frame changes go through UIGradient transparency and colour so the calm
view's fade can't fight them. `guard_rim`/`guard_fill`/`guard_seal` from
`art/ui/draw_guard.py` are no longer used. `Play.BlockButton` ("Guard", 擋) is the
touch-only guard button above Dash, placed by `Layout.apply` (not yet checked
against the Lock button's arc on a phone); GuardController binds it.

## Known gaps
- The vitals and seat bars were previewed in Studio's edit view at PC size and
  at a phone-sized stack (426 px wide), not on a device or the emulator, and not
  in play: the qi flash, trails, guard trough states, seated swap and nudge
  timing are untested.
- The 2026-10-23 redesign was previewed in edit view at a 560 px and a phone-
  sized (397x122) stack and checked once in play (realm and numbers fill); the
  chip shade draining, the seated swap and a device or the emulator are
  untested. Long realm names shrink to fit their plaque (about 15 px at most)
  rather than widening it.
- The name plaque's removal (2026-10-22) was a file-only crop, not previewed
  in Studio: check the realm plaque isn't clipped at the stack's top, the seated
  tiles, Force Breakthrough pill and calm lotus still sit just above the plate,
  the chips in the notch, and the touch prompt dock's list (`Prompts.Dock.List`
  at Y 0, now just above the realm plaque's top instead of the name row's).
- The Figma reskin (2026-10-22) was previewed in edit view at PC size (560 px
  stack), standing and seated, with a filled and a held hotbar slot; not on a
  phone or the emulator, not in play. The chip glyphs read small at 24 px.
- Bar numbers over a bright fill show the black text stroke as a ghost of the
  "/" at small sizes ("180 // 260"); the dantian texts use a lighter stroke
  (0.35). Check the others in play.
- The hotbar shows no qi price; arts just dim when short.
