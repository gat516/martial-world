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


if __name__ == "__main__":
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
