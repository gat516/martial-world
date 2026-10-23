# World events, tribulation and rifts (screen UI)

The Events screen (`StarterGui.Events`, `assets/Events.rbxmx`) shows world events, the
heavenly tribulation and secret-realm rifts; the leaderboard window shares it
([leaderboards](leaderboards.md)). Built 2026-10-23 in the kit's style from codex sheet C4
(and C5, C6, the light sheet), composed in Studio from the cuts (no Figma mock).

## Screen structure
- `tools/events_ui_build.luau` builds the whole ScreenGui (run in a sandbox's Edit
  datamodel, then export with `tools/export_rbxmx.luau`); `tools/events_ui_preview.luau`
  fills a layout's slots with `__P*` samples in Edit (and clears them). Rebuilding
  replaces the GUI, so check the live one for hand edits first.
- `Canvas` (fitted by `UiScale`) holds two sets of empty slots: `Desktop` laid out at
  1920x1080 and `Phone` at 844x390; one shows per session (`UiScale.isPhone()`).
  Art lives once in `Templates` (hidden), sized in scale so a clone fills any slot;
  `Events/Gui.luau` places clones (`Gui.place(template, slot)`).
- Fonts: Merriweather for titles, Builder Sans Bold for small text, Fredoka One for
  numbers. The kit's Cormorant Garamond isn't a Roblox font (checked in Studio).
- Text on the art is always live; light text has a near-black stroke, ink text on the
  paper scroll has none. Text sizes are `TextScaled` with a `UITextSizeConstraint`
  (floor 10 baseline px); the tracker's self-sizing name uses `Gui.textSize` (20 desktop,
  13 phone).

Slots (baseline px; anchor top-centre unless noted):

| Slot | Desktop | Phone | Holds |
|---|---|---|---|
| Herald | y 112, 760x118 | y 96, 430x70 | event scroll |
| Ribbon | y 112, 720x96 | y 96, 460x62 | tribulation ribbon |
| Tracker | y 116, 900x72 | y 98, 560x44 | countdown rings (row, centred) |
| Counter | y 216, 84x106 | y 152, 56x72 | strike counter |
| Chips | centre, y 0.42, full width minus 24 per side, 59 tall | y 0.5, minus 12, 46 tall | (unused box; edge chips go in its layout and move over the whole canvas) |
| Decree | y 96, 280x359 | y 68, 180x230 | Heaven's Decree card |
| Rift | centred, 380x519 | centred, 250x341 | rift card |
| Board | centred, 720x600 | centred, 600x350 | leaderboard window |

Top-centre slots sit under the Hud toast (y 10, up to ~90 px) and, on the phone,
under the top-right tiles. The top-left stays Roblox's chat. Heralds and the tracker
hide while a menu is open; nothing here darkens the screen or loops.

## World events (`Events/WorldEventView.luau`, wired)
Reads the workspace attribute `WorldEvents` (JSON `{ id, name, ends, at?, direction? }`,
published by `src/server/WorldEvents/init.luau`). No server change.
- **Herald:** when an event starts while you're here, the `event_scroll` (three-part:
  rods and cloud corners keep their aspect, the paper strip stretches) unrolls at the
  top centre from 0.3 of its width over 0.4 s, the kicker ("WORLD EVENT · TO THE
  NORTHEAST", in the event's ink colour) and name fade in, it holds 3.6 s and rolls up.
  Heralds queue with the tribulation ribbon (`Gui.herald`); skipped while a menu is open.
  Events already running when you join get a tracker and pin without a herald.
- **Tracker:** a `countdown_ring` per running event in a centred row (time `m:ss` in the
  ring, lacquer red under a minute, the event's pin faint behind it; the name beside it).
  Hidden while a herald or menu is up.
- **Pin:** `pin_gold`/`_jade`/`_crimson`/`_violet` over the event's spot (a BillboardGui on
  an Attachment in `workspace.Terrain`), the event's glyph live in the head and your
  distance under it. Always on top, up to 4000 studs.
- **Edge chip** (an off-screen indicator, user 2026-10-23): when the spot is off screen
  (or within 4 % of an edge), the `EdgeChip` template: the gold house plaque
  ([ribbons](ribbons.md), 44 tall, 36 on the phone; fitted once to the short name plus
  "  ·  9999m" so it never jitters) with the name in cream and the distance in gold on
  one line (Builder Sans Bold 16, 14 on the phone), and the kit's gold `chevron` (26x16,
  22x13.5 on the phone) orbiting it on an ellipse 2 px off the plaque, turned to point at
  the event. The text never rotates.
  - Where: the chip slides along an inset rectangle (`Events/EdgeMath.luau`): the canvas
    less the HUD's bands (top 84, bottom 222 baseline px on desktop: the top-right
    buttons and toast, the vitals stack; 56 and 124 on the phone), the chip's own half
    extents with the pointer, and an 8 px margin, so the whole chip, pointer included,
    stays inside the safe area (Events uses `DeviceSafeInsets`). The point is where a ray
    from the screen centre, toward the event, meets that rectangle. The direction is the
    event's camera-space x and y, so an event behind you and to the right leads to the
    right edge, one straight behind and below to the bottom.
  - Motion: one RenderStepped pass for all chips. The angle eases toward the event
    (rate 10 a second, at most 300° a second, so an event crossing behind you swings the
    chip round the bottom calmly) and the chip eases along the border the short way
    round, never across the screen. No pulsing.
  - Hand-off: when the spot comes on screen (in front, inside 4 % of every edge) the
    chip fades out at the same rate while the pin over the spot shows; it fades back in
    when the spot leaves. It also fades while a menu is open.
  - Several chips: sorted along the border, each one that would overlap the one before
    (boxes plus 10 px) moves on clockwise until clear, round corners too.
  - Measured (sandbox, 2026-10-23, `EdgeMath` with the real camera maths): 5400
    placements per layout (yaw 0-357° by 3, pitch -40..40°, three chips at once and
    single events ahead, behind, above and below): every chip with its pointer at least
    14.7 px (desktop) / 13.6 px (phone) inside the screen sides and 13.2 / 12.4 px clear
    of the HUD bands; no plaques overlapping, at least 10 px apart. Turning the camera
    at 60-240° a second, the chip moves 3-35 px a frame on average, at most 72 (the
    swing round the bottom when an event passes behind you).
