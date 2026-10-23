# Dialogue screen and interaction prompts

The dialogue screen (`StarterGui.Dialogue`, `src/client/Dialogue.luau`) and the world
prompt cards (`StarterGui.Prompts`, `src/client/WorldPrompts.luau`), both in the kit's
style from the house reference
([dialogue_prompt_reference.webp](../reference/ui/dialogue_prompt_reference.webp)).
Built 2026-10-23. Composed from the cut art in Studio (the Figma kit was over its plan
limit that day), by `tools/build_dialogue.luau` and `tools/build_prompts.luau`.

## Dialogue: API
Ready to wire; nothing in the game opens it yet. The elder's onboarding lines
([roadmap](../roadmap.md) section 2) and the NPC masters (section 3d) are its users.
Today the elder's Talk prompt still answers with a toast (`Quests.talk`).

```lua
local choice = Dialogue.open({
	speaker = "Elder Qingyun",   -- nil or "" shows "???"
	portrait = "elder_qingyun",  -- elder_qingyun, herbalist, weapon_rack_keeper, unnamed, unknown, or an rbxassetid
	lines = { "You have the look of someone who has hit a wall.", "Have you completed your root test?" },
	responses = {                -- optional, at most 4
		{ text = "I have completed it.", icon = "quest", highlight = true },
		{ text = "Can you tell me more?", icon = "talk" },
		{ text = "Nevermind.", icon = "leave", cancel = true },
	},
})
```
- `open` yields and returns the chosen response's index, or nil (no responses, closed
  early, or replaced by another `open`). Call it from the client, in its own thread if
  the caller mustn't wait.
- A response is a string (icon `talk`) or a table: `icon` (a `Glyphs` name: talk,
  quest, give, leave, bag, question, exclaim, purse, bow, fight, heart, lock, harvest,
  plant, rush, chest, insight, qi), `highlight` (the recommended one: lit art, focused
  first), `cancel` (what gamepad B picks), `disabled` (dimmed, lock glyph, can't be
  picked).
- `Dialogue.close()`, `Dialogue.isOpen()`. `Dialogue.preview()` plays two sample
  conversations (client console in play:
  `require(game.Players.LocalPlayer.PlayerScripts.Client.Dialogue).preview()`); the
  game never calls it.
- What a real system must provide: the speaker's name, a portrait key (a new NPC needs
  a gray silhouette, never a painted bust, uploaded and added to `PORTRAITS`), the lines,
  and what each response does once `open` returns. Server-driven dialogue will need a
  remote that sends this table and takes back the choice; not built.

## Dialogue: behaviour
- It's a menu (`Menus.register`): opening it closes any other window, hides the gameplay
  HUD and turns world prompts off; it pops open and shrinks away (Motion).
- Lines type out (48 characters a second). A click or tap on the panel, Space, Enter, E
  or gamepad A finishes the typing, then goes to the next line; the gold chevron bobs
  while there's more (or, with no responses, to close).
- After the last line the responses fade in, staggered. Mouse: hover lights one, click
  picks. Keyboard: Up/Down or W/S move the lit one, Enter/Space/E pick, 1-4 pick directly
  (the number shows on the button, keyboards only). Gamepad: d-pad or left stick, A
  picks, B picks the `cancel` response. Touch: tap; only the recommended one is lit.
- While open it holds those keys (ContextActionService, high priority), so Space
  doesn't jump and W/S don't walk.

## Dialogue: layout
Laid out at a baseline inside `Canvas` and fitted by `UiScale` (one `UiScale` UIScale);
`UiScale.isPhone()` picks the layout once and the other is destroyed. Both are centred on
the screen (the centre-of-screen rule for panels the player reads).

| | Desktop (1920x1080) | Phone (844x390) |
|---|---|---|
| Block | 1480 x 292 | 600 x 346 |
| Panel | 1000 x 250, top at 42 | 600 x 200, top at 34 |
| Portrait | 206 square, 22 from the panel's left, top and bottom | 164 square, 18 in |
| Text box | portrait + 14 to 22 from the right; text 24 px, padding 30/26 | portrait + 10 to 18 in; text 18 px, padding 20/18 |
| Name tab | 58 tall at x 30, fitted to the name (Merriweather Bold 24), at most 600 wide | 46 tall at x 22 (19 px), at most 360 |
| Responses | a column of 4 (460 x 56, gap 8) beside the panel, 20 px right, centred on it | a 2 x 2 grid below the panel (296 x 48, gap 8), panel-wide |

