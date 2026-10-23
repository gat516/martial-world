# Data, settings, analytics and admin

## Purpose
Load and save each player's profile safely, store their settings, measure the
game (funnels, progression, custom events), and give admins test tools.

## Design intent
- Profiles are session-locked so two servers can't overwrite each other when a
  player hops. If a load fails the player still plays but is never saved, so an
  outage can't wipe real progress.
- An unpublished place (PlaceId 0, the local test build) can't reach DataStores,
  so `PlayerData` swaps in an in-memory store there: profiles save and load, locks
  included, for that session only. Published places always use the real store.
- Schema changes go through numbered migrations.
- Analytics must never break gameplay (every call is pcall'd).
- Studio playtests and the [testbed](testbed.md) top up a test kit so systems can be tried at once
  (the testbed also skips onboarding and owns every technique and weapon).

## Key files
- `src/server/PlayerData.luau`: the `Data` type, `default()`, `migrations`
  (schema v5: v4 -> v5 adds `weapons` (everyone owns and equips the Iron Jian),
  `dao` (Fist and Sword at the neutral level) and `caches`; v8 -> v9 adds
  `quests`, the rewarded objectives claimed, by quest id (see
  [onboarding](onboarding.md)); beats a v8 profile had already passed count as
  claimed, so the tutorial isn't paid in arrears, while lessons already done
  pay out once on the next join; v9 -> v10 adds `seen`, the items, arts and
  weapons the Inventory has shown (id -> os.time() first seen; everything a v9
  profile owned counts as seen at 0), and `inventoryView`, the Inventory's sort
  and filter per tab (see [inventory](../ui/inventory.md))), load with session
  lock, autosave, release on leave.
- `src/server/Settings.luau` + `src/client/Settings.luau` (`SaveSettings` remote).
- `src/server/Analytics.luau`: onboarding funnel, realm progression events,
  custom events (e.g. `QuestClaimed`, field = quest id). See [cultivation](cultivation.md) for reading dropoff.
- `src/server/Admin.luau` + `src/client/AdminPanel.luau`: weather, give, seeds,
  stones, buildItems, spawn, growAll, mutateAll, wild, event, stopEvents, fillQi,
  techniqueLevel (set a technique to any level, learning it if needed),
  weapon, allWeapons, daoLevel (set a weapon class's Dao comprehension).
  Admins: the creator, `Config.Admin.USER_IDS`, anyone in Studio.
- `src/server/Main.server.luau`: join/leave order, `applyTestKit`, hook wiring.

## Data flow
Join: `PlayerData.load` -> test kit (Studio, testbed) -> `Cultivation.claimLogin` (offline
cultivation, daily qi) -> peak layout, realm tier, garden -> `pushState`. Leave:
analytics `SessionLength`, `PlayerData.release` (final save), every module's `forget`.

## Tuning knobs
- `Config.Data`: store name, autosave, lock timings, starting seeds.
- `Config.TestKit` (`ALL_TECHNIQUES`, `ALL_WEAPONS`); `Config.Admin.USER_IDS`.
- Starting raw qi: `Pacing.Income.STARTING_RAW_QI`; starting stones: `Config.Economy`.

## Known gaps
- `Config.TestKit.ENABLED` is on (Studio and the testbed only); `FILL_DANTIAN` fills the dantian on every Studio join.
