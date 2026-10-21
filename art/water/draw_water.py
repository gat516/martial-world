"""Draws the stylized shallow-water textures (ServerStorage.WaterKit): white shapes on
transparent so Texture.Color3 / Beam.Color / ParticleEmitter.Color tint them, toon edges
(no soft gradients except where noted), every surface texture tileable.

    uv run --with pillow --with numpy python art/water/draw_water.py [cells glints depth edge ring patch]

Writes into this folder:
  water_cells.png    512  rounded cells split by white foam lines, a light band inside
                          each cell offset toward one side (the main surface layer)
  water_glints.png   512  sparse broken caustic slivers (shimmer layer, drifts across the cells)
  water_depth.png    512  big soft blotches (tinted dark, breaks up the tiling at a large scale)
  water_edge.png     128x512  rim foam for a Beam: a solid wavy foam band on the left
                          (the bank side), loose bubbles, a broken second line and a
                          light shallow band fading out; tiles top to bottom (along the beam)
  foam_ring.png      256  wavy broken foam ring (expanding ripples where a fall lands)
  foam_patch.png     256  churned foam disc: a ring of foam blobs round small cells
"""

import math
import os

import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(7)


def tile_noise(n, freqs, seed):
    """Smooth tileable noise from sums of integer-frequency sines (period n)."""
    r = np.random.default_rng(seed)
    y, x = np.mgrid[0:n, 0:n] / n * 2 * math.pi
    out = np.zeros((n, n))
    for f in freqs:
        for _ in range(3):
            fx, fy = r.integers(-f, f + 1), r.integers(-f, f + 1)
            if fx == 0 and fy == 0:
                fx = f
            out += np.sin(fx * x + fy * y + r.uniform(0, 2 * math.pi)) / f
    out -= out.min()
    return out / out.max()


def voronoi(n, cells, seed, warp=0.0, warp_seed=1):
    """Tileable F1/F2 distances (pixels) for a jittered grid of cells x cells points."""
    r = np.random.default_rng(seed)
    step = n / cells
    pts = []
    for gy in range(cells):
        for gx in range(cells):
            pts.append(((gx + r.uniform(0.05, 0.95)) * step, (gy + r.uniform(0.05, 0.95)) * step))
    pts = np.array(pts)
    y, x = np.mgrid[0:n, 0:n].astype(float)
    if warp > 0:
        x = x + (tile_noise(n, [2, 3], warp_seed) - 0.5) * warp
        y = y + (tile_noise(n, [2, 3], warp_seed + 1) - 0.5) * warp
    f1 = np.full((n, n), 1e9)
    f2 = np.full((n, n), 1e9)
    for ox in (-n, 0, n):
        for oy in (-n, 0, n):
            for px, py in pts:
                d = np.hypot(x - (px + ox), y - (py + oy))
                f2 = np.where(d < f1, f1, np.minimum(f2, d))
                f1 = np.minimum(f1, d)
    return f1, f2


def wrap_blur(mask, radius):
    """Gaussian blur that wraps around the edges (keeps the tile seamless)."""
    n_y, n_x = mask.shape
    big = np.tile(mask, (3, 3))
    img = Image.fromarray((big * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius))
    a = np.asarray(img).astype(float) / 255
    return a[n_y:2 * n_y, n_x:2 * n_x]


def toon(field, edge, soft=1.5):
    """Antialiased step: 1 where field > edge (soft = width in pixels)."""
    return np.clip((field - edge) / soft + 0.5, 0, 1)


def save(alpha, name, size):
    a = np.clip(alpha, 0, 1)
    img = Image.new("RGBA", (a.shape[1], a.shape[0]), (255, 255, 255, 0))
    img.putalpha(Image.fromarray((a * 255).astype(np.uint8)))
    if size != a.shape[1]:
        img = img.resize((size, int(size * a.shape[0] / a.shape[1])), Image.LANCZOS)
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


def shift(a, dx, dy):
    return np.roll(np.roll(a, dy, axis=0), dx, axis=1)


def cells_texture():
    n = 1024
    f1, f2 = voronoi(n, 5, seed=11, warp=70, warp_seed=3)
    edge = f2 - f1  # ~twice the distance to the nearest cell border
    width = 7 + 15 * tile_noise(n, [1, 2], 21)  # foam lines thin and thicken across the tile
    cell = toon(edge, width, 1.0)
    cell = toon(wrap_blur(cell, 9), 0.6, 0.012)  # round the cells' corners
    # light band inside each cell: erode the cell further, push the core off-centre
    # so the band sits thicker on one side (the lit edge in the reference)
    core = toon(wrap_blur(cell, 14), 0.9, 0.012)
    core = toon(wrap_blur(shift(core, -10, -12) * cell, 4), 0.5, 0.02)
    foam = 1 - cell
    band = np.clip(cell - core, 0, 1)
    # some cells get a thin band or none, so the surface is not a grid of rings
    keep = 0.35 + 0.65 * toon(tile_noise(n, [1, 2, 3], 23), 0.35, 0.03)
    alpha = foam + band * 0.45 * keep
    save(alpha, "water_cells.png", 512)