Measured in Studio (2026-10-23): the block centre is the screen centre on both; portrait
and text-box insets are equal on every side (22/22/22, 18/18/18); the response column
is 1 px in from the panel's top and bottom (248 in 250); the grid spans the panel's exact
width; response icons sit within 0.5 px of the ring's centre and labels on the plate's
visible middle (0.552 of the button's height, measured in the art).

Text: dialogue lines and responses in Builder Sans (SemiBold 24/18, Bold 20/17), cream
with a near-black stroke; the name in Merriweather Bold, gold.

## Dialogue: art
All cut art, never repainted (ids in `art/ui/assets.json`):
- Panel frame: `ornament_window_corner` mirrored to four corners, with straight rail
  strips cropped from its own arms between them (`art/ui/dialogue/derive.py` makes
  `window_*`). The body is a navy gradient fill behind the frame.
- Portrait frame and text-box frame: `ornament_portrait_corner`, mirrored and railed the
  same way (`pcorner_*`). The portrait backdrop is a navy gradient with a soft blue
  `fx_glow`; the text box has two faint `inkwash_b` clouds along its bottom.
- Name tab: the ruby house plaque ([ribbons](ribbons.md), `Ribbon.fit` style `ruby`):
  pointed ends with a ruby stud, a dark lacquer middle sized to the name with even room
  to each stud (23.5 px on PC, 18 on the phone), the name centred on the plain band. A
  long name grows the tab to 60 % of the panel, then shrinks to 85 %, then truncates.
  (The objective banner's cloud caps it used before crowded the name and ran under it.)
- Responses: `response_button` and `response_button_hi`, three parts each (caps never
  stretch, the middle strip does), white glyphs tinted cream in the ring.
- Chevron: `ornament_chevron`. Portraits: `portrait_*` (gray silhouettes); the "???"
  speaker adds a live cream "?" on the head.
- Every upload went through `tools/alpha_bleed.py` first: the cutter leaves pure green
  under transparent pixels (and a green cast on soft edges), which Roblox's filtering
  drew as green lines along the rails.

## Interaction prompts
`WorldPrompts` keeps its behaviour (one target in focus, keys muted elsewhere, billboard
on the target with a mouse, keyboard or gamepad, the touch Dock otherwise). The card
(`Prompts.Board.List.Card`, 300 x 52 on the billboard) is now:
- `Banner`: the kit's `prompt_banner` with plain ends (40 tall), tucked behind the plate
  from its centre and nudged 2 px down so its interior's middle is the card's (26.3 of 52).
  The ends are `prompt_banner_capL_plain` (the left cap's outer rail and serif, cropped
  at source x 64, before the cap's top-left shine) and `capR_plain` (that crop mirrored),
  11 x 40 each; `Mid` stretches between them. The cut's cloud cap (`prompt_banner_capR`)
  is no longer used: at 40 tall its cloud swallowed the banner's right third and ran into
  the glyph, and the user finds that much ornament tacky.
- `Key`: the round `keyplate` (52). The key letter is live text on its cream tile (the
  gamepad button image when one exists); on touch the tile shows the action's glyph
  instead (a hand when there's none) and the whole card is the button.
- `Icon`: the action's white glyph (20), tinted cream, inside the banner's right end:
  6 px from the body text and 6.4 from the right rail's inner edge, centred on the card
  (keyboard and gamepad; on touch the plate shows it). `Glyphs.forPrompt`
  picks it from the action text's first word (Talk, Harvest/Pick/Gather, Plant/No seeds,
  Grow now, Read, Browse/Trade, Claim, Take, Study, Touch, Travel, "Gather Qi"...), or a
  prompt's `Glyph` attribute.
- `Key.Hold`: for a prompt with a HoldDuration, the `hold_ring` cut round the plate: a
  dim track and a lit copy swept clockwise from the top while held (two clipped halves,
  each a UIGradient with a hard edge, rotated `min(p, 0.5) * 360` and `max(p, 0.5) * 360`).
- `Body`: object line (13 px, top 10) over the action (17 px, top 24), 6 px right of the
  plate and 6 px left of the glyph (200 wide on a 300 card); with no glyph it widens by
  26 to stop 6.4 px short of the rail. Both lines truncate. The two-line block centres at
  26.25 and one line at 26.5, against the interior's 26.3.

Touch Dock: its box still mirrors `Hud.Stack` (aspect 3.75839, max 560 x 149). Its
`List` is 280 wide, cards bottom-up with a 6 px gap; `Lift` (same box) is where a
leaving card fades. Both carry a `Fit` UIScale that WorldPrompts sets to the dock's
height / 149, clamped to 0.85..1, so on a phone the cards are 44 px tall (as before)
and on a full-size stack 52.

## Known gaps
- Nothing opens the dialogue yet; the elder's Talk is still a toast.
- Not play-tested: typing, input binding, gamepad focus, the Menus hand-off, the hold
  ring's sweep under a real hold, and the Dock's Fit on a real phone.
- Gold (masters) and crimson (demons) name tabs, and a crisper large portrait corner,
  wait on Codex sheet A7; the `gold` plaque style can stand in for masters.
- Pressed and disabled response states are tints of the normal art.
- No Figma mock of these screens: the kit's MCP allowance ran out on 2026-10-23.
