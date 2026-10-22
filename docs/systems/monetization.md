# Monetization and receipts

## Purpose
Robux developer products, processed safely through one receipt handler.

## Design intent
- Optional convenience, never power: **Grow now** finishes one growing plant
  (price tiers by time left: 3, 6, 9 Robux); **Change Race** and **Change Last
  Name** reroll the race or family name on the character screen
  ([character creator](character-creator.md)).
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
- `src/shared/CharacterCreator/Products.luau`: reroll product ids and the price
  the buttons show. An id of 0 is mock mode (free, Studio and testbed only).
- `Config.Garden.GROW_NOW`: tiers (`upTo` seconds, `robux`, `productId`).

## Known gaps
- The reroll products aren't created yet (ids 0). A granted reroll isn't saved
  (no DataStore field yet), so it's lost on rejoin; see
  [character creator](character-creator.md).
- The three product ids are placeholders (0): create the products in the Creator
  Dashboard and paste the ids; until then the prompt shows but only warns.
