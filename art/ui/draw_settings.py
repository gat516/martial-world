"""Draws the Settings art: the gear tile icon, the slider knob and the on/off
toggle switch. Uses the shared helpers in draw_ui.py. Run:
    uv run --with pillow --with numpy python art/ui/draw_settings.py
"""

import math

from PIL import Image, ImageDraw, ImageFilter

from draw_ui import GOLD, GOLD_HI, GOLD_LO, INK, SS, canvas, finish, gradient_rect, lozenge, shadow_under


def gear_icon():
    """The Settings tile icon, 128px: a near-white gear silhouette with a soft
    top-light gradient, an ink outline and a round hole, tinted in Studio
    through ImageColor3 like the other tile icons. Stretched (ScaleType Fit)."""
    S = 128
    N = S * SS
    c = N / 2
    teeth = 8
    r_out, r_in, r_hole = 54 * SS, 42 * SS, 15 * SS
    pts = []
    for k in range(teeth * 4):
        a = k / (teeth * 4) * 2 * math.pi - math.pi / 2
        r = r_out if k % 4 in (1, 2) else r_in
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
    mask = Image.new("L", (N, N), 0)
    md = ImageDraw.Draw(mask)
    md.polygon(pts, fill=255)
    md.ellipse([c - r_in, c - r_in, c + r_in, c + r_in], fill=255)
    md.ellipse([c - r_hole, c - r_hole, c + r_hole, c + r_hole], fill=0)
    # ink outline: the shape grown a little, under the fill
    outline = mask.filter(ImageFilter.MaxFilter(4 * SS + 1))
    img = Image.new("RGBA", (N, N), INK[:3] + (0,))
    img.putalpha(outline)
    face = canvas(S, S)
    gradient_rect(face, [0, 0, N, N], (255, 255, 255), (196, 200, 204))
    face.putalpha(mask)
    img.alpha_composite(face)
    d = ImageDraw.Draw(img)
    # inner ring groove and one highlight
    rr = 30 * SS
    d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=(150, 156, 160, 255), width=3 * SS)
    d.arc([c - r_in + 6 * SS, c - r_in + 6 * SS, c + r_in - 6 * SS, c + r_in - 6 * SS], 200, 260, fill=(255, 255, 255, 255), width=4 * SS)
    finish(img, "gear_icon.png")


def slider_knob():
    """The slider knob, 64px: a gold-rimmed jade bead with a lozenge in the middle,
    ink-outlined. Stretched, shown at ~22px."""
    S = 64
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    c = S * SS / 2
    r = 28 * SS
    d.ellipse([c - r, c - r, c + r, c + r], fill=INK)
    r -= 3 * SS
    d.ellipse([c - r, c - r, c + r, c + r], fill=GOLD)
    d.arc([c - r, c - r, c + r, c + r], 190, 280, fill=GOLD_HI, width=3 * SS)
    r2 = r - 5 * SS
    bead = canvas(S, S)
    gradient_rect(bead, [c - r2, c - r2, c + r2, c + r2], (96, 196, 152), (20, 92, 70), radius=int(r2))
    img.alpha_composite(bead)
    d = ImageDraw.Draw(img)
    lozenge(d, c, c, 9 * SS, 2 * SS)
    finish(shadow_under(img, blur=2, offset=1, alpha=140), "slider_knob.png")


def toggle(name, lit):
    """An on/off switch, 256x128 (shown at 64x32, Stretch at native 2:1). Off: dim
    ink track, knob left, a hollow ring. On: lit jade track with a glow, knob
    right. The On image is laid over the Off one at the same size."""
    W, H = 256, 128
    img = canvas(W, H)
    m = 12 * SS
    box = [m, m, W * SS - m, H * SS - m]
    R = (H * SS - 2 * m) // 2
    if lit:
        halo = Image.new("L", img.size, 0)
        ImageDraw.Draw(halo).rounded_rectangle([m - 2 * SS, m - 2 * SS, W * SS - m + 2 * SS, H * SS - m + 2 * SS], radius=R, fill=170)
        halo = halo.filter(ImageFilter.GaussianBlur(7 * SS))
        glow = Image.new("RGBA", img.size, (90, 230, 170, 0))
        glow.putalpha(halo)
        img.alpha_composite(glow)
        gradient_rect(img, box, (74, 176, 132), (18, 86, 64), radius=R)
    else:
        gradient_rect(img, box, (26, 32, 36), (10, 13, 16), radius=R)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=R, outline=INK, width=5 * SS)
    rim = GOLD_HI if lit else (150, 120, 64, 255)
    d.rounded_rectangle([m + 4 * SS, m + 4 * SS, W * SS - m - 4 * SS, H * SS - m - 4 * SS], radius=R - 4 * SS, outline=rim, width=3 * SS)
    # the knob
    kr = R - 14 * SS
    kx = (W * SS - m - R) if lit else (m + R)
    ky = H * SS / 2
    d.ellipse([kx - kr - 3 * SS, ky - kr - 3 * SS, kx + kr + 3 * SS, ky + kr + 3 * SS], fill=INK)
    knob = canvas(W, H)
    top, bot = ((255, 246, 220), (214, 180, 110)) if lit else ((128, 126, 120), (70, 68, 64))
    gradient_rect(knob, [kx - kr, ky - kr, kx + kr, ky + kr], top, bot, radius=int(kr))
    img.alpha_composite(knob)
    d = ImageDraw.Draw(img)
    # a mark on the empty side: a small lit lozenge (on) or a hollow ring (off)
    if lit:
        lozenge(d, m + R, ky, 13 * SS, 3 * SS)
    else:
        ox = W * SS - m - R
        rr = 11 * SS
        d.ellipse([ox - rr, ky - rr, ox + rr, ky + rr], outline=(120, 110, 90, 255), width=3 * SS)
    finish(img, name)


if __name__ == "__main__":
    gear_icon()
    slider_knob()
    toggle("toggle_off.png", False)
    toggle("toggle_on.png", True)
