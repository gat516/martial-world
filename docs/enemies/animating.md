# Animating enemies: motion QA and solver pitfalls

The lessons from the boss and roster animation passes. Read it before keying a
family's poses or probing their motion. Each rig's own joints, signs and safe
ranges are in `art/enemies/<group>/RIGS.md`, and the enemy system is in
[enemies](../systems/enemies.md).

## Probe motion, not just poses

Static pose QA (lowest point, continuity tables) misses motion bugs. On the Jade
Jiao (2026-10-22), every top problem showed only in motion: a 1260 studs/s
spin-back, a dead frame at each release, an idle pop.

- **Run `art/enemies/motion_probe.luau` first on any keyed family.**
  - Set `_G.MOTION = { module, template, def, scale, keyedBlend, seamless, heroes, moves }`.
    The Ape's config is the example, with heroes `HandFR.FistR_FX`,
    `Skull.Mouth` and `Chest.Core`.
  - Use `lows = true`. Static key QA passed poses whose blend put a fist 6.8
    studs underground (Thunder Ape).
  - Use the probe's `setup` hook for families with a `configure` step
    (otherwise the tail geometry is wrong), and its `steps` list.
- **Probe the real state timeline:** windup, dash, recover, the keyed blends
  between them and the hand-off into idle, sampled per frame with part speeds
  and joint steps.
- **Probe the loops too** (walk, gallop, circle), not only attacks.
  - Scan per-joint steps at 60 Hz over `M.sample(move, phase, u)`. 30 Hz
    under-reports flips: the Elder Wolf King's walk flipped its lower legs 60
    degrees at every footfall while every attack probe was clean.
  - A variant probed at 0 studs/s isn't moving. An overlay on a planted joint
    is silently undone by the plant solve.
- **Read the per-frame speed of every hero tip** (each tail and limb tip), not
  only the mouth and chest. One frame at 500+ studs/s among frames near 50 is a
  branch jump, even when the joint-step summary and `lows` look fine (Nine-Tailed
  Fox).
- **Rough speed budget:** a hero part at most ~600 studs/s at contact, and no
  one-frame joint step over ~45 degrees outside deliberate snaps.
- **Compare pose QA against HEAD, not absolute allowances.** Push HEAD's source
  into the sandbox module, run the QA, then restore yours, so only new flags
  show.

## Blending and `seamless`

- **The keyed blend at windup -> recover restarts from the frozen last windup
  frame** and kills follow-through on keyed families (a strike went 321, then 0,
  then 7 studs/s).
  - EnemyAnimator's family flag `seamless` plays one attack's phases straight
    on. Try it on any keyed family with a hitch at release.
  - After switching it on, probe every move again: it exposes pops the old
    blend hid.
  - `seamlessStrike` is the variant for families with dashes: stationary
    strikes run straight on, and dash phases keep their blend.
- **Land a strike on the windup's end (W).** Never "contact at W-0.02, then
  hold": that leaves a dead frame seamless blending can't hide.
- **Express overlap lag as a fraction of the phase** (capped near 25%), not in
  absolute seconds, or short phases break.
- **A pose that grows with time spent still needs a clock that excludes attack
  time.** `still` counts attack time, so idle loops pop after long moves. Use
  `calm`: seconds still and out of any move.
- **The `snap` ease is fastest at its start.** It suits a head strike that hits
  and holds, or a teleport on a whip or lash (use `in`).
- **Weight chain coverage by arc length**, not by whole segments, or rings pop.

## Planting and IK

- **Reuse the wolf's `plant` solver** (two-joint IK, root drop, floor clamp) and
  `wolf_family/qa_wolf_poses.luau` for new families instead of rebuilding them.
  Pose tables live in `src/client/EnemyPoses/<Family>.luau` (format in the rig's
  RIGS.md).
- **Test which way a middle joint compresses near rest** before authoring planted
  poses. RIGS.md sign notes have been wrong (the wolf's hind knee).
- **Leg bend flips between a solver's two solutions.**
  - A planted limb blended toward a free one passes through "straight down".
    The solver takes the bend nearest the authored angle, so give planting keys
    an authored elbow or knee near the planted solution, or it flips mid-blend.
  - `Quadruped`'s opt-in `steady = true` (the King only; notes in
    `wolf_family/RIGS.md`) carries a foot on an arc and keeps the natural fold.
    It isn't a drop-in: adopting it needs that family's own probe and pose QA.
- **An IK or aim solve that picks between branches must stay continuous.** Find
  the solution once on a fixed side, then blend params from the keys to it.
  Re-solving every frame at blended targets near a singular point jumps.
- **A free leg lying near the floor** (curled, sitting, on its side) fights the
  floor clamp every frame. Plant it with a sliding reach, or skip the clamp
  (`air`) for that phase.

## Studio gotchas

- `FindFirstChild(name, true)` can return a Motor6D named after its part. Search
  for BaseParts when you mean the part.
- If a new module under `src/` doesn't appear, push it into the sandbox (the
  `sandbox-studio` skill). In a Rojo-connected Studio, ask the main session to
  have the user reconnect Rojo; don't work around it.
- Rebuilding a template from its build script replaces the live copy. Check the
  live copy for the user's hand edits first, and never overwrite the user's own
  Moon Animator work or AnimSaves.
- `EnemyAnimator.luau`, `Quadruped.luau` and `Serpent.luau` are edited by
  several animators at once. Commit only your hunks (the `shared-commit` skill).
