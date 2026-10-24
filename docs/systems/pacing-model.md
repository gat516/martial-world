# Pacing model

What real players get, stage by stage QC1-FE9, once herbs, the garden, building,
roots, the method, cores, nights and the rest stack on top of the curve, and the
check that no lever is mandatory. The rules it enforces are in
[progression rules](progression-rules.md); the 2026-10-24 rebalance (owner-approved)
was solved with it and is applied.

- Script: `python3 tools/pacing_model.py` (stdlib Python, outside Studio). It
  parses `Pacing.luau` (curve, `Adjust`, `Herbs`, `Aura`, `Meditation`, `PeakScore`,
  `Foundation`...), `Herbs.luau`, `Items.luau`, `Config.luau`, `BuildItems.luau` and
  `Weather.luau` on every run, so a tuning change shows on the next run. Every run
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
  ~0.3 stones per qiDrop plus nodes), sect dailies (`DAILY_STONES`), seclusion
  (`STONES_PER_HOUR` with the streak), quests and herb sales buy, in order: a day's
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

## Results (rebalance applied, 2026-10-24)

Active hours / calendar day to FE9 full ("online only" turns off offline credit,
which is what the active targets mean: QC 2.4 h, QR 7.1 h, FE 19.8 h, 29.3 h in all).

| | QC done | QR done | FE9 full | Online only: QC / QR / FE realm, total |
|---|---|---|---|---|
| Before (2026-10-24 morning) casual | 1.0 h / d3 | 3.0 h / d7 | 5.5 h / d12 | 1.6 / 3.6 / 5.7, 10.9 h |
| Before regular | 1.5 h / d2 | 4.5 h / d4 | 7.9 h / d6 | 1.7 / 3.7 / 4.4, 9.8 h |
| Before heavy | 1.0 h / d1 | 4.0 h / d2 | 7.0 h / d3 | 1.5 / 3.2 / 3.3, 8.0 h |
| **Now casual** | 1.5 h / d4 | 5.0 h / d11 | 14.4 h / d29 | 2.2 / 7.2 / 21.8, 31.2 h |
| **Now regular** | 2.1 h / d2 | 7.5 h / d6 | 22.5 h / d16 | 2.4 / 7.1 / 19.8, **29.3 h** |
| **Now heavy** | 1.6 h / d1 | 7.4 h / d3 | 21.5 h / d8 | 2.2 / 6.5 / 15.9, 24.6 h |
| Bare fighter (the header's active column) | 2.8 h | 14.5 h | 97.6 h | |

The approved proposal (the morning's `--proposal`, bars x1.15 / x1.8 / x5.1) gave
regular 29.2 h, casual 41.6 h and heavy 22.4 h online. The owner then asked for buff
falloff instead of strongest-only, an aura that sums every planted herb, a decorating
lever and "no lever is mandatory"; with those (below) the bars came out x1.15 / x1.65
/ x4.2, the casual 25% faster online and the heavy 10% slower than in the proposal.

### Balance check (online only)

| | Total | Against the regular | Limit |
|---|---|---|---|
| Hunter road | 32.3 h | +10% | +15% |
| Garden road | 32.9 h (QC 3.0 h: tier I herbs give little, so the garden road's QC is slower) | +12% | +15% |
| Heavy (everything) | 24.6 h | x1.19 speed | x1.30 |

Before the rebalance the garden road was +95% and the hunter +34% over the regular
(on the proposal's knobs); what closed it: buff caps, the lighter seat items, the aura
from every plant, the Herbalist's tier III-IV seeds and the gardener's herb sales.

### Levers, one at a time (`--levers`, to FE9 full with nights)

| Lever off | Casual | Regular | Heavy |
|---|---|---|---|
| Offline credit | +117% | +30% | +14% |
| Spirit cores | +5% | +8% | +12% |
| Herb qi | +2% | +6% | +12% |
| Herb buffs | 0% | +7% | +7% |
| Garden aura | +1% | +7% | +9% |
| Method (FE) | +2% | +7% | +10% |
| Peak score / cushion / party / root / seclusion | 0-1% | 0-1% | 7% / 2% / 3% / 1% / 14% |
| The stone economy (everything bought at once) | -13% | -28% | -21% |

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
  Bought outright, a regular would be 28% faster. The garden road needs herb sales to
  afford its garden; tier III-V sell prices then flood it (250,000 stones in FE).

### Acquisition (expected values)

| | Root pills by FE9 | Tier III seeds | Tier IV seeds | Stones QC / QR / FE |
|---|---|---|---|---|
| Casual | 1.1 | FE6, day 21 | FE8, day 26 | 600 / 1,800 / 7,700 |
| Regular | 2.3 | QR7, day 4 (Herbalist) | FE7, day 13 | 780 / 2,500 / 10,100 |
| Heavy | 3.4 (Earth at FE8) | QR6, day 2 | FE2, day 4 (seclusion) | 480 / 4,000 / 21,500 |
| Hunter road | 2.5 | FE3, day 7 | FE6, day 11 | 710 / 2,300 / 9,800 |
| Garden road | 1.2 | FE1, day 6 | FE4, day 9 | 450 / 7,500 / 250,000 |

Tier V still never drops on today's map (Far Reaches bosses only; 0.5-1% mutations):
the heavy reaches it at FE8 through mutation.

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

Applied (owner-approved): TARGET 4 for QC4-QC9, `DEFAULT_TARGET` 2.5, `OVER_COST` 3,
`MAX_PERCENT` 150, and experiences past what 150% needs carry into the next stage
(`Foundation.seal`). On this curve, with the carry:

| | Median | Mean | Stages under 100% | Stages at 130%+ |
|---|---|---|---|---|
| Casual | 100% | 94% | 11 | 3 |
| Regular | 133% | 128% | 2 | 12 |
| Heavy | 144% | 129% | 2 | 14 |

The regular reaching 130%+ on about half its stages breaks "130-140% takes real
effort" (an open call in [progression rules](progression-rules.md)): `OVER_COST` 4
gives medians 97 / 114 / 123%. The model's profiles barely separate on foundation (the
heavy's habits differ little from the regular's), so read these as rough. Structural
notes stay: band pools are front-loaded (FE4 and QR6 hit 150% for everyone, the carry
feeds the next stages); QR and FE have no same-realm beasts with variants off; slept
stages seal low for the casual (QC6, QR2, QR4). Re-run once variants are on.

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
