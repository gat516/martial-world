r"""Ear seating close-ups: the three fox ear sets side by side, one R6 head each, shot at eye level
just above the head top all round each ear base (where a gap between ear and head would show).

Run through the Blender MCP after build_fox.py has built the ear sets:
    P = r"\\wsl.localhost\Ubuntu\home\cj\roblox\martial-world-fox-v2\art\player\cosmetics\fox\seat_sheet.py"
    exec(compile(open(P).read(), P, "exec"), {"__file__": P})
It lays the sets out with tools/blender_lineup.py (a "Lineup" scene of collection instances; the
sets themselves aren't moved), renders renders/seat_<Set>_<view>.png, then puts the window back
on the Cosmetics scene. Stitch with `make_sheet.py seat`.
"""
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "art", "rig"))
import rig_preview as rp  # noqa: E402

SETS = ["FoxEarsBroad", "FoxEarsSleek", "FoxEarsLong"]
SPACING = 6.0
EYE_Z = 3.16          # just above the head top (3.1)
DIST = 1.35
# (name, which ear: +1 left / -1 right, eye direction from the ear base (x is mirrored for the right))
VIEWS = [("out_side", 1, (1, 0.05, 0)), ("out_back", 1, (0.7, 1, 0)), ("back", 1, (0.15, 1, 0)),
         ("out_front", 1, (0.7, -1, 0)), ("front", 1, (0.15, -1, 0)), ("right_out", -1, (1, 0.3, 0))]
BASE = Vector((0.45, 0.1, 3.02))   # the left ear's base, about (the right ear is mirrored)
LINEUP = os.path.join(os.path.dirname(REPO), "martial-world-race-cosmetics", "tools", "blender_lineup.py")


def main():
    home = bpy.context.window.scene
    looks = [[[s] for s in SETS]]
    exec(compile(open(LINEUP).read(), LINEUP, "exec"), {"LOOKS": looks, "SPACING": SPACING, "SCENE": "Lineup"})
    scene = bpy.data.scenes["Lineup"]
    rp.setup_render(scene, res=(360, 360))
    width = (len(SETS) - 1) * SPACING
    out = os.path.join(HERE, "renders")
    shots = []
    for c, name in enumerate(SETS):
        off = Vector((c * SPACING - width / 2, 0, 0))
        for view, side, d in VIEWS:
            base = Vector((BASE.x * side, BASE.y, BASE.z)) + off
            dv = Vector((d[0] * side, d[1], d[2])).normalized()
            eye = Vector((base.x, base.y, EYE_Z)) + dv * DIST
            eye.z = EYE_Z
            path = os.path.join(out, "seat_%s_%s.png" % (name, view))
            shots.append(rp.render(scene, path, tuple(eye), tuple(base), lens=40))
    # whole lineup at game distance from behind, for the read
    for view, y in (("back", 1), ("front", -1)):
        eye = Vector((0, 20 * y, 4.0))
        shots.append(rp.render(scene, os.path.join(out, "seat_lineup_%s.png" % view), tuple(eye), (0, 0, 2.0),
                               lens=40))
    bpy.context.window.scene = home
    print(len(shots), "seat tiles")


main()
