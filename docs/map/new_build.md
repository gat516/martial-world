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
| The whole sect (composition) | none yet | waiting on reference |
| Mountain Gate and Testing Stone | none yet | waiting on reference |
| Ascending Stair (meditation ledge, Martial Field) | none yet | waiting on reference |
| Outer court (main plaza) | none yet | waiting on reference |
| Inner court | none yet | not started |
| Summit (elders' hall) | none yet | not started |
| Spirit peak template, then 8 characters | none yet | waiting on reference |

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
