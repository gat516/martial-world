"""Writes the MESHES and KINDS blocks of place_karst.luau from Karst.json (run after build_karst.py exports).

  python3 art/karst/gen_blocks.py
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
rep = json.load(open(os.path.join(HERE, "Karst.json")))
lua_path = os.path.join(HERE, "place_karst.luau")
src = open(lua_path).read()


def num(x):
    return ("%.3f" % x).rstrip("0").rstrip(".")


meshes = ["local MESHES = {"]
for name, m in rep["meshes"].items():
    meshes.append("\t%s = { size = { %s }, center = { %s }, tris = %d }," % (
        name, ", ".join(num(v) for v in m["size"]), ", ".join(num(v) for v in m["center"]), m["tris"]))
meshes.append("}")
kinds = ["local KINDS = {"]
for name, k in rep["kinds"].items():
    legs = ", ".join("{ x = %s, y = %s, h = %s, r0 = %s, rtop = %s }" % (
        num(l["x"]), num(l["y"]), num(l["h"]), num(l["r0"]), num(l["rtop_out"])) for l in k["legs"])
    ledges = ", ".join("{ x = %s, y = %s, z = %s, r = %s }" % (
        num(l["x"]), num(l["y"]), num(l["z"]), num(l["r"])) for l in k["ledges"])
    trees = ", ".join('{ "%s", %s, %s, %s, %s }' % (t["kind"], num(t["x"]), num(t["y"]), num(t["z"]), num(t["s"]))
                      for t in k["trees"])
    kinds.append("\t%s = {\n\t\tlegs = { %s },\n\t\tledges = { %s },\n\t\ttrees = { %s },\n\t}," % (
        name, legs, ledges, trees))
kinds.append("}")


def put(src, tag, body):
    pat = re.compile(r"(-- BEGIN %s[^\n]*\n).*?(\n-- END %s)" % (tag, tag), re.S)
    assert pat.search(src), tag
    return pat.sub(lambda m: m.group(1) + body + m.group(2), src)


src = put(src, "MESHES", "\n".join(meshes))
src = put(src, "KINDS", "\n".join(kinds))
open(lua_path, "w").write(src)
print("kit tris", rep["kit_tris"], "meshes", len(rep["meshes"]))
