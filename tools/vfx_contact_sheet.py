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

Thumbnails are cached in OUT_DIR/thumbs. Dark-grey background so white-on-
transparent textures show; a solid black tile means the image has an opaque
black background (avoid unless it's meant for additive use).
"""

import io
import json
import os
import sys
import urllib.request

from PIL import Image, ImageDraw

LIB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vfx_library.json")
THUMBS = "https://thumbnails.roblox.com/v1/assets?assetIds={}&size={}x{}&format=Png"


def main():
    args = sys.argv[1:]
    big = "--size" in args and args[args.index("--size") + 1] == "420"
    if "--size" in args:
        i = args.index("--size")
        del args[i:i + 2]
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
    cache = os.path.join(out_dir, "thumbs" if not big else "thumbs420")
    os.makedirs(cache, exist_ok=True)
    need = [i for i in ids if not os.path.exists(os.path.join(cache, i + ".png"))]
    for k in range(0, len(need), 100):
        data = json.load(urllib.request.urlopen(THUMBS.format(",".join(need[k:k + 100]), px, px)))
        for entry in data.get("data", []):
            if entry.get("imageUrl"):
                try:
                    png = urllib.request.urlopen(entry["imageUrl"]).read()
                    open(os.path.join(cache, str(entry["targetId"]) + ".png"), "wb").write(png)
                except Exception as ex:  # a thumbnail still pending or blocked
                    print("skip", entry["targetId"], ex)
    tile, cols, per = (420, 4, 16) if big else (110, 10, 60)
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
        print(path, len(chunk))


if __name__ == "__main__":
    main()
