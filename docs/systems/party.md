# Parties, the player card and safe zones

Reasons to meet other players ([roadmap](../roadmap.md) 3e). A party is never required:
it adds a small qi bonus, lets nearby members share each other's kills, and gives a
one-tap ride to a member. PvP stays off and there is no trading (roadmap 3f).
Backend built 2026-10-23 (untested); the UI is still to build (ui-designer, from the
contract below).

Files: `src/server/Party.luau` (parties, card, people list, friend nudges),
`src/server/SafeZone.luau`, `Travel.toPlayer` (join and visit), `EnemyService.died`
(kill credit). Tuning: `Pacing.Party`, `Pacing.SafeZone`. Remotes: `PartyAction`,
`PartyState` (`assets/Remotes.rbxmx`).

## Rules
- **Server-local.** Up to `MAX_SIZE` (4), same server only, nothing saved. Leaving the
  game leaves the party and withdraws your invites.
- **Invites:** the leader (or a solo player, who leads the party it makes) invites anyone
  in the server; no range rule (the People list reaches everyone, the card is also
  opened by tapping a character or namecard). One invite every `INVITE_COOLDOWN` (2 s)
  per player. An invite lapses after `INVITE_SECONDS` (30). Accepting answers all your
  other invites; you must leave a party before accepting another. A full party
  withdraws its leader's other invites.
- **Leave / kick / promote:** anyone leaves; the leader kicks or hands the lead on. When
  the leader leaves, the next member in join order leads. A party of one disbands.

## What a party gives
- **Kill credit (everyone, party or not):** each player who dealt `Pacing.Rewards`
  `KILL_SHARE` (10%, bosses `BOSS_KILL_SHARE` 15%) of a beast's health gets their own full
  drop: realm-scaled qi, stones, the `onKill` rolls (loot, seeds, first-kill foundation
  experiences, kill milestones). The top damager always qualifies. Nobody's drop
  comes out of anyone else's, so there is no kill-stealing. The share stays so one tag
  in a crowd doesn't earn a boss's drops; set it to 0 to credit every damager in full.
- **Helpers** get `HELPER_QI_SHARE` (half) of their own realm-scaled qi for the beast
  and nothing else (no stones, drops or kill count): anyone who hit it for less than
  the share, and a credited player's party members within `RADIUS` (120 studs) of the
  kill who didn't hit it.
- **Group bonus:** a credited player's beast qi +`BONUS_PER_MEMBER` (5%) per other party
  member within `RADIUS` of the kill, capped at `BONUS_CAP` (15%).
- Realm suppression applies as before (to damage, `Realms.suppression`); qi is always
  scaled to the receiver's own realm, so a senior helping still earns their own.
- **Heart demon:** `stats.partied` counts seconds in a party with a member within
  `RADIUS`; the trial asks about company or solitude ([heart-demon](heart-demon.md)).

## Join and visit (`Travel.toPlayer`)
Both share the ride checks (taught the formation, alive, out of combat, cooldown) and
start from a teleport array or the sect's ground (`Gates.inSect`).
- **Join** (party members only): the array nearest the member that your realm has
  opened. The Sect Gate rule is waived (it's the social shortcut into the wilds). Within
  40 studs of them it says you're already there. The testbed has no arrays, so you land
  beside them.
- **Visit peak** (anyone with a peak): their peak's array (`Peaks.homeCFrame`). Visiting
  grants no build rights.

## Safe zones (`SafeZone.luau`)
The sect's grounds (`Gates.inSect`: plaza, paths, peaks) and every spirit peak's build
area (yours or one you're visiting; `SafeZone.peakAt`). `SafeZone.at(position)` and
`SafeZone.contains(player)` are the one definition; the server keeps the player
attribute `InSafeZone` current every 0.5 s. `Haul.safeAt` (bank points) is a safe zone
or any teleport array. Testbed: only within `Pacing.SafeZone.TESTBED_RADIUS` (24) of
`Workspace.Arena.SpawnPad`, where the TestPeak sits. Safe zones don't stop combat yet
(no PvP exists; beasts don't spawn there).

## UI contract (to build: ui-designer)
`PartyAction` (RemoteFunction) returns `(ok, payload|message)`; show the message as a
toast when `ok` is false. `PartyState` (RemoteEvent) is `(kind, payload)`.

**Player card** (`PartyAction "card", userId`): opened by tapping another player's
character or namecard, or a name in the People list. Fields: `name` (first and last
name, else display name), `displayName`, `username`, `realm` (stage name), `major`,
`minor`, `race`/`raceName`, `variant`/`variantName`, `bloodline` (nil: show "None"),
`hall` (nil: show "No Hall"), `friend`, `self`, `party = { inParty, size, leader,
withYou }`. Buttons by flag: `canInvite` -> "invite"; `invitedYou` -> "accept" /
"decline"; `canKick` -> "kick" (plus "promote", same flag); `withYou` -> "Leave party"
on your own row of the pips; `canJoin` -> "join"; `canVisit` -> "visit". Re-fetch the
card after an action.

**People list** (`PartyAction "people"`): a HUD tile shown only while the player
attribute `InSafeZone` is true opens it. Rows of `{ userId, name, realm, raceName,
friend, withYou, inParty }`, friends first then by name, yourself left out. Tapping a
row opens the card.

**Invite prompt** (`PartyState "invite"`): `{ from, name, realm, partySize, expires }`
(`expires` in server time: `workspace:GetServerTimeNow()`). A small prompt with a
countdown, Accept / Decline ("accept"/"decline", `from`). `"inviteGone", userId,
reason` ("expired", "withdrawn", "answered") closes it. On load, `PartyAction
"state"` returns `{ party, invites }` to restore both.

**Party pips** (`PartyState "party"`, snapshot or nil when solo): `{ id, leader, size,
max, members = { { userId, name, realm, health (0-1, 5% steps), leader, near, self } }
}` in join order. A small stack under the vitals: name, a health sliver, a leader mark,
dimmed when not `near` (outside `RADIUS`). Re-sent only on change, at most every
`PUSH_SECONDS`. The player attribute `Party` (the party id) lets nameplates mark members.
Keep it small on phones (the HUD is already full).

**Travel menu:** a "Join <name>" button per other member (`PartyAction "join"`) beside
the arrays; TravelMenu's buttons are prebuilt in the Hud, so this needs the ui-designer.

**Friend nudge** (`PartyState "friendHere", { userId, name }`): toast "<name> is on this
mountain", once per session per friend, both ways.

## Testing
The testbed stand-in (`TestbedDummy`) is not a Player, so parties need two clients:
Studio's Test > Clients and Servers with 2 players. No UI calls the remotes yet; drive
them from the command bar or wait for the UI.

## Known gaps
- All UI (card, people tile, invite prompt, pips, join button, friend toast).
- No cross-server parties, party chat or shared quests; co-op rifts and group world
  events (roadmap 3e) aren't built.
- Spar duels from the card are deferred (roadmap 3f).
