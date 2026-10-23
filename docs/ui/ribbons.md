# Title ribbons and name plaques

Every three-part title (cap, plain middle, cap) fits its text through one client module,
`src/client/Ribbon.luau`. Built 2026-10-23 after the user's playtest: the boss and
milestone card titles, the Herbarium title and the dialogue name tab ran their text
under big gold cloud caps, and the caps crowded the words.

## Look
The house plaque, from the user's taste reference
([hud_vitals_reference.webp](../reference/ui/hud_vitals_reference.webp), the "Player
Name" and realm plaques): pointed, bevelled ends, a dark lacquer middle with depth, and a
diamond stud set into each end. No heavy cloud caps (the user finds them tacky).

| Style | Studs | Caps | Used by |
| --- | --- | --- | --- |
| `ruby` | ruby | stud and point only (62 x 96) | dialogue name tab, tribulation ribbon |
| `ruby_curl` | ruby | plus a small scroll curl and line (123 x 96) | boss card title |
| `gold` | gold | stud and point only (70 x 112) | lineage epithet (card and ceremony) |
| `gold_curl` | gold | plus curl and line (154 x 112) | quest, rank and milestone card titles, Herbarium title |

Art: `art/ui/plaque/` (`derive.py`), crops of the existing house plaques
`art/ui/name_plaque.png` (ruby) and `art/ui/realm_plaque.png` (gold), never repainted:
each cap is the plaque's own end, the middle a 32 px strip of its plain band, then
`tools/alpha_bleed.py`. Ids in `art/ui/assets.json` (`plaque/...`). The plain band (inside
the inner rails) is rows 23-72 of 96 (ruby) and 23-88 of 112 (gold): both centre on 0.5
within a quarter pixel, so the text sits at half height.

These plaques were drawn by script long ago; a Codex regeneration at higher resolution
(the same shapes) would sharpen them at 50-60 px tall. Not urgent: they read cleanly at
real size.

## Fitting
`Ribbon.fit(holder, text, opts)`: the holder is a Frame with `Art` (or the caps directly
on it) holding `CapL`, `Mid`, `CapR`, and a TextLabel (`opts.label`, default `Title`).
- The middle is the text's width (`GetTextBoundsAsync`, cached) plus even padding
  (0.4 x the height each side, whole pixels), at least `minMid` (default 1.6 x height).
- The caps keep their true aspect (height x ratio, rounded to whole pixels); the holder
  becomes cap + middle + cap wide and keeps its AnchorPoint and Position.
- The text is centred on the middle's plain band, `TextScaled` off at `textSize`.
- Too long: the ribbon grows to `maxWidth`, then the text shrinks to `minTextSize`
  (default 85 % of `textSize`), then it truncates with an ellipsis.
- Sizes are in the holder's own units (baseline pixels): pass `height` when the caller
  knows it; otherwise the absolute height divided by every UIScale above, and it refits
  if that height changes.

Per screen:

| Ribbon | Height | Text | Least middle | Max width |
| --- | --- | --- | --- | --- |
| Dialogue name tab (`Dialogue.luau`) | 58 / 46 phone | Merriweather Bold 24 / 19 | 1.6 x h | 60 % of the panel |
| Reward card title (`Rewards.luau`) | 0.17 (boss) / 0.15 of the card art | 0.47 x height (28 on PC) | 36 % of the card | 84 % of the card |
| Reward banner (`Rewards.luau`) | 56 | 24 | 1.6 x h | 600 (keeps its own cloud ribbons) |
| Herbarium title (`Herbarium.luau`) | 50 | 22 | 1.6 x h | 60 % of the window |
| Tribulation ribbon (`Events/TribulationView.luau`) | 96 / 62 phone | 26 / 17 | 1.6 x h | the slot (720 / 460) |
| Lineage epithet (`Sect/Lineage.luau`) | 26 card, 28 ceremony | Builder Sans Bold 13, cream on near-black stroke | 1.6 x h | 244 card / 300 ceremony |

## Measured (2026-10-23, sandbox Edit view)
Desktop at 1616x784 scale 1, phone layouts and an 844x390 canvas for scale-sized
screens; short, typical and long texts. On every one: text-to-cap padding equal within
1 px (sub-pixel snapping), seams 0 px, text centre on the band centre (dy 0), caps at
their source aspect within half a pixel, holder centred in its slot or card (dx 0).
- Dialogue: "Elder Qingyun" 263 wide on PC (23.5 px each side), 211 on phone (18 px);
  a 60-character title shrinks to 20 / 16 px and truncates at 600 / 360.
- Boss card: "Victory" 368 wide on PC, 316 on phone, 116 / 99 px in from the card's
  sides; long titles stop at 84 % of the card (48 / 41 px in).
- Milestone card: "Breakthrough: Qi Condensation" 492 wide at 22 px on PC, 431 at 19 px
  on phone.
- Herbarium: "Herbarium" 279 wide, centred on the window (dx 0) at 1000 and 611 wide.
- Tribulation ribbon: "The heavens descend on Wei Lan" 552 / 364 wide at 26 / 17 px.
- Lineage: "Third Disciple of the Turtle Saint" 223 / 229 wide at 13 px.

## Known gaps
- The window title crests on the Herbalist, seed picker, build catalog (in `Hud`) and
  the Sect windows still use the A3 `title_crest` (one image, text centred inside):
  their titles are short and fit, but they don't match this plaque yet.
- The world-event herald scroll keeps its scroll art; its text sits inside the paper.
- Not play-tested: the first fit of a new text waits one `GetTextBoundsAsync` call.
