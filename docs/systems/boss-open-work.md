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
  `EnemyAnimator.luau` (it currently plays a 0.35 s pose in 0.28 s). Raise
  `bound`'s recover from 0.25 to 0.35. Fix the stale "boulder released at 0.60 s"
  comment in `Enemies.luau`.
- **Feel:** whether the combo still feels rushed under the new timings hasn't been
  judged.

**Effects** (`src/client/EnemyFX/ThunderApe.luau`, `tools/vfx_specs/ThunderApe.luau`).
The Opus pass was still running when this page was written: ghost removal, a
clean-up for boss grandeur, the boulder and lance projectile drawers, and
retiming to `122e93b`. Check `git log` for its commit and update this section.

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
Done: ghosts replaced (Kindle, RoarBreath, foxfire spiral, Dissolve and tail
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

**Effects** (`src/client/EnemyFX/JadeJiao.luau`). Done: ghosts replaced
(`101bc37`) and the `venomBolt` drawer (`aafa851`). Left:
- a full quality pass sized for the rebuilt, smaller body;
- the ascension windup, which is quieter than it was with the ghost head;
- the always-on aura `Under` disc, which still needs checking against the
  no-disc rule.

**Gaps:** the server hitbox is the root box, so tail hits don't register. The coil
ring has no collision, so you can walk out past the edge, not only through the gap.
There is no poison cure and no HUD poison icon.

## Elder Wolf King
Done: ghosts and the always-on ground mandala and ink disc removed (`719fb5d`).
Left: judge in play whether the rising light columns (Pack Call, Death) read. The
unused `AuraGround` template is still in `Effects.rbxm`; drop it on the next
rebuild. Open from earlier: its trial zone `WolfKingTrial` still auto-spawns,
while the other bosses spawn only from the admin panel.

## All bosses
- **Drops:** the Thunder Ape and the fox reuse the Wolf King's drop pool as a
  placeholder.
- **Testbed camera:** `CameraMaxZoomDistance` is 30, the ape's height. Raise it
  for big bosses.
- **Sounds:** every boss uses placeholder sounds reused from other enemies, never
  listened to.
- **Shipping:** nothing has been played. Each boss goes to the main game only
  after the user approves it in the testbed, by flipping its `Config.Wilds.NEW_*`
  flag.
