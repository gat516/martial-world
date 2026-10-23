# Map: layout, art direction and constraints

## Purpose
The plan every map pass builds against: what each area is for, what players see
first, the palette and lighting mood, the assets to dress with, and the
instances and coordinates scripts depend on. `Workspace.Map` lives only in the
place file (not Rojo), so these docs and the commit bodies are its only history.

This file is the core: world structure, art direction, composition rules, the
hard constraints scripts depend on, passes and gaps. Each area's layout and
build notes live in its own file under `docs/map/` (index below); read only the
ones your task touches. For the setting in brief, read
[world-overview](../world-overview.md).

## Index
| File | Covers | Read it when |
|---|---|---|
| [main-peak](../map/main-peak.md) | plaza, courts, grand stairs, ring terrace, summit, falls, landform, terrain colours | working on the main peak or `art/main_peak/` |
| [spirit-peaks](../map/spirit-peaks.md) | the spirit-peak template, its dressing and rebuild scripts; the rope bridges | touching a `Peak_N` or a bridge |
| [cloud-sea](../map/cloud-sea.md) | `Map.Clouds`: plane, wisps, mounds, banks, budget, mist spots | adding clouds or placing anything on the cloud plane |
| [karst-pillars](../map/karst-pillars.md) | `Map.Karst`: kit, kinds, look, collision, composition, clearances | moving pillars or laying out anything they must clear |
| [under-sect](../map/under-sect.md) | the forest floor under the peaks, peak roots, Ascension Array path | working on the ground below the sect |
| [wilds](../map/wilds.md) | Inner Wilds and Ruined Borderlands as built: boxes, `art/wilds/` scripts, layout, encounter spaces | any wilds map pass |
| [inner-wilds-rework](../map/inner-wilds-rework.md) | the Inner walled-valley plan (proposed 2026-10-21) and its build log: walls, pockets, event grounds, finds, prefabs, water, POI pass, dressing | Inner Wilds pockets, walls, water, finds or POIs |
| [editor-markers](../map/editor-markers.md) | `_EditorMarkers`/`EditorOnly`, the `POI` tag, the POI tour, hand-pass flags, the POI audit | tagging POIs, flagging hand passes, auditing a pass |
| [build-checks](../map/build-checks.md) | the checks every pass runs: pivots, seating, POI reachability, clearance, walls, the user's hand edits | before calling any map pass done |
| [asset-catalogue](../map/asset-catalogue.md) | AssetLibrary pieces by need, and what to avoid | choosing dressing |

## World at a glance
Floating stone peaks above a cloud sea (a flat cloud plane, top Y 440). The main sect
peak sits at the origin; eight player spirit peaks ring it at radius 300 (plateaus
Y 553.5, every 45 deg from 22.5 deg, `Peak_1` at (114.8, 553.5, 277.2)), each
linked by a rope bridge to the main peak's ring terrace (Y 582). The wilds lie
far below on the ground (`Workspace.Wilds`, Y ~0-10, south of the sect gate at
(0, 9, 500)). Axes below: +X east, -Z north (the summit is north of the plaza).

## World structure
Decided 2026-10-20. One place holds the hub and every zone; separate places are
only for instanced party content.

- **Hub server, 8 players.** The 8-player cap matches the 8 spirit peaks. The
  sect (main peak, plaza, spirit peaks) is where everyone keeps returning: peaks,
  market, elder, quest board, world events and tribulations people can watch.
- **Zones in the same place, linked by arrays and, between neighbours, a walkable
  gorge or bridge.** Each wilds zone is a dense walled area far from the others in
  space (the Inner Wilds valley is ~1800 x 920), one per
  realm tier, opened by realm (`Regions` `realm`). Staying in one server keeps
  friends together and weather, treasures and world events server-wide. Keep
  the zone count low (2-3 to start) so 8 players don't spread too thin; add more
  only when the existing ones are full of content.
  Adjacent zones may also join on foot through a gorge gate and a bridge (decided
  2026-10-21: the Inner Wilds and the Ruined Borderlands stay one continuous walk over
  the border river); zones that aren't neighbours only connect by arrays.
- **Arrays carry all long travel** (`Shared.Gates`, `src/server/Travel.luau`).
  Players spawn on their own peak's array, respawn after death on the plaza's and
  arrive on the destination's. On the sect's safe ground the Travel button rides
  to the sect's arrays (My Peak, Main Peak, Sect Gate) from anywhere; out in the
  wilds you travel only from an array (its prompt), and the wilds arrays answer
  only from the Sect Gate's array or another wilds array.