def glints_texture():
    """Short curved highlight slivers (sun glints on ripples), wrapped to tile."""
    n = 1024
    r = np.random.default_rng(31)
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    out = np.zeros((n, n))
    for _ in range(46):
        cx, cy = r.uniform(0, n), r.uniform(0, n)
        rad = r.uniform(30, 70)
        a0 = r.uniform(0, 2 * math.pi)
        span = r.uniform(0.5, 1.1)
        thick = r.uniform(3, 6)
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                dx, dy = xx - (cx + ox), yy - (cy + oy)
                near = (np.abs(dx) < rad + 10) & (np.abs(dy) < rad + 10)
                if not near.any():
                    continue
                d = np.hypot(dx, dy)
                ang = (np.arctan2(dy, dx) - a0) % (2 * math.pi)
                t = np.clip(ang / span, 0, 1)
                taper = np.sin(t * math.pi) * (ang < span)  # thin at both tips
                arc = toon(thick * taper - np.abs(d - rad), 0, 1.2)
                out = np.maximum(out, arc * near)
    save(out, "water_glints.png", 512)


def depth_texture():
    n = 512
    a = tile_noise(n, [1, 2], 41)
    a = np.clip((a - 0.35) / 0.6, 0, 1)
    a = a * a * (3 - 2 * a)
    save(a, "water_depth.png", 512)


def edge_texture():
    w, h = 2048, 512
    x = np.arange(w) / w * 2 * math.pi
    y = np.arange(h)[:, None].astype(float)
    r = np.random.default_rng(51)

    def wave(amp, freqs, seed):
        rr = np.random.default_rng(seed)
        s = np.zeros(w)
        for f in freqs:
            s += np.sin(f * x + rr.uniform(0, 2 * math.pi)) / f
        return s / np.abs(s).max() * amp

    # solid band from the top (bank side) down to a wavy edge
    band_edge = 120 + wave(40, [3, 5, 8, 13], 52)
    foam = toon(band_edge[None, :] - y, 0, 2.0)
    # loose bubbles just under the band
    bub = np.zeros((h, w))
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    for _ in range(70):
        bx = r.uniform(0, w)
        by_base = np.interp(bx, np.arange(w), band_edge)
        by = by_base + r.uniform(14, 60)
        br = r.uniform(7, 18)
        for ox in (-w, 0, w):
            d = np.hypot(xx - (bx + ox), yy - by)
            bub = np.maximum(bub, toon(br - d, 0, 2.0))
    # broken second line further out
    line_y = 240 + wave(30, [2, 4, 7], 53)
    line = toon(12 - np.abs(y - line_y[None, :]), 0, 2.0)
    gaps = toon(wave(1, [3, 5, 9], 54)[None, :] + 0.15, 0, 0.05)
    line = line * gaps
    # light shallow band fading out (the one soft part)
    fade = np.clip(1 - (y - 120) / 330, 0, 1) * 0.35
    alpha = np.maximum.reduce([foam, bub, line, np.broadcast_to(fade, (h, w))])
    # a Beam runs its texture's vertical axis along its length, so turn the strip
    # upright: foam on the left (x = 0), tiling top to bottom
    save(alpha.T, "water_edge.png", 128)


def ring_texture():
    n = 1024
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    c = n / 2
    ang = np.arctan2(yy - c, xx - c)
    rad = np.hypot(xx - c, yy - c)
    wob = 0
    rr = np.random.default_rng(61)
    for f in (5, 9, 14):
        wob = wob + np.sin(f * ang + rr.uniform(0, 6.3)) / f
    r0 = 420 + 18 * wob
    thick = 26 + 14 * np.sin(3 * ang + 1.0)
    ring = toon(thick - np.abs(rad - r0), 0, 2.5)
    gaps = toon(np.sin(4 * ang + 0.6) + 0.55 * np.sin(7 * ang), -0.55, 0.06)
    save(ring * gaps, "foam_ring.png", 256)


def patch_texture():
    n = 1024
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    c = n / 2
    rad = np.hypot(xx - c, yy - c) / c
    r = np.random.default_rng(71)
    blobs = np.zeros((n, n))
    for _ in range(90):
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(0.0, 0.8) ** 0.7 * c
        bx, by = c + math.cos(a) * d, c + math.sin(a) * d
        br = r.uniform(40, 110) * (1 - d / c * 0.55)
        blobs = np.maximum(blobs, toon(br - np.hypot(xx - bx, yy - by), 0, 2.5))
    # small holes (cells) punched through the foam
    f1, f2 = voronoi(n, 9, seed=72, warp=40, warp_seed=9)
    holes = toon(f2 - f1, 22, 1.5)
    holes = toon(wrap_blur(holes, 10), 0.5, 0.02) * toon(0.78 - rad, 0, 0.02)
    holes *= toon(rad - 0.12, 0, 0.02)  # the very centre stays solid
    alpha = blobs * (1 - holes * 0.85) * toon(0.98 - rad, 0, 0.01)
    save(alpha, "foam_patch.png", 256)


if __name__ == "__main__":
    import sys

    only = sys.argv[1:]
    for fn in (cells_texture, glints_texture, depth_texture, edge_texture, ring_texture, patch_texture):
        if not only or fn.__name__.replace("_texture", "") in only:
            fn()

