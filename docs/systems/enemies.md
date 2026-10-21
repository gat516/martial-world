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
  regions are deadlier. The sect has no ambient beasts, and none find a player
  within 90 of the sect gate or 75 of the Inner and Middle wilds arrays
  (`Spawns.Ambient.SAFE`; move these with the arrays).
- Bosses only come from their own zone and respawn timer, never from ambient
  packs (Spawner skips any `boss` def in a pack).
- Kill credit is earned, not tagged: a player gets the kill's rewards only after
  dealing `Pacing.Rewards.KILL_SHARE` of its max health (`BOSS_KILL_SHARE` for a
  boss). Whoever dealt the most always qualifies, so every kill pays someone.

## Server and client
The server is the only authority over a fight; clients only draw it, so every
player in a session sees the same beasts and nothing a client does can change one.

- **Server** (`EnemyService`): the AI state machine, movement (server-owned
  Humanoid physics), targeting, telegraphed areas, every hit check both ways,
  damage, knockback and rewards. Idle beasts with no player within
  `Config.Wilds.WAKE_RADIUS` sleep: anchored, not thinking, nothing to replicate
  (one walking home is put there and healed first). Beasts skip the humanoid
  states they never use.
- **Wire**: model attributes `AIState` + `StateAt` (server time it began),
  `Attack` (the attack's `name`, default its `kind`), `DashFrom/DashTo/DashSpeed/DashAt`
  (a lunge or charge's line), `FadeAt` (dying or despawning); and the `Telegraph`
  remote `(shape, seconds, model, attack, startedAt)`.
- **Client**: `EnemyMotion` predicts the visible body so beasts don't lag or jump
  for high-ping players: it draws the body ahead of the replicated root by its
  velocity over half the ping (at most 0.25 s), along the server's dash line
  during a dash, eased and snapping when far off, by offsetting the rig's
  root joint (layered over any animation; the overhead bar follows). `EnemyAnimator`
  poses the joints, `EnemySounds` plays voices, `Telegraphs` draws areas shortened by
  how late they arrived, `EnemyFX` plays per-beast cues and fades bodies.
- **Generous, but bounded.** A player's swing that misses the beast where it is
  now still lands if it was in the hitbox at the swing's time, rewound at most
  `Config.Combat.REWIND` (`EnemyHistory`); that cap is all a forged timestamp can
  buy, and only inside the attacker's own hitbox. An enemy strike spares a player
  whose own movement (server-seen velocity, capped at dodge speed) takes them out
  of the area within half their ping, at most `ESCAPE_LEAD`. Prediction is drawing
  only: no client position, timing or hit claim is trusted past these windows.

### Overhead health bars (EnemyBars)
Regular beasts carry a `HealthBar` BillboardGui (Dead Cells layout in the
game's lacquer-and-seal dress): a dark ink nameplate strip with the beast's name
and realm tag (`QC 4`), sitting on a long thin bar with a slanted right end. The
fill is blood-qi crimson, cut into ten slanted talisman slips (one per 10% of
health, the same count as the player's vitals bar; the divisions are drawn into
the rim art, so the slip size never depends on the beast's max health). A hit
drops the fill at once and a pale gold ghost (`Trail`) drains after it. The bar
shows while the beast is locked or for 8 s after it's hurt.

Its dressing says how dangerous the beast is **to you**: the gap between the
beast's realm and the local player's (`Realms.index`, in ladder stages) picks a
tier from `Pacing.Danger`, re-picked live when the player's `Realm` changes, so
a breakthrough makes the same beast look tamer.

| Tier | Gap (default) | Look |
|---|---|---|
| below | <= -2 | muted bronze frame, grey tag |
| even | -1 to +1 | jade frame, vermilion seal on the tip |
| above | +2 to +3 | gold frame, seal tip and lozenge cap, omen line |
| far | +4 to +5 | violet frame, long talisman tip, pulsing qi aura, sheen sweep, omen line |
| deadly | >= +6 | no name, realm or health: a pulsing cracked skull seal and an omen, shown whenever the beast is in range (90 studs) |

Omen lines are short xianxia warnings under the bar (under the skull for
deadly), one picked at random per beast per tier so it never flickers; the pools
live in `STYLES` in `EnemyBars.luau` (keep lines under ~24 characters). Bosses
skip all of this: their overhead bar stays off and the screen `Play.BossBar` is
unchanged. Art: `art/ui/draw_ui.py enemybar` (`EB` geometry, `EB_TIERS`
colours), ids in `art/ui/assets.json` (`enemybar_*`).

### Adding a beast's effects (EnemyFX)
Put `src/client/EnemyFX/<EnemyType>.luau` returning any of `windup`, `strike`,
`dash`, `stagger`, `death`, each `(cue) -> ()`; a cue is `{ model, root, kind,
attack, shape, seconds, at }` (shape and seconds left only on windup). Branch on
`cue.attack` for a boss's pattern. Skipped past 220 studs from the camera. Server
code never plays effects; if a cue is missing, add an attribute or a field on
the telegraph, not a server-side effect.

### Rig contract
Every enemy rig has exactly one joint off `HumanoidRootPart`: a Motor6D root
joint (Part0 the root, Part1 the body root: `JointRoot` to the Hips on the
beasts built by `rig_wolf.luau`, `RootJoint` on R6, `Root` on R15). Everything
else is welded or jointed below the body root, never straight to the root.
EnemyMotion moves the drawn body through that joint; a rig without one can't be
predicted and is drawn where it replicates. The four shipped templates got a
`RootJoint` (root to Chest, Body or Coil1) in place of their first root weld.

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
- `src/server/EnemyHistory.luau`: each beast's recent positions, for swing lag
  compensation (`Combat.damageSwing`).
- `src/shared/Knockback.luau`; client `EnemyAnimator.luau` (procedural gait by
  `AIState`), `EnemyMotion.luau` (predicted body), `EnemyFX/` (per-beast cues,
  death fade), `EnemyBars.luau` (overhead and boss bars), `EnemySounds.luau`,
  `Telegraphs.luau`.
- Models: `ServerStorage.Enemies` (`assets/Enemies.rbxmx`).

## Data flow
Spawner decides where -> `EnemyService.spawn` clones the model, tags it `Enemy`
-> AI ticks every `Config.Wilds.AI_TICK` (sleeping beasts skip) and records each
position in EnemyHistory -> attacks set `Attack`/`AIState`, fire `Telegraph` to
clients and resolve via `Combat.hurt`; player hits add to the beast's `damagers` tally
(`Combat.onEnemyDamaged`; cleared when it walks home and heals) -> on death each
credited player gets qi (capped by dantian),
stones, a kill count, and the `onKill` hooks run -> `onRemoved` lets Spawner refill.

## Tuning knobs
- Per beast: `Enemies.luau`. Ambient rates: `Spawns.luau`. Packs per region: `Regions.luau`.
- Overhead bar danger tiers: `Pacing.Danger` (`BELOW_AT`, `ABOVE_AT`, `FAR_AT`,
  `DEADLY_AT`, in realm stages); per-tier rim art, colours and omen pools in
  `EnemyBars.luau` `STYLES`; show time `SHOW_AFTER_HURT`, ghost drain `TRAIL`.
- Kill credit share: `Pacing.Rewards.KILL_SHARE`, `BOSS_KILL_SHARE`.
- Netcode: `Config.Wilds.WAKE_RADIUS` (sleep), `Config.Combat.REWIND`,
  `ESCAPE_LEAD`; client `EnemyMotion` `LEAD_MAX`, `FOLLOW`, `SNAP`, `DASH_SLACK`.
- Per stage (`Pacing.luau`, not wired yet): `beastHealth`, `beastDamage` (Adjust,
  by the beast's realm), `Global.BEAST_HEALTH/BEAST_DAMAGE`, the stage's `gather`
  for kill qi, and `Income.ENEMY_QI_EXPONENT` (replacing `Enemies.QI_SCALE_EXPONENT`).

## Known gaps
- The Pacing beast multipliers and `Realms.enemyQi` aren't read by
  EnemyService/Spawner yet.
- The Inner and Middle regions are now zone boxes (map.md "Wilds zones"); the Outer
  region is still a placeholder ring. The middle and outer regions reuse ring-1 beasts
  until their own exist.
- Enemy hits don't knock players back yet.
- The tiered overhead bars are untested in play: the aura pulse, sheen sweep and
  skull pulse, the restyle on breakthrough, and how the 150x62 px billboard reads
  on a phone with several beasts on screen. No shipped beast is far or deadly to a
  QC1 player yet (the Stone Boar at QC4 is the only "above"), so those tiers only
  show once higher-realm beasts or lower-realm players meet. A new beast template
  needs the same HealthBar (copy it from the Spirit Wolf in `assets/Enemies.rbxmx`).
- Netcode is untested in play, at any ping. Things to watch: the predicted body
  running ahead into walls on a blocked chase (it eases back), and R6 rigs
  (no enemy uses one yet).
- Techniques don't get lag compensation, only M1 swings; their areas lean on
  `AREA_SLACK`.
- Lock-on, auto-approach and the boss bar aim at the replicated root, not the
  predicted body (at most a few studs apart).
- Stagger shoves aren't predicted, only smoothed.
- Every beast still runs a server Humanoid. If live counts outgrow that, move
  awake beasts to a lighter server mover with client-only bodies.
- One ring of wilds: three beasts and one boss.
