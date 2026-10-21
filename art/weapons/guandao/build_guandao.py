"""Builds the halberd (guandao-style crescent-blade polearm) and exports it for Roblox.

Run inside Blender: exec(compile(open(p).read(), p, "exec"), {"__file__": p, "__name__": "__main__"}).
Builds into its own scene "Guandao" and copies itself into the "Review" lineup scene if it exists.

Units and axes: 1 Blender unit = 1 stud (art/rig/rig_preview.py has the R6 measurements and the
FBX/Roblox mapping). Origin = the primary (right-hand) grip; +Z runs up the shaft to the blade,
+X is the blade's cutting edge, Y is flat to flat. A broad single-edged crescent blade whose tip
sweeps back, a bronze collar with a red horse-hair tassel, a back spur, a wooden shaft with cord
wraps where the hands go, and a bronze butt spike.

Exports Guandao.fbx, Guandao.json (tris/centre/size in Blender axes + anchors) and Guandao.blend.
"""
import importlib
import math
import os
import sys

import bmesh
from mathutils import Vector

OUT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else ""
sys.path.insert(0, os.path.join(OUT_DIR, "..", "..", "rig"))
import rig_preview as rp  # noqa: E402
importlib.reload(rp)

NAME = "Guandao"
RENDER_PREVIEWS = True

# --- proportions (studs, z from the right-hand grip) -------------------------------------
BUTT_Z = -2.1             # bottom of the butt spike
SHAFT_TOP = 3.2           # shaft runs into the collar here
SHAFT_R = 0.12
SIDES = 8
GRIP_Z = 1.5              # right hand on the upper wrap, a bit below the middle (1.66): the blade end is longer
GRIP_ROLL = rp.EDGE_FORWARD_ROLL   # cutting edge (+X) forward
OFF_GRIP_Z = 0.0          # left hand on the lower wrap, toward the butt
WRAP_HALF = 0.42
COLLAR_Z0, COLLAR_Z1 = 3.05, 3.5   # bronze dragon-mouth collar
BLADE_ROOT = 3.42
BLADE_LEN = 2.0           # collar to tip; total ~7.5 with the shaft, the set's tallest piece
BLADE_EDGE_W = 0.52       # edge-side bulge at its widest (the crescent)
BLADE_BACK_W = 0.13       # back (spine) side of the centre line
BLADE_SWEEP = 0.42        # how far the tip curls back toward -X
BLADE_T = 0.065           # half thickness at the ridge
TASSEL_LEN = 0.65

PARTS = {"GuandaoBlade": "steel", "GuandaoFittings": "bronze", "GuandaoShaft": "wood",
         "GuandaoWrap": "cord", "GuandaoTassel": "red"}
N_STATIONS = 12


def blade_path():
    return [(-BLADE_SWEEP * (i / (N_STATIONS - 1)) ** 2.4, BLADE_ROOT + BLADE_LEN * i / (N_STATIONS - 1))
            for i in range(N_STATIONS)]


def blade_section(i, t):
    if i == N_STATIONS - 1:
        return [(-0.02, 0.0)]
    e = BLADE_EDGE_W * (0.6 + 0.4 * math.sin(math.pi * min(1.0, t * 1.25) ** 0.9)) * (1 - t ** 3) + 0.03
    b = BLADE_BACK_W * (1 - t ** 1.6) + 0.02
    th = BLADE_T * (1 - 0.6 * t)
    ridge = -b + (e + b) * 0.42
    return [(e, 0.0), (ridge, th), (-b, th * 0.8), (-b, -th * 0.8), (ridge, -th)]


def blade():
    bm = bmesh.new()
    rp.blade_along(bm, blade_path(), blade_section)
    # back spur: a short hooked fin off the spine, just above the collar
    z = BLADE_ROOT + 0.32
    b = BLADE_BACK_W + 0.02
    pts = [(-b + 0.02, z - 0.05), (-b - 0.22, z + 0.06), (-b - 0.30, z + 0.22), (-b - 0.12, z + 0.12), (-b + 0.02, z + 0.2)]
    top = [bm.verts.new((x, -0.035, zz)) for x, zz in pts]
    bot = [bm.verts.new((x, 0.035, zz)) for x, zz in pts]
    rp.loft(bm, [top, bot])
    return bm


