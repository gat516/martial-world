"""Stitch build_fox.py's render tiles (renders/<Tail>_<view>.png) into one labelled sheet.

Run from the repo root after build_fox.py has rendered:
  uv run --with pillow python3 -I art/player/cosmetics/fox/make_sheet.py [OUT.png]
  uv run --with pillow python3 -I art/player/cosmetics/fox/make_sheet.py ears [OUT.png] [Set ...]
Tails: the three tails, each shown with its paired ears, then the 3-tail fan proof.
Ears: one row per ear set (cute round, cute alert, cute sleepy), with the old side view beside
the new one and each set's size against the head (from <Set>.json).
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1] != "ears" else HERE / "sheets" / "fox_cosmetics.png"
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


EAR_COLUMNS = [("front", "front"), ("side", "side (left)"), ("back", "back"), ("fold", "fold back 60"),
               ("flick", "flick out 35"), ("seat_side", "seat: side, close"), ("seat_back", "seat: back, close"),
               ("seat_front", "seat: front, close"), ("game_back", "game cam 12 studs, back"),
               ("game_front", "game cam 12 studs, front"), ("oldnew", "old (left) vs new, side"),
               ("ratio", "scaled to 45% head height")]
EAR_ROWS = [("FoxEarsBroad", "approved: round dome"), ("FoxEarsSleek", "soft point, notch"),
            ("FoxEarsLong", "top flops out")]
EAR_TILE = 300


def ear_sheet(out, names):
    rows = [r for r in EAR_ROWS if not names or r[0] in names]
    t = EAR_TILE
    sheet = Image.new("RGB", (LABEL_W + len(EAR_COLUMNS) * (t + PAD), HEAD_H + len(rows) * (t + PAD)), BG)
    d = ImageDraw.Draw(sheet)
    f_head, f_row = font(13), font(19)
    for c, (_, label) in enumerate(EAR_COLUMNS):
        d.text((LABEL_W + c * (t + PAD) + 6, 10), label, fill=(210, 214, 222), font=f_head)
    for r, (name, note) in enumerate(rows):
        y = HEAD_H + r * (t + PAD)
        info = json.loads((HERE / f"{name}.json").read_text())
        pr = info["proportions"]
        lines = [(name, FG, f_row), (f"mood: {info['mood']}", DIM, f_head), (note, DIM, f_head),
                 (f"height {pr['visible_height']:.2f} studs", DIM, f_head),
                 (f"  = {pr['height_to_head']:.0%} of head height", DIM, f_head),
                 (f"base {pr['base_width']:.2f} studs", DIM, f_head),
                 (f"  = {pr['base_width_to_head']:.0%} of head width", DIM, f_head),
                 (f"head {pr['head_size'][0]:.2f} w x {pr['head_size'][2]:.2f} h", DIM, f_head),
                 (f"{info['tris_total']} tris a pair", DIM, f_head)]
        for i, (txt, col, fnt) in enumerate(lines):
            d.text((12, y + 12 + i * 24 + (6 if i else 0)), txt, fill=col, font=fnt)
        for c, (view, _) in enumerate(EAR_COLUMNS):
            x = LABEL_W + c * (t + PAD)
            if view == "oldnew":
                old = HERE / "renders" / f"old_{name}_side.png"
                new = HERE / "renders" / f"{name}_side.png"
                if old.exists() and new.exists():
                    half = t // 2
                    for k, src in enumerate((old, new)):
                        im = Image.open(src).convert("RGB")
                        w, h = im.size
                        im = im.crop((w // 4, 0, w * 3 // 4, h)).resize((half, t))
                        sheet.paste(im, (x + k * half, y))
                    d.line([(x + half, y), (x + half, y + t)], fill=BG, width=3)
                continue
            path = HERE / "renders" / f"{name}_{view}.png"
            if path.exists():
                sheet.paste(Image.open(path).convert("RGB").resize((t, t)), (x, y))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "ears":
        ear_sheet(Path(sys.argv[2]) if len(sys.argv) > 2 else HERE / "sheets" / "fox_ears.png", sys.argv[3:])
    else:
        main()