- **Looks** (`LOOKS` in the module, by def id then kind): Thousand-Year Ginseng jade 參,
  Beast Surge crimson 獸 (no spot, so no pin or chip), Auspicious Clouds gold 雲, Violet
  Cloud Mist violet 紫, Golden Auspicious Clouds gold 金; anything else gold 祥. A new event
  adds a line there.
- The server's announce toast still carries the flavour line.

## Tribulation (`Events/TribulationView.luau`, wired)
The tribulation had no screen UI before. CombatController forwards the Effect events:
`tribulationStart` (player, center, strikes), `bolt`, `tribulationEnd` (player, survived).
`src/server/Tribulation.luau` now plans the strike times up front (`schedule`, the same
shrinking interval) so the start can say how many strikes there are, and waits for each
planned time instead of chaining waits (no drift).
- **Challenger:** the `decree_card` ("Heaven's Decree", the strike count large in gold,
  "strikes of heavenly lightning", a line on what to do) fades in high on the screen, off
  the character, with one `fx_glint` sweep across its top edge, and holds 2.6 s (the
  bolts start at once). On the phone (180x230) it drops the kicker and footer and sets its
  lines at fixed sizes with a 14 px floor (title 16, count 36, "heavenly strikes" 14, the
  body line 14 in up to three lines), all inside the art's interior. Then the
  strike counter: a `countdown_ring` under the top centre with the strikes left and
  "strikes left" under it (14 px on the phone, just under the ring); each bolt ticks it down with one short pop and an
  `fx_sparkle` flash, gold for the last three. At the end it fades and the ribbon says
  "The heavens relent. You endured." or "The lightning overwhelmed you".
- **Everyone else:** the ribbon for 3.4 s: "The heavens descend on <name>", unless a menu
  is open. It's the ruby house plaque fitted to the message ([ribbons](ribbons.md); 26 px,
  17 on the phone, centred in its slot); the cut `tribulation_ribbon`'s cloud-and-lightning
  caps took 215 of the phone's 460 px and crowded the text.
- No darkening, no looping pulse (the user's taste from the boss bar). Without a strike
  count (an older server), the decree shows 雷 and no counter.

## Rifts (`Events/RiftCard.luau`, ready to wire)
Rifts don't exist yet (roadmap 9, "Secret realms"). The card is a centred window
(registered with `Menus`): `rift_card` with the kicker "SECRET REALM RIFT", the name, the
recommended realm, a cloud divider, "MODIFIERS" and up to four `rift_tag`s (three-part,
cut from the C4 tag), the first-clear bonus in jade, an Enter button (`response_button`
three-part, 入 live in its icon ring) and the kit's close seal.

```lua
RiftCard.show({
	name = "Sunken Bamboo Grotto",
	realm = "Qi Condensation 6",           -- optional
	modifiers = { "Frenzied beasts", ... }, -- up to 4, short
	bonus = "First clear today: double rewards", -- optional
	enter = "Enter the Rift",               -- optional label
	onEnter = function() end,               -- the card closes first
})
RiftCard.close(); RiftCard.isOpen(); RiftCard.preview()
```
The rift system must provide: the rift's name and recommended realm, its rolled
modifiers as short player-facing lines, whether today's first-clear bonus is still
available, and the enter action (a remote).

## Previews
In play, from the client console:
`require(game.Players.LocalPlayer.PlayerScripts.Client.Events.WorldEventView).preview()`
(a herald, a tracker and a pin 120 studs ahead), `...Events.TribulationView).preview()` (a
spectator ribbon, the decree, a counter ticking down six strikes, the end ribbon) and
`...Events.RiftCard).preview()`. None of them touch the server.

## Art
Cuts from `ui-assemble` (`art/ui/codex/cut/`, ids in `art/ui/assets.json`): `event_scroll`
caps and paper strip (`capL`, `midL`, `capR`; its `centre` cut carries a speck and isn't
used), `countdown_ring`, the four pins, `decree_card` (`direction_chip` and its mirror
are no longer used; the edge chip is the gold plaque and the kit's `chevron`),
`tribulation_ribbon` (three-part), `rift_card`, `rift_tag` (three-part), `response_button`
(three-part), `close_seal`, `divider_cloud`, `fx_glint`, `fx_sparkle`, `fx_glow`.
`art/ui/events/mirror.py` mirrors the left chip and the window corner sets (Roblox
can't flip images). Measured holes the layout centres on (share of each image):
scroll paper rows 0.204-0.741; ribbon band 0.226-0.667; ring hole centre (0.496, 0.497);
pin head (0.51, 0.473); chip plate x 0.221-0.853, y 0.26-0.83; decree interior
x 0.102-0.900, y 0.111-0.899; rift interior below 0.19; button icon ring (0.321, 0.543).

## Known gaps
- Untested in play: the herald queue and timings, the pins and chips against real
  events (the chip's slide, fade hand-off to the pin and the HUD insets on a real phone),
  the tribulation flow with real bolts, phone layout on a device.
- The chip insets are fixed numbers measured from the HUD's buttons and stack; the touch
  cluster on the phone's lower right can still meet a chip low on the right edge.
- No tracker tap action yet (it could open a map or point the guide later).
