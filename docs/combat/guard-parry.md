# Guard and perfect parry

Covers the guard, perfect and chain parries, guard break, their transport, animations, sounds and visuals; read it when working on guarding, parry timing, GuardFX or guard clips. The rest of combat is in [combat](../systems/combat.md); the guard bar UI is in [ui](../systems/ui.md).

Hold right click (PC), L2 (gamepad) or the touch Block button. Tuning:
`Config.Combat.GUARD`.
- The guard goes up only between actions and while free to act, and drops when
  an action starts or the player is staggered or stunned; while the input is
  held it comes back up by itself. Attacks and casts don't start while it's up;
  a dodge does. Walking at `MOVE` (half) speed, no sprinting, no Auto approach.
  The server enforces the no-sprint part too: `Movement.apply` drops the run
  bonus while the humanoid is `Guarding`, so a held Shift (or a client that keeps
  claiming to run) can't beat the slow (user, 2026-10-24).
  Right click still turns the camera when the mouse isn't locked (the binding
  passes the input on).
- Only enemy blows with a source (`Combat.hurt`'s `guard`, a `Guard.Hit` built
  by `guardHit` in EnemyService: every beast and boss hit through
  `hurtPlayer`/`hurtPart`) from in front can be guarded. Area strikes through
  `EnemyService.strike` (the Tribulation's bolts) can't. Where a blow comes
  from: melee from the beast; lunges, charges and leaps from where the beast set
  off, judged with the wider `DASH_DOT` (~117° either side), because the hit
  lands as the beast arrives on top of you (its position then read as beside or
  behind you, so charges often went through a raised guard); projectiles
  (bolts, lances, lobs and their splash) from where they were fired. Everything
  else within ~100° of facing (`FRONT_DOT`). Facing is the server's root or the
  facing the client last reported while guarding (within `LOOK_FRESH`),
  whichever passes: the replicated root is a ping or more behind a turn.
- **Facing while guarding**: without a lock-on you turn toward the beast winding
  up or dashing at you, else the nearest one, within `FACE_RANGE` of its edge
  (`FACE_TURN` sets how fast; GuardController writes `ActionState.guardFacing`,
  Movement applies it). Before, a free camera turned you the way you walked, so
  backing off with the guard up showed the beast your back.
- **Race grace**: an unguarded, guardable hit waits half the player's ping (at
  most `RACE_GRACE`) before it resolves and is judged at the server time it
  landed, so a guard or dodge pressed as the telegraph filled, still on its way
  to the server, counts. A raise up to `PARRY_LATE` after that time still
  parries (clock jitter). Nothing waits while the guard is up.
- **Blocked**: `CHIP` (15%) of the damage gets through, with no flinch or
  knockback; the meter drains by the hit's share of max health times `DRAIN`
  (times `HEAVY_DRAIN` for slams, charges and leaps), at least `MIN_DRAIN`.
  The meter refills at `REGEN` a second once `REGEN_DELAY` has passed since the
  last drain, at half that while guarding.
- **Guard break**: a blocked hit that empties the meter drops the guard, staggers
  the player for `BREAK_STAGGER` (PlayerStun; the usual stagger immunity
  applies) and lets the chip through; the meter comes back at `BREAK_REFILL`
  after the stagger and the delay. The input has to be pressed again.
- **Perfect parry**: a hit landing within `PARRY_WINDOW` (+ `IFRAME_SLACK` for
  latency) of raising the guard, even if the button was already let go (a tap
  parries; the pose stays up at least 0.25 s): no damage, `PARRY_REFUND` guard back, and the
  beast staggers (`PARRY_STAGGER`, bosses `PARRY_STAGGER_BOSS`), which calls off
  its windup, dash and follow-ups like a knockback stagger, unless the blow
  opens a chain (below). Every hit inside the window is parried. Raising again within `PARRY_RECOVER`
  of the last raise blocks but can't parry, so mashing never parries. In the
  testbed a blocked hit floats "early 0.xx s" (how long before it the guard went
  up), to tune the window.
