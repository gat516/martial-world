# Races, variants and traits

## Purpose
Who a character is: their race, a variant within it (Beast Folk: Wolf,
Tiger, Crane, Serpent), and traits, small perks that come from the race and
variant or are earned in play. Built 2026-10-23 at the user's request as one
modular, config-driven system. Test place only for now, like the character
screen it extends ([character creator](character-creator.md)).

## Design intent
- **Config apart from logic.** Everything a designer changes lives in
  `src/shared/Identity/`, one file per kind of thing; the code only reads it
  through `Registry`. Adding a race, a variant (a Bear), a trait or a new trait
  category is a config edit, never a code change.
- **Race and variant are separate.** A Beast Folk Wolf is race `BeastFolk`,
  variant `Wolf`, so anything can ask "is this Beast Folk?" and "which beast?".
  There is no Beast Folk Fox: foxes are the Spirit Fox race, which holds the fox
  traits (Fox Cunning innate, Nine Tails exclusive) (user, 2026-10-23). Its
  tail and ear shapes are free looks, not variants (below).
  Variants are a per-race module (`Variants/<Race>.luau`), so any race can get
  variants the same way.
- **Variants carry traits, looks are free** (user, 2026-10-23). A variant with
  traits or stats (Beast Folk Wolf, Tiger...) is rolled with the race and
  rerolled for Robux. A purely cosmetic choice inside a race (Spirit Fox's tail
  and ears) is a `Looks` slot on the race: the player picks it with arrows on the
  creator's Fate step, free, and can change it whenever they edit the look.
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
| Free looks a race offers (Spirit Fox's tail and ears: `Looks`) | `src/shared/Identity/Races.luau` |
| Trait definitions: racial / variant traits | `src/shared/Identity/Traits/Racial.luau` |
| Trait definitions: general traits | `src/shared/Identity/Traits/General.luau` |
| A new trait category | a new file in `Traits/`; its name is the category |
| Release, hide, disable; Roll / Select / Unlock; unlock requirements | `src/shared/Identity/Availability.luau` |
| A new kind of unlock requirement | one checker in `src/shared/Identity/Requirements.luau` |
| Accessories a race, variant or trait wears (`Cosmetics`) | `ReplicatedStorage.Cosmetics` (`assets/Cosmetics/<set>.rbxm`, one Folder per set), ids listed on the definition |
| Passive or ability code for a `Mechanics` id | register `Traits.mechanics[id] = { attach, detach }` (server) |

Each file's header lists its fields. The vocabulary:
- **Status** (Availability): `Released`, `Hidden` (implemented, unreleased:
  admins only, left off every list players see), `Disabled` (off for everyone;
  an owner keeps the record but gets no effect, and a disabled race or variant
  is replaced on the next join).
- **Acquire** (races and variants, one or a list): `Roll` (the free join roll
  and the paid reroll, weighted), `Select` (picked freely on the character
  screen), `Unlock` (picked once `Requires` is met).
- **Access** (traits): `"Everyone"`, or `{ Races, Variants = { "BeastFolk.Wolf" },
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
  Plus `size`: a share added to body size (Titan Frame: 0.15, 15% larger; see
  Body size below).
- **Excludes** (traits): traits it can't be held with.
- **Looks** (races): free cosmetic picks, a list of slots `{ Id, DisplayName,
  Options = { { Id, DisplayName, Cosmetics } } }`; the first option is the
  default. The pick is the slot's look field `RaceLook = { [slot]: option }`
  (`character.look.RaceLook` in the slot's profile). `Registry.lookPicks(race,
  raw)` fills in defaults and drops anything that isn't the race's (so picks
  saved for another race fall back after a reroll), `Registry.checkLook` is the
  server's check on confirm, and `Registry.cosmetics` adds the picked options'
  Cosmetics. Anything with traits or stats is a variant instead.

A variant's trait pool is its race's and its own innate traits plus every
trait whose Access names it (`Registry.traitPool`).

## Key files
- `src/shared/Identity/Registry.luau`: the only reader of the config, shared by
  server and client: lookups, availability, roll and choice pools, Access,
  `active`, `stat`, `label`, `accessLabel`, and `problems()`, a config check
  that warns at load about unknown ids, kinds and statuses, innate traits their
  own Access leaves out, and an empty race roll.
- `src/server/Slots.luau`: a slot position's fate holds its race and variant
  (with the last name): `Slots.fate` draws them (free, Availability Roll) where
  missing or dropped, `Slots.reroll("Race")` draws both again.
- `src/server/Traits.luau`: owns the played profile's `identity`: `load` (Play),
  `sync` (innate traits follow the race and variant, Unlock traits are granted,
  effects reapply), `setRace`, `rollRace`, `choose` (a player's pick),
  `grant` (game code), `adminGrant` / `adminRemove` / `adminSetRace`,
  `describe` and `check`. Hooks: `onGained`, `onLost`, `mechanics`.
- `src/server/CharacterIdentity.luau`: the character screen's server side;
  `load` copies the played slot's fate into `identity` and runs `Traits.load`.
- `src/server/Admin.luau`: `traitInfo`, `traitGrant` (force), `traitRemove`,
  `traitSetRace`, `traitSync`, each for a target player (UserId, name, or a
  unique name prefix; empty = yourself).
- Data: the slot position's fate (`Account.fates[id]`, [save slots](save-slots.md))
  is `{ Race, Variant, Surname }`, kept when the slot is deleted like the race
  always was. The slot's profile (`PlayerData`) holds `identity = { race, variant,
  traits = { [id] = { src, t, force } } }`: traits are the character's (a new
  character in the same position starts with only the innate ones), and race and
  variant are a copy of the fate that Traits reads. `Traits.setRace` writes a
  change back to the played slot's fate. `src` is innate, unlock, grant or admin.
- Player attributes: `Race`, `RaceVariant`, `Surname`, `Traits` and
  `TraitsInactive` (comma lists of owned trait ids that do or don't apply now).

## Flow
New slot: the creator shows the position's fate (race, variant, clan), drawn the
first time New is pressed there; a reroll draws race and variant together.
Play: `Main.server` activates the slot's profile, then `CharacterIdentity.load`
copies the fate in: the race and variant stay unless the config dropped them
(deleted or Disabled; Hidden ones stay, an admin gave them), else a free draw
(a kept race only draws a new variant); then a sync. A fate from before variants
draws just its variant. With slots off (the live game) the fate isn't saved, so
the profile's own copy is kept instead.
Unlock checks run after kills, breakthroughs, claimed quests and an admin realm
jump. A race change (reroll, pick, admin) drops the old innate traits, adds the
new ones and keeps the rest; owned traits the new race can't use stay in the
profile as inactive (no effect) and come back if the race does.

## Admin panel (Traits tab)
F2 opens the admin panel (PC, admins only); its header has two tabs, Tools (the
old sections) and Traits (`src/client/AdminTraits.luau`, `Hud.AdminPanel.Traits`).
The Traits tab loads you on first open, then:
- **Player**: type a name, display-name prefix or UserId and press Enter, or pick
  one of the server's players from the chips under the box (filtered as you
  type; shown when there's someone besides you); **Me** goes back to yourself.
  The line under it shows who's loaded and their race label; **Sync** re-runs
  innate and unlock checks for them (`traitSync`).
- **Race / variant**: a chip per race (and per variant of their race); the
  current one is gold. Hidden ones carry a small "hidden" in blue (assignable,
  for testing), Disabled ones are struck through, faded and refuse with a toast.
  Picking a race lands on a rollable variant (`traitSetRace`, variant "").
- **Held traits (n)**: their traits with tags (rarity, Hidden/Disabled status,
  who it's for when not Everyone, Forced, Inactive) and an info line (category,
  Obtain, requirements, source). Remove on each.
- **All traits**: every trait in the config, searchable (name, id, category,
  rarity, Obtain, access, status) and filtered by All, each category, or Their
  pool (`Registry.traitPool` of the loaded race and variant). The button says
  what it will do: Give (open to them), Force (outside its Access; marked
  forced), Remove (held); a Disabled trait has none. Clicking a row selects it
  (gold name, lit rim; one at a time) and opens its details: description,
  modifiers, who it's for, Excludes, Mechanics, id, and what it means for the
  loaded player (holds it, open to them, or Force needed), beside the button.
Every action toasts the server's message and reloads the target (`traitInfo`),
which also reloads when the target's Race/Traits attributes change.

## Character screen
The creator's Fate step shows the race row as "Beast Folk (Wolf)" in the
variant's rarity, then an arrow picker per `Looks` slot of the race ("Tail:
Plume 1 / 3"; none when it has no looks), then the clan; so do the nameplate under the preview and the slot cards
(`Registry.label`). The odds card lists the rollable races
(`Registry.racePool("Roll")`), then "<Race> variants" for each race with variants
(`Registry.variantPool(race, "Roll")`, chances within the race), the player's own
marked; Hidden and Disabled ones never show. There's no race or variant picker
([character creator](character-creator.md) known gaps).

## Cosmetics
Races, variants and traits can name accessories to wear (`Cosmetics = { ... }`,
ids of Accessories anywhere under `ReplicatedStorage.Cosmetics`). That's the
folder `assets/Cosmetics/` (mapped in both projects), one `.rbxm` per set, each a
Folder of Accessories, so sets are built and exported separately. It's in
ReplicatedStorage because the creator preview wears them too. The builds and
joint names are in `art/player/cosmetics/README.md`; how new ones are made is
[player accessories](../character/player-accessories.md).

| Who | Wears | Set |
|---|---|---|
| Spirit Fox (Looks: Tail Plume / Crescent / Wisp, Ears Sleek / Broad / Long, picked freely) | FoxTailPlume / FoxTailCrescent / FoxTailWisp, FoxEarsSleek / FoxEarsBroad / FoxEarsLong | Fox (skinned Blender meshes) |
| Beast Folk Wolf | WolfEars, WolfTail | BeastFolk (part-built placeholders) |
| Beast Folk Serpent | SerpentFinsSovereign, SerpentScalesSovereign | Serpent (Blender meshes; fins skinned, plates rigid) |
| Beast Folk Tiger | TigerEarsRound, TigerTailCurl, TigerWhiskersMarks | Tiger (skinned Blender meshes) |
| Beast Folk Crane | CraneHeadCascade, CraneFanCascade | Crane (skinned Blender meshes) |
| Dragonblood | DragonHornsAntler, DragonTailTuft | Dragonblood (skinned Blender meshes) |
| Demonic Human (Looks: Horns Ram / Swept / Crescent, Tail Whip / Hook / Trail, picked freely) | DemonHornsRam / DemonHornsSwept / DemonHornsCrescent, DemonTailWhip / DemonTailHook / DemonTailTrail | DemonicHuman (skinned Blender meshes) |
| Stone Spirit / Ghost | StoneShards / GhostWisps | Spirits (part-built placeholders) |

Spirit Fox's three tails and three ear shapes are its `Looks` (Tail, Ears), each
picked freely and separately on the creator's Fate step (user, 2026-10-23: purely
cosmetic pieces are free arrow picks, not rolled variants; they were rolled
variants pairing one tail with one ear shape before). Each has its own bones
(`EarL`/`EarR`, `Tail1..Tail5`) and a recolourable part per colour region
(`art/player/cosmetics/fox/README.md`). The fox traits stay on the race. A Spirit
Fox saved with an old variant drops it on its next join (`Slots.fate` clears the
variant of a race without variants) and wears the default looks until edited.

The Crane set holds three looks, each a head piece (red crest and white-and-black
plumes) and a tail fan: Cascade (the Crane variant's default), Scholar and Ascendant.
Scholar and Ascendant aren't worn by anything yet; they can become Crane `Looks` on
the Fate step (a variant-level Looks list doesn't exist yet: Looks are per race)
(`art/player/cosmetics/crane/README.md`).

The Tiger set holds three looks, each ears, a tail and whiskers (FaceFrontAttachment):
Cub (the Tiger variant's default), Feral and Regal. Feral and Regal aren't worn by
anything yet; they wait for a style picker (`art/player/cosmetics/tiger/README.md`).

The Dragonblood set holds three looks, each horns and a tail: Antler (worn; the
user's favourite part-built DragonHorns, remodelled), Celestial and Cub. Celestial and
Cub wait for a style picker (`art/player/cosmetics/dragonblood/README.md`).

The Serpent variant has three Blender-built directions, all kept (user, 2026-10-23): fins
`SerpentFinsVeil`, `SerpentFinsSovereign`, `SerpentFinsFang` and face plates
`SerpentScalesVeil`, `SerpentScalesSovereign`, `SerpentScalesFang`, any fins with any plates
(`art/player/cosmetics/serpent/README.md`). The variant wears Sovereign; Veil and Fang wait for
a style picker. They replace the part-built `SerpentScales` and `SerpentTail` (still in
`BeastFolk.rbxm`, unused), so the Serpent has no tail.

Human (the plain race) and Giant (its look is its size) wear nothing (user,
2026-10-23: "no need to go super crazy"). `Traits.applyBody` adds the ones the profile
calls for and removes the rest (each worn one carries a `Cosmetic` attribute with
its id) on every spawn, every trait, race or variant change, and after dress-up
(ApplyDescription strips accessories). They go on at scale 1 and grow with the
body. A missing template warns once and is skipped.

Demonic Human's horns and tail are its `Looks` (Horns: Ram, Swept, Crescent; Tail:
Whip, Hook, Trail; the first of each is the default), picked freely, any horns with any
tail (user, 2026-10-23). They replace the part-built `DemonHorns` (still in
`Spirits.rbxm`, unused) (`art/player/cosmetics/demonic-human/README.md`). Its flame
wisp is VFX, not built yet: it attaches at each tail's `VfxWisp` bone under `Tail5`.

The creator's preview dummy wears the drawn race's look too (`Look.race`):
`Registry.fresh(race, variant, raceLook)` stands in for a new character (only innate
traits), and `Preview.setRaceLook` puts its cosmetics on (rigid copies, no
joints, at scale 1) and scales the body, feet kept on the pedestal; the camera
pulls back by the same share so a bigger body still fits the stage (user,
2026-10-23) and reads big against the pedestal. It follows
every race reroll, and the slot screen shows each slot's race the same way.

## Body size
The `size` modifier (Titan Frame: 15% larger, user 2026-10-23; 25% was too big) scales the character with
`Model:ScaleTo` on the server (`Traits.applySize`, clamped 0.5 to 2), so parts,
joints, accessories and the held weapon scale together and animations keep
working. The root moves up so the feet stay on the ground. It's applied:
- on every spawn, once the avatar has loaded (`Traits.watch`);
- whenever traits, race or variant change (`Traits.publish`), and taken off the
  same way (back to 1 when the trait is removed or no longer applies);
- around dress-up: `CharacterIdentity.dress` scales the body to 1, dresses it
  (ApplyDescription, hair, clothes), then reapplies the size, so accessories
  always go on at scale 1 and grow with the body (attribute `Dressing` while it runs);
- to weapons: `Weapons.apply` scales a weapon to the body before attaching it
  (ScaleTo scales the hand joint's C0/C1 too), and a held weapon grows with the body.
On the client, `HeadLook` scales its cached neck offset by the body's scale, or
the head would sink after a resize.
Hitboxes and reach don't change with size, on purpose (balance): strikes use
boxes from the root (`Shared.Hitbox`, `Config.CLASSES` plus `HITBOX_SLACK`),
enemy attack areas test the root within `AREA_HEIGHT` (8 studs) and a fixed
`PLAYER_RADIUS`. Checked 2026-10-23 against every beast in the test arena:
the same hits at 1 and 1.25 (so at 1.15 too). Walk speed and jump height stay in studs.
The dash scales with the body (`CombatController.startDash`: speed times the
body's scale), so a giant dashes the same distance in body lengths (user,
2026-10-23: it felt short). Measured before that change: the same 9.3 studs at
1 and 1.15, so the plain dash wasn't slowed, it just read short from a bigger body.

## Known gaps
- Test place only, with the character screen: `Main.server` loads identities
  under `Config.TESTBED`. In the main game races are empty and every modifier is 0.
- No picker for Select or Unlock races and variants since the creator rewrite
  (none exist today). The creator runs before Play, so a picker needs Requires
  checked against the slot's profile from the slot screen; `Traits.choose` only
  works on the played slot.
- The trait values and the new races' weights are first guesses, not balanced.
- A giant is no easier to hit (enemy areas use a fixed player radius); widen
  `PLAYER_RADIUS` by the body's scale if that should change.
- Body size is untested on a phone, in seats (meditation) and with Tools held
  in the hand (herbs): those place by joints too, so they should follow, but
  nobody has looked.
- No `Mechanics` handlers exist yet, so passives and abilities named in config
  do nothing.
- Nothing uses `Traits.grant` yet (no quest or item gives a Grant trait).
- Bloodlines aren't built, so bloodline Access and requirements never match.
- The admin Traits tab lists every server player as a chip, up to six; a big server needs the search box.
- Unlock traits are checked on events, not continuously: a requirement met some
  other way (an item picked up) waits for the next kill, breakthrough or quest.
