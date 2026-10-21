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


# ---------------------------------------------------------------- maze formation

def _radial(S, profile):
    """A square image whose colour depends only on the distance from its centre
    (0 at the centre, 1 at the edge): profile(r) -> (r, g, b, a)."""
    N = S * SS
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    px = img.load()
    c = (N - 1) / 2
    for y in range(N):
        for x in range(N):
            r = math.hypot(x - c, y - c) / (N / 2)
            if r < 1:
                px[x, y] = tuple(int(max(0, min(255, v))) for v in profile(r))
    return img


def _mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(len(a)))


def maze_wall():
    """A formation wall, 128px: an engraved gold line (bright crest, bronze edge)
    in the middle 40% of the width, with a faint warm aura beyond it. Radially
    symmetric, so one image slices into horizontal and vertical walls alike and
    the round caps meet as rounded joints. 9-slice SliceCenter Rect(63, 63, 65, 65);
    SliceScale = shown thickness / 128 (set by Maze.luau from the board size)."""
    CORE = 0.4

    def profile(r):
        if r < CORE:
            t = r / CORE
            col = _mix((255, 236, 184), (196, 150, 70), t ** 1.6)
            a = 255 if t < 0.82 else 255 * (1 - (t - 0.82) / 0.18 * 0.35)
            return col + (a,)
        t = (r - CORE) / (1 - CORE)
        return (214, 172, 92, 120 * (1 - t) ** 2.2)

    finish(_radial(128, profile), "maze_wall.png")


def maze_trail():
    """The qi trail through walked corridors, 128px: a bright mint-white core
    fading to jade, wrapped in a soft jade glow. Radially symmetric like
    maze_wall. 9-slice SliceCenter Rect(63, 63, 65, 65); SliceScale = shown
    thickness / 128."""
    CORE = 0.5

    def profile(r):
        if r < CORE:
            t = r / CORE
            col = _mix((240, 255, 248), (88, 214, 170), t ** 1.4)
            return col + (255,)
        t = (r - CORE) / (1 - CORE)
        return _mix((88, 214, 170), (40, 150, 120), t) + (150 * (1 - t) ** 2,)

    finish(_radial(128, profile), "maze_trail.png")


def maze_spark():
    """The player's qi spark, 128px, stretched: a white-hot core in a jade orb,
    two qi wisps curling round it (taiji-like) and a wide soft halo."""
    def profile(r):
        if r < 0.16:
            return (255, 255, 250, 255)
        if r < 0.42:
            t = (r - 0.16) / 0.26
            return _mix((236, 255, 246), (96, 220, 176), t ** 1.2) + (255 - 40 * t,)
        t = (r - 0.42) / 0.58
        return (120, 230, 190, 170 * (1 - t) ** 2)

    img = _radial(128, profile)
    N = img.size[0]
    c = N / 2
    wisp = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(wisp)
    for start in (0.0, math.pi):
        pts = []
        for i in range(40):
            t = i / 39
            a = start + t * math.pi * 0.9
            rr = (0.5 - 0.08 * t) * c
            pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
        d.line(pts, fill=(235, 255, 245, 230), width=5 * SS, joint="curve")
        ex, ey = pts[0]
        d.ellipse([ex - 4 * SS, ey - 4 * SS, ex + 4 * SS, ey + 4 * SS], fill=(255, 255, 250, 255))
    img.alpha_composite(wisp.filter(ImageFilter.GaussianBlur(1.2 * SS)))
    finish(img, "maze_spark.png")


def maze_exit():
    """The formation's way out, 128px, stretched (spun slowly in script): a gold
    seal ring with eight trigram-like bars round a warm light, the gate the qi
    escapes through."""
    def profile(r):
        if r < 0.5:
            return (255, 226, 150, 150 * (1 - r / 0.5) ** 1.5 + 30)
        return (255, 210, 120, 40 * max(0, 1 - (r - 0.5) / 0.5))

    img = _radial(128, profile)
    N = img.size[0]
    c = N / 2
    d = ImageDraw.Draw(img)
    for rad, w in ((0.84, 5), (0.6, 3)):
        rr = rad * c
        d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=GOLD_LO, width=(w + 2) * SS)
        d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=GOLD, width=w * SS)
    # the eight trigrams between the rings, bottom line innermost
    trigrams = ["111", "011", "101", "001", "110", "010", "100", "000"]
    for k, bits in enumerate(trigrams):
        a = -math.pi / 2 + k * math.pi / 4
        ca, sa = math.cos(a), math.sin(a)
        for j, bit in enumerate(bits):
            rr = (0.665 + 0.05 * j) * c
            half = 0.1 * c
            segs = [(-half, half)] if bit == "1" else [(-half, -0.025 * c), (0.025 * c, half)]
            for lo, hi in segs:
                p0 = (c + ca * rr - sa * lo, c + sa * rr + ca * lo)
                p1 = (c + ca * rr - sa * hi, c + sa * rr + ca * hi)
                d.line([p0, p1], fill=GOLD_HI, width=int(2.5 * SS))
    lozenge(d, c, c, 14 * SS, 3 * SS)
    finish(img, "maze_exit.png")


