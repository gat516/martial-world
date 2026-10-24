# Map: the new build (the sect redo)

The main peak and the 8 spirit peaks are being rebuilt from scratch (user,
2026-10-24): the first map was mass generated and looks sloppy, "acceptable but not
great". **This file is the brief for that work.** Don't read the old area docs
([main-peak](main-peak.md), [spirit-peaks](spirit-peaks.md)) unless the user says to;
the old build is not the reference. The hard constraints in
[map](../systems/map.md) "Hard constraints" still hold: scripts read those names and
coordinates, and any rebuild that moves one updates the constraint and its Config in
the same commit.

## How we build: slow, one area at a time
1. **Reference first.** The user generates reference images with GPT (prompts from the
   main session) and approves one per area. Approved images go in
   `docs/reference/sect/` and the area's row below links it. No reference, no build.
2. **Break it down** into a written plan in the area's section: arrival point, the one
   hero landmark, the main path and where it ends, two or three secondary spots, the
   edges, and the numbers (sizes, heights, distances) read off the reference.
3. **Block out** in gray parts, capture from where players stand and from the
   approach, and check it against the reference with the user.
4. **Build** for real, then run [build-checks](build-checks.md).
5. **Done** only when the user approves it in Studio. Then the next area.
Never batch areas or build ahead of an approved block-out.

## Areas
| Area | Reference | Status |
|---|---|---|
| The whole sect (composition) | [sheet v1](../reference/sect/sect_sheet_v1.png) 1 (top left) | next: macro block-out |
| Mountain Gate and Testing Stone | [sheet v1](../reference/sect/sect_sheet_v1.png) 2 (top right) | waiting on block-out |
| Ascending Stair (meditation ledge, Martial Field) | [sheet v1](../reference/sect/sect_sheet_v1.png) 3 (middle left) | waiting on block-out |
| Outer court (main plaza) | [sheet v1](../reference/sect/sect_sheet_v1.png) 4 (middle right) | waiting on block-out |
| Inner court | none yet | not started |
| Summit (elders' hall) | none yet | not started |
| Spirit peak template, then 8 characters | [sheet v1](../reference/sect/sect_sheet_v1.png) 5 (bottom left); abode 6 (bottom right) | waiting on block-out |

## What the reference says (sheet v1, approved 2026-10-24: "good enough")
Roblox in-game look: parts in SmoothPlastic with flat colours, low-poly rock, roof
and tree meshes. Read off the six panels:
- **The sect is a cluster of pillars, not one mountain** (panel 1): each tier sits on
  its own pillar top at its own height, joined by stone stairs and rope bridges; the
  summit hall crowns the tallest pillar. Two or three waterfalls drop off pillar edges
  into the clouds. The spirit peaks are pillar islands at varied heights among
  dozens of bare pillars, not a level ring.
- **Gate** (2): a tall red paifang with a slate-teal roof, gold ridge ends and hanging
  banners, on axis with the Testing Stone (a pale monolith with a jade vein) on a
  stepped plinth just past it; stone lanterns and a balustrade; the stair climbing
  beyond.
- **Stair** (3): the training terrace is a walled stone platform on the cliff's
  shoulder with a pavilion, fence and banners; the meditation ledge is its own
  small outcrop with one big pine and a round platform.
- **Plaza** (4): an open paved axis to the main hall on its stair, the cauldron on a
  jade-inlaid disc in the centre, the notice board at the side, the garden plots and
  the teleport circle to one side, stalls at the edges.
- **Spirit peak** (5): the house at the back with the big pine behind it, beds in
  front, the well and circle between; a low fence on the rim keeps the view open;
  the bridge leaves from the side. **Abode** (6): a deep cave mouth with a railed
  balcony, a round meditation platform, scroll shelves, lanterns.

## The view is the point (user, 2026-10-24)
The classic cultivation view: a sea of clouds with Zhangjiajie-style stone pillars
rising out of it, layered into the distance. The old spirit peak limited it. The
redo builds for it:
- **Every home has a view.** From the peak's lawn, the dwelling's porch and the cave
  abode, the eye goes out over the cloud sea to pillars. The abode gets a wide mouth
  or balcony on the cliff facing out; the dwelling faces the open side.
- **Nothing blocks the open side.** Trees, walls, rims and props frame the view from
  the edges, never across it; the peak's "out" side stays low and open.
- **Look down onto the clouds.** The homes sit well above the cloud sea so it reads
  as a sea below, with pillars poking through.
- **Layers of depth:** near pillars (big, crisp), mid pillars, far pillars fading
  into blue haze, at varied heights and spacing. Peaks are spaced so the gaps between
  neighbours are views too.
- **Plan each area's views with the area:** a view line (where you stand, what you
  see) goes in the area's written plan and is checked by capture from that spot.

