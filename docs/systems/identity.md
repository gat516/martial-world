# Races, variants and traits

## Purpose
Who a character is: their race, a variant within it (Beast Folk: Fox, Wolf,
Tiger, Crane, Serpent), and traits, small perks that come from the race and
variant or are earned in play. Built 2026-10-23 at the user's request as one
modular, config-driven system. Test place only for now, like the character
screen it extends ([character creator](character-creator.md)).

## Design intent
- **Config apart from logic.** Everything a designer changes lives in
  `src/shared/Identity/`, one file per kind of thing; the code only reads it
  through `Registry`. Adding a race, a variant (a Bear), a trait or a new trait
  category is a config edit, never a code change.
- **Race and variant are separate.** A Beast Folk Fox is race `BeastFolk`,
  variant `Fox`, so anything can ask "is this Beast Folk?" and "which beast?".
  Variants are a per-race module (`Variants/<Race>.luau`), so any race can get
  variants the same way.
- **Availability is one file.** Release, hide or switch off any race, variant
  or trait, and say how it's obtained, without touching its definition. Serpent
  stays Hidden (testable by admins only) until its content is done (user,
  2026-10-23); releasing it is a Status and Acquire change.
- **One path for every change.** Normal play, game code and the admin panel all
  change a profile through `src/server/Traits.luau`, with the same checks. An
  admin can test Hidden content and force a trait past its Access, but never
  gets Disabled content, and players can never reach Hidden, Disabled or locked
  content: every pick is checked on the server.
- **No mechanics we haven't designed.** Traits, races and variants carry stat
  modifiers on the stats spirit roots already change, plus named `Mechanics`
  hooks for passives and abilities that don't exist yet. Nothing elaborate is
  built.
- Bloodlines aren't built ([bloodline](../character/bloodline.md)). Traits can
  already name bloodlines in their Access and requirements can test them; both
  read `data.bloodline.id` once it exists. The progression plan has bloodlines
  replacing races later; this system leaves room for either.

## Where to edit
| What | File |
|---|---|
| Race definitions (names, rarity, roll weight, innate traits, modifiers, mechanics, which variants module) | `src/shared/Identity/Races.luau` |
| Beast Folk variants (same fields) | `src/shared/Identity/Variants/BeastFolk.luau` |
| Trait definitions: racial / variant traits | `src/shared/Identity/Traits/Racial.luau` |
| Trait definitions: general traits | `src/shared/Identity/Traits/General.luau` |
| A new trait category | a new file in `Traits/`; its name is the category |
| Release, hide, disable; Roll / Select / Unlock; unlock requirements | `src/shared/Identity/Availability.luau` |
| A new kind of unlock requirement | one checker in `src/shared/Identity/Requirements.luau` |
| Passive or ability code for a `Mechanics` id | register `Traits.mechanics[id] = { attach, detach }` (server) |

Each file's header lists its fields. The vocabulary:
- **Status** (Availability): `Released`, `Hidden` (implemented, unreleased:
  admins only, left off every list players see), `Disabled` (off for everyone;
  an owner keeps the record but gets no effect, and a disabled race or variant
  is replaced on the next join).
- **Acquire** (races and variants, one or a list): `Roll` (the free join roll
  and the paid reroll, weighted), `Select` (picked freely on the character
  screen), `Unlock` (picked once `Requires` is met).
- **Access** (traits): `"Everyone"`, or `{ Races, Variants = { "BeastFolk.Fox" },
  Bloodlines }`. One variant named = exclusive; several = shared.
- **Obtain** (traits): `Innate` (from a race or variant's `InnateTraits`),
  `Unlock` (granted on its own when its `Requires` is met and it's open to the
  player), `Grant` (only when game code calls `Traits.grant`: a quest, an
  item).
- **Requires**: a list of `{ Kind = ..., ... }`: Realm (AtLeast "QC5"), Kills,
  BossKills, Breakthroughs (AtLeast n), Quest (Id), Item (Id, Count), Trait,
  Race, Variant, Bloodline (Id).
- **Modifiers**: `health`, `walk`, `jump`, `strike`, `guard`, `technique`,
  `growth`, `regen`, the spirit root perk kinds (amounts read the same way:
  shares, except `walk` in studs/s). They add to the root perk at the same
  places (Cultivation.applyStats, Combat, Garden, the Roots regen loop).
- **Excludes** (traits): traits it can't be held with.

A variant's trait pool is its race's and its own innate traits plus every
trait whose Access names it (`Registry.traitPool`).

## Key files
- `src/shared/Identity/Registry.luau`: the only reader of the config, shared by
  server and client: lookups, availability, roll and choice pools, Access,
  `active`, `stat`, `label`, `accessLabel`, and `problems()`, a config check
  that warns at load about unknown ids, kinds and statuses, innate traits their
  own Access leaves out, and an empty race roll.
- `src/server/Traits.luau`: owns the profile's `identity`: `load` (join),
  `sync` (innate traits follow the race and variant, Unlock traits are granted,
  effects reapply), `setRace`, `rollRace`, `choose` (a player's pick),
  `grant` (game code), `adminGrant` / `adminRemove` / `adminSetRace`,
  `describe` and `check`. Hooks: `onGained`, `onLost`, `mechanics`.
- `src/server/CharacterIdentity.luau`: the character screen's server side;
  rolls, rerolls and picks go through Traits; it saves the last name too.
- `src/server/Admin.luau`: `traitInfo`, `traitGrant` (force), `traitRemove`,
  `traitSetRace`, `traitSync`, each for a target player (UserId, name, or a
  unique name prefix; empty = yourself).
- Profile (`PlayerData`): `identity = { race, variant, surname, traits = {
  [id] = { src, t, force } } }`. `src` is innate, unlock, grant or admin.
- Player attributes: `Race`, `RaceVariant`, `Surname`, `Traits` and
  `TraitsInactive` (comma lists of owned trait ids that do or don't apply now).

## Flow
Join: `Main.server` loads the profile, then `CharacterIdentity.load`: the
saved race and variant stay unless the config dropped them (deleted or
Disabled; Hidden ones stay, an admin gave them), else a free roll; then a sync.
Unlock checks run after kills, breakthroughs, claimed quests and an admin realm
jump. A race change (reroll, pick, admin) drops the old innate traits, adds the
new ones and keeps the rest; owned traits the new race can't use stay in the
profile as inactive (no effect) and come back if the race does.

## Known gaps
- Test place only, with the character screen: `Main.server` loads identities
  under `Config.TESTBED`. In the main game races are empty and every modifier is 0.
- The trait values and the new races' weights are first guesses, not balanced.
- No `Mechanics` handlers exist yet, so passives and abilities named in config
  do nothing.
- Nothing uses `Traits.grant` yet (no quest or item gives a Grant trait).
- Bloodlines aren't built, so bloodline Access and requirements never match.
- Spirit Fox (an old placeholder race) overlaps Beast Folk Fox; decide whether
  to keep it.
- Unlock traits are checked on events, not continuously: a requirement met some
  other way (an item picked up) waits for the next kill, breakthrough or quest.