def fittings():
    bm = bmesh.new()
    # dragon-mouth collar: a bulb that swallows the blade root, with a lip ring
    rp.lathe(bm, [(COLLAR_Z0, SHAFT_R + 0.02), (COLLAR_Z0 + 0.06, SHAFT_R + 0.06), (COLLAR_Z0 + 0.1, SHAFT_R + 0.04),
                  (COLLAR_Z0 + 0.22, SHAFT_R + 0.11), (COLLAR_Z1 - 0.06, SHAFT_R + 0.09), (COLLAR_Z1, SHAFT_R + 0.03)],
             SIDES, sy=0.8)
    # butt spike (zun)
    rp.lathe(bm, [(BUTT_Z, 0.0), (BUTT_Z + 0.32, SHAFT_R * 0.75), (BUTT_Z + 0.4, SHAFT_R + 0.05),
                  (BUTT_Z + 0.52, SHAFT_R + 0.05), (BUTT_Z + 0.56, SHAFT_R + 0.01)], SIDES)
    return bm


def shaft():
    bm = bmesh.new()
    rp.loft(bm, [rp.ring(bm, z, SHAFT_R, SHAFT_R, SIDES, math.pi / SIDES) for z in (BUTT_Z + 0.5, SHAFT_TOP)])
    return bm


def wraps():
    bm = bmesh.new()
    for zc in (GRIP_Z, OFF_GRIP_Z):   # one wrap under each hand
        rp.cord_grip(bm, zc - WRAP_HALF, zc + WRAP_HALF, SHAFT_R + 0.02, SHAFT_R + 0.02, 5, SIDES)
    return bm


def tassel():
    # a red horse-hair plume hanging from under the collar, all round the shaft
    bm = bmesh.new()
    z = COLLAR_Z0 + 0.04
    r = SHAFT_R + 0.03
    rp.lathe(bm, [(z - TASSEL_LEN, SHAFT_R + 0.02), (z - TASSEL_LEN + 0.02, r + 0.17), (z - TASSEL_LEN * 0.45, r + 0.12),
                  (z - 0.05, r + 0.04), (z, r)], 10)
    return bm


def build():
    makers = {"GuandaoBlade": blade, "GuandaoFittings": fittings, "GuandaoShaft": shaft,
              "GuandaoWrap": wraps, "GuandaoTassel": tassel}
    return [rp.finish(n, makers[n](), rp.PALETTE[c]) for n, c in PARTS.items()]


def anchors():
    tip = blade_path()[-1]
    return {
        "grip": dict(pos=[0, 0, GRIP_Z], roll=GRIP_ROLL, dir=[0, 0, 1], up=[1, 0, 0],
                     note="right hand (RightGripAttachment) on the upper wrap; shaft along +Z, cutting edge +X turned forward"),
        "off_grip": dict(pos=[0, 0, OFF_GRIP_Z], roll=GRIP_ROLL, note="left hand on the lower wrap, toward the butt"),
        "tip": dict(pos=[tip[0], 0, tip[1]]),
        "blade_mid": dict(pos=[BLADE_EDGE_W * 0.6, 0, BLADE_ROOT + BLADE_LEN * 0.45], note="middle of the cutting edge"),
        "butt": dict(pos=[0, 0, BUTT_Z]),
    }


def previews(scene, objs):
    return rp.standard_previews(scene, objs, OUT_DIR, "guandao", detail_z=BLADE_ROOT + 0.8, detail_dist=4.0,
                                grip=anchors()["grip"])


if __name__ == "__main__":
    rp.item_main(NAME, OUT_DIR, build, anchors,
                 "1 Blender unit = 1 stud; Z along the shaft (blade +Z), X toward the cutting edge; origin = build origin, right hand at the grip anchor",
                 previews=previews, render_previews=RENDER_PREVIEWS)
