"""Writes the MESHES block of place_spirit_wolf.luau from SpiritWolf.json (python3 gen_place_block.py)."""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
data = json.load(open(os.path.join(HERE, "SpiritWolf.json")))
lines = ["local MESHES = {"]
for name, m in data["meshes"].items():
    c = ", ".join("%g" % v for v in m["roblox_center"])
    s = ", ".join("%g" % v for v in m["roblox_size"])
    lines.append("\t%s = { center = { %s }, size = { %s }, tris = %d, textured = %s },"
                 % (name, c, s, m["tris"], "true" if m["textured"] else "false"))
lines.append("}")
p = os.path.join(HERE, "place_spirit_wolf.luau")
src = open(p).read()
src = re.sub(r"(-- BEGIN MESHES[^\n]*\n).*?(\n-- END MESHES)", lambda mo: mo.group(1) + "\n".join(lines) + mo.group(2),
             src, flags=re.S)
open(p, "w").write(src)
print("wrote", len(data["meshes"]), "meshes,", data["total_tris"], "tris")
