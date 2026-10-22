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

A barrage's windup (the Fox's, the Toad's tongue, the Raven's embers) is ONE `windup` cue whose
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
| windup howl | under `Config.NEW_TELEGRAPHS`: the roar from 30% of the windup, `Impact.roar` (`EnemyImpact.Roar`: 3 rough sound rings flying out of the jaws with thin bright rings between, a breath wisp cone, motes; `EnemyImpact.RoarDust`: dust and grit blown forward off the ground ahead of the head, a flattening dust ring), aimed along the wolf's facing tilted up. Otherwise `HowlRings` (3 rings + slate ring) at Mouth. `CrestGlow` (glow, rising motes) on `Crest` either way | the stock howl ring draws only without `NEW_TELEGRAPHS` |
| skid (`pounceSkid`, `leapSkid`) | `Impact.skid`: dust sprayed ahead, chips, a dark scuff and a puff ring at all four paws, three bursts over 0.35 s | the overshoot turn-around (`Attack`/`AttackName` = `<move>Skid`, EnemyFX `skid` cue) |

Bosses get no stock howl ring: `Telegraphs` skips the pale swelling disc for any `howl` shape from a boss def (roars, intros, phase calls, the fox's leap marker, the Jiao's emerge), since each boss's EnemyFX plays its own effect there. Under `Config.NEW_TELEGRAPHS` (testbed only for now) no enemy gets one: a `howl` shape draws nothing, and the wolf's `howl` windup cue carries its roar effect. Damaging and crowd-control areas still draw (in the new look: [telegraphs.md](telegraphs.md)).
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

### Venom Serpent, Stone Tortoise and Shadow Mane Wolf effects (second bestiary wave)
Handlers `EnemyFX/VenomSerpent.luau`, `StoneTortoise.luau`, `ShadowManeWolf.luau`
(shared helpers in `EnemyFX/BeastKit.luau`: template playback, attachment lookup
that tolerates a missing one, the dim-to-bright Tell strips, hit frame). Templates
`ReplicatedStorage.Effects.<Beast>`, builders `tools/vfx_specs/<Beast>.luau`. Each
handler only plays for the new bodies (`Template` = `VenomSerpentB`,
`StoneTortoiseB`, `ShadowManeWolfB`); the old defs play nothing. Every bright layer
sits on a dark copy so it reads in daylight; emitter counts are low (packs).
Shared with the old effects: `Impact.explode/ground/swipe/skid/shot` (venom, earth
and a violet-ink palette). Checked numerically against the real bodies in a sandbox (every attachment and Tell
resolves, the model faces -Z at an identity pivot, every cue fires without error, the
guard hold and the spit lob run); not played in a fight; feel and phone cost are the
user's to review.

| Beast / beat | Layers (templates) |
|---|---|
| Serpent windup (all) | EyeGlint star + held glow; Tell parts dim -> yellow |
| spit windup | SacSwell on both sacs (glow, haze, drips); MouthDrip (drips, mist); at windup - 0.4 s the gob lob (`Impact.shot`, venom) to `shape.center` |
| spit landing | `Impact.explode` venom + SpitSplash (splash, droplets, ring on slate, pool, glint) |
| hoodStrike | windup HoodGlint (star, glow on slate) per HoodSpot; strike/dash Streak (streak on slate, drops) at the Mouth; land HopDust |
| hit (strike, spit) | HitSplash (pop, splash, drops, poison bubbles) on the torso |
| hop | HopDust (dust, venom smear) |
| stagger / death | StaggerFlash + flash; Death (venom mist, motes, core glint) |
| Tortoise windup | EyeGlint on eyes and BrowMark; seams jade -> pale |
| neckSnap / shellSnap | windup Breath (neckSnap); strike SnapBurst (jade streak, chips, dust); hit HitChips |
| quakeStomp | windup ShellDust at the Core, FootPebbles at the four feet (hind feet twice: they dig); strike QuakeCrack (scar, jade crack glow, dust ring, chips, flash) + `Impact.ground` earth with rocks, shake 0.3 within 28 studs; hit HitJade |
| shellGuard | the `Guarding` attribute (wired on `ready`): seams cold white-blue, GuardSheen + a faint Highlight sheen for the hold; each Health drop while guarding throws GuardSpark on the shell; the end plays GuardRelease |
| stagger / death | StaggerChips + flash; Death (jade flash, crumble, chips, glint), seams go dark |
| Mane windup | EyeGlint violet; mane-edge/tail Tell parts dim -> flare |
| shadowStep | windup Gather; dash Takeoff, StepTrail on the Core host (smoke, streak, motes) and PawSmoke on 4 paws; land Arrive; skid `Impact.skid` |
| shadowRake / maneRend | windup ClawGlint on a front paw (+ small ManeFlare for maneRend); maneRend strike ClawSweep x2 (0.35 s apart, second rolled to mirror) + swipe dust; hit ClawRake |
| maneLash | windup ManeFlare (large) at ManeTop_FX; strike LashRing (ink, violet, flare rings, smoke, motes) + `Impact.ground` violet-ink; hit LashHit |
| hop | HopSmoke (smoke puff, ink smear, violet smear) thrown backward |
| stagger / death | StaggerFlash + flash; Death (ink smoke up, violet motes, glint) |

Needs from the body contract: attachments `Mouth`, `SacL/R_FX`
(serpent); `Mouth`, `Core`, `Foot{FL,FR,BL,BR}_FX`, `NeckBase_FX` (tortoise);
`Mouth`, `Core`, `Paw{FL,FR,BL,BR}_FX`, `ManeTop_FX` (mane); Neon `Tell` parts and
`EyeL/R`, tortoise `BrowMark` and `SeamTell*`. The server must send the `hit`
`enemyCue` once per player caught.

### Golden Toad and Blood Centipede effects (third wave)
Handlers `EnemyFX/GoldenToad.luau`, `BloodCentipede.luau` on `BeastKit`; templates
`ReplicatedStorage.Effects.GoldenToad` / `.BloodCentipede` (builders
`tools/vfx_specs/<Beast>.luau`), gated by `Template` = the template name. Smoke test:
`tools/enemy_fx_smoke.luau` (fires cues at the real bodies in a sandbox).

| Beast / beat | Layers (templates) |
|---|---|
| Toad windup | EyeGlint (teal), SacTell/WartTell dim -> gold; SacGlow (glow, motes) on the sac; MouthMist for tongueLash/gulp |
| tongueLash | strike: TongueBeam (slate base, pink tongue, pale shine) between `Mouth` and `TongueTip`, held ~0.3 s, + TipPop |
| `snare` cue | TetherBeam (teal-gold on slate) from the Mouth to the caught player's torso for 0.4 s |
| bogCroak | `Impact.roar` (teal-gold) + CroakRings (3 staggered rings) from the sac at 40% of the windup |
| miasmaLob | windup - 0.4 s: a gob lobs (`BeastKit.lob`, `Impact.shot`) to `shape.center`; landing: `Impact.explode`; the server's `patch` cue (`Effect enemyPatch`, `shape.center/radius`, `seconds`) draws BogPuddle (dark pool, scum, rim, bubbles) refit to the patch length |
| hit / hop / stagger / death | MudSplash; HopDust; StaggerFlash; Death (gold motes, bog mist, glint) |
| Centipede windup | EyeGlint (red); seams and pincer Tells light front to back (`K.tell` sweep) |
| pincerSnap / coilSweep | CrescentSnap (two blood crescents, flecks) at the Mouth; SweepArc (flat crescent on slate, dust fan) + `Impact.swipe` |
| burrowDive / `Burrowed` | dash: DiveBurst; while `Burrowed`: plates fade, BurrowMound (earth hump, dirt, chips) rides the ground under the root and CrackStamp (crack + rust glow) is stamped along the lane every 0.14 s; the plates return when it clears |
| erupt | Eruption (scar, rust glow, dust column, chips, flash, ring) + `Impact.ground` (rocks, shake 0.3 within 30) |
| hit / stagger / death | BloodHit (splatter, drops, pop); StaggerFlash; Death (bone dust, red motes, glint) |

The `snare` cue is the Fox's (`enemyCue`, target = the caught Character); `Burrowed` is set only for the dive and cleared by erupt (BossAttacks), the client hides the body. Untested in play.

### Flame Raven and Iron-Winged Blood Bat effects (third wave)
Handlers `EnemyFX/FlameRaven.luau` (Template `FlameRavenB`) and `BloodBat.luau`;
templates `Effects.FlameRaven` (10, 34 emitters) and `Effects.BloodBat` (8, 15
emitters; the swarm gets 1 to 3 emitters a beat, the single shrieker plays
`Impact.roar`).

| Beast / beat | Layers (templates) |
|---|---|
| Raven windup | EyeGlint (gold); the eight primaries and Crest Tells dim -> gold; TipFlare (soot base, flame glow, sparks) on both wing tips and the crest |
| talonDive | dash: EmberTrail on both wing tips for 0.6 s (smoke, flame, embers); land: small EmberBurst under the talons; skid: `Impact.skid` fire palette |
| talonRake / windGust | FlameSlash (3-claw on soot, sparks, glint) at Talons_FX; GustBlast (wind streaks, dust fan, sparks) + `Impact.swipe` r10 |
| emberFan | each windup cue with a `shape` lobs an ember (`BeastKit.lob`) from the Mouth to land at the windup's end (+0.15 s per extra cue); the barrage sends one cue, so the handler lobs one ember to each circle in `shape.parts`. EmberBurst (scorch, rings, flame, sparks, flash) + `Impact.explode` |
| hit / hop / stagger / death | HitFlame; WingPuff; StaggerFlash; Death (feathers go to ash: ash, embers, glint) |
| Bat windup | EyeGlint (crimson); WingEdgeTell, MouthTell, ChestCore dim -> flare |
| bloodDive | dash: DiveStreak (2 emitters) on the Core; `leech` cue: a LeechMote trail flies from the target's torso to the bat's Core in 0.5 s, then ChestFlash |
| sonicShriek | `Impact.roar` (crimson/pale palette) from 40% of the windup |
| hit / hop / stagger / death | BiteHit (3); HopPuff (2); StaggerFlash (1); Death (feathers, blood mist) |

The perch (root 1.5 studs lower after a dive) needs nothing: effects ride the body and
read the root's ground. The emberFan sends one windup for all three circles (`shape.parts`). Untested in play.

### Frost Spider effects (third wave)
`EnemyFX/FrostSpider.luau`, templates `Effects.FrostSpider` (12, 39 emitters), builder
`tools/vfx_specs/FrostSpider.luau`; ice white-blue on slate.

