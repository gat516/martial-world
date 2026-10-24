# Enemies and spawning

## Purpose
Demon beasts in the wilds: the source of raw qi, Spirit Stones, spirit cores,
seeds and technique manuals, and the main test of a player's realm.

## Design intent
- Readable fights: every damaging attack has a ground telegraph; bosses rotate a
  pattern and summon adds at health thresholds. A boss can opt into its pack's
  attack slots (`shareTurns`) so their damaging windups do not overlap.
- Beasts cultivate on the same ladder as players (`realm`), and have a `weight`.
  Together they set how far player hits throw them: a Qi Condensation fist can't
  move the Elder Wolf King (QC9, weight 7); Foundation shoves it.
- Kill rewards scale with the killer's dantian, so old beasts stay worth hunting.
- Besides designated zones, players roaming open ground meet ambient packs drawn
  from the region they're in (`Regions.luau`: the Sect, Inner Wilds, Ruined
  Borderlands, Outer Wastes, each with the realm it's meant for), so deeper
  regions are deadlier. The sect has no ambient beasts, and none find a player
  within 90 of the sect gate or 75 of the Inner and Middle wilds arrays
  (`Spawns.Ambient.SAFE`; move these with the arrays).
- Bosses only come from their own zone and respawn timer, never from ambient
  packs (Spawner skips any `boss` def in a pack).
- Kill credit is earned, not tagged: a player gets the kill's rewards only after
  dealing `Pacing.Rewards.KILL_SHARE` of its max health (`BOSS_KILL_SHARE` for a
  boss). Whoever dealt the most always qualifies, so every kill pays someone.
