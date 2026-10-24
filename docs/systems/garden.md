# Garden, herbs and items

## Purpose
A farming layer on the player's own peak: plant seeds in plots, harvest herbs to
eat (qi and timed buffs) or sell for Spirit Stones. Mature, unharvested plants
radiate spirit aura that speeds passive cultivation. Plus the carried
consumables: spirit cores from beasts and heavenly treasures.

## Design intent
- Real-time growth (also offline) that rewards coming back.
- Collectible variance: each planting rolls a size (Large, Huge, Colossal);
  weather swells growing plants and gives mutations (Dewy, Thunderstruck,
  Rainbow, ...); rarer plants come from mutating seeds and from wild sprouts in
  their weather.
- The garden feeds cultivation (aura, buffs, qi) without replacing the active loop
  (aura capped at `Config.Garden.AURA_CAP`).
- Herb tiers I-V by region (I Common, II Spirit, III Rare, IV Treasure, V Heavenly;
  [progression](../progression.md)). A qi herb (`eat.qi = true`) gives a fixed share
  of the eater's current stage dantian by tier (`Pacing.Herbs.EAT_SHARE`: 6, 9, 12,
  16, 20%), so a herb matters at every stage but never replaces hunting. Each tier
  has a floor (`EAT_FLOOR`: 120, 400, 2500, 8000, 20000 raw qi) so early herbs stay worth
  eating, and event herbs use a bigger share (`PRIZE`: Thousand-Year Ginseng a full
  dantian, Rift Lotus half). Raw qi only
  fills the room left in the dantian; a qi-only herb is refused when it's full. Size
  and mutations multiply the harvest (herbs per pick), not the qi per herb.
  Buff-only herbs (Spirit Grass, Cloud Mint, Moonpetal Orchid, Purple Bamboo) give no qi.
