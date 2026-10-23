"""Draws the bar fill overlays shared by every HUD bar (vitals and seated).

The vitals mounts, plaques and chips now come from the Figma kit (art/ui/figma);
the old ones (vitals_mount.png, seat_mount.png, ...) were drawn by draw_vitals.ps1
(unused now). This file draws the bar fills and their overlays:
fill_sheen.png    16x64 (no longer used; hud_sheen_* below replace it): top lip, glow, darker
                  belly (white/black only, so the fill's colour shows through).
fill_edge.png     48x64, the soft bright leading edge at a fill's right end (no longer used).
hud_fill_*.png / hud_sheen_*.png   64 px tall, the vitals and seated fills
                  (2026-10-23): white shapes 9-sliced so only the plain middle
                  stretches (SliceScale = bar height / 64, Hud keeps it in step);
                  Fill, Trail and Flash use hud_fill_* (tinted by the Theme
                  gradient or ImageColor3), the Fill's Sheen child hud_sheen_*.
                  pt   both ends pointed (health)          64x64  Rect(19, 31, 45, 33)
                  ptl  left pointed, right square (track)  47x64  Rect(19, 31, 45, 33)
                  ptr  left square, right pointed (overflow) 47x64 Rect(2, 31, 28, 33)
                  round  stadium ends (qi, guard, dantian)  96x64  Rect(32, 31, 64, 33)
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



FILL_H = 64  # source height of the vitals fills
POINT = 19  # a pointed end's depth (0.3 of the height)
SHAPES = {"pt": (64, "point", "point"), "ptl": (47, "point", "square"), "ptr": (47, "square", "point"), "round": (96, "round", "round")}


def _shape_mask(kind):
    """The fill outline at SS, in an L mask."""
    w, left, right = SHAPES[kind]
    W, H = s(w), s(FILL_H)
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    if kind == "round":
        d.rounded_rectangle([0, 0, W - 1, H - 1], radius=H // 2, fill=255)
        return mask
    lx = s(POINT) if left == "point" else 0
    rx = W - s(POINT) if right == "point" else W
    pts = [(lx, 0), (rx, 0)]
    pts += [(W, H / 2), (rx, H)] if right == "point" else [(W, H)]
    pts += [(lx, H), (0, H / 2)] if left == "point" else [(0, H)]
    d.polygon(pts, fill=255)
    return mask


def shaped_fill(kind):
    """Plain white fill in the shape (tinted in game)."""
    mask = _shape_mask(kind)
    img = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    img.putalpha(mask)
    finish(img, f"hud_fill_{kind}.png")


def shaped_sheen(kind):
    """fill_sheen's rows (top lip, soft glow, darker belly) inside the shape."""
    mask = _shape_mask(kind)
    W, H = mask.size
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y in range(H):
        t = y / (H - 1)
        if t < 0.12:
            c = (255, 255, 255, int(170 * (1 - t / 0.12) + 60))
        elif t < 0.5:
            c = (255, 255, 255, int(max(0, 1 - abs(t - 0.32) / 0.2) * 46))
        else:
            c = (0, 0, 0, int(((t - 0.5) / 0.5) ** 2 * 110))
        ImageDraw.Draw(img).line([(0, y), (W, y)], fill=c)
    from PIL import ImageChops
    img.putalpha(ImageChops.multiply(img.getchannel("A"), mask))
    finish(img, f"hud_sheen_{kind}.png")


if __name__ == "__main__":
    fill_sheen()
    fill_edge()
    for kind in SHAPES:
        shaped_fill(kind)
        shaped_sheen(kind)
