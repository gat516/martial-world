"""Cuts generated UI art (Codex) into game-ready pieces. Never repaints anything.

Reads art/ui/codex/<name>.png (names in PIECES and ICON_SHEETS below, the same
list as the Codex brief), and for each one:
  1. keys out the background (real alpha, or flat magenta #FF00FF),
  2. trims to the piece and checks it: nothing may touch the canvas edge (a
     clipped cloud), no stray islands away from the piece (bleed from a
     neighbour), proportions close to the brief's,
  3. downscales to 2x its display size (never upscales), and if it is still
     wider than Roblox's 1024 px cap, cuts it into side-by-side tiles,
  4. icon sheets are split on a 4 x 3 grid into one 256 px icon each,
  5. ornament sheets (PIECE_SHEETS) are keyed by hue (generators paint noisy
     magenta), split into pieces by shape, named in reading order, and cut at
     full resolution (at most 1024 px, Roblox's cap) as ornament_<name>.png.

Writes art/ui/codex/cut/*.png, art/ui/codex/manifest.json (files, sizes,
tiles, display size, flags) for the ui-designer, and
art/ui/codex/contact_sheet.png: each source beside its cut on a checker, with
its flags, for the user to approve before anything is uploaded.

Run: uv run --with pillow --with numpy python tools/ui_assemble.py [names...]
Exits 1 if any piece has an error (edge, stray island, opaque background).
"""

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "ui" / "codex"
OUT = SRC / "cut"
MAX_TEX = 1024  # Roblox shrinks anything past this on its long side
ALPHA_CUT = 16  # alpha below this counts as empty when trimming and checking
EDGE_MARGIN = 2  # px; content this close to the canvas edge is "touching"
ASPECT_TOLERANCE = 0.15

# name: (display width at the 1920 x 1080 baseline, width : height ratio)
PIECES = {
    "dialogue_panel_desktop": (1000, 4),
    "dialogue_panel_phone": (560, 3),
    "nametab_S": (160, 4),
    "nametab_M": (240, 6),
    "nametab_L": (320, 8),
    "nametab_gold_M": (240, 6),
    "nametab_gold_L": (320, 8),
    "nametab_crimson_M": (240, 6),
    "nametab_crimson_L": (320, 8),
    "chevron": (28, 1),
    "chevron_glow": (28, 1),
    "portrait_frame_small": (110, 1),
    "portrait_medallion": (96, 1),
    "response_S": (360, 6),
    "response_M": (540, 9),
    "response_L": (780, 13),
    "response_hi_S": (360, 6),
    "response_hi_M": (540, 9),
    "response_hi_L": (780, 13),
    "keyplate": (88, 1),
    "keyplate_ring": (88, 1),
    "prompt_banner_S": (220, 4),
    "prompt_banner_M": (330, 6),
    "prompt_banner_L": (480, 9),
    "portrait_elder_qingyun": (256, 1),
    "portrait_herbalist": (256, 1),
    "portrait_rack_keeper": (256, 1),
    "portrait_silhouette": (256, 1),
    "portrait_unknown": (256, 1),
}

ICON_SIZE = 256
ICON_GRID = (4, 3)  # columns, rows; left to right, top to bottom
ICON_SHEETS = {
    "icons_dialogue": [
        "talk", "bag", "leave", "quest", "purse", "bow",
        "sword", "heart", "lock", "question", "exclaim", "give",
    ],
    "icons_interact": [
        "talk_prompt", "harvest", "rush", "plant", "open", "pray",
        "tap", "pad_a", "pad_x", "pad_y", "hold", "search",
    ],
}

