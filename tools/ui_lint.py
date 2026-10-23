"""UI lint: the mechanical checks behind every cropping, off-centre and blurry
complaint so far, run over a layout dump instead of by eye.

1. In Studio (Edit mode, the test build or a sandbox), run tools/ui_lint.luau
   (it posts one dump per size to the receiver on 8766).
2. uv run --with pillow python3 -I tools/ui_lint.py [--frag DIR] [--gui NAME ...] [--all]

Checks per element, at every lint size (1920x1080, 1366x768, 844x390, 667x375):
  FAIL clip        its rectangle (or its 1.05x hover box, for buttons) leaves the
                   nearest clipping ancestor or the screen
  FAIL slice       a 9-sliced image whose edge strips aren't uniform along their
                   length (Roblox smears or flattens them), or a SliceCenter with
                   no margin on a side
  FAIL oversize    art displayed larger than its source pixels (Stretch/Fit), or a
                   sliced image whose SliceScale shows corners above 1:1
  FAIL text        text that doesn't fit its box without TextScaled
  WARN centre      the only visible child of its parent, or an AnchorPoint 0.5
                   element, more than 1 px off its parent's centre
  WARN padding     a row or column of siblings with uneven gaps or uneven outer
                   padding (more than 1 px)
  WARN rect        an ImageRect crop that cuts into the glyph's alpha bounds
Offline, independent of the dump:
  WARN cut-edge    a cut PNG whose opaque pixels touch its border on part of a
                   side (an ornament tip flattened by the crop)

Put a `LintIgnore` attribute on an instance to skip it (the touch cluster that
reaches past the inset on purpose, say). Exit 1 when any FAIL remains.
"""

import argparse
import glob
import json
import os
import re
import sys
from collections import defaultdict

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art", "ui")
FRAG = os.path.join(ROOT, "tools", "frag")
TOL = 6  # per-channel tolerance along a slice strip (antialiasing)
ALPHA_TOL = 32  # alpha change along a strip that counts as the outline moving (a soft
#                 shadow or glow fading along it is a gradient: WARN, not FAIL)
PX = 1.0  # centring and padding tolerance in px
HOVER = 1.05  # Motion.buttons growth
SIZE_OK = 1.05  # displayed / source ratio allowed before "oversize" (5% upscaling is invisible)
MARGIN_PX = 1.0  # clear margin (display px) an image needs beyond ornament tips
TIP_SHARE = 0.6  # the outermost content line is "tips" when less of it than this is solid
CAP_PX = 2.0  # glyphs may touch a cap's ornament by this much (antialiasing)
STRIP = 32  # a source this narrow along an axis is a strip meant to stretch along it

# ---------------------------------------------------------------- sources

def art_index():
    """rbxassetid -> (relative png path, (w, h)) for every entry in assets.json."""
    assets = json.load(open(os.path.join(ART, "assets.json")))
    by_name = {}
    for p in glob.glob(os.path.join(ART, "**", "*.png"), recursive=True):
        rel = os.path.relpath(p, ART)
        by_name[rel] = p
        by_name.setdefault(os.path.basename(rel), p)
    out = {}
    for name, rid in assets.items():
        p = by_name.get(name) or by_name.get(os.path.basename(name))
        if not p:
            continue
        try:
            with Image.open(p) as im:
                out[rid] = (os.path.relpath(p, ROOT), im.size)
        except OSError:
            pass
    return out


_img_cache = {}


def load_png(path):
    if path not in _img_cache:
        _img_cache[path] = Image.open(os.path.join(ROOT, path)).convert("RGBA")
    return _img_cache[path]


# ---------------------------------------------------------------- slices

def strip_uniform(im, box, along, alpha_only=False):
    crop = im.crop(box)
    tol = TOL
    if alpha_only:
        crop = crop.getchannel("A").convert("RGBA")
        tol = ALPHA_TOL
    w, h = crop.size
    if w <= 0 or h <= 0:
        return True
    px = crop.load()
    if along == "x":  # top/bottom strip: every column equals column 0
        return all(
            max(abs(a - b) for a, b in zip(px[x, y], px[0, y])) <= tol
            for y in range(h) for x in range(w)
        )
    return all(  # left/right strip: every row equals row 0
        max(abs(a - b) for a, b in zip(px[x, y], px[x, 0])) <= tol
        for x in range(w) for y in range(h)
    )


