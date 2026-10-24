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
  by itself. Only two things bank silently: riding a teleport array (it banks as you
  leave a bank point) and logging out at a bank point. Logging out in the wilds out of
  combat keeps the haul unbanked across the session (`data.haul`), so the next join, at
  home, offers Store all for it.
- **Onboarding hook:** `Haul.onBanked` (server hook list) is called with
  `(player, amounts, how)`, `how` "store" (the prompt) or "travel" (a silent bank), so
  a beat can teach Store all right after the first hunt
  (`table.insert(Haul.onBanked, ...)` in Main or Quests). The player attribute
  `HaulReady` says the prompt is up right now (for a guide spotlight).
- **Death spills half the unbanked haul** (`SPILL_SHARE`, rounded to the nearest
  whole; raw qi rounds down) at the last place you stood (a fall spills on the
  ledge, not in the void). It waits `SPILL_SECONDS` (5 min) as a spirit-light only
  you can see; walking within `RECLAIM_RADIUS` gives it back, as haul again (still
  to be carried home). A second death before you reclaim it loses the first spill.
  A death never costs cultivation or a stage.
- **Leaving while combat-tagged** (the `InCombat` attribute, [combat](combat.md))
  counts as a death: the same share is lost, with no spill.
- **The spirit ring** keeps whole stacks safe even in the wilds: put herbs or items
  in it and every one of that id is banked. `RING_SLOTS` by major realm (2 at Qi
  Condensation, 3 Qi Refining, 4 Foundation); the Pavilion may sell more later.
  Taking a stack out keeps what's in it banked. Rare finds can't go in (they're
  safe already). Stacks you run out of leave the ring.

## How it works (server `Haul.luau`)
- **Snapshot, not a ledger.** Each player has an in-memory snapshot of what they
  held when they last banked; the haul is whatever they hold above it. Every check
  (`CHECK_SECONDS`) lowers the snapshot to what's held (using or spending eats the
  banked part first), and sets rare finds and ringed stacks to what's held. So every
  way of gaining something (drops, qi nodes, treasures, quests, the market) counts
  without reporting in.
- **Bank points:** `Haul.safeAt(player, position)`: `Gates.inSect` or
  `Travel.standingOn`. Each check sets `HaulReady` when the player is at one, out of
  combat, with a non-empty haul. `InventoryAction "storeAll"` -> `Haul.storeAll`
  re-checks all three, banks, fires `Effect "banked"` (the flare) and an
  `Effect "reward"` small float with the summary, then `onBanked`. `Travel.onTravel`
  (a hook list in Travel, called before the ride moves the character) ->
  `Haul.bankQuietly`. **Testbed** (`Config.TESTBED`): the whole arena reads as the
  sect, so only within `TESTBED_BANK_RADIUS` of `Workspace.Arena.SpawnPad` (where the
  TestPeak sits) banks; fight the zone beasts away from the pad to test spills.
- **Death:** `Haul.died` from `Humanoid.Died` (Main, before `Combat.died`) takes the
  share out of the profile into the spill and fires `Effect "spill"` to that player.
  After the respawn the spill is sent again with a toast naming the minutes left.
- **Leaving:** `Haul.leaving` from `PlayerRemoving`, before `PlayerData.release`
  saves the profile: combat-tagged loses the share; then at a bank point it banks,
  elsewhere the remaining haul is written to `data.haul` and the next session's
  snapshot starts that much lower.
- **Ring:** `data.ring` (ids, saved; added by `fillMissing`, no schema step),
  `InventoryAction ("ring", id, true|false)` -> `Haul.setRing`; `PlayerState` carries
  `ring` and `ringSlots`.

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
`SPILL_SHARE` 0.5, `SPILL_SECONDS` 300, `RECLAIM_RADIUS` 7, `SAFE_RARITY` 4 (Epic),
`RING_SLOTS` by major, `TESTBED_BANK_RADIUS` 24, `CHECK_SECONDS` 0.5.

## Known gaps
- Store all is untested in play: a client-side prompt on your own root is new here
  (WorldPrompts should treat it like any prompt; it is always the nearest, so while it
  is up it takes focus from plants on your peak until you store). If it misbehaves, a
  ui-designer pass can give it a fixed HUD button instead.
- Riding an array from the wilds banks silently, as decided, so walking home is where
  the Store all beat mostly shows.
- The Inventory's Ring button and ring marks are untested in play.
- The death screen doesn't say what spilled; a toast after the respawn does.
- The spill is a reuse of the guide marker; a dedicated spilled-haul spirit-light
  (vfx pass) is still on the Phase A shelf list.
- The qi surge (burns raw qi to keep the rest) isn't built.