- **Today:** the wilds are one continuous smooth-terrain field covering rings
  300-2200 around the origin (Inner, Middle, Outer). Each ring has one array
  (`Map.Markers.TeleportHome`), standing in for zone gates until the zones are
  rebuilt as separate areas. The Inner and Middle arrays stand in their built
  zones (see [wilds](../map/wilds.md)); the Outer one is still out on its ring.
- **What to build with** (`.claude/agents/map-builder.md`): meshes for the
  landmarks people look at (peaks, cliffs, spires, floating islands), smooth
  terrain for the ground people walk on in wild zones (exact collision for the
  ground raycasts, recoloured with MaterialVariants to the palette), parts for
  halls, houses, walls, gates and stairs (curved roofs as meshes).
- **Point-of-interest density:** something to do every 20-30 seconds of travel
  at the player's speed, in clusters with quiet space between, and one landmark
  per zone visible from its arrival array. Kinds: qi nodes, beast lairs, herbs,
  ruins/steles giving insight, meditation spots with a local bonus, hermit
  NPCs, small trials, secret-realm entrances, vistas.
- **Sword flight at Foundation Establishment:** free movement inside a zone,
  never between zones (that stays the arrays). Server-checked speed, landing
  forced in suppression zones (lairs, sect grounds), streaming requested ahead.
- **Separate places for instanced content:** secret realms, dungeons and trials,
  entered as a party (reserved server), a queue (`MemoryStoreService`) or an open
  public server. Saves must finish before leaving and load safely on arrival
  (session locking), and players always return to a hub server.
- **Later realm tiers may move to another place we own.** From about the third
  zone on, teleporting into a separate place is allowed (a "you've moved up"
  moment), at the cost of splitting friends across realms and a save handoff.
  Decide when zone 3 is close; zones 1-2 stay in this place.

### Zone shape: walled valleys, detailed pockets, open event grounds
Decided 2026-10-21. Only the spirit gate front was detailed to the target
standard, and an open field can never be finished (every direction needs
something to look at, and the horizon makes it read flat). So the terrain
funnels players, not teleports:
- **A spine and pockets.** Each zone is a walled valley a few hundred studs
  across: one main path from the arrival array, and 3-5 side pockets off it (a
  hollow, a waterfall pool, a ruin, a lair, a cache). Each pocket gets the spirit
  gate front's level of detail; cliff walls close every other view and are the
  zone edge (no invisible walls). Exploring means leaving the spine for a pocket.
- **Open event grounds.** Each zone also keeps 2-3 open, flat-ish grounds
  (meadows, clearings, a terrace) away from the arrival array and at different
  distances from it, deliberately lighter on dressing so world events,
  auspicious phenomena and treasures have room to land and players room to
  fight over them. They are the places `Treasures.randomSpot` and event kinds
  pick; keep them clear of trees and rock clusters and reachable by more than
  one route.
- **Events are races.** A world event or auspicious phenomenon is announced and
  visible from afar (light pillar, clouds), so everyone runs for it at once; the
  routes to each event ground should be about equal from the zone's array, with
  a riskier shortcut (a cleft, a climb, a lair) to reward knowing the zone. See
  [world](world.md); the Inner Wilds' three grounds and their routes are in
  [inner-wilds-rework](../map/inner-wilds-rework.md).
- **Dense with POIs.** Well past the "every 20-30 seconds" minimum: small finds
  between the big pockets (steles, herb patches, a hermit's camp, cave mouths,
  meditation rocks, vistas) and things found only off the path or by climbing.
- **Room to grow, and flight.** Players will fly (sword flight at Foundation,
  later real flight), so zones stay expandable: free space around each one so
  walls can move out or open onto new pockets (nothing scripts depend on sits
  against a wall); wall tops and backs look finished from above (a dressed rim,
  then mist or a drop); and each zone plans a vertical layer of cliff-top
  ledges, high caves and floating rocks with POIs only flyers or climbers reach.
  Each zone records its flight ceiling and bounds.
