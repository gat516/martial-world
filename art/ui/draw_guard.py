"""Draws the guard (posture) bar art: guard_rim.png, guard_fill.png, guard_seal.png, guard_cracks.png.

Hud.Play.Guard layout: a bronze-rimmed ink trough (guard_rim), a pale-gold fill
that drains toward the centre (guard_fill), a lacquer-and-bronze seal on the
centre (guard_seal) and red cracks shown on a guard break (guard_cracks).

guard_rim.png   512x64 stadium. SliceCenter Rect(36, 31, 476, 33), SliceScale 0.5
                (shown 256x32). Only the round ends hold curves; the centre rows
                are identical along the stretch.
guard_fill.png  512x64 stadium. SliceCenter Rect(36, 31, 476, 33), SliceScale 0.375
                (shown 24px high, inset in the rim).
guard_seal.png  96x96, Stretch at 1:1.
guard_cracks.png 512x64, Stretch at the rim's 8:1.
Run: uv run --with pillow --with numpy python art/ui/draw_guard.py
"""
import math
import random

from PIL import Image, ImageDraw, ImageFilter

from draw_ui import SS, GOLD, GOLD_HI, GOLD_LO, INK, canvas, finish, gradient_rect


def stadium(img, box, top, bot):
    x0, y0, x1, y1 = box
    gradient_rect(img, box, top, bot, radius=(y1 - y0) // 2)


def guard_rim():
    W, H = 512, 64
    img = canvas(W, H)
    s = SS
    d = ImageDraw.Draw(img)
    stadium(img, (0, 0, W * s, H * s), (14, 20, 24), (6, 9, 11))  # ink outline
    stadium(img, (2 * s, 2 * s, (W - 2) * s, (H - 2) * s), GOLD_HI[:3], GOLD_LO[:3])  # bronze rim
    stadium(img, (6 * s, 6 * s, (W - 6) * s, (H - 6) * s), (14, 20, 24), (14, 20, 24))
    stadium(img, (8 * s, 8 * s, (W - 8) * s, (H - 8) * s), (20, 34, 36), (6, 11, 14))  # lacquer back
    # fine gold hairline just inside the rim
    d.rounded_rectangle([7 * s, 7 * s, (W - 7) * s, (H - 7) * s], radius=25 * s, outline=GOLD_LO + (), width=s)
    # top light on the rim
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(hl).line([(30 * s, 3 * s), ((W - 30) * s, 3 * s)], fill=(255, 240, 190, 120), width=s)
    img.alpha_composite(hl)
    finish(img, "guard_rim.png")


def guard_fill():
    W, H = 512, 64
    img = canvas(W, H)
    s = SS
    stadium(img, (0, 0, W * s, H * s), (70, 44, 14), (70, 44, 14))
    stadium(img, (3 * s, 3 * s, (W - 3) * s, (H - 3) * s), (255, 244, 205), (206, 150, 66))
    d = ImageDraw.Draw(img)
    # soft sheen over the upper half, a darker belly below
    sheen = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sheen).rounded_rectangle([14 * s, 8 * s, (W - 14) * s, 24 * s], radius=8 * s, fill=(255, 255, 255, 110))
    sheen = sheen.filter(ImageFilter.GaussianBlur(3 * s))
    img.alpha_composite(sheen)
    # brush grain: faint long horizontal strokes (same along the stretch)
    rnd = random.Random(4)
    g = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    for y in (30, 38, 45, 51):
        gd.line([(24 * s, y * s), ((W - 24) * s, y * s)], fill=(150, 98, 30, 50), width=s)
    img.alpha_composite(g)
    finish(img, "guard_fill.png")


def guard_seal():
    S = 96
    img = canvas(S, S)
    s = SS
    d = ImageDraw.Draw(img)
    c = S * s // 2
    def dia(r, col):
        d.polygon([(c, c - r), (c + r, c), (c, c + r), (c - r, c)], fill=col)
    dia(44 * s, INK)
    dia(41 * s, GOLD_LO)
    dia(37 * s, GOLD)
    dia(30 * s, INK)
    dia(26 * s, (150, 28, 30, 255))  # lacquer red
    # chip highlight on the upper-left edge and a small bronze dot
    d.polygon([(c - 22 * s, c - 2 * s), (c - 2 * s, c - 22 * s), (c - 2 * s, c - 17 * s), (c - 17 * s, c - 2 * s)], fill=(215, 90, 80, 150))
    r = 5 * s
    d.ellipse([c - r, c - r, c + r, c + r], fill=GOLD_HI)
    finish(img, "guard_seal.png")


def guard_cracks():
    W, H = 512, 64
    img = canvas(W, H)
    s = SS
    d = ImageDraw.Draw(img)
    rnd = random.Random(11)
    cx, cy = W // 2, H // 2
    for side in (-1, 1):
        for k in range(5):
            x, y = cx, cy + rnd.randint(-6, 6)
            pts = [(x, y)]
            ang = math.radians(rnd.uniform(-35, 35))
            for _ in range(rnd.randint(6, 10)):
                step = rnd.uniform(18, 34)
                ang += math.radians(rnd.uniform(-40, 40))
                x += side * abs(math.cos(ang)) * step
                y = min(H - 14, max(14, y + math.sin(ang) * step))
                pts.append((x, y))
                if x < 14 or x > W - 14:
                    break
            pp = [(px * s, py * s) for px, py in pts]
            d.line(pp, fill=(40, 6, 8, 255), width=6 * s // 2, joint="curve")
            d.line(pp, fill=(235, 52, 44, 255), width=2 * s, joint="curve")
    finish(img, "guard_cracks.png")


if __name__ == "__main__":
    guard_rim()
    guard_fill()
    guard_seal()
    guard_cracks()
