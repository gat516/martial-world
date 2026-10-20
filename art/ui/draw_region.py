"""Draws the region entry banner art (StarterGui.Rewards.Region): an ink-wash
brush smear behind the text, a tapered brush rule, and a seal stamp.
All are used with ScaleType.Stretch at (about) their native aspect; none is
9-sliced. The rule and seal are near-white so ImageColor3 tints them to the
region's mood (jade: safe ground, gold: within your cultivation, cinnabar:
beyond it).
Run:  uv run --with pillow --with numpy python art/ui/draw_region.py
"""

import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from draw_ui import SS, finish  # noqa: E402


def ramp(x, x0, x1):
    t = min(1.0, max(0.0, (x - x0) / (x1 - x0)))
    return t * t * (3 - 2 * t)


def region_wash():
    """A horizontal ink smear, 1024x256 (Stretch behind the banner, ~4:1): one
    broad brush pass, densest through the middle, ragged dry-brush top and bottom
    edges, both ends trailing off into nothing so it has no hard edge anywhere."""
    W, H = 1024, 256
    N, M = W * SS // 2, H * SS // 2  # 2x is plenty for a soft wash
    rnd = random.Random(11)
    alpha = Image.new("L", (N, M), 0)
    ad = ImageDraw.Draw(alpha)
    cy = M * 0.5
    jt = jb = 0.0
    for x in range(N):
        t = x / N
        jt = jt * 0.8 + rnd.uniform(-1, 1) * 1.6
        jb = jb * 0.8 + rnd.uniform(-1, 1) * 1.6
        # the stroke swells in the middle, narrower at the ends
        half = M * (0.24 + 0.14 * math.sin(math.pi * t))
        a = int(235 * ramp(t, 0.0, 0.26) * (1 - ramp(t, 0.74, 1.0)))
        ad.line([(x, cy - half + jt * 2), (x, cy + half + jb * 2)], fill=a)
    # dry-brush streaks: thin lighter lines running along the stroke
    streaks = Image.new("L", (N, M), 0)
    sd = ImageDraw.Draw(streaks)
    for _ in range(60):
        y = cy + rnd.uniform(-0.36, 0.36) * M
        x0 = rnd.uniform(0.02, 0.6) * N
        x1 = x0 + rnd.uniform(0.2, 0.5) * N
        sd.line([(x0, y), (x1, y + rnd.uniform(-3, 3))], fill=rnd.randint(50, 130), width=rnd.randint(1, 4))
    streaks = streaks.filter(ImageFilter.GaussianBlur(1.0))
    alpha = ImageChops.subtract(alpha, streaks)
    alpha = alpha.filter(ImageFilter.GaussianBlur(M * 0.025))
    img = Image.new("RGBA", (N, M), (10, 13, 15, 0))
    img.putalpha(alpha)
    img = img.resize((W, H), Image.LANCZOS)
    img.save(os.path.join(os.path.dirname(os.path.abspath(__file__)), "region_wash.png"))
    print("wrote region_wash.png", img.size)


def region_rule():
    """A tapered brush rule, 1024x32 (Stretch, used ~360x10): white, thickest at
    the centre and drawn to fine points at both ends, with a slight dry-brush
    break near each tip. Tinted with ImageColor3."""
    W, H = 1024, 32
    N, M = W * SS, H * SS
    alpha = Image.new("L", (N, M), 0)
    ad = ImageDraw.Draw(alpha)
    cy = M / 2
    rnd = random.Random(5)
    for x in range(0, N, SS):
        t = abs(x / N - 0.5) * 2  # 0 at the centre, 1 at the ends
        th = (0.6 + 6.4 * (1 - t) ** 1.6) * SS
        a = 255 if t < 0.82 else int(255 * (1 - ramp(t, 0.82, 1.0)) * (0.6 + 0.4 * rnd.random()))
        ad.line([(x, cy - th / 2), (x, cy + th / 2)], fill=a, width=SS)
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.5 * SS))
    img = Image.new("RGBA", (N, M), (255, 255, 255, 0))
    img.putalpha(alpha)
    finish(img, "region_rule.png")


def region_seal():
    """A seal stamp, 128x128 (used ~30-40px square): a rounded square of
    near-white ink with a thin inner border, rough stamped edges and a few
    speckled gaps where the ink didn't take. Tinted with ImageColor3 (cinnabar,
    jade or bronze); the glyph is a TextLabel on top in parchment."""
    S = 128
    N = S * SS
    rnd = random.Random(3)
    body = Image.new("L", (N, N), 0)
    bd = ImageDraw.Draw(body)
    m = 10 * SS
    bd.rounded_rectangle([m, m, N - m, N - m], radius=10 * SS, fill=255)
    # rough edge: nibble the outline with small dark bites
    for _ in range(160):
        side = rnd.randrange(4)
        p = rnd.uniform(m, N - m)
        r = rnd.uniform(1, 3.2) * SS
        x, y = [(p, m), (N - m, p), (p, N - m), (m, p)][side]
        bd.ellipse([x - r, y - r, x + r, y + r], fill=0)
    # inner border: a thin carved line (no ink)
    k = 20 * SS
    bd.rounded_rectangle([k, k, N - k, N - k], radius=5 * SS, outline=0, width=int(2.6 * SS))
    # speckles where the ink didn't take
    for _ in range(70):
        x, y = rnd.uniform(m, N - m), rnd.uniform(m, N - m)
        r = rnd.uniform(0.5, 1.8) * SS
        bd.ellipse([x - r, y - r, x + r, y + r], fill=rnd.randint(0, 120))
    body = body.filter(ImageFilter.GaussianBlur(0.6 * SS))
    # slight tone variation so the tint keeps an ink texture
    tone = Image.effect_noise((N, N), 30).filter(ImageFilter.GaussianBlur(3 * SS)).point(lambda v: 205 + v // 5)
    img = Image.merge("RGBA", (tone, tone, tone, body))
    finish(img, "region_seal.png")


if __name__ == "__main__":
    region_wash()
    region_rule()
    region_seal()
