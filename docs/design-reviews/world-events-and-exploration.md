# Design review: world events, caches, regions, the "explore" verb

**Verdict: rework.** The core loop calls Explore half of going out and the source of most long-term goals. As built, it is five one-time caches, seven qi nodes, and 27 dressed "finds" that pay nothing. World events are first-come races that seven of eight players lose. **Challenges a decision** (first-come events).

## Why it exists / arrow
- Explore is "the 'what's over there?' pull" (core-loop "Explore"), and events are "surprise loot during trips". Both point into the loop. The arrow is right; the payload is missing.

## Who it's for
- The Discovery motivation, kids who love finding things, and social players (events as meeting points). This is the most social and most thumbnail-friendly system in the game (sky arrays, light pillars).

## Is it fun? What's there today
- **Caches:** five manual caches in the Inner Wilds and a plaza weapon rack, each claimed once per player (`weapons.md` World anchors). After one sweep, Explore is spent.
- **Finds:** F1-F27 (a sword in the rock, a meditation mat under a lone pine, a spirit-beast skeleton…) are tagged `POI` Kind `Find` and are pure dressing (`inner-wilds-rework.md` "Finds"). Every "what's over there?" gets answered "nothing", which teaches players to stop looking. This is the biggest gap in the slice.
- **Signposting:** the Rumours lesson is one QC8 quest with no guide, by design (`onboarding.md:355`), and core-loop "Why it felt messy" #3 says "nothing hints at them".
- **Events:** the Auspicious Clouds kinds are the only ones on the timer (rolled every 20-35 min). Ginseng and Beast Surge have no timer weight (`world.md` Known gaps). "First to claim keeps the prize" (Design intent). The look is excellent and readable from the peaks. The payoff structure is the problem.

## Cost
- On screen: the event scroll, a countdown ring, a pin and an edge chip, all only while an event runs. That's acceptable. The far-read sky work is already paid for.

## Failure and abuse
- **First-come on an 8-player server:** one winner, seven who ran 1,000-1,900 studs for nothing. The losers are the youngest and slowest players. The research says co-op over competition, with no contested nodes. Roadmap 3e already wants "rewards scaled to each player's realm", and `world.md` contradicts it.
- **Random timing** gives no appointment. Players can't plan a return for an event they can't predict.

## Metrics
- D7/D28: one-time caches add no return value. Repeatable finds and scheduled events are the cheap return hooks (Grow a Garden's 5-minute global restock; timed bosses).
- Sessions per day: an event on a known clock is the strongest lever here.
- Thumbnail and update beat: events are the best material in the game. Each new event or variant is a weekly beat.

## Recommendations (ranked)
1. **Make the finds pay, per player, daily.** On a find's first visit: a Discover foundation experience plus a page in a Wilds Journal (silhouettes for unvisited ones; Herbarium pattern). After that, a small daily roll there: stones, a herb or seed, rarely a manual. It reuses POIs that are already placed and the existing reward path.
2. **Shared event rewards.** Everyone who meditated in the ring or hit the guardian gets a realm-scaled reward. The first claim adds a flourish (a title or a stone bonus), never the whole prize. Brief: one change in `WorldEvents` finish, plus the claim.
3. **Put events on a clock.** For example, one at :00 and :30 server time, shown on the quest board and the event scroll ("Golden Clouds in 12 min"), with Ginseng and Beast Surge in the rotation. A predictable appointment is a reason for another session.
4. **Give rumours a voice early:** one elder or board line per region pointing at a cache ("an old blade rests where the hunters camped"). It costs words only.
5. Make caches respawn their *stones* daily while the manual stays one-time, so a cache stays worth a detour.
