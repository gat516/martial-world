# Pacing model

What real players get, stage by stage QC1-FE9, once herbs, the garden, building,
roots, the method, cores, nights and the rest stack on top of the curve, and the
check that no lever is mandatory. The rules it enforces are in
[progression rules](progression-rules.md); the 2026-10-24 rebalance (owner-approved)
was solved with it and is applied.

- Script: `python3 tools/pacing_model.py` (stdlib Python, outside Studio). It
  parses `Pacing.luau` (curve, `Adjust`, `Herbs`, `Aura`, `Meditation`, `PeakScore`,
  `Foundation`...), `Herbs.luau`, `Items.luau`, `Config.luau`, `BuildItems.luau` and
  `Weather.luau` on every run, so a tuning change shows on the next run. Herbs marked
  `deferred = true` (`Herbs.Deferred`, tier V) are skipped, and the mutation unlocks stop
  at the highest kept tier. Every run
  prints the profiles, the **balance check** and the **header check**.
  Flags: `--stages` (per-stage rates), `--sources` (where cultivation came from),
  `--levers` (one lever off at a time), `--foundation` (foundation percent per
  stage), `--header` (the `Pacing.luau` time table for this curve, to paste),
  `--proposal` (the knob rows in `PROPOSAL`, side by side, bars re-solved; empty now).
- Player behaviour (`PROFILES`, `ROADS`, `ASSUME`, `FOUNDATION_HABITS` in the script)
  and a few rates (events, treasures, mutations, caches) are transcribed
  assumptions: edit them there.

## Method

A minute-by-minute calendar simulation per profile. Each day has the profile's
sessions; each online minute is split between hunting (`fight_share`) and sitting on
the peak (meditating and circulating; `Meditating` covers circulation, so passive
runs at the seat's multiplier while refining).

- **Hunting minute:** passive (unseated, x herb buffs) plus the header's 2
  wolf-equivalents of kill qi (`14 * (dantian/120)^0.8 * gather`), times the method
  and the party factor, refined at the profile's efficiency x root x method (refining
  time netted, as in the header). Lesser cores (0.2 per wolf-equivalent, 2 kills' qi
  each) and greater cores (0.01 per wolf-equivalent from QC6, 8% of the bar) and
  heavenly treasures (dew, peach, pity fragments) come on top.
- **Seated minute:** passive x (ON_PEAK + peak score x 0.0024 + best meditation
  piece) x (1 + aura) x (1 + herb buffs) x (1 + weather) x root x method, and refines
  queued raw qi (herbs, cores, daily qi, dew) at up to `dantian / RUNS_PER_DANTIAN`
  a minute (one full run a minute).
- **Herb buffs:** the profile keeps its N strongest distinct QiRate herbs up for its
  uptime; they count with `BUFF_FALLOFF` (1, 0.5, 0.25) and stop at `BUFF_CAP` by major.
- **Garden:** plants per plot = an assumed plot area / spacing^2 (bed 24, pond 28,
  grove 48 studs^2: the PlotAnchor sizes live in the place file). Harvests a day from
  grow times, the online growth bonus (peak score) and seclusion's +50% at night. The
  plan per soil: standing aura plants, a mutation-chase bed, the strongest QiRate buff
  herbs for the uptime wanted, then the most raw qi a plant-day. Herb qi is
  `max(EAT_SHARE[tier] x dantian, EAT_FLOOR[tier])`, only the floor below the band's
  tier. A profile can sell a share of its qi herbs (`sell_share`); surplus is sold.
- **Aura:** every planted herb, `BY_TIER x RARITY x size`, mature plants in full
  (those that ripen between sessions stand mature through the session), growing ones at
  `GROWING`; capped by `Aura.CAP` x (1 + `DECOR` x score/scoreCap); it multiplies the
  seat only.
- **Acquisition (expected values):** Spirit Stones from hunting (~10 a hunting minute:
  ~0.3 stones per qiDrop plus nodes), sect dailies (`DAILY_STONES`), quests and herb sales buy, in order: a day's
  Herbalist stock of the next tier once its band sells it (tier III from QR6, tier IV
  from FE4; seeds back fill the plots), the tier II reseed, beds, the Meditation
  Cushion, ponds, groves, then the cheapest peak-score pieces. Tier III+ also come from
  harvest mutations (`mutateChance`) and seclusion's rare seed (`SEED_TIER`). Root
  pills: bosses (`boss_per_hour` x (3% pill + a pity fragment)), treasures' pity
  fragments and the Pavilion's 3 Marrow fragments a week; Earth at 3 pills.
