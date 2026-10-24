# Review: retention and monetization

**Verdict: rework monetization; keep the retention base with additions.** The offline and daily foundation is sound. But the only products on sale are a paid random reroll that carries stats and a timer skip that buys progress, and none of the notification, invite or update hooks exist. Reviewed 2026-10-23 from `docs/systems/monetization.md`, identity, garden, seclusion, sect (branch) and `src/server/Analytics.luau`.

## Why players come back (what exists)
- **Tomorrow (D1):** a daily login qi bonus (50% of the dantian, `Cultivation.luau:485`), offline cultivation (12 h cap), offline garden growth and long herbs. Sect dailies are QC5+, on the branch.
- **Sessions per day:** garden timers and weather events. These are the right hooks, but nothing *tells* a player away from the game (no `ExperienceNotificationService`).
- **D8-28:** the realm ladder (about 30 h to FE9), Herbarium pages, regional seeds, the sect rank. There's no weekly goal (weeklies deferred) and no timed bosses on a schedule.
- **Streaks:** the seclusion streak resets to 1 on a missed day (`Seclusion.luau:164`). It's a bonus only, but a reset streak is on the research's avoid list. Make it pause.
- **Missing:** a "come back tomorrow" line at session end, badges, a like prompt after the first breakthrough, the group-join perk, update codes and a countdown.

## Monetization (what's for sale)
- **Change Race, 299 R$ (`Products.luau`): paid randomness, with power.** It rerolls race *and variant*, and variants carry traits and stat modifiers (identity.md "Variants carry traits"). That's the exact category the research says to avoid entirely: random, bought with Robux, under 2026 regulatory pressure. There's no `PolicyService` `ArePaidRandomItemsRestricted` check (grep: none), so restricted players get nothing instead of a fixed path. An odds card exists. That's necessary, but not sufficient for a kids' game.
- **Change Last Name, 99 R$:** a random clan. Check whether clans carry anything. If cosmetic, sell it as a *pick*, not a roll.
- **Grow now, 3-9 R$:** buys qi, Herbarium stones and permanent foundation experiences on long herbs (see garden-and-herbarium). Stat power for Robux.
- **Accepted items not offered:** auras, robes, peak sets, emotes, extra plots, auto-harvest, a VIP pass, a pass with a free track. The building roadmap already plans "a few cosmetic robux items". Lead with those.

## Instrumentation
- Good: the onboarding funnel (11 steps to QC4), realm progression start/complete/fail, and session length, deaths, breakthrough timing and tribulations as custom events.
- Gaps: no `LogEconomyEvent` anywhere (stones and raw qi sources and sinks, the Pavilion, herbs), no shop funnel, no party, sect or garden events. The funnel stops at QC4: add first plant, first harvest and the board.

## Recommendations (ranked)
1. **Remove all paid randomness before launch.** Race and variant are earned or chosen (free pick at creation; later changes for stones or a fixed Robux price for a *chosen* race). Clan is a chosen cosmetic. Grow now can't touch long herbs or first-discovery credit. Add a `PolicyService` check regardless.
2. **Ship one honest cosmetic line instead:** an aura and robe set plus one peak set, fixed price, shown on the player card and the peak. Status items for teens sell without harming D1 or play-through.
3. **Wire the out-of-game hooks:** opt-in notifications (13+, after the first harvest: "your herbs are ready", "a storm is coming"), `PromptGameInvite` (party review), a like prompt after the first breakthrough card, a session-end "tomorrow" line (the board refresh, the herb ripening, the daily qi).
4. Add economy events for stones and raw qi (every faucet and sink) and extend the funnel through the first harvest and the first sect claim.
5. A weekly beat: a rotating Herbalist seed and one scheduled world boss on Fri-Sun. Make the seclusion streak pause, not reset.
