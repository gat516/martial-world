# Weapons and weapon Dao

## Purpose
Held weapons give each fighting style its own M1 chain, reach and feel, and a
Dao comprehension per weapon class that grows as you fight with it.

## Design intent
- A **weapon class** (Dao path): `Fist`, `Sword` (jian), `Saber` (dadao),
  `Greatsword`, `Guandao`, `Spear`, `Staff`. It owns the M1 chain (3-5 steps),
  hitbox, max targets per swing, idle/walk, the model's joint and a Dao level.
  Nothing equipped = Fist.
- A **weapon item** is one concrete weapon of a class and grade (Mortal 1.0,
  Spirit 1.25, Earth 1.5, Heaven 1.9). One is equipped at a time. Weapons are
  Models joined to the Right Arm by a Motor6D, not Backpack Tools. Equipping
  any Tool removes the weapon model and pauses its idle/walk; putting the Tool
  away restores the selected weapon once movement/combat controls are available.
  Meditation, circulation, other control locks and breakthroughs also stow it.
- **Dao comprehension**, level 0-10 per class: XP from landing M1 hits with the
  class (once per swing), casting its techniques and learning its manuals,
  and from QC7 a seated Practice Dao drill (capped and on a cooldown; see
  [meditation](meditation.md)).
  Damage of M1 and the class's techniques = base x realm power x grade x Dao.
  Level 2 is neutral (x1.0); untrained (0) is x0.8 and mastery x1.3. A new
  player's Fist and Sword start at 2, so starting power is unchanged.
- **Dao gates techniques:** a class skill is learned only at that class's Dao 2,
  and each comprehension bottleneck needs more (learn + 2 per bottleneck). A manual
  found too early waits in Arts reading "Requires Saber Dao 2" and is learned on
  the level-up that reaches it ([combat](combat.md)). Any-weapon arts count the
  highest class Dao.
- Starting kit: a Mortal Iron Jian, equipped (new profiles and the v5 migration).

## Key files
- `src/shared/Weapons.luau`: `Classes`, `ClassOrder`, `Defs` (12 weapons: an Iron
  one per class plus a Spirit-grade one per class), `Order`, `Grades`, `FIST`,
  helpers `classOf`, `gradeMultiplier`, `daoMultiplier`, `xpToNext`, `requires`
  ("Requires a sword"), `clip` (a chain step's Animations path).
- `src/shared/Config.luau` `Combat.CLASSES`: each class's chain (`steps`:
  damage, hit, hitStop, speed, recovery, push), `hitbox`, `maxTargets`.
- `src/shared/Pacing.luau` `Weapons`: Dao levels, multipliers and XP.
- `src/server/Weapons.luau`: `WeaponAction` ("equip", id / "unequip"), the held
  model (`HeldWeapon` in the character), `class`, `multiplier`, `addXp`, `grant`.
- `src/client/WeaponAnimator.luau`: the class's idle/walk on the local character,
  plus cosmetic stow requests from `Controls.isLocked()` / `ActionState.blocked`.
- `src/client/CombatController.luau`: plays the class's chain (`profile.clip`).
- `assets/Animations.rbxmx`: `Animations.Weapons.<Class>.1..n`, `.Idle`, `.Walk`.
  Every animation id lives only here, so swapping a clip is a one-file edit.

## Class techniques
Each technique names its `weapon` (a class or "Any"); a class technique needs
that class equipped and scales with its grade and Dao. One weapon skill per
class (Twin Phoenix Cannon, Moonflash Draw, Rampaging Tiger Cleave,
Heaven-Splitting Descent, Crescent Moon Sweep, Dragon-Piercing Thrust, Great
Sage Awakening); see [combat](combat.md) for their shapes and numbers.
Many more techniques are planned. Each one is a manual found in the world, gets
its own comprehension bottlenecks for free, and needs four visual tiers
(`<Id>_T1..T4`; it can launch with T1 and grow the rest).

