# Titles

Built 2026-10-24 (code only, untested in play). The user: "create a title / title
equip / title storage system and just come up with some titles. remember, we're only
at foundation establishment."

## Purpose
Status a player shows other players: a short line over their namecard that says what
they've done. Earned once, kept forever, one worn at a time (or none). Nothing to
grind for power: titles give no stats.

## Design intent
- Only what the game has now, up to Foundation Establishment. No Core Formation or
  later titles until those realms exist.
- Earned from the record the profile already keeps (realm, `data.stats`, the sect,
  the Herbarium, foundation percents, the root, weapon Dao, heart-demon trials), so a
  veteran gets everything they've already done on their next join.
- Short names: they sit on a phone's namecard. 18 characters or fewer; the one
  exception is "Foundation Perfected" (20), the user's own name for FE9.
- The colour is the rarity's, on the inventory's ladder (`Items.Rarities`: bronze,
  silver, jade, violet, gold).
- The heart-demon trial gives a **Dao heart** (design review [heart-demon](../design-reviews/heart-demon.md)
  rec 1): the path answer picks it, a denial picks the road the record shows, so
  there's nothing to fail. Calming a demon (no denials) is its own title.

## The titles (40)
| Category | Title | How it's earned | Rarity |
|---|---|---|---|
| Realm | Qi Refiner | Reach Qi Refining 1 | Uncommon |
| Realm | Peak of Refining | Reach Qi Refining 9 | Rare |
| Realm | Foundation Builder | Reach Foundation Establishment 1 | Epic |
| Realm | Foundation Perfected | Reach Foundation Establishment 9 | Legendary |
| Dao Heart | Heart of the Blade | Trial, hunter's path: "The fight is how I grow" (or the denial) | Rare |
| Dao Heart | Restless Blade | Trial, hunter's path: "I lost my peace out there" | Rare |
| Dao Heart | Heart of the Lotus | Trial, gardener's path: "My garden is enough" (or the denial) | Rare |
| Dao Heart | Unhidden Heart | Trial, gardener's path: "Yes. It frightened me." | Rare |
| Dao Heart | Two-Road Heart | Trial, both roads (any answer) | Rare |
| Dao Heart | Heart of Stillness | Trial, the still road (any answer) | Rare |
| Dao Heart | Calm Heart | Calm a heart demon (no denials) | Epic |
| Sect | Outer Disciple | Claim one sect daily | Common |
| Sect | Inner Disciple | Sect rank Inner | Rare |
| Sect | Core Disciple | Sect rank Core | Epic |
| Hunt | Wolf King's Bane | Kill the Elder Wolf King | Rare |
| Hunt | Jiao Slayer | Kill the Jade Jiao | Rare |
| Hunt | Thunder Ape Slayer | Kill the Thunder Ape | Epic |
| Hunt | Nine-Tail Hunter | Kill the Nine-Tailed Fox | Epic |
| Hunt | Bane of Kings | Kill all four bosses | Legendary |
| Hunt | Elite Hunter | 10 elite beasts (`stats.elites`) | Uncommon |
| Hunt | Apex Hunter | 1 apex beast (`stats.apexes`) | Rare |
| Home | Page Keeper | One Herbarium page complete | Uncommon |
| Home | Master Herbalist | Every herb in the Herbarium | Legendary |
| Home | Abode Builder | Peak score 60 (`stats.peakBest`) | Uncommon |
| Home | Lord of the Peak | Peak score 250 | Epic |
| Home | Secluded One | 10 h in seclusion (`stats.secluded`) | Uncommon |
| Home | Hermit of Clouds | 100 h in seclusion | Epic |
| Home | Prudent Hauler | Store all 50 times (`stats.stored`) | Uncommon |
| Path | Deep Foundation | Any stage at 150% foundation or more | Rare |
| Path | Earth Root | A spirit root at Earth grade (any element held) | Rare |
| Path | Heavenly Root | A spirit root at Heaven grade | Legendary |
| Path | Burning Meridians | 3 qi surges (`stats.surges`) | Rare |
| Path | Fellow Traveler | 1 h in a party with a member nearby (`stats.partied`) | Uncommon |
| Weapon Dao | Fist / Sword / Saber / Greatsword / Guandao / Spear / Staff Master | That class at Dao 10 (the max) | Epic |

