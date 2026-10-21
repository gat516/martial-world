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
skip all of this: their overhead bar stays off and the screen `Play.BossBar` is
unchanged. Art: `art/ui/draw_ui.py enemybar` (`EB` geometry, `EB_TIERS`
colours), ids in `art/ui/assets.json` (`enemybar_*`).

### Adding a beast's effects (EnemyFX)
Put `src/client/EnemyFX/<EnemyType>.luau` returning any of `windup`, `strike`,
`dash`, `stagger`, `death`, `land`, `hit`, each `(cue) -> ()`; a cue is `{ model,
root, kind, attack, shape, seconds, target, at }` (shape and seconds left only on
windup, target only on hit). Branch on `cue.attack` (the model's `Attack`
attribute when the cue fires). Skipped past 220 studs from the camera. Server
code never plays effects; if a cue is missing, add an attribute, a field on the
telegraph, or an `enemyCue` (below), not a server-side effect.

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

### Spirit Wolf effects
`EnemyFX/SpiritWolf.luau`, templates `ReplicatedStorage.Effects.SpiritWolf`
(builder `tools/vfx_specs/SpiritWolf.luau`; references
`docs/reference/vfx/claw_slash_streaks_grid.webp`, `ground_slam_dome_rocks_grid.webp`).
Moonlight qi: white-hot core, #CFE6FF falloff, #7FA8D8 rim, a #2F3B50 slate copy
under each bright shape for daylight. Body hooks (modeler, 3435025): attachments
`Mouth` (Skull), `Core` (Chest), `PawBL_FX`/`PawBR_FX` (ground under the hind
paws); Neon `EyeL`/`EyeR`; crest strips `TellCrest1..3` with `Tell = true`. Each
falls back to a part (Snout/Skull, Chest, FootB*/PawB*, `Crest`) when missing.
Body-anchored effects follow their part every frame (RenderStepped), ground
effects are placed once on a raycast that skips characters and the wolf.

| Cue / attack | Template (layers) | Notes |
|---|---|---|
| windup, all | `EyeGlint` (red star glint 0.16 s, pop, held glow for the windup) on each eye | crest Tell strips go 45% dim -> #CFE6FF over the windup, back 0.2 s after (`TellBase` attribute keeps the original colour) |
| windup bite | `Breath` (wisp, motes drawn in) at Mouth | |
| windup pounce | `Gather` (motes in, streaks in, chest glow) at Core, refit to the windup | `PawDust` at both hind paws at 5/7 of the windup, if still winding up |
| windup leap | `LeapSigil` (crescent moon, slate shadow, pale ring) at `shape.center`, refit to windup + 0.45 s flight and scaled to `shape.radius` (authored r5); `LeapGlint` 1.6 studs over the Skull | the stock red circle still draws |
| windup howl | `HowlRings` (3 rings + slate ring) at Mouth; `CrestGlow` (glow, rising motes) on `Crest` | stock howl ring still draws |
| strike bite | `FangSnap` (2 crescents x core/rim/slate, glint) at Mouth | |
| strike/dash pounce, leap | `DashDust` (dust ring, low puffs, motes) between the hind paws; `MoonTrail` (bright trail, slate trail, shed motes) on Chest | trail ends at `land` or after 0.3 s (pounce) / 0.45 s (leap); leap trail is silver |
| strike/land hop | `PawDust` (puff, grit) at both hind paws | |
| land pounce (any non-leap) | `Skid` (puffs thrown forward, grit) 1.5 studs ahead of Core | |
| land leap | `Landing` (crack decal 0.8 s, slate dust ring, r5 shockwave, dust spray, rock chips, flash) under Core | `CombatEffects.shake(0.22)` when the local character is within 8 studs |
| hit bite/leap/other | `BiteHit` (ink splash, red-white sparks, pop) on the target's torso, near side | |
| hit pounce | `ClawRake` (3-streak claw x core/rim/slate, glint, sparks) | |
| stagger | `StaggerFlash` (pop, star) at Core | 0.08 s white Highlight, eyes flicker 3x |
| death | `Death` (rising motes 0.8 s, gold-white glow and glint at Core) | eyes fade 0.2 s; the body's 1 s fade is init's |

