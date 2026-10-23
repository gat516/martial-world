"""Stitch build_serpent.py's render tiles (renders/<Dir>_<view>.png) into one labelled sheet,
with each direction's sizes as ratios of the R6 head (renders/ratios.json).

Run from the repo root after build_serpent.py has rendered:
  uv run --with pillow python3 -I art/player/cosmetics/serpent/make_sheet.py [OUT.png]
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "sheets" / "serpent_cosmetics.png"
COLUMNS = [("game", "game distance"), ("front", "front"), ("side", "side (left)"), ("back", "back"),
           ("threequarter", "front three-quarter"), ("flared", "fins flared 30 + tips 20 (bones)"),
           ("seat", "plate seating, close"), ("root", "fin root seating, close")]
ROWS = [
    ("Veil", "subtle-elegant", ["rounded leaf fins behind the ear", "slim crescent of round scales"]),
    ("Sovereign", "ceremonial", ["tall upswept fan (concept)", "two-lobed pointed plate"]),
    ("Fang", "fierce", ["level barbed blades, hooked", "spines past a short web;", "temple blade + cheek fang"]),
]
LABEL_W, HEAD_H, PAD = 300, 34, 6
BG, FG, DIM, ACC = (24, 26, 32), (240, 240, 240), (170, 176, 188), (120, 220, 200)


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "DejaVuSans.ttf", "Arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    ratios = json.loads((HERE / "renders" / "ratios.json").read_text())
    tile = Image.open(HERE / "renders" / f"{ROWS[0][0]}_front.png").size[0]
    lineup = [HERE / "renders" / f"Lineup_{v}.png" for v in ("front", "threequarter")]
    lineup = [Image.open(q).convert("RGB") for q in lineup if q.exists()]
    lh = max((im.size[1] for im in lineup), default=0)
    sheet = Image.new("RGB", (LABEL_W + len(COLUMNS) * (tile + PAD),
                              HEAD_H + len(ROWS) * (tile + PAD) + (lh + PAD if lineup else 0)), BG)
    d = ImageDraw.Draw(sheet)
    f_head, f_row, f_small = font(15), font(21), font(14)
    for c, (_, label) in enumerate(COLUMNS):
        d.text((LABEL_W + c * (tile + PAD) + 8, 9), label, fill=(210, 214, 222), font=f_head)
    for r, (key, mood, notes) in enumerate(ROWS):
        y = HEAD_H + r * (tile + PAD)
        d.text((12, y + 12), key, fill=FG, font=f_row)
        d.text((12, y + 42), mood, fill=ACC, font=f_head)
        yy = y + 66
        for n in notes:
            d.text((12, yy), n, fill=DIM, font=f_small)
            yy += 19
        q = ratios[key]
        yy += 10
        d.text((12, yy), "x head (W 1.2, H 1.0):", fill=FG, font=f_small)
        yy += 21
        for label, k in (("fin height", "fin_height"), ("fin length", "fin_length"),
                         ("fin rise over top", "fin_rise"), ("fin trails behind", "fin_reach_back"),
                         ("fin span tip-tip", "span"), ("plate height", "plate_height"),
                         ("plate width", "plate_width")):
            d.text((20, yy), f"{label}: {q[k]:.2f}", fill=DIM, font=f_small)
            yy += 19
        for col, (view, _) in enumerate(COLUMNS):
            path = HERE / "renders" / f"{key}_{view}.png"
            if path.exists():
                sheet.paste(Image.open(path).convert("RGB"), (LABEL_W + col * (tile + PAD), y))
    if lineup:
        y = HEAD_H + len(ROWS) * (tile + PAD)
        d.text((12, y + 12), "Lineup", fill=FG, font=f_row)
        d.text((12, y + 42), "Veil, Sovereign, Fang", fill=DIM, font=f_head)
        d.text((12, y + 62), "one body each", fill=DIM, font=f_head)
        x = LABEL_W
        for im in lineup:
            sheet.paste(im, (x, y))
            x += im.size[0] + PAD
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
