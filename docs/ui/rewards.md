# Reward banners

Roadmap 3c: players should feel the big gains, without anything blocking play. One
client API, `Rewards.show(spec)` in `src/client/Rewards.luau`, with four tiers on one
ScreenGui (`assets/Rewards.rbxmx`, `StarterGui.Rewards`). The toast (the `Hud`'s
`Toast`) is restyled in the same kit look but stays in `Hud.luau`.

## Tiers

| Tier | Looks like | Used by |
| --- | --- | --- |
| `small` | a number or short line with a white kit glyph, rising 40 px and fading over 1.1 s | ready for floating gains (qi, stones); nothing calls it yet |
| `feed` | a row in the reward feed (right side, above the touch cluster): the kit's leaderboard row, a coin (currency) or rarity tile (items) with the icon, the name in its colour, a count that climbs | stones, loot, insight, manuals, weapons, methods (`Effect`) |
| `banner` | kicker, a three-part ribbon with the title, a tag and a subtitle, top centre; jade, gold (the navy objective banner) or crimson | the region entry banner (`RegionBanner.luau`); notable gains and onboarding objectives later |
| `card` | one card, three jobs; reward tiles, stat deltas, the new unlock, one line of flavour; tap or click to skip | boss victory (`Effect "boss"`), breakthroughs (`BreakthroughView`), quests later |

Card jobs (`spec.kind`):
- `boss`: crimson-and-gold `card_boss`, crimson ribbon on its header strip, `rays_boss`
  turning slowly behind the whole card. Title "Victory", subtitle "<boss> defeated".
- `quest`: gold-and-jade `card_quest`, jade ribbon under the crest slot, the sect
  crest (`emblem_peak` by default, `spec.crest` to change it). Rare and weighty.
- `rank`: a sect rank-up (`SectRank.rankUp`): the quest card with a jade ribbon,
  `rays_milestone`, and the rank crest from `spec.crest` (`{ image, emblem, hole }` or an
  image id); the rank's line goes in `flavour`.
- `milestone`: the quest card with a crimson ribbon, `emblem_lotus` in the crest and
  `rays_milestone` glowing from the crest. Breakthroughs use it today ("Breakthrough" or
  "Major Breakthrough", the stage, health/power/combat qi/passive deltas from the
  stage before, "The <array> array is open" when the stage opens a travel array);
  bloodlines and firsts later.

Rules: one card at a time, queued; a card waits while another window or minigame is
open and opens when it closes. It is a `Menus` window (the HUD steps aside, shift lock
frees the mouse), closes on a click or tap after 1 s, or by itself after 7 s (5 s for a
minor breakthrough). Rewards that arrive within 1.5 s of a boss card (open or queued)
land on it as tiles. The feed hides while a card is open (the card shows the tiles; on a
phone the feed would sit on it). Banners queue (three at most) and are cleared by any
window or card. Motion: cards pop (Menus/Motion), the title ribbon gets one gold glint
sweep, banners fade in and out, feed rows and tiles pop on each gain. No screen
darkening, no looping pulses, no shakes (user taste, 2026-10-23); the only continuous
motion is the rays' slow turn (10 degrees a second) while a card is up.

## API

```lua
Rewards.show({ tier = "small", text = "+12", icon = "qi", at = worldPoint })      -- at: Vector3, or a Vector2 screen point (0-1); default (0.5, 0.62)
Rewards.show({ tier = "feed", key = "stones", amount = 5 })                      -- keys as below
Rewards.show({ tier = "banner", style = "jade", kicker = "OBJECTIVE COMPLETE",
	title = "Sit on your peak", tag = "+30 Spirit Stones", subtitle = nil, hold = 2.6 })
Rewards.show({ tier = "card", kind = "quest", title = "Quest Complete",
	subtitle = "The Herbalist's Errand",
	items = { { key = "stones", amount = 60 }, { key = "contribution", amount = 40 } },
	stats = { { name = "Health", from = 140, to = 165 } },
	unlock = "The Inner Wilds array is open", flavour = "One line on what to do next.",
	crest = nil, life = 7 })
Rewards.preview(tier, kind)  -- sample content: ("card", "boss"|"quest"|"milestone"|"rank"), ("banner", "jade"|"gold"|"crimson"), ("feed"), ("small")
```

Keys (feed rows and card tiles): `stones`, `qi`, `insight`, `contribution` (currency:
coin frame), `manual:<technique>`, `weapon:<id>`, `method:<id>`, or an `Items` id.
Item tiles take the edge of their rarity or grade on the Inventory's ladder
([inventory](inventory.md), `Rarity.luau`): Common/Mortal bronze (`neutral`),
Uncommon silver (`grey`), Rare/Spirit jade, Epic/Earth violet, Legendary/Heaven gold;
manuals neutral. One ladder everywhere (decided at the UI merge, 2026-10-23), so no
blue tier is needed.

