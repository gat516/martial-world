# Sect board, quest log, rank and contribution

Ready-to-wire screens for the sect and quests ([roadmap](../roadmap.md) 3, 3b;
[progression](../progression.md), "The sect and its quests"). None of the systems
behind them exist yet: each screen is a GUI template plus a client module with a small
API and a `.preview()`. Nothing calls them in the real flow until the sect system does.
Halls and masters are in [halls and masters](halls-masters.md).

## Where things are
- GUI: `StarterGui.Sect` (`assets/Sect.rbxmx`, mapped in both projects). `Canvas`
  holds every window and `Templates` (hidden): `Notice`, `Torn`, `QuestRow`,
  `Objective`, `RewardChip`, plus the Hall and lineage templates.
- Modules (`src/client/Sect/`): `SectBoard`, `QuestLog`, `SectRank`, shared `Ui`
  (finding the GUI, fitting, Menus, close seals, row helpers) and `Art` (image ids,
  native sizes and measured holes of the pieces swapped at runtime).
- Previews, from the client console in play:
  `require(game.Players.LocalPlayer.PlayerScripts.Client.Sect.SectBoard).preview()`
  (likewise `QuestLog.preview()`, `SectRank.preview()`).

## Principles (roadmap 3b)
- **Contribution is soft.** The board only offers. Nothing counts down, flashes or
  opens by itself. The one allowed pointer per session ("The elder summons disciples
  to the hall") is the existing elder line (`Onboarding`'s `Hud.Play` elder frame),
  sent by the server at most once per session and dismissible; no new widget.
- **One menu at a time.** Every window registers with `Menus` (opening one closes the
  rest, the gameplay HUD steps aside) and closes by its seal.
- The current `Hud.QuestBoardWindow` (onboarding's goals list) stays until the sect
  board is wired; then the board's ReadPrompt opens `SectBoard` instead and the goals
  become notices.

## Layout and scaling
All windows are 720x350, authored at the **phone baseline** (844x390) and fitted by
`UiScale.fit(canvas, { base = PHONE, max = 1.5 })`: about 1.0 on a landscape phone,
1.5 on a 1080p desktop (a 1080x525 window). The phone layout is the native one, so its
text sizes are what a phone shows (body 12-14, titles 16-20, never below 11).
Window anatomy (shared by every window here):
- `Body`: navy lacquer fill (#192129) inset 8 px, with the `inkwash_b` cloud at 86 %
  transparency in its lower right.
- `Rim`: `art/ui/sect/window_frame.png`, ScaleType Slice, SliceCenter
  Rect(476, 296, 484, 304), SliceScale 0.2 (corners about 95x59). It is the cut
  `window_corner_small` cropped before its end knots and mirrored into four corners by
  `tools/ui_compose_sect.py` (crop, mirror and paste only; no repainting).
- `Title`: the five-part `title_crest` (300x46, live Merriweather 18 on the plaque's
  body, rows 86-242 of 250); the board uses the three-part `board_header` (300x56).
- `Close`: `close_seal` (48x44) on the top-right corner with a live "×".
- `Content`: inset 28 left and right, 42 top (under the title), 22 bottom.

## Sect board (`SectBoard`)
`SectBoard.open(board)`, `SectBoard.update(tasks)`, `SectBoard.close()`.
```
board = { tasks = { Task }, status = SectRank.State?,
          onTake = (id) -> (), onClaim = (id) -> (), onSelect = (task) -> () }
Task  = { id, kind = "daily" | "weekly" | "chapter" | "torn", title, body,
          glyph = "fight" | "harvest" | "plant" | "give" | "quest" | "chest" | nil,
          reward = number?  -- contribution
          progress = number?, goal = number?,
          state = "offered" | "taken" | "done" | "claimed" }
```
- **Status row:** the rank crest (34 px), the rank name, and the contribution counter
  (token, the total counting up, "120 / 400 this week" under it for the weekly cap).
- **Notices:** pinned `notice_paper` cards, 152x178, four across (12 px gaps, 7 px
  either side of the grid), scrolling down. Each: the kind badge top left (`daily_seal`
  with a live 日 or `weekly_seal` with 周 in its empty face; chapter tasks show the
  `quest_scroll`), the playstyle glyph top right in ink (the A5 white glyphs tinted),
  the title (ink, 14), the body (12, two or three lines), and a footer: the
  contribution token and reward, then by state:
  - *offered:* a gold `tag_gold` "Take" (tap the notice or the tag: `onTake`);
  - *taken:* "2 / 5" progress;
  - *done:* a jade `tag_jade` "Claim" (`onClaim`);
  - *claimed:* the paper dims and a red `seal_round` chop with 完 stamps onto it
    (it lands with a short scale-in when the state changes while open).
- **Torn notice** (`kind = "torn"`): the defaced `notice_torn` with faded, gapped ink
  text and nothing else: no seal, reward or state. It is the demon chain's first clue
  (roadmap 9, "The demon secret"); nothing on it says "demon". A tap goes to `onSelect`
  (the elder's hint trail).
- Order is the server's: the current wall first, then the rest (progression: three
  dailies offered, one weekly, chapter chains).

**The real system provides:** the task list per player (dailies reset by day like the
daily login, weeklies by week), take/claim remotes, the contribution total and the
week's share against the cap, and when to pin the torn notice.

## Quest log (`QuestLog`)
`QuestLog.open(log)`, `QuestLog.update(quests)`, `QuestLog.close()`.
```
log   = { quests = { Quest }, selected = id?, tracked = id?, onTrack = (id?) -> () }
Quest = { id, kind = "chapter" | "daily" | "weekly" | "spirit" | "other", name,
          giver?, place?, description, status?,
          objectives = { { text, progress?, goal?, done? } },
          rewards = { { kind = "contribution" | "stones" | "qi", amount } } }
```
- **List** (left, 256 wide): `catalog_tab` three-part rows, 52 tall (48 px on a phone,
  a full thumb target), the selected one on `catalog_tab_selected`. Kind badge (seal
  with its character, the quest scroll for chapters, the gold quest glyph otherwise),
  the name, and a second line (`status`, else the first open objective with its count).
- **Detail** (right): the badge, the title (Merriweather 19), "From <giver> · <place>",
  a `divider_diamond`, then a scrolling description and objectives (checkmark when
  done, a gold ◇ otherwise, "1 / 3" counts on the right), and a footer with reward chips
  (token, jade spirit-stone and qi glyphs) and the **Track** button
  (`response_button_hi` three-part with the quest glyph in its ring). Track toggles
  "Tracking" (jade) and calls `onTrack`; the HUD objective line follows it.

**The real system provides:** the player's quests in display order (built on
`Quests.Quest`, `data.quests`), the tracked id and a remote for tracking.

## Rank and contribution (`SectRank`)
- `SectRank.set({ rank = "Outer" | "Inner" | "Core", contribution, week?, weekCap? })`
  paints the board's status row; the counter counts up from the last shown value.
- `SectRank.paintCrest(imageLabel, rank)` paints any `RankCrest` (an ImageLabel with an
  `Emblem` child): `crest_outer`, `crest_inner` or `crest_core`, with the sect's emblem
  (`emblem_peak`, `SectRank.EMBLEM`) centred on that crest's measured hole
  (`Art.Hole`), at 72 % of it.
- **Rank-up uses the shared Rewards card** (roadmap 3c: one card, three jobs); there is
  no card of our own. `SectRank.rankUp(rank, line?)` calls
  `Rewards.show({ tier = "card", kind = "rank", title = "Inner Disciple",
  subtitle = "The sect raises you in rank", flavour = line,
  crest = { image, emblem, hole } })`, where `crest` carries the rank crest's image id,
  the emblem's id and the hole (centre and size as fractions of the crest image). The
  card shows the crest image only until its `Crest` gets an `Emblem` child
  ([reward banners](rewards.md)).

**The real system provides:** the task list per player (dailies reset by day like the
daily login, weeklies by week), take/claim remotes, the contribution total and the
week's share against the cap, and when to pin the torn notice.

## Quest log (`QuestLog`)
`QuestLog.open(log)`, `QuestLog.update(quests)`, `QuestLog.close()`.
```
log   = { quests = { Quest }, selected = id?, tracked = id?, onTrack = (id?) -> () }
Quest = { id, kind = "chapter" | "daily" | "weekly" | "spirit" | "other", name,
          giver?, place?, description, status?,
          objectives = { { text, progress?, goal?, done? } },
          rewards = { { kind = "contribution" | "stones" | "qi", amount } } }
```
- **List** (left, 256 wide): `catalog_tab` three-part rows, 52 tall (48 px on a phone,
  a full thumb target), the selected one on `catalog_tab_selected`. Kind badge (seal
  with its character, the quest scroll for chapters, the gold quest glyph otherwise),
  the name, and a second line (`status`, else the first open objective with its count).
- **Detail** (right): the badge, the title (Merriweather 19), "From <giver> · <place>",
  a `divider_diamond`, then a scrolling description and objectives (checkmark when
  done, a gold ◇ otherwise, "1 / 3" counts on the right), and a footer with reward chips
  (token, jade spirit-stone and qi glyphs) and the **Track** button
  (`response_button_hi` three-part with the quest glyph in its ring). Track toggles
  "Tracking" (jade) and calls `onTrack`; the HUD objective line follows it.

**The real system provides:** the player's quests in display order (built on
`Quests.Quest`, `data.quests`), the tracked id and a remote for tracking.

## Rank and contribution (`SectRank`)
- `SectRank.set({ rank = "Outer" | "Inner" | "Core", contribution, week?, weekCap? })`
  paints the board's status row; the counter counts up from the last shown value.
- `SectRank.paintCrest(imageLabel, rank)` paints any `RankCrest` (an ImageLabel with an
  `Emblem` child): `crest_outer`, `crest_inner` or `crest_core`, with the sect's emblem
  (`emblem_peak`, `SectRank.EMBLEM`) centred on that crest's measured hole
  (`Art.Hole`), at 72 % of it.
- **Rank-up uses the shared Rewards card** (roadmap 3c: one card, three jobs), being
  built on branch `ui-rewards`; there is no card of our own. `SectRank.rankUp(rank,
  line?)` calls
  `Rewards.show({ tier = "card", kind = "rank", title = "Inner Disciple",
  subtitle = "The sect raises you in rank", line = line,
  crest = { image, emblem, hole } })`, where `crest` carries the rank crest's image id,
  the emblem's id and the hole (centre and size as fractions of the crest image) so the
  card can draw the crest in its crest slot. Until `Rewards.show` exists it only warns.
  The Rewards branch should accept `kind = "rank"` and the `crest` field (or tell us
  its shape and we adapt `rankUp`).

**The real system provides:** rank and contribution in `PlayerData`, promotions (realm
plus contribution), and the rank-up event that calls `SectRank.rankUp`.

## Art
Cuts copied from `ui-assemble` (`art/ui/codex/cut/`, ids in `art/ui/assets.json`, the
same ids in `Sect/Art.luau`): B3 `board_header` (three-part), `notice_paper`,
`notice_torn`, `crest_outer`/`inner`/`core`, `contribution_token`, `quest_scroll`,
`daily_seal`, `weekly_seal`; A3 `title_crest` (five-part), `close_seal`,
`window_corner_small` (composed into `window_frame.png`); A2 `response_button_hi`
(three-part); B1 `objective_banner` (three-part); C1 `tag_gold`, `tag_jade`; C2
`catalog_tab`, `catalog_tab_selected` (three-part); A1 `seal_round`, `divider_diamond`,
`inkwash_b`; A5/A6 glyphs (`fight`, `harvest`, `plant`, `give`, `quest`, `chest`,
`spirit_stone`, `qi`, `bow`), `checkmark`. Text is always live. A wooden board backing
is requested as Codex sheet B3b.

**No Figma mock:** the kit's Starter plan was out of calls when these were built
(2026-10-23), so none of these screens has a Figma frame; they were composed directly
in Studio from the cuts and reviewed by screenshot.

## Checked (2026-10-23, numbers at phone scale 1.0, 844x390)
Every window's centre is the screen's (0 px); titles 0 px off the window centre, labels
0.5 px; title labels within 0.7 px of the plaque bodies' centres; content padding
28/28. Notice grid 7/7 px either side, gaps 12/12/12; notice text padding 12/12.
Status row: crest, name and counter centres within 0 px. Quest row text block 0.3 px
off the plate body's centre, icon 0.2 px; Track glyph 0.4 px off the ring's hole, label
0.3 px off the body's centre line. Rank emblem on the crest hole: 0 px.
