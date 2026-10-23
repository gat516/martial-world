# Enemy audit briefs, 2026-10-23

One brief per item of the ranked list in [audit-2026-10-23.md](audit-2026-10-23.md); the
numbers they cite (the "now" values) are in that file's per-enemy tables.

Paste one brief into a fresh agent. Every brief also carries the shared lines: post a
`## Status:` line at each phase; capture only for the final sheet; don't edit `.claude/`;
commit on your branch with the `shared-commit` skill, don't merge or push; report with
`agent-report`. **Metric targets** come from `art/enemies/motion_audit.luau` (or
`motion_probe.luau` with the family's spec in `motion_specs.luau`); run the family before and
after, and paste both tables in the report.

### A1 Thunder Ape motion (animator, boss)
- **Goal:** the 30-stud storm ape moves with weight and overlap: big blows load back, swing
  through and settle, and nothing snaps faster than the eye reads. The player should feel a
  heavy beast, not a twitch.
- **Sandbox:** the `studio_id` the main session opens for this task. **Worktree:** fresh off `test`, branch `ape-motion`.
- **References:** `docs/reference/animation/beartiger.rbxm` (timing, arcs); the audit's Thunder
  Ape table; the open list in `docs/enemies/thunder-ape.md`; `art/enemies/beasts/rigs/thunder-ape-b.md`.
- **Exemplar:** the Spirit Wolf pass (`src/client/EnemyPoses/Wolf.luau`, "that was amazing"). Must not
  resemble the rejected Elder Wolf King first clips ("so stiff") or the ape that "jumps around and THEN rotates".
- **Do not change:** the body, the def timings (unless a move can't fit: then propose the
  windup change in the report), effect hooks and cue timings, the boulder release at 1.25 s.
- **Clips and attack table (ms, windup / active / recover / cooldown):** thunderPound 850 / - / 1300 / 2650;
  backhand 600 / - / 450 / 1100; clubSwing 800 / - / 450 / 1300; boulderHurl 1700 / - / 900 / 3200;
  thunderLance 1400 / - / 900 / 2900; thunderRush 1200 / 674 / 900 into rushSwipe 400 / - / 900;
  skyfallSlam 1200 / 750 / 1100 into skyfallSweep 500 / - / 1000; bound 450 / 550 / 350;
  thunderRoar 1300 / - / 1000; Stagger 450; Death 3200. Family flags (FAMILIES): scale 3.71,
  keyedBlend 0.06, seamless, motion. The pose module owns every joint; heroes `HandFR.FistR_FX`, `Skull.Mouth`, `Chest.Core`.
- **Stiffness checklist:** anticipation, chain lag (hips > chest > skull +1..+4 frames), overshoot and settle, landing compress, turn in the air never after landing.
- **Done means (metrics):** fist peak at most 600 studs/s in every move (now 937 pound, 778 rush,
  729 lance, 718 hurl); no one-frame joint step over 45 deg (now 83 in pound and backhand);
  no `BLOCK` on boulderHurl, bound, thunderLance, thunderRoar, Stagger; no hero stop inside a
  windup (boulderHurl fist x3, clubSwing chain); skyfallSlam land dip at least 0.5 studs (now
  stiff); lows above -0.5 except Death; plus the doc's chest-beat arm and beard clips. Filmstrip
  of thunderPound and boulderHurl (two images each) for the critic; `tools/check.sh` clean;
  `docs/enemies/thunder-ape.md` open list updated. `Test build: Thunder Ape (testbed) - pound, backhand, boulder, lance, rush, skyfall, roar; watch for snaps and stiff landings.`
- **Variants:** no (exact metric targets).

### A2 Nine-Tailed Fox motion (animator, boss)
- **Goal:** the fox fights like a dancer: body, neck and head ripple into every strike and the
  tails follow, instead of the whole body turning as one piece and the head freezing.
- **Sandbox / worktree:** the main session's `studio_id`; branch `fox-motion` off `test`.
- **References:** `beartiger.rbxm`; the audit's fox table; `docs/enemies/nine-tailed-fox.md` open list; `art/enemies/quadrupeds/rigs/nine-tail-fox-b.md`.
- **Exemplar:** Spirit Wolf pass. Not like the King's rejected "twitching" stun loop.
- **Do not change:** the body and tails' build, def timings (the doc's wanted def changes,
  rendingPounce windup 750 -> about 1000 and moonLeap recover 400 -> about 600, go in the report
  as a proposal), the `configure` tail layout, effect cues.