- **The herbs by tier** (22; `Herbs.Order` is this order, which is also the
  Herbarium's pages). Region is where its seeds drop (below); "shop" is sold by the
  Herbalist, "mut" comes from a lower herb's harvest (`mutatesTo`).

  | Tier | Herb | Soil | Rarity | Grow | Region | Seeds from | Eat (on top of the tier's qi share) |
  |---|---|---|---|---|---|---|---|
  | I | Spirit Grass | bed | Common | 2 min | Inner Wilds | shop, beasts | buff only: +15% cultivation 3 min |
  | I | Cloud Mint | bed | Uncommon | 5 min | Inner Wilds | shop, beasts, mut | buff only: +6 speed, +10% 2 min |
  | I | Jade Lotus | pond | Uncommon | 8 min | Inner Wilds | shop, beasts | +20% 3 min |
  | I | Ghostlamp Lily | pond | Uncommon | 12 min | Ruined Borderlands | beasts | +15% 3 min |
  | I | Purple Bamboo | grove | Uncommon | 10 min (regrows 4) | Inner Wilds | shop, beasts | buff only: +4 speed 3 min |
  | II | Blood Ginseng | bed | Rare | 15 min | Outer Wastes | shop, beasts, mut | qi only |
  | II | Moonpetal Orchid | bed | Epic | 30 min | Outer Wastes | mut | buff only: +50% 10 min |
  | II | Violet Cloud Fungus | bed | Epic | 20 min | Outer Wastes | wild (Auspicious Mist) | +30% 5 min |
  | II | Duskwind Thistle | bed | Rare | 25 min | Outer Wastes | beasts | +5 speed 3 min |
  | II | Spirit Peach | grove | Rare | 40 min (regrows 10) | Outer Wastes | shop, beasts | +25% 5 min |
  | III | Seven-Star Grass | bed | Epic | 1.5 h | Deep Wilds | beasts, mut | +60% 10 min |
  | III | Nine-Leaf Lingzhi | bed | Legendary | 2 h | Deep Wilds | mut, Deep Wilds bosses | +100% 15 min |
  | III | Thousand-Year Ginseng | bed | Legendary | 4 h | Deep Wilds | world event | a full dantian (PRIZE), +150% 20 min |
  | III | Rift Lotus | pond | Legendary | 1 h | Deep Wilds | wild (Heaven Split), mut | half a dantian (PRIZE), +75% 15 min |
  | III | Emberheart Fruit | grove | Epic | 2 h (regrows 45 min) | Deep Wilds | beasts, mut | +40% 10 min |
  | IV | Dragonblood Vine | bed | Legendary | 4 h | Far Reaches | beasts, mut | +120% 20 min |
  | IV | Phoenix Plume Orchid | bed | Legendary | 6 h | Far Reaches | beasts | +150% 20 min |
  | IV | Snowpeak Lotus | pond | Legendary | 3 h | Far Reaches | beasts, mut | +100% 15 min |
  | IV | Starfall Bamboo | grove | Epic | 4 h (regrows 1 h) | Far Reaches | beasts, mut | +8 speed 5 min |
  | V | Tribulation Thunder Grass | bed | Legendary | 8 h | Far Reaches | Far Reaches bosses, mut | +200% 20 min |
  | V | Ninefold Heaven Lotus | pond | Legendary | 12 h | Far Reaches | Far Reaches bosses, mut | +250% 30 min |
  | V | Dao Origin Fruit | grove | Legendary | 24 h (regrows 6 h) | Far Reaches | Far Reaches bosses, mut | +300% 30 min |

  Mutation chains: Spirit Grass > Cloud Mint > Blood Ginseng > Moonpetal Orchid >
  Nine-Leaf Lingzhi > Dragonblood Vine > Tribulation Thunder Grass; Duskwind Thistle >
  Seven-Star Grass > Nine-Leaf Lingzhi; Jade Lotus > Rift Lotus > Snowpeak Lotus >
  Ninefold Heaven Lotus; Purple Bamboo > Spirit Peach > Emberheart Fruit > Starfall
  Bamboo > Dao Origin Fruit.
- **Seeds come from the region** (`Herbs.Regions`, [progression](../progression.md)).
  Each damager of a kill rolls `BEAST_SEED_CHANCE` (bosses always drop `BOSS_SEEDS`)
  from the pool of the region the beast died in (`Regions.at` on its model; bosses add
  the region's `bossSeeds`). Off the seed regions, and always in the testbed, the
  beast's `realm` picks it on the ladder: Inner Wilds QC1, Ruined Borderlands QC5
  (tier I), Outer Wastes QR1 (II), Deep Wilds QR6 (III), Far Reaches FE4 (IV, with tier V
  only from its bosses). Deep Wilds and the Far Reaches have no map region yet, so
  today only their realm reaches them.
- One prompt key (F) for beds and ripe plants; G buys "Grow now" (see
  [monetization](monetization.md)).

## Key files
- `src/shared/Herbs.luau`: plant defs (tier, region, soil, grow time, yield, aura, eat
  effect, seed cost, sell price, mutation chain, model and stand-in), the seed regions
  (`Regions`), sizes, mutations, `eatQi` (share and floor; and the qi part of each qi
  herb's blurb, built at load from them), `template`/`clone` (the model or its tinted
  stand-in), `progress`, `growNowTier`.
- `src/shared/Items.luau`: every consumable (herbs mirrored in, spirit cores,
  treasures) and its `use`.
- `src/shared/Hotbar.luau`: nine slots of techniques and items.
- `src/server/Garden.luau`: plant/harvest/uproot, the 10 s weather tick (growth,
  swelling, mutations), wild sprouts, regional beast seed drops (`seedRegion`), the
  Herbalist (buy seeds, sell herbs), Grow now receipts.
- `src/server/Herbarium.luau`: the collection record and its rewards (see
  [herbarium](../ui/herbarium.md)); `Garden.harvest`, wild gathers and the guarded-herb
  event call `record`.
- `src/server/Inventory.luau`: items as real Tools in the Backpack, `use`, hotbar
  edits, beast drops (`onKill`), `grant`.
- `src/server/Treasures.luau`: treasures that fall in the wilds in auspicious weather.
- Client: `GardenView.luau` (draws plants from the plot's `Plants` JSON, prompts,
  PlantTag), `Planting.luau` + `PlantingBar.luau` + `SeedPicker.luau` (seed packet
  tiles), `PlantTag.luau`, `HerbShop.luau`, `Inventory.luau`, `HotbarView.luau`,
  `SlotArt.luau`; `HerbArt.luau` (shared kit art: herb in an item slot, rarity gems,
  mutation ribbons, tier shields); `Herbarium.luau` (the collection book, H). Their
  look and the Herbarium's API: [herbarium](../ui/herbarium.md).
- Models: plant templates are `ReplicatedStorage.HerbModels.<model>` (place file only;
  the testbed has an empty folder, so plants don't draw there). A def's `model`
  defaults to its id; a herb whose template is missing draws its `standIn` (an
  existing model of the same soil) tinted 55% to its colour (`Herbs.clone`).
  `ReplicatedStorage.GardenKit` (`assets/GardenKit.rbxmx`) holds prompts and glows;
  plots are build items tagged `HerbPlot` with a `Soil` attribute.
- `src/client/HerbAnimator.luau`: procedural R6 hand-to-mouth gesture, bite,
  two small chewing nods, and eased return. Each client animates confirmed eats;
  `HeadLook` eases the local gaze forward during the gesture. The temporary
  morsel is cloned from `ReplicatedStorage.HerbMorsel`
  (`assets/HerbMorsel.rbxmx`, authored from the Herb Tool in Studio).

## Data flow
`GardenAction("plant", plotId, herbId, x, z)` -> a `Plant` record in
`data.peak.plots[plotId]` -> mirrored as JSON in the plot's `Plants` attribute ->
every client draws it. The garden tick applies weather; `Cultivation.aura` sums
mature plants each second. Harvest grants herbs (and sometimes seeds); eating goes
through `InventoryAction("use")`.

Successful herb uses also broadcast `Effect("herbEat", character, itemId,
serverTime)`. Effects and inventory deduction still happen immediately; the
animation is cosmetic. A separate morsel remains visible until the bite even when
the last inventory Tool is removed, and also supports the inventory's Use button.
Held Tools and weapons are hidden locally for the gesture, then restored.
Combat actions interrupt/override eating; death, despawn and completion clean up
the pose and prop. Unsupported rigs skip the gesture (the game uses R6).

## Tuning knobs
- `Herbs.luau`: everything per plant; `Sizes`, `Mutations`, `GOLDEN_CHANCE`, `MAX_SIZE`.
- `Pacing.Herbs`: `EAT_SHARE` (qi per herb as a share of the dantian, by tier),
  `EAT_FLOOR` (the least raw qi, by tier), `PRIZE` (event herbs' share, by id).
- `Herbs.Regions`: each region's beast seed pool and boss additions (weights).
- `Pacing.Herbarium`: `DISCOVER` and `TIER` stone rewards.
- `Items.luau`: core and treasure effects, `treasureWeight`, `USE_COOLDOWN`.
- `Items.HERB_EAT_SECONDS` (1.05 s) sets the herb use cooldown and animation duration;
  `HERB_BITE_SECONDS` (0.4 s) removes the morsel. Reach/chew/return poses and
  their phase times live in `HerbAnimator.luau`.
- `Config.Garden`: seeds back, tick, aura cap, wild sprouts, beast seed chance and boss count, Grow now tiers.
- `Weather.luau` `garden`: growth speed, mutation and chance per weather.
- `Config.Economy`: starting stones; `Config.Build.MARKET_RANGE` (also how far you can walk
  before the Herbalist window closes, via `MarketRange.luau`).

## Known gaps
- Grow now product ids are placeholders (0) until the products are created.
- The 11 herbs added 2026-10-23 (Ghostlamp Lily to Dao Origin Fruit) draw tinted
  stand-ins until their models are built (below) and have glyphs, no icons.
- Deep Wilds and the Far Reaches aren't map regions yet; their seeds drop only by
  realm (an elite or apex beast anywhere off the seed regions, or the testbed).
- Tier IV-V numbers (grow times, aura, sell prices, buffs) are first guesses; the
  aura of a full tier V garden reaches `AURA_CAP` fast.
- Foundation's Home hint suggests the next herb tier to harvest even when that tier
  belongs to a far later realm.

## Models to build
For the modeler: one template per herb in `ReplicatedStorage.HerbModels`, named by the
id, built like the existing ones (mature size at scale 1; plants are drawn at
`SPROUT_SCALE` and scaled up as they grow, so there are no separate growth-stage
models; keep the template's pivot at the stem's ground point, upright). Until one
lands, the stand-in shown draws tinted.

| Id | Name | Tier | Soil | Stand-in | Look |
|---|---|---|---|---|---|
| GhostlampLily | Ghostlamp Lily | I | pond | JadeLotus | pale jade-white lily on a long stem, its closed bulb a soft cold-green glow like a ghost lantern; dark marsh-green pads |
| DuskwindThistle | Duskwind Thistle | II | bed | CloudMint | tall wind-bent silver-grey thistle, spiky leaves, two or three violet-dusk flower heads leaning one way |
| SevenStarGrass | Seven-Star Grass | III | bed | SpiritGrass | dark blue-green tuft of long blades with seven small white star flowers set like the Northern Dipper, faintly glowing |
| EmberheartFruit | Emberheart Fruit | III | grove | SpiritPeach | small charcoal-barked tree, leaves red at the tips, crackled ember-orange fruit that glow from inside |
| DragonbloodVine | Dragonblood Vine | IV | bed | BloodGinseng | thick dark-crimson vine coiling up on itself in a spiral, scale-like leaves, beads of glowing red sap |
| PhoenixPlumeOrchid | Phoenix Plume Orchid | IV | bed | MoonpetalOrchid | tall orchid whose petals are long curling plumes, gold at the base to scarlet at the tips, like a phoenix tail |
| SnowpeakLotus | Snowpeak Lotus | IV | pond | JadeLotus | pure white many-layered lotus with ice-blue petal tips, frosted pads, a faint cold mist |
| StarfallBamboo | Starfall Bamboo | IV | grove | PurpleBamboo | midnight-blue culms with silver nodes, leaves speckled like a night sky, slow falling motes of light |
| TribulationThunderGrass | Tribulation Thunder Grass | V | bed | NineLeafLingzhi | jagged silver-violet blades forking like lightning from a ring of scorched black soil, bright crackling tips |
| NinefoldHeavenLotus | Ninefold Heaven Lotus | V | pond | RiftLotus | a golden-white lotus of nine rings of petals, each smaller, hovering just above its pad under a thin halo |
| DaoOriginFruit | Dao Origin Fruit | V | grove | SpiritPeach | gnarled pale-jade tree with few leaves, roots spread in a taiji swirl, one fruit glowing half black, half white |
- Item qi (cores, treasures) is per item, set in `Items.luau`.
