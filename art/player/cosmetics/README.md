# Player cosmetics

`assets/Cosmetics.rbxm` (binary) is the folder `ServerStorage.Cosmetics`, mapped in
both project files. Each child is an Accessory template that races, variants and
traits name in their `Cosmetics` lists (`docs/systems/identity.md`, Cosmetics);
`Traits.applyBody` clones them onto the character with `humanoid:AddAccessory`.

| Accessory | Attaches to (R6) | Worn by |
| --- | --- | --- |
| `FoxTailPlume`, `FoxEarsSleek` | Torso.WaistBackAttachment, Head.HatAttachment | Spirit Fox, Plume |
| `FoxTailCrescent`, `FoxEarsBroad` | same | Spirit Fox, Crescent |
| `FoxTailWisp`, `FoxEarsLong` | same | Spirit Fox, Wisp |

The fox sets are skinned Blender meshes with bones: model, rig, colours and the
Studio build are in [`fox/README.md`](fox/README.md).

## Adding a cosmetic

Build the Accessory in a sandbox (unmapped there), keep the Handle at the
attachment point with identity rotation, make every part Massless with
CanCollide, CanQuery and CanTouch off, then export the folder with
`tools/export_rbxm.luau` (`_G.exportRbxm("ServerStorage.Cosmetics")`) to
`assets/Cosmetics.rbxm`. In a Rojo-connected place, build in an unmapped staging
copy, as AGENTS.md describes.
