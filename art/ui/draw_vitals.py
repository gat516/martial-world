"""Draws the vitals mount (health, qi, guard) and the seated cultivation mount.

vitals_mount.png  1600x256, Stretch at its native 6.25:1 (Hud.Stack.Vitals.Mount).
                  Three windows the fills show through, top to bottom: health
                  (thick, ten segments), qi (combat qi, the bright azure bar) and
                  guard (a shorter posture trough under a lacquer seal in the
                  middle; the fill drains toward the seal).
seat_mount.png    1600x256, Stretch at 6.25:1 (Hud.Stack.SeatBars.Mount), shown in
                  the vitals' place while seated. A realm title band on top, the
                  cultivation window with a breakthrough lozenge at its right end
                  and a short overflow chamber past it (cultivation beyond the
                  breakthrough mark), and the dantian (raw qi) window under it.
Both are drawn over their fills, so each window is cut clear and glazed.
The window boxes (VITALS2, SEAT) are what the Studio layout copies, as scale.
Run: uv run --with pillow --with numpy python art/ui/draw_vitals.py
"""
import math

from PIL import Image, ImageDraw

from draw_ui import (
    GOLD, GOLD_HI, GOLD_LO, INK, SS, canvas, finish, gradient_rect, bevel_border,
    lozenge, meander_band, shadow_under, spiral,
)

W, H = 1600, 256
VITALS2 = {
    "plate": (170, 20, 1430, 214),
    "health": (200, 36, 1400, 92),
    "qi": (200, 106, 1400, 150),
    "guard": (420, 166, 1180, 198),
    "seal": (800, 182, 30),
    "segments": 10,
}
SEAT = {
    "plate": (170, 20, 1430, 214),
    "title": (560, 22, 1040, 62),
    "cultivation": (200, 76, 1236, 132),
    "mark": (1268, 104, 26),
    "overflow": (1300, 86, 1400, 122),
    "dantian": (200, 148, 1400, 184),
}
WINDOW_RIM = (205, 170, 95, 220)


def s(v):
    return v * SS


def plate_and_horns(img, plate):
    d = ImageDraw.Draw(img)
    cx = W * SS / 2
    # ruyi pendant under the middle, behind the plate
    y = plate[3]
    tip = [(cx - s(80), s(y - 8)), (cx + s(80), s(y - 8)), (cx + s(30), s(y + 20)), (cx, s(y + 36)), (cx - s(30), s(y + 20))]
    d.polygon(tip, fill=GOLD_LO)
    inner = [(cx - s(66), s(y - 6)), (cx + s(66), s(y - 6)), (cx + s(23), s(y + 17)), (cx, s(y + 29)), (cx - s(23), s(y + 17))]
    d.polygon(inner, fill=(30, 22, 16, 255))
    for side in (-1, 1):
        spiral(d, cx + side * s(40), s(y + 6), s(10), 1.1, math.pi * 0.5, side, s(3), GOLD)
    lozenge(d, cx, s(y + 18), s(9), s(2))

    box = [s(v) for v in plate]
    gradient_rect(img, box, (34, 40, 44), (12, 15, 18), radius=s(16))
    d = ImageDraw.Draw(img)
    bevel_border(d, box, s(6), radius=s(16))

    # horns: cloud scrolls rising off each end
    for side in (-1, 1):
        ex = cx + side * (W / 2 - plate[0]) * SS
        top = plate[1]
        sweep = [(ex, s(top + 22)), (ex + side * s(44), s(top + 2)), (ex + side * s(86), s(top + 16))]
        d.line(sweep, fill=GOLD_LO, width=s(15), joint="curve")
        d.line(sweep, fill=GOLD, width=s(10), joint="curve")
        spiral(d, ex + side * s(104), s(top + 52), s(36), 1.4, math.pi if side > 0 else 0, -side, s(12), GOLD_LO)
        spiral(d, ex + side * s(104), s(top + 52), s(36), 1.4, math.pi if side > 0 else 0, -side, s(8), GOLD)
        spiral(d, ex + side * s(66), s(plate[3] - 10), s(22), 1.2, -math.pi * 0.5, side, s(8), GOLD)
        spiral(d, ex + side * s(130), s(top - 2), s(13), 1.1, math.pi * 0.5, side, s(5), GOLD)
        lozenge(d, ex, s((plate[1] + plate[3]) / 2), s(22), s(4))


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
    plate_and_horns(img, v["plate"])
    d = ImageDraw.Draw(img)
    gx0, gy0, gx1, gy1 = v["guard"]
    gm = (gy0 + gy1) / 2
    # meander bands either side of the guard trough
    meander_band(d, s(v["plate"][0] + 46), s(gx0 - 26), s(gm), s(10), (205, 170, 95, 190), int(1.6 * SS))
    meander_band(d, s(gx1 + 26), s(v["plate"][2] - 46), s(gm), s(10), (205, 170, 95, 190), int(1.6 * SS))
    cut(img, [v["health"], v["qi"], v["guard"]], [8, 7, 6])
    d = ImageDraw.Draw(img)
    hx0, hy0, hx1, hy1 = [s(x) for x in v["health"]]
    seg = (hx1 - hx0) / v["segments"]
    for i in range(1, v["segments"]):
        x = hx0 + seg * i
        d.line([(x, hy0), (x, hy1)], fill=(10, 14, 16, 230), width=s(5))
        d.line([(x + s(3), hy0 + s(2)), (x + s(3), hy1 - s(2))], fill=(255, 255, 255, 40), width=s(1))
    # qi: faint quarter ticks, so spending reads at a glance
    qx0, qy0, qx1, qy1 = [s(x) for x in v["qi"]]
    for i in (1, 2, 3):
        x = qx0 + (qx1 - qx0) * i / 4
        d.line([(x, qy0), (x, qy0 + s(10))], fill=(10, 14, 16, 200), width=s(4))
        d.line([(x, qy1 - s(10)), (x, qy1)], fill=(10, 14, 16, 200), width=s(4))
    glaze(img, v["health"], 8, 3, rim=GOLD, gloss=46)
    glaze(img, v["qi"], 7, 3, rim=GOLD)
    glaze(img, v["guard"], 6, 2)
    d = ImageDraw.Draw(img)
    cx, cy, r = v["seal"]
    seal_diamond(d, s(cx), s(cy), s(r))
    finish(shadow_under(img, blur=4, offset=3), "vitals_mount.png")


