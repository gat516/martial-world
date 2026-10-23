# Testbed

## Purpose
A separate place for trying things quickly: fight beasts you spawn, play
animations and effects, start world events and force weather, without walking
the real map. It runs locally as the **test build** (`mw-sandbox-test`, built from
the `test` branch and kept live by Rojo), where every feature is playtested before
it's pushed to `test`. Agent sandboxes are built from the same project. Publishing it
as its own experience was dropped (user, 2026-10-22); branches and the test build are
in AGENTS.md (Branches, Test build).

## Design intent
- **Same code, different world.** `test.project.json` maps the same `src/` and
  `assets/` as `default.project.json`, so the testbed always runs the current
  game. Workspace, a few Studio-only folders and the testbed's native mouse-lock
  setting differ. Never fork scripts for it: testbed-only code checks
  `Config.TESTBED` in the shared source.
- **Only what you trigger happens.** No timed world events, no rolled weather
  (forced weather clears back to Clear and stays there), no ambient encounters.
  Events tied to weather still fire when the admin dashboard forces that weather.
- **Ready to test on join.** Onboarding is skipped (every beat marked done, so
  the HUD is never dimmed or guided), and every player gets the Studio test kit
  plus every technique and weapon, published or not. Joining lands on the slot
  screen with a ready "Tester" (one tap to Play) and an empty slot to try the
  creator ([save slots](save-slots.md)); the Workspace attribute `QuickPlay`
  (off by default in `test.project.json`) skips straight into the world.
- **Local only.** It's never published, so it has no live players. Studio Play
  uses the place's own DataStores (none, unless Studio API access is on), so
  profiles never touch the real game's. Everyone in Studio is an admin.
- **R6 only, like the real game.** The avatar type is an experience setting, and a
  local file has none (StarterPlayer's old `GameSettingsAvatar` property is gone), so
  it spawned R15. In an unpublished place, `ForceR6.server.luau` puts an R6
  `StarterCharacter` (blank body; your clothes and accessories still load) in
  StarterPlayer and respawns anyone already in.
- **Saves last one session.** An unpublished place can't reach DataStores or other
  Open Cloud APIs ("must publish this place"), and Studio API access can only be
  turned on for a published place. So `PlayerData` uses an in-memory store when
  `PlaceId` is 0: rejoining in the same Play session keeps your profile; stopping
  Play or rebuilding wipes it (user, 2026-10-22).
- **Alt mouse lock in the testbed.** In the observed Studio Play client, Roblox
  supplied no `PlayerScripts.PlayerModule` for `ShiftLock.luau` to rebind, so Shift
  stayed native and Alt did nothing. `test.project.json` disables the native
  Shift toggle with `StarterPlayer.EnableMouseLockOption = false`;
  `TestbedAltMouseLock.client.luau` supplies Alt, mouse centering and shoulder
  offset only when `Config.TESTBED` is true. The main project's setting and
  `ShiftLock.luau` are unchanged. This needs a fresh testbed Play session to verify.

## World
Everything sits at the real Hub's height (plaza floor Y 648.6, around the origin),
so the real `Hub.rbxmx` (Elder, quest board, Spirit Market, Testing Stone) stands
on the baseplate unchanged.
- `Workspace.Arena.Baseplate`: 2048 x 2048, top at Y 648.6, centred on (0, 80), grid texture.
- `Workspace.Arena.SpawnPad`: the only SpawnLocation, at (0, 649.1, 40), no forcefield.
- `Workspace.Camera`: the saved edit-mode camera, at (0, 665, 95) looking down at the spawn pad, so Studio opens on the arena instead of the empty sky at Y 0.
- `Workspace.Wilds`: `EventGrounds.ArenaGround` (radius 60 at (0, 648.6, -120)),
  so world events and treasures land there through the real `EventGrounds` path;
  `QiNodes` and `Enemies` are empty folders; `Zones` holds `WolfPair` (2 Spirit
  Wolves at (-90, 648.6, -40), 127 studs from the pad), `BoarPair` (2 Stone Boars
  at (100, 648.6, -40)) and `WolfKingTrial` (one Elder Wolf King at
  (0, 648.6, -300)), respawning like any zone. The King stands farther beyond the
  event ground, away from the pairs and spawn pad.
  `SerpentPair` (2 Venom Serpents at (-90, 648.6, 80)), `TortoiseSolo` (one Stone
  Tortoise at (100, 648.6, 80)) and `ManePair` (2 Shadow Mane Wolves at (0, 648.6, 140))
  test the second bestiary wave behind `NEW_SERPENT` / `NEW_TORTOISE` / `NEW_SHADOW_MANE`.
  The third wave has `CentipedeSolo` (180, 0), `RavenSolo` (-180, -160),
  and `BatSwarm` (4 bats, 180, -160), behind
  `NEW_CENTIPEDE` / `NEW_RAVEN` / `NEW_BAT`.
- New bosses (Thunder Ape, Nine-Tailed Fox, Jade Jiao) get no zone: the user
  spawns them from the admin panel's "Spawn beasts" list (every def shows there,
  testbed-only defs included), and they land right in front of the player, just clear of their body.
- `Workspace.Map.Sect.SpiritPeaks`: an empty stub, so `Peaks` and `MyPeak` load
  (nobody gets a peak).
