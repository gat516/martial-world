# Pacing model

What real players get, stage by stage QC1-FE9, once herbs, the garden, building,
roots, the method, cores, nights and the rest stack on top of the curve. The
header table in `src/shared/Pacing.luau` times a bare fighter (passive + ~2 wolf
kills of raw qi a minute, refined at 1.1) and a bare gardener; nobody plays like
that. This is an analysis and a proposal: nothing here is applied to the game.

- Script: `python3 tools/pacing_model.py` (stdlib Python, outside Studio). It
  parses `Pacing.luau`, `Herbs.luau`, `Config.luau`, `BuildItems.luau` and
  `Weather.luau` on every run, so a tuning change shows on the next run.
  Flags: `--stages` (per-stage rates), `--sources` (where cultivation came from),
  `--levers` (one lever off at a time), `--foundation` (foundation percent per
  stage), `--proposal` (the proposed knobs, side by side).
- Player behaviour (`PROFILES`, `ASSUME`, `FOUNDATION_HABITS` in the script) and a
  few per-item numbers (`LESSER_CORE_SHARE`, `GREATER_CORE_BAR`, the event, treasure
  and mutation rates) are transcribed assumptions: edit them there.

## Method

A minute-by-minute calendar simulation per profile. Each day has the profile's
sessions; each online minute is split between hunting (`fight_share`) and sitting on
the peak (meditating and circulating; `Meditating` covers circulation, so passive
runs at the seat's multiplier while refining).

- **Hunting minute:** passive (unseated) plus the header's 2 wolf-equivalents of kill
  qi (`14 * (dantian/120)^0.8 * gather`), times the method and the party factor,
  refined at the profile's efficiency x root x method (refining time netted, as in
  the header). Lesser cores (0.2 per wolf-equivalent, `0.25 x dantian` each) and
  greater cores (0.01 per wolf-equivalent from QC6, `0.35 x bar`) and heavenly
  treasures (dew, peach, pity fragments) come on top.
- **Seated minute:** passive x (ON_PEAK + peak score x 0.004 + best meditation piece)
  x (1 + herb QiRate buffs) x (1 + aura) x (1 + weather) x root x method, and refines
  queued raw qi (herbs, cores, daily qi, dew) at up to `dantian / RUNS_PER_DANTIAN`
  a minute (one full run a minute).
- **Garden:** plants per plot = an assumed plot area / spacing^2 (bed 24, pond 28,
  grove 48 studs^2: the PlotAnchor sizes live in the place file). Harvests a day from
  grow times, the online growth bonus (peak score) and seclusion's +50% at night. The
  plan per soil: standing aura plants, a mutation-chase bed, the strongest QiRate buff
  herbs for the uptime wanted, then the most raw qi a plant-day. Plants that ripen
  between sessions stand mature (aura) through the session and are picked at its end.
  Herb qi is `max(EAT_SHARE[tier] x dantian, EAT_FLOOR[tier])`; surplus is sold.
- **Acquisition (expected values):** Spirit Stones from hunting (~10 a hunting minute:
  ~0.3 stones per qiDrop plus nodes), sect dailies (`DAILY_STONES`), seclusion
  (`STONES_PER_HOUR` with the streak), quests and herb sales buy, in order: the herb
  tier (re-seeding every plot from the Herbalist), beds, the Meditation Cushion,
  ponds, groves, then the cheapest peak-score pieces. Tier II is in the Herbalist
  (Blood Ginseng 160); tier III and up only come from harvest mutations
  (`mutateChance` 2-5%, then 0.5-3%) and seclusion's rare seed (`SEED_TIER`), because
  the Deep Wilds and Far Reaches aren't map regions and bosses there don't exist.
  Root pills: bosses (`boss_per_hour` x (3% pill + a pity fragment)), treasures'
  pity fragments and the Pavilion's 3 Marrow fragments a week; Earth at 3 pills.
- **Offline/AFK:** each absence credits `min(12 h, gap) x passive`, up to the overflow
  cap (1.5 bar); the carry keeps it all. Breakthroughs happen only online.
- **Check:** the bare fighter reproduces the header (QC 2.4 h, QR 7.1 h, FE 19.8 h).

### Profiles

