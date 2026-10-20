"""Draws the ornate xianxia UI art (hotbar slots, rail, window frame, title plaque).

Gold double borders, lozenge corner medallions and ruyi cloud-scroll curls on dark
jade lacquer. Everything is drawn 4x and downsampled for clean edges.
Run with a Python that has Pillow:  python art/ui/draw_ui.py  (writes PNGs beside it)
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.dirname(os.path.abspath(__file__))
SS = 4  # supersampling

GOLD = (214, 172, 92, 255)
GOLD_HI = (250, 222, 150, 255)
GOLD_LO = (120, 82, 34, 255)
INK = (14, 20, 24, 255)
JADE_TOP = (30, 50, 52)
JADE_BOT = (9, 15, 19)


def canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def finish(img, name):
    w, h = img.size
    img = img.resize((w // SS, h // SS), Image.LANCZOS)
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


def gradient_rect(img, box, top, bot, radius=0):
    x0, y0, x1, y1 = [int(v) for v in box]
    grad = Image.new("RGBA", (x1 - x0, y1 - y0))
    gd = ImageDraw.Draw(grad)
    for y in range(y1 - y0):
        t = y / max(1, y1 - y0 - 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
        gd.line([(0, y), (x1 - x0, y)], fill=c)
    mask = Image.new("L", grad.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, grad.size[0] - 1, grad.size[1] - 1], radius=radius, fill=255)
    img.paste(grad, (x0, y0), mask)


def vignette(img, box, strength=150, blur=0.08):
    """Darkens the inside edges of box, like lacquer pooling at a frame."""
    x0, y0, x1, y1 = [int(v) for v in box]
    w, h = x1 - x0, y1 - y0
    mask = Image.new("L", (w, h), strength)
    inset = int(min(w, h) * blur)
    ImageDraw.Draw(mask).rectangle([inset, inset, w - inset, h - inset], fill=0)
    mask = mask.filter(ImageFilter.GaussianBlur(inset * 0.9))
    dark = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    region = img.crop((x0, y0, x1, y1))
    region = Image.composite(dark, region, mask)
    alpha = img.crop((x0, y0, x1, y1)).getchannel("A")
    region.putalpha(alpha)
    img.paste(region, (x0, y0))


def bevel_border(d, box, width, radius=0):
    """A gold band with a lit top-left edge and a shaded bottom-right edge."""
    x0, y0, x1, y1 = box
    d.rounded_rectangle(box, radius=radius, outline=GOLD, width=width)
    hw = max(1, width // 4)
    d.line([(x0 + radius, y0 + hw), (x1 - radius, y0 + hw)], fill=GOLD_HI, width=hw)
    d.line([(x0 + hw, y0 + radius), (x0 + hw, y1 - radius)], fill=GOLD_HI, width=hw)
    d.line([(x0 + radius, y1 - hw), (x1 - radius, y1 - hw)], fill=GOLD_LO, width=hw)
    d.line([(x1 - hw, y0 + radius), (x1 - hw, y1 - radius)], fill=GOLD_LO, width=hw)


def spiral(d, cx, cy, r0, turns, start, direction, width, color):
    """A ruyi curl: an inward spiral starting at angle `start` (radians)."""
    pts = []
    steps = int(80 * turns)
    for i in range(steps + 1):
        t = i / steps
        a = start + direction * t * turns * 2 * math.pi
        r = r0 * (1 - 0.78 * t)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.line(pts, fill=color, width=width, joint="curve")
    ex, ey = pts[-1]
    d.ellipse([ex - width * 0.9, ey - width * 0.9, ex + width * 0.9, ey + width * 0.9], fill=color)
    return pts[0]


def lozenge(d, cx, cy, r, width):
    d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=GOLD_LO)
    r2 = r - width
    d.polygon([(cx, cy - r2), (cx + r2, cy), (cx, cy + r2), (cx - r2, cy)], fill=GOLD)
    r3 = r2 * 0.55
    d.polygon([(cx, cy - r3), (cx + r3, cy), (cx, cy + r3), (cx - r3, cy)], fill=INK)
    r4 = r3 * 0.4
    d.ellipse([cx - r4, cy - r4, cx + r4, cy + r4], fill=GOLD_HI)


def corner_layer(size, cx, cy, scale):
    """The top-left corner ornament: a lozenge medallion with a cloud curl on each
    arm, and a short tail along each border. Returned as a full-size layer."""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w = max(2, int(5 * scale))
    arm = Image.new("RGBA", size, (0, 0, 0, 0))
    ad = ImageDraw.Draw(arm)
    # curl sitting just outside the top border, rolling back toward the corner
    sx, sy = cx + 46 * scale, cy - 11 * scale
    spiral(ad, sx, sy, 15 * scale, 1.25, math.pi * 0.5, -1, w, GOLD)
    ad.line([(cx, cy - 2 * scale), (sx, sy + 15 * scale)], fill=GOLD, width=w)
    # a smaller counter-curl further along
    tx, ty = cx + 74 * scale, cy - 6 * scale
    spiral(ad, tx, ty, 8 * scale, 1.0, math.pi * 0.5, 1, max(2, int(w * 0.8)), GOLD)
    ad.line([(sx + 4 * scale, sy + 15 * scale), (tx, ty + 8 * scale)], fill=GOLD, width=max(2, int(w * 0.8)))
    # mirror the arm across the corner's diagonal for the left border
    layer = Image.alpha_composite(layer, arm)
    diag = arm.transpose(Image.Transpose.TRANSPOSE)
    # transpose mirrors around (0,0); shift so the corner maps onto itself
    shifted = Image.new("RGBA", size, (0, 0, 0, 0))
    shifted.paste(diag, (int(cx - cy), int(cy - cx)), diag)
    layer = Image.alpha_composite(layer, shifted)
    d = ImageDraw.Draw(layer)
    lozenge(d, cx, cy, 17 * scale, max(2, int(3 * scale)))
    return layer


def four_corners(img, layer):
    w, h = img.size
    for flip_x in (False, True):
        for flip_y in (False, True):
            l = layer
            if flip_x:
                l = l.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if flip_y:
                l = l.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            img.alpha_composite(l)


def shadow_under(img, blur=10, offset=6, alpha=150):
    a = img.getchannel("A").filter(ImageFilter.GaussianBlur(blur * SS))
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sh.putalpha(a.point(lambda v: v * alpha // 255))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(sh, (0, offset * SS))
    out.alpha_composite(img)
    return out


def meander_band(d, x0, x1, y, h, color, width):
    """A thin meander (回 key) band from x0 to x1 centred on y."""
    step = h * 2
    x = x0
    top, bot = y - h / 2, y + h / 2
    while x + step <= x1:
        pts = [(x, bot), (x, top), (x + h * 1.5, top), (x + h * 1.5, y + h * 0.1), (x + h * 0.6, y + h * 0.1), (x + h * 0.6, bot), (x + step, bot)]
        d.line(pts, fill=color, width=width, joint="curve")
        x += step


# ---------------------------------------------------------------- hotbar slot

def slot_frame():
    S = 256
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    m = 30 * SS
    box = [m, m, S * SS - m, S * SS - m]
    gradient_rect(img, box, JADE_TOP, JADE_BOT, radius=10 * SS)
    vignette(img, box, strength=170)
    d = ImageDraw.Draw(img)
    bevel_border(d, box, 9 * SS, radius=10 * SS)
    inset = 17 * SS
    d.rounded_rectangle([m + inset, m + inset, S * SS - m - inset, S * SS - m - inset], radius=5 * SS, outline=(205, 170, 95, 150), width=2 * SS)
    four_corners(img, corner_layer(img.size, m + 4 * SS, m + 4 * SS, SS * 1.05))
    # small meander tabs centred on the top and bottom borders
    for y in (m, S * SS - m):
        d.rounded_rectangle([S * SS / 2 - 22 * SS, y - 6 * SS, S * SS / 2 + 22 * SS, y + 6 * SS], radius=3 * SS, fill=INK, outline=GOLD, width=2 * SS)
        meander_band(d, S * SS / 2 - 17 * SS, S * SS / 2 + 17 * SS, y, 6 * SS, GOLD, int(1.6 * SS))
    finish(shadow_under(img, blur=5, offset=3), "slot_frame.png")


def slot_glow():
    """White inner glow for the slot's panel; tinted by rarity or technique color."""
    S = 256
    img = canvas(S, S)
    m = 40 * SS
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([m, m, S * SS - m, S * SS - m], radius=8 * SS, outline=255, width=14 * SS)
    mask = mask.filter(ImageFilter.GaussianBlur(14 * SS))
    clip = Image.new("L", img.size, 0)
    ImageDraw.Draw(clip).rounded_rectangle([m, m, S * SS - m, S * SS - m], radius=8 * SS, fill=255)
    from PIL import ImageChops

    mask = ImageChops.multiply(mask, clip)
    white = Image.new("RGBA", img.size, (255, 255, 255, 255))
    white.putalpha(mask)
    finish(white, "slot_glow.png")


