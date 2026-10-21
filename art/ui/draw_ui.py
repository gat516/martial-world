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
    """A pill button, 512x128. 9-slice with SliceCenter Rect(72, 63, 440, 65) and
    SliceScale ~0.28: the rounded ends are the corners, split at the one row
    where the curve is vertical. Only that row stretches, so nothing ornamental
    may sit on it (the end lozenges used to, and Roblox cropped the ends flat)."""
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


# ---------------------------------------------------------------- window buttons

def plaque_button(name, top, bottom, rim):
    """A rectangular lacquer button for windows (tabs, actions, destinations),
    512x128. 9-slice with SliceCenter Rect(64, 40, 448, 88): no ornament on the
    edges (they stretch), just plain gold rims."""
    W, H = 512, 128
    img = canvas(W, H)
    m = 8 * SS
    box = [m, m, W * SS - m, H * SS - m]
    gradient_rect(img, box, top, bottom, radius=10 * SS)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=10 * SS, outline=GOLD_LO, width=6 * SS)
    d.rounded_rectangle([m + 2 * SS, m + 2 * SS, W * SS - m - 2 * SS, H * SS - m - 2 * SS], radius=9 * SS, outline=rim, width=3 * SS)
    i = 12 * SS
    d.rounded_rectangle([m + i, m + i, W * SS - m - i, H * SS - m - i], radius=4 * SS, outline=(205, 170, 95, 90), width=2 * SS)
    gloss = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(gloss).rectangle([m + 16 * SS, m + 8 * SS, W * SS - m - 16 * SS, m + 24 * SS], fill=(255, 255, 255, 26))
    img.alpha_composite(gloss)
    finish(img, name)


def _seal_face(S, seed):
    """A vermilion seal stamp face on a fresh SxS canvas, its edge nibbled
    like a real chop."""
    import random
    rnd = random.Random(seed)
    img = canvas(S, S)
    m = 14 * SS
    face = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gradient_rect(face, [m, m, S * SS - m, S * SS - m], (196, 52, 38), (134, 26, 20), radius=12 * SS)
    # rough inked edge: nibble the outline
    mask = face.getchannel("A")
    md = ImageDraw.Draw(mask)
    for _ in range(90):
        side = rnd.randrange(4)
        t = rnd.uniform(m, S * SS - m)
        r = rnd.uniform(1.5, 4) * SS
        x, y = [(t, m), (S * SS - m, t), (t, S * SS - m), (m, t)][side]
        md.ellipse([x - r, y - r, x + r, y + r], fill=0)
    face.putalpha(mask)
    img.alpha_composite(face)
    return img


def seal_close():
    """The close button: a vermilion seal stamp, slightly uneven like a real
    chop, with an X cut into it in paper colour. 128px, stretched."""
    S = 128
    img = _seal_face(S, 7)
    d = ImageDraw.Draw(img)
    i = 24 * SS
    d.rounded_rectangle([i, i, S * SS - i, S * SS - i], radius=6 * SS, outline=(246, 226, 196, 200), width=3 * SS)
    paper = (248, 232, 204, 255)
    c0, c1 = 42 * SS, S * SS - 42 * SS
    for a, b in (((c0, c0), (c1, c1)), ((c1, c0), (c0, c1))):
        # a brush stroke: thick in the middle, tapering at both ends
        steps = 24
        for k in range(steps + 1):
            t = k / steps
            x = a[0] + (b[0] - a[0]) * t
            y = a[1] + (b[1] - a[1]) * t
            r = (2.2 + 4.6 * math.sin(math.pi * (0.15 + 0.7 * t))) * SS
            d.ellipse([x - r, y - r, x + r, y + r], fill=paper)
    finish(shadow_under(img, blur=3, offset=2, alpha=140), "seal_close.png")


def seal_mark():
    """The "equipped" stamp on a weapon cell: a small vermilion seal with a thin
    paper inner rim and a blank face (the glyph is a TextLabel on top, so the
    same art can carry other marks). 128px, stretched, shown at ~22px."""
    S = 128
    img = _seal_face(S, 11)
    d = ImageDraw.Draw(img)
    i = 24 * SS
    d.rounded_rectangle([i, i, S * SS - i, S * SS - i], radius=6 * SS, outline=(246, 226, 196, 210), width=4 * SS)
    finish(shadow_under(img, blur=3, offset=2, alpha=140), "seal_mark.png")


