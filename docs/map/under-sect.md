# Map: under-sect ground
The forest floor under the sect (r < ~470): terrain, peak roots, the Ascension Array and gate path. Read it before working on the ground below the peaks.

The floor under the sect (r < ~470, Y ~4-25), so a disciple who falls off a peak
lands in a forest instead of the void, and the pillars stand on something when
seen from the wilds. Smooth terrain from `art/ground/terrain_ground.luau`
(re-runnable; it only writes the columns that had no terrain, saved as
`Map.Ground.GroundFillMask`, in the band Y -40..48, and never sets material
colours). Decor near the peaks is re-seated by `art/ground/reseat_decor.luau`;
knoll rocks come from `art/ground/dress_sect_roots.luau` (`Map.Ground.SectRoots`).

```
            N (-Z)          Peak_4 / Peak_5 feet, ridge "spoke" at x 0
   (-268,-213) knoll+rocks        (-43,-344) K        (210,-265) K
   (-345,41) K   Peak_6/7   [ MAIN PEAK ROCK r~226 ]   Peak_2/3   (340,-41) K
                               | Ascension Array (0,5,236): TravelGate "SectFoot"
   (-214,268) knoll+rocks      | paved path x~0, Y 5, through the slot
            Peak_8  (x -13..25 at z 280)  Peak_1       (262,211) K
                       knoll (46,338) +rocks
            ======= sect wall z~377, gatehouse (0,~5,410) =======
                            S (+Z): gate (0, 9, 500)
   K = flat pocket kept clear for karst pillars (~40-45 across)
```

- Arrival: walking in through the gatehouse, or falling from a peak. First
  view from the gate: the path running north into the slot between Peak_8 and
  Peak_1, ending on the Ascension Array at the main peak's foot (hero: the main
  peak's wall rising out of the forest).
- Ground: a relaxed membrane from the surrounding wilds heights, easing down to
  a rolling floor (~Y 8, Grass/LeafyGrass by noise). Every rock base (spirit
  pillars and the main rock, outline raycast at Y 12) gets a Mud/Ground apron
  up to +5 that buries the mesh seam. Only stylized materials (Grass,
  LeafyGrass, Ground, Mud, Pavement have MaterialService overrides; Rock and
  Slate still look default).
- Old terrain spires (Slate/Rock, at r ~415-460, tops Y 300-480) whose bases
  hung at Y ~46-120 are joined down to the floor in their own material. The
  eight old hanging terrain columns at r ~212 in front of the main rock's face
  (Y ~48-400, nobody's) were deleted.
- Safety: `Regions` Sect ring is 0-410 (no ambient beasts under the peaks);
  the Ascension Array is a real array (any destination from it), and the gate
  array at (48, 6, 470) is a walk south. No fall damage exists.
- Peak roots: `Map.Ground.PeakRoots` (`art/ground/build_roots.py` +
  `place_roots.luau`, kit in `ServerStorage.PeakRootsKit`): a sleeve round each
  rock base stepping out per 2D-Voronoi cell, the spirit pillar's vertical
  column look, flaring up to ~10 studs at the floor. One mesh cloned to all
  eight pillars, a separate one for the main rock. No flare toward the slots
  between neighbouring pillars and the main rock, and none in front of the
  Ascension Array (the path and array squeeze between Peak_8, Peak_1 and the
  main rock there). Non-colliding; an invisible hull collider (*Foot) covers
  y 0-40.
