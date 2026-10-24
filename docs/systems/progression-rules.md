# Progression rules

The rulebook for how fast players climb and what they get along the way. Every new
reward, drop, item, multiplier, spawn or respawn change gets a row here and a run of
the [pacing model](pacing-model.md) (`python3 tools/pacing_model.py`) before it merges.
The `progression-designer` agent owns this file. Numbers live in
`src/shared/Pacing.luau` (and `Herbs.luau`, `Items.luau`, `Enemies.luau`,
`BuildItems.luau`); this page says what they must add up to. Last full pass: the
2026-10-24 rebalance (owner-approved).

## Targets

| | Target (active, the regular player online) | Built (model) |
|---|---|---|
| Qi Condensation | about 2.4 h; the first session lands 2-3 breakthroughs (QC4 by 9-10 min with the onboarding's talk) | 2.4 h, QC4 at 5 min of play |
| Qi Refining | about 7 h; the real slowdown from QR4, where the garden and the peak carry | 7.1 h |
| Foundation Establishment | about 20 h; no stage over about 3 h; FE9 is the cap | 19.8 h, stages 1.7-2.7 h |
| A gardener (garden and meditate road) | gets there, 1.5-2x slower at most | +12% overall (QC +25%) |
| A night (12 h offline or AFK) | about one stage, never two | QC/QR: the 1.5 cap; FE: 26-57% of a bar (open call) |

"The regular player" is the model's regular profile (1.5 h a day, hunts about half the
time, a growing garden, a cushion, some building, a party a quarter of the time). With
nights the regular finishes FE9 on about day 16, a casual (30 min a day) on day 29, a
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
   every run (now: hunter +10%, gardener +12%, everything x1.19).
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

## Multipliers and their caps

Online passive per second = `passive x (1 + herb buffs) x (1 + aura, own peak only) x
(1 + weather) x seat x root x method`. Refining = `raw qi x efficiency x refine x
root x method x (1 + weather circulation)`.

| Multiplier | Applies to | Value | Cap / limit | Where |
|---|---|---|---|---|
| Meditation seat | seated passive | anywhere x1.5, own peak x2.5, outdoor sites | one seat | `Pacing.Meditation` |
| Meditation piece (best in range, own peak) | adds to the seat | Cushion +0.75, Spirit Stone +0.5, Mat +0.4, Incense +0.25 | the best one only | `BuildItems` `meditation` |
| Peak score | adds to the seat on your peak; plant growth | +0.0024 a point; growth +0.002 a point | the tier's `scoreCap` 60 / 150 / 250 (seat +0.14 / +0.36 / +0.6; growth +12 / 30 / 50%) | `Pacing.PeakScore` |
| Garden aura | x the seat on your own peak | every planted herb: `BY_TIER` 0.02 / 0.05 / 0.15 / 0.3 / 0.6 x `RARITY` (C 1, U 1.1, R 1.25, E 1.5, L 2) x size x mutations, half while growing | QC 0.3, QR 0.6, FE 1.0, lifted up to +25% by the peak score (decorate your abode) | `Pacing.Aura` |
| Herb and item QiRate buffs | all online passive | per herb +5% (tier I) to +50% (tier V); Greater Core +20%, Immortal Peach +50% | falloff 1 / 0.5 / 0.25 / 0, then QC 0.2, QR 0.3, FE 0.5 | `Pacing.Herbs.BUFF_FALLOFF`, `BUFF_CAP` |
| Weather | passive / circulation | mean +4.9% / +0.6% (one weather at a time, up to +100% passive for minutes) | one weather | `Weather.luau` |
| Spirit root | passive, refining | Spirit 1, Earth 1.1, Heaven 1.25, Immortal 1.4 | the grade (pills, below) | `Pacing.Roots` |
| Cultivation method | passive, refining, kill and node qi (online) | Sect Breathing 1.0; starters 1.1 (+0.1 matching the root) from FE1 | the method | `Pacing.Methods` |
| Party | kill qi | +5% a nearby member; shared credit (`KILL_SHARE` 10%, helpers 50%) | +15% | `Pacing.Party` |
| Stage `gather` (curve) | raw qi income | QR1 x2, QR2 x1.6, QR7 x1.6, FE4 x1.25, FE7 x1.15 | per stage | `Pacing.Curve` |
| Foundation bonus | health and power only (never cultivation) | +1% by 100%, +2% more by 150%, per stage | 150% | `Pacing.Foundation` |
| Heaven-defier | bars | x1.5 | | `Pacing.HeavenDefying` |
| Pacing.Adjust (the rebalance) | bars | QC4-9 x1.15, QR x1.65, FE x4.2 | solved by the model | `Pacing.Adjust` |

**Decorate your abode** (owner, 2026-10-24): building raises the peak score, which adds
to meditation on your peak, speeds your plants, and lifts how much spirit energy the
abode can hold (the aura cap, up to +25% at the score cap). A fuller, rarer garden fills
it. Each is a modest reward: in the model the score is worth about 7% to a heavy
builder, the aura 7-9%, the cushion 2%; none is needed to reach the targets.

