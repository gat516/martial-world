"""Derived pieces for the dialogue panel, made only by mirroring and cropping cut art
(no painting): the four window corners, the straight rail strips that run between
them, and the same for the small portrait/text-box corner.

Run: uv run --with pillow python art/ui/dialogue/derive.py
Inputs: art/ui/codex/cut/ornament_window_corner.png, ornament_portrait_corner.png
Outputs: art/ui/dialogue/*.png (see docs/ui/dialogue.md for where each is used)

Rail strips are a few columns (or rows) cut from a plain stretch of the corner's own
rail, so stretched along their length they continue the rail exactly. Their cross
section keeps the corner's offsets (a horizontal strip spans the corner's rows
0..RAIL_H), so a strip laid at the corner's top edge lines up with its rail.
"""

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
CUT = ROOT / "art/ui/codex/cut"
OUT = ROOT / "art/ui/dialogue"

FLIP_X = Image.Transpose.FLIP_LEFT_RIGHT
FLIP_Y = Image.Transpose.FLIP_TOP_BOTTOM

# (source, prefix, horizontal strip column, rail depth, vertical strip row)
CORNERS = [
    # window_corner 1011x529: rails between the cloud and the fret at x 470-890,
    # y 330-420 on the vertical arm
    ("ornament_window_corner.png", "window", 700, 110, 400),
    # portrait_corner 238x158: plain arm runs x 120-210 and y 100-130
    ("ornament_portrait_corner.png", "pcorner", 170, 40, 115),
]
STRIP = 8


def main() -> None:
    for source, prefix, col, depth, row in CORNERS:
        im = Image.open(CUT / source).convert("RGBA")
        im.save(OUT / f"{prefix}_tl.png")
        im.transpose(FLIP_X).save(OUT / f"{prefix}_tr.png")
        im.transpose(FLIP_Y).save(OUT / f"{prefix}_bl.png")
        im.transpose(FLIP_X).transpose(FLIP_Y).save(OUT / f"{prefix}_br.png")
        top = im.crop((col, 0, col + STRIP, depth))
        top.save(OUT / f"{prefix}_rail_top.png")
        top.transpose(FLIP_Y).save(OUT / f"{prefix}_rail_bottom.png")
        left = im.crop((0, row, depth, row + STRIP))
        left.save(OUT / f"{prefix}_rail_left.png")
        left.transpose(FLIP_X).save(OUT / f"{prefix}_rail_right.png")
        print(prefix, im.size)
    # the cutter leaves the key colour under transparent pixels; Roblox filters it
    # into the edges (tools/alpha_bleed.py)
    sys.path.insert(0, str(ROOT / "tools"))
    from alpha_bleed import bleed

    for png in sorted(OUT.glob("*.png")):
        bleed(str(png))


if __name__ == "__main__":
    main()