_slice_cache = {}


def check_slice(path, sc, sides=("top", "bottom", "left", "right")):
    """(problems, warnings) for SliceCenter sc = (x0, y0, x1, y1) on png path, over
    the edge strips that actually stretch on screen (sides)."""
    key = (path, tuple(sc), tuple(sides))
    if key not in _slice_cache:
        warns = []
        _slice_cache[key] = (_check_slice(path, sc, warns, sides), warns)
    return _slice_cache[key]


def stretched_sides(it, path):
    """The edge strips with length on screen: top/bottom stretch when the shown width
    exceeds the scaled left+right corners, left/right likewise with the height."""
    w, h = load_png(path).size
    x0, y0, x1, y1 = it["sliceCenter"]
    k = it.get("sliceScale", 1)
    r = it["rect"]
    sides = []
    if r[2] > (x0 + w - x1) * k + 1:
        sides += ["top", "bottom"]
    if r[3] > (y0 + h - y1) * k + 1:
        sides += ["left", "right"]
    return tuple(sides)


def _check_slice(path, sc, warns, sides):
    im = load_png(path)
    w, h = im.size
    x0, y0, x1, y1 = sc
    problems = []
    if x0 <= 0 or y0 <= 0 or x1 >= w or y1 >= h:
        problems.append("SliceCenter touches the image edge (no margin)")
    if x1 <= x0 or y1 <= y0:
        problems.append("SliceCenter is empty")
        return problems
    strips = {
        "top": ((x0, 0, x1, y0), "x"),
        "bottom": ((x0, y1, x1, h), "x"),
        "left": ((0, y0, x0, y1), "y"),
        "right": ((x1, y0, w, y1), "y"),
    }
    strips = {n: v for n, v in strips.items() if n in sides}
    bad = [n for n, (box, along) in strips.items() if not strip_uniform(im, box, along, alpha_only=True)]
    if bad:
        problems.append("outline changes along the " + "/".join(bad) + " strip (Roblox crops or bends it)")
        return problems
    tint = [n for n, (box, along) in strips.items() if not strip_uniform(im, box, along)]
    if tint:
        warns.append("colour changes along the " + "/".join(tint) + " strip (fine for a gradient, smears an ornament)")
    return problems


# ---------------------------------------------------------------- geometry

def inside(r, c, tol=0.5):
    return (r[0] >= c[0] - tol and r[1] >= c[1] - tol
            and r[0] + r[2] <= c[0] + c[2] + tol and r[1] + r[3] <= c[1] + c[3] + tol)


def grow(r, f):
    cx, cy = r[0] + r[2] / 2, r[1] + r[3] / 2
    w, h = r[2] * f, r[3] * f
    return [cx - w / 2, cy - h / 2, w, h]


def centre_off(r, p):
    return (r[0] + r[2] / 2) - (p[0] + p[2] / 2), (r[1] + r[3] / 2) - (p[1] + p[3] / 2)


def alpha_bounds(im):
    a = im.getchannel("A").point(lambda v: 255 if v > 24 else 0)
    return a.getbbox()


# ---------------------------------------------------------------- checks

_uniform_cache = {}


def uniform_axes(path):
    """(columns all equal, rows all equal): the image may stretch along x / along y
    without showing its pixels larger (a strip or a plain middle)."""
    if path not in _uniform_cache:
        im = load_png(path)
        w, h = im.size
        _uniform_cache[path] = (strip_uniform(im, (0, 0, w, h), "x"), strip_uniform(im, (0, 0, w, h), "y"))
    return _uniform_cache[path]


REPEAT_HINT = ("Template", "Slot", "Cell", "Row", "Tile", "Chip", "Entry", "Option")


