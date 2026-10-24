# Garden, herbs and items

## Purpose
A farming layer on the player's own peak: plant seeds in plots, harvest herbs to
eat (qi and timed buffs) or sell for Spirit Stones. Every plant in your plots
radiates spirit aura into your abode, which speeds meditation on your own peak
([Aura](#aura)). Plus the carried
consumables: spirit cores from beasts and heavenly treasures.

## Design intent
- Real-time growth (also offline) that rewards coming back.
- Collectible variance: each planting rolls a size (Large, Huge, Colossal);
  weather swells growing plants and gives mutations (Dewy, Thunderstruck,
  Rainbow, ...); rarer plants come from mutating seeds and from wild sprouts in
  their weather.
- **Seclusion tends the garden** ([seclusion](seclusion.md)): growing plants grow
  `Pacing.Seclusion.GROWTH` (+50%) faster while the owner is secluded, online and
  offline (`Garden.advance` settles the time away). **Staying online is what lets it
  mutate** (user, 2026-10-23: "theres a chance for ur garden to mutate if u stay
  online"): while the owner is online and on their own peak (within
  `Config.Circulation.PEAK_RADIUS` of its plateau, secluded or not), each plant
  rolls `MUTATION_PER_HOUR` (3% an hour, times garden-piece luck) for one of
  `MUTATIONS` (Dewy, Windswept, Auspicious, Golden), on the garden tick. Never offline.
- The garden feeds cultivation (aura, buffs, qi) without replacing the active loop:
  the garden-and-meditate road reaches the targets on its own, within 15% of the
  regular mixed player ([progression rules](progression-rules.md)).
- The peak score (build pieces on your peak, capped per peak tier) adds growth
  speed to all your plants during the garden tick (`Peaks.growthBonus`: up to +30%
  at the QR cap, +50% at FE; [build](build.md#peak-score-built-untuned)) and lifts the
  aura's cap (**decorate your abode**, below). The peak tier also raises how many Herb
  Beds fit (16 / 20 / 24, `Config.Build.TIERS` `limits`).
- Herb tiers I-V by region (I Common, II Spirit, III Rare, IV Treasure, V Heavenly;
  [progression](../progression.md)). A qi herb (`eat.qi = true`) gives a fixed share
  of the eater's current stage dantian by tier (`Pacing.Herbs.EAT_SHARE`: 6, 9, 12,
  16, 20%), so a herb matters at every stage but never replaces hunting. Each tier
  has a floor (`EAT_FLOOR`: 60, 150, 900, 3000, 8000 raw qi) so early herbs stay worth
  eating; **a herb below the eater's band tier gives only its floor** (`Herbs.eatQi`
  with the stage: Inner Wilds and Borderlands QC1-9 are tier I, Outer Wastes QR1-5 II,
  Deep Wilds QR6-FE3 III, Far Reaches FE4-9 IV), so fast low-tier herbs stop scaling
  once you outgrow them and each band's own tier is the garden's qi. Event herbs use a
  bigger share at any stage (`PRIZE`: Thousand-Year Ginseng a full dantian, Rift Lotus
  half). Raw qi only
  fills the room left in the dantian; a qi-only herb is refused when it's full. Size
  and mutations multiply the harvest (herbs per pick), not the qi per herb.
  Buff-only herbs (Spirit Grass, Cloud Mint, Moonpetal Orchid, Purple Bamboo) give no qi.
- **Buffs stack with falloff** (rebalance 2026-10-24; owner: strongest-only was "kinda
  boring"): QiRate buffs from different herbs and items count the strongest whole, the
  second half, the third a quarter, the rest nothing (`Pacing.Herbs.BUFF_FALLOFF`), up
  to `BUFF_CAP` by your major (QC 0.2, QR 0.3, FE 0.5). Each herb's own QiRate is at
  most its band's cap (tier I +5-15%, II +15-25%, III +20-30%, IV +35-45%, V +50%),
  so the blurb never promises more than a single herb gives. Eating the same herb
  again refreshes its timer.
- **The Herbalist** (Spirit Market) sells seeds by tier with a daily stock per herb
  and player (`Pacing.Herbs.STOCK`: 30 / 12 / 3 / 2 a UTC day for tiers I-IV, saved as
  `data.herbalist`): tier I-II from the start, the Epic tier III seeds (Seven-Star
  Grass 400, Emberheart Fruit 600) from QR6 and Starfall Bamboo (tier IV, 1200) from FE4
  (`soldFrom`, the band's first stage). The window lists only what's sold at your realm,
  with "N left today". Legendary herbs are never sold.
- **The herbs by tier** (22; `Herbs.Order` is this order, which is also the
  Herbarium's pages). Region is where its seeds drop (below); "shop" is sold by the
  Herbalist, "mut" comes from a lower herb's harvest (`mutatesTo`).

  | Tier | Herb | Soil | Rarity | Grow | Region | Seeds from | Eat (on top of the tier's qi share) |
  |---|---|---|---|---|---|---|---|
  | I | Spirit Grass | bed | Common | 2 min | Inner Wilds | shop, beasts | buff only: +10% cultivation 3 min |
  | I | Cloud Mint | bed | Uncommon | 5 min | Inner Wilds | shop, beasts, mut | buff only: +6 speed, +5% 2 min |
  | I | Jade Lotus | pond | Uncommon | 8 min | Inner Wilds | shop, beasts | +15% 3 min |
  | I | Ghostlamp Lily | pond | Uncommon | 12 min | Ruined Borderlands | beasts | +10% 3 min |
  | I | Purple Bamboo | grove | Uncommon | 10 min (regrows 4) | Inner Wilds | shop, beasts | buff only: +4 speed 3 min |
  | II | Blood Ginseng | bed | Rare | 15 min | Outer Wastes | shop, beasts, mut | qi only |
  | II | Moonpetal Orchid | bed | Epic | 30 min | Outer Wastes | mut | buff only: +25% 10 min |
  | II | Violet Cloud Fungus | bed | Epic | 20 min | Outer Wastes | wild (Auspicious Mist) | +15% 5 min |
  | II | Duskwind Thistle | bed | Rare | 25 min | Outer Wastes | beasts | +5 speed 3 min |
  | II | Spirit Peach | grove | Rare | 40 min (regrows 10) | Outer Wastes | shop, beasts | +15% 5 min |
  | III | Seven-Star Grass | bed | Epic | 1.5 h | Deep Wilds | shop (QR6+), beasts, mut | +25% 10 min |
  | III | Nine-Leaf Lingzhi | bed | Legendary | 2 h | Deep Wilds | mut, Deep Wilds bosses | +30% 15 min |
  | III | Thousand-Year Ginseng | bed | Legendary | 4 h | Deep Wilds | world event | a full dantian (PRIZE), +30% 20 min |
  | III | Rift Lotus | pond | Legendary | 1 h | Deep Wilds | wild (Heaven Split), mut | half a dantian (PRIZE), +30% 15 min |
  | III | Emberheart Fruit | grove | Epic | 2 h (regrows 45 min) | Deep Wilds | shop (QR6+), beasts, mut | +20% 10 min |
  | IV | Dragonblood Vine | bed | Legendary | 4 h | Far Reaches | beasts, mut | +40% 20 min |
  | IV | Phoenix Plume Orchid | bed | Legendary | 6 h | Far Reaches | beasts | +45% 20 min |
  | IV | Snowpeak Lotus | pond | Legendary | 3 h | Far Reaches | beasts, mut | +35% 15 min |
  | IV | Starfall Bamboo | grove | Epic | 4 h (regrows 1 h) | Far Reaches | shop (FE4+), beasts, mut | +8 speed 5 min |
  | V | Tribulation Thunder Grass | bed | Legendary | 8 h | Far Reaches | Far Reaches bosses, mut | +50% 20 min |
  | V | Ninefold Heaven Lotus | pond | Legendary | 12 h | Far Reaches | Far Reaches bosses, mut | +50% 30 min |
  | V | Dao Origin Fruit | grove | Legendary | 24 h (regrows 6 h) | Far Reaches | Far Reaches bosses, mut | +50% 30 min |

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

## Aura
The air of your spirit abode (rebalance 2026-10-24; owner: "a legendary plant in your
garden should noticeably speed you up", and "I want players to be incentivized to
decorate their spirit abodes").
- **Every planted herb counts** (`Cultivation.aura`): its aura is `Pacing.Aura.BY_TIER`
  (I 0.02, II 0.05, III 0.15, IV 0.3, V 0.6) x `RARITY` (Common 1, Uncommon 1.1, Rare
  1.25, Epic 1.5, Legendary 2) x its size x its mutations (`Herbs.aura`,
  `Herbs.multiplier`), `GROWING` (half) of that while it grows and all of it once
  mature. Summed over every plant in every plot, so a fuller, rarer garden is always
  more, until the cap. Herbs carry no `aura` field of their own any more.
- **Capped by your peak tier** (`CAP`: QC 0.3, QR 0.6, FE 1.0).
- **It multiplies meditation on your own peak only** (`Cultivation.rate`: x (1 + aura)
  while `Meditation.spot` says `own`), never hunting or meditating elsewhere.
- **Decorate your abode:** the peak score lifts the cap by up to `DECOR` (25%) of it at
  the tier's score cap (`Peaks.decorShare` = score / scoreCap, passed in the spot):
  QC 0.3 -> 0.375, QR 0.6 -> 0.75, FE 1.0 -> 1.25. Building also adds the score's own
  meditation (`Pacing.PeakScore.MEDITATION` 0.0024 a point) and growth.
- Examples: one mature Legendary tier III herb (Nine-Leaf Lingzhi) is +0.3, the whole QC
  cap; a Legendary tier IV (Phoenix Plume Orchid) +0.6, the whole QR cap; a bed of tier
  III-IV herbs fills the FE cap. A Huge or Thunderstruck plant is several plants' worth.
- The model's sizes: a regular's garden sits at about 0.13 (QC), 0.4-0.6 (QR) and
  1.0-1.2 (FE); a natural gardener at the cap from QC5. Turning the aura off alone
  slows a regular or heavy by 7-9% ([pacing model](pacing-model.md)): a real but
  modest reward, and it is the garden road's main way to keep pace on the seat.

## Key files
- `src/shared/Herbs.luau`: plant defs (tier, region, soil, grow time, yield, eat
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
  the testbed has an empty folder) and, for the 11 herbs added 2026-10-23,
  `ReplicatedStorage.HerbModelsExtra.<model>` (`assets/HerbModelsExtra.rbxm`, mapped
  in both projects, so these do draw in the testbed). A def's `model` defaults to its
  id; `Herbs.template` looks in HerbModels, then HerbModelsExtra, and a herb with
  neither draws its `standIn` (an existing HerbModels model of the same soil) tinted
  55% to its colour (`Herbs.clone`).
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
every plant (mature in full, growing at half) when the rate is read. Harvest grants herbs (and sometimes seeds); eating goes
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
  `EAT_FLOOR` (the least raw qi, by tier), `PRIZE` (event herbs' share, by id),
  `BUFF_FALLOFF` and `BUFF_CAP` (QiRate stacking), `STOCK` (the Herbalist's daily seeds).
- `Pacing.Aura`: `BY_TIER`, `RARITY`, `CAP` by major, `GROWING`, `DECOR`.
- `Herbs.Regions`: each region's beast seed pool and boss additions (weights).
- `Pacing.Herbarium`: `DISCOVER` and `TIER` stone rewards.
- `Items.luau`: core and treasure effects, `treasureWeight`, `USE_COOLDOWN`.
- `Items.HERB_EAT_SECONDS` (1.05 s) sets the herb use cooldown and animation duration;
  `HERB_BITE_SECONDS` (0.4 s) removes the morsel. Reach/chew/return poses and
  their phase times live in `HerbAnimator.luau`.
- `Config.Garden`: seeds back, tick, wild sprouts, beast seed chance and boss count, Grow now tiers.
- `Weather.luau` `garden`: growth speed, mutation and chance per weather.
- `Pacing.Seclusion`: `GROWTH` (tending while secluded), `MUTATION_PER_HOUR`, `MUTATIONS` (the online roll on your own peak).
- `Pacing.PeakScore.GROWTH` per peak-score point; Herb Bed caps per tier in `Config.Build.TIERS`.
- `Config.Economy`: starting stones; `Config.Build.MARKET_RANGE` (also how far you can walk
  before the Herbalist window closes, via `MarketRange.luau`).

## Known gaps
- Grow now product ids are placeholders (0) until the products are created.
- The 11 herbs added 2026-10-23 (Ghostlamp Lily to Dao Origin Fruit) have only
  light-pass part models (below) and glyphs, no icons.
- Deep Wilds and the Far Reaches aren't map regions yet; their seeds drop only by
  realm (an elite or apex beast anywhere off the seed regions, or the testbed).
- Tier IV-V numbers (grow times, sell prices) are first guesses. Tier III-V sell
  prices (260-9000 a herb) flood stones once a garden of them stands; stones buy no
  speed past the score and plot caps, so it's flagged, not fixed
  ([progression rules](progression-rules.md)).
- Foundation's Home hint suggests the next herb tier to harvest even when that tier
  belongs to a far later realm.

## Herb models (light pass) and needs art pass
The 11 herbs below have cheap Roblox-part models in `ReplicatedStorage.HerbModelsExtra`,
built by `art/herbs_extra/build_herb_item_models.luau` (re-run it in a sandbox, then
export the folder with `tools/export_rbxm.luau` to `assets/HerbModelsExtra.rbxm`).
Each is a Model named by the id, mature size at scale 1 (plants are drawn at
`SPROUT_SCALE` and scaled up as they grow), identity-rotation WorldPivot at the stem's
ground point (the water surface for pond herbs), PrimaryPart nil, anchored, no
collision; plain SmoothPlastic with Neon only on the glowing parts. Each one has the
attributes `NeedsArtPass = true` and an `ArtPassReason`.

**Needs art pass** (all 11; the Look column is the target): proper modelled
petals/leaves/vines in Blender where parts fall short, and the glow, mist, motes and
crackle as vfx. Reasons per herb: the `ArtPassReason` attribute, also in the
builder's `HERB_REASON`. A finished model can go into `HerbModels` under the same
name (it wins over the extra one) or replace the one in `HerbModelsExtra`.

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
