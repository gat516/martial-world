"""Draws the boss health bar frames (one ornament per boss) plus shared glow and cracks.

Each frame is 1024x256, drawn to be stretched at its native 4:1 aspect (no 9-slice,
so nothing can smear). Layout, in image units, shared by every theme and mirrored
by BossBars.luau / Hud.BossBar:
    name plate  x 236..788  y 4..100     (name + title text sit on it)
    bar window  x 168..856  y 110..146   (transparent hole; the fill shows through)
    realm plaque x 392..632 y 154..186   (realm text)
Shown whole in the HUD (Hud.BossBar, 4:1, max 400x100); never cropped.
The motif for each boss is drawn on the left end and mirrored to the right.
No crowns or halos (rejected motif).
Run: uv run --with pillow --with numpy python art/ui/draw_boss_bars.py
"""

import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

OUT = os.path.dirname(os.path.abspath(__file__))
SS = 4
W, H = 1024, 256
WIN = (168, 110, 856, 146)
S = SS


def layer():
    return Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))


def sc(pts):
    return [(x * S, y * S) for x, y in pts]


def poly(img, pts, fill, outline=None, ow=2.0):
    d = ImageDraw.Draw(img)
    d.polygon(sc(pts), fill=fill)
    if outline:
        d.line(sc(list(pts) + [pts[0]]), fill=outline, width=int(ow * S), joint="curve")


def circ(img, x, y, r, fill):
    ImageDraw.Draw(img).ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=fill)


def line(img, pts, fill, w=2.0):
    ImageDraw.Draw(img).line(sc(pts), fill=fill, width=max(1, int(w * S)), joint="curve")


def rrect(img, box, r, fill):
    x0, y0, x1, y1 = box
    ImageDraw.Draw(img).rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, fill=fill)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def shade(mask_img, top, bot, y0, y1):
    """Fill the alpha of mask_img with a vertical gradient top->bot between y0..y1."""
    h = H * S
    ys = np.clip((np.arange(h) / S - y0) / max(y1 - y0, 1), 0, 1)[:, None]
    t = np.array(top[:3], float)[None, None, :]
    b = np.array(bot[:3], float)[None, None, :]
    rgb = t + (b - t) * ys[:, :, None]
    rgb = np.broadcast_to(rgb, (h, W * S, 3))
    out = np.dstack([rgb, np.array(mask_img.split()[3])]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def glow_under(img, color, radius, alpha=0.8):
    a = img.split()[3].filter(ImageFilter.GaussianBlur(radius * S))
    a = a.point(lambda v: int(min(255, v * alpha)))
    g = Image.new("RGBA", img.size, color[:3] + (0,))
    g.putalpha(a)
    return Image.alpha_composite(g, img)


def tube(img, pts, w0, w1, c0, c1, shape=0.0):
    """Tapered stroke along pts (dense list); width w0 -> w1, colour c0 -> c1."""
    n = len(pts)
    d = ImageDraw.Draw(img)
    for i, (x, y) in enumerate(pts):
        t = i / (n - 1)
        w = w0 + (w1 - w0) * t
        w *= 1 + shape * math.sin(math.pi * t)
        r = max(w / 2, 0.6)
        d.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=mix(c0, c1, t) + (255,))


def bez(p0, p1, p2, n=60):
    return [
        (
            (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1],
        )
        for t in [i / (n - 1) for i in range(n)]
    ]


def bez3(p0, p1, p2, p3, n=80):
    out = []
    for i in range(n):
        t = i / (n - 1)
        u = 1 - t
        out.append(
            (
                u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
            )
        )
    return out


def outline(img, color, w=2.0):
    """Ink outline around the alpha of img, composited under it."""
    a = img.split()[3]
    grown = a.filter(ImageFilter.MaxFilter(int(w * S) * 2 + 1))
    o = Image.new("RGBA", img.size, color)
    o.putalpha(grown)
    return Image.alpha_composite(o, img)


def lozenge(img, cx, cy, r, fill, edge):
    poly(img, [(cx, cy - r), (cx + r * 0.62, cy), (cx, cy + r), (cx - r * 0.62, cy)], fill, edge, 1.4)


