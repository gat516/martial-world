# Boss open work

What's still left on the four testbed bosses after the 2026-10-21 build and the
first Opus quality pass. Each section is one boss; take items off as they land.
The bosses themselves are documented in [enemies](enemies.md); each body's joints,
pivots and safe ranges are in its `art/enemies/<group>/RIGS.md`.

## Rules the user set (apply to every pass)
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

## Shared workflow notes
- **Shared files and locks.** `assets/Enemies.rbxm` and `assets/Effects.rbxm` are
  shared across agents and sessions. Take the lock dir before exporting (the boss
  run used `scratchpad/locks/enemies-rbxm` and `effects-rbxm`), open a fresh
  sandbox after taking it, and check every group or template is still there
  afterwards: `rojo build` a tiny project that maps the file, then grep the output
  for the names.
- **Committing.** Other sessions leave staged files in the shared index. Commit
  through a temporary `GIT_INDEX_FILE` built from HEAD plus your own paths, then
  `git reset` those paths. Commit RIGS.md and doc hunks straight away, or another
  session's commit swallows them.
- **QA.** Check visually, not only by numbers: capture key frames in your own
  sandbox. The animators' QA scripts are under `art/enemies/beasts/` and
  `art/enemies/quadrupeds/`.

## Thunder Ape (`ThunderApeB`, 3.71x, about 30 studs tall)
**Animation** (`src/client/EnemyPoses/ThunderApe.luau`; part 1 is `130f0b5`). Done:
timings match `122e93b`, the boulder throw beats (release at 1.25 s, fist within
3.6 studs of the spawn point), gait touchdown pops, and continuous secondary
motion. Left:
- **Chest beats:** swap the solved beat arm (written in RIGS.md) into the three
  roars, Death's beat and BodySlam C. The current arm clips the jaw and skull by
  about 2.5 studs.
- **ClubSwing and Backhand:** the sweeps clip the beard by 1.6-1.9 and the jaw by
  about 1.2. Re-solve the contact and follow-through arms, and rework the
  anticipation for the 0.8 s windup.
- **Landing pops:** BodySlam 0.67, ThunderRush 0.59, Bound 0.37, ThunderPound B
  0.30 rad. The planned fix is a lifted landing pose solved just before touchdown.
- **Judgment and Skyfall:** the deep crouches sink the thighs 0.6-1.2 studs.
- **Stagger:** a 0.66 rad pop, not reworked. **Death:** not reworked; it ends
  0.8 studs into the ground.
- **Thunder Lance:** swap in the solved throw arm (in RIGS.md). The lance fires
  from 16 ahead and 3.5 up.
- **Recovers:** the fists slide up to about 7 studs along the ground in the pound
  recover. They should step.
- **Small clips:** the beard sits about 0.8 into the chest, and the forearm grazes
  the skull in the boulder follow-through.
- **Def changes wanted:** register `staggerSeconds = 0.45` on `ThunderApeB` in
  `EnemyAnimator.luau` (it currently plays a 0.35 s pose in 0.28 s). (`bound`'s
  recover is now 0.35 and the boulder comment says 1.25 s.)
- **Arrivals (server done, 2026-10-22 feel pass, `WEIGHTED_MOVES`):** `thunderRush`
  pulls up 12 short of where you stood and swipes (`rushSwipe`, 0.40 s), `skyfallSlam`
  sweeps on landing (`skyfallSweep`, 0.50 s), a miss skids round (`thunderRushSkid`,
  `skyfallSlamSkid` in `AttackName`). Bounds pick `over`/`flank`/`back`/`short`
  (`BoundMode`, per-mode flight in `DashSeconds`), and the root turns during the
  windup and in the air. Poses and effects for these, and feel, are open.
- **Feel:** whether the combo still feels rushed under the new timings hasn't been
  judged.

**Effects** (`src/client/EnemyFX/ThunderApe.luau`, `tools/vfx_specs/ThunderApe.luau`;
pass committed `3d71470`, impact pass below). Done:
- **Ghosts replaced:** `SpeedShed` (sparks, arcs and cloud where the body passed)
  plus `LimbTrail` ribbons on rushes and leaps; the roar pushes forward instead of
  a ghost head; `DeathSoul` spirit flames for the death ghost.
- **Roars:** rebuilt `RoarGather`, `BeatGround` and `RoarShock`, reading without
  the howl disc and with no ring around the head.
- **Boulder:** the rip, a rock that rises to the fist and rides it, a charge, and
  the `"boulder"` drawer with a tightening shadow and an impact. The release is
  `seconds - 0.45`.
- **Lance:** a fist-only windup (the only lane is `warnLane`) and the
  `"thunderLance"` javelin drawer.