- **Clips (ms):** fangDance 650 / - / 1200; tailSweep 900 / - / 1100; tailLance 600 / - / 800;
  foxfireVolley 1100 / - / 1000; rootfireEruption 1500 / - / 1600; mournfulScream 1400 / - / 1600;
  nineTailFall 1800 / - / 2000; veilBreak 1600 / - / 1000; moonLeap 400 / 600 / 400; rendingPounce
  750 / 545 / 1000; intro 2200 / - / 800; Stagger; Death 3200. Flags: scale 2.13, keyedBlend 0.06,
  seamlessStrike, fox. Heroes `Head`, `Tail5Tip`, `PawFR`.
- **Done means:** no `BLOCK` on the body chain (Hips > Chest > Neck > Head) in any of the ten
  listed moves; the head stops dead at most once per move (now 4 in fangDance, 6 in the
  moonLeap volley); intro's first frame steps under 45 deg (now 95) and its hero under 60
  studs/s from rest; no leg step over 45 deg (rendingPounce 115, Death 100); rootfireEruption
  lows above -0.5; the doc's clip list re-measured. Filmstrip of fangDance (two images).
  `Test build: Nine-Tailed Fox (testbed) - fang dance, tail sweep, foxfire, rootfire, intro.`
- **Variants:** no.

### A3 Elder Wolf King motion (animator, boss)
- **Goal:** the King's heavy blows load, land and settle with its whole body; nothing stops dead.
- **Sandbox / worktree:** main session's `studio_id`; branch `king-motion` off `test`.
- **References:** `beartiger.rbxm`; the audit's King table; `art/enemies/wolf_family/RIGS.md` (King section, `steady` solver notes); `docs/enemies/elder-wolf-king.md`.
- **Exemplar:** Spirit Wolf pass. Rejected: the King's own first clips ("so stiff").
- **Do not change:** body, def timings, the left-forepaw rake, cue timings, the leap's hang.
- **Clips (ms):** pawSwipe 450 / - / 750; clawDown 550 / - / 850; crownfall 1250 / - / 1250;
  kingLeap 1100 / 700 / 1000 into kingRake 500 / - / 900; kingsRush 1000 / 600 / 1000 into kingRake;
  packCall 1200 / - / 1000. Flags: scale 2.4, keyedBlend 0.06, seamlessStrike. Heroes `Skull.Mouth`, `PawFR.PawFR_FX`, `Chest.Core`, `Seal.SealFX`.
- **Done means:** no `BLOCK` on body or tail in those six; no hero stops dead in any recover
  (now every hero in pawSwipe, crownfall, kingLeap, packCall); kingsRush rake's elbow step under
  45 deg (now 112) and the paw stops at most once (now 4); anticipation at least 0.15 studs on
  clawDown, crownfall and kingLeap (now none). Filmstrip of crownfall (two images).
  `Test build: Elder Wolf King (testbed) - swipe, claw down, crownfall, leap and rush into rake, pack call.`
- **Variants:** no.

### D1 Stone Tortoise: Jade Fault (enemy-designer, regular)
- **Goal:** the tank punishes kiting: a fault of jade spikes runs at you when you stand off,
  readable and dodgeable sideways. Its job: make the Tortoise a fight at every range.
- **Sandbox / worktree:** main session's `studio_id`; branch `tortoise-fault` off `test`, after A6 lands (same pose and effects modules).
- **References:** `docs/enemies/second-wave.md` (Tortoise), `docs/systems/telegraphs.md`, this
  audit's design read; `EnemyService.buildParts` (the `embers` / `lance` patterns are the models for a new `fault` pattern).
- **Exemplar:** the Spirit Wolf pass for clarity of tells; not the rejected neon ground crack
  ("kinda eh"): the fault is rock spikes erupting, not a glowing line.