| Beat | Layers (templates) |
|---|---|
| Windup | the six eyes (`Eye1..6`) EyeGlint; FangTell/FrostVeinTell/CoreGlow dim -> ice; FangGlint (slate base, star, chill) on each fang |
| webShot | SpinneretGlow (glow, motes); at the strike a WebBeam thread (slate base + bright thread) to the landing for 0.4 s, then WebSplat (frost puffs, shards, glint) + `Impact.explode` ice |
| `patch` cue (slow web, `Effect enemyPatch`) | WebPatch refit to `seconds`/`radius`: slate base, silk disc, dark and bright edge rings (the edge reads without colour), strands, twinkling glints; characters standing inside get FootFrost |
| frostFang | strike: FangFrost (two ice crescents on slate, shards); hit: FrostHit (pop, crystals, stars, frost); skid: `Impact.skid` ice from the four front feet |
| `slow` cue | FootFrost on both feet (slate base, rime ring, chill motes) for the rest of the slow (Humanoid `SlowUntil`, server time; else 1.5 s) |
| hop / stagger / death | SkitterPuff; StaggerFlash; Death (shatters: 26 shards, flash, frost mist, glint) |

Untested in play. Smoke-tested against the real body: `tools/enemy_fx_smoke.luau`
(destroy the old module copies before `push_src`, or `require` returns the cached one).

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
  overshoots). The Jade Jiao's `tailShove` uses `rangedNext` (below).

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

### Second bestiary wave: Venom Serpent, Stone Tortoise, Shadow Mane Wolf (testbed)
Three regular beasts with their own bodies, behind `Config.Wilds.NEW_SERPENT`,
`NEW_TORTOISE` and `NEW_SHADOW_MANE` (all `= TESTBED`; they turn on attack slots and
dash-front hits like the other new fights). The Tortoise and the Shadow Mane have no old
def, so they exist only while their flag is on; with `NEW_SERPENT` off the old one-spit
serpent stays (the Jade Jiao's molt still summons whichever `VenomSerpent` is live). They
are in no ambient pack yet: the testbed zones `SerpentPair` (-90, 648.6, 80), `TortoiseSolo`
(100, 648.6, 80) and `ManePair` (0, 648.6, 140) keep them for the user to fight. Each is a
Studio-part body with its own pose module and effects (below). All numbers are first guesses
for the user's playtest, not balance; the user retunes them.

User decisions (2026-10-22): the serpent's strike and spit apply poison (the existing
`PlayerPoison`); Shell Guard is a real damage-reduction state; the Tortoise sits at mid tier
(QC6); the user retunes every number later. A Toad and a Blood Centipede body are also being
built (no fights yet), and the Flame Raven (flies at melee height) is next.

New server mechanics (`EnemyService`, `Combat`, fields in `Enemies.luau`):
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

**Venom Serpent** (QC3, 80 HP, weight 0.8, `body = "VenomSerpentB"`, the user's reference
cobra at 1.40x, root 5.1 x 4.8 x 15.9, muzzle 7.1 ahead of the root centre). A skirmisher: it circles
14 studs out (`pack.circle`, 5 studs/s), spits from 12 to 32 studs, strikes when you come inside 12, then slides back 9 studs (`pack.hop`, only
after a strike: `hits = 99`). It does not repeat the Jiao's lance, fang cone, spray, pools,
coil or dive.

| Attack (`name`) | Kind | Windup / active / recover | Range | Area | Damage (QC3 140 HP) | Cooldown |
|---|---|---|---|---|---|---|
| `venomSpit` (opener) | spit | 1.1 / - / 0.6 | 12-32 | circle r 5.5 on the target, lobbed gob lands at windup end | 15 (11%) + 1 poison stack 4 s | 2.6 s |
| `hoodStrike` | lunge | 0.6 / 0.25 (up to 8 studs at 32/s, stops 4 short of you) / 0.8 | 2-12 | box 3.5 wide, dash + 7 (`reach`: the muzzle leads the root) | 14 (10%) + 1 poison stack | 3.2 s, then the backslide (`hop`) |

Rushed inside 12 studs it strikes first (`closeOpener`). Poses: `EnemyPoses/VenomSerpent.luau` (a serpent family on `Serpent.luau`'s maths, QA'd on the
roster body rebuilt at 1.4x, not yet on `VenomSerpentB`), registered as `VenomSerpentB` with
`circleLoop` (its circle loop plays while it side-steps) and the moves `venomSpit`,
`hoodStrike`, `hoodStrikeSkid`, `hop`. Dash skids turn it round
(`hoodStrikeSkid`). The optional rear Tail Snap was cut: the pool picks by distance, not
bearing, so it would fire at the face.

