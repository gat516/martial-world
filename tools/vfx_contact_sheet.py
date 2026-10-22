"""Contact sheets of vfxia Asset Library thumbnails, labelled with their ids, so
looks can be judged in one image instead of one asset at a time.

  uv run --with pillow python3 -I tools/vfx_contact_sheet.py OUT_DIR NAME KEYWORDS [KIND] [MAX]
    KEYWORDS  comma list matched against tools/vfx_library.json keywords
              (e.g. shockwave,ring,wave), or ids:ID;ID;... for explicit ids
              (live-search results, meshes, flipbooks)
    KIND      image (default), mesh, flipbook, sound
  -> OUT_DIR/NAME_0.png, NAME_1.png ... (60 per sheet, 10 columns), then Read them.
  --size 420 (anywhere in the args): big 420 px tiles, 16 per sheet, to read a
              flipbook's grid (2x2, 4x4...) or a texture's fine detail.

Layer mode (one call, one sheet per layer, from a live search dump):
  uv run --with pillow python3 -I tools/vfx_contact_sheet.py OUT_DIR layers PLAN.json DUMP.json [--size 420]
    PLAN.json  {"<layer>": ["cause word", ...], ...}: the words each layer's
               cause makes (air, dust, debris, light ...), written fresh per effect
    DUMP.json  the live search results for those words, written by
               _G.vfxLibrary.dump(words, "<name>") (tools/vfx_library.luau) to
               tools/frag/<name>.xml; sounds are listed per layer as text
  -> OUT_DIR/<layer>_0.png ..., every kind (image, flipbook, mesh) on the
     layer's sheet, deduped within the layer.

Raw thumbnails are cached in ~/.cache/vfx_thumbs (images only; nothing records
which assets were picked) and downloaded 16 at a time. Dark-grey background so white-on-
transparent textures show; a solid black tile means the image has an opaque
black background (avoid unless it's meant for additive use).
"""

import io
import json
import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

from PIL import Image, ImageDraw

LIB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vfx_library.json")
THUMBS = "https://thumbnails.roblox.com/v1/assets?assetIds={}&size={}x{}&format=Png"


def main():
    args = sys.argv[1:]
    big = "--size" in args and args[args.index("--size") + 1] == "420"
    if "--size" in args:
        i = args.index("--size")
        del args[i:i + 2]
    if len(args) > 1 and args[1] == "layers":
        return layers(args[0], args[2], args[3], big)
    out_dir, name, query = args[0], args[1], args[2]
    kind = args[3] if len(args) > 3 else "image"
    limit = int(args[4]) if len(args) > 4 else 200
    px = 420 if big else 150
    if query.startswith("ids:"):
        ids = [i for i in query[4:].split(";") if i]
    else:
        words = set(query.split(","))
        lib = json.load(open(LIB))
        ids = [a["id"] for a in lib["assets"] if a["kind"] == kind and words & set(a.get("keywords", []))][:limit]
    for path in render(ids, out_dir, name, big):
        print(path)


def fetch(ids, big):
    """Download missing thumbnails (16 at a time) into the shared raw cache."""
    px = 420 if big else 150
    cache = os.path.expanduser("~/.cache/vfx_thumbs/" + ("420" if big else "150"))
    os.makedirs(cache, exist_ok=True)
    need = [i for i in ids if not os.path.exists(os.path.join(cache, i + ".png"))]
    urls = []
    for k in range(0, len(need), 100):
        data = json.load(urllib.request.urlopen(THUMBS.format(",".join(need[k:k + 100]), px, px)))
        urls += [(str(e["targetId"]), e["imageUrl"]) for e in data.get("data", []) if e.get("imageUrl")]

    def get(item):
        aid, url = item
        try:
            png = urllib.request.urlopen(url, timeout=20).read()
            open(os.path.join(cache, aid + ".png"), "wb").write(png)
        except Exception as ex:  # a thumbnail still pending or blocked
            print("skip", aid, ex)

    with ThreadPoolExecutor(16) as pool:
        list(pool.map(get, urls))
    return cache


def render(ids, out_dir, name, big):
    os.makedirs(out_dir, exist_ok=True)
    cache = fetch(ids, big)
    tile, cols, per = (420, 4, 16) if big else (110, 10, 60)
    out = []
    for page in range(0, len(ids), per):
        chunk = ids[page:page + per]
        rows = (len(chunk) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * tile, rows * (tile + 14)), (60, 64, 72))
        draw = ImageDraw.Draw(sheet)
        for i, aid in enumerate(chunk):
            x, y = (i % cols) * tile, (i // cols) * (tile + 14)
            path = os.path.join(cache, aid + ".png")
            if os.path.exists(path):
                im = Image.open(path).convert("RGBA").resize((tile - 6, tile - 6))
                bg = Image.new("RGBA", im.size, (60, 64, 72, 255))
                bg.alpha_composite(im)
                sheet.paste(bg.convert("RGB"), (x + 3, y + 3))
            draw.text((x + 2, y + tile - 2), aid, fill=(255, 255, 0))
        path = os.path.join(out_dir, f"{name}_{page // per}.png")
        sheet.save(path)
        out.append(f"{path} {len(chunk)}")
    return out


def layers(out_dir, plan_path, dump_path, big):
    plan = json.load(open(plan_path))
    dump = json.load(open(dump_path))
    for layer, words in plan.items():
        ids, sounds = [], []
        for w in words:
            for a in dump.get(w, []):
                if a["kind"] == "sound":
                    entry = f"{a['id']} {a.get('name', '')}"
                    if entry not in sounds:
                        sounds.append(entry)
                elif a["id"] not in ids:
                    ids.append(a["id"])
        print(f"== {layer} ({', '.join(words)}): {len(ids)} visuals")
        for path in render(ids, out_dir, layer, big):
            print(path)
        if sounds:
            print("  sounds: " + "; ".join(sounds))


if __name__ == "__main__":
    main()
