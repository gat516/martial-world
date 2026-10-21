# Testbed

## Purpose
A separate place for trying things quickly: fight beasts you spawn, play
animations and effects, start world events and force weather, without walking
the real map. It's meant to be published as its **own experience** (not a place
inside Martial World), so its saves, players and dev-only assets stay out of the
real game.

## Design intent
- **Same code, different world.** `test.project.json` maps the same `src/` and
  `assets/` as `default.project.json`, so the testbed always runs the current
  game. Only Workspace and a few Studio-only folders differ. Never fork scripts
  for it: a testbed difference is a `Config.TESTBED` check in the real code.
- **Only what you trigger happens.** No timed world events, no rolled weather
  (forced weather clears back to Clear and stays there), no ambient encounters.
  Events tied to weather still fire when the admin dashboard forces that weather.
- **Ready to test on join.** Onboarding is skipped (every beat marked done, so
  the HUD is never dimmed or guided), and every player gets the Studio test kit
  plus every technique and weapon, published or not.
- **Its own experience.** Separate DataStores, so testbed profiles never touch
  real ones. Admins there are the creator and `Config.Admin.USER_IDS`, as in the
  real game (anyone in Studio).

## World
Everything sits at the real Hub's height (plaza floor Y 648.6, around the origin),
so the real `Hub.rbxmx` (Elder, quest board, Spirit Market, Testing Stone) stands
on the baseplate unchanged.
- `Workspace.Arena.Baseplate`: 2048 x 2048, top at Y 648.6, centred on (0, 80), grid texture.
- `Workspace.Arena.SpawnPad`: the only SpawnLocation, at (0, 649.1, 40), no forcefield.
- `Workspace.Wilds`: `EventGrounds.ArenaGround` (radius 60 at (0, 648.6, -120)),
  so world events and treasures land there through the real `EventGrounds` path;
  `QiNodes` and `Enemies` are empty folders; `Zones` holds `WolfPair` (2 Spirit
  Wolves at (-90, 648.6, -40), 127 studs from the pad) and `BoarPair` (2 Stone Boars
  at (100, 648.6, -40)), respawning like any zone.
- `Workspace.Map.Sect.SpiritPeaks`: an empty stub, so `Peaks` and `MyPeak` load
  (nobody gets a peak).
- Place-only, kept on purpose (not in git, never synced back): the enemy pose-preview rigs
  (rest and windup statues) in Workspace, and a spare copy of map pieces (bamboo,
  waterfall parts, `Snd_*` sounds, the `F01`-`F31` set dressing) loose in ServerStorage.
- Stubbed as empty folders: `ReplicatedStorage.BuildCatalog`, `HerbModels`;
  `ServerStorage.PeakStash`, `PeakTierModels`.

## Trials before shipping
New fights land here first behind a flag that is on only in the testbed, so the user
can fight them before the main game changes. Today: none waiting. Ship one by
setting its flag to `true`. Shipped so far: the Spirit Wolf (`NEW_WOLF`, 2026-10-21)
and the Stone Boar (`NEW_BOAR`, 2026-10-21); `WolfPair` and `BoarPair` stay for
tuning.

## Key files
- `test.project.json`: the testbed's Rojo project (serve port 34873); sets the
  `Testbed` attribute on Workspace.
- `src/shared/Config.luau`: `TESTBED` (reads that attribute).
- `src/server/Main.server.luau`: `applyTestKit` (skips onboarding, everything
  owned), `sendHome` (no-op: you spawn on the pad).
- `src/server/WorldEvents/init.luau` (no timer), `src/server/WeatherService.luau`
  (no rolls), `src/server/Spawner.luau` (no ambient encounters).

## Setting it up
1. In Studio, make a new place from the Baseplate template and delete its
   `Baseplate` and `SpawnLocation` (the arena brings its own).
2. In a terminal: `rojo serve test.project.json` (port 34873, so it can run
   next to the main project's serve), and connect the Rojo plugin to that port.
3. File > Publish to Roblox As > a **new experience**. Turn on Studio API access
   (Game Settings > Security) if you want profiles saved between sessions.

## Keeping it in sync
- Code and mapped assets sync by themselves: open the testbed place, serve
  `test.project.json`, then republish (File > Publish to Roblox). Commits that need
  testbed testing end with `Testbed: re-sync and republish to test ...`.
- Every non-Workspace mapping in `default.project.json` must also be in
  `test.project.json`; `python3 tools/check_testbed.py` checks it.
- Content moves between the places only through `assets/`: build a new enemy, effect
  or template in either place, export it, map it, and both places get it. No
  copy-and-paste between places.
- New code that waits on map instances needs a stub here or a `Config.TESTBED` guard.

`rojo build` doesn't work for now (for either project): some `.rbxmx` files store
`LightInfluence` as an enum where Rojo 7.7 expects a float. Live serve tolerates it.

## Phases (planned)
1. Scaffolding: project, switches, bare arena. **Done.**
2. Export the Studio-only content (`BuildCatalog`, `HerbModels`, `PeakTierModels`,
   Lighting/sky) to `assets/` and map it in both projects.
3. The arena itself (map-builder): pads, a dummy row, lighting.
4. A testbed panel on top of the admin dashboard (ui-designer): spawn at cursor,
   dummy mode, kill all, god mode, jump to any realm.
5. Animation and VFX stage: freeze an enemy, trigger any attack on demand, loop,
   slow motion; fire any technique or effect.
6. Publish.

## Known gaps
- Garden, build mode and peaks can't be tested (no peaks; empty `HerbModels` and
  `BuildCatalog`). The Guarded Herb event has no herb models to grow.
- Lighting is Studio's default; the real place's Sky, Atmosphere and post effects
  are place-only. So are the main place's map LocalScripts in StarterPlayerScripts
  (`BridgeSway`, `SkyLayerAtmosphere`, `SpiritLights`), which have nothing to act on here.
- Joins can be slow in a busy Studio (several places open), so client code that waits
  on Roblox's own modules or the HUD mustn't give up on a timeout (ShiftLock once fell
  back to Shift this way).
- Animations play only if the testbed experience's owner can use them (same
  creator as the uploads, or permission granted).
- Untested in Studio so far.