def base(pal):
    """Plate, rim with window hole, realm plaque, end jewels."""
    img = layer()
    # name plate: soft ink banner fading at the ends
    xs = np.arange(W * S) / S
    fade = np.clip(np.minimum(xs - 236, 788 - xs) / 90, 0, 1)
    fade = fade * fade * (3 - 2 * fade)
    ys = np.arange(H * S) / S
    vert = np.clip(np.minimum(ys - 6, 100 - ys) / 14, 0, 1)
    alpha = (fade[None, :] * vert[:, None] * pal["plate_a"]).astype(np.uint8)
    pl = np.zeros((H * S, W * S, 4), np.uint8)
    pl[..., :3] = pal["plate"]
    pl[..., 3] = alpha
    img = Image.alpha_composite(img, Image.fromarray(pl, "RGBA"))
    # plate hairlines
    ln = layer()
    for y in (8, 98):
        line(ln, [(250, y), (774, y)], pal["hi"] + (255,), 1.6)
    la = np.array(ln.split()[3]).astype(float) * fade[None, :]
    ln.putalpha(Image.fromarray(la.astype(np.uint8)))
    img = Image.alpha_composite(img, ln)
    # rim: metal frame around the window
    x0, y0, x1, y1 = WIN
    rim = layer()
    rrect(rim, (x0 - 12, y0 - 10, x1 + 12, y1 + 10), 9, (255, 255, 255, 255))
    rim = shade(rim, pal["metal_top"], pal["metal_bot"], y0 - 10, y1 + 10)
    rrect(rim, (x0 - 12, y0 - 10, x1 + 12, y1 + 10), 9, (0, 0, 0, 0))  # placeholder no-op
    img = Image.alpha_composite(img, rim)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([(x0 - 12) * S, (y0 - 10) * S, (x1 + 12) * S, (y1 + 10) * S], radius=9 * S, outline=pal["ink"] + (255,), width=2 * S)
    d.rounded_rectangle([(x0 - 9) * S, (y0 - 7) * S, (x1 + 9) * S, (y1 + 7) * S], radius=7 * S, outline=pal["hi"] + (200,), width=int(1.3 * S))
    d.rounded_rectangle([(x0 - 4) * S, (y0 - 3) * S, (x1 + 4) * S, (y1 + 3) * S], radius=4 * S, outline=pal["ink"] + (255,), width=int(2.2 * S))
    # punch the window hole
    hole = Image.new("L", img.size, 255)
    ImageDraw.Draw(hole).rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=2 * S, fill=0)
    img.putalpha(ImageChops.multiply(img.split()[3], hole))
    # inner shadow on the hole edge
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=2 * S, outline=(0, 0, 0, 170), width=int(1.5 * S))
    # realm plaque
    pq = layer()
    rrect(pq, (392, 154, 632, 186), 10, (255, 255, 255, 255))
    pq = shade(pq, pal["plate2_top"], pal["plate2_bot"], 154, 186)
    img = Image.alpha_composite(img, pq)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([392 * S, 154 * S, 632 * S, 186 * S], radius=10 * S, outline=pal["ink"] + (255,), width=2 * S)
    d.rounded_rectangle([396 * S, 158 * S, 628 * S, 182 * S], radius=7 * S, outline=pal["hi"] + (150,), width=int(1.2 * S))
    for cx in (372, 652):
        lozenge(img, cx, 170, 15, pal["accent"] + (255,), pal["ink"] + (255,))
    # jewel studs at the rim ends are part of each motif
    return img


def finish(img, name):
    img = img.resize((W, H), Image.LANCZOS)
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


def compose(pal, motif_fn, name, behind_fn=None):
    img = layer()
    if behind_fn:
        left = behind_fn()
        img = Image.alpha_composite(img, left)
        img = Image.alpha_composite(img, ImageOps.mirror(left))
    img = Image.alpha_composite(img, base(pal))
    left = motif_fn()
    img = Image.alpha_composite(img, left)
    img = Image.alpha_composite(img, ImageOps.mirror(left))
    finish(img, name)


# ---------------------------------------------------------------- Elder Wolf King
WOLF = dict(
    plate=(10, 16, 24), plate_a=225, metal_top=(150, 164, 180), metal_bot=(54, 66, 82), hi=(220, 232, 246), ink=(8, 12, 18),
    accent=(70, 190, 150), plate2_top=(28, 38, 52), plate2_bot=(10, 15, 22),
)
SILVER_T, SILVER_B = (236, 244, 252), (122, 138, 160)
CYAN = (110, 235, 240)
INKC = (6, 10, 16, 255)


def wolf_head_pts(ox, oy, s, flip=False):
    # profile facing right, nose at (ox + 60s, oy)
    pts = [
        (-60, -62), (-46, -96), (-28, -62), (-6, -52), (22, -34), (44, -12), (60, -2), (62, 6), (52, 12),
        (36, 14), (22, 20), (30, 32), (18, 40), (4, 34), (-14, 46), (-34, 40), (-60, 20), (-70, -20),
    ]
    return [(ox + (-x if flip else x) * s, oy + y * s) for x, y in pts]


def wolf_head(img, ox, oy, s, top, bot, edge, eye):
    m = layer()
    poly(m, wolf_head_pts(ox, oy, s), (255, 255, 255, 255))
    # mane: spikes fanning back from the nape
    for ang, ln_, wd in [(150, 74, 11), (165, 92, 12), (180, 98, 12), (195, 92, 12), (210, 76, 11), (125, 56, 9), (232, 56, 9), (140, 66, 9), (222, 66, 9)]:
        a = math.radians(ang)
        bx, by = ox - 46 * s, oy + 4 * s
        tip = (bx + math.cos(a) * ln_ * s, by - math.sin(a) * ln_ * s)
        nx, ny = -math.sin(a), -math.cos(a)
        poly(m, [(bx + nx * wd * s, by + ny * wd * s), tip, (bx - nx * wd * s, by - ny * wd * s)], (255, 255, 255, 255))
    shaded = shade(m, top, bot, oy - 100 * s, oy + 50 * s)
    shaded = outline(shaded, edge, 2.0)
    img.alpha_composite(shaded)
    circ(img, ox + 26 * s, oy - 24 * s, 4.2 * s, eye + (255,))
    line(img, [(ox + 16 * s, oy - 28 * s), (ox + 36 * s, oy - 20 * s)], edge, 2.2 * s)
    line(img, [(ox + 54 * s, oy + 10 * s), (ox + 28 * s, oy + 12 * s)], edge, 1.6)


