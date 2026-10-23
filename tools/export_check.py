"""Export round-trip check: does the .rbxmx hold every property the live GUI has?

tools/export_rbxmx.luau writes only the properties in its list that differ from a
fresh instance; anything missing from the list (SizeConstraint, once) or encoded
wrong silently reverts to the default when Rojo builds the file. After an export:

  1. in Studio: run tools/export_rbxmx.luau (if not yet), then tools/export_check.luau
     with _G.EXPORTCHECK = { target = "StarterGui.Hud", name = "Hud" }
  2. python3 tools/export_check.py assets/Hud.rbxmx [--frag DIR] [--root-name Hud]

Compares instance by instance (by name path and order) and FAILs on:
  dropped      a property that differs from the default live but isn't in the file
  changed      a property written with another value than the live one
  unsupported  a live non-default property the exporter has no encoding for
  attribute    an attribute missing from the file or different
  structure    an instance missing from either side
Exit 1 on any FAIL. Properties that never affect a GUI (selection, localization,
capabilities) are skipped on the live side (SKIP in the .luau).
"""

import argparse
import base64
import json
import os
import struct
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAG = os.path.join(ROOT, "tools", "frag")


def norm(el):
    """A property element as comparable text (tag, name, normalized content)."""
    def walk(e):
        text = (e.text or "").strip()
        kids = "".join(walk(c) for c in e)
        return f"<{e.tag}{''.join(f' {k}={v}' for k, v in sorted(e.attrib.items()))}>{text}{kids}</{e.tag}>"
    return walk(el)


def numbers_close(a, b):
    """Compare two normalized property texts, numbers within float noise."""
    import re
    ta, tb = re.split(r"(-?\d+(?:\.\d+)?(?:e-?\d+)?)", a), re.split(r"(-?\d+(?:\.\d+)?(?:e-?\d+)?)", b)
    if len(ta) != len(tb):
        return False
    for x, y in zip(ta, tb):
        if x == y:
            continue
        try:
            if abs(float(x) - float(y)) > 1e-4 * max(1.0, abs(float(x))):
                return False
        except ValueError:
            return False
    return True


def decode_attrs(b64):
    b = base64.b64decode(b64)
    n, = struct.unpack_from("<I", b, 0)
    i, out = 4, {}
    for _ in range(n):
        ln, = struct.unpack_from("<I", b, i)
        key = b[i + 4:i + 4 + ln].decode()
        i += 4 + ln
        t = b[i]
        i += 1
        if t == 0x02:
            ln, = struct.unpack_from("<I", b, i)
            out[key] = b[i + 4:i + 4 + ln].decode()
            i += 4 + ln
        elif t == 0x03:
            out[key] = bool(b[i])
            i += 1
        elif t == 0x06:
            out[key], = struct.unpack_from("<d", b, i)
            i += 8
        else:
            out[key] = f"<type {t}>"
            break
    return out


def file_tree(path, root_name):
    tree = ET.parse(path).getroot()
    items = {}

    def walk(item, p):
        props = item.find("Properties")
        rec = {"class": item.get("class"), "props": {}, "attrs": {}}
        for el in (props if props is not None else []):
            name = el.get("name")
            if name == "AttributesSerialize":
                rec["attrs"] = decode_attrs((el.text or "").strip())
            elif name:
                rec["props"][name] = norm(el)
        items[p] = rec
        seen = {}
        for child in item.findall("Item"):
            cn = child.find("Properties/string[@name='Name']")
            cname = cn.text if cn is not None else "?"
            seen[cname] = seen.get(cname, 0) + 1
            walk(child, f"{p}/{cname}#{seen[cname]}")

    top = tree.find("Item")
    walk(top, f"{root_name}#1")
    return items


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rbxmx")
    ap.add_argument("--frag", default=FRAG)
    ap.add_argument("--name", help="the EXPORTCHECK name (default: the file's stem)")
    ap.add_argument("--root-name", help="the live root's name when the file renames it")
    args = ap.parse_args()
    name = args.name or os.path.splitext(os.path.basename(args.rbxmx))[0]
    live = json.load(open(os.path.join(args.frag, f"exportcheck_{name}.xml")))
    for rec in live.values():  # JSON turns an empty table into []
        rec["props"] = rec["props"] or {}
        rec["attrs"] = rec["attrs"] or {}
    live_root = next(iter(k for k in live if "/" not in k))
    root_name = args.root_name or live_root.split("#")[0]
    # the file's root may be renamed (staging copies, CharacterCreatorGui -> CharacterCreator)
    filed = file_tree(args.rbxmx, root_name)
    fails = []
    for path, rec in live.items():
        f = filed.get(path)
        if f is None:
            fails.append(f"structure  {path}: in Studio, not in the file")
            continue
        for prop, enc in rec["props"].items():
            if prop == "Name" and "/" not in path:
                continue
            if enc.startswith("<unsupported"):
                fails.append(f"unsupported {path}.{prop}: {enc}")
                continue
            if prop not in f["props"]:
                fails.append(f"dropped    {path}.{prop} = {enc[:80]}")
                continue
            try:
                want = norm(ET.fromstring(enc))
            except ET.ParseError:
                want = enc
            if want != f["props"][prop] and not numbers_close(want, f["props"][prop]):
                fails.append(f"changed    {path}.{prop}: live {want[:70]} file {f['props'][prop][:70]}")
        if rec["attrs"] != f["attrs"]:
            fails.append(f"attribute  {path}: live {rec['attrs']} file {f['attrs']}")
    for path in filed:
        if path not in live:
            fails.append(f"structure  {path}: in the file, not in Studio")
    print(f"export_check {args.rbxmx}: {len(live)} instances, {len(fails)} FAIL")
    for line in fails[:200]:
        print("FAIL", line)
    if len(fails) > 200:
        print(f"... {len(fails) - 200} more")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
