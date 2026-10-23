"""Reshape the boss bar's plate and mount: the trough's right end at a shallow slant,
straight segment cuts, and the kit ruby stud as a small end cap in place of the square
socket (user, 2026-10-23: "lighter slant, straight cuts, smaller on phones").

The Figma sheet `Export / Roblox Boss Bar` (node 35:177) is still the first, 45-degree
version and the kit file can't be edited from here (no edit access through the MCP), so
this rebuilds the right part of the matted exports from the sheet's own flat shapes:
every column of the plate between its ends is identical (vertical gradients only), so
the body, gilt edge and trough are re-laid from one column each along the new outline;
the mount keeps its plaque and gold cap as exported, and its trough rim (1 px gilt) and
segment cuts (1.5 px, near black) are redrawn. The end cap is the kit's
`ornament_ruby_stud` cut, scaled, not redrawn. No generated ornament is repainted.

Source: the 45-degree exports (git show 3d6d826:art/ui/figma/boss/bossbar_plate.png and
bossbar_mount.png, 1024x190 for the 560x104 box), whose left part (x < 200 plate,
x < 40 mount) and plaque (y < 28.5) are copied as they are. It works on that 1024x190
grid and writes each piece at display size (SIZES).

    uv run --with pillow --with numpy python tools/boss_bar_reshape.py SRC_DIR OUT_DIR [--angle 15]

Prints the geometry (in 1x box px) that BossBars and draw_boss_bars.py must match:
the trough's top-right x (the Bar frame is 28..that x, rows 40..64) and the slant.
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RUBY = ROOT / "art/ui/codex/cut/ornament_ruby_stud.png"
BOX_W, BOX_H = 560, 104
OUT_W, OUT_H = 1024, 190
K = OUT_W / BOX_W  # working px per box px
# Written at display size (Roblox draws GUI images without mipmaps, so the 1024 px
# export shown at 560 looked soft; user, 2026-10-23): the PC box, and half of it for
# phones (shown about 270 wide).
SIZES = {"": (BOX_W, BOX_H), "_phone": (BOX_W // 2, BOX_H // 2)}
# Clear rows above the plaque's scroll tips, which reach the export's top edge (no
# mipmaps: the quad's edge would cut them straight). Plate and Mount are grown by it
# in Studio: Position y -PAD_TOP/104, Size y (104 + PAD_TOP)/104.
PAD_TOP = 4

PLATE_TOP, PLATE_BOT = 33.8, 70.0  # outer gilt edge rows
PLATE_MID = (PLATE_TOP + PLATE_BOT) / 2
TROUGH_TOP, TROUGH_BOT = 39.2, 64.3  # trough well, incl. its dark lip rows
BAR_TOP, BAR_BOT, BAR_LEFT = 40.0, 64.0, 28.0  # the Bar frame (fill window)
RIM_TOP, RIM_BOT, RIM_W = 39.65, 63.7, 1.1  # mount's trough rim, inside stroke
GILT_W = 2.25  # plate's outer gilt stroke
BODY_X, TROUGH_X = 25.5, 300.0  # plate columns sampled for body and trough
PLATE_KEEP, MOUNT_KEEP, PLAQUE_KEEP = 200.0, 40.0, 28.5
RIM_RGB, RIM_A = (150, 117, 59), 0.96
CUT_RGB, CUT_A, CUT_W = (5, 7, 10), 0.55, 1.5


def grid():
    ys, xs = np.mgrid[0:OUT_H, 0:OUT_W].astype(np.float64)
    return (xs + 0.5) / K, (ys + 0.5) / K  # pixel centres in box px


def cov(sd):
    """Coverage from a signed distance in box px (negative inside)."""
    return np.clip(0.5 - sd * K, 0, 1)


def slant_sd(x, y, x_at_mid, t, mid):
    """Signed distance to the end line through (x_at_mid, mid) leaning t px right per px up."""
    return ((x - x_at_mid) + (y - mid) * t) / math.sqrt(1 + t * t)


def ruby_layer(size, cx, cy):
    ruby = Image.open(RUBY).convert("RGBA")
    ruby = ruby.crop(ruby.getbbox())
    px = round(size * K)
    ruby = ruby.resize((px, round(px * ruby.height / ruby.width)), Image.LANCZOS)
    layer = Image.new("RGBA", (OUT_W, OUT_H))
    layer.alpha_composite(ruby, (round(cx * K - ruby.width / 2), round(cy * K - ruby.height / 2)))
    return np.asarray(layer).astype(np.float64)


def over(dst, rgb, a):
    """Alpha-composite a flat colour (or per-pixel rgb) with alpha a over dst (float RGBA)."""
    src_a = a
    dst_a = dst[..., 3] / 255
    out_a = src_a + dst_a * (1 - src_a)
    rgb = np.broadcast_to(np.asarray(rgb, dtype=np.float64), dst[..., :3].shape)
    out = (rgb * src_a[..., None] + dst[..., :3] * (dst_a * (1 - src_a))[..., None]) / np.maximum(out_a, 1e-6)[..., None]
    dst[..., :3] = out
    dst[..., 3] = out_a * 255
    return dst


def build(src: Path, out: Path, angle: float, ruby_size: float, ruby_cx: float, clear: float):
    t = math.tan(math.radians(angle))
    plate0 = np.asarray(Image.open(src / "bossbar_plate.png").convert("RGBA")).astype(np.float64)
    mount0 = np.asarray(Image.open(src / "bossbar_mount.png").convert("RGBA")).astype(np.float64)
    x, y = grid()
    ruby = ruby_layer(ruby_size, ruby_cx, PLATE_MID)

    # trough end: 6 px of frame inside the plate's end, and `clear` px left of the ruby
    # on every trough row, so a full bar's leading edge shows whole
    sec = math.sqrt(1 + t * t)
    tx_frame = ruby_cx + (PLATE_MID - BAR_TOP) * t - 6 * sec
    tx = tx_frame
    for row in range(OUT_H):
        yy = (row + 0.5) / K
        if not (BAR_TOP <= yy <= BAR_BOT):
            continue
        hit = np.where(ruby[row, :, 3] > 0.3 * 255)[0]
        if len(hit):
            cap_left = hit[0] / K
            tx = min(tx, cap_left - clear + (yy - BAR_TOP) * t)
    trough_mid = tx - (PLATE_MID - BAR_TOP) * t  # trough end line at the plate's mid row

    def col(img, bx):
        return img[:, int(bx * K)]

    def at_rows(column, rows):
        idx = np.clip(rows * K - 0.5, 0, OUT_H - 1)
        lo = np.floor(idx).astype(int)
        hi = np.minimum(lo + 1, OUT_H - 1)
        f = (idx - lo)[..., None]
        return column[lo] * (1 - f) + column[hi] * f

    # ---- plate
    body_col, trough_col = col(plate0, BODY_X), col(plate0, TROUGH_X)
    sd_end = slant_sd(x, y, ruby_cx, t, PLATE_MID)
    sd = np.maximum.reduce([PLATE_TOP - y, y - PLATE_BOT, sd_end])
    inside = -sd
    gilt = at_rows(body_col, PLATE_TOP + np.clip(inside, 0, GILT_W))
    body = at_rows(body_col, y)
    rgb = np.where((inside < GILT_W)[..., None], gilt[..., :3], body[..., :3])
    plate = np.zeros_like(plate0)
    plate[..., :3] = rgb
    plate[..., 3] = cov(sd) * 255
    sd_t = np.maximum.reduce([TROUGH_TOP - y, y - TROUGH_BOT, slant_sd(x, y, trough_mid, t, PLATE_MID)])
    tro = at_rows(trough_col, y)[..., :3]
    lip = slant_sd(x, y, trough_mid, t, PLATE_MID) > -0.6  # the dark lip the top/bottom have
    tro = np.where(lip[..., None], np.array([3.0, 3, 5]), tro)
    plate = over(plate, tro, cov(sd_t) * (plate[..., 3] / 255))
    keep = (x < PLATE_KEEP)[..., None]
    plate = np.where(keep, plate0, plate)

    # ---- mount
    mount = mount0.copy()
    redo = (x >= MOUNT_KEEP) & (y >= PLAQUE_KEEP)
    mount[redo] = 0
    rim_mid = trough_mid - 0.45 * sec  # the rim sits 0.45 px inside the well, like top/bottom
    sd_r = np.maximum.reduce([RIM_TOP - y, y - RIM_BOT, slant_sd(x, y, rim_mid, t, PLATE_MID)])
    rim = np.clip(cov(sd_r) - cov(sd_r + RIM_W), 0, 1) * redo
    mount = over(mount, RIM_RGB, rim * RIM_A)
    bar_w = tx - BAR_LEFT
    cuts = np.zeros_like(x)
    for i in range(1, 10):
        cx = BAR_LEFT + bar_w * i / 10
        cuts = np.maximum(cuts, cov(np.abs(x - cx) - CUT_W / 2))
    cuts *= cov(np.maximum(RIM_TOP + RIM_W - y, y - (RIM_BOT - RIM_W)))
    mount = over(mount, CUT_RGB, cuts * CUT_A * redo)
    mount = over(mount, ruby[..., :3], ruby[..., 3] / 255)

    out.mkdir(parents=True, exist_ok=True)
    for name, img in (("bossbar_plate", plate), ("bossbar_mount", mount)):
        full = Image.fromarray(np.clip(img, 0, 255).round().astype(np.uint8), "RGBA")
        for suffix, (w, h) in SIZES.items():
            pad = round(PAD_TOP * w / BOX_W)
            padded = Image.new("RGBA", (w, h + pad))
            padded.paste(full.resize((w, h), Image.LANCZOS), (0, pad))
            padded.save(out / f"{name}{suffix}.png")
    geo = {
        "angle": angle,
        "lean": round(t, 4),
        "bar_right_top": round(tx, 2),
        "bar_right_bottom": round(tx - (BAR_BOT - BAR_TOP) * t, 2),
        "bar_width": round(bar_w, 2),
        "bar_scale_x": round(bar_w / BOX_W, 6),
        "ruby": {"cx": ruby_cx, "cy": PLATE_MID, "size": ruby_size},
        "plate_end_top": round(ruby_cx + (PLATE_MID - PLATE_TOP) * t, 2),
    }
    print(json.dumps(geo))
    return geo


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--angle", type=float, default=15.0, help="end lean from vertical, degrees")
    ap.add_argument("--ruby", type=float, default=30.0, help="ruby cap width, box px")
    ap.add_argument("--ruby-cx", type=float, default=534.0, help="ruby centre x, box px (on the plate's end)")
    ap.add_argument("--clear", type=float, default=3.0, help="gap between a full fill and the ruby, box px")
    a = ap.parse_args()
    build(a.src, a.out, a.angle, a.ruby, a.ruby_cx, a.clear)
