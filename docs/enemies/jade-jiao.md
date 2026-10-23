# Jade Jiao (testbed trial)

Boss (testbed trial): fight, phases, numbers, effects. Shared systems (AI states, wire, cues, attack mechanics, template contract): [enemies.md](../systems/enemies.md).

`Config.Wilds.NEW_JIAO = Config.TESTBED` gates the whole boss; **spawn it from the admin panel** (no
testbed zone). The body `JadeJiao` is the user's reference python at 3.17x, rebuilt part for part
(37 joints, 24 x 19 x 38 studs, see `art/enemies/beasts/RIGS.md`): root box 24.7 x 9.5 x 26.3
centred under the coil, so the **mouth is about 24 studs ahead of the root centre (13 up)** and the
body lies mostly behind and around it. QC7, 1500 HP, weight 9, walk 6, run 21 (+2.5% a phase;
the player walks at 16), aggro 60, leash 130, `closeIn` 26 (holds just past the head). Poses
`EnemyPoses/JadeJiao.luau`, effects `EnemyFX/JadeJiao.luau`, poison visuals `PoisonFX.luau`, boss
bar theme `BossThemes.JadeJiao`, sounds `SFX.Enemies.JadeJiao` (voices reuse serpent ids pitched
down; the effect sounds are in the effects table below).

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

Jade Jiao effects: `Effects.JadeJiao` (40 templates, 113 authored emitters, 18 mesh waves, the
TailLash and VenomBolt trails; builder `tools/vfx_specs/JadeJiao.luau`, installs
`_G.buildJadeJiaoFX`), played by `EnemyFX/JadeJiao.luau` (gated to Template `JadeJiao`).
**Rebuilt 2026-10-22 with the intent-first method** (`.claude/agents/vfx.md`): the first pass was
technically fine but random (307 emitters; amber marker circles and arrays redrawing every
telegraph, the shared Impact kit stacked on every slam, sweep, emerge and pool, a skyward "spirit
stream" on every phase and the rain, three peaks in the death). Now every layer is caused by the
body doing the move, starts 20-150 ms behind its cause (EmitDelay), each beat has one hero on a
slate twin of its own shape, and every peak has a sound. The spec header holds the ms beat sheet
for every cue. Assets were searched fresh in the library from what each move causes (earth, dust,
debris, liquid, splash, mist, air, sound, scales, spirit): 35 ids, all new to the game except the
generic dot and the kept aura textures (5 flipbooks, 9 meshes as mesh waves). Look: venom-green
with white-hot centres for the venom, soil and dust for the earth, pale spirit-jade only where its
qi leaves the body (ascension, death); every bright layer on a slate twin. No crown or halo, no
copies of the body, no ground markers (telegraphs.md: the telegraph owns where and when).
Cut, and why: `Marker`/`MarkerLite`/`GroundMark` (redrew the telegraph), `GroundGather` (nothing in
the ground gathers before a blow), the aura's always-on ground mandala and sigil, every `Impact`
kit call and the bolts' `Impact.shot` core (doubled impacts), `HoodFlare` particles (the hood's
Tell parts already light), the skyward `RainRelease` streams (no cause), the old death's
white-out, rays and pillar (three peaks), the coil ring's 40 neon segments and ground pulses (the
body is the ring), and shakes on small beats. Found and fixed: `buildCoil` was never called, so
the coil, squeeze and break cues drew nothing; it now runs on the coil rush's `land` (with a
fallback after `DashSeconds`).

