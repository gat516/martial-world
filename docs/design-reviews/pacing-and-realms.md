# Review: pacing and realms

**Verdict: keep with changes.** The shape is right: three breakthroughs in ten minutes, a sawtooth per third, +10%/stage and x2.25 per major. But realm suppression kills co-play between friends of different majors, the curve breaks its own "bars never go down" rule, and heaven-defying is a tax with no real perk. Reviewed 2026-10-23 from `Pacing.luau`, progression.md, combat.md, roadmap section 1; nothing played.

## Why it exists / who it's for
- It is the spine (core-loop: "the loop itself"). Visible power every stage feeds competence for everyone; the realm label is status for teens.
- Good: the hook (QC2 ~1.5 min, QC4 ~10 min, `Pacing.luau:37-45`) matches the research's "first milestone inside 10 min". The 12 h night fills the 150% overflow cap at nearly every stage, so **every return opens with a ready breakthrough**. That's the best D1 hook in the game. Keep both exactly.
- Good: garden aura (up to +150% passive, online, anywhere; `Config.luau:321`, `Cultivation.luau:216`) against keeping plants unharvested is a real trade for the mid-QR slowdown.

## Problems
- **Suppression blocks cross-realm co-play.** A QC friend deals 0.2x to QR beasts (`Pacing.luau:290`), needs 10% of a beast's health for credit, and takes full damage from beasts 2.25x their stats. A QR player can't take a newer friend out at all. Intentional co-play days are a top-ranked signal, and "friend invites a newer friend" is the most common case. Party helper qi doesn't fix the newer friend dying and spilling their haul.
- **The cliff.** QC1 to QC9 is about 4.6x in total. QC9 against a QR1 beast is about 25x (11x the hits, 2.2x the damage). That's fine as fiction. But the Danger bar is the only warning, and nothing on the phone says why your hits read 20%.
- **The rule is broken.** "Bars never go down" (`Pacing.luau:101`; cultivation.md) is false at QR7 54,500 < QR6 79,500 (`:240`), FE4 < FE3 (`:252`) and FE7 < FE6 (`:258`). The CARRY_SHARE comment assumes the rule (`:467`). Either the rule or the curve is wrong. Breathers are good sawtooth, but a smaller number on the bar reads as regression to a kid.
- **Heaven-defiers pay for nothing.** Half resist turns 0.2x into 0.6x per major, but a beast one major up still has 2.25x stats and hits a heaven-defier at full. They still can't farm above their level. Net effect: 1.5x every bar (about +15 h to FE9) plus a tribulation at every major. Nothing sets the flag yet; if a reroll or bloodline can grant it, a kid can take a big slowdown without knowing it.
- **The cap comes early for the players who matter most.** At 2 h a day with nights, FE8 arrives on day 9 (`Pacing.luau:113`). The D8-28 window is decided by exactly these players, and FE9 is `PEAK` with nothing after it.
- **Signposting.** QR5 doubles the bar right after the QR4 breather (26,000 to 53,500), and nothing tells the player the garden aura is the lever.

## Metrics
D1 strong (morning breakthrough), D8-28 at risk for heavy players (cap), co-play days hurt by suppression. It does carry update beats: each new region and major is one.

## Recommendations (ranked)
1. **Party shelter.** In a party, realm suppression is waived between beasts and any member below the strongest member's major. The junior hits at their own stats and is hit as if the beast were their major. This brings back co-play without power sharing (*challenges a decision*: suppression "both ways").
2. **Make breathers ease the bar without shrinking it.** Breathers keep a bar at least the previous one's and get a row `gather` (like QR1-2) instead: QR7, FE4, FE7. Then fix the comments.
3. **Give heaven-defiers a real perk or a smaller tax.** Either they take 0.6x suppressed damage from beasts one major up (so they can actually fight above), or the bar drops to 1.25x. The flag must be an explicit, warned opt-in.
4. Objective line at QR5: "Your garden's aura speeds you. Let herbs mature." One line, no new HUD.
5. Plan a post-FE9 loop (apex gauntlet tiers, Herbarium and Dao collections) before FE ships, or slow FE nights (`OFFLINE_RATE` 0.75 at FE).
6. One toast the first time a hit is suppressed: "Their realm is above yours."
