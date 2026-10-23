"""Derived pieces for the cultivation screens, made only by cropping, mirroring and
stretching cut kit art (no painting), plus one procedural fill.

Run: uv run --with pillow --with numpy python art/ui/cultivation/derive.py
Inputs: art/ui/codex/cut/ornament_window_corner_small.png
Outputs (docs/ui/cultivation.md says where each is used):
  window_small.png  one 9-slice window: the small window corner, mirrored to all
                    four corners and cropped before its fret knots, joined by
                    strips of its own plain rail, over the kit's panel navy.
                    SliceCenter Rect(CORNER_W, CORNER_H, W - CORNER_W, H - CORNER_H),
                    SliceScale ~0.3 for a 300-400 px window.
  meter_disc.png    a white disc (the foundation meter's fill, tinted in game).
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
CUT = ROOT / "art/ui/codex/cut"
OUT = ROOT / "art/ui/cultivation"

FLIP_X = Image.Transpose.FLIP_LEFT_RIGHT
FLIP_Y = Image.Transpose.FLIP_TOP_BOTTOM

# window_corner_small is 573x386: the horizontal rail is plain from x 340 to 470
# (rows 14-64), the vertical rail from y 230 to 300 (cols 6-57); the fret knots
# start past those. The corner is cropped inside the plain stretch.
CORNER_W, CORNER_H = 420, 280
RAIL_COL, RAIL_ROW = 400, 260 # where the strips are taken
RAIL_DEPTH = 70 # rows (or columns) a strip spans from the outer edge
MIDDLE = 64 # plain middle between the corners, in source px
W, H = 2 * CORNER_W + MIDDLE, 2 * CORNER_H + MIDDLE
NAVY = (17, 24, 32, 246) # between the HUD plate and the kit tiles' interior
FILL_INSET_X, FILL_INSET_Y = 32, 39 # the rails' centre lines: the fill starts under them


def window() -> Image.Image:
    corner = Image.open(CUT / "ornament_window_corner_small.png").convert("RGBA")
    tl = corner.crop((0, 0, CORNER_W, CORNER_H))
    top = corner.crop((RAIL_COL, 0, RAIL_COL + 1, RAIL_DEPTH))
    left = corner.crop((0, RAIL_ROW, RAIL_DEPTH, RAIL_ROW + 1))
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(canvas).rectangle((FILL_INSET_X, FILL_INSET_Y, W - 1 - FILL_INSET_X, H - 1 - FILL_INSET_Y), fill=NAVY)
    rails = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hstrip = top.resize((W - 2 * CORNER_W + 2, RAIL_DEPTH))
    vstrip = left.resize((RAIL_DEPTH, H - 2 * CORNER_H + 2))
    rails.alpha_composite(hstrip, (CORNER_W - 1, 0))
    rails.alpha_composite(hstrip.transpose(FLIP_Y), (CORNER_W - 1, H - RAIL_DEPTH))
    rails.alpha_composite(vstrip, (0, CORNER_H - 1))
    rails.alpha_composite(vstrip.transpose(FLIP_X), (W - RAIL_DEPTH, CORNER_H - 1))
    rails.alpha_composite(tl, (0, 0))
    rails.alpha_composite(tl.transpose(FLIP_X), (W - CORNER_W, 0))
    rails.alpha_composite(tl.transpose(FLIP_Y), (0, H - CORNER_H))
    rails.alpha_composite(tl.transpose(FLIP_X).transpose(FLIP_Y), (W - CORNER_W, H - CORNER_H))
    canvas.alpha_composite(rails)
    return canvas


def disc(size: int = 256) -> Image.Image:
    ss = 4
    big = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(big).ellipse((0, 0, size * ss - 1, size * ss - 1), fill=255)
    alpha = big.resize((size, size), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def main() -> None:
    w = window()
    w.save(OUT / "window_small.png")
    print("window_small", w.size, "SliceCenter", (CORNER_W, CORNER_H, W - CORNER_W, H - CORNER_H))
    disc().save(OUT / "meter_disc.png")


if __name__ == "__main__":
    main()
