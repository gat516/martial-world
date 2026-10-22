# Guard sound effects

Short one-shot cues for `src/client/GuardController.luau`, mapped as Sounds
under `SoundService.SFX` by `assets/SoundGroups/SFX.rbxmx`. They play flat for
the defending player through `src/client/Sfx.luau`; the Settings SFX slider
scales them. Volume below is the Sound template's first-pass value.

| Cue | Sound | Roblox audio ID | Volume |
|---|---|---|---:|
| GuardRaise | Kenney RPG Audio `Audio/cloth1.ogg` | `rbxassetid://126422687387943` | 0.28 |
| Parry | User choice: parry against something sharp, like claws or a weapon | `rbxassetid://127555742263594` | 0.8 |
| Block | User choice: guarding against something successfully | `rbxassetid://5763723309` | 0.5 |
| GuardBreak | Kenney Impact Sounds `Audio/impactGlass_heavy_000.ogg` | `rbxassetid://91638768113300` | 0.8 |

Reserved user choices are recorded directly in `assets/SoundGroups/SFX.rbxmx`
for the agent that later routes parries by enemy attack:

| Roblox audio ID | Intended hit |
|---|---|
| `rbxassetid://137580087669661` | Another sharp-parry variant |
| `rbxassetid://137083228478857` | Magic or projectile parry |
| `rbxassetid://111913931670052` | BIG-attack parry |

`GuardController` still plays the single `Parry` template for every perfect
parry. The Kenney `Parry.ogg` and `Block.ogg` files in this folder, previously
published as `rbxassetid://84338662037070` and `rbxassetid://74105007560914`,
remain as alternative clips but are no longer the active templates.

Sources for the local `.ogg` files: [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio)
and [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds). Both packs
are Creative Commons Zero (CC0). The files here are unchanged copies of those
pack members. They were published with `python3 tools/upload_asset.py audio
art/sfx/guard/*.ogg` to group 772472600; the uploader granted testbed universe
10772308282 Use on those four Kenney assets. The five user-provided ids above
were supplied after that upload.

The current levels and balance against weapon hits and music still need a
player playtest.
