# Progression rules

The rulebook for how fast players climb and what they get along the way. Every new
reward, drop, item, multiplier, spawn or respawn change gets a row here and a run of
the [pacing model](pacing-model.md) (`python3 tools/pacing_model.py`) before it merges.
The `progression-designer` agent owns this file. Numbers live in
`src/shared/Pacing.luau` (and `Herbs.luau`, `Items.luau`, `Enemies.luau`,
`BuildItems.luau`); this page says what they must add up to. Last full pass: the
2026-10-24 rebalance (owner-approved), then the same day's herb re-tier, sell-price cut
and foundation bar (owner decisions), then the seclusion rework and tempering (owner
decisions, same day), then seclusion's fortuitous encounters (owner, same day).

## Targets

| | Target (active, the regular player online) | Built (model) |
|---|---|---|
| Qi Condensation | about 2.4 h; the first session lands 2-3 breakthroughs (QC4 by 9-10 min with the onboarding's talk) | 2.4 h, QC4 at 5 min of play |
| Qi Refining | about 7 h; the real slowdown from QR4, where the garden and the peak carry | 7.1 h |
| Foundation Establishment | about 20 h; no stage over about 3 h; FE9 is the cap | 20.2 h, stages 1.7-2.7 h |
| A gardener (garden and meditate road) | gets there, 1.5-2x slower at most | +14% overall (QC +25%) |
| A night (12 h offline or AFK) | about one stage, never two | QC/QR: the 1.5 cap; FE: 26-57% of a bar (owner, 2026-10-24: FE nights stay as is) |
| Foundation percent | 100% by playing a stage; 130%+ rare for the regular, common only for the heavy | sealed medians 97 / 110 / 111% (casual / regular / heavy), 130%+ on 1 / 3 / 6 of 23 stages; after tempering and deepening 103 / 111 / 120%, 130%+ on 1 / 4 / 6, no stage under 100% for the regular or heavy |

"The regular player" is the model's regular profile (1.5 h a day, hunts about half the
time, a growing garden, a cushion, some building, a party a quarter of the time). With
nights the regular finishes FE9 on about day 15, a casual (30 min a day) on day 29, a
heavy player (3 h a day) on day 8.

## Hard rules

1. **Every faucet has a sink**; every new reward names both (tables below).
2. **Every multiplier has a cap and is in the model.** A system that adds a speed-up to
   cultivation gets a row in "Multipliers" and a lever in `tools/pacing_model.py`.