def wolf_motif():
    img = layer()
    # silver crescent moon behind the head
    m = layer()
    circ(m, 100, 128, 82, (255, 255, 255, 255))
    ImageDraw.Draw(m).ellipse([(122 - 70) * S, (118 - 70) * S, (122 + 70) * S, (118 + 70) * S], fill=(0, 0, 0, 0))
    moon = shade(m, (230, 240, 250), (110, 130, 156), 46, 210)
    moon = glow_under(outline(moon, INKC, 1.6), CYAN, 9, 0.55)
    img.alpha_composite(moon)
    # ghost wolves: faint spirit-cyan heads drifting above and below the rim
    for ox, oy, s in [(214, 56, 0.42), (212, 206, 0.36)]:
        g = layer()
        poly(g, wolf_head_pts(ox, oy, s), CYAN + (255,))
        for ang in (150, 180, 210):
            a = math.radians(ang)
            bx, by = ox - 46 * s, oy
            poly(g, [(bx, by - 6 * s), (bx + math.cos(a) * 70 * s, by - math.sin(a) * 70 * s), (bx, by + 6 * s)], CYAN + (255,))
        g = g.filter(ImageFilter.GaussianBlur(0.7 * S))
        g.putalpha(g.split()[3].point(lambda v: int(v * 0.5)))
        img.alpha_composite(glow_under(g, CYAN, 6, 0.6))
    # the king's head, snout kissing the rim
    wolf_head(img, 96, 126, 1.08, SILVER_T, SILVER_B, INKC, CYAN)
    # jade seal studs
    for cx, cy in [(152, 128)]:
        circ(img, cx, cy, 11, INKC)
        circ(img, cx, cy, 9, (60, 170, 140, 255))
        circ(img, cx - 2, cy - 3, 3.2, (210, 255, 235, 255))
    return img


# ---------------------------------------------------------------- Nine-Tailed Fox
FOX = dict(
    plate=(26, 10, 20), plate_a=225, metal_top=(212, 150, 96), metal_bot=(96, 44, 40), hi=(255, 214, 160), ink=(22, 8, 12),
    accent=(150, 110, 255), plate2_top=(54, 22, 34), plate2_bot=(24, 8, 16),
)


def fox_tail(img, base_p, ctrl1, ctrl2, tip, w, hot, cold):
    pts = bez3(base_p, ctrl1, ctrl2, tip, 90)
    m = layer()
    tube(m, pts, w * 0.45, 1.5, (255, 255, 255), (255, 255, 255), shape=1.6)
    # colour: warm orange body fading to cream tip
    n = len(pts)
    t = layer()
    tube(t, pts, w * 0.45, 1.5, hot, cold, shape=1.6)
    t = outline(t, (24, 6, 10, 255), 1.8)
    img.alpha_composite(t)


def fox_behind():
    img = layer()
    hot, cold = (236, 120, 52), (255, 238, 205)
    tails = [
        ((150, 150), (90, 190), (30, 190), (12, 120), 44),
        ((150, 140), (84, 160), (22, 120), (24, 50), 46),
        ((152, 128), (96, 120), (50, 80), (78, 20), 46),
        ((156, 118), (120, 90), (110, 50), (150, 8), 40),
        ((152, 160), (130, 210), (90, 236), (50, 240), 36),
    ]
    for tl in tails:
        fox_tail(img, *tl, hot, cold)
    # foxfire wisps at the tips
    fire = layer()
    for fx, fy, r in [(12, 118, 9), (24, 46, 10), (78, 16, 9), (148, 8, 8), (50, 240, 8)]:
        pts = [(fx, fy - r * 1.9), (fx + r * 0.9, fy), (fx, fy + r * 0.7), (fx - r * 0.9, fy)]
        poly(fire, pts, (120, 170, 255, 255))
    img.alpha_composite(glow_under(fire, (140, 120, 255), 6, 0.9))
    return img


def fox_motif():
    img = layer()
    # a small fox-fire orb jewel at the rim end, ringed by tail tufts
    circ(img, 152, 128, 13, (22, 8, 12, 255))
    circ(img, 152, 128, 10.5, (255, 150, 70, 255))
    circ(img, 152, 128, 6, (255, 230, 170, 255))
    circ(img, 150, 125, 2.4, (255, 255, 255, 255))
    return glow_under(img, (255, 120, 60), 8, 0.7)


# ---------------------------------------------------------------- Jade Python
SNAKE = dict(
    plate=(6, 20, 14), plate_a=225, metal_top=(70, 150, 96), metal_bot=(18, 54, 38), hi=(176, 255, 190), ink=(4, 14, 10),
    accent=(150, 235, 70), plate2_top=(16, 44, 30), plate2_bot=(6, 20, 14),
)
SNAKE_GREEN_T, SNAKE_GREEN_B = (118, 214, 126), (22, 90, 60)