def ink_rect(it):
    """Where a label's glyphs actually sit: TextBounds placed by its alignment."""
    r, tb = it["rect"], it["textBounds"]
    tw, th = min(tb[0], r[2]), min(tb[1], r[3])
    x = {"Left": r[0], "Right": r[0] + r[2] - tw}.get(it.get("textX"), r[0] + (r[2] - tw) / 2)
    y = {"Top": r[1], "Bottom": r[1] + r[3] - th}.get(it.get("textY"), r[1] + (r[3] - th) / 2)
    return [x, y, tw, th]


def cap_ornament(cap, art, ink):
    """The part of a ribbon cap that holds ornament at the height of the text's
    glyphs (ink), on screen: the cap minus the plain band next to its inner edge.
    The plain run per band of rows comes from the dump (read from the uploaded
    image); without it the whole cap counts as ornament."""
    r = cap["rect"]
    left = cap["path"].endswith("CapL")
    bands = cap.get("capBands")
    if not bands:
        return r
    w = cap["srcSize"][0]
    n = len(bands)
    y0 = max(0.0, (ink[1] - r[1]) / r[3])
    y1 = min(1.0, (ink[1] + ink[3] - r[1]) / r[3])
    if y1 <= y0:
        return [r[0], r[1], 0, 0]
    covered = [bands[i] for i in range(n) if (i + 1) / n > y0 and i / n < y1]
    plain = min(covered) if covered else w
    k = r[2] / w
    orn = (w - plain) * k
    return [r[0], r[1], orn, r[3]] if left else [r[0] + plain * k, r[1], orn, r[3]]


_margin_cache = {}
EDGE_RECORDS = []  # structured edge-margin findings, for tools/ui_margin.py


def edge_margins(path, crop=None):
    """Per side (left, top, right, bottom): (clear margin in source px, share of the
    outermost solid line that is solid). Solid means alpha above half, so a soft fade
    counts as margin. A low share means tips (a stud, a curl, a gem's point) reach
    that side rather than a straight edge."""
    key = (path, crop)
    if key not in _margin_cache:
        im = load_png(path)
        if crop:
            im = im.crop(crop)
        a = im.getchannel("A")
        w, h = a.size
        bb = a.point(lambda v: 255 if v > 128 else 0).getbbox()
        if not bb:
            _margin_cache[key] = None
            return None
        px = a.load()
        x0, y0, x1, y1 = bb

        def share(line):
            return sum(1 for v in line if v > 128) / max(1, len(line))

        _margin_cache[key] = {
            "left": (x0, share([px[x0, y] for y in range(y0, y1)])),
            "top": (y0, share([px[x, y0] for x in range(x0, x1)])),
            "right": (w - x1, share([px[x1 - 1, y] for y in range(y0, y1)])),
            "bottom": (h - y1, share([px[x, y1 - 1] for x in range(x0, x1)])),
        }
    return _margin_cache[key]


def skipped(it, check):
    if check in (it.get("skip") or "").replace(" ", "").split(","):
        return True
    # a detached template is parked, not mounted (no LintMount): its size isn't what
    # players see, so only its art (slices) is checked
    return it.get("detached") and check != "slice"


def overlap(a, b):
    return min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0]), min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])


def visible_rect(it, art):
    """The part of an image element that draws (its art's alpha > 24 bounds, placed
    by Stretch/Fit), or None when that can't be known."""
    img = it.get("image")
    if not img or img not in art or it.get("scaleType") not in ("Stretch", "Fit"):
        return None
    if (it.get("rectSize") or [0, 0])[0] > 0:
        return None
    path, (w, h) = art[img]
    im = load_png(path)
    bb = im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    if not bb:
        return None
    r = it["rect"]
    sx, sy = r[2] / w, r[3] / h
    ox = oy = 0.0
    if it["scaleType"] == "Fit":
        k = min(sx, sy)
        ox, oy = (r[2] - w * k) / 2, (r[3] - h * k) / 2
        sx = sy = k
    return [r[0] + ox + bb[0] * sx, r[1] + oy + bb[1] * sy, (bb[2] - bb[0]) * sx, (bb[3] - bb[1]) * sy]


