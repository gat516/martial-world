# Review: breakthrough and the foundation grade

**Owner's decision (2026-10-24), rec 3:** foundation is shown as the percent only ("Foundation 86%"): no grade words, no count/target, anywhere; the bar with its 50/100 marks and overfill stays. Built ([cultivation](../systems/cultivation.md#foundation-grade)).

**Verdict: rework the feedback, keep the idea.** "What you lived through this stage makes you stronger" is the right fiction and the right counter to AFK. But the first breakthrough in the game is stamped "Unsteady foundation 0%". Experiences are earned silently. One idea is shown three ways (percent, word, count/target). On the live map, QR and FE can't reach a full foundation. Reviewed 2026-10-23 from cultivation.md "Foundation grade", `Foundation.luau`, `Pacing.luau:760-842`; nothing played.

## Why it exists / who it's for
- Arrow: it pays out (hunt, explore, events) and home (harvests, the Herbarium), and it rewards range over grinding (Hunter's `perKind` 4, `FIT_BELOW`). Good design: deeds ask for variety, and the Haul deed (bank 75% of a dantian) is a real risk decision.
- It serves explorers and completionists (Discovery, Achievement). The gardener road can reach 100% (Gardener, Haul, Home, Dao).

## Problems
- **The first milestone reads as a failure.** QC1's target is 2 (`Pacing.luau:805`). Onboarding breaks through at about 1:15, before any fight (onboarding.md:86), and nothing is earnable before then. So `Foundation.seal` (`Foundation.luau:198`) stamps 0%, and the card shows "QC2 · Unsteady foundation 0%" (`BreakthroughView.luau:212`). Worse, the unsteady toast fires 4 s after the bar fills (`Cultivation.luau:583-586`). QC2 and QC3 (target 3, minutes long) will mostly read Unsteady or Steady too. The game's three biggest first-session highs get a scolding.
- **No feedback when you earn it.** "Earning gives no toast" (cultivation.md:202). Players learn by doing, so an invisible reward is no reward. The player can't connect killing an elite boar with getting stronger.
- **Too many representations.** A percent up to 200, four grade words, count/target on the Self card, 7 categories, 4 deeds, 5 bands, hints. The elder can't say that in one sentence (roadmap principle 6). And "Unsteady" is the negative label the owner wanted to avoid ("so it isn't super negatively viewed").
- **Invisible per stage, large in total.** +2-4% a stage can't be felt in a fight, yet 26 stages sum to as much as +104%. A player who explored at 50% ends FE9 about 1.6x weaker than a maxed one, the size of five minor stages. That's fine as a reward, but the only catch-up is the heart demon (+75 points over 3 stages) and seclusion tempering isn't built.
- **The live map can't fill it.** With `Config.Wilds.VARIANTS` off there are no beasts at QR/FE realms, so Hunter, Daring and Hunt are impossible there (cultivation.md "Gaps"). QR/FE stages land at about 40-60% and fire the unsteady toast at almost every stage.

## Metrics
It hurts the first 10 minutes as built (negative copy at the milestone). It could help D7-28 a lot (a reason to explore each new band) once it's visible. Instrumented only through the card; there's no analytics event for percent at seal.

## Recommendations (ranked)
1. **Don't grade the hook.** QC1-3 seal at 100% with no grade on the card (or a target of 0), and the unsteady toast only from QC4. That's three lines in `Pacing.Foundation.TARGET` and the toast check.
2. **A tiny earn pop.** "+ Foundation" with the category icon on the same toast channel, once per experience. No new HUD.
3. **One representation.** Keep the percent and drop the words, or show 1-3 lotus pips on the card. Never print "Unsteady". If words stay, use only positive ones (Steady, Solid, Deep, Profound).
4. Until variants ship, `DEFAULT_TARGET` 3 for QR/FE, so the band pools and deeds reach 100%.
5. Log `FoundationSealed` (stage, percent), so tuning has data.
6. Build seclusion tempering or a band revisit as a second catch-up road (roadmap already lists it).
