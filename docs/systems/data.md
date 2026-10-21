# Data, settings, analytics and admin

## Purpose
Load and save each player's profile safely, store their settings, measure the
game (funnels, progression, custom events), and give admins test tools.

## Design intent
- Profiles are session-locked so two servers can't overwrite each other when a
  player hops. If a load fails the player still plays but is never saved, so an
  outage can't wipe real progress.
- Schema changes go through numbered migrations.
- Analytics must never break gameplay (every call is pcall'd).
- Studio playtests top up a test kit so systems can be tried at once.

## Key files
- `src/server/PlayerData.luau`: the `Data` type, `default()`, `migrations`
  (schema v4), load with session lock, autosave, release on leave.
- `src/server/Settings.luau` + `src/client/Settings.luau` (`SaveSettings` remote).
- `src/server/Analytics.luau`: onboarding funnel, realm progression events,
  custom events. See [cultivation](cultivation.md) for reading dropoff.
- `src/server/Admin.luau` + `src/client/AdminPanel.luau`: weather, give, seeds,
  stones, buildItems, spawn, growAll, mutateAll, wild, event, stopEvents, fillQi,
  techniqueLevel (set a technique to any level, learning it if needed).
  Admins: the creator, `Config.Admin.USER_IDS`, anyone in Studio.
- `src/server/Main.server.luau`: join/leave order, `applyTestKit`, hook wiring.

## Data flow
Join: `PlayerData.load` -> test kit (Studio) -> `Cultivation.claimLogin` (offline
cultivation, daily qi) -> peak layout, realm tier, garden -> `pushState`. Leave:
analytics `SessionLength`, `PlayerData.release` (final save), every module's `forget`.

## Tuning knobs
- `Config.Data`: store name, autosave, lock timings, starting seeds.
- `Config.TestKit`; `Config.Admin.USER_IDS`.
- Starting raw qi: `Pacing.Income.STARTING_RAW_QI`; starting stones: `Config.Economy`.

## Known gaps
- `Config.TestKit.ENABLED` is on (Studio only); `FILL_DANTIAN` fills the dantian on every Studio join.