**Stone Tortoise** (QC6, 450 HP, weight 6, walk 3.5 / run 6, `body = "StoneTortoiseB"`, the
user's reference at 1.76x, 13.3 x 13.9 x 22). Slow and heavy: it walks into you and picks from
a pool; Shell Guard first (after 5 s, every 14 s), then the stomp, then the snap. Reaches are
measured from the root centre: the root box is 13.3 x 8.5 x 22.0, the beak 10.8 ahead (11.5
stretched), the fore feet 3.3 ahead, so the stomp circle sits under the fore feet.

| Attack (`name`) | Kind | Windup / active / recover | Range | Area | Damage (QC6 220 HP) | Cooldown |
|---|---|---|---|---|---|---|
| `neckSnap` (opener) | cone | 0.7 / 0.12 / 0.9 | 13 | r 14, 60 deg | 24 (11%) | 2.5 s |
| `quakeStomp` | slam | 1.2 / 0.15 / 1.4 | 13 | r 10 at (0, 0, -3.3) | 40 (18%), stagger | 5 s |
| `shellGuard` | guard | 0.5 / hold 2.0 / 0.5 | 16, not before 5 s | none; takes 20% damage | 0 | 14 s |
| `shellSnap` (`arrive` of shellGuard, `chainOnly`) | cone | 0.35 / - / 1.0 | 14 | r 14, 70 deg | 24 (11%) | - |

**Shadow Mane Wolf** (QC6, 300 HP, weight 1.8, walk 9 / run 20, `body = "ShadowManeWolfB"`, the
user's reference at 1.63x on the wolf-family rig, root 6.5 x 8.4 x 21.3, muzzle 10.5 ahead of the
root centre). A flanker with no howl: it circles wide (`pack.circle` 18 studs, 7 studs/s), comes in on a flank, and fades back after a rend
(`pack.hop` 10 studs in 0.3 s, only after `maneRend`). Pool order: lash when hugged, rend, then
the step; rushed inside 11 it uses its pool (`closeOpener`).

| Attack (`name`) | Kind | Windup / active / recover | Range | Area | Damage (QC6 220 HP) | Cooldown |
|---|---|---|---|---|---|---|
| `shadowStep` (opener) | lunge, `flankPoint` 8 | 0.7 / 0.3-0.5 (up to 26 studs at 45/s) / 0.9 | 11-26 | 5-wide lane to a point 8 studs beside the target | 12 (5%) | 3.5 s |
| `shadowRake` (`arrive`, `chainOnly`) | cone | 0.4 / - / 0.9 | 14 | r 13, 100 deg | 22 (10%) | - |
| `maneRend` | cone + second cone at +0.35 s | 0.6 / 0.12 / 1.0 | 11 | r 12, 90 deg, twice | 16 (7%) a strike | 2.4 s, then the fade back |
| `maneLash` | slam | 0.8 / 0.15 / 1.1 | 8 | circle r 12 on the wolf | 20 (9%) | 6 s |

A step that ends with the target off its nose skids round (`shadowStepSkid`). Sounds
(`SFX.Enemies.StoneTortoise`, `ShadowManeWolf`, the serpent's additions) reuse existing ids
pitched, picked by description and unheard.

### Third bestiary wave: Golden Toad, Blood Centipede, Flame Raven, Blood Bat, Frost Spider (testbed)
Five more regular beasts on bodies already in `assets/Enemies.rbxm` (templates `GoldenToad`,
`BloodCentipede`, `FlameRavenB`, `BloodBat`, `FrostSpider`; RIGS.md has each rig), behind
`Config.Wilds.NEW_TOAD`, `NEW_CENTIPEDE`, `NEW_RAVEN`, `NEW_BAT`, `NEW_SPIDER` (all
`= TESTBED`; none has an old def, so each exists only while its flag is on, and none is in an
ambient pack yet). Testbed zones: `ToadPair` (-180, 0), `CentipedeSolo` (180, 0), `RavenSolo`
(-180, -160), `BatSwarm` (4 bats, 180, -160), `SpiderSolo` (0, -170), all Y 648.6. They fit
realms and regions like this: Toad QC3 (Inner marsh), Centipede QC6 (Ruined Borderlands), Raven
QC8 and Bat QC8 (deep Borderlands), Spider FE1 (Outer Wastes). Numbers are first guesses; the
user retunes them. A beast of each element is an affinity: toad water-venom, centipede
earth-blood, raven fire, bat wind-blood, spider ice. The Spider's higher-grade core item is
still open (it drops Greater cores until the user picks art for a new one).

New server mechanics (`EnemyService`, `BossAttacks`, `PlayerSlow`, fields in `Enemies.luau`):
- **Tongue pull**: the Toad's `tongueLash` is the Fox's `snare` barrage (a lane, `pull`,
  `followUpOnHit`), so a caught player is yanked to 4 studs and `gulp` follows only on a catch.
- **`slow`** (attack field, `PlayerSlow.luau`): a landed hit slows the player's walk by `factor`
  for `seconds` (Humanoid attributes `SlowMove`, `SlowUntil`, read by both `Movement`s). It
  refreshes and keeps the stronger factor; it never stacks or roots, and a dodge ignores it. The
  `slow` enemyCue draws it.
- **`patch`** (spit field): the landing circle lingers `seconds` as a poison (Toad miasma) or
  slow (Spider web) patch. `BossAttacks.addPatch` shares the Jiao's pool list, ticking every 0.5 s
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

| Beast | Attack (`name`) | Kind | Windup / active / recover | Range | Area | Damage |
|---|---|---|---|---|---|---|
| Toad (QC3, 90 HP) | `tongueLash` (opener) | barrage snare + pull 4 | 0.7 / - / 0.9 | 4-18 | lane 2.4 x 18 | 12 |
| | `gulp` (followUpOnHit) | cone | 0.35 / - / 0.8 | 9 | r 7, 90 deg | 14 |
| | `bogCroak` | howl + stagger 0.7 s | 1.0 / - / 0.8 | 10 | circle r 10 | 0 |
| | `miasmaLob` | spit + poison patch 3 s | 1.0 / - / 0.7 | 10-24 | circle r 4 | 10 + poison |
| Centipede (QC6, 320 HP) | `pincerSnap` (opener) | cone | 0.6 / - / 0.9 | 14 | r 11, 60 deg | 18 |
| | `coilSweep` | cone | 0.9 / - / 1.0 | 10 | r 12, 200 deg | 22 |
| | `burrowDive` | burrow, then `erupt` | 0.5 / up to 30 studs at 40/s / 0.1 | 8-32 | lane 5 wide | 0 |
| | `erupt` (followUp) | slam, stagger | 0.7 / - / 1.1 | chained | circle r 6.5 | 30 |
| Raven (QC8, 260 HP) | `talonDive` (opener) | charge, arrive `talonRake`, perch 1.5 | 0.8 / up to 20 studs at 34/s / 1.2 | 10-24 | lane 3 | 20 |
| | `talonRake` (arrive) | cone | 0.35 / - / 1.0 | 9 | r 8, 100 deg | 24 |
| | `emberFan` | barrage embers | 1.0 / - / 0.9 | 8-24 | 3 circles r 3.5 | 18 each |
| | `windGust` | cone, knock 10, then hop back 8 | 0.5 / - / 0.7 | 9 | r 10, 70 deg | 8 |
| Bat (QC8, 60 HP, swarm of 4) | `bloodDive` (opener) | charge, leech 0.5, hop away | 0.6 / up to 14 studs at 30/s / 0.8 | 6-16 | lane 2.5 | 12 |
| | `sonicShriek` | howl + stagger 0.6 s, `slot` | 1.0 / - / 0.8 | 10 | circle r 10 | 0 |
| Spider (FE1, 420 HP) | `webShot` (opener) | spit + slow patch 4 s | 0.9 / - / 0.7 | 12-30 | circle r 5 | 25 + slow 2 s |
| | `frostFang` | lunge, reach 4, slow 1.5 s, hop back 10 | 0.7 / up to 10 studs at 38/s / 0.9 | 3-14 | box 3.5 wide | 60 |

Sounds reuse existing ids pitched, picked by description and unheard
(`SFX.Enemies.GoldenToad`, `BloodCentipede`, `FlameRaven`, `BloodBat`, `FrostSpider`). Untested in
play: all of it. Specifically the tongue pull on a client-owned character, the centipede's dive
lane on uneven ground, the perch drop reading as a landing, three or four bats' phone cost and
whether overlapping shriek and dive windups feel fair (one slot at a time), the `slow` strength,
and every number.

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
Claw Down -> Crownfall -> Royal Bite -> King's Leap (skipped when the target is
closer than 12: it's a gap closer). King's Leap lands in its slam circle and, if the
target is still within 18 and in front, rakes at once (`arrive` `kingRake`); a miss
skids round (`kingLeapSkid`). King's Rush now pulls up 4 short of where the target
stood (`WEIGHTED_MOVES`; 3 past without it) and ends in the same rake, or
`kingsRushSkid`. Pack Call interrupts the next attack at 65%
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
| King's Leap (`kingLeap`, heavy telegraph) | leap | 1.10 / 0.70 flight (arc 16) / 1.00 (the skid) | 12-42 | r 14 on where the target stood, telegraph runs to touchdown | 86 (26%) | 3.2 s |
| King's Rake (`kingRake`, `arrive`) | cone | 0.50 / - / 0.90 | 18 on landing | r 16, 120 deg | 40 (12%) | - |
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
`windup`, `strike`, `dash`, `land`, `skid`, `hit`, `stagger`, `death` cues plus `ready`
and `aggro` (the aura). Every windup's `seconds` covers only the windup. Body hooks:
`Mouth` (Skull), `Core` (Chest), `PawFL_FX`/`PawFR_FX`/`PawBL_FX`/`PawBR_FX` (the
paws), `EyeL`/`EyeR`, `Neck`. No new remotes.

The King's effect set, `Effects.ElderWolfKing` (30 templates, 86 emitters, 21 mesh
waves; builder `tools/vfx_specs/ElderWolfKing.luau`, installs
`_G.buildElderWolfKingFX`), was rebuilt on 2026-10-22 with the intent-first method
(`.claude/agents/vfx.md`). Each move has an intent, a ms beat sheet and a layer sheet
(cause, role, library asset and why) in the builder's header, one hero per beat, and
layers staggered behind their cause. The old set (28 templates, ~190 emitters) layered
the shared `Impact` kit on top of its own impacts, redrew the danger area with a gold
ground `Marker` and turning formation arrays, and popped most layers on one frame. All
of that was cut.

Look: moon-silver qi (white core, pale-blue rim) on ink and slate. The King's gold
shows only on the first frame of a move (eyes, raised claws). Anything that hits the
ground throws warm grey dust and debris. No crown or halo, no copy of the body, no
always-on ground circle (user, 2026-10-21).

Shapes come from library flipbooks and meshes found by searching for what each move
causes (air, dust, debris, light):
- a dust puff opening into a ring (12360899465)
- a star burst (13580358178)
- air wisps (12094495797)
- a twinkle (102648375149008)
- a spirit flame (81332883799807)
- rising smoke (17703378809)
- swirl-ring and twisting-column meshes as 3D shocks (`MeshWave` models, played by
  `TechniqueVFX.emit`; the handler scales them with the template)

| Move | Intent | Anticipation | Peak (hero first) | Sound at the peak |
|---|---|---|---|---|
| every windup | the King's intent | `EyeGlint` on both eyes, 0-350 ms | - | voice: EnemySounds `Attack` |
| Royal Bite | draws breath, snaps its jaws on the space in front | `BiteTell`: breath pulled into the jaws, maw glow on ink, fang glints in the last 250 ms | `BiteSnap`: two dark-rimmed crescents slam shut (hero), +30 ms air ring shoved forward, +50 spray | `BiteSnap` |
| Paw Swipe | a quick foreleg sweep across the cone | `SwipeTell` on the left paw: star and gold claws, loudest on its first frame (short tell) | `SwipeSlash` 12 studs ahead: a brushed crescent sweeps across on a slate copy (hero), +20 claw rake, +50 wind, +60 grit | `SwipeSlash` |
| Claw Down | the right paw rises and is driven into the ground | `ClawRaise` from 50% of the windup | `ClawStrike` on the locked circle: three claw gouges carved, qi burning in them (hero), flash, +30 ground shock, pebbles, dust | `ClawStrike` |
| Crownfall | rears and slams both forepaws down | `CrownfallTell` on both forepaws: motes and air pulled in, glow accelerating, qi flames on the claws in the last 250 ms; a rising charge sound timed to end on contact (stops if interrupted) | `CrownfallImpact`: shockwave ring on a slate ring (hero), flash, carved crater with a lit crack cooling (fades over 6 s), Craters rocks, +30 pebbles, +60 dust wall, +250 settling smoke | `CrownfallImpact`, +150 `CrownfallRumble` |
| King's Rush | coils on its hind legs and bursts through the air | `Coil` on the hind paws: dust and grit kicked back from 30% | take-off `Launch` (dust burst behind, flat shock); dash `RushTrail` (air rings peel off the muzzle, speed lines, ink and moon ribbons, wake dust); stop: `Skid` from the forepaws | `Launch`; `Skid` |
| King's Leap | crouch, launch, the whole body lands | `Coil` on all four paws | take-off `Launch` at 1.3x; landing `LeapImpact`: a dust cloud bursting round the body (hero), shock ring on slate, flash, Craters rocks, pebbles. No crack (cracks are the paw slam's) | `Launch`; `LeapLand` |
| King's Rake | both forepaws rake the arrival cone | `SwipeTell` on both forepaws | two `SwipeSlash` 13 studs ahead, left then mirrored right +80 ms | `Rake` |
| Skids (`kingsRushSkid`, `kingLeapSkid`) | paws plough as the body swings round | - | `Skid` at all four paws | `Skid` |
| Engage roar | a blast of air and sound from the mouth | `RoarTell`: breath pulled in hard, maw glow | `RoarBlast`: three sound rings travel out of the mouth +0/+80/+160 on a slate ring (hero), +40 air swirl, +50 wind lines; `RoarGround` dust shoved ahead +120; the aura flares | `RoarBlast` |
| Pack Call (65%, 30%) | howls to the sky to call its spirit wolves | `HowlTell` (breath in, maw glow) and `HowlGather` (spirit motes rising in a ring round the King) | `HowlBlast`: the rings rise on an axis tilted 55 degrees up (hero); `ManeFlare` on the neck; `HowlGround` air shock over the stun radius with a dust skirt (dimmer, secondary); aura flared 3 s; the second call boosts counts | `HowlBlast` (a wolf howl) |
| Confirmed hits | the blow landing on a player | - | `HitClaw` (swipe, rake), `HitBite`, `HitHeavy` (the rest) | `HitClaw`/`HitBite`/`HitHeavy` |
| Stagger | qi knocked out of the chest | - | `Stagger` on the chest | `Hurt` (EnemySounds) |
| Death | qi leaks from the body, then the spirit breaks free | `DeathLeak` on the body, 0-850 ms | `DeathRelease` at 850 ms: a twisting column rises (hero), spirit flames, flash, ground shock, dust, motes rising ~3 s | `DeathRelease`, +300 `DeathRumble`; voice: EnemySounds `Death` |
| Aura (always on) | the King's qi | - | `AuraMane` (spirit flames, motes, embers below 70%), `AuraBreath` mist; health scales the rates and shifts the flames toward gold | - |

Layers per peak: Bite 7, Swipe 7, Claw Down 7, Crownfall 10 (+ Craters), Rush take-off
3 / dash 5, Leap landing 7 (+ Craters), Roar 9, Pack Call 8, hits 3, death 7.

Sounds: 18 under `SFX.Enemies.ElderWolfKing`: BiteSnap, SwipeSlash, ClawStrike,
CrownfallCharge, CrownfallImpact, CrownfallRumble, Launch, LeapLand, Skid, Rake,
RoarBlast, HowlBlast, HitClaw, HitBite, HitHeavy, Hurt, DeathRelease, DeathRumble.
They are library sounds: they load in Studio, but in-game permission is untested.

Shakes ride the templates' ScreenEffects attributes when the Game Module is present
(`TechniqueVFX.full`) and fall back to `CombatEffects.shake` otherwise. `Craters`
needs the Game Module too; the King's model is tagged `CraterIgnore` when its aura
starts. Held templates carry `AuthoredSeconds` and ground ones `AuthoredRadius`; the
handler refits them to the live windup and the locked circle. The telegraph is
unchanged and keeps the danger colour; no effect redraws the area.

Windup tasks cancel when the state or attack changes; rush release/dash cues dedupe,
and the trail stops on landing, interruption, death or its duration limit. Confirmed
hit flashes allow the same attack's immediate windup-to-contact state transition,
because its remote may arrive before the replicated phase update. Ground effects
stay at the locked point; body effects follow their attachment's part.

Known gaps (effects):
- Crownfall's circle sits under the King's chest (offset -3.5), so the body hides
  much of the impact from the side.
- The Craters rocks didn't show in Edit-mode previews; untested in play.
- Feel (shake strength, timing at play speed) and phone cost are untested.

#### Animation QA (2026-10-22)