def weapon_badge():
    """The weapon-class badge on technique slots and art cells: a round dark
    lacquer disc with a bronze rim and a lit top edge, the class icon drawn on top
    as a child ImageLabel. 128px, stretched, shown at ~22-24px."""
    S = 128
    img = canvas(S, S)
    c = S * SS / 2
    r = 54 * SS
    disc = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gradient_rect(disc, [c - r, c - r, c + r, c + r], (40, 34, 30), (12, 12, 14), radius=r)
    img.alpha_composite(disc)
    d = ImageDraw.Draw(img)
    d.ellipse([c - r, c - r, c + r, c + r], outline=INK, width=4 * SS)
    d.ellipse([c - r + 4 * SS, c - r + 4 * SS, c + r - 4 * SS, c + r - 4 * SS], outline=GOLD, width=6 * SS)
    d.arc([c - r + 4 * SS, c - r + 4 * SS, c + r - 4 * SS, c + r - 4 * SS], 200, 320, fill=GOLD_HI, width=4 * SS)
    d.ellipse([c - r + 12 * SS, c - r + 12 * SS, c + r - 12 * SS, c + r - 12 * SS], outline=GOLD_LO, width=2 * SS)
    finish(shadow_under(img, blur=3, offset=2, alpha=140), "weapon_badge.png")


def weapon_art():
    seal_mark()
    weapon_badge()


def note_panel():
    """A small 9-slice panel for notes and rows (elder line, objective, toast,
    list rows, build bar), 512x256: ink-dark jade, a thin gold rim and a lozenge
    stud in each corner. SliceCenter Rect(64, 64, 448, 192)."""
    W, H = 512, 256
    img = canvas(W, H)
    m = 10 * SS
    box = [m, m, W * SS - m, H * SS - m]
    gradient_rect(img, box, (24, 36, 40), (10, 15, 18), radius=12 * SS)
    vignette(img, box, strength=90, blur=0.12)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=12 * SS, outline=GOLD_LO, width=5 * SS)
    d.rounded_rectangle([m + 2 * SS, m + 2 * SS, W * SS - m - 2 * SS, H * SS - m - 2 * SS], radius=11 * SS, outline=(214, 172, 92, 210), width=2 * SS)
    for x in (m + 22 * SS, W * SS - m - 22 * SS):
        for y in (m + 22 * SS, H * SS - m - 22 * SS):
            lozenge(d, x, y, 8 * SS, 3 * SS)
    finish(img, "note_panel.png")


# ---------------------------------------------------------------- build window

def build_tile():
    """A catalog card for the build window, 256px: dark jade lacquer, a gold rim
    and a lozenge stud in each corner, with a lighter display well up top.
    9-slice with SliceCenter Rect(56, 56, 200, 200), SliceScale ~0.36."""
    S = 256
    img = canvas(S, S)
    m = 8 * SS
    box = [m, m, S * SS - m, S * SS - m]
    gradient_rect(img, box, (34, 52, 54), (12, 18, 22), radius=14 * SS)
    vignette(img, box, strength=80, blur=0.1)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=14 * SS, outline=GOLD_LO, width=5 * SS)
    d.rounded_rectangle([m + 2 * SS, m + 2 * SS, S * SS - m - 2 * SS, S * SS - m - 2 * SS], radius=13 * SS, outline=(214, 172, 92, 200), width=2 * SS)
    for x in (m + 20 * SS, S * SS - m - 20 * SS):
        for y in (m + 20 * SS, S * SS - m - 20 * SS):
            lozenge(d, x, y, 7 * SS, 3 * SS)
    finish(img, "build_tile.png")


def tile_select():
    """The selected-card ring, 256px, white so it can be tinted (gold): a crisp
    rim with a soft glow inside. Same geometry as build_tile, so it uses the same
    SliceCenter Rect(56, 56, 200, 200) and SliceScale."""
    S = 256
    img = canvas(S, S)
    m = 8 * SS
    glow = Image.new("L", img.size, 0)
    ImageDraw.Draw(glow).rounded_rectangle([m, m, S * SS - m, S * SS - m], radius=14 * SS, outline=255, width=12 * SS)
    glow = glow.filter(ImageFilter.GaussianBlur(7 * SS))
    clip = Image.new("L", img.size, 0)
    ImageDraw.Draw(clip).rounded_rectangle([m, m, S * SS - m, S * SS - m], radius=14 * SS, fill=255)
    from PIL import ImageChops

    glow = ImageChops.multiply(glow, clip).point(lambda v: v * 150 // 255)
    rim = Image.new("L", img.size, 0)
    ImageDraw.Draw(rim).rounded_rectangle([m, m, S * SS - m, S * SS - m], radius=14 * SS, outline=255, width=5 * SS)
    mask = ImageChops.lighter(glow, rim)
    white = Image.new("RGBA", img.size, (255, 255, 255, 255))
    white.putalpha(mask)
    finish(white, "tile_select.png")


def field_inset():
    """A recessed text field (search box), 512x128: near-black well, an inner
    shadow along the top and a thin bronze rim. 9-slice with SliceCenter
    Rect(48, 48, 464, 80), SliceScale ~0.28."""
    W, H = 512, 128
    img = canvas(W, H)
    m = 8 * SS
    box = [m, m, W * SS - m, H * SS - m]
    gradient_rect(img, box, (6, 9, 11), (16, 22, 25), radius=12 * SS)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=12 * SS, outline=(120, 92, 48, 255), width=4 * SS)
    d.rounded_rectangle([m + 4 * SS, m + 4 * SS, W * SS - m - 4 * SS, H * SS - m - 4 * SS], radius=9 * SS, outline=(0, 0, 0, 120), width=3 * SS)
    finish(img, "field_inset.png")


