"""Stitch build_wolf.py's render tiles (renders/<Set>_<view>.png) into the wolf sheets.

Run from the repo root after build_wolf.py (and lineup.py, for the lineup strip) has rendered:
  uv run --with pillow python3 -I art/player/cosmetics/wolf/make_sheet.py [OUT.png]
  uv run --with pillow python3 -I art/player/cosmetics/wolf/make_sheet.py ears [OUT.png] [Set ...]
Tails: one row per look (tail + its ears), with the tail's size against the torso and the
running check, and the lineup (one body per look) under the rows.
Ears: one row per ear set, with each set's size against the head and the measured seat.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1] != "ears" else HERE / "sheets" / "wolf_cosmetics.png"
COLUMNS = [("front", "front"), ("side", "side (left)"), ("back", "back"),
           ("threequarter", "rear three-quarter"), ("bent", "bent (per-joint check)"),
           ("run_a", "running, side"), ("run_b", "running, other phase"),
           ("game", "game cam 12 studs"), ("seat", "seat: where it leaves the back"),
           ("close", "close-up, bent (sealed?)")]
ROWS = [
    ("WolfTailBrush", "A: + WolfEarsSentinel"),
    ("WolfTailMane", "B: + WolfEarsRuff"),
    ("WolfTailBanner", "C: + WolfEarsLance"),
]
LINEUP = [("lineup_back", "lineup from behind (A, B, C left to right as worn)"),
          ("lineup_side", "lineup, rear three-quarter"), ("lineup_front", "lineup from the front")]
LABEL_W, HEAD_H, PAD = 280, 34, 6
BG, FG, DIM = (24, 26, 32), (240, 240, 240), (170, 176, 188)


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "DejaVuSans.ttf", "Arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def stats(name):
    """The build's numbers for a set: renders/<Set>_stats.json (written on every render), else the
    exported <Set>.json."""
    for path in (HERE / "renders" / f"{name}_stats.json", HERE / f"{name}.json"):
        if path.exists():
            return json.loads(path.read_text())
    return {}


def main():
    tile = Image.open(HERE / "renders" / f"{ROWS[0][0]}_front.png").size[0]
    width = LABEL_W + len(COLUMNS) * (tile + PAD)
    strip = [(HERE / "renders" / f"{k}.png", t) for k, t in LINEUP]
    strip = [(Image.open(p).convert("RGB"), t) for p, t in strip if p.exists()]
    lw = (width - LABEL_W - PAD * len(LINEUP)) // len(LINEUP)
    lh = round(lw * 9 / 16)
    sheet = Image.new("RGB", (width, HEAD_H + len(ROWS) * (tile + PAD) + (lh + HEAD_H if strip else 0)), BG)
    d = ImageDraw.Draw(sheet)
    f_head, f_row = font(15), font(19)
    for c, (_, label) in enumerate(COLUMNS):
        d.text((LABEL_W + c * (tile + PAD) + 8, 9), label, fill=(210, 214, 222), font=f_head)
    for r, (key, note) in enumerate(ROWS):
        y = HEAD_H + r * (tile + PAD)
        info = stats(key)
        pr = info.get("proportions", {})
        lines = [(key, FG, f_row), (f"mood: {info.get('mood', '?')}", DIM, f_head), (note, DIM, f_head)]
        if pr:
            ts = pr["torso_size"]
            lines += [(f"length {pr['length']:.2f} studs", DIM, f_head),
                      (f"  = {pr['length_to_torso_height']:.2f} x torso height", DIM, f_head),
                      (f"girth {pr['girth']:.2f} studs", DIM, f_head),
                      (f"  = {pr['girth_to_torso_width']:.2f} x torso width", DIM, f_head),
                      (f"torso {ts[0]:.2f} w x {ts[2]:.2f} h, legs {pr['leg_height']:.2f}", DIM, f_head)]
        clr = info.get("run_clearance", {}).get("limbs")
        if clr:
            worst = max(v["deepest"] for v in clr.values())
            lines.append((f"run swing: deepest touch {worst:.2f}", DIM, f_head))
        lines.append((f"{info.get('tris_total', '?')} tris", DIM, f_head))
        for i, (txt, col, fnt) in enumerate(lines):
            d.text((12, y + 12 + i * 24 + (6 if i else 0)), txt, fill=col, font=fnt)
        for col, (view, _) in enumerate(COLUMNS):
            path = HERE / "renders" / f"{key}_{view}.png"
            if path.exists():
                sheet.paste(Image.open(path).convert("RGB").resize((tile, tile)), (LABEL_W + col * (tile + PAD), y))
    if strip:
        y = HEAD_H + len(ROWS) * (tile + PAD)
        d.text((12, y + HEAD_H + 12), "one body per look", fill=FG, font=f_row)
        for i, (im, txt) in enumerate(strip):
            x = LABEL_W + i * (lw + PAD)
            d.text((x + 8, y + 9), txt, fill=(210, 214, 222), font=f_head)
            sheet.paste(im.resize((lw, lh)), (x, y + HEAD_H))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(OUT)


EAR_COLUMNS = [("front", "front"), ("side", "side (left)"), ("back", "back"), ("fold", "fold back 60"),
               ("flick", "flick out 35"), ("seat_side", "seat: side, close"), ("seat_back", "seat: back, close"),
               ("seat_front", "seat: front, close"), ("game_back", "game cam 12 studs, back"),
               ("game_front", "game cam 12 studs, front")]
EAR_ROWS = [("WolfEarsSentinel", "A: upright clean point"), ("WolfEarsRuff", "B: splayed, notched, serrated"),
            ("WolfEarsLance", "C: laid back, swept tip")]
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
        info = stats(name)
        pr = info["proportions"]
        lines = [(name, FG, f_row), (f"mood: {info['mood']}", DIM, f_head), (note, DIM, f_head),
                 (f"height {pr['visible_height']:.2f} studs", DIM, f_head),
                 (f"  = {pr['height_to_head']:.0%} of head height", DIM, f_head)]
        lines += [
                 (f"base {pr['base_width']:.2f} studs", DIM, f_head),
                 (f"  = {pr['base_width_to_head']:.0%} of head width", DIM, f_head),
                 (f"head {pr['head_size'][0]:.2f} w x {pr['head_size'][2]:.2f} h", DIM, f_head),
                 (f"{info['tris_total']} tris a pair", DIM, f_head),
                 (f"approved fox bar: 64% h, 40% w", DIM, f_head)]
        seat = info.get("seat", {})
        if seat:
            lines.append((f"base sunk {-max(g['base_shallowest'] for g in seat.values()):.3f}"
                          f"-{-min(g['base_deepest'] for g in seat.values()):.3f} along normal", DIM, f_head))
            lines.append((f"verts off the head: {sum(g['verts_outside_head_below_top'] for g in seat.values())}",
                          DIM, f_head))
        for i, (txt, col, fnt) in enumerate(lines):
            d.text((12, y + 12 + i * 24 + (6 if i else 0)), txt, fill=col, font=fnt)
        for c, (view, _) in enumerate(EAR_COLUMNS):
            x = LABEL_W + c * (t + PAD)
            path = HERE / "renders" / f"{name}_{view}.png"
            if path.exists():
                sheet.paste(Image.open(path).convert("RGB").resize((t, t)), (x, y))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "ears":
        ear_sheet(Path(sys.argv[2]) if len(sys.argv) > 2 else HERE / "sheets" / "wolf_ears.png", sys.argv[3:])
    else:
        main()
