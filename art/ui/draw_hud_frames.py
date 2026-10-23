"""Draws the HUD's frames in the reference's language (docs/reference/ui/hud_vitals_reference.webp):
dark lacquer with real depth (a lit top edge, an inner shade pooling at the rims), a gilt
band that follows the shape, and small diamond studs set into it.

Phone HUD pass (user, 2026-10-23): "give the foundation establishment a shape and some
depth ... sharp on the edges but curved, well suiting ornaments". The realm plaque, the
vitals and seated plates, the top-right tiles, the key caps and the lock-on reticle are
drawn here; the bar rims, ruby caps and segment cuts stay the Figma kit's
(art/ui/figma/hud_*_rims.png), and the round buttons reuse the kit's round seal
(art/ui/figma/hud_round_seal.png). Gold is a vertical gradient lit from the upper left
with an ink outline; nothing is repeated ornament.

Outputs (art/ui/hud/, 2x display size):
hud_vitals_plate.png  1024x128  Stack.Vitals.Plate (Stretch; the Vitals box, aspect 8)
hud_seat_plate.png    1024x128  Stack.SeatBars.Plate
hud_realm_plaque.png  1024x92 (714x64 at 1x: 6 px clear top and bottom)    Vitals.Crest and SeatBars.TitleCrest (text live on top)
hud_tile.png          128x128   Buttons.* tile frames (Stretch, square)
hud_keycap.png        48x48     key hints (Buttons.CultivateButton.KeyLabel, DodgeButton.KeyLabel,
                                Play.LockHint.Key) 9-slice Rect(14, 14, 34, 34)
hud_timer_ring.png    96x96     white ring (buff chips' timer, tinted; two clipped halves)
hud_lock_reticle.png  128x128   Play.LockReticle: four gilt chevrons around a ruby diamond
hud_lock_ring.png     128x128   Play.LockReticle.Ring: a thin broken gilt circle (static)
hud_lock_on.png       128x128   Play.LockButton.On: a jade ring on the round seal's rim

Run: uv run --with pillow --with numpy python art/ui/draw_hud_frames.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hud")
SS = 4

GOLD_HI = (255, 236, 176)
GOLD = (222, 178, 94)
GOLD_LO = (128, 84, 32)
INK = (34, 20, 8)
BODY_TOP = (31, 37, 47)
BODY_BOT = (11, 13, 18)
LACQUER_TOP = (70, 30, 17)
LACQUER_BOT = (28, 10, 7)
RUBY_HI = (255, 120, 110)
RUBY = (196, 28, 36)
RUBY_LO = (92, 8, 16)
PEARL = (250, 240, 214)
JADE = (110, 226, 170)


def s(v):
    return v * SS


def blank(w, h):
    return Image.new("L", (s(w), s(h)), 0)


def save(img, name, out=None):
    """Downsample from the supersampled canvas; `out` overrides the 1x output size
    (a piece shown bigger than 1x on screen is written at about its display size,
    capped at 1024 wide, so Roblox's unfiltered GUI sampling doesn't cut its tips)."""
    os.makedirs(OUT, exist_ok=True)
    w, h = img.size
    img = img.resize(out or (w // SS, h // SS), Image.LANCZOS)
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


def erode(mask, px):
    """Shrinks an L mask by px (at SS scale), round enough for 45-degree edges."""
    if px <= 0:
        return mask
    k = int(px) * 2 + 1
    return mask.filter(ImageFilter.MinFilter(k if k % 2 else k + 1))


def dilate(mask, px):
    k = int(px) * 2 + 1
    return mask.filter(ImageFilter.MaxFilter(k))


def shift(mask, dx, dy):
    out = Image.new("L", mask.size, 0)
    out.paste(mask, (dx, dy))
    return out


def gradient(size, top, bot, y0=0, y1=None, stops=None):
    """An RGB image with a vertical gradient from y0 to y1 (clamped outside)."""
    w, h = size
    y1 = h if y1 is None else y1
    ys = np.clip((np.arange(h) - y0) / max(1, y1 - y0), 0, 1)
    if stops is None:
        stops = [(0, top), (1, bot)]
    cols = np.zeros((h, 3))
    for c in range(3):
        cols[:, c] = np.interp(ys, [p for p, _ in stops], [col[c] for _, col in stops])
    arr = np.repeat(cols[:, None, :], w, axis=1).astype(np.uint8)
    return Image.fromarray(arr, "RGB")


def paint(img, mask, rgb_img_or_color, alpha=255):
    """Composites a colour (or RGB image) through mask onto img."""
    if isinstance(rgb_img_or_color, tuple):
        layer = Image.new("RGBA", img.size, rgb_img_or_color + (255,))
    else:
        layer = rgb_img_or_color.convert("RGBA")
    a = mask if alpha == 255 else mask.point(lambda v: v * alpha // 255)
    layer.putalpha(a)
    img.alpha_composite(layer)


def gild(img, mask, outline=1.0, light=True):
    """Gold through mask: an ink outline, a vertical gradient over the mask's own
    bounds, a lit upper-left edge and a shaded lower-right edge."""
    box = mask.getbbox()
    if not box:
        return
    if outline:
        paint(img, dilate(mask, s(outline)), INK, 235)
    g = gradient(img.size, GOLD_HI, GOLD_LO, box[1], box[3], [(0, GOLD_HI), (0.42, GOLD), (1, GOLD_LO)])
    paint(img, mask, g)
    if light:
        d = max(1, SS // 2)
        hi = ImageChops.subtract(mask, shift(mask, d * 2, d * 2))
        lo = ImageChops.subtract(mask, shift(mask, -d * 2, -d * 2))
        paint(img, hi, GOLD_HI, 200)
        paint(img, lo, GOLD_LO, 170)


def lacquer(img, mask, top, bot, shade=170, lit=110):
    """A lacquered body: gradient, an inner shade pooling at the rim and a lit top edge."""
    box = mask.getbbox()
    paint(img, mask, gradient(img.size, top, bot, box[1], box[3]))
    # inner shade: dark where the body is near its own edge
    inner = erode(mask, s(3)).filter(ImageFilter.GaussianBlur(s(3)))
    edge = ImageChops.multiply(mask, ImageChops.invert(inner))
    paint(img, edge, (0, 0, 0), shade)
    # the lit top edge: a soft warm line just inside the top
    top_edge = ImageChops.subtract(erode(mask, s(1)), shift(erode(mask, s(1)), 0, s(2)))
    paint(img, top_edge.filter(ImageFilter.GaussianBlur(s(0.6))), (255, 226, 170), lit)


def polygon_mask(w, h, pts):
    m = blank(w, h)
    ImageDraw.Draw(m).polygon([(s(x), s(y)) for x, y in pts], fill=255)
    return m


def diamond_pts(cx, cy, rx, ry=None):
    ry = rx if ry is None else ry
    return [(cx, cy - ry), (cx + rx, cy), (cx, cy + ry), (cx - rx, cy)]


def set_in_socket(img, cx, cy, r):
    """A socket the kit stud sits in: a dark diamond rimmed in gold, breaking the band."""
    w, h = img.size[0] // SS, img.size[1] // SS
    outer = polygon_mask(w, h, diamond_pts(cx, cy, r + 4))
    inner = polygon_mask(w, h, diamond_pts(cx, cy, r + 2.5))
    paint(img, dilate(outer, s(1)), INK, 235)
    gild(img, ImageChops.subtract(outer, inner), outline=0)
    paint(img, inner, (8, 9, 12))


def trough(img, mask, tint):
    """A recessed bar trough: dark, shaded under its top lip, a faint lit bottom lip."""
    box = mask.getbbox()
    top = tuple(min(255, int(c * 0.55)) for c in tint)
    paint(img, mask, gradient(img.size, top, tint, box[1], box[3]))
    lip = ImageChops.subtract(mask, shift(mask, 0, s(4))).filter(ImageFilter.GaussianBlur(s(1.5)))
    paint(img, ImageChops.multiply(lip, mask), (0, 0, 0), 200)
    low = ImageChops.subtract(mask, shift(mask, 0, -s(1)))
    paint(img, low, (255, 255, 255), 26)


def pointed(w, h, x0, y0, x1, y1, depth):
    ym = (y0 + y1) / 2
    return polygon_mask(w, h, [(x0 + depth, y0), (x1 - depth, y0), (x1, ym), (x1 - depth, y1), (x0 + depth, y1), (x0, ym)])


def rounded(w, h, x0, y0, x1, y1):
    m = blank(w, h)
    r = (y1 - y0) / 2
    ImageDraw.Draw(m).rounded_rectangle([s(x0), s(y0), s(x1), s(y1)], radius=s(r), fill=255)
    return m


# The Vitals box at 2x (1024x128 for 520x65). Bar windows from assets/Hud.rbxmx (scale
# of the box); troughs reach the kit rims, 2.4 px (1.2 at 1x) outside each window.
W, H = 1024, 128
PAD = 2.4
BODY = (12, 1, 1011, 92)  # the plate body; the tab hangs under its middle
TAB = (252, 126)  # tab x0 (mirrored) and bottom
CH = 7  # body corner chamfer
TCH = 6  # tab corner chamfer


def box(x, y, w, h):
    return (x * W, y * H, (x + w) * W, (y + h) * H)


HEALTH = box(0.058, 0.10, 0.885, 0.30)
QI = box(0.069133, 0.44, 0.862734, 0.20)
GUARD = box(0.279, 0.75, 0.442, 0.15)
TRACK = box(0.058, 0.11, 0.885, 0.52)


def plate_outline():
    x0, y0, x1, y1 = BODY
    tx0, tb = TAB
    tx1 = W - 1 - tx0
    return [
        (x0 + CH, y0), (x1 - CH, y0), (x1, y0 + CH), (x1, y1 - CH), (x1 - CH, y1),
        (tx1, y1), (tx1, tb - TCH), (tx1 - TCH, tb), (tx0 + TCH, tb), (tx0, tb - TCH), (tx0, y1),
        (x0 + CH, y1), (x0, y1 - CH), (x0, y0 + CH),
    ]


def plate(name, troughs, studs):
    img = Image.new("RGBA", (s(W), s(H)), (0, 0, 0, 0))
    body = polygon_mask(W, H, plate_outline())
    lacquer(img, body, BODY_TOP, BODY_BOT)
    # the gilt band follows the whole notched outline, with a fine inner line 3 px in
    band = ImageChops.subtract(body, erode(body, s(2.6)))
    inner = ImageChops.subtract(erode(body, s(5.2)), erode(body, s(6.2)))
    paint(img, inner, GOLD, 150)
    gild(img, band, outline=0)
    for mask, tint in troughs:
        trough(img, mask, tint)
    for cx, cy, r in studs:
        set_in_socket(img, cx, cy, r)
    save(img, name)


def vitals_plate():
    health = pointed(W, H, HEALTH[0] - PAD, HEALTH[1] - PAD, HEALTH[2] + PAD, HEALTH[3] + PAD, 0.3 * (HEALTH[3] - HEALTH[1]) + PAD)
    qi = rounded(W, H, QI[0] - PAD, QI[1] - PAD, QI[2] + PAD, QI[3] + PAD)
    guard = rounded(W, H, GUARD[0] - PAD, GUARD[1] - PAD, GUARD[2] + PAD, GUARD[3] + PAD)
    plate(
        "hud_vitals_plate.png",
        [(health, (52, 10, 14)), (qi, (8, 22, 40)), (guard, (40, 30, 14))],
        [(11.5, 31.5, 11), (1011.5, 31.5, 11), (11.5, 68.5, 8), (1011.5, 68.5, 8), (251.5, 99.5, 8), (771.5, 99.5, 8)],
    )


def seat_plate():
    track = pointed(W, H, TRACK[0] - PAD, TRACK[1] - PAD, TRACK[2] + PAD, TRACK[3] + PAD, 0.3 * (TRACK[3] - TRACK[1]) + PAD)
    dantian = rounded(W, H, GUARD[0] - PAD, GUARD[1] - PAD, GUARD[2] + PAD, GUARD[3] + PAD)
    plate(
        "hud_seat_plate.png",
        [(track, (16, 36, 34)), (dantian, (12, 30, 40))],
        [(11.5, 46.5, 11), (1011.5, 46.5, 11), (251.5, 99.5, 8), (771.5, 99.5, 8)],
    )


def gem_stud(img, cx, cy, r, gem="pearl"):
    """The reference's end stud: a gilt diamond frame, a dark well, a small gem."""
    w, h = img.size[0] // SS, img.size[1] // SS
    outer = polygon_mask(w, h, diamond_pts(cx, cy, r))
    well = polygon_mask(w, h, diamond_pts(cx, cy, r * 0.62))
    gild(img, ImageChops.subtract(outer, well), outline=1.0)
    paint(img, well, (16, 10, 6))
    gr = r * 0.34
    if gem == "pearl":
        paint(img, polygon_mask(w, h, diamond_pts(cx, cy, gr)), (196, 176, 136))
        paint(img, polygon_mask(w, h, [(cx, cy - gr), (cx + gr * 0.2, cy - gr * 0.2), (cx, cy), (cx - gr, cy)]), PEARL)
    else:
        paint(img, polygon_mask(w, h, diamond_pts(cx, cy, gr * 1.25)), RUBY)
        paint(img, polygon_mask(w, h, [(cx, cy - gr * 1.25), (cx, cy), (cx - gr * 1.25, cy)]), RUBY_HI)
        paint(img, polygon_mask(w, h, [(cx, cy + gr * 1.25), (cx, cy), (cx + gr * 1.25, cy)]), RUBY_LO)


