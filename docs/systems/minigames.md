# Circulation minigames

## Purpose
The active half of refining: a short, one-thumb skill game turns raw qi into
cultivation. Better play means more cultivation per qi; very poor play causes a
qi deviation.

## Design intent
- Full screen, one thumb, playable seated in meditation.
- **A run is levels, not a stretch of time.** It's up to Pacing `levels` levels
  (two at QC1-2, three after; one on the first run) against a cap of
  `LEVEL_SECONDS` a level. You're paid for the levels you clear: 2 of 3 refines
  2/3 of a full run's qi. Clearing every level ends the run on the spot and
  refines `Refine.FULL_CLEAR_BONUS` more, for no extra qi. A level only half
  done when time runs out or you leave counts for nothing. What a level is:
  Maze, one maze (accuracy from its `par` time); Thread, one channel (each wall
  touch costs accuracy); Pulse, `beats` beats; Gather, `motes` qi motes.
- Four games, picked by weight and never the same twice running: **Maze
  Formation** (trace the qi out of mazes), **Thread the Meridian** (steer a bead
  down a winding channel), **Meridian Pulse** (tap as rings close), **Gather Qi**
  (catch falling motes with a bowl). Purple impurities appear in every game;
  purging them is part of the score.
- The very first run is always a short, easier-than-easy Maze that the elder explains,
  and every run below QC4 (the hook) is the Maze (`pickGame`, user 2026-10-24); the
  other games are met from QC4 on, still with no lesson of their own.
- Difficulty rises with the realm stage, reaching `hard` at FE1.
- One shared frame (`StarterGui.Hud.Circulation`): a header (title, hint), the
  game's board sized to fit what's left (`Column.Arena`, flex-filled and capped
  at 600px tall), and a stats row (score, timer, flow) under it, so nothing
  overlaps the board on a phone. Each game draws its first board, then calls
  `ui.ready()` for the 3-2-1 count-in over it; the final board stays under the
  result card and is cleared through `ui.hold`.
- **The pointer is the cursor** (user decision, 2026-10-21, after the Maze's
  mouse lock and slow spark felt bad and Thread's bead kept letting go of a
  fast mouse). No game locks the mouse. On mouse, the spark, bead, bowl or aim
  follows the actual pointer; over the board the OS arrow hides and the qi
  pointer (`Circulation.Pointer`, a jade reticle) draws at the mouse, so it's
  always obvious where you're pointing (Gather hides the arrow and draws
  nothing: the bowl is the cursor; Pulse has no pointer, any tap counts). On
  touch the piece follows the finger. Keys and gamepad keep their steering.
  Walls still matter: the Maze's spark slides along open corridors toward the
  pointer and stops at a wall in the way (a faint tether runs from it to the
  pointer); Thread's bead tracks the pointer and never lets go however fast you
  move, but its path is swept, so a flick across a wall still touches it.
- **The camera holds still for every run** (circulation and Practice Dao),
  so nothing turns or zooms behind the board (`Feel.freezeCamera`: Scriptable
  for the run, then type, subject, field of view and framing come back exactly,
  on finishing, leaving, a game error, or at once on death).
- **Every game looks and feels like the Maze** (user decision, 2026-10-21):
  drawn board art, pops, bursts and shakes on hits, misses and purges, sounds,
  veiled transitions between levels and a clear "what to do" in the hint and
  flow line.
- **You can always leave a run early.** Leaving after clearing a level banks the
  levels cleared, like running out of time. Leaving (or running out of time)
  before clearing any refines nothing and costs nothing (the raw qi stays). A
  first run left with no level cleared is still the first run next time.

