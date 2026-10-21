"""Builds the staff (gun) and exports it for Roblox.

Run inside Blender: exec(compile(open(p).read(), p, "exec"), {"__file__": p, "__name__": "__main__"}).
Builds into its own scene "Staff" and copies itself into the "Review" lineup scene if it exists.

Units and axes: 1 Blender unit = 1 stud (art/rig/rig_preview.py has the R6 measurements and the
FBX/Roblox mapping). Origin = the primary (right-hand) grip; +Z runs up the staff to its head
end, the off-hand grip is further up +Z. A plain hardwood staff, a little thicker at the butt,
bronze caps at both ends, indigo cord wraps where the hands go, a red ribbon under the head cap.

Exports Staff.fbx, Staff.json (tris/centre/size in Blender axes + anchors) and Staff.blend.
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

NAME = "Staff"
RENDER_PREVIEWS = True

# --- proportions (studs, z from the right-hand grip) -------------------------------------
BUTT_Z, HEAD_Z = -2.0, 4.1      # 6.1 long: a head taller than the 5.1 R6, like a real gun
R_BUTT, R_HEAD = 0.14, 0.115    # tapers toward the head
SIDES = 8
CAP_LEN = 0.28                  # bronze ferrules on both ends
GRIP_Z = 0.8                    # right hand: near the balance point (middle 1.05), a little toward the butt
GRIP_ROLL = 0.0                 # round shaft: no edge to turn
OFF_GRIP_Z = 2.2                # left hand, 1.4 up the shaft toward the head
WRAP_HALF = 0.42                # each cord wrap covers a hand (0.84 long)
WRAP_BANDS = 5
RIBBON_Z = HEAD_Z - CAP_LEN - 0.12   # ribbon tie under the head cap
RIBBON_LEN = 0.75

PARTS = {"StaffShaft": "wood", "StaffFittings": "bronze", "StaffWrap": "cord", "StaffRibbon": "red"}


def radius(z):
    t = (z - BUTT_Z) / (HEAD_Z - BUTT_Z)
    return R_BUTT + (R_HEAD - R_BUTT) * t


def shaft():
    bm = bmesh.new()
    zs = [BUTT_Z + 0.05, 0.0, HEAD_Z - 0.05]
    rp.loft(bm, [rp.ring(bm, z, radius(z), radius(z), SIDES, math.pi / SIDES) for z in zs])
    return bm


def fittings():
    bm = bmesh.new()
    for end, sgn in ((BUTT_Z, 1), (HEAD_Z, -1)):
        r = radius(end) + 0.03
        z0, z1 = end, end + sgn * CAP_LEN
        prof = [(z0, r * 0.75), (z0 + sgn * 0.03, r), (z1 - sgn * 0.08, r), (z1 - sgn * 0.05, r + 0.025),
                (z1, r + 0.025), (z1 + sgn * 0.01, radius(z1) + 0.005)]
        rp.lathe(bm, sorted(prof), SIDES)
    return bm


def wraps():
    bm = bmesh.new()
    for zc in (GRIP_Z, OFF_GRIP_Z):   # one wrap under each hand
        r = radius(zc) + 0.02
        rp.cord_grip(bm, zc - WRAP_HALF, zc + WRAP_HALF, r, r, WRAP_BANDS, SIDES)
    return bm


def ribbon():
    bm = bmesh.new()
    r = radius(RIBBON_Z)
    # the tie: a short band round the shaft, then two tails hanging down and out to the sides
    rp.lathe(bm, [(RIBBON_Z - 0.07, r + 0.03), (RIBBON_Z + 0.07, r + 0.03)], SIDES)
    for sx, ln, sw in ((1, RIBBON_LEN, 0.13), (-1, RIBBON_LEN * 0.8, 0.12)):
        top = Vector((sx * (r + 0.02), -0.03 * sx, RIBBON_Z))
        mid = top + Vector((sx * 0.10, -0.02, -ln * 0.5))
        end = mid + Vector((sx * 0.05, 0.03, -ln * 0.5))
        rp.strip(bm, top, mid, 0.16, 0.02)   # broad face to the front, so the tails read
        rp.strip(bm, mid, end, sw, 0.02)
    return bm


def build():
    makers = {"StaffShaft": shaft, "StaffFittings": fittings, "StaffWrap": wraps, "StaffRibbon": ribbon}
    return [rp.finish(n, makers[n](), rp.PALETTE[c]) for n, c in PARTS.items()]


def anchors():
    return {
        "grip": dict(pos=[0, 0, GRIP_Z], roll=GRIP_ROLL, dir=[0, 0, 1],
                     note="right hand (RightGripAttachment), near the balance point; staff along +Z"),
        "off_grip": dict(pos=[0, 0, OFF_GRIP_Z], roll=GRIP_ROLL, note="left hand, further along the shaft"),
        "head": dict(pos=[0, 0, HEAD_Z], note="striking end (trail/impact effects)"),
        "butt": dict(pos=[0, 0, BUTT_Z], note="butt end"),
    }


def previews(scene, objs):
    return rp.standard_previews(scene, objs, OUT_DIR, "staff", detail_z=HEAD_Z - 0.4, detail_dist=2.4,
                                grip=anchors()["grip"])


if __name__ == "__main__":
    rp.item_main(NAME, OUT_DIR, build, anchors,
                 "1 Blender unit = 1 stud; Z along the staff (head +Z); origin = build origin, right hand at the grip anchor",
                 previews=previews, render_previews=RENDER_PREVIEWS)
