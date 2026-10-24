# Seclusion (the AFK mode)

## Purpose
Closed-door cultivation, framed: the player shuts themselves away on their own peak
and comes back to a result card. It's the game's AFK mode (roadmap 9b item 1), and
for gardeners and mobile players the "leave it running" reward moment.

## Design (user, 2026-10-23)
- **AFK online and offline earn the same cultivation.** Offline (up to
  `Pacing.Income.OFFLINE_MAX_HOURS`, 12 h), AFK online (no input for
  `Pacing.Income.AFK_AFTER`, 10 min) and seclusion all earn `Cultivation.afkRate`: the
  stage's plain passive times `OFFLINE_RATE` (1), with no meditation, aura, weather,
  buffs, root or method, for at most 12 h of AFK. All stop at the overflow cap
  (`Pacing.Breakthrough.OVERFLOW_CAP`); nothing breaks through on its own.
- **Seclusion pays its own rewards, never stages**, and no foundation experiences:
  - a slow Spirit Stone trickle: `STONES_PER_HOUR` 25 (QC) / 60 (QR) / 150 (FE);
  - the garden tended: growing plants grow `GROWTH` +50% faster, online and offline;
  - the garden's online mutation roll isn't seclusion's own (the user: "theres a chance
    for ur garden to mutate if u stay online"): it rolls whenever the owner is online on
    their own peak, secluded or not, never offline ([garden](garden.md)); mutations
    taken while secluded count on the card;
  - each full hour, `RARE_CHANCE` 10% of a rare find: Heavenly Dew 50, Cloud-Pattern
    Jade 25, Immortal Peach 5, or (60) a seed of the major's next herb tier
    (`SEED_TIER`: II in QC, III in QR, IV in FE; no wild or event herbs). Never root pills;
  - the streak: days with a seclusion of at least `STREAK_MIN_HOURS` (1 h). A missed
    day pauses it (adds nothing) and never resets it. Each day past the first adds `STREAK_BONUS` +10% to that seclusion's stones, up to
    `STREAK_MAX` 7 days (+70%).
  Everything counts for at most `MAX_HOURS` (12) of one seclusion.
- **The cap message.** When cultivation reaches the overflow cap the toast says once
  "Your dantian can hold no more. Break through." (only when a breakthrough is
  possible), and again when the player comes back from AFK, offline (a few seconds
  after login) or seclusion.

## The flow
1. Seated on your own peak (`Meditation` spot `own`), the Method tile (it reads
   **Seclusion** until a method is owned) opens the meditation panel; its first row
   is Seclusion with **Enter Seclusion** (`CultivationAction "seclusion"`).
2. Secluded (player attribute `Secluded`): still seated, a slim plaque under the top bar shows the time and what has gathered; the seated row shows only
   Seclusion and Rise. Circulate, Break Through, Practice, the heart demon, method
   and root changes are refused ("Rise to leave it first").
3. Rising (Rise, a hit, drifting off the seat) ends it and the result card shows
   (`Rewards.show` card, kind `seclusion`, through Effect "reward"): "9 hours in
   seclusion", the stones, finds, seeds (`seed:<herb>`) and garden (`garden` or
   `mutation`) tiles, Cultivation before and after, and the streak as day pips with the
   streak bonus.
4. Logging out while secluded keeps it going: `data.seclusion.since` stays set. The
   next login settles the time away (stones, hourly rolls, garden growth through
   `Garden.advance`; no mutations), ends it, and shows the card about 8 s in.

### The first seclusion (onboarding)
The **Seclusion** lesson (`Quests.Lessons`) waits for the second session (user,
2026-10-24): the first sit after a join that began at QC4 or later, with Home claimed
(the seed is what it tends), or QC5 for a player who never rejoins. "Rest now. Your
peak works for you while you're away." Guide: travel home, sit, then the
Method/Seclusion tile and the Enter Seclusion row (`GuideKey "Seclusion"`). The first
seclusion ends by itself after `FIRST_SECONDS` (45 s; 30-60 s) with a generous **First Seclusion** card: `FIRST_STONES` 60,
`FIRST_SEEDS` 2 Cloud Mint, `FIRST_BAR` a quarter of the bar as cultivation (never
past the bar) and `FIRST_GROWTH` 300 s on every growing plant (a Spirit Grass is
ready). The lesson's own reward (`Pacing.Quests.Seclusion`, 20 stones) is claimed then.
After that, normal rules. In the testbed the lesson doesn't wait for Home.

