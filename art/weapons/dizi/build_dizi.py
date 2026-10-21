"""Builds the dizi (bamboo transverse flute) and exports it for Roblox.

Run inside Blender: exec(compile(open(p).read(), p, "exec"), {"__file__": p, "__name__": "__main__"}).
Builds into its own scene "Dizi" and copies itself into the "Review" lineup scene if it exists.

Units and axes: 1 Blender unit = 1 stud (art/rig/rig_preview.py has the R6 measurements and the
FBX/Roblox mapping). Origin = the right-hand grip, over the lower three finger holes; +Z runs
along the flute toward the blow hole (the mouth end); the holes face -Y. Played sideways: the
mouth end goes to the player's left, held by the left hand near the mouth and the right further
out. Bamboo with node rings, indigo thread bindings, bronze end caps and a red tassel off the foot.

Exports Dizi.fbx, Dizi.json (tris/centre/size in Blender axes + anchors) and Dizi.blend.
"""
import importlib
import math
import os
import sys

import bmesh
from mathutils import Matrix

OUT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else ""
sys.path.insert(0, os.path.join(OUT_DIR, "..", "..", "rig"))
import rig_preview as rp  # noqa: E402
importlib.reload(rp)

NAME = "Dizi"
RENDER_PREVIEWS = True

# --- proportions (studs, z from the right-hand grip) -------------------------------------
FOOT_Z, HEAD_Z = -0.75, 1.55   # 2.3 long: arm-and-a-bit on the R6 (a real dizi is ~0.6 m)
R = 0.09                       # chunky enough to read in a hand on a phone
SIDES = 8
CAP = 0.08                     # bronze end caps
BLOW_Z = 1.22                  # blow hole (the mouth anchor)
MEMBRANE_Z = 0.95              # membrane hole
FINGER_Z = [0.58, 0.40, 0.22, -0.02, -0.20, -0.38]   # left hand three, right hand three
HOLE_R = 0.035
BINDINGS = [(HEAD_Z - 0.2, 0.08), (0.78, 0.06), (-0.58, 0.08)]   # (centre z, length) indigo thread
NODES = [0.1]                  # bamboo node rings
TASSEL_ON = True

PARTS = {"DiziBody": "bamboo", "DiziFittings": "bronze", "DiziBinding": "cord", "DiziHoles": "dark",
         "DiziTassel": "red"}


def body():
    bm = bmesh.new()
    prof = [(FOOT_Z + CAP - 0.01, R)]
    for z in NODES:
        prof += [(z - 0.03, R), (z - 0.01, R + 0.012), (z + 0.01, R + 0.012), (z + 0.03, R)]
    prof.append((HEAD_Z - CAP + 0.01, R))
    rp.lathe(bm, prof, SIDES)
    return bm


def fittings():
    bm = bmesh.new()
    rp.lathe(bm, [(FOOT_Z, R * 0.8), (FOOT_Z + 0.015, R + 0.02), (FOOT_Z + CAP, R + 0.02)], SIDES)
    rp.lathe(bm, [(HEAD_Z - CAP, R + 0.02), (HEAD_Z - 0.015, R + 0.02), (HEAD_Z, R * 0.8)], SIDES)
    return bm


def bindings():
    bm = bmesh.new()
    for zc, ln in BINDINGS:
        rp.cord_grip(bm, zc - ln / 2, zc + ln / 2, R + 0.012, R + 0.012, 2, SIDES)
    return bm


def holes():
    # dark hexagonal plugs whose outer face sits a hair proud of the -Y face (closed, so the
    # normals stay right)
    bm = bmesh.new()
    face_y = -R * math.cos(math.pi / SIDES)
    for z, r in [(BLOW_Z, HOLE_R * 1.1), (MEMBRANE_Z, HOLE_R * 0.9)] + [(z, HOLE_R) for z in FINGER_Z]:
        rings = [[bm.verts.new((r * math.cos(2 * math.pi * i / 6), y, z + r * math.sin(2 * math.pi * i / 6)))
                  for i in range(6)] for y in (face_y - 0.004, face_y + 0.03)]
        rp.loft(bm, rings)
    return bm


def tassel():
    bm = bmesh.new()
    rp.tassel(bm, FOOT_Z + 0.01, cord=0.2, length=0.38)
    return bm


def build():
    makers = {"DiziBody": body, "DiziFittings": fittings, "DiziBinding": bindings, "DiziHoles": holes,
              "DiziTassel": tassel}
    return [rp.finish(n, makers[n](), rp.PALETTE[c], smooth=(n not in ("DiziHoles",)))
            for n, c in PARTS.items() if n != "DiziTassel" or TASSEL_ON]


def anchors():
    return {
        "grip": dict(pos=[0, 0, 0], dir=[0, 0, 1], up=[0, -1, 0],
                     note="pivot; right hand (RightGripAttachment) over the lower holes; flute along +Z "
                          "toward the mouth, holes facing `up`"),
        "off_grip": dict(pos=[0, 0, sum(FINGER_Z[:3]) / 3], note="left hand, over the upper holes"),
        "mouth": dict(pos=[0, -R, BLOW_Z], dir=[0, -1, 0],
                      note="blow hole: put it at the R6's mouth (front of the Head, ~z 2.5 in the rig), "
                           "flute running across to the player's right"),
        "foot": dict(pos=[0, 0, FOOT_Z]),
    }


def previews(scene, objs):
    shots = rp.standard_previews(scene, objs, OUT_DIR, "dizi", detail_z=0.6, detail_dist=2.4)
    # playing pose: blow hole at the mouth, flute held out to the right, holes facing forward/up
    rp.pose_arm_forward(0)
    m = anchors()["mouth"]["pos"]
    frame = (Matrix.Translation((0.0, -0.85, 2.45)) @ Matrix.Rotation(math.radians(-8), 4, "Y") @
             Matrix.Rotation(math.radians(90), 4, "Y") @ Matrix.Rotation(math.radians(-90), 4, "Z") @
             Matrix.Translation((-m[0], -m[1], -m[2])))
    rp.place(objs, frame)
    shots.append(rp.render(scene, os.path.join(OUT_DIR, "preview", "dizi_play.png"), (3.0, -7.5, 3.2), (-0.6, -0.5, 1.9), lens=50))
    rp.place(objs, Matrix.Identity(4))
    return shots


if __name__ == "__main__":
    rp.item_main(NAME, OUT_DIR, build, anchors,
                 "1 Blender unit = 1 stud; Z along the flute toward the mouth end, holes face -Y; origin = right-hand grip",
                 previews=previews, render_previews=RENDER_PREVIEWS)
