# Nine-Tailed Fox (testbed trial)

Boss (testbed trial): fight, phases, numbers, effects, animation QA. Shared systems (AI states, wire, cues, attack mechanics, template contract): [enemies.md](../systems/enemies.md).

`Config.Wilds.NEW_NINE_TAIL_FOX = TESTBED` gates the def. QR9 boss, 2950 HP, weight 7,
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

| Attack (`name`) | Kind | Windup / active / recover | Area (from the fox's root) | Damage (def; share of a QR9 player) | Notes |
|---|---|---|---|---|---|
| `intro` | howl | 2.2 / - / 0.8 | ring | 0 | opener |
| `fangDance` | barrage `fangs` | 0.65 / 0.12 / 1.2 | 3 cones r 20, 80 deg, at +0, +0.4, +0.8 s | 35 each (6%) | melee, range 18 |
| `tailSweep` | cone | 0.9 / 0.25 / 1.1 | r 18, 200 deg | 68 (11%) | range 16 |
| `tailLance` | barrage `lance` | 0.6 / 0.1 / 0.8 | box 20 x 4 | 74 (12%) | 5-24 |
| `lanceFan` | barrage `lanceFan` | 0.95 / 0.1 / 1.1 (P3 1.8) | 20 x 4 boxes: P1 3 at +-22, P2 5 at +-40, P3 5 then back; 0.18 s apart | 56 each (9%) | 5-24 |
| `tailSnare` | barrage `snare` | 0.85 / 0.1 / 0.9 | box 20 x 4 | 50 (8%) | pulls the hit player to 11 studs in 0.45 s (a 0.45 s stagger), then `fangDance` follows (only on a hit) |
| `rendingPounce` | lunge | 0.75 / dash / 1.0 | box 8 x 30 at 55/s | 93 (15%) | 18-36 |
| `foxfireVolley` | barrage `volley` | 1.1 / 0.1 / 1.0 (P3 1.8) | 5 lanes 56 x 4 at 20 deg steps; P3 7 lanes at 15 deg in two waves 0.7 s apart | 50 each (8%) | 20-70; **converted to real projectiles** (below) |
| `rootfireEruption` (P2) | barrage `ringHeart` | 1.5 / 0.1 / 1.6 | 4 circles r 5 on a ring of 11 round the target, then r 7 under it at +0.8 s | 68 each (11%) | heart staggers 0.6 s |
| `moonLeap` | retreat | 0.4 / 0.6 flight / 0.4 | landing ring + trail box 34 x 6 ticking at +0.5, 1.0, 1.5 s | 15 per tick (2%) | then Foxfire Volley |
| `mournfulScream` (P2) | howl + stun | 1.4 / 0.3 / 1.6 | circle r 30 | 0 | stun 1.2 s, cooldown 14 s |
| `nineTailFall` (P3) | barrage `spiral` | 1.8 / 0.1 / 2.0 | 9 circles r 7 spiralling out from the target, 0.2 s apart, then r 20 under the fox at +1.9 s | 68 each, 136 final (11%, 22%) | the final circle staggers 0.6 s |
| `veilBreak` | howl + stagger | 1.6 / 0.2 / 1.0 | circle r 16 | 0 | phase step, stagger 0.6 s |

Numbers are authored against `Pacing.BeastBaseline` QR9 (620 HP, power 3.40), rescaled 2026-10-23 from the
first FE1 tuning (a 500 HP, power 3 player) with every share kept. Live, the curve scales them to the QR9 player
(1030 HP, power 10.30): about 8940 HP and x1.66 damage (pounce 154), the same shares and hits to kill.

Fox-only mechanics (the shared `barrage`, `retreat`, `spacing` are in enemies.md "Attack mechanics"):
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
`hurtPart` (50 damage, dodges and flinch apply); `data = { tail = 1..9, phase = 1..3 }`. A stagger of
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
(`.claude/skills/vfx-method/SKILL.md`): the first pass was technically fine but random (layers added because
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

## Animation QA (2026-10-22)
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
poses are tuned against the old blend. (The intro pop, the pounce's bound steps, the death's
shoulder step and Fang Dance's stops were fixed by the 2026-10-23 motion pass, below.) Plunging
tails now pass through the hind thighs (0.7-1.2 studs) where they used to pass through the chest
(1.4-1.7), since a straight tail from the hub to the floor must cross the flank. Timings, cue
moments and the pose API are unchanged. Untested in Play.

## Motion pass (2026-10-23, audit item A2)
Intent: the fox fights like a dancer. Every stationary move's body now ripples: the keyed body is
re-timed link by link (`RIPPLE` in the module), the hips reading the keys 3 frames ahead, the
chest 2, the neck 1 and the head on the beat, each link's world rotation averaged over a few frames
(wider toward the head) and the tail hub trailing the hips, so each strike starts in the hips and
arrives at the head on the contact frame, and keys that stopped dead now ease into their holds.
Stagger and Death take the blow from outside (the hips first, the head trails by up to 3 frames);
Moon Leap resamples the flip itself; the pounce keeps its own timing. Other changes:
- **Intro** opens from the standing idle (the fox never idles curled, so the first frame popped
  95 deg / 150 studs/s): a bow-stretch with a yawn, back onto the haunches, up through the arch,
  head thrown back for the howl at the release; tails sweep low with the bow, then unfurl 0.2 s
  apart. Timings and the intro cues are unchanged.
- **Pounce** bound is laid out for 32 studs/s (`STRIDE_SPEED`): at 55 the stance legs swept their
  range in three frames and flipped 80-115 deg a frame; the windup ends still loaded (the rise is
  in the dash). **Death** legs are filtered through the collapse (`LEG_SMOOTH`, it flipped 100 deg),
  the down-side legs roll a little and the head guard lets go as it falls (`GUARD_OFF`).
- **Head guard** lift is capped by the overlap depth and takes the smallest clearing lift: it used
  to jump straight to a big lift (head pops of 50-70 studs/s, most of the "stops dead").
- Plunging tails stop 0.42 unit over the floor (rootfire low -0.63 -> -0.34; Nine-Tail Fall -0.56 -> -0.27).

Probe (`motion_audit.luau`, before -> after): body chain BLOCK in 10 moves -> none of the ten
(Moon Leap reads BLOCK on its mid-flip speed plateau, though the links lag 1-3 frames on the rise
and fall); head stops dead Fang Dance 4 -> 0, Foxfire Volley 3 -> 0, Rootfire 3 -> 0, Moon Leap +
Volley 6 -> 1, every move at most 1; intro worst step 95 -> 27 deg, hero 150 -> 36 studs/s; leg
steps pounce 115 -> 47 (the take-off paw, baseline 46), Death 100 -> 30, Moon Leap 72 -> under 45.
Left: Fang Dance's and Tail Snare's planted forelegs step 57 deg on each snap (the IK as the root
drops; a leg filter sank the paws), the pounce's take-off paw 47, Death's forepaw still dips about
1.3 studs for 0.15 s as it rolls over, tail segments (stem > mid > tip) still turn together.
Untested in Play: feel, the ripple against EnemyAnimator's blends, cost (the ripple samples six
keyed poses a frame, about the follow-through spring's cost again).

## Open work

Left after the 2026-10-21 build and the first Opus quality pass (moved from the former boss open-work list); take items off as they land. Joints, pivots and safe ranges are in the body's `art/enemies/<group>/RIGS.md`.

Body: `NineTailFoxB`, 2.13x, fur tails rebuilt `d775419`.

**Animation** (`src/client/EnemyPoses/NineTailFox.luau`; part 1 is `b314d83`).
Done: tails stay above the floor everywhere except the plunges (which stab in on
purpose), a capped follow-through spring on the body, head, ears and tail hub,
and a head guard that lifts the head and neck off the forearms. Left:
- **Hind knees into the hips:** walk 0.48, run 0.68, RendingPounce 0.78,
  MoonLeap 0.59, Death 0.87 studs.
- **Intro:** the curl is gone (2026-10-23); the bow-stretch clips the forearms into the neck 0.15 unit and the sit's hind paws 0.30 into the thighs.
- **Death legs:** the hind paw sinks 0.72 into the hips and a hind leg 0.51 into
  the ground.
- **Tails through the body:**
  - FoxfireVolley: up to 0.75 through the ears and head.
  - RootfireEruption: tails 1 and 9 go 1.7 through the chest.
  - NineTailFall: tail 1 goes 1.44 through the chest.
  - TailSweep: tail 8 goes 0.35 through the left ear.
- **Remaining head and neck clips:** RendingPounce coil 0.35, NineTailFall 0.34,
  VeilBreak 0.18, Death 0.22.
- **Lower legs bent past range:** RendingPounce -2.08, VeilBreak -1.93,
  MoonLeap -1.99 rad.
- **Walk rework (not started):** it's a quick bent-legged glide. The plan is about
  1.35 cycles/s at speed 8, near-straight legs with a root that rises and falls
  with the planted legs, paws placed toward the midline, and a level head.
- **Per-move polish:** stronger settles, weight shifts in held poses, and a bigger
  always-on tail wave. Only the shared spring is in.
- **B/C variants:** not re-run through QA. **Visual review:** only about four
  poses captured.
- **Def changes wanted (proposal, not applied):** `rendingPounce` windup 0.75 → about 1.0 (room for the
  haunch wiggle) and `moonLeap` recover 0.4 → about 0.6. `veilBreak` drops from
  the full rear in the last 0.03-0.15 s: re-key it inside 1.6 s or allow 1.8.
- **Barrage timing:** `input.parts` isn't sent to the client, so the tails use
  `DEFAULT_PARTS` timing. If it's off, add a `Parts` attribute from the server.

**Effects** (`src/client/EnemyFX/NineTailFox.luau`; pass committed `5bc6e02`).
Impact pass (2026-10-22): rootfire eruptions and tail plunges land with a
shockwave, dust and flash in the phase colour; the eruption heart and
NineTailFall's final burst add the explosion, rocks and a scar; foxfire bolts
explode where they land (the bolt itself already had its core, slate halo and
trails, so it is unchanged). Done: ghosts replaced (Kindle, RoarBreath, foxfire spiral, Dissolve and tail
streams into SoulRelease), discs and slabs removed, lances and sweep ribbons
follow the real tails, and the `foxfireBolt` drawer. Left, all untested:
- feel at play speed (Edit mode draws trails as straight chords);
- the bolt drawer against the live server path;
- Game Module playback;
- phone load of NineTailFall (about 60 emitters) and Death;
- the moonLeap `Landing` crescent, which never showed in captures;
- the last brightness tweaks (Kindle, Dissolve, bolt trails), never re-captured.

**Drops:** the Thunder Ape and the fox reuse the Wolf King's drop pool as a placeholder.
