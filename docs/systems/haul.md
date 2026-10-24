# The haul and the spirit ring: the cost of death

## Purpose
Surviving a fight should matter. What you carry home is at stake: everything
gained since you last banked can spill when you die. Decided in the
[roadmap](../roadmap.md) "Phase A" (user, 2026-10-23).

## Design intent
- **At risk: this trip's haul.** Raw qi in the dantian (`data.rawQi`), herbs,
  seeds, spirit cores and other items below the rarity line, and Spirit Stones,
  gained since the last bank. "Materials" have no store yet; when they do, they join
  the haul.
- **Never at risk:** refined cultivation, stages, weapons (the equipped one and the
  rest), techniques and manuals, and **rare finds** (Epic and Legendary items, herbs
  and their seeds: `Pacing.Haul.SAFE_RARITY`), which bank the moment they're held.
  Bloodline essences will bank on pickup the same way when they exist.
- **Banking is a beat: Store all** (user, 2026-10-23: "think sell all but you store
  all"). At a bank point (your peak or anywhere on the sect's safe ground, or standing
  on any teleport array), out of combat and with something unbanked, a "Store all"
  prompt appears; one tap banks the whole haul with one summary line ("Stored: 120 raw
  qi, 3 herbs, 40 Spirit Stones") and a gold flare at your feet. Arriving doesn't bank
  by itself. Riding a teleport array banks too (it banks as you leave a bank point) and
  shows the same summary and flare when you arrive, so the beat plays every trip home.
  Only logging out at a bank point banks silently. Logging out in the wilds out of
  combat keeps the haul unbanked across the session (`data.haul`), so the next join, at
  home, offers Store all for it.
- **Onboarding hook:** `Haul.onBanked` (server hook list) is called with
  `(player, amounts, how)`, `how` "store" (the prompt) or "travel" (an array ride), so
  a beat can teach Store all right after the first hunt
  (`table.insert(Haul.onBanked, ...)` in Main or Quests). The player attribute
  `HaulReady` says the prompt is up right now (for a guide spotlight).
- **Death spills half the unbanked haul** (`SPILL_SHARE`, rounded to the nearest
  whole; raw qi rounds down) at the last place you stood (a fall spills on the
  ledge, not in the void). It waits `SPILL_SECONDS` (5 min) as a spirit-light only
  you can see; walking within `RECLAIM_RADIUS` gives it back, as haul again (still
  to be carried home). A second death before you reclaim it merges into the first:
  one spill with both contents, at the newest spot, its timer restarted.
  A death never costs cultivation or a stage.
- **Leaving while combat-tagged** (the `InCombat` attribute, [combat](combat.md);
  on phones mostly a drop or an app switch) spills the same share where you stood,
  like a death, and keeps it for your next join: rejoin within `KEEP_SECONDS` (2 h)
  and "Your haul waits where you fell" with the amounts, as a normal spill for
  `SPILL_SECONDS` from that join, only yours. Any spill still unclaimed at logout is
  kept the same way. The deterrent stays mild: a combat-logger still has to walk
  back into the wilds for half their haul.
- **Spending eats this trip's haul first.** The banked part only drops once what you
  hold falls below it. So refining raw qi at a wilds node keeps it safe (refined
  cultivation is never at risk) and nodes are waystations: refine now or push on.
- **The spirit ring** keeps whole stacks safe even in the wilds: put herbs or items
  in it and every one of that id is banked. `RING_SLOTS` by major realm (2 at Qi
  Condensation, 3 Qi Refining, 4 Foundation), plus one bought at the sect's Pavilion per
  major ([sect](sect.md); `data.sect.ring`).
  Taking a stack out keeps what's in it banked. Rare finds can't go in (they're
  safe already). Stacks you run out of leave the ring.

## How it works (server `Haul.luau`)
- **Snapshot, not a ledger.** Each player has an in-memory snapshot of what they
  held when they last banked; the haul is whatever they hold above it. Every check
  (`CHECK_SECONDS`) lowers the snapshot to what's held only where it's above it
  (`banked = min(banked, held)`: using or spending eats the unbanked haul first), and
  sets rare finds and ringed stacks to what's held. So every
  way of gaining something (drops, qi nodes, treasures, quests, the market) counts
  without reporting in.
- **Bank points:** `Haul.safeAt(player, position)`: a safe zone
  (`SafeZone.at`: the sect's grounds or any spirit peak) or `Travel.standingOn`. Each check sets `HaulReady` when the player is at one, out of
  combat, with a non-empty haul. `InventoryAction "storeAll"` -> `Haul.storeAll`
  re-checks all three, banks, fires `Effect "banked"` (the flare) and an
  `Effect "reward"` small float with the summary, then `onBanked`. `Travel.onTravel`
  (a hook list in Travel, called before the ride moves the character) ->
  `Haul.bankQuietly`, which banks there and fires the same `"banked"` and summary float
  once the character has moved (or after 6 s). **Testbed** (`Config.TESTBED`): the whole arena reads as the
  sect, so only the testbed's safe zone (`Pacing.SafeZone.TESTBED_RADIUS` of
  `Workspace.Arena.SpawnPad`, where the TestPeak sits; [safe zones](party.md#safe-zones)) banks; fight the zone beasts away from the pad to test spills.
- **Death:** `Haul.died` from `Humanoid.Died` (Main, before `Combat.died`) takes the
  share out of the profile into the spill (`addSpill`, merging into a live one) and
  fires `Effect "spill"` to that player. After the respawn the spill is sent again
  with a toast naming the minutes left.
- **Leaving:** `Haul.leaving` from `PlayerRemoving`, before `PlayerData.release`
  saves the profile: combat-tagged spills the share at the last ground (`addSpill`);
  a live spill is written to `data.spill` (`at` as `{ x, y, z }`, `contents`, `saved`
  os.time); then at a bank point it banks, elsewhere the remaining haul is written to
  `data.haul` and the next session's snapshot starts that much lower. The next
  session's first check turns a `data.spill` younger than `KEEP_SECONDS` back into a
  live spill (sent with a toast a second later) and clears it either way.
- **Ring:** `data.ring` (ids, saved; added by `fillMissing`, no schema step),
  `InventoryAction ("ring", id, true|false)` -> `Haul.setRing`; `PlayerState` carries
  `ring` and `ringSlots`.
- **Heart demon:** spills, reclaims, mid-fight logouts that spilled something, Store all
  uses and ring additions count in `data.stats` (`spills`, `reclaimed`, `fled`,
  `stored`, `ringed`) for the trial's greed or caution question ([heart-demon](heart-demon.md)).

## Client
- `HaulView.luau`, Store all: while `HaulReady` is set, a local ProximityPrompt on
  the player's own HumanoidRootPart, cloned from `ReplicatedStorage.GardenKit.WildPrompt`
  (a Custom-style prompt template) with "Store all" / "Your haul" and no hold, so
  `WorldPrompts` draws it as a normal card (dock on touch; glyph `chest`, Glyphs word
  "store"). Its Triggered invokes `InventoryAction "storeAll"`. No new template.
- `HaulView.luau`, the spill: draws it for its owner from `Effect "spill" (at, expires)`
  and `"spillGone" (reclaimed)`. It clones the onboarding guide's `Effects.Guide.Marker`
  (formation circle, light column, rising motes) at runtime, tinted spirit violet, and
  plays `Guide.Arrive` (tinted) on reclaim; the column thins in the last 30 s. No
  template of its own; falls back to a glowing orb if `Effects.Guide` is missing.
- Inventory ([inventory](../ui/inventory.md#spirit-ring-haul)): a jade **Ring**
  button on an item's detail ("Ring n/m" puts the stack in, "Take out" on a ringed
  one; hidden on rare finds), a jade 戒 seal on ringed Pouch cells, and "Spirit ring:
  n/m stacks kept safe." on the Pouch tab with nothing chosen.

## Tuning (`Pacing.Haul`)
`SPILL_SHARE` 0.5, `SPILL_SECONDS` 300, `KEEP_SECONDS` 7200, `RECLAIM_RADIUS` 7, `SAFE_RARITY` 4 (Epic),
`RING_SLOTS` by major, `CHECK_SECONDS` 0.5 (the testbed's bank radius is `Pacing.SafeZone`).

## Known gaps
- Store all is untested in play: a client-side prompt on your own root is new here
  (WorldPrompts should treat it like any prompt; it is always the nearest, so while it
  is up it takes focus from plants on your peak until you store). If it misbehaves, a
  ui-designer pass can give it a fixed HUD button instead.
- A saved spill sits at the logout spot in whatever server you rejoin; a spot inside
  an event area that's gone by then may be awkward to reach. Untested in play.
- The Inventory's Ring button and ring marks are untested in play.
- The death screen doesn't say what spilled; a toast after the respawn does.
- The spill is a reuse of the guide marker; a dedicated spilled-haul spirit-light
  (vfx pass) is still on the Phase A shelf list.
- The qi surge (burns raw qi to keep the rest) isn't built.
