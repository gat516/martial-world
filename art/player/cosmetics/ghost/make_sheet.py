"""Stitch build_ghost.py's render tiles (renders/<Direction>_<view>.png) into one labelled sheet,
one row per direction, with each piece's size against the body part it attaches to.

Run from the repo root after build_ghost.py has rendered:
  uv run --with pillow python3 -I art/player/cosmetics/ghost/make_sheet.py [OUT.png]
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "sheets" / "ghost_directions.png"
COLUMNS = [("front", "front"), ("side", "side (left)"), ("back", "back"), ("threequarter", "rear 3/4"),
           ("bent", "bent: wisps 22/joint, talisman 25"), ("run", "R6 run pose (clearance)"),
           ("game", "game cam 12 studs, back"), ("game_front", "game cam 12 studs, front"),
           ("tal_front", "talisman close"), ("tal_seat", "talisman seat, side"),
           ("tal_flutter", "talisman lifted 25"), ("solid", "solid (no fade): sealed?")]
ROWS = [("Sleeves", "GhostTalismanStrip", ["GhostSleeveL", "GhostSleeveR"],
         "spectral bell sleeves, a broad drape + ribbon streaming back; long strip talisman"),
        ("Train", "GhostTalismanBanner", ["GhostTrain"],
         "lower body: sash, broad tail sinking and curling, two side sheets; swallowtail banner"),
        ("Stole", "GhostTalismanSeal", ["GhostStole"],
         "celestial silk: halo hoop behind the head, ends floating over the arms; square seal")]
TILE, LABEL_W, HEAD_H, PAD = 300, 330, 34, 6
BG, FG, DIM = (24, 26, 32), (240, 240, 240), (170, 176, 188)


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "DejaVuSans.ttf", "Arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def wrap(text, n=40):
    out, line = [], ""
    for w in text.split():
        if len(line) + len(w) + 1 > n:
            out.append(line)
            line = w
        else:
            line = (line + " " + w).strip()
    return out + [line]


def lines_for(rep, tal, wisps):
    t = rep[tal]["proportions"]
    w = rep[wisps[0]]["proportions"]
    tris = sum(v for k, v in rep[tal].items() if isinstance(v, int))
    wt = sum(v for n in wisps for k, v in rep[n].items() if isinstance(v, int))
    out = [f"talisman {tal[13:]}: {t['height']:.2f} h x {t['width']:.2f} w",
           f"  = {t['height_to_head']:.0%} head height, {t['width_to_head']:.0%} head width"]
    if "cuff_height_to_arm" in w:
        out += [f"cuff {w['cuff_height']:.2f} = {w['cuff_height_to_arm']:.0%} of arm length",
                f"  opening {w['cuff_opening_to_arm_width']:.0%} of arm width",
                f"drape {w['ribbon_length']:.2f} = {w['ribbon_to_arm_length']:.0%} of arm length",
                f"  width {w['ribbon_width_to_arm_width']:.0%} of arm width"]
    elif "tail_to_leg_height" in w:
        out += [f"tail {w['tail_length']:.2f} = {w['tail_to_leg_height']:.0%} of leg height",
                f"  width {w['tail_width_to_torso']:.0%} of torso width",
                f"side sheets {w['side_length_to_leg']:.0%} of leg height",
                f"  span {w['span_to_torso_width']:.0%} of torso width"]
    else:
        out += [f"hoop top {w['hoop_above_shoulders']:.2f} above shoulders",
                f"  = {w['hoop_above_shoulders_to_torso']:.0%} of torso height",
                f"ends {w['trail_length']:.2f} = {w['trail_to_torso_height']:.0%} of torso h.",
                f"  span {w['span_to_torso_width']:.0%} of torso width"]
    out.append(f"tris: talisman {tris}, wisps {wt}")
    clr = {k: v for n in wisps for k, v in rep[n]["run_clearance"]["inside"].items() if k != "Floor"}
    out.append("run swing: clear" if not clr else "run swing: " + ", ".join(f"{k} {v[1]:.2f}" for k, v in clr.items()))
    return out


def main():
    rep = json.loads((HERE / "renders" / "report.json").read_text())
    t = TILE
    sheet = Image.new("RGB", (LABEL_W + len(COLUMNS) * (t + PAD), HEAD_H + len(ROWS) * (t + PAD)), BG)
    d = ImageDraw.Draw(sheet)
    f_head, f_row, f_small = font(13), font(20), font(13)
    for c, (_, label) in enumerate(COLUMNS):
        d.text((LABEL_W + c * (t + PAD) + 6, 10), label, fill=(210, 214, 222), font=f_head)
    for r, (label, tal, wisps, note) in enumerate(ROWS):
        y = HEAD_H + r * (t + PAD)
        d.text((12, y + 8), f"{r + 1}. {label}", fill=FG, font=f_row)
        yy = y + 38
        for ln in wrap(note, 44):
            d.text((12, yy), ln, fill=DIM, font=f_small)
            yy += 17
        yy += 6
        for ln in lines_for(rep, tal, wisps):
            d.text((12, yy), ln, fill=DIM, font=f_small)
            yy += 17
        for c, (view, _) in enumerate(COLUMNS):
            path = HERE / "renders" / f"{label}_{view}.png"
            if path.exists():
                sheet.paste(Image.open(path).convert("RGB").resize((t, t)), (LABEL_W + c * (t + PAD), y))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
