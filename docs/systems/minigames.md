# Circulation minigames

## Purpose
The active half of refining: a short, one-thumb skill game turns raw qi into
cultivation. Better play means more cultivation per qi; very poor play causes a
qi deviation.

## Design intent
- Full screen, one thumb, playable seated in meditation, 15-40 seconds.
- Four games, picked by weight and never the same twice running: **Maze
  Formation** (trace the qi out of mazes), **Thread the Meridian** (steer a bead
  down a winding channel), **Meridian Pulse** (tap as rings close), **Gather Qi**
  (catch falling motes with a bowl). Purple impurities appear in every game;
  purging them is part of the score.
- The very first run is always a short, easier-than-easy Maze that the elder explains.
- Difficulty rises with the realm stage, reaching `hard` at FE1.
- One shared frame (`StarterGui.Hud.Circulation`): a header (title, hint), the
  game's board sized to fit what's left (`Column.Arena`, flex-filled and capped
  at 600px tall), and a stats row (score, timer, flow) under it, so nothing
  overlaps the board on a phone. Each game draws its first board, then calls
  `ui.ready()` for the 3-2-1 count-in over it; the final board stays under the
  result card and is cleared through `ui.hold`.
- **You can always leave a run early**, for free: nothing is spent until a run
  finishes, so leaving refines nothing and costs nothing (the raw qi stays). The
  first run left early is still the first run next time.

## Key files
- `src/server/Circulation.luau`: start/finish, game pick, where runs may happen
  (own peak within `PEAK_RADIUS`, or within a `QiNode`'s `Radius`), anti-cheat
  (minimum duration, clamped score, realm unchanged), qi spend and gain.
- `src/client/CirculationMinigame.luau`: overlay, count-in, result card. Also
  runs Practice Dao drills (`practice(stance)`: the seat stands up on `begin` and swings on every `ui.tapped`; server `DaoPractice`, an `info.title`
  replaces the game's title, the result reads "+N Sword Dao XP").
- `src/client/Minigames/Feel.luau`: shared run info, difficulty blend, feel helpers.
- `src/client/Minigames/{Maze,Thread,Pulse,Gather}.luau`: the games;
  `Forms.luau` is the Practice Dao drill's own game (weight 0, never picked for
  circulation; see `docs/systems/meditation.md`). Its stage is
  `Circulation`…`Forms` in `assets/Hud.rbxmx`.
- `src/shared/Config.luau` `Circulation`: games and their `easy`/`hard` values.
- `src/shared/Pacing.luau`: per-stage `runSeconds`, `difficulty`; `Pacing.Refine`.

## Data flow
`CultivationAction("start")` -> `{ id, game, duration, difficulty, impurities, seed }`
-> the client plays with that seed -> `CultivationAction("finish", id, accuracy,
purged)` -> score = `accuracy * ACCURACY_WEIGHT + purgedShare * (1 - ACCURACY_WEIGHT)`
-> `{ score, gain, spent, deviation, full }`. Only the qi needed to fill the bar is
spent. `Circulation.onFinished` logs `CirculationScore`.
Leaving early: `CirculationMinigame.quit()` (gamepad B, `Menus.close` on the
overlay, and the overlay's Leave button) sets `ui.quit()`; the game ends on its
next frame, and the client sends `CultivationAction("cancel", id)` instead of
"finish" (the server just drops the run).

## Tuning knobs
- Per stage (Pacing.Curve / Adjust): `runSeconds`, `difficulty`, `refine`.
- Pacing.Refine: `RUNS_PER_DANTIAN`, `MIN_RUN_FRACTION`, `EFFICIENCY_MIN/MAX`,
  `DEVIATION_SCORE`, `DEVIATION_SECONDS`.
- Config.Circulation: `Games.<name>.weight/easy/hard`, `IMPURITIES_PER_10S`,
  `ACCURACY_WEIGHT`, `FIRST_RUN_*`, `MIN_DURATION_FRACTION`, `RUN_TIMEOUT_GRACE`,
  `PEAK_RADIUS`.

## Maze Formation: feel and look
- **Drag feel.** A drag doesn't move the spark directly: it feeds a short lead
  (at most `MAX_LAG` cells) that the spark glides after (`FOLLOW`, never faster
  than `MAX_SPEED` cells/s), so it moves smoothly and a flick can't fling it
  through the maze. `DRAG_GAIN` is 0.6 spark px per mouse px on PC and 0.9 per
  finger px on touch. On PC the mouse is pinned (`MouseBehavior =
  LockCurrentPosition`) and hidden while the button is held, so the pointer
  can't drift off the board while walls hold the spark; the game's own mouse
  mode and pointer (ShiftLock/Cursor) come back on release, also when the
  release happened outside the window. WASD / arrows walk it at `KEY_SPEED`.
  The spark swells a little while it's held (grip) and breathes otherwise.
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

## Known gaps
- The score is client-reported (clamped and time-checked, not replayed).
- Thread has a local `SCATTER_SECONDS` constant in its file rather than in Config.
