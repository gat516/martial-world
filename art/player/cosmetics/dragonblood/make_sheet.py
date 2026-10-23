"""Stitch build_dragonblood.py's render tiles (renders/<A|B|C>_<view>.png) into one labelled sheet,
one row per direction (horns + tail), with each piece's size against the head or torso.

Run from the repo root after the build has rendered:
  uv run --with pillow python3 -I art/player/cosmetics/dragonblood/make_sheet.py [OUT.png]
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "sheets" / "dragonblood_directions.png"
COLUMNS = [("front", "front"), ("side", "side (left)"), ("back", "back"), ("threequarter", "rear three-quarter"),
           ("head", "horns, front three-quarter"), ("bent", "bent: horns back 15, tail curled"),
           ("seat_side", "seat: horn root, side"), ("seat_back", "seat: horn root, back"),
           ("close", "tail close-up, bent"), ("game", "game cam 12 studs")]
ROWS = [("A", "DragonHornsAntler", "DragonTailTuft", "approved antlers: wide V, long tines"),
        ("B", "DragonHornsCelestial", "DragonTailRising", "long low sweep, three tines"),
        ("C", "DragonHornsCub", "DragonTailStub", "short, chunky, one fat tine")]
LABEL_W, HEAD_H, PAD, TILE = 330, 34, 6, 300
BG, FG, DIM = (24, 26, 32), (240, 240, 240), (170, 176, 188)


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "DejaVuSans.ttf", "Arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    t = TILE
    sheet = Image.new("RGB", (LABEL_W + len(COLUMNS) * (t + PAD), HEAD_H + len(ROWS) * (t + PAD)), BG)
    d = ImageDraw.Draw(sheet)
    f_head, f_row, f_small = font(14), font(19), font(13)
    for c, (_, label) in enumerate(COLUMNS):
        d.text((LABEL_W + c * (t + PAD) + 6, 10), label, fill=(210, 214, 222), font=f_head)
    for r, (key, horns, tail, note) in enumerate(ROWS):
        y = HEAD_H + r * (t + PAD)
        h = json.loads((HERE / f"{horns}.json").read_text())
        tl = json.loads((HERE / f"{tail}.json").read_text())
        hp, tp = h["proportions"], tl["proportions"]
        lines = [(f"{key}  {h['label']} + {tl['label']}", FG, f_row), (note, DIM, f_small),
                 (f"mood: {h['mood']}", DIM, f_small),
                 (f"{horns}", FG, f_small),
                 (f"  height {hp['height_above_head']:.2f} = {hp['height_to_head']:.0%} head h", DIM, f_small),
                 (f"  root {hp['root_diameter']:.2f} = {hp['root_to_head_width']:.0%} head w", DIM, f_small),
                 (f"  span {hp['span']:.2f} = {hp['span_to_head_width']:.0%} head w", DIM, f_small),
                 (f"  {h['tris_total']} tris a pair", DIM, f_small),
                 (f"{tail}", FG, f_small),
                 (f"  reach {tp['reach_behind_back']:.2f} = {tp['reach_to_torso_height']:.0%} torso h", DIM, f_small),
                 (f"  width {tp['width']:.2f} = {tp['width_to_torso_width']:.0%} torso w", DIM, f_small),
                 (f"  legs clear to {tp['leg_swing_back_clear_deg']} deg back-swing", DIM, f_small),
                 (f"  {tl['tris_total']} tris", DIM, f_small),
                 (f"head {hp['head_size'][0]:.2f} w x {hp['head_size'][2]:.2f} h, "
                  f"torso {tp['torso_size'][0]:.2f} x {tp['torso_size'][2]:.2f}", DIM, f_small)]
        for i, (txt, col, fnt) in enumerate(lines):
            d.text((12, y + 8 + i * 20 + (6 if i else 0)), txt, fill=col, font=fnt)
        for c, (view, _) in enumerate(COLUMNS):
            path = HERE / "renders" / f"{key}_{view}.png"
            if path.exists():
                sheet.paste(Image.open(path).convert("RGB").resize((t, t)), (LABEL_W + c * (t + PAD), y))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