- **Chain parry**: parry the first blow of an assault on timing, then ride the
  flurry. When the parried blow has another one of the same assault coming
  (`Guard.Hit.nextIn`, from `planAssault` in EnemyService: barrage and retreat
  parts, cone `strikes`, a slam's `wave`, and a `followUp` combo after the dash,
  recover and its windup), the beast is not staggered and keeps going
  ("deflected"); each of its next blows that lands within `CHAIN_SLACK` of when
  it was due while the guard is up (held or raised again, no timing needed, so
  `PARRY_RECOVER` doesn't apply) is parried too, for `CHAIN_REFUND` guard each.
  The beast staggers on the chain's last blow, on the `CHAIN_MAX`-th (which
  calls off the rest), or when the next blow doesn't come in time (its blows
  missed, the follow-up didn't start; `Guard.onChainEnd`), for its parry
  stagger plus `CHAIN_STAGGER_BONUS` per chained blow, at most
  `CHAIN_STAGGER_MAX`. A blow of the chain that finds the guard down or comes
  from behind breaks it and lands as usual, and the beast isn't staggered:
  letting go mid-flurry is a gamble. Chains are per player and per attacker;
  other beasts' hits are judged normally meanwhile. Bosses chain the same way
  (their stagger base is `PARRY_STAGGER_BOSS`). Examples: the fox's three-bite
  fangDance, the Jiao's fangFlurry strikes, the Thunder Ape's
  clubSwing-backhand-thunderPound combo, the boar's charge into gore.
- Transport: Attack remote `op "guard"` (`on`, `time`, `seq`, `look`) and, while
  guarding, `op "guardLook"` (`time`, `look`; at most every 0.1 s once the
  facing turned 8°); the server answers the owner with Effect `"guardMeter"`
  (character, stored, at, up, the latest `seq` it applied; the client's bar
  runs `GuardRules.value` on it, and a "down" answering an op older than its
  last raise is ignored as stale rather than taken for a refusal, which used to
  drop a quickly re-raised guard for 0.25 s) and tells everyone the outcome with Effect
  `"guard"` (character, `"parried" | "blocked" | "broken" | "chainEnd"`,
  attacker position, then for parries the chain index (1 = the timed parry)
  and whether it closed the chain; `chainEnd` carries the count).
  The Humanoid's `Guarding` attribute mirrors the guard for other clients.
