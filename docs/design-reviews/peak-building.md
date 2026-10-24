# Review: peak building

**Verdict: keep with changes.** Expression and a home are the right long tail for teens and creatives. But today it's a stone sink with a hidden score, no moment, no audience and an empty catalog of looks. Reviewed 2026-10-23 from `docs/systems/build.md` and code; nothing played.

## Why it exists
- Arrow: a better home (peak score adds meditation and growth, `Pacing.PeakScore`), plus a stone sink. That's legitimate, but the bonus is a capped background number. The real reason to build is showing off, and nothing shows it off yet.
- Who: Creativity and Achievement players, mostly teens. Kids enjoy placing things but need a goal. Autonomy is high; competence is weak (no feedback on "good"); relatedness is zero until visiting works and someone visits.

## Is it fun
- Good: server-authoritative placement, a green/red ghost with the reason, snapping and support chains. The tooling is solid.
- The decision is thin. The score is items × category points with `PER_ITEM` 5, so the dominant play is "buy five of each cheap high-category item". That's spreadsheet building, the opposite of expression.
- **No moment.** A tier change is silent (build.md Known gaps), and QC and QR peaks are bare rock with no template. The biggest payoff of a major breakthrough, "your peak grew", doesn't exist for 2/3 of the ladder.
- No themed sets have items yet, so the catalog is about 40 loose pieces.

## Cost
- One top-right tile (contextual, near your peak; that's fine). One more currency use. A large content pipeline (60-80 pieces) before it pays off.
- The phone build UX is untested at 3 tiles per row (844x390). Precise placement on a phone is the hardest UI in the game.

## Failure and abuse
- No griefing: only you build, and visitors get no rights. Good.
- Select risk is low. The 2024 policy keeps under-13s away from free-form *2D drawing/creation*, not catalog placement ([TechCrunch](https://techcrunch.com/2024/11/07/roblox-adds-new-safety-measures-to-ban-kids-under-13-from-social-spaces)). Keep it catalog-only, with no player text on signs.
- Loss aversion is fine: storing returns pieces.

## Metrics
- First session: none (not taught until later). Correct.
- D8-28: a strong *potential* hook (sets unlocked by realm and rank). Today it's empty.
- Co-play: visiting exists in the backend with no UI, so there's no co-play signal yet.
- Update beats: themed sets are ideal weekly drops, and an honest thumbnail of a cloud palace peak would sell.
- Not instrumented: no economy event for build spend, no event for placements or tiers.

## Interactions
- The peak score overlaps the garden's own boosters (garden pieces with `growth`/`luck`) and the seclusion growth bonus. These are three growth levers in one place. Players should get one readable line, "Your abode: +x% cultivation, +y% growth".

## Recommendations (ranked)
1. **Make the tier-up a moment:** on the major breakthrough, cut to the peak transforming, with a one-line banner and the new room ring. Build the QC and QR templates first. It costs one VFX beat plus two templates and carries the breakthrough spectacle home.
2. **Score sets, not counts:** completing a themed set (even a 5-piece one) gives a big chunk of score plus a named title ("Jade Pavilion abode"). Lower `PER_ITEM` to 2-3. That turns the score into a collection goal with silhouettes in the catalog.
3. **Ship visiting with a reason:** "Visit peak" on the player card, a "Visit a friend's peak" row in Travel, and a one-tap "admire" (a like) that gives the owner a few stones a day. That rewards builders through other players, works with no chat, and adds a co-play reason.
4. Put the peak-score bonus in one line on the Self card's cultivation column, not only the catalog gauge (hidden on phones).
5. Add `LogEconomyEvent` sinks for build purchases.
