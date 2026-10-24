# Game design principles (red-team reference)

Read before judging any feature. Audience: kids/teens on mobile, casual players first, real depth for hardcore players, no permadeath, PvP off. The owner hates many confusing mechanics landing at once.

## 1. Frameworks for judging a feature

- **MDA** (Hunicke, LeBlanc, Zubek 2004). Designers build *mechanics*, which produce *dynamics* at runtime, which players feel as *aesthetics*. Start from the feeling (here: growing stronger, discovery, a calm garden, a big fight with friends) and work backwards. If you can't name the dynamic a rule creates, it's clutter.
- **Self-Determination Theory** (Ryan, Rigby, Przybylski 2006, "The Motivational Pull of Video Games"). Players stick with a game that serves *competence* (I'm getting better and can see it), *autonomy* (real choices about what to do next) and *relatedness* (other people matter). Rate each feature on all three.
- **Motivation models.** Bartle's four types (achievers, explorers, socialisers, killers) are a rough lens. Quantic Foundry's survey-based model is better: 12 motivations in 6 groups (Action, Social, Mastery, Achievement, Immersion, Creativity), with Discovery added later. Ask which group a feature serves. With PvP off, "killers" get PvE mastery, boss timers and leaderboards instead.
- **Fun is learning** (Koster, *A Theory of Fun*, 2004). Fun is the brain mastering a pattern. Once the pattern is solved, boredom follows unless new variation arrives. Every system needs a next thing to learn, not just a bigger number.
- **Loops** (Daniel Cook, Lost Garden, "loops and arcs"). Core loop: the 30-second action (fight, gather, cultivate). Meta loop: the hours-to-weeks goals (realm, peak, sect). Every feature needs an arrow into the core loop. A system that feeds nothing and takes nothing is a side menu.
- **Interesting decisions** (Sid Meier, GDC 2012). A choice is interesting when there's no dominant answer, the trade-offs are clear and the player can see the result. If one option is always best, the "choice" is a hidden trap.
- **Flow** (Csikszentmihalyi; Jenova Chen 2007, "Flow in Games"). Keep challenge just ahead of skill. Use a sawtooth curve: ramp up, give a relief beat after each breakthrough or boss, then ramp again. Let players choose their difficulty through content (which zone, which beast) rather than menus.
- **Juice** (Jonasson & Purho, "Juice it or lose it", 2012; Nijman, "The Art of Screenshake"). Every input gets an immediate, layered answer: sound, flash, particles, number pops, a little camera shake. On mobile, juice is also how the player knows what happened. A feature without feedback reads as broken.
- **Reward schedules.** Fixed rewards (every N kills, daily) are predictable and calm. Variable-ratio rewards (drops, mutations, rare spawns) drive the strongest engagement and the strongest compulsion. For kids: variable rewards are fine *inside play* (drops, rare beasts). Never sell them for Robux without odds, and never tie them to time pressure plus payment. Roblox requires every paid random item, including ones bought with paid in-game currency, to show all outcomes with percentages that sum to 100% (create.roblox.com, "Paid random items").
- **Loss aversion** (Kahneman & Tversky). A loss hurts about twice as much as an equal gain feels good. Punish by taking *time* or *momentum* (a respawn walk, a cooldown, a missed bonus streak, a dropped temporary buff), never banked progress. Make sure the player can see why they failed and has a quick way back in. Deepwoken shows the cost: players say the real pain of a wipe is replaying the early grind.

## 2. Progression and economy

- **Pacing.** Early levels are fast, with a win every minute or two, and stretch out later. Pecorella's "Math of Idle Games" (Kongregate, 2016) has the standard shape: costs grow exponentially, output grows polynomially or by multipliers, and a wall shows up where the next lever (a new system, a prestige) unlocks. Design each wall on purpose; don't let it appear by accident.
- **Idle/AFK.** Offline progress brings players back ("my plants grew"), and Grow a Garden proves it. Cap it (for example 8-12 h) so returning is rewarding but active play stays better. AFK should never beat active play per minute, or the game plays itself.
- **Sinks and faucets.** Every currency source (faucet) needs a sink: upgrades, consumables, cosmetics, repairs, rerolls. Watch the total money supply. Trading between players speeds up inflation, so tax trades, make sinks scale with wealth (percentage costs, prestige cosmetics), and keep power items bound to the player.
- **Power creep.** Each new tier makes the last one obsolete. Prefer horizontal additions (new techniques, elements, builds, cosmetics) over raw stat tiers once the realm ladder is in place. Vertical progress (realms) is the spine. Horizontal progress (builds, collections, sect roles) is where hardcore depth lives without leaving casual players behind.
- **Prestige/rebirth.** Only works if the reset is visibly faster the second time and opens something new, not just a multiplier. A realm breakthrough already works like a soft prestige. Don't stack a second reset on top.
- **Collections.** A codex of beasts, herbs, mutations or techniques gives completionists a long tail cheaply. Show the empty slots as silhouettes so players can see what's left.
- **Long tail.** Endgame comes from a mix of skill (boss tiers), luck (rare mutations, rare spawns), social play (sect projects) and expression (peak building). Grind alone doesn't hold it.

## 3. Onboarding (FTUE)

- One new mechanic at a time, each with its own small win before the next unlocks (Celia Hodent, *The Gamer's Brain*: attention is scarce, and learning by doing beats reading).
- Show, don't tell: arrows, glowing targets and one-line prompts beat text walls. Let the player do it first and name it afterwards.
- First 5 minutes: move, hit something, see a number go up, get a visible upgrade, glimpse something aspirational (a higher-realm player, a peak, a boss). There should be no menus to read before the first fight.
- Cultivation lesson: Tale of Immortal and Amazing Cultivation Simulator are deep, and both are known for crushing learning curves. ACS players report needing 100+ hours and guides to learn the basics. Keep the depth, but drip-feed it over hours, gated by realm.

## 4. Kids and casual players

- **Reading level:** about grade 3-5. Short words, at most one sentence per prompt, icons alongside every word. Many players are young or playing in a second language.
- **Cognitive load:** at most 3-4 things on screen asking for attention. Each new HUD element must earn its place or replace one. The phone HUD is already full.
- **Failure tolerance:** plenty of checkpoints, no permanent loss, mercy mechanics (catch-up XP, a pity timer on rare drops, comeback buffs after deaths).
- **Social safety:** rely on Roblox's own chat filtering. Give no free-text channel of your own, and make griefing impossible by design (no stealing or destroying others' things, no kill-stealing loot, opt-in trades with a confirmation screen).
- **Dark patterns to avoid:** fake countdowns tied to purchases, confusing buy buttons (the FTC's $245M Fortnite refund order in 2022 covered one-press accidental charges), loot boxes without odds, pay-to-skip on purpose-built frustration, guilt prompts, streaks that punish a missed day harshly. **Acceptable:** cosmetics, convenience that doesn't gate content, honest timers (crops grow, shops refresh), daily rewards that pause rather than reset, gifting.
- **Accessibility** (gameaccessibilityguidelines.com): large touch targets (at least 44 px), colour never the only signal, readable contrast, subtitles or icons for audio cues, no required rapid tapping, and difficulty that comes from choices rather than reflexes alone.

## 5. Social design

- Give real reasons to play together: bosses that are easier or more rewarding in a group, shared world events, gifting, visiting peaks, sect goals that everyone contributes to.
- Co-op over competition: shared credit (everyone who hits a beast gets the loot), no contested nodes, no last-hit stealing. Leaderboards are fine for opt-in bragging.
- Guilds/sects work when membership gives a role, a shared project with visible progress, and a place. Don't make solo play feel punished.
- Make griefing impossible by design: no player collision on key paths, no blocking spawns, no stealing, no trolling with physics.
- Veterans helping newbies is a top retention driver (Grow a Garden gifting; Deepwoken's "freshie" rescue culture). Reward the helper.

## 6. Genre lessons

- **Grow a Garden** (21.6M peak concurrent players in June 2025, more than Fortnite's record; Fortune, AP): a dead-simple loop (buy, plant, sell), one-tap travel, offline growth, depth hidden under the surface (mutations, weather, sprinklers), a *global* shop that restocks every 5 minutes so everyone chases the same stock, low stress with no fail state, frequent weekly updates and events, gifting. Weak spots: a trade-driven economy that inflates, scams, and a hollow late game.
- **Pet Simulator:** collection plus rarity tiers plus showing off works. Heavy paid-random-item monetisation is the ethics line not to copy.
- **Blox Fruits / Grand Piece Online:** an aspirational, readable power fantasy (fruits and techniques you can see across the map), with bosses as social meeting points. Weak spots: a long solo level grind with few decisions, PvP and griefing friction, rarity locked behind RNG and trading, wipes and resets that destroy trust.
- **Deepwoken:** deep builds and a strong identity, but permadeath plus early grind plus a steep curve shut out casual players, and paid restores feel like a cheat. Take the build depth, leave the loss.
- **Tale of Immortal / ACS:** the richest gamification of cultivation (realms, tribulations, encounters, sect politics), but too many systems up front, little teaching, and weak combat. Lesson: the fantasy sells itself; the teaching and the moment-to-moment combat must carry it.
- **Idle cultivation mobile games:** the breakthrough moment is the hook (a wall, then a spectacle), offline qi works, and so do daily cultivation rhythms. Weak spots: menu bloat, a dozen currencies, aggressive paywalls at the walls.

## 7. Red-team procedure (run on every feature)

1. **Why does it exist?** One sentence. What player need does it meet (competence, autonomy, relatedness; which motivation group)?
2. **Arrow into the core loop.** What does it take from fight/gather/cultivate, and what does it feed back? If neither, cut it or merge it.
3. **Who is it for?** A kid in their first hour, a casual player at week 1, a hardcore player at month 3. When does it unlock?
4. **Cost.** New buttons, HUD space, currencies, rules to learn, server cost. Does it replace something? Can it be taught in one prompt?
5. **Decisions.** Is there a dominant option? Is there anything interesting to decide?
6. **Feedback.** What does the player see and hear the moment it works or fails?
7. **Frustration.** Worst case for a 9-year-old on a phone: lost progress, confusion, waiting with nothing to do, a feel-bad loss. Is the punishment time, not property?
8. **Exploits and economy.** AFK farming, alt accounts, trade duping, inflation, griefing, one dominant farm spot. What is its faucet and its sink?
9. **Ethics.** Paid randomness with odds shown? Pressure tactics? Would a parent be comfortable watching it?
10. **Better and smaller.** What one change makes it more fun? What can be cut and still deliver the aesthetic? Ship the smallest version that delivers the feeling.

## Sources

Hunicke, LeBlanc & Zubek, "MDA" (2004) · Ryan, Rigby & Przybylski, Motivation and Emotion 30 (2006) · quanticfoundry.com (Gamer Motivation Model) · Koster, *A Theory of Fun* (2004) · lostgarden.com (Cook, loops and arcs) · Sid Meier, GDC 2012 "Interesting Decisions" · Chen, "Flow in Games", CACM 2007 · Jonasson & Purho, "Juice it or lose it" (2012) · gamedeveloper.com "The Math of Idle Games" I-III (Pecorella) · Hodent, *The Gamer's Brain* (2017) · create.roblox.com/docs/production/monetization/paid-random-items · ftc.gov (Epic Games settlement, Dec 2022) · gameaccessibilityguidelines.com · fortune.com/2025/07/30/roblox-video-game-grow-a-garden-viral-summer-hit · sportskeeda.com/roblox-news/why-grow-garden-popular · forum.arcaneodyssey.dev/t/a-review-of-deepwoken/73730 · gamegeeker.com Tale of Immortal review · gamingnexus.com and cubed3.com Amazing Cultivation Simulator reviews.

## Addenda
Findings added by game-designer reviews, one line each with a source.
