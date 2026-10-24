# Seclusion

## Purpose
Closed-door cultivation, framed: work on yourself with what you've gathered, short
and purposeful (owner, 2026-10-24). The player shuts themselves away on their own
peak, absorbs a herb or pill to mend an old foundation, lets the garden grow, and
comes back to a result card. It's also the game's AFK mode.

## Rules (owner, 2026-10-24)
- **Purposeful, never a leash.** Seclusion is tempering, a faster garden (plus the
  online mutation chance), AFK cultivation and fortuitous encounters (band herbs and
  seeds) rolled continuously. No hour streaks, no flat stone trickle, nothing that needs a full hour or rewards sitting on
  a timer for its own sake.
- **Tempering mends, it never exceeds**: up to 100% only ([cultivation](cultivation.md#foundation-grade)).
  Past 100% is earned by living through a stage; deepening (a calmed heart demon) is
  the only other lift past it. Never for Robux.

## Design
- **AFK online and offline earn the same cultivation.** Offline, AFK online (no input
  for `Pacing.Income.AFK_AFTER`, 10 min) and seclusion all earn `Cultivation.afkRate`:
  the stage's plain passive times `OFFLINE_RATE` (1), with no meditation, aura, weather,
  buffs, root or method, out of one `Pacing.Income.OFFLINE_MAX_HOURS` (12 h) budget a
  UTC day shared by all of them (`Cultivation.awayLeft`). Seclusion's own rewards count
  up to `MAX_HOURS` (12) of one seclusion. All stop at the overflow cap
  (`Pacing.Breakthrough.OVERFLOW_CAP`); nothing breaks through on its own.
- **Seclusion pays its own rewards, never stages**, and no foundation experiences:
  - **tempering** (below): the reason to go in;
  - the garden tended: growing plants grow `GROWTH` +50% faster, online and offline;
  - the garden's online mutation roll isn't seclusion's own (the user: "theres a chance
    for ur garden to mutate if u stay online"): it rolls whenever the owner is online on
    their own peak, secluded or not, never offline ([garden](garden.md)); mutations
    taken while secluded count on the card;
  - **fortuitous encounters, rolled continuously** (owner, 2026-10-24: the heavy
    player's edge comes from encounters, not stones): every `FIND_SECONDS` (5 min) a roll
    of `FIND_CHANCE` (0.6) x 5/60, so 5% a roll, 0.6 finds an hour, and a 10-minute
    seclusion can still find something. By `FINDS` weight of 100: a herb of the
    player's band 35, a seed of it 45, a seed of the next band 5 (rare; past the Far
    Reaches the band's own), Heavenly Dew 8, Cloud-Pattern Jade 4, Immortal Peach 1, a
    Foundation Tempering Pill 2. Never stones, never root pills. The band's herbs
    (`bandPool`) are its `Herbs.Regions` pools plus the herbs whose `region` it is, of
    the band's own tier (no wild or event herbs), picked by `FIND_RARITY` (Common 10,
    Uncommon 30, Rare 40, Epic 16, Legendary 0.25). Odds and band contents:
    [progression rules](progression-rules.md#herbs-and-seeds) "Fortuitous encounters".
    Each find is told as an encounter (`ENCOUNTERS` in Seclusion.luau: "A wandering
    spirit bee led you to a Seven-Star Grass seed.", "A white crane landed beside you
    and left a Jade Lotus.", a far seed from "a streak of starlight", items from "a
    hermit's cache"): a toast online, the plaque's count, and the card (its flavour
    "Fortune found you in the stillness." when nothing was tempered). Offline finds land
    on the card only.
- **The cap message.** When cultivation reaches the overflow cap the toast says once
  "Your dantian can hold no more. Break through." (only when a breakthrough is
  possible), and again when the player comes back from AFK, offline (a few seconds
  after login) or seclusion.

## Tempering
`Pacing.Tempering`; server `Seclusion.cantAbsorb` / `absorb`, through `Inventory.use`.
- **What tempers** (`POINTS`): the **Foundation Tempering Pill** +20 (Rare; used only in
  seclusion), **Snowpeak Lotus** +10 and **Nine-Leaf Lingzhi** +20 (eaten while secluded
  they temper as well as giving their qi and buffs; eaten anywhere else they're plain
  herbs). Where they come from: [progression rules](progression-rules.md#cores-treasures-and-pills).
- **Flow:** seated in seclusion, use the item from the hotbar or Inventory. It's
  absorbed ("Its warmth sinks toward your Qi Condensation 5 foundation. Stay a few
  minutes.") and settles `SETTLE_SECONDS` (3 min) of seclusion later: the lowest old
  stage (lowest percent, ties the earliest) rises by its points, never past 100%
  (`Foundation.temper(data, 1, points)`; `Pacing.Foundation.TEMPER_MAX`). A toast names
  it, stats refresh, and the card lists every stage mended ("QC5  60% -> 80%").
- **One at a time**; another is refused until it settles ("Let the last one settle
  first."). **Caps:** `PER_DAY` 2 absorbed a UTC day and `PER_WEEK` 5 a week (Monday
  00:00 UTC). Refused, and kept, when nothing is under 100% or a cap is reached, or
  outside seclusion (the pill).
- **Rising before it settles gives it back** (and the cap count). Logging out keeps it
  settling offline with the rest of the seclusion.
- Counted in `data.stats.tempered` (stages mended; the heart demon's root question
  names it, [heart demon](heart-demon.md)).

## The flow
1. Seated on your own peak (`Meditation` spot `own`), the Method tile (it reads
   **Seclusion** until a method is owned) opens the meditation panel; its first row
   is Seclusion with **Enter** (`CultivationAction "seclusion"`; the guide's callout
   says "Enter Seclusion"). Its line under the name is "Temper old foundations"; the
   blurb names the items, the garden and the finds.
2. Secluded (player attribute `Secluded`): still seated, a slim plaque under the top
   bar shows the time, the tempering under way and what has gathered; the seated row
   shows only Seclusion and Rise. Circulate, Break Through, Practice, the heart demon,
   method and root changes are refused ("Rise to leave it first").
3. Rising (Rise, a hit, drifting off the seat) ends it. The result card shows after
   at least `CARD_MIN_MINUTES` (10), for the first one, or when anything was found or
   tempered (a quick sit to check something rises quietly). The card (`Rewards.show`
   card, kind `seclusion`, through Effect "reward"): "9 minutes in seclusion", the
   finds, seeds (`seed:<herb>`) and garden (`garden` or `mutation`) tiles, a stat row per
   stage mended plus Cultivation before and after, and a line ("Your old foundations are
   mended.").
4. Logging out while secluded keeps it going: `data.seclusion.since` stays set. The
   next login settles the time away (finds, a settling item, garden growth through
   `Garden.advance`; no mutations), ends it, and shows the card about 8 s in.

### The first seclusion (onboarding)
The **Seclusion** lesson (`Quests.Lessons`) waits for the second session (user,
2026-10-24): the first sit after a join that began at QC4 or later, with Home claimed
(the seed is what it tends), or QC5 for a player who never rejoins. "Rest now. Your
peak works for you while you're away." Guide: travel home, sit, then the
Method/Seclusion tile and the Enter Seclusion row (`GuideKey "Seclusion"`). The first
seclusion ends by itself after `FIRST_SECONDS` (45 s) with a **First Seclusion** card
about the garden and tempering: `FIRST_SEEDS` 2 Cloud Mint, `FIRST_GROWTH` 300 s on
every growing plant (a Spirit Grass is ready), `FIRST_BAR` a quarter of the bar as
cultivation (never past the bar) and `FIRST_ITEMS` one Foundation Tempering Pill, with
"Next time, bring a herb or pill to temper an old foundation." The lesson's own reward
(`Pacing.Quests.Seclusion`, 20 stones) is claimed then. In the testbed the lesson
doesn't wait for Home.

## Balance (Pacing header "AFK, OFFLINE AND SECLUSION")
A 12 h night is `passive * 43200` cultivation: it fills the overflow cap at every QC and
QR stage and 26-57% of an FE bar. So a night is worth about one stage, never two. With
the stone trickle gone seclusion is no stone source: in the model the heavy profile
(nightly seclusion) earns about 12,500 stones to FE9 instead of 26,000, and its online
time to FE9 rose 25.2 -> 29.8 h ([progression rules](progression-rules.md#open-calls-the-owners)).

## Data
- `data.seclusion = { since, counted, online, start, rolled, tally, first, temper,
  temperAt, temperDay, temperDayN, temperWeek, temperWeekN }` (PlayerData type
  `Seclusion`; `rolled` = find rolls made; `tally` = cultivation, items, seeds,
  mutations, growth, tempered; `temper` the absorbed item settling at `counted` =
  `temperAt`; the day and week counters for the caps). Missing-field defaults, no
  schema bump; old saves' `streak`/`streakDay` are ignored.
- `data.stats.secluded`: seconds in seclusion, online and offline (the heart demon:
  "You sat in seclusion for 40 hours. Were you hiding?"); `data.stats.tempered`: stages
  mended in seclusion.
- Remotes: `CultivationAction "seclusion"` (enter); `InventoryAction "use"` (absorb);
  `Meditate "awake"` (the client's input ping, at most every `Pacing.Income.AWAKE_PING`
  30 s); Effect `"reward"` (the card). Analytics: `SeclusionEntered`, `SeclusionEnded`,
  `FoundationTempered` (stages, item id).

## Files
`src/server/Seclusion.luau` (enter, tick, finds, tempering, offline settle, card), hooks in
`Cultivation.luau` (AFK rate and budget, cap line, `secluded`, `enterSeclusion`,
breakthrough refused), `Inventory.luau` (`cantAbsorb` / `absorb` from `use`),
`Foundation.luau` (`temper`, `nextTemper`, `temperStats`), `Circulation.luau` (the
action, refusals), `Garden.luau` (tending, the online mutation roll, `advance`),
`Meditation.luau` (`own` spot, the awake ping), `Quests.luau` (the lesson),
`HeartDemon.luau` (the questions), `Main.server.luau` (`Seclusion.resume` after
`claimLogin`). Client: `Meditation.luau` (awake ping, tiles), `MeditationMenu.luau` (the
row), `Guide.luau` (`Seclusion` inside the panel), `SeclusionView.luau` (the plaque),
`Rewards.luau` (the `seclusion` card, `seed:`, `garden`, `mutation` tiles);
`assets/Cultivation.rbxmx` (`Canvas.Seclusion`; `tools/seclusion_ui_build.luau`). Tuning:
`Pacing.Seclusion`, `Pacing.Tempering`, `Pacing.Income` (`AFK_AFTER`, `AWAKE_PING`,
`OFFLINE_*`).

## UI ([cultivation UI](../ui/cultivation.md#seclusion))
- **State for the plaque** (player attributes `Seclusion.publish` sets while live and
  clears when it ends; the shape a slimmer plaque should read):
  - `Secluded` (true), `SeclusionSince` (os.time it began: the timer);
  - `SeclusionTempering` (the stage name being tempered, "Qi Condensation 5"; "" none)
    and `SeclusionTemperAt` (os.time it settles; 0 none), `SeclusionTempered` (stages
    mended this seclusion);
  - `SeclusionFinds` (finds and seeds so far), `SeclusionTended` (the garden grew),
    `SeclusionMutations` (plants that took a mutation).
- **Secluded plaque today** (`SeclusionView.luau`, Cultivation `Canvas.Seclusion`): the
  timer, the finds and garden chips, and the streak row's label reused for the
  tempering line ("Tempering Qi Condensation 5 · 2:41", "2 old foundations mended", or
  "Absorb a herb or pill to temper"); the Stones chip and the pips are hidden in code.
  **Next (ui-designer):** slim the plaque to that state: drop the Stones chip and the
  `Templates.SeclusionStreak` pips from `assets/Cultivation.rbxmx`, give the tempering
  line its own label, and remove `SeclusionView.paintStreak` and Rewards' `spec.streak`.
- **The card**: Rewards kind `seclusion`: tiles for finds, seeds and the garden
  (`mutation` with the count, or `garden`), a stats row per stage mended ("QC5 60% ->
  80%") and "Cultivation from -> to" (the stats share one line, so three or more stages
  may crowd it), and a flavour line.
- **Row icon**: `emblem_peak`.
- **Seclusion tile, for the next Hud pass** (`assets/Hud.rbxmx` was owned by another
  pass, so the Method tile is still reused with its caption swapped in
  `Meditation.luau`): a tile of its own, `Stack.CultivatePrompt.Seclusion`, a clone of
  `Method` (same `tile_neutral` frame, 54 px, phone 50 px, caption "Seclusion" under it)
  with the `emblem_peak` icon at 50 % centred on the tile and cropped to its drawn area
  like the others, untinted gold. Placement: first in the row (LayoutOrder before
  Method), shown seated on your own peak (`MeditationMenu`'s `seclusionHere`); while
  secluded the row is only Seclusion and Rise, as now. The Method tile then goes back to
  reading "Method" and shows only when a method is owned. When a white seclusion glyph
  exists (a Codex request: a peak with a closed gate, white, plain), swap it in.

## Known gaps
- Untested in play (tempering, the continuous finds, the reworked card and plaque).
- **Roblox kicks idle clients after 20 minutes without input**, so staying online in
  seclusion (and the garden's online mutation roll) only lasts while the client gets
  input; after a kick the offline path takes over and settles on the next login.
- A seclusion running when a server crashes (no logout time saved) may count its
  online stretch twice on the next login (capped at `MAX_HOURS`).
- The Foundation Tempering and Clear Heart Pills have light-pass models in the item
  builder only, not yet built or exported ([item models](item-models.md)); their slot
  icons are glyphs (基, 心) until the icon pass.
