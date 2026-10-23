"""Stitch build_demonic_human.py's render tiles (renders/<Direction>_<view>.png) into one sheet.

Run from the repo root after the build has rendered:
  uv run --with pillow python3 -I art/player/cosmetics/demonic-human/make_sheet.py [OUT.png]
One row per direction (horns + tail), with each piece's size against the body part it sits on
(from renders/report.json).
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "sheets" / "demonic_human_directions.png"
COLUMNS = [("front", "front"), ("side", "side (left)"), ("back", "back"), ("threequarter", "rear three-quarter"),
           ("bent", "bent pose (tail chain)"), ("head", "horns close"), ("seat_side", "seat: side, close"),
           ("seat_back", "seat: back, close"), ("game", "game cam, 12 studs")]
ROWS = [("Ram", "DemonHornsRam", "DemonTailWhip", "the reference: curl + whip"),
        ("Swept", "DemonHornsSwept", "DemonTailHook", "low sweep back + hook"),
        ("Crescent", "DemonHornsCrescent", "DemonTailTrail", "rising crescents + trail")]
LABEL_W, HEAD_H, PAD, TILE = 330, 34, 6, 320
BG, FG, DIM = (24, 26, 32), (240, 240, 240), (170, 176, 188)


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "DejaVuSans.ttf", "Arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    rep = json.loads((HERE / "renders" / "report.json").read_text())
    t = TILE
    sheet = Image.new("RGB", (LABEL_W + len(COLUMNS) * (t + PAD), HEAD_H + len(ROWS) * (t + PAD)), BG)
    d = ImageDraw.Draw(sheet)
    f_head, f_row = font(14), font(20)
    for c, (_, label) in enumerate(COLUMNS):
        d.text((LABEL_W + c * (t + PAD) + 6, 10), label, fill=(210, 214, 222), font=f_head)
    for r, (label, horns, tail, note) in enumerate(ROWS):
        y = HEAD_H + r * (t + PAD)
        h, tl = rep[horns], rep[tail]
        hp, tp = h["proportions"], tl["proportions"]
        lines = [(f"{r + 1}. {label}", FG, f_row), (note, DIM, f_head),
                 (f"{horns}  ({h['mood']})", FG, f_head),
                 (f"  above head {hp['height_above_head']:.2f} = {hp['height_to_head']:.0%} head h", DIM, f_head),
                 (f"  span {hp['span']:.2f} = {hp['span_to_head']:.0%} head w", DIM, f_head),
                 (f"  base dia {hp['base_diameter']:.2f} = {hp['base_to_head']:.0%} head w", DIM, f_head),
                 (f"  {h['tris_total']} tris a pair", DIM, f_head),
                 (f"{tail}  ({tl['mood']})", FG, f_head),
                 (f"  length {tp['length']:.2f} = {tp['length_to_torso_height']:.0%} torso h", DIM, f_head),
                 (f"  thick {tp['thickness']:.2f} = {tp['thickness_to_torso_width']:.0%} torso w", DIM, f_head),
                 (f"  spade {tp['spade_length']:.2f} = {tp['spade_length_to_torso_width']:.0%} torso w", DIM, f_head),
                 (f"  {tl['tris_total']} tris, run clearance {tl['limb_clearance_running']:.2f}", DIM, f_head)]
        for i, (txt, col, fnt) in enumerate(lines):
            d.text((12, y + 8 + i * 25 + (4 if i else 0)), txt, fill=col, font=fnt)
        for c, (view, _) in enumerate(COLUMNS):
            path = HERE / "renders" / f"{label}_{view}.png"
            if path.exists():
                sheet.paste(Image.open(path).convert("RGB").resize((t, t)), (LABEL_W + c * (t + PAD), y))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
