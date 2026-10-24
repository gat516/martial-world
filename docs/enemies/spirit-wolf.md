# Spirit Wolf (shipped)

The ring-1 pack wolf (shipped): fight, numbers, effects. Shared systems (AI states, wire, cues, attack mechanics, template contract): [enemies.md](../systems/enemies.md).

History: the new fight went to the **testbed first** behind `Config.Wilds.NEW_WOLF`;
the user fought it there and approved it, and it shipped to the main game on
2026-10-21 (`NEW_WOLF = true`). Setting the flag back to false still brings back the
old def (one 0.55 s lunge, 60 HP, the old part-built body). **Follow-up:** remove
`OLD_SPIRIT_WOLF` (Enemies.luau), the old `SpiritWolf` template in
`assets/Enemies.rbxm` and the flag once the main game has run on the new wolf for a
while. Also decided: a careless player
may die to the GateWolves (3 since the hook rework, `Spawns.Zones`; fallback `Pacing.Adjust.QC2 = { beastDamage = 0.85 }`);
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
  only one, and only if no other Spirit Wolf is within 30 studs; at the GateWolves
  the first howl rallies the others, so nothing spawns. They are `fleeting`: gone
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

Testbed (`WEIGHTED_MOVES`): a pounce or leap that ends with the target more than 60
degrees off its nose skids round to face it over the recover (`pounceSkid`, `leapSkid`)
instead of sliding and snapping; the windup turns into the lunge or leap.

Health 80 (was 60), QC2, weight 1. Sanity check against a QC2 sword player (power
1.10, chain about 44 damage per 2.25 s): roughly 8 s to kill one wolf with realistic
uptime; the sword finisher (push 6) breaks a windup at QC2 (ARMOR_BREAK 6). Sounds
(`SFX.Enemies.SpiritWolf`): `Howl` (PSE Wolf Howl 5), `Attack_bite`, `Attack_leap`,
`Attack` (pounce), `Hurt` (a pitched-up whimper on stagger), `Land` (PSE Dirt
Impacts), `Aggro`, `Death`; all picked by description only, not listened to.

The testbed's `Wilds.Zones.WolfPair` (test.project.json) still keeps two Spirit Wolves
at (-90, 648.6, -40), 127 studs from the spawn pad, for tuning.


## Effects
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
| windup howl | under `Config.NEW_TELEGRAPHS`: the roar from 30% of the windup, `Impact.roar` (`EnemyImpact.Roar`: 3 rough sound rings flying out of the jaws with thin bright rings between, a breath wisp cone, motes; `EnemyImpact.RoarDust`: dust and grit blown forward off the ground ahead of the head, a flattening dust ring), aimed along the wolf's facing tilted up. Otherwise `HowlRings` (3 rings + slate ring) at Mouth. `CrestGlow` (glow, rising motes) on `Crest` either way | the stock howl ring draws only without `NEW_TELEGRAPHS` |
| skid (`pounceSkid`, `leapSkid`) | `Impact.skid`: dust sprayed ahead, chips, a dark scuff and a puff ring at all four paws, three bursts over 0.35 s | the overshoot turn-around (`Attack`/`AttackName` = `<move>Skid`, EnemyFX `skid` cue) |

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

## Known gaps
- The Spirit Wolf's howl reinforcements are untested in play: where they appear on
  broken ground (a spot can be behind a wall the mover can't cross), whether 3 extra
  wolves on a QC2 player is too much, the onboarding limit, and whether howls become a
  farm (full rewards; see "Howl reinforcements").
- The Spirit Wolf fight was approved in the testbed but is unseen in the main game's
  wilds: the leap's flight over broken ground (EnemyMover can stop it short at a wall;
  the hit still resolves on the circle), the GateWolves pair in the FirstKill beat,
  and phones with a pack of four. Its sounds were picked unheard.