def maze_impurity():
    """A purple impurity, 128px, stretched: a lumpy violet miasma knot with a
    near-black core, ink rim and one pale glint."""
    N = 128 * SS
    c = N / 2
    shape = Image.new("L", (N, N), 0)
    pts = []
    for i in range(96):
        a = i / 96 * 2 * math.pi
        rr = c * (0.62 + 0.07 * math.sin(a * 5 + 0.6) + 0.04 * math.sin(a * 3 - 1.1))
        pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
    ImageDraw.Draw(shape).polygon(pts, fill=255)
    glow = shape.filter(ImageFilter.GaussianBlur(10 * SS)).point(lambda v: v * 110 // 255)
    img = Image.new("RGBA", (N, N), (190, 110, 240, 0))
    img.putalpha(glow)
    rim = shape.filter(ImageFilter.MaxFilter(4 * SS + 1))
    img.paste(Image.new("RGBA", (N, N), (28, 8, 36, 255)), (0, 0), rim)
    body = _radial(128, lambda r: _mix((40, 10, 52), (196, 108, 236), min(1, r / 0.66) ** 1.3) + (255,))
    img.paste(body, (0, 0), shape)
    d = ImageDraw.Draw(img)
    d.ellipse([c - 30 * SS, c - 30 * SS, c - 14 * SS, c - 18 * SS], fill=(240, 210, 255, 200))
    finish(img, "maze_impurity.png")


def maze_array():
    """The formation array under the maze, 512px, stretched over the board and
    shown faint: concentric gold rings, the eight trigrams round the middle and
    tick marks, like the plate of a formation compass."""
    N = 512 * SS
    c = N / 2
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    col = (214, 172, 92, 255)
    for rad, w in ((0.97, 4), (0.9, 2), (0.62, 3), (0.56, 2), (0.3, 3)):
        rr = rad * c
        d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=col, width=w * SS)
    for k in range(72):
        a = k * math.pi / 36
        r0 = 0.9 * c
        r1 = (0.84 if k % 3 == 0 else 0.87) * c
        d.line([(c + math.cos(a) * r0, c + math.sin(a) * r0), (c + math.cos(a) * r1, c + math.sin(a) * r1)], fill=col, width=2 * SS)
    # earlier-heaven trigrams, bottom line first: 1 = solid, 0 = broken
    trigrams = ["111", "011", "101", "001", "110", "010", "100", "000"]
    for k, bits in enumerate(trigrams):
        a = -math.pi / 2 + k * math.pi / 4
        ca, sa = math.cos(a), math.sin(a)
        for j, bit in enumerate(bits):
            rr = (0.66 + 0.06 * j) * c
            half = 0.1 * c
            segs = [(-half, half)] if bit == "1" else [(-half, -0.02 * c), (0.02 * c, half)]
            for lo, hi in segs:
                p0 = (c + ca * rr - sa * lo, c + sa * rr + ca * lo)
                p1 = (c + ca * rr - sa * hi, c + sa * rr + ca * hi)
                d.line([p0, p1], fill=col, width=7 * SS)
    # a taiji at the heart
    rr = 0.18 * c
    d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=col, width=3 * SS)
    d.pieslice([c - rr, c - rr, c + rr, c + rr], 90, 270, fill=col)
    h = rr / 2
    d.ellipse([c - h, c - rr, c + h, c], fill=col)
    d.ellipse([c - h, c, c + h, c + rr], fill=(0, 0, 0, 0))
    d.ellipse([c - 6 * SS, c - h - 6 * SS, c + 6 * SS, c - h + 6 * SS], fill=(0, 0, 0, 0))
    d.ellipse([c - 6 * SS, c + h - 6 * SS, c + 6 * SS, c + h + 6 * SS], fill=col)
    finish(img, "maze_array.png")


def maze_art():
    maze_wall()
    maze_trail()
    maze_spark()
    maze_exit()
    maze_impurity()
    maze_array()



# ---------------------------------------------------------------- circulation minigames
# Shared pieces for Thread, Pulse, Gather and Forms (and the qi pointer every
# pointing game uses). Run: draw_ui.py minigames

def mg_pointer():
    """The qi pointer, 64px, stretched (shown ~30px at the mouse while it's over
    a board; the OS arrow hides there): a jade ring with four gold ticks and a
    white-hot pinpoint at the exact centre, ink-outlined so it reads on any board."""
    N = 64 * SS
    c = N / 2
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    glow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    r = 0.6 * c
    gd.ellipse([c - r, c - r, c + r, c + r], outline=(120, 240, 200, 200), width=8 * SS)
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(3 * SS)))
    d = ImageDraw.Draw(img)
    d.ellipse([c - r, c - r, c + r, c + r], outline=INK, width=6 * SS)
    d.ellipse([c - r, c - r, c + r, c + r], outline=(170, 250, 220, 255), width=3 * SS)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        ca, sa = math.cos(a), math.sin(a)
        p0 = (c + ca * 0.72 * c, c + sa * 0.72 * c)
        p1 = (c + ca * 0.95 * c, c + sa * 0.95 * c)
        d.line([p0, p1], fill=INK, width=7 * SS)
        d.line([p0, p1], fill=GOLD_HI, width=3 * SS)
    rr = 0.16 * c
    d.ellipse([c - rr - 2 * SS, c - rr - 2 * SS, c + rr + 2 * SS, c + rr + 2 * SS], fill=INK)
    d.ellipse([c - rr, c - rr, c + rr, c + rr], fill=(255, 255, 245, 255))
    finish(img, "mg_pointer.png")


def mg_ring():
    """A white glowing ring, 128px, stretched and tinted by ImageColor3: the
    pops on hits, purges and touches (Feel.pop) and the closing approach rings.
    A crisp band at r 0.80-0.90 with a soft glow either side."""
    def profile(r):
        band = max(0.0, 1 - abs(r - 0.85) / 0.05)
        soft = max(0.0, 1 - abs(r - 0.85) / 0.16) ** 2
        a = 255 * min(1, band * 1.4) if band > 0 else 0
        a = max(a, 120 * soft)
        return (255, 255, 255, a)

    finish(_radial(128, profile), "mg_ring.png")


def mg_burst():
    """A spray of qi light, 128px, stretched and tinted: twelve tapering rays from
    a soft core, for Perfect hits, purges and clears (Feel.burst)."""
    N = 128 * SS
    c = N / 2
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(12):
        a = k * math.pi / 6 + (0.12 if k % 2 else 0)
        length = (0.95 if k % 2 == 0 else 0.7) * c
        w = 0.07 * c
        ca, sa = math.cos(a), math.sin(a)
        p0 = (c + ca * 0.25 * c - sa * w, c + sa * 0.25 * c + ca * w)
        p1 = (c + ca * 0.25 * c + sa * w, c + sa * 0.25 * c - ca * w)
        tip = (c + ca * length, c + sa * length)
        d.polygon([p0, tip, p1], fill=(255, 255, 255, 230))
    img = img.filter(ImageFilter.GaussianBlur(1.5 * SS))
    core = _radial(128, lambda r: (255, 255, 255, 220 * max(0, 1 - r / 0.4) ** 1.5))
    img.alpha_composite(core)
    finish(img, "mg_burst.png")


