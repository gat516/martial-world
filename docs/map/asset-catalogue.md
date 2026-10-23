# Map: asset catalogue
What to dress with from `ServerStorage.AssetLibrary` (and the kits), by need, plus what to avoid. Read it when picking props, rocks, trees, water or structures for a map pass.

All under `ServerStorage.AssetLibrary` unless noted. Clone, don't move, the
originals; re-colour to the palette.

| Need | Pieces |
|---|---|
| Lanterns, lamps | `_Templates.FX_StoneLantern`, `FX_JadeLamp`, `FX_Brazier`; `Stylized Asset Pack I/Stylized Wooden Props I/Stone Lamps` (Stone Lamp 1 4x7, Stone Lamp 2 4x16); `Stylized Asset Pack I/Stylized Props/Stylized Lamp Post` (2x16); `Map Detailing`: Lanterns 1/2/3 (hanging strings ~15 tall), Lantern 1/3/4 (small), Latern 2; Inno `Wood_Iron_Assets/Lantern_Pole`, `Lantern` |
| Rocks | `Stylized Rock Packs`: Cliff Rock Pack I (Cliff Rock I-III, 10-17 wide), Cliff Rock Pack II (Cliff Terrain Rock 45-70 wide: big edge masses), Fantasy Rocks (Rock I-V, 10-20), Stone Rock Pack (Single Stone 1-5 wide, standing stones); Inno `Customizable_Assets/Rocks` (Rock_01..Rocks_07, Presets 01-06 clusters 30-46 wide) |
| Shrubs, ground cover | `Stylized Foliage + Pots/Stylized Bushes` (Green 7-34 wide; Orange for autumn accents only); `Plants + Pots` (Ferns, Leaf, Reeds, Mush, Pot & Flower); Inno Foliage (Bush1/Bush2), Clovers 01-03, Flowers (Blue/Pink/White/Yellow beds), Mushrooms; Map Detailing Bush Pink/White/Yellow flowers (6x5x9) |
| Trees | Inno `Pine_Trees` Variation_01-06 (4 sizes each, 33-45 wide, 57-75 tall: the best chunky pines); Map Detailing Pine Tree 1-5, Tree 3 realistic, Tree 2 realistic, Small Tree 1-3; `Stylized Tree Pack` (Light/Dark Green 43 tall, Wide, Orange, Wind Physics); `_Templates.BambooCluster_1..3` (old single-part unions, ~45 tall); `_Templates.BambooCluster_4..16` (Models, `art/bamboo/`, `BambooKind` attribute: 4 Grove dense clump, 5 Sparse 4 culms, 6 Single tall culm, 7 Arching wind-bent, 8 Young with shoots, 9 Stumps cut, 10 Dry gold accent, 11 Thicket low oval row, 12-14 Stand A/B/C 16x16 tiles that butt into a continuous grove (turn by 90 deg), 15 Giant 78-96 tall for the hero grove, 16 Edge 16x8 border strip, tall side +Z, shoots toward -Z; multi-part, so recolour per part, not `c.Color`); `Tree Log Stumps` |
| Fences, rails | Stylized Wooden Props II `Stylized Fence` (Full Fence, Fence Pillar 7 tall); `Stylized Props/Bamboo Fence (modular)`; Inno `Fences/Fence_01..03` (7x4); Map Detailing Asset Pack Fence1-3; `Lighting Fence` |
| Paths, edging | `Textures` (Pavement I-III, Tiles, Ground I/II, Grass I/II, Wood Planks; reference swatches for colours); Map Detailing Pebble, Stone (8x1x8 stepping), Inno Logs |
| Water edges | `ServerStorage.WaterKit` (stylized shallow water, never terrain water: `ShallowWater` block / `ShallowWaterRound` surfaces, `waterKit.dress` for unions, `RimFoam` and `waterKit.rimPart`/`rimAlong` rims, `WaterfallFoam` at a fall's foot with `AmbientFX.WaterfallSpray`; see [world water](../world/water.md)); LilyPads (W Flower 7 wide), Inno Lilypads 01-06, Reeds; `VFX`: Blue Waterfall (28x80, the colour reference for water), WaterFall Main (26x62), Stylized Rock Formation Waterfall (87x74), Map Detailing Stylized waterfall 2/3, Water Fountain, Wells (Clean Blue, Mossy Green) |
| Bridges, stairs | `Stylized Bridges + Step Ladders` (Bridge I/II 108 long, Step Ladder I/II); Inno `Stone_Bridges/Bridge_Regular` (38 long arch, good for pool crossings), `Bridge_Wood`; Map Detailing Bridge, Pier |
| Props | `Stylized Props`: barrels, crates, sacks, hay, trough, buckets, table + chairs, ladders, cart wheels; Wooden Props I: Pushing Cart, Strong Box; Props II: logs, LogPile, bench; Map Detailing: Gong, Wood Sign 1/2, Display, Market shop, Whistling board, Candles, Book Podium, Bell Pillar, Stone Statue |
| Structures | Map Detailing: Tori Gate (with/without sign, 36x30), Temple Structure (36x32), Shop House, Smith House, House 1-3; `Stylized Market Tent`; VFX Shrine Statue, Portal |
| Clouds | own meshes in `ServerStorage.CloudKit` (`art/clouds/`); Props II `Stylized Clouds` (22-28 wide swirl puffs, used as `Map.Clouds.Auspicious`); Map Detailing `Clouds_01..09` (flat side-profile strips, unused) |

Avoid: Map Detailing modern props (traffic cones, hydrants, mail box, AC unit,
stop sign, street lights), palm trees, Castle/Medieval_House, Dummy.
