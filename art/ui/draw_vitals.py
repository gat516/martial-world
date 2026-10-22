"""Draws the vitals mount (health, qi, guard) and the seated cultivation mount.

Both are one notched plate (1600x196, Stretch at its native 8.16:1): a full-width
upper body and a narrower tab under its middle, so the PC cooldown chips tuck into
the left notch instead of taking a row of their own (user, 2026-10-22). Ornament is
trimmed to a gilt rim, end lozenges and small curls so the bars get the height.
vitals_mount.png  Hud.Stack.Vitals.Mount: health (thick, ten segments) and combat
                  qi in the body, the guard trough in the tab under a lacquer seal
                  (the fill drains toward the seal).
seat_mount.png    Hud.Stack.SeatBars.Mount, in the vitals' place while seated: a realm
                  title band, the cultivation window with a breakthrough lozenge and a
                  short overflow chamber past it, and the dantian (raw qi) in the tab.
Both are drawn over their fills, so each window is cut clear and glazed. The window
boxes (VITALS2, SEAT, NOTCH_LEFT) are what the Studio layout copies, as scale.
Run: uv run --with pillow --with numpy python art/ui/draw_vitals.py [preview]
"""
import math

from PIL import Image, ImageDraw, ImageFilter

from draw_ui import (
    GOLD, GOLD_HI, GOLD_LO, INK, SS, canvas, finish, gradient_rect, bevel_border,
    lozenge, meander_band, shadow_under, spiral,
)

W, H = 1600, 196
# The plate is notched (user, 2026-10-22): a full-width upper body holds health and
# qi; a narrower tab under its middle holds the bottom row (guard; the dantian when
# seated). The PC cooldown chips (Stack.Cooldowns) tuck into the left notch beside
# the tab, so they no longer take their own row above the hotbar.
UPPER = (120, 4, 1480, 128)
TAB = (440, 96, 1160, 192)
NOTCH_LEFT = (120, 128, 440, 196)  # where the chips sit
VITALS2 = {
    "health": (152, 14, 1448, 70),
    "qi": (152, 78, 1448, 120),
    "guard": (480, 138, 1120, 172),
    "seal": (800, 155, 26),
    "segments": 10,
}
SEAT = {
    "title": (600, 10, 1000, 40),
    "cultivation": (152, 48, 1300, 120),
    "mark": (1328, 84, 22),
    "overflow": (1354, 64, 1448, 104),
    "dantian": (480, 138, 1120, 172),
}
WINDOW_RIM = (205, 170, 95, 220)


def s(v):
    return v * SS


def plate_and_horns(img, plate=None):
    """The notched lacquer plate: the upper body and the tab under it, one gilt
    outline, small cloud curls at the outer ends and at the two steps."""
    body = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for box in (UPPER, TAB):
        gradient_rect(body, [s(v) for v in box], (34, 40, 44), (12, 15, 18), radius=s(14))
    # one silhouette, then the gilt rim traced around it
    alpha = body.getchannel("A")
    edge = alpha.filter(ImageFilter.MaxFilter(s(6) + 1))
    rim = Image.new("RGBA", img.size, GOLD)
    rim.putalpha(edge)
    lo = Image.new("RGBA", img.size, GOLD_LO)
    lo.putalpha(alpha.filter(ImageFilter.MaxFilter(s(8) + 1)))
    img.alpha_composite(lo)
    img.alpha_composite(rim)
    inner = alpha.filter(ImageFilter.MinFilter(s(3) + 1))
    body.putalpha(inner)
    img.alpha_composite(body)
    d = ImageDraw.Draw(img)
    # a fine hairline just inside the upper body's top edge (top light)
    d.line([(s(UPPER[0] + 20), s(UPPER[1] + 3)), (s(UPPER[2] - 20), s(UPPER[1] + 3))], fill=(255, 236, 180, 140), width=s(1))
    # end caps: a lozenge on each outer end, a small curl beside it
    my = (UPPER[1] + UPPER[3]) / 2
    for side in (-1, 1):
        ex = s(UPPER[0] if side < 0 else UPPER[2])
        lozenge(d, ex, s(my), s(18), s(4))
        spiral(d, ex + side * s(4), s(my + 34), s(10), 1.1, math.pi * 0.5, side, s(4), GOLD)
        # curl at the step where the tab leaves the body
        sx = s(TAB[0] if side < 0 else TAB[2])
        spiral(d, sx - side * s(2), s(UPPER[3] + 16), s(11), 1.1, -math.pi * 0.5, -side, s(4), GOLD)


def cut(img, boxes, radius):
    alpha = img.getchannel("A")
    ad = ImageDraw.Draw(alpha)
    for box, r in zip(boxes, radius):
        ad.rounded_rectangle([s(v) for v in box], radius=s(r), fill=0)
    img.putalpha(alpha)


def glaze(img, box, r, rim_width, rim=WINDOW_RIM, gloss=40):
    x0, y0, x1, y1 = [s(v) for v in box]
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(layer)
    hh = (y1 - y0) * 0.28
    gd.rounded_rectangle([x0 + s(4), y0 + s(2), x1 - s(4), y0 + hh], radius=s(3), fill=(255, 255, 255, gloss))
    # a darker lip under the top rim so the fill reads as set in
    gd.line([(x0 + s(r), y0 + s(1)), (x1 - s(r), y0 + s(1))], fill=(0, 0, 0, 120), width=s(2))
    img.alpha_composite(layer)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x0 - s(3), y0 - s(3), x1 + s(3), y1 + s(3)], radius=s(r + 2), outline=rim, width=s(rim_width))