- **Do not change:** the Tortoise's other four moves, its body, Shell Guard.
- **Contracts:** the attack table under "Two new attacks" in the audit (name `jadeFault`, pattern `fault`,
  one windup cue whose 4 boxes are in `shape.parts` with `delay` 0 / 0.12 / 0.24 / 0.36, `seconds`
  = windup only, release at the windup's end). Move name `JadeFault` in `EnemyPoses/StoneTortoise.luau`
  (unit space, scaled 1.76 once); hooks `FootFL_FX`, `FootFR_FX`, `NeckBase_FX`, `SeamTell*`.
  Sound `SFX.Enemies.StoneTortoise.Attack_jadeFault`. Behind the existing `NEW_TORTOISE` flag.
- **Briefs to hand back:** animator (JadeFault windup: rear 0-800, loaded hold 800-1100, both fore
  feet land on W = 1100; active 150 compress; recover 1400 settle with a step back; metric
  targets: body not `BLOCK`, antic at least 0.1, no hero stop in recover); vfx (windup pebbles at
  the fore feet and the seam sweep; release: a dust burst at the fore feet, then each box erupts
  jade rock spikes and grit at its own delay, read from `shape.parts`; hit: HitJade; earth and
  jade palette, the existing StoneTortoise templates for reuse).
- **Done means:** defs, `fault` pattern, telegraph draws the 4 boxes in sequence, pool order as
  above, sound, effects and pose hooked in; `tools/check.sh` clean; `docs/enemies/second-wave.md`
  table and enemies.md "Attack mechanics" (`fault`) updated.
  `Test build: Stone Tortoise (testbed TortoiseSolo) - back off past 14 studs; the jade fault should run at you, dodge sideways.`

### A4 Jade Jiao motion (animator, boss)
- **Goal:** the serpent's tail ripples behind every move instead of swinging as a rigid beam,
  and the sweep and shove read as whips, not teleports.
- **Sandbox / worktree:** main session's `studio_id`; branch `jiao-motion` off `test`.
- **References:** the audit's Jiao table; `docs/enemies/jade-jiao.md` open list; `art/enemies/beasts/rigs/jade-jiao.md`; `Serpent.luau`.
- **Exemplar:** Spirit Wolf pass. Rejected: the cobra-hood rebuild (no body change).
- **Do not change:** the body (the user's own snake), the coil radius, def timings, cues.
- **Clips (ms):** venomLance 700 / - / 800; venomFang 750 / - / 900; tailShove 700 / - / 800;
  pillarSlam 1000 / - / 1300; tailSweep 800 / - / 1000; dreadHiss 1100 / - / 900; venomSpray
  1000 / - / 1200; venomPools 1000 / - / 900; molt 1600 / - / 900; ascension 2000 / - / 1000;
  Stagger 400. Flags: keyedBlend 0.2, seamless. Heroes `Skull.Mouth`, `Tail18.TailTip_FX`, `Body.Core`.
- **Done means:** tail chain (Body > Tail1 > Tail2...) not `BLOCK` in any of the ten; tail tip
  at most 600 studs/s (tailSweep 1173, tailShove 834) and no hitch; venomFang's mouth and core
  don't stop inside the windup; pillarSlam lows above -0.5 (now -1.1 for 25 frames); venomPools
  without hitches; plus the doc's coil QA re-run. Filmstrip of tailSweep (two images).
  `Test build: Jade Jiao (testbed) - tail sweep, tail shove, venom fang, pillar slam, pools.`
- **Variants:** no.

### A5 Flame Raven motion (animator, regular)
- **Goal:** the raven dives like a bird of prey (wings fold, the body leads, the wings open to
  brake) and perches with its wings clear of the ground.
- **Sandbox / worktree:** main session's `studio_id`; branch `raven-motion` off `test`.
- **References:** the audit's raven table and the filmstrip read (wings straight up and still
  from W through the apex; wings dragged across the ground in the perch);
  `art/enemies/beasts/rigs/flame-raven.md`, `poses_flame_raven.md`; enemies.md "Flier height" (the server's perch drop of 1.5).
- **Exemplar:** Spirit Wolf pass.
- **Do not change:** body, def timings, the perch value, the hover root height.
- **Clips (ms):** talonDive 800 / up to 588 / 1200 into talonRake 350 / - / 1000, and its skid;
  windGust 500 / - / 700; emberFan 1000 / - / 900; Stagger 300; circle loop at 8 studs/s.
  Flags: keyedBlend 0.08, loopSmoothing 60. Heroes `Skull.Mouth`, `Body.Talons_FX`, `WingTipR.WingTipR_FX`.
- **Done means:** no hero stops dead during the dive; wing chain (Body > UpperWing > ForeWing >
  WingTip) not `BLOCK`; lows above -0.5 in every move and loop, perch included (now -3.2, and
  -2.4 in the circle loop); shoulder steps under 45 deg (now 107-114); a land dip at least 0.2
  on the perch (now stiff). Filmstrip of talonDive with the skid (two images).
  `Test build: Flame Raven (testbed RavenSolo) - dive and perch, gust, ember fan, circling.`
- **Variants:** no.

### M1 Part faults on every body (enemy-modeler, boss + regular)
- **Goal:** no floating or flickering parts and no missing effect hooks, with every silhouette
  exactly as it is.
- **Sandbox / worktree:** main session's `studio_id`; branch `body-faults` off `test`. Run alone
  among body work (it exports `assets/Enemies.rbxm`, a shared binary).
- **References:** the audit's "Body" lines; `docs/enemies/modeling-checks.md`; each body's RIGS.md.
- **Exemplar:** the bodies themselves (they are the user's reference row and approved bodies).
  Rejected: any redesign ("BRO WHYAAAAGH").
- **Do not change:** any silhouette, colour, size, joint, pivot or part name; no added armour or detail.
- **Fixes (all 12 templates in `ServerStorage.Enemies`):**
  - Hooks: add `Core` (Attachment, body centre) to `VenomSerpentB.Body`; add `PawFL_FX` and
    `PawFR_FX` (sole of the paw) to `SpiritWolfB` `PawFL` / `PawFR`; document the King's
    `PawFL_FX` / `PawFR_FX` in `wolf_family/RIGS.md` and the new hooks in their rig docs.
  - Floating: `ThunderApeB` ChestSigil3, ChestSigil5 (seat them in the chest plate); kissing
    BackBolt1-2, KnuckleL2/R2, ChestRivet5-8 (sink 0.05).
  - Shell slit: `StoneTortoiseB` Cap, Dome, Crag1-4, CragMoss1-2, CapMoss, DomeMossL/R, CapEnd±1,
    CapSide±1, SeamTellCrackCap and the DomeSide / SeamTellCrack11-12 kisses: sink each 0.05 into its neighbour.
  - Flicker (coplanar, different colour): inset the smaller part 0.01-0.02 on BloodCentipede's 13
    `Seg*Cap` / `CollarCap` / `TailCap`, ShadowManeWolfB's 18 pairs, NineTailFoxB's 36 tail fur /
    tip pairs and ears / belly, ElderWolfKingB's 21, ThunderApeB's 8, JadeJiao's 7 skull pairs,
    SpiritWolfB's 9, VenomSerpentB's 5, FlameRavenB's 3, BloodBat Body / Chest, StoneTortoiseB Rim / NeckUnder.
  - Check only (leave if intended): BloodBat `MouthTell` hidden at rest; boar lower tusks hidden.
- **Done means:** `tools/parts_audit.luau` on all twelve: 0 floating, 0 loose, 0 different-colour
  z-fights, hidden list unchanged except as above; `check_rig` clean; `tools/vfx_hooks_check.py`
  reports no missing hook for SpiritWolf and VenomSerpent and `tools/vfx_origin_check.luau`
  passes `VenomSerpent.StaggerFlash` / `Death`; exported to `assets/Enemies.rbxm` via staging.
  No `Test build:` (no fight change) beyond "look at the Ape's chest and the tortoise shell up close".
- **Variants:** no.

### A6 Stone Tortoise motion (animator, regular)
- **Goal:** a heavy tank that moves in layers: the shell, then the neck, then the head; the stomp lands, shudders and settles.
- **Sandbox / worktree:** main session's `studio_id`; branch `tortoise-motion` off `test` (before D1).
- **References:** the audit's tortoise table; `art/enemies/quadrupeds/rigs/stone-tortoise.md`.
- **Exemplar:** Spirit Wolf pass. **Do not change:** body, def timings, the guard's `hitAt` flinch.
- **Clips (ms):** neckSnap 700 / - / 900; quakeStomp 1200 / - / 1400; shellGuard 500 / hold 2000 / 500
  into shellSnap 350 / - / 1000; Stagger; Death. Flags: scale 1.76, guard, turnInPlace. Heroes `Head.Mouth`, `FootFR.FootFR_FX`, `Shell.Core`.
- **Done means:** body and tail not `BLOCK` in any attack (now all); no hero stops dead in
  quakeStomp's recover; neckSnap anticipation at least 0.05 on the mouth (now still); the
  snap's mouth doesn't stop inside its windup. `Test build: Stone Tortoise (testbed TortoiseSolo) - snap, stomp, guard into snap.`

### D2 Blood Centipede: Underpass (enemy-designer, regular)
- **Goal:** a second dive the player has to read: the mound passes under them and the
  centipede bursts up behind. The fight stops being one memorised answer.
- **Sandbox / worktree:** main session's `studio_id`; branch `centipede-underpass` off `test`, after A8.
- **References:** `docs/enemies/third-wave.md`; enemies.md "Burrow for a regular beast"; `docs/systems/telegraphs.md`.
- **Exemplar:** the Spirit Wolf pass. **Do not change:** pincerSnap, coilSweep, burrowDive, erupt, the body.
- **Contracts:** the Underpass table above (`underpass` burrow, `stopPast = 7`, followUp `backlash`,
  alternation with `burrowDive`). `EnemyAnimator` map `underpass = "BurrowDive"`, new move
  `Backlash` (rises already turned, rears the front segments, pincers rake down and back);
  sound `Attack_underpass`; behind `NEW_CENTIPEDE`.
- **Briefs to hand back:** animator (Backlash windup 900: rise and turn 0-500, rear 500-900, strike
  on W; recover 1200 with the front on the ground; targets: segs not `BLOCK`, no hero stop in
  recover, antic at least 0.1); vfx (reuse BurrowMound / CrackStamp for the dive; Backlash: the
  Eruption set at the surface point, turned to face the target, the crimson and bone palette).
- **Done means:** defs, alternation, telegraph (lane past the player, then the circle), pose and
  effects hooked in; check.sh clean; third-wave.md and enemies.md updated.
  `Test build: Blood Centipede (testbed CentipedeSolo) - it should alternate: one dive erupts under you, the next behind you.`

### V1 Thunder Ape effects (vfx, boss)
- **Goal:** the lance bolt reads as one bolt leaving the hand, and the boulder's shatter has its own hero texture.
- **Sandbox / worktree:** main session's `studio_id`; branch `ape-vfx` off `test`.
- **References:** `tools/vfx_specs/ThunderApe.luau` (layer sheet), `docs/vfx/style.md`, `docs/reference/vfx/`; `docs/enemies/thunder-ape.md` effects.
- **Exemplar:** the Elder Wolf King first effects pass ("that's really good"). Rejected: ghost
  body copies, flat discs, effects "thrown all over the place".
- **Do not change:** every other Thunder Ape template, the palette, the cue timings.
- **Contracts and beats:** thunderLance windup 1400 ms (the lance forms at `HandFR.FistR_FX`;
  it fires from 16 ahead and 3.5 up), bolt `LanceBolt`; boulderHurl windup 1700, release 1250,
  impact `BoulderImpact`. Hooks: `FistR_FX`, `FistL_FX`, `Mouth`, `Core`, `ChestBeatL/R_FX`.
- **Done means:** `vfx_origin_check` passes `ThunderApe.LanceBolt` (state the bolt's length in an
  Authored* size attribute, or bring Head / Dark / Glow / Core within its bound);
  `vfx_texture_audit` passes BoulderImpact.Shatter (a non-top-10 id, the one the spec names);
  roles marked; critic SHIP; exported to `assets/Effects.rbxm` with `effects_merge`.
  `Test build: Thunder Ape (testbed) - thunder lance and boulder impact.`

### V2 Jade Jiao effects (vfx, boss)
- **Goal:** the Jiao's charge-ups have their own look, and every gather sits on the body.
- **Sandbox / worktree:** main session's `studio_id`; branch `jiao-vfx` off `test`.
- **References:** `tools/vfx_specs/JadeJiao.luau`; `docs/enemies/jade-jiao.md` effects open list.
- **Exemplar:** Elder Wolf King first effects pass. Rejected: ghost copies, flat discs.
- **Do not change:** the venom bolt drawer, palette, cue timings.
- **Beats:** venomLance windup 700 (gather), venomSpray 1000, venomPools 1000 (SpitGather), the
  QiGather; hooks `Mouth`, `Throat`, `FangL/R_FX`, `HoodL/R_FX`, `Core`, `TailTip_FX`.
- **Done means:** SpitGather.Core and QiGather.Core off the stock glow (`vfx_texture_audit` clean
  for JadeJiao); the venomLance windup's gather on a named hook (now 7.7 studs above the root,
  11.9 from the nearest hook) or the report says why it floats there; the aura `Under` disc
  checked against the no-flat-disc rule (removed or replaced); roles marked; exported.
  `Test build: Jade Jiao (testbed) - lance, spray, pools windups and the aura.`

### A7 Shadow Mane Wolf motion (animator, regular)
- **Goal:** the flanker settles out of its rends and lash instead of freezing, and its run stays on the ground.
- **Sandbox / worktree:** main session's `studio_id`; branch `mane-motion` off `test`.
- **References:** the audit's mane table; `art/enemies/wolf_family/rigs/shadow-mane.md`; Wolf.luau's `plant` solver.
- **Exemplar:** Spirit Wolf pass (same family). **Do not change:** body, timings, the step-rake overlap (it's good).
- **Clips (ms):** maneRend 600 / - / 1000 (second cone +350); maneLash 800 / - / 1100; shadowStep
  700 / up to 578 / 900 and its skid; walk at 9, run at 20. Flags: scale 1.63, keyedBlend 0.06.
- **Done means:** no hero stops dead in rend or lash recovers; lash root anticipation at least
  0.05; run lows above -0.5 (now -0.87 for 17 frames); walk and run body not `BLOCK`; skid
  elbow step under 45 deg (now 111). `Test build: Shadow Mane Wolf (testbed ManePair) - rend, lash, the run, flank skids.`

### V3 Fox and King effects (vfx, boss)
- **Goal:** the last generic hero layer and the one misplaced layer on the two bosses fixed.
- **Sandbox / worktree:** main session's `studio_id`; branch `fox-king-vfx` off `test`.
- **References:** `tools/vfx_specs/NineTailFox.luau`, `ElderWolfKing.luau`; both boss docs.
- **Exemplar:** Elder Wolf King first pass. Rejected: ghosts, flat discs, halos.
- **Do not change:** everything else in both groups.
- **Beats:** fox TipCharge (tail tips `TailTip1-9_FX`, the barrage windups 600-1800 ms);
  King RushTrail (kingsRush dash 600 ms, `Chest.Core`); King packCall strike (1200 ms windup).
- **Done means:** TipCharge.Core off the stock glow; RushTrail.BowRing within its bound of the
  Core hook (now 10.5 off, bound 4.5); Pack Call's 11-stud flat ground ring checked against the
  no-flat-disc rule (keep only if it reads as a ground wave caused by the call; else replace);
  the King's 7 secondaries on top-10 ids reviewed; drop the unused `AuraGround` template; lints
  clean; exported. `Test build: Nine-Tailed Fox tail charges; Elder Wolf King rush and pack call.`

### V4 Second-wave effects (vfx, regular)
- **Goal:** the Mane's biggest blow lands with a visible slash, and the wave's specs say which layer is the hero.
- **Sandbox / worktree:** main session's `studio_id`; branch `wave2-vfx` off `test` (after D1 if it touched StoneTortoise effects).
- **References:** `tools/vfx_specs/ShadowManeWolf.luau`, `VenomSerpent.luau`, `StoneTortoise.luau`, `SpiritWolf.luau`, `StoneBoar.luau`; `docs/enemies/second-wave.md` effects.
- **Exemplar:** the Spirit Wolf pass (approved; its look doesn't change). Rejected: effects not from the paw or mouth.
- **Do not change:** any approved look (Spirit Wolf, Stone Boar): roles only there.
- **Beats:** shadowRake (arrive after shadowStep, windup 400 ms, release at W, from `PawFR_FX`).
- **Done means:** a `shadowRake` strike slash from the raking paw (it plays nothing at release
  now); a LAYER SHEET with roles in all five specs; `vfx_texture_audit` lists none of them as
  unmarked and flags no hero; exported. `Test build: Shadow Mane Wolf flank step into rake.`

### V5 Third-wave effects (vfx, regular)
- **Goal:** the raven's fire and the centipede's blood read as their own, not stock glows, on the rebuilt bodies.
- **Sandbox / worktree:** main session's `studio_id`; branch `wave3-vfx` off `test` (after D2 if it touched centipede effects).
- **References:** `tools/vfx_specs/FlameRaven.luau`, `BloodCentipede.luau`, `BloodBat.luau`; `docs/enemies/third-wave.md` (centipede palette note).
- **Exemplar:** the Spirit Wolf pass. **Do not change:** cue timings, ember lob timing, the bat's small budget.
- **Done means:** the raven's hero and secondary layers off top-10 ids (now 102 of its ~200
  emitters on the stock soft glow); the centipede's palette retuned to the crimson-and-bone
  rebuild; roles marked in all three specs; lints clean; exported.
  `Test build: Flame Raven and Blood Centipede effects.`

### A8 Centipede and Bat motion (animator, regular)
- **Goal:** the centipede's body ripples into its snap and its legs don't cross; the bat's wings bend and stay out of the ground.
- **Sandbox / worktree:** main session's `studio_id`; branch `wave3-motion` off `test` (before D2).
- **References:** the audit's tables; `art/enemies/beasts/rigs/blood-centipede.md`, `blood-bat.md`, `poses_blood_bat.md`; third-wave.md open items.
- **Exemplar:** Spirit Wolf pass. **Do not change:** bodies, timings.
- **Clips (ms):** centipede pincerSnap 600 / - / 900, coilSweep 900 / - / 1000, burrowDive into
  erupt 700 / - / 1100; bat bloodDive 600 / up to 467 / 800, Stagger 250, Death 1200.
- **Done means:** centipede segs not `BLOCK` in pincerSnap, no hero stop in its recover, erupt
  land dip at least 0.1, the leg pass-through and pincer cross gone; bat wing chain not `BLOCK`
  in the dive, Death lows above -0.5 (now -3.9 for 29 frames), wing steps under 45 deg, the
  stagger hand clear of the body. `Test build: Blood Centipede snap and dive; Blood Bat dive, stagger, death.`

### A9 Boar and Serpent polish (animator, regular)
- **Goal:** small overlap fixes on two shipped or near-shipped beasts.
- **Sandbox / worktree:** main session's `studio_id`; branch `boar-serpent-motion` off `test`.
- **References:** the audit's tables; `quadrupeds/rigs/stone-boar.md`, `beasts/rigs/venom-serpent.md`.
- **Exemplar:** Spirit Wolf pass. **Do not change:** bodies, timings, the serpent's loops.
- **Clips (ms):** boar charge 1000 / up to 545 / 700 into gore 600 / - / 800; serpent venomSpit 1100 / - / 600.
- **Done means:** boar body not `BLOCK` in charge and gore, the hoof doesn't stop dead in the
  dash, root anticipation at least 0.05, land dip at least 0.3; serpent spit body not `BLOCK`, no
  mouth stop in the windup, mouth anticipation at least 0.05.
  `Test build: Stone Boar charge and gore; Venom Serpent spit.`