## Where techniques and weapons come from (v1)
| Source | What |
|---|---|
| Start | Iron Jian (equipped), Lightning Talisman (any weapon, so the starter works whatever you hold) |
| Kill milestones (`Pacing.Rewards.MILESTONES`) | 3 Fire Seal, 12 Sword Qi Wave, 30 Iron Skin, 60 Moonflash Draw, 100 Palm Strike (any-weapon manuals first: the 3-kill one is the onboarding's) |
| First boss kill (`BOSS_FIRST_MANUAL`) | Twin Phoenix Cannon |
| Boss pool (`Enemies.ElderWolfKing.bossDrops`) | one unowned entry of: Rampaging Tiger Cleave, Heaven-Splitting Descent, Crescent Moon Sweep, Great Sage Awakening, or a Spirit weapon of any class. Guaranteed on the first kill, then 25% a kill |
| Manual caches (`ManualCache` anchors) | whatever manual/weapon the anchor names; meant for Dragon-Piercing Thrust and the other class manuals |
| Sect weapon rack (`WeaponRack` anchors) | one free Mortal weapon of each class, once each |
| Admin / test kit | `weapon`, `allWeapons`, `daoLevel`; `Config.TestKit.ALL_WEAPONS` |

Learning a class manual grants that class `XP_MANUAL` Dao XP (re-studying a
known one at a cache too). A manual kept for lack of Dao grants nothing until it
is learned; Fist and Sword start at Dao 2, so Twin Phoenix Cannon and Moonflash
Draw are learned on the spot, the other classes' skills wait on that class's Dao.
The Cloud-Pattern Jade treasure gives Dao XP to the class in hand. A gained weapon fires Effect `"weapon"` (weaponId).

### World anchors (placed by the map)
- `ManualCache`: a BasePart tagged `ManualCache` in Workspace, attributes `Cache`
  (unique id, saved in `data.caches`), `Manual` (technique id) and/or `Weapon`
  (weapon id), optional `Realm` (a stage key like `"QC5"` needed to claim it).
  The server gives it `ServerStorage.ItemTemplates.CachePrompt` and a
  `WeaponModels.ManualScroll` clone resting on top.
- `WeaponRack`: a BasePart tagged `WeaponRack`, attribute `Weapon`, optional
  `Cache` (default `rack:<Weapon>`); gets `RackPrompt`.
- `src/server/WorldCaches.luau` sets them up (zero anchors is fine) and claims
  once per player; `src/client/WorldCaches.luau` disables prompts already
  claimed (`caches` is in the state push).

## Data flow
Equip (dragging a weapon onto the Inventory's weapon slot or the hotbar, or tapping the weapon slot; [inventory](../ui/inventory.md)): client invokes `WeaponAction("equip", id)` -> the server checks ownership
and that no action is running -> `data.weapons.equipped`, clones
`ServerStorage.WeaponModels.<model>` into the character as `HeldWeapon` with its
`<joint>` Motor6D's Part0 = Right Arm, sets player `Weapon` and character
`WeaponClass`, pushes state. Respawns re-apply it. M1: `ActionRules.start(...,
class)` picks the chain from `WeaponClass` (client) / the equipped weapon
(server); `Combat.damageSwing` uses the class's hitbox, targets, step damage and
push, times `Weapons.multiplier`, and grants `XP_HIT` Dao XP when it lands.
Dao level-ups notify and push state; other XP rides the periodic state refresh.

`Weapons.watch` observes character Tool additions/removals on every spawn.
While any Tool is equipped, `Weapons.apply` removes/skips `HeldWeapon` on the
server so all players see it stowed. Removing the last Tool (including consuming
the final item) restores the model. Tool swaps are coalesced; changing the
selected weapon while holding an item leaves it stowed until the hand is free.
The saved selection, player `Weapon`, and character `WeaponClass` stay selected.
`WeaponAnimator` pauses the weapon's idle/walk while stowed. It sends
`WeaponAction("stow", character, boolean)` only when the local aggregate control
lock changes: named movement locks (including meditation's get-up and circulation
results), blocked combat input (menus, building, planting, typing/focus), sitting,
death, or an anchored root. This is cosmetic: the server validates the current
character and boolean and never uses the request to authorize combat.

`Weapons.apply` combines Tool occupancy, `WeaponControlsLocked`, and
`WeaponBreakthroughUntil` into the replicated character `WeaponStowed`
attribute. Releasing one reason cannot override another. The breakthrough hook
stows the weapon for the 1.6-second column effect, including forced breakthroughs;
the timer is scoped to that character and latest breakthrough. The next respawn
gets fresh attributes and a new client report. Ordinary attack/cast/dodge movement
restrictions (`ActionBusy` / zero action speed) do not stow the weapon.

Saved: `weapons = { owned = { [id]: count }, equipped = "" | id }`,
`dao = { [class]: { level, xp } }`, `caches = { [cacheId]: true }`. All three are
in the `PlayerState` push (`weapons`, `dao`).

## Weapon models (contract with the modeler)
`ServerStorage.WeaponModels` (binary `assets/WeaponModels.rbxm`, built by
`art/weapons/place_weapons.luau`): one Model per model name (`Jian`, `Dadao`,
`Greatsword`, `Guandao`, `Spear`, `Staff`, `ManualScroll`). Meshes are Parts with
a SpecialMesh (MeshPart ids don't survive Rojo sync); `Tip`/`Base` attachments on
the PrimaryPart.
PrimaryPart = a small invisible part named the class's joint (`HiltR` for Jian
and Greatsword, `Hilt` for the rest), holding a Motor6D of the same name with
Part1 = the PrimaryPart and Part0 = nil. Everything welded to it, unanchored,
massless, no collide/touch/query. A missing model only warns: the weapon still
works, held invisibly.

Equip places the hilt at `arm.CFrame * joint.C0 * joint.C1:Inverse()` (including
the PrimaryPart's `PivotOffset` when calling `PivotTo`), parents the model into
the character so its internal welds activate, then connects `joint.Part0` to
the arm. Connecting before parenting can snap the hilt separately from its
meshes and bake an unwanted offset into their welds. Keep the attachment
derived from the template's joint frames; no per-weapon correction is needed.

## Tuning knobs
- `Config.Combat.CLASSES`: chains, hitboxes, max targets. Hit/hitStop are clip
  seconds and must match each clip's `Hit`/`Hit Stop` markers (check with
  `tools/anim_markers.luau`): the server validates hits against Config, not the
  markers. When a clip is re-uploaded, change its id in `assets/Animations.rbxmx`
  and re-check its timings.
- `Pacing.Weapons`: `NEUTRAL_LEVEL`, `STARTING`, `MULTIPLIER`, XP per hit / cast /
  manual, `XP_BASE`/`XP_PER_LEVEL`.
- `Weapons.Grades`: grade multipliers, colours and inventory frame tier (Mortal bronze, Spirit jade, Earth violet, Heaven gold; [inventory](../ui/inventory.md)).
- `server/Weapons.BREAKTHROUGH_STOW_SECONDS`: 1.6 s, matching the breakthrough
  effect's lifetime.

## Known gaps
- Sword, Saber have placeholder idles (Spear Idle, Bat Idle) and no walk.
- Equipping is refused only mid-action, not in combat.
- The sect weapon rack and five manual caches are placed and all reachable
  (positions in [map](map.md)); not yet claimed in a play session.
- Dadao and Guandao lead with the blade's back on their backhand steps (Saber 2
  and 4, Guandao 2): the clips were made for a double-bit axe.
- All six weapons preserve their mesh-to-hilt offsets in an Edit-mode attachment
  comparison after the equip-order fix. Animation playback, grips through full
  combos and the idle/walk overlay still need a player review.
