# Remotes, attributes and server hooks

Every remote, the attributes the server publishes, and the hook pattern. Read it when you add or change a remote, an attribute or a server hook.

## Remotes (`ReplicatedStorage.Remotes`, `assets/Remotes.rbxmx`)

Wired in `Main.server.luau` unless noted. RemoteFunctions return `(ok, message|payload)`
and are wrapped in `guarded` (a pcall that logs and returns "Something went wrong").

| Remote | Kind | Direction | Server handler | Client user |
|---|---|---|---|---|
| CultivationAction | Function | C->S | `Circulation.handle` ("start", "finish", "cancel", "breakthrough", "method" id, "root" keepNew, "practiceStart/Finish/Cancel") | CirculationMinigame, BreakthroughView |
| Meditate | Event | both | `Meditation.handle(on)`; server fires `false` to stand you up | Meditation |
| Sprint | Event | C->S | `Cultivation.setRunning` | Sprint |
| Attack | Event | C->S | `Combat.action` (ordered begin/hit/cancel/sync; "guard" raises/lowers the guard) | CombatController |
| Effect | Event | S->C | many: "root" (to all: player, element, grade, first), "perfect", "damage", "hurt", "cast", "qi", "stones", "loot", "insight", "manual", "weapon", "method", "boss", "reward" (a `Rewards.show` spec table: tier, kind, title...), "used", "bolt", "tribulationStart/End", "guardMeter" (owner: character, stored, at, up), "guard" (to all: character, parried/blocked/broken, attacker position), "enemyCue" (to all: enemy model, cue name, target character; see enemies.md) | CombatController, CombatEffects, Rewards, RootFX, EnemyFX |
| Telegraph | Event | S->C | `EnemyService` (attack areas before they land: shape, seconds, enemy or nil, attack name, server start time) | Telegraphs, EnemyFX |
| PlayerState | Event | S->C | `Cultivation.pushState` (full snapshot) | State (everything reads State) |
| Breakthrough | Event | S->all | `Cultivation.advance` (player, stage name, major) | BreakthroughView |
| Notify | Event | S->C | toasts from everywhere | Hud |
| QuestState | Event | S->C | `Quests` (beat, objective, reward, goals, guide, lesson, openBoard) | Onboarding |
| BuildAction | Function | C->S | `Build.handle` ("buy", "place", "store", "move") | BuildMode, BuildCatalog |
| GardenAction | Function | C->S | `Garden.handle` ("plant", "harvest", "growTarget", "uproot", "buySeed", "sell", "sellAll") | Planting, GardenView, HerbShop |
| InventoryAction | Function | C->S | `Inventory.handle` ("use", "slot", "clear", "swap", "comprehend") | Inventory, HotbarView |
| TravelAction | Function | C->S | `Travel.go` (gate id; sect arrays from anywhere in the sect, otherwise from an array; wilds arrays only from the Sect Gate's or a wilds array) | TravelMenu |
| SaveSettings | Event | C->S | `Settings.save` | Settings |
| AdminAction | Function | C->S | `Admin.handle` (admins only) | AdminPanel |
| CharacterAction | Function | C->S | `CharacterIdentity.handle` (`state`, `templates`, `hair`, `defaults`, `reroll`, `confirm`); test place only | CharacterCreator.Bridge |
| WeaponAction | Function | C->S | `Weapons.handle` ("equip", weaponId / "unequip" / "stow", character, boolean) | Inventory (Weapons tab), WeaponAnimator (cosmetic control locks) |
| Dodge, Cast | Event | - | unused (combat moved onto Attack) | - |

`Effect "cast"` is relayed by `Combat.releaseTechnique` to every client except the
caster as `(caster, id, origin, dir, level, chain)`; `level` is the caster's
technique level at cast time (picks the visual tier), `chain` the chain targets or nil.
`Effect "herbEat"` broadcasts `(character, itemId, serverTime)` from
`Inventory.use` to `HerbAnimator` on every client after a successful herb use.

Besides remotes, the server publishes fast-changing values as attributes:
player `Realm`, `Cultivation` (may exceed `CultivationMax`, up to `CultivationCap`), `CultivationMax`, `CultivationCap`,
`BreakthroughReady`, `BreakthroughBlock` ([cultivation](systems/cultivation.md)), `Qi`, `QiMax`, `QiDenied` (combat qi,
[combat](systems/combat.md#combat-qi-technique-mana)), `RawQi`, `DantianCap`, `Stones`, `Root`, `RootGrade`, `Method`, `Meditating` (seated; for others' method auras),
`DeviationUntil`, `Admin`, `Peak`/`PeakFrame`, `Weapon`; character `WeaponClass`, `WeaponStowed`
(combines Tool occupancy, `WeaponControlsLocked`, `WeaponBreakthroughUntil`); humanoid `BaseWalkSpeed`,
`Running`, `ActionBusy`; enemy `Health`, `MaxHealth` (enemies have no Humanoid), `AIState`, `StateAt`, `Attack`, `DashFrom`/`DashTo`/`DashSpeed`/`DashAt`, `FadeAt`, `Realm`
(see [enemies](systems/enemies.md), "Server and client"); workspace `Weather`,
`WeatherEnds`, `WorldEvents`; plot `Plants` (JSON).

## Server hook pattern

Modules expose hook lists that `Main.server.luau` fills, which keeps modules from
requiring each other in circles: `Cultivation.onBreakthrough`, `.onPush`,
`.onInsightBlocked`; `EnemyService.onKill`; `Circulation.onFinished`;
`Tribulation.onFinished`; `Quests.onBeat`, `.onClaimed`; `Progression.onEarned`. Some are
function slots set by the module that owns the answer: `Cultivation.meditation`
(Meditation), `Cultivation.inCombat` (Combat), `CombatQi.fighting` (Combat), `Cultivation.startTribulation`
(Tribulation), `Progression.slotTechnique` (Inventory).
