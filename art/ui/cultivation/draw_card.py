"""The meditation panel's shaped backing (docs/ui/cultivation.md, "Meditation panel").

A card with a silhouette of its own instead of the plain kit window: a raised crest
on the top edge that holds the title (lacquer-red, set off from the body by a thin
gold rule), concave cut corners, and a shallow point at the bottom. The rail is the
kit's own: the cross-section of `ornament_window_corner_small`'s plain rail (outline,
gold band, navy channel, gold band, outline), swept along the new outline, with a
little upper-left light. No ornaments are painted on; the close seal sits in the
top-right cut corner.

Run: uv run --with pillow --with numpy --with scipy python art/ui/cultivation/draw_card.py
Output: art/ui/cultivation/meditation_card.png, 1020x270, drawn at 3x the panel's
display size: the shape is 338 px wide (the 330 px panel + 4 px a side) inside a 1 px
clear margin, so the Backdrop is the panel + 10 px wide.
  ScaleType Slice, SliceCenter Rect(508, 159, 512, 165), SliceScale 1/3 (0.3333).
  Only the 4 centre columns (crest top, bottom point; stretch ~1.0 since the panel
  width is fixed) and the 6 middle rows (plain side rails) stretch.
  Shape in display px (inside the margin): crest top 28 above the body's outer top edge, point 10
  below its outer bottom edge, rail 7 deep (inner edge 7 px in from the outer edge).
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
CUT = ROOT / "art/ui/codex/cut"
OUT = ROOT / "art/ui/cultivation"

K = 3 # image px per display px
SS = 4 # supersampling
U = K * SS # drawing px per display px

M = 1 # clear margin round the shape, so the outline never touches the image edge
SW = 338 # shape width (display)
W = SW + 2 * M
CREST = 28 + M # crest height above the body's top edge (+ the margin)
TOP_CAP = 52 + M # rows (display) above the stretch band
MID = 2 # stretch band (display)
BOTTOM_CAP = 34 + M # rows below it, including the point
TIP = 10 # point depth below the body's bottom edge
H = TOP_CAP + MID + BOTTOM_CAP
BODY_TOP, BODY_BOTTOM = CREST, H - TIP - M
NOTCH = 12 # cut-corner radius
RAIL = 7.0 # rail depth
CX = W / 2
CREST_BASE, CREST_TOP = 112, 77 # half-widths
TIP_HALF = 70
RULE_Y = BODY_TOP + 3.5 # the gold rule under the crest (centre line)

NAVY = np.array([17, 24, 32, 246], float)
LACQUER_TOP = np.array([112, 28, 28], float)
LACQUER_BOTTOM = np.array([66, 14, 16], float)


def bezier(p0, p1, p2, p3, n=40):
    t = np.linspace(0, 1, n)[:, None]
    p = [np.array(v, float) for v in (p0, p1, p2, p3)]
    return ((1 - t) ** 3 * p[0] + 3 * (1 - t) ** 2 * t * p[1] + 3 * (1 - t) * t**2 * p[2] + t**3 * p[3]).tolist()


def arc(cx, cy, r, a0, a1, n=24):
    a = np.radians(np.linspace(a0, a1, n))
    return list(zip(cx + r * np.cos(a), cy + r * np.sin(a)))


def outline():
    pts = []
    pts += arc(M, BODY_TOP, NOTCH, 90, 0) # top-left cut
    left_crest = bezier((CX - CREST_BASE, BODY_TOP), (CX - CREST_BASE + 21, BODY_TOP), (CX - CREST_TOP - 14, M), (CX - CREST_TOP, M))
    pts += left_crest
    pts += [(2 * CX - x, y) for x, y in reversed(left_crest)]
    pts += arc(W - M, BODY_TOP, NOTCH, 180, 90) # top-right cut
    pts += arc(W - M, BODY_BOTTOM, NOTCH, 270, 180) # bottom-right cut
    pts += [(CX + TIP_HALF, BODY_BOTTOM), (CX, H - M), (CX - TIP_HALF, BODY_BOTTOM)]
    pts += arc(M, BODY_BOTTOM, NOTCH, 0, -90) # bottom-left cut
    return [(x * U, y * U) for x, y in pts]


def rail_profile():
    """The kit rail's cross-section, outer edge first (rows 14-65 of column 400)."""
    corner = Image.open(CUT / "ornament_window_corner_small.png").convert("RGBA")
    return np.array([corner.getpixel((400, y)) for y in range(14, 66)], float)


def draw() -> Image.Image:
    w, h = W * U, H * U
    mask_img = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask_img).polygon(outline(), fill=255)
    mask = np.array(mask_img) > 127
    dist = ndimage.distance_transform_edt(mask) / U # display px from the outer edge
    gy, gx = np.gradient(ndimage.gaussian_filter(dist, U))
    norm = np.hypot(gx, gy) + 1e-6
    # the gradient points inward; light from the upper left lands on outward
    # normals facing up-left, i.e. inward gradients facing down-right
    light = (gx * 0.6 + gy * 0.8) / norm

    yy, xx = np.mgrid[0:h, 0:w] / U
    out = np.zeros((h, w, 4), float)
    under_crest = np.abs(xx - CX) < CREST_BASE
    crest = (yy < RULE_Y) & under_crest
    t = np.clip((yy - M - RAIL) / (BODY_TOP - M - RAIL), 0, 1)[..., None]
    lacquer = LACQUER_TOP * (1 - t) + LACQUER_BOTTOM * t
    out[...] = NAVY
    out[crest, :3] = lacquer[crest]
    out[crest, 3] = 250

    prof = rail_profile()
    # the gold rule under the crest: the profile's inner gold band (rows 32-51)
    band = prof[32:52]
    rule = under_crest & (np.abs(yy - RULE_Y) < 1.6) & (dist > RAIL - 0.5)
    idx = np.clip(((yy - (RULE_Y - 1.6)) / 3.2 * len(band)).astype(int), 0, len(band) - 1)
    out[rule] = band[idx[rule]]

    on_rail = mask & (dist < RAIL)
    idx = np.clip((dist / RAIL * len(prof)).astype(int), 0, len(prof) - 1)
    rail = prof[idx]
    shade = (1 + 0.14 * light)[..., None]
    rail[..., :3] = np.clip(rail[..., :3] * shade, 0, 255)
    out[on_rail] = rail[on_rail]
    out[~mask] = 0

    # downsample with premultiplied alpha
    a = out[..., 3:4] / 255
    pre = np.concatenate([out[..., :3] * a, out[..., 3:4]], axis=-1)
    small = pre.reshape(H * K, SS, W * K, SS, 4).mean(axis=(1, 3))
    alpha = small[..., 3:4]
    rgb = np.where(alpha > 0, small[..., :3] / np.maximum(alpha / 255, 1e-6), 0)
    img = np.concatenate([np.clip(rgb, 0, 255), alpha], axis=-1).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def main() -> None:
    img = draw()
    img.save(OUT / "meditation_card.png")
    cx = W * K // 2
    print("meditation_card", img.size, "SliceCenter", (cx - 2, TOP_CAP * K, cx + 2, (TOP_CAP + MID) * K), "SliceScale", 1 / K)


if __name__ == "__main__":
    main()
