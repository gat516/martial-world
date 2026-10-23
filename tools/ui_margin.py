"""Clears ui_lint's edge-margin findings: ornament tips cut straight by the image's
own edge because the art reaches its border (the cutter keeps a 2 px pad, a fraction
of a screen pixel once a piece is shown at a fifth of its size, and Roblox draws GUI
images without mipmaps).

The fix is never a repaint: a display-sized copy (Lanczos, art/ui/sized/, the
registry art/ui/sized/sized.json, tools/ui_assemble.py --sized) with a clear margin
of at least a screen pixel on every side that doesn't join another piece, and every
element that shows it grown by that margin so the art stays exactly where it was.

  1. plan: run tools/ui_lint.luau in Studio, then
       uv run --with pillow --with numpy python3 -I tools/ui_margin.py plan \\
           --frag DIR --out PLAN.json [--only REGEX]
     picks a height (2x the largest display height) and margin per source, writes
     the registry entries and the sized copies, and the plan.
  2. upload the plan's files (upload_image) and save {file: id} as UPLOADS.json.
  3. uv run ... tools/ui_margin.py ids PLAN.json UPLOADS.json --luau OUT.luau
     records the ids in art/ui/assets.json, swaps old ids for new in src/, and
     writes the Studio table.
  4. In Studio, run OUT.luau then tools/ui_margin.luau: it swaps each element's image
     and grows it (and keeps its children where they were). Elements it can't grow
     in place (inside a layout) are listed for a hand fix.
  5. Rerun the lint; export the GUIs.

FAMILIES: images code swaps into the same element (rarity tiles, gems, tags) get
the same height and margin, so one compensation fits them all.
"""

import argparse
import glob
import json
import math
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import ui_assemble  # noqa: E402
import ui_lint  # noqa: E402
from PIL import Image  # noqa: E402

ART = os.path.join(ROOT, "art", "ui")
MIN_MARGIN_PX = 1.25  # clear margin, in screen px, at the smallest display
# Images code swaps into the same element: one family gets one height and margin, so
# the element's compensation fits whichever member code shows. Regexes over the
# source path (codex cuts and their sized copies alike).
FAMILIES = [
    r"ornament_(tile_(neutral|grey|jade|violet|gold)|coin_frame)",  # Rewards tiles
    r"ornament_gem_(grey|jade|violet|gold)",  # Rarity gems
    r"ornament_(blood_)?ruby_stud",  # Events themes
    r"ornament_item_slot(_selected)?\.",  # InventoryFilter chips
    r"ornament_set_",  # BuildCatalog medallions
    r"ornament_herb_card",  # Herbarium cards (empty / found)
    r"ornament_herb_tier_",  # HerbArt tiers
    r"ornament_(daily|weekly)_seal",  # Sect notices
]


def source_of(rel, registry):
    """The source a file was resized from (a sized copy) and the copy's height, or (rel, None)."""
    if rel.startswith("sized/"):
        m = re.match(r"sized/(.+)_h(\d+)\.png$", rel)
        if m:
            for src, entry in registry.items():
                if os.path.splitext(os.path.basename(src))[0] == m.group(1) and int(m.group(2)) in entry["heights"]:
                    return src, int(m.group(2))
    return rel, None


