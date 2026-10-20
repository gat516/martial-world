"""Draws the reward art: the pickup feed's ink strip and its tintable accent
stroke, and the boss victory card's rays, lacquer banner and ink backdrop.
All are used with ScaleType.Stretch at their native aspect (no 9-slice: the
strip fades along its length, which slicing would smear).
Run:  uv run --with pillow --with numpy python art/ui/draw_rewards.py
"""

import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from draw_ui import GOLD, GOLD_HI, GOLD_LO, INK, SS, bevel_border, canvas, finish, gradient_rect, lozenge, shadow_under, spiral  # noqa: E402


def ramp(x, x0, x1):
    """0 before x0, 1 after x1, smoothstep between."""
    t = min(1.0, max(0.0, (x - x0) / (x1 - x0)))
    return t * t * (3 - 2 * t)


def feed_strip():
    """The pickup feed entry, 480x64 (used at 240x32, Stretch): a band of ink wash
    that fades out to the left, with ragged brushed top/bottom edges, a thin gold
    rule along the top and a small gold lozenge cap at the right end."""
    W, H = 480, 64
    img = canvas(W, H)
    N, M = W * SS, H * SS
    rnd = random.Random(7)
    alpha = Image.new("L", (N, M), 0)
    ad = ImageDraw.Draw(alpha)
    top0, bot0 = 6 * SS, M - 6 * SS
    jt = jb = 0.0
    for x in range(0, N, SS):
        jt = jt * 0.85 + rnd.uniform(-1, 1) * 0.6 * SS
        jb = jb * 0.85 + rnd.uniform(-1, 1) * 0.6 * SS
        fade = ramp(x, 0, N * 0.42)
        a = int(225 * fade)
        ad.line([(x, top0 + jt), (x, bot0 + jb)], fill=a, width=SS)
    alpha = alpha.filter(ImageFilter.GaussianBlur(1.2 * SS))
    band = Image.new("RGBA", (N, M), (0, 0, 0, 0))
    gradient_rect(band, [0, 0, N, M], (30, 38, 40), (10, 14, 17))
    band.putalpha(alpha)
    img.alpha_composite(band)
    # gold hairline along the top, fading in from the left like the band
    rule = Image.new("RGBA", (N, M), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rule)
    for x in range(0, N, SS):
        a = int(200 * ramp(x, N * 0.18, N * 0.7))
        rd.line([(x, top0 + 2 * SS), (x + SS, top0 + 2 * SS)], fill=GOLD[:3] + (a,), width=int(1.5 * SS))
    img.alpha_composite(rule)
    # right end: a short gold rail and a lozenge cap
    d = ImageDraw.Draw(img)
    ex = N - 7 * SS
    d.line([(ex, top0 + 6 * SS), (ex, bot0 - 6 * SS)], fill=GOLD_LO, width=3 * SS)
    d.line([(ex, top0 + 6 * SS), (ex, bot0 - 6 * SS)], fill=GOLD, width=int(1.5 * SS))
    lozenge(d, ex, M / 2, 7 * SS, int(1.5 * SS))
    finish(img, "feed_strip.png")


def feed_accent():
    """The feed entry's rarity stroke, 480x16 (used at 240x8 along the entry's
    bottom, Stretch): a white brush line, tapered and fading out to the left.
    White so ImageColor3 tints it to the item's rarity colour."""
    W, H = 480, 16
    N, M = W * SS, H * SS
    alpha = Image.new("L", (N, M), 0)
    ad = ImageDraw.Draw(alpha)
    cy = M / 2
    for x in range(0, N, SS):
        t = x / N
        th = (1.0 + 2.4 * ramp(t, 0.15, 0.9)) * SS  # thicker toward the right
        a = int(255 * ramp(t, 0.08, 0.6))
        ad.line([(x, cy - th / 2), (x, cy + th / 2)], fill=a, width=SS)
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.6 * SS))
    img = Image.new("RGBA", (N, M), (255, 255, 255, 0))
    img.putalpha(alpha)
    finish(img, "feed_accent.png")


def victory_rays():
    """Radiant rays, 1024x1024 (rotated slowly behind the victory banner): warm
    gold wedges from the centre, fading out with distance."""
    S = 1024
    N = S * SS // 2  # 2x is plenty for soft rays
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    c = N / 2
    wedges = Image.new("L", (N, N), 0)
    wd = ImageDraw.Draw(wedges)
    count = 18
    for k in range(count):
        a = k * 2 * math.pi / count
        half = math.pi / count * (0.45 if k % 2 else 0.3)
        r = N * 0.75
        wd.polygon([(c, c), (c + r * math.cos(a - half), c + r * math.sin(a - half)), (c + r * math.cos(a + half), c + r * math.sin(a + half))], fill=255 if k % 2 == 0 else 150)
    wedges = wedges.filter(ImageFilter.GaussianBlur(N * 0.006))
    radial = Image.new("L", (N, N), 0)
    px = radial.load()
    for y in range(N):
        for x in range(0, N):
            dist = math.hypot(x - c, y - c) / (N / 2)
            px[x, y] = int(255 * max(0.0, 1 - dist) ** 1.6)
    from PIL import ImageChops

    alpha = ImageChops.multiply(wedges, radial)
    glow = Image.new("L", (N, N), 0)
    ImageDraw.Draw(glow).ellipse([c - N * 0.16, c - N * 0.16, c + N * 0.16, c + N * 0.16], fill=200)
    glow = glow.filter(ImageFilter.GaussianBlur(N * 0.06))
    alpha = ImageChops.lighter(alpha, glow)
    col = Image.new("RGBA", (N, N), (255, 226, 150, 255))
    col.putalpha(alpha)
    img.alpha_composite(col)
    img = img.resize((S, S), Image.LANCZOS)
    img.save(os.path.join(os.path.dirname(os.path.abspath(__file__)), "victory_rays.png"))
    print("wrote victory_rays.png", img.size)


