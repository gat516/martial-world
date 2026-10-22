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


# ================================================================ v2: one design per boss
# Four frames that each carry their boss in the rim itself (no emblem or medallion),
# each built differently: silhouette, material, rim weight and where the ornament
# sits. Same 1024x256 canvas and the same bar window (WIN) and text areas as above,
# so they drop into Hud.BossBar unchanged. Drawn to read at ~400px wide (0.39x).
#   bossbar2_wolf.png  weathered iron, frost fur ruff above, fangs hanging below
#   bossbar2_fox.png   red lacquer and gold, slim; nine tails curl off the right end
#   bossbar2_ape.png   a broken stone slab clamped in bronze, split by lightning
#   bossbar2_jiao.png  thin jade channel; the jiao's body wraps under and round it
WHITE = (255, 255, 255, 255)


def mask_of(draw_fn):
    m = layer()
    draw_fn(m)
    return m


def punch(img, box=WIN, r=2, shadow=190):
    """Cut the bar window out and darken its edge (the fill shows through)."""
    x0, y0, x1, y1 = box
    hole = Image.new("L", img.size, 255)
    ImageDraw.Draw(hole).rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, fill=0)
    img.putalpha(ImageChops.multiply(img.getchannel("A"), hole))
    ImageDraw.Draw(img).rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, outline=(0, 0, 0, shadow), width=int(2 * S))
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


def chamfer(x0, y0, x1, y1, c):
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def feather_plate(img, x0, x1, y0, y1, color, alpha, fx=70, fy=12):
    """A soft ink banner behind the name, fading at its ends."""
    xs = np.arange(W * S) / S
    fade = np.clip(np.minimum(xs - x0, x1 - xs) / fx, 0, 1)
    fade = fade * fade * (3 - 2 * fade)
    ys = np.arange(H * S) / S
    vert = np.clip(np.minimum(ys - y0, y1 - ys) / fy, 0, 1)
    pl = np.zeros((H * S, W * S, 4), np.uint8)
    pl[..., :3] = color
    pl[..., 3] = (fade[None, :] * vert[:, None] * alpha).astype(np.uint8)
    return Image.alpha_composite(img, Image.fromarray(pl, "RGBA")), fade


def rivet(img, x, y, r, face, ink):
    circ(img, x, y, r + 1.2, ink)
    circ(img, x, y, r, face)
    circ(img, x - r * 0.35, y - r * 0.35, r * 0.38, (255, 255, 255, 220))


