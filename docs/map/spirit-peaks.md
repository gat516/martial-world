# Map: spirit peaks and bridges
The player spirit-peak template (layout, dressing, rebuild scripts in `art/spiritpeak/`) and the rope bridges to the main peak. Read it before touching a `Peak_N` or a bridge. Reserved names and ids are in [map](../systems/map.md) "Hard constraints".

Peak-local frame (`Peak.frame`): origin at Plateau, "in" = +Z toward the main peak
(bridge side), "out" = -Z, +X right looking out. Plateau r 50, build space r 47,
Y -30..+30. Lawn top local -1.5 (world 552).

```
            out (-Z)
   z -52  .  .  rim behind the house (low shrubs; the abode facade is below)
   z -46  .   [TERRACE x+-17, z -25.6..-45.5, top -0.5]  SignatureTree (33,-31)
   z -34  .     DWELLING (0,-34) on it, planters at the front corners
   z -21  +--fence--[gap x+-4.5]--fence--+      well/trough (38,-9..-1)
          |  12 beds, x +-28, z -20..32   |      spawn (39,8) (disabled)
   z   8  TP array (-39,8)                       stele (37,26)
          |    stepping-stone aisle x=0   |
   z  33  +--fence--[gap x+-4.5]--fence--+
   z  39  forecourt, jade lamps (+-6,39)
   z  44  BRIDGE GATE (flank walls x +-6..13); bridge lands z ~50 (x +-11)
            in (+Z, toward the main peak)
   stairs' head (-47,-7) on the left rim -> cliff stairs -> abode porch (0,-25,-60)
```

As built (2026-10-21, approved on Peak_1 and rolled out to all 8 peaks):
- Lawn: the `PeakGrass` mesh (the user chose it over a smooth-terrain lawn, which
  showed a slab edge, grass blades and lumps over the rim), on Material
  LeafyGrass (MaterialService overrides it with the stylized "Grass II" variant,
  the same one terrain lawns use) tinted `6E8F5A`, so it reads as the main peak's
  terrain green. Top local -1.7..-1.2 (it rolls gently); invisible `LawnCollider`
  boxes 0.3 under it close the mesh-collision holes. PeakRock/PeakRockBase are
  Slate `7A7570`/`615D59`. The cliff ledges are bare rock shelves
  (`LEDGE_TURF = False` in `art/build_peak_pillar.py`: no green ledge discs).
  No terrain on the peak tops.
- Focal point: the dwelling on `Pillar.Terrace`, a 1-stud stone terrace (under
  Pillar on purpose: `Config.Build.GROUND` counts Pillar as natural ground), with
  a front step, a side step toward the well and planters at the front corners.
  The view from the gate runs up a stepping-stone aisle (`Dressing.Path`, Slate
  flagstones 0.06 proud, the rest sunk) between the beds and ends on house +
  signature tree.
- Plants (`Dressing.Plants`, library "Stylized Foliage + Pots" bushes, ferns and
  leaf tufts, and one "Stylized Tree (Dark Green)" pine), in clusters with quiet
  lawn between: Signature (the tree, a bush, ferns, a tuft, a standing stone),
  LeftFront (the pine outside the garden's front-left corner framing the gate
  view, a bush, a fern, a tuft, a stone), StairHead (bush, tallest standing
  stone, fern, column stub), Landing (left: fern, tuft, stone, stub; right: one
  fern), Stele (two tufts), Back (bushes, a fern on the rim behind the house),
  Trough (one fern). Starter foliage (Bush, StandingStone, PineTree, SpiritTree
  pieces; their `Foliage/...@x,z` ids differ per peak and are kept) is moved into
  these slots by ItemId. Nothing on vertical faces, nothing over the lawn's
  bevelled lip (the flat top ends about r 44-48).
- Rocks: only `Dressing.Stones`, two little groups of hexagonal Slate column
  stubs sunk a stud into the lawn (stair head, bridge landing), plus the starter
  standing stones. No library boulders.
