# Frost Spider pose notes

Module: `src/client/EnemyPoses/FrostSpider.luau` (header has the full move and API notes). QA:
`art/enemies/beasts/qa_frost_spider_poses.luau` (`_G.QA` = rig / moves / loops / skate / timing, run in a sandbox).

FAMILIES line (EnemyAnimator, Template `FrostSpider`):

    FAMILIES.FrostSpider = { poses = FrostSpider, scale = 1, runFrom = 9, keyedBlend = 0.08, deathSeconds = 1.3,
        staggerSeconds = 0.35, moves = { webShot = "WebShot", frostFang = "FrostFang", hop = "Hop", frostFangSkid = "FrostFangSkid" } }

## Moves (designed seconds)
- WebShot: windup 0.9 (crouch 0.16, abdomen climbs to -0.64 with front legs up by 0.5, held beat with a quiver),
  active 0.22 (abdomen thrusts +0.34, body lurches), recover 0.7 (damped abdomen bounce; the engine shortens it by the active).
- FrostFang: windup 0.7 (coil 0.14, rear up to pitch 0.62 with front four legs up, fangs spread), active 0.3
  (fall forward, front legs rake in, fangs snap shut at 0.8-0.95), recover 0.9 (worrying shake, release). FrostFangSkid: a braking slide.
- Hop: active (flight time) a fast backward tetrapod run, about 4.6 steps/s, body low.
- Stagger 0.35, Death 1.2 (legs buckle, body sinks, legs rise then curl over the back).
- Loops: idle (taps, feeling front legs, breath), walk/run (tetrapod, planted), circle (side scuttle, dir +1 = left).

## Gotchas
- Legs are solved by two-bone IK (module-owned; Quadruped.plant is 4-legged): a key gives `plant` + `reach` per leg tag
  (L1..L4 left, front = 1). Planted reach is world space, free legs body space. The foot counter-rotates against the leg
  chain AND the body's own rotation, so soles stay level (without the body term, feet sank 0.04 on a pitched body).
- Adjacent same-side feet are 2.1-2.4 apart: strides over about 0.85 half-stride make neighbouring knees touch; alternate
  legs sit 0.3 further out in the gait.
- Abdomen over -0.62 clips the hip of leg 3 slightly (0.26); the Death root drop stays under -0.85 with the abdomen at -0.1.
- Death: the quick curl passes through a tangled frame or two around u 0.75 (knees overlap, no sink).
- Untested: feel in Play, blend with EnemyAnimator smoothing, phone cost (24 leg joints solved per frame, about 16 IK solves).
