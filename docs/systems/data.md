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
- Save slots ([save slots](save-slots.md), testbed only for now): with
  `Config.Slots.ENABLED` the record is an account of up to `Slots.MAX` separate
  characters under a new key; the old profile is wrapped losslessly into slot 1
  and its old key is kept as a backup. Off, everything is exactly as before.
- Analytics must never break gameplay (every call is pcall'd).
- Studio playtests and the [testbed](testbed.md) top up a test kit so systems can be tried at once
  (the testbed also skips onboarding and owns every technique and weapon).

## Key files
- `src/server/PlayerData.luau`: the `Data` type (one slot's profile), the
  `Account` (slots, fates, shared settings and receipts, trash), `default()`, `migrations`
  (schema v5: v4 -> v5 adds `weapons` (everyone owns and equips the Iron Jian),
  `dao` (Fist and Sword at the neutral level) and `caches`; v8 -> v9 adds
  `quests`, the rewarded objectives claimed, by quest id (see
  [onboarding](onboarding.md)); beats a v8 profile had already passed count as
  claimed, so the tutorial isn't paid in arrears, while lessons already done
  pay out once on the next join; v9 -> v10 adds `seen`, the items, arts and
  weapons the Inventory has shown (id -> os.time() first seen; everything a v9
  profile owned counts as seen at 0), and `inventoryView`, the Inventory's sort
  and filter per tab (see [inventory](../ui/inventory.md)); v10 -> v11 adds
  `character`, the slot's first name and look from the character screen), load
  (the account) with session lock, `activate` (play a slot; `get` is nil before),
  autosave, release on leave.
- `src/server/Slots.luau`: the slot screen's actions and `awaitPlay`.
- `src/server/Receipts.luau`: Robux receipts, deduped on the account.
- `src/server/Settings.luau` + `src/client/Settings.luau` (`SaveSettings` remote).
- `src/server/Analytics.luau`: onboarding funnel, realm progression events,
  custom events (e.g. `QuestClaimed`, field = quest id). See [cultivation](cultivation.md) for reading dropoff.
- `src/server/Admin.luau` + `src/client/AdminPanel.luau`: weather, give, seeds,
  stones, buildItems, spawn, growAll, mutateAll, wild, event, stopEvents, fillQi,
  techniqueLevel (set a technique to any level, learning it if needed),
  weapon, allWeapons, daoLevel (set a weapon class's Dao comprehension).
  The F2 panel's "UI previews" section opens screens in the running client (build
  mode, catalog, shop, the death screen, reward and rank cards, dialogue, herbarium,
  sect board, events): the Studio command bar can't, since its `require` gets a
  fresh, never-initialised copy of each module.
  Admins: the creator, `Config.Admin.USER_IDS`, anyone in Studio.
- `src/server/Main.server.luau`: join/leave order, `applyTestKit`, hook wiring.

## Data flow
Join: `PlayerData.load` (account) -> `Slots.awaitPlay` (the slot screen; slots
off or QuickPlay: at once) -> test kit (Studio, testbed) -> `Cultivation.claimLogin` (offline
cultivation, daily qi) -> peak layout, realm tier, garden -> `pushState`. Leave:
analytics `SessionLength`, `PlayerData.release` (final save), every module's `forget`.

## Tuning knobs
- `Config.Data`: store name, autosave, lock timings, starting seeds.
- `Config.Slots`: on/off, slot cap, trash days, delete token time, QuickPlay.
- `Config.TestKit` (`ALL_TECHNIQUES`, `ALL_WEAPONS`); `Config.Admin.USER_IDS`.
- Starting raw qi: `Pacing.Income.STARTING_RAW_QI`; starting stones: `Config.Economy`.

## Known gaps
- `Config.TestKit.ENABLED` is on (Studio and the testbed only); `FILL_DANTIAN` fills the dantian on every Studio join.