- **Cheap reads fixed:** code bolts and the phase-2 ground disc.
- **Impact pass (2026-10-22, the shared kit below):** thunderPound, the pound
  wave, bodySlam, skyfall and judgment landings, bound landings and take-offs
  layer shockwave, dust, debris, contact flash and (landings) burst and scar,
  with a distance shake. rushSwipe and skyfallSweep reuse the club/backhand
  tells and crescents plus a dust rake; `thunderRushSkid`/`skyfallSlamSkid`
  plough dust from fists and feet. The boulder gets a dark wake and an earth
  explosion; the lance a white-hot core, trail and a thunder explosion.
  Landings now play when Attack has already moved on to the arrival follow-up
  (`arrived`), and the leap circle is kept apart (`leapShape`) so the
  follow-up's cone doesn't move the landing.

Left, all untested:
- captures of the dash shed and limb trails, `AuraGround`, the phase roar and
  `BeatGround`;
- night, the 40-stud read, and phone cost (`SpeedShed` is about 120 particles/s);
- Game Module playback;
- both drawers against the real server messages. The boulder jumps from the
  animator's fist to the server's fire point `(7, 14, -2)` at hand-off, and the
  rock's ride on the real lift pose is unchecked;
- `LanceBolt`'s particles and trails, which never showed in Edit-mode captures;
- the chest `SigilFlare` dark disc, which reads a bit blobby and should be toned
  down.

## Nine-Tailed Fox (`NineTailFoxB`, 2.13x, fur tails rebuilt `d775419`)
**Animation** (`src/client/EnemyPoses/NineTailFox.luau`; part 1 is `b314d83`).
Done: tails stay above the floor everywhere except the plunges (which stab in on
purpose), a capped follow-through spring on the body, head, ears and tail hub,
and a head guard that lifts the head and neck off the forearms. Left:
- **Hind knees into the hips:** walk 0.48, run 0.68, RendingPounce 0.78,
  MoonLeap 0.59, Death 0.87 studs.
- **Intro and the curled sleep:** paw/thigh 0.89, play-bow paw/paw 0.40.
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
- **Def changes wanted:** `rendingPounce` windup 0.75 → about 1.0 (room for the
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

## Jade Jiao (`JadeJiao`, the user's own snake, rebuilt `33c253a`)
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

## Elder Wolf King
**Animation** (`WolfKing.luau`, 2026-10-22): `KingLeap` (low coil, drive, stretched
apex and hang, forepaws touch first), `KingRake` (opens on the landing compression, left
paw cocked wide, rakes across), `KingLeapSkid` and `KingsRushSkid` (brace, the head leads
the live target yaw, hind end swings out, scrabble, square up), all checked numerically
(RIGS.md). The rake uses the LEFT forepaw only (effects that tell both forepaws should
follow it). `kingsRushSkid` waits on the server sending it. Left: feel in play, the dash's
arc has no apex hang of its own (EnemyMotion's plain parabola), phone cost of the extra
secondary-motion samples.
Done: ghosts and the always-on ground mandala and ink disc removed (`719fb5d`). The
server side of `kingLeap` (r14 slam, heavy telegraph) -> `kingRake` (or
`kingLeapSkid`) is in (2026-10-22), and `kingsRush` now ends in the same `kingRake`
(or `kingsRushSkid`).
Impact pass (2026-10-22): clawDown and crownfall layer moonlight shockwave, dust,
flash and (crownfall) a scar and rocks; new `kingLeap` (crouch tell and the
landing sigil, rush trail and take-off dust, a landing slam with burst, scar and
rocks), `kingRake` (both forepaws' tells, two slashes, a dust rake), and
`kingsRushSkid`/`kingLeapSkid` dust from all four paws.
Left: judge in play whether the rising light columns (Pack Call, Death) read. The
unused `AuraGround` template is still in `Effects.rbxm`; drop it on the next
rebuild. Open from earlier: its trial zone `WolfKingTrial` still auto-spawns,
while the other bosses spawn only from the admin panel.

## All bosses
- **Impact kit (2026-10-22):** `src/client/EnemyFX/Impact.luau` plays
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
- **Drops:** the Thunder Ape and the fox reuse the Wolf King's drop pool as a
  placeholder.
- **Testbed camera:** `CameraMaxZoomDistance` is 30, the ape's height. Raise it
  for big bosses.
- **Sounds:** every boss uses placeholder sounds reused from other enemies, never
  listened to.
- **Shipping:** nothing has been played. Each boss goes to the main game only
  after the user approves it in the testbed, by flipping its `Config.Wilds.NEW_*`
  flag.
