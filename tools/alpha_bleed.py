"""Alpha bleed: give fully transparent pixels the colour of their nearest visible
neighbours, in place, and take the green cast off half-transparent edge pixels
(green is clamped to max(red, blue) there; opaque pixels are untouched). The art
looks the same; only what Roblox's texture filtering samples at the edges changes.

Why: the cutter leaves the key colour (pure green) under alpha-0 pixels, and
Roblox filters RGB without premultiplying, so a scaled or stretched image shows a
green fringe along its edges (rails turned green in Studio, 2026-10-23).

Run: uv run --with pillow --with numpy python tools/alpha_bleed.py <png>...
"""

import sys

import numpy as np
from PIL import Image


def bleed(path: str, rounds: int = 16) -> None:
    im = Image.open(path).convert("RGBA")
    a = np.array(im).astype(np.float32)
    rgb, alpha = a[:, :, :3], a[:, :, 3]
    # green despill on the soft edge: the key colour also survives, faintly,
    # in half-transparent pixels; no gold or navy has green above both red and blue
    soft = (alpha > 0) & (alpha < 250)
    cap = np.maximum(rgb[:, :, 0], rgb[:, :, 2])
    fix = soft & (rgb[:, :, 1] > cap)
    rgb[:, :, 1][fix] = cap[fix]
    known = alpha > 0
    if known.all() or not known.any():
        a[:, :, :3] = rgb
        Image.fromarray(np.clip(a + 0.5, 0, 255).astype(np.uint8), "RGBA").save(path)
        return
    fallback = rgb[known].mean(axis=0)
    for _ in range(rounds):
        if known.all():
            break
        acc = np.zeros_like(rgb)
        cnt = np.zeros(alpha.shape, np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
            k = np.roll(np.roll(known, dy, 0), dx, 1)
            c = np.roll(np.roll(rgb, dy, 0), dx, 1)
            acc += c * k[:, :, None]
            cnt += k
        grow = (~known) & (cnt > 0)
        rgb[grow] = acc[grow] / cnt[grow][:, None]
        known = known | grow
    rgb[~known] = fallback
    a[:, :, :3] = rgb
    Image.fromarray(np.clip(a + 0.5, 0, 255).astype(np.uint8), "RGBA").save(path)


if __name__ == "__main__":
    for p in sys.argv[1:]:
        bleed(p)
        print("bled", p)
