"""Draws the boss health bar art: one slim shaped frame, a channel gloss, and a
small medallion emblem per boss, plus the phase cracks.

Everything is drawn for the bar's real size in the HUD (Hud.Play.BossBar) and
saved at EXPORT x (2x) for crispness, supersampled SS x on top of that.
Real-size layout (px), shared with assets/Hud.rbxmx and BossBars.luau:
    frame        32 tall, stretched across the bar's width (9-slice)
    channel      rows 8..24 (16 tall); from x 27 to width - 30 (the Bar frame,
                 Back/Trail/Fill, sits there under the frame art)
    socket       the left end: a gold ring, centre (15, 16), radius 15; the
                 emblem (24x24) sits in it
    blade        the right end: the rim runs into a talisman blade point with a
                 jade stud
bossbar_frame.png  256x64 source, SliceCenter Rect(68, 31, 188, 33),
                   SliceScale 0.5 (element height must be 32 so the ends do
                   not stretch; split at the exact vertical centre).
bossbar_gloss.png  8x32, stretched over the channel above the fill: top lip
                   highlight, bottom shade (the bevelled channel).
bossbar_emblem_<boss>.png  64x64 round medallion, shown at 24x24 in the socket.
bossbar_cracks.png phase cracks (light on ink), cropped from the centre outward.
No crowns or halos (rejected motif). No slip lines (they read as a ruler).
Run: uv run --with pillow --with numpy python art/ui/draw_boss_bars.py
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.dirname(os.path.abspath(__file__))
EXPORT = 2  # saved px per real px
SS = 4  # supersampling on top of EXPORT
K = EXPORT * SS  # drawing px per real px
CS = 4  # cracks supersampling

INK = (12, 9, 7, 255)
GOLD_T, GOLD_B = (246, 214, 140), (132, 86, 36)
GOLD_HI = (255, 240, 196, 255)
LACQUER = (30, 12, 12, 255)


def canvas(w, h):
    return Image.new("RGBA", (int(w * K), int(h * K)), (0, 0, 0, 0))


def P(pts):
    return [(x * K, y * K) for x, y in pts]


def poly(img, pts, fill):
    ImageDraw.Draw(img).polygon(P(pts), fill=fill)


def disc(img, cx, cy, r, fill):
    ImageDraw.Draw(img).ellipse([(cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K], fill=fill)


def line(img, pts, fill, w):
    ImageDraw.Draw(img).line(P(pts), fill=fill, width=max(1, int(w * K)), joint="curve")


def vgrad(mask, top, bot, y0, y1):
    """Colour the opaque parts of mask with a vertical gradient (real-px rows y0..y1)."""
    h, w = mask.size[1], mask.size[0]
    ys = np.clip((np.arange(h) / K - y0) / max(y1 - y0, 1e-3), 0, 1)[:, None, None]
    t, b = np.array(top[:3], float), np.array(bot[:3], float)
    rgb = np.broadcast_to(t + (b - t) * ys, (h, w, 3))
    return Image.fromarray(np.dstack([rgb, np.array(mask.getchannel("A"))]).astype(np.uint8), "RGBA")


def grow(img, color, w):
    """An ink outline w real px wide around img's alpha, under it."""
    a = img.getchannel("A").filter(ImageFilter.MaxFilter(int(w * K) * 2 + 1))
    o = Image.new("RGBA", img.size, color)
    o.putalpha(a)
    return Image.alpha_composite(o, img)