def scaled_body(img, pts, w0, w1):
    m = layer()
    tube(m, pts, w0, w1, (255, 255, 255), (255, 255, 255))
    n = len(pts)
    body = layer()
    tube(body, pts, w0, w1, (96, 200, 120), (20, 86, 58))
    body = outline(body, (4, 20, 12, 255), 2.0)
    # belly sheen and scale arcs
    d = ImageDraw.Draw(body)
    for i in range(3, n - 3, 3):
        x, y = pts[i]
        t = i / (n - 1)
        w = w0 + (w1 - w0) * t
        px, py = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
        L = math.hypot(px, py) or 1
        nx, ny = -py / L, px / L
        for k in (-0.28, 0.28):
            cx, cy = x + nx * w * k, y + ny * w * k
            d.arc([(cx - 3.2) * S, (cy - 3.2) * S, (cx + 3.2) * S, (cy + 3.2) * S], 200, 340, fill=(8, 50, 34, 230), width=int(1.1 * S))
    hl = layer()
    tube(hl, [(x, y - 0.22 * (w0 + (w1 - w0) * i / (n - 1))) for i, (x, y) in enumerate(pts)], w0 * 0.2, w1 * 0.2, (190, 255, 200), (110, 220, 150))
    hl.putalpha(ImageChops.multiply(hl.split()[3], body.split()[3]).point(lambda v: int(v * 0.5)))
    body.alpha_composite(hl)
    img.alpha_composite(body)


def snake_motif():
    img = layer()
    # tail trailing out along the lower rim, coils crossing the rim end, neck rising to the head
    tail = bez3((160, 168), (120, 200), (60, 210), (16, 190), 70)
    scaled_body(img, tail, 20, 4)
    neck = bez3((150, 96), (120, 70), (70, 80), (84, 46), 70)
    scaled_body(img, neck, 20, 24)
    for cx in (176, 198):
        band = [(cx - 14 + 30 * t, 88 + 80 * t) for t in [i / 30 for i in range(31)]]
        scaled_body(img, band, 15, 15)
    # head facing the bar, jaws open, jade eye
    hd = layer()
    head_pts = [(60, 34), (96, 24), (128, 36), (150, 52), (136, 58), (110, 58), (90, 64), (70, 56)]
    poly(hd, head_pts, (255, 255, 255, 255))
    hd = shade(hd, (150, 232, 150), (28, 100, 64), 24, 64)
    hd = outline(hd, (4, 20, 12, 255), 2.0)
    img.alpha_composite(hd)
    poly(img, [(150, 52), (138, 74), (126, 60)], (240, 255, 240, 255), (4, 20, 12, 255), 1.2)  # fang
    line(img, [(88, 64), (120, 66), (148, 56)], (150, 20, 40, 255), 2.0)  # tongue-red mouth
    circ(img, 112, 38, 5.5, (4, 20, 12, 255))
    circ(img, 112, 38, 4, (200, 255, 90, 255))
    line(img, [(112, 33.5), (112, 42.5)], (4, 20, 12, 255), 1.6)
    return glow_under(img, (80, 220, 110), 5, 0.35)


# ---------------------------------------------------------------- Thunder Ape
STORM = dict(
    plate=(10, 14, 26), plate_a=225, metal_top=(120, 132, 160), metal_bot=(36, 40, 60), hi=(226, 236, 255), ink=(6, 8, 18),
    accent=(150, 210, 255), plate2_top=(26, 30, 50), plate2_bot=(10, 12, 22),
)


def cloud(img, cx, cy, s, top=(120, 132, 166), bot=(30, 34, 56)):
    m = layer()
    for dx, dy, r in [(-38, 6, 22), (-14, -8, 28), (16, -4, 30), (42, 8, 22), (0, 12, 26), (-24, 14, 20), (26, 16, 20)]:
        circ(m, cx + dx * s, cy + dy * s, r * s, (255, 255, 255, 255))
    c = shade(m, top, bot, cy - 34 * s, cy + 38 * s)
    img.alpha_composite(outline(c, (6, 8, 18, 255), 1.8))


def bolt(img, pts, core, halo, w):
    g = layer()
    line(g, pts, halo + (255,), w * 3)
    g = g.filter(ImageFilter.GaussianBlur(2.2 * S))
    img.alpha_composite(g)
    line(img, pts, halo + (255,), w * 1.5)
    line(img, pts, core + (255,), w * 0.7)


def storm_behind():
    img = layer()
    cloud(img, 78, 52, 1.25)
    cloud(img, 44, 196, 1.0, (96, 108, 142), (24, 28, 48))
    cloud(img, 160, 30, 0.7, (130, 142, 176), (36, 40, 62))
    return img


def storm_motif():
    img = layer()
    bolt(img, [(96, 82), (80, 112), (104, 122), (70, 164), (92, 172), (62, 226)], (255, 255, 235), (130, 190, 255), 3.4)
    bolt(img, [(170, 40), (154, 62), (168, 68), (150, 96)], (255, 255, 235), (130, 190, 255), 2.4)
    # iron stud with a spark
    circ(img, 152, 128, 12, (6, 8, 18, 255))
    circ(img, 152, 128, 9.5, (150, 200, 255, 255))
    circ(img, 152, 128, 5, (255, 255, 240, 255))
    return glow_under(img, (140, 200, 255), 6, 0.5)


# ---------------------------------------------------------------- generic
GEN = dict(
    plate=(18, 14, 12), plate_a=225, metal_top=(220, 176, 100), metal_bot=(100, 66, 30), hi=(255, 232, 170), ink=(14, 10, 8),
    accent=(176, 54, 44), plate2_top=(44, 32, 24), plate2_bot=(18, 12, 10),
)