def grow_like(inner, rect, grown):
    """inner (a sub-rect of rect) after rect became grown about the same centre."""
    k = grown[2] / rect[2] if rect[2] else 1
    cx, cy = grown[0] + grown[2] / 2, grown[1] + grown[3] / 2
    rcx, rcy = rect[0] + rect[2] / 2, rect[1] + rect[3] / 2
    return [cx + (inner[0] - rcx) * k, cy + (inner[1] - rcy) * k, inner[2] * k, inner[3] * k]


def lint_dump(doc, art, findings):
    w, h = doc["size"]
    tag = f"{w}x{h}"
    items = doc["items"]
    # an element whose parent already leaves the same clipper is reported once, at
    # the outermost one
    leaving = set()
    for it in items:
        if it.get("clip") and not it.get("canvas") and not inside(it.get("hover") or it["rect"], it["clip"]):
            leaving.add((it["gui"], it.get("scene", "base"), it["path"], it["clipPath"]))
    by_parent = defaultdict(dict)  # (gui, scene, parent path) -> {path: item}
    caps = defaultdict(list)  # (gui, scene) -> ribbon caps
    for it in items:
        parent = it["path"].rsplit(".", 1)[0] if "." in it["path"] else ""
        by_parent[(it["gui"], it.get("scene", "base"), parent)][it["path"]] = it
        if it["path"].rsplit(".", 1)[-1] in ("CapL", "CapR") and it.get("image"):
            caps[(it["gui"], it.get("scene", "base"))].append(it)

    # sides of an image that butt against another image in the same parent (a cap
    # against its middle, a corner against its rail): the art continues there
    joined = defaultdict(set)
    for kids in by_parent.values():
        imgs = [k for k in kids.values() if k.get("image")]
        for a in imgs:
            ra = a["rect"]
            for b in imgs:
                if a is b:
                    continue
                rb = b["rect"]
                ox, oy = overlap(ra, rb)
                if oy > 1 and abs(ra[0] - (rb[0] + rb[2])) <= 1.5:
                    joined[id(a)].add("left")
                if oy > 1 and abs(ra[0] + ra[2] - rb[0]) <= 1.5:
                    joined[id(a)].add("right")
                if ox > 1 and abs(ra[1] - (rb[1] + rb[3])) <= 1.5:
                    joined[id(a)].add("top")
                if ox > 1 and abs(ra[1] + ra[3] - rb[1]) <= 1.5:
                    joined[id(a)].add("bottom")

    for it in items:
        where = f"{it['gui']}.{it['path']}"
        r = it["rect"]
        # clipping (a UiScale canvas is the screen in baseline units; its own rect
        # is the limit for its children, so the canvas itself isn't checked)
        parent_path = it["path"].rsplit(".", 1)[0] if "." in it["path"] else ""
        if not it.get("canvas") and it.get("clip") and not skipped(it, "clip"):
            box = it.get("hover") or r
            # an image's clear margin may leave the clipper: only its drawn part counts
            vis = visible_rect(it, art)
            if vis is not None:
                hb = it.get("hover")
                box = vis if not hb else grow_like(vis, r, hb)
            if (it["gui"], it.get("scene", "base"), parent_path, it["clipPath"]) in leaving:
                pass
            elif not inside(box, it["clip"]):
                c = it["clip"]
                dx = max(c[0] - box[0], box[0] + box[2] - c[0] - c[2], 0)
                dy = max(c[1] - box[1], box[1] + box[3] - c[1] - c[3], 0)
                how = "rect" if inside(r, c) is False else "hover box"
                findings["FAIL"]["clip"].append(
                    f"{where} @{tag}: {how} leaves {it['clipPath']} by {dx:.0f}x{dy:.0f} px")
        # images
        img = it.get("image")
        if img and img.startswith("rbxassetid://") and img not in art:
            findings["WARN"]["unknown-art"].append(
                f"{it['gui']}: {img} isn't in art/ui/assets.json (no source to check or re-cut)")
        if img and img in art and it.get("imageTransparency", 0) < 1:
            path, (sw, sh) = art[img]
            rs = it.get("rectSize") or [0, 0]
            src_w, src_h = (rs[0], rs[1]) if rs[0] > 0 and rs[1] > 0 else (sw, sh)
            st = it.get("scaleType")
            if st == "Slice":
                sc = it["sliceCenter"]
                fails, warns = check_slice(path, sc, stretched_sides(it, path))
                for p in fails if not skipped(it, "slice") else []:
                    findings["FAIL"]["slice"].append(f"{where}: {os.path.basename(path)} {sc}: {p}")
                for p in warns:
                    findings["WARN"]["slice"].append(f"{where}: {os.path.basename(path)} {sc}: {p}")
                if it.get("sliceScale", 1) > SIZE_OK and not skipped(it, "oversize"):
                    findings["FAIL"]["oversize"].append(
                        f"{where} @{tag}: SliceScale {it['sliceScale']:.2f} shows corners above 1:1")
            elif st in ("Stretch", "Fit", "Crop"):
                rx, ry = r[2] / src_w, r[3] / src_h
                if st == "Fit":
                    rx = ry = min(rx, ry)
                elif st == "Crop":
                    rx = ry = max(rx, ry)
                ux, uy = uniform_axes(path) if not (rs[0] > 0) else (False, False)
                # a strip cut to stretch (a 3-slice middle, a frame edge) is narrow
                # along its stretch axis
                ux, uy = ux or src_w <= STRIP, uy or src_h <= STRIP
                ratio = max(0 if ux else rx, 0 if uy else ry)
                if ratio > SIZE_OK and not skipped(it, "oversize"):
                    findings["FAIL"]["oversize"].append(
                        f"{where} @{tag}: {r[2]:.0f}x{r[3]:.0f} shown from {src_w}x{src_h} source ({ratio:.2f}x)")
            # ornament tips at the image's border: the quad's edge cuts them straight
            # unless the cut leaves at least a display pixel of clear margin
            if st in ("Stretch", "Fit", "Crop") and not skipped(it, "edge-margin"):
                ro = it.get("rectOffset") or [0, 0]
                crop = (ro[0], ro[1], ro[0] + rs[0], ro[1] + rs[1]) if rs[0] > 0 and rs[1] > 0 else None
                m = edge_margins(path, crop)
                sx, sy = r[2] / src_w, r[3] / src_h
                if st == "Fit":
                    sx = sy = min(sx, sy)
                elif st == "Crop":
                    sx = sy = max(sx, sy)
                if m:
                    bad = [f"{side} {px * (sx if side in ('left', 'right') else sy):.1f}"
                           for side, (px, solid) in m.items()
                           if side not in joined[id(it)] and solid < TIP_SHARE and px * (sx if side in ("left", "right") else sy) < MARGIN_PX]
                    if bad:
                        EDGE_RECORDS.append({"item": it, "path": path, "crop": crop, "tag": tag,
                                             "joined": sorted(joined[id(it)]), "scale": (sx, sy)})
                        findings["FAIL"]["edge-margin"].append(
                            f"{where} @{tag}: ornament tips reach the image edge ({', '.join(bad)} px clear) in "
                            f"{os.path.basename(path)}{' rect' if crop else ''}")
            if rs[0] > 0 and rs[1] > 0:
                ro = it.get("rectOffset") or [0, 0]
                bb = alpha_bounds(load_png(path))
                if bb:
                    crop = (ro[0], ro[1], ro[0] + rs[0], ro[1] + rs[1])
                    if bb[0] < crop[0] or bb[1] < crop[1] or bb[2] > crop[2] or bb[3] > crop[3]:
                        findings["WARN"]["rect"].append(
                            f"{where}: ImageRect {crop} cuts glyph bounds {bb} of {os.path.basename(path)}")
        # text
        if "text" in it and it["text"].strip() and it.get("textTransparency", 0) < 1:
            # TextFits reads false on an AutomaticSize label even when the box grew to
            # the text; there the bounds against the box decide
            auto = it.get("autoSize", "None")
            tb = it["textBounds"]
            fits = it["textFits"] or (auto != "None" and tb[0] <= r[2] + 0.5 and tb[1] <= r[3] + 0.5)
            if not it["textScaled"] and not fits and not skipped(it, "text"):
                tb = it["textBounds"]
                findings["FAIL"]["text"].append(
                    f"{where} @{tag}: text {tb[0]:.0f}x{tb[1]:.0f} doesn't fit {r[2]:.0f}x{r[3]:.0f}: {it['text'][:30]!r}")
            # glyphs under a ribbon's cap (the cap's ornament covers them): caps under
            # the label's parent
            parent = it["path"].rsplit(".", 1)[0] if "." in it["path"] else ""
            line = ink_rect(it)
            # the glyphs' ink within the line box: cap height down to the baseline
            ink = [line[0], line[1] + 0.12 * line[3], line[2], 0.68 * line[3]]
            for cap in caps[(it["gui"], it.get("scene", "base"))] if not skipped(it, "text-cap") else []:
                if parent and not cap["path"].startswith(parent + "."):
                    continue
                ox, oy = overlap(ink, cap_ornament(cap, art, ink))
                if ox > CAP_PX and oy > PX:
                    findings["FAIL"]["text-cap"].append(
                        f"{where} @{tag}: text runs {ox:.0f} px under {cap['path'].rsplit('.', 1)[-1]}: {it['text'][:30]!r}")
            # TextScaled on a repeated tile: every copy picks its own size
            if it["textScaled"] and not it.get("maxTextSize"):
                if any(h in seg for seg in it["path"].split(".")[:-1] for h in REPEAT_HINT):
                    findings["WARN"]["textscaled-repeat"].append(
                        f"{where}: TextScaled with no UITextSizeConstraint on a repeated tile (copies size apart)")
        # centring
        anchored = it["anchor"] == [0.5, 0.5]
        if (anchored or it["visibleSiblings"] == 1) and not it.get("layout") and not skipped(it, "centre"):
            dx, dy = centre_off(r, it["parent"])
            if anchored and abs(dx) > PX and abs(dx) < r[2] and abs(dy) > PX and abs(dy) < r[3]:
                pass  # anchored but deliberately placed off-centre on both axes
            elif it["visibleSiblings"] == 1 and (abs(dx) > PX or abs(dy) > PX) and it["class"] not in ("Frame", "ScrollingFrame") and r[2] < it["parent"][2] and r[3] < it["parent"][3]:
                findings["WARN"]["centre"].append(
                    f"{where} @{tag}: {dx:+.1f}, {dy:+.1f} px off its parent's centre")

    # padding: rows/columns of same-size visible siblings (repeated pieces)
    for (gui, scene, parent), kids in by_parent.items():
        kids = [k for k in kids.values() if k["class"] in ("ImageLabel", "ImageButton", "TextButton", "Frame")]
        groups = defaultdict(list)
        for k in kids:
            groups[(round(k["rect"][2]), round(k["rect"][3]), k["class"])].append(k)
        for ks0 in groups.values():
            if len(ks0) < 2 or any(skipped(k, "padding") for k in ks0):
                continue
            p = ks0[0]["parent"]
            for axis, other in ((0, 1), (1, 0)):
                cs = [k["rect"][other] + k["rect"][other + 2] / 2 for k in ks0]
                if max(cs) - min(cs) > PX:
                    continue
                ks = sorted(ks0, key=lambda k: k["rect"][axis])
                gaps = [ks[i + 1]["rect"][axis] - (ks[i]["rect"][axis] + ks[i]["rect"][axis + 2]) for i in range(len(ks) - 1)]
                where = f"{gui}.{parent or '<root>'} @{tag}"
                if gaps and max(gaps) - min(gaps) > PX and min(gaps) >= -PX:
                    findings["WARN"]["padding"].append(
                        f"{where}: uneven gaps {[round(g) for g in gaps]} along {'x' if axis == 0 else 'y'}")
                if len(ks) == len(kids) and len(ks) >= 2:
                    lead = ks[0]["rect"][axis] - p[axis]
                    trail = (p[axis] + p[axis + 2]) - (ks[-1]["rect"][axis] + ks[-1]["rect"][axis + 2])
                    if abs(lead - trail) > PX and lead >= -PX and trail >= -PX \
                            and (ks[0].get("layoutAlign") or ["", ""])[axis] == "Center":
                        findings["WARN"]["padding"].append(
                            f"{where}: outer padding {lead:.0f} vs {trail:.0f} along {'x' if axis == 0 else 'y'}")
                break


