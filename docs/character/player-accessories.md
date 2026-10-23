# Player accessories: how they're made

Race cosmetics and anything else worn on the player's R6 body (ears, tails, horns,
crests, plates, talismans, wisps). Read this before briefing or building one. What
each race wears and how it's wired is in [identity](../systems/identity.md#cosmetics);
the per-race prompts are in `art/player/cosmetics/briefs/` with the concept sheet
`docs/reference/race_cosmetics.png`.

## Pipeline

1. **Blender, by a fresh `modeler` per set or race** (user, 2026-10-23: part-built looks
   "sucked"). Never Studio parts, never `enemy-modeler`. One race at a time in the
   one live Blender, scene `Cosmetics`, beside the untouched `R6Reference`
   collection (from `art/rig/r6_rigged.fbx`); each set in its own collection, other
   sets hidden, not deleted.
   **Parallel modelers don't share the live Blender**: it's one process with one
   active scene, so `look` and context collide.
   - Each parallel modeler opens its own visible window,
     `tools/blender_live.sh open <race>`, and runs its build script there with
     `tools/blender_live.sh run <race> <script.py>`.
   - The build script imports `art/rig/r6_rigged.fbx`, saves the race's `.blend`,
     renders the sheet tiles and exports.
   - Each modeler works in its own worktree.
   - At most 4 Blenders at once (counting the live one), all visible so the user
     can watch.
   - Headless `tools/blender_run.sh` is only for jobs nobody needs to watch.
2. **Directions first.** 2-3 directions on one sheet, then stop for the user's pick.
   The user often keeps all of them as variants.
3. **Polish, export, commit.** One FBX + JSON per set under
   `art/player/cosmetics/<race>/`, a re-runnable `build_<race>.py`, `make_sheet.py`,
   the `.blend` and a README.
4. **Import** in a sandbox, by a fresh agent with the sandbox's `studio_id`:
   - upload each FBX as a model (`tools/upload_asset.py model`) and the shade ramp
     with the MCP's `upload_image` (it only takes http URLs; when that's blocked,
     reuse the shared ramp: build it with the fox's settings so it matches
     `fox_shade.png` byte for byte and use `rbxassetid://124559907609415`), then
     `insert_asset` each model as
     `Workspace._Import<Set>`. There's no manual FBX import step.
   - a `place_<race>_cosmetics.luau` script turns the imports into Accessories: the
     importer's RootPart becomes an invisible 0.2 Handle at the attachment, holding
     the bones; the skinned MeshParts are welded to it, each with a `Region`
     attribute.
   - export the set's Folder to `assets/Cosmetics/<Set>.rbxm` (mapped to
     `ReplicatedStorage.Cosmetics`, one file per set, so the creator preview can
     wear them), and name the accessories in the race's or variant's `Cosmetics`.
   - check that the bones deform when worn, and that the accessory still fits after
     `ScaleTo(1.15)`.
5. **Merge to the test build** for the user to see in game.

The fox (`art/player/cosmetics/fox/`) is the worked example of every step. The tiger
(`art/player/cosmetics/tiger/`) adds patterned fur, ear markings, whiskers (a third accessory
on FaceFrontAttachment), size ratios and a limb-clearance check.

**Space.** Each FBX is in its attachment's space. A Blender point `(x, y, z)` is
Roblox `(-x, z, y)` from the attachment, with no extra rotation. The fox README's
first note (a pi turn) put the tail in front of the body.

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
  `FurTip`). Shading comes from a greyscale ramp texture in a SurfaceAppearance
  tinted by its Color. The SurfaceAppearance covers the part colour, so a race or
  bloodline recolour sets both the MeshPart's Color and `SurfaceAppearance.Color`.
- **Read as the material.** Fur is layered clumps graded big at the base to small
  at the tip, with a tapering end: not a smooth tube, not pinecone rows of equal
  scales (both rejected on the fox).
- **Size against the part it attaches to.** Measure the R6 head, torso or limb
  mesh's bounding box, and give each piece's height and width as a ratio of it.
  Print the ratios and put them on the sheet. The user's words: "make sure we're
  checking in relation to the size of the head or the body part the accessory is
  attaching to".
- **Cute is the approved fox direction.** "YES, the cute set for foxes is
  perfect. that is the exact direction i want to go in": soft, rounded, chunky.
  The pass after it ran tall and thin, with tooth-like inner tufts: "now we're
  going too long", "not cute it just looks creepy". Once a look is approved, lock
  it and only polish.
