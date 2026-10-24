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
  - **online only, a garden mutation roll** (the user: "theres a chance for ur garden
    to mutate if u stay online"): each plant, `MUTATION_PER_HOUR` 3% an hour (times the
    garden pieces' luck), one of Dewy 50 / Windswept 30 / Auspicious 15 / Golden 5;
  - each full hour, `RARE_CHANCE` 10% of a rare find: Heavenly Dew 50, Cloud-Pattern
    Jade 25, Immortal Peach 5, or (60) a seed of the major's next herb tier
    (`SEED_TIER`: II in QC, III in QR, IV in FE; no wild or event herbs). Never root pills;
  - the streak: consecutive days with a seclusion of at least `STREAK_MIN_HOURS` (1 h);
    each day past the first adds `STREAK_BONUS` +10% to that seclusion's stones, up to
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
2. Secluded (player attribute `Secluded`): still seated; the seated row shows only
   Seclusion and Rise. Circulate, Break Through, Practice, the heart demon, method
   and root changes are refused ("Rise to leave it first").
3. Rising (Rise, a hit, drifting off the seat) ends it and the result card shows
   (`Rewards.show` milestone card through Effect "reward"): "You spent 9 hours in
   seclusion. Your garden was tended, and 3 plants took a mutation." with the stones,
   finds and seeds (`seed:<herb>` tiles), Cultivation before and after, the streak and
   the streak bonus.
4. Logging out while secluded keeps it going: `data.seclusion.since` stays set. The
   next login settles the time away (stones, hourly rolls, garden growth through
   `Garden.advance`; no mutations), ends it, and shows the card about 8 s in.

### The first seclusion (onboarding)
The **Seclusion** lesson (`Quests.Lessons`, after Home at QC4; paired with it, since
the seed just planted is what it tends): "Now rest. Sit on your peak and enter
seclusion..." Guide: travel home, sit, then the Method/Seclusion tile and the Enter
Seclusion row (`GuideKey "Seclusion"`). The first seclusion ends by itself after
`FIRST_SECONDS` (90 s) with a generous **First Seclusion** card: `FIRST_STONES` 60,
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
(`Seclusion` inside the panel), `Rewards.luau` (`seed:` tiles). Tuning:
`Pacing.Seclusion`, `Pacing.Income` (`AFK_AFTER`, `AWAKE_PING`, `OFFLINE_*`).

## UI needs (for a ui-designer pass; `assets/Hud.rbxmx` untouched)
- A **Seclusion tile** of its own in `Stack.CultivatePrompt` (today the Method tile is
  reused: caption swapped in code, still the method icon).
- A **secluded state on screen**: a quiet banner or vignette with the elapsed time and
  what has gathered so far (stones, finds), and a clear "Rise to leave" hint. Today
  only the panel row says "In seclusion".
- A **seclusion card** look (today the milestone card): the lotus crest, a garden
  line, the streak as a row of day pips instead of a "from -> to" stat.
- A **Seclusion row icon** (today the kit's lotus emblem, `emblem_lotus`).

## Known gaps
- Untested in play.
- **Roblox kicks idle clients after 20 minutes without input**, so staying online in
  seclusion (and its mutation roll) only lasts while the client gets input; after a
  kick the offline path takes over and settles on the next login. Overnight online
  seclusion in practice needs the device to stay active.
- A seclusion running when a server crashes (no logout time saved) may count its
  online stretch twice on the next login (capped at `MAX_HOURS`).
- No foundation tempering from seclusion (roadmap's earlier idea); the heart demon tempers.
- Analytics: `SeclusionEnded` (minutes counted) only.