# ---------------------------------------------------------------- Elder Wolf King v2
def v2_wolf():
    """Weathered iron: a heavy chamfered band, iron end blocks with hanging fangs,
    and a frost-fur ruff rising above the rim to frame an iron name plaque."""
    INK = (8, 10, 14, 255)
    IRON_T, IRON_B = (176, 188, 204), (60, 68, 84)
    FROST_T, FROST_B = (248, 252, 255), (124, 146, 178)
    x0, y0, x1, y1 = WIN
    img = layer()
    rng = np.random.default_rng(3)

    # fur ruff: tufts leaning out from the centre, tallest where they frame the plate
    fur = layer()
    for i in range(46):
        x = 196 + i * (828 - 196) / 45
        d = min(abs(x - 300), abs(x - 724))
        h = 22 + 44 * max(0.0, 1 - d / 150) + rng.uniform(-5, 5)
        lean = (x - 512) / 512 * 26 + rng.uniform(-4, 4)
        w = 12
        poly(fur, [(x - w, 100), (x - 3 + lean * 0.45, 100 - h * 0.62), (x + lean, 100 - h),
                   (x + 4 + lean * 0.5, 100 - h * 0.5), (x + w, 100)], WHITE)
    fur = shade(fur, FROST_T, FROST_B, 30, 102)
    sd = ImageDraw.Draw(fur)
    for i in range(46):  # strand lines
        x = 196 + i * (828 - 196) / 45
        d = min(abs(x - 300), abs(x - 724))
        h = 18 + 36 * max(0.0, 1 - d / 150)
        lean = (x - 512) / 512 * 26
        sd.line([(x * S, 99 * S), ((x + lean * 0.8) * S, (100 - h * 0.75) * S)], fill=(96, 116, 150, 200), width=int(1.4 * S))
    fur = outline(fur, INK, 1.8)
    img.alpha_composite(glow_under(fur, (160, 225, 255), 6, 0.35))

    # iron: chamfered band round the window and squat end blocks
    rim = layer()
    poly(rim, chamfer(x0 - 22, y0 - 15, x1 + 22, y1 + 15, 9), WHITE)
    for cx in (x0 - 34, x1 + 34):
        poly(rim, chamfer(cx - 22, 88, cx + 22, 168, 12), WHITE)
    rim = grain(shade(rim, IRON_T, IRON_B, 88, 168), 0.22, 5)
    rim = outline(rim, INK, 2.2)
    img.alpha_composite(rim)
    line(img, [(x0 - 13, y0 - 12), (x1 + 13, y0 - 12)], (230, 240, 252, 230), 1.6)  # lit top bevel
    line(img, [(x0 - 13, y1 + 12), (x1 + 13, y1 + 12)], (30, 36, 48, 230), 1.6)
    for cx in (x0 - 34, x1 + 34):
        poly(img, chamfer(cx - 15, 98, cx + 15, 158, 8), None, (24, 30, 40, 255), 1.6)
        rivet(img, cx, 128, 5, (210, 222, 236, 255), INK)
    for x in range(214, 830, 62):
        rivet(img, x, y0 - 7.5, 2.8, (206, 218, 232, 255), INK)
        rivet(img, x, y1 + 7.5, 2.8, (170, 182, 198, 255), INK)

    # fangs hanging from the end blocks
    fg = layer()
    for bx, length, width, curve in [(x0 - 44, 70, 20, 12), (x0 - 20, 42, 13, 7)]:
        left = bez((bx - width / 2, 164), (bx - width / 2 + curve * 0.2, 164 + length * 0.6), (bx + curve, 164 + length))
        right = bez((bx + curve, 164 + length), (bx + width / 2 + curve * 0.55, 164 + length * 0.45), (bx + width / 2, 164))
        poly(fg, left + right, WHITE)
    fg = shade(fg, (252, 248, 236), (168, 150, 124), 164, 234)
    fg = Image.alpha_composite(fg, ImageOps.mirror(fg))
    fg = outline(fg, INK, 1.8)
    img.alpha_composite(fg)
    for bx, length in [(x0 - 44, 70), (1024 - (x0 - 44), 70)]:
        line(img, [(bx - 5, 170), (bx - 2, 164 + length * 0.55)], (255, 255, 255, 210), 1.3)

    # frost rime crusting the top of the band and blocks
    fr = layer()
    for i in range(70):
        x = rng.uniform(x0 - 50, x1 + 50)
        y = (88 if abs(x - (x0 - 34)) < 22 or abs(x - (x1 + 34)) < 22 else y0 - 15) + rng.uniform(-1, 3)
        r = rng.uniform(2.5, 6)
        ImageDraw.Draw(fr).ellipse([(x - r) * S, (y - r * 0.55) * S, (x + r) * S, (y + r * 0.55) * S], fill=(244, 250, 255, 235))
    img.alpha_composite(fr)
    for i in range(14):  # crystal glints
        x, y = rng.uniform(x0 - 40, x1 + 40), rng.choice([y0 - 14, y1 + 14]) + rng.uniform(-2, 2)
        lozenge(img, x, y, 3.2, (220, 250, 255, 255), (60, 120, 160, 255))

    # iron name plaque (over the ruff's middle) and realm tab
    pl = layer()
    poly(pl, chamfer(300, 10, 724, 96, 14), WHITE)
    pl = outline(grain(shade(pl, (44, 52, 66), (14, 18, 26), 10, 96), 0.12, 9), INK, 2.2)
    img.alpha_composite(pl)
    poly(img, chamfer(306, 16, 718, 90, 10), None, (150, 168, 192, 200), 1.2)
    tab = layer()
    poly(tab, chamfer(404, 154, 620, 188, 8), WHITE)
    img.alpha_composite(outline(shade(tab, (44, 52, 66), (16, 20, 28), 154, 188), INK, 2))
    poly(img, chamfer(409, 158, 615, 184, 6), None, (150, 168, 192, 180), 1.1)
    return punch(img)