def slot_select():
    """A halo drawn around the frame for the held item; tinted gold."""
    S = 256
    img = canvas(S, S)
    mask = Image.new("L", img.size, 0)
    m = 22 * SS
    ImageDraw.Draw(mask).rounded_rectangle([m, m, S * SS - m, S * SS - m], radius=14 * SS, outline=255, width=12 * SS)
    mask = mask.filter(ImageFilter.GaussianBlur(9 * SS))
    white = Image.new("RGBA", img.size, (255, 255, 255, 255))
    white.putalpha(mask)
    finish(white, "slot_select.png")




# ---------------------------------------------------------------- window frame

def panel_frame():
    """A 9-slice window frame, 1024px. SliceCenter is Rect(200, 200, 824, 824):
    every ornament sits inside the 200px corners and the edges between them are
    plain lines, so stretching a window never distorts the art."""
    S = 1024
    img = canvas(S, S)
    m = 40 * SS
    box = [m, m, S * SS - m, S * SS - m]
    gradient_rect(img, box, (22, 33, 37), (11, 16, 20), radius=20 * SS)
    d = ImageDraw.Draw(img)
    bevel_border(d, box, 10 * SS, radius=20 * SS)
    inset = 24 * SS
    d.rounded_rectangle([m + inset, m + inset, S * SS - m - inset, S * SS - m - inset], radius=10 * SS, outline=(205, 170, 95, 140), width=3 * SS)
    four_corners(img, corner_layer(img.size, m + 8 * SS, m + 8 * SS, SS * 1.6))
    finish(img, "panel_frame.png")