## How it works
- **Defs:** `src/shared/Titles.luau`: `Titles.Defs[id]` = `{ id, name, how, rarity,
  category, rule }`, `Titles.Order` (picker order), `Titles.Categories` (groups, in
  order: Realm, Dao Heart, Sect, Hunt, Home, Path, Weapon Dao), `Titles.color(id)`.
  `how` is the one line the picker shows, earned or not. The rule kinds are listed at
  the top of the file.
- **Data:** `data.titles = { owned = { [id] = os.time() earned }, equipped = id or "" }`
  (missing-field default, no schema bump).
- **Grants:** `src/server/Titles.luau` `Titles.check` runs after every state push
  (`Cultivation.onPush`, wired in Main), so kills, breakthroughs, claims, trials and
  the periodic refresh (time-based stats) all reach it with no per-system hook. It
  grants every met rule not yet owned. The session's first check grants a veteran's
  backlog with one banner ("N titles"); after that each title gets its own gold banner
  (Effect "reward": kicker TITLE EARNED, the name, its rarity as the tag in its
  colour, the how line). Analytics event `TitleEarned` (field: the id).
- **Equip:** CultivationAction `"title", "equip", id` (must be owned) and
  `"title", "unequip"` -> `(ok, equipped id or "")`. Main routes `"title"` to
  `Titles.handle`, like `"sect"`.
- **Shown:** the worn title is the Player's `Title` (its name) and `TitleColor` (its
  rarity colour) attributes, nil for none, set on every check and equip. The
  namecard over the head already reads them ([nameplates](nameplates.md)).
- **State:** `PlayerState.titles` (the data table as is); `State.Snapshot.titles` on the
  client.
- **Heart demon:** the path question's answers carry a `title` id; `HeartDemon.answer`
  stores the first question's in the trial record (`trials[major].title`) and adds a
  closing line "Your Dao heart: <name>."; the trial's state push grants it (rule kind
  `heart`). One per trial, so QC9, QR9 and FE9 can each give a different one.
- Titles add no `data.stats` counter (they read the existing ones), so the
  heart-demon trial needs no new question.

## UI contract (for ui-designer: the picker)
Lives on the Self card ([character window](../character/character-window.md)):
- **Title row** on the Self card: "Title", the worn title's name in its colour (or
  "None" muted), and the count earned ("12 / 40"). Tapping it opens the list.
- **The list** (a ListWindow-style scroll, mobile first), grouped by
  `Titles.Categories`, each group in `Titles.Order`:
  - **Earned:** the name in `Titles.color(id)`, the `how` line under it, small; the
    worn one marked (a seal or tick). Tapping it equips it; tapping the worn one
    unequips (or an explicit "Wear none" row at the top).
  - **Locked:** the name as a gray silhouette (a blank bar or dimmed "???", not the
    real name, so earning it is a reveal), the `how` line readable, so players know
    what to chase. Heart titles show their how line too.
  - Optional NEW mark: `owned[id]` is the os.time() it was earned; the picker can
    keep the last-opened time client-side and mark later ones.
- Calls: `Remotes.CultivationAction:InvokeServer("title", "equip", id)` /
  `("title", "unequip")`; refresh from the next PlayerState (`State.current.titles`).
- Reads only: `Shared.Titles` and `State.current.titles`. The banner on earning is
  already done server-side.

## Files
`src/shared/Titles.luau` (defs), `src/server/Titles.luau` (rules, grants, equip,
attributes), hooks in `Main.server.luau` (onPush, `onChanged`, the action route,
`forget`), `Cultivation.pushState` (`titles`), `PlayerData` (`titles`, `HeartTrial.title`),
`HeartDemon.luau` (path answers' `title`), client `State.luau` (type), `Nameplates.luau`
(shows it).

## Tuning
Names, lines, rarities and thresholds are all in `src/shared/Titles.luau`.

## Known gaps
- No picker yet (ui-designer, from the contract above). Until then a title can only be
  worn through the remote; nothing calls it.
- Untested in play: grants on join (the backlog banner), the banner per title, the
  attribute on the namecard, the heart-demon line.
- The HUD has no title line for your own (your own namecard isn't shown to you).
- Banners clear when a window opens (Rewards), so a title earned with a window open
  shows no banner; the picker is where it's seen for sure.
- Heart titles from trials faced before titles existed aren't granted (old trial
  records have no `title`); Calm Heart is.
