"""Builds the spear (qiang) and exports it for Roblox.

Run inside Blender: exec(compile(open(p).read(), p, "exec"), {"__file__": p, "__name__": "__main__"}).
Builds into its own scene "Spear" and copies itself into the "Review" lineup scene if it exists.

Units and axes: 1 Blender unit = 1 stud (art/rig/rig_preview.py has the R6 measurements and the
FBX/Roblox mapping). Origin = the primary (right-hand) grip; +Z runs up the shaft to the blade,
X is edge to edge (+X is the edge turned forward in the hand), Y is flat to flat. A long, slim
wooden shaft (the set's longest piece), a double-edged leaf blade with a raised centre ridge, a
bronze socket with a lip ring and a small disc, the big red horse-hair plume (hongying) under
the blade, indigo cord wraps where the hands go, and a bronze butt cap.

The right hand sits toward the butt, about a quarter of the way up, as on the source SpearRig
(the Spear1-4 clips put the left hand 0.3-2.2 studs further up the shaft, and slide the shaft
through the grip on the thrusts).

Exports Spear.fbx, Spear.json (tris/centre/size in Blender axes + anchors) and Spear.blend.
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

NAME = "Spear"
RENDER_PREVIEWS = True

# --- proportions (studs, z from the right-hand grip) -------------------------------------
BUTT_Z = -2.3             # bottom of the butt cap
SHAFT_TOP = 4.75          # shaft runs into the socket here
R_BUTT, R_TOP = 0.11, 0.085   # slim, tapering toward the blade (thinner than the guandao's 0.12)
SIDES = 8
GRIP_Z = 0.0              # right hand: about a quarter of the way up from the butt
GRIP_ROLL = rp.EDGE_FORWARD_ROLL   # an edge (+X) forward, flats to the sides
OFF_GRIP_Z = 1.5          # left hand, further up the shaft toward the blade
WRAP_HALF = 0.42
WRAP_BANDS = 5
SOCKET_Z0, SOCKET_Z1 = 4.55, 5.05   # bronze socket (the blade's tang sleeve)
BLADE_ROOT = 5.0
BLADE_LEN = 1.4           # socket to tip; total ~8.7, a head longer than the guandao
BLADE_W = 0.22             # half width at the widest point of the leaf
BLADE_WIDEST = 0.3        # where the leaf is widest, as a fraction of its length
BLADE_T = 0.06            # half thickness at the ridge
BUTT_CAP = 0.32
TASSEL_TOP = SOCKET_Z0 + 0.05
TASSEL_LEN = 0.85         # the plume hangs this far down the shaft
TASSEL_R = 0.34           # plume radius at its fullest
TASSEL_LOBES = 7          # clumps round the plume, so it reads as hair, not a cone

PARTS = {"SpearBlade": "steel", "SpearFittings": "bronze", "SpearShaft": "wood",
         "SpearWrap": "cord", "SpearTassel": "red"}
N_STATIONS = 10


def radius(z):
    t = (z - BUTT_Z) / (SHAFT_TOP - BUTT_Z)
    return R_BUTT + (R_TOP - R_BUTT) * t


def blade_half_width(t):
    """Leaf outline: swells quickly to BLADE_WIDEST, then a long straight-ish taper to the point."""
    if t <= BLADE_WIDEST:
        u = t / BLADE_WIDEST
        return 0.06 + (BLADE_W - 0.06) * math.sin(u * math.pi / 2)
    u = (t - BLADE_WIDEST) / (1 - BLADE_WIDEST)
    return BLADE_W * (1 - u ** 1.25)


def blade():
    bm = bmesh.new()
    path = [(0.0, BLADE_ROOT + BLADE_LEN * i / (N_STATIONS - 1)) for i in range(N_STATIONS)]

    def section(i, t):
        if i == N_STATIONS - 1:
            return [(0.0, 0.0)]
        w = blade_half_width(t)
        th = BLADE_T * (1 - 0.7 * t) + 0.012
        # diamond: two edges (+-X) and the raised ridge on each flat (+-Y)
        return [(w, 0.0), (0.0, th), (-w, 0.0), (0.0, -th)]

    rp.blade_along(bm, path, section)
    return bm


def fittings():
    bm = bmesh.new()
    r = radius(SHAFT_TOP)
    # socket: a turned sleeve that flares into a lip ring under the blade, a small disc below
    rp.lathe(bm, [(SOCKET_Z0, r + 0.015), (SOCKET_Z0 + 0.04, r + 0.05), (SOCKET_Z0 + 0.09, r + 0.05),
                  (SOCKET_Z0 + 0.12, r + 0.03), (SOCKET_Z1 - 0.14, r + 0.025), (SOCKET_Z1 - 0.09, r + 0.065),
                  (SOCKET_Z1 - 0.04, r + 0.065), (SOCKET_Z1, r * 0.7)], SIDES)
    # butt cap (zun): a short ferrule ending in a blunt point
    rb = radius(BUTT_Z) + 0.025
    rp.lathe(bm, [(BUTT_Z, 0.0), (BUTT_Z + 0.06, rb * 0.7), (BUTT_Z + 0.14, rb), (BUTT_Z + BUTT_CAP - 0.05, rb),
                  (BUTT_Z + BUTT_CAP - 0.03, rb + 0.02), (BUTT_Z + BUTT_CAP, rb + 0.02),
                  (BUTT_Z + BUTT_CAP + 0.01, radius(BUTT_Z + BUTT_CAP) + 0.005)], SIDES)
    return bm


def shaft():
    bm = bmesh.new()
    zs = [BUTT_Z + BUTT_CAP - 0.02, GRIP_Z, SHAFT_TOP]
    rp.loft(bm, [rp.ring(bm, z, radius(z), radius(z), SIDES, math.pi / SIDES) for z in zs])
    return bm


def wraps():
    bm = bmesh.new()
    for zc in (GRIP_Z, OFF_GRIP_Z):
        r = radius(zc) + 0.02
        rp.cord_grip(bm, zc - WRAP_HALF, zc + WRAP_HALF, r, r, WRAP_BANDS, SIDES)
    return bm


def tassel():
    # the red horse-hair plume: tied tight under the socket, bursting out and hanging down the
    # shaft in clumps (a lobed lathe: every other ring point pushed out)
    bm = bmesh.new()
    n = TASSEL_LOBES * 2
    r0 = radius(TASSEL_TOP) + 0.02
    prof = [  # (z, mean radius, lobe depth), bottom to top: flares out and hangs, fullest low down
        (TASSEL_TOP - TASSEL_LEN + 0.02, r0 + 0.04, 0.0),
        (TASSEL_TOP - TASSEL_LEN, TASSEL_R * 0.8, 0.45),
        (TASSEL_TOP - TASSEL_LEN * 0.8, TASSEL_R, 0.35),
        (TASSEL_TOP - TASSEL_LEN * 0.45, TASSEL_R * 0.75, 0.25),
        (TASSEL_TOP - 0.15, r0 + 0.1, 0.1),
        (TASSEL_TOP - 0.06, r0 + 0.05, 0.0),
        (TASSEL_TOP, r0, 0.0),
    ]
    rings = []
    for z, rm, lobe in prof:
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n
            rr = rm * (1 + lobe * (0.5 if i % 2 == 0 else -0.5))
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)))
        rings.append(ring)
    rp.loft(bm, rings)
    # the tie band that gathers it
    rp.lathe(bm, [(TASSEL_TOP - 0.1, r0 + 0.03), (TASSEL_TOP, r0 + 0.03)], SIDES)
    return bm


def build():
    makers = {"SpearBlade": blade, "SpearFittings": fittings, "SpearShaft": shaft,
              "SpearWrap": wraps, "SpearTassel": tassel}
    return [rp.finish(n, makers[n](), rp.PALETTE[c]) for n, c in PARTS.items()]


def anchors():
    return {
        "grip": dict(pos=[0, 0, GRIP_Z], roll=GRIP_ROLL, dir=[0, 0, 1], up=[1, 0, 0],
                     note="right hand (RightGripAttachment) on the lower wrap; shaft along +Z, an edge (+X) turned forward"),
        "off_grip": dict(pos=[0, 0, OFF_GRIP_Z], roll=GRIP_ROLL, note="left hand on the upper wrap, toward the blade"),
        "tip": dict(pos=[0, 0, BLADE_ROOT + BLADE_LEN], note="blade point (trail/impact effects)"),
        "blade_mid": dict(pos=[0, 0, BLADE_ROOT + BLADE_LEN * 0.35], note="widest part of the leaf"),
        "butt": dict(pos=[0, 0, BUTT_Z]),
    }


def previews(scene, objs):
    return rp.standard_previews(scene, objs, OUT_DIR, "spear", detail_z=BLADE_ROOT, detail_dist=3.2,
                                grip=anchors()["grip"])


if __name__ == "__main__":
    rp.item_main(NAME, OUT_DIR, build, anchors,
                 "1 Blender unit = 1 stud; Z along the shaft (blade +Z), X edge to edge; origin = the right-hand grip",
                 previews=previews, render_previews=RENDER_PREVIEWS)
