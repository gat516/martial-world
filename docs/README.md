# Martial World: code map

A Roblox cultivation / martial-arts game, synced with Rojo (`default.project.json`).
A second project, `test.project.json`, runs the same code in a baseplate
[testbed](systems/testbed.md) for quick fights, animations and events.
`main` is production; all work lands on `test` first and is playtested in the local
test build (AGENTS.md "Branches"; [orchestration](agents/orchestration.md#test-build)).
**Start with [the core loop](core-loop.md)**: cultivate until you hit a wall, go
out and break it, come home stronger. Every system plugs into it.
This page says where everything lives. For the setting and zones in brief, read
[world-overview](world-overview.md). Each system has a design doc in
[`systems/`](systems/) (purpose, design intent, files, data flow, tuning knobs, gaps).
Big systems are a core doc plus parts, one file per item: enemies in
[`enemies/`](enemies/), map areas in [`map/`](map/), world effects in [`world/`](world/),
combat in [`combat/`](combat/). **Read the core and the one part you need, not the folder.**
Agent orchestration (sandboxes, test build, who does what): [agents/orchestration](agents/orchestration.md). Agent definitions are in `.claude/agents/`, their shared procedures in `.claude/skills/`.
Visual effects have their own pair: [`vfx/style.md`](vfx/style.md) (how effects
should look, from the reference videos) and [`vfx/toolkit.md`](vfx/toolkit.md)
(core plus topic files in [`vfx/toolkit/`](vfx/toolkit/): the vfxia plugin, asset library and Studio pipeline), [`vfx/world_events.md`](vfx/world_events.md) for sky-scale events, plus
[`vfx/translator.md`](vfx/translator.md) (the user's plain words, such as
"messy" or "weak", mapped to causes and property fixes).

## Layout

| On disk | In the game | What |
|---|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` | data and rules both sides use (defs, tuning, placement, action rules) |
| `src/server/` | `ServerScriptService.Server` | authority: data, cultivation, combat, enemies, garden, build, events |
| `src/client/` | `StarterPlayerScripts.Client` | input, prediction, HUD, effects |
| `src/first/` | `ReplicatedFirst` | runs first on the client: `EditorOnly` strips editor-only markers |
| `assets/*.rbxmx` | mapped instances | MCP-authored Studio instances (GUIs, remotes, templates, the map) |
| `art/` | - | Blender sources and UI art scripts (not synced); the map's landforms come from `art/main_peak/` (`build_main_peak.py`, `place_main_peak.luau`) and the spirit-peak pillar scripts (`art/build_peak_pillar.py`, `art/place_peak_pillar.luau`) |
| `tools/` | - | checks (the UI lint `ui_lint`, the export round-trip check `export_check`, the VFX lints, the motion probe and filmstrip), sandbox Studios, exporters, the asset uploader, the VFX library and preview kits, the review stage, the POI tour: the full list is in [tools.md](tools.md) |

Entry points: `src/server/Main.server.luau` (requires every server module, loads
profiles, wires remotes and hooks) and `src/client/Main.client.luau` (inits every
client module against `StarterGui.Hud`).

Mapped assets: `Remotes`, `Animations`, `Ambience`, `Effects` (binary
`assets/Effects.rbxm`, VFX templates with plugin attributes), `WorldFX` (binary
`assets/WorldFX.rbxm`, the sky-scale world-event kit built by `tools/worldfx_build.luau`:
Grade, LightPillar, SkyRift, Meteor, SkyCircle, GroundCircle, CloudRing; and
`Tribulation` (Vortex, Seal, Strike, Scorch, Finale) built by `tools/vfx_specs/Tribulation.luau`;
see [event-fx](world/event-fx.md)), `BuildKit`, `GardenKit`
(ReplicatedStorage); `HerbMorsel` (ReplicatedStorage, temporary eating prop);
`Hud`, `Rewards`, `Sect`, `Prompts`, `DeathScreen` (StarterGui); `Music`, `SFX`, `Ambience` (binary
`assets/SoundGroups/Ambience.rbxm`, positional ambient sound templates placed by
`AmbientSound`-tagged anchors; see [ambient-sound](world/ambient-sound.md))
(SoundService); `Wilds`, `Hub` (Workspace); `Enemies` (binary `assets/Enemies.rbxm`, so rigs keep their Motor6D C0/C1, `Tell`
attributes and FX attachments; exported with `tools/export_rbxm.luau`; copied at start to
`ReplicatedStorage.EnemyBodies` for clients to draw from), `PeakTiers`,
`ItemTemplates`, `AmbientFX` (binary `assets/AmbientFX.rbxm`, world-ambience
effect templates: fireflies, spirit motes, lamp glows, mist, waterfall spray and
mist, incense, qi spring, den mist, bamboo light, lotus mere, rim veil, petals; see
[ambient-fx](world/ambient-fx.md)), `WaterKit` (binary `assets/WaterKit.rbxm`, stylized
shallow-water surfaces, rim foam and waterfall foam; see [water](world/water.md)),
`WeaponModels` (binary `assets/WeaponModels.rbxm`, weapon
models: one Model per class weapon joined to the Right Arm by its `Hilt`/`HiltR` Motor6D, plus
Dizi, Zither, SpiritStone and the ManualScroll prop; built by `art/weapons/place_weapons.luau`)
(ServerStorage; the same file is also mapped to `ReplicatedStorage.WeaponModels` so the
client can draw weapons in Inventory slots, `WeaponView`). Never restructure these by hand in Studio: see
AGENTS.md, "Studio". `Workspace.Map` (peaks, plaza, cliffs, bridges,
ground, `Map.Sect.Ambience` lights) is place-only, not Rojo-mapped: see
[map](systems/map.md).

Editor-only markers: planning blockouts, POI labels and any other inspection aid go
under `Workspace._EditorMarkers` (place-only) or carry the `EditorOnly` tag. They show
in Studio Edit mode only; `src/server/EditorOnly.server.luau` destroys them when the
game runs, before anyone joins, and `ReplicatedFirst.EditorOnly` (`src/first/`) strips any
copy that still reaches a client. Never leave labels or blockouts anywhere else. Every
POI, cache, find, qi node, lair, boss ring, array and event ground is tagged `POI`
(attributes `PoiName`, `Kind`, `Zone`, optional `LabelNote`); see
[editor-markers](map/editor-markers.md).

The whole plan from QC1 to FE9 (stages, regions, sect quests, optional bosses) is in [progression](progression.md).
The UI screens we need and their art prompts are in [ui overhaul plan](ui/overhaul-plan.md). Every piece of art to generate, as Codex sheets, is in [codex sheets](ui/codex-sheets.md) (the older per-piece list: [codex brief](ui/codex-brief.md)).
What we build next and in what order (solidity, onboarding, sect, techniques, garden, building) is in [roadmap](roadmap.md) (relationships and replayability are parts in [roadmap/](roadmap/)).

## Where to tune things

| Want to change | File |
|---|---|
| How fast players climb, per stage: qi, breakthroughs, tribulation, insight, beast strength | `src/shared/Pacing.luau` ([cultivation](systems/cultivation.md)) |
| Enemy overhead bar danger tiers (realm-gap thresholds); their art, colours and omen lines | `src/shared/Pacing.luau` `Danger`; `STYLES` in `src/client/EnemyBars.luau` ([enemies](systems/enemies.md)) |
| Practice Dao drill (unlock stage, cooldown, XP share, game) | `src/shared/Pacing.luau` `DaoPractice` ([meditation](systems/meditation.md)) |
| Objective rewards (every onboarding beat and lesson, by id) | `src/shared/Pacing.luau` `Quests` ([onboarding](systems/onboarding.md)) |
| Combat qi (technique mana): pool size per stage, regen, regen delay, default cost; per-technique cost | `src/shared/Pacing.luau` `CombatQi`; `qiCost` in `src/shared/Techniques.luau` ([combat](systems/combat.md#combat-qi-technique-mana)) |
| Cultivation past the bar: overflow cap and how much carries over a breakthrough | `src/shared/Pacing.luau` `Breakthrough.OVERFLOW_CAP`, `CARRY_SHARE` ([cultivation](systems/cultivation.md)) |
| Realm ladder names and helpers (built from Pacing) | `src/shared/Realms.luau` |
| Everything else gameplay (combat timings, build limits, garden, travel, weather ambience, minigame shapes) | `src/shared/Config.luau` |
| Enemies (stats, attacks, realm, weight) | `src/shared/Enemies.luau`; spawning in `src/shared/Spawns.luau`, regions in `src/shared/Regions.luau` |
| Testbed fight trials before shipping | `Config.Wilds.NEW_WOLF_KING` (King trial); `test.project.json` zones ([testbed](systems/testbed.md)) |
| Knockback / stagger (beasts) | `src/shared/Knockback.luau` |
| Player flinch, stagger, stun: lengths, immunity, diminishing returns; which enemy hits stagger; knockback on the player | `Config.Combat.CC` (`HEAVY_KINDS`, `STAGGER_WEIGHT`, `KNOCK_*`); per attack `react`/`knock`, per beast `knock` in `Enemies.luau`; API `PlayerStun.apply` ([combat](systems/combat.md#player-crowd-control)) |
| Techniques (and their visual tiers, `VISUAL_TIERS`, elements) | `src/shared/Techniques.luau` |
| Spirit roots: element odds, grades, perks, element match | `src/shared/Pacing.luau` `Roots`; elements in `src/shared/Roots.luau` |
| Cultivation methods: qi speed, reach, root match | `src/shared/Pacing.luau` `Methods`; defs in `src/shared/Methods.luau` |
| Guard: move speed, front arcs (melee, dash), chip, drain, regen, break, parry window and stagger, chain parry, threat facing, race grace; cue volume; per-class guard clips | `Config.Combat.GUARD`; `assets/Animations.rbxmx` (`Guard.<Class>`); `assets/SoundGroups/SFX.rbxmx` (`GuardRaise`, `Parry`, `Block`, `GuardBreak`; [guard and parry](combat/guard-parry.md)) |
| Weapons, classes, grades; M1 chains per class | `src/shared/Weapons.luau`, `Config.Combat.CLASSES`; Dao comprehension in `Pacing.Weapons` |
| Herbs and plants | `src/shared/Herbs.luau` |
| Consumables (cores, treasures) | `src/shared/Items.luau` |
| Build items | `src/shared/BuildItems.luau` |
| Weather | `src/shared/Weather.luau` |
| World events | `src/shared/WorldEvents.luau` |
| Races, Beast Folk variants, traits, who can get them and how | `src/shared/Identity/` ([identity](systems/identity.md#where-to-edit)) |
| How player accessories (race ears, tails, horns) are made: Blender pipeline, seating, rig, recolour rules | [player accessories](character/player-accessories.md) |
| Character screen: last names, rarity colours, outfits, hair colours, reroll products and prices, the world backdrop, name rules, when it shows | `src/shared/CharacterCreator/` (one module each; [character creator](systems/character-creator.md)); look in `src/client/CharacterCreator/Theme.luau` |

## Systems

| System | Doc | Server | Shared | Client |
|---|---|---|---|---|
| Cultivation, realms, breakthroughs, tribulation, insight | [cultivation](systems/cultivation.md) | Cultivation, Circulation, Tribulation, Progression, QiNodes | Pacing, Realms | Hud, SeatBars, BreakthroughView, CirculationMinigame, CultivationGui, FoundationMeter, DeathSave, CultivationMarks |
| Circulation minigames | [minigames](systems/minigames.md) | Circulation | Config.Circulation | CirculationMinigame, Minigames/* |
| Meditation | [meditation](systems/meditation.md) | Meditation | Pacing.Meditation, BuildItems `meditation` | Meditation, Controls, Movement |
| Combat and action states | [combat](systems/combat.md); [guard and parry](combat/guard-parry.md), [technique visuals](combat/technique-visuals.md) (one file per technique in [combat/techniques/](combat/techniques/)) | Combat, CombatQi, Movement, PlayerStun, Guard | ActionRules, Hitbox, Techniques, Knockback, GuardRules, Config.Combat (`CC`: player flinch, stagger, stun; `GUARD`) | CombatController, ActionState, GuardController, GuardBar, GuardFX, CrowdControl, Movement, Sprint, Strafe, LockOn, CombatEffects, Telegraphs, HeadLook, ShiftLock |
| Weapons, weapon Dao, manual caches, weapon racks | [weapons](systems/weapons.md) | Weapons, Combat, WorldCaches, Progression | Weapons, Config.Combat.CLASSES, Pacing.Weapons | WeaponAnimator, CombatController, WorldCaches |
| Character: spirit root, cultivation method (built); bloodline (design); character window | [character](systems/character.md) (core + [character/](character/): spirit root, method, bloodline, character window, later layers), method aura rules [auras](systems/auras.md) (one file per method in [auras/](auras/)) | Roots (perks applied in Cultivation, Circulation, Combat, Garden), Methods (qi speed in Cultivation, Circulation, EnemyService, QiNodes) | Roots, Methods, Pacing.Roots, Pacing.Methods, Techniques `element` | RootFX (reveal pillar, each element in its methods' aura language), MethodAura (one aura per method while seated, from player attributes Meditating + Method; ignites on sit, switch and the Breakthrough remote) |
| Enemies, spawning, regions, server/client split, boss projectiles | [enemies](systems/enemies.md) (core + one doc per enemy in [enemies/](enemies/), plus [projectiles](enemies/projectiles.md) and [arrivals](enemies/arrivals.md)); open boss work in each boss doc's "Open work", boss rules in [enemies](systems/enemies.md#boss-rules-user-decisions); telegraph language and attack feel in [telegraphs](systems/telegraphs.md) | EnemyService, EnemyMover, EnemyHistory, Spawner, Projectiles | Enemies, Spawns, Regions, Knockback, Pacing.Danger, ProjectilePath | ProjectileView, EnemyMotion, EnemyAnimator, EnemyPoses/*, EnemyFX/*, EnemyBars, BossBars, BossThemes, EnemySounds, Telegraphs |
| Garden, herbs, items | [garden](systems/garden.md) | Garden, Inventory | Herbs, Items, Hotbar | GardenView, Planting, PlantingBar, SeedPicker, PlantTag, HerbShop, Inventory, HotbarView, SlotArt, WeaponView, IconRects |
| Build mode and peaks | [build](systems/build.md) | Build, Peaks | BuildItems, Placement, Peak, Config.Build | BuildMode, BuildCatalog, MyPeak, MarketRange |
| Weather, world events, treasures, ambience, stylized water | [world](systems/world.md) | WeatherService, WorldEvents/*, Treasures, EventGrounds | Weather, WorldEvents | WeatherFX, WorldEventFX, Events/WorldEventView, Events/TribulationView, WorldFX/* (Kit, SkyGrade, TreasureFX, TribulationFX), DayNight, Music, AmbientSounds, StylizedWater (+ Shared.WaterSurface) |
| Onboarding, rewarded objectives, quest board, travel | [onboarding](systems/onboarding.md) | Quests, Travel | Gates, Config.Travel, Pacing.Quests | Onboarding, Guide, GuideFX (`Effects.Guide`), Dialogue (the elder's Talk), TravelMenu, GateMarkers, Veil |
| UI and HUD | [ui](systems/ui.md) (core + [ui/](ui/): vitals stack, inventory, boss bar, [overhaul plan and Figma kit](ui/overhaul-plan.md), [Codex sheets](ui/codex-sheets.md), [dialogue ornaments](ui/dialogue-ornaments.md), [dialogue and prompts](ui/dialogue.md), [title ribbons and plaques](ui/ribbons.md), [sect board](ui/sect-board.md), [halls and masters](ui/halls-masters.md), [death screen](ui/death-screen.md)) | - | - | Hud, SeatBars, GuardBar, Menus, Layout, Motion, BossBars, BossThemes, ScrollHint, WorldPrompts, Dialogue, Glyphs, UiScale, Ribbon, Rewards, DeathScreen, DeathLines, Cursor, Settings, Platform, ListWindow, AdminPanel, Sect/* |
| Data, settings, analytics, admin | [data](systems/data.md) | PlayerData, Settings, Analytics, Admin | Config.Data | State, Settings, AdminPanel |
| Map: layout, art direction, anchors scripts depend on | [map](systems/map.md) | Peaks (Map.Sect.SpiritPeaks), Tribulation (CENTER), Travel (TravelGate arrays) | Gates, Config.Travel, Config.Tribulation, Config.Build | DayNight (Map.Sect.Ambience), MyPeak |
| Testbed / test build (local baseplate arena, `test.project.json`; branches and test build in AGENTS.md) | [testbed](systems/testbed.md) | Main (`applyTestKit`, `sendHome`), ForceR6 (R6 when unpublished), WorldEvents, WeatherService, Spawner | Config.TESTBED | - |
| Monetization | [monetization](systems/monetization.md) | Receipts, Garden (Grow now), CharacterIdentity (rerolls) | Config.Garden.GROW_NOW, CharacterCreator.Products | GardenView, CharacterCreator |
| Character creator (join screen: outfit, skin, hair, race and last name, first name) | [character-creator](systems/character-creator.md) | CharacterIdentity, TestbedDummy (testbed stand-in) | CharacterCreator/* | CharacterCreator/* |
| Save slots (slot screen: Play, New, Edit look, Delete; one account of separate characters) | [save-slots](systems/save-slots.md) | Slots, PlayerData, CharacterIdentity, Receipts | Config.Slots | CharacterCreator/Controller, Modals |
| Races, Beast Folk variants and traits (config-driven; availability in one file; admin trait tools) | [identity](systems/identity.md) | Traits, CharacterIdentity, Admin (trait*) | Identity/* (Races, Variants/, Traits/, Availability, Requirements, Registry) | CharacterCreator (race row, odds card), AdminPanel |
| Nameplates (namecard and title over every other player's head; your own name isn't shown to you) | [nameplates](systems/nameplates.md) | - (reads player attributes) | CharacterCreator.Surnames | Nameplates (template `ReplicatedStorage.Nameplate`, `assets/Nameplate.rbxmx`) |

## Remotes, attributes and hooks

Every remote, published attribute and server hook list is in [remotes.md](remotes.md).

## Where to look when...

- **A number feels wrong in progression**: `Pacing.luau` first; it says which knob does what.
- **A HUD value is stale**: is it an attribute (`Cultivation.publish`) or in the `PlayerState` push? See [ui](systems/ui.md).
- **`attempt to index nil` on a GUI/asset child**: probably a duplicate or a missing MCP-authored instance; see AGENTS.md.
- **A remote call fails silently**: the server's `guarded` wrapper logs `Remote error for <name>` in the output.
- **Inspecting a POI or cache in Studio**: `local T = require(game.ServerStorage._EditorTools.PoiTour)`, then `T()` lists them, `T(12)` or `T("WolfDen")` frames one from a player's eye height, `T.labels()` rebuilds the floating labels.
- **Saved data**: `PlayerData.luau` (`Data` type, `default()`, `migrations`).
- **What a subagent is doing right now**: `tools/agent_feed.sh` (one line per tool call, plus each agent's `## Status:` lines); stop or steer from the main session. See [orchestration](agents/orchestration.md).
- **A visual result the user would send back**: the `visual-gate` skill (lint, one sheet, `visual-critic`) and the bar in [approved](reference/approved/README.md); briefs follow [briefs](agents/briefs.md).
