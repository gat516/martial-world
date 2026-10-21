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
  Models joined to the Right Arm by a Motor6D, not Backpack Tools, so they never
  fight the item Tools.
- **Dao comprehension**, level 0-10 per class: XP from landing M1 hits with the
  class (once per swing), casting its techniques and learning its manuals.
  Damage of M1 and the class's techniques = base x realm power x grade x Dao.
  Level 2 is neutral (x1.0); untrained (0) is x0.8 and mastery x1.3. A new
  player's Fist and Sword start at 2, so starting power is unchanged.
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
- `src/client/WeaponAnimator.luau`: the class's idle/walk on the local character.
- `src/client/CombatController.luau`: plays the class's chain (`profile.clip`).
- `assets/Animations.rbxmx`: `Animations.Weapons.<Class>.1..n`, `.Idle`, `.Walk`.
  Every animation id lives only here, so swapping a clip is a one-file edit.

## Data flow
Equip: client invokes `WeaponAction("equip", id)` -> the server checks ownership
and that no action is running -> `data.weapons.equipped`, clones
`ServerStorage.WeaponModels.<model>` into the character as `HeldWeapon` with its
`<joint>` Motor6D's Part0 = Right Arm, sets player `Weapon` and character
`WeaponClass`, pushes state. Respawns re-apply it. M1: `ActionRules.start(...,
class)` picks the chain from `WeaponClass` (client) / the equipped weapon
(server); `Combat.damageSwing` uses the class's hitbox, targets, step damage and
push, times `Weapons.multiplier`, and grants `XP_HIT` Dao XP when it lands.
Dao level-ups notify and push state; other XP rides the periodic state refresh.

Saved: `weapons = { owned = { [id]: count }, equipped = "" | id }`,
`dao = { [class]: { level, xp } }`, `caches = { [cacheId]: true }`. All three are
in the `PlayerState` push (`weapons`, `dao`).

## Weapon models (contract with the modeler)
`ServerStorage.WeaponModels` (`assets/WeaponModels.rbxmx`): one Model per model
name (`Jian`, `Dadao`, `Greatsword`, `Guandao`, `Spear`, `Staff`, `ManualScroll`).
PrimaryPart = a small invisible part named the class's joint (`HiltR` for Jian
and Greatsword, `Hilt` for the rest), holding a Motor6D of the same name with
Part1 = the PrimaryPart and Part0 = nil. Everything welded to it, unanchored,
massless, no collide/touch/query. A missing model only warns: the weapon still
works, held invisibly.

## Tuning knobs
- `Config.Combat.CLASSES`: chains, hitboxes, max targets. Hit/hitStop are clip
  seconds and must match each clip's `Hit`/`Hit Stop` markers (check with
  `tools/anim_markers.luau`): the server validates hits against Config, not the
  markers. When a clip is re-uploaded, change its id in `assets/Animations.rbxmx`
  and re-check its timings.
- `Pacing.Weapons`: `NEUTRAL_LEVEL`, `STARTING`, `MULTIPLIER`, XP per hit / cast /
  manual, `XP_BASE`/`XP_PER_LEVEL`.
- `Weapons.Grades`: grade multipliers and colours.

## Known gaps
- The held weapon is still drawn while an item Tool is out.
- Sword, Saber have placeholder idles (Spear Idle, Bat Idle) and no walk.
- Equipping is refused only mid-action, not in combat.
- Untested in game: grips, joints and the idle/walk overlay need a look in Studio.
