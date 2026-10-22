#!/usr/bin/env python3
"""Publish animation clips to Roblox through Open Cloud and print their ids.

    python3 tools/upload_animation.py path/to/Clip.rbxm [...]

Each file is a binary .rbxm whose root is one KeyframeSequence. To split a
folder of clips: `rojo build` it to .rbxmx, cut each KeyframeSequence into its
own <roblox> file, and `rojo build` each back to .rbxm (from the repo root, so
rokit finds rojo); art/player/guard/clips/ was made this way.

Clips are owned by the group that owns the main game (GROUP_ID), and the
testbed's universe is granted Use on them, so they play in both places.

The key is read from ~/.config/roblox/api_key (Assets API read+write and
asset-permissions write). It never goes in the repo, a command line or output.
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


def call(method: str, url: str, key: str, body: bytes | None = None, ctype: str | None = None) -> dict:
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key})
    if ctype:
        req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read() or b"{}")
    except urllib.error.HTTPError as err:
        sys.exit(f"{method} {url} -> {err.code}: {err.read().decode(errors='replace')[:400]}")


def upload(path: pathlib.Path, key: str) -> str:
    request = {
        "assetType": "Animation",
        "displayName": path.stem,
        "description": "Martial World animation",
        "creationContext": {"creator": {"groupId": GROUP_ID}},
    }
    boundary = uuid.uuid4().hex
    body = b"".join([
        f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n'.encode(),
        json.dumps(request).encode(),
        f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\nContent-Type: model/x-rbxm\r\n\r\n'.encode(),
        path.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode(),
    ])
    op = call("POST", f"{ASSETS}/assets", key, body, f"multipart/form-data; boundary={boundary}")
    for _ in range(30):
        if op.get("done"):
            break
        time.sleep(1)
        op = call("GET", f"{ASSETS}/{op['path']}", key)
    asset = (op.get("response") or {}).get("assetId")
    if not asset:
        sys.exit(f"{path.name}: upload didn't finish: {json.dumps(op)[:400]}")
    return asset


def grant_testbed(ids: list[str], key: str):
    body = json.dumps({
        "subjectType": "Universe",
        "subjectId": TESTBED_UNIVERSE,
        "action": "Use",
        "requests": [{"assetId": i} for i in ids],
    }).encode()
    call("PATCH", "https://apis.roblox.com/asset-permissions-api/v1/assets/permissions", key, body, "application/json")


def main():
    files = [pathlib.Path(a) for a in sys.argv[1:]]
    if not files:
        sys.exit(__doc__)
    key = KEY_FILE.read_text().strip()
    ids = []
    for path in files:
        asset = upload(path, key)
        ids.append(asset)
        print(f"{path.stem}\trbxassetid://{asset}")
    grant_testbed(ids, key)
    print(f"granted testbed universe {TESTBED_UNIVERSE} Use on {len(ids)} clip(s)")


if __name__ == "__main__":
    main()
