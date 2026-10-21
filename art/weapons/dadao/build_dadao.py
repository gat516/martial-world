"""Builds the two-handed saber (dadao) and exports it for Roblox.

Run inside Blender: exec(compile(open(p).read(), p, "exec"), {"__file__": p, "__name__": "__main__"}).
Builds into its own scene "Dadao" and copies itself into the "Review" lineup scene if it exists.

Units and axes: 1 Blender unit = 1 stud (art/rig/rig_preview.py has the R6 measurements and the
FBX/Roblox mapping). Origin = the primary (right-hand) grip, just under the guard; +Z runs up the
blade, +X is the cutting edge, Y is flat to flat. A broad single-edged blade that widens toward a
clipped tip, with a slight backward curve; a round bronze disc guard; a long two-hand cord grip;
a bronze ring pommel with red cloth ties (the dadao's look).

Exports Dadao.fbx, Dadao.json (tris/centre/size in Blender axes + anchors) and Dadao.blend.
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

NAME = "Dadao"
RENDER_PREVIEWS = True

# --- proportions (studs, z from the right-hand grip) -------------------------------------
GRIP_TOP = 0.42           # grip runs from here down to GRIP_BOTTOM
GRIP_BOTTOM = -1.25       # 1.67 long: room for both R6 hands
GRIP_RX, GRIP_RY = 0.13, 0.105
GRIP_Z = -0.1             # right hand centre: the 1-stud R6 hand sits just under the guard (base 0.42)
GRIP_ROLL = rp.EDGE_FORWARD_ROLL   # cutting edge (+X) forward
OFF_GRIP_Z = -0.9         # left hand, toward the ring (the 1.67 grip is a little short of two R6 hands)
GUARD_Z = GRIP_TOP        # disc guard base
GUARD_R = 0.34
GUARD_T = 0.09
BLADE_ROOT = GUARD_Z + GUARD_T + 0.02
BLADE_LEN = 2.9           # the R6 is 5.1 tall; tip to ring ~5.1, ~5.7 with the cloth ties
ROOT_W = 0.36             # blade width at the guard
TIP_W = 0.52              # widest, just before the clipped tip
BACK_CURVE = 0.16         # spine bows back toward -X along the length
BLADE_T = 0.07            # half thickness at the spine
RING_R = 0.17             # ring pommel
N_STATIONS = 10

PARTS = {"DadaoBlade": "steel", "DadaoFittings": "bronze", "DadaoGrip": "cord", "DadaoRibbon": "red"}


def blade_path():
    # the path is the spine; widths are measured toward +X from it. The spine starts half the
    # root width behind the grip axis so the blade's root is centred on the hilt.
    pts = []
    for i in range(N_STATIONS):
        t = i / (N_STATIONS - 1)
        pts.append((-ROOT_W / 2 - BACK_CURVE * t * t, BLADE_ROOT + BLADE_LEN * t))
    return pts


def blade_section(i, t):
    if i == N_STATIONS - 1:
        return [(0.0, 0.0)]                       # the tip sits on the spine: a clipped point
    w = ROOT_W + (TIP_W - ROOT_W) * min(1.0, t / 0.8) ** 1.3
    if t > 0.8:                                   # the clip: edge sweeps up to the spine
        w *= max(0.0, 1 - (t - 0.8) / 0.2) ** 0.8
    w = max(w, 0.04)
    th = BLADE_T * (1 - 0.35 * t)
    return [(w, 0.0), (w * 0.55, th * 0.85), (0.0, th), (0.0, -th), (w * 0.55, -th * 0.85)]


def blade():
    bm = bmesh.new()
    rp.blade_along(bm, blade_path(), blade_section)
    return bm


def fittings():
    bm = bmesh.new()
    # disc guard: a thick oval plate, a step wider at its middle
    rp.lathe(bm, [(GUARD_Z, GUARD_R * 0.9), (GUARD_Z + GUARD_T * 0.35, GUARD_R), (GUARD_Z + GUARD_T * 0.65, GUARD_R),
                  (GUARD_Z + GUARD_T, GUARD_R * 0.9)], 12, sy=0.72)
    # collars above and below the grip
    for z0, z1 in ((GRIP_TOP - 0.08, GRIP_TOP), (GRIP_BOTTOM, GRIP_BOTTOM + 0.08)):
        rp.lathe(bm, [(z0, GRIP_RX + 0.03), (z1, GRIP_RX + 0.03)], 8, sy=GRIP_RY / GRIP_RX)
    # ring pommel: an octagonal ring in the XZ plane under the grip
    zc = GRIP_BOTTOM - RING_R - 0.02
    rings = []
    for k in range(10):
        a = 2 * math.pi * k / 10
        c = Vector((RING_R * math.sin(a), 0, zc + RING_R * math.cos(a)))
        radial = Vector((math.sin(a), 0, math.cos(a)))
        rings.append([bm.verts.new(c + radial * (0.045 * math.cos(b)) + Vector((0, 0.045 * math.sin(b), 0)))
                      for b in (2 * math.pi * j / 6 for j in range(6))])
    for k in range(10):
        a, b = rings[k], rings[(k + 1) % 10]
        for j in range(6):
            jj = (j + 1) % 6
            bm.faces.new((a[j], a[jj], b[jj], b[j]))
    return bm


def grip():
    bm = bmesh.new()
    rp.cord_grip(bm, GRIP_BOTTOM + 0.08, GRIP_TOP - 0.08, GRIP_RX, GRIP_RY, 9)
    return bm


def ribbon():
    # red cloth tied through the ring: a knot and two tails hanging down
    bm = bmesh.new()
    z = GRIP_BOTTOM - 2 * RING_R - 0.04
    rp.box(bm, (0, 0, z + 0.02), (0.12, 0.1, 0.1))
    for sx, ln in ((1, 0.62), (-1, 0.5)):
        a = Vector((sx * 0.04, 0, z - 0.02))
        m = a + Vector((sx * 0.1, 0.0, -ln * 0.5))
        e = m + Vector((sx * 0.03, 0.02, -ln * 0.5))
        rp.strip(bm, a, m, 0.15, 0.02)
        rp.strip(bm, m, e, 0.13, 0.02)
    return bm


def build():
    makers = {"DadaoBlade": blade, "DadaoFittings": fittings, "DadaoGrip": grip, "DadaoRibbon": ribbon}
    return [rp.finish(n, makers[n](), rp.PALETTE[c]) for n, c in PARTS.items()]


def anchors():
    tip, mid = blade_path()[-1], blade_path()[5]
    return {
        "grip": dict(pos=[0, 0, GRIP_Z], roll=GRIP_ROLL, dir=[0, 0, 1], up=[1, 0, 0],
                     note="right hand (RightGripAttachment) just under the guard; blade along +Z, edge +X turned forward"),
        "off_grip": dict(pos=[0, 0, OFF_GRIP_Z], roll=GRIP_ROLL, note="left hand, toward the pommel"),
        "tip": dict(pos=[tip[0], 0, tip[1]]),
        "guard": dict(pos=[0, 0, GUARD_Z + GUARD_T / 2]),
        "blade_mid": dict(pos=[mid[0] + blade_section(5, 5 / (N_STATIONS - 1))[0][0], 0, mid[1]],
                          note="middle of the cutting edge"),
    }


def previews(scene, objs):
    return rp.standard_previews(scene, objs, OUT_DIR, "dadao", detail_z=0.0, detail_dist=3.2,
                                grip=anchors()["grip"])


if __name__ == "__main__":
    rp.item_main(NAME, OUT_DIR, build, anchors,
                 "1 Blender unit = 1 stud; Z along the blade, X toward the cutting edge; origin = build origin, right hand at the grip anchor",
                 previews=previews, render_previews=RENDER_PREVIEWS)
