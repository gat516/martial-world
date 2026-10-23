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
| Chips | centre, y 0.42, full width minus 24 per side, 59 tall | y 0.5, minus 12, 46 tall | edge chips |
| Decree | y 96, 280x359 | y 68, 150x192 | Heaven's Decree card |
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
- **Edge chip:** when the spot is off screen (or within 4 % of an edge), a
  `direction_chip` at the left or right edge pointing toward it (left uses the mirrored
  copy), the short name and distance on its plate; several stack downward.
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
  bolts start at once). On the phone it keeps only the title and the count. Then the
  strike counter: a `countdown_ring` under the top centre with the strikes left and
  "strikes left" under it; each bolt ticks it down with one short pop and an
  `fx_sparkle` flash, gold for the last three. At the end it fades and the ribbon says
  "The heavens relent. You endured." or "The lightning overwhelmed you".
- **Everyone else:** the `tribulation_ribbon` (three-part) for 3.4 s: "The heavens descend
  on <name>", unless a menu is open.
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
used), `countdown_ring`, the four pins, `direction_chip`, `decree_card`,
`tribulation_ribbon` (three-part), `rift_card`, `rift_tag` (three-part), `response_button`
(three-part), `close_seal`, `divider_cloud`, `fx_glint`, `fx_sparkle`, `fx_glow`.
`art/ui/events/mirror.py` mirrors the left chip and the window corner sets (Roblox
can't flip images). Measured holes the layout centres on (share of each image):
scroll paper rows 0.204-0.741; ribbon band 0.226-0.667; ring hole centre (0.496, 0.497);
pin head (0.51, 0.473); chip plate x 0.221-0.853, y 0.26-0.83; decree interior
x 0.102-0.900, y 0.111-0.899; rift interior below 0.19; button icon ring (0.321, 0.543).
- **Cutter follow-up (ui-assemble):** `rift_tag` was cut three-part by adding it to
  `SLICE3` in `tools/ui_assemble.py` on a scratch copy; the same one-word change belongs
  in the cutter on `ui-assemble` so a re-cut keeps `ornament_rift_tag_capL/_mid/_capR`.

## Known gaps
- Untested in play: the herald queue and timings, the pins and chips against real
  events, the tribulation flow with real bolts, phone layout on a device.
- No tracker tap action yet (it could open a map or point the guide later).