def save(img, name):
    w, h = img.size
    img = img.resize((w // SS, h // SS), Image.LANCZOS)
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


# ---------------------------------------------------------------- frame
FW, FH = 128, 32  # real px of the source (saved 256x64)
CY = 16
CH0, CH1 = 8, 24  # channel rows
BAND = 4  # rim band thickness
CL, CR = 27, FW - 30  # channel left / right x


def frame_png():
    """The slim boss frame: a gold rim band around a hollow channel, a round
    emblem socket on the left end, a talisman blade point on the right.
    SliceCenter Rect(68, 31, 188, 33), SliceScale 0.5, element 32px tall."""
    top, bot = CH0 - BAND, CH1 + BAND
    # metal silhouette: band + blade + socket
    m = canvas(FW, FH)
    poly(m, [(18, top), (CR, top), (CR + 8, top), (FW - 9, CY - 3), (FW - 1, CY),
             (FW - 9, CY + 3), (CR + 8, bot), (CR, bot), (18, bot)], (255, 255, 255, 255))
    disc(m, 15, CY, 15, (255, 255, 255, 255))
    # cut the channel back out (the fill shows through)
    cut = canvas(FW, FH)
    ImageDraw.Draw(cut).rectangle([CL * K, CH0 * K, CR * K, CH1 * K], fill=(255, 255, 255, 255))
    a = np.array(m.getchannel("A")).astype(int) - np.array(cut.getchannel("A")).astype(int)
    m.putalpha(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)))
    metal = vgrad(m, GOLD_T, GOLD_B, top, bot)
    img = grow(metal, INK, 1.0)
    # band: lit top edge, shaded bottom edge, ink lip along the channel
    line(img, [(19, top + 0.6), (CR + 8, top + 0.6)], GOLD_HI, 0.7)
    line(img, [(19, bot - 0.6), (CR + 8, bot - 0.6)], (90, 54, 20, 255), 0.7)
    ImageDraw.Draw(img).rectangle([(CL - 1) * K, (CH0 - 1) * K, (CR + 1) * K, CH0 * K], fill=INK)
    ImageDraw.Draw(img).rectangle([(CL - 1) * K, CH1 * K, (CR + 1) * K, (CH1 + 1) * K], fill=INK)
    ImageDraw.Draw(img).rectangle([CR * K, (CH0 - 1) * K, (CR + 1) * K, (CH1 + 1) * K], fill=INK)
    # blade: a fuller groove and a jade stud
    line(img, [(CR + 4, CY), (FW - 6, CY)], (100, 62, 24, 255), 0.9)
    line(img, [(CR + 4, CY - 0.9), (FW - 7, CY - 0.9)], GOLD_HI, 0.5)
    poly(img, [(CR + 6, CY - 4.2), (CR + 10.2, CY), (CR + 6, CY + 4.2), (CR + 1.8, CY)], INK)
    poly(img, [(CR + 6, CY - 3), (CR + 9, CY), (CR + 6, CY + 3), (CR + 3, CY)], (72, 190, 140, 255))
    poly(img, [(CR + 6, CY - 3), (CR + 7.4, CY - 1.4), (CR + 5.2, CY - 0.6)], (200, 255, 226, 255))
    # socket: ring with a lacquer well for the emblem
    disc(img, 15, CY, 12.6, INK)
    disc(img, 15, CY, 11.8, LACQUER)
    ImageDraw.Draw(img).arc([(15 - 14) * K, (CY - 14) * K, (15 + 14) * K, (CY + 14) * K], 200, 320, fill=GOLD_HI, width=int(0.7 * K))
    # four little studs on the ring
    for ang in (0, 90, 180, 270):
        x, y = 15 + 13.7 * math.cos(math.radians(ang)), CY + 13.7 * math.sin(math.radians(ang))
        if ang == 0:
            continue  # the band runs out of the ring there
        disc(img, x, y, 1.3, INK)
        disc(img, x, y, 0.8, (255, 232, 170, 255))
    save(img, "bossbar_frame.png")


