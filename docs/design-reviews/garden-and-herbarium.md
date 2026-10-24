# Review: spirit garden and Herbarium

**Verdict: keep with changes.** It's the game's best session-per-day engine and the gardener road's backbone. But Grow now sells progress, the best surprise layer (mutations) only happens in AFK mode, and the garden has no shared moment like Grow a Garden's. Reviewed 2026-10-23 from docs and code; nothing played.

## Why it exists
- Arrow: home turns herbs into qi, buffs and stones (core-loop table). Offline growth gives the "my plants grew" return hook. That is the D1 lever the research names first.
- Who: kids (collecting, bright mutations), casuals (check-ins), completionists (Herbarium). Competence and autonomy are served. Relatedness is near zero: no gifting, no visiting gift, no shared stock.

## Is it fun
- Good: real-time growth, sizes, weather mutations and the mutation chains (Jade Lotus > Rift Lotus > ...) give a variable reward *inside play*. That's the right schedule. The Herbarium's silhouettes give a cheap long tail, as the research recommends.
- Weak: there is no decision. Planting the highest-tier seed you own is dominant. There are no plot trade-offs (fast herbs for buffs vs long herbs for qi) the player can see.
- Mutations while you play are mostly weather. The 3%/h garden roll fires **only while secluded online** (`Garden.luau:463`), so the fun roll is gated behind AFK. That rewards leaving the game running, not playing, and it pads the 60 min/day playtime with idle time.
- Grow a Garden's core is a **global shop on a 5-min restock** that every player in the server chases together. Here the Herbalist is a private catalog (no stock code in `Garden.luau`), so the one social, FOMO-free, come-back-in-5-minutes beat is missing.

## Cost
- 22 herbs, 3 soils, 5 tiers, 7 mutations, sizes and weather. That's a lot of words, but they arrive over 30 h by region, which is acceptable. The eat-share math is invisible to players, which is fine.
- One more top-right tile (Herbarium), now 7 tiles. See hud-and-menus.

## Failure and abuse
- **Grow now sells progress** (`Config.Garden.GROW_NOW` 3/6/9 R$). 9 R$ finishes a 24 h Dao Origin Fruit or a 4 h Thousand-Year Ginseng (a *full dantian* per herb, `Pacing.Herbs.PRIZE`). The first harvest also pays Herbarium stones and a Home foundation experience, which is a permanent stat bonus. That is stat power for Robux, priced like candy.
- **Paid-randomness risk:** a Grow now harvest still rolls yield, seeds back and the `mutatesTo` seed (`Garden.luau:220-237`). Robux buys a faster random roll. It may sit outside the letter of the paid-random-items policy, but not its spirit.
- No loss, no pests, nothing withers. Good for kids.

## Metrics
- D1 and sessions per day: strong, provided the first plant ripens on a timer that ends after the session (a 2-min Spirit Grass doesn't pull anyone back). The garden opens at QC4, inside the first session. Good.
- D8-28: tier IV-V grow times (6-24 h) are the right shape for daily check-ins.
- Not instrumented: no economy events for herb sales or seed buys, no event for harvests or Herbarium pages.
- Notifications ("your herbs are ready") aren't wired: no `ExperienceNotificationService`.

## Interactions
- Foundation Home experiences, the sect's herb and harvest dailies, seclusion growth and peak-score growth all feed it. These are good arrows, but four different growth multipliers stack (weather, peak score, root, seclusion). Players can't read why a plant is fast. Show one "growth +x%" line on the plant tag.

## Recommendations (ranked)
1. **Rework Grow now so it can't buy progress.** Cap it at tier I-II, or make it finish the plant with *fixed* yield and no mutated-seed roll, and exclude it from first-discovery foundation credit. Better still, replace it with a convenience pass (auto-harvest, an extra plot row).
2. **Move the 3%/h mutation roll from "secluded online" to "owner online on the peak"**, whatever the player is doing. Active tending should beat AFK (research: AFK never better than active play).
3. **Add a shared Herbalist restock**: 4-6 rotating seed lots per server every 5-10 min, with an honest timer and earned stones only. That's the Grow a Garden beat, and an update-cadence hook (new seeds in the rotation each week).
4. Add `LogEconomyEvent` for seed buys and herb sales, plus a custom event per Herbarium page.
5. Add an opt-in (13+) "herbs ready" notification after the first harvest, and a gift-a-herb action on the player card.
