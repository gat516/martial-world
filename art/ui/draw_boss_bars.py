"""Draws the boss bar's fill pieces. The frame itself (plate, rims, plaque, gems)
is not drawn here: it comes from the Figma UI kit (tools/boss_bar_reshape.py,
art/ui/figma/boss/).

bossbar_fill[_phone].png   plain white, square left end, right end leaning ANGLE
                           degrees from vertical (the trough's end). Fill, Trail and
                           Flare use it, tinted in game.
bossbar_sheen[_phone].png  the overlay inside the same shape: a bright top lip, a soft
                           inner glow, a darker belly and a lit band along the slanted
                           end (white/black only, so the fill colour shows through).
Drawn at display height (Roblox draws GUI images without mipmaps, so a 64 px source
shown 24 px tall looked soft; user, 2026-10-23: "looks kinda low res"): 24 px for the
PC bar (560x104 box, bar 24 tall), 12 px for the phone bar (about 270 wide, bar ~12).
Both: ScaleType Slice, SliceScale = bar height / source height (BossBars keeps it in
step), so the slant keeps its angle at any size. The right corner holds the whole
slant plus a margin, the left corner is a 2 px margin; the sheen's corner also holds
the lit band, so it stays in the corner instead of smearing along the bottom strip.
The script prints each SliceCenter.
Run: uv run --with pillow --with numpy python art/ui/draw_boss_bars.py [ANGLE]
"""

import math
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw

OUT = os.path.dirname(os.path.abspath(__file__))
SS = 8
ANGLE = float(sys.argv[1]) if len(sys.argv) > 1 else 15.0  # end lean from vertical (user, 2026-10-23)
LEAN = math.tan(math.radians(ANGLE))
SIZES = {"": (64, 24), "_phone": (40, 12)}  # suffix: (W, H)


def mask(w: int, h: int) -> Image.Image:
    run = h * LEAN
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).polygon([(0, 0), (w * SS, 0), ((w - run) * SS, h * SS), (0, h * SS)], fill=255)
    return m


def save(img: Image.Image, w: int, h: int, name: str) -> None:
    img = img.resize((w, h), Image.LANCZOS)
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


def fill(w: int, h: int, suffix: str) -> None:
    img = Image.new("RGBA", (w * SS, h * SS), (255, 255, 255, 0))
    img.putalpha(mask(w, h))
    save(img, w, h, f"bossbar_fill{suffix}.png")


def band(h: int) -> float:
    return 7 / 64 * h  # lit band along the slant, source px


def sheen(w: int, h: int, suffix: str) -> None:
    sw, sh = w * SS, h * SS
    ys, xs = np.mgrid[0:sh, 0:sw].astype(np.float64)
    t = ys / (sh - 1)
    white = np.where(t < 0.12, 170 * (1 - t / 0.12) + 60, np.where(t < 0.5, np.clip(1 - np.abs(t - 0.32) / 0.2, 0, 1) * 46, 0))
    black = np.where(t >= 0.5, ((t - 0.5) / 0.5) ** 2 * 110, 0)
    d_right = (sw - (xs + ys * LEAN)) / np.sqrt(1 + LEAN * LEAN) / SS  # source px inside the slant
    white = np.maximum(white, np.clip(1 - d_right / band(h), 0, 1) ** 1.6 * 200)
    a = np.clip(white + black, 0, 255)
    rgb = np.where(white >= black, 255, 0)
    img = Image.fromarray(np.dstack([rgb, rgb, rgb, a]).astype(np.uint8), "RGBA")
    img.putalpha(ImageChops.multiply(img.getchannel("A"), mask(w, h)))
    save(img, w, h, f"bossbar_sheen{suffix}.png")


if __name__ == "__main__":
    for suffix, (w, h) in SIZES.items():
        fill(w, h, suffix)
        sheen(w, h, suffix)
        mid = h // 2
        edge = w - math.ceil(h * LEAN) - 2
        sedge = edge - math.ceil(band(h)) - 1
        # one middle row: the bar is exactly the source height x SliceScale, so nothing
        # stretches along the slanted right strip
        print(f"  {suffix or 'pc'}: fill SliceCenter Rect(2, {mid - 1}, {edge}, {mid}), sheen Rect(2, {mid - 1}, {sedge}, {mid})")