def mg_glow():
    """A soft white glow, 128px, stretched and tinted: halos and flashes (the
    bead's halo, the bowl's pooled qi, the pulse core's beat)."""
    finish(_radial(128, lambda r: (255, 255, 255, 255 * (1 - r) ** 2.2)), "mg_glow.png")


def mg_disc():
    """A plain white disc with an antialiased edge, 128px, tinted by
    ImageColor3. Thread's channel: 9-slice SliceCenter Rect(63, 63, 65, 65),
    SliceScale = shown thickness / 128 (set by Thread.luau), so it makes
    round-capped strokes whose overlaps are invisible (one flat colour)."""
    finish(_radial(128, lambda r: (255, 255, 255, 255 if r < 0.97 else 255 * (1 - r) / 0.03)), "mg_disc.png")


def thread_wall():
    """The meridian's wall, 128px, radially symmetric: a gold band whose inner
    side (where the channel meets it) is lit and outer side shaded bronze, out to
    r 0.78, then a faint warm aura. The channel (mg_disc) covers the middle, so
    only the band shows, like an engraved gold rim. 9-slice SliceCenter
    Rect(63, 63, 65, 65); SliceScale = shown thickness / 128 (Thread.luau)."""
    CORE = 0.78

    def profile(r):
        if r < CORE:
            t = max(0.0, (r - 0.5) / (CORE - 0.5))
            col = _mix((255, 238, 186), (150, 104, 40), t ** 1.3)
            a = 255 if r < CORE - 0.03 else 255 * (1 - (r - CORE + 0.03) / 0.03 * 0.4)
            return col + (a,)
        t = (r - CORE) / (1 - CORE)
        return (230, 180, 96, 110 * (1 - t) ** 2)

    finish(_radial(128, profile), "thread_wall.png")


def thread_node():
    """An acupoint on the meridian, 64px, stretched and tinted (dim jade unlit,
    gold once the qi passes): a ring with four petals and a centre pip."""
    N = 64 * SS
    c = N / 2
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = 0.78 * c
    d.ellipse([c - r, c - r, c + r, c + r], outline=(255, 255, 255, 255), width=5 * SS)
    for k in range(4):
        a = k * math.pi / 2
        ca, sa = math.cos(a), math.sin(a)
        p = (c + ca * 0.42 * c, c + sa * 0.42 * c)
        w = 0.13 * c
        d.polygon([(c + ca * 0.18 * c, c + sa * 0.18 * c), (p[0] - sa * w, p[1] + ca * w), (c + ca * 0.62 * c, c + sa * 0.62 * c), (p[0] + sa * w, p[1] - ca * w)], fill=(255, 255, 255, 200))
    rr = 0.14 * c
    d.ellipse([c - rr, c - rr, c + rr, c + rr], fill=(255, 255, 255, 255))
    finish(img, "thread_node.png")


def _note(name, body_in, body_out, rim, rim_hi, rim_lo, glint):
    """A struck point (Pulse and Forms notes), 128px, stretched: a lacquer disc
    with a bevelled metal rim, an ink outline and a soft top-left glint. The
    centre stays plain for the Forms number."""
    N = 128 * SS
    c = N / 2
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    R = 0.94 * c
    d.ellipse([c - R, c - R, c + R, c + R], fill=INK)
    R2 = R - 3 * SS
    d.ellipse([c - R2, c - R2, c + R2, c + R2], fill=rim_lo)
    d.pieslice([c - R2, c - R2, c + R2, c + R2], 135, 315, fill=rim_hi)
    R3 = R2 - 3 * SS
    d.ellipse([c - R3, c - R3, c + R3, c + R3], fill=rim)
    R4 = R3 - 9 * SS
    d.ellipse([c - R4 - 2 * SS, c - R4 - 2 * SS, c + R4 + 2 * SS, c + R4 + 2 * SS], fill=INK)
    body = _radial(128, lambda r: _mix(body_in, body_out, min(1, r / (R4 / c)) ** 1.4) + (255,))
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).ellipse([c - R4, c - R4, c + R4, c + R4], fill=255)
    img.paste(body, (0, 0), mask)
    hl = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(hl).arc([c - R4 + 6 * SS, c - R4 + 6 * SS, c + R4 - 6 * SS, c + R4 - 6 * SS], 200, 280, fill=glint, width=5 * SS)
    img.alpha_composite(hl.filter(ImageFilter.GaussianBlur(1.5 * SS)))
    finish(img, name)


def mg_notes():
    _note("mg_note.png", (64, 150, 122), (12, 40, 34), GOLD, GOLD_HI, GOLD_LO, (230, 255, 240, 150))
    _note("mg_note_impure.png", (150, 70, 190), (40, 12, 54), (150, 92, 206), (226, 196, 255, 255), (66, 30, 104, 255), (240, 210, 255, 150))


def pulse_core():
    """The dantian at the centre of Meridian Pulse, 256px, stretched: a round
    lacquer seal with a double gold ring and eight lozenge studs; the 脈 glyph
    sits on it as text."""
    N = 256 * SS
    c = N / 2
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    R = 0.95 * c
    d.ellipse([c - R, c - R, c + R, c + R], fill=INK)
    body = _radial(256, lambda r: _mix((40, 74, 66), (8, 18, 18), min(1, r / 0.9) ** 1.2) + (255,))
    mask = Image.new("L", (N, N), 0)
    R2 = R - 4 * SS
    ImageDraw.Draw(mask).ellipse([c - R2, c - R2, c + R2, c + R2], fill=255)
    img.paste(body, (0, 0), mask)
    for rad, w in ((0.86, 7), (0.72, 3)):
        rr = rad * c
        d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=GOLD_LO, width=(w + 3) * SS)
        d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=GOLD, width=w * SS)
    for k in range(8):
        a = k * math.pi / 4
        lozenge(d, c + math.cos(a) * 0.79 * c, c + math.sin(a) * 0.79 * c, 9 * SS, 2 * SS)
    finish(img, "pulse_core.png")


