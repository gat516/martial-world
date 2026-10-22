#!/usr/bin/env python3
"""Splice named groups from an Effects export into assets/Effects.rbxm.

    python3 tools/effects_merge.py <export.rbxm> <Group> [Group ...]

Lets several vfx agents work in parallel, each in its own sandbox. A sandbox's
export holds the whole Effects folder as it was when that sandbox opened, so
copying it over assets/Effects.rbxm (what vfx_export.sh does) would throw away
groups another agent shipped since. This takes only the named groups
(`Effects.<Group>`) from the export and replaces or adds them in the current
assets/Effects.rbxm, leaving every other group as it is on disk. Attributes and
tags survive (the round trip goes through rojo's rbxmx).

Export with a name of your own so agents don't overwrite each other's file:
PostAsync("http://127.0.0.1:8766/Effects_<Group>.rbxm", _G.exportRbxm(...))
lands in tools/frag/Effects_<Group>.rbxm. Then run this, then
`tools/vfx_export.sh --check <names>` is not needed: this prints the groups and
fails if a named group is missing from the export.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.environ.get("EFFECTS_TARGET") or os.path.join(ROOT, "assets", "Effects.rbxm")
ROJO = os.path.expanduser("~/.rokit/bin/rojo")


def to_xml(rbxm, tmp, tag):
    proj = os.path.join(tmp, tag + ".project.json")
    out = os.path.join(tmp, tag + ".rbxmx")
    json.dump({"name": "Effects", "tree": {"$path": os.path.abspath(rbxm)}}, open(proj, "w"))
    subprocess.run([ROJO, "build", proj, "-o", out], check=True, capture_output=True)
    return ET.parse(out)


def name_of(item):
    n = item.find("Properties/string[@name='Name']")
    return n.text if n is not None else None


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src, groups = sys.argv[1], sys.argv[2:]
    with tempfile.TemporaryDirectory() as tmp:
        base = to_xml(TARGET, tmp, "base")
        frag = to_xml(src, tmp, "frag")
        broot, froot = base.getroot().find("Item"), frag.getroot().find("Item")

        # Referents must stay unique: prefix the export's, Ref values included.
        for el in frag.getroot().iter():
            if el.tag == "Item" and "referent" in el.attrib:
                el.attrib["referent"] = "M" + el.attrib["referent"]
            elif el.tag == "Ref" and el.text and el.text.strip() not in ("", "null"):
                el.text = "M" + el.text.strip()

        fgroups = {name_of(i): i for i in froot.findall("Item")}
        missing = [g for g in groups if g not in fgroups]
        if missing:
            sys.exit("not in the export: " + " ".join(missing))
        for g in groups:
            old = [i for i in broot.findall("Item") if name_of(i) == g]
            idx = list(broot).index(old[0]) if old else len(list(broot))
            for i in old:
                broot.remove(i)
            broot.insert(idx, fgroups[g])
            print(("replaced " if old else "added ") + g)

        # Mesh and other shared data lives in SharedStrings, keyed by hash.
        fshared = frag.getroot().find("SharedStrings")
        if fshared is not None:
            bshared = base.getroot().find("SharedStrings")
            if bshared is None:
                bshared = ET.SubElement(base.getroot(), "SharedStrings")
            have = {s.attrib.get("md5") for s in bshared}
            for s in fshared:
                if s.attrib.get("md5") not in have:
                    bshared.append(s)

        merged = os.path.join(tmp, "merged.rbxmx")
        base.write(merged, encoding="utf-8", xml_declaration=False)
        proj = os.path.join(tmp, "merged.project.json")
        json.dump({"name": "Effects", "tree": {"$path": merged}}, open(proj, "w"))
        out = os.path.join(tmp, "Effects.rbxm")
        subprocess.run([ROJO, "build", proj, "-o", out], check=True, capture_output=True)
        # the temp dir may be on another filesystem (WSL /tmp): copy next to
        # the target first, then swap atomically
        staged = TARGET + ".merging"
        shutil.copyfile(out, staged)
        os.replace(staged, TARGET)
    print("groups now:", " ".join(name_of(i) for i in broot.findall("Item")))
    print("wrote assets/Effects.rbxm")


if __name__ == "__main__":
    main()