def stone_icon():
    """A spirit stone, 128px: a pale jade hexagonal crystal with facets, an ink
    outline and one highlight. Stretched, used at 16-24px beside prices."""
    S = 128
    N = S * SS
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    cx = N / 2
    top, bot = 14 * SS, 114 * SS
    wl, wr = 22 * SS, 106 * SS
    sh = 38 * SS  # shoulder height from the tips
    outline = [(cx, top), (wr, top + sh), (wr, bot - sh), (cx, bot), (wl, bot - sh), (wl, top + sh)]
    d = ImageDraw.Draw(img)
    d.polygon(outline, fill=INK)
    k = 6 * SS
    inner = [(cx, top + k), (wr - k, top + sh + 2 * SS), (wr - k, bot - sh - 2 * SS), (cx, bot - k), (wl + k, bot - sh - 2 * SS), (wl + k, top + sh + 2 * SS)]
    # facets: left face light, right face mid, centre ridge pale
    a, b, c, e, f, g = inner
    mid_t = (cx, top + sh + 6 * SS)
    mid_b = (cx, bot - sh - 6 * SS)
    d.polygon([a, g, f, e, mid_b, mid_t], fill=(196, 238, 214, 255))
    d.polygon([a, b, c, e, mid_b, mid_t], fill=(104, 186, 150, 255))
    d.polygon([g, mid_t, mid_b, f], fill=(150, 220, 186, 255))
    d.polygon([mid_t, b, c, mid_b], fill=(70, 150, 118, 255))
    d.line([mid_t, mid_b], fill=(236, 252, 244, 255), width=2 * SS)
    # highlight
    hx = wl + k + 8 * SS
    d.polygon([(hx, top + sh + 4 * SS), (cx - 10 * SS, top + k + 14 * SS), (cx - 6 * SS, top + k + 20 * SS), (hx + 5 * SS, top + sh + 10 * SS)], fill=(255, 255, 255, 230))
    finish(shadow_under(img, blur=3, offset=2, alpha=120), "stone_icon.png")


def build_art():
    plaque_button("button_jade.png", (62, 150, 112), (22, 82, 60), GOLD_HI)
    plaque_button("button_red.png", (170, 46, 36), (96, 20, 16), GOLD)
    build_tile()
    tile_select()
    field_inset()
    stone_icon()


# ---------------------------------------------------------------- garden, build modes

def chip():
    """A small stadium chip for tags and badges (mutations on plant cards,
    benefit badges on build tiles), 256x64: a near-black fill and a white rim,
    so ImageColor3 tints the rim (the fill stays dark). 9-slice with SliceCenter
    Rect(32, 31, 224, 33), SliceScale ~0.26 for a 16-18px chip: the round ends
    are the corners, split at the vertical centre row."""
    W, H = 256, 64
    img = canvas(W, H)
    m = 3 * SS
    r = (H * SS - 2 * m) // 2
    box = [m, m, W * SS - m, H * SS - m]
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=r, fill=(14, 18, 20, 225))
    d.rounded_rectangle(box, radius=r, outline=(255, 255, 255, 255), width=4 * SS)
    gloss = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(gloss).rounded_rectangle([m + 16 * SS, m + 6 * SS, W * SS - m - 16 * SS, m + 14 * SS], radius=4 * SS, fill=(255, 255, 255, 30))
    img.alpha_composite(gloss)
    finish(img, "chip.png")