## Faucets and sinks

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
(15-800) and pages (150-8000), seclusion (25 / 60 / 150 an hour), herb sales (`sellPrice`
3-9000), event relic fallbacks (60, 120), a reclaimed spill. Sinks: the Herbalist's seeds,
build pieces (the decor shop), technique comprehension, the death spill, fleeing. A
regular earns about 13,000 stones to FE9 (QC 780, QR 2,500, FE 10,000).

**Sect contribution**: dailies (25-60 each) and sheltering (2 a kill), inside a 700-a-week
cap; the chain (60, final 150); promotions are by contribution earned. Sink: the Pavilion
(seed packets, root pill fragments, the ring's slot, manual copies).

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
below, repeated, which is its own slow pity) and boss seed pools.

## Where things come from

Bands (`Herbs.Regions`): Inner Wilds QC1-4 and Ruined Borderlands QC5-9 (tier I), Outer
Wastes QR1-5 (II), Deep Wilds QR6-FE3 (III), Far Reaches FE4-9 (IV; V from its bosses).
Deep Wilds and the Far Reaches aren't map regions yet: their seeds drop only by a beast's
realm (variants, the testbed).

### Herbs and seeds

Herb qi: `EAT_SHARE` 6 / 9 / 12 / 16 / 20% of the eater's dantian by tier, at least
`EAT_FLOOR` 60 / 150 / 900 / 3000 / 8000; **below the eater's band tier only the floor**.
Event herbs (`PRIZE`) keep their share anywhere. Seeds back on harvest: 1-2. Beast seeds:
12% a kill per damager from the band's pool; bosses 2-4 seeds, plus their `bossSeeds`.
The Herbalist: `STOCK` 30 / 12 / 3 / 2 seeds of a herb a player a day for tiers I-IV.

| Tier | Herb | Rarity | Band | Comes from | Worth |
|---|---|---|---|---|---|
| I | Spirit Grass | Common | Inner Wilds | Herbalist 10, beasts 40% of the pool | buff +10% 3 min; sells 3 |
| I | Cloud Mint | Uncommon | Inner Wilds | Herbalist 40, beasts, mutation (Spirit Grass 15%) | +6 speed, +5% 2 min; sells 9 |
| I | Jade Lotus | Uncommon | Inner Wilds | Herbalist 60, beasts | qi, +15% 3 min; sells 14 |
| I | Ghostlamp Lily | Uncommon | Borderlands | beasts (30% of the pool) | qi, +10% 3 min; sells 18 |
| I | Purple Bamboo | Uncommon | Inner Wilds | Herbalist 80, beasts | +4 speed 3 min; sells 8 |
| II | Blood Ginseng | Rare | Outer Wastes | Herbalist 160, beasts (5-35%), mutation (Cloud Mint 10%) | qi only; sells 40 |
| II | Moonpetal Orchid | Epic | Outer Wastes | mutation (Blood Ginseng 8%) | +25% 10 min; sells 110 |
| II | Violet Cloud Fungus | Epic | Outer Wastes | wild sprouts (Auspicious Mist) | qi, +15% 5 min; sells 150 |
| II | Duskwind Thistle | Rare | Outer Wastes | beasts (35%) | qi, +5 speed; sells 55 |
| II | Spirit Peach | Rare | Outer Wastes | Herbalist 400, beasts, mutation (Purple Bamboo 4%) | qi, +15% 5 min; sells 45 |
| III | Seven-Star Grass | Epic | Deep Wilds | **Herbalist 400 from QR6**, beasts, mutation (Duskwind 4%), seclusion | qi, +25% 10 min; sells 320 |
| III | Nine-Leaf Lingzhi | Legendary | Deep Wilds | mutation (Moonpetal 5%, Seven-Star 5%), Deep Wilds bosses (15 of the boss pool) | qi, +30% 15 min; sells 600 |
| III | Thousand-Year Ginseng | Legendary | Deep Wilds | the world event only (prize: a full dantian) | +30% 20 min; sells 3000 |
| III | Rift Lotus | Legendary | Deep Wilds | wild sprouts (Heaven Split), mutation (Jade Lotus 2%) (prize: half a dantian) | +30% 15 min; sells 700 |
| III | Emberheart Fruit | Epic | Deep Wilds | **Herbalist 600 from QR6**, beasts, mutation (Spirit Peach 3%), seclusion | qi, +20% 10 min; sells 260 |
| IV | Dragonblood Vine | Legendary | Far Reaches | beasts (25%), mutation (Lingzhi 3%) | qi, +40% 20 min; sells 1400 |
| IV | Phoenix Plume Orchid | Legendary | Far Reaches | beasts (15%) | qi, +45% 20 min; sells 2000 |
| IV | Snowpeak Lotus | Legendary | Far Reaches | beasts (25%), mutation (Rift Lotus 3%) | qi, +35% 15 min; sells 1200 |
| IV | Starfall Bamboo | Epic | Far Reaches | **Herbalist 1200 from FE4**, beasts (35%), mutation (Emberheart 2%), seclusion | qi, +8 speed; sells 500 |
| V | Tribulation Thunder Grass | Legendary | Far Reaches bosses | boss seeds (6), mutation (Dragonblood 1%) | qi, +50% 20 min; sells 5000 |
| V | Ninefold Heaven Lotus | Legendary | Far Reaches bosses | boss seeds (4), mutation (Snowpeak 1%) | qi, +50% 30 min; sells 7000 |
| V | Dao Origin Fruit | Legendary | Far Reaches bosses | boss seeds (2), mutation (Starfall 0.5%) | qi, +50% 30 min; sells 9000 |

