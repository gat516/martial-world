"""Compose the sect windows' frame from the kit's cut window corner.

Only crops, mirrors and pastes `art/ui/codex/cut/ornament_window_corner_small.png`
(generated art, never repainted): the corner is cropped just before its two end
knots so its rails run on cleanly, mirrored into the other three corners, and
the gap between corners is filled with copies of the rail's last plain column
(top and bottom) and last plain row (left and right), so every 9-slice edge strip
is identical along its stretch.

Writes art/ui/sect/window_frame.png. In Roblox:
    ScaleType Slice, SliceCenter Rect(CW, CH, CW + GAP, CH + GAP), SliceScale ~0.22
(the docstring's numbers are printed when it runs).

Run: uv run --with pillow python tools/ui_compose_sect.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CUT = ROOT / "art/ui/codex/cut"
OUT = ROOT / "art/ui/sect"

CROP = (0, 0, 476, 296)  # stops before the end knots (x 482+, y 300+)
GAP = 8


def window_frame() -> None:
    corner = Image.open(CUT / "ornament_window_corner_small.png").convert("RGBA").crop(CROP)
    cw, ch = corner.size
    w, h = cw * 2 + GAP, ch * 2 + GAP
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    tl = corner
    tr = corner.transpose(Image.FLIP_LEFT_RIGHT)
    bl = corner.transpose(Image.FLIP_TOP_BOTTOM)
    br = tr.transpose(Image.FLIP_TOP_BOTTOM)
    canvas.paste(tl, (0, 0))
    canvas.paste(tr, (cw + GAP, 0))
    canvas.paste(bl, (0, ch + GAP))
    canvas.paste(br, (cw + GAP, ch + GAP))
    col = tl.crop((cw - 1, 0, cw, ch))
    row = tl.crop((0, ch - 1, cw, ch))
    for i in range(GAP):
        canvas.paste(col, (cw + i, 0))
        canvas.paste(col.transpose(Image.FLIP_TOP_BOTTOM), (cw + i, ch + GAP))
        canvas.paste(row, (0, ch + i))
        canvas.paste(row.transpose(Image.FLIP_LEFT_RIGHT), (cw + GAP, ch + i))
    OUT.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT / "window_frame.png")
    print(f"window_frame.png {w}x{h} SliceCenter Rect({cw}, {ch}, {cw + GAP}, {ch + GAP})")


if __name__ == "__main__":
    window_frame()