def title_plaque():
    """A title plaque: lacquer band with gold rails and curled ends.
    9-slice horizontally: SliceCenter is Rect(160, 0, 864, 128)."""
    W, H = 1024, 128
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    cy = H * SS / 2
    x0, x1 = 120 * SS, (W - 120) * SS
    gradient_rect(img, [x0, cy - 36 * SS, x1, cy + 36 * SS], (52, 30, 24), (24, 12, 10), radius=6 * SS)
    d = ImageDraw.Draw(img)
    bevel_border(d, [x0, cy - 36 * SS, x1, cy + 36 * SS], 5 * SS, radius=6 * SS)
    d.line([(x0 + 12 * SS, cy - 26 * SS), (x1 - 12 * SS, cy - 26 * SS)], fill=(205, 170, 95, 120), width=2 * SS)
    d.line([(x0 + 12 * SS, cy + 26 * SS), (x1 - 12 * SS, cy + 26 * SS)], fill=(205, 170, 95, 120), width=2 * SS)
    for side in (-1, 1):
        ex = W * SS / 2 + side * (W / 2 - 120) * SS
        lozenge(d, ex, cy, 30 * SS, 5 * SS)
        spiral(d, ex + side * 46 * SS, cy - 14 * SS, 20 * SS, 1.3, math.pi * 0.5, -side, 6 * SS, GOLD)
        spiral(d, ex + side * 46 * SS, cy + 14 * SS, 20 * SS, 1.3, -math.pi * 0.5, side, 6 * SS, GOLD)
        spiral(d, ex + side * 84 * SS, cy, 12 * SS, 1.1, math.pi if side > 0 else 0, side, 4 * SS, GOLD)
    finish(shadow_under(img, blur=4, offset=3), "title_plaque.png")


# ---------------------------------------------------------------- round buttons

def round_frame():
    """A gilded ring for the round combat buttons, with lozenges at the four
    points and cloud curls between them. The face inside is left clear so the
    button's own color shows through."""
    S = 256
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    c = S * SS / 2
    r = 98 * SS
    w = 9 * SS
    d.ellipse([c - r, c - r, c + r, c + r], outline=GOLD_LO, width=w + 4 * SS)
    d.ellipse([c - r + 2 * SS, c - r + 2 * SS, c + r - 2 * SS, c + r - 2 * SS], outline=GOLD, width=w)
    d.arc([c - r + 3 * SS, c - r + 3 * SS, c + r - 3 * SS, c + r - 3 * SS], 200, 300, fill=GOLD_HI, width=3 * SS)
    ri = r - 15 * SS
    d.ellipse([c - ri, c - ri, c + ri, c + ri], outline=(205, 170, 95, 150), width=2 * SS)
    for k in range(4):
        a = k * math.pi / 2 - math.pi / 2
        lozenge(d, c + math.cos(a) * r, c + math.sin(a) * r, 16 * SS, 3 * SS)
    for k in range(4):
        a = k * math.pi / 2 - math.pi / 4
        px, py = c + math.cos(a) * (r + 12 * SS), c + math.sin(a) * (r + 12 * SS)
        spiral(d, px, py, 10 * SS, 1.15, a + math.pi, 1, 4 * SS, GOLD)
    finish(shadow_under(img, blur=5, offset=3), "round_frame.png")