def gen_motif():
    img = layer()
    gold = (214, 172, 92)
    for rr, w in [(30, 5), (21, 4), (12, 3)]:
        pass
    # ruyi curl scrolls on each end
    pts = []
    for i in range(80):
        t = i / 79
        a = t * 2.4 * math.pi
        r = 38 * (1 - t) + 4
        pts.append((112 + math.cos(a + math.pi) * r, 128 + math.sin(a + math.pi) * r))
    t = layer()
    tube(t, pts, 9, 3, (250, 222, 150), (150, 100, 44))
    img.alpha_composite(outline(t, (14, 10, 8, 255), 1.8))
    t2 = layer()
    tube(t2, bez((20, 128), (60, 92), (112, 90), 40), 7, 3, (250, 222, 150), (150, 100, 44))
    tube(t2, bez((20, 128), (60, 164), (112, 166), 40), 7, 3, (250, 222, 150), (150, 100, 44))
    img.alpha_composite(outline(t2, (14, 10, 8, 255), 1.8))
    lozenge(img, 28, 128, 16, (176, 54, 44, 255), (14, 10, 8, 255))
    circ(img, 152, 128, 11, (14, 10, 8, 255))
    circ(img, 152, 128, 8.5, (176, 54, 44, 255))
    circ(img, 150, 125, 2.6, (255, 190, 170, 255))
    return img


# ---------------------------------------------------------------- shared bits
def glow_png():
    w, h = 512, 128
    ys, xs = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xs - w / 2) / (w / 2)) ** 2 + ((ys - h / 2) / (h / 2)) ** 2)
    a = np.clip(1 - d, 0, 1) ** 1.6
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(os.path.join(OUT, "bossbar_glow.png"))
    print("wrote bossbar_glow.png")


def cracks_png():
    """Jagged cracks across the bar window, radiating from the centre, light-on-ink."""
    w, h = 1024, 56
    rng = np.random.default_rng(7)
    img = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def crack(x, y, dx, length, drift, width):
        pts = [(x, y)]
        for _ in range(int(length / 14)):
            x += dx * rng.uniform(8, 18)
            y = float(np.clip(y + rng.uniform(-drift, drift), 2, h - 2))
            pts.append((x, y))
        for w_, col in [(width + 2.4, (0, 0, 0, 210)), (width, (255, 255, 255, 255))]:
            d.line([(px * S, py * S) for px, py in pts], fill=col, width=int(w_ * S), joint="curve")
        # fork
        if len(pts) > 4:
            fx, fy = pts[len(pts) // 2]
            d.line([(fx * S, fy * S), ((fx + dx * 24) * S, (fy + rng.choice([-1, 1]) * 14) * S)], fill=(255, 255, 255, 230), width=int(1.2 * S))

    for k in range(16):
        crack(w / 2 + rng.uniform(-24, 24), rng.uniform(8, h - 8), 1, 520, 9, 1.8)
        crack(w / 2 + rng.uniform(-24, 24), rng.uniform(8, h - 8), -1, 520, 9, 1.8)
    img = img.resize((w, h), Image.LANCZOS)
    img.save(os.path.join(OUT, "bossbar_cracks.png"))
    print("wrote bossbar_cracks.png")


# ================================================================ v2: one slender frame per boss
# One family, four bosses: a long thin bar, a thin dark rim hugging it, pointed or
# shaped ends, and small organic accents growing out of the rim with one small motif
# at top-centre. No plaques (the name is plain stroked text above the bar), no
# emblem or medallion. Each boss differs in rim material and texture, end finials
# and the top motif, never by recolour. Same 1024x256 canvas as the originals, but
# a longer, thinner window (V2_WIN), so BossBars switches the layout with the art:
#   name text above the bar, realm small at the right above it, the intro title and
#   omen below. Drawn smooth and anti-aliased; reads at ~400px wide (0.39x).
#   bossbar2_wolf.png  dark iron, frost tufts and tiny fangs, a fur-crest motif
#   bossbar2_fox.png   black lacquer with gold lines, foxfire wisps, a curled tail
#   bossbar2_ape.png   rough dark bronze, lightning hairlines, notched ends, a storm cloud
#   bossbar2_jiao.png  jade with fine scales, fin curls at the ends, pearl and horns
WHITE = (255, 255, 255, 255)
V2_WIN = (64, 112, 960, 144)  # mirrored in BossBars.luau (V2_LAYOUT)


def punch(img, box, r=2, shadow=200):
    """Cut the bar window out and darken its edge (the fill shows through)."""
    x0, y0, x1, y1 = box
    hole = Image.new("L", img.size, 255)
    ImageDraw.Draw(hole).rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, fill=0)
    img.putalpha(ImageChops.multiply(img.getchannel("A"), hole))
    ImageDraw.Draw(img).rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, outline=(0, 0, 0, shadow), width=int(2.2 * S))
    return img


