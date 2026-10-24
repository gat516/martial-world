# Cultivation, realms and progression

## Purpose
The core loop: gather raw qi, refine it into cultivation, fill the realm bar,
break through to the next stage. Stages raise health and damage, so progress is
felt in fights.

## Design intent
- **Phase A (decided 2026-10-23):** insight is deleted (built: the walls are the bar,
  techniques gate on weapon Dao, see [combat](combat.md)), breakthroughs get a
  foundation grade (built, see "Foundation grade" below), death spills half of
  the unbanked haul (built: raw qi, herbs, stones; a spirit ring keeps some safe;
  [haul](haul.md)), and the forced breakthrough is replaced by the qi surge (built,
  see "Qi surge" below). See [roadmap](../roadmap.md) "Phase A". The rest of this
  page is the code as it stands.
- **The ladder is 27 stages** (2026-10-22, [progression](../progression.md)): Qi
  Condensation 1-9, Qi Refining 1-9, Foundation Establishment 1-9 (FE9 is the cap).
- **The curve (2026-10-23, [roadmap](../roadmap.md) "Pacing, realm gaps and verbs"):**
  active play is about 2.4 h of QC, 7 h of QR and 20 h of FE. The hook lands QC2,
  QC3 and QC4 in the first ten minutes; each realm is three thirds, each opened by a
  breather; the real slowdown is mid Qi Refining (QR4 on), where passive grows as a
  share of income so the garden aura, peak build items and herbs carry cultivation;
  no FE stage runs over about 3 h. The gardener's road (meditating on the peak) is
  about 2x the fighter's time in QC, 1.6x in QR and 1.5x in FE. The per-stage table
  and its formulas are in the `Pacing.luau` header. Untuned in play.