- **Ears: short and solid.** The fox's first ears were "too tall. make them
  cute" and "too thin.. why are they so thin?" (user, 2026-10-23).
  - Size: the approved cute fox ears are about 64% of the head's height with a
    base about 40% of its width (R6 head mesh 1.20 wide, 1.02 tall). Use that as
    the bar unless the brief says otherwise.
  - Body: a solid, rounded cup with depth front to back, wide at the base. Not a
    flat card.
  - Inner fur: a few soft, chunky, rounded tufts that fill the cup, not thin needle
    spikes ("and the 'fur' thats in the inside").
  - Read: judge it from game-camera distance, not only up close.
- **Markings must not read as faces.** A small white spot inside a dark oval on each ear back
  read as a pair of eyes from behind (tiger, user 2026-10-23). Put the dark across the
  ear's tip, rim to rim, and keep the light mark small, soft and wide, at the dark's edge.
- **Patterns follow the fur.** Hard-edged rings over a tube read as a caterpillar ("furrier,
  less segmented"). Colour whole clumps instead. Tail clump rows are staggered, so a single
  coloured row checkers with its neighbours; a stripe needs two rows (tiger, `PATTERN`).
- **Whiskers stay simple.** "they dont have to wrap around the face" (user, 2026-10-23): a
  root point sunk into each cheek, then a few thick, closed, tapered strands sticking straight
  out sideways, fanned, with at most a gentle curl. Never fitted along the face's curve.
- **Size against the part it attaches to.** Measure the R6 part's bounding box and give each
  piece's height and width as a ratio of it, printed and on the sheet. The approved cute fox
  ears stand 64% of head height on a base 40% of head width (head 1.20 x 1.02); tall, thin
  ears read "creepy". Tails also get a limb-clearance check with the legs and arms swung
  (tiger `limb_clearance`).
- **Variants really vary.** "when i mean variant make it really vary. instead of
  pointy, give it a round peak" (user, 2026-10-23). Each variant has its own
  silhouette, recognisable at game distance: a round soft peak against a sharp
  notched point against a folded tip. Tweaks of tilt or tufts don't count. Cover
  both moods, "cool / tuff / aggressive and cute".
- **Clear the body.** Ears clear a normal hair accessory and work bald; tails clear
  the legs and arms at rest and while running.
- **Budget:** ears about 1,500 tris a pair, horns 2,000-3,500 a pair, a tail about
  4,000 (6,000 at most).
- **Sheet:** front, side, back, rear three-quarter, bent pose, a seating close-up
  and a bent close-up, one row per direction.
- **Keep what the user likes.** When the user approves a placeholder's design,
  remodel that same look in Blender and don't redesign it. Dragonblood's
  part-built antlers are one: "i actually really like what we have going on for
  dragonblood already" (`briefs/dragonblood.md`). The Blender remodel
  (`dragonblood/`, Antler) keeps it, with the beams splayed in a wide V and
  longer tines, as the user asked at the pick.
- **Scales and tufts** (user, 2026-10-23, on the first Dragonblood tails: "less like a
  pickle with a cotton ball"): scales are flat, tight, overlapping plates, not bumps,
  and a tip tuft grows out of the tail (fur starting among the last scales, short at
  the root and long at the end, one flame-shaped plume), never a ball stuck on the end.
- **One checkout unless parallel.** Races run one at a time in the shared
  `race-cosmetics` checkout. A worktree is only for an agent running alongside
  another one (AGENTS.md, Branches).
- **Effects aren't meshes.** Flames, qi wisps and mist (Demonic Human's flame,
  Ghost's wisps) go to `vfx`; the modeler builds only the solid pieces.
  Ghost's trailing silk is the exception that proves it: solid, closed ribbons that fade
  through an alpha ramp (`ghost_fade.png`, SurfaceAppearance `AlphaMode = Transparency`), with
  any mist on top left to `vfx` (`art/player/cosmetics/ghost/`).

## Next: bringing them to life

The accessories are rigged, but nothing moves the bones yet. Planned once the remade fox tails are in (user approved, 2026-10-23):
- one client script that drives every worn accessory's bones by name
- tails (`Tail1..`) sway with lag down the chain, faster while running, settling when the player stops
- ears (`EarL`/`EarR`) twitch now and then

Every race gets it for free, as long as it uses the standard bone names.
