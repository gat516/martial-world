"""Checks every 9-sliced image in assets/*.rbxmx against its source PNG in art/ui/.

Roblox stretches the four edge strips of a 9-slice along their length. Any
curve, ornament or gradient that changes along that length gets distorted or
cut off: a pill whose rounded ends reach into the left and right strips renders
with flat, cropped ends. So each top/bottom strip must be identical in every
column, and each left/right strip identical in every row. The centre may hold
anything uniform enough to stretch.

Run: uv run --with pillow python tools/check_slices.py
Exits 1 and lists every image/SliceCenter pair that breaks the rule.
"""

import json
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art" / "ui"
TOLERANCE = 6  # max per-channel difference allowed along a strip (antialiasing)

alpha_only = False
ids = {v: k for k, v in json.loads((ART / "assets.json").read_text()).items()}


def strip_ok(im, box, along):
    """True if every line across the strip matches its first line along `along`."""
    crop = im.crop(box)
    if alpha_only:
        crop = crop.getchannel("A").convert("RGBA")
    w, h = crop.size
    px = crop.load()
    if along == "x":  # top/bottom strip: each column equals column 0
        return all(
            max(abs(a - b) for a, b in zip(px[x, y], px[0, y])) <= TOLERANCE
            for y in range(h) for x in range(w)
        )
    return all(  # left/right strip: each row equals row 0
        max(abs(a - b) for a, b in zip(px[x, y], px[x, 0])) <= TOLERANCE
        for y in range(h) for x in range(w)
    )


def items(text):
    for m in re.finditer(r'<Item class="(Image\w+)"[^>]*>\s*<Properties>(.*?)</Properties>', text, re.S):
        props = m.group(2)
        if not re.search(r'<token name="ScaleType">1</token>', props):
            continue
        name = re.search(r'<string name="Name">(.*?)</string>', props).group(1)
        image = re.search(r'name="Image">\s*<url>(.*?)</url>', props)
        rect = re.search(r'name="SliceCenter">(.*?)</Rect2D>', props, re.S)
        if image and rect:
            nums = [float(n) for n in re.findall(r'-?[\d.]+', rect.group(1))]
            yield name, image.group(1), [round(n) for n in nums[:4]]


failed = False
warned = False
for rbxmx in sorted((ROOT / "assets").glob("*.rbxmx")):
    seen = set()
    for name, image, (x0, y0, x1, y1) in items(rbxmx.read_text()):
        key = (image, x0, y0, x1, y1)
        if key in seen:
            continue
        seen.add(key)
        file = ids.get(image)
        if not file:
            print(f"? {rbxmx.name} {name}: {image} not in art/ui/assets.json")
            continue
        im = Image.open(ART / file).convert("RGBA")
        w, h = im.size
        label = f"{rbxmx.name} {name}: {file} SliceCenter=({x0},{y0},{x1},{y1})"
        if not (0 < x0 < x1 < w and 0 < y0 < y1 < h):
            failed = True
            print(f"FAIL {label}: needs margins on all sides inside {w}x{h}")
            continue
        strips = [((x0, 0, x1, y0), "x", "top"), ((x0, y1, x1, h), "x", "bottom"),
                  ((0, y0, x0, y1), "y", "left"), ((x1, y0, w, y1), "y", "right")]
        for alpha_only in (True, False):
            bad = [side for box, along, side in strips if not strip_ok(im, box, along)]
            if bad and alpha_only:
                failed = True
                print(f"FAIL {label}: the outline changes along the {'/'.join(bad)} strip, "
                      "so Roblox crops or bends it (keep curves inside the corners)")
                break
            if bad:
                warned = True
                print(f"warn {label}: colour changes along the {'/'.join(bad)} strip "
                      "(fine for a gradient; an ornament there will smear)")

if not failed and not warned:
    print("All 9-slices clean.")
sys.exit(1 if failed else 0)