Also: seclusion's hourly rare find (10% an hour; Seed 60 of 140 by weight) gives a seed of
the next tier by major (QC II, QR III, FE IV); the Pavilion sells packets (tier I 4 seeds
40 contribution from Outer, tier II 3 for 150 from Inner, tier III 2 for 450 from Core, a
random Herbalist-sold herb of the tier).

### Cores, treasures and pills

| Item | Rarity | Comes from | Worth |
|---|---|---|---|
| Lesser Spirit Core | Uncommon | beasts 20-50% (wolf 20%, boar 35%, QC6-8 beasts 40-50%); bosses 100% | 2 kills' raw qi at the eater's stage (`qiKills`, a spirit wolf's qiDrop) |
| Greater Spirit Core | Epic | QC6-8 beasts 4-10%, bosses 100% | 8% of the bar, +20% cultivation 5 min |
| Heavenly Dew | Rare | heavenly treasures (weight 60 of 103), seclusion finds (50 of 140) | a full dantian, full heal |
| Cloud-Pattern Jade | Epic | treasures (30), seclusion (25) | +60 Dao XP |
| Immortal Peach | Legendary | treasures (10), seclusion (5) | 50% of the bar, full heal, +50% 10 min |
| Marrow Washing Pill | Legendary | bosses 2-4%, treasures (1); pity: every boss kill or treasure that isn't a pill gives a fragment (10 a pill); the Pavilion 3 fragments a week | a root wash (Earth 3, Heaven +5, Immortal +8) |
| Root Rebirth Pill | Epic | bosses 3-5%, treasures (2); fragments (25% with each Marrow fragment), the Pavilion 2 a week | reroll the root's element |

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
  tier III seeds from QR6 and Starfall Bamboo from FE4, 3 and 2 a day.
- The Herbalist had no stock limit: `STOCK` 30 / 12 / 3 / 2 a herb a player a day.
- The Pavilion's tier III packet fell back to any tier III herb (the event prizes
  included); it now draws from the Herbalist-sold ones.
- Foundation pools front-loaded per band: the carry past 150%.

Still open (proposed fix):
- **Tier V never drops on today's map** (Far Reaches bosses don't exist): the heavy
  reaches it by mutation at FE8. Fix with the Far Reaches map and its bosses; until then
  accept it (it's past the cap's band).
- **Legendary herbs have no explicit pity** (mutation chains only). Proposed: a mutation
  counter per chain that guarantees the mutation every 1 / mutateChance harvests.
- **High-tier sell prices flood stones** (tier III-V 260-9000 a herb; a gardener selling a
  third of a tier III-IV garden earns 250,000 stones in FE). Stones buy no speed past the
  score and plot caps, so it isn't a pace problem, but it empties every other stone
  reward. Proposed: tier III+ `sellPrice` about a tenth, or a daily sell cap at the
  Herbalist.
- **QR and FE have no same-realm beasts while variants are off**: hunts, Hunter and
  Daring deeds vanish there, so hunting falls behind meditating in FE. Re-run when
  variants ship.
- **The stone economy is a brake**: the regular's cushion arrives at FE9. Fine (no lever
  is mandatory), but re-check when stone income changes.
- **The Greater Core's and the Immortal Peach's buffs**, mutated plants' aura and
  Huge/Colossal sizes aren't in the model.

## Open calls (the owner's)

- **FE nights.** With FE bars x4.2 a 12 h night is 26-57% of an FE bar, not "about one
  stage". Options: accept (FE is the long realm), or an FE-only offline rate (x2-3 would
  make a night about half to one stage; AFK would still trail active play but match bare
  meditation on the peak). Raising FE passive doesn't work: it speeds online play too and
  breaks the hunter's road.
- **Foundation 130%+ is easy for the regular on this curve** (median 133%, 12 of 23
  stages at 130%+ with the approved knobs). `OVER_COST` 4 gives medians 97 / 114 / 123%.
- **The QC garden road** is 25% slower than the regular in QC (tier I herbs give little
  qi); overall it's within 15%. A bigger QC aura cap or tier I qi would close it.