## Key files
- `src/server/Circulation.luau`: start/finish, game pick, where runs may happen
  (own peak within `PEAK_RADIUS`, or within a `QiNode`'s `Radius`), anti-cheat
  (minimum time per cleared level, clamped score, realm unchanged), qi spend and gain.
- `src/client/CirculationMinigame.luau`: overlay, count-in, result card. Also
  runs Practice Dao drills (`practice(stance)`: the seat stands up on `begin` and swings on every `ui.tapped`; server `DaoPractice`, an `info.title`
  replaces the game's title, the result reads "+N Sword Dao XP").
- `src/client/Minigames/Feel.luau`: shared run info, difficulty blend, and the
  feel kit every game uses: `pop` (glowing ring), `burst` (spray of light),
  `shake`, `judge`, `veilIn/Out`, `fadeIn`, `buzz`, `sound`, `pointer` (the qi
  pointer over a board), `line` (tethers) and `freezeCamera`.
- `src/client/Minigames/{Maze,Thread,Pulse,Gather}.luau`: the games;
  `Forms.luau` is the Practice Dao drill's own game (weight 0, never picked for
  circulation; see `docs/systems/meditation.md`). Its stage is
  `Circulation`…`Forms` in `assets/Hud.rbxmx`.
- `Hud.Circulation.Pointer` (the qi pointer) and `Hud.Circulation.Sounds`
  (Tick, Perfect, Purge, Clear, Thud: Pro Sound Effects clips and the gong
  already used elsewhere, played through `SoundService.SFX`).
- Art: `art/ui/draw_ui.py maze` (the Maze's pieces, reused by the others) and
  `art/ui/draw_ui.py minigames` (pointer, ring, burst, glow, disc, Thread's wall
  and acupoint, the struck-point notes, Pulse's core and meridian ring, Gather's
  bowl, the ink-wash landscape); ids in `art/ui/assets.json`.
- `src/shared/Config.luau` `Circulation`: games and their `easy`/`hard` values.
- `src/shared/Pacing.luau`: per-stage `levels`, `difficulty`; `Pacing.Refine`.

## Data flow
`CultivationAction("start")` -> `{ id, game, levels, duration, difficulty,
impurities (per level), seed }` -> the client plays with that seed until every
level is cleared, `duration` runs out or the player leaves ->
`CultivationAction("finish", id, cleared, accuracy, purged)` (accuracy averaged
over the cleared levels) -> score = `accuracy * ACCURACY_WEIGHT + purgedShare *
(1 - ACCURACY_WEIGHT)`, purged share out of the cleared levels' impurities ->
gain = a full run's qi * cleared / levels * efficiency (times `1 +
FULL_CLEAR_BONUS` when all are cleared) -> `{ score, gain, spent, deviation, full,
cleared, levels, bonus }`. Only the qi needed to fill the bar is spent.
`Circulation.onFinished` logs `CirculationScore`.
No level cleared (out of time, or left): the client sends
`CultivationAction("cancel", id)` and the server just drops the run. Leaving:
`CirculationMinigame.quit()` (gamepad B, `Menus.close` on the overlay, and the
overlay's Leave button) sets `ui.quit()`; the game ends on its next frame and
reports what it cleared. Practice Dao drills keep the timed flow:
`practiceFinish(id, accuracy, purged)`.

## Tuning knobs
- Per stage (Pacing.Curve / Adjust): `levels`, `difficulty`, `refine`.
- Pacing.Refine: `RUNS_PER_DANTIAN`, `MIN_RUN_FRACTION`, `EFFICIENCY_MIN/MAX`,
  `DEVIATION_SCORE`, `DEVIATION_SECONDS`, `FULL_CLEAR_BONUS`.
- Config.Circulation: `Games.<name>.weight/easy/hard` (Pulse `beats`, Gather
  `motes` per level), `LEVEL_SECONDS`, `IMPURITIES_PER_LEVEL`, `ACCURACY_WEIGHT`,
  `MIN_LEVEL_SECONDS`, `RUN_TIMEOUT_GRACE`, `FIRST_RUN_*`, `PEAK_RADIUS`; Practice
  Dao drills (still timed) use `MIN_DURATION_FRACTION` and `IMPURITIES_PER_10S`.
- In the game files: Thread `SCATTER_COST`; Pulse and Gather `LEVEL_GAP`.

## Maze Formation: feel and look
- **Pointer feel.** The spark runs to the pointer (the mouse over the board,
  no click; or a finger while it's down): each frame it closes `FOLLOW` of the
  gap a second, never faster than `MAX_SPEED` cells/s (30, so it feels under
  the hand), sliding along the corridors through `move()`. A pull must be
  `TURN_BIAS` times more across than along to take a turning, so a diagonal
  pull doesn't flicker between two ways at a junction. When a wall holds it
  more than `TETHER_AT` cells short of the pointer, a faint tether
  (`Board.Tether`, maze_trail.png) shows where you're pulling. WASD / arrows
  walk it at `KEY_SPEED` (keys win while held). The spark swells a little while
  it's steered (grip) and breathes otherwise.
- **Look: a qi formation on lacquer.** Walls are engraved gold array lines with a
  faint warm aura (`maze_wall.png`), the walked path is a glowing jade qi trail
  (`maze_trail.png`), the spark is a white-hot qi orb with two wisps
  (`maze_spark.png`), the way out is a slowly turning gold trigram seal
  (`maze_exit.png`), impurities are pulsing violet miasma knots
  (`maze_impurity.png`), and a faint bagua array plate (`maze_array.png`, `Board.Array`)
  sits under the maze. Art: `art/ui/draw_ui.py maze`. Walls and trail are
  9-sliced from one radially symmetric image (SliceCenter Rect(63, 63, 65, 65),
  `SliceScale` set per board size by Maze.luau), so the same image makes
  horizontal and vertical strokes and their round caps meet as rounded joints.
  Knobs at the top of `Maze.luau`: `WALL_SHARE`/`WALL_PX` (the gold line),
  `WALL_CORE`, `TRAIL_SHARE`/`TRAIL_PX`, `SPARK_SIZE`, `EXIT_SIZE`, `IMPURITY_SIZE`.
- Purges burst violet with the Purge sound; escaping bursts gold with the gong.

## Thread the Meridian: feel and look
- **Take hold, then it follows.** Point at the bead (within `GRAB_RADIUS`, or
  `GRAB_PX` for a finger) to take hold; from then on it heads straight for the
  pointer at up to `MAX_SPEED` field heights/s (6: a fast hand only leaves it
  trailing, it never lets go), swept in `STEP` sub-steps against the walls, so
  a flick across a bend touches the wall. A touch scatters it: thud, red pop,
  the board shakes and the bead flies back to the last lit acupoint, where you
  take hold again (a lifted finger lets go too). While it's loose it breathes,
  a tether runs to it from the pointer and the flow line says "Take hold of the
  qi". Keys steer it directly.
- **Look.** The meridian is a dark jade channel (`mg_disc.png`, tinted) inside
  an engraved gold rim (`thread_wall.png`, lit on its inner side, with a warm
  aura), both round-capped 9-slice strokes (Rect(63, 63, 65, 65), `SliceScale`
  from the board's pixel height) so segments meet as round joints; the qi you've
  carried fills it as the Maze's glowing trail; acupoints (`thread_node.png`)
  light gold with a pop and a rising tick; the bead is the Maze's spark, the
  goal its turning seal, impurities its miasma knots; a faint ink-wash landscape
  (`field_wash.png`) sits under it all. Knobs: `WALL_CORE`, `TRAIL_SHARE`,
  `BEAD_ART`, `IMPURITY_ART`, `TETHER_PX`.

## Meridian Pulse and Weapon Forms: look
- Beats are lacquered acupoints (`mg_note.png`, violet `mg_note_impure.png`)
  that pop in with a little overshoot, each with a glowing ring (`mg_ring.png`)
  closing on it; a hit flares the point out, a miss sinks it away grey.
  Perfect bursts gold with a bright chime, Good pops with a tick (both pitch up
  with the combo), Miss and stray taps thud.
- Pulse: a dark pool (`Plate`, mg_glow.png) and a faint bagua plate
  (`Backdrop`) under the gold meridian ring (`pulse_path.png`) round the
  dantian seal (`pulse_core.png`), whose `CoreGlow` flares with each hit; a
  cleared level bursts from the core with the gong.
- Forms: the same points, numbered, on a scroll panel over the ink wash; the
  qi pointer shows over the panel so aim is exact.

## Gather Qi: feel and look
- The bowl follows the pointer's x (`BOWL_FOLLOW` of the gap a second, at most
  `BOWL_SPEED` field widths/s); the OS arrow hides over the board.
- A lacquer-red dantian bowl with a gold lip (`gather_bowl.png`, 9-sliced to
  any width: Rect(120, 63, 392, 65), SliceScale 0.31, 40px tall; its sides run
  straight through the slice rows) catches spinning qi motes (the Maze's spark)
  and lets violet knots fall past. A catch squashes the bowl, lights its pooled
  glow and ticks up the combo; a caught impurity jolts the board red with a
  thud; an impurity let past bursts violet as it's purged.

## Known gaps
- The score is client-reported (clamped and time-checked, not replayed).
- The sounds were picked from the store by name and not yet heard in game;
  volumes are first guesses (`Hud.Circulation.Sounds`).
- Thread sizes its strokes' `SliceScale` when a level is drawn; a phone turned
  mid-level keeps the old caps until the next level.
- Thread has a local `SCATTER_SECONDS` constant in its file rather than in Config.