def lint_cut_edges(findings, art):
    """Opaque pixels touching a border on only part of a side: a flattened tip."""
    seen = set()
    for rid, (path, _) in art.items():
        if path in seen or "/codex/" in path:
            continue
        seen.add(path)
        im = load_png(path)
        a = im.getchannel("A").load()
        w, h = im.size
        sides = {
            "left": [a[0, y] > 128 for y in range(h)],
            "right": [a[w - 1, y] > 128 for y in range(h)],
            "top": [a[x, 0] > 128 for x in range(w)],
            "bottom": [a[x, h - 1] > 128 for x in range(w)],
        }
        bad = []
        for name, run in sides.items():
            n = sum(run)
            if 0 < n < 0.9 * len(run):
                bad.append(f"{name} {n}/{len(run)}")
        if bad:
            findings["WARN"]["cut-edge"].append(f"{path}: opaque to the border on {', '.join(bad)}")


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frag", default=FRAG, help="where ui_lint.luau's dumps landed")
    ap.add_argument("--gui", action="append", help="only these ScreenGuis")
    ap.add_argument("--all", action="store_true", help="print every finding, not the first 40 per check")
    ap.add_argument("--no-edges", action="store_true", help="skip the offline cut-edge scan")
    args = ap.parse_args()

    art = art_index()
    findings = {"FAIL": defaultdict(list), "WARN": defaultdict(list)}
    dumps = sorted(d for d in glob.glob(os.path.join(args.frag, "uilint_*.xml")) if re.match(r"uilint_\d+x\d+_", os.path.basename(d)))
    if not dumps:
        print(f"no dumps in {args.frag}; run tools/ui_lint.luau in Studio first", file=sys.stderr)
        return 2
    for d in dumps:
        doc = json.load(open(d))
        if args.gui:
            doc["items"] = [i for i in doc["items"] if i["gui"] in args.gui]
        lint_dump(doc, art, findings)
    if not args.no_edges:
        lint_cut_edges(findings, art)

    # dedupe across sizes where the message is size-free
    total_fail = 0
    for sev in ("FAIL", "WARN"):
        for check, rows in findings[sev].items():
            rows = sorted(set(rows))
            findings[sev][check] = rows
            if sev == "FAIL":
                total_fail += len(rows)
    sizes = sorted({os.path.basename(d)[7:-4].split("_")[0] for d in dumps})
    print(f"ui_lint: {total_fail} FAIL, {sum(len(r) for r in findings['WARN'].values())} WARN "
          f"over {len(sizes)} sizes ({', '.join(sizes)}), {len(dumps)} dumps\n")
    per = defaultdict(lambda: [0, 0])
    for i, sev in enumerate(("FAIL", "WARN")):
        for rows in findings[sev].values():
            for row in rows:
                per[row.split(".", 1)[0].split(":", 1)[0] if "/" not in row.split(" ", 1)[0] else "<art>"][i] += 1
    print("per gui: " + ", ".join(f"{g} {f}/{w}" for g, (f, w) in sorted(per.items())) + "  (FAIL/WARN)\n")
    for sev in ("FAIL", "WARN"):
        for check, rows in sorted(findings[sev].items()):
            print(f"## {sev} {check} ({len(rows)})")
            for row in rows if args.all else rows[:40]:
                print("-", row)
            if not args.all and len(rows) > 40:
                print(f"- ... {len(rows) - 40} more (--all)")
            print()
    return 1 if total_fail else 0


if __name__ == "__main__":
    sys.exit(main())
