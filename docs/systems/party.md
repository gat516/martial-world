# Parties, the player card and safe zones

Reasons to meet other players ([roadmap](../roadmap.md) 3e). A party is never required:
it adds a small qi bonus, lets nearby members share each other's kills, and gives a
one-tap ride to a member. PvP stays off and there is no trading (roadmap 3f).
Backend built 2026-10-23; the UI (card, People, invite prompt, pips, friend toast) built
the same day (both untested in play). The People seal (in the Self card's header) and
the travel menu's Join rows live in the Hud, built 2026-10-24 (see "UI" below).

Files: `src/server/Party.luau` (parties, card, people list, friend nudges),
`src/server/SafeZone.luau`, `Travel.toPlayer` (join and visit), `EnemyService.died`
(kill credit). Tuning: `Pacing.Party`, `Pacing.SafeZone`. Remotes: `PartyAction`,
`PartyState` (`assets/Remotes.rbxmx`). UI: `src/client/Social.luau`, `StarterGui.Social`
(`assets/Social.rbxmx`, built by `tools/build_social.luau`), namecard taps through
`Nameplates.onTap`.

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

## UI contract
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

**People list** (`PartyAction "people"`): the People seal in the Self card's header,
shown only while the player attribute `InSafeZone` is true, opens it (no tile of its
own: four-tile row, user 2026-10-24). Rows of `{ userId, name, realm, raceName,
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

**Travel menu:** a "Join <name>" row per other member (`PartyAction "join"`, the join
ride) at the top of the list; built, see "In the Hud" below.

**Friend nudge** (`PartyState "friendHere", { userId, name }`): toast "<name> is on this
mountain", once per session per friend, both ways.

## UI (built 2026-10-23)
One ScreenGui, `StarterGui.Social` (DisplayOrder 4, device safe insets), laid out at the
phone baseline 844x390 inside `Canvas` and fitted by `UiScale` (base PHONE, max 1.3; the
lint knows the same fit). Only kit cuts already uploaded: the panel frame, close seal,
gold / jade / lacquer buttons, field inset rows, note panel, the namecard band and the
cinnabar seal. Calm and plain: no ornament beyond the frame.
- **Player card** (`Canvas.Card`, 440x252, centred, a Menus window). Chosen over a
  centred "slip" with a 2x2 grid and no avatar (the critic: the avatar tells a kid whose
  card it is; the rows read in one scan). The Self card's family without its columns: a
  still copy of their character in a plain well (104x158) on the left; on the right the
  name (Merriweather 20), the realm in gold with the marks after it in jade ("· Friend ·
  With you"), a hairline, then RACE (race · variant), BLOODLINE ("None", muted), HALL ("No
  Hall", muted) and PARTY ("Travelling alone", "In your party", "Leads a party of 3") as
  gold capitals over cream values (14 / 16 baseline). The actions run along the bottom,
  44 tall, at most 112 wide, shrinking to share the 392 px row: `invitedYou` Accept (gold)
  + Decline, else `canInvite` Invite (gold); `canJoin` "Travel to" (jade, the join ride);
  `canVisit` Visit peak (jade); `canKick` Make leader + Remove (its text in a muted red).
  The card is re-fetched after every action and on every party push while open. Opened
  from People, its close seal goes back to the list.
- **Opening it:** tapping or clicking a namecard (`Nameplate.Band.Hit`, the billboard is
  `Active`), on touch a tap on the character itself (a mouse click there is a Strike), a
  People row, or a pip.
- **People** (`Canvas.People`, 440x276 with the title plaque "People"): rows of the kit's
  field inset, 44 tall: name, then realm · race in gold; on the right "Friend" (jade),
  "With you" (gold) or "In a party" (muted). Empty: "No one else is on this mountain yet."
  Refreshed on open and as players come and go.
- **Invite prompt** (`Canvas.Invite`, 320x110 on the note panel, top-centre 70 px down,
  under the top-right tiles; not a Menus window, nothing hides for it): "<name> invites you
  to travel together", realm · party size, the seconds left and a thin gold line draining
  to the expiry, Accept (gold) / Decline. One at a time, oldest first; `inviteGone` and the
  countdown take it away.
- **Party pips** (`Canvas.Pips`, left edge, top at 36 % of the screen, between Roblox's chat
  corner and the thumbstick; on a phone x 7-140 against the vitals stack from x 160, so
  nothing overlaps): one 150x28 row per member in join order, the namecard band with the
  name (yours reads "You") and a 3 px health sliver, the cinnabar 首 seal on the leader's
  row; members out of `RADIUS` dim (band, name, sliver at half). Hidden when solo and while
  any window is open. Tap a member for their card, your own row for **Leave party** (a
  130x40 lacquer button that drops under it for 4 s).
- **Friend toast:** `friendHere` -> `Hud.toast("<name> is on this mountain")`.

**In the Hud (built 2026-10-24, `assets/Hud.rbxmx`):**
- **People** is a round seal in the Self card's header (`Hud.SelfCard.Header.PeopleButton`,
  two busts composited from the Self icon, `draw_ui.py people`), not a tile: the tile row
  is four tiles and a new persistent element must name the one it replaces
  ([ui](ui.md)). Visible only while `InSafeZone`; Activated ->
  `Social.openPeople(SelfCard.open)` (its close seal goes back to the card). No P key.
- **Travel menu:** `TravelMenu.List.Party`, a row above the Sect grounds and Wilds
  columns (`List.Columns`): one `JoinTemplate` clone per other member, a third of the
  row each (up to three), the jade button art, "Join <name>" over their realm. Activated
  -> closes the menu and `Social.join(userId)` (`PartyAction "join"`; refusals arrive as
  a toast). Rebuilt on every party push (`Social.onParty`); hidden when solo, and the
  window's height cap grows by the row (262 -> 314) while it shows.

## Testing
The testbed stand-in (`TestbedDummy`) is not a Player, so parties need two clients:
Studio's Test > Clients and Servers with 2 players. `Social.preview()` (client console)
shows a sample card, invite and pips alone.

## Known gaps
- The People seal and the travel menu's Join row are untested in play (two clients).
- The UI is untested in play (two clients); the People list doesn't get the Hud's
  ScrollHint chevron (it's in its own ScreenGui).
- No cross-server parties, party chat or shared quests; co-op rifts and group world
  events (roadmap 3e) aren't built.
- Spar duels from the card are deferred (roadmap 3f).