## Balance (Pacing header "AFK, OFFLINE AND SECLUSION")
A 12 h night is `passive * 43200` cultivation: it fills the overflow cap at every
stage up to FE5 and 110-142% of the bar at FE6-FE9. So a night is worth about one
stage, never two: breakthroughs need the player, the overflow (at most half a bar)
all carries but the cap stops a night there, and a
mostly slept-through stage seals a weak foundation grade. Simulated on the curve
(active rate while playing, a 12 h night every day): 1 h a day finishes QC on day 2,
QR on day 7, FE8 on day 15 (3, 10, 27 without nights); 2 h a day 2, 4, 9 (2, 5, 14).
Lowering the AFK ceiling below the cap barely moves this; to slow nights, lower
`OFFLINE_RATE` or `OFFLINE_MAX_HOURS`. Seclusion's stones are small next to hunting
(a QC wolf is about 4.5 stones; 12 h of QC seclusion is 300).

## Data
- `data.seclusion = { since, counted, online, start, rolled, tally, streak, streakDay, first }`
  (PlayerData type `Seclusion`; `tally` = stones, frac, cultivation, items, seeds,
  mutations, growth). Missing-field defaults, no schema bump.
- `data.stats.secluded`: seconds in seclusion, online and offline (the heart demon:
  "You sat in seclusion for 40 hours. Were you hiding?").
- Remotes: `CultivationAction "seclusion"` (enter); `Meditate "awake"` (the client's
  input ping, at most every `Pacing.Income.AWAKE_PING` 30 s); Effect `"reward"` (the card).

## Files
`src/server/Seclusion.luau` (enter, tick, offline settle, card), hooks in
`Cultivation.luau` (AFK rate and budget, cap line, `secluded`, `enterSeclusion`,
breakthrough refused), `Circulation.luau` (the action, refusals), `Garden.luau`
(tending, the online mutation roll, `advance`), `Meditation.luau` (`own` spot, the
awake ping), `Quests.luau` (the lesson), `HeartDemon.luau` (the question),
`Main.server.luau` (`Seclusion.resume` after `claimLogin`). Client:
`Meditation.luau` (awake ping, tiles), `MeditationMenu.luau` (the row), `Guide.luau`
(`Seclusion` inside the panel), `SeclusionView.luau` (the plaque), `Rewards.luau`
(the `seclusion` card, `seed:`, `garden`, `mutation` tiles); `assets/Cultivation.rbxmx`
(`Canvas.Seclusion`, `Templates.SeclusionStreak`; `tools/seclusion_ui_build.luau`). Tuning:
`Pacing.Seclusion`, `Pacing.Income` (`AFK_AFTER`, `AWAKE_PING`, `OFFLINE_*`).

## UI ([cultivation UI](../ui/cultivation.md#seclusion))
- **Secluded plaque** (`SeclusionView.luau`, Cultivation `Canvas.Seclusion`): elapsed
  time, stones, finds, the garden, the streak's day pips and "Rise to leave", from the
  player attributes `SeclusionSince`, `SeclusionStones`, `SeclusionFinds` (items and
  seeds), `SeclusionTended`, `SeclusionMutations`, `SeclusionStreak` (the streak's days; a
  missed day only pauses it) and `SeclusionToday` (today already counts),
  set by `Seclusion.luau` while live and cleared when it ends.
- **The card**: Rewards kind `seclusion`: tiles for stones, finds, seeds, and the
  garden (`mutation` with the count, or `garden`), "Cultivation from -> to", and
  `streak = { days, text }` as day pips ("Day 3 · +54 streak stones"; "an hour keeps the
  streak" when this one was too short; "An hour a day builds a streak" with none).
- **Row icon**: `emblem_peak`.
- **Seclusion tile, for the next Hud pass** (`assets/Hud.rbxmx` was owned by another
  pass, so the Method tile is still reused with its caption swapped in
  `Meditation.luau`): a tile of its own, `Stack.CultivatePrompt.Seclusion`, a clone of
  `Method` (same `tile_neutral` frame, 54 px, phone 50 px, caption "Seclusion" under it)
  with the `emblem_peak` icon at 50 % centred on the tile and cropped to its drawn area
  like the others, untinted gold (the tiles' white glyphs are tinted cream; the peak is a
  gold emblem, as the panel row shows it). Placement: first in the row (LayoutOrder
  before Method), shown seated on your own peak (`MeditationMenu`'s `seclusionHere`);
  while secluded the row is only Seclusion and Rise, as now. The Method tile then goes
  back to reading "Method" and shows only when a method is owned. When a white
  seclusion glyph exists (a Codex request: a peak with a closed gate, white, plain),
  swap it in, tinted cream like the rest.

## Known gaps
- Untested in play.
- **Roblox kicks idle clients after 20 minutes without input**, so staying online in
  seclusion (and the garden's online mutation roll) only lasts while the client gets input; after a
  kick the offline path takes over and settles on the next login. Overnight online
  seclusion in practice needs the device to stay active.
- A seclusion running when a server crashes (no logout time saved) may count its
  online stretch twice on the next login (capped at `MAX_HOURS`).
- No foundation tempering from seclusion (roadmap's earlier idea); the heart demon tempers.
- Analytics: `SeclusionEntered` (first/again), `SeclusionEnded` (minutes counted), and the stones tally as a `Seclusion` economy source.