- Garden fence: 16 `Fence` segments (`Garden/Fence_1..16`,
  `art/spiritpeak/garden_fence.luau`, each run seated on the lowest of its three
  post spots); the catalogue Fence (`art/spiritpeak/fence_model.luau`) is a
  knee-high two-rail Wood run, one post per joint (the +Z end post and its cap
  tuck inside the neighbour's), pivot height and +-6.7 snap edges unchanged.
- BridgeGate sits on the lawn (its flank walls and pillar bases used to float
  ~0.8); no lanterns on the flank walls (they were wider than the walls). The
  flank walls are Slate `7E776B` (were Pavement, whose "Stylized Pavement II"
  override has a metalness map and renders the sides near black).
- Lights: 8 per peak (gate lanterns are the Bridge's; jade lamps; dwelling and
  porch stone lanterns; abode spirit stone; well), no shadows.
- `Peak_N.Dressing` holds all non-piece dressing (no StarterId/ItemId, never
  colliding, CanQuery off): Plants, Stones, Path (`dress_spirit_peaks.luau`),
  Planters, Abode (porch lanterns) and FX (invisible FX_* placeholders sized like
  the `ServerStorage.AmbientFX` templates, for the vfx agent).
- Scripts, in rebuild order (all in `art/spiritpeak/` unless noted; Edit mode via
  the MCP): pillar import + `art/place_peak_pillar.luau` (`peaks = {...}` limits
  the swap; extra Pillar children such as Terrace move across);
  `rollout_peaks.luau` (copies Peak_1's Terrace, starter poses except beds and
  Foliage, and Planters/Abode/FX into other peaks by Peak.frame);
  `fence_model.luau` + `garden_fence.luau`; `dress_spirit_peaks.luau`;
  `fix_overhangs.luau` (pulls back anything hanging over a terrace or wall
  edge); `strict_seat.luau` (rays over every unit's whole footprint, lowers
  anything floating; run dry to check); `recolor_peaks.luau` (palette pass on the
  peaks' plain parts: flagstones and terrace stone in warm mid grays, since sunlit
  Slate tops read far paler than their tint; dwelling walls Plaster cream, roofs
  dark Slate, abode hall walls Slate; also the catalogue Dwelling). Then raycast
  the lawn for holes.

Not done yet: the doc's raised garden curb and lantern-lit path turns. The
starter PineTree (BuildCatalog `PineTree`, a sparse realistic tree) and the
brown starter standing stones are catalogue models, left as they are.

## Bridges between peaks
Rope bridges from the terrace bridgeheads (r 172.5) down to each peak's gate
(a ~28-stud drop over ~75 studs). Keep: dark wood planks with slight per-plank
shade change, rope sag, posts at both ends with gold caps and a lantern on the
peak end. Landings at both ends per [map](../systems/map.md) "Composition rules". `SwayBridge` tags are free
(no code reads them).

As seated (`art/spiritpeak/seat_bridges.luau`, re-runnable, run it after any
rebuild of the main peak's terrace or the spirit pillars; nothing else moves the
bridges, `strict_seat.luau` skips them):
- Terrace end: the `Bridgehead` (14x0.6x8 paving, top Y 582.05, Slate: the
  Pavement override's sides render near black) on a `Plinth` of rock-tone stone
  inset 0.25 under it, down into the sunk rim rock (580.5). They were a thin slab
  hanging a stud over the rock.
- Peak end: a stone `Landing` (11 wide, from just past the last plank to just
  inside the end posts, top on the posts' feet ~0.2 over the lawn, up to 6.5 deep
  into the lawn's bevel). The last plank and the posts hung over the bevel.
- Deck: the first plank's inner edge meets the Bridgehead top, the last plank's
  outer edge meets the Landing (a linear vertical shear; hangers keep their tops
  on the chains). Walk-checked along three lines per bridge: the only dips are
  the plan gaps between the pitched planks (0.4) and between the Bridgehead and
  the first plank (0.7), too narrow to step into.