# ---------------------------------------------------------------- Nine-Tailed Fox v2
def v2_fox():
    """Slim red lacquer with gold pinstripes; a gold ruyi spear-point on the left,
    and nine tails sweeping up off the right end with foxfire at their tips.
    Asymmetric on purpose."""
    INK = (24, 6, 10, 255)
    LAC_T, LAC_B = (222, 58, 46), (110, 12, 22)
    GOLD = (246, 206, 120, 255)
    FIRE = (150, 120, 255)
    x0, y0, x1, y1 = WIN
    img = layer()

    # tails first (behind the rim end): fanned up and curling back to the left
    bx, by = x1 + 8, 128
    tails = []
    for i in range(9):
        ang = math.radians(-8 - i * 13.5)
        r = 128 - abs(i - 4) * 6
        tip = (bx + 30 + r * math.cos(ang), by + r * math.sin(ang) * 0.92)
        c1 = (bx + 46, by + 2)
        c2 = (tip[0] + 34 * math.cos(ang + 0.9), tip[1] + 34 * math.sin(ang + 0.9))
        tails.append((bez3((bx, by), c1, c2, tip, 70), tip, ang))
    for pts, tip, ang in reversed(tails):
        t = layer()
        tube(t, pts, 22, 5, (236, 96, 40), (255, 236, 212), 0.35)
        img.alpha_composite(outline(t, INK, 1.5))
    for pts, tip, ang in tails[::2]:  # foxfire on alternate tips
        f = layer()
        fx, fy = tip
        poly(f, [(fx - 5, fy + 2), (fx, fy - 16), (fx + 5, fy + 2), (fx, fy + 6)], FIRE + (255,))
        circ(f, fx, fy + 1, 5, FIRE + (255,))
        img.alpha_composite(glow_under(f, FIRE, 6, 0.9))
        circ(img, fx, fy, 2.2, (240, 236, 255, 255))

    # lacquer band with gold pinstripes
    band = layer()
    rrect(band, (x0 - 11, y0 - 9, x1 + 14, y1 + 9), 10, WHITE)
    band = outline(shade(band, LAC_T, LAC_B, y0 - 9, y1 + 9), INK, 2)
    img.alpha_composite(band)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([(x0 - 8) * S, (y0 - 6) * S, (x1 + 11) * S, (y1 + 6) * S], radius=8 * S, outline=GOLD, width=int(1.6 * S))
    line(img, [(x0 + 4, y0 - 7.5), (x1 - 4, y0 - 7.5)], (255, 236, 200, 150), 0.8)

    # gold ruyi spear-point on the left end
    sp = layer()
    poly(sp, [(x0 - 10, y0 - 7), (x0 - 46, y0 - 7), (x0 - 70, 128), (x0 - 46, y1 + 7), (x0 - 10, y1 + 7)], WHITE)
    poly(sp, [(x0 - 66, 118), (x0 - 112, 128), (x0 - 66, 138)], WHITE)
    sp = outline(shade(sp, (255, 232, 160), (170, 104, 36), 108, 148), INK, 1.8)
    img.alpha_composite(sp)
    t = layer()
    pts = []
    for k in range(60):  # ruyi curl on the spear
        a = k / 59 * 1.7 * math.pi
        r = 12 * (1 - k / 75)
        pts.append((x0 - 40 + math.cos(a + math.pi) * r, 128 + math.sin(a + math.pi) * r))
    tube(t, pts, 4.5, 2, (120, 30, 30), (90, 16, 20))
    img.alpha_composite(t)
    for fx, fy in [(x0 - 100, 98), (x0 - 82, 160)]:  # stray foxfire
        f = layer()
        poly(f, [(fx - 4, fy + 2), (fx, fy - 12), (fx + 4, fy + 2), (fx, fy + 5)], FIRE + (255,))
        circ(f, fx, fy + 1, 4, FIRE + (255,))
        img.alpha_composite(glow_under(f, FIRE, 5, 0.8))

    # lacquer cartouche for the name, and a small realm pill
    pl = layer()
    rrect(pl, (300, 12, 724, 94), 30, WHITE)
    img.alpha_composite(outline(shade(pl, (40, 12, 20), (14, 4, 8), 12, 94), INK, 2))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([300 * S, 12 * S, 724 * S, 94 * S], radius=30 * S, outline=GOLD, width=int(2 * S))
    d.rounded_rectangle([307 * S, 19 * S, 717 * S, 87 * S], radius=24 * S, outline=(246, 206, 120, 120), width=int(1 * S))
    for cx in (300, 724):
        lozenge(img, cx, 53, 9, GOLD, INK)
    pq = layer()
    rrect(pq, (408, 155, 616, 186), 15, WHITE)
    img.alpha_composite(outline(shade(pq, (40, 12, 20), (16, 4, 8), 155, 186), INK, 1.8))
    ImageDraw.Draw(img).rounded_rectangle([408 * S, 155 * S, 616 * S, 186 * S], radius=15 * S, outline=GOLD, width=int(1.5 * S))
    return punch(img, r=3)