- **Strength:** about +10% health and power a minor stage and x2.25 at a major;
  beasts follow, and realm suppression cuts damage across majors
  ([combat](combat.md#realm-power-and-suppression-2026-10-23)).
- **Tribulations are for the heaven-defying only.** `data.heavenDefying` (default
  false; `Cultivation.heavenDefying`) puts a tribulation on every major
  breakthrough (QC9, QR9); everyone else breaks through quietly on a full bar. A
  heaven-defier's every bar is `Pacing.HeavenDefying.BAR` (1.5x) longer
  (`Cultivation.stage` returns `Realms.forPlayer`'s copy), and they resist half of
  realm suppression when hitting upward. Nothing sets the flag yet: a heaven-defying bloodline or root will.
- **Walls are the bar, never a boss.** A wall stage has the biggest bar of its
  chapter (plus the tribulation for heaven-defiers); nothing else gates a breakthrough.
- **Two kinds of qi.** Raw qi (`data.rawQi`, the dantian) is cultivation's fuel:
  gathered, then refined into the realm bar. **Combat qi** (the `Qi` attribute)
  is the mana techniques spend: a separate, unsaved pool whose size grows with
  the stage and which refills on its own ([combat](combat.md#combat-qi-technique-mana)).
  Fighting never drains the dantian, and cultivating never drains combat qi.
- **Cultivation runs past the bar.** Passive, refining and items keep filling
  past `CultivationMax` up to the overflow cap (`OVERFLOW_CAP` x the bar) without
  moving the realm, so a player who isn't ready (tribulation
  cooldown, not seated, a method that can't go further) keeps progressing. A normal breakthrough carries the
  excess into the next stage, at most `CARRY_SHARE` of the new bar. The
  breakthrough requirement is still a full bar.
- Two speeds: **passive** cultivation is always on (online, offline, faster while
  meditating) so nobody is ever stuck; **active** play (kill beasts / gather qi
  nodes, then refine with a skill minigame) is several times faster.
- A deliberate rhythm, not a flat ramp: QC1-3 hook (onboarding), QC4 breather,
  QC5 ramp, QC6 mini-wall, QC7 breather, QC8 ramp, QC9 wall (biggest bar, a
  tribulation for heaven-defiers), then Qi Refining and Foundation
  Establishment (FE9 is the top). The intent and time estimates for each stage are in the header of
  `src/shared/Pacing.luau`.
- Breakthroughs happen seated in meditation, never anywhere else (no forced
  breakthrough, no qi debt). In a fight the nearly full bar's answer is the
  **qi surge**: a short borrowed stage, see "Qi surge".
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
  aura, breakthroughs (`breakthrough`, `advance`), `fightStage` (the stage whose
  health and power apply, the next one while surging), qi deviation,
  idle warnings, offline/daily login claim, stats (health, walk speed),
  `pushState` and the player attributes; `cap`/`add` (the overflow cap) and
  `block` (what stops a breakthrough).
- `src/server/QiSurge.luau`: the qi surge (ready check, fire, end, the
  "falls back" toast; see "Qi surge").
- `src/server/Circulation.luau`: refining runs (see [minigames](minigames.md)).
- `src/server/Tribulation.luau`: the lightning trial for a major breakthrough.
  Every client draws it with `src/client/WorldFX/TribulationFX.luau` (templates
  `WorldFX.Tribulation`): a storm wheel of cloud arcs over the platform with lightning
  flickering inside round an eye, a seal and closing ring under each telegraph, the bolt
  and its impact and scorch, and on success gold light pouring through as the clouds part
  ([tribulation look](../vfx/world_events/tribulation.md)). The strikes are planned up
  front (`schedule`: the interval shrinks from `intervalStart` to `intervalEnd`), so
  the start tells clients how many there are; on screen the challenger gets the
  Heaven's Decree card and a strikes-left counter, spectators a short ribbon
  (`src/client/Events/TribulationView.luau`, [world events UI](../ui/world-events.md)).
- `src/server/Progression.luau`: technique manuals from kills (kept until their
  weapon Dao is reached, then learned), and `comprehend` (stones plus weapon Dao
  break a technique's bottleneck). First kills and boss kills feed `Foundation.kill`.
- `src/server/Foundation.luau`: foundation experiences, grades, the stat bonus and
  the open-experience hints (see "Foundation grade").
- `src/server/QiNodes.luau`: raw qi (and stones) from wilds nodes.
- `src/server/Inventory.luau` (`use`): consumables that add qi, cultivation, weapon Dao XP.
- Client: `SeatBars.luau` (the seated cultivation track with its overflow past the mark
  and the dantian; cultivation is off the fighting HUD), `BreakthroughView.luau`
  (the qi surge pill and its ember burst, light column, the milestone card on your
  own breakthrough and the "ready to break through" nudge); the foundation meter and death-save (shelved by Phase A)
  are in [cultivation UI](../ui/cultivation.md),
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
   checks the method, seat, bar; a major one calls `Tribulation.start`. `advance`
   grades the stage being left (`Foundation.seal`), moves the realm (carrying the excess past the old bar, capped at
   `CARRY_SHARE` of the new one), heals, fires `Breakthrough` to everyone and the
   `onBreakthrough` hooks (analytics, peak tier).
5. The HUD reads `Realm`, `Cultivation`, `CultivationMax`, `CultivationCap`,
   `BreakthroughReady`, `BreakthroughBlock`, `RawQi`, `DantianCap` attributes
   every second and the `PlayerState` snapshot on change. Seated, `SeatBars`
   shows the bar, the overflow past it and the dantian; standing, a ready player
   gets a toast once and then now and then while idle ([ui](ui.md)).

## Qi surge
Built 2026-10-23 (Phase A, untuned, untested in play). Replaces the forced
breakthrough: a clutch comeback to survive a fight and keep the haul, not insurance.
Server `QiSurge.luau`, tuning `Pacing.Surge`.
- **Ready** (`SurgeReady` player attribute, checked every 0.2 s): in combat (the
  `InCombat` tag), health at most `Breakthrough.FORCE_HEALTH_SHARE` (35%) of max,
  cultivation at least `FORCE_BAR_SHARE` (90%) of the bar, not seated, not in a
  tribulation, a next stage exists, not already surging, and not used yet this
  engagement (`ONCE_PER_COMBAT`: reset once the tag drops and the surge is over).
- **Fire:** `CultivationAction "surge"` (`Cultivation.surge` -> `QiSurge.fire`;
  refusals return why). PC: M surges instead of meditating while `SurgeReady`
  (Meditation's binding), and the standing pill reads "M to qi surge". Touch: the
  same pill reads "Qi Surge" and fires it ([HUD vitals](../ui/hud-vitals.md)).
- **Effect:** `SECONDS` (15) at the next stage's health and power
  (`Cultivation.surgeStage` -> `fightStage`, read by `applyStats` and `Combat.power`;
  max health rises keeping the fraction), then a heal of `HEAL_SHARE` (20%) of the
  raised max. Foundation bonuses still apply on top. The realm plaque shows the
  surged stage (`SurgeRealm`); every client plays the breakthrough burst in ember
  and motes for the duration (`SurgeUntil`, server time). Stage, bar and foundation
  never move.
- **Cost:** `RAW_QI_SHARE` (25%) of the raw qi in the dantian when it fires (free on
  an empty dantian). When it ends, back to the own stage (health fraction kept);
  once the surge is over and the tag has dropped, one toast "Your cultivation falls
  back." Death or a breakthrough ends it quietly.
- **Gaps:** combat qi doesn't follow the surged stage; no cooldown beyond once per
  engagement; essence blood (roadmap open question) isn't a cost option.

## Foundation grade
Built 2026-10-23 (Phase A, untuned, untested in play). What the player experiences
at a stage grades the breakthrough out of it. Time fills the bar, not the grade.
- **Experiences** are one-time keys, once ever per profile (`data.foundation.seen`),
  weighted by category (`Pacing.Foundation.WEIGHTS`) into `data.foundation.count`:
  Hunt `hunt:<enemy>` (first kill of a beast type, `Progression.onKill`), Boss
  `boss:<enemy>` (counts 2), Home `home:tier:<n>` (first harvest of a herb tier) and
  `home:mut:<id>` (a harvest with a mutation of bonus >= `MUTATION_BONUS`: Golden,
  Thunderstruck, Auspicious, Rainbow, Heavenlit; `Garden.harvest`), Dao
  `dao:<class>:<level>` (each weapon Dao level reached, `Weapons.onLevelUp`), Discover
  `discover:<cache id>` (`WorldCaches` claim), World `world:<event id>` (within
  `EVENT_RADIUS` of a located event while it runs, or any kill during an unlocated
  one such as the Beast Surge; `WorldEvents`) and `world:treasure:<weather>` (claiming a
  heavenly treasure). Earning one gives no toast; it shows in the state push.
- **Grade:** at `Cultivation.advance` (every breakthrough), `Foundation.seal` grades the
  stage being left: count / `TARGET[stage]` (default `DEFAULT_TARGET`) reaching
  `GRADES` shares 0 / 0.34 / 0.67 / 1 gives Cracked / Steady / Solid / Deep, stored in
  `data.foundation.grades[stageKey]`; the count and the toast flag reset. Profiles
  from before this have no grades (no bonus, nothing retro).
- **Bonus:** the sum of every graded stage's `BONUS` (Cracked 0, Steady 1%, Solid 2%,
  Deep 4%; at most about +104% by FE9, below a major jump) multiplies max health (`applyStats`) and power (`Combat.power`, so
  knockback too) as its own factor on top of `Pacing.Curve`.
- **Shown:** the card subtitle "<stage>  ·  <grade> foundation" (grade sent as the
  Breakthrough remote's 4th arg); one toast per stage when the bar first fills with
  a breakthrough open and the pending grade below Solid ("Your foundation is
  unsteady. The world still has things to teach you.", `data.foundation.warned`);
  `PlayerState.foundation` for the Self card (shape in [remotes](../remotes.md), UI
  note in [cultivation UI](../ui/cultivation.md#foundation-line-in-the-self-card-ready-to-wire)).
- **Hints** (`Foundation.hints`, up to `HINTS`): unearned beasts from `HINT_BELOW`
  stages below to `HINT_ABOVE` above (two first), the lowest unharvested herb tier
  (else the mildest rare mutation not yet harvested), the equipped class's next Dao
  level, a cache, a world event if any is left, a third beast, and a boss in range as
  "The fast road: defeat the <boss>" (always shown when one is open, replacing the last line).
- **Tribulation:** a heaven-defier's strikes deal `TRIBULATION_DAMAGE` x more by the
  pending grade (Cracked 1.25, Steady 1.1).
- **Gaps:** the pools are global and small (five beast types, three herb tiers, a
  handful of caches and events), so past QC they run thin and the Dao levels carry
  the grade. Per-region (and per-realm) pools are needed as regions arrive. Not built:
  tempering old grades, the heart-demon trial, the Cultivate-window line (the Self
  card will read `PlayerState.foundation`). The Discover hint shows even when no
  cache is left. Numbers are first guesses.

## Player attributes (set every second by `Cultivation.publish`)
- `Cultivation`: may exceed `CultivationMax` now, up to `CultivationCap`
  (`floor(bar * OVERFLOW_CAP)`). Never negative now; a save left in the old qi
  debt pays it off through the normal sources.
- `CultivationMax`: the bar (the breakthrough requirement).
- `BreakthroughBlock`: what stops a seated breakthrough, `""` when nothing does.
  In order of precedence: `"peak"` (no stage beyond, FE9 today), `"method"` (the
  method can't reach the next stage; reported even before the bar is full, so the
  HUD can warn early), `"bar"` (not full yet).
- `BreakthroughReady`: `BreakthroughBlock == ""`: the bar is met, the method
  allows it, and a next stage exists. It does **not** count being
  seated, the tribulation cooldown or another player's tribulation in progress;
  the server still says why on the attempt.
- `SurgeReady`, `SurgeUntil`, `SurgeRealm`: the qi surge (`QiSurge`, see "Qi surge").


## Tuning knobs (all in `Pacing.luau`)
- **Pacing.Curve**: one row per stage. QI: `bar`, `dantian`, `passive`.
  BREAKTHROUGH: `levels` (circulation run levels), `difficulty`, `tribulation`. FIGHT:
  `health`, `power` (beasts follow through `Pacing.BeastBaseline`).
- **Pacing.Suppression** (`KEEP`) and **Pacing.HeavenDefying** (`BAR`,
  `SUPPRESSION_RESIST`).
- **Pacing.Adjust**: per-stage multipliers on top of the curve, keyed `"QC1".."FE9"`:
  `bar`, `passive`, `refine`, `gather`, `difficulty` (added), `levels`,
  `tribulation` (field overrides), `health`, `power`, `beastHealth`,
  `beastDamage` (for beasts whose Enemies `realm` is that stage).
- **Pacing.Global**: whole-game `BAR`, `PASSIVE`, `REFINE`, `GATHER`, `DIFFICULTY`,
  `BEAST_HEALTH`, `BEAST_DAMAGE`, `TRIBULATION_DAMAGE`.
- **Pacing.Refine / Income / Meditation / Breakthrough / Rewards**: run qi cost and
  efficiency, node/daily/offline/starting qi and the enemy-qi exponent,
  meditation multipliers, the qi surge's ready thresholds (`FORCE_*`), the overflow cap past
  the bar and the carry-over share (`OVERFLOW_CAP`, `CARRY_SHARE`), manuals (boss and milestones),
  and the kill-credit share (`Rewards.KILL_SHARE`, `BOSS_KILL_SHARE`).
- **Pacing.Surge**: the qi surge's length, heal share, raw-qi cost share and
  once-per-engagement switch.
- **Pacing.Foundation**: experience weights, per-stage targets, grade shares,
  grade bonuses, the tribulation damage per grade, the rare-mutation line, the
  world-event radius and the hint count and range.
- **Pacing.Comprehension**: the weapon Dao to learn a technique (`CLASS_SKILL_DAO`) and
  to break each bottleneck (`DAO_PER_BOTTLENECK`), and the stones each bottleneck costs.
- **Pacing.Methods**: the cultivation method's qi multiplier (passive, refining,
  kill and node qi), how far each method reaches, the root-match bonus, and the
  major where the random starter is given ([cultivation method](../character/method.md)).
- Arena geometry for the tribulation stays in `Config.Tribulation` (`CENTER`,
  `ARENA_RADIUS`, `STRIKE_RADIUS`, `RETURN_DELAY`).

## Reading dropoff from analytics
`Analytics.luau` logs a progression path **"Realm"** (level = stage index,
1 = QC1 ... 27 = FE9): *start* on entering a stage (stage 1 on a new player's
first join), *complete* on leaving it, *fail* when its tribulation beats the
player. In the Creator Dashboard (Analytics > Progression), a level whose starts
greatly exceed its completes is a dropoff. Also useful: the custom events
`Breakthrough` (seconds since the previous breakthrough this session, field: new
stage name), `TribulationResult`, `CirculationScore`, and the onboarding funnel
(8 steps, ends at QC3).

To ease a stage, add it to `Pacing.Adjust`, e.g. `QC6 = { bar = 0.8 }` (stuck on
qi), `QC9 = { tribulation = {
damageShare = 0.15 } }` (failing the trial), `QC4 = { beastHealth = 0.8 }` (dying
to Stone Boars).

## Known gaps
- FE9 is the top: no stage beyond it, so its bar is shown but can't be broken
  through ("peak of this world"). When FE2+ exist, a method that
  doesn't reach the next stage blocks it with "seek a stronger method" instead.
- `Config.Meditation.ANYWHERE/ON_PEAK` are aliases of `Pacing.Meditation` until
  `server/Meditation.luau` reads Pacing directly.
- Herb qi is a tier share of the dantian with a per-tier floor (event herbs a
  bigger share); cores and treasures are shares too. All of it only fills the
  dantian's room, so a herb never gives more than one dantian.
- The `Breakthrough` analytics event's "seconds since" resets each session.
- Overflow is untuned: `OVERFLOW_CAP` 1.5 and `CARRY_SHARE` 0.25 are first
  guesses. Open question: should gains past the bar slow down (a lower rate
  instead of only a cap), and should the QC9 -> FE1 tribulation carry as much as
  a minor breakthrough?
- The idle warning about a full bar fires at the bar, not at the cap; nothing
  tells the player when the overflow cap is reached except refining refusing.