def pulse_path():
    """The meridian ring the beats travel round, 512px, stretched over
    Pulse.Field.Path: a thin gold line in a faint jade glow, with twelve small
    acupoint pips on it."""
    N = 512 * SS
    c = N / 2
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    glow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    r = 0.96 * c
    ImageDraw.Draw(glow).ellipse([c - r, c - r, c + r, c + r], outline=(90, 210, 170, 140), width=14 * SS)
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(6 * SS)))
    d = ImageDraw.Draw(img)
    d.ellipse([c - r, c - r, c + r, c + r], outline=GOLD_LO, width=5 * SS)
    d.ellipse([c - r, c - r, c + r, c + r], outline=GOLD, width=3 * SS)
    for k in range(12):
        a = k * math.pi / 6
        x, y = c + math.cos(a) * r, c + math.sin(a) * r
        pr = 6 * SS
        d.ellipse([x - pr - 2 * SS, y - pr - 2 * SS, x + pr + 2 * SS, y + pr + 2 * SS], fill=INK)
        d.ellipse([x - pr, y - pr, x + pr, y + pr], fill=GOLD_HI)
    finish(img, "pulse_path.png")


def gather_bowl():
    """The dantian bowl in Gather Qi, 512x128, 9-sliced so it stretches to any
    width: a shallow lacquer-red vessel with a gold lip, its rounded ends wholly
    inside the corners. Every row of the top/bottom strips and every column of
    the side strips is identical. SliceCenter Rect(120, 63, 392, 65), SliceScale
    0.22 (about 28px tall)."""
    W, H = 512 * SS, 128 * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shape = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(shape)
    end = 110 * SS
    top, bot = 22 * SS, 120 * SS
    knee = 74 * SS  # the sides drop straight to here (through the slice rows), then round under
    # the body: straight sides down past the slice rows, then rounded-in bottom
    # corners (quarter ellipses), all within the corners
    sd.rectangle([8 * SS, top, W - 8 * SS, knee], fill=255)
    sd.rectangle([end, knee - SS, W - end, bot], fill=255)
    sd.pieslice([8 * SS, knee - (bot - knee), 2 * end - 8 * SS, bot], 90, 180, fill=255)
    sd.pieslice([W - 2 * end + 8 * SS, knee - (bot - knee), W - 8 * SS, bot], 0, 90, fill=255)
    outline = shape.filter(ImageFilter.MaxFilter(5 * SS + 1))
    img.paste(Image.new("RGBA", (W, H), INK), (0, 0), outline)
    grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    for y in range(H):
        t = max(0, min(1, (y - top) / (bot - top)))
        gd.line([(0, y), (W, y)], fill=tuple(int(v) for v in _mix((178, 52, 40), (70, 14, 14), t ** 1.1)) + (255,))
    img.paste(grad, (0, 0), shape)
    # a gold band low on the body, and the gold lip along the top
    band = Image.new("L", (W, H), 0)
    ImageDraw.Draw(band).rectangle([0, 82 * SS, W, 88 * SS], fill=255)
    band = Image.composite(band, Image.new("L", (W, H), 0), shape.filter(ImageFilter.MinFilter(10 * SS + 1)))
    img.paste(Image.new("RGBA", (W, H), GOLD), (0, 0), band)
    lip = Image.new("L", (W, H), 0)
    ImageDraw.Draw(lip).rounded_rectangle([2 * SS, 12 * SS, W - 2 * SS, 30 * SS], radius=9 * SS, fill=255)
    img.paste(Image.new("RGBA", (W, H), INK), (0, 0), lip)
    lip2 = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    l2 = ImageDraw.Draw(lip2)
    l2.rounded_rectangle([6 * SS, 15 * SS, W - 6 * SS, 27 * SS], radius=6 * SS, fill=GOLD)
    l2.line([(12 * SS, 18 * SS), (W - 12 * SS, 18 * SS)], fill=GOLD_HI, width=3 * SS)
    img.alpha_composite(lip2)
    finish(img, "gather_bowl.png")


def field_wash():
    """A faint ink-wash landscape, 1024x512, stretched under the Thread, Gather
    and Forms boards (shown with ImageTransparency ~0.8): layered mountain
    ridges fading upward and two drifting cloud bands, in pale jade-white."""
    W, H = 1024 * SS, 512 * SS
    import random
    rng = random.Random(7)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for layer, (base, amp, alpha) in enumerate(((0.62, 0.18, 70), (0.74, 0.14, 110), (0.86, 0.1, 150))):
        pts = [(0, H)]
        phase = rng.random() * 6
        for i in range(129):
            x = W * i / 128
            u = i / 128
            y = H * (base - amp * (0.55 * math.sin(u * 7 + phase) ** 2 + 0.3 * math.sin(u * 17 + phase * 2) ** 2 + 0.15 * math.sin(u * 37)))
            pts.append((x, y))
        pts.append((W, H))
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).polygon(pts, fill=alpha)
        # fade each ridge toward its foot, like ink thinning in water
        fade = Image.new("L", (W, H), 0)
        fd = ImageDraw.Draw(fade)
        for y in range(0, H, SS):
            t = y / H
            fd.rectangle([0, y, W, y + SS], fill=int(255 * max(0, 1 - max(0, t - base + 0.05) * 2.2)))
        m = Image.composite(m, Image.new("L", (W, H), 0), fade)
        m = m.filter(ImageFilter.GaussianBlur(3 * SS))
        img.paste(Image.new("RGBA", (W, H), (200, 236, 222, 255)), (0, 0), m)
    clouds = Image.new("L", (W, H), 0)
    cd = ImageDraw.Draw(clouds)
    for cy, cx0, cx1 in ((0.3, 0.08, 0.42), (0.45, 0.58, 0.95)):
        for k in range(9):
            x = W * (cx0 + (cx1 - cx0) * k / 8)
            r = H * (0.03 + 0.02 * rng.random())
            cd.ellipse([x - r * 2.2, H * cy - r, x + r * 2.2, H * cy + r], fill=90)
    clouds = clouds.filter(ImageFilter.GaussianBlur(8 * SS))
    img.paste(Image.new("RGBA", (W, H), (230, 246, 240, 255)), (0, 0), clouds)
    finish(img, "field_wash.png")


