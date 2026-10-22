# Guard sound effects

Short one-shot cues for `src/client/GuardController.luau`, mapped as Sounds
under `SoundService.SFX` by `assets/SoundGroups/SFX.rbxmx`. They play flat for
the defending player through `src/client/Sfx.luau`; the Settings SFX slider
scales them. Volume below is the Sound template's first-pass value.

| Cue | Source file in Kenney pack | Roblox audio ID | Volume |
|---|---|---|---:|
| GuardRaise | RPG Audio `Audio/cloth1.ogg` | `rbxassetid://126422687387943` | 0.28 |
| Parry | Impact Sounds `Audio/impactMetal_medium_000.ogg` | `rbxassetid://84338662037070` | 0.8 |
| Block | Impact Sounds `Audio/impactPlate_medium_000.ogg` | `rbxassetid://74105007560914` | 0.5 |
| GuardBreak | Impact Sounds `Audio/impactGlass_heavy_000.ogg` | `rbxassetid://91638768113300` | 0.8 |

Sources: [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio) and
[Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds). Both packs are
Creative Commons Zero (CC0). The `.ogg` files here are unchanged copies of
those pack members. Published with `python3 tools/upload_asset.py audio
art/sfx/guard/*.ogg` to group 772472600; the uploader granted testbed universe
10772308282 Use on all four assets.

The four levels and the balance against weapon hits and music still need a
player playtest.