A motion probe over the real state timeline (`art/enemies/motion_probe.luau`, 30 Hz, plus
per-frame joint steps at 60 Hz) found the King's worst problems in the legs, not the poses:
- **Leg flips.** The shared one-joint leg solve picked between its two bends by a threshold,
  so a lower leg flipped 60-160 degrees in one frame at every footfall of the walk and gallop,
  every paw lift and plant in the attacks, the skids' steps and the death roll (keyed moves
  aren't smoothed, so these showed raw). The King now opts into `Quadruped`'s `steady` solver
  (`steady = true` in its spec; no other family changes): gait swings always take the natural
  fold, a foot being put down or picked up travels on a low arc from its authored spot to its
  plant (solved in full, levelled as it lands) instead of blending joint angles through the
  floor, a planted foot is only levelled after its solve, and the floor clamp lifts a dipping
  foot only as far as it dips. Worst one-frame steps: walk 60 -> 18, gallop 140 -> 60,
  attacks 85-160 -> under 55 (the rest are real fast lifts and the take-offs), death 118 -> 16.
- **A dead frame at every release.** The 0.06 s keyed blend restarted from the frozen contact
  frame. `seamlessStrike` on the King's family plays a stationary strike's windup straight
  into its recover (the dash phases keep the blend).
- **The rush's pawing never moved** (an overlay on planted shoulders that the plant solve
  undid): each forepaw now lifts, digs in ahead and drags back, left then right.

Per move (intent, then what changed; timings and cue moments are unchanged):
- **Paw Swipe:** the chest rears up off the striking paw, then drives down and forward
  through the sweep; the head looks with the cocked paw and leads the sweep across.
- **Claw Down:** the mass rises over the hind legs as the paw goes up, then the forebody
  drives down onto the claw (the body used to stay still while only the arm moved).
- **Royal Bite:** the held rear keeps loading (higher, wider jaw, onto the haunches) instead
  of a dead hold, then drops.
- **Crownfall:** it reaches the top earlier, hangs there still rising, and drops in 80 ms
  (was 130 ms): the paws and jaw hit at 130-150 studs/s, up from 90.
- **Pack Call and the engage roar:** the windup draws breath (chest and head rising, jaw part
  open) and the jaw opens wide at the release, where the howl and its effects go out; the
  forepaws come down as the air goes out. They used to hold the jaw wide early and, for Pack
  Call, close it at the release.
- **Skids:** the inside forepaw's step reaches round with the bend it plants with.

Known gaps (animation): the rush's arrival into the rake or skid still blends from the frozen
gallop frame (one dead frame, a claw about 0.6 studs into the floor for two frames); the
gallop still steps a joint up to 60 degrees a frame at lift-off (smoothed by the loop
blend); the bent hind paw's merge into the thigh and the raised forearm into the manes are
rig geometry, as before. Feel in Play, the hand-off from EnemyAnimator's blends at real
frame rates and phone cost are untested.

### Nine-Tailed Fox (testbed trial)
`Config.Wilds.NEW_NINE_TAIL_FOX = TESTBED` gates the def. FE1 boss, 2600 HP, weight 7,
walk 8 / run 22, `body = "NineTailFoxB"` (2.13x, nine extending fox tails: gold stem, cream brush, foxfire lance and flame; `RIGS.md`
"NineTailFoxB": reach 8.9 studs at rest, 21.6 extended, so every tail lane is 18-20
studs, shortened from the 30 first designed). Spawn it from the admin panel's "Spawn beasts" list (no testbed zone). Sheets for the build agents: the fox contracts (kept in the
session scratchpad, folded in here).

