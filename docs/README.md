# Martial World: code map

A Roblox cultivation / martial-arts game, synced with Rojo (`default.project.json`).
This page says where everything lives. Each system has a short design doc in
[`systems/`](systems/) (purpose, design intent, files, data flow, tuning knobs, gaps).

## Layout

| On disk | In the game | What |
|---|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` | data and rules both sides use (defs, tuning, placement, action rules) |
| `src/server/` | `ServerScriptService.Server` | authority: data, cultivation, combat, enemies, garden, build, events |
| `src/client/` | `StarterPlayerScripts.Client` | input, prediction, HUD, effects |
| `assets/*.rbxmx` | mapped instances | MCP-authored Studio instances (GUIs, remotes, templates, the map) |
| `art/` | - | Blender sources and UI art scripts (not synced) |
| `tools/` | - | `check.sh` (luau-lsp), rbxmx export/receive, rbxm export (keeps attributes, for VFX), duplicate finder |

Entry points: `src/server/Main.server.luau` (requires every server module, loads
profiles, wires remotes and hooks) and `src/client/Main.client.luau` (inits every
client module against `StarterGui.Hud`).

Mapped assets: `Remotes`, `Animations`, `Ambience`, `BuildKit`, `GardenKit`
(ReplicatedStorage); `Hud`, `Rewards`, `Prompts` (StarterGui); `Music`, `SFX`
(SoundService); `Wilds`, `Hub` (Workspace); `Enemies`, `PeakTiers`,
`ItemTemplates` (ServerStorage). Never restructure these by hand in Studio: see
AGENTS.md, "Studio instances".

## Where to tune things

| Want to change | File |
|---|---|
| How fast players climb, per stage: qi, breakthroughs, tribulation, insight, beast strength | `src/shared/Pacing.luau` ([cultivation](systems/cultivation.md)) |
| Realm ladder names and helpers (built from Pacing) | `src/shared/Realms.luau` |
| Everything else gameplay (combat timings, build limits, garden, travel, weather ambience, minigame shapes) | `src/shared/Config.luau` |
| Enemies (stats, attacks, realm, weight) | `src/shared/Enemies.luau`; spawning in `src/shared/Spawns.luau`, regions in `src/shared/Regions.luau` |
| Knockback / stagger | `src/shared/Knockback.luau` |
| Techniques (and their visual tiers, `VISUAL_TIERS`) | `src/shared/Techniques.luau` |
| Herbs and plants | `src/shared/Herbs.luau` |
| Consumables (cores, treasures) | `src/shared/Items.luau` |
| Build items | `src/shared/BuildItems.luau` |
| Weather | `src/shared/Weather.luau` |
| World events | `src/shared/WorldEvents.luau` |

## Systems

| System | Doc | Server | Shared | Client |
|---|---|---|---|---|
| Cultivation, realms, breakthroughs, tribulation, insight | [cultivation](systems/cultivation.md) | Cultivation, Circulation, Tribulation, Progression, QiNodes | Pacing, Realms | Hud, BreakthroughView, CirculationMinigame |
| Circulation minigames | [minigames](systems/minigames.md) | Circulation | Config.Circulation | CirculationMinigame, Minigames/* |
| Meditation | [meditation](systems/meditation.md) | Meditation | Pacing.Meditation, BuildItems `meditation` | Meditation, Controls, Movement |
| Combat and action states | [combat](systems/combat.md) | Combat, Movement | ActionRules, Hitbox, Techniques, Knockback, Config.Combat | CombatController, ActionState, Movement, Sprint, LockOn, CombatEffects, Telegraphs, HeadLook, ShiftLock |
| Enemies, spawning, regions | [enemies](systems/enemies.md) | EnemyService, Spawner | Enemies, Spawns, Regions, Knockback | EnemyAnimator, EnemyBars, EnemySounds, Telegraphs |
| Garden, herbs, items | [garden](systems/garden.md) | Garden, Inventory | Herbs, Items, Hotbar | GardenView, Planting, PlantingBar, SeedPicker, PlantTag, HerbShop, Inventory, HotbarView, SlotArt |
| Build mode and peaks | [build](systems/build.md) | Build, Peaks | BuildItems, Placement, Peak, Config.Build | BuildMode, BuildCatalog, MyPeak, MarketRange |
| Weather, world events, treasures | [world](systems/world.md) | WeatherService, WorldEvents/*, Treasures | Weather, WorldEvents | WeatherFX, DayNight, Music |
| Onboarding, quests, travel | [onboarding](systems/onboarding.md) | Quests, Travel | Config.Travel | Onboarding, TravelMenu |
| UI and HUD | [ui](systems/ui.md) | - | - | Hud, Menus, Layout, Motion, WorldPrompts, Rewards, Cursor, Settings, Platform, ListWindow, AdminPanel |
| Data, settings, analytics, admin | [data](systems/data.md) | PlayerData, Settings, Analytics, Admin | Config.Data | State, Settings, AdminPanel |
| Monetization | [monetization](systems/monetization.md) | Receipts, Garden (Grow now) | Config.Garden.GROW_NOW | GardenView |

## Remotes (`ReplicatedStorage.Remotes`, `assets/Remotes.rbxmx`)

Wired in `Main.server.luau` unless noted. RemoteFunctions return `(ok, message|payload)`
and are wrapped in `guarded` (a pcall that logs and returns "Something went wrong").

| Remote | Kind | Direction | Server handler | Client user |
|---|---|---|---|---|
| CultivationAction | Function | C->S | `Circulation.handle` ("start", "finish", "breakthrough") | CirculationMinigame, BreakthroughView |
| Meditate | Event | both | `Meditation.handle(on)`; server fires `false` to stand you up | Meditation |
| Sprint | Event | C->S | `Cultivation.setRunning` | Sprint |
| Attack | Event | C->S | `Combat.action` (ordered begin/hit/cancel/sync) | CombatController |
| Effect | Event | S->C | many: "action", "perfect", "damage", "hurt", "cast", "qi", "stones", "loot", "insight", "manual", "boss", "used", "bolt", "tribulationStart/End" | CombatController, CombatEffects, Rewards |
| Telegraph | Event | S->C | `EnemyService` (attack areas before they land) | Telegraphs |
| PlayerState | Event | S->C | `Cultivation.pushState` (full snapshot) | State (everything reads State) |
| Breakthrough | Event | S->all | `Cultivation.advance` (player, stage name, major) | BreakthroughView |
| Notify | Event | S->C | toasts from everywhere | Hud |
| QuestState | Event | S->C | `Quests` (beat, objective, goals, openBoard) | Onboarding |
| BuildAction | Function | C->S | `Build.handle` ("buy", "place", "store", "move") | BuildMode, BuildCatalog |
| GardenAction | Function | C->S | `Garden.handle` ("plant", "harvest", "growTarget", "uproot", "buySeed", "sell", "sellAll") | Planting, GardenView, HerbShop |
| InventoryAction | Function | C->S | `Inventory.handle` ("use", "slot", "clear", "swap") | Inventory, HotbarView |
| TravelAction | Function | C->S | `Travel.go` | TravelMenu |
| SaveSettings | Event | C->S | `Settings.save` | Settings |
| AdminAction | Function | C->S | `Admin.handle` (admins only) | AdminPanel |
| Dodge, Cast | Event | - | unused (combat moved onto Attack) | - |

`Effect "cast"` is relayed by `Combat.releaseTechnique` to every client except the
caster as `(caster, id, origin, dir, level, chain)`; `level` is the caster's
technique level at cast time (picks the visual tier), `chain` the chain targets or nil.

Besides remotes, the server publishes fast-changing values as attributes:
player `Realm`, `Cultivation`, `CultivationMax`, `RawQi`, `DantianCap`, `Stones`,
`DeviationUntil`, `Admin`, `Peak`/`PeakFrame`; humanoid `BaseWalkSpeed`,
`Running`, `ActionBusy`; enemy `AIState`, `Realm`; workspace `Weather`,
`WeatherEnds`, `WorldEvents`; plot `Plants` (JSON).

## Server hook pattern

Modules expose hook lists that `Main.server.luau` fills, which keeps modules from
requiring each other in circles: `Cultivation.onBreakthrough`, `.onPush`,
`.onInsightBlocked`; `EnemyService.onKill`; `Circulation.onFinished`;
`Tribulation.onFinished`; `Quests.onBeat`; `Progression.onEarned`. Some are
function slots set by the module that owns the answer: `Cultivation.meditation`
(Meditation), `Cultivation.inCombat` (Combat), `Cultivation.startTribulation`
(Tribulation), `Progression.slotTechnique` (Inventory).

## Where to look when...

- **A number feels wrong in progression**: `Pacing.luau` first; it says which knob does what.
- **A HUD value is stale**: is it an attribute (`Cultivation.publish`) or in the `PlayerState` push? See [ui](systems/ui.md).
- **`attempt to index nil` on a GUI/asset child**: probably a duplicate or a missing MCP-authored instance; see AGENTS.md.
- **A remote call fails silently**: the server's `guarded` wrapper logs `Remote error for <name>` in the output.
- **Saved data**: `PlayerData.luau` (`Data` type, `default()`, `migrations`).
