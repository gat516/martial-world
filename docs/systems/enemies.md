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
themed screen bar instead (`BossBars.luau`, see [ui](ui.md)), dressed with the
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
- **Howl reinforcements** (user decision, 2026-10-21; the user saw no wolves arriving
  to a howl): a howl that finds no idle packmate within its 30 studs calls 1-3 Spirit
  Wolves instead (`summons`, `count` 1 to `countMax` 3, `maxAlive` 3 per howler). They
  appear 18-25 studs around the target on ground within 8 studs of its height
  (`reinforcePoint`), already targeting it, so they never howl themselves (no chains),
  wait 1-2.5 s before their first attack and take attack slots like any wolf. While the
  target is still in onboarding (its `QC3` beat not passed, `data.beats`) a howl calls
  only one, and only if no other Spirit Wolf is within 30 studs; at the GateWolves pair
  the first howl rallies the second, so nothing spawns. They are `fleeting`: gone
  without rewards once they have no target, leave the leash or would fall asleep.
  **Rewards: summoned wolves pay full rewards** (qi, stones, drops, kill credit, exactly
  like any wolf; summons have never been reduced), so a player who leaves and re-engages
  a lone wolf (a fresh engagement after `ENGAGE_RESET`) can farm up to 3 extra wolves
  per howl. The Elder Wolf King's summons now also arrive already targeting (they used
  to howl on their first think) and wait 1-2.5 s before attacking.
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
| `howl` | howl | 0.8 / - / 0.2 | first notice | stock howl ring | 0 | once per engagement; rallies, or calls 1-3 wolves |

Health 80 (was 60), QC2, weight 1. Sanity check against a QC2 sword player (power
1.10, chain about 44 damage per 2.25 s): roughly 8 s to kill one wolf with realistic
uptime; the sword finisher (push 6) breaks a windup at QC2 (ARMOR_BREAK 6). Sounds
(`SFX.Enemies.SpiritWolf`): `Howl` (PSE Wolf Howl 5), `Attack_bite`, `Attack_leap`,
`Attack` (pounce), `Hurt` (a pitched-up whimper on stagger), `Land` (PSE Dirt
Impacts), `Aggro`, `Death`; all picked by description only, not listened to.

The testbed's `Wilds.Zones.WolfPair` (test.project.json) still keeps two Spirit Wolves
at (-90, 648.6, -40), 127 studs from the spawn pad, for tuning.

### Stone Boar (shipped)
Built behind `Config.Wilds.NEW_BOAR` for the testbed first; the user shipped it to the
main game on 2026-10-21 (`NEW_BOAR = true`) without fighting it in the testbed first.
Setting the flag back to false still brings back the old boar (one 1.0 s charge,
160 HP, the old body). **Follow-up:** remove `OLD_STONE_BOAR` (Enemies.luau), the old
`StoneBoar` template in `assets/Enemies.rbxm` and the flag once the new boar has
proved itself in play. User direction (2026-10-21): "a charge and then it uses its tusk
to attack you". Either `NEW_WOLF` or `NEW_BOAR` turns on attack slots and dash-front
hits for every non-boss beast (`TURNS` in EnemyService).

With the flag on: the body is `StoneBoarB` (the roster boar, built by
`art/enemies/quadrupeds/build_stone_boar.luau` + `rig_stone_boar.luau`, posed by
`EnemyPoses/Boar.luau`, effects in `EnemyFX/StoneBoar.luau`, "Stone Boar effects"
above; shared leg planting in `EnemyPoses/Quadruped.luau`, QA
`art/enemies/quadrupeds/qa_quadruped_poses.luau`). EnemyAnimator loads the pose module
only if it's there (`FindFirstChild`) and falls back to the generic pose. Tells: the Neon cracks
`CrackL1/L2/R1/R2`, `CrackBack` (Chest) and `EyeL/EyeR` (Head); effect attachments
`TuskTip` (Head), `Core` (Chest), `HoofFL_FX`, `HoofFR_FX`. It never hops.
- **Pacing:** while the charge is ready (or within 1 s of it) it side-paces 16 studs
  out (`pack.circle` with `waitFor = "charge"`, 5 studs/s, facing you; it closes in
  from farther and backs out to 16 from closer). While the charge cools down it
  closes in to gore range and gores, holding at 4 studs when the gore is cooling too.
