# Design review: the haul, Store all, death spill, spirit ring, combat-leave

**Verdict: keep with changes.** It is the right kind of death cost: momentum, not banked progress, reclaimable, and rare finds always safe. But it punishes phone disconnects, hides its best beat behind silent banking, and the ring is a decision about the wrong items.

## Why it exists / arrow
- "Today death costs nothing, so surviving a fight doesn't matter" (roadmap Phase A). It gives "come home" weight in the loop. The arrow is strong: it turns the walk home into a beat.

## Who it's for
- Hardcore: tension on a long trip. Casual and kid: a small sting with a quick way back (the 5 min spill). Gardeners at home are never touched. Loss aversion is handled as the research says: what's lost is time, and banked progress is safe.

## Is it fun?
- Good: the spill as a spirit-light only you can reclaim. No looting and no griefing. That is a short comeback quest.
- **Store all, the satisfying "sell all" beat, rarely shows.** Riding any array banks silently (`haul.md` Design intent), and arrays are how everyone goes home. The doc admits "walking home is where the Store all beat mostly shows". Most players will see it only in onboarding.
- **The ring decision is weak.** It protects herb and item stacks (2 slots at QC), but the big losses are raw qi and Spirit Stones, which can't go in. And the rare herbs are already safe (`SAFE_RARITY`). The choice is between low-stakes stacks: a menu step, not a decision.

## Cost
- New words: haul, Store all, spill, spirit ring. "Spirit ring" is the extra one. It needs an Inventory button, cell seals and a pane line (`inventory.md`).
- Server: snapshot every 0.5 s. That's cheap.

## Failure and abuse
- **A disconnect while tagged loses half the haul outright, with no spill** (`Haul.leaving`). 72% of play is mobile, where drops, app switches and "dinner!" are routine. That turns a punishment meant for cheaters into a feel-bad for kids. Six seconds of combat tag (`IN_COMBAT_SECONDS`) is often, because landing damage also sets it.
- **A second death before you reclaim deletes the first spill.** Boss attempts are exactly when two deaths happen back to back. The second loss stacks to ~75%.
- **The death screen doesn't say what spilled.** Only a toast after the respawn does (Known gaps). The research is clear: show why you failed and the way back, at the moment of failure.
- **The doc is wrong about spending.** `Haul.luau:188-192` sets `banked = min(banked, held)`, so spending eats the *unbanked* haul first, not the banked part as `haul.md` says. Refining raw qi at a wilds node therefore banks it. That is fine as design (a node becomes a waystation and a real choice: refine now or push on), but it should be intended and said.

## Metrics
- D1/D7: a fair death cost raises session tension. An unfair one (a disconnect) raises churn. Track `spills`, `reclaimed` and `fled`: they are already in `data.stats`, so send them as analytics events too.
- Sessions per day: a pending spill or an unbanked logout ("Store all for it" next join) is a mild return hook. Good.

## Recommendations (ranked)
1. **Turn a combat-leave into a spill, not a loss.** Write it to `data` at the spot, and the next join gets it for 5 minutes. A cheater gains nothing (they still have to walk back into the wilds), and a dropped phone loses nothing permanent.
2. **Every bank shows the summary.** An array ride plays the flare and "Stored: 120 raw qi, 40 stones" on arrival, so the beat happens every trip. The prompt stays for walking in.
3. **Merge spills on a second death** instead of deleting the first one.
4. **Put the spill on the death screen:** "Half your haul waits where you fell: 4:59", with the amounts.
5. **The ring: hold a share of raw qi or stones, or cut it** until materials exist. As built, it adds a word and a button for herbs.
6. Fix the `haul.md` wording and decide on nodes as waystations. If you keep them, one elder line: "Refine at a node and the wild can't take it."