def seat_mount():
    v = SEAT
    img = canvas(W, H)
    plate_and_horns(img, v["plate"])
    d = ImageDraw.Draw(img)
    # title band: a lacquer-red strip with gold rails behind the realm name
    tx0, ty0, tx1, ty1 = [s(x) for x in v["title"]]
    gradient_rect(img, [tx0, ty0, tx1, ty1], (70, 26, 22), (34, 12, 10), radius=s(8))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([tx0, ty0, tx1, ty1], radius=s(8), outline=GOLD, width=s(3))
    for side in (-1, 1):
        ex = tx0 if side < 0 else tx1
        lozenge(d, ex, (ty0 + ty1) / 2, s(14), s(3))
        meander_band(d, *(sorted([ex + side * s(24), ex + side * s(150)])), (ty0 + ty1) / 2, s(10), (205, 170, 95, 190), int(1.6 * SS))
    cut(img, [v["cultivation"], v["overflow"], v["dantian"]], [8, 6, 6])
    d = ImageDraw.Draw(img)
    # fifths on the cultivation window
    cx0, cy0, cx1, cy1 = [s(x) for x in v["cultivation"]]
    for i in range(1, 5):
        x = cx0 + (cx1 - cx0) * i / 5
        d.line([(x, cy0), (x, cy0 + s(10))], fill=(10, 14, 16, 200), width=s(4))
        d.line([(x, cy1 - s(10)), (x, cy1)], fill=(10, 14, 16, 200), width=s(4))
    glaze(img, v["cultivation"], 8, 3, rim=GOLD, gloss=46)
    glaze(img, v["overflow"], 6, 2)
    glaze(img, v["dantian"], 6, 2)
    d = ImageDraw.Draw(img)
    # the breakthrough mark between the bar and its overflow chamber
    mx, my, mr = v["mark"]
    d.line([(s(mx), s(v["cultivation"][1] - 6)), (s(mx), s(v["cultivation"][3] + 6))], fill=GOLD_LO, width=s(6))
    lozenge(d, s(mx), s(my), s(mr), s(5))
    finish(shadow_under(img, blur=4, offset=3), "seat_mount.png")


def preview():
    """Both mounts at real in-game size (520 px wide, the Stack's max) on grey."""
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.environ.get("PREVIEW", os.path.join(here, "preview_vitals.png"))
    bg = Image.new("RGBA", (1100, 260), (110, 110, 110, 255))
    y = 10
    for name, fills in (("vitals_mount.png", (("health", 0.7, (60, 190, 110)), ("qi", 0.55, (90, 200, 255)), ("guard", 0.6, (245, 220, 150)))),
                        ("seat_mount.png", (("cultivation", 1.0, (230, 190, 90)), ("overflow", 0.4, (255, 235, 160)), ("dantian", 0.35, (170, 140, 255))))):
        im = Image.open(os.path.join(here, name))
        boxes = VITALS2 if name.startswith("vitals") else SEAT
        layer = Image.new("RGBA", im.size, (14, 19, 22, 0))
        ld = ImageDraw.Draw(layer)
        for key, frac, col in fills:
            x0, y0, x1, y1 = boxes[key]
            ld.rectangle([x0, y0, x1, y1], fill=(14, 19, 22, 255))
            if key == "guard":
                c, half = (x0 + x1) / 2, (x1 - x0) / 2 * frac
                ld.rectangle([c - half, y0, c + half, y1], fill=col + (255,))
            else:
                ld.rectangle([x0, y0, x0 + (x1 - x0) * frac, y1], fill=col + (255,))
        layer.alpha_composite(im)
        for scale, x in ((520 / 1600, 10), (330 / 1600, 560)):
            small = layer.resize((int(1600 * scale), int(256 * scale)), Image.LANCZOS)
            bg.alpha_composite(small, (x, y))
        y += 120
    bg.save(out)
    print("preview", out)


if __name__ == "__main__":
    import sys
    vitals_mount()
    seat_mount()
    if len(sys.argv) > 1 and sys.argv[1] == "preview":
        preview()