def minigame_art():
    mg_pointer()
    mg_ring()
    mg_burst()
    mg_glow()
    mg_disc()
    thread_wall()
    thread_node()
    mg_notes()
    pulse_core()
    pulse_path()
    gather_bowl()
    field_wash()


# ---------------------------------------------------------------- enemy bars

# The overhead bar on regular demon beasts (bosses keep Play.BossBar), Dead Cells
# style: a dark nameplate strip over a long thin bar with a slanted right end,
# cut into ten talisman slips (one per 10% of health, like the player's vitals).
# Every piece is drawn at its display size x EB_R and shown with ScaleType Stretch
# at a fixed pixel size in the BillboardGui, so nothing is 9-sliced.
# Geometry in display px (the BillboardGui lays its frames on these numbers):
EB_R = 4  # image px per display px
EB = {
    "bar": (136, 22),  # bar art canvas: Back, Rim and Aura all cover it
    "window": (10, 7, 126, 15),  # fill window bbox: Fill / Trail clip frames
    "slant": 4,  # the right end leans back this far over the window's height
    "outer": (6, 5, 17),  # rim outer edge: left x, top y, bottom y
    "segments": 10,
    "strip": (112, 15),  # nameplate strip
    "sheen": (28, 8),
    "skull": (40, 40),
}

# Danger tiers (EnemyBars.STYLES picks one from the realm gap, Pacing.Danger).
EB_TIERS = {
    "bronze": {"metal": (150, 104, 62), "hi": (206, 158, 104), "lo": (82, 52, 30)},
    "jade": {"metal": (78, 158, 128), "hi": (176, 228, 196), "lo": (30, 74, 60)},
    "gold": {"metal": (214, 172, 92), "hi": (252, 226, 156), "lo": (120, 82, 34)},
    "far": {"metal": (150, 92, 206), "hi": (226, 196, 255), "lo": (66, 30, 104)},
}


def _eb(v):
    return int(round(v * EB_R * SS))


def _eb_canvas(w, h):
    return Image.new("RGBA", (_eb(w), _eb(h)), (0, 0, 0, 0))


