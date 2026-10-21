"""Draws the item icons for the hotbar and inventory: plain silhouettes with a soft
colour gradient, an ink outline and one small highlight, so they read at hotbar
size without crowding the slot. Writes icon_<ItemId>.png (128x128) into icons/.
Run with a Python that has Pillow:  python art/ui/draw_icons.py
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
S = 128
SS = 4
N = S * SS
INK = (16, 22, 26, 255)
GOLD = (226, 186, 104, 255)


def blank():
    return Image.new("L", (N, N), 0)


def grad(top, bottom):
    img = Image.new("RGBA", (N, N))
    d = ImageDraw.Draw(img)
    for y in range(N):
        t = y / (N - 1)
        d.line([(0, y), (N, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return img


def lighten(c, k):
    return tuple(int(c[i] + (255 - c[i]) * k) for i in range(3))


def darken(c, k):
    return tuple(int(c[i] * (1 - k)) for i in range(3))


class Icon:
    def __init__(self):
        self.img = Image.new("RGBA", (N, N), (0, 0, 0, 0))

    def shape(self, mask, color, outline=5, light=0.45, dark=0.35):
        """Fill mask with a top-light gradient of color, outlined in ink."""
        edge = mask.filter(ImageFilter.MaxFilter(outline * SS * 2 + 1))
        ink = Image.new("RGBA", (N, N), INK)
        self.img.paste(ink, (0, 0), edge)
        self.img.paste(grad(lighten(color, light), darken(color, dark)), (0, 0), mask)

    def line(self, pts, color, width):
        d = ImageDraw.Draw(self.img)
        d.line([(x * SS, y * SS) for x, y in pts], fill=color, width=int(width * SS), joint="curve")

    def gloss(self, box, alpha=110):
        layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse([v * SS for v in box], fill=(255, 255, 255, alpha))
        self.img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(3 * SS)))

    def glow(self, center, radius, color, alpha=150):
        layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        cx, cy = center
        ImageDraw.Draw(layer).ellipse([(cx - radius) * SS, (cy - radius) * SS, (cx + radius) * SS, (cy + radius) * SS], fill=color + (alpha,))
        self.img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(10 * SS)))

    def save(self, name):
        os.makedirs(OUT, exist_ok=True)
        self.img.resize((S, S), Image.LANCZOS).save(os.path.join(OUT, f"icon_{name}.png"))
        print("wrote", name)


def poly(points):
    m = blank()
    ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in points], fill=255)
    return m


def ellipse(box):
    m = blank()
    ImageDraw.Draw(m).ellipse([v * SS for v in box], fill=255)
    return m


def union(*masks):
    out = blank()
    for m in masks:
        out.paste(255, (0, 0), m)
    return out


def leaf(cx, cy, length, width, angle):
    """A pointed leaf from (cx, cy) along angle (radians, 0 = up)."""
    pts = []
    for i in range(41):
        t = i / 40
        r = math.sin(math.pi * t) * width * (1 - 0.3 * t)
        pts.append((t * length, r))
    pts += [(t, -r) for t, r in reversed(pts)]
    ca, sa = math.cos(angle), math.sin(angle)
    return poly([(cx + y * ca + x * sa, cy - x * ca + y * sa) for x, y in pts])


# ---------------------------------------------------------------- herbs

def spirit_grass():
    ic = Icon()
    blades = union(
        leaf(64, 112, 86, 9, -0.05),
        leaf(58, 112, 70, 8, -0.5),
        leaf(70, 112, 72, 8, 0.48),
        leaf(52, 114, 50, 7, -0.95),
        leaf(76, 114, 52, 7, 0.9),
    )
    ic.shape(blades, (120, 220, 100))
    ic.line([(64, 104), (63, 40)], (255, 255, 255, 90), 2)
    ic.save("SpiritGrass")


def cloud_mint():
    ic = Icon()
    leaves = union(leaf(62, 104, 66, 22, -0.55), leaf(66, 104, 66, 22, 0.55), leaf(64, 108, 40, 14, 0))
    ic.shape(leaves, (140, 215, 230))
    ic.line([(62, 102), (36, 58)], (255, 255, 255, 110), 2.4)
    ic.line([(66, 102), (92, 58)], (255, 255, 255, 110), 2.4)
    ic.line([(64, 110), (64, 120)], INK, 5)
    ic.save("CloudMint")


def blood_ginseng():
    ic = Icon()
    root = union(
        ellipse([46, 40, 82, 96]),
        poly([(50, 84), (60, 86), (46, 120), (40, 118)]),
        poly([(68, 86), (78, 84), (90, 118), (84, 120)]),
        poly([(48, 60), (52, 66), (28, 82), (26, 78)]),
        poly([(78, 60), (76, 66), (100, 80), (102, 76)]),
    )
    ic.shape(root, (205, 70, 70))
    tuft = union(leaf(64, 44, 30, 8, -0.4), leaf(64, 44, 30, 8, 0.4), leaf(64, 44, 34, 7, 0))
    ic.shape(tuft, (120, 200, 100), outline=4)
    for y in (58, 70, 82):
        ic.line([(52, y), (60, y + 3)], (90, 20, 24, 200), 2)
    ic.gloss([54, 46, 66, 70])
    ic.save("BloodGinseng")


def moonpetal_orchid():
    ic = Icon()
    petals = union(*[leaf(64, 66, 46, 15, a) for a in [i * 2 * math.pi / 5 for i in range(5)]])
    ic.shape(petals, (215, 195, 255))
    ic.shape(ellipse([54, 56, 74, 76]), (255, 214, 120), outline=3)
    for a in [i * 2 * math.pi / 5 for i in range(5)]:
        ic.line([(64, 66), (64 + 30 * math.sin(a), 66 - 30 * math.cos(a))], (255, 255, 255, 90), 2)
    ic.save("MoonpetalOrchid")


def lingzhi():
    ic = Icon()
    stem = poly([(58, 76), (70, 76), (74, 118), (54, 118)])
    ic.shape(stem, (200, 150, 90))
    cap = union(ellipse([18, 34, 110, 86]))
    cap.paste(0, (0, 0), ellipse([40, 70, 88, 100]))
    ic.shape(cap, (240, 150, 50))
    d = ImageDraw.Draw(ic.img)
    for k, inset in enumerate((10, 20, 30)):
        d.arc([(18 + inset) * SS, (34 + inset * 0.55) * SS, (110 - inset) * SS, (86 - inset * 0.2) * SS], 190, 350, fill=(140, 70, 20, 200), width=2 * SS)
    ic.gloss([38, 40, 70, 54])
    ic.save("NineLeafLingzhi")


# ---------------------------------------------------------------- cores

def core(name, color, flame):
    ic = Icon()
    ic.glow((64, 66), 46, color, 120)
    if flame:
        tongues = union(*[leaf(64, 66, 54, 13, a) for a in [i * 2 * math.pi / 7 + 0.2 for i in range(7)]])
        ic.shape(tongues, darken(color, 0.1), outline=4, light=0.2)
    ic.shape(ellipse([34, 36, 94, 96]), color, light=0.55)
    d = ImageDraw.Draw(ic.img)
    d.arc([46 * SS, 48 * SS, 82 * SS, 84 * SS], 200, 470, fill=(255, 255, 255, 150), width=3 * SS)
    ic.gloss([44, 42, 66, 58], 160)
    ic.save(name)


# ---------------------------------------------------------------- treasures

def heavenly_dew():
    ic = Icon()
    ic.glow((64, 76), 34, (150, 220, 255), 110)
    pts = []
    for i in range(61):
        a = math.pi * (i / 60)
        pts.append((64 + 30 * math.cos(a + math.pi), 80 + 30 * math.sin(a)))
    drop = union(poly([(64, 18), (34, 80), (94, 80)]), ellipse([34, 50, 94, 110]))
    ic.shape(drop, (150, 215, 255), light=0.5)
    ic.gloss([46, 58, 60, 84], 170)
    ic.save("HeavenlyDew")


def cloud_jade():
    ic = Icon()
    disc = ellipse([16, 16, 112, 112])
    disc.paste(0, (0, 0), ellipse([48, 48, 80, 80]))
    ic.shape(disc, (130, 225, 165), light=0.35)
    d = ImageDraw.Draw(ic.img)
    for cx, cy, a in ((38, 54, 0), (88, 74, 180)):
        pts = []
        for i in range(50):
            t = i / 49
            r = 10 * (1 - 0.7 * t)
            ang = math.radians(a) + t * 2 * math.pi * 1.2
            pts.append(((cx + r * math.cos(ang)) * SS, (cy + r * math.sin(ang)) * SS))
        d.line(pts, fill=(50, 120, 80, 220), width=int(2.5 * SS), joint="curve")
    d.ellipse([16 * SS, 16 * SS, 112 * SS, 112 * SS], outline=GOLD, width=2 * SS)
    ic.gloss([30, 24, 70, 44], 120)
    ic.save("CloudPatternJade")


def immortal_peach():
    ic = Icon()
    body = union(ellipse([22, 40, 70, 112]), ellipse([56, 40, 106, 112]), poly([(36, 56), (64, 24), (92, 56)]))
    ic.shape(body, (255, 165, 175), light=0.35)
    ic.line([(64, 32), (62, 100)], (200, 90, 110, 200), 2.5)
    ic.shape(leaf(66, 30, 40, 11, 1.0), (120, 200, 100), outline=4)
    ic.gloss([34, 50, 52, 76], 140)
    ic.save("ImmortalPeach")


# ---------------------------------------------------------------- currency / progress

def spirit_stone():
    """A spirit stone: a pale jade crystal with a soft qi glow, one facet ridge
    and a highlight. Used in the reward feed and beside prices."""
    ic = Icon()
    ic.glow((64, 66), 52, (190, 255, 230), 200)
    stone = poly([(64, 14), (96, 40), (100, 82), (64, 116), (28, 82), (32, 40)])
    ic.shape(stone, (160, 236, 210), light=0.7, dark=0.3)
    # facets: a shaded right face and a centre ridge
    shade = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(shade).polygon([(x * SS, y * SS) for x, y in [(66, 20), (94, 42), (97, 81), (66, 110)]], fill=(40, 120, 100, 90))
    ic.img.alpha_composite(shade)
    ic.line([(64, 18), (64, 110)], (255, 255, 255, 120), 2)
    ic.line([(36, 42), (64, 52), (92, 42)], (255, 255, 255, 80), 1.6)
    ic.gloss([40, 34, 56, 70], 170)
    ic.save("SpiritStone")


def insight():
    """Insight: an open eye of golden light with a violet iris and short rays
    above, for comprehension and enlightenment gains."""
    ic = Icon()
    ic.glow((64, 66), 48, (255, 220, 140), 140)
    # rays
    for k in range(5):
        a = math.radians(-60 + k * 30)
        x0, y0 = 64 + 40 * math.sin(a), 60 - 40 * math.cos(a)
        x1, y1 = 64 + 54 * math.sin(a), 60 - 54 * math.cos(a)
        ic.line([(x0, y0), (x1, y1)], INK, 7)
        ic.line([(x0, y0), (x1, y1)], (255, 222, 140, 255), 3.5)
    # almond eye: two arcs meeting at points
    pts = []
    for i in range(41):
        t = i / 40
        pts.append((14 + 100 * t, 74 - 30 * math.sin(math.pi * t)))
    for i in range(41):
        t = 1 - i / 40
        pts.append((14 + 100 * t, 74 + 24 * math.sin(math.pi * t)))
    ic.shape(poly(pts), (255, 236, 190), light=0.5, dark=0.15)
    ic.shape(ellipse([46, 54, 82, 90]), (150, 110, 230), outline=3, light=0.45)
    ic.shape(ellipse([57, 65, 71, 79]), (30, 20, 60), outline=1, light=0.1, dark=0.1)
    ic.gloss([58, 58, 68, 66], 220)
    ic.save("Insight")


# ---------------------------------------------------------------- weapons
# Weapons lie on the diagonal, grip at the lower left and tip at the upper right,
# drawn in a vertical frame (x across, y down the length, tip at the top) and
# turned 45 degrees so every class reads at hotbar size. Colours follow the
# models in art/weapons/: pale steel, bronze fittings, indigo grip wrap, lacquer
# red tassels, warm wood shafts.

STEEL = (196, 208, 226)
BRONZE = (214, 174, 96)
WRAP = (82, 88, 124)
TASSEL = (214, 84, 72)
WOOD = (166, 118, 74)


class Diag:
    """Maps vertical-frame points onto the 45 degree diagonal (tip to the upper right)."""

    def __init__(self, cy=64, k=1.0, deg=-45):
        """cy: the vertical-frame row that lands on the icon centre; k: scale."""
        a = math.radians(deg)
        self.c, self.s, self.cy, self.k = math.cos(a), math.sin(a), cy, k

    def p(self, x, y):
        dx, dy = (x - 64) * self.k, (y - self.cy) * self.k
        return (64 + dx * self.c + dy * self.s, 64 - dx * self.s + dy * self.c)

    def poly(self, pts):
        return poly([self.p(x, y) for x, y in pts])

    def rect(self, x0, y0, x1, y1):
        return self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])

    def oval(self, cx, cy, rx, ry, n=36):
        return self.poly([(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)])

    def line(self, ic, pts, color, width):
        ic.line([self.p(x, y) for x, y in pts], color, width)


def wrap_bands(ic, d, x0, x1, y0, y1, step=6):
    d_ = ImageDraw.Draw(ic.img)
    y = y0 + step
    while y < y1 - 1:
        d.line(ic, [(x0, y), (x1, y)], (40, 42, 70, 230), 1.6)
        y += step


def tassel(ic, d, x, y, length=22, spread=6):
    ic.shape(d.poly([(x - 2, y), (x + 2, y), (x + spread, y + length), (x - spread, y + length)]), TASSEL, outline=3)


def jian():
    """Straight double-edged sword: long tapering blade, bronze wing guard, wrapped
    grip, bronze pommel and a red tassel."""
    ic, d = Icon(), Diag(68, 0.92)
    tassel(ic, d, 64, 128, 18, 6)
    ic.shape(d.rect(60, 96, 68, 122), WRAP, outline=4)
    wrap_bands(ic, d, 60, 68, 96, 122, 5)
    ic.shape(d.oval(64, 125, 6, 5), BRONZE, outline=4)
    ic.shape(d.poly([(58, 6), (64, -6), (70, 6), (70.5, 88), (57.5, 88)]), STEEL, outline=4, light=0.6)
    d.line(ic, [(64, 0), (64, 86)], (255, 255, 255, 140), 1.6)
    ic.shape(d.poly([(46, 92), (52, 86), (76, 86), (82, 92), (76, 98), (52, 98)]), BRONZE, outline=4)
    ic.save("IronJian")


def dadao():
    """Broad saber: a wide single-edged blade swelling toward a clipped tip, a
    small disc guard, wrapped grip, ring pommel with a red tassel."""
    ic, d = Icon(), Diag(70, 0.95)
    tassel(ic, d, 64, 128, 14, 7)
    ring = d.oval(64, 122, 7, 7)
    ring.paste(0, (0, 0), d.oval(64, 122, 3.2, 3.2))
    ic.shape(ring, BRONZE, outline=3)
    ic.shape(d.rect(60, 88, 68, 115), WRAP, outline=4)
    wrap_bands(ic, d, 60, 68, 88, 115, 5)
    blade = d.poly([(58, 80), (56, 40), (57, 14), (60, 2), (80, 14), (82, 44), (74, 80)])
    ic.shape(blade, STEEL, outline=4, light=0.6)
    d.line(ic, [(60, 10), (60, 78)], (255, 255, 255, 140), 1.6)
    ic.shape(d.oval(64, 84, 12, 4), BRONZE, outline=4)
    ic.save("IronDadao")


def greatsword():
    """Two-handed great sword: a wide heavy blade with a fuller, a broad bronze
    guard and a long wrapped grip."""
    ic, d = Icon(), Diag(62, 0.95)
    ic.shape(d.rect(59.5, 92, 68.5, 124), WRAP, outline=4)
    wrap_bands(ic, d, 59.5, 68.5, 92, 124, 5)
    ic.shape(d.oval(64, 126, 7, 5), BRONZE, outline=4)
    ic.shape(d.poly([(54, 8), (64, -8), (74, 8), (75, 84), (53, 84)]), STEEL, outline=4, light=0.6)
    ic.shape(d.rect(62.5, 10, 65.5, 78), darken(STEEL, 0.25), outline=0, light=0.2)
    d.line(ic, [(57, 6), (57, 82)], (255, 255, 255, 140), 1.6)
    ic.shape(d.poly([(40, 88), (46, 82), (82, 82), (88, 88), (82, 94), (46, 94)]), BRONZE, outline=4)
    ic.save("IronGreatsword")


def guandao():
    """Crescent glaive: a curved moon blade with a back spike on a long wood
    shaft, bronze collar and red tassel, wrapped near the butt."""
    ic, d = Icon(), Diag(54, 0.84)
    ic.shape(d.rect(60, 34, 68, 132), WOOD, outline=4, light=0.3)
    ic.shape(d.rect(60, 100, 68, 116), WRAP, outline=3)
    wrap_bands(ic, d, 60, 68, 100, 116, 5)
    ic.shape(d.poly([(61, 132), (67, 132), (64, 140)]), BRONZE, outline=3)
    tassel(ic, d, 64, 28, 14, 8)
    blade = d.poly([(60, 24), (60, 4), (62, -14), (68, -32), (78, -16), (84, 2), (82, 18), (72, 24)])
    ic.shape(blade, STEEL, outline=4, light=0.6)
    ic.shape(d.poly([(61, 10), (50, 2), (52, 12), (61, 18)]), STEEL, outline=3, light=0.6)
    d.line(ic, [(64, -16), (63, 20)], (255, 255, 255, 140), 1.6)
    ic.shape(d.oval(64, 27, 6, 4), BRONZE, outline=4)
    ic.save("IronGuandao")


def spear():
    """Spear (art/weapons/spear): a slim leaf-shaped steel head on a bronze
    collar, a bell of red horsehair below it, a long wood shaft with two indigo
    wrap bands and a rounded bronze butt cap."""
    ic, d = Icon(), Diag(60, 0.88)
    ic.shape(d.rect(60, 30, 68, 134), WOOD, outline=4, light=0.3)
    for y0, y1 in ((76, 90), (100, 114)):
        ic.shape(d.rect(59.5, y0, 68.5, y1), WRAP, outline=3)
        wrap_bands(ic, d, 59.5, 68.5, y0, y1, 5)
    ic.shape(d.oval(64, 136, 5.5, 6), BRONZE, outline=3)
    ic.shape(d.poly([(60, 16), (68, 16), (76, 34), (52, 34)]), TASSEL, outline=3)
    ic.shape(d.poly([(64, -22), (69.5, -2), (64, 12), (58.5, -2)]), STEEL, outline=4, light=0.6)
    d.line(ic, [(64, -18), (64, 10)], (255, 255, 255, 150), 1.6)
    ic.shape(d.rect(60, 10, 68, 17), BRONZE, outline=3)
    ic.save("IronSpear")


def staff():
    """Staff: a long wood pole with bronze caps, two indigo wrap bands and a red
    cloth tie near the head."""
    ic, d = Icon(), Diag(64, 0.86)
    ic.shape(d.rect(59.5, -10, 68.5, 138), WOOD, outline=4, light=0.35)
    for y0, y1 in ((22, 40), (84, 102)):
        ic.shape(d.rect(59.5, y0, 68.5, y1), WRAP, outline=3)
        wrap_bands(ic, d, 59.5, 68.5, y0, y1, 5)
    ic.shape(d.poly([(62, 2), (66, 2), (74, 18), (69, 20)]), TASSEL, outline=3)
    ic.shape(d.poly([(62, 2), (66, 2), (59, 20), (54, 18)]), TASSEL, outline=3)
    for y in (-12, 132):
        ic.shape(d.rect(59.5, y, 68.5, y + 8), BRONZE, outline=3)
    d.line(ic, [(62.5, -4), (62.5, 130)], (255, 255, 255, 90), 1.4)
    ic.save("BambooStaff")


def fist():
    """Bare fists (no weapon): a clenched fist seen from the front, knuckles up,
    in warm skin tone with an indigo wrist wrap."""
    ic = Icon()
    skin = (236, 196, 156)
    ic.shape(poly([(38, 80), (90, 80), (86, 116), (42, 116)]), WRAP, outline=4)
    for y in (90, 100, 108):
        ic.line([(41, y), (88, y)], (40, 42, 70, 230), 1.6)
    palm = union(
        poly([(30, 50), (98, 46), (100, 84), (36, 88)]),
        *[ellipse([24 + i * 18, 26 + abs(i - 1.5) * 3, 46 + i * 18, 58 + abs(i - 1.5) * 3]) for i in range(4)],
    )
    ic.shape(palm, skin, light=0.35, dark=0.25)
    for i in range(1, 4):
        x = 24 + i * 18
        ic.line([(x, 34 + abs(i - 1.5) * 3), (x + 1, 54)], (150, 100, 70, 230), 2)
    thumb = union(poly([(32, 64), (62, 60), (66, 74), (34, 80)]), ellipse([54, 58, 74, 76]))
    ic.shape(thumb, skin, outline=3, light=0.3, dark=0.2)
    ic.line([(40, 30), (44, 26)], (255, 255, 255, 150), 2.5)
    ic.save("Fist")


# ---------------------------------------------------------------- spirit root elements
# One symbol per element (Shared.Roots), in the element's colour. They sit on the
# round weapon badge disc (weapon_badge.png) in the reveal card and the Self card,
# so each stays inside a ~100px circle. Written as icon_Root<Element>.png.

def stroke_mask(pts, width):
    m = blank()
    ImageDraw.Draw(m).line([(x * SS, y * SS) for x, y in pts], fill=255, width=int(width * SS), joint="curve")
    r = width * SS / 2
    d = ImageDraw.Draw(m)
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x * SS - r, y * SS - r, x * SS + r, y * SS + r], fill=255)
    return m


def root_fire():
    """Fire: a three-tongued flame with a bright core."""
    ic = Icon()
    ic.glow((64, 76), 40, (255, 150, 80), 120)
    body = union(
        ellipse([30, 56, 98, 116]),
        poly([(31, 86), (50, 50), (70, 6), (78, 40), (97, 86)]),
        poly([(31, 96), (24, 56), (34, 64), (50, 78)]),
        poly([(97, 96), (102, 64), (92, 70), (80, 78)]),
    )
    ic.shape(body, (255, 120, 60), light=0.5, dark=0.25)
    core = union(ellipse([46, 78, 82, 112]), poly([(48, 92), (66, 46), (80, 92)]))
    ic.shape(core, (255, 214, 120), outline=0, light=0.6, dark=0.05)
    ic.gloss([50, 36, 60, 60], 150)
    ic.save("RootFire")


def root_water():
    """Water: a droplet with a wave across its lower half."""
    ic = Icon()
    drop = union(ellipse([30, 50, 98, 118]), poly([(32, 76), (64, 8), (96, 76)]))
    ic.shape(drop, (80, 160, 255), light=0.5, dark=0.35)
    wave = [(36, 92)] + [(36 + i * 2, 92 + 5 * math.sin(i / 32 * 2 * math.pi)) for i in range(29)]
    ic.line(wave, (255, 255, 255, 170), 4)
    ic.gloss([44, 50, 56, 78], 190)
    ic.save("RootWater")


def root_wood():
    """Wood: a sprout, a short stem with two broad leaves and a bud."""
    ic = Icon()
    stem = poly([(60, 118), (68, 118), (67, 50), (61, 50)])
    leaves = union(leaf(64, 74, 54, 20, -1.0), leaf(64, 64, 56, 20, 1.0), leaf(64, 56, 46, 14, 0))
    ic.shape(union(stem, leaves), (110, 200, 90), light=0.45, dark=0.3)
    ic.line([(62, 72), (30, 52)], (255, 255, 255, 110), 2.2)
    ic.line([(66, 62), (98, 42)], (255, 255, 255, 110), 2.2)
    ic.line([(64, 52), (64, 18)], (255, 255, 255, 90), 1.8)
    ic.save("RootWood")


def root_metal():
    """Metal: a silver yuanbao ingot, a boat-shaped base and a domed top."""
    ic = Icon()
    base = union(
        poly([(14, 62), (34, 64), (94, 64), (114, 62), (104, 92), (84, 104), (44, 104), (24, 92)]),
        ellipse([10, 52, 34, 72]),
        ellipse([94, 52, 118, 72]),
    )
    ic.shape(base, (215, 218, 232), light=0.5, dark=0.4)
    ic.shape(ellipse([40, 36, 88, 76]), (232, 234, 244), outline=4, light=0.6, dark=0.3)
    ic.line([(28, 80), (100, 80)], (120, 126, 150, 200), 2)
    ic.gloss([50, 42, 64, 56], 200)
    ic.save("RootMetal")


def root_earth():
    """Earth: a mountain, a tall peak and a shorter one with a ridge line."""
    ic = Icon()
    hills = union(poly([(8, 108), (52, 22), (82, 72), (92, 56), (120, 108)]))
    ic.shape(hills, (200, 150, 80), light=0.4, dark=0.4)
    shade = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(shade).polygon([(x * SS, y * SS) for x, y in [(52, 24), (82, 72), (76, 106), (56, 106), (60, 64)]], fill=(70, 40, 10, 80))
    ic.img.alpha_composite(shade)
    ic.line([(52, 26), (46, 46), (54, 60), (48, 78)], (255, 245, 220, 150), 2.4)
    ic.line([(16, 108), (112, 108)], INK, 4)
    ic.save("RootEarth")


def root_lightning():
    """Lightning: a zigzag bolt with a violet glow."""
    ic = Icon()
    ic.glow((64, 64), 44, (180, 140, 255), 150)
    bolt = poly([(72, 6), (30, 70), (58, 70), (44, 122), (100, 50), (70, 50), (90, 6)])
    ic.shape(bolt, (190, 150, 255), light=0.6, dark=0.25)
    ic.line([(76, 14), (50, 60)], (255, 255, 255, 170), 2.6)
    ic.save("RootLightning")


def root_wind():
    """Wind: a curling gust, a spiral with two trailing streaks."""
    ic = Icon()
    spiral = []
    for i in range(70):
        t = i / 69
        a = math.radians(-90 + 400 * t)
        r = 8 + 26 * t
        spiral.append((70 + r * math.cos(a) * -1, 54 + r * math.sin(a) * -1))
    spiral.append((10, spiral[-1][1]))
    gust = union(stroke_mask(spiral, 11), stroke_mask([(28, 96), (100, 96)], 9), stroke_mask([(44, 114), (86, 114)], 8))
    ic.shape(gust, (150, 235, 210), outline=4, light=0.5, dark=0.3)
    ic.save("RootWind")


def root_ice():
    """Ice: a six-armed snowflake with small side branches."""
    ic = Icon()
    ic.glow((64, 64), 40, (190, 240, 255), 130)
    masks = []
    for k in range(6):
        a = math.radians(k * 60)
        ca, sa = math.cos(a), math.sin(a)
        p = lambda r, s: (64 + r * sa + s * ca, 64 - r * ca + s * sa)
        masks.append(stroke_mask([p(0, 0), p(50, 0)], 9))
        masks.append(stroke_mask([p(30, 0), p(44, -12)], 7))
        masks.append(stroke_mask([p(30, 0), p(44, 12)], 7))
    masks.append(poly([(64 + 14 * math.sin(math.radians(k * 60)), 64 - 14 * math.cos(math.radians(k * 60))) for k in range(6)]))
    ic.shape(union(*masks), (170, 230, 255), outline=4, light=0.6, dark=0.3)
    ic.gloss([56, 54, 66, 62], 200)
    ic.save("RootIce")


ROOTS = [root_fire, root_water, root_wood, root_metal, root_earth, root_lightning, root_wind, root_ice]


if __name__ == "__main__":
    import sys

    if sys.argv[1:] == ["roots"]:
        for draw in ROOTS:
            draw()
        sys.exit()
    spirit_grass()
    cloud_mint()
    blood_ginseng()
    moonpetal_orchid()
    lingzhi()
    core("LesserSpiritCore", (110, 225, 205), flame=False)
    core("GreaterSpiritCore", (255, 120, 90), flame=True)
    heavenly_dew()
    cloud_jade()
    immortal_peach()
    spirit_stone()
    insight()
    jian()
    dadao()
    greatsword()
    guandao()
    spear()
    staff()
    fist()
    for draw in ROOTS:
        draw()
