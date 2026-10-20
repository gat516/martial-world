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

## Key files
- `src/server/Circulation.luau`: start/finish, game pick, where runs may happen
  (own peak within `PEAK_RADIUS`, or within a `QiNode`'s `Radius`), anti-cheat
  (minimum duration, clamped score, realm unchanged), qi spend and gain.
- `src/client/CirculationMinigame.luau`: overlay, count-in, result card.
- `src/client/Minigames/Feel.luau`: shared run info, difficulty blend, feel helpers.
- `src/client/Minigames/{Maze,Thread,Pulse,Gather}.luau`: the games.
- `src/shared/Config.luau` `Circulation`: games and their `easy`/`hard` values.
- `src/shared/Pacing.luau`: per-stage `runSeconds`, `difficulty`; `Pacing.Refine`.

## Data flow
`CultivationAction("start")` -> `{ id, game, duration, difficulty, impurities, seed }`
-> the client plays with that seed -> `CultivationAction("finish", id, accuracy,
purged)` -> score = `accuracy * ACCURACY_WEIGHT + purgedShare * (1 - ACCURACY_WEIGHT)`
-> `{ score, gain, spent, deviation, full }`. Only the qi needed to fill the bar is
spent. `Circulation.onFinished` logs `CirculationScore`.

## Tuning knobs
- Per stage (Pacing.Curve / Adjust): `runSeconds`, `difficulty`, `refine`.
- Pacing.Refine: `RUNS_PER_DANTIAN`, `MIN_RUN_FRACTION`, `EFFICIENCY_MIN/MAX`,
  `DEVIATION_SCORE`, `DEVIATION_SECONDS`.
- Config.Circulation: `Games.<name>.weight/easy/hard`, `IMPURITIES_PER_10S`,
  `ACCURACY_WEIGHT`, `FIRST_RUN_*`, `MIN_DURATION_FRACTION`, `RUN_TIMEOUT_GRACE`,
  `PEAK_RADIUS`.

## Known gaps
- The score is client-reported (clamped and time-checked, not replayed).
- Thread has a local `SCATTER_SECONDS` constant in its file rather than in Config.
