---
name: upload-asset
description: Publishing your own assets to Roblox and recording the ids - animations, audio and models through tools/upload_asset.py (Open Cloud, owned by the game's group, testbed granted Use), images and textures through the Studio MCP's upload_image from a loopback server, and swapping ids after a re-upload. Use whenever something needs an rbxassetid.
user-invocable: false
---

# Uploading to Roblox

Publish your own assets. Never ask the user to upload or publish anything.

The Open Cloud key is in `~/.config/roblox/api_key`. Never read, print, copy or
commit it. Only `tools/upload_asset.py` touches it.

## Animations, audio, models: `tools/upload_asset.py`

```bash
python3 tools/upload_asset.py animation art/player/guard/clips/*.rbxm
python3 tools/upload_asset.py audio art/sfx/Parry.ogg
python3 tools/upload_asset.py model art/props/Lantern.fbx
```

- **animation:** a binary `.rbxm` whose root is one KeyframeSequence. Export
  each clip on its own (`_G.exportRbxm`, the `studio-export` skill). To split a
  folder of clips, see the script's docstring.
- **audio:** `.mp3 .ogg .wav .flac`.
- **model:** `.fbx .gltf .glb .rbxm .rbxmx`. Use it only for an asset that should
  exist on Roblox (InsertService, the Toolbox). Meshes still come in through the
  Studio import pipeline (the `mesh-pipeline` skill).

Assets are owned by the main game's group (772472600), and the testbed universe
is granted Use on animations and audio. The script prints `rbxassetid://` ids.

## Images: the MCP's `upload_image`

Use this for UI art and emitter textures. Open Cloud would return a Decal, not
an image id.
1. `upload_image` takes only http(s) URLs. Serve the folder on loopback, time
   limited, in the background:
   `cd <folder> && timeout 120 python3 -m http.server 8765 --bind 127.0.0.1`
   If 8765 is busy, pick another free port.
2. Call `upload_image` with `http://127.0.0.1:<port>/<file>.png`. Several files
   fit in one call.
3. A new upload takes a few seconds to render. `ContentProvider:PreloadAsync` or
   the image's `IsLoaded` tells you when it has.

## Record the ids

Put each id where the asset lives:
- the `Animation` or `Sound` instance (a property-only edit straight into the
  `.rbxmx` is fine)
- `art/ui/assets.json` for UI images
- the art folder's `README.md` for anything else

## Re-uploads

Asset ids are immutable, so a changed file needs a new upload. Swap the old id
for the new one everywhere: `grep -rn <old id> assets/ src/ art/`. Parallel work
may still hold the old id, so after a merge, grep again.