# ---------------------------------------------------------------- Thunder Ape v2
def jag(pts, amp, rng, step=10):
    """Roughen a polyline into a broken-stone edge."""
    out = []
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(bx - ax, by - ay) / step))
        for k in range(n):
            t = k / n
            out.append((ax + (bx - ax) * t + rng.uniform(-amp, amp) * 0.5, ay + (by - ay) * t + rng.uniform(-amp, amp)))
    out.append(pts[-1])
    return out


def bolt_path(p0, p1, rng, segs=7, amp=7):
    pts = [p0]
    for k in range(1, segs):
        t = k / segs
        pts.append((p0[0] + (p1[0] - p0[0]) * t + rng.uniform(-amp, amp), p0[1] + (p1[1] - p0[1]) * t + rng.uniform(-amp, amp)))
    pts.append(p1)
    return pts


def v2_ape():
    """A broken stone slab, thick and blocky, clamped in bronze at the ends and
    split by glowing lightning cracks; a rough slate lintel carries the name."""
    INK = (10, 10, 12, 255)
    STONE_T, STONE_B = (150, 144, 132), (62, 58, 54)
    BRZ_T, BRZ_B = (234, 176, 96), (112, 64, 28)
    ARC = (120, 200, 255)
    x0, y0, x1, y1 = WIN
    rng = np.random.default_rng(11)
    img = layer()

    # the slab: jagged top and bottom edges, broken chunky ends
    outline_pts = (
        jag([(118, 96), (300, 92), (512, 94), (724, 92), (906, 96)], 5, rng)
        + jag([(906, 96), (930, 84), (944, 112), (926, 150), (946, 178), (900, 168)], 7, rng, 8)
        + jag([(900, 168), (724, 166), (512, 164), (300, 166), (124, 168)], 5, rng)
        + jag([(124, 168), (80, 180), (94, 140), (74, 104), (100, 80), (118, 96)], 7, rng, 8)
    )
    slab = layer()
    poly(slab, outline_pts, WHITE)
    slab = grain(shade(slab, STONE_T, STONE_B, 84, 182), 0.32, 13, blur=0.6, cell=3)
    img.alpha_composite(outline(slab, INK, 2.4))
    # chipped bevel: light flecks on the top edge, dark pits
    for i in range(46):
        x = rng.uniform(110, 910)
        poly(img, [(x, 97 + rng.uniform(0, 3)), (x + rng.uniform(6, 14), 98 + rng.uniform(0, 3)), (x + rng.uniform(2, 8), 103)], (196, 190, 176, 200))
    for i in range(30):
        x, y = rng.uniform(100, 920), rng.choice([rng.uniform(150, 163), rng.uniform(100, 106)])
        circ(img, x, y, rng.uniform(1, 2.2), (40, 36, 34, 200))

    # lightning cracks through the stone (never across the window)
    cr = layer()
    paths = [bolt_path((x0 - 6, 104), (96, 92), rng), bolt_path((x0 - 30, 150), (88, 172), rng),
             bolt_path((x1 + 6, 152), (934, 172), rng), bolt_path((x1 + 30, 104), (936, 92), rng),
             bolt_path((360, 98), (420, 108), rng, 4, 3), bolt_path((640, 162), (700, 158), rng, 4, 3)]
    for p in paths:
        line(cr, p, ARC + (255,), 3.4)
    glow = cr.filter(ImageFilter.GaussianBlur(4 * S))
    img.alpha_composite(glow)
    img.alpha_composite(glow)
    for p in paths:
        line(img, p, (30, 50, 90, 255), 3.6)
        line(img, p, (236, 248, 255, 255), 1.6)

    # bronze clamps round the ends
    for cx in (x0 - 22, x1 + 22):
        c = layer()
        poly(c, [(cx - 15, 86), (cx + 15, 86), (cx + 17, 172), (cx - 17, 172)], WHITE)
        c = outline(grain(shade(c, BRZ_T, BRZ_B, 86, 172), 0.15, 21), INK, 2)
        img.alpha_composite(c)
        line(img, [(cx - 12, 92), (cx + 12, 92)], (255, 228, 170, 230), 1.4)
        for yy in (100, 156):
            rivet(img, cx, yy, 3.4, (250, 210, 140, 255), INK)

    # rough slate lintel for the name, a crack glowing at one corner
    lt = layer()
    poly(lt, jag([(292, 12), (512, 8), (732, 12)], 4, rng) + jag([(732, 12), (740, 54), (734, 96)], 4, rng)
         + jag([(734, 96), (512, 100), (290, 96)], 4, rng) + jag([(290, 96), (284, 54), (292, 12)], 4, rng), WHITE)
    lt = grain(shade(lt, (66, 66, 72), (30, 30, 36), 8, 100), 0.25, 17, blur=0.6, cell=3)
    img.alpha_composite(outline(lt, INK, 2.2))
    p = bolt_path((732, 30), (700, 10), rng, 4, 4)
    c2 = layer()
    line(c2, p, ARC + (255,), 3)
    img.alpha_composite(c2.filter(ImageFilter.GaussianBlur(3 * S)))
    line(img, p, (236, 248, 255, 255), 1.4)
    # bronze realm tablet
    tb = layer()
    poly(tb, jag([(404, 156), (620, 156)], 2, rng) + [(624, 188), (400, 188)], WHITE)
    img.alpha_composite(outline(grain(shade(tb, (120, 78, 40), (60, 34, 16), 156, 188), 0.12, 23), INK, 2))
    line(img, [(408, 160), (616, 160)], (255, 214, 150, 200), 1.1)
    return punch(img, r=1)