Server side: `Effect "reward"` with a spec table goes straight to `Rewards.show`, so a
new system picks its own tier without a new remote. What a real system must send:
the tier, and for a card its `kind`, title, subtitle and whatever it has of items,
stats, unlock and flavour (empty lines hide). Quests and bloodlines don't send it yet.

## Layout

The ScreenGui holds one `Canvas` with the authored `UiScale` (fitted by `UiScale.fit`:
desktop baseline 1920x1080, phone 844x390, one layout for both). Inside it:
- `Feed` (as before: bottom-right anchor at 58 % height, 264 wide, rows 250x30, 4 px
  apart). Row: `Plate.Art` (CapL, Mid with a fill flex, CapR; the art is 164/118 of the
  row so the rims sit on the row's edges), `Badge` (coin or tile) with `Icon`/`Glyph`,
  `NameLabel`, `CountLabel`.
- `Floats.FloatTemplate`.
- `Banner` (620x118 at the top centre, 64 px down): `Kicker`, `Ribbon` (440x56, `Art`
  plus `Title` on the body's centre row), `Tag`, `Subtitle` (hidden on small phones).
- `Card` (62 % x 84 %, aspect 1.57, at most 600x382, 10 px above centre): `Rays`,
  `Art` (its aspect set per job: 1.718 boss, 1.571 quest), with `Crest`, `Ribbon`,
  `Body` (a centred list: `Subtitle`, `List` of `RewardTemplate` tiles 64x82 with 14 px
  gaps, `Stats`, `Unlock`, `Flavour`) and `Hint` under the card.
Per-job positions (ribbon, body, rays) are fractions of the card art measured in the
PNGs, in `KINDS` in `Rewards.luau`. Fonts: Merriweather for titles and the italic
subtitle and flavour, Builder Sans Bold for small text, Fredoka One for counts (the kit's
Cormorant Garamond and Fredoka aren't Roblox fonts).

Rebuild the GUI with `tools/rewards_gui_build.luau` (sandbox only; it also sets the Hud
toast's subtree), then export.

Measured in edit view (1060x784, scale 1) and on an 844x390 phone canvas: card, ribbon,
body, crest and hint centres all on the canvas centre (530.0); crest on the slot's
centre row (263.4 = 263.4); ribbon titles on the body's centre row (311.5, 116.3);
tiles 103/103 px from the list edges with 14/14/14 gaps; toast 20/20 padding, 14/14
gaps, message and studs on the centre line; feed badge, name and count on the row
centre, 30/30 px from the ends. Phone card: 514x328, 21 px from the top, hint inside.

## Toast

`Hud.Toast` is the kit's `Frame/Toast` (Figma node 4:70): a navy plate at 95 %
fading out over the ends, gold rules top and bottom (`art/ui/toast_plate.png`, redrawn
from the kit's numbers by `draw_ui.py toast`, SliceCenter Rect(40, 4, 216, 94),
SliceScale 0.5), a kit `gold_stud` at each end, the message in Builder Sans Bold 16
cream. It grows with the text (up to 380 px wide, wraps to more lines) and fades in and
out (`Motion.fadeIn/fadeOut`); the queue and timing are unchanged.

## Art

Kit cuts in `art/ui/codex/cut/` (sheets B1, B2, A6, C3, C5, light effects; ids in
`art/ui/assets.json`): `card_boss`, `card_quest`, `rays_boss`, `rays_milestone`,
`ribbon_crimson_*`, `ribbon_jade_*`, `objective_banner_*`, `leaderboard_row_*`,
`tile_*`, `gem_*`, `coin_frame`, `glyph_spirit_stone`, `glyph_qi`, `glyph_insight`,
`emblem_peak`, `emblem_lotus`, `fx_glint`, `gold_stud`. The Figma mock is
"Rewards / Cards, feed, toast (mock)" on the kit's Example page (file
`WNgoTL6QGdTEBy693Me8Y8`).

## Known gaps
- A `rank` card shows only the rank crest ring: the card's `Crest` needs an authored
  `Emblem` child to draw `spec.crest.emblem` on the crest's hole.
- `contribution` uses a 功 glyph in the coin; the kit's `contribution_token` could
  replace it.
- `Hud.Banner` and `Hud.Flash` (the old breakthrough title card and flash) are unused
  now; they are outside this pass's Hud subtree and should be removed with the Hud's
  next structural edit.
- Rewards no longer uses the old Pillow art (`victory_*`, `feed_strip`, `feed_accent`,
  `region_wash`, `slot_simple`); some of it is still used elsewhere in the Hud.
