# Review: circulation minigames, meditation, refining and the dantian

**Verdict: keep the minigames for the hook, rework refining after QC.** The four games are juicy, one-thumb, phone-first and a great first action. But refining is mandatory, it never changes after FE1, and it runs about 530 times on the way to FE9. That's 5-6 hours of a solved pattern. The skill band also cuts a weak player's income by more than half. Reviewed 2026-10-23 from minigames.md, meditation.md, cultivation.md "Data flow", `Pacing.Refine`; nothing played.

## Why it exists / who it's for
- Arrow: the loop itself. Raw qi from out becomes progress at home or a node. The dantian cap is a good wall: it sends you home when it's full and out when it's empty (core-loop "Walls").
- The first-run Maze (guaranteed, easier than easy) is a textbook first action: it serves competence and gives a number going up inside 90 s. Keep it.

## Do they earn their place?
- **Early (QC1-QC5): yes.** It's new, it's juicy (pops, gong, purges), and the variety of four games keeps it fresh for the first hour.
- **After that: no, it's a tax.** The runs column in `Pacing.luau` sums to 69 (QC) + 157 (QR) + 308 (FE) = **534 runs**, each up to 45 s (`LEVEL_SECONDS` 15 x 3). Difficulty reaches 0.89 at QC9 and is capped at 1.0 from FE1. Nothing new to learn for about 25 hours: the pattern is solved and boredom follows.
- **Skill gates income.** Efficiency runs from 0.5 to 1.3, plus 20% for a full clear (`Pacing.luau:336`). A weak player gets about 38% of a strong one's cultivation per raw qi. A kid on a small phone isn't barred, but they're heavily taxed on every hunt. Deviation below 0.35 stacks a 20 s lockout on top.
- **Meditation** is clean (sit, multiplier, calm view, at most 5 tiles). But its "idle-safe" promise is broken by the 10-min AFK rule (see afk-seclusion-offline). Three seated modes (meditate, seclusion, practice drill) plus a nested Practice row are near the limit for a kid.
- **Qi overload.** Raw qi, cultivation, combat qi, overflow, qi nodes, qi deviation, the qi surge: one word does seven jobs.

## Metrics
A strong first 60-180 s. A negative contributor to D7-28 session quality, because it's a repeated chore that pads time without adding learning. Score is logged (`CirculationScore`), so the decline can be watched in analytics.

## Recommendations (ranked)
1. **One run refines a whole dantian from QC5.** Set `RUNS_PER_DANTIAN` from 2.5 to 1 at QC5 and up (a per-stage field or a curve change). That's about 2.5x fewer runs for the same income: one knob, the biggest win.
2. **Raise the floor.** `EFFICIENCY_MIN` 0.5 to 0.8, and soften deviation to "no gain" instead of a lockout. The skilled ceiling stays, so mastery still pays, but kids aren't halved.
3. **A seated "steady breathing" option** (from QR1): refine the dantian with no minigame at 0.8 efficiency over 60 s, while the minigame stays the faster, better-paying road. That gives the player a choice and gives mobile a way to rest.
4. One new circulation game at QR1 and at FE1 as an update beat (new pattern, new mastery), and let the player pick their game once they own two (autonomy).
5. Rename for clarity: combat qi becomes "spirit" (or "energy") on screen. Cultivation is the bar; qi is only the dantian.
