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
  active play is about 2.4 h of QC, 7.1 h of QR and 20 h of FE. Bars never go down
  from one stage to the next (QR1 22000 > QC9 20000), breathers included: QR1-2 open
  fast with a row `gather` (x2.0, x1.6 raw qi from kills, nodes and daily qi) instead,
  and the breathers QR7, FE4 and FE7 keep the previous stage's bar, eased by `gather`
  (x1.6, x1.25, x1.15) and a small passive lift. The hook lands QC2,
  QC3 and QC4 in the first ten minutes; each realm is three thirds, each opened by a
  breather; the real slowdown is mid Qi Refining (QR4 on), where passive grows as a
  share of income so the garden aura, peak build items and herbs carry cultivation;
  no FE stage runs over about 3 h. Since the 2026-10-24 rebalance the bars
  (`Pacing.Adjust`: QC4-9 x1.15, QR x1.65, FE x4.2) are sized for players who use the
  systems: the model's regular player (1.5 h a day) meets the targets online, a
  one-road player (only hunting, or only gardening and meditating) is within 15% of
  it, and a min-maxer is at most 1.3x faster ([progression rules](progression-rules.md),
  [pacing model](pacing-model.md)). The per-stage table (bare fighter, bare gardener and
  the regular) and its formulas are in the `Pacing.luau` header. Untuned in play.