def gloss_png():
    """Channel bevel over the fill: a bright lip at the top, shade at the bottom.
    4x16 real (8x32 saved), stretched over the Bar."""
    h = 16 * EXPORT
    a = np.zeros((h, 8 * EXPORT // 2, 4), np.uint8)
    for y in range(h):
        t = y / (h - 1)
        if t < 0.18:
            a[y] = (255, 255, 255, int(150 * (1 - t / 0.18) + 40))
        elif t < 0.45:
            a[y] = (255, 255, 255, int(40 * (1 - (t - 0.18) / 0.27)))
        elif t > 0.72:
            a[y] = (0, 0, 0, int(110 * (t - 0.72) / 0.28))
    Image.fromarray(a, "RGBA").save(os.path.join(OUT, "bossbar_gloss.png"))
    print("wrote bossbar_gloss.png", a.shape[1::-1])


# ---------------------------------------------------------------- emblems
EM = 32  # real px of the emblem source (saved 64x64); shown at 24x24


def medallion(bg_top, bg_bot):
    img = canvas(EM, EM)
    disc(img, 16, 16, 15.5, (255, 255, 255, 255))
    return vgrad(img, bg_top, bg_bot, 1, 31)


def motif(img, shape, top, bot, y0, y1, hi=None):
    """Paste a motif silhouette with a top-light gradient, ink outline, highlight."""
    shaded = vgrad(shape, top, bot, y0, y1)
    img = Image.alpha_composite(img, grow(shaded, INK, 1.1))
    if hi:
        line(img, hi, (255, 255, 255, 200), 0.9)
    return img


def wolf():
    img = medallion((40, 56, 84), (12, 18, 30))
    s = canvas(EM, EM)
    # front-facing wolf head: ears, brow, cheeks, snout
    poly(s, [(7, 6), (12.5, 11), (19.5, 11), (25, 6), (24.5, 15), (27, 18), (21, 21),
             (18.5, 26.5), (16, 28), (13.5, 26.5), (11, 21), (5, 18), (7.5, 15)], (255,) * 4)
    img = motif(img, s, (240, 246, 255), (130, 146, 172), 6, 28, hi=[(8.5, 8.5), (11.5, 11.5)])
    for x in (12.2, 19.8):  # eyes
        poly(img, [(x - 2, 15.6), (x + 2, 15.2), (x, 17.2)], (90, 230, 230, 255))
    poly(img, [(14.4, 24.5), (17.6, 24.5), (16, 26.4)], INK)  # nose
    return img


def fox():
    img = medallion((70, 30, 52), (24, 8, 18))
    s = canvas(EM, EM)
    # front-facing fox head: tall ears, wide cheeks, a narrow snout
    poly(s, [(5, 4), (12, 11), (20, 11), (27, 4), (26, 15), (29, 19), (19, 22.5),
             (16, 28), (13, 22.5), (3, 19), (6, 15)], (255,) * 4)
    img = motif(img, s, (255, 186, 96), (210, 70, 34), 4, 28, hi=[(6.5, 6.5), (10.5, 10.5)])
    for side in (-1, 1):  # dark ear insides, pale cheek ruffs, slit eyes
        poly(img, [(16 + side * 9.6, 7.2), (16 + side * 6.2, 11.2), (16 + side * 9.8, 12.2)], (60, 20, 24, 255))
        poly(img, [(16 + side * 12.4, 18.6), (16 + side * 4.6, 20.6), (16 + side * 2.6, 23)], (255, 240, 222, 255))
        poly(img, [(16 + side * 6.6, 15.4), (16 + side * 2.6, 16.4), (16 + side * 6.0, 16.6)], (255, 230, 120, 255))
    poly(img, [(14.6, 25.6), (17.4, 25.6), (16, 27.4)], INK)
    return img


def serpent():
    img = medallion((22, 64, 46), (6, 22, 16))
    s = canvas(EM, EM)
    pts = []
    for i in range(60):  # an S-coil rising to the head
        t = i / 59
        pts.append((16 + 8 * math.sin(t * 2.2 * math.pi + 0.4) * (1 - 0.35 * t), 27 - 19 * t))
    for i, (x, y) in enumerate(pts):
        r = 2.0 + 1.4 * (i / 59)
        disc(s, x, y, r, (255,) * 4)
    hx, hy = pts[-1]
    poly(s, [(hx - 4, hy + 1), (hx - 1, hy - 4), (hx + 5, hy - 3), (hx + 7, hy + 0.5), (hx + 2, hy + 3)], (255,) * 4)
    img = motif(img, s, (170, 246, 120), (30, 130, 70), 5, 28)
    disc(img, hx + 2.2, hy - 1.4, 0.9, (250, 230, 80, 255))
    line(img, [(hx + 6.6, hy + 0.6), (hx + 9, hy + 1.6)], (220, 40, 40, 255), 0.6)  # tongue
    return img


def storm():
    img = medallion((30, 40, 82), (8, 10, 28))
    s = canvas(EM, EM)
    for cx, cy, r in ((10, 14, 5.2), (16, 11, 6.6), (22.5, 13.5, 5.4), (16, 16, 5.5)):
        disc(s, cx, cy, r, (255,) * 4)
    ImageDraw.Draw(s).rectangle([6 * K, 14 * K, 27 * K, 18.5 * K], fill=(255,) * 4)
    img = motif(img, s, (196, 206, 236), (88, 98, 140), 5, 19, hi=[(12, 8.5), (16, 6.2)])
    b = canvas(EM, EM)
    poly(b, [(17.5, 16), (12.5, 23), (16, 23), (13, 30), (21, 20.5), (17.2, 20.5), (20, 16)], (255,) * 4)
    return motif(img, b, (255, 252, 190), (250, 196, 60), 16, 30)


def default():
    img = medallion((84, 20, 18), (28, 6, 6))
    s = canvas(EM, EM)
    for dx in (-6, 0, 6):  # three claw rakes
        poly(s, [(10 + dx, 6), (13.4 + dx, 6.4), (23 + dx * 0.4, 26), (21.6 + dx * 0.4, 27)], (255,) * 4)
    return motif(img, s, (255, 236, 196), (220, 160, 90), 6, 27)


def emblems():
    for name, fn in (("wolf", wolf), ("fox", fox), ("serpent", serpent), ("storm", storm), ("default", default)):
        save(fn(), f"bossbar_emblem_{name}.png")


# ---------------------------------------------------------------- shared bits
def cracks_png():
    """Jagged cracks across the bar window, radiating from the centre, light-on-ink."""
    w, h = 1024, 56
    rng = np.random.default_rng(7)
    img = Image.new("RGBA", (w * CS, h * CS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def crack(x, y, dx, length, drift, width):
        pts = [(x, y)]
        for _ in range(int(length / 14)):
            x += dx * rng.uniform(8, 18)
            y = float(np.clip(y + rng.uniform(-drift, drift), 2, h - 2))
            pts.append((x, y))
        for w_, col in [(width + 2.4, (0, 0, 0, 210)), (width, (255, 255, 255, 255))]:
            d.line([(px * CS, py * CS) for px, py in pts], fill=col, width=int(w_ * CS), joint="curve")
        # fork
        if len(pts) > 4:
            fx, fy = pts[len(pts) // 2]
            d.line([(fx * CS, fy * CS), ((fx + dx * 24) * CS, (fy + rng.choice([-1, 1]) * 14) * CS)], fill=(255, 255, 255, 230), width=int(1.2 * CS))

    for k in range(16):
        crack(w / 2 + rng.uniform(-24, 24), rng.uniform(8, h - 8), 1, 520, 9, 1.8)
        crack(w / 2 + rng.uniform(-24, 24), rng.uniform(8, h - 8), -1, 520, 9, 1.8)
    img = img.resize((w, h), Image.LANCZOS)
    img.save(os.path.join(OUT, "bossbar_cracks.png"))
    print("wrote bossbar_cracks.png")


def build():
    frame_png()
    gloss_png()
    emblems()
    cracks_png()


if __name__ == "__main__":
    build()
