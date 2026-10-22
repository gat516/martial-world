# Blood Centipede poses (`src/client/EnemyPoses/BloodCentipede.luau`)

Rig table: `RIGS.md` "Blood Centipede" (43 joints, 1x, faces -Z). The module header has the
FAMILIES registration line, the beat-by-beat description and the API; this file keeps the numbers
and gotchas.

## How the chain is posed

- The body is a chain of 0.8 stud plates (JointRoot -> JointSeg1..12 -> JointTail, 14 nodes), each joint
  relative to the plate before it, and a bend over 0.25 rad per joint gaps the plates. The module authors the
  ABSOLUTE heading (yaw) and pitch of every plate (a wave, a rear, a curl, a follow) and turns each joint
  by `A(j-1)^-1 * A(j)` with `A = Ry(yaw) * Rx(pitch)`. Do not stack relative `Rx*Ry` per joint: a yaw on a
  pitched plate then tilts the whole tail (the first version sank legs 0.7 studs this way).
- Per-axis steps are clamped at 0.25. `BloodCentipede.lastMaxStep` is the biggest step the last pose asked
  for before the clamp. Worst case in QA: 0.263, a hard run turn (1.6 rad/s) on top of the wave.
- Planting: JointRoot's translation is solved so the tail end (loops: plate 6) stays at its rest spot,
  lowered by `sink` and moved by `slideZ`; the body is recentred sideways by `cx` (0.6) of its mean offset.
  A reared front or a curl never floats or slides the tail by itself.
- Burial: `sink` 3.4 hides everything (antenna tips at 2.9). QA: BurrowDive ends at top -0.25; Erupt
  starts at top -0.23.
- Legs: swing is Y (`side * swing`), lift is Z (`side * lift`); left lifts with -Z. X swings a leg only
  through its 0.84 stud drop, so it is barely used. Leg ripple: plate i is `lag * i` behind plate 0
  (0.9 rad), the right leg half a cycle after the left, and the legs of the reared plates scrabble.

## Loops

| Loop | Wave | Legs | Notes |
|---|---|---|---|
| idle | 0.07 rad, 13 stud, slow | tiny shuffle, a ripple front to rear every ~5.5 s | head scan, antenna flicks, a pincer click every ~3 s |
| walk | 0.55 rad, 15 stud | 3 leg cycles per wave cycle, swing 0.55, lift 0.6 | lateral swing 0.8 studs at the head, 1.7 p-p mid body |
| run | 0.45 rad, 12 stud | swing 0.62, lift 0.7 | |

`gaitRate` = 2 pi (0.39 + 0.056 speed): walk at 6 studs/s is 0.73 Hz (legs 2.2 Hz, 0.07 s per plate), run at 18
is 1.4 Hz (legs 4.2 Hz, 0.03 s per plate). Measured over a phase sweep the wave peak moves
rearward about 0.45 rad per plate (a real travelling wave with lag). The brief's "0.3 s per segment" is
slower than a 2-4 Hz leg cycle can show (it would alias), so the lag is a fraction of the cycle instead.
The wave runs a little faster than the ground speed (6 studs/s walks a 11 stud/s wave), so the plates
shimmy a little against the ground instead of following one groove; the body trails the head through
turns with the travel-heading history (`input.yawAt`, a step of at most 0.07 per joint).

## Moves (seconds)

| Move | windup | active | posed recover | Notes |
|---|---|---|---|---|
| PincerSnap | 0.60 | 0.10 | 0.80 | front 9 plates rear to 1.1 rad (63 deg), pincers 0.86 open (rest 0, -0.5 shut), 1.15 stud pull-back; the bite lunges 2.6 studs and slams the jaws to -0.48 in 0.075 s |
| CoilSweep | 0.90 | 0.15 | 0.85 | rear 0.9, the tail half curls 1.35 rad x 1.12 with 0.028 s per plate lag; the sweep crosses to -1.35 x 1.1 in 0.24 s with 0.008 s per plate lag, rings, and unwinds to rest by 1.0 s after the active began (the end of the recover) |
| BurrowDive | 0.50 | dash secs | 0.30 | rears to 1.14 rad with the head tipped over; the dive is timed in seconds from the dash start (head plunge 0.12 s, buried by 0.45 s, compressed down to 0.45x for a short lane); underground it runs a fast wave |
| Erupt | 0.70 | - | 1.10 | starts at sink 3.4; the chain inclines (rearN 13) and the tail leaves the hole last; at u = 1 the front is reared 1.1 rad, the rear half is on the ground (low -0.11); the recover crashes down in 0.13 s |
| Stagger | - | 0.40 | - | head thrown away from `input.side`, a fast rearward ripple (`wph = 34 t`) |
| Death | - | 2.0 | hold | rears and flails, writhes, collapses at 0.8 s, curls to 1.9 rad (the tail toward the head's side), legs folded up 1.15, antennae down, twitches die by 1.8 s |

EnemyAnimator plays an attack's active beat first inside the server recover, so the posed recover is
(server recover - active) seconds: PincerSnap 0.9 -> 0.1 + 0.8, CoilSweep 1.0 -> 0.15 + 0.85.
Erupt has no active, so its recover is the server's 1.1 s whole.

## QA (`qa_blood_centipede_poses.luau`)

Poses the real template by FK over 547 poses (each move phase every 0.05 of u, both sides for
Stagger/Death, a short burrow lane, walk 3/6/11 and run 14/18 at 16 phases with and without a 1.6 rad/s
turn, idle at 61 clocks) and flags plate steps over 0.25, plates under the ground (-0.02) or feet,
pincers and antennae under -0.15 (rest is -0.07), a floating body, gaps between a plate and its parent,
clips and merges. Result: 2 flagged (the clamped hard run turn above), 0 sunk, 0 gaps, 0 clips.
`keyframe_test`: keyable (43 joints).

## Untested / requests

- Nothing was watched in Play; the feel, the blend into EnemyAnimator's smoothing, foot skate at speed
  (legs are not planted, they ripple) and phone cost (43 transforms per frame, 42 of them cheap) are the
  user's to judge.
- While `Burrowed` and not mid-move the loops draw the surfaced body (EnemyAnimator does not pass
  `Burrowed` to the module). The attacks carry the burial themselves. Request: if the designer wants a
  buried idle or crawl, pass `input.burrowed = model:GetAttribute("Burrowed") == true`, and the module can
  add `sink = 3.4` to the loops (ask and it is a three-line change).
- `staggerSeconds = 0.4` and `deathSeconds = 2.0` in the FAMILIES line must match the module.