def slot_simple():
    """The light hotbar slot: dark jade panel, one thin gold border and small
    corner diamonds. Same footprint as slot_frame, so either fits the template."""
    S = 256
    img = canvas(S, S)
    m = 30 * SS
    box = [m, m, S * SS - m, S * SS - m]
    gradient_rect(img, box, (26, 40, 42), (10, 15, 18), radius=12 * SS)
    vignette(img, box, strength=120)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=12 * SS, outline=(214, 172, 92, 230), width=4 * SS)
    for x in (m, S * SS - m):
        for y in (m, S * SS - m):
            r = 9 * SS
            d.polygon([(x, y - r), (x + r, y), (x, y + r), (x - r, y)], fill=GOLD)
            d.polygon([(x, y - r / 2.4), (x + r / 2.4, y), (x, y + r / 2.4), (x - r / 2.4, y)], fill=INK)
    finish(img, "slot_simple.png")


def pill(name, top, bottom, rim, inner):
    """A pill button, 512x128. 9-slice with SliceCenter Rect(72, 40, 440, 88):
    the rounded ends and their lozenges stay in the side slices, and the top and
    bottom margins keep Roblox's slicer from clipping the art."""
    W, H = 512, 128
    img = canvas(W, H)
    m = 10 * SS
    box = [m, m, W * SS - m, H * SS - m]
    r = (H * SS - 2 * m) // 2
    gradient_rect(img, box, top, bottom, radius=r)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=r, outline=GOLD_LO, width=7 * SS)
    d.rounded_rectangle([m + 2 * SS, m + 2 * SS, W * SS - m - 2 * SS, H * SS - m - 2 * SS], radius=r, outline=rim, width=4 * SS)
    i = 14 * SS
    d.rounded_rectangle([m + i, m + i, W * SS - m - i, H * SS - m - i], radius=r - i, outline=inner, width=2 * SS)
    gloss = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(gloss).rounded_rectangle([m + 24 * SS, m + 10 * SS, W * SS - m - 24 * SS, m + 30 * SS], radius=10 * SS, fill=(255, 255, 255, 34))
    img.alpha_composite(gloss)
    for side in (-1, 1):
        lozenge(d, W * SS / 2 + side * (W / 2 - 40) * SS, H * SS / 2, 11 * SS, 3 * SS)
    finish(img, name)


# ---------------------------------------------------------------- vitals mount

# Windows in the vitals mount, in image pixels (the game lays its fills behind these).
VITALS = {
    "size": (1600, 160),
    "health": (170, 38, 1430, 78),
    "qi": (240, 92, 772, 110),
    "cultivation": (828, 92, 1360, 110),
    "segments": 10,
}


