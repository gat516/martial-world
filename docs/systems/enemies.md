# Enemies and spawning

## Purpose
Demon beasts in the wilds: the source of raw qi, Spirit Stones, spirit cores,
seeds, insight and technique manuals, and the main test of a player's realm.

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
skip all of this: their overhead bar stays off and the boss you fight gets the
themed screen bar instead (`BossBars.luau`, see [boss bar](../ui/boss-bars.md)), dressed with the
same tiers and per-boss omen pools. Art: `art/ui/draw_ui.py enemybar` (`EB` geometry, `EB_TIERS`
colours), ids in `art/ui/assets.json` (`enemybar_*`).

### Adding a beast's effects (EnemyFX)
Put `src/client/EnemyFX/<EnemyType>.luau` returning any of `windup`, `strike`,
`dash`, `stagger`, `death`, `land`, `hit`, each `(cue) -> ()`; a cue is `{ model,
root, kind, attack, shape, seconds, target, at }` (shape and seconds left only on
windup, target only on hit). Branch on `cue.attack` (the model's `Attack`
attribute when the cue fires). Skipped past 220 studs from the camera. Server
code never plays effects; if a cue is missing, add an attribute, a field on the
telegraph, or an `enemyCue` (below), not a server-side effect.

A barrage's windup (the Fox's, the Raven's embers) is ONE `windup` cue whose
`shape` is `{ kind = "multi", parts, center }`: the real circles, lanes and cones are in
`shape.parts` (each with its own centre or box, `radius` and `delay`), and `shape.center` is
the beast's own ground position, not the target. Read `shape.parts`, never `shape.center`, for
where a barrage lands.

Where each cue comes from (`EnemyFX/init.luau`):
| Cue | Source |
|---|---|
| `windup` | the `Telegraph` remote (needs the enemy model in it); `seconds` = time left |
| `strike` | `AIState` goes windup -> dash or recover (fires for every attack, telegraphed or not) |
| `dash` | `AIState` becomes dash (same tick as strike for lunges) |
| `stagger` | `AIState` becomes stagger |
| `land` | `AIState` leaves dash (to recover, stagger, anything), or the server's `enemyCue` |
| `hit` | only the server: `Effect:FireAllClients("enemyCue", model, "hit", character)` once per player caught |
| `death` | `Health` reaches 0 |

`enemyCue` is generic: `Effect:FireAllClients("enemyCue", model, name, target?)`
calls handler `name` with `cue.target = target` (a Character or nil). Use it for
moments with no state change, such as a leap's touchdown when the leap isn't
modelled as a dash. Handlers dedupe what can arrive twice (the Spirit Wolf
ignores a second `land` within 0.3 s).

Bosses get no stock howl ring: `Telegraphs` skips the pale swelling disc for any `howl` shape from a boss def (roars, intros, phase calls, the fox's leap marker, the Jiao's emerge), since each boss's EnemyFX plays its own effect there. Under `Config.NEW_TELEGRAPHS` (testbed only for now) no enemy gets one: a `howl` shape draws nothing, and the wolf's `howl` windup cue carries its roar effect. Damaging and crowd-control areas still draw (in the new look: [telegraphs.md](telegraphs.md)).

### Arrivals, skids and turning into moves (testbed, `Config.Wilds.WEIGHTED_MOVES`)
The server side of telegraphs.md "Attacks that make sense" (2026-10-22 boss feel pass).
`WEIGHTED_MOVES = TESTBED`: the main game keeps the old snap-and-slide until the user
approves it.
- **Turning into the move.** A leap, bound, charge or lunge no longer snaps to face the
  target at windup start: the root turns toward where it goes over the first 60% of
  the windup (`EnemyMover.turnTo`, an eased timed yaw that wins over walking turns and
  works standing still). A leap or bound then finishes its yaw in the air, over 80% of
  the flight, to touch down facing the target (or along the flight when the target is
  still on the landing spot). Nothing turns after landing except an `arrive` follow-up
  turning into its own blow.