- **Offline/AFK:** one 12 h budget a day shared by every absence, `x passive`, up to
  the overflow cap (1.5 bar); the carry keeps it all. Breakthroughs happen only online.
- **Header check:** the `Pacing.luau` table (bar and the bare fighter's active time per
  stage) must match this curve; `--header` prints a fresh one.

### Profiles

| | Casual | Regular | Heavy (everything) | Hunter road | Garden road |
|---|---|---|---|---|---|
| Sessions | 30 min at 19:00 | 90 min at 19:00 | 60 min at 08:00, 120 at 18:00 | as regular | as regular |
| Hunting share | 55% | 55% | 50% | 75% | 30% |
| Refine (cultivation per raw qi) | 1.0 | 1.1 | 1.25 | 1.1 | 1.1 |
| Plots wanted (beds/ponds/groves) QC / QR / FE | 3/1/0, 5/1/0, 8/1/1 | 8/2/1, 12/2/2, 16/3/2 | 16/4/3, 20/4/3, 24/4/3 | 4/1/0, 6/1/1, 8/2/1 | as regular |
| Peak score wanted | 12 / 40 / 70 | 30 / 90 / 160 | the tier's cap | plots only | plots only |
| Meditation Cushion | no | from QC6 | from QC5 | no | from QC6 |
| QiRate buffs kept up | none | 2 at 60% | 4 at 100% | none | none |
| Mutation chase / standing aura plants | 0 / 0 | 1 bed / 2 | 3 beds / 4 | 0 / 0 | 0 / 0 |
| Party share of hunting, sect dailies, bosses an hour | 0, 1, 0.2 | 25%, 2, 0.5 | 40%, 3, 1.2 | 0, 1, 0.5 | 0, 1, 0.5 |
| Sells qi herbs / seclusion nightly | no / no | no / no | no / yes | no / no | 30% / no |

The two roads are the balance check's "one road plus a natural garden, no min-maxing
of buffs, cores or decorations".

## Results (rebalance, herb re-tier and foundation bar applied, 2026-10-24)

Active hours / calendar day to FE9 full ("online only" turns off offline credit,
which is what the active targets mean: QC 2.4 h, QR 7.1 h, FE 19.8 h, 29.3 h in all).
The herb re-tier, the deferred tier V and the sell-price cut moved every profile by
under 3% (regular online 29.3 > 29.7 h).

