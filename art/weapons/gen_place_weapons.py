"""Regenerates the MESHES block of art/weapons/place_weapons.luau from the items' bounds JSONs.

Run from anywhere with plain python3 (no Blender needed): python3 art/weapons/gen_place_weapons.py
Mesh centres/sizes stay in Blender axes (the Luau side converts); anchors are written in the
model's Roblox space (the JSON's `roblox` value, relative to the pivot), plus `roll` (degrees
about the item axis, Roblox +Y) where the JSON has one: the grip's roll turns the edge forward.
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ITEMS = {
    "Jian": "jian/Jian.json",
    "Staff": "staff/Staff.json",
    "Guandao": "guandao/Guandao.json",
    "Spear": "spear/Spear.json",
    "Dadao": "dadao/Dadao.json",
    "Greatsword": "greatsword/Greatsword.json",
    "Zither": "zither/Zither.json",
    "Dizi": "dizi/Dizi.json",
    "SpiritStone": "../items/spirit_stone/SpiritStone.json",
    "ManualScroll": "../items/manual_scroll/ManualScroll.json",
}


def vec(v):
    return "{ " + ", ".join(f"{x:g}" for x in v) + " }"


def main():
    lines = ["local ITEMS = {"]
    for item, rel in ITEMS.items():
        with open(os.path.join(HERE, rel)) as fh:
            d = json.load(fh)
        lines.append(f"\t{item} = {{")
        lines.append("\t\tmeshes = {")
        for name, m in d["meshes"].items():
            lines.append(f"\t\t\t{name} = {{ center = {vec(m['center'])}, size = {vec(m['size'])}, tris = {m['tris']} }},")
        lines.append("\t\t},")
        lines.append("\t\tanchors = {")
        for name, a in d["anchors"].items():
            pos = a.get("roblox") or [a["pos"][0], a["pos"][2], -a["pos"][1]]
            roll = f", roll = {a['roll']:g}" if a.get("roll") else ""
            lines.append(f"\t\t\t{name} = {{ {', '.join(f'{x:g}' for x in pos)}{roll} }},")
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    path = os.path.join(HERE, "place_weapons.luau")
    with open(path) as fh:
        src = fh.read()
    block = "\n".join(lines)
    src, n = re.subn(r"(-- BEGIN MESHES[^\n]*\n).*?(\n-- END MESHES)", lambda m: m.group(1) + block + m.group(2), src, flags=re.S)
    assert n == 1, "MESHES markers not found"
    with open(path, "w") as fh:
        fh.write(src)
    print("wrote", len(ITEMS), "items")


if __name__ == "__main__":
    main()