# Ornament sheets: many isolated pieces on one magenta sheet, found by shape
# (islands of art), named in reading order (rows top to bottom, then left to
# right). Cut at full resolution; the pieces are small enough already.
PIECE_SHEETS = {
    "ornaments_filled_source": [
        "name_scroll", "double_cloud", "single_cloud", "cloud_wisp",
        "panel_corner", "portrait_corner",
        "scroll_stud", "ruby_stud", "gold_stud",
        "keyplate", "chevron",
    ],
    "sheet_a1": [
        "plaque_end", "plaque_end_small",
        "divider_diamond", "divider_cloud", "divider_vertical",
        "inkwash_a", "inkwash_b",
        "seal_square", "seal_round",
    ],
    "a1/plaque_end_large": ["plaque_end_large"],
    # Codex's one-piece redraws of A1; listed after sheet_a1 so they win.
    "a1/plaque_end_small": ["plaque_end_small"],
    "a1/divider_diamond": ["divider_diamond"],
    "a1/divider_cloud_ends": ["divider_cloud"],
    "a1/divider_vertical": ["divider_vertical"],
    "a1/ink_cloud": ["inkwash_a"],
    "a1/ink_cloud_wide": ["inkwash_b"],
    "a1/seal_square": ["seal_square"],
    "a1/seal_round": ["seal_round"],
    "a2/response_button_normal": ["response_button"],
    "a2/response_button_highlight": ["response_button_hi"],
    "a2/interaction_prompt_banner": ["prompt_banner"],
    "a2/hold_ring_track": ["hold_ring"],
}
SHEET_GROUP_GAP = 16  # px; parts of one piece closer than this belong together
SHEET_MIN_AREA = 400  # px; smaller islands are generator noise


def key_sheet(im):
    """Alpha-keyed RGBA array for a sheet on noisy, near-magenta ground.

    Generators paint the "flat" magenta with drift and dark flecks, so the key
    is by hue, not by one colour: anything whose red and blue both rise far
    above green, at any brightness, is background. Gold, ruby, cream and navy
    all have green at or above one of red and blue.
    """
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    ratio = (np.minimum(r, b) - g) / np.maximum(np.maximum(r, b), 1)
    alpha = 1 - np.clip((ratio - 0.35) / 0.45, 0, 1)
    border = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.clip((a - (1 - alpha)[..., None] * bg) / safe, 0, 255)
    # Despill: the generator tints outlines and shading toward magenta (dark
    # outlines come out (119, 11, 49), not brown). Art never has both red and
    # blue above green except as spill, so take that excess off both.
    spill = np.clip(np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1], 0, None)
    rgb[..., 0] -= spill
    rgb[..., 2] -= spill
    # Pink highlights on gold (blue at or above green): gold always has blue
    # well below green. Rubies have dim green and are left alone.
    pink = (rgb[..., 2] >= rgb[..., 1]) & (rgb[..., 1] > 80) & (rgb[..., 0] > rgb[..., 1])
    rgb[..., 2] = np.where(pink, rgb[..., 1] * 0.6, rgb[..., 2])
    return np.dstack([rgb, alpha * 255])