def seal_diamond(d, cx, cy, r):
    """A lacquer-red diamond seal in a gold rim (the guard's centre)."""
    def dia(rr, col):
        d.polygon([(cx, cy - rr), (cx + rr, cy), (cx, cy + rr), (cx - rr, cy)], fill=col)
    dia(r, INK)
    dia(r * 0.92, GOLD_LO)
    dia(r * 0.82, GOLD)
    dia(r * 0.62, INK)
    dia(r * 0.52, (150, 28, 30, 255))
    d.polygon([(cx - r * 0.42, cy - r * 0.04), (cx - r * 0.04, cy - r * 0.42), (cx - r * 0.04, cy - r * 0.3), (cx - r * 0.3, cy - r * 0.04)], fill=(215, 90, 80, 160))
    rr = r * 0.12
    d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=GOLD_HI)


def vitals_mount():
    v = VITALS2
    img = canvas(W, H)
    plate_and_horns(img)
    cut(img, [v["health"], v["qi"], v["guard"]], [8, 7, 6])
    d = ImageDraw.Draw(img)
    hx0, hy0, hx1, hy1 = [s(x) for x in v["health"]]
    seg = (hx1 - hx0) / v["segments"]
    for i in range(1, v["segments"]):
        x = hx0 + seg * i
        d.line([(x, hy0), (x, hy1)], fill=(10, 14, 16, 200), width=s(4))
    glaze(img, v["health"], 8, 3, rim=GOLD, gloss=46)
    glaze(img, v["qi"], 7, 3, rim=GOLD)
    glaze(img, v["guard"], 6, 3, rim=GOLD)
    d = ImageDraw.Draw(img)
    cx, cy, r = v["seal"]
    seal_diamond(d, s(cx), s(cy), s(r))
    finish(shadow_under(img, blur=3, offset=2), "vitals_mount.png")


def seat_mount():
    v = SEAT
    img = canvas(W, H)
    plate_and_horns(img)
    tx0, ty0, tx1, ty1 = [s(x) for x in v["title"]]
    gradient_rect(img, [tx0, ty0, tx1, ty1], (70, 26, 22), (34, 12, 10), radius=s(8))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([tx0, ty0, tx1, ty1], radius=s(8), outline=GOLD, width=s(3))
    for ex in (tx0, tx1):
        lozenge(d, ex, (ty0 + ty1) / 2, s(12), s(3))
    cut(img, [v["cultivation"], v["overflow"], v["dantian"]], [8, 6, 6])
    d = ImageDraw.Draw(img)
    cx0, cy0, cx1, cy1 = [s(x) for x in v["cultivation"]]
    for i in range(1, 5):
        x = cx0 + (cx1 - cx0) * i / 5
        d.line([(x, cy0), (x, cy0 + s(10))], fill=(10, 14, 16, 200), width=s(4))
        d.line([(x, cy1 - s(10)), (x, cy1)], fill=(10, 14, 16, 200), width=s(4))
    glaze(img, v["cultivation"], 8, 3, rim=GOLD, gloss=46)
    glaze(img, v["overflow"], 6, 2)
    glaze(img, v["dantian"], 6, 3, rim=GOLD)
    d = ImageDraw.Draw(img)
    mx, my, mr = v["mark"]
    lozenge(d, s(mx), s(my), s(mr), s(5))
    finish(shadow_under(img, blur=3, offset=2), "seat_mount.png")


def preview():
    """Both mounts at real in-game size on grey: 520 px wide (the Stack's PC max)
    and 320 px (a landscape phone), with full fills and two chip dots in the notch."""
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.environ.get("PREVIEW", os.path.join(here, "preview_vitals.png"))
    bg = Image.new("RGBA", (900, 200), (110, 110, 110, 255))
    y = 10
    for name, boxes, fills in (
        ("vitals_mount.png", VITALS2, (("health", 1.0, (255, 92, 84)), ("qi", 1.0, (120, 220, 255)), ("guard", 1.0, (255, 236, 170)))),
        ("seat_mount.png", SEAT, (("cultivation", 1.0, (240, 200, 100)), ("overflow", 0.4, (255, 240, 180)), ("dantian", 0.35, (180, 150, 255)))),
    ):
        im = Image.open(os.path.join(here, name))
        layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        for key, frac, col in fills:
            x0, y0, x1, y1 = boxes[key]
            ld.rectangle([x0, y0, x1, y1], fill=(14, 19, 22, 255))
            ld.rectangle([x0, y0, x0 + (x1 - x0) * frac, y1], fill=col + (255,))
        layer.alpha_composite(im)
        nx0, ny0, nx1, ny1 = NOTCH_LEFT
        for cx in (nx0 + (nx1 - nx0) * 0.38, nx0 + (nx1 - nx0) * 0.62):
            r = (ny1 - ny0) * 0.4
            ld = ImageDraw.Draw(layer)
            ld.ellipse([cx - r, (ny0 + ny1) / 2 - r, cx + r, (ny0 + ny1) / 2 + r], fill=(16, 18, 18, 220), outline=(240, 226, 190, 200), width=3)
        for scale, x in ((520 / 1600, 10), (320 / 1600, 560)):
            small = layer.resize((int(W * scale), int(H * scale)), Image.LANCZOS)
            bg.alpha_composite(small, (x, y))
        y += 90
    bg.save(out)
    print("preview", out)


if __name__ == "__main__":
    import sys
    vitals_mount()
    seat_mount()
    if len(sys.argv) > 1 and sys.argv[1] == "preview":
        preview()