Layers per beat: windup 2 (tell) + 2 to 3 per attack; strike/take-off 3 + 3;
landing 6; hits 3 to 5; stagger 2 + flash; death 3. Library ids are in the
builder's `TEX` table. Untested in play: placement on the live body, follow
smoothness, how it reads at 40 studs and on phones with a pack of four, and the
whole path through the Game Module (not in the place; effects play on
TechniqueVFX's plain-emitter fallback).

### Stone Boar effects
`EnemyFX/StoneBoar.luau`, templates `ReplicatedStorage.Effects.StoneBoar`
(builder `tools/vfx_specs/StoneBoar.luau`, built straight from the
enemy-designer's brief, no new references). Earth qi: #FF8A2B amber with a
white-hot centre, #7E5D45 umber dust, #8F8B80 stone chips, a slate copy under
each bright shape for daylight. Every handler returns early unless the model's
`Template` is `StoneBoarB` (the old boar has none of these hooks). Body hooks
(a7115a5): attachments `TuskTip` (Head, between the two tusk points; each tusk
point is 1.15 studs either side), `Core` (Chest), `HoofFL_FX`/`HoofFR_FX`
(ground under the fore hooves); hind hooves are the `HoofBL`/`HoofBR` parts;
`Tell = true` on `CrackL1/L2/R1/R2`, `CrackBack` and `EyeL/EyeR`.

| Cue / attack | Template (layers) | Notes |
|---|---|---|
| windup, both | `EyeGlint` (amber star, pop) on each eye at t = 0 | every Tell part goes 50% dim -> hot amber over `seconds`, back 0.2 s after (`TellBase` keeps the original colour) |
| windup charge | `HoofScrape` (dust ring, puffs kicked back, slate grit) at HoofFL_FX at 0.2 and 0.55 x seconds; `Snort` (2 nostril jets) at NosePad at 0.8 x seconds | the second scrape and the snort only while AIState is still `windup` |
| windup gore | `TuskGlint` (slate dot, spinning amber glint, halo) on each tusk point | follows the Head |
| strike/dash charge | `DashDust` (umber ring, low puffs, chips, amber embers) between the hind hooves; `ChargeTrail` (dust, chips, slate grit, amber sparks; Rate emitters) ridden under the HRP at hoof level | strike and dash dedupe (0.25 s); trail stops at `land`, death or 0.65 s |
| strike gore | `GoreHook` (crescent sweep x bone core / amber rim / slate, glint at the peak) 4.5 studs ahead of TuskTip, 1 stud low, sweeping up 0.18 s | |
| land charge | `Skid` (umber under-puff, dust thrown forward, chips) 1.2 studs ahead of the fore hooves | |
| hit charge | `ChargeHit` (slate blot, amber flash, star, dust burst, chips) on the target's torso, near side | `CombatEffects.shake(0.3)` when the target is the local character |
| hit gore | `GoreHit` (crescent mark x core/slate, amber sparks, pop) | |
| stagger | `StaggerChips` (amber pop, dust, chips) at Core | Tell parts flicker 3x |
| death | `Death` (umber dust crumbling 0.9 s, amber motes rising, core glow and glint) | Tell parts fade to slate in 0.3 s; the body's 1 s fade is init's |

Layers per beat: windup 2 (+ tell) + 3 to 5; take-off 4 + 4; gore hook 4;
skid 3; hits 4 to 5; stagger 3; death 4. Library ids are in the builder's
`TEX` table. Untested in play: placement on the moving, animated body (tusk
points, trail height), the full cue path, how it reads at 40 studs and on
phones, and the Game Module path (effects play on TechniqueVFX's fallback
when the module isn't in the place).

### Spirit Wolf (shipped)
History: the new fight went to the **testbed first** behind `Config.Wilds.NEW_WOLF`;
the user fought it there and approved it, and it shipped to the main game on
2026-10-21 (`NEW_WOLF = true`). Setting the flag back to false still brings back the
old def (one 0.55 s lunge, 60 HP, the old part-built body). **Follow-up:** remove
`OLD_SPIRIT_WOLF` (Enemies.luau), the old `SpiritWolf` template in
`assets/Enemies.rbxm` and the flag once the main game has run on the new wolf for a
while. Also decided: a careless player
may die to the GateWolves pair (fallback `Pacing.Adjust.QC2 = { beastDamage = 0.85 }`);
attack slots apply to every non-boss beast; `qiDrop` stays 14; the leap stays on the
basic wolf; its qi is moonlight pale blue-white; `ServerStorage.Enemies` is now binary
`assets/Enemies.rbxm`.

The fight:
- **Body:** the def's `body = "SpiritWolfB"` (the rigged Studio-part wolf, 90 parts,
  `art/enemies/spirit_wolf_b/`); the old `SpiritWolf` template stays beside it until
  the follow-up above removes it. EnemyAnimator poses it from
  `EnemyPoses/Wolf.luau` (FAMILIES by `Template`); others keep the generic pose.
- **Pack:** the first wolf to notice a player howls (0.8 s, no damage; packmates of
  its kind within 30 studs take the same target). Each engagement opens with the
  pounce; the leap waits 6 s into it. Waiting wolves circle at 10 studs (8 studs/s,
  facing the player, switching direction every 2-4 s). A wolf hops 7 studs back
  (0.25 s, 1.2-stud arc) after a bite, or after 3 hits within 2 s, at most every 4 s.
- **Attack slots** (every non-boss beast): one beast at a time winds up or strikes at
  a player (`ATTACK_SLOTS` 1), and the next windup waits `SLOT_GAP` 0.6 s after it
  resolves, so blows land at least ~1.4 s apart (more than the 1.2 s dodge cooldown).
- **Dash hits:** lunges and charges hit each player when the dash front reaches them
  (their distance along the lane / dash speed), not at the end of the windup; a
  stagger or the next attack calls the rest off. The leap resolves its circle as it
  lands.

| Attack (`name`) | Kind | Windup / active / recover | Range | Area | Damage (QC2 120 HP) | Cooldown |
|---|---|---|---|---|---|---|
| `bite` | cone | 0.45 / 0.1 / 0.5 | 0-5 | cone r 6, 70 deg | 10 (8%) | 2.2 s, then a hop |
| `pounce` (opener) | lunge | 0.7 / 0.3 (12 studs at 40/s) / 0.9 | 5-12 | box 3.5 x 12 | 16 (13%) | 3.5 s |
| `leap` | leap | 1.0 / 0.45 flight / 1.1 | 12-24, not before 6 s | circle r 5 on the target, telegraph runs to touchdown | 18 (15%) | 9 s |
| `howl` | howl | 0.8 / - / 0.2 | first notice | stock howl ring | 0 | once per engagement |

Health 80 (was 60), QC2, weight 1. Sanity check against a QC2 sword player (power
1.10, chain about 44 damage per 2.25 s): roughly 8 s to kill one wolf with realistic
uptime; the sword finisher (push 6) breaks a windup at QC2 (ARMOR_BREAK 6). Sounds
(`SFX.Enemies.SpiritWolf`): `Howl` (PSE Wolf Howl 5), `Attack_bite`, `Attack_leap`,
`Attack` (pounce), `Hurt` (a pitched-up whimper on stagger), `Land` (PSE Dirt
Impacts), `Aggro`, `Death`; all picked by description only, not listened to.

The testbed's `Wilds.Zones.WolfPair` (test.project.json) still keeps two Spirit Wolves
at (-90, 648.6, -40), 127 studs from the spawn pad, for tuning.

### Template contract
Templates in `ServerStorage.Enemies` stay ordinary rigs: an unrotated
`HumanoidRootPart` as PrimaryPart standing on Y 0 (its height is the beast's root
height), everything jointed or welded back to it, the `HealthBar` somewhere inside,
and a Humanoid if the rig wants one (R6 animations need its Animator; nothing
else reads it). The server uses only the root (its height and the model's bounds);
the rest is drawn by clients. Server code must never look for a body part or a
Humanoid on a live enemy, and client code finds the body under `Body`.

## Key files
- `src/shared/Enemies.luau`: defs (health, speeds, aggro/leash, attack and boss
  pattern, `qiDrop`, `stones`, `drops`, `bossDrops` (bosses' manual/weapon pool, see [weapons](weapons.md)), `realm`, `weight`), `QI_SCALE_EXPONENT`.
- `src/shared/Spawns.luau`: ambient encounter rules (rates, caps, safe spots).
- `src/shared/Regions.luau`: named regions (shape, intended realm, flavour line,
  ambient pack table).
- `src/server/Spawner.luau`: keeps zones (`Workspace.Wilds.Zones` parts with
  `Enemy`/`Count`/`Radius`) topped up with respawns (zones: GateWolves 2 Spirit Wolves
  by the Sect Gate array for the FirstKill beat, WolfPocket, WolfDen, BoarMeadow,
  BoarField, SerpentMarsh, SerpentFen, BossArena; positions in map.md), runs ambient encounters,
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
  paws solved onto the ground; format at its top and in `wolf_family/RIGS.md`),
  `EnemyMotion.luau` (builds and draws the predicted body), `EnemyFX/` (per-beast cues,
  death fade), `EnemyBars.luau` (overhead and boss bars), `EnemySounds.luau`,
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
- **Roster in review** (models only, no defs yet), each group in its own staging folder:
  `ServerStorage._RosterWolves`, `_RosterQuadrupeds`, `_RosterBeasts`, `_RosterBandits`
  and `_RosterCultivators`, previewed off the map at Y 400, Z 3000, X 100 to 500. All
  18 are rigged and QA'd.
- **Known gaps:** EnemyAnimator can't play R6 tracks or authored clips yet (humanoid
  enemies need an AnimationTrack per AIState). No roster model has a def, sounds or
  VFX. The Flame Raven's server stand-in would take its whole 15-stud wingspan as a
  hitbox. The new Spirit Wolf is shipped (`Config.Wilds.NEW_WOLF`).

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
- Kill credit share: `Pacing.Rewards.KILL_SHARE`, `BOSS_KILL_SHARE`.
- Movement: `Config.Wilds.MOVE_TICK` (step and replication rate), `WALK_SLOPE`,
  `CLIMB`, `FALL_SPEED`, `TURN_RATE`, `CROWD`.
- Packs and turns: `Config.Wilds.NEW_WOLF` (the wolf fight's switch, shipped on),
  `ATTACK_SLOTS`, `SLOT_GAP`, `ENGAGE_RESET`; per beast `attacks` (with `minRange`,
  `notBefore`, `active`, `arc`, `hopAfter`) and `pack` (`howl`, `hop`, `circle`).
- Netcode: `Config.Wilds.WAKE_RADIUS` (sleep), `Config.Combat.REWIND`,
  `ESCAPE_LEAD`; client `EnemyMotion` `LEAD_MAX`, `STALE`, `FOLLOW`, `TURN`, `SNAP`,
  `DASH_SLACK`.
- Per stage (`Pacing.luau`): `beastHealth`, `beastDamage` (Adjust, by the beast's
  realm; EnemyService applies them through `Realms.ofBeast`),
  `Global.BEAST_HEALTH/BEAST_DAMAGE`, and kill qi through `Realms.enemyQi`.

## Known gaps
- The Inner and Middle regions are now zone boxes (map.md "Wilds zones"); the Outer
  region is still a placeholder ring. The middle and outer regions reuse ring-1 beasts
  until their own exist.
- Enemy hits don't knock players back yet.
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
- The Spirit Wolf fight was approved in the testbed but is unseen in the main game's
  wilds: the leap's flight over broken ground (EnemyMover can stop it short at a wall;
  the hit still resolves on the circle), the GateWolves pair in the FirstKill beat,
  and phones with a pack of four. Its sounds were picked unheard.
- Techniques don't get lag compensation, only M1 swings; their areas lean on
  `AREA_SLACK`.
- Stagger shoves aren't predicted, only smoothed.
- `tools/vfx_session.luau` still builds preview dummies without `Health`
  attributes until it's regenerated from `build_vfx_session.py`
  (`vfx_preview.luau` already sets them).
- One ring of wilds: three beasts and one boss.
