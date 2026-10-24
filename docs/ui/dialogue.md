# Dialogue screen and interaction prompts

The dialogue screen (`StarterGui.Dialogue`, `src/client/Dialogue.luau`) and the world
prompt cards (`StarterGui.Prompts`, `src/client/WorldPrompts.luau`), both in the kit's
style from the house reference
([dialogue_prompt_reference.webp](../reference/ui/dialogue_prompt_reference.webp)).
Built 2026-10-23. Composed from the cut art in Studio (the Figma kit was over its plan
limit that day), by `tools/build_dialogue.luau` and `tools/build_prompts.luau`.

## Dialogue: API
Its first user is Elder Qingyun's Talk prompt (wired 2026-10-23, see
[onboarding](../systems/onboarding.md) "Talking to the elder"); the NPC masters
([roadmap section 3d](../roadmap/relationships.md)) come next. The server sends the
conversation in `QuestState` `{ talk = { lines, reply, board } }` and
`Onboarding.luau` opens it; the choice stays on the client (its responses only close
the screen or open the quest board), so no C->S remote was needed.

```lua
local choice = Dialogue.open({
	speaker = "Elder Qingyun",   -- nil or "" shows "???"
	portrait = "elder_qingyun",  -- elder_qingyun, herbalist, weapon_rack_keeper, unnamed, unknown, or an rbxassetid
	lines = { "You have the look of someone who has hit a wall.", "Have you completed your root test?" },
	near = elder,                -- optional: walking more than `range` studs (default 14) away closes it
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
  and what each response does once `open` returns. A response the server must act on
  (accept a quest, give an item) will need a C->S remote that takes back the choice;
  not built.

## Dialogue: behaviour
- It's a menu (`Menus.register`): opening it closes any other window, hides the gameplay
  HUD and turns world prompts off; it pops open and shrinks away (Motion).
- Lines type out (48 characters a second). A click or tap on the panel, Space, Enter, E
  or gamepad A finishes the typing, then goes to the next line; the gold chevron bobs
  while there's more (or, with no responses, to close).
- After the last line the responses fade in, staggered. Mouse: hover lights one, click
  picks. Keyboard: Up/Down move the lit one, Enter/Space/E pick, 1-4 pick directly
  (the number shows on the button, keyboards only). Gamepad: d-pad, A picks, B picks
  the `cancel` response. Touch: tap; only the recommended one is lit.
- While open it holds those keys (ContextActionService, high priority), so Space
  doesn't jump. WASD and the left stick stay free so the player can walk off: with
  `near`, going past `range` studs ends the conversation (`open` returns nil). The
  elder's range is his TalkPrompt's reach + 4 (user, 2026-10-24).
- On a touch phone (the phone layout on a touch screen) Roblox's touch controls
  (thumbstick and jump) are hidden while it's open (`GuiService.TouchControlsEnabled`),
  so the bar and column can reach into the bottom-left (user, 2026-10-24: "take the
  joystick away if dialogue pops up so we can take up more screen"). `finish` gives
  them back, and every way out runs it: a response, the last tap, walking away, another
  menu opening, `Dialogue.close()`, and dying or respawning (`CharacterRemoving`,
  `Humanoid.Died`). With the stick gone a phone player leaves by a response; if every
  response is disabled, a tap on the bar ends it. Tablets get the desktop layout, which
  already clears the stick, so they keep it and can still walk away.

## Dialogue: layout
A bar centred along the bottom of the screen with the responses in a column to its
right, both with the same top and bottom, so they read as one piece (user, 2026-10-23,
after the phone playtest: "dialogues too small... more in the middle... the choices
shouldn't be way taller than the dialogue"). It started from the user's mockup
([dialogue_bar_figma.png](../reference/ui/dialogue_bar_figma.png): "a bar on the bottom
screen like in figma") and replaced a panel in the screen's centre. The gameplay HUD
is hidden while it's open (Menus), so the bottom is free. Laid out at a baseline
inside `Canvas` and fitted by `UiScale` (one `UiScale` UIScale); `UiScale.isPhone()`
picks the layout once and the other is destroyed, and the canvas is fitted at that
layout's baseline; the phone layout is capped at 1x, since a PC window under 600 px tall
gets it too and it filled half the screen there at 1.3x (2026-10-24). The layout root is the bar plus
the name tab, anchored at its bottom centre (AnchorPoint 0.5,1); `Responses` hangs
off its right edge.

| | Desktop (1920x1080) | Phone (844x390) |
|---|---|---|
| Bar | 1000 x 196, centred, 24 above the bottom | 486 x 172, 8 above the safe bottom; centred while lines show, 163 left while the responses show |
| Window corners | 173 x 91 (rails 18) | 100 x 53 (rails 10) |
| Portrait | 156 square, 20 in, centred | 136 square, 18 in |
| Text box | portrait + 14 to 20 from the right (790 x 156); text 24, line height 1.08, padding 26/22, 24 kept for the chevron | portrait + 10 to 18 in (304 x 136); text 22, padding 16/12, 20 kept for the chevron |
| Name tab | 58 tall at x 30, its bottom 16 px over the top rail, fitted to the name (Merriweather Bold 24), at most 60 % of the bar | 40 tall at x 16 (19 px) |
| Responses | a column 12 px right of the bar, 420 x 196: four 46-tall buttons, 4 apart, centred on the bar's height | 8 px right, 318 x 172: four 40-tall buttons |

Phone slide: there's no room for a centred bar and the column beside it (812 of 844
wide with 16 margins: the column grew 18 into the old 24 margins and the gap, for
the response text, and the hidden stick frees the bottom-left), so the phone layout
is authored as it looks with the responses up (the pair centred, the root at x -163,
so the lint checks the column on screen) and its `ChoiceShift` attribute (-163) says
how far that sits from the centred bar.
`Dialogue.open` puts the bar centred (home minus the shift); `showResponses` slides it
back to home over 0.2 s as the column fades in. Desktop has room (the column ends 28
px from the edge), so its shift is 0.

Footprint: on PC the bar and tab take the bottom 24 % of the screen; on a phone the
unit covers the bottom 204 of 390 rows (52 %, stopping at row 186, under the middle)
and 812 of 844 columns with the responses up (796 before the stick went), and Roblox's
thumbstick and jump no longer sit over the bar's left end.

Pages: a line too long for the text box is split at word breaks into pages (each a
click or tap), measured with `TextService:GetTextBoundsAsync` against the box's width
in layout units (Line has a fixed authored height, so width = on-screen width x
authored height / on-screen height) and the rows that fit (4 on both layouts).

Response labels stay on their plate: the label runs from past the icon ring to where
the right cap starts (phone 61 to 55 from the edge, PC 70 to 63). The cap's art is
plain only for its first ~10 % (the lit chevron starts there, the clouds at 30-35 % in
the text's rows), so text must never run into it; the old label ran 20 % in and
"What should I aim for next?" touched the clouds on a phone (2026-10-24). On keyboards
the number key sits on the cap's plain edge and the label stops 4 px short of it.
Too wide a label shrinks from 20 px to its `MinTextSize` attribute (18), then
truncates with an ellipsis (`fitLabel`). "What should I aim for next?" (215 px at 20,
195 at 18) fits at 20 on PC and 18 in the phone's 202 px label.

Phone choice (2026-10-23): `UiScale.isPhone()` used to need a touch screen. The Studio
device emulator reports a mouse and keyboard, so it got the desktop layout squeezed to
the 0.4 clamp: 9.6 px text in a box and column covering about 55 % of the screen,
the "tiny text, takes up everything" of the first phone playtest. It now goes by size
alone (short side under 600 px, the rule `ui_lint` already used), which also changes
the other `UiScale` screens (CultivationGui, DeathScreen, Herbarium, Events) in a small
PC window.

Text: dialogue lines and responses in Builder Sans (SemiBold 24/22, Bold 20 down to 18),
cream with a near-black stroke; the name in Merriweather Bold, gold.

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
- Cloud flourish (`NameTab.Flourish`): the kit's `ornament_single_cloud` as a margined
  display-sized copy (`sized/ornament_single_cloud_h80.png`, 4 px clear on every side),
  a child of the tab anchored to its right edge, so it follows the fitted width and never
  touches the name: the mockup's cloud after the tab.
- Responses: `response_button` and `response_button_hi`, three parts each (caps never
  stretch, the middle strip does), white glyphs tinted cream in the ring. The red
  ribbon under the right cap's tip is painted in the generated art (not keying bleed);
  the user kept it for now (2026-10-23).
- Chevron: `ornament_chevron`. Portraits: `portrait_*` (gray silhouettes); the "???"
  speaker adds a live cream "?" on the head.
- Every upload went through `tools/alpha_bleed.py` first: the cutter leaves pure green
  under transparent pixels (and a green cast on soft edges), which Roblox's filtering
  drew as green lines along the rails.

## Interaction prompts
`WorldPrompts` keeps its behaviour (one target in focus, keys muted elsewhere, billboard
on the target with a mouse, keyboard or gamepad, the touch Dock otherwise). The card
(`Prompts.Board.List.Card`, 300 x 52 on the billboard) is now a quiet one (user,
2026-10-24: the kit's medallion plate and bracket-ended banner read "tacky"; "make it
nice, just not tacky"):
- `Banner`: a plain dark band (#0c0f14 at 22 % transparency, 36 tall) from the key's
  centre to the card's right, its `Fade` UIGradient clearing it out by the right end; a
  1 px gold `Rule` (#d6ac5c, 35 %) along its bottom from the key's edge, fading the same
  way. No caps, border or cloud ends.
- `Key`: a 38 px round dark tile (#10141b, UICorner 0.5) with a 1.5 px gold `Edge`
  UIStroke, centred 26 px in. The key letter is live cream text on it (the gamepad
  button image when one exists); on touch it shows the action's glyph instead (a hand
  when there's none, `Glyphs.forPrompt` from the action's first word or a `Glyph`
  attribute) and the whole card is the button.
- `Icon`: kept in the template but always hidden; the action glyph at the band's end
  went with the old look.
- `Key.Hold`: for a prompt with a HoldDuration, the `hold_ring` cut round the key (1.3x):
  a dim track and a lit copy swept clockwise from the top while held (two clipped
  halves, each a UIGradient with a hard edge, rotated `min(p, 0.5) * 360` and
  `max(p, 0.5) * 360`).
- `Body`: gold object line (12 px, top 10) over the cream action (17 px, top 24), soft
  strokes, from 54 px to 16 px short of the right end. Both lines truncate.
Not checked in Studio yet: the band's fade over bright ground and the ring's fit round
the smaller key.

Touch Dock: its box still mirrors `Hud.Stack` (aspect 3.75839, max 560 x 149). Its
`List` is 280 wide, cards bottom-up with a 6 px gap; `Lift` (same box) is where a
leaving card fades. Both carry a `Fit` UIScale that WorldPrompts sets to the dock's
height / 149, clamped to 0.85..1, so on a phone the cards are 44 px tall (as before)
and on a full-size stack 52.

## Known gaps
- On a real iPhone 13 the 844-wide phone layout is fitted to the 750 x 369 safe area at
  0.889: lines 19.6 px, responses 16-17.8 px, buttons 36 px tall, under the 20 / 18 /
  44 targets. A 667 x 375 phone fits at 0.79 (lines 17.4 px). A sideways-stretching phone
  layout would fix it; the centred bar with the column beside it needs the full width.
- The red ribbon on the response buttons' right caps is in the art; a Codex
  regeneration without it is the fix if the user wants it gone.
- The export in e056f64 shipped the ScreenGui with `Enabled=false` (a review-stage
  leftover). The fix dropped the property (true is the default), and Rojo doesn't sync
  a property the file omits, so places synced in between kept it off: Talk hid the HUD
  and nothing showed (2026-10-24). The file now states `Enabled` true, and `init`
  re-enables a disabled copy with a warning (and warns about duplicate copies).
- Not play-tested: hiding the touch controls on a real phone (and getting them back
  after each way out), the elder's conversations, typing, input binding, gamepad focus, the Menus hand-off, the hold
  ring's sweep under a real hold, and the Dock's Fit on a real phone.
- Gold (masters) and crimson (demons) name tabs, and a crisper large portrait corner,
  wait on Codex sheet A7; the `gold` plaque style can stand in for masters.
- Pressed and disabled response states are tints of the normal art.
- The keyboard number key sits 4-11 px into the right cap on the phone layout (a PC
  window under 600 px tall) and -5-13 px on PC, over where the lit cap draws its
  chevron; not changed in the 2026-10-24 label fix.
- No Figma composition of the bar: built from the user's mockup and the cut art.
  `tools/build_dialogue.luau` is stale (see its header); the template was re-laid out
  from the export by hand. The
  mockup's ink cloud over the portrait's lower left (the kit's `portrait_clouds`) isn't
  cut yet.
- The response glyphs touch their image edge by 2 source px (0.1 screen px); the Icon
  carries `LintIgnore = edge-margin` since Glyphs swaps in any of the 18 shared glyphs.