def _eb_finish(img, name):
    w, h = img.size
    img = img.resize((w // SS, h // SS), Image.LANCZOS)
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


def _eb_poly(inset):
    """The bar body, `inset` display px in from the rim's outer edge: square
    left end, right end slanted back toward the bottom."""
    lx, ty, by = EB["outer"]
    wx0, wy0, wx1, wy1 = EB["window"]
    k = EB["slant"] / (wy1 - wy0)  # x lean per px of height
    rx_top = wx1 + (wy0 - ty) * k + 2.2  # outer right edge, through the rim
    a, b = ty + inset, by - inset
    rt = rx_top - inset - (inset * k)
    return [(_eb(lx + inset), _eb(a)), (_eb(rt), _eb(a)), (_eb(rt - (b - a) * k), _eb(b)), (_eb(lx + inset), _eb(b))]


def _eb_window_poly(ox=0, oy=0):
    """The fill shape in window space (offset by ox, oy display px)."""
    wx0, wy0, wx1, wy1 = EB["window"]
    w, h = wx1 - wx0, wy1 - wy0
    s = EB["slant"]
    return [(_eb(ox), _eb(oy)), (_eb(ox + w), _eb(oy)), (_eb(ox + w - s), _eb(oy + h)), (_eb(ox), _eb(oy + h))]


def eb_back():
    """Dark lacquer backing for lost health, the whole bar body. 544x88,
    stretched at 136x22."""
    img = _eb_canvas(*EB["bar"])
    d = ImageDraw.Draw(img)
    d.polygon(_eb_poly(0), fill=(8, 8, 10, 235))
    wx0, wy0, _, _ = EB["window"]
    d.polygon(_eb_window_poly(wx0, wy0), fill=(30, 14, 16, 235))
    # a faint inner shadow along the top of the window
    d.line([(_eb(wx0), _eb(wy0) + _eb(0.6)), (_eb(EB["window"][2]), _eb(wy0) + _eb(0.6))], fill=(0, 0, 0, 200), width=_eb(1.2))
    _eb_finish(shadow_under(img, blur=1, offset=1, alpha=150), "enemybar_back.png")


def _eb_strip_fill(name, top, bot, glint):
    """A window-shaped strip (Fill, Trail): 464x32, stretched at 116x8 inside
    its clip frame."""
    wx0, wy0, wx1, wy1 = EB["window"]
    w, h = wx1 - wx0, wy1 - wy0
    img = _eb_canvas(w, h)
    grad = _eb_canvas(w, h)
    gradient_rect(grad, [0, 0, _eb(w), _eb(h)], top, bot)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(_eb_window_poly(), fill=255)
    img.paste(grad, (0, 0), mask)
    if glint:
        # blood-qi sheen: a soft lit band near the top, and a faint core line
        g = Image.new("RGBA", img.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(g)
        gd.rectangle([0, _eb(1), _eb(w), _eb(2.6)], fill=glint)
        gd.rectangle([0, _eb(h * 0.62), _eb(w), _eb(h * 0.62 + 0.6)], fill=(255, 90, 70, 40))
        g = g.filter(ImageFilter.GaussianBlur(_eb(0.35)))
        g.putalpha(Image.composite(g.getchannel("A"), Image.new("L", img.size, 0), mask))
        img.alpha_composite(g)
    _eb_finish(img, name)


def eb_fill():
    _eb_strip_fill("enemybar_fill.png", (222, 58, 50), (112, 12, 24), (255, 170, 150, 110))


def eb_ghost():
    """The recent-damage chip: pale qi gold, drains after the fill."""
    _eb_strip_fill("enemybar_ghost.png", (255, 240, 200), (226, 182, 108), None)


def eb_sheen():
    """A soft slanted white band that sweeps across the fill on far-above beasts.
    112x32, stretched at 28x8."""
    w, h = EB["sheen"]
    img = _eb_canvas(w, h)
    d = ImageDraw.Draw(img)
    s = EB["slant"]
    cx = w / 2
    d.polygon([(_eb(cx - 3 + s / 2), 0), (_eb(cx + 3 + s / 2), 0), (_eb(cx + 3 - s / 2), _eb(h)), (_eb(cx - 3 - s / 2), _eb(h))], fill=(255, 236, 255, 150))
    img = img.filter(ImageFilter.GaussianBlur(_eb(1.6)))
    _eb_finish(img, "enemybar_sheen.png")


def _eb_seal(d, cx, cy, r, face, edge):
    """A small diamond seal stamp on the bar's tip."""
    d.polygon([(_eb(cx), _eb(cy - r - 0.8)), (_eb(cx + r + 0.8), _eb(cy)), (_eb(cx), _eb(cy + r + 0.8)), (_eb(cx - r - 0.8), _eb(cy))], fill=INK)
    d.polygon([(_eb(cx), _eb(cy - r)), (_eb(cx + r), _eb(cy)), (_eb(cx), _eb(cy + r)), (_eb(cx - r), _eb(cy))], fill=face)
    q = r * 0.45
    d.polygon([(_eb(cx), _eb(cy - q)), (_eb(cx + q), _eb(cy)), (_eb(cx), _eb(cy + q)), (_eb(cx - q), _eb(cy))], outline=edge, width=_eb(0.5))


def eb_rim(tier):
    """The frame over the fill for one danger tier: ink outline, a metal band
    with a lit top edge, nine slanted talisman divisions across the window and
    the tier's end caps (jade: a vermilion seal on the tip; gold: seal plus a
    lozenge on the left end; far: a violet lozenge and a long pointed talisman
    tip). 544x88, stretched at 136x22."""
    t = EB_TIERS[tier]
    metal, hi, lo = t["metal"] + (255,), t["hi"] + (255,), t["lo"] + (255,)
    img = _eb_canvas(*EB["bar"])
    d = ImageDraw.Draw(img)
    lx, ty, by = EB["outer"]
    wx0, wy0, wx1, wy1 = EB["window"]
    cy = (ty + by) / 2

    if tier == "far":
        # long talisman tip: a pointed blade leaning off the right end
        tip = [(_eb(126.5), _eb(ty - 0.5)), (_eb(135.5), _eb(cy - 1)), (_eb(122), _eb(by + 0.5))]
        d.polygon(tip, fill=INK)
        tip2 = [(_eb(127.4), _eb(ty + 1)), (_eb(133.6), _eb(cy - 1)), (_eb(123.6), _eb(by - 1))]
        d.polygon(tip2, fill=metal)
        d.line([tip2[0], tip2[1]], fill=hi, width=_eb(0.6))

    # body ring: ink, metal, then cut the window back out
    ring = _eb_canvas(*EB["bar"])
    rd = ImageDraw.Draw(ring)
    rd.polygon(_eb_poly(0), fill=INK)
    rd.polygon(_eb_poly(0.8), fill=metal)
    # lit top edge and shaded bottom edge of the band
    p = _eb_poly(0.8)
    rd.line([p[0], p[1]], fill=hi, width=_eb(0.55))
    rd.line([p[3], p[2]], fill=lo, width=_eb(0.55))
    rd.polygon(_eb_window_poly(wx0 - 0.6, wy0 - 0.6), fill=INK)
    a = ring.getchannel("A")
    ImageDraw.Draw(a).polygon(_eb_window_poly(wx0, wy0), fill=0)
    # the window poly is cut 1px wider on the slant side to keep the tip crisp
    ring.putalpha(a)
    img.alpha_composite(ring)
    d = ImageDraw.Draw(img)

    # slanted talisman divisions, one per 10%
    n = EB["segments"]
    w = wx1 - wx0
    s = EB["slant"]
    for i in range(1, n):
        x = wx0 + w * i / n
        d.line([(_eb(x + 0.3), _eb(wy0)), (_eb(x + 0.3 - s), _eb(wy1))], fill=(6, 6, 8, 255), width=_eb(1.1))
        d.line([(_eb(x + 0.95), _eb(wy0 + 0.3)), (_eb(x + 0.95 - s), _eb(wy1 - 0.3))], fill=(255, 255, 255, 46), width=_eb(0.35))

    # glaze along the top of the window
    gl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(gl).rectangle([_eb(wx0), _eb(wy0 + 0.4), _eb(wx1), _eb(wy0 + 1.5)], fill=(255, 255, 255, 30))
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).polygon(_eb_window_poly(wx0, wy0), fill=255)
    gl.putalpha(Image.composite(gl.getchannel("A"), Image.new("L", img.size, 0), m))
    img.alpha_composite(gl)

    if tier in ("jade", "gold"):
        _eb_seal(d, 128.6, cy, 4.2, (176, 40, 30, 255), (246, 226, 196, 230))
    if tier in ("gold", "far"):
        face = (30, 18, 40, 255) if tier == "far" else (40, 30, 22, 255)
        r = 5.0
        d.polygon([(_eb(lx), _eb(cy - r - 0.8)), (_eb(lx + r + 0.8), _eb(cy)), (_eb(lx), _eb(cy + r + 0.8)), (_eb(lx - r - 0.8), _eb(cy))], fill=INK)
        d.polygon([(_eb(lx), _eb(cy - r)), (_eb(lx + r), _eb(cy)), (_eb(lx), _eb(cy + r)), (_eb(lx - r), _eb(cy))], fill=metal)
        q = r * 0.5
        d.polygon([(_eb(lx), _eb(cy - q)), (_eb(lx + q), _eb(cy)), (_eb(lx), _eb(cy + q)), (_eb(lx - q), _eb(cy))], fill=face)
        d.line([(_eb(lx - r * 0.5), _eb(cy - r * 0.5)), (_eb(lx), _eb(cy - r))], fill=hi, width=_eb(0.5))
    if tier == "far":
        _eb_seal(d, 126.2, cy - 0.6, 2.6, (150, 26, 52, 255), (255, 210, 230, 220))
    _eb_finish(shadow_under(img, blur=1, offset=1, alpha=140), f"enemybar_rim_{tier}.png")


def eb_aura():
    """The faint violet qi glow behind a far-above beast's bar (pulsed by the
    script). 544x88, stretched at 136x22."""
    img = _eb_canvas(*EB["bar"])
    d = ImageDraw.Draw(img)
    lx, ty, by = EB["outer"]
    d.rounded_rectangle([_eb(lx + 1), _eb(ty + 1.5), _eb(128), _eb(by - 1.5)], radius=_eb(4), fill=(190, 120, 255, 200))
    img = img.filter(ImageFilter.GaussianBlur(_eb(2.4)))
    _eb_finish(img, "enemybar_aura.png")


def eb_strip():
    """The nameplate strip: dark ink, slightly translucent, washing out to the
    right, with a thin bronze hairline along its foot. 448x60, stretched at
    112x15."""
    w, h = EB["strip"]
    img = _eb_canvas(w, h)
    px = img.load()
    W, H = img.size
    for x in range(W):
        t = x / (W - 1)
        a = 168 if t < 0.62 else int(168 * max(0, 1 - (t - 0.62) / 0.38) ** 1.4)
        for y in range(H):
            v = y / (H - 1)
            edge = 1 - 0.35 * (abs(v - 0.5) * 2) ** 6
            px[x, y] = (10, 12, 14, int(a * edge))
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    for x in range(0, W, SS):
        t = x / (W - 1)
        a = int(200 * max(0, 1 - t / 0.8) ** 1.2)
        hd.line([(x, H - _eb(0.9)), (x + SS, H - _eb(0.9))], fill=(206, 164, 96, a), width=_eb(0.6))
    img.alpha_composite(hl)
    d = ImageDraw.Draw(img)
    # a small lozenge tick at the left end of the hairline
    cy, r = h - 0.9, 1.6
    d.polygon([(_eb(1.6), _eb(cy - r)), (_eb(1.6 + r), _eb(cy)), (_eb(1.6), _eb(cy + r)), (_eb(1.6 - r), _eb(cy))], fill=GOLD)
    _eb_finish(img, "enemybar_strip.png")


def eb_skull():
    """The "do not fight" mark over a beast far past the player: a cracked
    crimson talisman seal with a horned bone skull, ringed by a soft blood-qi
    glow (pulsed by the script). 160x160, stretched at 40x40."""
    import random
    rnd = random.Random(23)
    w, h = EB["skull"]
    img = _eb_canvas(w, h)
    c = _eb(w / 2)
    # glow
    g = _eb_canvas(w, h)
    ImageDraw.Draw(g).ellipse([c - _eb(15), c - _eb(15), c + _eb(15), c + _eb(15)], fill=(220, 30, 40, 170))
    g = g.filter(ImageFilter.GaussianBlur(_eb(3.5)))
    img.alpha_composite(g)
    d = ImageDraw.Draw(img)
    # seal: a diamond talisman face
    R = _eb(14.5)
    d.polygon([(c, c - R - _eb(1.2)), (c + R + _eb(1.2), c), (c, c + R + _eb(1.2)), (c - R - _eb(1.2), c)], fill=INK)
    face = _eb_canvas(w, h)
    gradient_rect(face, [c - R, c - R, c + R, c + R], (170, 30, 34), (86, 10, 20))
    m = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(m)
    md.polygon([(c, c - R), (c + R, c), (c, c + R), (c - R, c)], fill=255)
    for _ in range(60):  # nibbled chop edge
        k = rnd.random()
        side = rnd.randrange(4)
        corners = [(c, c - R), (c + R, c), (c, c + R), (c - R, c), (c, c - R)]
        (x0, y0), (x1, y1) = corners[side], corners[side + 1]
        x, y = x0 + (x1 - x0) * k, y0 + (y1 - y0) * k
        r = rnd.uniform(0.3, 0.8) * _eb(1)
        md.ellipse([x - r, y - r, x + r, y + r], fill=0)
    img.paste(face, (0, 0), m)
    d = ImageDraw.Draw(img)
    q = R * 0.84
    d.polygon([(c, c - q), (c + q, c), (c, c + q), (c - q, c)], outline=(240, 200, 170, 150), width=_eb(0.5))
    bone = (240, 226, 200, 255)
    u = _eb(1)
    sy = c - 1.5 * u
    # horns
    for side in (-1, 1):
        d.line([(c + side * 4.2 * u, sy - 3.6 * u), (c + side * 6.6 * u, sy - 6.4 * u), (c + side * 6.2 * u, sy - 8.6 * u)], fill=INK, width=round(2.6 * u), joint="curve")
        d.line([(c + side * 4.2 * u, sy - 3.6 * u), (c + side * 6.6 * u, sy - 6.4 * u), (c + side * 6.2 * u, sy - 8.6 * u)], fill=bone, width=int(1.4 * u), joint="curve")
    # cranium and jaw
    d.ellipse([c - 6.4 * u, sy - 6.2 * u, c + 6.4 * u, sy + 5.2 * u], fill=INK)
    d.rounded_rectangle([c - 4.2 * u, sy + 2.2 * u, c + 4.2 * u, sy + 8.4 * u], radius=1.5 * u, fill=INK)
    d.ellipse([c - 5.5 * u, sy - 5.3 * u, c + 5.5 * u, sy + 4.4 * u], fill=bone)
    d.rounded_rectangle([c - 3.4 * u, sy + 2.4 * u, c + 3.4 * u, sy + 7.6 * u], radius=1.2 * u, fill=bone)
    # eyes, nose, teeth
    for side in (-1, 1):
        ex = c + side * 2.4 * u
        d.polygon([(ex - 1.8 * u, sy - 0.6 * u), (ex + 1.8 * u, sy - 0.6 * u), (ex + side * 0.4 * u, sy + 1.8 * u)], fill=(120, 8, 16, 255))
        d.ellipse([ex - 0.5 * u, sy - 0.2 * u, ex + 0.5 * u, sy + 0.8 * u], fill=(255, 90, 70, 255))
    d.polygon([(c, sy + 2.2 * u), (c - 0.9 * u, sy + 3.8 * u), (c + 0.9 * u, sy + 3.8 * u)], fill=INK)
    for k in (-1.5, 0, 1.5):
        d.line([(c + k * u, sy + 5.0 * u), (c + k * u, sy + 7.4 * u)], fill=INK, width=int(0.6 * u))
    # a crack across the brow and down through the seal
    crack = [(c + 1.2 * u, sy - 5.3 * u), (c + 0.2 * u, sy - 3.2 * u), (c + 1.4 * u, sy - 1.8 * u)]
    d.line(crack, fill=INK, width=int(0.6 * u))
    d.line([(c - 4 * u, c + 8 * u), (c - 6.2 * u, c + 9.4 * u), (c - 7.0 * u, c + 7.4 * u)], fill=INK, width=int(0.6 * u))
    _eb_finish(img, "enemybar_skull.png")


def enemy_bar_art():
    eb_back()
    eb_fill()
    eb_ghost()
    eb_sheen()
    for tier in EB_TIERS:
        eb_rim(tier)
    eb_aura()
    eb_strip()
    eb_skull()


# ---------------------------------------------------------------- scroll hints


def scroll_fade():
    """The "more below" fade over a scrolling list's bottom edge, 64x64: ink
    lacquer from clear at the top to dense at the bottom (smoothstep). Every
    column is the same, so it stretches sideways at any width; shown with
    ScaleType Stretch at ~48px tall (Hud.ScrollHint.Hint.Fade)."""
    W, H = 64, 64
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        a = t * t * (3 - 2 * t)
        for x in range(W):
            px[x, y] = (8, 12, 15, int(250 * a))
    img.save(os.path.join(OUT, "scroll_fade.png"))
    print("wrote scroll_fade.png", img.size)


def scroll_more():
    """The bobbing "scroll for more" seal, 128px: a round dark-jade lacquer disc
    with a gold rim and a gold downward chevron, ink outline and soft top light.
    It straddles the list's bottom edge, so the disc keeps it readable over rows
    and frame alike. Stretched, shown at ~30px (Hud.ScrollHint.Hint.More)."""
    N = 128 * SS
    c = N / 2
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    R = 54 * SS
    d.ellipse([c - R, c - R, c + R, c + R], fill=INK)
    r = R - 4 * SS
    d.ellipse([c - r, c - r, c + r, c + r], fill=GOLD_LO)
    r2 = r - 3 * SS
    disc = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    gradient_rect(disc, (c - r2, c - r2, c + r2, c + r2), (40, 64, 64), (10, 18, 22), radius=int(r2))
    img.alpha_composite(disc)
    d.ellipse([c - r, c - r, c + r, c + r], outline=GOLD, width=3 * SS)
    shape = Image.new("L", (N, N), 0)
    sd = ImageDraw.Draw(shape)
    y = c + 6 * SS
    sd.line([(c - 26 * SS, y - 14 * SS), (c, y + 12 * SS), (c + 26 * SS, y - 14 * SS)], fill=255, width=14 * SS, joint="curve")
    outline = shape.filter(ImageFilter.MaxFilter(4 * SS + 1))
    img.paste(Image.new("RGBA", (N, N), INK), (0, 0), outline)
    grad = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    top, bot = (255, 236, 180), (210, 156, 70)
    for yy in range(N):
        t = yy / N
        gd.line([(0, yy), (N, yy)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    img.paste(grad, (0, 0), shape)
    hl = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(hl).arc([c - r + 6 * SS, c - r + 6 * SS, c + r - 6 * SS, c + r - 6 * SS], 200, 290, fill=(255, 250, 230, 110), width=3 * SS)
    img.alpha_composite(hl)
    finish(shadow_under(img, blur=3, offset=2, alpha=140), "scroll_more.png")


def scroll_thumb():
    """A scroll bar thumb drawn in three parts for ScrollingFrame Top/Mid/Bottom
    Image (32px wide, shown at ScrollBarThickness ~6, ScrollBarImageColor3 white):
    a gold bar lit from the left with an ink outline. Mid is identical in every
    row, so it stretches cleanly; Top and Bottom are its rounded caps."""
    W = 32 * SS

    def strip(h, cap):
        img = Image.new("RGBA", (W, h), (0, 0, 0, 0))
        shape = Image.new("L", (W, h), 0)
        d = ImageDraw.Draw(shape)
        if cap == "top":
            d.rounded_rectangle([0, 0, W - 1, h + W], radius=W // 2, fill=255)
        elif cap == "bottom":
            d.rounded_rectangle([0, -W - 1, W - 1, h - 1], radius=W // 2, fill=255)
        else:
            d.rectangle([0, 0, W - 1, h - 1], fill=255)
        inner = shape.filter(ImageFilter.MinFilter(6 * SS + 1))
        img.paste(Image.new("RGBA", (W, h), INK), (0, 0), shape)
        grad = Image.new("RGBA", (W, h), (0, 0, 0, 0))
        gd = ImageDraw.Draw(grad)
        left, right = (252, 226, 156), (176, 124, 50)
        for x in range(W):
            t = x / (W - 1)
            gd.line([(x, 0), (x, h)], fill=tuple(int(left[i] + (right[i] - left[i]) * t) for i in range(3)) + (255,))
        img.paste(grad, (0, 0), inner)
        return img

    for cap, name in (("top", "scroll_thumb_top.png"), ("mid", "scroll_thumb_mid.png"), ("bottom", "scroll_thumb_bottom.png")):
        finish(strip(W, cap), name)


def scroll_art():
    scroll_fade()
    scroll_more()
    scroll_thumb()


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "enemybar":
        enemy_bar_art()
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "maze":
        maze_art()
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "minigames":
        minigame_art()
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "scroll":
        scroll_art()
        sys.exit()
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
