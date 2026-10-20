"""Draws the lock-on art: the target reticle and its spinning ring, the
shift-lock cursor, the Lock
touch button (off and lit), and the health bar rim and end
caps shared by the boss bar and the enemy overhead bars.

Uses the shared helpers in draw_ui.py. Run:
    uv run --with pillow --with numpy python art/ui/draw_lockon.py
"""

import math

from PIL import Image, ImageDraw, ImageFilter

from draw_ui import GOLD, GOLD_HI, GOLD_LO, INK, SS, canvas, finish, gradient_rect, lozenge, shadow_under, spiral

PALE = (255, 246, 222, 255)  # reticle white-gold
GLYPH = (190, 230, 255, 255)  # matches the cluster's glyph colour


def ink_under(layer, grow=3, alpha=235):
    """An ink outline: the layer's alpha dilated and darkened beneath it, so a
    pale mark reads on bright sky and dark forest alike."""
    a = layer.getchannel("A").filter(ImageFilter.MaxFilter(grow * SS * 2 + 1))
    a = a.filter(ImageFilter.GaussianBlur(SS * 0.6)).point(lambda v: v * alpha // 255)
    out = Image.new("RGBA", layer.size, INK[:3] + (0,))
    out.putalpha(a)
    out.alpha_composite(layer)
    return out


def brush(d, a, b, w0, w1, color):
    """A tapered brush stroke from a (thick, w0) to b (thin, w1)."""
    steps = 28
    for k in range(steps + 1):
        t = k / steps
        x = a[0] + (b[0] - a[0]) * t
        y = a[1] + (b[1] - a[1]) * t
        r = (w0 + (w1 - w0) * t) / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def reticle_marks(d, c, scale, color, core_fill, core_dot):
    """Four bracket corners (brush strokes thick at the bend) and a diamond core."""
    arm = 30 * scale
    off = 74 * scale  # bend distance from centre, per axis
    w = 13 * scale
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx, by = c + sx * off, c + sy * off
            brush(d, (bx, by), (bx - sx * arm, by), w, w * 0.35, color)
            brush(d, (bx, by), (bx, by - sy * arm), w, w * 0.35, color)
    r = 27 * scale
    d.polygon([(c, c - r), (c + r, c), (c, c + r), (c - r, c)], fill=color)
    r2 = r * 0.58
    d.polygon([(c, c - r2), (c + r2, c), (c, c + r2), (c - r2, c)], fill=core_fill)
    r3 = r2 * 0.42
    d.ellipse([c - r3, c - r3, c + r3, c + r3], fill=core_dot)


def lock_reticle():
    """The lock-on cursor, 128px (shown at ~48px): white-gold brush brackets at the
    four corners and a jade-cored diamond, all ink-outlined. Stretched."""
    S = 128
    layer = canvas(S, S)
    d = ImageDraw.Draw(layer)
    c = S * SS / 2
    reticle_marks(d, c, SS * S / 200, PALE, (64, 190, 140, 255), PALE)
    img = ink_under(layer, grow=3)
    finish(img, "lock_reticle.png")


def lock_ring():
    """The outer ring that spins slowly around the reticle, 128px, same centre and
    size as lock_reticle: four gold arcs between the brackets, each ending in a
    small dot, ink-outlined. Stretched."""
    S = 128
    layer = canvas(S, S)
    d = ImageDraw.Draw(layer)
    c = S * SS / 2
    r = 48 * SS
    w = 4 * SS
    for k in range(4):
        start = k * 90 - 25
        d.arc([c - r, c - r, c + r, c + r], start, start + 50, fill=GOLD_HI, width=w)
        for a in (start, start + 50):
            ar = math.radians(a)
            x, y = c + math.cos(ar) * (r - w / 2), c + math.sin(ar) * (r - w / 2)
            d.ellipse([x - w, y - w, x + w, y + w], fill=GOLD_HI)
    img = ink_under(layer, grow=2, alpha=200)
    finish(img, "lock_ring.png")


def lock_icon(d, c, scale, color):
    """The button icon: a small reticle (brackets and diamond) in one colour."""
    reticle_marks(d, c, scale, color, (20, 44, 60, 255), color)


def lock_face():
    """The Lock button face, 256px, filling the button: the cluster's dark
    blue-jade disc with a pale-blue rim and a reticle icon. The gold
    round_frame ring sits over it like the other cluster buttons. Stretched."""
    S = 256
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    c = S * SS / 2
    r = 124 * SS
    d.ellipse([c - r, c - r, c + r, c + r], fill=(20, 44, 60, 220))
    d.ellipse([c - r, c - r, c + r, c + r], outline=(120, 190, 240, 255), width=5 * SS)
    icon = canvas(S, S)
    lock_icon(ImageDraw.Draw(icon), c, SS * 0.9, GLYPH)
    img.alpha_composite(icon)
    finish(img, "lock_face.png")


def lock_face_on():
    """The lit Lock state, 256px, laid over the button at 1.3x its size: a glowing
    jade disc (same diameter as the face) with a soft jade halo and a bright
    reticle icon. Stretched."""
    S = 256
    img = canvas(S, S)
    c = S * SS / 2
    r = 124 * SS / 1.3
    halo = Image.new("L", img.size, 0)
    ImageDraw.Draw(halo).ellipse([c - r - 6 * SS, c - r - 6 * SS, c + r + 6 * SS, c + r + 6 * SS], fill=200)
    halo = halo.filter(ImageFilter.GaussianBlur(12 * SS))
    glow = Image.new("RGBA", img.size, (90, 230, 170, 0))
    glow.putalpha(halo)
    img.alpha_composite(glow)
    disc = canvas(S, S)
    gradient_rect(disc, [c - r, c - r, c + r, c + r], (66, 170, 128), (16, 78, 60), radius=int(r))
    img.alpha_composite(disc)
    d = ImageDraw.Draw(img)
    d.ellipse([c - r, c - r, c + r, c + r], outline=(170, 250, 210, 255), width=5 * SS)
    icon = canvas(S, S)
    lock_icon(ImageDraw.Draw(icon), c, SS * 0.9 / 1.3, (255, 248, 226, 255))
    img.alpha_composite(ink_under(icon, grow=1, alpha=160))
    finish(img, "lock_face_on.png")


# Health bar rim: window inset (outer edge to window) in source pixels.
BAR = {"size": (512, 128), "inset": 24}


def bar_rim():
    """The rim laid over a health bar, 512x128: ink outline, a gold band with a lit
    top edge, a dark lip, and a transparent window the fills show through, with a
    faint glaze along its top. Drawn over the fills.
    9-slice with SliceCenter Rect(48, 48, 464, 80). The window is inset 24px, so
    the rim reaches 24 x SliceScale px outside the bar: SliceScale 0.25 on the
    boss bar (6px), 0.14 on the overhead bars."""
    W, H = BAR["size"]
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    m = 4 * SS
    k = BAR["inset"] * SS
    R = 20 * SS
    d.rounded_rectangle([m, m, W * SS - m, H * SS - m], radius=R, fill=INK)
    d.rounded_rectangle([m + 3 * SS, m + 3 * SS, W * SS - m - 3 * SS, H * SS - m - 3 * SS], radius=R - 3 * SS, fill=GOLD_LO)
    d.rounded_rectangle([m + 5 * SS, m + 5 * SS, W * SS - m - 5 * SS, H * SS - m - 5 * SS], radius=R - 5 * SS, fill=GOLD)
    d.rounded_rectangle([m + 5 * SS, m + 5 * SS, W * SS - m - 5 * SS, H * SS - m - 5 * SS], radius=R - 5 * SS, outline=GOLD_HI, width=3 * SS)
    d.rounded_rectangle([k - 5 * SS, k - 5 * SS, W * SS - k + 5 * SS, H * SS - k + 5 * SS], radius=9 * SS, fill=GOLD_LO)
    d.rounded_rectangle([k - 3 * SS, k - 3 * SS, W * SS - k + 3 * SS, H * SS - k + 3 * SS], radius=7 * SS, fill=INK)
    # cut the window
    alpha = img.getchannel("A")
    ImageDraw.Draw(alpha).rounded_rectangle([k, k, W * SS - k, H * SS - k], radius=5 * SS, fill=0)
    img.putalpha(alpha)
    gloss = canvas(W, H)
    ImageDraw.Draw(gloss).rectangle([k + 6 * SS, k + 2 * SS, W * SS - k - 6 * SS, k + 12 * SS], fill=(255, 255, 255, 40))
    img.alpha_composite(gloss)
    finish(img, "bar_rim.png")


def bar_cap():
    """The left end cap of the boss bar, 128px: a gold lozenge medallion with a
    cloud curl above and below, mirror-symmetric top to bottom so the right cap
    is the same image at Rotation 180. Stretched, at native 1:1."""
    S = 128
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    c = S * SS / 2
    for side in (-1, 1):
        spiral(d, c + 18 * SS, c + side * 28 * SS, 14 * SS, 1.2, math.pi, side, 6 * SS, GOLD_LO)
        spiral(d, c + 18 * SS, c + side * 28 * SS, 14 * SS, 1.2, math.pi, side, 4 * SS, GOLD)
        d.line([(c, c + side * 10 * SS), (c + 4 * SS, c + side * 28 * SS)], fill=GOLD, width=4 * SS)
    lozenge(d, c, c, 30 * SS, 5 * SS)
    img = ink_under(img, grow=2, alpha=200)
    finish(shadow_under(img, blur=2, offset=1, alpha=120), "bar_cap.png")


def shiftlock_reticle():
    """The shift-lock cursor, 64px (shown at ~26px), the quiet sibling of
    lock_reticle: a small jade-cored white-gold diamond and four short ticks at
    the cardinal points (the lock-on reticle uses corner brackets), all
    ink-outlined. Stretched."""
    S = 64
    layer = canvas(S, S)
    d = ImageDraw.Draw(layer)
    c = S * SS / 2
    gap, length, w = 11 * SS, 8 * SS, 4 * SS
    for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        a = (c + dx * gap, c + dy * gap)
        b = (c + dx * (gap + length), c + dy * (gap + length))
        brush(d, b, a, w, w * 0.55, PALE)
    r = 6 * SS
    d.polygon([(c, c - r), (c + r, c), (c, c + r), (c - r, c)], fill=PALE)
    r2 = r * 0.5
    d.polygon([(c, c - r2), (c + r2, c), (c, c + r2), (c - r2, c)], fill=(64, 190, 140, 255))
    finish(ink_under(layer, grow=2, alpha=225), "shiftlock_reticle.png")


if __name__ == "__main__":
    lock_reticle()
    shiftlock_reticle()
    lock_ring()
    lock_face()
    lock_face_on()
    bar_rim()
    bar_cap()
