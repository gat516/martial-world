# Player accessories: how they're made

Race cosmetics and anything else worn on the player's R6 body (ears, tails, horns,
crests, plates, talismans, wisps). Read this before briefing or building one. What
each race wears and how it's wired is in [identity](../systems/identity.md#cosmetics);
the per-race prompts are in `art/player/cosmetics/briefs/` with the concept sheet
`docs/reference/race_cosmetics.png`.

## Pipeline

1. **Blender, by a fresh `modeler` per set** (user, 2026-10-23: part-built looks
   "sucked"). Never Studio parts, never `enemy-modeler`. One race at a time in the
   one live Blender, scene `Cosmetics`, beside the untouched `R6Reference`
   collection (from `art/rig/r6_rigged.fbx`); each set in its own collection, other
   sets hidden, not deleted.
2. **Directions first.** 2-3 directions on one sheet, then stop for the user's pick.
   The user often keeps all of them as variants.
3. **Polish, export, commit.** One FBX + JSON per set under
   `art/player/cosmetics/<race>/`, a re-runnable `build_<race>.py`, `make_sheet.py`,
   the `.blend` and a README.
4. **Import** in a sandbox: upload, build one Accessory per set in
   `assets/Cosmetics.rbxm`, wire the race or variant `Cosmetics`, merge to the test
   build. The fox (`art/player/cosmetics/fox/`) is the worked example of every step.

## Rules

- **Seat it in the body, no gaps.** Every piece that sits on the head or torso is
  sunk into it across its whole footprint, including over the head's rounded
  edges. No open bottoms, no flat base hovering on a curve, no floating tufts:
  from any angle, including low and close, you see body or accessory, never
  background, between them. The fox's first ears showed a gap under the base
  against the head's curve (user, 2026-10-23: "we need to be careful of this").
  Check with a close-up from just above head height at the side and back.
- **No see-through gaps inside a piece.** Fur clumps, feathers and scales are
  closed wedges rooted in a full core of the same colour; nothing single-sided
  (Roblox culls back faces). Check in rest and bent poses.
- **Riggable** (user: "keep stuff riggable"). Real armature, bones named like the
  Motor6Ds they become: `Root` -> `EarLBase` -> `EarL` (and R); `Root` ->
  `TailBase` -> `Tail1..Tail5`. Pivots at true hinges, smooth skin weights across
  each joint, transforms applied. The sheet shows a bent pose.
- **Recolourable by region.** Each colour region is its own mesh (outer, inner,
  tip, veins...), with a material named by region (`FurOuter`, `FurInner`,
  `FurTip`). Shading comes from a greyscale ramp texture tinted by Color, so a
  race or bloodline recolour is one Color per part.
- **Read as the material.** Fur is layered clumps graded big at the base to small
  at the tip, with a tapering end: not a smooth tube, not pinecone rows of equal
  scales (both rejected on the fox).
- **Cute, not tall.** Ears stay compact and appealing on the blocky R6 head; the
  fox's 1.2-stud ears were "too tall. make them cute" (user, 2026-10-23). Keep
  ears to about 0.6-0.9 studs unless the brief says otherwise.
- **Clear the body.** Ears clear a normal hair accessory and work bald; tails clear
  the legs and arms at rest and while running.
- **Budget:** ears about 1,500 tris a pair, a tail about 4,000 (6,000 at most).
- **Sheet:** front, side, back, rear three-quarter, bent pose, a seating close-up
  and a bent close-up, one row per direction.
- **Effects aren't meshes.** Flames, qi wisps and mist (Demonic Human's flame,
  Ghost's wisps) go to `vfx`; the modeler builds only the solid pieces.