def victory_banner():
    """The victory banner, 1024x208 (Stretch at native aspect): a lacquer-red
    band with gold rails, swallowtail ribbon ends folded behind it, a lozenge
    and cloud curls at each end of the band."""
    W, H = 1024, 208
    img = canvas(W, H)
    N, M = W * SS, H * SS
    cy = M / 2
    # ribbon tails behind: darker red, swallowtail cut, dropped a little
    tails = canvas(W, H)
    td = ImageDraw.Draw(tails)
    for side in (-1, 1):
        x_in = N / 2 + side * 330 * SS
        x_out = N / 2 + side * 488 * SS
        notch = N / 2 + side * 452 * SS
        t0, t1 = cy - 34 * SS, cy + 52 * SS
        pts = [(x_in, t0), (x_out, t0), (notch, (t0 + t1) / 2), (x_out, t1), (x_in, t1)]
        td.polygon(pts, fill=GOLD_LO)
        k = 4 * SS
        inner = [(x_in, t0 + k), (x_out - side * 7 * SS, t0 + k), (notch - side * 5 * SS, (t0 + t1) / 2), (x_out - side * 7 * SS, t1 - k), (x_in, t1 - k)]
        td.polygon(inner, fill=(104, 26, 22, 255))
        td.line([(x_in, t0 + 12 * SS), (x_out - side * 24 * SS, t0 + 12 * SS)], fill=(200, 150, 80, 120), width=2 * SS)
        td.line([(x_in, t1 - 12 * SS), (x_out - side * 24 * SS, t1 - 12 * SS)], fill=(200, 150, 80, 120), width=2 * SS)
        # the fold: a dark triangle where the tail tucks behind the band
        fx = N / 2 + side * 360 * SS
        td.polygon([(fx, cy + 40 * SS), (fx + side * 30 * SS, cy + 52 * SS), (fx, cy + 52 * SS)], fill=(50, 10, 8, 255))
    img.alpha_composite(tails)
    # the band
    x0, x1 = N / 2 - 380 * SS, N / 2 + 380 * SS
    y0, y1 = cy - 58 * SS, cy + 42 * SS
    gradient_rect(img, [x0, y0, x1, y1], (196, 52, 40), (112, 22, 18), radius=8 * SS)
    d = ImageDraw.Draw(img)
    bevel_border(d, [int(x0), int(y0), int(x1), int(y1)], 6 * SS, radius=8 * SS)
    d.line([(x0 + 16 * SS, y0 + 14 * SS), (x1 - 16 * SS, y0 + 14 * SS)], fill=(250, 210, 140, 130), width=2 * SS)
    d.line([(x0 + 16 * SS, y1 - 14 * SS), (x1 - 16 * SS, y1 - 14 * SS)], fill=(250, 210, 140, 130), width=2 * SS)
    gloss = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(gloss).rounded_rectangle([x0 + 24 * SS, y0 + 18 * SS, x1 - 24 * SS, y0 + 38 * SS], radius=8 * SS, fill=(255, 240, 220, 36))
    img.alpha_composite(gloss)
    d = ImageDraw.Draw(img)
    my = (y0 + y1) / 2
    for side in (-1, 1):
        ex = x0 if side < 0 else x1
        lozenge(d, ex, my, 26 * SS, 4 * SS)
        spiral(d, ex - side * 46 * SS, my - 18 * SS, 15 * SS, 1.25, math.pi * 0.5, side, 4 * SS, GOLD)
        spiral(d, ex - side * 46 * SS, my + 18 * SS, 15 * SS, 1.25, -math.pi * 0.5, -side, 4 * SS, GOLD)
    finish(shadow_under(img, blur=6, offset=4, alpha=170), "victory_banner.png")


def victory_backdrop():
    """A soft ink-wash pool, 512x288 (Stretch behind the whole card): near-black,
    densest in the middle and fading out to nothing at the edges, so the card's
    text stays legible over any scene without a hard panel edge."""
    W, H = 512, 288
    img = Image.new("RGBA", (W, H), (8, 11, 13, 0))
    px = img.load()
    for y in range(H):
        for x in range(W):
            dx = (x - W / 2) / (W / 2)
            dy = (y - H / 2) / (H / 2)
            dist = math.sqrt(dx * dx + dy * dy)
            a = min(1.0, max(0.0, 1 - dist) * 2.0)
            px[x, y] = (8, 11, 13, int(215 * a * a * (3 - 2 * a)))
    img.save(os.path.join(os.path.dirname(os.path.abspath(__file__)), "victory_backdrop.png"))
    print("wrote victory_backdrop.png", img.size)


if __name__ == "__main__":
    feed_strip()
    feed_accent()
    victory_rays()
    victory_banner()
    victory_backdrop()