| | Casual | Regular | Heavy |
|---|---|---|---|
| Sessions | 30 min at 19:00 | 90 min at 19:00 | 60 min at 08:00, 120 at 18:00 |
| Hunting share | 55% | 55% | 50% |
| Refine (cultivation per raw qi) | 1.0 | 1.1 | 1.25 |
| Plots wanted (beds/ponds/groves) QC / QR / FE | 3/1/0, 5/1/0, 8/1/1 | 8/2/1, 12/2/2, 16/3/2 | 16/4/3, 20/4/3, 24/4/3 |
| Peak score wanted | 12 / 40 / 70 | 30 / 90 / 160 | the tier's cap |
| Meditation Cushion | no | from QC6 | from QC5 |
| QiRate buffs kept up | none | 2 at 60% | 4 at 100% |
| Mutation chase / standing aura plants | 0 / 0 | 1 bed / 2 | 3 beds / 4 |
| Party share of hunting, sect dailies, bosses an hour | 0, 1, 0.2 | 25%, 2, 0.5 | 40%, 3, 1.2 |
| Seclusion nightly | no | no | yes |

## Results today (Global = 1, Adjust empty)

Active hours / calendar day. "Online only" turns off offline credit, which is what the
header's active targets mean.

| | QC4 | QC9 | QC done | QR9 | QR done | FE9 | FE9 full |
|---|---|---|---|---|---|---|---|
| Header target (active) | 9-10 min | | 2.4 h | | 9.5 h | | 29.3 h |
| Casual | 5 min / d1 | 56 min / d2 | 1.0 h / d3 | 2.8 h / d6 | 3.0 h / d7 | 5.0 h / d11 | 5.5 h / d12 |
| Regular | 4 min / d1 | 1.2 h / d1 | 1.5 h / d2 | 4.3 h / d3 | 4.5 h / d4 | 7.5 h / d6 | 7.9 h / d6 |
| Heavy | 4 min / d1 | 59 min / d1 | 1.0 h / d1 | 3.6 h / d2 | 4.0 h / d2 | 7.0 h / d3 | 7.0 h / d3 |
| Casual, online only | | | 1.6 h | | 5.2 h | | 10.9 h |
| Regular, online only | | | 1.7 h | | 5.4 h | | 9.8 h |
| Heavy, online only | | | 1.5 h | | 4.7 h | | 8.0 h |

