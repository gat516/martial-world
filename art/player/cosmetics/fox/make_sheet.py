"""Stitch build_fox.py's render tiles (renders/<Tail>_<view>.png) into one labelled sheet.

Run from the repo root after build_fox.py has rendered:
  uv run --with pillow python3 -I art/player/cosmetics/fox/make_sheet.py [OUT.png]
  uv run --with pillow python3 -I art/player/cosmetics/fox/make_sheet.py ears [OUT.png] [Set ...]
  uv run --with pillow python3 -I art/player/cosmetics/fox/make_sheet.py seat [OUT.png]   (after seat_sheet.py)
Tails: one row per tail (worn with the approved cute ears), with its size against the torso,
the running check and the approved ears beside it.
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
           ("threequarter", "rear three-quarter"), ("bent", "bent (per-joint check)"),
           ("run_a", "running, side"), ("run_b", "running, other phase"),
           ("game", "game cam 12 studs"), ("seat", "seat: where it leaves the back"),
           ("close", "close-up, bent (sealed?)")]
ROWS = [
    ("FoxTailPlume", "plump curled ball"),
    ("FoxTailCrescent", "round S-plume"),
    ("FoxTailWisp", "long full brush (bold)"),
]
APPROVED = HERE.parents[3] / "docs" / "reference" / "approved" / "modeling" / "fox_ears_cute.png"
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
    ref = Image.open(APPROVED).convert("RGB") if APPROVED.exists() else None
    if ref:   # the approved cute ears under the rows, the look these tails match
        ref = ref.resize((width, round(ref.size[1] * width / ref.size[0])))
    sheet = Image.new("RGB", (width, HEAD_H + len(ROWS) * (tile + PAD) + (ref.size[1] + HEAD_H if ref else 0)), BG)
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
    if ref:
        y = HEAD_H + len(ROWS) * (tile + PAD)
        d.text((12, y + 8), "approved: the cute fox ears (docs/reference/approved/modeling/fox_ears_cute.png)",
               fill=(210, 214, 222), font=f_head)
        sheet.paste(ref, (0, y + HEAD_H))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(OUT)


EAR_COLUMNS = [("front", "front"), ("side", "side (left)"), ("back", "back"), ("fold", "fold back 60"),
               ("flick", "flick out 35"), ("seat_side", "seat: side, close"), ("seat_back", "seat: back, close"),
               ("seat_front", "seat: front, close"), ("game_back", "game cam 12 studs, back"),
               ("game_front", "game cam 12 studs, front"), ("old:seat_front", "before | after: tufts"),
               ("old:game_back", "before | after: game cam back"), ("old:front", "before | after: front")]
EAR_ROWS = [("FoxEarsBroad", "approved: round dome"), ("FoxEarsSleek", "soft point, notch"),
            ("FoxEarsLong", "top flops down and out")]
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
        old_json = HERE / "renders" / f"old_{name}.json"   # the committed set before this pass
        was = json.loads(old_json.read_text())["proportions"] if old_json.exists() else None
        lines = [(name, FG, f_row), (f"mood: {info['mood']}", DIM, f_head), (note, DIM, f_head),
                 (f"height {pr['visible_height']:.2f} studs", DIM, f_head),
                 (f"  = {pr['height_to_head']:.0%} of head height", DIM, f_head)]
        if was:
            lines.append((f"  was {was['visible_height']:.2f} = {was['height_to_head']:.0%}", DIM, f_head))
        lines += [
                 (f"base {pr['base_width']:.2f} studs", DIM, f_head),
                 (f"  = {pr['base_width_to_head']:.0%} of head width", DIM, f_head),
                 (f"head {pr['head_size'][0]:.2f} w x {pr['head_size'][2]:.2f} h", DIM, f_head),
                 (f"{info['tris_total']} tris a pair", DIM, f_head)]
        for i, (txt, col, fnt) in enumerate(lines):
            d.text((12, y + 12 + i * 24 + (6 if i else 0)), txt, fill=col, font=fnt)
        for c, (view, _) in enumerate(EAR_COLUMNS):
            x = LABEL_W + c * (t + PAD)
            if view.startswith("old:"):
                old = HERE / "renders" / f"old_{name}_{view[4:]}.png"
                new = HERE / "renders" / f"{name}_{view[4:]}.png"
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


SEAT_COLUMNS = [("out_side", "left ear, outer side"), ("out_back", "left ear, back-outer"), ("back", "left ear, back"),
                ("out_front", "left ear, front-outer"), ("front", "left ear, front"), ("right_out", "right ear, outer side")]


def seat_sheet(out):
    """Ear seating close-ups (seat_sheet.py): one row per ear set, eye level just above the head,
    with the measured seat numbers from <Set>.json, and the lineup at game distance below."""
    t = 300
    lineup = [HERE / "renders" / f"seat_lineup_{v}.png" for v in ("back", "front")]
    lineup = [Image.open(p).convert("RGB") for p in lineup if p.exists()]
    lw = lh = 2 * t if lineup else 0
    sheet = Image.new("RGB", (LABEL_W + len(SEAT_COLUMNS) * (t + PAD), HEAD_H + len(EAR_ROWS) * (t + PAD) + lh), BG)
    d = ImageDraw.Draw(sheet)
    f_head, f_row = font(13), font(19)
    for c, (_, label) in enumerate(SEAT_COLUMNS):
        d.text((LABEL_W + c * (t + PAD) + 6, 10), label, fill=(210, 214, 222), font=f_head)
    for r, (name, note) in enumerate(EAR_ROWS):
        y = HEAD_H + r * (t + PAD)
        info = json.loads((HERE / f"{name}.json").read_text())
        seat = info.get("seat", {})
        outer = [v for k, v in seat.items() if not k.endswith("Inner")]
        inner = [v for k, v in seat.items() if k.endswith("Inner")]
        lines = [(name, FG, f_row), (note, DIM, f_head), ("base under the head surface,", DIM, f_head),
                 ("along its normal (studs):", DIM, f_head)]
        for label, group in (("shell", outer), ("inner", inner)):
            if group:
                lines.append((f"  {label}: {-max(g['base_shallowest'] for g in group):.3f}"
                              f" to {-min(g['base_deepest'] for g in group):.3f} deep", DIM, f_head))
        hang = sum(g["verts_outside_head_below_top"] for g in seat.values())
        lines.append((f"verts hanging off the head: {hang}", DIM, f_head))
        pr = info["proportions"]
        lines.append((f"height {pr['height_to_head']:.0%} of head, base {pr['base_width_to_head']:.0%}", DIM, f_head))
        for i, (txt, col, fnt) in enumerate(lines):
            d.text((12, y + 12 + i * 24 + (6 if i else 0)), txt, fill=col, font=fnt)
        for c, (view, _) in enumerate(SEAT_COLUMNS):
            p = HERE / "renders" / f"seat_{name}_{view}.png"
            if p.exists():
                sheet.paste(Image.open(p).convert("RGB").resize((t, t)), (LABEL_W + c * (t + PAD), y))
    y = HEAD_H + len(EAR_ROWS) * (t + PAD)
    for i, (im, txt) in enumerate(zip(lineup, ("lineup from behind (Long, Sleek, Broad)",
                                               "lineup from the front (Broad, Sleek, Long)"))):
        sheet.paste(im.resize((lw, lh)), (LABEL_W + i * (lw + PAD), y))
        d.text((LABEL_W + i * (lw + PAD) + 8, y + 8), txt, fill=FG, font=f_head)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "seat":
        seat_sheet(Path(sys.argv[2]) if len(sys.argv) > 2 else HERE / "sheets" / "fox_ears_seat.png")
    elif len(sys.argv) > 1 and sys.argv[1] == "ears":
        ear_sheet(Path(sys.argv[2]) if len(sys.argv) > 2 else HERE / "sheets" / "fox_ears.png", sys.argv[3:])
    else:
        main()
