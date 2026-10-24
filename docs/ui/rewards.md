# Reward banners

Roadmap 3c: players should feel the big gains, without anything blocking play. One
client API, `Rewards.show(spec)` in `src/client/Rewards.luau`, with four tiers on one
ScreenGui (`assets/Rewards.rbxmx`, `StarterGui.Rewards`). The toast (the `Hud`'s
`Toast`) is restyled in the same kit look but stays in `Hud.luau`.

## Tiers

| Tier | Looks like | Used by |
| --- | --- | --- |
| `small` | a number or short line with a white kit glyph, rising 40 px and fading over 1.1 s | floating gains: the Haul's line, the "+ Foundation" earn pop (server `Foundation`, jade text, no icon) |
| `feed` | a row in the reward feed (right side, above the touch cluster): the toast's plaque, plain; the icon on a seal disc in its rarity or currency colour, the name, a count that climbs | stones, loot, manuals, weapons, methods (`Effect`) |
| `banner` | kicker, a three-part ribbon with the title, a tag and a subtitle, top centre; jade, gold (the navy objective banner) or crimson | the region entry banner (`RegionBanner.luau`); notable gains and onboarding objectives later |
| `card` | one card, three jobs; reward tiles, stat deltas, the new unlock, one line of flavour; tap or click to skip | boss victory (`Effect "boss"`), breakthroughs (`BreakthroughView`), quests later |

Card jobs (`spec.kind`):
- `boss`: crimson-and-gold `card_boss`, the ruby title plaque (`ruby_curl`,
  [ribbons](ribbons.md)) on its header strip, `rays_boss`
  turning slowly behind the whole card. Title "Victory", subtitle "<boss> defeated".
- `quest`: gold-and-jade `card_quest`, the gold title plaque (`gold_curl`) under the crest slot, the sect
  crest (`emblem_peak` by default, `spec.crest` to change it). Rare and weighty.
- `rank`: a sect rank-up (`SectRank.rankUp`): the quest card with the gold plaque,
  `rays_milestone`, and the rank crest from `spec.crest` (`{ image, emblem, size, hole }`
  or an image id); the emblem is drawn in the crest's `Emblem` child, a square 72 % of the
  hole's smaller side, centred on the hole as `SectRank.paintCrest` does. The rank's line
  goes in `flavour`.