def stroke_path(w, h, pts, width):
    m = blank(w, h)
    d = ImageDraw.Draw(m)
    d.line([(s(x), s(y)) for x, y in pts], fill=255, width=int(s(width)), joint="curve")
    for x, y in (pts[0], pts[-1]):
        r = s(width) / 2
        d.ellipse([s(x) - r, s(y) - r, s(x) + r, s(y) + r], fill=255)
    return m


def curl(cx, cy, r0, turns, start, direction):
    pts = []
    n = int(60 * turns)
    for i in range(n + 1):
        t = i / n
        a = start + direction * t * turns * 2 * math.pi
        r = r0 * (1 - 0.72 * t)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def scroll(w, h, tip_x, cy, direction):
    """A small scroll set off the plaque's point: a stem with a curl above and below it
    and a bud at its end (the reference's end scroll, kept small)."""
    m = blank(w, h)
    sx = tip_x - direction * 2
    ex = tip_x - direction * 30
    m = ImageChops.lighter(m, stroke_path(w, h, [(sx, cy), (ex, cy)], 1.6))
    cxr = tip_x - direction * 15
    # upper curl rolls back toward the plaque, the lower one mirrors it
    up = curl(cxr, cy - 7.5, 6.5, 1.15, math.pi / 2, -direction)
    lo = [(x, 2 * cy - y) for x, y in up]
    for path in (up, lo):
        m = ImageChops.lighter(m, stroke_path(w, h, path, 2.0))
    # bud: a small diamond at the stem's end
    m = ImageChops.lighter(m, polygon_mask(w, h, diamond_pts(ex - direction * 2, cy, 4, 3.2)))
    return m