- **Strength:** about +10% health and power a minor stage and x2.25 at a major;
  beasts follow, and realm suppression cuts damage across majors
  ([combat](combat.md#realm-power-and-suppression-2026-10-23)).
- **Tribulations are for the heaven-defying only.** `data.heavenDefying` (default
  false; `Cultivation.heavenDefying`) puts a tribulation on every major
  breakthrough (QC9, QR9); everyone else breaks through quietly on a full bar. A
  heaven-defier's every bar is `Pacing.HeavenDefying.BAR` (1.5x) longer
  (`Cultivation.stage` returns `Realms.forPlayer`'s copy), and they resist half of
  realm suppression when hitting upward. Nothing sets the flag yet: a heaven-defying bloodline or root will. Player-facing text calls it **Defier of Heaven** (`Pacing.HeavenDefying.TITLE`), never "heaven-defying" (it would read like a Heaven-grade root).
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
  excess into the next stage, at most `CARRY_SHARE` (0.5) of the new bar, which is all
  of it: AFK and offline hours past the bar are never wasted (user, 2026-10-23). The
  breakthrough requirement is still a full bar.
- Two speeds: **passive** cultivation is always on (online, offline, faster while
  meditating) so nobody is ever stuck; **active** play (kill beasts / gather qi
  nodes, then refine with a skill minigame) is several times faster.
- **AFK online = offline (user, 2026-10-23).** Offline time, AFK online
  (no input for `Pacing.Income.AFK_AFTER`, 10 min; the client pings `Meditate "awake"`
  on input) and [seclusion](seclusion.md) all earn `Cultivation.afkRate`: the plain
  stage passive x `OFFLINE_RATE` (1), no meditation, aura, weather, buffs, root or
  method, up to the overflow cap, out of **one `OFFLINE_MAX_HOURS` (12 h) budget a UTC
  day** shared by every absence, AFK stretch and seclusion (`Cultivation.awayLeft` /
  `spendAway`, saved as `awayDay`/`awayUsed`; rebalance 2026-10-24: two logins used to
  earn two nights). Nothing breaks through on its own. At the cap a toast says "Your
  dantian can hold no more. Break through." once, and again on coming back from AFK,
  offline or seclusion. A night fills the cap at every QC and QR stage and 26-57% of
  an FE bar (`Pacing.luau` header; an open call in [progression rules](progression-rules.md)).
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
- `src/server/Foundation.luau`: foundation experiences, percents, the stat bonus,
  tempering, the per-band pools, deeds and the open-experience hints (see "Foundation grade").
- `src/server/HeartDemon.luau` + `src/client/HeartDemon.luau`: the heart-demon trial
  ([heart-demon](heart-demon.md)).
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
3. Passive: `stage.passive * (1 + QiRate buffs) * (1 + garden aura, on your own peak
   only) * (1 + weather) * meditation multiplier * root * method` every second. QiRate
   buffs stack with falloff (the strongest whole, the second half, the third a quarter,
   `Pacing.Herbs.BUFF_FALLOFF`) up to `BUFF_CAP` by major (QC 0.2, QR 0.3, FE 0.5); the
   aura is in [garden](garden.md#aura), up to the overflow cap
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
Rare by design (user, 2026-10-24): it fires only with the bar at 90%+ and low health in a fight, "when it really counts"; not a regular second wind.
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
  (Meditation's binding), and the standing pill reads "M to qi surge". Touch: a
  Surge button in the combat cluster fires it ([HUD vitals](../ui/hud-vitals.md#qi-surge-button-and-notice)).
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
at a stage builds the foundation of the breakthrough out of it. Time fills the bar,
not the foundation.
- **A percent, and it goes past 100% (user, 2026-10-23):** "so players are okay with
  breaking through by doing the bare minimum". The stage's weighted experiences
  (`data.foundation.count`) over its target (`Pacing.Foundation.TARGET`, default
  `DEFAULT_TARGET`) give the percent, 100% a full foundation, more up to `MAX_PERCENT`
  (150). Breaking through at 80% is a good breakthrough, just a bit less.
- **100% is easy; the real bonus is past it (user, 2026-10-24):** "break through at 100
  percent should be easy to reach... players should have to grind crazy hard so they get
  the real, extra bonuses". Targets are small (4 a stage QC4-QC9, `DEFAULT_TARGET` 2.5 in
  QR and FE, which have no same-realm beasts while variants are off; rebalance
  2026-10-24), and past the target each percent costs `OVER_COST` (5; owner, 2026-10-24:
  "if foundation is too easy, then raise the bar") times as many experiences, so the
  cap, 150%, takes 3.5x the target; 130-140% is meant to be a real achievement (in the
  model the regular reaches it on 3 of 23 stages, the heavy on 7).
- **The carry:** experiences past what 150% needs carry into the next stage's count
  (`Foundation.seal`), so a band's front-loaded pool (its first stage takes most of the
  fresh experiences) spreads over its stages. The model's medians with it: casual 100%,
  regular 133%, heavy 144% (`tools/pacing_model.py --foundation`); the regular reaching
  130%+ on about half its stages is an open call ([progression rules](progression-rules.md)).
- **The extra is hidden:** past `HIDDEN_FROM` (110%) the Self card stops listing open
  experiences (`state.veiled`, hints empty): "Beyond this, the Dao hides its lessons." The
  rest are found by exploring and doing varied things, not read off a list.
- **Bonus, always positive, mostly past 100%:** each graded stage adds up to
  `BONUS_TO_FULL` (+1%) by 100% and `BONUS_PAST_FULL` (+2%) more by 150%; the sum multiplies max
  health (`applyStats`) and power (`Combat.power`, so knockback too) as its own factor on
  top of `Pacing.Curve`. All 23 graded stages (QC4-FE8) at 150% is +69% by FE9, below a major jump.
- **The hook has no foundation** (`Pacing.Foundation.FROM` "QC4"; review
  [breakthrough and foundation](../design-reviews/breakthrough-and-foundation.md) rec 1):
  at QC1-3 nothing is earned (keys stay unseen, so QC4 can still earn them; deeds don't
  progress), `seal` stores nothing and returns nil (the card shows only the stage),
  the unsteady toast never fires, and `PlayerState.foundation` is `{ hidden = true,
  bonus }` (the Self card hides the row). The first percent shows on the QC4 -> QC5 card.
- **Shown as the percent only (owner, 2026-10-24):** everywhere a player sees it,
  "Foundation 86%". No grade words (the old Unsteady/Steady/Solid/Deep are gone from
  code too) and never count / target. The only thresholds are `UNSTEADY_BELOW` (50:
  the toast and the harder tribulation) and the Self card bar's 50 and 100 marks.
- **Rejected (user, 2026-10-23):** a visible solidity meter (no HUD room;
  `FoundationMeter.luau` is shelved) and damaging your own cultivation to reroll stats
  (the best play becomes regrinding, which players hate). Shattering your cultivation
  stays a one-time story beat on the demon path ([replayability](../roadmap/replayability.md)).
- **Pools per region and realm band.** Keys are once per profile
  (`data.foundation.seen`), most scoped `@<band>`: the band is a `Herbs.Regions` entry
  (InnerWilds QC1-4, MiddleWilds QC5-9, OuterWilds QR1-5, DeepWilds QR6-FE3, FarReaches
  FE4-9, as in [progression](../progression.md) "Regions"), so each band brings a fresh
  pool. A kill's band is the beast's own realm (a variant's spawn realm); the rest use
  the player's realm. Regions on the map don't pick the band (the testbed has none, and
  Deep Wilds and the Far Reaches aren't built), they only place caches.
  | Category (weight) | Key | Source |
  |---|---|---|
  | Hunt (1) | `hunt:<id>:<tier>@<band>` | first kill of a beast at a tier (young, adult, elite, apex) in a band; `Progression.onKill` |
  | Boss (2) | `boss:<id>@<band>` | first kill of a boss |
  | Home (1) | `home:tier:<n>@<band>` | first harvest of a herb tier at or over the band's (`Herbs.Regions` tier); `Garden.harvest` |
  | | `home:mut:<id>@<band>` | a harvest with a mutation of bonus >= `MUTATION_BONUS` (Golden, Thunderstruck, Auspicious, Rainbow, Heavenlit) |
  | | `home:book:<tier>` | a tier's Herbarium page completed (once ever; server `Herbarium`) |
  | Dao (1) | `dao:<class>:<level>` | each weapon Dao level (once ever; `Weapons.onLevelUp`) |
  | Discover (1) | `discover:<cache id>` | a cache or rack claimed (once ever; `WorldCaches`, which registers each anchor's region for the hint) |
  | World (1) | `world:<event>@<band>` | within `EVENT_RADIUS` of a located event while it runs, or any kill during an unlocated one (Beast Surge); `WorldEvents` |
  | | `world:treasure:<weather>@<band>` | claiming a heavenly treasure (`Treasures`) |
  | Deed (1) | per stage | `DEEDS`, below |
  A kill from a beast more than `FIT_BELOW` (3) stages under the player earns nothing,
  so a later realm can't farm the first region's young beasts. Each experience or deed
  earned pops a small "+ Foundation" line (Effect "reward", Rewards `small` tier) and
  pushes the state. Profiles from before the bands keep their old keys
  (`hunt:<id>`); the new ones are fresh, so they can earn their bands' pools once.
- **Deeds** (`DEEDS`, once per stage, `data.foundation.deeds`, reset by `seal`): the
  floor that keeps every stage's pool from emptying, each asking for range rather than
  repetition. Hunter: slay 10 beasts at most 2 stages under you, no more than 4 of one
  beast counting (so three kinds at least). Gardener: harvest 3 different herbs. Haul:
  one Store all banking at least 75% of the dantian in raw qi (`Haul.storeAll`).
  Daring: defeat a beast or boss 2 stages above you. Seclusion is not a deed: AFK,
  offline and seclusion earn no foundation (decided 2026-10-23, "AFK online = offline").
- **Targets and their sources** (the `Pacing.luau` Foundation header has the table):
  QC1-3 none (the hook), QC4 4 (the Inner Wilds pool: wolf,
  serpent, boar, the first tier I harvest, Dao, caches), QC5-8 5 (the Borderlands
  pool: the QC6 and QC8 beasts, elite wolves, boars and serpents with variants, Jade
  Jiao, tier I and mutations again, the tier I page, events and treasures again), QC9 6
  (the Elder Wolf King), QR1-5 5 (Outer Wastes: apex ring-1 beasts with variants, tier
  II and its page), QR6-FE3 5 (Deep Wilds band: Thunder Ape and Nine-Tailed Fox, tier
  III), FE4-9 5 (tier IV, events, Dao). The deeds give up to 4 a stage on top. A
  band's pool is shared by its stages, so the first stage of a band runs past 100% and
  the later ones lean on the deeds, Dao and world events.
- **Seal:** at `Cultivation.advance` (every breakthrough from QC4 on), `Foundation.seal` stores the
  percent in `data.foundation.grades[stageKey]` (a number; the field keeps its old name
  for saves, and a profile from before percents holds a word, read through `LEGACY`:
  Cracked 25, Steady 60, Solid 100, Deep 150) and resets the count, deeds and toast flag.
- **Shown:** the card subtitle "<stage>  ·  Foundation <percent>%" (the percent is the
  Breakthrough remote's 4th arg); one toast per stage when the bar first fills with a
  breakthrough open below `UNSTEADY_BELOW` ("Your foundation is only 40%. The world
  still has things to teach you.", `data.foundation.warned`); `PlayerState.foundation`
  for the Self card (`percent`, `max`, `percents` by stage key, `bonus`, `hints`;
  [remotes](../remotes.md), UI note in
  [cultivation UI](../ui/cultivation.md#foundation-row-in-the-self-card-built)).
- **Hints** (`Foundation.hints`, up to `HINTS`), all from the player's band, never a
  later realm's: beasts with an open key from `HINT_BELOW` stages below to `HINT_ABOVE`
  above (every def at its realm, plus with `Config.Wilds.VARIANTS` each ambient pack's
  range at its tier: "Slay an elite Spirit Wolf"), the next open deed with its progress,
  the band's herb tier (else the mildest open mutation, else an open Herbarium page up to
  the band's tier), the equipped class's next Dao level, a cache only when an unclaimed
  one the player can open is registered in the band's region (or in no region: the
  testbed), a world event (else a treasure) not yet met in the band, more deeds and
  beasts, and a boss in range as "The fast road: defeat the <boss>" (always shown when
  one is open, replacing the last line).
- **Tempering:** `Foundation.temper(data, steps)` raises up to `steps` old stages
  `TEMPER_POINTS` (25) each, the lowest percent first, never past `TEMPER_MAX` (150),
  never lowering; the [heart-demon trial](heart-demon.md) at each major's stage 9 tempers
  up to 3 (1 to 3 by how honestly it's answered). Each change is `{ key, fromPercent,
  toPercent }`; the trial's closing line reads "Qi Condensation 5 is now 125%".
- **Tribulation:** a heaven-defier's strikes deal `UNSTEADY_TRIBULATION` (1.2) x more
  while the pending percent is below `UNSTEADY_BELOW` (50).
- **Gaps:** with `Config.Wilds.VARIANTS` off (the main map today) beasts only spawn at
  their own realms, so QR and FE have no hunts and the Hunter and Daring deeds can't be
  done there; the rest reaches about 100% a stage. Deep Wilds and the Far Reaches aren't
  on the map, so their caches don't exist and their beasts are the bosses only. The
  Ruined Borderlands' own beasts (Stone Tortoise and the rest) aren't in an ambient
  pack, so their elite tiers aren't hinted. Not built: tempering by seclusion, the
  Cultivate-window line. Numbers
  are first guesses.
- **Sect keys** (once ever): `world:sect:rank:<rank>` (a promotion) and
  `world:sect:chain:Borderlands` (the chain finished; [sect](sect.md)).

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
- **Pacing.Curve** rows can carry `gather` (the curve's own raw qi multiplier: QR1-2 and the breathers QR7, FE4, FE7).
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
- **Pacing.HeartDemon**: questions, tempering steps, path shares, offer cooldown
  ([heart-demon](heart-demon.md#tuning)).
- **Pacing.Foundation**: experience weights, per-stage targets, grade shares,
  grade bonuses, the tribulation damage per grade, the rare-mutation line, the
  world-event radius and the hint count and range.
- **Pacing.Comprehension**: the weapon Dao to learn a class skill (`SKILL_DAO` rungs 2/5/8) and
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
stage name), `TribulationResult`, `CirculationScore`, `TimeToQC2`/`TimeToQC4`,
the raw-qi economy, and the onboarding funnel (14 steps, ends at QC4). The full
list is in [data](data.md) "What we track".

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
  bigger share), only the floor once the eater is past the herb's band (`Herbs.eatQi`);
  a Lesser Spirit Core is two wolf kills' qi at the eater's stage (`qiKills`), a Greater
  Core 8% of the bar, treasures shares. All of it only fills the dantian's room, so a
  herb never gives more than one dantian.
- The `Breakthrough` analytics event's "seconds since" resets each session.
- Overflow is untuned: `OVERFLOW_CAP` 1.5 and `CARRY_SHARE` 0.5 are first
  guesses. Open question: should gains past the bar slow down (a lower rate
  instead of only a cap), and should the QC9 -> FE1 tribulation carry as much as
  a minor breakthrough?
- The cap line ("Your dantian can hold no more") is a toast only; the objective line
  doesn't show it.
