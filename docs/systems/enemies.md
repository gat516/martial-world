# Enemies and spawning

## Purpose
Demon beasts in the wilds: the source of raw qi, Spirit Stones, spirit cores,
seeds, insight and technique manuals, and the main test of a player's realm.

## Design intent
- Readable fights: every damaging attack has a ground telegraph; bosses rotate a
  pattern and summon adds at health thresholds.
- Beasts cultivate on the same ladder as players (`realm`), and have a `weight`.
  Together they set how far player hits throw them: a Qi Condensation fist can't
  move the Elder Wolf King (QC9, weight 7); Foundation shoves it.
- Kill rewards scale with the killer's dantian, so old beasts stay worth hunting.
- Besides designated zones, players roaming open ground meet ambient packs drawn
  from the region they're in (`Regions.luau`: the Sect, Inner Wilds, Ruined
  Borderlands, Outer Wastes, each with the realm it's meant for), so deeper
  regions are deadlier. The sect has no ambient beasts.

## Key files
- `src/shared/Enemies.luau`: defs (health, speeds, aggro/leash, attack and boss
  pattern, `qiDrop`, `stones`, `drops`, `bossDrops` (bosses' manual/weapon pool, see [weapons](weapons.md)), `realm`, `weight`), `QI_SCALE_EXPONENT`.
- `src/shared/Spawns.luau`: ambient encounter rules (rates, caps, safe spots).
- `src/shared/Regions.luau`: named regions (shape, intended realm, flavour line,
  ambient pack table).
- `src/server/Spawner.luau`: keeps zones (`Workspace.Wilds.Zones` parts with
  `Enemy`/`Count`/`Radius`) topped up with respawns, runs ambient encounters,
  `Spawner.pack` (drop a group) and `Spawner.boost` (world events).
- `src/server/EnemyService.luau`: runs beasts: `spawn(id, at, { home, roam, target })`,
  `despawn`, `onRemoved`, the state machine (idle, chase, windup, dash, recover,
  stagger), `strike` (telegraphed areas, also used by the tribulation), kill
  rewards and `onKill` hooks.
- Kill hooks: `Progression.onKill` (insight, manuals, boss pools), `Inventory.onKill`
  (drops), `Garden.onKill` (seeds).
- `src/shared/Knockback.luau`; client `EnemyAnimator.luau` (procedural gait by
  `AIState`), `EnemyBars.luau` (overhead and boss bars), `EnemySounds.luau`,
  `Telegraphs.luau`.
- Models: `ServerStorage.Enemies` (`assets/Enemies.rbxmx`).

## Data flow
Spawner decides where -> `EnemyService.spawn` clones the model, tags it `Enemy`
-> AI ticks every `Config.Wilds.AI_TICK` -> attacks fire `Telegraph` to clients and
resolve via `Combat.hurt` -> on death each damager gets qi (capped by dantian),
stones, a kill count, and the `onKill` hooks run -> `onRemoved` lets Spawner refill.

## Tuning knobs
- Per beast: `Enemies.luau`. Ambient rates: `Spawns.luau`. Packs per region: `Regions.luau`.
- Per stage (`Pacing.luau`, not wired yet): `beastHealth`, `beastDamage` (Adjust,
  by the beast's realm), `Global.BEAST_HEALTH/BEAST_DAMAGE`, the stage's `gather`
  for kill qi, and `Income.ENEMY_QI_EXPONENT` (replacing `Enemies.QI_SCALE_EXPONENT`).

## Known gaps
- The Pacing beast multipliers and `Realms.enemyQi` aren't read by
  EnemyService/Spawner yet.
- Region shapes and Spawns' safe spots are placeholders until the world layout
  settles; the middle and outer regions reuse ring-1 beasts until their own exist.
- Enemy hits don't knock players back yet.
- One ring of wilds: three beasts and one boss.