## Where to build
The new sect is built **beside the old one** (a clear offset, away from the wilds and
the old sect's ring), so the live game keeps working; it is swapped in, the
constraint coordinates and Config updated, only when it's done.

## Style targets (user, 2026-10-24: "the styles we want to recreate / follow")
In `docs/reference/sect/style/`. All are Blender meshes mixed with smooth terrain and
Roblox parts. The sheet above says *what* goes where; these say *how it looks*.
- [waterfall_meadow](../reference/sect/style/waterfall_meadow.jpg): dense tall terrain
  grass right up to the camera, rounded boulders with green moss caps stacked into a
  wall, a glowing white-cyan fall into a bright pool, saturated sky, strong bloom.
- [forest_path](../reference/sect/style/forest_path.jpg): tall trees with clumped
  foliage in layers, a sandy path between grass banks with small white flowers, one
  big pale rounded boulder, dappled light, haze between the trunk layers.
- [pavilion_sunset](../reference/sect/style/pavilion_sunset.jpg): a red-lacquer
  pavilion with a tiered roof on an irregular flagstone platform; tall grass
  recoloured to the mood (red), a warm low sun.
- [river_town](../reference/sect/style/river_town.png): white-walled buildings with
  gray tiled roofs, wood lattice and red lanterns; a stone embankment with a
  balustrade; shallow river with grass islands and low-poly rocks; huge cliffs with
  layered strata and hanging ivy, willows, and depth in layers of blue haze.
- [part_temple](../reference/sect/style/part_temple.jpg): a temple built from
  parts: red columns and railings, layered roofs with upswept eave corners from
  wedges, gold ridge and eave trims, an octagon window, a raised plinth.
What they share, and what we copy: painted, stylized textures on the meshes (not
flat colours); dense grass; big rounded moss-capped rock; strong atmospheric haze
and bloom; few hero buildings with lots of nature around them.
**Grass decoration** is on, with a player setting to turn it off (user, 2026-10-24;
check that a client can switch it at runtime before relying on it). **Open:** how
textured the meshes are next to the flat-colour palette above.

## What to build with (user, 2026-10-24)
The map-builder's rule ("What to build with" in `.claude/agents/map-builder.md`),
confirmed for the redo. One rule for every area: go-backs are expensive.
- **Floor:** smooth terrain (lawns, plaza fill, ledges, valley floors), built by script.
- **Structures:** buildings are Blender meshes or parts, whichever reaches the bar
  (user, 2026-10-24: "buildings can be stud too"; `part_temple` is the part-built
  bar). Parts for the simple pieces (platforms, steps, walls, railings, paving).
- **Greenery:** the existing library assets and meshes (`ServerStorage.AssetLibrary`,
  place-only), or made in Blender when nothing fits.
- **Landforms, by size (decided 2026-10-24):**
  - **Large, special shapes** (the Zhangjiajie rock pillars, a hero spire): Blender
    meshes, a reusable kit.
  - **Bulk landforms** (valleys, mountains, cliffs, slopes): smooth terrain, built by
    script.
  - **Small rock** (outcrops, ledges, rock piles, edge cover): the library's boulder
    assets, enlarged and mixed.

## Step 1: the macro block-out
Gray masses only, no detail: the cloud sea's height; the sect's pillars (gate crag,
stair cliff, plaza pillar, inner terrace, summit) with their top heights and the
stairs and bridges between them; the 8 spirit peak pillars at their heights; and three
layers of bare pillars for the view. Checked by capture from the gate, the plaza, the
balcony, a spirit peak's lawn and its abode before anything is built for real.

## The agreed shape (user, 2026-10-24)
The sect is a climb: senior is higher. Every building is a verb or a view, never
filler (no disciple quarters: homes are the peaks; houses only as distant rooftops
and lanterns). NPCs make it lived in.
- **Mountain Gate**, the lowest tier on its own crag to the south: the gate arch,
  examiners, NPC hopefuls. New players arrive here as mortals. The **Testing Stone**
  stands on a terrace past the arch: the entrance trial's first station, where the root
  is rolled ([roadmap](../roadmap.md) section 2).
- **Ascending Stair**: switchbacks up the main peak's south face, with two wide ledges:
  the meditation ledge (the trial's sitting station, the first breakthrough) and the
  Martial Field (the trial's fight ring and puppets; afterwards the sparring and Dao
  drill ground).
- **Outer court**, the main plaza and daily hub: Mission Hall (the sect board), Herb
  Hall (Herbalist, markets, the shared sect garden), the elder, the array plaza and the
  bridges to the peaks.
- **Inner court**, a higher terrace seen from the plaza, gated at Inner Disciple:
  Treasure Pavilion, Scripture Pavilion, an Alchemy Hall standing closed.
- **Summit**: the elders' hall and the sect's hero silhouette. Open: whether the
  tribulation moves onto the player's own peak ([dreams](../roadmap/dreams.md)) or
  stays on the summit.
- **The 8 spirit peaks** keep one functional layout, identical on all 8 (beds and
  their `PlotId`s, the build radius, the array, the bridge gate, the cave abode; see the
  hard constraints), so saved gardens and builds are safe and every peak is equal. Each
  gets its own character (a waterfall peak, bamboo, pine cliffs, plum blossom, a lotus
  pond, a crystal vein...): its own rock silhouette, signature tree and edge dressing,
  with open lawn left for building.

## Handoff: where we are (2026-10-24)
- Done: the reference sheet, its read-out above, the agreed shape, the build rules.
- **Next:** step 1 (the macro block-out), then capture the five view spots for review.
- Studio: the user's sandbox is `mw-sandbox-martial-world-test.rbxl` (find its id
  with `list_roblox_studios`; ids change per session). It's built from
  `test.project.json`, so it has no old `Workspace.Map` and may lack the place-only
  `AssetLibrary`: check before dressing (the user's real place, "Martial World", has
  it). The vfx library plugin and Blender are up for vfx and mesh work.
- Export what's built to `assets/` as it's approved (the `studio-export` skill), so
  the new sect is in git, unlike the old map.