- **Summoned beasts pay qi only.** Anything another beast calls (a howl's
  reinforcements, a boss's adds: `SpawnOptions.called`, set by `summon`) gives its
  qi at the untiered rate (the tier's `reward` divided back out) and nothing else: no
  stones, drops, seeds, first kills, foundation experiences, kill count or `onKill`
  hooks, so a howl is never a farm. A player still in onboarding (before the `QC3`
  beat) is paid in full, so the lesson's one reinforcement counts (`fullPay`).

### Every enemy is designed, not filled in (user, 2026-10-22)
- **Bosses go all out.** Each one has its own AI, its own signature mechanic and an
  ultimate built around its character: an arena-wide nuke the player has to dive
  behind cover for, an absorption state where it heals unless it's interrupted, or
  a boss so fast you can only hit it while it's stunned or asleep. Difficulty tiers
  push the same fight further, with bigger areas, faster windups and more
  follow-ups, but stay possible at every tier.
- **Regular beasts get the same care at their scale.** A beginner mob plays like
  one (slow, clear, forgiving). One meant to be annoying is annoying on purpose (it
  kites, swarms, poisons or interrupts). Attack patterns are learnable, with
  switch-ups so a fight never runs on autopilot, and stay fair.
- The method is in `.claude/agents/enemy-designer.md`. Bodies are built by the
  `enemy-modeler`.

### Roster
One doc per enemy (fight, numbers, effects, its own gaps). Read only the one you're working on.

| Doc | Enemies | Status |
|---|---|---|
| [spirit-wolf.md](../enemies/spirit-wolf.md) | Spirit Wolf | shipped |
| [stone-boar.md](../enemies/stone-boar.md) | Stone Boar | shipped |
| [second-wave.md](../enemies/second-wave.md) | Venom Serpent, Stone Tortoise, Shadow Mane Wolf | testbed |
| [third-wave.md](../enemies/third-wave.md) | Blood Centipede, Flame Raven, Iron-Winged Blood Bat | testbed |
| [next-beasts.md](../enemies/next-beasts.md) | Blood-Fed Hound, Ember-Scale Pangolin | approved cards, parked |
| [elder-wolf-king.md](../enemies/elder-wolf-king.md) | Elder Wolf King (boss) | testbed trial |
| [nine-tailed-fox.md](../enemies/nine-tailed-fox.md) | Nine-Tailed Fox (boss) | testbed trial |
| [thunder-ape.md](../enemies/thunder-ape.md) | Thunder Ape (boss) | testbed trial |
| [jade-jiao.md](../enemies/jade-jiao.md) | Jade Jiao (boss) | testbed trial |

A new enemy gets its own file here and a row in this table.

Shared parts (not one enemy): [variants.md](../enemies/variants.md) (realm variants and tiers), [health-bars.md](../enemies/health-bars.md) (overhead bars), [effects.md](../enemies/effects.md) (EnemyFX cues, boss impacts), [arrivals.md](../enemies/arrivals.md) (arrive follow-ups, skids, turning into moves), [projectiles.md](../enemies/projectiles.md) (boss projectiles), [animating.md](../enemies/animating.md) (motion QA), [modeling-checks.md](../enemies/modeling-checks.md) (shots, silhouette fidelity against the reference, parts audit). The 2026-10-23 roster audit (every enemy measured, a ranked work list and its briefs): [audit-2026-10-23.md](../enemies/audit-2026-10-23.md).

## Boss rules (user decisions)
Apply to every boss pass.
- **Bodies match the user's reference.** Bosses are sized and shaped like the
  reference row in the testbed place (`workspace.Folder.Model`: NineTailFox_R 2.13x,
  ThunderApe 3.71x, JadePython 3.17x, ElderWolfKing 2.4x, a 5-stud R6 `Player`).
  Never redesign a body without asking. Extra joints go in by splitting segments,
  and extra parts stay hidden or flush at rest.
- **No ghost copies.** Effects never clone the boss's body for afterimages, ghost
  heads or death ghosts. Use particles, trails and beams.
- **No flat placeholder discs.** Bosses get no stock howl disc (`Telegraphs`
  skips it for boss defs, `d1f8780`). Every roar, intro and landing carries its
  own effect.
- **Not stiff, not rushed.** Overlapping action, anticipation, weight and
  follow-through, with nothing frozen. On a big body a short windup reads as a
  twitch: lengthen the windup in the def rather than cram the pose. Each pose
  module keeps every move's timing on one line.
- **Readable at 40 studs.** Telegraphs and windup silhouettes have to read at a
  glance. The player reported "zero reaction time" on the ape's boulder before its
  windups were lengthened (`122e93b`).
- **Boss feel.** Grandeur without crowns, halos or rings over the head.
- **Telegraphs and attack feel:** see [telegraphs](telegraphs.md) (one danger
  language, projectile treatments, every movement ending in a blow, weight).
- **Projectiles.** Boss projectiles are real objects in flight
  (`src/server/Projectiles.luau`). The projectile in flight is the warning, so
  its drawer must be bright, big and shadowed.

## Server and client
The server is the only authority over a fight; clients only draw it, so every
player in a session sees the same beasts and nothing a client does can change one.

- **Server** (`EnemyService`): the AI state machine, targeting, telegraphed areas,
  every hit check both ways, health, damage, knockback and rewards. **No Humanoid
  and no body**: a live enemy is a Model holding one anchored, invisible root part
  (the template's `HumanoidRootPart`, grown to the body's bounds: the hit volume).
  `EnemyMover` walks it kinematically every `Config.Wilds.MOVE_TICK` (toward a goal
  at a speed, snapped to the ground, sliding along walls, refusing cliffs it can't
  climb, turning to face where it goes; knockback is a timed push; overlapping
  beasts drift apart) and writes its CFrame only when it moves. Idle beasts with no
  player within `Config.Wilds.WAKE_RADIUS` sleep: no thinking, no moving, nothing to
  replicate (one walking home is put there and healed first).
- **Wire**: model attributes `Health` + `MaxHealth`, `AIState` + `StateAt` (server time it began),
  `Attack` (the attack's `name`, default its `kind`), `DashFrom/DashTo/DashSpeed/DashAt`
  (a lunge, charge, leap or hop's line) and `DashArc` (studs the body rises mid-dash),
  `Target` (the UserId it's after, for head turns and circling), `Template` (the body
  template clients draw: the def's `body`, else its id), `FadeAt` (dying or
  despawning); the `Telegraph` remote `(shape, seconds, model, attack, startedAt)`;
  and `Effect "enemyCue"` (model, cue, character) for hits and other moments.
- **Client**: `EnemyMotion` builds each enemy's body locally (a clone of its
  template from `ReplicatedStorage.EnemyBodies`, the server's copy of
  `ServerStorage.Enemies`, parented as the enemy's `Body`: anchored root, no
  collisions, its Humanoid inert) and draws it where the beast is on the server
  now, so it doesn't lag or jump for high-ping players: the last replicated spot
  plus its velocity over the time since and half the ping (at most 0.35 s), along
  the server's dash line during a dash, eased, snapping when far off. Locally the
  enemy's `PrimaryPart` is the body's root, so lock-on and effects aim at what you
  see. `EnemyAnimator` poses the body's joints from its drawn velocity and `AIState`,
  `EnemyBars` shows the body's `HealthBar` from the health attributes, `EnemySounds`
  plays voices, `Telegraphs` draws areas shortened by how late they arrived,
  `EnemyFX` plays per-beast cues and fades bodies.
- **Generous, but bounded.** A player's swing that misses the beast where it is
  now still lands if it was in the hitbox at the swing's time, rewound at most
  `Config.Combat.REWIND` (`EnemyHistory`); that cap is all a forged timestamp can
  buy, and only inside the attacker's own hitbox. An enemy strike spares a player
  whose own movement (server-seen velocity, capped at dodge speed) takes them out
  of the area within half their ping, at most `ESCAPE_LEAD`. Prediction is drawing
  only: no client position, timing or hit claim is trusted past these windows.

### Overhead health bars, effects and impacts
Regular beasts' overhead bar (layout, danger tiers by realm gap, omen lines): [health-bars.md](../enemies/health-bars.md).
Adding a beast's client effects (`src/client/EnemyFX/<EnemyType>.luau`, cue sources, `enemyCue`, barrage shapes, no stock howl ring for bosses) and the shared boss impact layers (`Effects.EnemyImpact`): [effects.md](../enemies/effects.md).

### Arrivals, skids and turning into moves
Testbed only (`Config.Wilds.WEIGHTED_MOVES`): [arrivals.md](../enemies/arrivals.md) (`arrive`, `skid`, eased windup turns, flight yaw, client poses, its gaps).

## Realm variants (2026-10-23)
One def, many strengths: a spawn gives a beast a realm and a tier (young, adult, elite, apex) that scales its body, speed, cadence and moveset. Behind `Config.Wilds.VARIANTS` (testbed only; off on the main map). Bosses never take variants. Tiers, the wire, first kills, zone realms and gaps: [variants.md](../enemies/variants.md).

## Attack mechanics
Shared fields and kinds any def can use (`EnemyService`, `BossAttacks`, `Combat`, fields in `Enemies.luau`). First built for the beast named in brackets.

- **`guard`** (attack kind): no damage. After its windup it holds as AIState `dash` for `hold`
  seconds (`DashSeconds` carries the hold) with the model attributes `Guarding = true` and
  `GuardReduction` (`reduction`, 0.8); `Combat.damageEnemy` lets only `1 - reduction` of a
  player hit through (at least 1) and drops its knockback. `Guarding` clears the tick the state
  leaves `dash` (the hold ends, a stagger breaks it). When the hold ends its `arrive` follow-up
  starts at once if the target is in range and within the arrive angle of its nose, else it
  recovers. Works without `WEIGHTED_MOVES` (the only arrive that does).
- **`reach`** (lunge/charge field): studs the hit box runs past the dash's end, for a muzzle that leads the root (the serpent's strike); the telegraph shows it.
- **`flankPoint`** (lunge field): the lane ends that many studs beside the target, approached
  60 degrees off the line to it on a random side, and the windup turns toward that point, so
  the beast comes in on a flank. Its `arrive` follow-up turns into the target.
- Poison rides the existing `poison` field on spit and lunge hits (`hurtPlayer` applies it).
- **`slow`** (attack field, `PlayerSlow.luau`, unused since the Spider was cut): a landed hit slows the player's walk by `factor`
  for `seconds` (Humanoid attributes `SlowMove`, `SlowUntil`, read by both `Movement`s). It
  refreshes and keeps the stronger factor; it never stacks or roots, and a dodge ignores it. The
  `slow` enemyCue draws it.
- **`patch`** (spit field): the landing circle lingers `seconds` as a poison or slow pool (no
  beast uses either now). `BossAttacks.addPatch` shares the Jiao's pool list, ticking every 0.5 s
  for a slow and 1 s for poison; clients get `Effect "enemyPatch"` (EnemyFX handler `patch`,
  `cue.shape = { center, radius, effect }`, `cue.seconds`).
- **`leech`** (Bat): a landed hit heals the beast that share of the damage the player actually
  took (after suppression, guard and reductions) and fires the `leech` cue. **`slot`**: a zero-damage attack (the shriek) still takes the attack slot.
- **Burrow for a regular beast** (Centipede): the Jiao's `burrow` kind and a `followUp` slam
  (`erupt`, `unburrow`) work for any def; the lane ends on the target's spot (`stopPast = 0`).
  It spawns surfaced; only the dive is underground (`Burrowed`). The erupt sets `unburrowAt =
  "windup"` so `Burrowed` clears as its windup starts and the animator's rise out of the ground
  is seen (the Jiao's erupt still surfaces at resolve); the handler bursts the mound as the
  plates return and the ground break lands with the strike.
- **Flier height**: a flier's root already sits at its template height (Y 5.0 raven, 4.6 bat), so
  the hit volume is at melee reach. `perch` (a dash field, the raven's talonDive = 1.5) lowers
  `enemy.mover.rootHeight` for the dive's recover (its hit volume follows the body down) and
  restores it when the beast stands again (the drop therefore also covers the arrive `talonRake`'s
  windup, active and recover, and the skid). The animator may add Y on `JointRoot`, but the
  perch drop itself is the server's. The restore is a snap, so the root pops up 1.5 studs at the
  end of the recover unless the client eases the drawn body (untested).
- **Pose smoothing for fast loops** (`EnemyAnimator` family field `loopSmoothing`): loops are
  lerped at 14/s, which cuts off near 2 Hz; the Raven (2.4 Hz flap) and Bat (about 7 Hz) use 60.
- **Barrage pattern `embers`** (Raven): three circles (`radius`, the middle on the target and one
  `flank` studs either side) hitting 0 / 0.15 / 0.3 s after the windup.
- **`barrage`**: parts (box / circle / cone plus `delay`, `ext`, `tail`) computed at the windup's
  start from where the target stands (locked, fair), sent as Telegraph shape
  `{ kind = "multi", pattern, parts }`; `Telegraphs` draws each part filling until the windup
  plus its delay, and any shape with `parts` (the retreat's trail too, `hidden` ones skipped).
  Parts hit `delay` s after release for whoever stands in them; the beast's next attack or a
  stagger calls the rest off (`strikeId`). Part flags: `stun` (the attack's `hitStun`),
  `snare` (the attack's `pull`), `damageScale`.
- **`retreat`**: damage-free flip away (`distance`, `active`, `arc`) plus the fire-trail parts.
- **`spacing`** (`def.spacing`): the random pick and retreat triggers (Nine-Tailed Fox doc).
- Windup cues carry the telegraph's `attack` name (the Thunder Ape's change), and a snared
  player gets `enemyCue "snare"` with their Character.

## Template contract
Templates in `ServerStorage.Enemies` stay ordinary rigs: an unrotated
`HumanoidRootPart` as PrimaryPart standing on Y 0 (its height is the beast's root
height), everything jointed or welded back to it, the `HealthBar` somewhere inside,
and a Humanoid if the rig wants one (R6 animations need its Animator; nothing
else reads it). The server uses only the root (its height and the model's bounds);
the rest is drawn by clients. Server code must never look for a body part or a
Humanoid on a live enemy, and client code finds the body under `Body`.

The user's reference bodies `StoneTortoiseB` (1.76x), `ShadowManeWolfB` (1.63x) and `VenomSerpentB`
(1.40x) are in `assets/Enemies.rbxm` (brought in by `art/enemies/beasts/bring_in_wave1.luau`; look
untouched). Their `HumanoidRootPart` is grown to the body's bounds and centred on them, so a spawn
point is the body centre. Per-body numbers and attachments are in the RIGS.md of their group
(`quadrupeds`, `wolf_family`, `beasts`). Nothing uses them until the wave-1 defs land.

## Key files
- Craft docs: [animating](../enemies/animating.md) (motion QA, blending, planting) and
  [enemy effects](../vfx/enemy-effects.md) (palette, readable beats, smoke tests).
- `src/shared/Enemies.luau`: defs (health, speeds, aggro/leash, attack and boss
  pattern, `qiDrop`, `stones`, `drops`, `bossDrops` (bosses' manual/weapon pool, see [weapons](weapons.md)), `realm`, `weight`). Kill qi scaling uses
  `Pacing.Income.ENEMY_QI_EXPONENT` through `Realms.enemyQi`.
- Loot (`drops`): common beasts drop spirit cores only. Root pills are boss-only
  and extremely rare (user, 2026-10-23), Marrow Washing / Root Rebirth: Elder Wolf
  King (QC9) 2% / 3%, Jade Jiao (QC7) 2% / 3%, Thunder Ape (QR5) and Nine-Tailed Fox (QR9)
  4% / 5%. A grade takes several Marrow Washing Pills ([spirit root](../character/spirit-root.md)).
- `src/shared/Spawns.luau`: ambient encounter rules (rates, caps, safe spots), zone and pack
  realm ranges (realm variants).
- `src/shared/Regions.luau`: named regions (shape, intended realm, flavour line,
  ambient pack table).
- `src/server/Spawner.luau`: keeps zones (`Workspace.Wilds.Zones` parts with
  `Enemy`/`Count`/`Radius`) topped up with respawns (`Shared.Spawns.Zones` overrides a zone's count and
  respawn by name; zones: GateWolves, 3 Spirit Wolves respawning in 8 s,
  by the Sect Gate array for the FirstKill and Technique beats, WolfPocket, WolfDen, BoarMeadow,
  BoarField, SerpentMarsh, SerpentFen, BossArena; positions in [world-overview](../world-overview.md) and [docs/map/wilds.md](../map/wilds.md)), runs ambient encounters,
  `Spawner.pack` (drop a group) and `Spawner.boost` (world events).
- `src/server/EnemyService.luau`: runs beasts: `spawn(id, at, { home, roam, target, fleeting, called, stage, tier })`,
  `despawn`, `onRemoved`, the state machine (idle, chase, windup, dash, recover,
  stagger), attack pools, packs (howl, circle, hop) and attack slots, `strike`
  (telegraphed areas, also used by the tribulation), kill rewards and `onKill` hooks.
- Kill hooks: `Progression.onKill` (manuals, boss pools; first kills tracked), `Inventory.onKill`
  (drops), `Garden.onKill` (seeds).
- `src/server/EnemyMover.luau`: kinematic movement (goal, speed, push, turn, `look`
  to face a point while circling, ground and walls).
- `src/server/EnemyHistory.luau`: each beast's recent positions, for swing lag
  compensation (`Combat.damageSwing`).
- `src/shared/Knockback.luau`; client `EnemyAnimator.luau` (procedural gait by
  `AIState`), `EnemyPoses/` (per-family pose tables for it: `Wolf.luau` keys every
  shared wolf joint for idle, walk, run, circle and each Spirit Wolf move, with planted
  paws solved onto the ground; `WolfKing.luau` adds the King's boss moves and mane/seal
  motion; format at Wolf's top and in `wolf_family/RIGS.md`),
  `EnemyMotion.luau` (builds and draws the predicted body), `EnemyFX/` (per-beast cues,
  death fade), `EnemyBars.luau` (overhead bars; picks the boss), `BossBars.luau` and
  `BossThemes.luau` (the themed screen boss bar), `EnemySounds.luau`,
  `Telegraphs.luau`.
- Models: `ServerStorage.Enemies` (binary `assets/Enemies.rbxm`; it keeps Motor6D
  C0/C1, attributes and attachments). To change it: clone it to
  `ServerStorage._StagingEnemiesLive`, edit there, export with
  `_G.exportRbxm("ServerStorage._StagingEnemiesLive", "Enemies")`
  (`tools/export_rbxm.luau`, posted to `tools/receive_rbxmx.py`), copy
  `tools/frag/Enemies.rbxm` to `assets/`, destroy the staging copy.
- Model sources (Studio-built, re-runnable): `art/enemies/` holds one build script
  per body (the Spirit Wolf is `spirit_wolf_b/build_spirit_wolf_b.luau`), the shared
  wolf rig `spirit_wolf/rig_wolf.luau`, the posed preview `spirit_wolf/preview_wolves.luau`
  the template checker `check_rig.luau`, the keyability test `keyframe_test.luau`
  and `rig_copies.luau` (rebuilds the animatable row `Workspace._EnemyRigs`).
- Animator notes per group (joint tables, sign conventions, safe ranges):
  `art/enemies/wolf_family/RIGS.md`, `quadrupeds/RIGS.md`, `beasts/RIGS.md`,
  `bandits/RIGS.md`, `cultivators/RIGS.md`.
- Agents: `modeler` builds and rigs bodies ("Enemy bodies"), `animator` animates
  them, `enemy-designer` designs the fight and integrates.

## Model rules (user decisions, 2026-10-21)
- **Beasts** are built from Studio parts, not Blender. Each is a Motor6D tree rooted
  at the HRP, with every joint frame identity in model space. The legacy joint names
  (`JointHead`, `JointTail`, `JointLeg*`) keep their meaning, so EnemyAnimator drives
  any body.
- **Humanoid enemies** (bandits, cultivators, sect members) are standard R6 rigs
  unless the user says otherwise. Part-built armour is welded per limb so R6
  animations move it.
- **Animator-ready:** every keyed part has a unique name (clips key by part name),
  each Humanoid has an Animator, and cloth, weapons and sway pieces get their own
  joints. Every template passes `check_rig.luau` and `keyframe_test.luau`; a body built to a
  reference is scored against it with the [modeling checks](../enemies/modeling-checks.md).
- **Previews** posed in Edit mode are anchored and tagged `EditorOnly`.
- **Roster in review** (staging bodies), each group in its own staging folder:
  `ServerStorage._RosterWolves`, `_RosterQuadrupeds`, `_RosterBeasts`, `_RosterBandits`
  and `_RosterCultivators`, previewed off the map at Y 400, Z 3000, X 100 to 500. All
  18 were rigged and QA'd in the roster pass. Spirit Wolf B and Stone Boar B have
  shipped; Elder Wolf King B is promoted for the testbed trial. The other roster
  bodies still await their fights.
- **Known gaps:** EnemyAnimator can't play R6 tracks or authored clips yet (humanoid
  enemies need an AnimationTrack per AIState). The remaining roster bodies have no
  dedicated fights, sounds or VFX. The Flame Raven's server stand-in would take its whole 15-stud wingspan as a
  hitbox.

## Boss projectiles
Real projectiles are for bosses only (user, 2026-10-21): [projectiles.md](../enemies/projectiles.md) (warnings, backend, converted attacks).

## Data flow
Spawner decides where -> `EnemyService.spawn` clones the type's root-only stand-in,
sets its health attributes and tags it `Enemy` -> every client builds its body ->
AI ticks every `Config.Wilds.AI_TICK` and EnemyMover steps every `MOVE_TICK`
(sleeping beasts skip both), recording each position in EnemyHistory -> attacks set `Attack`/`AIState`, fire `Telegraph` to
clients and resolve via `Combat.hurt`; player hits go through `Combat.damageEnemy`
to `Combat.onEnemyDamaged`, where EnemyService takes the health and adds to the
beast's `damagers` tally (cleared when it walks home and heals) -> at 0 health each
credited player gets qi (capped by dantian),
stones, a kill count, and the `onKill` hooks run -> `onRemoved` lets Spawner refill.

## Tuning knobs
- Per beast: `Enemies.luau`. Ambient rates: `Spawns.luau`. Packs per region: `Regions.luau`.
- Realm variants: `Pacing.Variants` (tier gaps, size, speed, cadence, health, damage, rewards,
  tints, `AMBIENT_SPREAD`); zone and pack realms in `Spawns.luau`; region `depth` in
  `Regions.luau`; per attack `minTier` / `tiers`; `Config.Wilds.VARIANTS`.
- Overhead bar danger tiers: `Pacing.Danger` (`BELOW_AT`, `ABOVE_AT`, `FAR_AT`,
  `DEADLY_AT`, in realm stages); per-tier rim art, colours and omen pools in
  `EnemyBars.luau` `STYLES`; show time `SHOW_AFTER_HURT`, ghost drain `TRAIL`.
- Boss bar: one entry per boss def id in `BossThemes.luau` (title, optional motif frame,
  colours, omen pools; thresholds come from `summonAt`); `BIG_HIT` in `BossBars.luau`.
- Kill credit share: `Pacing.Rewards.KILL_SHARE`, `BOSS_KILL_SHARE`.
- Movement: `Config.Wilds.MOVE_TICK` (step and replication rate), `WALK_SLOPE`,
  `CLIMB`, `FALL_SPEED`, `TURN_RATE`, `CROWD`.
- Packs and turns: `NEW_JIAO` (Jade Jiao trial, testbed only), `Config.Wilds.NEW_WOLF` (the wolf fight's switch, shipped on; it or NEW_BOAR turns on slots
  and dash-front hits for everyone), `NEW_BOAR` (the boar fight's switch, shipped on),
  `NEW_WOLF_KING` (King trial, testbed only),
  `ATTACK_SLOTS`, `SLOT_GAP`, `ENGAGE_RESET`; per beast `attacks` (with `minRange`,
  `notBefore`, `active`, `arc`, `hopAfter`, `followUp`, `stopPast`) and `pack` (`howl`, `hop`,
  `circle` with optional `waitFor`, `closeOpener`); boss `pattern`, `summonAt`,
  `shareTurns`, `resetOnEvade`, and attack `offset` / `thresholdOnly`.
- Arrivals (`Config.Wilds.WEIGHTED_MOVES`, testbed only): attack `arrive`, `skid`,
  `boundModes`, `rangedNext`/`rangedWait`, negative `stopPast`; EnemyService
  `WINDUP_TURN`, `AIR_TURN`, `ARRIVE_TURN`, `ARRIVE_ANGLE`, `SKID_ANGLE`, `SKID_SLIDE`,
  `SKID_SLIDE_SECONDS`, `SKID_TURN`, `OVER_MAX`, `BACK_MAX`.
- Netcode: `Config.Wilds.WAKE_RADIUS` (sleep), `Config.Combat.REWIND`,
  `ESCAPE_LEAD`; client `EnemyMotion` `LEAD_MAX`, `STALE`, `FOLLOW`, `TURN`, `SNAP`,
  `DASH_SLACK`.
- Per stage (`Pacing.luau`): `beastHealth`, `beastDamage` (the curve's player power
  and health over `Pacing.BeastBaseline`'s, times Adjust, by the beast's realm;
  EnemyService applies them through `Realms.ofBeast`). Defs are authored against the
  baseline (e.g. QC9: a 330 HP player at power 2.13), not the live curve. Realm
  suppression (`Pacing.Suppression`) cuts damage across major realms both ways
  ([combat](combat.md#realm-power-and-suppression-2026-10-23); eased by the party
  shelter, and beasts a major below fear a player: `Pacing.Shelter`, `Pacing.Pressure`),
  `Global.BEAST_HEALTH/BEAST_DAMAGE`, and kill qi through `Realms.enemyQi`.

## Known gaps
- The Inner and Middle regions are now zone boxes ([docs/map/wilds.md](../map/wilds.md)); the Outer
  region is still a placeholder ring. The middle and outer regions reuse ring-1 beasts
  until their own exist.
- The tiered overhead bars are untested in play: the aura pulse, sheen sweep and
  skull pulse, the restyle on breakthrough, and how the 150x62 px billboard reads
  on a phone with several beasts on screen. No shipped beast is far or deadly to a
  QC1 player yet (the Stone Boar at QC4 is the only "above"), so those tiers only
  show once higher-realm beasts or lower-realm players meet. A new beast template
  needs the same HealthBar (copy it from the Spirit Wolf in `assets/Enemies.rbxm`).
- The Humanoid-free movement and netcode are untested in play, at any ping.
  Things to watch: beasts on steep or broken ground and stairs (EnemyMover has no
  pathfinding, like the Humanoid MoveTo before it: a wall it can't slide along
  stops it), cliffs, packs crowding, the body overshooting when a beast stops,
  and R6 rigs (no enemy uses one yet).
- Players and beasts pass through each other: the server root doesn't collide
  and the body is client-only.
- Techniques don't get lag compensation, only M1 swings; their areas lean on
  `AREA_SLACK`.
- Stagger shoves aren't predicted, only smoothed.
- `tools/vfx_session.luau` still builds preview dummies without `Health`
  attributes until it's regenerated from `build_vfx_session.py`
  (`vfx_preview.luau` already sets them).
- One ring of wilds: three beasts and one boss.
- **Open idea, undecided (user, 2026-10-23): boss variants.** A stronger version of a boss
  reads as one at a glance: an extra aura, a darkened or corrupted palette, and a heavier
  vfx pass on the same attacks. It may be how tiers show up: a rarer variant met in the
  world (a corrupted Thunder Ape) rather than a difficulty mode the player picks. This
  sits alongside roadmap principle 1 ("No difficulty modes with scaling"); the user
  hasn't chosen between them. Raise it on a boss design card; don't build it unasked.
- No difficulty-tier system yet (user wants bosses at several tiers: bigger areas, faster
  windups, more follow-ups, still possible). The next boss designer proposes the tier table
  and builds per-tier scaling on a def's attacks once the user approves it. No existing
  boss has an ultimate or a cover mechanic yet either.
- Every boss uses placeholder sounds reused from other enemies, never
  listened to.
