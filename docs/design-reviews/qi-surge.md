# Review: the qi surge

**Verdict: rework (or cut).** The fantasy is right: burn your qi to survive and keep your haul. But the rule rarely lets it fire, and when it does, at 24 of 26 stages it does almost nothing but heal 20%. A once-in-a-while mid-fight button nobody has learned is a phone-HUD cost with little feeling behind it. Reviewed 2026-10-23 from cultivation.md "Qi surge", `QiSurge.luau`, `Pacing.Surge`; nothing played.

## Why it exists / who it's for
- It replaced the forced breakthrough and qi debt (good riddance). Arrow: it protects the haul, so it feeds "come home". It's meant for the fighter in a clutch moment: competence and drama.

## Problems
- **The ready window is tiny.** It needs all of: in combat, health at most 35%, bar at least 90%, not used this engagement (`QiSurge.luau` `blocked`). The bar sits in the 90-100% band for roughly the last tenth of a stage. Most players with a full bar go home and break through, because that's the loop. So most fights never offer it, and players won't learn a button they see a few times in 30 hours.
- **The effect is near-invisible at most stages.** "The next stage's stats" is +10% health and power at minors (`Pacing.Curve`). The real payload is the 20% heal. At stage 9 it's x2.25 (QC9 to QR1 stats), a huge spike. One button with two wildly different strengths isn't readable.
- **The decision is shallow.** 25% of raw qi to avoid spilling 50% of the haul is always worth it, so it's not a choice, only a reaction.
- **HUD and input cost.** A new button appears mid-fight in the touch cluster, the worst moment to add one on a phone (3-4 attention items). On PC, M is both Meditate and Surge depending on hidden state.
- **Gaps:** combat qi doesn't follow the surge. It's another "qi" word (surge, combat qi, raw qi, deviation). The heart-demon surge question depends on it.

## Metrics
Neutral to slightly negative: no effect on the first session, little on retention. It could add a highlight moment (comeback clips) if it fired often enough to matter.

## Recommendations (ranked)
1. **Drop the bar gate; make it a flat second wind.** Once per engagement, at health at most 35%, from QC2: heal 30% and +25% power for 10 s, burning 25% of raw qi. The same at every stage, so one sentence teaches it: "Hurt badly? Burn your qi to fight on." Keep the plaque glow, not the next-stage name.
2. **Teach it once, scripted.** The first time it becomes ready, slow time briefly and pulse the button with one line. Otherwise the button stays hidden.
3. **Give it its own key on PC** (or make M surge only, never meditate, while in combat). Never overload meditation on one hidden condition.
4. If 1 is rejected: **cut it.** The spirit ring and the half-spill already make death cheap enough, and the touch cluster gets a slot back.