- `milestone`: the quest card with the gold plaque, `emblem_lotus` in the crest and
  `rays_milestone` glowing from the crest. Breakthroughs use it today ("Breakthrough" or
  "Major Breakthrough", the subtitle "<stage>  ·  Foundation <percent>%" with what
  the stage left earned (the percent only, which can pass 100%; [cultivation](../systems/cultivation.md#foundation-grade); only the stage leaving QC1-3, which have no foundation),
  health/power/combat qi/passive deltas from the stage before (the curve's, without
  the foundation bonus), "The <array> array is open" when the stage opens a travel array);
  bloodlines and firsts later.
- `seclusion`: the milestone card (lotus crest, `rays_milestone`) for seclusion's result
  ("Seclusion Ends", or "First Seclusion" for the onboarding one): the time spent as the
  subtitle, the stone, find, seed and garden tiles, "Cultivation from -> to", and
  `spec.streak = { days, text }`: the Cultivation GUI's `Templates.SeclusionStreak` (seven
  kit gems as day pips and a jade line, painted by `SeclusionView.paintStreak`) cloned
  into the body in Unlock's place ([cultivation UI](cultivation.md#seclusion)).

Rules: one card at a time, queued; a card waits while another window or minigame is
open and opens when it closes. It is a `Menus` window (the HUD steps aside, shift lock
frees the mouse), closes on a click or tap after 1 s, or by itself after 7 s (5 s for a
minor breakthrough). Rewards that arrive within 1.5 s of a boss card (open or queued)
land on it as tiles. The feed never draws over an open window: while one covers its
column (the reward card, or the Inventory on a phone) it hides and its rows wait, then
show for their full time when the window closes; on PC a centred window leaves it up. Banners queue (three at most) and are cleared by any
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
Rewards.preview(tier, kind)  -- sample content: ("card", "boss"|"quest"|"milestone"|"rank"|"seclusion"), ("banner", "jade"|"gold"|"crimson"), ("feed"), ("small")
```

Keys (feed rows and card tiles): `stones`, `qi`, `contribution` (currency:
coin frame on card tiles, a disc in the currency's colour on feed rows), `manual:<technique>`, `weapon:<id>`, `method:<id>`, `seed:<herb>` (named by the herb),
`garden` (seclusion: "Garden tended", the plant glyph on a jade tile, no count),
`mutation` (seclusion: plants that took a mutation, gold tile), or an `Items` id.
A card tile's name longer than 14 letters wraps to a second line at the same 12 px; the
tile and the row grow 13 px (no truncation).
Item tiles take the edge of their rarity or grade on the Inventory's ladder
([inventory](inventory.md), `Rarity.luau`): Common/Mortal bronze (`neutral`),
Uncommon silver (`grey`), Rare/Spirit jade, Epic/Earth violet, Legendary/Heaven gold;
manuals neutral. One ladder everywhere (decided at the UI merge, 2026-10-23), so no
blue tier is needed.

Server side: `Effect "reward"` with a spec table goes straight to `Rewards.show`, so a
new system picks its own tier without a new remote. What a real system must send:
the tier, and for a card its `kind`, title, subtitle and whatever it has of items,
stats, unlock and flavour (empty lines hide). Sect quests send the quest card
(`Sect.luau`); onboarding objectives and bloodlines don't send it yet.

## Layout

The ScreenGui holds one `Canvas` with the authored `UiScale` (fitted by `UiScale.fit`:
desktop baseline 1920x1080, phone 844x390, one layout for both). Inside it:
- `Feed` (bottom-right anchor at 58 % height, 264 wide, rows 256x34, 6 px apart; user,
  2026-10-23: "too bundled together and the icons dont fit"). Row (`EntryTemplate`):
  the toast's plaque, 9-sliced (SliceScale 34/96); `Disc` (`art_disc`, 24 px, tinted
  the look's colour leaned 20 % to black) with its `Icon` (cropped to its drawn area,
  `SlotArt.setIcon`, 62 % of the disc) or `Glyph`; `NameLabel` (Builder Sans Bold 15,
  8 px after the disc, truncated); `CountLabel` (Fredoka One 16, gold). The disc's left
  edge and the count's right edge both sit 4 px inside the plaque's points.
- `Floats.FloatTemplate`.
- `Banner` (620x118 at the top centre, 64 px down): `Kicker`, `Ribbon` (56 tall, `Art`
  plus `Title`; fitted to the title by `Ribbon.fit`, 24 px, at most 600 wide, keeping
  its jade, crimson or navy-gold cloud ribbons), `Tag`, `Subtitle` (hidden on small phones).
- `Card` (62 % x 84 %, aspect 1.57, at most 600x382, 10 px above centre): `Rays`,
  `Art` (its aspect set per job: 1.718 boss, 1.571 quest), with `Crest` (and its hidden
  `Emblem`), `Ribbon`,
  `Body` (a centred list: `Subtitle`, `List` of `RewardTemplate` tiles 64x82 with 14 px
  gaps, `Stats`, `Unlock`, `Flavour`) and `Hint` under the card.
The card's title plaque fits its title ([ribbons](ribbons.md)): the plain middle is the
title plus even padding, at least 36 % of the card wide, at most 84 %; the text is 0.47 of
the plaque's height (28 on PC), shrinks to 85 % and then truncates.
Per-job positions (ribbon, body, rays) are fractions of the card art measured in the
PNGs, in `KINDS` in `Rewards.luau`. Fonts: Merriweather for titles and the italic
subtitle and flavour, Builder Sans Bold for small text, Fredoka One for counts (the kit's
Cormorant Garamond and Fredoka aren't Roblox fonts).

Rebuild the GUI with `tools/rewards_gui_build.luau` (sandbox only; it also sets the Hud
toast's subtree), then export. To rebuild only the feed, run its helpers and its
"Feed" block against the existing `Canvas` (the 2026-10-23 pass did that).

Measured in edit view (1060x784, scale 1) and on an 844x390 phone canvas: card, ribbon,
body, crest and hint centres all on the canvas centre (530.0); crest on the slot's
centre row (263.4 = 263.4); ribbon titles on the body's centre row (311.5, 116.3);
tiles 103/103 px from the list edges with 14/14/14 gaps (toast and feed: see "Toast").
Phone card: 514x328, 21 px from the top, hint inside.
Rank emblem (rank card, 1024/652 art): its centre lands on each crest's hole centre to
0.01 px (crest_outer, crest_inner, crest_core), 25.0/23.5/20.7 px in 50 px crests.

## Toast

`Hud.Toast` (user, 2026-10-23: "lackluster", then "change the shape"; reference
`docs/reference/ui/hud_vitals_reference.webp`, its name plaques): a dark lacquer plaque
with pointed, bevelled ends, a gold rim lit along its upper edges and shaded along its
lower ones, a thin inner gold line, a lit top edge and an inner shade
(`art/ui/toast_plaque.png`, `draw_ui.py plain`, SliceCenter Rect(48, 47, 464, 49),
SliceScale 0.375 for 36 px). A kit `ruby_stud` (20 px) is set into each end, 15 px
from the tip, part of the shape rather than floating off it. The message is Builder
Sans Bold 16 cream with a near-black stroke; `Hud.placeToast` sizes it to its text
(`TextService:GetTextBoundsAsync`, up to 380 px, then two lines) and the plaque grows
around it (34 px sides, 10 px top and bottom).

Where: the row of Roblox's top bar (`Platform.topbar`, `GuiService.TopbarInset`),
centred on the screen when it fits, else slid clear of Roblox's menu and chat buttons
on the left and, while they show, the top-right tiles; vertically centred in the bar.
Windows start below the bar, so a toast never lands on one (the phone Inventory's
title used to take it, `4.png`); if an open window or the build banner still reaches
the toast, it moves below that (or above it). It fades in and out
(`Motion.fadeIn/fadeOut`); the queue and timing are unchanged. Feed rows use the same
plaque, plain, so the two read as one family.

The bar's depth comes from `Platform.topbar`, which until 2026-10-23 read it twice
over (116 px for the 58 px bar: `AbsolutePosition` is measured from below the GUI
inset, `TopbarInset` from the screen top), so in play the toast sat under the bar,
centred on its bottom edge, rather than in it, on PC and phones alike.

Phone (touch and short screen; user, 2026-10-23: "the toast is fkn TERRIBLE for
mobile", a two-line plaque jammed against Roblox's chat button, as tall as the
tiles): a slimmer plaque (SliceScale 0.3, 20/6 px padding, no studs) and 14 px text,
read by contrast (cream, near-black stroke). It takes the bar's free lane (Roblox's
buttons to the tiles) only when the message fits there on one line; otherwise it
drops just under the top band (8 px below the tiles), from the end of Roblox's
buttons to the objective column's left edge, where it wraps if it must. The
meditation toast is shorter for it: "Cultivation ×2.5 on your peak" (was
"Meditating on your peak: passive cultivation ×2.5"). Queue (4 at most, repeats
skipped) and timing (3.2 s plus up to 2 s for long text) are unchanged.

Measured 2026-10-23 (sandbox preview, faked top bar 58 px PC / 44 px phone): 36 px
tall; message centre on the plaque centre to 0.0 px; studs 15.0 / 15.0 px from the
tips and on the centre line; 7.5 / 7.5 px from the studs to the text. 1366x768: at
x 490 (centred, dx 0.0), y 11 in the bar, window top 134. 667x375 with the Inventory
open: one line, y 4 in the 44 px bar, slid 7.5 px right of centre to clear Roblox's
buttons, window top 50; never overlapping. Feed rows (PC, scale 0.726): icon centre on
disc centre, disc, name and count on the row's centre line, all 0.00 px; 6 px between
rows; 17 px from each end to the disc and the count.

## Art

Kit cuts in `art/ui/codex/cut/` (sheets B1, B2, A6, C3, C5, light effects; ids in
`art/ui/assets.json`): `card_boss`, `card_quest`, `rays_boss`, `rays_milestone`,
`ribbon_crimson_*`, `ribbon_jade_*`, `objective_banner_*`, `tile_*` (card tiles),
`gem_*`, `coin_frame`, `glyph_spirit_stone`, `glyph_qi`, `glyph_insight` (now only the dialogue's study glyph),
`emblem_peak`, `emblem_lotus`, `fx_glint`, `ruby_stud` (toast). Drawn: `toast_plaque`
(toast and feed rows) and `art_disc` (feed discs), `art/ui/draw_ui.py plain`. The Figma mock is
"Rewards / Cards, feed, toast (mock)" on the kit's Example page (file
`WNgoTL6QGdTEBy693Me8Y8`).

## Known gaps
- `contribution` uses a 功 glyph in the coin; the kit's `contribution_token` could
  replace it.
- `Hud.Banner` and `Hud.Flash` (the old breakthrough title card and flash) are unused
  now; they are outside this pass's Hud subtree and should be removed with the Hud's
  next structural edit.
- Rewards no longer uses the old Pillow art (`victory_*`, `feed_strip`, `feed_accent`,
  `region_wash`, `slot_simple`); some of it is still used elsewhere in the Hud.
