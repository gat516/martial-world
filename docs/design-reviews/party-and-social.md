# Review: parties and social

**Verdict: keep with changes.** The rules are right: shared credit, no kill-stealing, PvP off, no trading, qi scaled to each player's realm. But it's server-local and has no Roblox invite, so it does nothing for the co-play-days ranking signal. Its whole UI is unbuilt. Reviewed 2026-10-23 from `docs/systems/party.md`, roadmap 3e/3f and code; nothing played.

## Why it exists
- Arrow: out (the hunt) is better together: helpers get qi, there's a small group bonus, and Join rides you to a member. Visiting a peak links to home.
- Who: the social player and kids playing with real-life friends. Relatedness is the one SDT need the game barely serves today.

## Is it fun
- **Kill credit is genuinely good.** Every 10%+ damager gets a full own drop, and seniors earn at their own realm (`EnemyService.died`). It kills the classic Roblox grief and makes "help a newbie" free. Keep it exactly.
- The group bonus is small (+5% per member, cap 15%). Correct: a party should never feel required.
- What's missing is a *shared goal*. A party of four hitting wolves is four solo players standing close. Co-op rifts, roaming beast kings and group events (roadmap 3e) are where it would become fun, and none are built.

## Cost
- New UI: the card, People tile, invite prompt, party pips, Join button and friend toast. The People tile and the pips are two more HUD elements on a HUD that is already over budget.
- Tapping a character to open the card competes with combat taps on touch.

## Failure and abuse
- **Invite spam:** a 2 s cooldown per inviter and a 30 s expiry. One player can still re-invite the same kid every few seconds. Add a per-target cooldown (60 s after a decline) and a "no invites" setting.
- No PvP, no trading, no free text. The design is griefing-proof. Good.
- No-chat players: the card and invites work without chat, but there's no way to say "follow me" or "boss here". Add 4-6 quick pings/emotes.

## Metrics
- **Co-play days count only friends who join through invites, joins or private servers; matchmaking doesn't count.** Nothing calls `SocialService:PromptGameInvite`, and there are no private-server perks (grep: none). A party with a stranger in the same server earns zero co-play credit.
- The friend nudge ("<name> is on this mountain") is good, but only fires if the friend already came.
- Not instrumented: there's no "party formed" funnel step or event.

## Interactions
- Visiting peaks overlaps with build and garden (gifting). Do them as one feature: visit, admire, gift a herb.
- `stats.partied` feeds the heart demon. Fine.

## Recommendations (ranked)
1. **Add "Invite a friend" (`PromptGameInvite`)** to the People list, the card and the party pips, and give a small, once-a-day "friend joined you" reward (stones, never qi) to *both* players. This is the cheapest direct lever on a top ranking signal.
2. **Free private servers plus a "Join friend" path from the Roblox friends list.** Make sure a join-by-friend lands next to the friend (it already does by array) and auto-offers a party invite.
3. **Ship the smallest UI first:** the player card (with Invite and Visit) and the invite prompt. Skip the People tile (the card opens from nameplates) and keep the pips as names on the existing nameplates, not a new HUD stack. Add a 4-ping quick wheel for no-chat play.
4. Add a per-target invite cooldown and a Settings toggle, "Accept invites from: everyone / friends / no one".
5. Add a funnel or custom event for party formed, friend joined and invite sent.