def realm_plaque():
    """714x52: a lacquer plaque whose ends come to points through curved bevels, a gilt
    band and fine inner line following it, a gem stud set into each point and a small
    scroll beyond it. RealmText sits over 0.242-0.758 of the width (173-541 px)."""
    w, h = 714, 52
    img = Image.new("RGBA", (s(w), s(h)), (0, 0, 0, 0))
    lx, rx, cy = 92, w - 92, h / 2
    top, bot, c = 4, h - 4, 22  # c: how far in the bevels reach
    pts = []
    # curved bevels: concave quarter-ish arcs from the flat edge to the point
    def bevel(x_flat, y_edge, x_tip, side):
        out = []
        for i in range(17):
            t = i / 16
            # concave: the bevel leaves the flat edge steeply and sweeps out to a sharp point
            x = x_flat + (x_tip - x_flat) * t ** 1.5
            y = y_edge + (cy - y_edge) * t
            out.append((x, y))
        return out
    pts += [(lx + c, top), (rx - c, top)]
    pts += bevel(rx - c, top, rx, 1)[1:]
    pts += list(reversed(bevel(rx - c, bot, rx, 1)))[1:]
    pts += [(lx + c, bot)]
    pts += bevel(lx + c, bot, lx, -1)[1:]
    pts += list(reversed(bevel(lx + c, top, lx, -1)))[1:-1]
    body = polygon_mask(w, h, pts)
    lacquer(img, body, LACQUER_TOP, LACQUER_BOT, shade=150, lit=120)
    band = ImageChops.subtract(body, erode(body, s(2.4)))
    inner = ImageChops.subtract(erode(body, s(5)), erode(body, s(6)))
    paint(img, inner, GOLD, 170)
    gild(img, band, outline=0)
    paint(img, ImageChops.subtract(dilate(body, s(1)), body), INK, 200)
    for tip, direction in ((lx, -1), (rx, 1)):
        gild(img, scroll(w, h, tip + direction * 14, cy, -direction), outline=0.8)
        gem_stud(img, tip, cy, 14)
    # A clear margin above and below (PAD px at 1x) and a 1024-wide output: at 52 px
    # the plaque is shown at ~1.4x on PC and its 2 px edge cut the bevel points and
    # studs flat on phones (2026-10-23). The Crest/TitleCrest elements grow by
    # (h + 2 * PAD) / h in height and their bottom anchor moves down by PAD / h of the
    # old height, so the art stays where it was. Geometry inside is unchanged.
    PAD = 6
    padded = Image.new("RGBA", (s(w), s(h + 2 * PAD)), (0, 0, 0, 0))
    padded.paste(img, (0, s(PAD)))
    save(padded, "hud_realm_plaque.png", out=(1024, round(1024 * (h + 2 * PAD) / w)))