def vitals_frame():
    """The health and qi mount: a gilded lacquer plate with two clear windows the
    bar fills show through, segment marks across the health window, cloud-scroll
    horns at both ends and a ruyi pendant under the middle. Drawn on top of the
    fills, so it also glazes them with a soft highlight."""
    W, H = VITALS["size"]
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    hx0, hy0, hx1, hy1 = [v * SS for v in VITALS["health"]]
    qx0, qy0, qx1, qy1 = [v * SS for v in VITALS["qi"]]
    kx0, ky0, kx1, ky1 = [v * SS for v in VITALS["cultivation"]]
    cx = W * SS / 2

    # pendant under the middle, behind the plate
    tip = [(cx - 70 * SS, 112 * SS), (cx + 70 * SS, 112 * SS), (cx + 26 * SS, 140 * SS), (cx, 154 * SS), (cx - 26 * SS, 140 * SS)]
    d.polygon(tip, fill=GOLD_LO)
    inner = [(cx - 58 * SS, 114 * SS), (cx + 58 * SS, 114 * SS), (cx + 20 * SS, 137 * SS), (cx, 148 * SS), (cx - 20 * SS, 137 * SS)]
    d.polygon(inner, fill=(30, 22, 16, 255))
    for side in (-1, 1):
        spiral(d, cx + side * 34 * SS, 124 * SS, 9 * SS, 1.1, math.pi * 0.5, side, 3 * SS, GOLD)
    lozenge(d, cx, 134 * SS, 8 * SS, 2 * SS)

    # the lacquer plate
    plate = [150 * SS, 26 * SS, (W - 150) * SS, 122 * SS]
    gradient_rect(img, plate, (34, 40, 44), (12, 15, 18), radius=14 * SS)
    d = ImageDraw.Draw(img)
    bevel_border(d, plate, 6 * SS, radius=14 * SS)
    meander_band(d, qx0 - 70 * SS, qx0 - 14 * SS, 101 * SS, 9 * SS, (205, 170, 95, 200), int(1.6 * SS))
    meander_band(d, kx1 + 14 * SS, kx1 + 70 * SS, 101 * SS, 9 * SS, (205, 170, 95, 200), int(1.6 * SS))
    lozenge(d, cx, 101 * SS, 13 * SS, 3 * SS)

    # horns: big cloud scrolls rising off each end
    for side in (-1, 1):
        ex = cx + side * (W / 2 - 150) * SS
        sweep = [(ex, 44 * SS), (ex + side * 44 * SS, 26 * SS), (ex + side * 84 * SS, 38 * SS)]
        d.line(sweep, fill=GOLD_LO, width=15 * SS, joint="curve")
        d.line(sweep, fill=GOLD, width=10 * SS, joint="curve")
        spiral(d, ex + side * 100 * SS, 62 * SS, 32 * SS, 1.4, math.pi if side > 0 else 0, -side, 11 * SS, GOLD_LO)
        spiral(d, ex + side * 100 * SS, 62 * SS, 32 * SS, 1.4, math.pi if side > 0 else 0, -side, 7 * SS, GOLD)
        spiral(d, ex + side * 62 * SS, 108 * SS, 18 * SS, 1.2, -math.pi * 0.5, side, 7 * SS, GOLD)
        spiral(d, ex + side * 126 * SS, 20 * SS, 12 * SS, 1.1, math.pi * 0.5, side, 5 * SS, GOLD)
        lozenge(d, ex, 74 * SS, 20 * SS, 4 * SS)

    # cut the windows, then rim and glaze them
    alpha = img.getchannel("A")
    ad = ImageDraw.Draw(alpha)
    ad.rounded_rectangle([hx0, hy0, hx1, hy1], radius=6 * SS, fill=0)
    ad.rounded_rectangle([qx0, qy0, qx1, qy1], radius=5 * SS, fill=0)
    ad.rounded_rectangle([kx0, ky0, kx1, ky1], radius=5 * SS, fill=0)
    img.putalpha(alpha)
    d = ImageDraw.Draw(img)
    seg = (hx1 - hx0) / VITALS["segments"]
    for i in range(1, VITALS["segments"]):
        x = hx0 + seg * i
        d.line([(x, hy0), (x, hy1)], fill=(10, 14, 16, 230), width=5 * SS)
        d.line([(x + 3 * SS, hy0 + 2 * SS), (x + 3 * SS, hy1 - 2 * SS)], fill=(255, 255, 255, 40), width=1 * SS)
    gloss = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gd.rounded_rectangle([hx0 + 4 * SS, hy0 + 3 * SS, hx1 - 4 * SS, hy0 + 14 * SS], radius=4 * SS, fill=(255, 255, 255, 46))
    for x0, x1 in ((qx0, qx1), (kx0, kx1)):
        gd.rounded_rectangle([x0 + 4 * SS, qy0 + 2 * SS, x1 - 4 * SS, qy0 + 6 * SS], radius=2 * SS, fill=(255, 255, 255, 40))
    img.alpha_composite(gloss)
    d.rounded_rectangle([hx0 - 3 * SS, hy0 - 3 * SS, hx1 + 3 * SS, hy1 + 3 * SS], radius=8 * SS, outline=GOLD, width=3 * SS)
    for x0, x1 in ((qx0, qx1), (kx0, kx1)):
        d.rounded_rectangle([x0 - 3 * SS, qy0 - 3 * SS, x1 + 3 * SS, qy1 + 3 * SS], radius=6 * SS, outline=(205, 170, 95, 220), width=2 * SS)
    finish(shadow_under(img, blur=4, offset=3), "vitals_frame.png")


if __name__ == "__main__":
    pill("pill_lacquer.png", (34, 44, 48), (12, 16, 20), GOLD, (205, 170, 95, 110))
    pill("pill_gold.png", (196, 150, 66), (120, 82, 30), GOLD_HI, (255, 236, 180, 120))
    slot_simple()
    vitals_frame()
    round_frame()
    slot_frame()
    slot_glow()
    slot_select()
    panel_frame()
    title_plaque()
