# Combat and action states

## Purpose
Action combat against beasts: an M1 chain per weapon class (a five-hit fist
chain bare-handed; see [weapons](weapons.md)), a flying-sword dash with
i-frames and perfect dodges, and up to a few equipped techniques. Realm power
scales all player damage.

## Realm power and suppression (2026-10-23)
- **Strength by stage** (`Pacing.Curve` `health`, `power`): about +10% a minor stage
  and x2.25 at each major. Health 100 (QC1), 215 (QC9), 480 (QR1), 1030 (QR9), 2330
  (FE1), 4990 (FE9); power 1.0, 2.14, 4.82, 10.3, 23.3, 49.9.
- **Beasts follow the curve.** Enemy defs are authored against `Pacing.BeastBaseline`
  (the 2026-10-22 player stats); `Realms` scales each beast's health by the curve's
  power over the baseline's and its damage by the curve's health over the baseline's,
  at the beast's `realm`, so a same-stage beast stays the fight it was designed as.
- **Realm suppression** (`Pacing.Suppression.KEEP` 0.2, `Realms.suppression`): an
  attacker whose major realm is below the target's deals 0.2x per major between them
  (a QC player does 20% to a QR beast, 4% to an FE one; a QC beast the same to a QR
  player). A higher realm gets no bonus beyond its stats; minor stages never suppress.
  Applied at the two choke points: `Combat.damageEnemy` (every player hit) and
  EnemyService `hurtBy` (every beast and boss blow). Tribulation strikes aren't
  suppressed. A minor stage up is fightable (1.1x on both sides); a major up is not
  (2.25x on both sides plus suppression).
- **Heaven-defiers** (`data.heavenDefying`) ignore `Pacing.HeavenDefying.SUPPRESSION_RESIST`
  (half) of the reduction when they hit upward: 0.6x per major instead of 0.2x.
- Enemy bars read a beast a major up as at least "far" (two: "deadly"), and one a
  major below as "below" ([enemies](enemies.md)).

## Design intent
- Responsive on every device: the client predicts actions and hits; the server
  re-checks the same timelines and owns damage and cooldowns.
- Every enemy attack that hurts is telegraphed on the ground first, and dodging
  through it negates it. A **perfect dodge** (just before the hit) refunds
  technique cooldowns.
- Holding **guard** (right click, L2, touch Block) blocks beast attacks from the
  front at the cost of a guard bar; raising it just before a hit is a **perfect
  parry** that staggers the beast ([guard and perfect parry](../combat/guard-parry.md)).
- Souls-style lock-on (PC T/middle mouse, gamepad R3, touch Lock button) and a
  touch **Auto** mode that locks, closes in and strikes by itself so mobile
  players only dash and cast. The lock camera pulls back for big targets: its
  distance range (normally 8-24 studs) and the scroll-out limit scale with the
  target's size (1.0-1.8x its height, or half its length), so the Thunder Ape
  (~30 studs) frames at 30-54. Tuning: `DISTANCE_*`, `SIZE_*` in `LockOn.luau`.
- Getting hurt marks you in combat for a few seconds: no teleporting away, and
  it's the condition for a forced breakthrough (to become the qi surge, Phase A). Getting hurt or landing damage
  (`fighting`) sets the player attribute `InCombat` until `IN_COMBAT_SECONDS`
  pass quietly; the client reads only that (the top-right tiles fold down, the
  boss bar lifts, Guide holds its spotlight). The server's `Haul` reads it too: no
  banking while it's set, and leaving the game with it set loses half the unbanked
  haul, like a death ([haul](haul.md)).
