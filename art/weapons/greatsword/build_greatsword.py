"""Builds the greatsword (a two-handed straight double-edged sword, the jian's big sibling).

Run inside Blender: exec(compile(open(p).read(), p, "exec"), {"__file__": p, "__name__": "__main__"}).
Builds into its own scene "Greatsword" and copies itself into the "Review" lineup scene if it exists.

Units and axes: 1 Blender unit = 1 stud (art/rig/rig_preview.py has the R6 measurements and the
FBX/Roblox mapping). Origin = the primary (right-hand) grip, just under the guard; +Z runs up the
blade, X is edge to edge, Y is flat to flat. A broad blade with bevelled edges and a centre ridge,
a big cloud guard (the jian's, scaled up), a long two-hand cord grip, a bronze pommel and a tassel.

Exports Greatsword.fbx, Greatsword.json (tris/centre/size in Blender axes + anchors) and
Greatsword.blend.
"""
import importlib
import math
import os
import sys

import bmesh

OUT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else ""
sys.path.insert(0, os.path.join(OUT_DIR, "..", "..", "rig"))
import rig_preview as rp  # noqa: E402
importlib.reload(rp)

NAME = "Greatsword"
RENDER_PREVIEWS = True

# --- proportions (studs, z from the right-hand grip) -------------------------------------
GRIP_TOP = 0.42
GRIP_BOTTOM = -1.2        # 1.62 long, two hands
GRIP_RX, GRIP_RY = 0.135, 0.11
GRIP_Z = -0.1             # right hand centre: the 1-stud R6 hand sits just under the guard (base 0.42)
GRIP_ROLL = rp.EDGE_FORWARD_ROLL   # an edge forward
OFF_GRIP_Z = -0.9         # left hand, toward the pommel
GUARD_Z = GRIP_TOP
GUARD_HALF_W = 0.62
GUARD_THICK = 0.30
GUARD_HEIGHT = 1.35       # the jian's guard profile, stretched taller
BLADE_ROOT = GUARD_Z + 0.27
BLADE_LEN = 3.5           # whole sword ~5.6, a touch over the R6's height
ROOT_HALF_W = 0.27        # 0.54 wide: reads as "great" next to the jian's 0.30
TIP_HALF_W = 0.22
BLADE_HALF_T = 0.075
BEVEL = 0.62              # edge bevel starts this far out from the ridge (fraction of half width)
TIP_LEN = 0.5
POMMEL_LEN = 0.28
TASSEL_ON = True

PARTS = {"GreatswordBlade": "steel", "GreatswordFittings": "bronze", "GreatswordGrip": "cord",
         "GreatswordTassel": "red"}


def blade():
    bm = bmesh.new()
    tip = BLADE_ROOT + BLADE_LEN
    z1 = tip - TIP_LEN
    stations = [(BLADE_ROOT - 0.12, ROOT_HALF_W, BLADE_HALF_T), (BLADE_ROOT + 0.4, ROOT_HALF_W * 0.98, BLADE_HALF_T),
                (z1, TIP_HALF_W, BLADE_HALF_T * 0.85), (z1 + TIP_LEN * 0.55, TIP_HALF_W * 0.6, BLADE_HALF_T * 0.6)]
    rings = []
    for z, w, t in stations:
        # edge, bevel shoulder, ridge, bevel shoulder, edge, ... (8 points, flat bevelled faces)
        b = w * BEVEL
        pts = [(w, 0), (b, t * 0.8), (0, t), (-b, t * 0.8), (-w, 0), (-b, -t * 0.8), (0, -t), (b, -t * 0.8)]
        rings.append([bm.verts.new((x, y, z)) for x, y in pts])
    rings.append([bm.verts.new((0, 0, tip))])
    rp.loft(bm, rings, cap_end=False)
    return bm


def fittings():
    bm = bmesh.new()
    rp.cloud_guard(bm, GUARD_Z, GUARD_HALF_W, GUARD_THICK, GUARD_HEIGHT, lobe=0.12)
    rp.lathe(bm, [(GRIP_TOP - 0.09, GRIP_RX + 0.02), (GRIP_TOP - 0.08, GRIP_RX + 0.04), (GRIP_TOP + 0.02, GRIP_RX + 0.04)],
             8, GRIP_RY / GRIP_RX)
    pz = GRIP_BOTTOM
    rp.lathe(bm, [(pz - POMMEL_LEN, 0.0), (pz - POMMEL_LEN + 0.03, 0.12), (pz - POMMEL_LEN + 0.09, 0.22),
                  (pz - 0.1, 0.22), (pz - 0.05, 0.16), (pz + 0.01, GRIP_RX + 0.02)], 8, 0.75)
    return bm


def grip():
    bm = bmesh.new()
    rp.cord_grip(bm, GRIP_BOTTOM, GRIP_TOP, GRIP_RX, GRIP_RY, 10)
    return bm


def tassel():
    bm = bmesh.new()
    rp.tassel(bm, GRIP_BOTTOM - POMMEL_LEN + 0.03, cord=0.26, length=0.5, scale=1.25)
    return bm


def build():
    makers = {"GreatswordBlade": blade, "GreatswordFittings": fittings, "GreatswordGrip": grip,
              "GreatswordTassel": tassel}
    return [rp.finish(n, makers[n](), rp.PALETTE[c]) for n, c in PARTS.items() if n != "GreatswordTassel" or TASSEL_ON]


def anchors():
    tip = BLADE_ROOT + BLADE_LEN
    return {
        "grip": dict(pos=[0, 0, GRIP_Z], roll=GRIP_ROLL, dir=[0, 0, 1],
                     note="right hand (RightGripAttachment) just under the guard; blade along +Z, an edge turned forward"),
        "off_grip": dict(pos=[0, 0, OFF_GRIP_Z], roll=GRIP_ROLL, note="left hand, toward the pommel"),
        "tip": dict(pos=[0, 0, tip]),
        "guard": dict(pos=[0, 0, GUARD_Z + 0.1]),
        "blade_mid": dict(pos=[0, 0, (BLADE_ROOT + tip) / 2]),
        "tassel_mount": dict(pos=[0, 0, GRIP_BOTTOM - POMMEL_LEN + 0.03]),
    }


def previews(scene, objs):
    return rp.standard_previews(scene, objs, OUT_DIR, "greatsword", detail_z=0.1, detail_dist=3.4,
                                grip=anchors()["grip"])


if __name__ == "__main__":
    rp.item_main(NAME, OUT_DIR, build, anchors,
                 "1 Blender unit = 1 stud; Z along the blade, X edge to edge, Y flat to flat; origin = build origin, right hand at the grip anchor",
                 previews=previews, render_previews=RENDER_PREVIEWS)
