"""Stitch build_stone_spirit.py's render tiles (renders/<Direction>_<view>.png) into one sheet,
one row per direction, with each piece's size against the body part it sits on.

Run from the repo root after the build has rendered (the proportions come from the build's
printout, saved as renders/report.json):
  uv run --with pillow python3 -I art/player/cosmetics/stone-spirit/make_sheet.py [OUT.png]
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "sheets" / "stone_spirit_directions.png"
COLUMNS = [("front", "front"), ("side", "side (left)"), ("back", "back"), ("front34", "front three-quarter"),
           ("rear34", "rear three-quarter"), ("game", "game cam, 12 studs"),
           ("motion", "arms swung 70/-45, ring turned, bob"), ("seat_side", "seat: arm piece, low side"),
           ("seat_front", "seat: arm piece, low front")]
ROWS = [
    ("Peak", "A. Peak", "hero: stacked-stone pauldrons",
     ["StonePeakPlateL", "StonePeakShards"]),
    ("Orbit", "B. Orbit", "hero: full ring of six shards",
     ["StoneOrbitShards", "StoneOrbitBracerL"]),
    ("Fist", "C. Fist", "hero: heavy stone gauntlets",
     ["StoneFistGauntletL", "StoneFistShards"]),
]
LABEL_W, HEAD_H, PAD, TILE = 330, 34, 6, 300
BG, FG, DIM = (24, 26, 32), (240, 240, 240), (170, 176, 188)


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "DejaVuSans.ttf", "Arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def lines_for(name, info):
    pr = info["proportions"]
    if "shards" in pr:
        return [f"{name}: {pr['shards']} shards, {info['tris']} tris",
                f"  shard {pr['shard_size'][0]:.2f}-{pr['shard_size'][1]:.2f} st"
                f" = {pr['shard_to_head_height'][0]:.0%}-{pr['shard_to_head_height'][1]:.0%} head h",
                f"  span {pr['span']:.2f} st = {pr['span_to_shoulders']:.0%} of shoulders (4.0)"]
    out = [f"{name}: {info['tris']} tris (x2)",
           f"  {pr['width']:.2f} w = {pr['width_to_arm']:.0%} arm width ({pr['arm_size'][0]:.2f})",
           f"  {pr['depth']:.2f} d = {pr['depth_to_arm']:.0%} arm depth ({pr['arm_size'][1]:.2f})"]
    if "above_arm" in pr:
        out.append(f"  rises {pr['above_arm']:.2f} over arm = {pr['above_arm_to_arm_width']:.0%} arm w")
    else:
        out.append(f"  {pr['height']:.2f} long = {pr['height_to_arm_length']:.0%} arm length (2.0)")
    return out


def main():
    report = json.loads((HERE / "renders" / "report.json").read_text())
    sheet = Image.new("RGB", (LABEL_W + len(COLUMNS) * (TILE + PAD), HEAD_H + len(ROWS) * (TILE + PAD)), BG)
    d = ImageDraw.Draw(sheet)
    f_head, f_row, f_small = font(13), font(20), font(12)
    for c, (_, label) in enumerate(COLUMNS):
        d.text((LABEL_W + c * (TILE + PAD) + 6, 10), label, fill=(210, 214, 222), font=f_head)
    for r, (key, title, hero, sets) in enumerate(ROWS):
        y = HEAD_H + r * (TILE + PAD)
        d.text((12, y + 10), title, fill=FG, font=f_row)
        d.text((12, y + 38), hero, fill=DIM, font=f_head)
        yy = y + 64
        for s in sets:
            for i, txt in enumerate(lines_for(s, report[s])):
                d.text((12, yy), txt, fill=FG if i == 0 else DIM, font=f_small)
                yy += 18
            yy += 6
        for col, (view, _) in enumerate(COLUMNS):
            path = HERE / "renders" / f"{key}_{view}.png"
            if path.exists():
                sheet.paste(Image.open(path).convert("RGB").resize((TILE, TILE)), (LABEL_W + col * (TILE + PAD), y))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