- **Techniques spend combat qi**, the mana pool (`Qi`), never the raw qi in the
  dantian that feeds cultivation. Basic attacks, dashes and the guard are free,
  so a player out of qi still fights with the weapon
  ([Combat qi](#combat-qi-technique-mana)).

## Sub-docs
- [Guard and perfect parry](../combat/guard-parry.md): guarding, perfect and
  chain parries, guard break, guard clips, sounds and GuardFX.
- [Technique visuals](../combat/technique-visuals.md): how technique effects
  are specced, built, timed and played, the shared weapon-skill helpers, and an
  index of one file per technique under `docs/combat/techniques/`.

## Key files
- `src/shared/ActionRules.luau`: the one action timeline (attack, cast, dodge),
  combo state, buffers and cooldowns, shared by client and server.
- `src/shared/Hitbox.luau`: the shared M1 hitbox, per weapon class.
- `src/shared/Weapons.luau`, `src/server/Weapons.luau`: weapon classes, the
  equipped weapon, grade and Dao multipliers ([weapons](weapons.md)).
- `src/shared/Techniques.luau`: technique defs (line, circle, chain, zone, buff),
  levels (`MAX_LEVEL` 10, +8% damage a level, XP per cast). At the top of
  tiers I-III (levels 3, 6, 9) XP stops at a bottleneck (`Techniques.bottleneck`);
  the player breaks it seated in meditation with Spirit Stones and enough weapon Dao
  (`InventoryAction "comprehend"` -> `Progression.comprehend`, numbers in
  `Pacing.Comprehension`), which opens the next visual tier.
- **Weapon Dao gates techniques** ([weapons](weapons.md) Dao 0-10). Learning needs
  the def's `dao` in its class (`Techniques.learnDao`): the seven class skills need
  2 (`CLASS_SKILL_DAO`), the starter arts (Sword Qi Wave, Palm Strike and the
  any-weapon arts) 0, so onboarding never waits on Dao. Any-weapon arts count the
  player's highest class Dao. Bottleneck k (1-3, at levels 3, 6, 9) needs Dao
  `min(10, learn + 2k)` (`Techniques.comprehendDao`): Sword Qi Wave 2/4/6, Moonflash
  Draw 4/6/8. A manual found too early is kept (`data.techniques.manuals`), toasts
  "requires Sword Dao 2", shows in Arts with its requirement, and is learned the
  moment that Dao level is reached (`Weapons.onLevelUp` -> `Progression.learnReady`).
- `src/shared/Knockback.luau`: how far player hits push beasts (by realm power
  ratio and beast weight) and the stagger they cause.
- `src/server/Combat.luau`: `action` (Attack remote: begin/hit/cancel/sync),
  damage validation, `damageEnemy`, `hurt` (i-frames, perfect dodge, Iron Skin,
  non-lethal), `power` (the stage's `power`), `inCombat`, `fighting` (hurt or
  dealing damage lately) and the `InCombat` attribute that mirrors it, technique XP.
- `src/server/CombatQi.luau`: the combat qi pool (`has`, `spend`, `deny`,
  `refill`), its regen loop and the `Qi`/`QiMax`/`QiDenied` attributes.
- `src/server/Movement.luau`, `src/client/Movement.luau`: the only writers of walk
  speed, jump and facing (actions, running, herb buffs, meditation all feed it).
- `src/client/CombatController.luau`: input, prediction, buffering, animations.
- `src/client/ActionState.luau`: local predicted action state, and
  `crowdKind`/`crowdLocked` (the local player's flinch/stagger/stun).
- `src/server/Guard.luau`, `src/client/GuardController.luau`,
  `src/shared/GuardRules.luau` (the shared meter): guarding and perfect parries;
  `src/client/GuardBar.luau` (the bar) and `src/client/GuardFX.luau` (visuals).
- `src/server/PlayerStun.luau`, `src/client/CrowdControl.luau`: player flinch,
  stagger and stun ([Player crowd control](#player-crowd-control)).
- `src/client/LockOn.luau`, `Sprint.luau`, `ShiftLock.luau` (Alt
  binding), `HeadLook.luau`.
  Sprint's loop is `Animations/Run` in `assets/Animations.rbxmx` (rbxassetid
  117319074411273, the new run clip; the old one was 81617655199380). Its
  playback speed is scaled from `Config.Movement.RUN_ANIMATION_SPEED` (26 studs/s,
  set for the old clip), so the new clip's pace is untuned: check the feet against
  the ground at run speed and retune that number if it slides.
- `src/client/CombatEffects.luau`, `Telegraphs.luau`: cosmetic effects and ground warnings.
- `src/client/CastFX.luau`: shared runtime helpers for technique effects, used
  for the caster's own casts and relayed ones alike: the striking limb
  (`handPosition`, R6/R15), the ground under a point with characters, enemies
  and effects excluded (`groundBelow`), the enemies a circle/zone/line covers
  with their near-side contact point and arrival progress (`targets`), arrival
  timing from a growing curve (`curveTime`/`frontTime`), impacts placed on a
  target (`impactAt`), and cast phases from `ActionRules.castProfile` (`phases`).
- `src/client/TechniqueVFX.luau`: plays technique effect templates
  (`ReplicatedStorage.Effects.<Id>.<Id>_T<tier>`) through the vfxia Game Module
  (`ReplicatedStorage.vfx`, plugin-owned, not mapped); falls back to plain
  `ParticleEmitter:Emit` with a warning while the module is missing.

## Techniques and weapon gating
Every technique has a `weapon`: a weapon class or `"Any"`. A class technique
casts only with that class equipped: the client shows "Requires a sword" (or
"Requires bare hands") without starting, and the server refuses the begin with
the same message. Class techniques scale with the class's grade and Dao
comprehension, and each cast grants that class `Pacing.Weapons.XP_CAST` Dao XP.
- Any: Lightning Talisman, Iron Skin, Fire Seal. Fist: Palm Strike. Sword: Sword Qi Wave.
- Weapon skills play their own clip (`Animations.Techniques.<Id>`) at
  `castSpeed`; `hits` lists each strike's clip window and damage (matching the
  clip's `Hit`/`Hit Stop` markers, numbered for multi-hit). Windup runs to the
  first hit, the active window to the last stop, and the caster is committed
  through it. The client reports the first hit; the server lands the later ones
  at their times from wherever the caster is then (unless the action ended).
- `lunge`: the client drives the root forward over `lungeWindow` (the clip's
  Lunge or Leap -> Land markers); each hit is measured from the root unless it is
  farther from the cast's start than the lunge plus `LUNGE_SLACK` and
  `LUNGE_WALK_ALLOWANCE`, when it's pulled back.

| Id | Weapon | Shape | Hits (dmg) | Lunge | Cooldown |
|---|---|---|---|---|---|
| TwinPhoenixCannon | Fist | line 18 x 6, right then left fist | 14, 14 | - | 9 |
| MoonflashDraw | Sword | line 18 x 5 from the cast's start (the dash path) | 30 | 14, i-frames while dashing | 7 |
| RampagingTiger | Saber | circle r 10 around the caster | 9, 7, 7, 16 | 6 over the leap | 12 |
| HeavenSplitter | Greatsword | circle r 12 centred 4 ahead | 6, 6, 60 (slam) | 6 over the leap; castSpeed 1.3 | 16 |
| CrescentSweep | Guandao | circle r 11 | 32 | - | 9 |
| DragonPierce | Spear | line 22 x 4 | 34 | 8 | 8 |
| GreatSageAwakening | Staff | buff 8 s: +25% all damage, +15% M1 speed; circle r 8 burst at the strike | 12 | - | 20 |

## Combat qi (technique mana)
Qi is the mana techniques spend; raw qi (`data.rawQi`, the dantian) is only for
cultivation ([cultivation](cultivation.md)). The two never mix.
- **Pool.** `src/server/CombatQi.luau`. Its size is the stage's
  `Pacing.CombatQi.MAX` (QC1 100 ... QC9 200, FE1 300; Realms `combatQi`). Not
  saved: full on join, on respawn and after a breakthrough. A larger pool after a
  stage change keeps the current qi (a breakthrough refills it anyway).
- **Regen.** Nothing for `REGEN_DELAY` (1.5 s) after a spend, then
  `REGEN_SHARE` (4%) of max per second while fighting (`Combat.fighting`: hurt
  or dealing damage within `Config.Combat.IN_COMBAT_SECONDS`), or
  `OUT_OF_COMBAT_SHARE` (20%, empty to full in 5 s) otherwise. Ticks at 10 Hz.
- **Cost.** `Techniques.qiCost(def)`: the def's `qiCost`, else `cooldown *
  COST_PER_COOLDOWN` (2.5) rounded, so 6 s Sword Qi Wave costs 15 and 20 s Great
  Sage Awakening 50. Iron Skin overrides to 25 (a defensive button shouldn't be
  priced out). Basic attacks, dashes and the guard cost nothing.
- **Authority.** `Combat.action` "begin" for a cast checks `CombatQi.has` after
  the weapon check and refuses the begin when short (`reply` false, the client
  rolls back like any refused action); the cost is spent only once
  `ActionRules.start` accepts the cast (so a cast refused for its cooldown costs
  nothing). Qi is spent at the begin, like the cooldown: a cast cancelled by a
  pre-hit dodge is not refunded.
- **Client early check.** `CombatController.cast` reads the `Qi` attribute and
  doesn't start a cast it can't pay for.
- **Refusal feedback.** Both sides set the player attribute `QiDenied` to
  `workspace:GetServerTimeNow()` (the server's refusal replicates; the client's
  early check sets it locally). The HUD flashes the qi bar on change. No toast
  and no remote.
- **Attributes (the HUD contract).** `Qi` (current, rounded to 0.1, written only
  when it changes, ~10 Hz while regenerating), `QiMax`, `QiDenied`. A hotbar can
  show each technique's price with `Techniques.qiCost`.

## Dodge visuals
Only the dodging player sees them (`CombatEffects`, from `CombatController`).
Templates: `ReplicatedStorage.Effects.Dodge`, built by
`tools/vfx_specs/Dodge.luau` (`_G.buildDodgeFX(effects)`; no tiers).
- **Dodge** (`dashTrail`): one light qi streak along the path, two
  camera-facing jade Trails (`Dodge.Streak`) moved onto the root for the dash
  and gone ~0.2 s after it. While the dash runs it also samples the body's
  pose every 5 studs (at most five, the start included) for a perfect dodge to
  draw from. Nothing is left behind.
- **Perfect dodge** (`perfectDodge`, on `Effect "perfect"`, i.e. when the hit
  would have landed), "the blow cut only a shadow". The hero is a trail of
  gold Neon afterimages along the dash (user, 2026-10-22: "make multiple after
  image copies"): the start one is this pose moved back to where the dash
  began (where the blow lands; the look the single ghost had), solid, holding
  0.14 s and dissolving by ~0.6 s; then the sampled poses toward the player,
  appearing 25 ms apart, each fainter (Transparency 0.12 up to 0.62) and
  gone sooner (the nearest ~0.3 s), none within 4.5 studs of the player, so a
  24-stud dash leaves four. A perfect dodge confirmed mid-dash drops the rest
  as the player passes their poses. Afterimage parts are pooled per body part
  (`ghostPool`) and faded by one RenderStepped loop. At the start one
  (`Perfect.Ghost`): a white 4-point twinkle flipbook where the blow meets
  it (0 ms), cut-air wisps (flipbook, 30 ms), a soft push-off ring flat at its
  feet (30 ms) and gold motes lifting off it (from 120 ms). On the player
  (`Perfect.Player`, 60 ms): a small glint and six gold sparks, plus a gold
  Highlight rim (0.35 s; Highlights are capped at 31 on screen, so map
  dressing must carry none). The rest of the dash streak turns gold, and a
  short desaturated time-slow grade plays (0.08 s hold, 0.4 s return). No
  ground crack and no shake: nothing was hit. The old gold Beam streak from
  the ghost to the player was cut: the trail draws the path now. Library ids
  are in the spec's `TEX` table.

## Guard and perfect parry
Hold right click (PC), L2 (gamepad) or the touch Block button to block beast
blows from the front for chip damage and guard meter; a raise just before a
hit parries it and staggers the beast, and a parried assault can be chained.
Tuning `Config.Combat.GUARD`. Rules, transport, clips, sounds, visuals and
guard gaps: [guard and perfect parry](../combat/guard-parry.md).

## Technique visuals
Every technique has T1-T4 effect templates played on all clients at its
technique level's tier. The pipeline and shared helpers are in
[technique visuals](../combat/technique-visuals.md); each technique's look,
layers and remake notes are in `docs/combat/techniques/<technique>.md`
(indexed there).

## Player crowd control

Bosses (and any enemy) can take a player's control for a moment, and every hit
that lands makes the player react. One server API, `src/server/PlayerStun.luau`;
the player is an R6 rig, so the reactions are procedural joint offsets drawn by
`src/client/CrowdControl.luau` on every client (observers see them too).

`PlayerStun.apply(player, kind, seconds?, source?)` returns `"applied"`,
`"immune"`, `"evaded"` or `"ignored"`. `source` is a Model the player stumbles
away from.

| Kind | Length (`Config.Combat.CC`) | Effect |
|---|---|---|
| `"flinch"` | 0.28 s | a hard recoil (torso snaps back ~24 deg, head whip, arms jolt) with a white pulse on the character and a camera shake for the local player. Never cancels or blocks an action; walking at 75%. Fired by `Combat.hurt` on every enemy hit that deals damage, so enemies don't call it; heavier hits upgrade it ([below](#enemy-hits-reaction-level-and-knockback)). |
| `"stagger"` | 0.75 s (0.4-1.0) | knocked off balance: cancels the current action, no attacking, dodging, casting, sprinting or jumping, walking at 20%, a short stumble away from `source`, camera shake. |
| `"stun"` | `seconds` (default 1.2, at most 3) | cancels the action; no actions, no movement, no steering. Pose: a snap back with the arms thrown out, then an upright drunken sway on a wide stance (one swing ~3 s; every other swing nearly falls and is caught with a sideways step, the arms lifting for balance; the heavy head and loose arms trail a beat behind), shaken off in the last 0.35 s. |

Protection, so a boss can't chain-lock a player:
- A dodge's i-frames (or a dash skill's) dodge a stagger or stun: `"evaded"`.
- After a stagger or stun ends, the player is immune to both for `IMMUNITY` (1 s).
  A stun may replace a stagger in progress; nothing replaces a stun.
- A stun landing within `DR_WINDOW` (6 s) of the end of the last one lasts
  `DR_FACTOR` (half) as long per link in the chain (1.2, 0.6, then 0.3 s, which is
  under `STUN_MIN` and ignored). A longer pause resets the chain.
- Flinches never start during a stagger or stun, or within `FLINCH_GAP` of the last.

Other API: `PlayerStun.isLocked(player)` (stagger or stun now), `kind(player)`,
`remaining(player)`, `clear(player)`. State replicates as Humanoid attributes:
`CCKind`, `CCStart`, `CCEnd` (server time), `CCMove` (walk speed share, applied by
both `Movement` writers), `CCLock`, `CCFrom` (source position). No remote.
Gating: server `Combat.action` refuses `begin` while locked and `PlayerStun`
cancels the running action (`onLock`); client `ActionState.crowdLocked()` blocks
`tryStart`, drops buffered inputs, sprint, approach and jumping.

Enemy attacks can carry `stun = { kind, radius, seconds? }` (Enemies.luau): at
the end of the windup every player inside that circle is hit with `PlayerStun.apply`, and the exact circle is telegraphed like a damaging attack.
The new Elder Wolf King opens every fresh engagement with a `roar` (`pack.howl`, a `howl` attack, 1.0 s windup, no damage) that staggers players within 18 studs for 0.8 s; the server holds the roar until the target is within 24 studs so it can catch them (a dodge or backing off avoids it). Its Pack Call (the two health-threshold calls) also has
`stun = { kind = "stun", radius = 20, seconds = 1.0 }`; it only exists behind
`Config.Wilds.NEW_WOLF_KING` (testbed). Dodge through the roar or stay out of the ring.

### Enemy hits: reaction level and knockback

Every enemy hit that lands (`hurtPlayer`/`hurtPart` in EnemyService) picks one of
the three levels (`EnemyService.reaction`):
1. a stun or stagger the attack carries for its hits (`stun.onHit`, a barrage's
   `hitStun` on parts flagged `stun`), else
2. the attack's own `react` (`"flinch" | "stagger" | "stun"`, length
   `reactSeconds`), else
3. `"stagger"` for a heavy blow (`CC.HEAVY_KINDS`: slam, charge, leap) from a
   beast of weight `CC.STAGGER_WEIGHT` (2.5, the Stone Boar) or more, else
4. the flinch `Combat.hurt` already gave.

So wolves and serpents only flinch, the boar's charge staggers, boss slams,
charges and leaps stagger, the Thunder Ape's Body Slam staggers (`react`) and
Judgment and the Jiao's coil stun (`stun.onHit`). A slam's outer pound wave only
flinches. Protection (immunity, i-frames) applies as above.

The hit also knocks the player back, by the enemy (`EnemyService.knockback`):
the beast's `knock` studs, else `KNOCK_BASE + KNOCK_PER_WEIGHT * weight` (wolf ~2,
boar ~2.8, wolf king and fox 5, ape and jiao 6), times `KNOCK_BY_REACT` (1.5 for a
stagger or stun), capped at `KNOCK_MAX` (9). An attack's `knock` replaces it
(`0` = none: the Jiao's coil, so the ring keeps its trap). A snare's pull
replaces the shove. The server sends Effect `"knock"` (from, studs) to the hit
player only and `CrowdControl.knock` shoves their own root away from the beast
over `KNOCK_SECONDS` (0.22 s, easing off; longer throws stretch to an average
of `KNOCK_MEAN_SPEED` 60 studs/s, so the Jiao's 36-stud tail shove takes 0.6 s), taking over from the stagger's stumble
while it plays. Untested in play: the shove fights the Humanoid's ground
controller the same way the stumble does, so the real distance may come out
shorter than `studs`.

## Data flow
Client presses -> `ActionRules` decides if legal -> plays locally and sends
`Attack { begin }`; hit reports follow as `Attack { hit, targets }` -> server
replays the timeline, checks timing (`MAX_LAG`, `CLOCK_SLACK`) and the slackened
hitbox (a claimed target outside it now still counts if it was inside at the
swing's time, rewound at most `REWIND`: lag compensation, `EnemyHistory`), applies `damage * Combat.power(player)` (times `Weapons.multiplier` for M1,
then realm suppression in `damageEnemy`) and knockback, and acknowledges
via `Effect "action"`. Enemy attacks call `Combat.hurt`, which reports
`"perfect" | "dodged" | "hit"` and fires `Effect "hurt"`/`"perfect"`.

## Tuning knobs
- `Config.Combat`: `CLASSES` (each weapon class's chain with per-step `push`,
  hitbox and max targets; `FIST_STEPS` is the Fist chain), chain/reset timings, buffers, dodge
  (`DODGE_*`, `IFRAME_*`, `PERFECT_*`), hitbox and server slack, `REWIND` (swing
  lag compensation) and `ESCAPE_LEAD` (enemy strikes spare a player already
  moving out, see [enemies](enemies.md) "Server and client"), lock-on and
  auto ranges, `IN_COMBAT_SECONDS`.
- `Techniques.luau`: per-technique damage, cooldown, `qiCost` (optional), shape,
  cast timing, `weapon`, and for weapon skills `hits`, `castSpeed`,
  `lunge`/`lungeWindow`.
- `Pacing.CombatQi`: pool size by stage (`MAX`, `DEFAULT_MAX`), `REGEN_SHARE`,
  `OUT_OF_COMBAT_SHARE`, `REGEN_DELAY`, `COST_PER_COOLDOWN` (the default cost).
- `Config.Combat.LUNGE_SLACK`, `LUNGE_WALK_ALLOWANCE`: the server's lunge check.
  `VISUAL_TIERS` maps levels to the four visual tiers (I 1-3, II 4-6, III 7-9,
  IV 10), and so where the comprehension bottlenecks sit; `TechniqueVFX.STEP_COUNT` is the extra particle count per level inside a tier.
- `Knockback.luau`: `REALM_EXPONENT`, `MIN_DISTANCE`, `ARMOR_BREAK`, stun, base pushes.
- Per stage (`Pacing.luau`): player `power` and `health` (curve and Adjust);
  `Pacing.Suppression.KEEP`, `Pacing.HeavenDefying.SUPPRESSION_RESIST`; `Pacing.BeastBaseline`.
- `Config.Combat.CC`: flinch, stagger and stun lengths, move shares, stumble push, immunity and diminishing returns.

## Known gaps
- Palm Strike plays Fists.4, whose `Hit Stop` marker is at 0.45 s, but
  `Config.Combat.FIST_STEPS[4].hitStop` is 0.50: the hitbox window (and the
  effect's active phase, which follows Config) runs ~0.05 s of source time past
  the animation's marker. Effects follow Config until the two are aligned.
- Flinch, stagger and stun
  are procedural R6 poses (untested in play, no authored clips) and there is no
  dazed-stars effect yet: the VFX library has a `star` but no template is built.
  The Elder Wolf King's `Roar` pose is still unplayed (its Pack Call keeps its own).
- Sword Qi Wave's blade stops visually at walls, but its damage box still
  reaches through them.
- An interrupted enemy windup's telegraph still plays out on clients.
- `Dodge` and `Cast` remotes in `assets/Remotes.rbxmx` are unused.
- Combat qi is untuned and unplayed: pool sizes, regen rates and costs are first
  guesses (three techniques cast on cooldown at QC1 drain the pool in roughly
  20 s of fighting). Open questions: costs are flat while the pool grows with
  the stage, so casting gets freer as players climb (scale costs with technique
  level or stage?); should a dodge-cancelled cast refund its qi; should perfect
  dodges or parries restore qi; should items or root perks touch combat qi.
- Testbed casts cost qi like the main game (no free-qi flag).
- Suppression is unplayed. Poison and slow from a lower-realm beast still land in
  full (poison is a share of max health), and a bat's leech heals from the
  unsuppressed damage.
- Technique visual gaps (Fire Seal's client-timed ticks, observers never
  seeing windups or the Great Sage twirl, Heaven-Splitting Descent's first
  hit landing before the sweep) are in [technique visuals](../combat/technique-visuals.md#known-gaps)
  and the technique files; guard gaps in [guard and perfect parry](../combat/guard-parry.md).
