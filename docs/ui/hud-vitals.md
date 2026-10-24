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
authored full, so the edit view and the first frame read full.

Bar shape (user, 2026-10-23, from their pre-reskin HUD; a 45-degree slant tried
first was rejected as overdone): health comes to a short point at both ends
(depth 0.3 of its height), each tip covered by a `ruby_stud` cap with a small
gold diamond outside it on the frame, and slanted segment cuts inside; qi is a
plain rounded bar inset to health's full-height span; the guard and the
dantian are rounded bars centred in the symmetric tray under the ruby seal. The
seated track is pointed at both ends with ruby caps, split by the breakthrough
mark into the cultivation fill (pointed start, square end) and the overflow
(square start, pointed end). How: `Fill`, `Trail` and `Flash` are ImageLabels
of a white shape (`hud_fill_pt`, `_ptl`, `_ptr`, `_round`; `draw_vitals.py`)
9-sliced so only the plain middle stretches and the ends keep their shape at
any width, so a draining fill keeps its pointed or rounded leading edge; the
`Theme` gradient (or `ImageColor3` for the trail and flashes) colours it, and
the Fill's `Sheen` child (`hud_sheen_*`: top lip, darker belly) is sliced the
same way. Hud keeps every such image's `SliceScale` at its height / 64 so the
ends keep their proportions on any stack size. The bar frames themselves are
transparent: troughs, rims, cuts and caps are baked into the plate and rims
art. The
stack takes at most 39% of the screen's height (`Layout` HEIGHT_SHARE), 31% on
short screens (`Platform.isSmall`, SMALL_HEIGHT_SHARE; 45% once, which on a
landscape phone in the device emulator, which gets the PC layout, filled over
half the screen), and 26% on a touch phone (TOUCH_SMALL_SHARE, phone HUD pass
2026-10-23: 101 px tall and 381 wide at 844x390, slots 35 px; at 667x375 the
stack is held by its width, the screen less the touch cluster's room, 347 px). In combat on a
touch phone the realm plaque (`Crest`) fades away with the folding top-right
tiles and comes back when they do (`TileFold`, the same `InCombat` attribute;
user's pick of two options, 2026-10-23, after the vitals sat big over the
character in a boss fight; the other was fading the plate while health is full). Its box is aspect 3.758 with MaxSize 560x149, and
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

Shape and depth (phone HUD pass, user, 2026-10-23, from
`docs/reference/ui/hud_vitals_reference.webp`: "give the foundation establishment a
shape and some depth... sharp on the edges but curved, well suiting ornaments"):
the realm plaque, the vitals plate and the seated plate are drawn by
`art/ui/draw_hud_frames.py` into `art/ui/hud/`. The plaque is dark red-brown
lacquer with a lit top edge and an inner shade, its ends come to points through
concave curved bevels, a gilt band and fine inner line follow that outline, a gilt
diamond stud with a pearl sits on each point and a small scroll (two curls and a
bud) beyond it; no cloud caps. The plates are the same notched body in dark
lacquer with the same depth, a chamfered gilt band and inner line following the
whole outline (tab included), recessed troughs (shaded under the top lip, tinted
red, azure and warm for health, qi and guard; jade and blue seated), and gilt
sockets under the kit's side and tab studs so they read as set into the frame.
The rims (`Vitals.Mount`, `SeatBars.Mount`: rims, ruby caps, segment cuts, the guard
seal) are still the Figma exports below, untouched. Realm text: `RealmText` /
`Title` sit at 0.242-0.758 x 0.2-0.8 of the plaque, inside its inner line, centred
to 0.00 px. The player's name stays off the HUD.

Art (kit reskin, user, 2026-10-22): exported from the Figma kit, not drawn by
script (the plate and plaque have since been redrawn, above). `art/ui/figma/` holds the Figma exports (source frame, pieces and the
re-export steps in its README): `Vitals.Plate` (ZIndex 0, behind the bars) is
the notched body, guard tray and troughs, `Vitals.Mount` (ZIndex 3, over the
bars) the rims, segment cuts, ruby caps, studs and the guard seal, `Crest`
the kit's title plaque, and the Dash/Strike chips the kit's round seal with the
white `element_wind` / `weapon_sword` kit cuts (19 px at the 560 px stack, 4 px
apart, glyphs at 60% and centred to 0.00 px, left edge on slot 1's left edge,
centred in the 25.8 px band between the plate body's bottom (row 93 of 128 in the
chips' columns) and the slots: 3.39 px clear of each. They were 28 px and ran into
the plate's frame and studs: "dash and melee icons are being overlapped, need to make
it smaller", 2026-10-23. The held slot's halo, 3 px outside the slot, comes within
0.4 px of them. `FoundationMeter` mirrors the Dash chip's spot and size on the right).
Seated has its own plate and rims (`hud_seat_plate.png`, `hud_seat_rims.png`)
and the same plaque. Each image is laid out on the
Vitals box's own bar positions and fills its box exactly (Stretch, no slicing),
so moving a bar means moving it in the Figma sheet too. Hotbar slots are the
Inventory's plain slot (2026-10-23, [inventory](inventory.md) "Slots"): an ink well
(`slot_plain`, empty slots at 35 % transparency) with the rarity as a thin tinted
`Edge` and a faint `Wash`, the icon in a `Well` box (arts on their seal `Disc`), and
the held item's `Halo` the same edge ring in cream, 3 px outside the slot. On PC the
name is one line of Builder Sans Bold 11 in a strip at the bottom (truncated with an
ellipsis; two lines left a 21 px icon), the well centred in the space above it
(28 px, 0.00 px off centre, 12 px at the sides and 4.7 px above and below); on touch
names hide and the well (64 %) is centred on the slot, 9.4 px from the edges
(`Layout`). The weapon slot shows the model in hand (its `Model` viewport, 6 px
from the edges). On a touch phone the hotbar shrinks with the stack (35 px slots at
844x390) and hides empty slots unless the Inventory is open. `draw_vitals.ps1`'s
`vitals_mount`, `seat_mount`, `realm_plaque`, `vitals_chip` and `name_plaque`
are no longer used, nor are `fill_sheen`/`fill_edge` (still drawn by
`draw_vitals.py`, which now also draws the shaped fills).
The seated tiles, lotus, Qi Surge pill and the touch prompt dock's
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

## Qi surge pill
The old Force Breakthrough pill (`Stack.BreakthroughButton`, unchanged in
`assets/Hud.rbxmx`) is now the qi surge's button and notice, driven by
`BreakthroughView`: it shows only while the server's `SurgeReady` is true (in a
fight, badly hurt, bar at 90%; [cultivation](../systems/cultivation.md#qi-surge)),
never seated or with a menu open. Its label reads "M to qi surge" on PC (M surges
instead of meditating while it's ready) and "Qi Surge" on touch; a click or tap
fires it. While surging, the realm plaque shows the surged stage (`SurgeRealm`,
`Hud.luau`).

**For the ui-designer (not built):** the roadmap wants the touch surge button in
the touch cluster (`Play`, beside Dash/Guard), not the stack pill, and its own
glyph (the pill still wears the breakthrough glyph). A `Play.SurgeButton`
ImageButton (hidden by default, with a `Label` TextLabel) would be wired by
showing it on touch in place of the pill; the pill would then stay the PC notice.
Also unchecked: "M to qi surge" fitting the pill's label box at phone scale.

## Seated bars and meditation tiles
Seated: the vitals give way to the cultivation bars (`Stack.SeatBars`, the
same notched plate with `hud_seat_rims.png`; `Menus.setSeated`): the realm on
the same crest the vitals wear (`TitleCrest`), one cultivation track with the
breakthrough mark inside it at 80% and the overflow (cultivation beyond the
bar, up to `CultivationCap`) as the paler stretch past the mark, and the
dantian (raw qi) in the tab under it. The cultivation line reads the numbers, "Ready to break
through" in gold, or what blocks a full bar (`BreakthroughBlock`:
method, peak). Then the meditation menu, a row of square tiles above them that
appear only when relevant (Circulate or Break Through, Method, Spirit Root,
Practice, Rise; Practice swaps in its own tiles: Technique, Weapon Dao,
Back), a small panel for Comprehend / Method / Spirit
Root (root pills and the reform choice live on its Spirit Root page), and
the lotus calm toggle that fades the HUD for a clean view (`Menus.setCalm`;
also after 20 s idle; a tap brings it back). See [meditation](../systems/meditation.md).
Breakthroughs are seated only: there is no breakthrough button outside the seat.

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
- Phone HUD pass (2026-10-23): previewed in the sandbox's Edit view on simulated
  1920x1080, 1366x768, 844x390 and 667x375 canvases (the real Hud cloned onto a
  sized frame with Layout's touch flips applied by hand), not on a device, the
  emulator or in play. Untested: the buff chips' timer and tap/hover details, the
  `seconds` field on buffs from the server, the arc cluster and Lock button with
  Roblox's thumbstick, the safe-area inset on a notched phone. The plaque and plates
  were drawn by script on the brief's say-so; a Codex sheet in the kit's hand could
  replace them later.
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
  tiles, Qi Surge pill and calm lotus still sit just above the plate,
  the chips in the notch, and the touch prompt dock's list (`Prompts.Dock.List`
  at Y 0, now just above the realm plaque's top instead of the name row's).
- The Figma reskin (2026-10-22) was previewed in edit view at PC size (560 px
  stack), standing and seated, with a filled and a held hotbar slot; not on a
  phone or the emulator, not in play.
- The pointed/rounded bars (2026-10-23) were previewed in edit view (a short
  952x306 viewport), standing (full and part-drained health, trail, qi, guard)
  and seated, and checked numerically at a 560x149 and a 430x114 stack: every
  bar box on its baked window to 0.00 px, labels, glyphs and slot frames
  centred to 0.00 px, the guard and dantian within 0.25 px of the tray centre
  with equal trough-to-tray gaps on both sides, health and qi 0.26 px right of
  the plate centre. Edit view doesn't run Hud's SliceScale keeper, so at
  smaller stacks the points look a touch larger there than in play.
  Not checked in play: the deny and parry flashes, trail tweens, guard jolt, the
  calm fade over the image fills, and the SliceScale keeper on a resize.
- Bar numbers over a bright fill show the black text stroke as a ghost of the
  "/" at small sizes ("180 // 260"); the dantian texts use a lighter stroke
  (0.35). Check the others in play.
- The hotbar shows no qi price; arts just dim when short.
