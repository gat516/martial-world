# Monetization and receipts

## Purpose
Robux developer products, processed safely through one receipt handler.

## Design intent
- Optional convenience, never power: today the only product is **Grow now**,
  which finishes one growing plant. Price tiers by time left (3, 6, 9 Robux).
- A replayed receipt never pays twice: granted PurchaseIds are saved in the
  profile before Roblox hears PurchaseGranted.

## Key files
- `src/server/Receipts.luau`: the single `MarketplaceService.ProcessReceipt`;
  features call `Receipts.register(productId, handler)`.
- `src/server/Garden.luau`: `growTarget` (the client picks a plant, the server
  remembers it and returns the tier's product id) and the `growNow` handler.
- `src/shared/Herbs.luau` `growNowTier`, `src/shared/Config.luau` `Garden.GROW_NOW`.
- `src/client/GardenView.luau`: the "Grow now (N R$)" prompt on G.

## Data flow
G on a plant -> `GardenAction("growTarget")` -> client prompts the product ->
`ProcessReceipt` -> handler finishes the target plant (or grants as is if it
ripened meanwhile) -> profile saved with the PurchaseId -> PurchaseGranted.

## Tuning knobs
- `Config.Garden.GROW_NOW`: tiers (`upTo` seconds, `robux`, `productId`).

## Known gaps
- The three product ids are placeholders (0): create the products in the Creator
  Dashboard and paste the ids; until then the prompt shows but only warns.
