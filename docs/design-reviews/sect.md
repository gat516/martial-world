# Review: the sect MVP

**Verdict: keep with changes.** Rank, soft dailies and a region chain with a peaceful path beside every combat step are the right MVP, and the anti-nag rules are exemplary. But it's a solo NPC quest board named "sect": no other player is in it. Reviewed 2026-10-23 from branch `sect-mvp` (`/home/cj/roblox/mw-sect-mvp/docs/systems/sect.md`, commit 0b1a5fe); nothing played.

## Why it exists
- Arrow: it sends you out (hunt, gather, the cache rumour, the chain's places) and home (herbs, harvest, seclusion, Store all), and pays stones and Pavilion goods. That's a clean, two-way arrow.
- Who: casuals at week 1 (something to do today), teens (rank as status), both roads equally. It serves competence and autonomy. Relatedness is absent until Halls exist.

## Is it fun
- Good: "take any, a lapsed daily costs nothing", at most one combat daily, rank by contribution *earned*, so spending never demotes. A weekly cap (700) stops grinding. "Never qi" keeps the curve honest. These are the right choices for kids and the research's dark-pattern list.
- Good: the chain "Ash Past the Gorge" is the exploring voice the core loop says is missing (core-loop "Why it felt messy" #3).
- Weak: the dailies are counters ("harvest 4", "3 node gathers") the player would do anyway. They pay, but they don't create a decision or teach anything new. The "seclusion: an hour" daily pays for AFK.
- **Opens at QC5**, after the first session for most players. The first daily, the strongest D1 hook a quest board offers, arrives on day 2 or later.

## Cost
- New words: rank, contribution, Pavilion, chain. They're taught one at a time at QC5. Acceptable.
- No HUD entry to the quest log (Known gaps). Good for the budget; tracking via the objective line is the right channel.
- Overlap: the board now holds the goals list, onboarding lessons, dailies, the chain and the Pavilion. The core loop asks for "the current wall first and at most two other goals". Make sure the sect board obeys it.

## Failure and abuse
- No penalty or streak loss. Good.
- The Pavilion seed packet is "one herb of the tier, rolled". That's random, but bought with earned contribution, so it's outside paid-random rules. Keep it that way: contribution must never be buyable.
- UTC reset: for US evening players the day flips mid-session. That's fine, but say "new tasks in 3h" on the board.

## Metrics
- D1/D7: dailies plus a weekly cap are the standard daily rhythm. The value depends on the board being reached early.
- Co-play: none. Sect-wide goals and Halls are the co-play features, and both are deferred.
- Instrumented: claims route through `Quests.onClaimed`, then `QuestClaimed`. Add a sect funnel (board opened, first daily, first claim, Inner Disciple).

## Recommendations (ranked)
1. **Open a starter board at QC3-4**, one peaceful daily only (the harvest or store task), so the first session ends with "come back tomorrow, the board refreshes". Keep the full board at QC5.
2. **Pull one sect-wide goal into the MVP:** a server storehouse bar ("fill the storehouse: 0/200 herbs or cores"), where every contributor gets a small reward when it fills. That's one bar on the board, no new HUD, and it's the only part of the sect that makes other players matter.
3. **Make dailies ask for range, not counts:** "harvest a herb you haven't this week", "bank a haul from the Borderlands", "defeat a beast at your realm". Rotate a weekly theme as an update beat.
4. Add the sect funnel steps; show the reset time on the board.
5. Replace the seclusion daily with an active home task (refine at the peak, plant three seeds).
