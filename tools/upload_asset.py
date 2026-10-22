#!/usr/bin/env python3
"""Publish assets to Roblox through Open Cloud and print their ids.

    python3 tools/upload_asset.py animation art/player/guard/clips/*.rbxm
    python3 tools/upload_asset.py audio art/sfx/Parry.ogg [...]
    python3 tools/upload_asset.py model art/props/Lantern.fbx [...]

  animation  .rbxm whose root is one KeyframeSequence. To split a folder of
             clips: `rojo build` it to .rbxmx, cut each KeyframeSequence into
             its own <roblox> file, and `rojo build` each back to .rbxm (from
             the repo root, so rokit finds rojo); see art/player/guard/clips/.
  audio      .mp3 .ogg .wav .flac (sound effects, music, ambience)
  model      .fbx .gltf .glb .rbxm .rbxmx (a Model asset, for InsertService
             or the Toolbox; the Studio import pipeline stays the default)

Images (UI art, textures) keep going through the Studio MCP's upload_image:
it returns the image id an ImageLabel or emitter needs, where Open Cloud
returns a Decal.

Assets are owned by the group that owns the main game (GROUP_ID). Animations
and audio are private to their owner, so the testbed's universe is granted Use
on them and they play in both places.

The key is read from ~/.config/roblox/api_key (Assets API read+write and
asset-permissions write). Never read, print, copy or commit it; this script is
the only thing that touches it.
"""

import json
import pathlib
import sys
import time
import urllib.error
import urllib.request
import uuid

GROUP_ID = "772472600"  # owns the main game (place 90657469522375)
TESTBED_UNIVERSE = "10772308282"  # Martial World Test, owned by the user
KEY_FILE = pathlib.Path.home() / ".config/roblox/api_key"
ASSETS = "https://apis.roblox.com/assets/v1"

TYPES = {
    "animation": ("Animation", {".rbxm": "model/x-rbxm"}, True),
    "audio": ("Audio", {".mp3": "audio/mpeg", ".ogg": "audio/ogg", ".wav": "audio/wav", ".flac": "audio/flac"}, True),
    "model": ("Model", {".fbx": "model/fbx", ".gltf": "model/gltf+json", ".glb": "model/gltf-binary",
                        ".rbxm": "model/x-rbxm", ".rbxmx": "model/x-rbxmx"}, False),
}


class Failed(Exception):
    pass


def call(method: str, url: str, key: str, body: bytes | None = None, ctype: str | None = None) -> dict:
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key})
    if ctype:
        req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read() or b"{}")
    except urllib.error.HTTPError as err:
        raise Failed(f"{method} {url} -> {err.code}: {err.read().decode(errors='replace')[:400]}")


def upload(path: pathlib.Path, asset_type: str, content_type: str, key: str) -> str:
    request = {
        "assetType": asset_type,
        "displayName": path.stem,
        "description": "Martial World",
        "creationContext": {"creator": {"groupId": GROUP_ID}},
    }
    boundary = uuid.uuid4().hex
    body = b"".join([
        f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n'.encode(),
        json.dumps(request).encode(),
        f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\nContent-Type: {content_type}\r\n\r\n'.encode(),
        path.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode(),
    ])
    op = call("POST", f"{ASSETS}/assets", key, body, f"multipart/form-data; boundary={boundary}")
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(1)
        op = call("GET", f"{ASSETS}/{op['path']}", key)
    asset = (op.get("response") or {}).get("assetId")
    if not asset:
        raise Failed(f"didn't finish (moderation can take longer): {json.dumps(op)[:400]}")
    return asset


def grant_testbed(ids: list[str], key: str):
    body = json.dumps({
        "subjectType": "Universe",
        "subjectId": TESTBED_UNIVERSE,
        "action": "Use",
        "requests": [{"assetId": i} for i in ids],
    }).encode()
    result = call("PATCH", "https://apis.roblox.com/asset-permissions-api/v1/assets/permissions", key, body, "application/json")
    for error in result.get("errors") or []:
        print(f"testbed grant failed: {error}", file=sys.stderr)


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in TYPES:
        sys.exit(__doc__)
    asset_type, content_types, grant = TYPES[sys.argv[1]]
    files = [pathlib.Path(a) for a in sys.argv[2:]]
    for path in files:
        if path.suffix.lower() not in content_types:
            sys.exit(f"{path}: a {sys.argv[1]} must be one of {', '.join(content_types)}")
    key = KEY_FILE.read_text().strip()
    ids, failed = [], 0
    for path in files:
        try:
            asset = upload(path, asset_type, content_types[path.suffix.lower()], key)
        except Failed as err:
            failed += 1
            print(f"{path.name}: {err}", file=sys.stderr)
            continue
        ids.append(asset)
        print(f"{path.stem}\trbxassetid://{asset}")
    if grant and ids:
        try:
            grant_testbed(ids, key)
            print(f"granted testbed universe {TESTBED_UNIVERSE} Use on {len(ids)} asset(s)")
        except Failed as err:
            print(f"testbed grant failed: {err}", file=sys.stderr)
            failed += 1
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
