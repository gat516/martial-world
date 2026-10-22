"""Draws the technique VFX textures: white shapes on transparent (alpha carries the
shape) so ParticleEmitter/Beam Color tints them. Soft edges throughout so they
read as qi, ink and paper rather than hard sprites.

Writes into this folder:
  glow.png        soft radial glow (flash cores, motes)
  ring.png        thin soft ring (ground shockwaves, rising rings)
  spark.png       four-point star glint
  mote.png        small soft dot with a bright centre (qi motes, embers)
  slash.png       beam texture for a sword-qi crescent: tapered along U, sharp
                  leading edge and soft tail across V
  ink.png         beam texture: a dry-brush ink stroke with bristle gaps
  bolt.png        beam texture: a jagged lightning strand on a soft glow
  seal.png        talisman seal circle: double ring, tick marks, eight brush glyphs
  runes.png       a narrow band of glyphs around a ring (rotating rune rings)
  flame.png       a stylised flame tongue (licks upward, round base)
  crack.png       radial ground cracks from a centre
  palm.png        a palm print silhouette (Palm Strike mastery)
  talisman.png    a paper talisman card with a brush glyph cut out of it
Run with Pillow and numpy:  uv run --with pillow --with numpy art/vfx/draw_vfx.py
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.dirname(os.path.abspath(__file__))


def save(name, alpha):
    """alpha: float array 0..1 or an 'L' image."""
    if isinstance(alpha, np.ndarray):
        a = Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8), "L")
    else:
        a = alpha
    img = Image.new("RGBA", a.size, (255, 255, 255, 0))
    img.putalpha(a)
    img.save(os.path.join(OUT, name))


def grid(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    return (x + 0.5) / w * 2 - 1, (y + 0.5) / h * 2 - 1  # -1..1


def glow():
    x, y = grid(256, 256)
    r = np.sqrt(x * x + y * y)
    a = np.clip(1 - r, 0, 1) ** 2.2
    save("glow.png", a)


def ring():
    x, y = grid(512, 512)
    r = np.sqrt(x * x + y * y)
    # sharp outer rim, soft inner falloff (a wave front moving outward)
    outer = np.clip((0.97 - r) / 0.025, 0, 1)
    inner = np.clip(1 - (0.9 - r) / 0.22, 0, 1) ** 2
    a = outer * inner
    save("ring.png", a)


def spark():
    x, y = grid(256, 256)
    ax, ay = np.abs(x), np.abs(y)
    star = np.clip(1 - (ax * 10 + ay) , 0, 1) ** 1.5 + np.clip(1 - (ay * 10 + ax), 0, 1) ** 1.5
    r = np.sqrt(x * x + y * y)
    core = np.clip(1 - r / 0.35, 0, 1) ** 2
    save("spark.png", np.clip(star + core, 0, 1))


def mote():
    x, y = grid(128, 128)
    r = np.sqrt(x * x + y * y)
    a = np.clip(1 - r, 0, 1) ** 3 * 0.7 + np.clip(1 - r / 0.3, 0, 1) ** 1.5
    save("mote.png", np.clip(a, 0, 1))


def slash():
    # Beam texture: U (x) runs along the beam from Attachment0 to Attachment1,
    # V (y) across its width. Leading edge at the top.
    w, h = 512, 128
    x, y = grid(w, h)
    along = np.clip(1 - np.abs(x) ** 2.4, 0, 1)  # tapered tips
    v = (y + 1) / 2  # 0 at top (leading edge) .. 1 at bottom (tail)
    edge = np.clip(v / 0.12, 0, 1)
    thick = 0.35 + 0.65 * along  # thicker in the middle
    tail = np.clip(1 - v / thick, 0, 1) ** 1.6
    a = edge * tail * along
    save("slash.png", a)


def ink():
    w, h = 512, 128
    rnd = random.Random(7)
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    # bristles: many thin strokes that start together and break up toward the end
    for i in range(46):
        yb = h * (0.18 + 0.64 * i / 45) + rnd.uniform(-2, 2)
        end = w * rnd.uniform(0.55, 0.98)
        x = w * rnd.uniform(0.0, 0.06)
        while x < end:
            seg = rnd.uniform(18, 90)
            gap = rnd.uniform(0, 14) * (x / w) ** 1.5 * 3
            d.line([(x, yb), (min(x + seg, end), yb + rnd.uniform(-1.5, 1.5))], fill=int(255 * rnd.uniform(0.7, 1)), width=rnd.choice([2, 3, 3, 4]))
            x += seg + gap
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    x, y = grid(w, h)
    fade = np.clip((x + 1) / 0.08, 0, 1) * np.clip((1 - x) / 0.5, 0, 1) ** 0.8
    a = np.asarray(img, np.float32) / 255 * fade
    save("ink.png", a)


def bolt():
    w, h = 512, 128
    rnd = random.Random(3)
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    pts = []
    n = 14
    for i in range(n + 1):
        px = w * i / n
        py = h / 2 + (rnd.uniform(-1, 1) * h * 0.28 if 0 < i < n else 0)
        pts.append((px, py))
    d.line(pts, fill=255, width=7, joint="curve")
    # a couple of forks
    for k in (4, 9):
        fx, fy = pts[k]
        d.line([(fx, fy), (fx + 40, fy + rnd.choice([-1, 1]) * 30), (fx + 70, fy + rnd.choice([-1, 1]) * 40)], fill=200, width=3)
    core = np.asarray(img.filter(ImageFilter.GaussianBlur(1.5)), np.float32) / 255
    halo = np.asarray(img.filter(ImageFilter.GaussianBlur(10)), np.float32) / 255
    a = np.clip(core + halo * 0.9, 0, 1)
    save("bolt.png", a)


def glyph(d, cx, cy, s, rnd, width):
    """A small brush glyph: a few short strokes in a square of size s."""
    for _ in range(rnd.randint(3, 5)):
        kind = rnd.random()
        if kind < 0.4:  # horizontal
            yy = cy + rnd.uniform(-0.4, 0.4) * s
            d.line([(cx - s * 0.4, yy), (cx + s * 0.4, yy + rnd.uniform(-0.05, 0.05) * s)], fill=255, width=width)
        elif kind < 0.75:  # vertical
            xx = cx + rnd.uniform(-0.35, 0.35) * s
            d.line([(xx, cy - s * 0.45), (xx + rnd.uniform(-0.1, 0.1) * s, cy + s * 0.45)], fill=255, width=width)
        else:  # diagonal sweep
            sgn = rnd.choice([-1, 1])
            d.line([(cx, cy - s * 0.1), (cx + sgn * s * 0.45, cy + s * 0.45)], fill=255, width=width)


def seal():
    S = 1024
    rnd = random.Random(11)
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    c = S / 2
    for r, wdt in ((0.48, 14), (0.43, 5), (0.27, 8), (0.22, 4)):
        R = S * r
        d.ellipse([c - R, c - R, c + R, c + R], outline=255, width=wdt)
    # tick marks between the outer rings
    for i in range(72):
        t = i / 72 * math.tau
        r0, r1 = S * 0.435, S * (0.46 if i % 3 else 0.475)
        d.line([(c + math.cos(t) * r0, c + math.sin(t) * r0), (c + math.cos(t) * r1, c + math.sin(t) * r1)], fill=255, width=4)
    # eight glyphs in the middle band
    for i in range(8):
        t = i / 8 * math.tau + math.pi / 8
        R = S * 0.35
        glyph(d, c + math.cos(t) * R, c + math.sin(t) * R, S * 0.085, rnd, 9)
    # an eight-point star (two squares) in the centre
    for rot in (0, math.pi / 4):
        R = S * 0.2
        pts = [(c + math.cos(rot + k * math.pi / 2) * R, c + math.sin(rot + k * math.pi / 2) * R) for k in range(4)]
        d.polygon(pts, outline=255, width=6)
    d.ellipse([c - 18, c - 18, c + 18, c + 18], fill=255)
    img = img.filter(ImageFilter.GaussianBlur(2.2)).resize((512, 512), Image.LANCZOS)
    # a faint wash inside so the seal reads as a lit disc, not just lines
    x, y = grid(512, 512)
    r = np.sqrt(x * x + y * y)
    wash = np.clip(1 - r / 0.97, 0, 1) ** 0.6 * 0.14
    a = np.clip(np.asarray(img, np.float32) / 255 + wash, 0, 1)
    save("seal.png", a)


def runes():
    S = 1024
    rnd = random.Random(5)
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    c = S / 2
    for r, wdt in ((0.47, 6), (0.37, 6)):
        R = S * r
        d.ellipse([c - R, c - R, c + R, c + R], outline=255, width=wdt)
    for i in range(16):
        t = i / 16 * math.tau
        R = S * 0.42
        glyph(d, c + math.cos(t) * R, c + math.sin(t) * R, S * 0.06, rnd, 7)
    img = img.filter(ImageFilter.GaussianBlur(2)).resize((512, 512), Image.LANCZOS)
    save("runes.png", img)


def flame():
    w = h = 256
    x, y = grid(w, h)
    # teardrop: round at the bottom, licking to a point at the top, slight S-bend
    yy = (y + 1) / 2  # 0 top .. 1 bottom
    bend = 0.12 * np.sin((1 - yy) * math.pi * 1.4)
    half = np.where(yy > 0.62, np.sqrt(np.clip(1 - ((yy - 0.62) / 0.36) ** 2, 0, 1)) * 0.5, 0.5 * (yy / 0.62) ** 1.3)
    dx = np.abs(x - bend)
    body = np.clip((half - dx) / 0.08, 0, 1)
    inner = np.clip((half * 0.5 - dx) / 0.08, 0, 1) * np.clip((yy - 0.35) / 0.3, 0, 1)
    a = body * (0.55 + 0.45 * inner) * np.clip((0.995 - yy) / 0.05, 0, 1)
    img = Image.fromarray((a * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(2))
    save("flame.png", img)


def crack():
    S = 1024
    rnd = random.Random(9)
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    c = S / 2

    def branch(x, y, ang, length, width, depth):
        steps = 6
        for _ in range(steps):
            ang += rnd.uniform(-0.35, 0.35)
            nx = x + math.cos(ang) * length / steps
            ny = y + math.sin(ang) * length / steps
            d.line([(x, y), (nx, ny)], fill=255, width=max(1, int(width)))
            x, y = nx, ny
            width *= 0.85
        if depth > 0:
            for s in (-1, 1):
                if rnd.random() < 0.6:
                    branch(x, y, ang + s * rnd.uniform(0.4, 0.8), length * 0.55, width, depth - 1)

    for i in range(9):
        a0 = i / 9 * math.tau + rnd.uniform(-0.2, 0.2)
        r0 = S * 0.05
        branch(c + math.cos(a0) * r0, c + math.sin(a0) * r0, a0, S * rnd.uniform(0.25, 0.4), 12, 2)
    img = img.filter(ImageFilter.GaussianBlur(1.5)).resize((512, 512), Image.LANCZOS)
    x, y = grid(512, 512)
    r = np.sqrt(x * x + y * y)
    a = np.asarray(img, np.float32) / 255 * np.clip((1 - r) / 0.25, 0, 1)
    save("crack.png", a)


def palm():
    S = 1024
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    # palm pad
    d.rounded_rectangle([S * 0.27, S * 0.44, S * 0.73, S * 0.86], radius=S * 0.16, fill=255)
    # fingers (index..little) and thumb, as rounded capsules
    fingers = [(0.335, 0.13, 0.5), (0.445, 0.07, 0.5), (0.555, 0.09, 0.5), (0.655, 0.18, 0.52)]
    for fx, top, bottom in fingers:
        w = S * 0.085
        d.rounded_rectangle([S * fx - w / 2, S * top, S * fx + w / 2, S * bottom], radius=w / 2, fill=255)
    # thumb: a capsule from the pad's lower left out and up
    w = S * 0.095
    a0, a1 = (S * 0.33, S * 0.72), (S * 0.17, S * 0.45)
    d.line([a0, a1], fill=255, width=int(w))
    for px, py in (a0, a1):
        d.ellipse([px - w / 2, py - w / 2, px + w / 2, py + w / 2], fill=255)
    # soft edge plus a brighter rim so it reads as a qi imprint, not a sticker
    solid = np.asarray(img.filter(ImageFilter.GaussianBlur(6)), np.float32) / 255
    inner = np.asarray(img.filter(ImageFilter.MinFilter(41)).filter(ImageFilter.GaussianBlur(14)), np.float32) / 255
    a = np.clip(solid - inner * 0.55, 0, 1)
    img = Image.fromarray((a * 255).astype(np.uint8), "L").resize((512, 512), Image.LANCZOS)
    save("palm.png", img)


def talisman():
    w, h = 256, 256
    rnd = random.Random(21)
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    # a tall paper strip centred in a square (particles are square)
    x0, x1, y0, y1 = w * 0.33, w * 0.67, h * 0.04, h * 0.96
    d.rectangle([x0, y0, x1, y1], fill=200)
    # brush glyphs cut out of it, top to bottom
    cut = Image.new("L", (w, h), 0)
    cd = ImageDraw.Draw(cut)
    for i in range(4):
        glyph(cd, w * 0.5, h * (0.17 + i * 0.21), w * 0.16, rnd, 5)
    cd.rectangle([x0 + 5, y0 + 5, x1 - 5, y1 - 5], outline=255, width=2)
    a = np.asarray(img, np.float32) / 255 * (1 - np.asarray(cut.filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255 * 0.85)
    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255
    save("talisman.png", a)


if __name__ == "__main__":
    for fn in (glow, ring, spark, mote, slash, ink, bolt, seal, runes, flame, crack, palm, talisman):
        fn()
        print("wrote", fn.__name__)
