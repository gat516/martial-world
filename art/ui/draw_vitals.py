"""Draws the bar fill overlays shared by every HUD bar (vitals and seated).

The vitals mounts, plaques and chips now come from the Figma kit (art/ui/figma);
the old ones (vitals_mount.png, seat_mount.png, ...) were drawn by draw_vitals.ps1
(unused now). This file draws the bar fills and their overlays:
fill_sheen.png    16x64 (no longer used; the slanted sheens below replace it): top lip, glow, darker
                  belly (white/black only, so the fill's colour shows through).
fill_edge.png     48x64, the soft bright leading edge at a fill's right end (no longer
                  used by the vitals; the slanted fills below light their own edge).
hud_fill_r.png / hud_sheen_r.png     160x64, the slanted vitals fills (2026-10-23):
                  square left end, right end cut at 45 degrees. Fill and Trail use
                  hud_fill_r (white, tinted by the bar's Theme gradient or colour),
                  the Fill's Sheen child hud_sheen_r (top lip, darker belly, lit
                  slanted leading edge). Slice, SliceCenter Rect(2, 31, 96, 33),
                  SliceScale = bar height / 64 (Hud keeps it in step).
hud_fill_lr.png / hud_sheen_lr.png   192x64, the same with both ends cut (a
                  parallelogram): the guard, which drains toward its centre seal, and
                  the seated overflow, which starts on the breakthrough mark's slant.
                  Slice, SliceCenter Rect(64, 31, 128, 33).
Run: uv run --with pillow --with numpy python art/ui/draw_vitals.py
"""
from PIL import Image, ImageDraw, ImageFilter

from draw_ui import SS, finish


def s(v):
    return v * SS


def fill_sheen():
    """fill_sheen.png 16x64, Stretch over any bar fill (white and black only, so
    it works on every colour): a bright lip along the top, a soft lighter core
    (the inner glow) and a darker belly. Identical in every column."""
    w, h = 16, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        t = y / (h - 1)
        if t < 0.12:
            a = int(170 * (1 - t / 0.12) + 60)
            c = (255, 255, 255, a)
        elif t < 0.5:
            k = 1 - abs(t - 0.32) / 0.2
            c = (255, 255, 255, int(max(0, k) * 46))
        else:
            k = (t - 0.5) / 0.5
            c = (0, 0, 0, int(k * k * 110))
        for x in range(w):
            img.putpixel((x, y), c)
    img.save(__import__("os").path.join(__import__("os").path.dirname(__import__("os").path.abspath(__file__)), "fill_sheen.png"))
    print("wrote fill_sheen.png", img.size)


def fill_edge():
    """fill_edge.png 48x64: the bright leading edge at a fill's right end, a white
    glow brightest at the right, fading left (anchored at the fill's right edge)."""
    w, h = 48, 64
    img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    layer = Image.new("L", img.size, 0)
    ld = ImageDraw.Draw(layer)
    for i in range(w * SS):
        t = i / (w * SS - 1)
        ld.line([(i, 0), (i, h * SS)], fill=int(255 * t ** 2.2 * 0.85))
    # soften top and bottom so it sits inside the trough
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, s(6), w * SS, (h - 6) * SS], radius=s(10), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(s(4)))
    from PIL import ImageChops
    alpha = ImageChops.multiply(layer, mask)
    white = Image.new("RGBA", img.size, (255, 255, 255, 255))
    white.putalpha(alpha)
    finish(white, "fill_edge.png")



SLANT_H = 64  # source height; the cut leans one px per px of height (45 degrees)


def _slant_poly(w, both):
    """The fill shape at SS: square or slanted left end, right end slanted."""
    h = SLANT_H
    left_top = h if both else 0
    return [(s(left_top), 0), (s(w), 0), (s(w - h), s(h)), (0, s(h))]


def _slant_mask(w, both):
    mask = Image.new("L", (s(w), s(SLANT_H)), 0)
    ImageDraw.Draw(mask).polygon(_slant_poly(w, both), fill=255)
    return mask


def slant_fill(name, w, both):
    """Plain white slanted fill (tinted in game)."""
    img = Image.new("RGBA", (s(w), s(SLANT_H)), (255, 255, 255, 0))
    img.putalpha(_slant_mask(w, both))
    finish(img, name)


def slant_sheen(name, w, both):
    """The overlay for a slanted fill: the fill_sheen rows (lip, glow, belly) plus a
    lit band along each slanted end, inside the same shape."""
    import numpy as np
    W, H = s(w), s(SLANT_H)
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float64)
    t = ys / (H - 1)
    white = np.where(t < 0.12, 170 * (1 - t / 0.12) + 60, np.where(t < 0.5, np.clip(1 - np.abs(t - 0.32) / 0.2, 0, 1) * 46, 0))
    black = np.where(t >= 0.5, ((t - 0.5) / 0.5) ** 2 * 110, 0)
    # distance (in source px) inside the right slant: x + y = W at the edge
    d_right = (W - (xs + ys)) / np.sqrt(2) / SS
    edge = np.clip(1 - d_right / 7, 0, 1) ** 1.6 * 200
    if both:
        d_left = ((xs + ys) - H) / np.sqrt(2) / SS
        edge = np.maximum(edge, np.clip(1 - d_left / 7, 0, 1) ** 1.6 * 200)
    white = np.maximum(white, edge)
    a = np.clip(white + black, 0, 255)
    rgb = np.where(white >= black, 255, 0)
    out = np.dstack([rgb, rgb, rgb, a]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    mask = _slant_mask(w, both)
    from PIL import ImageChops
    img.putalpha(ImageChops.multiply(img.getchannel("A"), mask))
    finish(img, name)


if __name__ == "__main__":
    fill_sheen()
    fill_edge()
    slant_fill("hud_fill_r.png", 160, False)
    slant_sheen("hud_sheen_r.png", 160, False)
    slant_fill("hud_fill_lr.png", 192, True)
    slant_sheen("hud_sheen_lr.png", 192, True)
