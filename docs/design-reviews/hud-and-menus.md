# Review: HUD and menus on a phone

**Verdict: rework the tile row.** The vitals stack, the one-window rule, combat folding and the phone footprint pass (33.7% to 19.7% at 844x390) are good work. But the out-of-combat HUD runs about 12 persistent elements against a ~5 guideline, and more are queued. Reviewed 2026-10-23 from `docs/systems/ui.md`, `docs/ui/*`; nothing seen on a real phone.

## The count (phone, out of combat, at your peak)
1-7. Top-right tiles: Herbarium, Build, Cultivate, Self, Travel, Inventory, Settings (about 343 px of 844). 8. The objective line. 9. Buff chips. 10. The vitals stack with the realm crest. 11. The hotbar. 12. The touch cluster (Strike, Jump, Dash, Guard, Lock). Queued: the People tile, party pips, the surge button and the sect log. Roblox's own top-left buttons and chat sit beside all of it.

## Why it matters
- Kids handle 3-4 things asking for attention. The research's top phone rule is "no new permanent button unless it replaces one".
- Top-right tiles are status territory (hard to reach), yet seven of them are buttons, at 44 px, the floor.

## What's right
- `Menus`: one window, the HUD hides while it's open. TileFold in combat (Inventory and Settings only). Contextual tiles (Build near your peak, Travel in the sect). Hotbar empty slots hidden on touch. These are the right patterns. Extend them rather than adding tiles.

## Problems
- **Two doors to one room:** the realm crest already opens the Self card (`Hud.luau`, "The crest is a shortcut to the character window"), and the Self tile opens it too.
- **The Herbarium is a once-a-day book with a permanent tile.** It belongs at home (a lectern on the peak, or a tab in the Pouch or garden windows), not in the global row.
- **Settings is a permanent tile** on a phone. It's rarely used and could sit inside Self or a "more" fold.
- **Cultivate vs seated tiles:** sitting shows about 8 seated tiles (Break Through, Rise, Practice, Weapon Dao, Circulate, Technique, Method, Back). That's a second dense menu. Check that each one is needed at QC1-4; hide Method and Technique until they first matter.
- The inventory has 3 tabs plus a chip rail, sort and search on a 390 px tall screen. The phone grid shows about one section row (inventory.md). Search is a PC habit; the phone needs chips only.
- Window text: Herbarium cards are about 81x125 with a 9 px name floor, below the 14-16 px body guideline. The readability-through-contrast rule can't fix 9 px.

## Metrics
- First 60-180 s: onboarding's spotlight veil hides the clutter while it teaches. Good. Free play then reveals everything at once.
- Low-end phones: the Herbarium renders up to 470 parts in ViewportFrames per spread. That's untested on a 2-3 GB device.

## Recommendations (ranked)
1. **Cut the row to four tiles:** Inventory, Cultivate, a contextual tile (Build at your peak, Travel in the sect: one slot, whichever applies), and Self (absorbing Settings as its last tab). Drop the Self tile if the crest is kept as the door; drop the Herbarium tile in favour of a peak lectern plus a Pouch link. Saves about 150 px and three decisions.
2. **A hard rule in ui.md:** a new persistent element must name the one it replaces. Apply it now to the People tile (open the card from nameplates instead) and the party pips (mark members on nameplates).
3. **Gate the seated tiles by stage:** show only Circulate, Break Through and Rise at QC1-3; the others appear the moment they're taught.
4. Raise the Herbarium card name floor to 12 px (two columns of cards on the phone instead of three).
5. Profile the Herbarium spread and the full HUD on a 2-3 GB Android before the next release.