- Animations: `Animations.Guard` in `assets/Animations.rbxmx`. Per weapon class
  (`Guard.<Class>`, the `Config.Combat.CLASSES` names) `Hold` (loop, Action;
  Fist 87546165212405 and Sword 83417013514031 are the user's block poses,
  2026-10-24, one-frame poses held by the loop),
  `Parry`, `ParryAlt` (the opposite-side deflect) and `Impact` (Action2);
  GuardController picks by the character's `WeaponClass` (`Fist` while
  `WeaponStowed`), re-picks when either changes (a held guard swaps into the new
  Hold) and falls back clip by clip to the generic `Guard.Hold`/`Parry`/`Impact`
  (ParryAlt to the class's own Parry, then the generic Parry). A chain plays
  Parry on odd blows and ParryAlt on even ones. To add a class's ids, put
  `<Content name="AnimationId"><url>rbxassetid://ID</url></Content>` in its
  empty Animation items; every class is filled. Playing a Parry, ParryAlt or
  Impact stops the other two with the same fade: a finished one-shot lingers
  about 0.3 s on its last frame at the same priority and would halve the next
  deflect in a chain. Sources and ids are in
  `art/player/guard/README.md`, published with
  `tools/upload_asset.py animation`. `SoundService.SFX` in
  `assets/SoundGroups/SFX.rbxmx` holds `GuardRaise` (soft cloth when the local
  guard rises), `Parry` (bright metal clash), `Block` (muted plate hit) and
  `GuardBreak` (brittle shatter). `GuardController` plays them locally through
  `Sfx`; the Settings SFX slider scales all four. Files, CC0 sources, upload
  ids and template volumes are in `art/sfx/guard/README.md`. Sound levels have
  not been heard in play yet.
- Visuals (`src/client/GuardFX.luau`, templates `ReplicatedStorage.GuardFX`
  from `assets/GuardFX.rbxm`, built by `tools/guardfx_build.luau` in a sandbox;
  kept out of `Effects.rbxm`). Palette white to pale gold, jade for the guard
  itself, away from the gold perfect dodge. `parry` plays `Parry` at a contact
  point 2.4 studs in front of the torso toward the attacker, -Z along the
  deflect (vfx pass, 2026-10-22: "a crisp, heavy deflect"). t = 0 is the
  contact: a hard white-hot dot (~2 frames), an impact-star flipbook that
  opens and breaks up (the hero, 0.3 s), a thin white spike star (0.14 s) and
  a slate splat behind them (reads in daylight); white-gold-orange spark
  spindles thrown along the deflect; at 20 ms a crackling shock ring on the
  guard plane (0.2 s); at 30 ms a few orange-hot metal chips falling. The
  parrying player gets a light shake, a 0.05 s grade and camera punch
  (`CombatEffects.punch`) and a hit-stop: the Parry/ParryAlt clip freezes
  0.05 s from 0.04 s in (0.08 s on a closing blow; `hitStop` in
  GuardController). `blocked` plays `Block` (jade sparks and streaks, a faint
  ripple on a shield-shaped plane). `guardBreak` plays `GuardBreak` (a
  cracking shield shell, thrown jade shards and chips, sparks, a spiky ring,
  dust at the feet; a heavier shake and jade grade for the player). `hold`
  puts a faint low-rate qi shimmer (`Hold`) on both forearms while the guard
  is up, for anyone within 70 studs of the camera; bursts are skipped past
  120 studs. **Chain parries climb by adding layers**, not only size: an
  emitter's `Chain` attribute is the first blow of a chain that shows it
  (GuardFX strips the rest; the plugin's Emit button shows them all): blow 2
  adds a crescent flipbook sweeping to the deflect's side, blow 3 a wider
  spiky shock ring (50 ms), blow 4 a gold ring of radial streaks. From the
  second blow the deflect also throws to alternate sides (right with Parry,
  left with ParryAlt), the burst grows (`TechniqueVFX.rescale`, +7% a blow
  for five), the sparks go from 12 to 27, the shake and punch climb and the
  `Parry` cue rises in pitch (`Sfx.play`'s `speed`, +7% a blow to 1.35x) with
  "x2", "x3" floating. The closing blow (60 ms after its clash) or `chainEnd`
  plays `ParryFinish`: a warm white flash, a big starburst (the hero), a slate
  splat, a heavy spark fan along the throw, a spiky shock ring out to ~10
  studs, two crescents (both sides, 30 ms), falling embers (40 ms) and a soft
  wide ring (70 ms, the second beat), with a heavy shake and gold punch, the
  Parry cue low under the Block cue and "Deflect xN!". Library ids are in the
  builder's `A` table. Look unreviewed in play.
- Known gaps: a client can claim its raise time within `MAX_LAG`, and
  re-raising every `PARRY_RECOVER` keeps a window open about half the time;
  the reported facing is trusted like the client-owned root, so a cheat could
  guard from behind; the race grace delays an unguarded hit's damage and
  reaction by up to `RACE_GRACE`; slam waves, pools, the coil squeeze and storm
  bolts are judged from the beast's position; PvP hits aren't guardable (there's
  no PvP). Untested in play: the threat facing, the dash origins and the race
  grace. The chain parry and its feel are untested in play; a blow's due time
  is planned from the attack's timings, so a follow-up that waits long for its
  attack slot ends the chain early (the beast still staggers).