**Every profile is about 3-4x faster than the targets**, and FE9, meant to be hard to
reach, is reached on day 3 (heavy), day 6 (regular) and day 12 (casual, 30 min a day).
(QC4 at 4-5 min leaves out the onboarding's talk and travel.) With every lever off,
the same profiles take 34-37 h, so the curve itself is sound; the extras are not in it.

Where the cultivation came from (`--sources`): nights are 50-64% of a casual's QR and
FE, 30-40% of a regular's; cores (lesser + greater) are 15-30% for everyone; seated
passive grows to a third of the heavy's FE; herbs are only 2-14% today because stones
can't keep up.

### Levers, one at a time (`--levers`, to FE9 full)

| Lever off | Casual | Regular | Heavy |
|---|---|---|---|
| Offline credit | +97% | +23% | +13% |
| Spirit cores | +18% | +33% | +18% |
| Herb qi | +18% | +14% | +3% |
| Method (FE) | +9% | +14% | +9% |
| Buffs, party, weather, seclusion finds | 0% | 6-8% | 5-13% |
| Aura, peak score, cushion, root | 0% | 0% | 0% |
| The stone economy (everything bought at once) | -9% | -43% | -66% |

Levers substitute for each other: the seat refines up to `0.4 x dantian` raw qi a
minute, about 5x what hunting brings in, so any extra raw qi (herbs, cores, dew,
daily qi) fills the same headroom, and turning one off lets the others take its place.
Turning one on alone shows its real size: from a bare 23.4 h of FE (regular, online
only, garden bought outright), herb qi alone cuts it to 7.8 h, herb buffs to 8.7 h,
cores to 10.5 h, aura to 13.2 h, the method to 17.8 h, the cushion to 19.4 h. The
one-lever table understates every lever.

**The stone economy is the hidden brake.** At today's speed a regular earns about
4,000 stones on the way to FE9, enough for a few beds: the garden, the cushion and
the peak score arrive late or never (the casual's beds never hold a qi herb in QC).
Bought outright, the regular is 43% faster and the heavy 66%. Slowing the curve gives
players time to earn, so these levers grow back: the proposal is solved with the
economy on.

### Findings by lever

- **Herbs (too strong where the economy allows).** The share-of-dantian rule lets
  the cheapest fast herb win at every stage: Blood Ginseng (tier II, 15 min, shop)
  gives 9% of the dantian (or its 400 floor) and is picked ~8 times a session, so one
  bed out-earns all of a regular's hunting from QC6 to FE9. Higher tiers grow 6-96x
  slower for 12-20% instead of 9%: they're worth planting only for buffs. Tier II's
  400 floor alone is 11 wolves at QC4.
- **Spirit cores (too strong, and they scale wrong).** A lesser core is 25% of the
  dantian, so it grows with the dantian while kill qi grows with dantian^0.8: a
  core is 2.7 wolves at QC4 and 7 at FE9. A greater core is 35% of the *bar*: one
  QC8 thunder beast kill at 10% is worth 0.035 bars at any stage, so QR and FE players
  farm the QC8 beasts (the only ones on the map) for bar shares.
- **Offline (as designed, with one hole).** A 12 h night fills the 1.5 cap at almost
  every stage: about a stage a night, as decided. The hole: the 12 h cap is per
  absence, so two logins a day (the heavy) earn up to 24 h.
- **Herb buffs (uncapped).** QiRate buffs from different herbs add up with no cap:
  at FE the four strongest tier III-IV buffs are +470%, and tier V adds up to +300%
  each. They only matter once the economy lets a player grow them, then they
  dominate seated passive.
- **Garden aura (weak per plant, and it sits everywhere).** `Cultivation.aura` sums
  every mature, unharvested plant (`aura x size x mutations`), capped at
  `AURA_CAP` 1.5, and applies to all online passive wherever the player is (no peak
  check). Per plant it does scale with tier (I 0.007-0.013, II 0.017-0.03, III
  0.045-0.1, IV 0.1-0.14, V 0.2-0.3), but rarity adds nothing on its own, and one
  standing Legendary is +5% (Nine-Leaf Lingzhi) to +14% (Phoenix Plume Orchid). In
  the model the heavy's garden (four plants kept standing) gives 0 in QC, 0.1-0.36 in
  QR and 0.36-0.52 in FE; the cap needs a dozen tier IV plants.
  It does not deliver "a legendary plant in my spirit cove speeds me up".
- **Peak score (cheap).** Points cost 2.5-10 stones each (fences, buckets, troughs):
  the QC cap of 60 is ~265 stones. Meditation +0.24/+0.6/+1.0 and growth +12/30/50%
  at the caps. With the cushion (+1.5, best piece in range only) the seat reaches 5.0
  at FE, double the header's 2.5.
- **Spirit root (rare, as meant).** Earth needs 3 Marrow pills: bosses give ~0.13 a
  kill (3% pill + a pity fragment), treasures a fragment, the Pavilion 0.3 a week.
  Today nobody reaches Earth before FE9; with the proposal only the heavy does, at FE8.
- **Cultivation method (FE1 on).** The starter is the root's own element, so 1.1 + 0.1
  match = 1.2 on passive (online), refining, kill and node qi; not on offline, herbs,
  cores or daily qi. Better methods aren't placed yet. Techniques don't touch
  cultivation speed (only `Cultivation`, `Circulation`, `QiNodes` and `EnemyService`
  read `methodSpeed`).
- **Foundation bonus: combat only.** `Foundation.multiplier` scales max health and
  power; it never touches cultivation.
- **Parties: modest.** The group bonus is +5% a member (cap 15%), but KILL_SHARE 10%
  lets every member who chipped in take full kill qi; the model assumes 1.4x kill qi
  a party minute.
- **Daily qi, weather, seclusion finds: small.** Daily qi is half a dantian a day;
  weather averages +4.9% passive and +0.6% circulation; a seclusion night rolls ~1.2
  rare finds (0.43 Heavenly Dew, 0.04 Immortal Peach, 0.5 seed of the next tier: the
  heavy's fastest road to tier III).

### Acquisition (expected values, `acq` in the script)

| | Root pills by FE9 | Tier III seeds | Tier IV seeds | Stones earned QC / QR / FE |
|---|---|---|---|---|
| Casual, today | 0.4 | never | never | 400 / 1,000 / 2,100 |
| Regular, today | 0.8 | FE3, day 4 | never | 560 / 1,360 / 2,150 |
| Heavy, today | 1.1 | QR6, day 1 | never | 300 / 1,970 / 3,840 |
| Casual, proposal | 1.3 | FE5, day 21 | never | 600 / 1,800 / 9,700 |
| Regular, proposal | 2.3 | QR7, day 4 | FE7, day 13 | 780 / 2,500 / 10,300 |
| Heavy, proposal | 3.2 (Earth at FE8) | QR5, day 2 | FE2, day 4 | 480 / 3,700 / 17,900 |

Herb seeds also drop from beasts (`BEAST_SEED_CHANCE` 12% a kill from the region's
pool: Blood Ginseng 5-35%), so tier II is never the gate; tier V never arrives (Far
Reaches bosses only, 0.5-1% mutations). The Herbalist has no stock limit.

## Proposal (not applied)

Trims first (each a knob or a small rule), then the bars re-solved so the regular's
online-only hours meet the header's targets. `--proposal` runs all of it.

| Change | Where | Why |
|---|---|---|
| Lesser Spirit Core: 2 kills' qi at the eater's stage (`dantian^0.8` like kills), not 25% of the dantian | `Items.luau` `use` (a new `qiKills` field) | stops cores outgrowing hunting |
| Greater Spirit Core: 8% of the bar, not 35% | `Items.luau` | a bar share per QC8 kill at any stage |
| Herbs below the stage's band tier (`Herbs.Regions`) give only their floor | `Herbs.eatQi` | fast low-tier herbs stop scaling; each band's own tier is the garden's qi |
| `EAT_FLOOR` 120/400/2500/8000/20000 -> 60/150/900/3000/8000 | `Pacing.Herbs` | tier II's floor was 11 wolves at QC4 |
| One 12 h AFK/offline budget a day, shared by every absence | `Cultivation.claimLogin`, AFK budget | two logins doubled the night |
| Only the strongest QiRate herb buff counts | `Cultivation.buffTotal` (max, not sum) | buff stacking was uncapped |
| `PeakScore.MEDITATION` 0.004 -> 0.0024 | `Pacing.PeakScore` | +0.6 at the FE cap, not +1.0 |
| Aura by tier and rarity, capped by peak tier, on your own peak only (below) | `Herbs.luau` `aura`, `Config.Garden`, `Cultivation.rate` | the owner's intent |
| Bars: `Pacing.Adjust` `bar` x1.15 for QC1-9, x1.8 for QR1-9, x5.1 for FE1-9 | `Pacing.Adjust` (or fold into the curve) | the stacked extras, after the trims |

**The aura proposal.** A planted herb's aura = `AURA_BY_TIER` (I 0.02, II 0.05, III
0.15, IV 0.3, V 0.6) x rarity (Common 1, Uncommon 1.1, Rare 1.25, Epic 1.5,
Legendary 2) x size x mutations, summed over mature standing plants, capped by the
peak tier (QC 0.3, QR 0.6, FE 1.0), and it multiplies **meditation on your own peak**
(the air of your spirit cove) instead of all passive everywhere. One standing
Legendary tier III herb (Nine-Leaf Lingzhi) is +30% on the peak, a Legendary tier IV
(Phoenix Plume Orchid) +60%, so keeping one unpicked is a real choice against eating
it. In the model the heavy's four kept plants reach the cap by QR5; the regular's two
reach about half. A higher FE cap (2.0 was tried) pushes the FE bar multiplier to x6.3.

**With the proposal** (bars x1.15 / x1.8 / x5.1):

| | QC done | QR done | FE9 | FE9 full |
|---|---|---|---|---|
| Casual | 1.5 h / d4 | 5.0 h / d11 | 15.0 h / d31 | 16.5 h / d34 |
| Regular | 2.2 h / d2 | 7.5 h / d6 | 21.3 h / d15 | 23.3 h / d16 |
| Heavy | 1.6 h / d1 | 6.5 h / d3 | 19.1 h / d7 | 20.6 h / d7 |
| Regular, online only | 2.4 h | 9.5 h | 26.9 h | 29.2 h |
| Bare fighter (the old header) | 2.8 h | 15.6 h | 101.6 h | 116.5 h |

The regular now matches the targets online (2.4 / 7.1 / 19.8 h a realm) and lands
near the header's mixed player with nights (1 h/day: FE8 on day 15). The casual
needs a month for FE9, the heavy a week.

**Read the FE x5.1 with care.** FE is where every extra stacks (the method x1.2,
aura, the strongest buffs at tiers III-IV, the richest garden, cores), and today's FE
bars were sized for a bare fighter who never meditates. x5 bars would make the
header's "no stage over about 3 h" true only for players who use the systems, and a
night would fill a third of an FE bar instead of a whole one. Gentler routes to the
same place: an FE aura cap of 0.6 and no tier IV+ QiRate buffs above +100%, then
re-solve (`solve_bars`). If the owner wants nights to stay "about a stage", raise FE
`passive` with the bars.

## Foundation percent (TARGET, OVER_COST)

`--foundation` estimates the weighted experiences each profile earns per graded stage
(QC4-FE8) from `Foundation.luau`'s sources on today's map (variants off): first
kills by beast and band (`FIT_BELOW` 3), bosses (x2), deeds (Hunter needs 3+ kinds
within 2 stages below, Gardener 3 kinds harvested, Haul 75% of the dantian in one
trip, Daring 2 stages up in the same major), the band's herb tier, rare mutations
(weather and peak rolls on growing plants), Herbarium pages, Dao levels (XP a hunting
minute), caches (assumed 3/3/2/0/0 per band), world events (~4.6 an hour server-wide)
and treasures, and the sect (chain, Inner, Core). Expected values, so fractional.

Today's knobs (QC4 2, then 3, OVER_COST 3, MAX 150), on the proposed curve: casual
median 93%, regular 109%, heavy 109%. Three structural problems, before any tuning:

1. **Band pools are front-loaded.** A band's first stage takes most of its pool
   (QC4-6, QR1, QR6 and FE4 at 150%), the stages after it starve (FE1-3 and FE6-8
   near 50% for everyone).
2. **QR and FE have no beasts at their realm** (variants off), so Hunter, Daring and
   hunts are gone there: only Gardener, Haul, events, mutations and Dao remain. QR/FE
   need a lower target than QC (or variants on).
3. **Slept stages are empty.** A casual crosses some stages almost entirely offline
   (QR2, QR4, QR7 in the run) and they seal near 5-12%: the designed cost of
   sleeping through, but it drags the casual's mean down.

Solved for medians of casual ~95, regular ~105, heavy ~135 (`solve_foundation`):

| Option | TARGET | OVER_COST | Casual | Regular | Heavy |
|---|---|---|---|---|---|
| Today | QC4 2, QC5-9 3, rest 3 | 3 | 93% | 109% | 109% |
| Retune only | QC4-9 5, rest 2.5 | 1.5 | 100% (5 stages 130%+) | 116% | 126% |
| **Retune + carry** | QC4-9 4, rest 2.5 | 3 | **100%** (3 stages 130%+) | **118%** | **133%** |

Recommended: **TARGET 4 for QC4-QC9, DEFAULT_TARGET 2.5, OVER_COST 3, MAX 150, plus a
carry rule**: experiences earned past what MAX_PERCENT needs carry into the next
stage instead of being lost (a small `Foundation.seal` change). It smooths the
front-loaded pools, keeps 130%+ mostly for the heavy and keeps OVER_COST at 3 (so
130-140% stays real effort). Without the carry, OVER_COST has to drop to 1.5 and the
casual reaches 130% on five stages. Re-run once variants are on: QR/FE then get
hunts and deeds back, and their target should rise toward QC's.

## Known gaps

- Untested in play. Plot sizes, kill rate, stone rate, boss and treasure appetite,
  event participation and cache counts are assumptions in the script.
- The economy buys in one fixed order and never re-seeds a soil's herb after its
  tier is paid; seed counts are assumed to keep up (1-2 seeds back a harvest).
- Herbs harvested at session start are spread over the session; surplus herb qi is
  sold, never stockpiled past a day.
- Heaven-defiers (x1.5 bars, tribulations), Grow now, Robux and alchemy (not built)
  are out of the model.