- **`arrive`** (attack field, an ordinary attack): started the moment the parent's dash,
  leap or bound arrives, with no recover between, if the target is within the
  follow-up's `range` and at most 100 degrees off the nose (its windup turns into it,
  over 70% of the windup). It keeps the attack slot, sends its own telegraph, windup
  and strike cues under its own name (AIState goes dash -> windup, so the parent's
  `land` cue still carries the parent's name), and a pattern boss resumes the attack
  it cut in front of. List it in the pattern or pool with `chainOnly` so clients find
  its timing.
- **`skid`** (attack field): no follow-up to start (the arrive missed, or there is none
  and the target is more than 60 degrees off the nose): AIState `recover` for the
  parent's recover, model attribute `AttackName = "<name>Skid"` (`Attack` stays the
  parent's; `AttackName` equals `Attack` everywhere else), a 1-5 stud slide on along a
  charge or lunge (0.06 s of its dash speed, over 0.3 s), and a turn to the target over
  75% of the recover (at most 0.9 s).
- **`DashSeconds`** is now also set for leaps and bounds (their real flight);
  `EnemyAnimator` times leap and bound poses by it.
- **Client** (`EnemyAnimator`, `EnemyMotion`): a recover whose `AttackName` names another
  move than `Attack` plays that move (the skids), timed by the parent's recover; an
  arrival's dash -> windup holds the landing pose until `Attack` names the follow-up;
  `motion` families (the ape) get `BoundMode`, `BoundSide`, the drawn velocity and the
  turn rate as pose input. With the flag on, leaps and bounds fly a flatter-topped arc
  (`EnemyMotion` `HANG`): same apex, flight time and landing, a quicker rise and drop
  and a short hang at the top.
- Users: Thunder Ape `thunderRush` -> `rushSwipe` / `thunderRushSkid`, `skyfallSlam` ->
  `skyfallSweep` / `skyfallSlamSkid`, its bound modes; Elder Wolf King `kingLeap` ->
  `kingRake` / `kingLeapSkid`; Spirit Wolf `pounceSkid`, `leapSkid` (skid only, when it
  overshoots). The Jade Jiao's `tailShove` uses `rangedNext` ([jade-jiao.md](../enemies/jade-jiao.md)).


Bosses' impacts (2026-10-22):
`src/client/EnemyFX/Impact.luau` plays
`Effects.EnemyImpact` (builder `tools/vfx_specs/EnemyImpact.luau`), layered
on every boss's ground blows, landings, skids and projectile ends (and the
normal wolf's roar). Templates are authored at radius 10 in neutral colours;
each layer's `Role` attribute is painted from the element palette (thunder,
venom, fox, moon, earth), and the shake falls off with distance. Layers:
`Shock` (Neon torus wave and echo, bright front, rough ring, rays, dark
crater; 6), `Dust` (skirt, smoke ring, flipbook plume, rock chips; 4),
`Contact` (flash, flipbook star, glint, sparks, ink; 5), `Burst` (splat
flipbook, flame tongues, embers, dark smoke; 4), `Scar` (scorch, crack web,
burning crack cooling to dark, smoulder; 4, fades over 3.5 s), `Rocks`
(Craters ring, Game Module only), `Roar`/`RoarDust` (sound rings, breath,
motes; forward dust, grit, ring), `Skid` (spray, chips, scuff, puff), `Shot`
(core over a dark disc, halo, glint, shed sparks, dark and bright trails).
A heavy landing is about 100 particles one-shot. Untested: everything at play
speed and in a real fight (only Edit-mode stills of a landing, the roar and a
bolt were checked), the arrival follow-ups and skids against the combat
agent's live cues (the skid is detected from `Attack` or `AttackName` ending
in `Skid`), Craters rocks and Game Module playback, phone cost with several
impacts at once, and whether the extra shakes double up with the templates'
ScreenEffects shakes when the Game Module is present.

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
- **`leech`** (Bat): a landed hit heals the beast that share of its damage and fires the `leech`
  cue. **`slot`**: a zero-damage attack (the shriek) still takes the attack slot.
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
- `src/shared/Enemies.luau`: defs (health, speeds, aggro/leash, attack and boss
  pattern, `qiDrop`, `stones`, `drops`, `bossDrops` (bosses' manual/weapon pool, see [weapons](weapons.md)), `realm`, `weight`). Kill qi scaling uses
  `Pacing.Income.ENEMY_QI_EXPONENT` through `Realms.enemyQi`.
- `src/shared/Spawns.luau`: ambient encounter rules (rates, caps, safe spots).
- `src/shared/Regions.luau`: named regions (shape, intended realm, flavour line,
  ambient pack table).
- `src/server/Spawner.luau`: keeps zones (`Workspace.Wilds.Zones` parts with
  `Enemy`/`Count`/`Radius`) topped up with respawns (zones: GateWolves 2 Spirit Wolves
  by the Sect Gate array for the FirstKill beat, WolfPocket, WolfDen, BoarMeadow,
  BoarField, SerpentMarsh, SerpentFen, BossArena; positions in [world-overview](../world-overview.md) and [docs/map/wilds.md](../map/wilds.md)), runs ambient encounters,
  `Spawner.pack` (drop a group) and `Spawner.boost` (world events).
- `src/server/EnemyService.luau`: runs beasts: `spawn(id, at, { home, roam, target })`,
  `despawn`, `onRemoved`, the state machine (idle, chase, windup, dash, recover,
  stagger), attack pools, packs (howl, circle, hop) and attack slots, `strike`
  (telegraphed areas, also used by the tribulation), kill rewards and `onKill` hooks.
- Kill hooks: `Progression.onKill` (insight, manuals, boss pools), `Inventory.onKill`
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
  joints. Every template passes `check_rig.luau` and `keyframe_test.luau`.
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

## Boss projectiles (backend built; the Nine-Tailed Fox's foxfireVolley uses it)

User decision (2026-10-21): real projectiles are for **bosses only**. Regular
beasts (the Venom Serpent's spit) keep their ground circles, and player
techniques keep resolving at Hit with the flight drawn on top.

A projectile is a real object in flight: it hits whoever it reaches when it
reaches them, so a player beats it by sidestepping or dashing through it, and
walls or rising ground stop it. The hit goes through the boss's `hurtPlayer`,
so dodges, reactions and knockback apply
([combat](combat.md#enemy-hits-reaction-level-and-knockback)).

**Warning the player.** Melee reads at a glance from the red ground fill;
projectiles use the same language, then the shot itself takes over:
- Straight shot: in the windup, the red lane it will fly down
  (`Projectiles.warnLane`), filling until release. In flight, the shot is the
  warning: its effect must be bright and big, with a ground shadow under it so
  its distance reads, and a whoosh (vfx agent).
- Lob: its landing circle (`Projectiles.warnLanding`), sent for windup + flight
  so the fill completes at touchdown.
- Homing shot: no lane (it follows you); a red ring under the target player that
  follows them through the windup (`Projectiles.mark`).
- Not built: a screen-edge arrow for a shot aimed at you from off screen (UI).

**Backend** (`src/server/Projectiles.luau`, `src/shared/ProjectilePath.luau`,
`src/client/ProjectileView.luau`):
- `Projectiles.fire(spec)` -> id. Spec: `owner` (the boss model; never hit, the
  shot ends if it leaves), `cue` (what clients draw), `origin`, `velocity`,
  `radius`, `gravity` (0 straight), `homing = { player, turn }` (deg/s),
  `range`, `lifetime` (default 4 s), `pierce`, `terrain = false` to pass through
  the map, `ignore`, `onHit(player, position)` (return false: not a hit, fly
  on), `onEnd(position, reason)` (`hit`, `terrain`, `range`, `lifetime`,
  `owner`, `cancel`), `data` (passed to the drawer). `Projectiles.lobVelocity`
  aims a lob onto a point in a given flight time. Also `cancel(id)`,
  `cancelOwner(model)`, `position(id)`. At most 80 in flight.
- Each Heartbeat the server steps the path and spherecasts the step against the
  map (skipping characters, live enemies and zones), then checks every player
  once per shot: hit when the step's segment comes within radius + 1.5 of their
  root, both where the server sees them and where their movement carries them
  within half their ping (the same grace as ground areas, `ESCAPE_LEAD`). A
  player in dodge i-frames (`Combat.evading`) is passed through; `onHit` still
  runs so the perfect dodge is granted.
- Clients get Effect `"projectile"` (spawn info with server start time) and
  `"projectileEnd"` (id, position, reason); nothing replicates per frame.
  ProjectileView catches a late spawn up by server time, flies it on the same
  `ProjectilePath` rule, and calls the drawer registered for its cue
  (`ProjectileView.register(cue, { start, step, finish })`). A homing shot may
  drift slightly on clients by the target's replication lag. In the testbed an
  unregistered cue draws a red debug ball; in the main game it draws nothing.
- Untested in play. Converting a boss attack: in its resolve, warn in the
  windup, then `fire` with `onHit = ctx.hurtPlayer(enemy, attack, player)` and
  register its drawer in that boss's EnemyFX. The knockback still pushes away
  from the boss, not along the shot.
- Converted (testbed, untested): Thunder Ape `boulderHurl` and `thunderLance` (`Attack.projectile`).
  The lob warns its r10 landing circle for the whole 1.7 s windup (`warnLanding`, locked at windup start),
  fires `cue "boulder"` at 1.25 s from the root-relative offset (7, 14, -2) (right hand overhead), radius 5,
  gravity 160, aimed with `lobVelocity` to land on the circle 0.45 s later, `data = { size = 5 }`. A direct
  hit hurts; on `onEnd` anyone else in the r10 circle takes the impact, only if it landed inside the circle.
  The lance warns the 8 x 90 lane (`warnLane`, 1.4 s) and fires `cue "thunderLance"` at windup end from 16
  studs ahead of the root at 3.5 studs above the ground: speed 150, radius 2.5 (matches the lane's half width),
  range 74, `pierce`, `data = { length = 90, width = 8 }`. A stagger of the ape before the release cancels the
  boulder's fire. Other candidates: Jade Jiao
  `venomLance` and `venomSpray`; Nine-Tailed Fox `foxfireVolley`. Each goes to
  the testbed first.

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
- Per stage (`Pacing.luau`): `beastHealth`, `beastDamage` (Adjust, by the beast's
  realm; EnemyService applies them through `Realms.ofBeast`),
  `Global.BEAST_HEALTH/BEAST_DAMAGE`, and kill qi through `Realms.enemyQi`.

## Known gaps
- The Inner and Middle regions are now zone boxes ([docs/map/wilds.md](../map/wilds.md)); the Outer
  region is still a placeholder ring. The middle and outer regions reuse ring-1 beasts
  until their own exist.
- Arrivals, skids and turning into moves (`WEIGHTED_MOVES`) are untested in play:
  whether the eased windup turn reads, the ape's `over` bound (a 180-degree air turn
  over 0.64 s), skid slides against walls, the follow-ups' short windups (rushSwipe
  0.4 s right after a dodge of the rush), the Jiao holding still for its shot, and the
  36-stud tail shove, which the client plays over the stock `KNOCK_SECONDS` 0.22 s
  (a near-teleport; CrowdControl should stretch long knocks). The pose modules time a
  bound's flight from `active`, not the per-mode `DashSeconds`, until the animators
  read it.
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
- No difficulty-tier system yet (user wants bosses at several tiers: bigger areas, faster
  windups, more follow-ups, still possible). The next boss designer proposes the tier table
  and builds per-tier scaling on a def's attacks once the user approves it. No existing
  boss has an ultimate or a cover mechanic yet either.
- Every boss uses placeholder sounds reused from other enemies, never
  listened to.