def sheet_pieces(arr):
    """Boxes of the pieces on a keyed sheet, in reading order, plus the noise-free alpha."""
    from PIL import ImageFilter
    alpha = arr[..., 3]
    core = Image.fromarray(((alpha > 128) * 255).astype(np.uint8))
    step = 4
    small = core.resize((core.width // step, core.height // step), Image.BOX)
    grown = small.filter(ImageFilter.MaxFilter(2 * (SHEET_GROUP_GAP // step) + 1))
    groups = components(np.asarray(grown) > 0)
    boxes, keep = [], np.zeros(alpha.shape, bool)
    for _, (x1, y1, x2, y2) in groups:
        X1, Y1, X2, Y2 = x1 * step, y1 * step, min(x2 * step, alpha.shape[1]), min(y2 * step, alpha.shape[0])
        region = alpha[Y1:Y2, X1:X2] > 128
        if region.sum() < SHEET_MIN_AREA:
            continue
        keep[Y1:Y2, X1:X2] |= True
        ys, xs = np.nonzero(alpha[Y1:Y2, X1:X2] >= ALPHA_CUT)
        boxes.append((X1 + xs.min(), Y1 + ys.min(), X1 + xs.max() + 1, Y1 + ys.max() + 1))
    clean = np.where(keep, alpha, 0)
    # Reading order: a box starts a new row when its top is below the current
    # row's middle.
    boxes.sort(key=lambda bx: bx[1])
    rows, row_bottom = [], None
    for bx in boxes:
        if row_bottom is None or bx[1] > row_bottom:
            rows.append([bx])
            row_bottom = (bx[1] + bx[3]) / 2
        else:
            rows[-1].append(bx)
            row_bottom = max(row_bottom, (bx[1] + bx[3]) / 2)
    return [bx for row in rows for bx in sorted(row, key=lambda bx: bx[0])], clean


def cut_piece_sheet(sheet, src):
    """Cut every piece of an ornament sheet. Returns contact rows and manifest entries."""
    names = PIECE_SHEETS[sheet]
    arr = key_sheet(src)
    boxes, clean = sheet_pieces(arr)
    arr[..., 3] = clean
    h, w = clean.shape
    if len(boxes) != len(names):
        return [(sheet, src, None, [f"found {len(boxes)} pieces, the list names {len(names)}"], [], f"{w} x {h}")], {}
    rows, entries = [], {}
    for name, (x1, y1, x2, y2) in zip(names, boxes):
        errs = []
        if x1 < EDGE_MARGIN or y1 < EDGE_MARGIN or x2 > w - EDGE_MARGIN or y2 > h - EDGE_MARGIN:
            errs.append("touches the sheet edge (clipped?)")
        pad = 2
        box = (max(0, x1 - pad), max(0, y1 - pad), min(w, x2 + pad), min(h, y2 + pad))
        full = arr[box[1]:box[3], box[0]:box[2]]
        piece = fit(to_image(full), MAX_TEX, MAX_TEX)
        f = f"ornament_{name}.png"
        piece.save(OUT / f)
        entries[f"ornament_{name}"] = {"sheet": sheet, "size": [piece.width, piece.height], "source_box": list(map(int, box)),
                                       "tiles": [{"file": f, "x": 0, "width": piece.width, "height": piece.height}], "flags": errs}
        if name in SLICE3:
            entries[f"ornament_{name}"]["slice3"] = slice3(name, full, errs)
        rows.append((f"{sheet}: {name}", src.crop(box), piece, errs, [], f"{piece.width} x {piece.height}"))
    return rows, entries


# Pieces with ornate ends and a plain middle (buttons, banners): also cut as left cap,
# a narrow middle strip to stretch, and right cap, from the full-resolution art.
SLICE3 = {"response_button", "response_button_hi", "prompt_banner"}
SLICE3_TOL = (3, 6)  # smoothed alpha and brightness differences that still count as "plain"


def slice3(name, full, errs):
    """Split a horizontal piece at the plain middle. Returns the caps' widths and files.

    Generated middles carry painted texture and glow, so columns are compared by
    shape (alpha) and brightness, each smoothed over 15 px along the length.
    """
    h, w = full.shape[:2]
    kernel = np.ones(15) / 15
    smooth = lambda a: np.array([np.convolve(row, kernel, mode="same") for row in a])
    alpha = smooth(full[..., 3])
    lum = smooth(full[..., :3].mean(-1) * full[..., 3] / 255)
    c = w // 2
    plain = (np.abs(alpha - alpha[:, [c]]).mean(0) < SLICE3_TOL[0]) & (np.abs(lum - lum[:, [c]]).mean(0) < SLICE3_TOL[1])
    left = c
    while left > 0 and plain[left - 1]:
        left -= 1
    right = c
    while right < w - 1 and plain[right + 1]:
        right += 1
    if right - left < w * 0.2:
        errs.append("no plain middle wide enough to stretch")
    strip = max(8, min(32, (right - left) // 4))
    parts = {
        "capL": full[:, : left + 2],
        "mid": full[:, w // 2 - strip // 2 : w // 2 + strip // 2],
        "capR": full[:, right - 1 :],
    }
    out = {}
    for part, a in parts.items():
        im = fit(to_image(a), MAX_TEX, MAX_TEX)
        f = f"ornament_{name}_{part}.png"
        im.save(OUT / f)
        out[part] = {"file": f, "size": [im.width, im.height]}
    return out


def key(im):
    """RGBA float array with the background removed, and an error or None."""
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    h, w = a.shape[:2]
    corners = np.array([a[0, 0], a[0, w - 1], a[h - 1, 0], a[h - 1, w - 1]])
    if (corners[:, 3] < 128).all():
        return a, None
    r, g, b = corners[:, 0], corners[:, 1], corners[:, 2]
    if not ((r > 200) & (b > 200) & (g < 80)).all():
        return a, "opaque background (not transparent or magenta)"
    # Magenta strength: how far min(R, B) rises above G. Gold, navy and cream
    # all have G above min(R, B), so they stay opaque; edges blend smoothly.
    m = np.minimum(a[..., 0], a[..., 2]) - a[..., 1]
    t0 = 40.0
    k = np.clip((m - t0) / (255.0 - t0), 0, 1)
    alpha = 1 - k
    # Undo the magenta blended into edge pixels: c = alpha*fg + (1-alpha)*M.
    safe = np.maximum(alpha, 1e-3)[..., None]
    mag = np.array([255.0, 0.0, 255.0])
    rgb = np.clip((a[..., :3] - (1 - alpha)[..., None] * mag) / safe, 0, 255)
    out = np.dstack([rgb, alpha * 255])
    return out, None


def bbox(alpha):
    ys, xs = np.nonzero(alpha >= ALPHA_CUT)
    if len(xs) == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def components(mask):
    """Connected components of a small boolean mask: list of (area, bbox)."""
    h, w = mask.shape
    seen = np.zeros_like(mask)
    found = []
    for y0, x0 in zip(*np.nonzero(mask)):
        if seen[y0, x0]:
            continue
        stack = [(y0, x0)]
        seen[y0, x0] = True
        area, x1, y1, x2, y2 = 0, x0, y0, x0, y0
        while stack:
            y, x = stack.pop()
            area += 1
            x1, y1, x2, y2 = min(x1, x), min(y1, y), max(x2, x), max(y2, y)
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        found.append((area, (x1, y1, x2 + 1, y2 + 1)))
    return found


def strays(alpha):
    """Islands well away from the main piece (neighbour bleed), as boxes."""
    step = 4
    small = alpha[::step, ::step] >= 64
    comps = components(small)
    if len(comps) < 2:
        return []
    comps.sort(key=lambda c: -c[0])
    main_area, (mx1, my1, mx2, my2) = comps[0]
    gap = max(3, int(0.03 * max(small.shape)))
    out = []
    for area, (x1, y1, x2, y2) in comps[1:]:
        near = x2 >= mx1 - gap and x1 <= mx2 + gap and y2 >= my1 - gap and y1 <= my2 + gap
        if not near and area >= 2:
            out.append((x1 * step, y1 * step, x2 * step, y2 * step))
    return out


def check(alpha, region):
    """Errors for one piece occupying `region` (x1, y1, x2, y2) of `alpha`."""
    x1, y1, x2, y2 = region
    sub = alpha[y1:y2, x1:x2]
    box = bbox(sub)
    if box is None:
        return None, ["empty"]
    errs = []
    bx1, by1, bx2, by2 = box
    h, w = sub.shape
    if bx1 < EDGE_MARGIN or by1 < EDGE_MARGIN or bx2 > w - EDGE_MARGIN or by2 > h - EDGE_MARGIN:
        errs.append("touches the edge (clipped?)")
    for s in strays(sub):
        errs.append(f"stray island at {s[0] + x1},{s[1] + y1}")
    return (bx1 + x1, by1 + y1, bx2 + x1, by2 + y1), errs


def to_image(arr):
    return Image.fromarray(np.round(arr).astype(np.uint8), "RGBA")


def fit(im, w, h):
    """Downscale `im` to at most w x h, keeping proportions. Never upscales."""
    s = min(w / im.width, h / im.height, 1.0)
    if s >= 1.0:
        return im
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)


def cut_piece(name, arr, display_w, ratio):
    box, errs = check(arr[..., 3], (0, 0, arr.shape[1], arr.shape[0]))
    if box is None:
        return None, errs, []
    warns = []
    piece = to_image(arr[box[1]:box[3], box[0]:box[2]])
    aspect = piece.width / piece.height
    if abs(aspect - ratio) / ratio > ASPECT_TOLERANCE:
        warns.append(f"proportion {aspect:.2f} : 1, brief asks {ratio} : 1")
    target_w = math.ceil(display_w * 2)
    if piece.width < display_w * 1.25:
        warns.append(f"{piece.width} px wide, under 1.25x display ({display_w}); blurs when scaled up")
    piece = fit(piece, target_w, piece.height)
    n = math.ceil(piece.width / MAX_TEX)
    if piece.height > MAX_TEX:
        piece = fit(piece, piece.width, MAX_TEX)
    tiles = []
    if n == 1:
        f = f"{name}.png"
        piece.save(OUT / f)
        tiles.append({"file": f, "x": 0, "width": piece.width, "height": piece.height})
    else:
        edges = [round(i * piece.width / n) for i in range(n + 1)]
        for i in range(n):
            f = f"{name}_{i + 1}.png"
            piece.crop((edges[i], 0, edges[i + 1], piece.height)).save(OUT / f)
            tiles.append({"file": f, "x": edges[i], "width": edges[i + 1] - edges[i], "height": piece.height})
    entry = {
        "size": [piece.width, piece.height],
        "display": [display_w, round(display_w / ratio)],
        "tiles": tiles,
    }
    return entry, errs, warns


def cut_sheet(sheet, arr, names):
    cols, rows = ICON_GRID
    h, w = arr.shape[:2]
    results = []
    for i, name in enumerate(names):
        c, r = i % cols, i // cols
        region = (round(c * w / cols), round(r * h / rows), round((c + 1) * w / cols), round((r + 1) * h / rows))
        box, errs = check(arr[..., 3], region)
        if box is None:
            results.append((name, None, errs))
            continue
        glyph = to_image(arr[box[1]:box[3], box[0]:box[2]])
        side = max(glyph.width, glyph.height)
        square = Image.new("RGBA", (side, side), (255, 255, 255, 0))
        square.paste(glyph, ((side - glyph.width) // 2, (side - glyph.height) // 2))
        square = fit(square, ICON_SIZE, ICON_SIZE)
        f = f"icon_{name}.png"
        square.save(OUT / f)
        results.append((name, {"sheet": sheet, "size": [square.width] * 2, "tiles": [{"file": f, "x": 0, "width": square.width, "height": square.height}]}, errs))
    return results


# Contact sheet ----------------------------------------------------------------

ROW_H = 200
COL_W = 520
PAD = 16


def font(size):
    try:
        return ImageFont.load_default(size)
    except TypeError:
        return ImageFont.load_default()


def checker(w, h, cell=12):
    bg = Image.new("RGB", (w, h), (70, 74, 84))
    d = ImageDraw.Draw(bg)
    for y in range(0, h, cell):
        for x in range((y // cell % 2) * cell, w, cell * 2):
            d.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(96, 100, 112))
    return bg


def thumb(im, w, h):
    t = im.copy()
    t.thumbnail((w, h), Image.LANCZOS)
    tile = checker(w, h)
    tile.paste(t, ((w - t.width) // 2, (h - t.height) // 2), t if t.mode == "RGBA" else None)
    return tile


def contact_sheet(rows, missing):
    big, small = font(18), font(14)
    width = PAD * 4 + COL_W * 2 + 360
    lines = [", ".join(missing[i:i + 8]) for i in range(0, len(missing), 8)]
    top = PAD + 28 + 18 * len(lines) + 12
    height = top + len(rows) * (ROW_H + PAD) + PAD
    sheet = Image.new("RGB", (width, height), (25, 33, 41))
    d = ImageDraw.Draw(sheet)
    head = "Left: source as generated.  Middle: the cut, as the game gets it.  Red: must fix.  Amber: check."
    d.text((PAD, PAD), head, fill=(250, 236, 195), font=big)
    for i, line in enumerate(lines):
        d.text((PAD, PAD + 28 + 18 * i), ("Missing: " if i == 0 else "") + line, fill=(211, 164, 88), font=small)
    y = top
    for name, src, cut, errs, warns, info in rows:
        sheet.paste(thumb(src, COL_W, ROW_H), (PAD, y))
        if cut is not None:
            sheet.paste(thumb(cut, COL_W, ROW_H), (PAD * 2 + COL_W, y))
        tx = PAD * 3 + COL_W * 2
        d.text((tx, y), name, fill=(250, 236, 195), font=big)
        ly = y + 26
        d.text((tx, ly), info, fill=(180, 180, 180), font=small)
        for msg, col in [(e, (235, 90, 80)) for e in errs] + [(w, (230, 170, 60)) for w in warns]:
            ly += 18
            d.text((tx, ly), msg, fill=col, font=small)
        if not errs and not warns:
            d.text((tx, ly + 18), "ok", fill=(120, 200, 120), font=small)
        y += ROW_H + PAD
    sheet.save(SRC / "contact_sheet.png")


def stitched(entry):
    tiles = [Image.open(OUT / t["file"]) for t in entry["tiles"]]
    if len(tiles) == 1:
        return tiles[0]
    w = sum(t.width for t in tiles)
    im = Image.new("RGBA", (w, tiles[0].height), (0, 0, 0, 0))
    for t, info in zip(tiles, entry["tiles"]):
        im.paste(t, (info["x"], 0))
    return im


def main():
    only = set(sys.argv[1:])
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = SRC / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    rows, missing = [], []
    failed = False
    # One-piece images Codex drops into a sheet folder (art/ui/codex/a2/<piece>.png) are
    # cut without a PIECE_SHEETS entry, named after the file.
    for p in sorted(SRC.glob("*/*.png")):
        key_name = f"{p.parent.name}/{p.stem}"
        if p.parent.name != "cut" and key_name not in PIECE_SHEETS:
            PIECE_SHEETS[key_name] = [p.stem]
    for name in list(PIECES) + list(ICON_SHEETS) + list(PIECE_SHEETS):
        if only and name not in only:
            continue
        path = SRC / f"{name}.png"
        if not path.exists():
            missing.append(name)
            continue
        src = Image.open(path).convert("RGBA")
        if name in PIECE_SHEETS:
            sheet_rows, entries = cut_piece_sheet(name, src)
            manifest.update(entries)
            rows.extend(sheet_rows)
            failed = failed or any(r[3] for r in sheet_rows)
            continue
        arr, bg_err = key(src)
        if bg_err:
            rows.append((name, src, None, [bg_err], [], f"{src.width} x {src.height}"))
            failed = True
            continue
        if name in ICON_SHEETS:
            results = cut_sheet(name, arr, ICON_SHEETS[name])
            errs = [f"{n}: {e}" for n, _, es in results for e in es]
            ok = [(n, e) for n, e, _ in results if e]
            for n, e in ok:
                manifest[f"icon_{n}"] = e
            strip = Image.new("RGBA", (ICON_SIZE * len(ok) or 1, ICON_SIZE), (0, 0, 0, 0))
            for i, (n, e) in enumerate(ok):
                strip.paste(Image.open(OUT / e["tiles"][0]["file"]), (i * ICON_SIZE, 0))
            rows.append((name, src, strip, errs, [], f"{len(ok)} of {len(results)} icons"))
        else:
            display_w, ratio = PIECES[name]
            entry, errs, warns = cut_piece(name, arr, display_w, ratio)
            if entry:
                entry["flags"] = errs + warns
                manifest[name] = entry
            cut = stitched(entry) if entry else None
            info = f"{src.width} x {src.height} -> " + (
                f"{entry['size'][0]} x {entry['size'][1]}, {len(entry['tiles'])} tile(s)" if entry else "nothing")
            rows.append((name, src, cut, errs, warns, info))
        failed = failed or bool(rows[-1][3])
    (SRC / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if rows:
        contact_sheet(rows, missing)
    for name, _, _, errs, warns, info in rows:
        print(f"{'FAIL' if errs else 'ok  '} {name}: {info}")
        for m in errs + warns:
            print(f"     {m}")
    if missing:
        print(f"missing ({len(missing)}): {', '.join(missing)}")
    print(f"contact sheet: {SRC / 'contact_sheet.png'}" if rows else "nothing to cut")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
