# Golden Toad poses

Module: `src/client/EnemyPoses/GoldenToad.luau` (Wolf.luau format, 1x real studs, scale 1). QA: `qa_golden_toad_poses.luau` (a copy of `quadrupeds/qa_quadruped_poses.luau` with the toad's config; run it in a sandbox after `tools/push_src.luau`). The header of the module has the moves, timings, API and the FAMILIES line.

## Moves (windup / active / recover, seconds)

| Move | Timing | Notes |
|---|---|---|
| TongueLash | 0.7 / 0.15 / 0.9 | gather 0-0.2, head lifts and jaw opens by 0.5 (jaw 0.58 then), sac swells, held beat 0.5-0.7 with a tremble; tongue z 0 -> -14 in 0.1 s (active u 0.67); recoil in 0.3 s (recover u 0.33), jaw snaps shut, two swallow pulses |
| Gulp | 0.35 / 0.1 / 0.8 | head reared, jaw 0.9; lunging snap; chew and swallow |
| BogCroak | 1.0 / 0.1 / 0.8 | crouch, sac inflates in heaves to 0.9 of its slide, strain tremble, croak thrust, decaying throat pulses |
| MiasmaLob | 1.0 / 0.1 / 0.8 | deep crouch, retching heaves, head rears 0.65-0.78, the gob leaves at windup 0.8 s, fling and follow-through to 1.0 |
| Hop | active 0.35 (air) + recover 0.3 | push, tuck, reach, touchdown planted; the module adds no arc (the client lifts) |
| Stagger | 0.3 | head thrown up, jaw open, lids shut |
| Death | 1.0, hold | legs give, body flops down, tongue lolls out |

Loops: idle (squat, sac breath, throat flutter, blinks, rare weight shift); walk (three-point: front, left hind, right hind, one at a time; shift +-0.3, roll 0.07, head bob); run (hop chain, 0.9 root arc, 0.4 of the cycle on the ground); `circle` aliases walk.

## Rules found

- The Quadruped.new solver cannot do this hind leg (a Z-fold with the knee forward of the hip: its height solve leaves the foot hovering). The module has its own two-bone solver in the leg's plane, a front-leg column solver, and a floor clamp for every leg.
- The planted hind foot sliding BACK of its rest spot drops the knee into the ground (knee ball bottom 0.55 at rest): all hind reach is forward (-Z) of rest in the walk (-0.5 bias) and in the lunging moves (-0.3 to -0.55).
- Shin and ankle ball: the QA treats Ball parts as spheres; a rotated ankle cube would sink.
- Sac slide: more than 1.0 gaps it off the body; a full swell with a deep crouch puts it on the ground (the croak and the lob crouch -0.2 to -0.45).
- Lifted feet: toes-up flex puts the toes into the belly and the sac, so no flex; lift 0.32-0.38.
- Body drop floor: -0.8 on the root is the lowest (Death).
- Back plates (bevels) overlap the shin by design (QA allows 0.6).
