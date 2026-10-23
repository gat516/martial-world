"""Silhouette fidelity: how closely a built model's outline matches its reference image.

Extracts both silhouettes, aligns them by bounding box, and scores the overlap (IoU,
intersection over union: 1.0 = identical outlines, 0 = no overlap) overall, per height band
(top / middle / bottom thirds: head, body, legs on an upright body) and per length band
(front / middle / back thirds along the image's width: head, body, tail on a side-on beast).
Writes one composite PNG for a critic to read: reference | capture | overlay, where grey is
shared, blue is in the reference but missing from the build, and red is extra in the build.
Docs: docs/enemies/modeling-checks.md.

Silhouettes:
  - an image with real transparency: alpha > 50%
  - otherwise the background is the border's colour, flood-filled inward with a tolerance
    (works for tools/model_shot.luau captures on its grey set, flat-backdrop concept art and
    art/tools/silhouette_render.py's white-on-black renders); enclosed holes count as body.
  Specks under 0.2% of the larger component are dropped; --largest keeps one component only.

Alignment (--fit): `height` (default) scales the capture uniformly so the heights match, then
lines up the bottoms (the ground) and the horizontal centres, so a body that is too long or too
short shows up as red or blue at the ends; `box` stretches it to the reference's box (shape only,
proportions ignored). The reference may face the other way: both mirrorings are tried and the
better one is kept unless --no-flip.

Run (from the repo root):
  uv run --with pillow --with numpy python3 -I tools/fidelity_check.py REF CAPTURE [--out PNG]
      [--fit height|box] [--tol 28] [--largest] [--no-flip] [--json]
Prints the scores and the composite's path (default: CAPTURE's name + _fidelity.png beside it).
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SIZE = 480          # silhouettes are compared at this bounding-box height, in pixels
PAD = 24
SPECK = 0.002       # components smaller than this share of the biggest are dropped
SHARED = (150, 150, 150)
MISSING = (60, 120, 235)    # in the reference, not in the build
EXTRA = (225, 60, 50)       # in the build, not in the reference
BG = (32, 32, 36)


def load(path):
    im = Image.open(path)
    im.load()
    return im


def flood_from_border(similar):
    """Pixels of `similar` connected to the image border (4-connected), by scanline fill."""
    h, w = similar.shape
    seen = np.zeros_like(similar)
    stack = [(y, x) for x in range(w) for y in (0, h - 1) if similar[y, x]]
    stack += [(y, x) for y in range(h) for x in (0, w - 1) if similar[y, x]]
    while stack:
        y, x = stack.pop()
        if seen[y, x] or not similar[y, x]:
            continue
        x0 = x
        while x0 > 0 and similar[y, x0 - 1] and not seen[y, x0 - 1]:
            x0 -= 1
        x1 = x
        while x1 < w - 1 and similar[y, x1 + 1] and not seen[y, x1 + 1]:
            x1 += 1
        seen[y, x0:x1 + 1] = True
        for ny in (y - 1, y + 1):
            if 0 <= ny < h:
                row = similar[ny, x0:x1 + 1] & ~seen[ny, x0:x1 + 1]
                if row.any():
                    # one seed per run of fillable pixels in the neighbouring row
                    idx = np.flatnonzero(row)
                    starts = idx[np.r_[True, np.diff(idx) > 1]]
                    stack.extend((ny, x0 + int(i)) for i in starts)
    return seen


def components(mask):
    """Label 4-connected components; returns (labels, sizes) with label 0 = background."""
    h, w = mask.shape
    labels = np.zeros((h, w), np.int32)
    sizes = [0]
    for y0, x0 in zip(*np.nonzero(mask)):
        if labels[y0, x0]:
            continue
        n = len(sizes)
        count = 0
        stack = [(y0, x0)]
        labels[y0, x0] = n
        while stack:
            y, x = stack.pop()
            count += 1
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = n
                    stack.append((ny, nx))
        sizes.append(count)
    return labels, np.array(sizes)


def silhouette(im, tol, largest):
    """Boolean foreground mask and a note on how it was found."""
    rgba = np.asarray(im.convert("RGBA")).astype(np.int16)
    alpha = rgba[..., 3]
    if (alpha < 250).mean() > 0.05:
        mask, how = alpha > 127, "alpha"
    else:
        rgb = rgba[..., :3]
        border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
        key = np.median(border, axis=0)
        dist = np.abs(rgb - key).max(axis=2)
        bg = flood_from_border(dist <= tol)
        mask = ~bg
        how = "border key rgb(%d,%d,%d) tol %d" % (*key, tol)
    # small images label fast enough; big ones are labelled at half size
    small = mask
    step = 1
    while small.size > 700_000:
        step *= 2
        small = mask[::step, ::step]
    labels, sizes = components(small)
    if len(sizes) > 1:
        sizes[0] = 0
        keep = np.zeros(len(sizes), bool)
        if largest:
            keep[sizes.argmax()] = True
        else:
            keep = sizes >= sizes.max() * SPECK
            keep[0] = False
        kept = keep[labels]
        if step > 1:
            kept = np.repeat(np.repeat(kept, step, 0), step, 1)[: mask.shape[0], : mask.shape[1]]
        mask &= kept
    if not mask.any():
        sys.exit("fidelity_check: no silhouette found in the image (try --tol)")
    return mask, how


def bbox(mask):
    ys, xs = np.nonzero(mask)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def resize_mask(mask, w, h):
    im = Image.fromarray(mask.astype(np.uint8) * 255).resize((max(1, w), max(1, h)), Image.BILINEAR)
    return np.asarray(im) > 127


def align(ref_m, cap_m, fit):
    """Both silhouettes on one canvas: the reference's box scaled to SIZE high."""
    rx0, ry0, rx1, ry1 = bbox(ref_m)
    cx0, cy0, cx1, cy1 = bbox(cap_m)
    rw, rh = rx1 - rx0, ry1 - ry0
    cw, ch = cx1 - cx0, cy1 - cy0
    s = SIZE / rh
    rW, rH = round(rw * s), SIZE
    if fit == "box":
        cW, cH = rW, rH
    else:
        k = SIZE / ch
        cW, cH = round(cw * k), SIZE
    W = max(rW, cW) + 2 * PAD
    H = SIZE + 2 * PAD
    ref = np.zeros((H, W), bool)
    cap = np.zeros((H, W), bool)
    r = resize_mask(ref_m[ry0:ry1, rx0:rx1], rW, rH)
    c = resize_mask(cap_m[cy0:cy1, cx0:cx1], cW, cH)
    ox = (W - rW) // 2
    ref[PAD:PAD + rH, ox:ox + rW] = r
    ox2 = (W - cW) // 2
    cap[PAD + SIZE - cH:PAD + SIZE, ox2:ox2 + cW] = c
    return ref, cap, (ox, ox + rW)