| Cue | Intent (what happens / feel / job) | Hero | Other layers (start) | Sound (beat) |
|---|---|---|---|---|
| every windup | the eyes fix on the prey / warning | `EyeFlare` glint (0-250) | Tell parts brighten in code | `Attack_<name>` voice (EnemySounds) |
| `emerge` / `erupt` | the ground heaves, then the serpent breaks out of the earth / dread, arrival | `EmergeBurst`: a crown of earth heaving up (mesh) with venom shimmering inside it | `EmergeBuild` through the windup (cracks spreading, tremor dust, pebbles from 900, venom seeping from 1300); burst: flash +0, hole +0, rocks and Craters +30, dust ring +60, dust cloud +80, venom mist +120; shake | `Attack_emerge`/`Attack_erupt` rumble at the windup, `EmergeBlast` +0, `EmergeDebris` +150 |
| `mireDive` | the head dives into the earth and a ridge runs under it / evasion | `DiveBurst`: soil splashing round the head (mesh) | hole, clods +20, dust +60; `RidgeFX` soil spray on the code-built ridge | `Dive`, `Burrow` at the dash |
| `venomFang` / `fangFlurry` | venom beads on the bared fangs, the jaws snap shut / threat, melee | `FangSnap`: two ragged jaw crescents closing on slate twins | `VenomWell` drips through the windup; flash +0, venom flung +30 | `Bite` + `BiteVenom` per bite |
| `tailSweep` | the tail winds high, trembles, lashes round the right and slaps down / weight | `TailImpact`: a wall of dust kicked along the lash under the tip | `TailTell` dust and glint at 400; `TailLash` trails ride the tip 450 to R+150; flash +0, rocks +20, slate shock ring +40, cloud +80 | `Lash` at the lash's start, `TailSlam` at contact |
| `tailShove` | the coiled tail whips out and shoves you 36 studs / knock-back | `ShoveBlast`: a torn air front rushing outward on its slate twin | `TailTell`, `TailLash` 550-850; flash +0, speed lines +20, dust +30 | `Lash`, `ShoveBlast` |
| `pillarSlam` | the head rears, drooling venom, drives into the ground, then tears free / impact | `SlamImpact`: a crown of earth thrown up round the head (two spike meshes) | `VenomWell`; flash +0, crater held 2.4 s, dirt +0, venom off the jaws +20, slate shock ring and Craters +40, dust ring +60, cloud +100; `RipFree` (rocks, dust) at R+860; shake | `Attack_pillarSlam` inhale, `SlamImpact` +0, `SlamRocks` +80, `RipFree` |
| `venomLance` / `venomSpray` | venom pumped into the mouth and spat as a glob / dodge | the writhing glob (`VenomBolt`) on a slate halo | `SpitGather` (core on slate, drool, fume in the last 40%); `SpitRelease` jet on slate +0, mist +40; trails, drips, a shadow on the floor; `BoltSplat` (flash, splash on slate, drops +30, fume +80) and `GroundSplat` | `Spit` at release, `Splat` at the end |
| `venomPools` | three globs lobbed into poison pools / area denial | `PoolDisc`: the puddle on its slate twin (7 s, the hazard) | `SpitGather`; spit and lob; `BoltSplat` on landing; bubbles and a thin fume | `Spit`, `PoolLand`, `PoolBubble` |
| `venomRain` (P3) | venom gathered and spat into the sky, falling as nine drops / dread | the drops (`VenomBolt` falling 60 studs) | `SpitGather` x1.5; `SpitRelease` aimed up x2; each drop `BoltSplat` + `GroundSplat` | `Attack_venomRain` gulp, `Geyser` at release, `Splat` per drop |
| `jiaoCoil` | the body slaps down round you, tightens, crushes / dread, escape through the door | `CoilSlam`: dust rising off the ring's rim | seams glow (windup) then beat faster toward the squeeze (code), `CoilGate` venom wisps at the door's edges; `CoilSqueeze` (air ring collapsing inward, dust shoved in, crush flash, venom forced up); `CoilBreak` (scales and dust flung out) | `CoilSlam`, `Squeeze`, `CoilBreak` |
| `dreadHiss` | breath drawn in, then a hiss radiating all round / stagger | `HissWave`: a torn sound ring racing out to r30 on its slate twin | `HissTell` inhale (last 60%); second ring +120 (ForceField), breath +60, `HissDust` +80 | `Attack_dreadHiss` inhale, `Hiss` + `HissWave` at release |
| `molt` / phase 2 | the old skin peels and sloughs off / power shift | `ShedBurst`: scales bursting off every body hook | `ShedSkin` flakes through the windup; P2 cracks reveal | `Molt` at the phase cue |
| `ascension` / phase 3 | jade qi drawn into the chest surges up as it ascends / power shift | `AscendSurge`: a twisting jade column (ForceField over a soft Neon core) | `QiGather` (wisps in, core on slate), seams glow; flash +0, slate puff, motes +40; fins and whiskers reveal; shake | `Attack_ascension` charge, `Ascend` at the phase cue |
| `hit` | the blow lands / hit confirm | `HitFang` spatter on slate, `HitTail` soft burst, `HitHeavy` flash and slate shock ring, `HitVenom` splat on slate | dust or a fume | `HitFang`, `HitTail`, `HitHeavy`, `HitVenom` |
| `stagger` | a blow knocks scales loose / punish window | `StaggerFlare` scale chips | flash | `Hurt` (EnemySounds, unset) |
| `death` | venom and qi bleed off the fading body, its spirit rises / release, reward | `SpiritRise` at 1000 where the chest was: a twisting jade column | `DeathBleed` on every hook 0-1000; flash, slate puff, spirit swirl +30, motes +60 | `DeathSlump` at 0, `SpiritRise` at 1000 |

