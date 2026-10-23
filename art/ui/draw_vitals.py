"""Draws the bar fill overlays shared by every HUD bar (vitals and seated).

The vitals and seated mounts (vitals_mount.png, seat_mount.png), the name and realm
plaques and the cooldown chips are drawn by draw_vitals.ps1 since the reference
redesign (user, 2026-10-23); this file keeps only the fill overlays:
fill_sheen.png    16x64, Stretch over every bar fill: top lip, soft inner glow, darker
                  belly (white/black only, so the fill's colour shows through).
fill_edge.png     48x64, the soft bright leading edge at a fill's right end.
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



if __name__ == "__main__":
    fill_sheen()
    fill_edge()