- **Bamboo is its own biome.** Bamboo grows only in pure, dense groves with a
  reason (a hero bamboo-forest pocket in the Inner Wilds, the hidden hollow,
  round steles, shrines or water), with a clear edge or a short transition of
  shoots and sparse culms. Never single clumps mixed into pine or broadleaf
  forest (today `dress_wilds.luau`'s `bambooAt` noise field does exactly that).
- **Rework passes remove what they replace.** Past AI passes layered new work on
  old (orphaned props, half-replaced dressing, misaligned seams, floating or sunk
  pieces). Every rework of an area starts with an inventory of what is there and
  ends with a sweep: every piece in the area either belongs to the new pass or is
  deliberately kept; replaced pieces go to `ServerStorage._<Area>Replaced` with a
  `FromPath` attribute (as `_WildsReplaced`), not left in place; seams that
  should meet (wall segments, path to bridge, lawn to rock) are checked for
  gaps; props are raycast onto the ground. See `.claude/agents/map-builder.md`.

### Still to do, in rough order
1. ~~**Gate UI** (`ui-designer`): TravelMenu buttons for `InnerWilds`,
   `MiddleWilds`, `OuterWilds` (TravelMenu wires any List button named after a
   gate id) showing the realm each opens at and a locked state; a prompt or glow
   on arrays so players find them; a fade while the destination streams in.~~
   Done: wilds buttons with realm locks, `GateMarkers` billboards, the `Veil`
   fade. A glow or particle on the arrays themselves is left for `vfx`.
2. **Zone separation** (`map-builder`): rebuild each wilds zone as its own
   bounded area far apart, with its array, landmark and POIs; switch `Regions`
   from rings to per-zone bounds, and update `Music.luau` (copies the layout),
   `Spawns`, qi nodes, treasures and world-event locations to match.
3. **Zone edges:** tall stacked-rock cliff walls with waterfalls (see
   "Verticality"), so each zone is an enclosed valley; mist where a wall can't
   go, plus an out-of-bounds return to the zone's array.
4. **Combat tag:** `Combat.inCombat` (taking damage within `IN_COMBAT_SECONDS`)
   already blocks travel. Also count dealing damage and being targeted by a
   beast, so hitting and running to an array doesn't work.
5. **Array discovery:** wilds arrays unlock on first visit (saved per player),
   on top of the realm requirement.
6. **Quiet empty zones:** no zone spawns or AI ticks where no player is.
7. **World events and treasures** pick a zone someone is in.
8. **Cross-place travel:** party/queue/open entry, data handoff, return to hub.
9. **Sword flight.**

## Art direction
Stylized, chunky, readable; shape carries detail. Plain colours on
SmoothPlastic (the modeler's rules: crisp vertical rock columns, grass only as
slabs with one overhanging turf lip). Never one flat colour over a big area:
vary each slab or part a step either way inside its family.

| Family | Base | Light | Dark | Use |
|---|---|---|---|---|
| Lawn (jade/sage) | `#6E8F5A` | `#83A36A` | `#56744A` | lawns, ledges; turf lip `#4A6340`, moss `#4E6B45` |
| Rock (warm gray) | `#7A7570` | `#8E8983` | `#615D59` | cliffs; deep base/shadow `#4D4A47` |
| Paving | `#B3AA9A` | `#C2B9A8` | `#9A9183` | plaza, paths; curbs `#8A8274` |
| Wood | `#5A3F2E` | `#6E4F3A` | `#3F2C21` | posts, rails, bridges, fences |
| Lacquer | `#9B2D26` | `#B23A30` | `#74201C` | columns, gates, lantern bodies |
| Roof | `#33403F` | `#43524F` | `#262F2F` | tiled roofs (slate teal, not black) |
| Jade | `#5FAE96` | `#8FD4BC` | `#3E7F6C` | lamps, runes, inlays |
| Gold | `#C29A48` | `#DDBA68` | `#8E6E30` | trims, caps, finials |
| Water | `#4E9FB2` | `#CFE6EA` (foam/rim) | `#2F6E80` | pool rims, wet stone; the water itself is brighter (WaterKit `#20AAE0`, foam `#F2FCFF`, after the library falls, [world water](../world/water.md)) |

### Verticality: walls and water
Decided 2026-10-21, from the reference `docs/reference/map_enclosed_valley.webp`.
The map reads flat: the wilds are rolling ground under open sky, so every view
ends in a horizon. Ground-level areas should feel like **enclosed valleys**:
- **Walls:** each pocket is ringed by cliffs of big stacked, chunky, blocky
  boulders (meshes in the house rock style, or library rocks sized up and
  piled), 15-40 studs high near the path and rising higher behind, with grass
  and moss spilling over every top and a few trees growing out of ledges. A
  player at the path should see a wall or rise behind most things they look at.
  Walls are also the zone edges ("Still to do" step 3), so they replace invisible
  boundaries.
- **Waterfalls:** the hero of most pockets. A bright white-cyan fall drops from
  a notch or overhang in the wall into a pool with a stone rim (a flat water
  part, never terrain water with a mesh fall). Several zones should have more
  than one: a big hero fall plus small trickles down other walls. Spray and mist
  are `vfx` (`FX_FallSpray`, `FX_FallMist`).
- **Framing layers:** foreground (tall grass and bushes by the path), mid (path,
  boulders, crates and props), background (the wall and its fall), with tall
  trees on both sides framing the view.
- **Light:** sunlit tops bright fresh green, shade sides cool blue-violet, pale
  warm stone; bloom on water. The sky stays a clear saturated blue in the day.
- Terrain grass decoration (the reference's big blades) stays off for mobile
  unless the user asks; fake it with grass clumps from the library by paths.

Left to undo: a floating 125x1x117 gray slab (`MainPeak.Part` at (-72, 721, 90)), unless
the landform pass already deleted it (no commit says so; check the place). The lime grass,
cool flat rock and neon garland lanterns are gone (see [main-peak](../map/main-peak.md)).

Lighting: `src/client/DayNight.luau` (`KEYS`) drives Lighting, Atmosphere,
ColorCorrection, Bloom and SunRays at runtime, so tune the mood there, not on the
Lighting instances (those are only the Edit-mode look).
- Day: soft and warm (tint ~`#FFFAF4`), mist that thickens with distance over the
  cloud sea (Atmosphere density ~0.24, haze ~0.7), peaks fade to blue-gray.
- Dusk/dawn: peach/rose atmosphere, low sun rays.
- Night: moody blue (ambient ~`#262C52`, outdoor ~`#424E84`), lanterns (`#FFB56B`),
  jade lamps (`#7FE0C0`) and qi glows (`#9FD8FF`) carry the scene. Light pools
  should mark paths, entrances and focal points, not be sprinkled.
- Budget (mobile): GlobalShadows stays off; PointLight/SpotLight `Shadows=false`,
  Range <= 16; about 40 lights in view on the plaza and <= 8 per spirit peak;
  fake distant glow with Neon parts and bloom instead of more lights.
- Lights that follow day/night go under `Map.Sect.Ambience` (the first recursive
  "Ambience" under Map). Particles and beams are `vfx` work: leave named
  Attachments (`FX_<What>`, e.g. `FX_FallSpray`, `FX_Fireflies`, `FX_LanternFlicker`).

## Composition rules
- Every area starts from a written plan: arrival point, the one hero landmark,
  the main path and where it ends, two or three secondary spots, the edges.
- Block out in gray parts, `screen_capture` from where players stand and from the
  approach, then build for real.
- Props have a reason (frame a path, mark an entrance, sit where people would put
  them, soften an edge). Water has a source and a rim.
- Clusters of odd numbers and mixed scale (big + medium + small) with quiet space
  between; no even sprinkling, identical spacing or one-of-each.
- Vary height: terraces, steps, plinths, low walls, tall trees over shrubs.
  On the ground, enclose: every view from the path ends in a wall, a rise or a
  waterfall, not open horizon (see "Verticality").
- Edges get the most care: lawn-to-rock (turf lip, rocks, shrubs, moss),
  path-to-lawn (curb or stepping stones), bridge landings (posts, gate, pad).
- Cliffs: a few deliberate ledges of clearly different sizes, each with a reason
  (a pine, a shrine, a waterfall step). Never rows of same-size ledges.
- Mirror symmetry only on the ceremonial axis (plaza); everything else is
  asymmetric.

## Hard constraints
From a read-only audit of the code (2026-10-20); code refs inline.
- `Workspace.Map` is place-only. `Workspace.Hub` (`assets/Hub.rbxmx`) and
  `Workspace.Wilds` (`assets/Wilds.rbxmx`) are Rojo-mapped: AGENTS.md staging.
- Spirit peaks: `Map.Sect.SpiritPeaks.Peak_1..8` (Models; folder name read in
  `Peaks.luau`, `MyPeak.luau`, `Peak.luau`). Attributes Owner, OwnerName,
  PeakName. `Plateau` (invisible 100x100 cylinder, PrimaryPart) is the frame
  origin for saved layouts, build bounds (`Config.Build` RADIUS 47, Y -30..30,
  PEAK_RADIUS 60), RealmTier and wild herb spots: never move it or the rock
  relative to it.
- Keep names TeleportArray (home spawn, reserved r 9), SpawnLocation (disabled),
  NameStele>Cap (owner sign), Placed (Folder), BridgeGate (reserved r 9),
  AbodeEntrance (reserved r 7), Pillar and Plateau (GROUND names), Garden.
  Restricted names: Bridge, BridgeGate, CaveAbode, NameStele, TeleportArray,
  Pillar, Garden. Free to restyle: GardenAnchor, DwellingAnchor, AbodeInterior,
  Accent, Foliage, Props, CliffDecor, Well, Trough, Dwelling.
- Starter pieces: descendants with `StarterId` (+`ItemId`); ids identical on all
  8 peaks and never changed (saved data stores removed ids; `PeakStash` holds
  stashed ones). Moving them is fine.
- Beds `Garden.Beds.Bed_K`: tag HerbPlot, attrs PlotId, ItemId, BedIndex, Soil,
  Round; child `PlotAnchor` never resized or rotated. Losing a PlotId deletes
  saved plantings.
- RealmTier `ServerStorage.PeakTiers.Foundation` (`assets/PeakTiers.rbxmx`:
  Lantern1-8 at r 47 y 7, a thin jade SkyBeam with a gold SkyBeamCore from y 75
  to 344) plus the place-only `ServerStorage.PeakTierModels.Foundation`
  (`Pavilion`: the plaza Temple mesh on an inverted Slate rock island, top y 56,
  spike bottom ~y 32, spirit stone, gold finial, roots, fern tufts), which
  `Peaks.applyRealm` merges into the clone. Library MeshParts live place-only
  because Rojo can't sync MeshIds (they arrive as gray boxes). Peak-local X/Z
  +-49, all non-colliding with CanQuery off; re-check clipping if the plateau
  surface changes.
- Teleport arrays (`Shared.Gates`): every array players travel through is tagged
  `TravelGate` with a `Gate` attribute: `Plaza.TeleportArray_Plaza` "MainPeak"
  (66, 649.5, 92; also the death respawn), `Markers.TeleportHome.TeleportHome_Gate`
  "SectGate" (48, 6, 470; turned 2026-10-21 to face west-north-west, LookVector
  (-0.98, 0, 0.21), so arrivals face the GateWolves lair across the gate road; it faced
  north into the sect wall before), `TeleportHome_Inner` "InnerWilds" (18, 4.2, 676; a
  clearing east of the trunk past the Old Stone Gate, facing south down the path),
  `TeleportHome_Middle` "MiddleWilds" (234, 1.4, 1662; between the road and the east
  road past the Border Gate, facing south toward the arena; moved with the Borderlands), `TeleportHome_Outer`
  "OuterWilds", each peak's `TeleportArray` "Peak". Arrivals land 4
  above the pivot facing its LookVector; travel works within 12 studs flat of the
  pivot. Arrays are `ModelStreamingMode` Atomic. Moving one moves where players
  arrive; keep the tag and attribute on any rebuild. `SectGate.AscensionArray`
  (0, 5.1, 236) is tagged with Gate "SectFoot", an id not in `Gates.List`: you
  can leave from it (the way out for anyone who fell under the sect) but it is
  never a destination, and its marker reads "Teleport Array".
- Main peak: PlazaSpawn (0, 648.3, 100)
  is the only enabled spawn (players are moved straight onto an array); plaza floor at Y ~647-648 under it. Hub: Elder
  (-24.2, 652.7, 80), QuestBoard (24, 652.15, 80), SpiritMarket (40, 650.1, 96)
  (MARKET_RANGE 24); prompts by name (MarketPrompt, Herbalist).
- TestingStone (spirit-root reveal, `Roots.luau`): `Hub.TestingStone` at
  (-34, 648.6, 64) on the plaza floor west of the axis, 19 studs N-W of the
  Elder, step facing the spawn. Stone > TestPrompt (found recursively) and
  Stone > PillarOrigin (top centre, Y 654.85) for the root pillar vfx; keep the
  air above it clear. Built by `art/main_peak/build_testing_stone.luau` into a
  staging clone, then spliced into `assets/Hub.rbxmx`.
- Tribulation: `Config.Tribulation.CENTER` (2, 857, -86), ARENA_RADIUS 34; the
  floor raycast from CENTER+20 down 60 (CanCollide parts only) must hit the
  walkable floor (TopSurface, Y 855.3) (`Tribulation.luau`). Effect parts above
  the floor (TribulationLightning) must stay CanCollide off.
  Keep a walkable floor >= 34 radius at Y ~855.5 with clear air, or update Config.
- Day/night lights: `DayNight.luau` scales only Lights under the first recursive
  "Ambience" under Map (`Map.Sect.Ambience`). Never add another "Ambience".
- Regions (`Regions.luau`): the sect is ring 0-410 on the ground (the under-sect floor
  included) and ring 0-470 above Y 150 (only over the sect, so flyers in the wilds keep
  their region); InnerWilds box x -1020..1020, z 470..1560 and MiddleWilds box x
  -320..620, z 1560..2060, both below Y 420 (the wilds' flight ceiling under the cloud
  plane); Outer still the ring 1600-2200. `Music.luau` copies the Borderlands line
  (`MARSH_SOUTH` 1560) and the boss arena centre (220, 1800).
  SECT_GATE (0, 9, 500).
- Wilds zones and qi nodes (positions in `assets/Wilds.rbxmx`) are leash and
  spawn homes; ground raycasts (spawns reject Water, treasures, placement) need
  real collision under them.
- Event grounds (`Wilds.EventGrounds`, parts with a `Radius` attribute, in
  `assets/Wilds.rbxmx`) are where `Treasures.randomSpot` drops treasures and world
  events; keep them flat, open (no trees or rock clusters inside) and on real
  collision, and move them with the zone reworks (staging).
- Weapon racks and manual caches (`src/server/WorldCaches.luau`, design in
  `docs/systems/weapons.md`): found only by CollectionService tag, anywhere
  under Workspace. Each anchor is an invisible BasePart (Transparency 1,
  anchored, CanCollide/CanQuery/CanTouch off); the server parents the prompt
  (`ItemTemplates.RackPrompt`/`CachePrompt`, 10 studs) to it, so the anchor is
  where the prompt shows. Moving anchors is fine; renaming a `Cache` id or a
  rack's `Weapon` re-opens it for everyone who claimed it (`data.caches`).
  - `WeaponRack` (attr `Weapon`, optional `Cache`, default `rack:<Weapon>`):
    `Plaza.WeaponRack` in the west court, a lacquered rack against the court's
    west balustrade (x -93, z 50..72, floor 649.2) facing the axis, with a chest
    and crates at its south end. One `RackAnchor_<Weapon>` (1 stud cube) per
    weapon at (-92, 652.7, z): IronJian 52.9, IronDadao 55.8, IronGreatsword
    58.6, IronGuandao 63.4, IronSpear 66.2, BambooStaff 69.1. The weapons on it
    are part props (non-colliding).
  - `ManualCache` (attrs `Cache` unique id, `Manual` technique id and/or
    `Weapon`, optional `Realm` stage key like "QC3"): `Map.Markers.ManualCaches.
    Cache_<Manual>`, each a small Slate pedestal (or a log at the camp) with a
    red cloth, a 1x0.2x1 `CacheAnchor` on top (the server rests
    `WeaponModels.ManualScroll` on it, so keep ~1.5 studs clear above), an
    `FX_CacheGlow` attachment on the cap for `vfx`, and a little dressing.
    Harder spots hold the stronger manuals:
    | Manual | Cache id | Realm | Anchor | Spot |
    |---|---|---|---|---|
    | CrescentSweep | cache_crescentsweep | - | (-126, 8.05, 620) | in the bamboo at the south foot of Old Stone Hill's boulders, by the end of the Hidden trail (Inner) |
    | RampagingTiger | cache_rampagingtiger | - | (313, 8.7, 628) | hunter's camp rise, beside the tent's south end, 17 studs off the camp's back (Inner, east) |
    | HeavenSplitter | cache_heavensplitter | - | (-100, 9.6, 816) | west foot of the Shrine Terrace's boulders, off the WestLoop (Inner, deep) |
    | DragonPierce | cache_dragonpierce | QC3 | (-302, 8.0, 685) | in front of the wolf den crag's south boulders (Inner, wolves) |
    | GreatSageAwakening | cache_greatsageawakening | - | (-77, 7.2, 1779) | at the SerpentGrotto's mouth, end of the Grotto trail (Middle, moved with the zone) |
    Re-seat the pedestals if the wilds terrain is re-run. The bamboo hollow, the
    WolfDenCave and the grotto are filled by BoulderPile hull colliders, so caches
    sit just outside them. The 2026-10-21 audit moved four that were unreachable or
    hidden: HeavenSplitter sat inside a boulder pile and a tree trunk, DragonPierce
    inside a boulder pile, GreatSageAwakening in the filled grotto (1 of 24 approach
    spots could see it), RampagingTiger half behind the camp's crates. After any
    dressing change re-run the audit (see [editor-markers](../map/editor-markers.md)):
    each cache needs open standing spots within 8 studs with a clear line to the
    scroll, through visual meshes as well as colliders.
- Free (no code reads them): `Map.Markers.*` (except the tagged TeleportHome arrays and ManualCaches), `Map.Clouds`, `Map.Ground`, tags
  SwayBridge, WindShake, SkyLantern. Place-only: `ReplicatedStorage.BuildCatalog`,
  `ReplicatedStorage.HerbModels`, `ServerStorage.PeakStash`.
- Collision matches looks: raycast-check walkable areas in Edit mode after every
  change. Meshes follow the `mesh-pipeline` skill (build script in `art/`, FBX +
  bounds JSON, batched import via `art/fbx_export/`, `place_*.luau`).

## Passes (in order)
1. **Collision holes** (done, `fcc1119`): spirit-peak lawns backed by
   `Pillar.LawnCollider` boxes (`art/lawn_collider.py`); main peak terrace,
   ledges, bridges and the rebuilt plaza raycast-checked with no holes. Not yet
   walked in play.
2. **Main peak landform** (`art/main_peak/build_main_peak.py`): warm rock with
   per-column value variation, lawns as jade slabs with turf lips, the 4-5
   planned cliff ledges instead of 14, terrace notches and mesa cleft for the
   two waterfalls, spring pools with rims. Delete the stray sky slab.
3. **Plaza rebuild**: block out hall terrace and courts in gray, capture from
   spawn and the stairs, then pave, wall and dress; recolour garland lanterns to
   lacquer/gold; group planters, lanterns and benches per court.
4. **Ring terrace, waterfalls and bridgeheads**: pools, falls (asset library
   waterfalls re-coloured), landings, pine clusters, VFX attachments.
5. **Spirit peak template**: Peak_1 focal terrace, signature tree, garden curb
   and path, edges, abode gate, bridge landing; replicate to Peaks 2-8.
6. **Lighting and night**: retune `DayNight.luau` KEYS to the palette above, place
   path/entrance lights under `Map.Sect.Ambience`, hand fireflies, mist, spray
   and lantern flicker to `vfx`.
7. **Detailing and distance**: moss, small rocks, flowers at edges; drifting
   clouds and far karst silhouettes; final day/night captures from spawn, the
   balcony, a bridge, a spirit peak gate and the summit.

## Known gaps
- Other WildsKit models had smaller pivot offsets (Wide_L 54 studs, Pine_A/C 36-38,
  CliffMass_2/3 33), so trees and cliff masses stood up to that far from where the layout
  put them (their colliders follow them). Fixed in the kit; the Inner valley's dressing was
  re-run in the rework's phase 4, the Borderlands' is only right once `dress_wilds.luau` is
  re-run there.
- The wilds outside the Inner valley read flat: low ridges and rims under open sky, no
  tall walls and no waterfalls on the ground. The Inner valley has its walls and falls
  ([inner-wilds-rework](../map/inner-wilds-rework.md)); the Borderlands and the Outer Wastes
  still need a walls-and-water pass (see "Verticality").
- Wilds: only the Inner and Middle boxes south of the sect gate are built (see
  [wilds](../map/wilds.md)); the rest of those rings and the Outer Wastes still carry the old sprinkled
  ring dressing (zone separation, step 2 above). `art/karst/place_karst.luau`'s array
  clearance list still has the Inner/Middle arrays' old spots (524, -367), (-403, -1108).
- Under the sect: the path and array clearing have no lights or dressing yet;
  `FX_` attachment points for mist/fireflies there are still to place.
