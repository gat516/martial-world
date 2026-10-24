# Roblox metrics and audience (research, Oct 2026)

What Roblox rewards, what numbers to aim for, and who plays. Read it before judging a Martial World feature. **[U]** = unverified or third-party only.

## 1. Discovery: what Roblox rewards

**Recommended For You (Home)** is the main traffic source. It retrieves candidates, then ranks them per user. Since **June 2026** it uses a **28-day window** (it was 7), with separate signals for D1, D2-7 and D8-28. The old qualified play-through rate (qPTR) was split into play-through, session-quality and spend signals. Roblox's stated aim is to stop "exciting thumbnails" beating games with long-term value ([newsroom, 2026-06-15](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox)). Signals by priority ([discovery docs](https://create.roblox.com/docs/discovery)):
- **Most important:**
  - play-through rate (impression to play);
  - first-play bounce rate, counted at **<60 s** and **61-180 s** (a penalty);
  - play days per user (D1, D2-7, D8-28);
  - playtime per user, **capped at 60 min per user per day**.
- **Important:**
  - intentional co-play days (friends join through invites, joins or private servers; matchmaking doesn't count);
  - qualified sessions per user;
  - spend days per user;
  - Robux spent per user.
- **How it's scored:** per-user averages, not totals, so a small game with engaged players isn't penalised. Only users who arrived organically from that sort count. Changes show in impressions **a few days later**. Weekly traffic peaks on **Saturday**.
- **Eligibility:** a **custom thumbnail is required** for Home impressions, and it must be accurate (no bait). Event pages take up to 5 thumbnails.
- **Other surfaces:**
  - Discover charts (Top / Trending): updated, criteria not public;
  - curated Standout Games;
  - Live Events;
  - Sponsored (Ads Manager);
  - semantic search in every supported language, so the game description and keywords matter.
- **Business effect:** the switch moved impressions from high-monetising 2025 viral games to retentive ones. Roblox guided Q3 2026 bookings down 14-18% and accepted the cost ([Nasdaq](https://www.nasdaq.com/articles/roblox-guided-bookings-down-much-18-and-withdrew-its-full-year-outlook-algorithm-change)). **Retention now outranks monetisation.**
- **Creator Rewards** replaced Engagement-Based Payouts on **24 July 2025** ([10-K](https://www.sec.gov/Archives/edgar/data/1315098/000131509826000024/rblx-20251231.htm)):
  - **Daily Engagement Reward:** 5 Robux when an "active spender" (about $9.99 spent in the last 60 days) plays **≥10 min**. Only the first 3 games they play each day count.
  - **Audience Expansion Reward:** 35% of a new or returning user's first $100 of spend over 2 months, if they play ≥10 min.
  - Source: [Tubefilter](https://www.tubefilter.com/?p=186987). The thresholds come from press coverage **[U]**.
  - Lesson: **a 10-minute first session pays directly.**
- **Content maturity and age-gated catalogues** ([content maturity](https://create.roblox.com/docs/en-us/production/promotion/content-maturity)):
  - Labels: Minimal / Mild / Moderate / Restricted. Without a completed questionnaire, a game is restricted for everyone.
  - Since April 2026, under-16 accounts are **Roblox Kids (5-8)**, which takes Minimal or Mild games, and **Roblox Select (9-15)**, which takes Minimal, Mild or Moderate. Social hangouts and free-form building are 16+ only.
  - Kids/Select eligibility ([docs](https://create.roblox.com/docs/production/publishing/kids-and-select)):
    - ID-verified owner with 2FA;
    - a Plus/Premium subscription for 2 months, or a refundable fee;
    - **250 unique plays from "highly engaged" players in 60 days** (a DevForum post says 500 **[U]**);
    - a safety review. Until it passes, the game shows only to age-checked 16+ users.
  - **Martial World must target Mild (beast combat, no realistic blood) and pass Select, or it loses most of its audience.**
- **Chat age checks** (worldwide since Jan 2026, [newsroom](https://about.roblox.com/newsroom/2026/01/roblox-age-checks-required-to-chat)):
  - Bands: <9, 9-12, 13-15, 16-17, 18-20, 21+. You chat with your own band and the ones next to it.
  - Under-9s have chat off unless a parent consents. Under-16s can't chat with adults.
  - Many players have no chat at all, so **every social feature must work without text chat** (emotes, pings, quick-chat wheels, party UI).

## 2. Benchmarks

Roblox's dashboard compares you with similar games at the 50th to 90th percentile once you have **100+ DAU** ([analytics](https://create.roblox.com/docs/production/analytics)). Public numbers come from GameAnalytics, 2025 data ([2025 Roblox Benchmark Report](https://investgame.net/news/pdf/the-2025-roblox-benchmark-report/)), for games with **25+ min average sessions** (our class):

| Metric | p50 | p75 | p90 | p95 |
|---|---|---|---|---|
| D1 retention | 10.8% | 12.3% | 18.9% | 24.8% |
| D7 retention | 1.8% | 2.9% | 5.9% | 6.4% |
| D30 retention | 0.5% | 1.2% | 1.5% | 1.9% |
| Sessions/day | 2.2 | 3.0 | 3.8 | 4.9 |
| ARPPU/day | $2.12 | $2.82 | $6.40 | $11.41 |

- **Session length is where retention comes from:** games under 6 min average sit below 10% D1, and 19+ min games reach double digits. Casual players leave within 2 min, core players average 37 min a session, and the p95 player plays about 94 min a day.
- **Sessions per day:** frequency predicts retention better than length. Top games reach 3.5+ sessions a day **[U]** ([rowatcher](https://rowatcher.com/news/best-roblox-rpgs-in-2026-ranking-the-top-10-by-gameplay-and-player-retention)).
- **Targets for us:**
  - good: D1 ≥15%, D7 ≥4%, D30 ≥1.2%;
  - top quartile of the genre: D1 20-25%, D7 6%+, D30 2%;
  - average session 20-30 min; 2-3 sessions a day.
- **Payer conversion:** no public Roblox benchmark. ARPDAU = conversion × ARPPU ([monetization docs](https://create.roblox.com/docs/en-us/production/analytics/monetization)). A well-monetised RPG does about **$0.015-0.025 ARPDAU** **[U]** ([rowatcher](https://rowatcher.com/news/devex-math-in-2026-what-you-actually-take-home-per-1-000-players)). Mobile-wide rule of thumb: 1-3% payers **[U]**.
- **Dashboards:** Retention (cohorts by first-play date), Engagement (session time, sessions per user), Monetization (conversion, ARPPU, ARPDAU), Acquisition > Home Recommendations (the signal values above), Audience Reach (Kids/Select progress), plus Funnels, Economy and Custom.
- **Instrument with `AnalyticsService`** ([funnels](https://create.roblox.com/docs/en-us/production/analytics/funnel-events), [custom events](https://create.roblox.com/docs/en-us/production/analytics/custom-events)):
  - `LogOnboardingFunnelStepEvent`: every FTUE step, through to the first breakthrough.
  - `LogFunnelStepEvent`: per-realm progression funnel, shop funnel, sect join, party formed. Up to 10 funnels of 100 steps each.
  - `LogEconomyEvent`: qi stones and other currencies, sources and sinks.
  - `LogCustomEvent`: up to 100 names with ≤3 fields. Use one name with fields, not many names.
  - Limits: 120 + 20×CCU requests a minute. Charts take about 24 h to fill in.

## 3. Audience

- **Age:** of the age-checked DAU (about 45-51% of all DAU, Jan-Q1 2026), **35-36% are under 13, 38% are 13-17 and 26-27% are 18+** ([search summary of Roblox disclosures](https://www.tikr.com/blog/roblox-jumped-10-on-older-user-growth-why-the-stock-could-hit-115-in-2026)) **[U on exact split]**. The 18+ group grows fastest and monetises about 40% higher. Younger North American players' spend per hour is falling ([pocketgamer](https://www.pocketgamer.biz/roblox-revenue-rises-36-yy-but-young-north-americans-see-falling-per-hour-monetisation/)).
- **Regions (Q2 2026 DAU, 123 M):** APAC 41 M, Europe 26 M, US and Canada 22 M, rest of world 34 M. US and Canada bring in **>50% of spend**. Japan (+67%) and India (+64%) grow fastest. **Use auto-translation-friendly text** (short strings, no text baked into images) and test long translations (German, Portuguese).
- **Devices:** mobile carries about 72% of activity **[U]**, and 8 in 10 accounts signed up on mobile (Statista). GameAnalytics finds 48% of players on PC and mobile, 38% PC-only, 7-10% mobile-only and about 2% console. **Design for phones first, with tablet and PC as bonuses.**
- **Session patterns:** traffic peaks at weekends (Saturday), after school and in the evening local time, with spikes in school holidays. Plan events for Friday to Sunday, and keep weekday sessions shortish (15-30 min) with a clean stopping point.
- **Reading level:** assume about age 8-10. Text in 1-line chunks, icons with numbers, no lore walls. Show it, don't tell it.
- **Social:** friends joining you is a ranking signal (co-play days). Under-13s often have no chat. Kids like collecting, visible power growth, pets and companions, bright feedback and being shown what to do. Teens want mastery, status (titles, auras, rare cosmetics), competition and guilds/sects. Martial World's realms, cosmetic auras and sects suit teens, and the spirit garden and companions suit kids.

## 4. What top Roblox RPGs do

Blox Fruits, Sailor Piece, Anime Vanguards-style games, Deepwoken, Arcane Odyssey. Observations are mostly from community and press sources **[U]**.
- **First session (FTUE):** in combat or earning within 30 s. Visible power gains in the first 5 min. The first big milestone (here, the first breakthrough with VFX) inside 10 min, which also crosses the 10-min Creator Rewards line. Kill the 60-180 s bounce: no long cutscenes, menus or loading at spawn.
- **Daily and weekly loops:**
  - daily login streaks and quests;
  - timed spawns (bosses, world events);
  - weekly quests or leaderboards;
  - offline progress (garden growth) that pulls players back;
  - a "come back tomorrow" hook at the end of each session.
- **Updates:** weekly to biweekly patches plus a big update every 4-8 weeks. Games that slow down drop off the charts within weeks ([rowatcher](https://rowatcher.com/news/top-10-roblox-games-by-players-march-2026-data-breakdown)). Each update brings new codes and a countdown on the game page.
- **Social hooks:**
  - party bonuses (more XP or drops together);
  - join-friend buttons and invite prompts (`SocialService:PromptGameInvite`);
  - free private servers (VIP servers count as co-play);
  - sect/clan progress;
  - group-join reward (in-game perk for joining the Roblox group);
  - badges for milestones;
  - a like/favourite prompt after a satisfying moment, never at spawn.
- **Notifications:** `ExperienceNotificationService` reaches **13+ only**. Check `CanPromptOptInAsync`, then prompt after a positive moment. Use it for "your herbs are ready" and "event starts" ([API](https://create.roblox.com/docs/reference/engine/classes/ExperienceNotificationService)).
- **Monetization players accept:**
  - cosmetics (auras, robes, emotes);
  - convenience passes (extra garden plots, auto-collect, more storage);
  - temporary XP or qi boosts;
  - a VIP pass with cosmetic flair;
  - a season or battle pass with a free track.
- **What players hate:** stat power for Robux, paywalled zones or realms, energy timers that end a session, and constant purchase pop-ups. Pay-to-win draws review-bombing and dislikes, which hurt play-through rate.
- **Trading pitfalls:** duping, scams, real-money trading, and inflation that kills drop value. Trading needs server-authoritative two-step confirmation. **Players with `IsPaidItemTradingAllowed = false` must not trade paid items.**
- **Paid random items** ([policy](https://create.roblox.com/docs/production/monetization/paid-random-items)):
  - **Scope:** anything random bought directly or indirectly with Robux, including eggs, chests, rerolls, enhancement rolls and **luck boosts or pity**. A **seed bought with Robux that grows a random result also counts.**
  - **Disclosure:** show every outcome with odds that add up to 100%, behind a labelled "Info/Details" button (a bare (i) doesn't count). Update the odds while a boost is active.
  - **Restricted players:** if `PolicyService` returns `ArePaidRandomItemsRestricted`, offer a free path, a fixed order or a direct purchase instead.
  - **Regulation:** Korea's law pushed disclosure worldwide in June 2026 ([TechTimes](https://www.techtimes.com/articles/319148/20260626/koreas-loot-box-rules-push-roblox-disclose-item-odds-worldwide.htm)). In May 2026, US groups asked the FTC to investigate paid random items aimed at kids **[U]**.
  - **Recommendation:** no paid randomness at all. Sell only fixed items. Random drops from play are free of these rules.

## 5. Mobile UX

- **Touch targets:** Roblox publishes no number. Use the iOS **44×44 pt** minimum (WCAG floor 24 pt) with ≥8 pt gaps. Key buttons should be 60-80 pt.
- **Thumb zones:** the left thumb has the movement stick (bottom-left), and the right thumb has jump and actions (bottom-right arc). Keep techniques in a right-hand arc near jump. The top corners are hard to reach, so put status displays there, not buttons. Respect safe areas on notched phones.
- **HUD:** at most about 5 persistent elements during play **[U]** ([creation.dev](https://www.creation.dev/blog/roblox-ui-design-best-practices)). Move secondary buttons into a collapsible menu. Panels collapse on narrow screens. Use Scale, not pixel offsets, and check `ViewportDisplaySize` = Small ([adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design), [cross-platform](https://create.roblox.com/docs/projects/cross-platform)). This game's phone HUD is already too big: get readability from contrast, never by enlarging.
- **Text:** text-scaling preferences are on by default. Avoid thin or decorative fonts. Body text ≥14-16 px on a 360-400 px wide phone **[U, convention]**, with high contrast against bright scenes.
- **Performance** ([design for performance](https://create.roblox.com/docs/performance-optimization/design)):
  - target 60 fps;
  - pick a baseline low-end phone (2-3 GB RAM) and test on it; Studio's emulator does not show memory;
  - running out of memory crashes low-end phones; StreamingEnabled is the main memory lever;
  - prefer built-in materials over custom textures; use model LevelOfDetail and SLIM avatars for crowds;
  - merge meshes to cut draw calls; keep particle counts low;
  - community targets (no official budgets): <50k parts in a loaded area **[U]**, client memory ideally <1.5 GB on low-end devices **[U]**.

## Checklist for judging a feature against Roblox metrics

1. **First session:** does it shorten or lengthen the first 60-180 s? Anything that delays the first action raises bounce rate, the main ranking penalty.
2. Does it help a new player reach **10 min** and a felt milestone (the first breakthrough) in the first session?
3. Does it give a reason to return **tomorrow** (D1) and over **days 8-28** (the new 28-day window)? Name the hook: offline growth, a timed event, a streak, the next realm.
4. Does it add **sessions per day** (short check-ins such as the garden harvest), not just longer sessions? Playtime counts only up to 60 min a day.
5. Does it create **intentional co-play** (party, sect, invite, private server) and still work for players with no chat?
6. Is it readable at an **8-10-year-old's reading level**, with icons, numbers and one-line text that translates well?
7. **Phone:** does it fit the phone HUD budget, with thumb-reachable targets ≥44 pt and no new permanent button unless it replaces one?
8. Does it run on a **low-end phone** (memory, particles, part count, streaming-friendly)?
9. Does it keep the game **Mild** and Select-eligible (no realistic blood, gambling imagery, social hangouts or free building)?
10. **Monetization:** if it makes money, is it cosmetic or convenience, with **no paid randomness** (luck boosts included) and no pay-to-win power?
11. Do players without permissions (no paid trading, no paid random items, under 13 with no notifications) still get a full experience?
12. Is it **instrumented** (funnel step, economy event or custom event) so its effect shows in the dashboards a day later?
13. Can it carry an **update beat** (new codes, event thumbnail, countdown) so it feeds the weekly/biweekly cadence?
14. Would an honest thumbnail of it make someone click and stay? (Bait thumbnails now lose.)
15. Does it widen the economy without inflation (a sink for every source)?

## Addenda
Findings added by game-designer reviews, one line each with a source.
