"""Stitch build_crane.py's render tiles (renders/<Direction>_<view>.png) into one labelled sheet,
with each piece's size as a ratio of the body part it attaches to (renders/ratios.json).

Run from the repo root after build_crane.py has rendered:
  uv run --with pillow python3 -I art/player/cosmetics/crane/make_sheet.py [OUT.png]
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "sheets" / "crane_cosmetics.png"
COLUMNS = [("front", "front"), ("side", "side (left)"), ("back", "back"),
           ("threequarter", "rear three-quarter"), ("bent", "bent: plumes sway, crest back, fan spread"),
           ("seat", "head close (plume seating)"), ("crest", "crest close (seating)"),
           ("fanclose", "fan close, bent (sealed?)")]
ROWS = [
    ("Scholar", "A  Scholar", "elegant", ["flat crimson crown cap", "streamer plumes trail straight back",
                                          "compact half-fan hangs behind the hips"]),
    ("Ascendant", "B  Ascendant", "bold", ["one tall flame crest feather", "wing plumes sweep up and back",
                                           "sunburst fan rises behind the back"]),
    ("Cascade", "C  Cascade", "soft", ["raised crimson crown, swept back", "broad plumes drape over the nape",
                                       "long trailing train"]),
]
LABEL_W, HEAD_H, PAD = 330, 34, 6
BG, FG, DIM, HI = (24, 26, 32), (240, 240, 240), (170, 176, 188), (232, 196, 120)


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "DejaVuSans.ttf", "Arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    data = json.loads((HERE / "renders" / "ratios.json").read_text())
    rat, tris = data["ratios"], data["tris"]
    tile = Image.open(HERE / "renders" / f"{ROWS[0][0]}_front.png").size[0]
    sheet = Image.new("RGB", (LABEL_W + len(COLUMNS) * (tile + PAD), HEAD_H + len(ROWS) * (tile + PAD)), BG)
    d = ImageDraw.Draw(sheet)
    f_head, f_row, f_small = font(15), font(21), font(14)
    for c, (_, label) in enumerate(COLUMNS):
        d.text((LABEL_W + c * (tile + PAD) + 8, 9), label, fill=(210, 214, 222), font=f_head)
    for r, (key, title, mood, notes) in enumerate(ROWS):
        y = HEAD_H + r * (tile + PAD)
        d.text((12, y + 12), title, fill=FG, font=f_row)
        d.text((12, y + 40), mood, fill=HI, font=f_head)
        yy = y + 64
        for n in notes:
            d.text((12, yy), n, fill=DIM, font=f_small)
            yy += 19
        h, fn = rat.get(f"CraneHead{key}", {}), rat.get(f"CraneFan{key}", {})
        yy += 10
        d.text((12, yy), "size vs the part it sits on", fill=HI, font=f_small)
        yy += 20
        lines = [
            f"crest: {h.get('crest_above_head')} head-h above top,",
            f"   {h.get('crest_width')} head-w wide",
            f"plumes: {h.get('plume_width')} head-w wide, {h.get('plume_height')} head-h tall,",
            f"   reach {h.get('plume_reach')} head-d behind",
            f"fan: {fn.get('fan_width')} torso-w wide, {fn.get('fan_height')} torso-h tall,",
            f"   reach {fn.get('fan_reach')} torso-d behind",
        ]
        for ln in lines:
            d.text((12, yy), ln, fill=DIM, font=f_small)
            yy += 18
        th = sum(tris.get(f"CraneHead{key}", {}).values())
        tf = sum(tris.get(f"CraneFan{key}", {}).values())
        d.text((12, yy + 6), f"tris: head {th:,}, fan {tf:,}", fill=DIM, font=f_small)
        for col, (view, _) in enumerate(COLUMNS):
            path = HERE / "renders" / f"{key}_{view}.png"
            if path.exists():
                sheet.paste(Image.open(path).convert("RGB"), (LABEL_W + col * (tile + PAD), y))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
