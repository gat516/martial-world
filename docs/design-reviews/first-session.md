# Review: the first session (join to QC4)

**Owner's decision (2026-10-24):** rec 2 (hook noise) and rec 5 (elder lines) built in [onboarding](../systems/onboarding.md): Maze only below QC4, objectives at most 5 words, elder lines at most 12, the foundation introduced on the QC4->5 card. The front door (recs 1, 3, 4) and the HUD tiles (rec 6) are their own branches.

**Verdict: rework the front door; keep the hook with cuts.** The hook is well built: a guaranteed breakthrough, never-blocking beats, a guide all the way. But a new player spends nearly all of the 0-180 s bounce window in menus. They meet 11-13 mechanics and about 260 words before QC4, and the objectives are cut off on a phone. Reviewed 2026-10-23 from docs and code; nothing played or timed.

**Why it exists:** to teach the loop in about 10 minutes and cross the Creator Rewards line. That arrow is right. The hard case is a 9-year-old on a phone with no chat.

## Good
- The first run fills the bar (`FIRST_RUN_FILLS_BAR`), so visible power comes about 75 s from spawn. That's the genre's hook.
- The favourite prompt comes at the root reveal (QC3), never at spawn.
- Gate wolves: 3 of them, 8 s respawn, shared credit, a refine node about 100 studs away.
- The seclusion card plus a growing seed gives a "come back later" ending.

## Problems
1. **Join to the first action takes 1.5-4 min.** On a first join: a slot screen of empty cards, then Appearance, Hair, Fate, and a name typed on a phone keyboard. Then Cultivate, Circulate, a 3-2-1 count-in and the maze. Combat comes about 2:00 after spawn, so 2.5-5 min after join. The circulate-first order alone would meet "earning within 30 s"; **the creator is the breach.**
2. **The bounce point isn't measured.** The funnel's "Joined" fires only after a slot is played (`Main.server.luau:157-169`). Players who quit in the creator are invisible.
3. **A Robux button before the first play.** The Fate step has paid, random, stat-carrying rerolls (299 and 99). There's no `PolicyService` check anywhere in `src/`. See [retention-and-monetization](retention-and-monetization.md). **Challenges a decision.**
4. **Mechanics.** The doc counts "five (six with the haul)". My count before QC3: sit, Maze, break through, the travel menu, strike, dodge telegraphs, cast (hotbar, combat qi), Store, refine at a node, purging impurities, and **an unexplained second minigame**. `pickGame` excludes the last game (`Circulation.luau:45-54`), so the Refine run can't be the Maze. Then the root (grade, element, perk). Guard, Build and the Herbarium are on screen, untaught.
5. **The first win carries a failure word.** The breakthrough subtitle prints the foundation grade (`BreakthroughView.luau:212`). QC1 needs 2 experiences and none can happen before a kill, so the 1:15 milestone likely reads "Unsteady foundation".
6. **Reading.** The auto lines total 185 words: 16-23 words each, 2-3 sentences, against "one sentence per prompt". There are about 28 jargon terms (dantian, meridians, haul, array, raw qi, formations...). FirstKill gives three orders in one line.
7. **Objectives don't fit.** The tracker is 13 px and cuts off at 205 px, about 30 characters (`ui.md`). The Circulate objective plus its reward runs about 90.
8. **Overlay time.** Four or five runs are about 4 of the first 10 minutes spent in a full-screen minigame, not the world.

**Metrics:** the first 180 s are all menus, the worst case for the bounce penalty. QC4 lands about 11-13 min from join; QC3 and the root (about 7-9 min) are the felt milestone in time. D1: the seclusion and garden ending. Nothing needs chat.

## Recommendations (ranked)
1. **Join to world in ≤20 s.** If an account has no slots, skip the slot screen. A first character gets one screen: the free race reveal, a prefilled random name (editable, no keyboard needed) and Enter. Appearance and Hair move to Edit look.
2. **Hook noise pass.** Maze only below QC4 (`pickGame` returns `FIRST_RUN_GAME`), with the other games taught one per breather. Hide the foundation grade until the QC4→5 card. Objectives: verb plus noun, at most 5 words, with the reward as an icon and number.
3. **Funnel the front door:** add steps for slot screen, creator opened and Enter World, plus `TimeToFirstKill` and `TimeToQC4` events. Otherwise recommendation 1 can't be judged.
4. Hide the paid Change buttons on a first creation.
5. Elder auto lines: one sentence, at most 12 words; the detail stays in Talk.
6. Reveal HUD tiles as they're taught (Herbarium, Build, the guard trough). See [hud-and-menus](hud-and-menus.md).
7. A/B test a wolf pup on the player's peak before Circulate (combat in about 10 s, its qi feeds the first run). **Challenges a decision** only if the data says so.
