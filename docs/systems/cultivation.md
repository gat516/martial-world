# Cultivation, realms and progression

## Purpose
The core loop: gather raw qi, refine it into cultivation, fill the realm bar,
break through to the next stage. Stages raise health and damage, so progress is
felt in fights.

## Design intent
- **Two kinds of qi.** Raw qi (`data.rawQi`, the dantian) is cultivation's fuel:
  gathered, then refined into the realm bar. **Combat qi** (the `Qi` attribute)
  is the mana techniques spend: a separate, unsaved pool whose size grows with
  the stage and which refills on its own ([combat](combat.md#combat-qi-technique-mana)).
  Fighting never drains the dantian, and cultivating never drains combat qi.
- **Cultivation runs past the bar.** Passive, refining and items keep filling
  past `CultivationMax` up to the overflow cap (`OVERFLOW_CAP` x the bar) without
  moving the realm, so a player who isn't ready (no insight, tribulation
  cooldown, not seated) keeps progressing. A normal breakthrough carries the
  excess into the next stage, at most `CARRY_SHARE` of the new bar. The
  breakthrough requirement is still a full bar.
- Two speeds: **passive** cultivation is always on (online, offline, faster while
  meditating) so nobody is ever stuck; **active** play (kill beasts / gather qi
  nodes, then refine with a skill minigame) is several times faster.
- A deliberate rhythm, not a flat ramp: QC1-3 hook (onboarding), QC4 breather,
  QC5 ramp, QC6 mini-wall, QC7 breather, QC8 ramp, QC9 wall (biggest bar, 5
  insight, heavenly tribulation), then Foundation Establishment (FE1, the current
  top). The intent and time estimates for each stage are in the header of
  `src/shared/Pacing.luau`.
- Breakthroughs happen seated in meditation. A minor one can be **forced** in a
  fight when badly hurt with a 90% bar; the new stage starts in qi debt.
- Failing a tribulation costs time (a cooldown, saved as
  `data.tribulationReadyUnix` so rejoining doesn't skip it), never cultivation.
- One tribulation at a time, server-wide, on the main peak's platform. Others
  asking meanwhile are told who holds it and how long is left, then notified
  when it clears. Bystanders on the platform are sent to the plaza array when
  one starts (and during it); the challenger follows `RETURN_DELAY` seconds
  after it ends, so nobody can camp the platform.

## Key files
- `src/shared/Pacing.luau`: the master tuning (see below).
- `src/shared/Realms.luau`: resolves Pacing into `Realms.Stages`; `index`, `get`,
  `after`, `ByKey`, `ofBeast`, `enemyQi`, `nodeQi`.
- `src/server/Cultivation.luau`: passive tick (1 s), rate formula, buffs, garden
  aura, breakthroughs (`breakthrough`, `advance`, `canForce`), qi deviation,
  idle warnings, offline/daily login claim, stats (health, walk speed),
  `pushState` and the player attributes; `cap`/`add` (the overflow cap) and
  `block` (what stops a breakthrough).
- `src/server/Circulation.luau`: refining runs (see [minigames](minigames.md)).
- `src/server/Tribulation.luau`: the lightning trial for a major breakthrough.
- `src/server/Progression.luau`: insight and technique manuals from kills, and
  `comprehend` (spends insight and stones to break a technique's bottleneck).
- `src/server/QiNodes.luau`: raw qi (and stones) from wilds nodes.
- `src/server/Inventory.luau` (`use`): consumables that add qi, cultivation, insight.
- Client: `SeatBars.luau` (the seated cultivation bar with its overflow chamber
  and the dantian; cultivation is off the fighting HUD), `BreakthroughView.luau`
  (button, light column and the "ready to break through" nudge),
  `CirculationMinigame.luau`.

## Data flow
1. Raw qi in (`data.rawQi`, capped by the stage's dantian): enemy kills
   (`EnemyService.died`), qi nodes, daily login, herbs/cores/treasures.
2. Refining: `CultivationAction "start"` -> server picks the game, length and
   difficulty from the stage -> client plays -> `"finish"` with accuracy and purged
   impurities -> efficiency `lerp(EFFICIENCY_MIN, EFFICIENCY_MAX, score) * stage.refine
   * weather` -> `data.cultivation`. A score under `DEVIATION_SCORE` deviates qi
   (no refining or passive for a while).
3. Passive: `stage.passive * (1 + QiRate buffs) * (1 + garden aura) * (1 + weather)
   * meditation multiplier` every second, up to the overflow cap
   (`Cultivation.cap`; everything that adds cultivation goes through
   `Cultivation.add`, which stops there). Refining refuses to start at the cap.
4. Breakthrough: `CultivationAction "breakthrough"` -> `Cultivation.breakthrough`
   checks insight, seat, bar; a major one calls `Tribulation.start`. `advance`
   moves the realm (carrying the excess past the old bar, capped at
   `CARRY_SHARE` of the new one; a forced one starts in debt instead), heals, fires `Breakthrough` to everyone and the
   `onBreakthrough` hooks (analytics, peak tier).
5. The HUD reads `Realm`, `Cultivation`, `CultivationMax`, `CultivationCap`,
   `BreakthroughReady`, `BreakthroughBlock`, `RawQi`, `DantianCap` attributes
   every second and the `PlayerState` snapshot on change. Seated, `SeatBars`
   shows the bar, the overflow past it and the dantian; standing, a ready player
   gets a toast once and then now and then while idle ([ui](ui.md)).

## Player attributes (set every second by `Cultivation.publish`)
- `Cultivation`: may exceed `CultivationMax` now, up to `CultivationCap`
  (`floor(bar * OVERFLOW_CAP)`). Negative while in qi debt.
- `CultivationMax`: the bar (the breakthrough requirement).
- `BreakthroughBlock`: what stops a seated breakthrough, `""` when nothing does.
  In order of precedence: `"peak"` (no stage beyond, FE1 today), `"insight"`
  (insight earned is short; reported even before the bar is full, so the HUD can
  warn early), `"method"` (the method can't reach the next stage), `"bar"` (not
  full yet).
- `BreakthroughReady`: `BreakthroughBlock == ""`: the bar is met, insight and
  the method allow it, and a next stage exists. It does **not** count being
  seated, the tribulation cooldown or another player's tribulation in progress;
  the server still says why on the attempt.


## Insight: earned and spent
`data.insightEarned` counts every insight gained and is what breakthroughs (and
the quest board's "Gather insight") check. `data.insight` is what's left to spend:
comprehending a technique past a bottleneck costs insight and Spirit Stones
(`Pacing.Comprehension`, see [combat](combat.md)). So spending never blocks a
breakthrough, and insight is a choice: which technique to deepen.

## Tuning knobs (all in `Pacing.luau`)
- **Pacing.Curve**: one row per stage. QI: `bar`, `dantian`, `passive`.
  BREAKTHROUGH: `insight`, `levels` (circulation run levels), `difficulty`, `tribulation`. FIGHT:
  `health`, `power`.
- **Pacing.Adjust**: per-stage multipliers on top of the curve, keyed `"QC1".."FE1"`:
  `bar`, `passive`, `refine`, `gather`, `difficulty` (added), `levels`,
  `insight`, `tribulation` (field overrides), `health`, `power`, `beastHealth`,
  `beastDamage` (for beasts whose Enemies `realm` is that stage).
- **Pacing.Global**: whole-game `BAR`, `PASSIVE`, `REFINE`, `GATHER`, `DIFFICULTY`,
  `BEAST_HEALTH`, `BEAST_DAMAGE`, `TRIBULATION_DAMAGE`.
- **Pacing.Refine / Income / Meditation / Breakthrough / Rewards**: run qi cost and
  efficiency, node/daily/offline/starting qi and the enemy-qi exponent,
  meditation multipliers, forced-breakthrough thresholds, the overflow cap past
  the bar and the carry-over share (`OVERFLOW_CAP`, `CARRY_SHARE`), insight and manuals,
  and the kill-credit share (`Rewards.KILL_SHARE`, `BOSS_KILL_SHARE`).
- **Pacing.Comprehension**: insight and stones to break each technique bottleneck.
- **Pacing.Methods**: the cultivation method's qi multiplier (passive, refining,
  kill and node qi), how far each method reaches, the root-match bonus, and the
  major where the random starter is given ([character](character.md)).
- Arena geometry for the tribulation stays in `Config.Tribulation` (`CENTER`,
  `ARENA_RADIUS`, `STRIKE_RADIUS`, `RETURN_DELAY`).

## Reading dropoff from analytics
`Analytics.luau` logs a progression path **"Realm"** (level = stage index,
1 = QC1 ... 10 = FE1): *start* on entering a stage (stage 1 on a new player's
first join), *complete* on leaving it, *fail* when its tribulation beats the
player. In the Creator Dashboard (Analytics > Progression), a level whose starts
greatly exceed its completes is a dropoff. Also useful: the custom events
`Breakthrough` (seconds since the previous breakthrough this session, field: new
stage name), `InsightBlocked` (a full bar refused for missing insight; value =
stage index), `TribulationResult`, `CirculationScore`, and the onboarding funnel
(8 steps, ends at QC3).

To ease a stage, add it to `Pacing.Adjust`, e.g. `QC6 = { bar = 0.8 }` (stuck on
qi), `QC9 = { insight = 3 }` (stuck at the gate), `QC9 = { tribulation = {
damageShare = 0.15 } }` (failing the trial), `QC4 = { beastHealth = 0.8 }` (dying
to Stone Boars).

## Known gaps
- Foundation Establishment is the top: no stage beyond FE1, so its bar is shown but
  can't be broken through ("peak of this world"). When FE2+ exist, a method that
  doesn't reach the next stage blocks it with "seek a stronger method" instead.
- Enemy qi drops and beast health/damage multipliers are defined in Pacing
  (`Realms.enemyQi`, `stage.beastHealth/beastDamage`) but EnemyService/Spawner
  don't read them yet; enemy qi still uses `Enemies.QI_SCALE_EXPONENT`.
- `Config.Meditation.ANYWHERE/ON_PEAK` are aliases of `Pacing.Meditation` until
  `server/Meditation.luau` reads Pacing directly.
- Herb, core and treasure qi amounts are per item (Herbs/Items), not per stage, so
  flat-qi herbs matter less at high stages by design.
- The `Breakthrough` analytics event's "seconds since" resets each session.
- Overflow is untuned: `OVERFLOW_CAP` 1.5 and `CARRY_SHARE` 0.25 are first
  guesses. Open question: should gains past the bar slow down (a lower rate
  instead of only a cap), and should the QC9 -> FE1 tribulation carry as much as
  a minor breakthrough?
- The idle warning about a full bar fires at the bar, not at the cap; nothing
  tells the player when the overflow cap is reached except refining refusing.
