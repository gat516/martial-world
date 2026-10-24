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
  has a floor (`EAT_FLOOR`: 120, 400, 2500 raw qi for I-III) so early herbs stay worth
  eating, and event herbs use a bigger share (`PRIZE`: Thousand-Year Ginseng a full
  dantian, Rift Lotus half). Raw qi only
  fills the room left in the dantian; a qi-only herb is refused when it's full. Size
  and mutations multiply the harvest (herbs per pick), not the qi per herb.
  Buff-only herbs (Spirit Grass, Cloud Mint, Moonpetal Orchid, Purple Bamboo) give no qi.
- Current tiers: I Spirit Grass, Cloud Mint, Jade Lotus, Purple Bamboo; II Blood
  Ginseng, Moonpetal Orchid, Violet Cloud Fungus, Spirit Peach; III Nine-Leaf Lingzhi,
  Thousand-Year Ginseng, Rift Lotus. No IV or V herbs yet.
- One prompt key (F) for beds and ripe plants; G buys "Grow now" (see
  [monetization](monetization.md)).

## Key files
- `src/shared/Herbs.luau`: plant defs (tier, soil, grow time, yield, aura, eat effect,
  seed cost, sell price, mutation chain), sizes, mutations, `eatQi` (share and floor; and the qi part
  of each qi herb's blurb, built at load from them), `progress`, `growNowTier`.
- `src/shared/Items.luau`: every consumable (herbs mirrored in, spirit cores,
  treasures) and its `use`.
- `src/shared/Hotbar.luau`: nine slots of techniques and items.
- `src/server/Garden.luau`: plant/harvest/uproot, the 10 s weather tick (growth,
  swelling, mutations), wild sprouts, beast seed drops, the Herbalist
  (buy seeds, sell herbs), Grow now receipts.
- `src/server/Inventory.luau`: items as real Tools in the Backpack, `use`, hotbar
  edits, beast drops (`onKill`), `grant`.
- `src/server/Treasures.luau`: treasures that fall in the wilds in auspicious weather.
- Client: `GardenView.luau` (draws plants from the plot's `Plants` JSON, prompts,
  PlantTag), `Planting.luau` + `PlantingBar.luau` + `SeedPicker.luau` (seed packet
  tiles), `PlantTag.luau`, `HerbShop.luau`, `Inventory.luau`, `HotbarView.luau`,
  `SlotArt.luau`; `HerbArt.luau` (shared kit art: herb in an item slot, rarity gems,
  mutation ribbons, tier shields); `Herbarium.luau` (the collection book, ready to
  wire). Their look and the Herbarium's API: [herbarium](../ui/herbarium.md).
- Models: `ReplicatedStorage.GardenKit` (`assets/GardenKit.rbxmx`); plots are build
  items tagged `HerbPlot` with a `Soil` attribute.
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
- `Items.luau`: core and treasure effects, `treasureWeight`, `USE_COOLDOWN`.
- `Items.HERB_EAT_SECONDS` (1.05 s) sets the herb use cooldown and animation duration;
  `HERB_BITE_SECONDS` (0.4 s) removes the morsel. Reach/chew/return poses and
  their phase times live in `HerbAnimator.luau`.
- `Config.Garden`: seeds back, tick, aura cap, wild sprouts, beast seed drops, Grow now tiers.
- `Weather.luau` `garden`: growth speed, mutation and chance per weather.
- `Config.Economy`: starting stones; `Config.Build.MARKET_RANGE` (also how far you can walk
  before the Herbalist window closes, via `MarketRange.luau`).

## Known gaps
- Grow now product ids are placeholders (0) until the products are created.
- The Herbarium (`StarterGui.Herbarium`) is built but nothing opens it: it waits for
  herb tiers and a per-player collection record (discovered, harvested, largest,
  mutations seen); contract in [herbarium](../ui/herbarium.md).
- Herb tiers exist but aren't tied to regions yet: no tier IV-V herbs, and seeds
  don't come from their region's beasts (roadmap section 5).
- Item qi (cores, treasures) is per item, set in `Items.luau`.