Fight: a fresh engagement opens with `intro` (2.2 s, no damage). Then a **random pick**
(`def.spacing`, `EnemyService.foxAttack`) among the pool attacks that fit phase, range
band and cooldown (cooldowns x1 / 0.85 / 0.7 by phase), never the same twice in a row
and never a crowd-control attack within `windup + recover + 2` s of the last one. The
fox circles at 24 studs (`pack.circle`, waiting on the volley) and closes in when the
volley is cooling. **Moon Leap** is not in the draw: after 2 melee attacks in a row, 2.5 s
within 14 studs, or 12% of max health lost in 3 s, it backflips 34 studs away (leaving a
fire trail) and follows with a Foxfire Volley. Phases at 66% and 33% (`veilBreak`,
reusing the Thunder Ape's `phaseCall` / `phaseStep` and `Phase` attribute).

| Attack (`name`) | Kind | Windup / active / recover | Area (from the fox's root) | Damage (FE1 500 HP) | Notes |
|---|---|---|---|---|---|
| `intro` | howl | 2.2 / - / 0.8 | ring | 0 | opener |
| `fangDance` | barrage `fangs` | 0.65 / 0.12 / 1.2 | 3 cones r 20, 80 deg, at +0, +0.4, +0.8 s | 28 each | melee, range 18 |
| `tailSweep` | cone | 0.9 / 0.25 / 1.1 | r 18, 200 deg | 55 | range 16 |
| `tailLance` | barrage `lance` | 0.6 / 0.1 / 0.8 | box 20 x 4 | 60 | 5-24 |
| `lanceFan` | barrage `lanceFan` | 0.95 / 0.1 / 1.1 (P3 1.8) | 20 x 4 boxes: P1 3 at +-22, P2 5 at +-40, P3 5 then back; 0.18 s apart | 45 each | 5-24 |
| `tailSnare` | barrage `snare` | 0.85 / 0.1 / 0.9 | box 20 x 4 | 40 | pulls the hit player to 11 studs in 0.45 s (a 0.45 s stagger), then `fangDance` follows (only on a hit) |
| `rendingPounce` | lunge | 0.75 / dash / 1.0 | box 8 x 30 at 55/s | 75 | 18-36 |
| `foxfireVolley` | barrage `volley` | 1.1 / 0.1 / 1.0 (P3 1.8) | 5 lanes 56 x 4 at 20 deg steps; P3 7 lanes at 15 deg in two waves 0.7 s apart | 40 each | 20-70; **converted to real projectiles** (below) |
| `rootfireEruption` (P2) | barrage `ringHeart` | 1.5 / 0.1 / 1.6 | 4 circles r 5 on a ring of 11 round the target, then r 7 under it at +0.8 s | 55 each | heart staggers 0.6 s |
| `moonLeap` | retreat | 0.4 / 0.6 flight / 0.4 | landing ring + trail box 34 x 6 ticking at +0.5, 1.0, 1.5 s | 12 per tick | then Foxfire Volley |
| `mournfulScream` (P2) | howl + stun | 1.4 / 0.3 / 1.6 | circle r 30 | 0 | stun 1.2 s, cooldown 14 s |
| `nineTailFall` (P3) | barrage `spiral` | 1.8 / 0.1 / 2.0 | 9 circles r 7 spiralling out from the target, 0.2 s apart, then r 20 under the fox at +1.9 s | 55 each, 110 final | the final circle staggers 0.6 s |
| `veilBreak` | howl + stagger | 1.6 / 0.2 / 1.0 | circle r 16 | 0 | phase step, stagger 0.6 s |

New server mechanics (all in `EnemyService`, defs in `Enemies.luau`):
- **`barrage`**: parts (box / circle / cone plus `delay`, `ext`, `tail`) computed at the windup's
  start from where the target stands (locked, fair), sent as Telegraph shape
  `{ kind = "multi", pattern, parts }`; `Telegraphs` draws each part filling until the windup
  plus its delay, and any shape with `parts` (the retreat's trail too, `hidden` ones skipped).
  Parts hit `delay` s after release for whoever stands in them; the beast's next attack or a
  stagger calls the rest off (`strikeId`). Part flags: `stun` (the attack's `hitStun`),
  `snare` (the attack's `pull`), `damageScale`.
- **`retreat`**: damage-free flip away (`distance`, `active`, `arc`) plus the fire-trail parts.
- **`spacing`** (`def.spacing`): the random pick and retreat triggers above.
- Windup cues carry the telegraph's `attack` name (the Thunder Ape's change), and a snared
  player gets `enemyCue "snare"` with their Character.
- Cut for now (later add-ons): snapBite, tailWhirl, crossLash, wispRain, phantomStep (blink),
  mirrorVeil (illusion clones).
Sounds: `SFX.Enemies.NineTailFox`. The voices (Aggro, Attack, Death, Hurt and most
`Attack_<name>`, played by `EnemySounds` at the windup's start) still reuse the wolf, swing,
fire-seal and thunder clips. Four windup voices were swapped in the effects pass (2026-10-22)
because their old clip was the release's cry, heard 1.4-2.2 s early: `Attack_intro` a rising
fire charge (3748209484), `Attack_mournfulScream` an inhale (5297498542), `Attack_veilBreak` a
magic charge (5696557721), `Attack_nineTailFall` a soul-beam charge (74686546597444), each pitched
to end on its release. The effect sounds are played by `EnemyFX/NineTailFox` on their beat (table
below).
Untested: everything (feel, lane reach against the animated tails, the pull on a client-owned
character, the volley's lane gaps, boss HP, phone load of nine tails).
**Foxfire volley = projectiles** (testbed): the windup keeps the barrage's lane warnings (the lanes the
bolts fly down; no second warning is drawn). At each lane's `delay` after release (P1-2 `(i-1) x
0.04 + (i odd 0.05)` s, i.e. a quick left-to-right fan over about 0.2 s; P3 odd lanes first, even lanes
0.7 s later) the server calls `Projectiles.fire` with `cue = "foxfireBolt"`, origin 6 studs ahead of
the fox's root along the lane at 3.5 studs above the ground (player torso height; the tail tips are
not readable on the server, so clients draw the start from the tail), velocity lane direction x 70
studs/s, radius 1.5, range 50, lifetime 1.6, no pierce, stopped by the map. `onHit` goes through
`hurtPart` (40 damage, dodges and flinch apply); `data = { tail = 1..9, phase = 1..3 }`. A stagger of
the fox or its next attack calls unfired bolts off (strikeId); bolts already in flight keep flying.
Poses: `EnemyPoses/NineTailFox.luau` (notes in `RIGS.md` "Animating NineTailFoxB"), registered in
`EnemyAnimator` as `NineTailFoxB` (`scale = 2.13`, `runFrom = 8.5`, death 3.2 s). The animator calls
`NineTailFox.configure(template)` once (it reads each tail's ExtendAxis / ExtendMax / pivots and the
`TailTip<i>_FX` lance end, so a rebuilt tail needs no code change), passes `stage` (the `Phase`
attribute), `side` and `duration`, and scales with the module's `scaled` (which also scales the tail
slides). The barrage parts are not sent to clients, so the poses time their tails from the module's
`DEFAULT_PARTS`; if a timing ever differs, send them (a `Parts` attribute). `retreat` attacks (Moon
Leap) take their flight length from `active` like leaps and bounds, and the server's 8-stud `DashArc`
lifts the root so the flipping tails clear the floor.
Effects: `Effects.NineTailFox` (37 templates, 110 authored emitters, 20 mesh waves, Ribbon/Bolt
trails and Thread/Whip beams; builder `tools/vfx_specs/NineTailFox.luau`, installs
`_G.buildNineTailFoxFX`), played by `EnemyFX/NineTailFox.luau` (gated to `NineTailFoxB`; found by
`EnemyType`, no registry). **Rebuilt 2026-10-22 with the intent-first method**
(`.claude/agents/vfx.md`): the first pass was technically fine but random (layers added because
they looked cool, everything on one frame, ground sigils and lane lines redrawing the telegraph,
the shared Impact kit stacked on every eruption). Now every layer is caused by the move, starts
staggered 20-150 ms behind its cause (EmitDelay in the templates), each beat has one hero on a
slate twin of its own shape, and each impact is its own stack. The spec header holds the ms beat
sheet for every cue; the assets were searched fresh in the library from what each move causes
(air, dust, debris, light, fire), 36 ids of which 20 are new to the game (9 flipbooks, 8 meshes).
Look: foxfire azure with a white-hot core (P1), violet (P2), white-hot with a crimson edge (P3),
re-tinted per cue from the model's `Phase` (Neon mesh waves take the edge colour); lances and tail
strikes white-gold, the scream pale. **No copies of the fox's body** (user, 2026-10-21), no stock
howl disc, no ground sigils (telegraphs.md: the telegraph alone says where).
Cut in this pass, and why: the intro's ground `Sigil` and `Kindle` (nothing in the ground lit), the
lit `Lane` line along lance boxes and the `FallSigil` on each Nine-Tail Fall circle (the telegraph's
job), the moon printed on the leap's landing (a landing is weight: dust and a shock), the phase
break's second peak over the fox and its forward roar, the forward roar on the scream (a scream
radiates), the TailIgnite flares on the sweep's strike (same frame as the ribbons), the shared
`Impact` kit calls (they doubled every impact), and shakes on the small beats (bites, lance hits,
bolt bursts).

| Cue | Intent (what happens / feel / job) | Hero | Other layers (start) | Sound (beat) |
|---|---|---|---|---|
| `intro` | nine flames catch one by one, breath drawn in, then a howl blasts air and sound out of the jaws / dread / arrival | `RoarBreath`: a spiked air front (mesh `blastBowl`) opening forward from the Mouth | `TailIgnite` x9 (250-2000 ms), `RoarTell` inhale (last 600), release: flash +0, sound rings on slate +50/+140, speed lines +30, breath mist +80, `RoarWave` dust off the ground under the head +80; shake | `Ignite` per tail (rising pitch), `Roar` + `AirBlast` at release |
| `fangDance` | three snapping bites of foxfire jaws / threat / melee hit confirm | `FangSnap` reach crescent flying ~12 studs down the cone, on its slate twin | `Breath` licks in the jaws (windup), jaws closing +0, flash +0, embers +50 | `Snap` per bite |
| `tailSweep` | three burning tails swing through 200 deg / weight / wide melee | white-gold ribbons riding the live tips 2/5/8 | `TipCharge` + `TailGlow` (windup), `Dust` at the arc's ends +140/+280; light shake | `Sweep` at the strike |
| `tailLance` / `lanceFan` | a tail spears down a lane into the earth / precision / lane hit | the lance beam (`Thread`) leaving the live tip, led by a ribbon head | `TipCharge`, `TailIgnite` at launch; `LanceHit` at the hit: star +0, earth splash on slate +20, chips +30, scar +50, dust +60 | `LanceOut` at launch, `LanceHit` at the hit |
| `tailSnare` / `snare` | a tail lashes out like a whip, then coils and yanks / danger / pull | the wavy `Whip` beam, then the coil ribbon round the torso | `TipCharge`, tether `Whip` shrinking, small flash on arrival | `SnareLash` at the lash, `SnarePull` on the pull |
| `rendingPounce` | the fox crouches, springs and rakes through / speed / dash hit | the white-gold dash ribbon on the chest | `Dust` at the hind paws at 40% of the windup, take-off dust, skid dust +0/+100 on landing | `Dash` at take-off, `Skid` on landing |
| `foxfireVolley` | tails flare and throw balls of foxfire / dodge / projectiles | `Bolt`: a turning striped orb on a slate halo (white core, flame tongues, comet trail, ground shadow) | `TipCharge` outside in; `Burst` on landing: flash and burst on slate +0, shock ring +30, tongues +40, scar +60, smoke +120 | `BoltLaunch` per bolt, `BoltBurst` per landing (gap-limited) |
| `rootfireEruption` | five tails drive into the earth, fire runs underground and erupts / dread / area denial | `Eruption`: flame spikes rising out of the ground (mesh `spikes`) on a slate twin | `TailGlow` to 60%, `PlungeImpact` at the tips (star, splash crown on slate, chips, scar held while buried, dust), fissure ribbons to the circles, `StuckGlow`; the heart adds `Burst` + shake | `Plunge` + `Rumble` at the plunge, `Eruption` per circle, `HeartBurst` at the heart |
| `moonLeap` | a backflip away, burning tails scorching a trail, a heavy landing / evasion / zone | the moon-crescent streak on the chest in flight | `Dust` at the hind paws, `FireStrip` along the trail (flares on each tick), `Landing`: flash, shock ring, dust ring, kick, tongues | `LeapOff`, `TrailIgnite` at take-off, `Land` |
| `mournfulScream` | breath drawn in, then a scream radiating all round / dread / stun | `ScreamWave`: torn sound rings racing out at head height to the shape radius, on a slate twin | `ScreamTell` inhale, `TailFlare` on lit tails (windup); speed lines +20, spiky ground shock +40, dust +100, second ring +120; `StunSting` stars on the local stunned player | `Attack_mournfulScream` inhale at the windup, `Scream` + `ScreamShock` at release |
| `nineTailFall` | each tail rises and swells, then all nine slam down in a spiral and the last one under the fox / climax / P3 ultimate | `FallBurst`: a 40-stud burst and shock ring on slate twins | `TailRise` per tail, per circle `PlungeImpact` then `Eruption` +70; final flame spikes +30, chips +40, column +50, scar +60, dust ring +80, smoke +200; heavy shake | `FallPlunge` per plunge, `FallSlam` + `FallBlast` at the final |
| `veilBreak` | foxfire drawn into the chest tears the fox's veil off / power shift / phase step | `PhaseBurst`: a swirled veil shell bursting off the chest (in the old phase's colour) on a slate twin | `Gather` (wisps in, core on slate, orb forming in the last 500), release on the frame: streaks +20, `PhaseRing` shock +60 and dust +90; follow-through: veil shreds spiral up and fade, the new phase's tails re-ignite 80 ms apart; shake | `Attack_veilBreak` charge at the windup, `VeilBurst` at release |
| `hit` | the blow lands on the player / hit confirm | `Hit` flame burst, or `HitHeavy` rend crescent on slate | contact star +0, embers +30 | `HitStab` (lances), `HitHeavy` (sweep, pounce), `HitFire` (foxfire) |
| `stagger` | the fox's qi is knocked loose / punish window | `SpiritGlint` on the Core | embers +30 | `Hurt` (EnemySounds) |
| `death` | the flames gutter tail by tail into streams that meet over the fox as the body burns away / release / reward | `SoulRelease` (spirit swirl bloom) where the streams meet at 2.7 s | gutter puffs 0.2 s apart, `Dissolve` (flames, ash, motes) over the body, glint, ring, twinkles drifting down | `DeathGutter` at the death, `SoulRelease` at the peak |

Sound ids (library names; `PlaybackSpeed` in `SFX.rbxmx`): Ignite 1538607239 "Fire (62)", Roar
5727297364 "DragonRoar", AirBlast 411274847 "Air Blast", Snap 4958427918 "SlashTempo", Sweep
3809084884 "WindWoosh", LanceOut 118783238636456 "Stab Wind", LanceHit 79436646901611 "Ground
Impact", SnareLash 75422951 "FireSlash", SnarePull 116338527674024 "Magic Wind Cut", Dash 3929467229
"Dash", Skid 231917806 "Stomp", BoltLaunch 96144156475300 "Magic Bullet Fire", BoltBurst and HitFire
3763467590 "FireHit", Plunge 71472197762839 "Earth Slam", Rumble 9114221327 "Earthquake Debris",
Eruption 6952411082 "Fire Pillar", HeartBurst 331888892 "FireExplosion", LeapOff 3809085250
"WindWoosh (2)", TrailIgnite 8597296318 "Fire (66)", Land 74149238738530 "Ground Impact (2)", Scream
3041462242 "Scream", ScreamShock 107099176643351 "Shockwave Impact", FallPlunge 120935595628430
"Ground Impact (3)", FallSlam 100457174196725 "Heavy Ground Slam", FallBlast 122258480286280 "big
magic explosion", VeilBurst 9116385087 "Magic Burst 5", HitStab 107563238507399 "Lance Stab",
HitHeavy 6947964914 "Hit (16)", DeathGutter 9116407532 "Magic Rumbling Decay 1", SoulRelease
131722051883127 "Magic crystal sparkle 2". All load in Studio; picked by name and length, not
listened to, and other creators' uploads may be silent in-game.
Aura (unchanged): low flipbook tongues on each tail tip (lit tails burn brighter: 3 / 6 / 9 by
phase), ground mist and rising twinkles round the paws; `Tell` parts dim then brighten through each
windup and are recoloured per phase. All sizes, lengths and centres come from the cue's shape; cues
past 220 studs are skipped.
Checked: every cue fired against the real body in a sandbox (no errors, hooks present, spawns
counted; `tools/enemy_fx_smoke.luau` with server-like barrage shapes), frozen captures of the intro
howl, a bite, the lance hit, the eruption ring, the scream, the final fall, the veil break, the
death peak and a bolt in flight and bursting (static pose, so the tails do not move).
Untested: the look and feel at play speed with the animated tails (the user reviews; beams and
trails cannot be frozen in Edit mode, so the lance, whip and ribbons were only checked as
templates), every sound in-game (permissions, loudness, fit), the Game Module playback of the
templates, phone load of `nineTailFall` (nine eruptions and the final, about 55 emitters live for
2 s) and the death.

#### Animation QA (2026-10-22)
A motion probe over the real state timeline (`art/enemies/motion_probe.luau`, every move at 30 and
60 Hz, `lows`, plus the new `steps` list of big one-frame joint steps) ranked the Fox's problems:
1. **Plunging tails teleported.** Rootfire Eruption's tails 1 and 9 and Nine-Tail Fall's tails 1-3
   jumped 10-20 studs in one frame (505-562 studs/s, the base joint 160-177 deg) while planted and
   when handing back to their keys. The plunge solve (`groundQ`) tested only the ends of its pitch
   range, so it flipped to "unreachable" as the body dropped, and it was re-solved each frame at a
   blended height and azimuth that spins when the keyed tail stands over its root. Now the solve
   takes the first crossing after the end height's peak on a chosen side (`ground` returns a
   `branch`: Rootfire over the head, Nine-Tail Fall over the back) and the tail blends its own
   params from the keys to that landing. Each plunge eases in and lands on its time (Rootfire at
   `plungeAt`, the vfx's PlungeImpact; each Fall slam on its circle's hit time), instead of
   settling onto the floor on a double smoothstep. Tips now peak 170-390 studs/s.
2. **A dead frame at every stationary release** (the keyed blend restarting from the frozen
   contact frame): the family takes EnemyAnimator's `seamlessStrike`; the pounce and Moon Leap keep
   their dash blends (full `seamless` stepped the leap's forelegs 72-80 deg at take-off and
   landing). Fang Dance and Foxfire Volley lost a 20 ms hold before contact that stopped the body
   and tails dead for a frame.
3. **The body did not carry the tail attacks** (the stiffness): Tail Lance's load and strike were
   nearly the same pose (chest 7 studs/s). It now rocks back onto its haunches as the tail coils,
   creeps deeper into the hold, drives forward off the hind legs as the lance leaves (ease in,
   fastest at contact), overshoots and rebounds (chest 27, mouth 99 -> 162 studs/s, root travel
   0.7 -> 1.2). Lance Fan does the same and each lance kicks the body back and turns the shoulders
   toward its lane (mouth 85 -> 193). Idle tails sway wider (tips 1-2 studs/s read as frozen).
4. **Leg flips**: the intro's forearms flipped 150-160 deg in a frame rising from the curl (the
   floor clamp's two bends). The forepaws now stay planted and slide back under the chest
   (`gather`) into a real sit (chest up, pitch 0.38); the intro windup and the death skip the
   floor clamp (`air`), which on its side toggled every frame (lower legs 100-122 deg a frame).
5. Moon Leap's tail flame went 1.9 studs into the floor mid-flip: the tails tuck forward over the
   back (lift -0.75) for the inversion.
Not taken: `Quadruped.steady` (the King's solver) made the intro and the pounce worse here and the
poses are tuned against the old blend. Left: the intro still starts with a 0.06 s blend from
standing into the curl (the fox idles standing before the engagement; a curled idle before aggro
would fix it, a design call); the pounce's bound steps the forelegs 60-78 deg a frame at 55
studs/s (the run gait at that speed); the death's collapse steps one shoulder 105 deg and sinks a
paw 1.3 studs for 0.2 s; Fang Dance's bites end in a one-frame stop before each recoil; plunging
tails now pass through the hind thighs (0.7-1.2 studs) where they used to pass through the chest
(1.4-1.7), since a straight tail from the hub to the floor must cross the flank. Timings, cue
moments and the pose API are unchanged. Untested in Play.

### Thunder Ape (testbed trial)
A 30-stud storm boss for Foundation 1 (`Config.Wilds.NEW_THUNDER_APE = TESTBED`; flip it to ship).
Body `ThunderApeB` (3.71x the roster ape; root box 14.8 x 14.8 x 16.3, so every reach below is measured from
its centre and starts past ~15 studs). No testbed zone: spawn it from the admin panel ("Spawn beasts"), which puts it just in front of the player, clear of its body.
3000 HP, FE1, weight 9 (a FE1 fist cannot shove it), walk 8, run 22 (the player walks 16; each phase x1.09),
aggro 90, leash 240, `resetOnEvade`. A fresh engagement opens with `challenge` (2.4 s entrance, no damage,
`pack.howl`). `def.rotate` picks the next pattern attack whose phase, range band and cooldown fit
(`rotateAttack`), so a boulder is skipped at melee; `chainOnly` attacks (`backhand`, `thunderPound`,
`challenge`) only start as a `followUp`, which now also searches `def.pattern`. Phases: `summonAt`
{0.66, 0.33} (the boss bar's ticks) call `def.phaseCall` (`phaseRoar`, `phaseStep`), which on resolving raises
the `Phase` model attribute (1-3), fires `enemyCue "phase"` and applies `phaseSpeed`.

| Attack | Kind | Windup / active / recover | Area (from centre) | Damage (500 HP player) | Phase |
|---|---|---|---|---|---|
| `clubSwing` -> `backhand` -> `thunderPound` | cone r30 110 deg / cone r30 120 deg / slam r15 at 18 ahead | .80/-/.45, .60/-/.45, .85/-/1.30 | | 50, 50, 110 | 1 |
| `poundWave` (cue only) | ring from the pound, r34, 0.45 s later, spares the slam's own circle | | | 55 | 2+ |
| `bodySlam` | lunge box 20 x 34 at 55/s | 1.10 / ~.62 / 1.10 | | 140 | 1 |
| `skyfallSlam` | leap r20 on the target, arc 26, range 22-55; `arrive` `skyfallSweep`, else `skyfallSlamSkid` | 1.20 / .75 / 1.10 | | 150 | 1 |
| `skyfallSweep` | cone r32 140 deg backhand on landing (target within 34, in front) | .50 / - / 1.00 | | 55 | 1 |
| `thunderRush` | charge box 14 x 24-64 at 95/s, pulls up 12 short of where the target stood; `arrive` `rushSwipe`, else `thunderRushSkid` | 1.20 / ~.5 / .90 | | 110 | 1 |
| `rushSwipe` | cone r30 110 deg at the end of the rush (target within 32, in front) | .40 / - / .90 | | 60 | 1 |
| `bound` | hop, no telegraph (an empty `bound` shape so the windup cue fires); landing mode `BoundMode` (never twice running; `BoundSide` +1/-1 says which way it travels across the body, so the windup leans into it): `over` past the target 22-28 (target within 50; flight .80, arc 24, turns in the air to face back), `flank` left or right 22-28 (.60, arc 11), `back` a retreat hop 14-20 farther away (target within 40; .55, arc 9), `short` a small hop round the target at the same distance (.42, arc 5) | .45 / per mode / .35 | | 0 | 1 |
| `boulderHurl` | spit r10 on the target, range 45-85 (flight always readable) | 1.7 / - / .90 (rip 0-.6, lift .6-1.0, rear back 1.0-1.25, release 1.25, flight to 1.7) | | 70 | 1 |
| `thunderLance` | `lance` box 8 x 90 | 1.4 / - / .90 | | 120 | 2+ |
| `thunderRoar` | howl, stun circle r42, stagger 0.9 s | 1.3 / - / 1.0 | | 0 | 2+ |
| `stormCall` | `storm`: 5 bolts (7 in P3), 0.45 s apart on where the target stands, r8, 0.9 s warning each (`stormBolt` telegraphs) | 1.2 / - / ~3.0 | | 70 each | 2+ |
| `judgment` | leap r28, arc 48, range 25-70, stuns 1.0 s only players its damage hit (`stun.onHit`) | 1.6 / 1.0 / 1.8 | | 190 | 3 |
| `phaseRoar` | howl, stun circle r34, stagger 0.8 s | 1.6 / - / 1.2 | | 0 | 66% / 33% |

Server additions: attack kinds `lance`, `bound`, `storm`; fields `stun.onHit`, `phase`, `chainOnly`, `phaseStep`,
`landMin/Max`, `bolts/boltsP3/boltWindup/boltInterval/boltRadius`, `wave`; def fields `rotate`, `phaseCall`,
`phaseSpeed`, `closeIn`. A leap's landing now hits with the leap's own attack (`landAttack`; `enemy.attack` has
already moved to the next pattern entry). `EnemyFX` windup cues now carry the telegraph's attack name, so
`stormBolt` and `poundWave` arrive as `cue.attack` (other windups are unchanged). Sounds
`SFX.Enemies.ThunderApe` voices (`Aggro`, `Attack_*`, `Death`, `Hurt`) reuse the King, boar and Thunder samples at low pitch (placeholders, not listened to); the effect sounds are listed under Effects below.
Poses: `EnemyPoses/ThunderApe.luau`, family `ThunderApeB` in `EnemyAnimator` (scale 3.71 applied once; the
module's loops divide speeds by its own `SCALE`). A storm call publishes its real recover as the `RecoverFor`
attribute for the pose's long channel; `bound` is treated like a leap (flight time from `active`, no active beat in recover).
Untested: all of it (feel, numbers, wall/ground checks for the flank bound, the wave's readability).

Animation QA (2026-10-22, animator; a motion probe, `art/enemies/motion_probe.luau`, plays each move
the way EnemyAnimator does and measures per frame). Found and fixed, worst first:
- The swinging fist went 6.8 studs into the ground in the club's and backhand's recovers (a free arm
  blended toward a planted one), and every rear-up from all fours sank the thighs 2.5-3.2 studs
  (the pound, the body slam, the roars, the stagger). Fixed in the pose module's plant blend.
- Every strike and leap stopped dead for a frame at its release (the 0.06 s keyed blend restarted
  from the frozen last windup frame). The family now has `seamless` (as the Jade Jiao): one
  attack's windup, dash and recover play straight on.
- Club and backhand stopped after the hit and restarted for the recover. The blow now carries
  through: one decelerating sweep past the target across the active beat, the forearm folding,
  the fist swinging back and reaching down to plant while the other arm lifts for the next blow.
- The body slam's hind feet hung 1.3-2.2 studs under the floor through the fall and the prone
  slide (now folded, drawn in under the hips as it pushes up); the death's kneel put the shins 3.4
  under (1.9 now); a back hop's landing flipped an elbow 85 degrees (the fists land with the feet).
Attack names, phase lengths, cue moments and the pose API are unchanged. Left: ClubSwing B (not the
default) still sinks its fist in its recover; the combo hand-offs (recover -> next windup) still
freeze the lifting arm for 0.06 s; the prone body and the pound's forearms brush 1.3-1.8 studs into
the floor; the rush's arrival (dash -> swipe windup) holds one frame. Untested in Play.

Effects (vfx agent): `Effects.ThunderApe` (49 templates, 127 emitters, 22 mesh waves; builder
`tools/vfx_specs/ThunderApe.luau`, installs `_G.buildThunderApeFX`), handler `EnemyFX/ThunderApe.luau` (gated to
`ThunderApeB`), sounds `SFX.Enemies.ThunderApe.<Name>` (30 effect sounds, played with `Sfx.play` at each peak from
where its cause is). Rebuilt on 2026-10-22 with the intent-first method (`.claude/agents/vfx.md`; user: the effects
were technically fine but random). Each move has an intent, a ms beat sheet and a layer sheet (cause, role, library
asset and why) in the builder's header; one hero per beat, layers staggered 20-160 ms behind their cause. Cut from
the old set (58 templates): the `SkySigil` ground circles under the leaps (they redrew the telegraph), the lit crack
spreading under the roars (a roar is air and sound, it hits nothing; user's own example), the always-on
`AuraGround` formation, `AuraSigil`/`AuraMotes`/`AuraBack`, the body trail, and the shared `Impact` kit layered over
the ape's own impacts (its generic rings and scars doubled them). Storm blue-white (white-hot core, rim `B8F0FF`,
falloff `5BD8FF`) over an indigo `1B2547` or slate copy; violet only in phase 3 (runtime tint); dust and rock are lit
earth tones. No crowns or halos, no copy of the body, no flat discs. Everything is authored at the 30-stud body and
rescaled to each cue's `shape` (mesh waves too); held effects are refit to the cue's `seconds`.

Assets were found by searching the library for what each move causes (lightning, air, dust, debris, light, cracks):
crackle-arc flipbook 11492870634, bold arcs 76973563852665, forked bolt 914595092, discharge 528280947, electric
burst 7216850580, zigzag sparks 12517923720, star flash 12156297119, glint 13908198788, heavy smear crescent
88807999398470, air streaks 15107683952, dust 11989899750, breaking puff 71869624437521, rock chunks
130042646554310, cloud puffs 14050526759, crater 11705672210, carved cracks 7994630128, lightning cracks 301851161,
scorch 7216852679, wobbly sound ring 90387581951997, crackling ring 7150933366, air ring 15611866526, dust ring
16505105356, electric strip 10528782340 (beams and trails); meshes: swirling funnel 71849885439764 (the roar),
notched ring 129778117978668, shard ring 1726537151, swirl ring 73349240058321, blade ring 122007796695786, heaved
earth 89195313060285, spike flare 102470267627424, twister 117701979506507. The boulder keeps its stone mesh
(17608108317).

| Move | Intent | Anticipation | Peak (hero first) | Sounds |
|---|---|---|---|---|
| big windups | the ape's intent | `EyeGlint` on both eyes, 0-350 ms | - | voice: EnemySounds `Attack_*` |
| clubSwing / backhand / rushSwipe / skyfallSweep | a charged fist swept through the cone | `KnuckleCharge` on the swinging fist (arcs, denser in the last 25%, glint at 80%) | `SwingArc` smeared crescent on slate across the cone, tilted along the fist's path (hero); +40 arcs flung off; +60 grit; `LimbTrail` rides the fist 300 ms through the follow-through (the animation now carries past the target) | `SwingWhoosh` |
| thunderPound | both fists hammer the ground, the lightning discharges into the cracks | `KnuckleCharge` on both fists | `PoundImpact` shock ring on slate (hero), flash; +30 lit cracks over a carved crater, arcs in the cracks, heaved rock; +40 chunks; +60 dust wall; +250 settling dust | `PoundSlam`, +150 `PoundDebris` |
| poundWave (P2+) | the shock rolls on through the ground | `PoundWave`: a heaved shard ring, crackle and dust travelling r15 -> r34 over 0.45 s | `PoundWaveEnd`: dust and arcs burst off the ring | `PoundWave` |
| bodySlam | the whole weight thrown down the lane | `ChestCharge` on the chest | dash: `BowWave` (air rings off the chest, streaks), `SpeedShed`; land: `BellyImpact` dust cloud bursting out (hero), shock on slate, flash, chunks, settle | `BellySlam` |
| skyfallSlam | springs high, lands fists first | `Coil` at the hind feet from 50%, `KnuckleCharge` both fists | take-off `Launch`; flight `LimbTrail`s; land `SkyfallImpact` blade shock on slate (hero), flash, crater + lit cracks, ground forks, heaved rock, chunks, dust wall | `Launch`; `SkyfallLand`, +150 `PoundDebris` |
| judgment (P3) | leaps into the storm; the sky's bolt rides it down | `JudgeCloud` gathers over the landing (violet arcs in it from 50%), `Coil`, `KnuckleCharge`, `BodyCrackle`, the sky dims | take-off: a bolt from the cloud hits the ape (`BoltHit`); land: the cloud's bolt (code beam) + `JudgmentImpact` discharge ring (hero), spike flare, blade shock, crater, cracks, forks, chunks, dust wall | `JudgmentTakeoff`, `Launch`; `JudgmentBolt`, +100 `JudgmentQuake` |
| thunderRush | drops to all fours and charges like a storm front | `Coil` at fists and feet from 40%, `KnuckleCharge` | take-off `Launch`; dash `BowWave` (hero), `SpeedShed`, fist `LimbTrail`s; stop `Skid` at both fists | `RushLaunch`; `Skid` |
| bound | a hop | - | `Launch` at take-off (0.5x) and landing (0.7x) | `Launch`; `BoundLand` |
| skids (`*Skid`) | fists and feet plough as it turns | - | `Skid` at all four | `Skid` |
| boulderHurl | tears a boulder out, charges it, throws it | `BoulderRip` (cracks, plume, chunks) 0-600; the rock rides the fist shedding grit; `BoulderCharge` arcs the last 250 ms | flight: dust trail, shadow; impact `BoulderImpact` rock shatters (hero), dust burst, flash, discharge, shock on slate, crater | `BoulderRip`; `BoulderThrow`; `BoulderImpact` |
| thunderLance (P2+) | forges a javelin of lightning and hurls it | `LanceForm`: arcs drawn into the fist, the javelin grows from 300 ms, glint at 1250 | `LanceFlash` at the throw; `LanceBolt` in flight (hero) + `ScorchSpot`s; end `LanceFlash` + `BoltStrike` | `LanceCharge` (sped up to end at the throw; stops if the windup breaks); `LanceThrow`; `LanceImpact` |
| thunderRoar / phaseRoar / challenge | chest beats, a breath, then air, sound and lightning from the mouth | `ChestBeat` on each beat (air thumped off the chest, sparks), `Inhale` + `BodyCrackle` in the last 450 ms | `RoarBlast`: a translucent swirling funnel opening out of the mouth over an indigo copy (hero), sound rings +0/+80/+160, arcs +40; `RoarGround` +120: dust shoved out to the stun radius. phaseRoar: four storm bolts land round it | `ChestBeat`, `Inhale`; `RoarBlast` + `RoarCrackle` (+ `StormRaise` on phaseRoar) |
| stormCall | arms raised, the storm answers | `StormRaise` arcs climbing off the back, `KnuckleCharge`, the sky dims | a bolt leaves the back for the sky; each bolt: `BoltGather` cloud over the point (arcs from 55%), then the bolt out of it + `BoltStrike` (flash, discharge, scorch, sparks, dust) | `StormRaise`; `BoltStrike` |
| phase change | the storm surges out of the body | - | `PhaseSurge` arcs burst (hero), discharge, flash, air ring; tells flash white; aura rebuilt | `PhaseSurge` |
| hits | the blow on the player | - | `HitStorm` / `HitHeavy` (+ `StunArcs` 1 s after judgment) | `HitStorm` / `HitHeavy` |
| stagger | qi knocked out of the chest | - | `StaggerPop`, tells flicker | EnemySounds `Hurt` |
| death | the storm leaks out, then leaps back into the sky | `DeathLeak` arcs over the body, rates ramping 0.4x -> 2.8x, code bolts lancing out faster | 3050 ms `DeathRelease`: a twister rises round a bolt to the sky (hero), flash, discharge, rising arcs; `DeathGround` shock and dust; tells go slate | `DeathCrackle`; `DeathRelease`; voice EnemySounds `Death` |
| aura | the storm on the body | - | `AuraForearm` arcs, `AuraCloud` indigo wisps on shoulders and back; P2+ `AuraArcs` on fists and shoulders and arcs jumping between them; P3 violet, white eyes | - |

Layers per peak: swing 5 (+trail), pound 11, pound wave 3 + 2, belly slam 6, skyfall landing 12, judgment landing
13 (+ the bolt), rush dash 3 + trails, boulder impact 8, lance flight 4 (+ trails), roar 7 + 2, bolt strike 6 (+ the
bolt), phase surge 4, hits 3 / 4, death release 4 + 3. Sounds: 30 under `SFX.Enemies.ThunderApe` (library sounds:
they load in Studio; in-game permission is untested). Shakes ride the templates' ScreenEffects attributes when the
Game Module is present and fall back to `CombatEffects.shake`.

Checked in the sandbox (Edit mode, fake cues on the real body, noon, two review rounds): the pound peak and +400 ms,
the swing, the roar's funnel, the skyfall landing, the judgment cloud and landing, the storm bolt's cloud, the
phase surge, the death release; every cue fires without errors (`enemy_fx_smoke`, `stateful`). Not checked
visually: the code bolts (beams fade before a still), rate-driven layers (coil dust, the rip's plume), trails,
dash layers, the projectiles in flight, night, 40 studs, phones and the Game Module (add-on shakes).

Known gaps (effects):
- Dust and rock are earth-lit, so they read low on the grey testbed baseplate; they are meant for grass and stone.
- The judgment cloud is placed at the windup and does not follow a target that moves the landing (the server
  locks the circle with the telegraph, so it should match).
- Feel (shake strength, sound mix, timing at play speed) and phone cost are untested.

### Jade Jiao (testbed trial)
`Config.Wilds.NEW_JIAO = Config.TESTBED` gates the whole boss; **spawn it from the admin panel** (no
testbed zone). The body `JadeJiao` is the user's reference python at 3.17x, rebuilt part for part
(37 joints, 24 x 19 x 38 studs, see `art/enemies/beasts/RIGS.md`): root box 24.7 x 9.5 x 26.3
centred under the coil, so the **mouth is about 24 studs ahead of the root centre (13 up)** and the
body lies mostly behind and around it. QC7, 1500 HP, weight 9, walk 6, run 21 (+2.5% a phase;
the player walks at 16), aggro 60, leash 130, `closeIn` 26 (holds just past the head). Poses
`EnemyPoses/JadeJiao.luau`, effects `EnemyFX/JadeJiao.luau`, poison visuals `PoisonFX.luau`, boss
bar theme `BossThemes.JadeJiao`, sounds `SFX.Enemies.JadeJiao` (existing serpent/boom ids
pitched down, unheard).

Fight: it spawns `Burrowed` (an earth mound, immune, no lock-on) and every engagement opens with
`emerge` (2.2 s, `pack.howl`; it surfaces at the end). The pattern rotates by range band and phase
(`rotate`); thresholds 66/33/12% call molt (phase 2, 2 Venom Serpents), ascension (phase 3, 2 more,
then `venomRain` as its follow-up) and venomRain again at 12%.

| Attack (`name`) | Kind | Windup / recover | Reach from the root | Damage (QC7 255 HP) | CC |
|---|---|---|---|---|---|
| `venomLance` | bolt: 1 projectile, r 1.8, 75/s, range 76 | 0.7 / 0.8 | 26-70 | 28 + poison | flinch |
| `venomFang` | cone r 34, 80 deg | 0.75 / 0.9 | 30 | 36 + poison | flinch |
| `pillarSlam` | slam r 9 at (0,0,-27) | 1.0 / 1.3 | 36 | 61 | stagger 0.7 |
| `tailSweep` | slam r 22 at the root | 0.8 / 1.0 | 20 | 31 | stagger 0.5 |
| `tailShove` | slam r 20 at the root, throws a hit player 36 studs out (`knock`); then `rangedNext` | 0.7 / 0.8 | 22 | 18 | stagger 0.5 |
| `mireDive` (P2) | burrow, lane 6 wide up to 56 at 75/s, no damage; follow-up `erupt` | 0.8 / 0.1 | 30-56 | 0 | none |
| `erupt` | slam r 14 at the root, surfaces it | 0.85 / 1.1 | chained | 56 | stagger 0.8 |
| `dreadHiss` (P2) | howl, stagger circle r 30 | 1.1 / 0.9 | 30 | 0 | stagger 0.8 |
| `venomSpray` (P2) | bolt: 3 projectiles r 1.5 at 0/-22/+22 deg, range 65 | 1.0 / 1.2 | 26-60 | 20 a bolt + poison | flinch |
| `jiaoCoil` (P2) | coil: circle r 13.5 on the target, ring radius 11.9 | 1.5 / 4.4 | 8-45 | 20 + squeeze 71 | stun 1.4 (P3 1.6) |
| `fangFlurry` (P2) | cone r 30 / 70 deg, then re-aimed cones at +0.4 s (r 30) and +1.0 s (r 36, 90 deg) | 0.9 / 2.1 | 28 | 18 a strike + poison | flinch |
| `venomPools` (P2) | 3 circles r 7 (target, +-11 sideways) leaving poison pools 7 s | 1.0 / 0.9 | 24-60 | 18 + poison | flinch |
| `molt`, `ascension` | summon 2 Venom Serpents, phase step | 1.6 / 0.9, 2.0 / 1.0 | threshold | 0 | none |
| `venomRain` | storm: 9 circles r 7, one every 0.3 s from the release, each on where the target stands then and striking 0.9 s after it shows | 2.0 / 5.0 | threshold | 26 a drop | flinch |
| `emerge` | howl, the entrance | 2.2 / 0.6 | engage | 0 | none |

Mechanics (`src/server/BossAttacks.luau`, hooks in EnemyService): `bolt` warns each lane
(`Projectiles.warnLane`, lane 3.6 or 3 wide from the mouth) and at release fires one real boss
projectile per lane (`Projectiles.fire`, cue `venomBolt`, `data.size` = 3.6 or 3, origin at
the mouth 24.2 ahead and 13.1 up, aimed straight down to the target's height over its distance,
no pierce; the hit goes through `hurtPlayer`, so poison and flinch apply; cancelled when the
boss dies or loses its target); `pools` hurt at windup end and
leave hazard circles that add a poison stack a second; `burrow` sets `Burrowed` (model attribute,
cleared by any attack with `unburrow` or when it loses its target; `Combat.damageEnemy` ignores a
burrowed model and LockOn skips it); `coil` locks its circle on the target, the boss runs
to a point `coilRadius` from the centre during the windup, a landed hit stuns and sets
`CoilCenter/CoilRadius/CoilGap/CoilHalfAngle/CoilAt/CoilSqueezeAt`; at the squeeze (dash +
`hold` 3.0 s, P3 2.6) everyone inside `coilRadius` + 1.7 and outside the gap takes damage (no CC:
stun immunity would swallow it); 3% of max health dealt during the hold breaks the ring (stagger
0.9 s, cue `coilBreak`). Poison: `PlayerPoison` (3 stacks, 1.2% max health a stack each second,
5 s refreshed, never lethal, no flinch; attributes `PoisonStacks`/`PoisonUntil`).
Making its own range: after `tailShove` the boss only picks `venomLance`, `venomSpray`
or `venomPools` (`rangedNext`), holding still and facing the target meanwhile, for up to
2.5 s past the recover (`rangedWait`). A bolt whose target came inside its `minRange`
during the windup doesn't fire.
Attack fields `poison`, `strikes`, `lanes`, `flank`, `unburrow`, `dashMin`, `mouth`,
`mouthHeight`, `boltName`, def `phaseCalls`, `startsBurrowed` are documented in Enemies.luau.

Known gaps: the server hitbox is the root box, so tail and body hits don't register (only
the areas above hurt); the coil ring has no collision, so anyone who leaves past the ring
(not only through the door) escapes the squeeze; the coil radius 11.9 is provisional until the
animator's number; no poison cure and no HUD icon; P3's run speed is 22.1 by `phaseSpeed` and
P3 coil timings differ only in hold/stun/gap, not recover; untested in play: the flurry's
re-aimed cones, bolt flight against terrain and uneven ground (the aimed slope ends them on the
ground past the target), the dive under broken ground, the rain at 9 drops on mobile, brood
slot sharing, difficulty (QC7).

Motion (animation QA pass, 2026-10-22; details in `art/enemies/beasts/RIGS.md`, timings and cue
moments unchanged): **Tail Sweep** is a wind-and-lash now, not a full circle: the coil swings out
left and high while the body twists with it and the head dips and looks away, holds, then the
body unwinds and the tail lashes behind and round the right flank, low at contact, and recoils
(the full circle knotted the tail base through the recover and spun it back afterwards). **Tail
Shove**'s whip accelerates into contact over 0.15 s (it was a two-frame jump). **Pillar Slam**'s
head strains in the ground, rips free with a toss and settles (it popped upright at the end).
The **coil ring**'s free tail no longer pops on the squeeze. Every attack plays on from windup into
its release without the 0.2 s re-blend that stopped each strike dead for a frame
(`FAMILIES.JadeJiao.seamless` in EnemyAnimator). After a move the head no longer drops toward the
walk's low neck, and the resting coil gathers only once it is calm again (EnemyAnimator `calm`),
so the body doesn't snap into a coil when a long move ends. Known motion gaps: the body and the
coiled tail slide together with a strike's lunge (the tail doesn't anchor); the tail tip still
peaks near 1000 studs/s in the last two frames of the sweep (the lag catch-up); Tail Shove ends
half reared for a ranged follow-up and sinks back if none comes; untested in Play (feel, the
EnemyAnimator hand-offs at real frame rates, phones).

Jade Jiao effects: `Effects.JadeJiao` (48 templates, 307 emitters; builder
`tools/vfx_specs/JadeJiao.luau`, installs `_G.buildJadeJiaoFX`), handler `EnemyFX/JadeJiao.luau`.
Acid venom-green (9BFF4A) with white-hot cores is the element, amber-gold only for warning tells,
pale spirit-jade for the phase 3 aura, spirit beats and rain; every bright shape sits on a slate/ink
copy. No crown or halo, and no Neon copies of the body (the user rejected boss afterimages,
2026-10-21): the spirit beats are emitters on named body hooks (`Throat`, `Core`,
`Coil_Tail6`, `Coil_Tail12`, `TailTip_FX`, `Mouth`, falling back to `Skull`/`Body`/root), so a
rebuilt body with the same hook names keeps working. Sizes are read off each cue's shape (`AuthoredRadius`/`AuthoredSeconds`
refit); only the dormant mound, earth ridge and coil ring are drawn in code (soil balls and neon
segments, support only).
- Aura (`ready`): ground array (ink, mandala, sigil), venom mist from 5 body parts, motes, mouth
  breath; phase 3 adds jade wisps and motes; health scales the rates; cracks (`P2Crack*`) and
  fins/whiskers (`P3*`) tween in on `Phase`. While `Burrowed` and idle: a soil dome, dust leak
  and green glints at the root, the body hidden (`LocalTransparencyModifier`, one loop).
- Every windup: `EyeFlare` on both eyes, tell parts (`Tell`/`TellBase`) dim to hot amber, hood
  spots flare green, per-attack `Marker`/`MarkerLite` amber circle on the shape.
- `emerge`/`erupt`: `EmergeBuild` (cracks and tremors) then `EmergeBurst` (column, rocks, rings,
  flash, scorch, Craters, heavy shake), `HissBurst` venom mist rings on the hole (0.8x radius) and
  `PhaseFlare` on the surfacing head; the body and dome stay hidden until contact (no stock howl
  disc for bosses). `mireDive`: `GroundGather`, `DiveBurst` (collapsing hole), a moving soil ridge with
  `RidgeFX` until `land`.
- `venomFang`/`fangFlurry`: `FangTell`, `FangSnap`; each flurry strike is its own cue (snap at the
  Mouth plus `GroundMark` on its cone); the snap adds `SpitRelease` at the Mouth. `tailSweep`: `TailTell`, `SweepImpact`, `TailWhip` trail.
  `pillarSlam`: `SlamTell`, `GroundGather`, `SlamImpact` (scorch 6 s).
- Spit: `SpitGather` + throat sac swell. Lance/spray bolts are real projectiles drawn by the
  `venomBolt` ProjectileView drawer in the handler: `SpitRelease` once per volley, `VenomBolt`
  scaled to `data.size` (3.6 lance / 3 spray), a flat ink shadow (the `GroundGather` ink emitter)
  that darkens as the glob drops, and on end `BoltImpact` plus a `PoolSplash` splat when it
  ends near the ground (`hit`/`terrain`); `range`/`lifetime` end in a small airburst. The lane
  warnings are the server's. Pools lob a glob per circle into
  `PoolSplash` + `PoolDisc` (7 s, the only persistent effect); rain: `RainGather`, `RainRelease`,
  and per circle `MarkerLite`, `RainDrop`, `RainSplash` (light).
- `jiaoCoil`: `Marker`, jade glow down `ScaleSeam1..9`, `CoilForm` on `CoilAt`; the ring is 40
  neon segments at `CoilRadius` with the door gap at `CoilGap`/`CoilHalfAngle` (bright dashes and
  two `CoilGate` light posts), pulses tightening to `CoilSqueezeAt`; `squeeze`/`coilBreak` cues.
- `dreadHiss`: `RoarTell`, `HissBurst`. `molt`/`ascension`: `RoarTell`, `ShedSkin` on 5 hooks,
  `GroundGather` under the coils (r14, jade for the ascension), and for the ascension `RainGather`
  on the chest; then `phase`: `PhaseBurst`, `PhaseFlare`, `RainRelease` thrown skyward from the
  Mouth; at phase 3 also `ShedSkin` x1.5 on every hook and a second skyward stream from `Core`.
- Death: `DeathBuild` plus jade `ShedSkin` (3 s, x1.6) on every hook, then `DeathBurst`,
  `DeathSpirit` and a `RainRelease` spirit stream skyward from the chest.
- Players: `PoisonFX.luau` (green Highlight pulse, bubbles and drips by stacks, a screen-edge
  tint for the local player) from `PoisonStacks`/`PoisonUntil`.
Untested: all of it in play (placement on the animated body, follow smoothness, 40-stud read,
phones, the Game Module path, the rain gather if the server sends no windup cue for the 2.0 s
phase; the handler synthesises one from the `Attack` attribute after 0.25 s).

### Template contract
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
- Boss bar: one entry per boss def id in `BossThemes.luau` (title, frame art,
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
- The Spirit Wolf fight was approved in the testbed but is unseen in the main game's
  wilds: the leap's flight over broken ground (EnemyMover can stop it short at a wall;
  the hit still resolves on the circle), the GateWolves pair in the FirstKill beat,
  and phones with a pack of four. Its sounds were picked unheard.
- The second bestiary wave (Venom Serpent, Stone Tortoise, Shadow Mane Wolf) is untested in
  play and mostly unbuilt as of the server pass: reaches on the big Tortoise and the Mane's
  flank lane against the real bodies, whether Shell Guard's 20% reads (and its snap-out
  `arrive`), the serpent's poison at QC3, the poison-hop backslide, and every number. Rewards are
  placeholders; the Tortoise drops a Lesser core (and a small chance of a Greater).
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
