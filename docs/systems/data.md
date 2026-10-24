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
  and filter per tab: `Weapons`, `Arts`, `Pouch`; a profile saved before the
  Weapons/Arts split holds one `Arsenal` view, which both tabs start from (the
  client maps it on load and the server's first "view" save splits it; no schema
  step) (see [inventory](../ui/inventory.md)); v10 -> v11 adds
  `character`, the slot's first name and look from the character screen), load
  (the account) with session lock, `activate` (play a slot; `get` is nil before),
  autosave, release on leave.
- `src/server/Slots.luau`: the slot screen's actions and `awaitPlay`.
- `src/server/Receipts.luau`: Robux receipts, deduped on the account.
- `src/server/Settings.luau` + `src/client/Settings.luau` (`SaveSettings` remote).
- `src/server/Analytics.luau`: onboarding funnel, realm progression events,
  economy events and custom events (see "What we track"). See
  [cultivation](cultivation.md) for reading realm dropoff.
- `src/server/Admin.luau` + `src/client/AdminPanel.luau`: weather, give, seeds,
  stones, buildItems, spawn, growAll, mutateAll, wild, event, stopEvents, fillQi,
  techniqueLevel (set a technique to any level, learning it if needed),
  weapon, allWeapons, daoLevel (set a weapon class's Dao comprehension), realm (the
  F2 Player chips Realm QC9 / QR9), heartReset (forget heart-demon trials).
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

## What we track
All through `Analytics.luau` (Creator Dashboard > Analytics). Roblox limits: 120 +
20 x CCU requests a minute per server, at most 100 custom event names with 3
fields, 10 funnels; charts take about a day to fill. Economy events are summed
per player and kind and sent every 120 s and on leaving, so busy sources stay
cheap.
- **Onboarding funnel** (renumbered 2026-10-24 when the creator became one
  page, and 2026-10-23 before that; compare across those dates with care):
  1 Joined, 2 Creator opened (the first-character page), 3 Enter World, 4 First
  sit, then one step per onboarding beat (`Quests.Beats` position + 4): 5 First
  circulation, 6 First breakthrough, 7 First kill, 8 First technique earned,
  9 First technique cast, 10 Haul stored, 11 Refined qi, 12 QC3, 13 Root
  tested, 14 QC4. Steps 1-4 count only for a new player (no slot with any
  progress), once a session; a new account skips the slot screen, so it has no
  step. With slots off (the live game) 2-3 never fire: the funnel goes 1 -> 4.
  `TimeToEnterWorld` (custom event): seconds from a new player's join to Enter
  World, field 1 how the name was chosen (Kept the drawn one, Rolled another,
  Typed).
- **Progression**: path "Realm", see [cultivation](cultivation.md).
- **Economy** (currency, source/sink, SKU): `SpiritStones` sources Kill, QiNode,
  Quest (beat and lesson rewards), SectDaily, SectChain, SectRank,
  HerbariumNew, HerbariumTier, Seclusion (the whole tally at its end),
  HerbSell, AuspiciousRelic, SpillReclaimed; sinks Herbalist (seeds), Decor
  (build shop), Comprehend, DeathSpill, Fled. `RawQi` sources Kill, QiNode,
  Quest, DailyQi, HerbEaten, ItemUsed, SpillReclaimed; sinks Refine
  (circulation), Surge, DeathSpill, Fled. `Contribution` sources SectDaily,
  SectChain; sink Pavilion. Not tracked: weapon repairs (none exist), Grow now
  (a Robux product: the Monetization dashboard has it), admin and test-kit grants.
- **Timings** (seconds since the slot's first join, `data.firstJoinUnix`; slots
  from before it was recorded send nothing): `TimeToFirstKill`, `TimeToQC2`,
  `TimeToQC4`.
- **Custom events**: `CirculationScore` (0-100), `Breakthrough` (seconds since
  the last one; realm), `TribulationResult` (1/0), `Death` (what killed them),
  `OfflineQiClaimed`, `SessionLength`, `QuestClaimed` (quest id),
  `MethodGained`, `RootTested` (element), `SeclusionEntered` (first/again),
  `SeclusionEnded` (minutes counted), `SectTask` (taken/claimed; daily kind or
  chain), `PartyFormed` (size; new/joined, logged for the leader), `StoreAll`
  (stones banked), `SpillReclaimed` (seconds left on the spill),
  `HeartDemonFaced` (denials; major; calm/whispers), `SurgeFired` (raw qi spent;
  realm), `Lesson` (lesson id; `shown` when its elder line first fires, `claimed`
  when its objective pays: the lessons' funnel, from `Quests.luau`).

## Tuning knobs
- `Config.Data`: store name, autosave, lock timings, starting seeds.
- `Config.Slots`: on/off, slot cap, trash days, delete token time, QuickPlay.
- `Config.TestKit` (`ALL_TECHNIQUES`, `ALL_WEAPONS`, `SKIP_ITEMS`: items the kit never tops up, the root pills); `Config.Admin.USER_IDS`.
- Starting raw qi: `Pacing.Income.STARTING_RAW_QI`; starting stones: `Config.Economy`.

## Known gaps
- `Config.TestKit.ENABLED` is on (Studio and the testbed only); `FILL_DANTIAN` fills the dantian on every Studio join.
