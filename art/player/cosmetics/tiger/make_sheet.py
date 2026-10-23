"""Stitch build_tiger.py's render tiles (renders/<Direction>_<view>.png) into one labelled sheet,
with each piece's size as a ratio of the body part it attaches to (renders/sizes.json).

Run from the repo root after build_tiger.py has rendered:
  uv run --with pillow python3 -I art/player/cosmetics/tiger/make_sheet.py [OUT.png]
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "sheets" / "tiger_cosmetics.png"
COLUMNS = [("front", "front"), ("side", "side (left)"), ("back", "back"), ("threequarter", "rear three-quarter"),
           ("bent", "bent: tail + ears folded 50"), ("ears", "ears close (back spots)"),
           ("face", "face close (whiskers)"), ("seat", "ear seating, side close"), ("close", "tail close, bent")]
ROWS = [  # (direction, tail, ears, whiskers, note)
    ("Cub", "TigerTailCurl", "TigerEarsRound", "TigerWhiskersMarks", ["cute", "round dome ears", "thick tail, curled",
                                                                       "banded tip", "short whisker marks"]),
    ("Feral", "TigerTailLash", "TigerEarsPinned", "TigerWhiskersFine", ["aggressive", "ears pinned flat and back",
                                                                         "long low lash",
                                                                         "fine swept whiskers"]),
    ("Regal", "TigerTailCrown", "TigerEarsTufted", "TigerWhiskersCurl", ["proud", "upright fringed ears",
                                                                          "tail raised in a high arc",
                                                                          "curled whiskers"]),
]
LABEL_W, HEAD_H, PAD = 330, 34, 6
BG, FG, DIM = (24, 26, 32), (240, 240, 240), (170, 176, 188)


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "DejaVuSans.ttf", "Arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    sizes = json.loads((HERE / "renders" / "sizes.json").read_text())
    tile = Image.open(HERE / "renders" / f"{ROWS[0][0]}_front.png").size[0]
    sheet = Image.new("RGB", (LABEL_W + len(COLUMNS) * (tile + PAD), HEAD_H + len(ROWS) * (tile + PAD)), BG)
    d = ImageDraw.Draw(sheet)
    f_head, f_row, f_small = font(15), font(21), font(14)
    for c, (_, label) in enumerate(COLUMNS):
        d.text((LABEL_W + c * (tile + PAD) + 8, 9), label, fill=(210, 214, 222), font=f_head)
    for r, (direction, tail, ears, whisk, note) in enumerate(ROWS):
        y = HEAD_H + r * (tile + PAD)
        e, t, w = sizes[ears], sizes[tail], sizes[whisk]
        lines = note + ["", ears, f"  {e['visible_height']} st tall = {e['height_vs_head']:.0%} head h",
                        f"  {e['width']} st wide = {e['width_vs_head']:.0%} head w", f"  {e['tris']} tris (pair)",
                        tail, f"  {t['length']} st = {t['length_vs_torso_height']:.0%} torso h",
                        f"  {t['thickness']} st thick = {t['thickness_vs_torso_depth']:.0%} torso d",
                        f"  {t['tris']} tris", whisk, f"  span {w['span_vs_head_width']:.0%} head w,",
                        f"  past side {w['past_side_vs_head_width']:.0%}; {w['tris']} tris"]
        d.text((12, y + 10), direction, fill=FG, font=f_row)
        for i, line in enumerate(lines):
            d.text((12, y + 40 + i * 19), line, fill=FG if line.startswith("Tiger") else DIM, font=f_small)
        for col, (view, _) in enumerate(COLUMNS):
            path = HERE / "renders" / f"{direction}_{view}.png"
            if path.exists():
                sheet.paste(Image.open(path).convert("RGB"), (LABEL_W + col * (tile + PAD), y))
    ref = sizes["_reference"]
    d.text((12, 9), f"head {ref['head']['width']} w x {ref['head']['height']} h", fill=DIM, font=f_small)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
