# Review: AFK, offline and seclusion

**Verdict: keep with changes.** "AFK = offline = plain passive, capped at 12 h and the overflow" is the cleanest rule in the progression. A night is worth about one stage, so every return opens on a ready breakthrough. Keep that. But meditation is sold as "leave it running" and silently drops to 1x after 10 minutes. The online-only mutation rewards leaving a phone on. Seclusion is a tap you should always make, so it's a tax, not a choice. Reviewed 2026-10-23 from seclusion.md, `Pacing.Income`, `Pacing.Seclusion`, `Cultivation.luau`; nothing played.

## Why it exists / who it's for
- Arrow: home. Offline growth is the proven return hook (Grow a Garden). The seclusion card gives a clean session end and a "my garden grew" opening. It's for casuals, gardeners and mobile players: autonomy without punishment.
- Good: AFK never beats active play, nothing breaks through alone, and the overflow carries. These match the research exactly.

## Problems
- **A hidden rule against meditation.** meditation.md:8 says "Idle-safe: you can leave it running", and the calm view fades the HUD after 20 s idle. But after `AFK_AFTER` (600 s) without input, meditation's 2.5-3.1x on the peak becomes 1x (`Cultivation.luau:542-549`), and the client shows nothing. Players will believe they're meditating at full speed. It also invites auto-clickers for the "awake" ping.
- **Online-only mutations reward a phone left on.** 3%/plant/h and only online (`Pacing.luau:411`), while Roblox kicks idle clients at 20 min (doc gap). So it pays only kids who leave a device running or use anti-AFK tools. That's a small reward with a bad incentive, and it inflates idle CCU, not qualified play (*challenges a decision*).
- **Seclusion is always right.** It earns the same cultivation as logging out, plus stones, +50% growth and rare finds. So the right play is always "sit, open the panel, Enter Seclusion, then quit": three taps of ritual every session. Wood's "+25% herbs, while online" root perk adds another online-only rule.
- **The streak punishes a missed day.** Consecutive days reset (`STREAK_*`), and the research says pause, don't reset. The reward is small, which makes the loss feel petty rather than meaningful.
- **Docs disagree.** progression.md:101 lists seclusion as QR4's new idea, while onboarding teaches it at QC4, right after Home. That puts two ideas in one chapter, against "one idea per chapter". cultivation.md:333 still says `CARRY_SHARE` 0.25 (the code has 0.5).

## Metrics
D1 strong (the morning card plus a ready breakthrough). Sessions per day are neutral; seclusion could add a short check-in if the card teased the next roll. The 20-min kick makes the online path unreliable.

## Recommendations (ranked)
1. **Logging out on your own peak is seclusion**, with the same rewards automatically. The button stays for online use. That removes the ritual tax and keeps the card.
2. **Show AFK.** When AFK starts while seated, show one quiet line on the calm view ("Your mind drifts... tap to focus"), and fix the meditation doc. Or keep meditation's multiplier for 30 min before AFK applies to seated players.
3. **Mutations roll offline too** (same or half rate). Drop "online only" from mutations and from the Wood perk.
4. The streak pauses (or loses one day per missed day) instead of resetting.
5. Move the Seclusion lesson to a later chapter (QC7 or QR4 as progression.md says), so QC4 teaches only Home.