def tile():
    """128x128 tile frame: a lacquer square with chamfered corners, a gilt band and fine
    inner line, lit along the top. Icons centre on the frame (its hole is symmetric:
    the inner line runs 11 px in on every side)."""
    w = h = 128
    img = Image.new("RGBA", (s(w), s(h)), (0, 0, 0, 0))
    m, c = 3, 14
    body = polygon_mask(w, h, [(m + c, m), (w - m - c, m), (w - m, m + c), (w - m, h - m - c), (w - m - c, h - m), (m + c, h - m), (m, h - m - c), (m, m + c)])
    lacquer(img, body, BODY_TOP, BODY_BOT, shade=150, lit=120)
    band = ImageChops.subtract(body, erode(body, s(4)))
    inner = ImageChops.subtract(erode(body, s(8)), erode(body, s(9.2)))
    paint(img, inner, GOLD, 140)
    gild(img, band, outline=1.0)
    save(img, "hud_tile.png")


def keycap():
    """48x48 key cap, 9-slice Rect(14, 14, 34, 34): a small lacquer cap, chamfered,
    gilt band, lit top. The live key letter sits on top."""
    w = h = 48
    img = Image.new("RGBA", (s(w), s(h)), (0, 0, 0, 0))
    m, c = 2, 7
    body = polygon_mask(w, h, [(m + c, m), (w - m - c, m), (w - m, m + c), (w - m, h - m - c), (w - m - c, h - m), (m + c, h - m), (m, h - m - c), (m, m + c)])
    lacquer(img, body, BODY_TOP, BODY_BOT, shade=120, lit=140)
    band = ImageChops.subtract(body, erode(body, s(3)))
    gild(img, band, outline=1.0)
    save(img, "hud_keycap.png")


