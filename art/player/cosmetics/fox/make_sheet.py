"""Stitch build_fox.py's render tiles (renders/<Tail>_<view>.png) into one labelled sheet.

Run from the repo root after build_fox.py has rendered:
  uv run --with pillow python3 -I art/player/cosmetics/fox/make_sheet.py [OUT.png]
Rows: the three tails, each shown with its paired ears, then the 3-tail fan proof.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "sheets" / "fox_cosmetics.png"
COLUMNS = [("front", "front"), ("side", "side (left)"), ("back", "back"),
           ("threequarter", "rear three-quarter"), ("bent", "bent: 40 deg/joint (Wisp: 30 sway), ears back"),
           ("ears", "ears close"), ("close", "close-up, bent (sealed?)")]
ROWS = [
    ("FoxTailPlume", "FoxTailPlume", "+ FoxEarsSleek", "rising S-curve plume"),
    ("FoxTailCrescent", "FoxTailCrescent", "+ FoxEarsBroad", "sweeps aside into a crescent"),
    ("FoxTailWisp", "FoxTailWisp", "+ FoxEarsLong", "low hang, hooked tip"),
    ("FoxFan", "3-tail fan", "proof, not exported", "Plume x3 at -40/0/+40 deg"),
]
LABEL_W, HEAD_H, PAD = 280, 34, 6
BG, FG, DIM = (24, 26, 32), (240, 240, 240), (170, 176, 188)


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "DejaVuSans.ttf", "Arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    tile = Image.open(HERE / "renders" / f"{ROWS[0][0]}_front.png").size[0]
    sheet = Image.new("RGB", (LABEL_W + len(COLUMNS) * (tile + PAD), HEAD_H + len(ROWS) * (tile + PAD)), BG)
    d = ImageDraw.Draw(sheet)
    f_head, f_row = font(15), font(19)
    for c, (_, label) in enumerate(COLUMNS):
        d.text((LABEL_W + c * (tile + PAD) + 8, 9), label, fill=(210, 214, 222), font=f_head)
    for r, (key, title, sub, note) in enumerate(ROWS):
        y = HEAD_H + r * (tile + PAD)
        d.text((12, y + 14), title, fill=FG, font=f_row)
        d.text((12, y + 42), sub, fill=DIM, font=f_head)
        d.text((12, y + 64), note, fill=DIM, font=f_head)
        for col, (view, _) in enumerate(COLUMNS):
            path = HERE / "renders" / f"{key}_{view}.png"
            if path.exists():
                sheet.paste(Image.open(path).convert("RGB"), (LABEL_W + col * (tile + PAD), y))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