# ---------------------------------------------------------------- Jade Jiao v2
def body_path():
    """The jiao's centreline: head above the left end, round the end, under the
    bar, round the right end and up into a trailing tail fin."""
    pts = []
    pts += bez3((122, 74), (86, 92), (80, 160), (138, 186), 40)  # neck down round the left end
    for k in range(1, 81):  # along under the bar, gently weaving
        t = k / 80
        x = 138 + (884 - 138) * t
        pts.append((x, 186 + 7 * math.sin(t * 3 * math.pi)))
    pts += bez3((884, 186), (950, 180), (958, 110), (906, 84), 40)[1:]  # round the right end
    pts += bez3((906, 84), (880, 72), (860, 66), (836, 60), 20)[1:]  # tail trailing back
    return pts


def v2_jiao():
    """A thin dark-jade channel; the jiao's scaled body wraps under and round the
    bar, horned head rising over the left end, whiskers trailing, tail fin up on
    the right; waves curl below; a jade pearl carries the realm."""
    INK = (6, 20, 18, 255)
    JADE_T, JADE_B = (160, 240, 196), (22, 112, 92)
    BELLY = (236, 232, 190)
    HORN = (238, 214, 140)
    x0, y0, x1, y1 = WIN
    img = layer()

    # soft dark-teal banner for the name
    img, _ = feather_plate(img, 280, 744, 10, 98, (6, 30, 30), 215, 80, 14)
    for y in (14, 94):
        t = layer()
        pts = [(x, y + 2.2 * math.sin((x - 280) / 22)) for x in range(300, 726, 3)]
        line(t, pts, (150, 230, 200, 200), 1.3)
        img.alpha_composite(t)

    # waves curling under each end
    for sx in (1, -1):
        w = layer()
        cx = 150 if sx == 1 else 874
        for k, (ox, oy, r) in enumerate([(0, 222, 22), (40 * sx, 230, 16)]):
            pts = []
            for i in range(50):
                a = i / 49 * 1.6 * math.pi
                rr = r * (1 - i / 70)
                pts.append((cx + ox + sx * math.cos(a + math.pi) * rr, oy + math.sin(a + math.pi) * rr))
            tube(w, pts, 7, 2.5, (110, 210, 220), (236, 252, 255))
        img.alpha_composite(outline(w, INK, 1.4))

    # the body: jade tube, belly stripe toward the bar, scale arcs, dorsal fins
    path = body_path()
    n = len(path)
    fins = layer()
    for k in range(10, n - 30, 9):
        (ax, ay), (bx, by) = path[k], path[k + 1]
        dx, dy = bx - ax, by - ay
        L = math.hypot(dx, dy) or 1
        nx, ny = dy / L, -dx / L  # outward (away from the bar)
        w = 15
        px, py = ax + nx * w * 0.6, ay + ny * w * 0.6
        poly(fins, [(px - dx / L * 6, py - dy / L * 6), (px + nx * 11 + dx / L * 4, py + ny * 11 + dy / L * 4), (px + dx / L * 6, py + dy / L * 6)], WHITE)
    fins = outline(shade(fins, (120, 220, 200), (30, 120, 110), 60, 230), INK, 1.2)
    img.alpha_composite(fins)
    body = layer()
    widths = [10 + 7 * math.sin(min(1.0, k / 30) * math.pi / 2) - (5 * max(0, k - (n - 70)) / 70) for k in range(n)]
    d = ImageDraw.Draw(body)
    for k, (x, y) in enumerate(path):
        r = widths[k]
        d.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=WHITE)
    body = shade(body, JADE_T, JADE_B, 60, 210)
    sc = ImageDraw.Draw(body)
    for k in range(4, n - 6, 3):  # scale arcs
        x, y = path[k]
        r = widths[k] * 0.62
        sc.arc([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], 20, 160, fill=(18, 90, 72, 210), width=int(1.3 * S))
    body = outline(body, INK, 1.8)
    img.alpha_composite(body)
    belly = layer()
    for k in range(6, n - 20):
        (ax, ay), (bx, by) = path[k], path[min(k + 1, n - 1)]
        dx, dy = bx - ax, by - ay
        L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L, dx / L  # toward the bar
        r = widths[k] * 0.32
        ox, oy = ax + nx * widths[k] * 0.55, ay + ny * widths[k] * 0.55
        ImageDraw.Draw(belly).ellipse([(ox - r) * S, (oy - r) * S, (ox + r) * S, (oy + r) * S], fill=BELLY + (255,))
    img.alpha_composite(belly)
    # tail fin
    tf = layer()
    poly(tf, [(840, 60), (812, 34), (826, 58), (796, 50), (824, 70), (842, 66)], WHITE)
    img.alpha_composite(outline(shade(tf, (170, 240, 220), (40, 140, 120), 34, 70), INK, 1.4))

    # the head over the left end, facing the name
    hd = layer()
    hx, hy = 122, 66
    poly(hd, [(hx - 22, hy + 8), (hx - 14, hy - 12), (hx + 6, hy - 18), (hx + 30, hy - 10), (hx + 52, hy - 4),
              (hx + 56, hy + 4), (hx + 34, hy + 8), (hx + 46, hy + 16), (hx + 20, hy + 20), (hx - 8, hy + 22)], WHITE)
    hd = outline(shade(hd, JADE_T, JADE_B, hy - 18, hy + 22), INK, 1.8)
    img.alpha_composite(hd)
    line(img, [(hx + 34, hy + 8), (hx + 52, hy + 2)], INK, 1.2)  # mouth line
    circ(img, hx + 14, hy - 6, 4, INK)
    circ(img, hx + 14, hy - 6, 2.6, (250, 214, 70, 255))
    circ(img, hx + 15, hy - 7, 0.9, INK)
    for (a, b, c) in [((hx - 4, hy - 14), (hx - 24, hy - 40), (hx - 40, hy - 44)), ((hx + 4, hy - 16), (hx - 2, hy - 44), (hx - 14, hy - 58))]:
        h = layer()
        tube(h, bez(a, b, c, 30), 6, 2.4, HORN, (255, 244, 210))
        mid = bez(a, b, c, 30)[18]
        tube(h, bez(mid, (mid[0] - 2, mid[1] - 10), (mid[0] + 6, mid[1] - 16), 14), 3.4, 1.6, HORN, (255, 244, 210))
        img.alpha_composite(outline(h, INK, 1.2))
    for (a, b, c) in [((hx + 50, hy + 2), (hx + 80, hy + 4), (hx + 92, hy + 30)), ((hx + 48, hy + 8), (hx + 64, hy + 30), (hx + 54, hy + 52))]:
        wsk = layer()
        tube(wsk, bez(a, b, c, 40), 2.8, 1.0, (236, 228, 180), (200, 240, 220))
        img.alpha_composite(outline(wsk, INK, 0.8))

    # thin dark-jade channel round the window (over the body)
    ch = layer()
    rrect(ch, (x0 - 8, y0 - 7, x1 + 8, y1 + 7), 8, WHITE)
    img.alpha_composite(outline(shade(ch, (40, 120, 104), (10, 44, 40), y0 - 7, y1 + 7), INK, 1.8))
    ImageDraw.Draw(img).rounded_rectangle([(x0 - 5) * S, (y0 - 4.5) * S, (x1 + 5) * S, (y1 + 4.5) * S], radius=6 * S, outline=(170, 240, 210, 170), width=int(1.1 * S))

    # jade pearl plaque for the realm, sitting on the body
    pq = layer()
    ImageDraw.Draw(pq).ellipse([402 * S, 154 * S, 622 * S, 190 * S], fill=WHITE)
    pq = glow_under(outline(shade(pq, (44, 120, 104), (10, 46, 40), 154, 190), INK, 1.8), (150, 255, 220), 6, 0.6)
    img.alpha_composite(pq)
    ImageDraw.Draw(img).ellipse([408 * S, 158 * S, 616 * S, 186 * S], outline=(190, 250, 225, 170), width=int(1.1 * S))
    return punch(img, r=3)


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
