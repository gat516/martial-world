"""Contact sheets of vfxia Asset Library thumbnails, labelled with their ids, so
looks can be judged in one image instead of one asset at a time.

  uv run --with pillow python3 -I tools/vfx_contact_sheet.py OUT_DIR NAME KEYWORDS [KIND] [MAX]
    KEYWORDS  comma list matched against tools/vfx_library.json keywords
              (e.g. shockwave,ring,wave), or ids:ID;ID;... for explicit ids
              (live-search results, meshes, flipbooks)
    KIND      image (default), mesh, flipbook, sound
  -> OUT_DIR/NAME_0.png, NAME_1.png ... (60 per sheet, 10 columns), then Read them.

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
THUMBS = "https://thumbnails.roblox.com/v1/assets?assetIds={}&size=150x150&format=Png"


def main():
    out_dir, name, query = sys.argv[1], sys.argv[2], sys.argv[3]
    kind = sys.argv[4] if len(sys.argv) > 4 else "image"
    limit = int(sys.argv[5]) if len(sys.argv) > 5 else 200
    if query.startswith("ids:"):
        ids = [i for i in query[4:].split(";") if i]
    else:
        words = set(query.split(","))
        lib = json.load(open(LIB))
        ids = [a["id"] for a in lib["assets"] if a["kind"] == kind and words & set(a.get("keywords", []))][:limit]
    cache = os.path.join(out_dir, "thumbs")
    os.makedirs(cache, exist_ok=True)
    need = [i for i in ids if not os.path.exists(os.path.join(cache, i + ".png"))]
    for k in range(0, len(need), 100):
        data = json.load(urllib.request.urlopen(THUMBS.format(",".join(need[k:k + 100]))))
        for entry in data.get("data", []):
            if entry.get("imageUrl"):
                try:
                    png = urllib.request.urlopen(entry["imageUrl"]).read()
                    open(os.path.join(cache, str(entry["targetId"]) + ".png"), "wb").write(png)
                except Exception as ex:  # a thumbnail still pending or blocked
                    print("skip", entry["targetId"], ex)
    tile, cols, per = 110, 10, 60
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