Sound ids (`SFX.Enemies.JadeJiao`, library names): Bite 4511723890 "Eat", BiteVenom and HitVenom
3781479909 "Bloody Splat", Lash 3755636152 "Swing (8)", TailSlam 112198630684733 "Ground Slam",
ShoveBlast 112611832797358 "Downslam Air", SlamImpact 18506356852 "Ground Slam (3)", SlamRocks
9118612665 "Rock Impact", RipFree 132758217 "Collapse (3)", EmergeBlast 9114224354 "Earthquake
Explosion", EmergeDebris 134854740 "Collapse (1)", Dive 103626556433205 "Earth Impact", Burrow
78919029033811 "Earthquake debris", Spit 5845688763 "Blood Spew", Splat 8164951181 "Blood Splatter
SFX", PoolLand 9119477732 "Splash impact", PoolBubble 9113605402 "Bubble Whoosh", Geyser 9120503305
"Water Burst", CoilSlam 104313759544581 "Ground Slam (2)", Squeeze 3739363791 "Gore (2)", CoilBreak
9118614718 "Rock Impact (2)", Hiss 9120618797 "Water Spray", HissWave 4580495407 "Wind Orb
Activate", Molt 6849041223 "Gore (4)", Ascend 9116385079 "Magic Burst 4", HitFang 102157587407122
"Heavy Stab (2)", HitTail 610359515 "Punch (2)", HitHeavy 441202925 "Punch", DeathSlump 3784889529
"Collapse", SpiritRise 9116378941 "Magic Acceleration Musical Phasey Tones 1". Windup voices swapped
because they played a roar or boom 1-2 s before the blow: `Attack_emerge` and `Attack_erupt` the
earthquake rumble, `Attack_pillarSlam`, `Attack_dreadHiss` and `Attack_venomRain` an inhale
(5297498542, pitched), `Attack_ascension` a charge (137463716). All load in Studio; picked by name
and length, not listened to, and other creators' uploads may be silent in-game.
Kept from the first pass: the aura on the body (`AuraBody`, `AuraBreath`; health scales the rates,
phase 3 adds jade wisps and motes), the dormant mound (`MoundFX` and the code-built soil dome), the
body hiding while burrowed, the phase reveal parts, the Tell parts, and `PoisonFX.luau` on players.
Checked: every cue fired against the real body in a sandbox (`enemy_fx_smoke` with `stateful`, plus
phase 3, the coil's land/squeeze/break with server-like `Coil*` attributes and the venomBolt drawer's
start/step/finish: no errors, spawns counted); frozen captures of the emerge burst (+170, +600), a
bite, the tail slap, the slam (+180, +300, two rounds), the hiss, the ascension surge, the death
column and a pool landing (static pose, so the head and tail are not where the animation puts them).
Untested: the look at play speed on the animated body (the lash trails and the bolt's flight cannot
be frozen; the impacts land under the live tip and circles), the Disc-rim emitters of the coil
beats, every sound in-game (permissions, loudness, fit), the Game Module path, phone load of the
rain (nine drops, about 12 emitters each live for a second) and three pools (4 emitters each, 7 s).

## Open work

Left after the 2026-10-21 build and the first Opus quality pass (moved from the former boss open-work list); take items off as they land. Joints, pivots and safe ranges are in the body's `art/enemies/<group>/RIGS.md`.

Body: `JadeJiao`, the user's own snake, rebuilt `33c253a`.

**Animation** (`Serpent.luau` and `JadeJiao.luau`; slither is `7ed302d`). Done: a
ground-fixed S-wave slither that follows the head's path (skate 0.7-1.2 studs/s),
coil radius 11.9 (tightens to about 9.8 in the hold), the resting coil at idle
with an uncoil and recoil. Left:
- **Contact points:** measure them against the re-fitted areas (`a80f0eb`): fang
  cone r 34, slam circle at (0, 0, -27), sweep r 22, lance and spray from the
  mouth 24.2 ahead and 13.1 up.
- **Coil QA:** re-run it (its output was cut off). Neither the ring's on-circle
  error nor the free-tail arch at the gap has been checked; the tail reaches only
  about 267 of 280 degrees.
- **Clipping:** hood, fang and whisker clipping is unchecked.
- **Stiffness:** the moves carry over overlapping action and settle, but nothing
  was re-tuned for the new body.
- **In play:** the live uncoil and recoil, blending, and phone cost (the old coil
  neck solve cost about 1.4 ms per frame).
- **Part budget:** the body is 220 parts, over the ~150 boss budget.

**TailShove pose (2026-10-22, `JadeJiao.luau` `TailShove`):** coil and twist, the tail
cocked out to the right, a low whip round to the front-right (contact at the end of the
windup) with a release flick, then it rears back hood up and ends half reared, ready to
spit. Clear of the neck and Body by forward kinematics (RIGS.md). Untested in play: the
tail against the def's area and the blend into the ranged windup.

**Effects** (`src/client/EnemyFX/JadeJiao.luau`). Done: ghosts replaced
(`101bc37`) and the `venomBolt` drawer (`aafa851`). Impact pass (2026-10-22):
pillarSlam, tailSweep, erupt/emerge and the pool globs layer venom shockwave,
mud, debris, flash and (slam, erupt) a scar; new `tailShove` (tail tell, a
body-wide shove of dust and shock); the venom bolt gets a white-hot core, a
dark trail under a bright one and an explosion on the ground. Left:
- a full quality pass sized for the rebuilt, smaller body;
- the ascension windup, which is quieter than it was with the ghost head;
- the always-on aura `Under` disc, which still needs checking against the
  no-disc rule.

**Fight (server done, 2026-10-22):** `tailShove` throws close players 36 studs out and
the boss then holds for a ranged attack (`rangedNext`); bolts no longer fire at a target
inside their `minRange`. Open: its pose and effect, and the client's 0.22 s knock reading
as a teleport at 36 studs.

**Gaps:** the server hitbox is the root box, so tail hits don't register. The coil
ring has no collision, so you can walk out past the edge, not only through the gap.
There is no poison cure and no HUD poison icon.