def grain(img, strength, seed, blur=1.0, cell=4):
    """Weathering: smooth noise brightens and darkens the colour where opaque."""
    rng = np.random.default_rng(seed)
    n = rng.normal(0, 1, (H * S // cell, W * S // cell)).astype(np.float32)
    nimg = Image.fromarray(np.clip(n * 40 + 128, 0, 255).astype(np.uint8)).resize((W * S, H * S), Image.BICUBIC)
    nimg = nimg.filter(ImageFilter.GaussianBlur(blur * S))
    a = np.array(img).astype(np.float32)
    k = (np.array(nimg).astype(np.float32) - 128) / 128 * strength
    a[..., :3] = np.clip(a[..., :3] * (1 + k[..., None]), 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def rim_shape(m, pad, tip, ends="point", notch=0):
    """The thin rim round V2_WIN: pad px of band, ends `tip` px past the window.
    ends: "point" (arrow tips) or "blunt" (squared ends with a notch cut in)."""
    x0, y0, x1, y1 = V2_WIN
    cy = (y0 + y1) / 2
    t, b = y0 - pad, y1 + pad
    if ends == "point":
        pts = [(x0 - 4, t), (x1 + 4, t), (x1 + tip, cy), (x1 + 4, b), (x0 - 4, b), (x0 - tip, cy)]
    else:
        e0, e1 = x0 - tip, x1 + tip
        pts = [(e0 + 4, t), (e1 - 4, t), (e1, t + 4), (e1, cy - notch), (e1 - notch, cy), (e1, cy + notch),
               (e1, b - 4), (e1 - 4, b), (e0 + 4, b), (e0, b - 4), (e0, cy + notch), (e0 + notch, cy),
               (e0, cy - notch), (e0, t + 4)]
    poly(m, pts, WHITE)
    return pts


def chevrons(img, color, inset, tip, w=1.6):
    """A fine chevron line inside each pointed end, echoing the tip."""
    x0, y0, x1, y1 = V2_WIN
    cy = (y0 + y1) / 2
    for sx, ex in ((-1, x0), (1, x1)):
        a = (ex + sx * 2, y0 - inset)
        m = (ex + sx * (tip - inset * 2.2), cy)
        b = (ex + sx * 2, y1 + inset)
        line(img, [a, m, b], color, w)


def finish_rim(img, pts, top, bot, ink, hi, pad, seed=None, grain_k=0.0):
    x0, y0, x1, y1 = V2_WIN
    m = layer()
    poly(m, pts, WHITE)
    m = shade(m, top, bot, y0 - pad, y1 + pad)
    if grain_k:
        m = grain(m, grain_k, seed, blur=0.5, cell=3)
    img.alpha_composite(outline(m, ink, 1.8))
    line(img, [(x0 - 2, y0 - pad + 1.6), (x1 + 2, y0 - pad + 1.6)], hi, 1.1)  # lit top edge


def drip(img, x, y, length, width, top, bot, ink):
    """A small hanging point (icicle, fang, moss drip) from the rim's underside."""
    d = layer()
    poly(d, bez((x - width / 2, y), (x - width * 0.2, y + length * 0.6), (x + width * 0.15, y + length))
         + bez((x + width * 0.15, y + length), (x + width * 0.3, y + length * 0.5), (x + width / 2, y)), WHITE)
    img.alpha_composite(outline(shade(d, top, bot, y, y + length), ink, 1.3))


def tufts(img, cx, base, n, h, spread, top, bot, ink, lean=0.0):
    """A small cluster of pointed fur/grass tufts rising from the rim."""
    t = layer()
    for i in range(n):
        u = (i - (n - 1) / 2) / max(1, (n - 1) / 2)
        x = cx + u * spread
        hh = h * (1 - 0.45 * abs(u))
        lx = u * spread * 0.35 + lean
        poly(t, [(x - 5, base + 2), (x - 1 + lx * 0.5, base - hh * 0.6), (x + lx, base - hh), (x + 2 + lx * 0.6, base - hh * 0.5), (x + 5, base + 2)], WHITE)
    img.alpha_composite(outline(shade(t, top, bot, base - h, base), ink, 1.3))


def wisp(img, x, y, s, color):
    """A tiny flame wisp with a soft glow (foxfire)."""
    f = layer()
    poly(f, [(x - 4 * s, y + 2 * s), (x - 1 * s, y - 7 * s), (x + 1 * s, y - 13 * s), (x + 4 * s, y - 3 * s), (x + 4 * s, y + 2 * s), (x, y + 5 * s)], color + (255,))
    circ(f, x, y + 1 * s, 4 * s, color + (255,))
    img.alpha_composite(glow_under(f, color, 5, 0.9))
    circ(img, x, y + 1 * s, 1.8 * s, (246, 240, 255, 255))


# ---------------------------------------------------------------- Elder Wolf King v2
def v2_wolf():
    """Dark weathered iron with arrow tips; frost tufts on the rim, tiny fangs
    and icicles beneath the ends, a small fur crest with a frost gem at top-centre."""
    INK = (8, 10, 14, 255)
    IRON_T, IRON_B = (124, 134, 152), (30, 34, 44)
    FROST_T, FROST_B = (248, 252, 255), (130, 152, 186)
    x0, y0, x1, y1 = V2_WIN
    img = layer()
    pts = rim_shape(layer(), 7, 40)
    # frost tufts along the top, behind the rim
    for cx in (150, 330, 694, 874):
        tufts(img, cx, y0 - 5, 4, 12, 12, FROST_T, FROST_B, INK, lean=(cx - 512) / 512 * 6)
    tufts(img, 512, y0 - 5, 7, 24, 30, FROST_T, FROST_B, INK)  # the crest
    finish_rim(img, pts, IRON_T, IRON_B, INK, (220, 230, 244, 220), 7, seed=5, grain_k=0.22)
    chevrons(img, (200, 214, 232, 200), 3, 40)
    # tiny fangs and icicles under the ends
    for x, ln, w in ((x0 + 16, 16, 7), (x0 + 30, 10, 5), (x1 - 16, 16, 7), (x1 - 30, 10, 5)):
        drip(img, x, y1 + 6, ln, w, (252, 248, 238), (176, 160, 136), INK)
    for x in (260, 420, 604, 764):
        drip(img, x, y1 + 6, 8, 4, (236, 246, 255), (140, 170, 200), INK)
    # frost gem in the crest
    lozenge(img, 512, y0 - 9, 6.5, (180, 236, 255, 255), INK)
    circ(img, 510.5, y0 - 11, 1.4, (255, 255, 255, 255))
    return punch(img, V2_WIN)


# ---------------------------------------------------------------- Nine-Tailed Fox v2
def v2_fox():
    """Black lacquer with fine gold lines; gold hook-curls at the ends, tiny
    foxfire wisps, and a small curled tail at top-centre."""
    INK = (14, 4, 8, 255)
    LAC_T, LAC_B = (54, 16, 22), (14, 3, 6)
    GOLD = (240, 198, 112, 255)
    FIRE = (150, 124, 255)
    x0, y0, x1, y1 = V2_WIN
    cy = (y0 + y1) / 2
    img = layer()
    pts = rim_shape(layer(), 6, 30)
    # gold hook-curls springing from each end
    for sx, ex in ((-1, x0 - 30), (1, x1 + 30)):
        h = layer()
        curl = []
        for k in range(50):
            a = k / 49 * 1.5 * math.pi
            r = 11 * (1 - k / 70)
            curl.append((ex - sx * 4 + sx * (8 + math.sin(a) * r), cy - 14 + math.cos(a) * r - 4))
        tube(h, [(ex, cy)] + bez((ex, cy), (ex + sx * 8, cy - 6), curl[0], 12) + curl, 3.4, 1.4, (250, 216, 140), (190, 130, 50))
        img.alpha_composite(outline(h, INK, 1.1))
    finish_rim(img, pts, LAC_T, LAC_B, INK, (255, 220, 160, 140), 6)
    d = ImageDraw.Draw(img)
    line(img, [(x0 - 2, y0 - 3), (x1 + 2, y0 - 3)], GOLD, 1.0)  # gold pinstripes
    line(img, [(x0 - 2, y1 + 3), (x1 + 2, y1 + 3)], GOLD, 1.0)
    chevrons(img, GOLD, 2.5, 30, 1.3)
    for x in range(x0 + 112, x1 - 50, 224):  # small gold studs along the rim
        lozenge(img, x, y0 - 3, 3.2, GOLD, INK)
        lozenge(img, x, y1 + 3, 3.2, GOLD, INK)
    # foxfire wisps at the ends
    wisp(img, x0 - 16, y0 - 10, 0.9, FIRE)
    wisp(img, x1 + 14, y0 - 12, 0.8, FIRE)
    wisp(img, x1 + 26, y1 + 12, 0.6, FIRE)
    # the curled tail at top-centre: a plume rising off the rim and hooking over
    t = layer()
    path = bez3((498, y0 - 3), (476, y0 - 30), (508, y0 - 50), (538, y0 - 34), 80)
    tube(t, path, 7, 3, (226, 92, 40), (250, 196, 150), 1.6)
    tip = layer()
    tube(tip, path[56:], 9.5, 3, (255, 236, 214), (255, 250, 240), 0.6)
    t.alpha_composite(tip)
    img.alpha_composite(glow_under(outline(t, INK, 1.4), FIRE, 6, 0.35))
    return punch(img, V2_WIN)


# ---------------------------------------------------------------- Thunder Ape v2
def v2_ape():
    """Rough dark bronze, blunt notched ends, a few faint lightning hairlines in
    the rim, and a small storm-cloud tuft with a bolt at top-centre."""
    INK = (10, 9, 8, 255)
    BRZ_T, BRZ_B = (112, 84, 56), (30, 22, 16)
    ARC = (130, 205, 255)
    x0, y0, x1, y1 = V2_WIN
    rng = np.random.default_rng(11)
    img = layer()
    pts = rim_shape(layer(), 8, 24, ends="blunt", notch=11)
    finish_rim(img, pts, BRZ_T, BRZ_B, INK, (236, 196, 140, 170), 8, seed=13, grain_k=0.35)
    # faint lightning hairlines running in the rim
    for (ax, ay, bx, by) in ((x0 + 40, y0 - 4, x0 + 150, y0 - 5), (x1 - 170, y1 + 4, x1 - 60, y1 + 5), (380, y1 + 5, 450, y1 + 4)):
        p = [(ax, ay)]
        for k in range(1, 6):
            t = k / 6
            p.append((ax + (bx - ax) * t, ay + (by - ay) * t + rng.uniform(-2.2, 2.2)))
        p.append((bx, by))
        g = layer()
        line(g, p, ARC + (255,), 2.4)
        img.alpha_composite(g.filter(ImageFilter.GaussianBlur(2.2 * S)))
        line(img, p, (220, 242, 255, 220), 0.9)
    # notched end caps get a lit bevel
    for ex in (x0 - 22, x1 + 22):
        line(img, [(ex + (4 if ex < 512 else -4), y0 - 6), (ex + (4 if ex < 512 else -4), y1 + 6)], (210, 170, 110, 140), 1.0)
    # storm-cloud tuft with a little bolt at top-centre
    c = layer()
    for cx, cyy, r in ((490, y0 - 15, 11), (511, y0 - 24, 14), (533, y0 - 15, 11), (512, y0 - 11, 11)):
        circ(c, cx, cyy, r, WHITE)
    img.alpha_composite(outline(shade(c, (150, 158, 184), (52, 56, 76), y0 - 38, y0 - 2), INK, 1.4))
    b = layer()
    poly(b, [(518, y0 - 18), (504, y0 - 2), (512, y0 - 2), (504, y0 + 10), (524, y0 - 8), (515, y0 - 8), (524, y0 - 18)], WHITE)
    bb = outline(shade(b, (255, 252, 200), (250, 196, 70), y0 - 18, y0 + 10), INK, 1.0)
    img.alpha_composite(glow_under(bb, ARC, 4, 0.7))
    return punch(img, V2_WIN, r=1)


# ---------------------------------------------------------------- Jade Jiao v2
def v2_jiao():
    """Jade with a fine scale texture, small fin curls sweeping back from each
    end, and a luminous pearl between two tiny horns at top-centre."""
    INK = (4, 22, 18, 255)
    JADE_T, JADE_B = (126, 210, 176), (18, 84, 70)
    x0, y0, x1, y1 = V2_WIN
    cy = (y0 + y1) / 2
    img = layer()
    pts = rim_shape(layer(), 7, 34)
    # swept fins: three rays and a membrane rising back along the rim from each tip
    for sx, ex in ((-1, x0 - 34), (1, x1 + 34)):
        f = layer()
        base = ex - sx * 12
        poly(f, [(base, y0 - 4), (base - sx * 2, y0 - 24), (base - sx * 16, y0 - 12), (base - sx * 20, y0 - 28),
                 (base - sx * 32, y0 - 10), (base - sx * 40, y0 - 22), (base - sx * 52, y0 - 4)], WHITE)
        f = outline(shade(f, (176, 244, 220), (30, 128, 110), y0 - 28, y0), INK, 1.2)
        img.alpha_composite(f)
    m = layer()
    poly(m, pts, WHITE)
    m = shade(m, JADE_T, JADE_B, y0 - 7, y1 + 7)
    sd = ImageDraw.Draw(m)
    for row, yy in enumerate((y0 - 4, y1 + 4)):  # fine scale arcs along the band
        for x in range(int(x0 - 10), int(x1 + 10), 9):
            xx = x + (4.5 if row else 0)
            sd.arc([(xx - 5) * S, (yy - 4) * S, (xx + 5) * S, (yy + 4) * S], 20, 160, fill=(12, 70, 58, 210), width=int(1.0 * S))
    img.alpha_composite(outline(m, INK, 1.8))
    line(img, [(x0 - 2, y0 - 5.4), (x1 + 2, y0 - 5.4)], (214, 255, 236, 200), 1.0)
    chevrons(img, (200, 250, 230, 190), 3, 34)
    # whisker curls trailing off the tips
    for sx, ex in ((-1, x0 - 34), (1, x1 + 34)):
        wsk = layer()
        tube(wsk, bez((ex, cy), (ex + sx * 14, cy + 4), (ex + sx * 10, cy + 18), 30), 2.2, 0.9, (226, 230, 186), (190, 240, 220))
        img.alpha_composite(outline(wsk, INK, 0.7))
    # the flaming pearl at top-centre: a luminous jade pearl with three flame licks
    fl = layer()
    for ang, ln in ((-90, 22), (-140, 16), (-40, 16)):
        a = math.radians(ang)
        bx, by = 512 + math.cos(a) * 8, y0 - 14 + math.sin(a) * 8
        tx, ty = 512 + math.cos(a) * (8 + ln), y0 - 14 + math.sin(a) * (8 + ln)
        tube(fl, bez((bx, by), ((bx + tx) / 2 + 5, (by + ty) / 2), (tx, ty), 24), 7, 1.5, (120, 230, 200), (230, 255, 246))
    img.alpha_composite(glow_under(outline(fl, INK, 1.0), (150, 255, 220), 5, 0.6))
    p = layer()
    circ(p, 512, y0 - 14, 11, WHITE)
    p = shade(p, (240, 255, 250), (110, 214, 184), y0 - 25, y0 - 3)
    img.alpha_composite(glow_under(outline(p, INK, 1.3), (160, 255, 220), 6, 0.7))
    circ(img, 508, y0 - 18, 3, (255, 255, 255, 240))
    return punch(img, V2_WIN, r=3)


def build_v2():
    for fn, name in ((v2_wolf, "bossbar2_wolf.png"), (v2_fox, "bossbar2_fox.png"),
                     (v2_ape, "bossbar2_ape.png"), (v2_jiao, "bossbar2_jiao.png")):
        finish(fn(), name)


def build():
    compose(WOLF, wolf_motif, "bossbar_wolf.png")
    compose(FOX, fox_motif, "bossbar_fox.png", fox_behind)
    compose(SNAKE, snake_motif, "bossbar_serpent.png")
    compose(STORM, storm_motif, "bossbar_storm.png", storm_behind)
    compose(GEN, gen_motif, "bossbar_generic.png")
    glow_png()
    cracks_png()


if __name__ == "__main__":
    import sys

    if sys.argv[1:] == ["v2"]:
        build_v2()  # only the per-boss v2 frames
    else:
        build()
        build_v2()