- `Workspace.Arena.TribulationPlatform`: a 72-stud slab at (0, 649, 240); in the testbed `Config.Tribulation.CENTER` points at it, since the main peak's platform isn't there. Jump with the admin actions `realm` (`"QC9"`) and `tribulation`.
- Place-only, kept on purpose (not in git, never synced back): the enemy pose-preview rigs
  (rest and windup statues) in Workspace, and a spare copy of map pieces (bamboo,
  waterfall parts, `Snd_*` sounds, the `F01`-`F31` set dressing) loose in ServerStorage.
- Stubbed as empty folders: `ReplicatedStorage.BuildCatalog`, `HerbModels`;
  `ServerStorage.PeakStash`, `PeakTierModels`.

## Trials before shipping
New fights land here first behind a flag that is on only in the testbed, so the user
can fight them before the main game changes. Waiting: the Elder Wolf King boss
animation/fight pass (`NEW_WOLF_KING = Config.TESTBED`): heavy bite/rush/Crownfall,
fast paw swipe and downward claw, and capped pack calls. Tune at QC9; the test kit
gives equipment but does not change realm. The user asked for a reasonably hard
boss that can kill the player, with short readable reaction checks and recovery
windows. Ship after approval by setting `NEW_WOLF_KING = true`.
Shipped so far: the Spirit Wolf (`NEW_WOLF`, 2026-10-21)
and the Stone Boar (`NEW_BOAR`, 2026-10-21); `WolfPair` and `BoarPair` stay for
tuning.

## Key files
- `test.project.json`: the testbed's Rojo project (serve port 34873); sets the
  `Testbed` attribute on Workspace.
- `src/shared/Config.luau`: `TESTBED` (reads that attribute).
- `src/server/Main.server.luau`: `applyTestKit` (skips onboarding, everything
  owned), `sendHome` (no-op: you spawn on the pad).
- `src/shared/Enemies.luau`: the King's trial def and tuning;
  `src/client/EnemyPoses/WolfKing.luau` and `EnemyFX/ElderWolfKing.luau` draw it.
- `src/server/WorldEvents/init.luau` (no timer), `src/server/WeatherService.luau`
  (no rolls), `src/server/Spawner.luau` (no ambient encounters).

## Setting it up (the test build)
Any dev can do this on their own machine.
1. Once: `git worktree add ../martial-world-test test` (the test checkout).
2. In the test checkout: `tools/sandbox.sh open test` builds the place from
   `test.project.json` and opens it in Studio as `mw-sandbox-test`.
3. In the same checkout: `rojo serve test.project.json` (port 34873, so it can run
   next to the main project's serve), and connect the Rojo plugin in that window
   to that port.
Without WSL, replace step 2 with `rojo build test.project.json -o mw-sandbox-test.rbxl`
and open that file in Studio. Nothing in it is saved. After a restart, repeat steps 2 and 3.

## Keeping it in sync
- Code and mapped assets sync by themselves: merging a feature branch into the
  test checkout updates the open test build through Rojo. Commits that need
  testing there end with `Test build: <what to test>`.
- Every non-Workspace mapping in `default.project.json` must also be in
  `test.project.json`; `python3 tools/check_testbed.py` checks it.
- Content moves between the places only through `assets/`: build a new enemy, effect
  or template in either place, export it, map it, and both places get it. No
  copy-and-paste between places.
- New code that waits on map instances needs a stub here or a `Config.TESTBED` guard.

## Phases (planned)
1. Scaffolding: project, switches, bare arena. **Done.**
2. Export the Studio-only content (`BuildCatalog`, `HerbModels`, `PeakTierModels`,
   Lighting/sky) to `assets/` and map it in both projects.
3. The arena itself (map-builder): pads, a dummy row, lighting.
4. A testbed panel on top of the admin dashboard (ui-designer): spawn at cursor,
   dummy mode, kill all, god mode, jump to any realm.
5. Animation and VFX stage: freeze an enemy, trigger any attack on demand, loop,
   slow motion; fire any technique or effect.
(Publishing it was dropped: it runs locally as the test build.)

## Known gaps
- Garden, build mode and peaks can't be tested (no peaks; empty `HerbModels` and
  `BuildCatalog`). The Guarded Herb event has no herb models to grow.
- Lighting is Studio's default; the real place's Sky, Atmosphere and post effects
  are place-only. So are the main place's map LocalScripts in StarterPlayerScripts
  (`BridgeSway`, `SkyLayerAtmosphere`, `SpiritLights`), which have nothing to act on here.
- Joins can be slow in a busy Studio (several places open). The previous
  `ShiftLock` timeout was removed, but this testbed client had no `PlayerModule`
  at all; the testbed Alt controller no longer waits for one.
- Animations play in Studio only if the logged-in user can use them (they're owned
  by the main game's group).
- The test build shows code and `assets/` only: the real map isn't in it, so map
  work (and anything that needs `Workspace.Map`) is still tested in the user's own
  copy of the main place.
- The King's new poses, effects, contact placement and QC9 difficulty are untested
  in play, including latency and phone cost. The earlier Spirit Wolf fight was
  reviewed here before it shipped.
- Camera: `CameraMaxZoomDistance` is 30 in both projects; locking a big enemy
  raises it for that fight ([combat](combat.md), lock-on).