def iou(a, b):
    u = (a | b).sum()
    return float((a & b).sum() / u) if u else 1.0


def score(ref, cap, xspan):
    bands = {}
    third = SIZE / 3
    for i, name in enumerate(("top", "middle", "bottom")):
        y0, y1 = PAD + round(i * third), PAD + round((i + 1) * third)
        bands[name] = iou(ref[y0:y1], cap[y0:y1])
    x0, x1 = xspan
    w3 = (x1 - x0) / 3
    length = {}
    for i, name in enumerate(("left", "centre", "right")):
        a, b = x0 + round(i * w3), x0 + round((i + 1) * w3)
        if i == 0:
            a = 0
        if i == 2:
            b = ref.shape[1]
        length[name] = iou(ref[:, a:b], cap[:, a:b])
    area = ref.sum()
    return {
        "iou": iou(ref, cap),
        "height_bands": bands,
        "length_bands": length,
        "missing": float((ref & ~cap).sum() / area),
        "extra": float((cap & ~ref).sum() / area),
    }


def crop_panel(im, mask, flip):
    x0, y0, x1, y1 = bbox(mask)
    m = 0.06 * max(x1 - x0, y1 - y0)
    box = (max(0, int(x0 - m)), max(0, int(y0 - m)), min(im.width, int(x1 + m)), min(im.height, int(y1 + m)))
    p = im.convert("RGBA").crop(box)
    flat = Image.new("RGBA", p.size, BG + (255,))
    flat.alpha_composite(p)
    p = flat.convert("RGB")
    if flip:
        p = p.transpose(Image.FLIP_LEFT_RIGHT)
    k = (SIZE + 2 * PAD) / p.height
    return p.resize((max(1, round(p.width * k)), SIZE + 2 * PAD), Image.LANCZOS)


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def composite(ref_im, ref_m, cap_im, cap_m, ref, cap, res, flip, out):
    overlay = np.zeros(ref.shape + (3,), np.uint8)
    overlay[:] = BG
    overlay[ref & cap] = SHARED
    overlay[ref & ~cap] = MISSING
    overlay[cap & ~ref] = EXTRA
    ov = Image.fromarray(overlay)
    d = ImageDraw.Draw(ov)
    for i in (1, 2):
        y = PAD + round(i * SIZE / 3)
        d.line([(0, y), (ov.width, y)], fill=(90, 90, 100), width=1)
    panels = [crop_panel(ref_im, ref_m, flip), crop_panel(cap_im, cap_m, False), ov]
    head = 74
    W = sum(p.width for p in panels) + PAD * (len(panels) + 1)
    sheet = Image.new("RGB", (W, panels[0].height + head + PAD), BG)
    d = ImageDraw.Draw(sheet)
    f, fs = font(20), font(15)
    x = PAD
    titles = ["reference" + (" (mirrored)" if flip else ""), "build", "overlay: grey shared, blue missing, red extra"]
    for p, t in zip(panels, titles):
        sheet.paste(p, (x, head))
        d.text((x, head - 22), t, fill=(220, 220, 220), font=fs)
        x += p.width + PAD
    hb, lb = res["height_bands"], res["length_bands"]
    d.text((PAD, 10), "IoU %.2f   missing %.0f%%  extra %.0f%%" % (res["iou"], res["missing"] * 100, res["extra"] * 100),
           fill=(255, 255, 255), font=f)
    d.text((PAD, 34), "height bands top %.2f / middle %.2f / bottom %.2f     length bands left %.2f / centre %.2f / right %.2f"
           % (hb["top"], hb["middle"], hb["bottom"], lb["left"], lb["centre"], lb["right"]), fill=(200, 200, 200), font=fs)
    sheet.save(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("reference")
    ap.add_argument("capture")
    ap.add_argument("--out")
    ap.add_argument("--fit", choices=("height", "box"), default="height")
    ap.add_argument("--tol", type=int, default=28, help="background colour tolerance (0-255 per channel)")
    ap.add_argument("--largest", action="store_true", help="keep only the biggest component of each silhouette")
    ap.add_argument("--no-flip", action="store_true", help="don't try the reference mirrored")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    ref_im, cap_im = load(a.reference), load(a.capture)
    ref_m, ref_how = silhouette(ref_im, a.tol, a.largest)
    cap_m, cap_how = silhouette(cap_im, a.tol, a.largest)

    best = None
    for flip in (False,) if a.no_flip else (False, True):
        rm = ref_m[:, ::-1] if flip else ref_m
        ref, cap, xspan = align(rm, cap_m, a.fit)
        res = score(ref, cap, xspan)
        if best is None or res["iou"] > best[0]["iou"]:
            best = (res, flip, ref, cap)
    res, flip, ref, cap = best
    rx0, ry0, rx1, ry1 = bbox(ref_m)
    cx0, cy0, cx1, cy1 = bbox(cap_m)
    res["aspect_ref"] = round((rx1 - rx0) / (ry1 - ry0), 3)
    res["aspect_build"] = round((cx1 - cx0) / (cy1 - cy0), 3)
    res["mirrored_reference"] = flip
    res["fit"] = a.fit

    out = Path(a.out) if a.out else Path(a.capture).with_name(Path(a.capture).stem + "_fidelity.png")
    composite(ref_im, ref_m, cap_im, cap_m, ref, cap, res, flip, out)
    res["composite"] = str(out)
    res["silhouettes"] = {"reference": ref_how, "build": cap_how}

    if a.json:
        print(json.dumps(res, indent=1))
        return
    hb, lb = res["height_bands"], res["length_bands"]
    print("IoU %.3f  (missing %.1f%% of the reference, extra %.1f%%)" % (res["iou"], res["missing"] * 100, res["extra"] * 100))
    print("height bands  top %.3f  middle %.3f  bottom %.3f" % (hb["top"], hb["middle"], hb["bottom"]))
    print("length bands  left %.3f  centre %.3f  right %.3f" % (lb["left"], lb["centre"], lb["right"]))
    print("width/height  reference %.2f  build %.2f%s" % (res["aspect_ref"], res["aspect_build"],
                                                        "  (reference mirrored)" if flip else ""))
    print("silhouettes   reference: %s; build: %s" % (ref_how, cap_how))
    print("composite     %s" % out)


if __name__ == "__main__":
    main()