def _icon_finish(shape, name):
    """Turn a white silhouette mask (L, at SS) into a cream-gold icon with a
    soft top light, an ink outline and a drop shadow."""
    N = shape.size[0]
    outline = shape.filter(ImageFilter.MaxFilter(4 * SS + 1))
    img = Image.new("RGBA", shape.size, (0, 0, 0, 0))
    ink = Image.new("RGBA", shape.size, INK)
    img.paste(ink, (0, 0), outline)
    grad = Image.new("RGBA", shape.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    top, bot = (255, 240, 200), (214, 164, 84)
    for y in range(N):
        t = y / N
        gd.line([(0, y), (N, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    img.paste(grad, (0, 0), shape)
    finish(shadow_under(img, blur=3, offset=2, alpha=120), name)


def icon_move():
    """Mode tab icon, 128px: four arrows out from a centre (move a piece)."""
    N = 128 * SS
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    c = N / 2
    arm = 7 * SS  # half-width of the shafts
    d.rectangle([c - arm, 30 * SS, c + arm, N - 30 * SS], fill=255)
    d.rectangle([30 * SS, c - arm, N - 30 * SS, c + arm], fill=255)
    head = 17 * SS
    tip = 10 * SS
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        tx, ty = c + dx * (c - tip), c + dy * (c - tip)
        bx, by = c + dx * (c - tip - head * 1.3), c + dy * (c - tip - head * 1.3)
        px, py = -dy, dx
        d.polygon([(tx, ty), (bx + px * head, by + py * head), (bx - px * head, by - py * head)], fill=255)
    d.ellipse([c - 13 * SS, c - 13 * SS, c + 13 * SS, c + 13 * SS], fill=255)
    _icon_finish(m, "icon_move.png")


def icon_store():
    """Mode tab icon, 128px: a lidded storage chest (put a piece away)."""
    N = 128 * SS
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([18 * SS, 30 * SS, N - 18 * SS, 56 * SS], radius=8 * SS, fill=255)  # lid
    d.rounded_rectangle([22 * SS, 62 * SS, N - 22 * SS, N - 20 * SS], radius=6 * SS, fill=255)  # body
    # clasp: a notch cut through lid and body
    d.rectangle([N / 2 - 9 * SS, 46 * SS, N / 2 + 9 * SS, 76 * SS], fill=0)
    d.rounded_rectangle([N / 2 - 5 * SS, 50 * SS, N / 2 + 5 * SS, 72 * SS], radius=3 * SS, fill=255)
    _icon_finish(m, "icon_store.png")


def icon_sort():
    """Sort and filter button icon (Inventory Arts and Weapons tabs), 128px:
    three brush bars that shorten downward, with a small downward arrow."""
    N = 128 * SS
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    h = 13 * SS  # bar thickness
    for i, length in enumerate((76, 56, 36)):
        y = (30 + i * 28) * SS
        d.rounded_rectangle([18 * SS, y - h / 2, (18 + length) * SS, y + h / 2], radius=h / 2, fill=255)
    x = 104 * SS
    d.rectangle([x - 5 * SS, 24 * SS, x + 5 * SS, 84 * SS], fill=255)
    d.polygon([(x - 17 * SS, 76 * SS), (x + 17 * SS, 76 * SS), (x, 104 * SS)], fill=255)
    _icon_finish(m, "icon_sort.png")


def key_cap():
    """The key cap on world prompts, 128x128: an ivory key with a bronze rim and
    a deeper bottom lip, so it reads as a key to press. The letter (or a gamepad
    glyph) goes on top in ink. Not sliced: ScaleType Fit at a fixed size."""
    S = 128
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    m = 12 * SS
    r = 22 * SS
    lip = 7 * SS
    # the key's body (seen as a lip under the face)
    d.rounded_rectangle([m, m + lip, S * SS - m, S * SS - m], radius=r, fill=(92, 62, 26, 255))
    d.rounded_rectangle([m, m, S * SS - m, S * SS - m - lip], radius=r, fill=GOLD_LO)
    # the face: a warm ivory with a soft top light
    i = 5 * SS
    face = [m + i, m + i, S * SS - m - i, S * SS - m - lip - i]
    gradient_rect(img, face, (255, 248, 226), (226, 206, 160), radius=r - i)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([m + 2 * SS, m + 2 * SS, S * SS - m - 2 * SS, S * SS - m - lip - 2 * SS], radius=r - 2 * SS, outline=GOLD, width=3 * SS)
    gloss = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(gloss).rounded_rectangle([face[0] + 8 * SS, face[1] + 4 * SS, face[2] - 8 * SS, face[1] + 16 * SS], radius=6 * SS, fill=(255, 255, 255, 90))
    img.alpha_composite(gloss)
    finish(shadow_under(img, blur=3, offset=2, alpha=140), "key_cap.png")


def self_icon():
    """The Self tile icon (character window), 128px: a cultivator's bust, a topknot
    with a hairpin over the head and a cross-collared robe on the shoulders. Near
    white with a soft top light, an ink outline and one highlight, tinted in Studio
    through ImageColor3 like the other tile icons (gear_icon). ScaleType Fit."""
    S = 128
    N = S * SS
    c = N / 2
    u = SS
    mask = Image.new("L", (N, N), 0)
    md = ImageDraw.Draw(mask)
    # robe: broad rounded shoulders down to the bottom edge
    md.rounded_rectangle([14 * u, 78 * u, N - 14 * u, 122 * u], radius=28 * u, fill=255)
    md.rectangle([14 * u, 104 * u, N - 14 * u, 122 * u], fill=255)
    # neck and head
    md.rectangle([c - 9 * u, 62 * u, c + 9 * u, 84 * u], fill=255)
    hr = 22 * u
    hy = 50 * u
    md.ellipse([c - hr, hy - hr, c + hr, hy + hr], fill=255)
    # topknot bun
    br = 10 * u
    by = 24 * u
    md.ellipse([c - br, by - br, c + br, by + br], fill=255)
    # the hairpin crosses the bun and pokes out both sides
    ImageDraw.Draw(mask).line([(c - 19 * u, 31 * u), (c + 19 * u, 17 * u)], fill=255, width=4 * u)
    outline = mask.filter(ImageFilter.MaxFilter(4 * SS + 1))
    img = Image.new("RGBA", (N, N), INK[:3] + (0,))
    img.putalpha(outline)
    face = canvas(S, S)
    gradient_rect(face, [0, 0, N, N], (255, 255, 255), (196, 200, 204))
    face.putalpha(mask)
    img.alpha_composite(face)
    d = ImageDraw.Draw(img)
    groove = (120, 126, 130, 255)
    # cross collar: left lapel over right, meeting below the neck
    d.line([(c - 16 * u, 82 * u), (c + 6 * u, 108 * u)], fill=groove, width=4 * u)
    d.line([(c + 16 * u, 82 * u), (c + 1 * u, 100 * u)], fill=groove, width=4 * u)
    # chin line under the head, so head and robe read apart
    d.arc([c - hr, hy - hr, c + hr, hy + hr], 30, 150, fill=groove, width=3 * u)
    # one highlight on the head
    d.arc([c - hr + 5 * u, hy - hr + 5 * u, c + hr - 5 * u, hy + hr - 5 * u], 200, 255, fill=(255, 255, 255, 255), width=4 * u)
    finish(img, "self_icon.png")


def prompt_art():
    key_cap()


def garden_art():
    chip()
    icon_move()
    icon_store()


# ---------------------------------------------------------------- meditation menu icons

def _tile_icon(mask, name, decorate=None):
    """Finish a 128px tile icon from a white silhouette mask (L, at SS) the way
    self_icon does: near white with a soft top light and an ink outline, tinted in
    Studio through ImageColor3. `decorate(d, u)` draws grooves and the one
    highlight on top. ScaleType Fit."""
    N = mask.size[0]
    S = N // SS
    outline = mask.filter(ImageFilter.MaxFilter(4 * SS + 1))
    img = Image.new("RGBA", (N, N), INK[:3] + (0,))
    img.putalpha(outline)
    face = canvas(S, S)
    gradient_rect(face, [0, 0, N, N], (255, 255, 255), (196, 200, 204))
    face.putalpha(mask)
    img.alpha_composite(face)
    if decorate:
        decorate(ImageDraw.Draw(img), SS)
    finish(img, name)


GROOVE = (120, 126, 130, 255)
SHINE = (255, 255, 255, 255)


def icon_circulate():
    """Meditation menu: Circulate. Three qi streams chasing round a still centre,
    each a tapering arc with a round head."""
    N = 128 * SS
    u = SS
    c = N / 2
    mask = Image.new("L", (N, N), 0)
    md = ImageDraw.Draw(mask)
    r = 38 * u
    for k in range(3):
        a0 = k * 120 - 90
        # the stream: a run of discs that swell toward a round head
        steps = 60
        for i in range(steps + 1):
            t = i / steps
            a = math.radians(a0 + t * 80)
            w = (2.5 + 5 * t) * u
            x, y = c + math.cos(a) * r, c + math.sin(a) * r
            md.ellipse([x - w, y - w, x + w, y + w], fill=255)
        a = math.radians(a0 + 80)
        x, y = c + math.cos(a) * r, c + math.sin(a) * r
        md.ellipse([x - 10 * u, y - 10 * u, x + 10 * u, y + 10 * u], fill=255)
    md.ellipse([c - 11 * u, c - 11 * u, c + 11 * u, c + 11 * u], fill=255)

    def deco(d, u):
        d.arc([c - 7 * u, c - 7 * u, c + 7 * u, c + 7 * u], 200, 290, fill=SHINE, width=3 * u)
    _tile_icon(mask, "icon_circulate.png", deco)


def icon_breakthrough():
    """Meditation menu: Break Through. A bold arrow bursting up through a broken
    barrier, two short rays beside its head."""
    N = 128 * SS
    u = SS
    c = N / 2
    mask = Image.new("L", (N, N), 0)
    md = ImageDraw.Draw(mask)
    # the barrier, broken in the middle
    md.rounded_rectangle([12 * u, 78 * u, c - 20 * u, 92 * u], radius=5 * u, fill=255)
    md.rounded_rectangle([c + 20 * u, 78 * u, N - 12 * u, 92 * u], radius=5 * u, fill=255)
    md.polygon([(c - 20 * u, 78 * u), (c - 12 * u, 70 * u), (c - 14 * u, 92 * u)], fill=255)
    md.polygon([(c + 20 * u, 78 * u), (c + 12 * u, 70 * u), (c + 14 * u, 92 * u)], fill=255)
    # the arrow
    md.rectangle([c - 9 * u, 46 * u, c + 9 * u, 114 * u], fill=255)
    md.polygon([(c, 10 * u), (c - 28 * u, 50 * u), (c + 28 * u, 50 * u)], fill=255)
    # rays
    for sx in (-1, 1):
        md.line([(c + sx * 34 * u, 30 * u), (c + sx * 46 * u, 20 * u)], fill=255, width=6 * u)
        md.line([(c + sx * 38 * u, 50 * u), (c + sx * 52 * u, 48 * u)], fill=255, width=6 * u)

    def deco(d, u):
        d.line([(c - 3 * u, 24 * u), (c - 16 * u, 44 * u)], fill=SHINE, width=3 * u)
    _tile_icon(mask, "icon_breakthrough.png", deco)


def icon_comprehend():
    """Meditation menu: Comprehend (break a technique's bottleneck). A calabash
    gourd, its narrow neck cracking open, with sparks escaping the mouth."""
    N = 128 * SS
    u = SS
    c = N / 2
    mask = Image.new("L", (N, N), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([c - 36 * u, 52 * u, c + 36 * u, 122 * u], fill=255)  # belly
    md.ellipse([c - 20 * u, 26 * u, c + 20 * u, 64 * u], fill=255)  # upper bulb
    md.rectangle([c - 9 * u, 52 * u, c + 9 * u, 64 * u], fill=255)  # waist
    md.rounded_rectangle([c - 6 * u, 18 * u, c + 6 * u, 30 * u], radius=3 * u, fill=255)  # mouth
    # sparks out of the mouth: three short rays, apart from it
    for ang in (-50, -90, -130):
        a = math.radians(ang)
        x0, y0 = c + math.cos(a) * 12 * u, 12 * u + math.sin(a) * 2 * u
        md.line([(x0, y0), (x0 + math.cos(a) * 9 * u, y0 + math.sin(a) * 9 * u)], fill=255, width=4 * u)

    def deco(d, u):
        # the crack across the waist
        d.line([(c - 14 * u, 52 * u), (c - 4 * u, 58 * u), (c - 8 * u, 64 * u), (c + 4 * u, 70 * u), (c + 2 * u, 76 * u)], fill=GROOVE, width=4 * u, joint="curve")
        d.arc([c - 30 * u, 58 * u, c + 30 * u, 116 * u], 200, 250, fill=SHINE, width=4 * u)
    _tile_icon(mask, "icon_comprehend.png", deco)


def icon_method():
    """Meditation menu: Method (cultivation methods). An open scroll between two
    rollers, three columns of script on it."""
    N = 128 * SS
    u = SS
    mask = Image.new("L", (N, N), 0)
    md = ImageDraw.Draw(mask)
    md.rectangle([26 * u, 30 * u, N - 26 * u, 98 * u], fill=255)  # the sheet
    for x in (20, N // SS - 20):
        md.rounded_rectangle([(x - 9) * u, 20 * u, (x + 9) * u, 108 * u], radius=6 * u, fill=255)
        md.rounded_rectangle([(x - 4) * u, 12 * u, (x + 4) * u, 116 * u], radius=3 * u, fill=255)

    def deco(d, u):
        for x in (48, 64, 80):
            d.line([(x * u, 42 * u), (x * u, 86 * u)], fill=GROOVE, width=4 * u)
        for x in (20, N // SS - 20):
            d.line([((x - 9) * u, 30 * u), ((x + 9) * u, 30 * u)], fill=GROOVE, width=2 * u)
            d.line([((x - 9) * u, 98 * u), ((x + 9) * u, 98 * u)], fill=GROOVE, width=2 * u)
        d.line([(16 * u, 34 * u), (16 * u, 60 * u)], fill=SHINE, width=3 * u)
    _tile_icon(mask, "icon_method.png", deco)


def icon_rise():
    """Meditation menu: Rise (stand up). A double chevron lifting off a round
    meditation cushion."""
    N = 128 * SS
    u = SS
    c = N / 2
    mask = Image.new("L", (N, N), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([18 * u, 92 * u, N - 18 * u, 120 * u], fill=255)  # cushion
    for top in (14, 44):
        w = 14 * u
        pts = [(c - 36 * u, (top + 34) * u), (c, top * u), (c + 36 * u, (top + 34) * u)]
        md.line(pts, fill=255, width=w, joint="curve")
        for x, y in (pts[0], pts[2]):
            md.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=255)
        md.ellipse([c - w / 2, top * u - w / 2 + 2 * u, c + w / 2, top * u + w / 2 + 2 * u], fill=255)

    def deco(d, u):
        d.arc([20 * u, 94 * u, N - 20 * u, 118 * u], 190, 250, fill=SHINE, width=3 * u)
        d.line([(30 * u, 106 * u), (N - 30 * u, 106 * u)], fill=GROOVE, width=2 * u)
    _tile_icon(mask, "icon_rise.png", deco)


def icon_lotus():
    """The calm-view toggle while meditating: a lotus. A tall middle petal, two
    leaning beside it and two low outer ones on a flat pad, drawn back to front,
    each with its own ink edge so the petals read apart."""
    from PIL import ImageChops
    N = 128 * SS
    u = SS
    c = N / 2
    base = 98 * u

    def petal(length, width, angle):
        layer = Image.new("L", (N, N), 0)
        ImageDraw.Draw(layer).polygon(_petal_points(c, base, length, width), fill=255)
        return layer.rotate(angle, resample=Image.BICUBIC, center=(c, base))

    shapes = [petal(44 * u, 15 * u, a) for a in (66, -66)]
    shapes += [petal(60 * u, 17 * u, a) for a in (32, -32)]
    shapes.append(petal(76 * u, 19 * u, 0))
    pad = Image.new("L", (N, N), 0)
    ImageDraw.Draw(pad).rounded_rectangle([18 * u, 96 * u, N - 18 * u, 110 * u], radius=7 * u, fill=255)
    shapes.append(pad)
    grad = canvas(128, 128)
    gradient_rect(grad, [0, 0, N, N], (255, 255, 255), (196, 200, 204))
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    edge = 4 * SS + 1
    for shape in shapes:
        ink = Image.new("RGBA", (N, N), INK[:3] + (255,))
        img.paste(ink, (0, 0), shape.filter(ImageFilter.MaxFilter(edge)))
        img.paste(grad, (0, 0), shape)
    d = ImageDraw.Draw(img)
    d.line([(c - 4 * u, 40 * u), (c - 7 * u, 70 * u)], fill=SHINE, width=3 * u)
    finish(img, "icon_lotus.png")


def _petal_points(cx, base_y, length, width):
    """A pointed petal standing up from (cx, base_y)."""
    pts = []
    steps = 24
    for i in range(steps + 1):
        t = i / steps
        y = base_y - t * length
        w = width * math.sin(math.pi * min(1.0, t * 1.04)) ** 0.55
        pts.append((cx + w, y))
    for i in range(steps, -1, -1):
        t = i / steps
        y = base_y - t * length
        w = width * math.sin(math.pi * min(1.0, t * 1.04)) ** 0.55
        pts.append((cx - w, y))
    return pts


def icon_practice():
    """Meditation menu: Practice Dao (a weapon drill). Two jian crossed point up,
    guards and pommels clear of each other, a fuller groove down each blade."""
    N = 128 * SS
    u = SS
    c = N / 2
    mask = Image.new("L", (N, N), 0)

    def blade(angle):
        layer = Image.new("L", (N, N), 0)
        ld = ImageDraw.Draw(layer)
        # drawn upright about the centre, then rotated
        ld.polygon([(c, 2 * u), (c - 10 * u, 18 * u), (c - 10 * u, 84 * u), (c + 10 * u, 84 * u), (c + 10 * u, 18 * u)], fill=255)
        ld.rounded_rectangle([c - 24 * u, 82 * u, c + 24 * u, 94 * u], radius=6 * u, fill=255)  # guard
        ld.rectangle([c - 6 * u, 92 * u, c + 6 * u, 112 * u], fill=255)  # grip
        ld.ellipse([c - 10 * u, 106 * u, c + 10 * u, 126 * u], fill=255)  # pommel
        return layer.rotate(angle, resample=Image.BICUBIC, center=(c, c))

    for a in (38, -38):
        mask.paste(255, (0, 0), blade(a))

    def deco(d, u):
        d.line([(c - 30 * u, 30 * u), (c - 40 * u, 42 * u)], fill=SHINE, width=3 * u)
    _tile_icon(mask, "icon_practice.png", deco)


def icon_back():
    """Seated Practice sub-row: Back (to the main row). A return arrow: a thick
    stroke running left along the top into a broad arrowhead, its tail curving
    round the right side and back along the bottom."""
    N = 128 * SS
    u = SS
    mask = Image.new("L", (N, N), 0)
    md = ImageDraw.Draw(mask)
    w = 16 * u
    top, bot = 40 * u, 100 * u
    r = (bot - top) / 2
    cx = 82 * u  # centre of the turn
    # the turn: a half ring on the right
    md.arc([cx - r - w / 2, top - w / 2, cx + r + w / 2, bot + w / 2], 270, 90, fill=255, width=int(w))
    # the top run to the arrowhead, the bottom run back left
    md.rectangle([40 * u, top - w / 2, cx, top + w / 2], fill=255)
    md.rectangle([34 * u, bot - w / 2, cx, bot + w / 2], fill=255)
    md.ellipse([34 * u - w / 2, bot - w / 2, 34 * u + w / 2, bot + w / 2], fill=255)
    # the arrowhead, pointing left
    md.polygon([(10 * u, top), (46 * u, top - 28 * u), (46 * u, top + 28 * u)], fill=255)

    def deco(d, u):
        d.arc([cx - r + 2 * u, top + 4 * u, cx + r - 2 * u, bot - 4 * u], 290, 340, fill=SHINE, width=3 * u)
        d.line([(50 * u, top - 3 * u), (74 * u, top - 3 * u)], fill=SHINE, width=3 * u)
    _tile_icon(mask, "icon_back.png", deco)


def meditation_art():
    icon_circulate()
    icon_breakthrough()
    icon_comprehend()
    icon_method()
    icon_rise()
    icon_lotus()
    icon_practice()
    icon_back()


# ---------------------------------------------------------------- onboarding guide

def guide_hole():
    """The spotlight cut-out of the onboarding dim, 128px: an ink-jade veil all
    round a soft rounded hole, with a faint warm halo at the hole's edge. The
    alpha only depends on the distance to the centre square, so every edge strip
    is identical along its length. 9-slice SliceCenter Rect(48, 48, 80, 80),
    SliceScale 0.5; tinted to the dim's transparency with ImageTransparency."""
    S = 128
    N = S * SS
    lo, hi = 48 * SS, 80 * SS
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    px = img.load()
    for y in range(N):
        dy = max(lo - y, 0, y - hi)
        for x in range(N):
            dx = max(lo - x, 0, x - hi)
            dist = math.hypot(dx, dy) / SS
            t = min(1.0, max(0.0, (dist - 4) / 36))
            a = t * t * (3 - 2 * t)
            # a warm halo hugging the hole
            h = max(0.0, 1 - abs(dist - 7) / 5) * 0.55
            r = int(10 + (232 - 10) * h)
            g = int(16 + (190 - 16) * h)
            b = int(20 + (110 - 20) * h)
            px[x, y] = (r, g, b, int(255 * max(a, h * 0.8)))
    finish(img, "guide_hole.png")


def guide_arrow():
    """The guide's pointer, 128px, pointing right (rotated in script): a gold
    arrowhead with a jade core, ink outline and soft top light. Used at the
    screen edge for an off-screen target and, turned down, as the marker over
    the target. Stretched, shown at ~36-44px."""
    N = 128 * SS
    shape = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(shape)
    c = N / 2
    d.polygon([(c + 54 * SS, c), (c - 40 * SS, c - 50 * SS), (c - 20 * SS, c), (c - 40 * SS, c + 50 * SS)], fill=255)
    outline = shape.filter(ImageFilter.MaxFilter(5 * SS + 1))
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    img.paste(Image.new("RGBA", (N, N), INK), (0, 0), outline)
    grad = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    top, bot = (255, 236, 180), (200, 146, 62)
    for y in range(N):
        t = y / N
        gd.line([(0, y), (N, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    img.paste(grad, (0, 0), shape)
    core = Image.new("L", (N, N), 0)
    ImageDraw.Draw(core).polygon([(c + 26 * SS, c), (c - 18 * SS, c - 24 * SS), (c - 9 * SS, c), (c - 18 * SS, c + 24 * SS)], fill=255)
    img.paste(Image.new("RGBA", (N, N), (64, 156, 120, 255)), (0, 0), core)
    hl = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(hl).line([(c - 32 * SS, c - 38 * SS), (c + 32 * SS, c - 7 * SS)], fill=(255, 250, 230, 150), width=3 * SS)
    img.alpha_composite(hl)
    finish(shadow_under(img, blur=3, offset=2, alpha=130), "guide_arrow.png")


def guide_trail():
    """The walking path's beam texture, 256x64, tiling along its length (U):
    soft white chevrons pointing toward the target, tinted by the Beam's Color.
    A glow under each chevron keeps it readable on bright ground."""
    W, H = 256, 64
    img = canvas(W, H)
    glow = canvas(W, H)
    gd = ImageDraw.Draw(glow)
    d = ImageDraw.Draw(img)
    for i in range(2):
        x = (i * 128 + 64) * SS
        pts = [(x - 18 * SS, 10 * SS), (x + 14 * SS, 32 * SS), (x - 18 * SS, 54 * SS)]
        gd.line(pts, fill=(255, 255, 255, 120), width=22 * SS, joint="curve")
        d.line(pts, fill=(255, 255, 255, 255), width=9 * SS, joint="curve")
    glow = glow.filter(ImageFilter.GaussianBlur(8 * SS))
    glow.alpha_composite(img)
    finish(glow, "guide_trail.png")


def guide_art():
    guide_hole()
    guide_arrow()
    guide_trail()


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "guide":
        guide_art()
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "back":
        icon_back()
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "meditation":
        meditation_art()
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "self":
        self_icon()
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "garden":
        garden_art()
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "prompt":
        prompt_art()
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "weapons":
        weapon_art()
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "sort":
        icon_sort()
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "build":
        build_art()
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "window":
        plaque_button("button_lacquer.png", (36, 50, 54), (12, 18, 22), GOLD)
        plaque_button("button_gold.png", (190, 146, 64), (112, 76, 28), GOLD_HI)
        seal_close()
        note_panel()
        sys.exit()
    plaque_button("button_lacquer.png", (36, 50, 54), (12, 18, 22), GOLD)
    plaque_button("button_gold.png", (190, 146, 64), (112, 76, 28), GOLD_HI)
    seal_close()
    note_panel()
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