def timer_ring():
    """96x96 white ring (tinted in game) for the buff chips' timer: radius 44, 5 px."""
    w = h = 96
    m = blank(w, h)
    d = ImageDraw.Draw(m)
    d.ellipse([s(3), s(3), s(93), s(93)], fill=255)
    d.ellipse([s(8.5), s(8.5), s(87.5), s(87.5)], fill=0)
    img = Image.new("RGBA", m.size, (255, 255, 255, 0))
    img.putalpha(m)
    save(img, "hud_timer_ring.png")


def lock_reticle():
    """128x128: four gilt chevrons pointing in (N, E, S, W) around a small ruby
    diamond, all centred with 10 px clear on every side."""
    w = h = 128
    img = Image.new("RGBA", (s(w), s(h)), (0, 0, 0, 0))
    c = 64
    for k in range(4):
        a = k * math.pi / 2
        def rot(x, y):
            return (c + x * math.cos(a) - y * math.sin(a), c + x * math.sin(a) + y * math.cos(a))
        # a chevron at the top pointing down at the centre
        pts = [rot(-15, -50), rot(0, -36), rot(15, -50), rot(0, -42)]
        gild(img, polygon_mask(w, h, pts), outline=1.2)
    gem_stud(img, c, c, 9, gem="ruby")
    save(img, "hud_lock_reticle.png")


def lock_ring():
    """128x128: a thin gilt circle broken into four arcs between the chevrons."""
    w = h = 128
    img = Image.new("RGBA", (s(w), s(h)), (0, 0, 0, 0))
    m = blank(w, h)
    d = ImageDraw.Draw(m)
    r0, r1 = 31, 28.6
    for k in range(4):
        start = k * 90 + 18
        d.arc([s(64 - r0), s(64 - r0), s(64 + r0), s(64 + r0)], start, start + 54, fill=255, width=int(s(r0 - r1)))
    gild(img, m, outline=0.8, light=False)
    save(img, "hud_lock_ring.png")


def lock_on():
    """128x128: a jade ring over the round seal's inner rim (the seal's inner line sits
    at radius ~47 of 64), shown while locked."""
    w = h = 128
    m = blank(w, h)
    d = ImageDraw.Draw(m)
    d.ellipse([s(15), s(15), s(113), s(113)], fill=255)
    d.ellipse([s(19), s(19), s(109), s(109)], fill=0)
    img = Image.new("RGBA", m.size, (0, 0, 0, 0))
    paint(img, dilate(m, s(0.8)), (8, 30, 22), 200)
    paint(img, m, JADE)
    save(img, "hud_lock_on.png")


if __name__ == "__main__":
    vitals_plate()
    seat_plate()
    realm_plaque()
    tile()
    keycap()
    timer_ring()
    lock_reticle()
    lock_ring()
    lock_on()
