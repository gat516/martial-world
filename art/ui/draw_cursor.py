"""Draws the mouse cursor: a plain arrow pointer in the HUD's palette, and its
hover variant shown over buttons.

Roblox draws a custom mouse icon at its native size, centred on the mouse, so
the arrow's tip sits at the centre pixel (32, 32) of a 64px image, the same as
Roblox's own ArrowFarCursor.png. Not sliced.

Uses the shared helpers in draw_ui.py. Run:
    uv run --with pillow --with numpy python art/ui/draw_cursor.py
"""

from PIL import Image, ImageDraw

from draw_lockon import PALE, ink_under
from draw_ui import GOLD, GOLD_HI, GOLD_LO, SS, canvas, finish, shadow_under

S = 64
TIP = (32, 32)
# a classic arrow, tip at (0, 0), in pixels at 1x
ARROW = [(0, 0), (0, 21), (5, 16.5), (8.8, 24.5), (12, 23.2), (8.4, 15.4), (15, 15.4)]
PAPER_LO = (226, 212, 180, 255)  # the pale fill's shaded foot


def arrow_points(inset=0.0):
    """The arrow's outline in supersampled canvas pixels, pulled toward its
    centroid by `inset` pixels (for the inner highlight)."""
    cx = sum(p[0] for p in ARROW) / len(ARROW)
    cy = sum(p[1] for p in ARROW) / len(ARROW)
    out = []
    for x, y in ARROW:
        dx, dy = cx - x, cy - y
        n = max(1e-6, (dx * dx + dy * dy) ** 0.5)
        out.append(((TIP[0] + x + dx / n * inset) * SS, (TIP[1] + y + dy / n * inset) * SS))
    return out


def vertical_fill(top, bot):
    """A full-canvas top-light gradient, masked to the arrow later."""
    img = Image.new("RGBA", (S * SS, S * SS))
    d = ImageDraw.Draw(img)
    y0, y1 = TIP[1] * SS, (TIP[1] + 25) * SS
    for y in range(S * SS):
        t = min(1, max(0, (y - y0) / (y1 - y0)))
        d.line([(0, y), (S * SS, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    return img


def cursor(top, bot, edge, name):
    mask = Image.new("L", (S * SS, S * SS), 0)
    ImageDraw.Draw(mask).polygon(arrow_points(), fill=255)
    layer = canvas(S, S)
    layer.paste(vertical_fill(top, bot), (0, 0), mask)
    # one thin bevel line just inside the edge
    d = ImageDraw.Draw(layer)
    pts = arrow_points(1.3)
    d.line(pts + [pts[0]], fill=edge, width=int(0.8 * SS), joint="curve")
    img = ink_under(layer, grow=2, alpha=245)
    finish(shadow_under(img, blur=2, offset=1, alpha=110), name)


def cursor_arrow():
    """The normal pointer: aged-paper white with a soft top light, ink outline."""
    cursor(PALE, PAPER_LO, (255, 255, 255, 200), "cursor_arrow.png")


def cursor_hover():
    """Over a button: the same arrow gilded, so clickable things read at a glance."""
    cursor(GOLD_HI, GOLD, GOLD_LO[:3] + (150,), "cursor_hover.png")


if __name__ == "__main__":
    cursor_arrow()
    cursor_hover()
