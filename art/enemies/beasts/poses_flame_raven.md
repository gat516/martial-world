# Flame Raven poses (`src/client/EnemyPoses/FlameRaven.luau`, shared stroke in `Flap.luau`)

Header of the module has the move list and the FAMILIES line. Numbers only, no visual review yet.

## Wing stroke (Flap.cycle)
- Down-stroke is 40% of the cycle (power, fast), up-stroke 60% (recovery). Elbow trails the shoulder by 0.85 rad of cycle, the wrist by 1.7, and they swing further (k 1.15 / 1.3): the wing bows up on the down-stroke, the tip droops on the up-stroke.
- Sweep: wings are back at the top of the stroke and forward at the bottom. **Sign (measured): back = +Y on L, -Y on R** (the brief had it reversed).
- Body follows: rises just after the down-stroke (bob 0.2), pitch +-0.05, gaze held level, tail fan flutters a beat behind (pitch 0.22 + roll 0.14), legs trail, crest flutters.
- Rates: idle 15 rad/s (2.4 Hz), walk 16+0.4v, run 20+0.25v, circle 18.

## Moves (u over the real phase seconds)
| Move | windup | active | recover | Notes |
|---|---|---|---|---|
| TalonDive | 0.8 | 0.55 | 1.2 | 0.1 s gather dip, 3 power strokes climbing 2.6, wings cocked up/back (1.3 rad, swept 0.5), hang with head down, talons forward, tremble from 0.5 s. Stoop: wings fold back, pitch -0.7 flattening, last 0.15 s air-brake flare. Recover = the perch. |
| TalonRake | 0.35 | 0.12 | 0.88 | cock (legs back, beak wide) -> talons thrust forward + hard down-stroke -> follow-through then the same perch |
| TalonDiveSkid | - | - | 1.2 | LEAD: brake flare, head snaps to live targetYaw and leads, body banks, hard strokes; rises 0.5-0.9 |
| EmberFan | 1.0 | 0.1 | 0.8 | coil, wings overhead (1.55 rad), chest rears, crest stands, held trembling from 0.7; flick 1 in active, flicks 2/3 at +0.05/+0.2 s of recover (the barrage's 0.15/0.3 s) |
| WindGust | 0.5 | 0.1 | 0.6 | back-swept cock, nose up; one huge forward down-stroke; second stroke |
| Hop | - | 0.3 | - | two quick strokes, nose up |
| Stagger | - | 0.28 | - | thrown back, near wing flung higher |
| Death | - | 1.4 | - | flail, spiral, belly-down on the ground (JointRoot Y -3.05), wings flat |

## Contracts / gotchas
- **Perch drop**: the server drops the root 1.5 after a dive (designer, ce37fee). The module keys NO perch drop: the perch is droop only (wings half open, head hanging, tail down, panting, pitch +0.18). The skid recover rises 0.5-0.9 so the legs stay clear of the ground with the drop on.
- Death drops JointRoot 3.05 (the talons then rest on Y 0). Numeric QA: lowest point -0.01.
- Climb +2.6 on JointRoot Y is fine (talon dive windup). Keep the shoulder, elbow and wrist joint smoothing fast (see requests).
- Clipping QA (`qa_fliers_poses.luau`): outer wing parts vs body: clean in every phase and loop sample. The shoulder bones sit inside the body, so they overlap it by design (not counted).