3. **No lever is mandatory; stacking all of them buys at most about 25-30%** (owner,
   2026-10-24: "I don't want it overcomplicated to get a good progression pace, in a way
   that players feel they have to do EVERYTHING to cultivate faster"). The main roads,
   playing the loop (hunt and refine) or gardening and meditating, reach the targets on
   their own: a one-road player with a natural garden and no min-maxing of buffs, cores
   or decorations stays within **15%** of the regular's online time, and a min-maxer
   stacking everything is at most **1.3x** the regular's speed. Every extra lever is a
   modest bonus with diminishing returns. The model's balance check enforces it on
   every run (now: hunter +12%, gardener +14%, everything x1.14).
4. **Items come from the realm band they belong to**; nothing from a later band drops
   earlier except as a rare, announced prize (event herbs, heavenly treasures).
5. **One rarity table** (below): a rarity means the same odds everywhere, and anything
   rarer than Epic has a pity path.
6. **AFK never beats active play per minute.** AFK, offline and seclusion earn the plain
   passive (no seat, aura, buffs, weather, root or method), out of one 12 h budget a day.
7. **Caps are per day, not per event.** A daily cap can't be doubled by logging in twice.
8. **Pay in kills at the eater's stage or floors by band, not shares of the dantian or
   the bar.** Shares scale faster than hunting (kill qi grows with dantian^0.8), so a
   reward that pays a share must be rare (treasures, event herbs) or capped.
9. **Bars never go down** from one stage to the next; +10% strength per minor stage,
   x2.25 per major, realm suppression 0.2 per major, the party shelter.
10. **No paid randomness, no stat power for Robux, never sell qi.** Grow now (Robux)
    only finishes a growing plant.
11. **Few currencies:** Spirit Stones, sect contribution and raw qi. Don't add another
    without a strong case.
12. **A change that moves any profile's time to QC4, QC9, QR9 or FE9 by more than 10%
    needs the owner's sign-off**: report it, don't ship it.
13. **Tempering mends to 100%; past 100% is earned only** (owner, 2026-10-24). Every
    tempering source (seclusion's herbs and pills, the heart demon, the Clear Heart
    Pill's extra steps) raises an old stage at most to 100%, lowest first.
    **Deepening** (`Foundation.deepen`) is the only other lift past 100%, up to
    `DEEPEN_MAX` 130, and only for cultivation-themed effort: a fully calmed heart demon
    today, heaven-and-earth treasures and feats above your realm later. **Only living
    through a stage reaches 150%.** A maximised stage keeps a lead no temperer can
    catch (23 stages mended to 100%: +23% health and power; deepened to 130%: +51%;
    earned to 150%: +69%). None of it is ever sold for Robux.
14. **Seclusion is purposeful, never a leash** (owner, 2026-10-24): tempering, a faster
    garden plus the online mutation chance, AFK cultivation, random finds rolled
    continuously. No hour streaks, no flat stone trickle, nothing that needs a full hour
    (the sect's seclusion daily is 15 minutes).

## Multipliers and their caps

Online passive per second = `passive x (1 + herb buffs) x (1 + aura, own peak only) x
(1 + weather) x seat x root x method`. Refining = `raw qi x efficiency x refine x
root x method x (1 + weather circulation)`.

| Multiplier | Applies to | Value | Cap / limit | Where |
|---|---|---|---|---|
| Meditation seat | seated passive | anywhere x1.5, own peak x2.5, outdoor sites | one seat | `Pacing.Meditation` |
| Meditation piece (best in range, own peak) | adds to the seat | Cushion +0.75, Spirit Stone +0.5, Mat +0.4, Incense +0.25 | the best one only | `BuildItems` `meditation` |
| Peak score | adds to the seat on your peak; plant growth | +0.0024 a point; growth +0.002 a point | the tier's `scoreCap` 60 / 150 / 250 (seat +0.14 / +0.36 / +0.6; growth +12 / 30 / 50%) | `Pacing.PeakScore` |
| Garden aura | x the seat on your own peak | every planted herb: `BY_TIER` 0.02 / 0.05 / 0.15 / 0.3 (V's 0.6 parked) x `RARITY` (C 1, U 1.1, R 1.25, E 1.5, L 2) x size x mutations, half while growing | QC 0.3, QR 0.6, FE 1.0, lifted up to +25% by the peak score (decorate your abode) | `Pacing.Aura` |
| Herb and item QiRate buffs | all online passive | per herb +5% (tier I) to +45% (tier IV); Greater Core +20%, Immortal Peach +50% | falloff 1 / 0.5 / 0.25 / 0, then QC 0.2, QR 0.3, FE 0.5 | `Pacing.Herbs.BUFF_FALLOFF`, `BUFF_CAP` |
| Weather | passive / circulation | mean +4.9% / +0.6% (one weather at a time, up to +100% passive for minutes) | one weather | `Weather.luau` |
| Spirit root | passive, refining | Spirit 1, Earth 1.1, Heaven 1.25, Immortal 1.4 | the grade (pills, below) | `Pacing.Roots` |
| Cultivation method | passive, refining, kill and node qi (online) | Sect Breathing 1.0; starters 1.1 (+0.1 matching the root) from FE1 | the method | `Pacing.Methods` |
| Party | kill qi | +5% a nearby member; shared credit (`KILL_SHARE` 10%, helpers 50%) | +15% | `Pacing.Party` |
| Stage `gather` (curve) | raw qi income | QR1 x2, QR2 x1.6, QR7 x1.6, FE4 x1.25, FE7 x1.15 | per stage | `Pacing.Curve` |
| Foundation bonus | health and power only (never cultivation) | +1% by 100%, +2% more by 150%, per stage; past 100% each percent costs `OVER_COST` 5x | 150% (3.5x the target) | `Pacing.Foundation` |
| Heaven-defier | bars | x1.5 | | `Pacing.HeavenDefying` |
| Pacing.Adjust (the rebalance) | bars | QC4-9 x1.15, QR x1.65, FE x4.2 | solved by the model | `Pacing.Adjust` |

**Decorate your abode** (owner, 2026-10-24): building raises the peak score, which adds
to meditation on your peak, speeds your plants, and lifts how much spirit energy the
abode can hold (the aura cap, up to +25% at the score cap). A fuller, rarer garden fills
it. Each is a modest reward: in the model the score is worth about 7% to a heavy
builder, the aura 7-9%, the cushion 2%; none is needed to reach the targets.

## Faucets and sinks

**Foundation percent** (health and power, never cultivation): experiences and deeds
while at a stage (to 150%); tempering to 100% (the heart demon 50 points x 1-3 stages a
trial; seclusion's items +10/+20, 2 a day and 5 a week); deepening to 130% (a calmed
heart demon +20 on one stage). Sink: none (a stage's percent never falls). In the model
the regular mends about 9 items' worth (64 points) by FE9; a casual's sub-100 stages
drop from 12 to 5.

**Cultivation** (the realm bar): passive (online, AFK, offline, seclusion), refining
raw qi (circulation), Greater Spirit Cores (8% of the bar), Immortal Peach (50% of the
bar), seclusion's first-time card (25%, once). Sink: the breakthrough (the bar resets;
the overflow up to 1.5 bars carries, at most 0.5 of the new bar). Cap: the overflow
cap.

**Raw qi** (the dantian): kills (`qiDrop x (dantian/120)^0.8 x gather`), qi nodes (20%
of the dantian x gather, 45 s per player), daily login (50% of the dantian), herbs (tier
share or floor), Lesser Spirit Cores (2 kills' qi), Heavenly Dew (a full dantian),
objective rewards (`qiShare`), a reclaimed death spill, the patron's shelter share (20%
of their own qi per sheltered kill). Sinks: refining, the qi surge, the death spill (half
of unbanked), fleeing. Cap: the dantian.

**Spirit Stones**: kills (3-24 a beast, bosses 50-180), qi nodes (4-8), objectives (85 in
the first session, lessons 20-50, the method 150), sect dailies (40 / 110 / 300 by major x
the daily's share) and ranks (300, 1500), the chain (60, final 200), Herbarium discoveries
(15-300) and pages (150-3000), herb sales (`sellPrice` 3-300), event relic fallbacks (60,
120), a reclaimed spill. Seclusion pays no stones (the trickle and its streak were cut,
owner 2026-10-24); its encounters give seeds in kind instead (below). Sinks: the Herbalist's seeds, build pieces (the decor shop), technique
comprehension, the death spill, fleeing. A regular earns about 12,800 stones to FE9 (QC
780, QR 2,500, FE 9,500); a heavy player about 11,100, plus found seeds that stand in for
about 10,800 stones of Herbalist buys (the model lets them pay only for seeds); a garden
road selling a third of its qi herbs about 44,000 (FE 37,000).

**Sell prices** (2026-10-24: the stone flood fixed by price, not a daily cap): one
ladder by tier and rarity, so a grander herb never sells for less than a humbler one of
its rarity: tier I 3-18, II Rare 40-55, II Epic 45-55, III Epic 45-50, III Legendary 80,
IV Epic 70, IV Legendary 110-140, the event's Thousand-Year Ginseng 300 (tier III-IV were
260-3000, about a tenth now). A herb sells for a tenth or less of its seed (Seven-Star 400,
Emberheart 600, Dragonblood 1200), so seeds stay a sink. A gardener's remaining sales
are mostly tier I-II volume; re-check if plot counts or yields rise.

**Sect contribution**: dailies (25-60 each) and sheltering (2 a kill), inside a 700-a-week
cap; the chain (60, final 150); promotions are by contribution earned. Sink: the Pavilion
(seed packets, root pill fragments, a Foundation Tempering Pill and a Clear Heart Pill a
week, the ring's slot, manual copies).

## Rarity

| Rarity | Odds on a roll that can give it | Pity |
|---|---|---|
| Common | most rolls (40%+) | no |
| Uncommon | 15-40% | no |
| Rare | 5-15% | no |
| Epic | 1-5% (bosses may guarantee one) | no |
| Legendary | under 1-4%, bosses and treasures only | yes: fragments, the Pavilion, or a mutation chain |

Today's deviations, accepted: the Lesser Spirit Core (Uncommon) drops at 20-50% (it's a
hunting reward, a kill's worth of qi); the Greater Core (Epic) is guaranteed from bosses;
Legendary herbs come from mutation chains (a 1-5% roll on every harvest of the herb
below, repeated, which is its own slow pity) and boss seed pools. An explicit Legendary
herb pity is **deferred** (owner, 2026-10-24; below).

## Where things come from

Bands (`Herbs.Regions`): Inner Wilds QC1-4 and Ruined Borderlands QC5-9 (tier I), Outer
Wastes QR1-5 (II), Deep Wilds QR6-FE3 (III), Far Reaches FE4-9 (IV). Tier V is deferred
(below).
Deep Wilds and the Far Reaches aren't map regions yet: their seeds drop only by a beast's
realm (variants, the testbed).

### Herbs and seeds

Herb qi: `EAT_SHARE` 6 / 9 / 12 / 16 / 20% of the eater's dantian by tier, at least
`EAT_FLOOR` 60 / 150 / 900 / 3000 / 8000; **below the eater's band tier only the floor**.
Event herbs (`PRIZE`) keep their share anywhere. Seeds back on harvest: 1-2. Beast seeds:
12% a kill per damager from the band's pool; bosses 2-4 seeds, plus their `bossSeeds`.
The Herbalist: `STOCK` 30 / 12 / 3 / 2 seeds of a herb a player a day for tiers I-IV.

**A herb's tier matches how grand its name is** (owner, 2026-10-24): in xianxia terms a
grass, mint, bamboo or common lotus is humble (tier I), a ginseng or orchid of the
wastes is a spirit herb (II), star-, rift-, snow- and ember-named herbs are rare (III),
and the classic treasures (a thousand-year ginseng, a nine-leaf lingzhi, a phoenix
plume, dragon's blood) are Foundation treasures (IV). Names that promise more than
Foundation Establishment are deferred. Rarity, region, grow time, seed sources,
mutation chains, buffs and sell prices follow the tier.

| Tier | Herb | Rarity | Band | Comes from | Worth |
|---|---|---|---|---|---|
| I | Spirit Grass | Common | Inner Wilds | Herbalist 10, beasts 40% of the pool | buff +10% 3 min; sells 3 |
| I | Cloud Mint | Uncommon | Inner Wilds | Herbalist 40, beasts, mutation (Spirit Grass 15%) | +6 speed, +5% 2 min; sells 9 |
| I | Jade Lotus | Uncommon | Inner Wilds | Herbalist 60, beasts | qi, +15% 3 min; sells 14 |
| I | Ghostlamp Lily | Uncommon | Borderlands | beasts (30% of the pool) | qi, +10% 3 min; sells 18 |
| I | Purple Bamboo | Uncommon | Inner Wilds | Herbalist 80, beasts | +4 speed 3 min; sells 8 |
| II | Blood Ginseng | Rare | Outer Wastes | Herbalist 160, beasts (5-35%), mutation (Cloud Mint 10%) | qi only; sells 40 |
| II | Moonpetal Orchid | Epic | Outer Wastes | mutation (Blood Ginseng 8%) | +25% 10 min; sells 45 |
| II | Violet Cloud Fungus | Epic | Outer Wastes | wild sprouts (Auspicious Mist) | qi, +15% 5 min; sells 55 |
| II | Duskwind Thistle | Rare | Outer Wastes | beasts (35%) | qi, +5 speed; sells 55 |
| II | Spirit Peach | Rare | Outer Wastes | Herbalist 400, beasts, mutation (Purple Bamboo 4%) | qi, +15% 5 min; sells 45 |
| III | Seven-Star Grass | Epic | Deep Wilds | **Herbalist 400 from QR6**, beasts (30%), mutation (Duskwind 4%, Moonpetal 5%) | qi, +25% 10 min; sells 50 |
| III | Rift Lotus | Legendary | Deep Wilds | wild sprouts (Heaven Split), Deep Wilds bosses (10 of the boss pool), mutation (Snowpeak 3%) (prize: half a dantian) | +30% 15 min; sells 80 |
| III | Snowpeak Lotus | Epic | Deep Wilds | beasts (15%), mutation (Jade Lotus 2%) | qi, +25% 10 min; tempers +10 in seclusion; sells 50 |
| III | Emberheart Fruit | Epic | Deep Wilds | **Herbalist 600 from QR6**, beasts (25%), mutation (Spirit Peach 3%) | qi, +20% 10 min; sells 45 |
| III | Starfall Bamboo | Epic | Deep Wilds | beasts (15%), mutation (Emberheart 2%) | qi, +8 speed; sells 45 |
| IV | Dragonblood Vine | Epic | Far Reaches | **Herbalist 1200 from FE4**, beasts (40%) | qi, +35% 15 min; sells 70 |
| IV | Nine-Leaf Lingzhi | Legendary | Far Reaches | mutation (Seven-Star 1%), Far Reaches bosses (15) | qi, +40% 20 min; tempers +20 in seclusion; sells 110 |
| IV | Phoenix Plume Orchid | Legendary | Far Reaches | beasts (10%), Far Reaches bosses (5), mutation (Dragonblood 2%) | qi, +45% 20 min; sells 140 |
| IV | Thousand-Year Ginseng | Legendary | Far Reaches | the world event only (prize: a full dantian) | +45% 30 min; sells 300 |

**Re-tiered 2026-10-24** (before > after): Nine-Leaf Lingzhi III > IV (and Far Reaches
bosses instead of Deep Wilds'); Thousand-Year Ginseng III > IV; Snowpeak Lotus IV
Legendary > III Epic; Starfall Bamboo IV > III (no longer sold; Dragonblood Vine, now IV
Epic, took its FE4 shop slot). Mutation chains end at the highest kept herb of each soil:
Moonpetal now leads to Seven-Star (not Lingzhi), Seven-Star to Lingzhi at 1% (was 5%),
Jade Lotus to Snowpeak, Snowpeak to Rift Lotus, Dragonblood to Phoenix Plume; Lingzhi,
Rift Lotus and Starfall Bamboo end their chains.

**Deferred (owner, 2026-10-24): tier V and any herb past Foundation Establishment.**
Tribulation Thunder Grass, Ninefold Heaven Lotus and Dao Origin Fruit keep their defs and
models (`deferred = true`, listed in `Herbs.Deferred`) but are out of the game: not in
`Herbs.Order` (no Herbarium page, shop row, seed picker, Pavilion packet, seclusion find
or item def), in no seed or boss pool, and no herb mutates into them. They come back with
the realms past FE9 ([roadmap](../roadmap.md) "Deferred to a later update").

Also: the Pavilion sells packets (tier I 4 seeds 40 contribution from Outer, tier II 3
for 150 from Inner, tier III 2 for 450 from Core, a random Herbalist-sold herb of the
tier).

**Fortuitous encounters** (owner, 2026-10-24: the heavy player's long-term edge comes
from encounters: seclusion's finds now, world events and secret realms later; never a
stone trickle). Seclusion rolls every `FIND_SECONDS` (5 min) at `FIND_CHANCE` 0.6 an
hour (5% a roll), so value comes per minute and a 10-minute seclusion can find
something. A find, by `FINDS` weight of 100: a **herb of the player's band** 35, a
**seed of it** 45, a **seed of the next band** 5 (the rare, announced prize of rule 4;
past the Far Reaches, the band's own), Heavenly Dew 8, Cloud-Pattern Jade 4, Immortal
Peach 1, Foundation Tempering Pill 2. Never stones, never root pills. The band's herbs
are its `Herbs.Regions` pools plus the herbs whose `region` it is, **of the band's own
tier** (no carry-overs from the band below, no wild sprouts or event prizes), picked by
`FIND_RARITY` (Common 10, Uncommon 30, Rare 40, Epic 16, Legendary 0.25: leaning rare,
a find is never a weed). A roll gives a herb or seed 4.25% of the time, so every
rarity stays inside the table per roll: QR's Rares 3.8%, its Epic (Moonpetal) 0.5%, the
tier III and IV Epics 4.1-4.3%, a Legendary 0.13% (FE: Nine-Leaf Lingzhi or Phoenix
Plume, 1 in 33 Far Reaches herb or seed finds; their pity stays the mutation chain). What a band gives: QC tier I Uncommons
(Spirit Grass 10%); QR1-5 Blood Ginseng, Duskwind Thistle, Spirit Peach (29% each),
Moonpetal Orchid 12%; QR6-FE3 the four tier III Epics; FE4-9 Dragonblood Vine 97%. A
heavy secluding 12 h a night finds about 7: 2.5 herbs, 3.2 seeds, a far seed every
3 nights. In the model the found seeds pay for seed buys (about 10,800 stones' worth by
FE9) and start tier III and IV earlier; the herbs are eaten for their qi (inside the
band floors, rule 8). Worth 12% of the heavy's time to FE9; nothing for players who
don't seclude. Per hour it stays far below active play (rule 6): a FE night's finds are
about 0.4 of a dantian in herbs plus seeds, against several dantians an active hour.

### Cores, treasures and pills

| Item | Rarity | Comes from | Worth |
|---|---|---|---|
| Lesser Spirit Core | Uncommon | beasts 20-50% (wolf 20%, boar 35%, QC6-8 beasts 40-50%); bosses 100% | 2 kills' raw qi at the eater's stage (`qiKills`, a spirit wolf's qiDrop) |
| Greater Spirit Core | Epic | QC6-8 beasts 4-10%, bosses 100% | 8% of the bar, +20% cultivation 5 min |
| Heavenly Dew | Rare | heavenly treasures (weight 60 of 103), seclusion finds (8 of 100) | a full dantian, full heal |
| Cloud-Pattern Jade | Epic | treasures (30), seclusion (4 of 100) | +60 Dao XP |
| Immortal Peach | Legendary | treasures (10), seclusion (1 of 100) | 50% of the bar, full heal, +50% 10 min |
| Marrow Washing Pill | Legendary | bosses 2-4%, treasures (1); pity: every boss kill or treasure that isn't a pill gives a fragment (10 a pill); the Pavilion 3 fragments a week | a root wash (Earth 3, Heaven +5, Immortal +8) |
| Root Rebirth Pill | Epic | bosses 3-5%, treasures (2); fragments (25% with each Marrow fragment), the Pavilion 2 a week | reroll the root's element |
| Foundation Tempering Pill | Rare | every boss kill 10% (`Pacing.Tempering.BOSS_CHANCE`), the Pavilion 1 a week (120 contribution), seclusion finds (2 of 100), one from the first seclusion | absorbed in seclusion: +20 on the lowest old stage, to 100% (2 a day, 5 a week with the herbs) |
| Clear Heart Pill | Epic | every boss kill 3% (`Pacing.HeartDemon.CLEAR_BOSS_CHANCE`), the Pavilion 1 a week (250 contribution); no pity needed (Epic), the Pavilion is the sure road | absorbed while meditating: the next heart demon forgives one denial, or the latest uncalmed trial may be faced again once |

Both pills are **realm-neutral** (they pay percent points, not qi or a share of anything),
so every band's bosses drop them and the Pavilion sells them from Outer rank; never for
Robux. Tempering herbs: **Snowpeak Lotus** (III Epic, +10) and **Nine-Leaf Lingzhi** (IV
Legendary, +20) temper when eaten in seclusion, inside the same caps (the gardener's road
to tempering; the hunter's is boss pills, the sect disciple's the Pavilion).

Heavenly treasures fall in auspicious weather (Auspicious Mist 3, Rainbow Aurora 2,
Heaven Split 4 per weather) on the wilds' event grounds; first claim keeps it. In the model
a regular has 2.3 root pills by FE9, a heavy 3.4 (Earth at FE8).

### Manuals, methods and weapons

| What | Comes from |
|---|---|
| Starter manuals | kill milestones (3 / 12 / 30 / 60 / 100 kills: Fire Seal, Sword Qi Wave, Iron Skin, Moonflash Draw, Palm Strike); the Pavilion sells copies (60-250 contribution) while not owned |
| The first boss manual | the first boss kill: the best art the held class's Dao reaches |
| Boss manuals and Spirit weapons | each boss kill rolls 25% from its `bossDrops` pool |
| Class manuals and Mortal weapons | world caches and the sect weapon rack (once each) |
| Technique relics | Auspicious Clouds, Violet Cloud Mist, Golden Auspicious Clouds (events; deferred), else 60-120 stones |
| Cultivation method | a random starter at FE1 (the root's own element first); better ones aren't placed yet |

## Gaps and fixes

Fixed in the 2026-10-24 rebalance:
- Lesser cores outgrew hunting (25% of the dantian) and greater cores paid 35% of the
  bar from QC8 beasts at any stage: 2 kills' qi and 8%.
- Herb floors (tier II's 400 was 11 wolves at QC4) and low-tier herbs scaling forever:
  new floors, only the floor below the band's tier.
- The 12 h offline cap was per absence: one budget a day for offline, AFK and seclusion.
- Herb buffs stacked uncapped (+470% at FE) and promised +100-300%: falloff, a cap by
  major, and every herb's own buff at most its band's cap (tier III-V numbers cut 2-6x).
- The garden aura was weak, rarity-blind and applied everywhere: by tier x rarity over
  every plant, capped by peak tier, lifted by decorating, on your own peak only.
- The seat stacked (+1.5 cushion on 2.5): meditation pieces halved.
- Tier III-IV seeds only came from mutations and seclusion: the Herbalist sells the Epic
  tier III seeds from QR6 and Dragonblood Vine from FE4, 3 and 2 a day.
- The Herbalist had no stock limit: `STOCK` 30 / 12 / 3 / 2 a herb a player a day.
- The Pavilion's tier III packet fell back to any tier III herb (the event prizes
  included); it now draws from the Herbalist-sold ones.
- Foundation pools front-loaded per band: the carry past 150%.

Fixed the same day (owner decisions):
- **Herb tiers didn't match their names** (a Nine-Leaf Lingzhi and a Thousand-Year
  Ginseng at tier III, a Snowpeak Lotus at IV): re-tiered by how grand the name is
  (table above).
- **Tier V never dropped and is past the cap**: deferred with every herb named past
  Foundation Establishment (`Herbs.Deferred`).
- **High-tier sell prices flooded stones** (tier III-V 260-9000 a herb; a gardener
  earned 250,000 stones in FE): tier III-IV prices to 45-300, the tier II Epics to 45-55
  (one ladder). The garden road now earns about 37,000 in FE, the regular 9,500.
- **Foundation 130%+ was easy for the regular** (median 133%, 12 of 23 stages at 130%+;
  owner: "if foundation is too easy, then raise the bar"): `OVER_COST` 3 > 5. Medians 97
  / 110 / 112%; 130%+ on 1 / 3 / 7 stages (the regular's three are the band-entry stages
  QR1, QR6 and FE4, where a fresh pool lands).

Still open (proposed fix):
- **Legendary herbs have no explicit pity** (mutation chains and boss seeds only).
  **Deferred** (owner, 2026-10-24): a mutation counter per chain that guarantees the
  mutation every 1 / mutateChance harvests, built later ([roadmap](../roadmap.md)).
- **QR and FE have no same-realm beasts while variants are off**: hunts, Hunter and
  Daring deeds vanish there, so hunting falls behind meditating in FE. Re-run when
  variants ship.
- **The stone economy is a brake**: the regular's cushion arrives at FE9. Fine (no lever
  is mandatory), but re-check when stone income changes.
- **The Greater Core's and the Immortal Peach's buffs**, mutated plants' aura and
  Huge/Colossal sizes aren't in the model.
- **Foundation under 100% on thin stages**: with `OVER_COST` 5 less carries past 150%,
  so the regular seals FE1-3 and FE6-8 at 66-98% (the Deep Wilds and Far Reaches pools
  land on QR6 and FE4). Part of it is the model's planner (it plants two herb kinds in
  FE1-2, so no Gardener deed). Fix with variants (QR and FE beasts, hunts and deeds) or
  deeper band pools, not a lower bar.
- **Tier IV by mutation before its band**: Seven-Star Grass's 1% Lingzhi roll gives the
  regular a tier IV seed around FE3 in the model (heavy FE2), one stage before the Far
  Reaches band; an announced rare prize, accepted.

## Open calls (the owner's)

Decided 2026-10-24: FE nights stay as is (26-57% of an FE bar, no FE offline rate);
foundation raised by `OVER_COST` (above). The stone trickle's cut had made the heavy
x1.00 the regular (29.8 h online, +18%): the owner gave the heavy its edge back through
fortuitous encounters (seclusion's band herbs and seeds, above), not stones. Heavy
online 29.8 -> 26.1 h (x1.14; 25.2 h with the trickle), with nights 24.2 -> 21.9 h;
casual and regular unchanged.

- **The QC garden road** is 25% slower than the regular in QC (tier I herbs give little
  qi); overall it's within 15%. A bigger QC aura cap or tier I qi would close it.