| | QC done | QR done | FE9 full | Online only: QC / QR / FE realm, total |
|---|---|---|---|---|
| Before (2026-10-24 morning) casual | 1.0 h / d3 | 3.0 h / d7 | 5.5 h / d12 | 1.6 / 3.6 / 5.7, 10.9 h |
| Before regular | 1.5 h / d2 | 4.5 h / d4 | 7.9 h / d6 | 1.7 / 3.7 / 4.4, 9.8 h |
| Before heavy | 1.0 h / d1 | 4.0 h / d2 | 7.0 h / d3 | 1.5 / 3.2 / 3.3, 8.0 h |
| **Now casual** | 1.5 h / d4 | 5.0 h / d11 | 14.3 h / d29 | 2.2 / 7.2 / 22.3, 31.7 h |
| **Now regular** | 2.1 h / d2 | 7.5 h / d6 | 22.3 h / d15 | 2.4 / 7.1 / 20.2, **29.7 h** |
| **Now heavy** (no seclusion stones) | 1.6 h / d1 | 7.7 h / d3 | 24.2 h / d9 | 2.2 / 7.5 / 20.1, 29.8 h |
| Bare fighter (the header's active column) | 2.8 h | 14.5 h | 97.6 h | |

The approved proposal (the morning's `--proposal`, bars x1.15 / x1.8 / x5.1) gave
regular 29.2 h, casual 41.6 h and heavy 22.4 h online. The owner then asked for buff
falloff instead of strongest-only, an aura that sums every planted herb, a decorating
lever and "no lever is mandatory"; with those (below) the bars came out x1.15 / x1.65
/ x4.2, the casual 25% faster online and the heavy 10% slower than in the proposal.

### Balance check (online only)

| | Total | Against the regular | Limit |
|---|---|---|---|
| Hunter road | 33.3 h | +12% | +15% |
| Garden road | 34.0 h (QC 3.0 h: tier I herbs give little, so the garden road's QC is slower) | +14% | +15% |
| Heavy (everything) | 29.8 h (25.2 h with the seclusion stone trickle, cut 2026-10-24) | x1.00 speed | x1.30 |

Before the rebalance the garden road was +95% and the hunter +34% over the regular
(on the proposal's knobs); what closed it: buff caps, the lighter seat items, the aura
from every plant, the Herbalist's tier III-IV seeds and the gardener's herb sales.

### Levers, one at a time (`--levers`, to FE9 full with nights)

| Lever off | Casual | Regular | Heavy |
|---|---|---|---|
| Offline credit | +122% | +33% | +16% |
| Spirit cores | +5% | +9% | +11% |
| Herb qi | +2% | +8% | +11% |
| Herb buffs | 0% | +7% | +3% |
| Garden aura | +2% | +6% | +9% |
| Method (FE) | +2% | +7% | +9% |
| Peak score / cushion / party / root / seclusion | 0-1% | 0-1% | 4% / 2% / 4% / 1% / 14% |
| The stone economy (everything bought at once) | -12% | -25% | -27% |

No single lever is worth more than about 12% to anyone but offline credit (the casual's
nights carry two thirds of their QR and FE). Levers still substitute for each other
(the seat refines up to `0.4 x dantian` raw qi a minute), so the one-lever table
understates each a little; the balance check is the real measure.

### Findings that shaped the rebalance

- **The curve was fine; the extras weren't in it.** Bare, the profiles took 34-37 h;
  with the extras every profile was 3-4x faster than the targets.
- **Shares of the dantian scaled too well:** a lesser core was 25% of the dantian (2.7
  wolves at QC4, 7 at FE9); a greater core 35% of the bar from a QC8 beast at any
  stage; Blood Ginseng's 9% (or its 400 floor) out-earned hunting from QC6 to FE9.
  Now: 2 kills' qi, 8% of the bar, floors 60/150/900/3000/8000 and only the floor below
  the band's tier.
- **Caps were per event:** 12 h offline per absence (two logins, two nights); buffs
  uncapped (+470% at FE). Now: one 12 h budget a day; falloff + cap by major.
- **The garden aura was weak and everywhere.** Now by tier x rarity over every plant,
  capped by peak tier, lifted by decorating, on your own peak only.
- **The seat stacked:** cushion +1.5 on 2.5 (+60% for 260 stones) times aura times
  buffs made a regular's FE seat 2.3x a natural gardener's. Meditation pieces halved.
- **The stone economy is a brake:** a regular earns about 13,000 stones by FE9 (QC
  780, QR 2,500, FE 10,000); the cushion arrives at FE9, the score at about half.
  Bought outright, a regular would be 25% faster. The garden road needs herb sales to
  afford its garden; tier III-V sell prices then flooded it (250,000 stones in FE) until
  the 2026-10-24 price cut (37,000).

### Acquisition (expected values)

| | Root pills by FE9 | Tier III seeds | Tier IV seeds | Stones QC / QR / FE |
|---|---|---|---|---|
| Casual | 1.1 | FE6, day 21 | FE8, day 25 | 600 / 1,800 / 7,700 |
| Regular | 2.2 | QR7, day 4 (Herbalist) | FE3, day 8 (Lingzhi mutation) | 780 / 2,500 / 9,500 |
| Heavy | 3.4 (Earth at FE8) | QR6, day 2 | FE2, day 4 | 480 / 4,000 / 21,600 |
| Hunter road | 2.5 | FE3, day 7 | FE5, day 10 | 710 / 2,300 / 9,900 |
| Garden road | 1.2 | FE1, day 6 | FE2, day 7 | 450 / 7,500 / 36,700 (sales 31,300) |

Tier V is deferred (`Herbs.Deferred`): out of the game and the model. Stones aren't
printed by a flag; read them from `Model(...).run()["stones"]` (by major and source).

## Foundation percent (TARGET, OVER_COST, carry)

`--foundation` estimates the weighted experiences each profile earns per graded stage
(QC4-FE8) from `Foundation.luau`'s sources on today's map (variants off): first
kills by beast and band (`FIT_BELOW` 3), bosses (x2), deeds (Hunter needs 3+ kinds
within 2 stages below, Gardener 3 kinds harvested, Haul 75% of the dantian in one
trip, Daring 2 stages up in the same major), the band's herb tier, rare mutations
(weather and peak rolls on growing plants), Herbarium pages, Dao levels (XP a hunting
minute), caches (assumed 3/3/2/0/0 per band), world events (~4.6 an hour server-wide)
and treasures, and the sect (chain, Inner, Core). Expected values, so fractional.
`solve_foundation` grid-searches the knobs for `FOUNDATION_GOAL`.

Applied (owner-approved): TARGET 4 for QC4-QC9, `DEFAULT_TARGET` 2.5, `MAX_PERCENT` 150,
experiences past what 150% needs carry into the next stage (`Foundation.seal`), and
`OVER_COST` 5 (was 3; owner, 2026-10-24: "if foundation is too easy, then raise the
bar"). On this curve, with the carry:

| `OVER_COST` | Casual median / 130%+ | Regular median / 130%+ / under 100% | Heavy median / 130%+ |
|---|---|---|---|
| 3 (before) | 100% / 3 | 119% / 11 / 4 | 144% / 14 |
| 4 | 97% / 3 | 113% / 7 / 5 | 123% / 8 |
| **5 (applied)** | 97% / 1 | **110% / 3 / 5** | 112% / 7 |
| 6 | 97% / 1 | 108% / 3 / 5 | 110% / 4 |

(Before the herb re-tier the regular's median at 3 was 133% with 12 stages at 130%+.)
At 5 the regular reaches 130%+ only on the band-entry stages (QR1, QR6, FE4, where a
fresh pool lands); the heavy on 7 of 23. Raising the bar further squeezes the heavy as
much as the regular: the profiles barely separate on foundation (the heavy plays 3 h a
day, so it spends less time per stage, and its habits differ little), so read these as
rough. A higher target instead would push more of the casual's stages under 100%.
Structural notes stay: band pools are front-loaded (FE4 and QR6 hit 150% for everyone,
the carry feeds the next stages, less of it at 5); QR and FE have no same-realm beasts
with variants off; slept stages seal low for the casual (QC6, QR2, QR4); the regular's
FE1-3 and FE6-8 sit at 66-98%. Re-run once variants are on.

## Tempering and deepening (`--foundation`, after the percent table)

`tempered_percents` takes each profile's sealed percents and, stage by stage on its
calendar, applies the heart demon at QC9 / QR9 / FE9 (`TEMPER_CALM` - denials steps of
`TEMPER_POINTS` to `TEMPER_MAX`, then `DEEPEN_CALM` on the lowest stage at 100%+ when
calm) and seclusion's tempering items (`Pacing.Tempering.POINTS` to 100%, inside
`PER_DAY` / `PER_WEEK`). Item supply per stage: boss kills x `BOSS_CHANCE`, the
Pavilion's weekly pill (`TEMPER_HABITS` pavilion share, from QC5), seclusion finds for
profiles that seclude, the first seclusion's pill at QC5, and Snowpeak Lotus / Nine-Leaf
Lingzhi a week from QR6 / FE4 (`TEMPER_HABITS`). A Clear Heart Pill forgives one denial
for its `clear` share. It prints sealed vs tempered median, stages under 100%, 130%+ and
the summed bonus, plus the reference: all mended to 100% +23%, all deepened to 130% +51%,
all earned to 150% +69%.

| | Sealed: median / under 100% / 130%+ / bonus | Tempered and deepened |
|---|---|---|
| Casual | 97% / 12 / 1 / +25% | 103% / 5 / 1 / +29% |
| Regular | 110% / 5 / 3 / +36% | 111% / 0 / 4 / +40% |
| Heavy | 111% / 4 / 6 / +39% | 120% / 0 / 6 / +42% |

Tempering mends the regular's and heavy's few low stages long before the caps bind (they
hold items with nothing to mend); the casual is supply-limited and keeps 5 stages under
100%. Deepening is what moves the heavy's median (three calmed trials, each +20 on a
stage at 100%).

## Known gaps

- Untested in play. Plot sizes, kill rate, stone rate, boss and treasure appetite,
  event participation and cache counts are assumptions in the script.
- The economy buys in one fixed order; seeds back are assumed to keep the plots full
  once a tier is started (the Herbalist's daily stock isn't simulated past the first
  day's purchase).
- Herbs harvested at session start are spread over the session; surplus herb qi is
  sold, never stockpiled past a day.
- The greater core's and the Immortal Peach's own QiRate buffs, mutated plants' aura
  and Huge/Colossal sizes beyond the mean size are left out.
- Heaven-defiers (x1.5 bars, tribulations), Grow now, Robux and alchemy (not built)
  are out of the model.
