"""Draws technique icons for the hotbar and Arts window: flat white glyphs with
bold, tapering brush strokes on a transparent background, matching the first
five (Sword Qi Wave, Palm Strike, Lightning Talisman, Iron Skin, Fire Seal).
They're white so the game tints them with the technique's colour (SlotArt).
Writes tech_<TechniqueId>.png (128x128) into icons/.
Run:  uv run --with pillow python art/ui/draw_techniques.py
"""

import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
S = 128
SS = 4
N = S * SS
WHITE = (255, 255, 255, 255)


class Glyph:
    def __init__(self):
        self.img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def poly(self, pts, fill=WHITE):
        self.d.polygon([(x * SS, y * SS) for x, y in pts], fill=fill)

    def cut(self, pts):
        """Punch a hole (transparent) in what's drawn so far."""
        self.d.polygon([(x * SS, y * SS) for x, y in pts], fill=(0, 0, 0, 0))

    def disc(self, cx, cy, r, fill=WHITE):
        self.d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=fill)

    def stroke(self, pts, w0, w1=None, wmid=None, steps=60):
        """A brush stroke along a polyline: width w0 at the start, w1 at the end,
        swelling to wmid in the middle when given."""
        w1 = w0 if w1 is None else w1
        segs = []
        total = 0
        for a, b in zip(pts, pts[1:]):
            L = math.dist(a, b)
            segs.append((a, b, L))
            total += L
        n = max(steps, int(total * 1.5))
        for k in range(n + 1):
            t = k / n
            s = t * total
            for a, b, L in segs:
                if s <= L or (a, b, L) == segs[-1]:
                    u = 0 if L == 0 else min(1, s / L)
                    x, y = a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u
                    break
                s -= L
            w = w0 + (w1 - w0) * t
            if wmid is not None:
                w = w + (wmid - (w0 + w1) / 2) * math.sin(math.pi * t)
            self.disc(x, y, w / 2)

    def arc(self, cx, cy, r, a0, a1, w0, w1=None, wmid=None):
        """A brush stroke along a circular arc (degrees, 0 = right, clockwise on screen)."""
        pts = []
        for i in range(61):
            a = math.radians(a0 + (a1 - a0) * i / 60)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        self.stroke(pts, w0, w1, wmid)

    def save(self, name):
        os.makedirs(OUT, exist_ok=True)
        self.img.resize((S, S), Image.LANCZOS).save(os.path.join(OUT, f"tech_{name}.png"))
        print("wrote", name)


def rot(pts, cx, cy, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


def comet(g, hx, hy, r, tail):
    """A qi blast flying up-right: a round head drawn out into a long tapering
    tail."""
    g.stroke([(hx - tail * 0.72, hy + tail * 0.72), (hx, hy)], 2, 2 * r)
    g.disc(hx, hy, r)


def twin_phoenix_cannon():
    """Two qi blasts from alternating fists: two comets flying up-right, side by
    side, the second a beat behind."""
    g = Glyph()
    comet(g, 70, 28, 16, 70)
    comet(g, 102, 62, 14, 56)
    g.save("TwinPhoenixCannon")


def moonflash_draw():
    """A dash-slash: a jian along the diagonal (tip upper right) and a crescent of
    moonlight cut across it."""
    g = Glyph()
    g.arc(66, 66, 52, 195, 335, 3, 3, 17)
    g.poly(rot([(58, 12), (64, 0), (70, 12), (70, 78), (58, 78)], 64, 64, 45))
    g.poly(rot([(46, 78), (82, 78), (82, 88), (46, 88)], 64, 64, 45))
    g.poly(rot([(59, 88), (69, 88), (69, 114), (59, 114)], 64, 64, 45))
    g.disc(*rot([(64, 119)], 64, 64, 45)[0], 7)
    g.save("MoonflashDraw")


def rampaging_tiger():
    """A tiger's rake: three curved claw cuts, thick in the middle and sharp at
    both ends, raking down across the icon."""
    g = Glyph()
    for dx in (-30, 0, 30):
        cx = 64 + dx
        pts = [(cx + 16, 8 + abs(dx) * 0.3), (cx + 7, 40), (cx - 5, 78), (cx - 16, 120 - abs(dx) * 0.3)]
        g.stroke(pts, 2, 2, 22)
    g.save("RampagingTiger")


def heaven_splitter():
    """A greatsword plunging point-down into the ground, the impact bursting
    out in rays over a broken ground line."""
    g = Glyph()
    g.poly([(50, 32), (78, 32), (78, 80), (64, 100), (50, 80)])
    g.poly([(32, 22), (96, 22), (96, 34), (32, 34)])
    g.poly([(58, 4), (70, 4), (70, 22), (58, 22)])
    g.disc(64, 5, 8)
    g.cut([(62, 38), (66, 38), (66, 82), (62, 82)])  # fuller
    g.stroke([(4, 110), (48, 110)], 10, 3)
    g.stroke([(80, 110), (124, 110)], 3, 10)
    for a in (195, 228, 312, 345):
        r0, r1 = 24, 46
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        g.stroke([(64 + r0 * ca, 104 + r0 * sa), (64 + r1 * ca, 104 + r1 * sa)], 9, 2)
    g.stroke([(58, 112), (50, 122), (42, 126)], 6, 2)
    g.stroke([(70, 112), (78, 122), (88, 126)], 6, 2)
    g.save("HeavenSplitter")


def crescent_sweep():
    """A spinning low sweep: a broad crescent moon swinging most of the way round,
    sharp at both horns, around the wielder (a dot)."""
    g = Glyph()
    g.arc(64, 64, 46, 120, 400, 3, 3, 26)
    g.disc(64, 64, 10)
    g.save("CrescentSweep")


def dragon_pierce():
    """A spear thrust: a long spear on the diagonal, a leaf head breaking through,
    a coiling stroke of qi wound around the shaft like a dragon."""
    g = Glyph()
    g.poly(rot([(59, 34), (69, 34), (69, 130), (59, 130)], 64, 64, 45))
    g.poly(rot([(64, -10), (78, 16), (64, 36), (50, 16)], 64, 64, 45))
    g.poly(rot([(54, 34), (74, 34), (74, 42), (54, 42)], 64, 64, 45))
    pts = []
    for i in range(80):
        t = i / 79
        y = 116 - 74 * t
        x = 64 + 20 * math.sin(t * math.pi * 3) * (1 - 0.35 * t)
        pts.append(rot([(x, y)], 64, 64, 45)[0])
    g.stroke(pts, 3, 9, 11)
    g.save("DragonPierce")


def great_sage_awakening():
    """A staff held upright with a blazing burst of power around its head: a
    ring of rays and a halo, for the awakening buff."""
    g = Glyph()
    cx, cy = 64, 38
    for k in range(10):
        a = math.radians(k * 36 - 90)
        g.stroke([(cx + 22 * math.cos(a), cy + 22 * math.sin(a)), (cx + 38 * math.cos(a), cy + 38 * math.sin(a))], 10, 2)
    g.arc(cx, cy, 15, 0, 360, 6, 6)
    g.poly([(58, 22), (70, 22), (70, 126), (58, 126)])
    for y0, y1 in ((16, 26), (116, 126), (66, 74), (86, 94)):
        g.poly([(54, y0), (74, y0), (74, y1), (54, y1)])
    g.save("GreatSageAwakening")


if __name__ == "__main__":
    twin_phoenix_cannon()
    moonflash_draw()
    rampaging_tiger()
    heaven_splitter()
    crescent_sweep()
    dragon_pierce()
    great_sage_awakening()
