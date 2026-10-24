# Remotes, attributes and server hooks

Every remote, the attributes the server publishes, and the hook pattern. Read it when you add or change a remote, an attribute or a server hook.

## Remotes (`ReplicatedStorage.Remotes`, `assets/Remotes.rbxmx`)

Wired in `Main.server.luau` unless noted. RemoteFunctions return `(ok, message|payload)`
and are wrapped in `guarded` (a pcall that logs and returns "Something went wrong").

| Remote | Kind | Direction | Server handler | Client user |
|---|---|---|---|---|
| CultivationAction | Function | C->S | `Circulation.handle` ("start", "finish", "cancel", "breakthrough" (seated only), "surge" (the qi surge, `Cultivation.surge` -> `QiSurge.fire`), "method" id, "root" keepNew, "practiceStart/Finish/Cancel", "heartDemon", "heartDemonAnswer" choices, "heartDemonDecline": [heart-demon](systems/heart-demon.md#data)) | CirculationMinigame, BreakthroughView, HeartDemon |
| Meditate | Event | both | `Meditation.handle(on)`; server fires `false` to stand you up | Meditation |
| Sprint | Event | C->S | `Cultivation.setRunning` | Sprint |
| Attack | Event | C->S | `Combat.action` (ordered begin/hit/cancel/sync; "guard" raises/lowers the guard) | CombatController |
| Effect | Event | S->C | many: "root" (to all: player, element, grade, first), "perfect", "damage", "hurt", "cast", "qi", "stones", "loot", "manual", "weapon", "method", "boss", "reward" (a `Rewards.show` spec table: tier, kind, title...), "used", "bolt", "tribulationStart" (to all: player, center, strikes), "tribulationEnd", "guardMeter" (owner: character, stored, at, up), "guard" (to all: character, parried/blocked/broken, attacker position), "enemyCue" (to all: enemy model, cue name, target character; see enemies.md), "spill" (owner only: position, expires server time; the spilled haul, `Haul.died`), "spillGone" (owner: reclaimed?), "banked" (owner: Store all landed; the summary comes as a "reward" small float), "died" (`Combat.died` from Humanoid.Died: `{ cause = "enemy"/"fall"/"tribulation"/"unknown", source = enemy def id?, poisoned, respawn = seconds, hub }`; see ui/death-screen.md) | CombatController, CombatEffects, Rewards, RootFX, EnemyFX, DeathScreen, HaulView |
| Telegraph | Event | S->C | `EnemyService` (attack areas before they land: shape, seconds, enemy or nil, attack name, server start time) | Telegraphs, EnemyFX |
| PlayerState | Event | S->C | `Cultivation.pushState` (full snapshot; `foundation` = `Foundation.state`: `count`, `target`, `percent` (what the stage would get now, 100 = full, up to `max`, 200), `max`, `grade` (its word: Unsteady, Steady, Solid, Deep), `grades` (words by stage key), `percents` (by stage key), `bonus` (summed share), `hints` (up to 5 `{ category, text }`, categories Hunt, Boss, Home, Dao, Discover, World, Deed), see [cultivation](systems/cultivation.md#foundation-grade); `heartDemon` = `HeartDemon.state`: `open`, `name`, `atPeak`, `snoozed`, `trials`, see [heart-demon](systems/heart-demon.md#data)) | State (everything reads State) |
| Breakthrough | Event | S->all | `Cultivation.advance` (player, stage name, major, foundation grade word and percent of the stage left) | BreakthroughView |
| Notify | Event | S->C | toasts from everywhere | Hud |
| QuestState | Event | S->C | `Quests` (beat, objective, reward, goals, guide, lesson, openBoard) | Onboarding |
| BuildAction | Function | C->S | `Build.handle` ("buy", "place", "store", "move") | BuildMode, BuildCatalog |
| GardenAction | Function | C->S | `Garden.handle` ("plant", "harvest", "growTarget", "uproot", "buySeed", "sell", "sellAll") | Planting, GardenView, HerbShop |
| InventoryAction | Function | C->S | `Inventory.handle` ("use", "slot" (onto an occupied slot: that item goes back to the bag), "clear", "swap" (any two slots, empty ones too), "comprehend" (stones plus weapon Dao), "seen" {ids}: no longer NEW, "view" tab, sort, filter: the Inventory's saved view, "ring" itemId, inRing: a stack into or out of the spirit ring, `Haul.setRing`; "storeAll": bank the haul at a bank point, `Haul.storeAll`) | Inventory, HotbarView, Fresh, InventoryFilter |
| TravelAction | Function | C->S | `Travel.go` (gate id; sect arrays from anywhere in the sect, otherwise from an array; wilds arrays only from the Sect Gate's or a wilds array) | TravelMenu |
| SaveSettings | Event | C->S | `Settings.save` | Settings |
| AdminAction | Function | C->S | `Admin.handle` (admins only; trait* actions take a target player, see [identity](systems/identity.md)) | AdminPanel |
| CharacterAction | Function | C->S | `CharacterIdentity.handle` (`state`, `templates`, `hair`, `defaults`, `reroll`, `confirm`); test place only | CharacterCreator.Bridge |
| WeaponAction | Function | C->S | `Weapons.handle` ("equip", weaponId / "unequip" / "stow", character, boolean) | HotbarView (weapon drags and the weapon slot), WeaponAnimator (cosmetic control locks) |
| Dodge, Cast | Event | - | unused (combat moved onto Attack) | - |

`Effect "cast"` is relayed by `Combat.releaseTechnique` to every client except the
caster as `(caster, id, origin, dir, level, chain)`; `level` is the caster's
technique level at cast time (picks the visual tier), `chain` the chain targets or nil.
`Effect "herbEat"` broadcasts `(character, itemId, serverTime)` from
`Inventory.use` to `HerbAnimator` on every client after a successful herb use.

Besides remotes, the server publishes fast-changing values as attributes:
player `Race`, `RaceVariant`, `Traits`, `TraitsInactive` ([identity](systems/identity.md)), `Realm`, `Cultivation` (may exceed `CultivationMax`, up to `CultivationCap`), `CultivationMax`, `CultivationCap`,
`BreakthroughReady`, `BreakthroughBlock`, `SurgeReady`, `SurgeUntil` (server time), `SurgeRealm` (the qi surge, [cultivation](systems/cultivation.md#qi-surge)), `Qi`, `QiMax`, `QiDenied` (combat qi,
[combat](systems/combat.md#combat-qi-technique-mana)), `RawQi`, `DantianCap`, `Stones`, `Root`, `RootGrade`, `Method`, `Meditating` (seated; for others' method auras),
`DeviationUntil`, `Admin`, `Peak`/`PeakFrame`, `Weapon`, `InCombat` (hurt or dealing damage within `IN_COMBAT_SECONDS`, [combat](systems/combat.md)), `HaulReady` (at a bank point with an unbanked haul: Store all is offered, [haul](systems/haul.md)); character `WeaponClass`, `WeaponStowed`
(combines Tool occupancy, `WeaponControlsLocked`, `WeaponBreakthroughUntil`); humanoid `BaseWalkSpeed`,
`Running`, `ActionBusy`; enemy `Health`, `MaxHealth` (enemies have no Humanoid), `AIState`, `StateAt`, `Attack`, `DashFrom`/`DashTo`/`DashSpeed`/`DashAt`, `FadeAt`, `Realm`
(see [enemies](systems/enemies.md), "Server and client"); workspace `Weather`,
`WeatherEnds`, `WorldEvents`; plot `Plants` (JSON).

## Server hook pattern

Modules expose hook lists that `Main.server.luau` fills, which keeps modules from
requiring each other in circles: `Cultivation.onBreakthrough`, `.onPush`;
`EnemyService.onKill`; `Weapons.onLevelUp` (Progression learns kept manuals); `Circulation.onFinished`;
`Tribulation.onFinished`; `Quests.onBeat`, `.onClaimed`; `Haul.onBanked` (player, amounts, "store"/"travel"); `Travel.onTravel` (Haul banks quietly); `Progression.onEarned`. Some are
function slots set by the module that owns the answer: `Cultivation.meditation`
(Meditation), `Cultivation.inCombat` (Combat), `CombatQi.fighting` (Combat), `Cultivation.startTribulation`
(Tribulation), `Cultivation.surgeStage` and `.surge` (QiSurge), `Progression.slotTechnique` (Inventory).
