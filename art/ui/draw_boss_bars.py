"""Draws the boss bar's fill pieces. The frame itself (plate, rims, plaque, gems)
is not drawn here: it is exported from the Figma UI kit (tools/figma_boss_export.py,
art/ui/figma/boss/).

bossbar_fill.png   160x64, plain white, square left end, right end cut at 45 degrees
                   (the trough's slant). Fill, Trail and Flare use it, tinted in game.
bossbar_sheen.png  160x64, the overlay inside the same shape: a bright top lip, a soft
                   inner glow, a darker belly and a lit band along the slanted end
                   (white/black only, so the fill colour shows through).
Both: ScaleType Slice, SliceScale = bar height / 64 (BossBars keeps it in step), so
the slant stays at 45 degrees at any size. Fill: SliceCenter Rect(2, 31, 96, 33) (the
64 px right corner holds the whole slant, the left corner is a 2 px margin). Sheen:
Rect(2, 31, 88, 33), a 72 px right corner, so the lit band along the slant (7 px
inside it) stays in the corner instead of smearing along the bottom strip.
Same shape as the vitals' slanted fills (hud-compact, draw_vitals.py hud_fill_r).
Run: uv run --with pillow --with numpy python art/ui/draw_boss_bars.py
"""

import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw

OUT = os.path.dirname(os.path.abspath(__file__))
SS = 4
W, H = 160, 64  # the cut leans one px per px of height


def mask() -> Image.Image:
    m = Image.new("L", (W * SS, H * SS), 0)
    ImageDraw.Draw(m).polygon([(0, 0), (W * SS, 0), ((W - H) * SS, H * SS), (0, H * SS)], fill=255)
    return m


def save(img: Image.Image, name: str) -> None:
    img = img.resize((W, H), Image.LANCZOS)
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


def fill() -> None:
    img = Image.new("RGBA", (W * SS, H * SS), (255, 255, 255, 0))
    img.putalpha(mask())
    save(img, "bossbar_fill.png")


def sheen() -> None:
    w, h = W * SS, H * SS
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    t = ys / (h - 1)
    white = np.where(t < 0.12, 170 * (1 - t / 0.12) + 60, np.where(t < 0.5, np.clip(1 - np.abs(t - 0.32) / 0.2, 0, 1) * 46, 0))
    black = np.where(t >= 0.5, ((t - 0.5) / 0.5) ** 2 * 110, 0)
    d_right = (w - (xs + ys)) / np.sqrt(2) / SS  # source px inside the slant
    white = np.maximum(white, np.clip(1 - d_right / 7, 0, 1) ** 1.6 * 200)
    a = np.clip(white + black, 0, 255)
    rgb = np.where(white >= black, 255, 0)
    img = Image.fromarray(np.dstack([rgb, rgb, rgb, a]).astype(np.uint8), "RGBA")
    img.putalpha(ImageChops.multiply(img.getchannel("A"), mask()))
    save(img, "bossbar_sheen.png")


if __name__ == "__main__":
    fill()
    sheen()
