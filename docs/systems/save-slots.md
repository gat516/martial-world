# Save slots

## Purpose
A player keeps several cultivators. Each slot is a separate character with its
own progression (realm, inventory, peak, everything in the profile). Joining
lands on the slot screen: Play, New, Edit look and Delete. Characters change
only at join; there is no in-game switch.

## Design intent (user, 2026-10-23)
- "create a play system slot system new slot delete slot etc", and a way to edit
  a slot's customization. Delete has a clear confirm step (hold to delete).
- Data safety first: the old profile migrates into slot 1 losslessly, session
  locking and "a failed load never saves" still hold.
- Race and clan stick to the slot **position**, not the character in it: drawn
  free the first time New is pressed there, kept when the slot is deleted. So
  delete-then-new gives the same draw (no free reroll), and an account sees at
  most `Slots.MAX` free draws ever. Robux rerolls work on new and existing
  characters (the creator's Name / Identity step).
- The first name is set once: Edit look changes the look only (the name shows,
  locked, on the Identity step). Names are identity; a rename would be its own
  feature.
- The screen is calm and readable like the creator (same stage, same panel):
  cards show name and clan, race, realm and when last played.

## Key files
- `src/server/PlayerData.luau`: the `Account` record, `load` (account),
  `activate` (play a slot), `createSlot`, `deleteSlot`, `account`, `active`,
  `canSave`; the legacy wrap and the slot-off path.
- `src/server/Slots.luau`: the slot actions, fates (race and clan by position),
  the testbed seed, QuickPlay, and `awaitPlay` (Main's join waits here).
- `src/server/CharacterIdentity.luau`: the creator's server side; `confirm`
  commits a new slot or an edited look through Slots, `enter` spawns the played
  slot's character, reroll receipts go to `Account.rerollFor`.
- `src/server/Receipts.luau`: receipts are the account's (shared by slots).
- `src/client/CharacterCreator/Controller.luau`: the slot screen and the
  creator on one stage; `Modals.luau` (delete confirm, odds), `Components.luau`
  (`slotCard`).
- `assets/CharacterCreator.rbxmx` (`ReplicatedStorage.CharacterCreatorGui`, built
  by `art/ui/creator/build_gui.luau`): the slot page is `Root.Panel.Pages.Slots`
  beside the creator's pages; `Root.Modal` holds the Delete and Odds cards.

## Data
Slots on, one DataStore key per player, `a_<userId>`, session-locked as before:
```
{ data = Account, session = { job, t } }
Account = { av = 1, slots = { ["1"] = Data, ... },   -- string keys, "1".."MAX"
            fates = { ["1"] = { Race, Surname }, ... },  -- by position, kept on delete
            last = "1", settings, receipts,           -- shared by every slot
            rerollFor = "1",                          -- where a paid reroll lands
            trash = { slot, data, fate, at }? }       -- the last deleted slot
```
- Each slot's `Data` is the old profile schema with its own numbered migrations
  (v10 -> v11 adds `character = { firstName, look }`, empty until named).
- **Migration (lossless):** the first load finds `a_` empty, reads the old
  `u_<userId>` profile without writing it (waiting on its lock like a claim), and
  wraps it untouched into slot 1; settings and receipts are copied up (the slot
  keeps its copies). `u_` is never written again: it stays as a backup and is
  what a rollback would read. If that read fails, the load fails (unsaved
  session), so an empty account can never hide the old profile.
- **Playing a slot** (`activate`): its profile becomes `PlayerData.get`'s, with
  `settings` and `receipts` pointing at the account's tables, so every system
  works unchanged. Before Play, `get` is nil.
- **Delete:** only from the slot screen (never the played slot), only when the
  account can save. The server needs a token from `deleteAsk` (under
  `DELETE_TOKEN_SECONDS` old) and the slot's first name; the slot moves to
  `trash` (one entry, replaced by the next delete, dropped after `TRASH_DAYS`),
  then the account saves at once. The trash has no UI: support restores it by
  hand.
- **Failed load:** an empty unsaved account. The slot screen says so, Delete is
  hidden, and nothing is written.
- **Slots off** (`Config.Slots.ENABLED`, false in the live game for now): the old
  key is read and written exactly as before, seen as a one-slot account and
  played at once. Live data is untouched until slots ship.
- Offline cultivation and the daily qi are per slot (each slot has its own
  `lastLogoutUnix` and `lastDailyDay`).

## Flow
Join -> `PlayerData.load` (account) -> `Slots.awaitPlay` waits -> the client asks
`slots` and opens the slot screen ->
- **Play** (named slot): `play, id` -> the join resumes on that profile (test kit,
  offline qi, peak, garden, state) -> `CharacterIdentity.enter` shows its race,
  clan and name as attributes and spawns the character -> the screen fades out.
- **Create** (empty) or **Name & play** (a migrated profile with no name): `new,
  id` -> the position's fate is drawn (or shown) and saved -> the creator
  (Appearance, Hair, Name) -> Enter World: `confirm` checks everything, fills the
  slot and plays it.
- **Edit look**: `edit, id` -> the creator on the slot's look; Save look sends
  `confirm` (look only) -> back to the slot screen.
- **Delete**: the centred card, hold 1.5 s -> `deleteAsk`, `delete` -> the list
  refreshes.
All on the `CharacterAction` RemoteFunction (see `Slots.luau`'s header).

## Testbed
- The test build (in-memory store) starts every session with a ready "Tester" in
  slot 1 (default look, rolled race and clan, the test kit on Play) and an empty
  slot 2, so both Play and New can be tried.
- `QuickPlay` (a Workspace attribute in `test.project.json`, off by default)
  skips both screens and plays the last or first named slot at once, for combat
  testers.

## Tuning knobs
`Config.Slots`: `ENABLED`, `MAX` (3), `TRASH_DAYS` (7), `DELETE_TOKEN_SECONDS`
(30), `QUICK_PLAY`. Hold time: `Theme.Tween.Hold`.

## Known gaps
- Test place only (with the creator). Before turning slots on in the live game:
  set `Config.Slots.ENABLED = true` with the creator's shipping steps
  ([character creator](character-creator.md), Known gaps), then **shut down all
  servers** on release so no old-version server writes `u_` after a player's
  account has been made from it (their later `u_` progress would not carry over).
- A rollback after slots ship reads `u_`: progress made since the migration
  would be lost (the `a_` record is untouched and could be re-read by a fix).
- Untested in play: everything (the migration, locks with two keys, delete and
  trash, rerolls through `rerollFor`, QuickPlay, the screen's flow). Previewed in
  Studio's Edit view only, with sample data.
- No restore UI for the trash; no paid extra slots.
