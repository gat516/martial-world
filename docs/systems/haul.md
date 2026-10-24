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
- **Banking** happens on the sect's safe ground (your peak, the plaza, anywhere
  `Gates.inSect`), or standing on any teleport array, while not combat-tagged. A
  feed toast ("Haul banked: 120 raw qi, 3 herbs, 40 Spirit Stones.") shows when you
  come back from outside with something new. Logging out normally (not in combat)
  keeps the haul: you rejoin at home.
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
- **Banking check:** `Haul.safeAt(player, position)`: `Gates.inSect` or
  `Travel.standingOn`. **Testbed** (`Config.TESTBED`): the whole arena reads as the
  sect, so only within `TESTBED_BANK_RADIUS` of `Workspace.Arena.SpawnPad` (where the
  TestPeak sits) banks; fight the zone beasts away from the pad to test spills.
- **Death:** `Haul.died` from `Humanoid.Died` (Main, before `Combat.died`) takes the
  share out of the profile into the spill and fires `Effect "spill"` to that player.
  After the respawn the spill is sent again with a toast naming the minutes left.
- **Leaving:** `Haul.leaving` from `PlayerRemoving`, before `PlayerData.release`
  saves the profile.
- **Ring:** `data.ring` (ids, saved; added by `fillMissing`, no schema step),
  `InventoryAction ("ring", id, true|false)` -> `Haul.setRing`; `PlayerState` carries
  `ring` and `ringSlots`.

## Client
- `HaulSpill.luau`: draws the spill for its owner from `Effect "spill" (at, expires)`
  and `"spillGone" (reclaimed)`. It clones the onboarding guide's `Effects.Guide.Marker`
  (formation circle, light column, rising motes) at runtime, tinted spirit violet, and
  plays `Guide.Arrive` (tinted) on reclaim; the column thins in the last 30 s. No
  template of its own; falls back to a glowing orb if `Effects.Guide` is missing.
- Inventory: an item in the ring says so in its detail ("In your spirit ring (1/2):
  safe even in the wilds."). **There is no Ring button yet**: the detail pane has two
  action buttons (Use/Eat, Hold), and a third needs a GUI change.

## Tuning (`Pacing.Haul`)
`SPILL_SHARE` 0.5, `SPILL_SECONDS` 300, `RECLAIM_RADIUS` 7, `SAFE_RARITY` 4 (Epic),
`RING_SLOTS` by major, `TESTBED_BANK_RADIUS` 24, `CHECK_SECONDS` 0.5.

## Known gaps
- **No Ring button in the Inventory.** A ui-designer pass adds one (a third action
  button, or the Hold button's row) that calls `InventoryAction "ring"`, plus the ring
  slots view the roadmap lists; until then only the server action exists.
- The death screen doesn't say what spilled; a toast after the respawn does.
- The spill is a reuse of the guide marker; a dedicated spilled-haul spirit-light
  (vfx pass) is still on the Phase A shelf list.
- The qi surge (burns raw qi to keep the rest) isn't built.