- **Charge:** straight through you, but only 3 studs past where you stood at the
  windup (`stopPast`; the lane is clamped between 12 and 30 studs, and the telegraph
  shows the real lane). EnemyAnimator times the dash pose from the `DashSeconds`
  attribute.
- **Follow-up:** if you're within 7 studs when the charge's recover ends it gores at
  once (`followUp`: past its pause and the gore's cooldown, but it still waits for the
  attack slot, up to 1 s past the recover, `FOLLOW_UP_WAIT`).
- **Opener:** each engagement opens with the charge, but if you rush it inside the
  charge's 12-stud minimum it uses its pool (the gore) instead of waiting
  (`pack.closeOpener`; the wolf doesn't set it).

Fix 2026-10-21: in play it only ever charged. The 30-stud dash left it far past you
so the follow-up lapsed, circling held it at 16 studs, and the opener rule blocked the
gore up close.

| Attack (`name`) | Kind | Windup / active / recover | Range | Area | Damage (QC4 165 HP) | Cooldown |
|---|---|---|---|---|---|---|
| `charge` (opener) | charge | 1.0 / up to 0.55 (distance + 3, 12-30 studs at 55/s, `dash`) / 0.7 | 12-28 | box 5 x lane | 26 (16%) | 4 s, then the gore if close |
| `gore` | cone | 0.6 / 0.15 (the hook: the first 0.15 s of recover) / 0.8 in all | 0-7 | cone r 7, 100 deg | 20 (12%) | 2.5 s |

Cues as the wolf's: `windup` (Telegraph remote, `seconds` = the windup only),
`strike` (windup -> dash for the charge, windup -> recover for the gore), `dash`
with the strike, `land` as it leaves `dash`, `hit` once per player caught (the
charge's when the dash front reaches them), `stagger`, `death`. The gore resolves at
windup end; the hook is drawn in the first 0.15 s of `recover`.

Health 200 (was 160), QC4, weight 2.5, qiDrop 24. Sounds (`SFX.Enemies.StoneBoar`, PSE,
picked by description, unheard): `Attack_charge` (Pig Grunts 2, deep, 0.85 pitch),
`Attack_gore` (Pig Squeals 6 at 0.7), `Hurt` (Pig Grunts 5), `Land` (Debris Rain 4, the
skid as a charge ends); the old boar picks these up too. The testbed's
`Wilds.Zones.BoarPair` keeps two at (100, 648.6, -40).

### Elder Wolf King (testbed trial)
User direction (2026-10-21): try the animation workflow on the wolf boss; make it
reasonably hard, with real risk of dying, and add fast reaction checks: a paw swipe
and a downward paw/claw strike. The big attacks keep longer, readable anticipation
and every move leaves an opening. This is a pass on the existing QC9 boss, not a
new enemy id.

`Config.Wilds.NEW_WOLF_KING = Config.TESTBED` gates the entire pass. The main game
keeps the older body, 1500 HP and old attack pattern. After the user fights and
approves the trial, set that flag to `true` to ship it.

The trial draws `ElderWolfKingB`: the already-rigged Studio-part roster King,
promoted from `_RosterWolves.ElderWolfKing` without changing its wolf-family
skeleton. Sources: `art/enemies/wolf_family/build_elder_wolf_king.luau`,
`rig_wolf_family.luau`, `promote_wolf_king.luau`; poses:
`src/client/EnemyPoses/WolfKing.luau`, registered only for that body in
`EnemyAnimator`. It shares the Spirit Wolf's hierarchy at 2.4x, with its own
`JointManeL/R` and `JointSeal`. Dark slate body, silver mane and crest, amber eyes
and brow, jade collar seal; its shoulders stand above a player. Its eventual home
is the Inner Wilds boss arena; the trial is on the separate testbed baseplate.
The promotion cloned the live roster rig instead of regenerating it: 146 parts,
26 motors, 119 welds, the original HealthBar and six Tell attributes. The root is
upright at (0, 6.24, 0), with rest feet at Y 0. There were no AnimSaves on the source.
Only the new B template was added to the binary asset; the old King and the other
shipped templates are retained. The promotion script refuses to replace an existing
staging folder or B template.

The opener is Royal Bite. The repeating pattern is Paw Swipe -> King's Rush ->
Claw Down -> Crownfall -> Royal Bite. Pack Call interrupts the next attack at 65%
and 30% health, then resumes that attack; `thresholdOnly = true` keeps the call out
of the normal rotation. It calls two Spirit Wolves, capped at two owned wolves
alive. Those wolves arrive already targeting and cannot howl in another pack.

| Attack (`name`) | Kind | Windup / active / server recover | Start range | Locked area | Damage (QC9 330 HP) | Cooldown |
|---|---|---|---|---|---|---|
| Royal Bite (`royalBite`) | cone | 0.90 / 0.16 / 1.00 | 14 | r 15, 100 deg | 64 (19%) | 2.3 s |
| Paw Swipe (`pawSwipe`) | cone | 0.45 / 0.12 / 0.75 | 11 | r 12, 95 deg | 34 (10%) | 1.6 s |
| King's Rush (`kingsRush`) | charge | 1.00 / lane / 1.00 | 30 | 7-wide lane, 12-30 long | 82 (25%) | 3.1 s |
| Claw Down (`clawDown`) | slam | 0.55 / 0.12 / 0.85 | 11 | r 4.5 at local (1.7, 0, -7) | 46 (14%) | 1.8 s |
| Crownfall (`crownfall`) | slam | 1.25 / 0.18 / 1.25 | 14 | r 13 at local (0, 0, -3.5) | 104 (32%) | 2.9 s |
| Engage roar (`roar`, `pack.howl`) | howl | 1.00 / 0.10 / 0.80 | first engagement (`ENGAGE_RESET`), held until the target is within 24 | no damage; staggers players within 18 studs for 0.8 s (`stun`, `PlayerStun`; circle telegraphed; a dodge evades it). Doesn't consume the pattern | 0 | - |
| Pack Call (`packCall`) | summon | 1.20 / 0.10 / 1.00 | threshold | no damage, but the howl stuns players within 20 studs for 1.0 s (`stun`, `PlayerStun`; the circle is telegraphed; a dodge evades it) | 0 | 2.6 s |

Cooldowns start with the windup; the server always completes the attack and recover
before starting the next one. Stationary attacks hit **at windup end**. Their active
animation is the first part of server recover, not extra damage delay: the windup
reaches contact and the active phase follows through. The rush hits each player as
the dash front arrives, stops three studs beyond the locked target position, and
runs at 50 studs/s (up to 0.60 s plus the mover's 0.10 s settling allowance).
`DashSeconds` times the moving pose. Slam `offset` values are facing-local ground
studs; the downward strike's circle is under the right forepaw. The offsets are
locked with the telegraph, so the attack cannot track a late dodge.

Health 1900, QC9, weight 7, walk/run 5/20 (run raised from 14: the player walks at 16, so 14 could never close; King's Rush stays a 50/s dash), aggro 55, leash 110. Rewards, drops and
respawn remain the existing boss's. The quick checks punish slow reactions without
the damage of the big commitments; Crownfall punishes ignoring a long tell. These
are starting values for the user's playtest, not measured difficulty.

`shareTurns = true` makes the King reserve the same damaging-attack slot as its
wolves; it keeps its root planted against crowd nudges during windup and recover.
`resetOnEvade = true` sends it home when no eligible player remains, heals and
resets its pattern/thresholds there, and dismisses owned wolves on abandonment,
death or despawn. Its wolves are temporary encounter adds, not arena residents.
The testbed zone `WolfKingTrial` spawns one at (0, 648.6, -300), away from the wolf
and boar pairs and the spawn pad. Fight at QC9 for the intended comparison; the
test kit gives equipment but does not change the player's realm.

Effects: `src/client/EnemyFX/ElderWolfKing.luau`, gated to `ElderWolfKingB`; standard
`windup`, `strike`, `dash`, `land`, `hit`, `stagger`, `death` cues. Every windup's
`seconds` covers only the windup. Body hooks: `Mouth` (Skull), `Core` (Chest),
`PawFL_FX`/`PawFR_FX`/`PawBL_FX`/`PawBR_FX` (the paws), `SealFX` (Seal).
The existing `SFX.Enemies.ElderWolfKing` Aggro/Attack/Death sounds are reused.
No new remotes.

The King has its own effect set, `Effects.ElderWolfKing` (28 templates, about 190
emitters; builder `tools/vfx_specs/ElderWolfKing.luau`, installs
`_G.buildElderWolfKingFX`). It no longer uses the wolf or boar templates. Look:
moon-silver qi on ink-slate; **gold is the warning tell** (every windup flare is
gold, so gold means react); pale spirit-cyan for the ghost-wolf flourishes; jade
only on the collar seal. No crown or halo (user, 2026-10-21). Identity comes from
the aura (mane flames, spirit motes, breath mist, a turning ground array) and from
**ghost wolves**: translucent Neon copies of the King's own parts (`ghost` in the
handler: the head for roar/howl/bite, up to 40 body parts for the death) that rise,
swell and dissolve. A particle's `Size` is a half-width, so the builder halves its
authored diameters once in `em`.

Cues (the handler is `EnemyFX/ElderWolfKing.luau`; `EnemyFX/init.luau` gained two
generic cues, `ready` once per enemy when first seen and `aggro` on idle/return ->
chase, for any beast that wants them):

| Beat | Layers / how it plays |
|---|---|
| Aura (`ready`, always on) | ground array (ink disc + turning mandala, 2), mane flames, spirit motes, crest embers, mouth mist: 6 light emitters mounted in the body, about 17 particles/s. Health scales it: rates x(1 + 1.2 x lost health), flames go silver -> gold-white (<=65%) -> gold (<=30%), embers appear below 70%, and Pack Call flares it x2.2 for 3 s |
| Aggro roar (plays on the `roar` attack's release, via `strike`; `aggro` itself only lights the aura) | `Roar` at the Mouth (8: three sound rings, mist blast, flash, sparks, floor ring and dust), a ghost head lunging out, aura flare, small shake; 12 s gap |
| Every windup | `BrowFlare` on both eyes (4: gold star, pop, held glow, needle) |
| Royal Bite | windup `BiteTell` (8: gold motes drawn into the muzzle, two closing rings, ink + gold maw glow, fang glints flash at 0.62 s, mist); contact `BiteSnap` (13: upper and lower fang crescents, flash, star, spiky ring, rays, ink, embers, smoke, shake) plus a short ghost-head lunge |
| Paw Swipe | windup `SwipeTell` on the left paw (5, the loudest at its start: a big gold star at 0 s, three gold claw streaks, closing ring); contact `SwipeSlash` (9: three crescents and echo sweeping across the cone, claw rake, wind lines, sparks, smear) |
| Claw Down | windup `Marker` on the locked circle (6) then `ClawRaise` on the right paw at 50% (5); contact `ClawStrike` (11: falling claws, lit crack over a dark crack, ring, dust, chips, embers, shake) |
| King's Rush | windup `RushCharge` (6: motes and speed lines pulled in, swelling core, closing rings) + `GroundArray` under the King (5, gold); take-off `RushLaunch` (6); dash `RushTrail` (7: ink and white trails, wind, spirit glow, flames, floor dust); stop `RushSkid` (4) |
| Crownfall | windup `SlamTell` on the chest (7) + `Marker` on the locked circle (6: boundary ring, ink under it, a disc that fills to contact, a turning array, a ring closing from outside, edge sparks; this is the radius read) + jade seal flare; contact `SlamImpact` (16: flash, star, three rings, dust wall, chips and rock chunks, rays, lit crack, **scorch that stays about 6 s and fades**, embers, settling smoke, a Craters rock ring and an Explosion shake) |
| Pack Call (65% and 30%) | windup `HowlTell` (6: sound rings and arcs, glow, mist, spirit motes) + `GroundArray` in spirit-cyan + a ghost head; release `PhaseBurst` (11: spirit sigil, three shock rings, light rays and a pillar, rising motes, flash, dust, shake) + `PhaseFlare` on the chest (5) + a bigger ghost head + aura flare; at 30% (health <= 35%) counts x1.6 and a second ghost head |
| Confirmed hits | `HitClaw` (swipe), `HitBite`, `HitHeavy` (claw, rush, slam): 6 to 8 layers each, short |
| Stagger | a half-strength `PhaseFlare` on the chest |
| Death | `DeathBuild` (5, 0.9 s collapsing gather) while a ghost of the whole body (40 parts, 3.6 s) rises 16 studs and dissolves; at 0.85 s `DeathBurst` (9: white-out, star, ink splash, two rings, rays, motes, smoke, embers, shake) and `DeathSpirit` on the floor (6: sigil, pillar of rays, rising motes and petals for 3-4 s, smoke); the aura goes out |

Shakes ride the templates' ScreenEffects attributes when the Game Module is
present (`TechniqueVFX.full`) and fall back to `CombatEffects.shake` otherwise.
`Craters` needs the Game Module too; the King's model is tagged `CraterIgnore`.
Held templates carry `AuthoredSeconds` and ground ones `AuthoredRadius`; the handler
refits them to the live windup and the locked circle. The stock red telegraph is
unchanged and stays under the new markers.

Windup tasks cancel when the state or attack changes; rush release/dash cues dedupe,
and the trail stops on landing, interruption, death or its duration limit. Confirmed
hit flashes allow the same attack's immediate windup-to-contact state transition,
because its remote may arrive before the replicated phase update. Ground effects
stay at the locked point; body effects follow their attachment's part. Layer details
and library ids are in the builder.

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
  pattern, `qiDrop`, `stones`, `drops`, `bossDrops` (bosses' manual/weapon pool, see [weapons](weapons.md)), `realm`, `weight`). Kill qi scaling uses
  `Pacing.Income.ENEMY_QI_EXPONENT` through `Realms.enemyQi`.
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
- Boss bar: one entry per boss def id in `BossThemes.luau` (title, frame art,
  colours, omen pools; thresholds come from `summonAt`); `BIG_HIT` in `BossBars.luau`.
- Kill credit share: `Pacing.Rewards.KILL_SHARE`, `BOSS_KILL_SHARE`.
- Movement: `Config.Wilds.MOVE_TICK` (step and replication rate), `WALK_SLOPE`,
  `CLIMB`, `FALL_SPEED`, `TURN_RATE`, `CROWD`.
- Packs and turns: `Config.Wilds.NEW_WOLF` (the wolf fight's switch, shipped on; it or NEW_BOAR turns on slots
  and dash-front hits for everyone), `NEW_BOAR` (the boar fight's switch, shipped on),
  `NEW_WOLF_KING` (King trial, testbed only),
  `ATTACK_SLOTS`, `SLOT_GAP`, `ENGAGE_RESET`; per beast `attacks` (with `minRange`,
  `notBefore`, `active`, `arc`, `hopAfter`, `followUp`, `stopPast`) and `pack` (`howl`, `hop`,
  `circle` with optional `waitFor`, `closeOpener`); boss `pattern`, `summonAt`,
  `shareTurns`, `resetOnEvade`, and attack `offset` / `thresholdOnly`.
- Netcode: `Config.Wilds.WAKE_RADIUS` (sleep), `Config.Combat.REWIND`,
  `ESCAPE_LEAD`; client `EnemyMotion` `LEAD_MAX`, `STALE`, `FOLLOW`, `TURN`, `SNAP`,
  `DASH_SLACK`.
- Per stage (`Pacing.luau`): `beastHealth`, `beastDamage` (Adjust, by the beast's
  realm; EnemyService applies them through `Realms.ofBeast`),
  `Global.BEAST_HEALTH/BEAST_DAMAGE`, and kill qi through `Realms.enemyQi`.

## Known gaps
- The Elder Wolf King's animation was reworked (secondary motion, attack variants,
  2.6 s death; see `art/enemies/wolf_family/RIGS.md`, numeric pose QA only, known clips
  listed there). The trial is untested in play: fast tells on a moving camera and at latency, paw contact against
  the locked circles, the full cue path, shared slots with two wolves, abandonment
  reset, QC9 difficulty and phone cost need the user's testbed review. The test
  kit does not raise the player's realm; lower-realm fights are deliberately much
  harder. Do not ship the flag to the main game until that review is approved.
- The Spirit Wolf's howl reinforcements are untested in play: where they appear on
  broken ground (a spot can be behind a wall the mover can't cross), whether 3 extra
  wolves on a QC2 player is too much, the onboarding limit, and whether howls become a
  farm (full rewards; see "Howl reinforcements").
- The Stone Boar's gore fix (shorter charge, closing in while the charge cools down,
  goring when rushed) is untested in play: whether it now gores, whether the 4-stud
  hold crowds the player, and whether it backs off to charge too often for the gore
  to come up outside the follow-up.
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
- The Stone Boar fight shipped untested in play (not fought in the testbed first): its
  poses in EnemyAnimator, whether pacing at 16 studs reads as
  stalking, the gore's reach (range 7 against a cone of radius 7), the follow-up's wait
  for the slot, sounds (picked unheard). Time to kill at QC4 is about 14 s, above the
  pack-beast guide.
- Techniques don't get lag compensation, only M1 swings; their areas lean on
  `AREA_SLACK`.
- Stagger shoves aren't predicted, only smoothed.
- `tools/vfx_session.luau` still builds preview dummies without `Health`
  attributes until it's regenerated from `build_vfx_session.py`
  (`vfx_preview.luau` already sets them).
- One ring of wilds: three beasts and one boss.
