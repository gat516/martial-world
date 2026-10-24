# Item models

3D models of the consumables in `src/shared/Items.luau`, for loot drops, pickups and
eating/absorbing effects. **Nothing uses them yet**; they are ready for the code that
drops or shows an item in the world.

## Where
- `ReplicatedStorage.ItemModels.<ItemId>` (`assets/ItemModels.rbxm`, mapped in
  `default.project.json` and `test.project.json`).
- Built by `art/herbs_extra/build_herb_item_models.luau` (the same builder as the
  light-pass herbs); re-run it in a sandbox and export the folder with
  `tools/export_rbxm.luau`.

## Contract
- A Model named by the item id; WorldPivot is the identity at the bottom centre, so
  `model:PivotTo(CFrame.new(spot) * template:GetPivot().Rotation)` sets it on the
  ground. PrimaryPart nil.
- Parts are anchored, CanCollide/CanTouch off. A drop that should fall or bounce must
  weld them and unanchor itself.
- Sizes: pills about 0.45, cores 0.6-0.75, dew, jade and peach 0.6-0.8. Scale up with
  `Model:ScaleTo` for a showcase (ellipsoids are Sphere SpecialMeshes that follow
  their part's size, so ScaleTo works).

| Id | Model |
|---|---|
| MarrowWashingPill | gold glossy pill, amber band, faint glow shell |
| RootRebirthPill | violet pill, pale band, two small leaves on top |
| LesserSpiritCore | teal faceted gem on its point, glowing heart |
| GreaterSpiritCore | red gem flanked by two leaning shards (a cluster, so it never reads as the lesser one) |
| HeavenlyDew | pale blue translucent droplet with a bright heart |
| CloudPatternJade | jade bi disc on edge, dark centre, two cloud curls a side |
| ImmortalPeach | pink peach with a blush top, crease and two leaves |
| TemperingPill | **not built yet**: the Marrow pill recoloured earth-brown (builder entry only) |
| ClearHeartPill | **not built yet**: the Marrow pill recoloured pale water-blue (builder entry only) |

The Foundation Tempering and Clear Heart Pills (2026-10-24) were added to the builder in
code only: re-run it in a sandbox and export `ReplicatedStorage.ItemModels` to put them
in `assets/ItemModels.rbxm`.

## Needs art pass
All are a light pass in Roblox parts. Each carries `NeedsArtPass = true` and an
`ArtPassReason` (also in the builder's `ITEM_REASON`): moulded pill meshes with their
icon's pattern (spiral, taiji), cut-gem cores with an inner pulse, a pierced bi disc
with carved clouds, a droplet mesh, and glow/shimmer vfx.