def plan(args):
    art = ui_lint.art_index()
    ids_by_file = {}
    for rid, (path, _) in art.items():
        ids_by_file.setdefault(os.path.relpath(os.path.join(ROOT, path), ART), []).append(rid)
    findings = {"FAIL": ui_lint.defaultdict(list), "WARN": ui_lint.defaultdict(list)}
    docs = [json.load(open(d)) for d in sorted(glob.glob(os.path.join(args.frag, "uilint_*.xml")))]
    for d in docs:
        ui_lint.lint_dump(d, art, findings)
    registry = ui_assemble.sized_registry()
    only = re.compile(args.only) if args.only else None
    skip = re.compile(args.skip) if args.skip else None

    # every display of every flagged image (flagged or not), in screen px of art height
    icon_rects = open(os.path.join(ROOT, "src", "client", "IconRects.luau")).read()
    flagged = {}
    for rec in ui_lint.EDGE_RECORDS:
        if rec["crop"]:
            continue  # an icon shown through an ImageRect: tools/icon_rects.py's margin
        rel = os.path.relpath(os.path.join(ROOT, rec["path"]), ART)
        if only and not only.search(rel):
            continue
        if skip and skip.search(rel):
            continue
        if any(rid.split("//")[1] in icon_rects for rid in ids_by_file.get(rel, [])):
            continue  # icons are cropped through IconRects wherever code shows them
        # a side counts as joined only where every flagged display of it joins
        joined = set(rec["joined"])
        flagged[rel] = joined if rel not in flagged else flagged[rel] & joined
    sliced = set()  # files 9-sliced anywhere keep their geometry (SliceCenter in their pixels)
    for d in docs:
        for it in d["items"]:
            if it.get("image") in art and it.get("scaleType") == "Slice":
                sliced.add(os.path.relpath(os.path.join(ROOT, art[it["image"]][0]), ART))
    for rel in list(flagged):
        if rel in sliced:
            print(f"skip {rel}: also 9-sliced somewhere")
            del flagged[rel]
    displays = {}
    for d in docs:
        for it in d["items"]:
            img = it.get("image")
            if img in art and it.get("scaleType") in ("Stretch", "Fit", "Crop") and not ui_lint.skipped(it, "edge-margin"):
                rel = os.path.relpath(os.path.join(ROOT, art[img][0]), ART)
                w, h = art[img][1]
                sy = it["rect"][3] / h
                if it["scaleType"] == "Fit":
                    sy = min(it["rect"][2] / w, sy)
                displays.setdefault(rel, []).append(sy * h)

    # group into families (same height and margin)
    groups = []
    seen = set()
    for rel in sorted(flagged):
        if rel in seen:
            continue
        src, _ = source_of(rel, registry)
        group = {rel}
        for fam in FAMILIES:
            if re.search(fam, src):
                for f in ids_by_file:
                    if re.search(fam, source_of(f, registry)[0]) and not (skip and skip.search(f)) and f not in sliced:
                        group.add(f)
        seen |= group
        groups.append(sorted(group))

    entries = []
    for group in groups:
        disp = [v for f in group for v in displays.get(f, [])] or [1]
        hi, lo = max(disp), max(1.0, min(disp))
        joins = set()
        for f in group:
            joins |= flagged.get(f, set())
        srcs = sorted({source_of(f, registry)[0] for f in group})
        sizes = {s: Image.open(os.path.join(ART, s)).size for s in srcs}
        h = min(min(sz[1] for sz in sizes.values()), int(math.ceil(2 * hi / 8) * 8))
        m = max(2, math.ceil(MIN_MARGIN_PX * h / lo))
        for f in group:
            src, old_h = source_of(f, registry)
            entry = registry.setdefault(src, {"heights": [], "margin": 0})
            if old_h is not None and old_h != h:
                pass  # keep the other height; the new one is added below
            if h not in entry["heights"]:
                entry["heights"].append(h)
                entry["heights"].sort()
            entry.setdefault("margins", {})[str(h)] = m
            if joins:
                entry["joins"] = sorted(set(entry.get("joins", ui_assemble.sized_joins(src, {}))) | joins)
            name, aw, ah, margins = ui_assemble.sized_layout(src, entry, h, sizes[src])
            for old_id in ids_by_file.get(f, []):
                entries.append({"old_id": old_id, "old_file": f, "source": src, "file": "sized/" + name,
                                "art": [aw, ah], "margins": margins, "displays": [round(lo, 1), round(hi, 1)]})
    if not args.dry:
        with open(ui_assemble.SIZED_REGISTRY, "w") as fh:
            json.dump(registry, fh, indent=1, sort_keys=True)
            fh.write("\n")
        ui_assemble.sized_copies({e["source"] for e in entries})
    # dedupe (several old ids of one file)
    json.dump(entries, open(args.out, "w"), indent=1)
    files = sorted({e["file"] for e in entries})
    print(f"{len(entries)} old ids -> {len(files)} sized copies; plan {args.out}")
    for e in entries:
        ml, mt, mr, mb = e["margins"]
        print(f"  {e['old_file']} -> {e['file']} (art {e['art'][0]}x{e['art'][1]}, margin {ml},{mt},{mr},{mb}, "
              f"shown {e['displays'][0]}-{e['displays'][1]} px tall)")


def ids(args):
    entries = json.load(open(args.plan))
    uploads = json.load(open(args.uploads))  # {"sized/<name>.png" or url: "rbxassetid://..."}
    by_file = {}
    for k, v in uploads.items():
        by_file[re.sub(r"^.*?/(sized/)", r"\1", k)] = v
    assets_path = os.path.join(ART, "assets.json")
    assets = json.load(open(assets_path))
    table = []
    swaps = {}
    for e in entries:
        new = by_file.get(e["file"])
        if not new:
            sys.exit(f"no upload for {e['file']}")
        assets[e["file"]] = new
        aw, ah = e["art"]
        ml, mt, mr, mb = e["margins"]
        swaps[e["old_id"]] = new
        table.append(f'\t["{e["old_id"]}"] = {{ new = "{new}", l = {ml / aw:.6f}, t = {mt / ah:.6f}, '
                     f'r = {mr / aw:.6f}, b = {mb / ah:.6f} }}, -- {e["old_file"]} -> {e["file"]}')
    with open(assets_path, "w") as fh:
        json.dump(assets, fh, indent=2)
        fh.write("\n")
    changed = []
    for path in glob.glob(os.path.join(ROOT, "src", "**", "*.luau"), recursive=True):
        text = open(path).read()
        new_text = text
        for old, new in swaps.items():
            new_text = new_text.replace(old, new)
        if new_text != text:
            with open(path, "w") as fh:
                fh.write(new_text)
            changed.append(os.path.relpath(path, ROOT))
    with open(args.luau, "w") as fh:
        fh.write("-- generated by tools/ui_margin.py ids\n_G.UIMARGIN = {\n" + "\n".join(table) + "\n}\nreturn #_G.UIMARGIN\n")
    print(f"assets.json: {len(swaps)} new ids; src swapped in: {', '.join(changed) or 'nothing'}")
    others = subprocess.run(["grep", "-rlF", "-e", "\n".join(o.split("//")[1] for o in swaps), "assets"],
                            cwd=ROOT, capture_output=True, text=True).stdout.split()
    if others:
        print("old ids still in (export these from Studio after tools/ui_margin.luau):", ", ".join(others))


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("plan")
    p.add_argument("--frag", default=ui_lint.FRAG)
    p.add_argument("--out", required=True)
    p.add_argument("--only")
    p.add_argument("--skip", help="regex of files to leave out")
    p.add_argument("--dry", action="store_true", help="print the plan, write nothing")
    p.set_defaults(fn=plan)
    q = sub.add_parser("ids")
    q.add_argument("plan")
    q.add_argument("uploads")
    q.add_argument("--luau", required=True)
    q.set_defaults(fn=ids)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
