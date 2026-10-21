"""Builds the technique-manual scroll (the prop shown on world manual caches) and exports it.

Run inside Blender: exec(compile(open(p).read(), p, "exec"), {"__file__": p, "__name__": "__main__"}).
Builds into its own scene "ManualScroll" and copies itself into the "Review" lineup scene if it exists.

Units and axes: 1 Blender unit = 1 stud (art/rig/rig_preview.py has the FBX/Roblox mapping).
Origin = the middle of the scroll's footprint on the surface it rests on; X along the roll,
Y outward (the loose end lies toward -Y, the viewer), Z up. A chunky rolled paper scroll on a
lacquered rod with turned knobs, a red silk tie with two tails, an indigo title slip on the roll
and a short tongue of paper unrolled onto the ground so it reads as a manual, not a log.

Exports ManualScroll.fbx, ManualScroll.json and ManualScroll.blend.
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

NAME = "ManualScroll"
RENDER_PREVIEWS = True

# --- proportions (studs) -------------------------------------------------------------------
ROLL_R = 0.2              # paper roll radius
ROLL_LEN = 1.1            # paper width (along X)
ROD_R = 0.06              # rod through the roll
KNOB_R = 0.12             # turned knobs on the rod ends
KNOB_LEN = 0.17           # each knob sticks out this far: total length ~1.45
SIDES = 10
TONGUE_LEN = 0.38         # unrolled paper lying on the ground toward -Y
TONGUE_T = 0.025
TIE_X = 0.18              # the tie sits a little off centre (+X), the title slip on the other side
TIE_W = 0.07
TAIL_LEN = 0.32
LABEL_X = -0.2            # title slip centre
LABEL_W, LABEL_H = 0.22, 0.03   # slip width along X and how far it stands off the paper

PARTS = {"ManualScrollPaper": "silk", "ManualScrollRod": "lacquer", "ManualScrollTie": "red",
         "ManualScrollLabel": "cord"}


def x_ring(bm, x, r, sides, cz):
    """A ring in the YZ plane at x (the roll runs along X)."""
    return [bm.verts.new((x, r * math.cos(2 * math.pi * i / sides + math.pi / sides),
                          cz + r * math.sin(2 * math.pi * i / sides + math.pi / sides))) for i in range(sides)]


def x_lathe(bm, profile, sides, cz):
    """Turned part along X. profile: [(x, r)] from -X to +X; r 0 = a point."""
    rings = [[bm.verts.new((x, 0, cz))] if r <= 0 else x_ring(bm, x, r, sides, cz) for x, r in profile]
    rp.loft(bm, rings)


def paper():
    bm = bmesh.new()
    h = ROLL_LEN / 2
    # the roll, its ends slightly rounded in so it reads as paper wound up
    x_lathe(bm, [(-h, ROLL_R * 0.55), (-h + 0.005, ROLL_R * 0.92), (-h + 0.03, ROLL_R),
                 (h - 0.03, ROLL_R), (h - 0.005, ROLL_R * 0.92), (h, ROLL_R * 0.55)], SIDES, ROLL_R)
    # the loose end: a thin sheet leaving the roll's underside and lying flat toward -Y
    y0 = -ROLL_R * 0.55
    rp.box(bm, (0, y0 - TONGUE_LEN / 2, TONGUE_T / 2), (ROLL_LEN * 0.96, TONGUE_LEN, TONGUE_T))
    return bm


def rod():
    bm = bmesh.new()
    h = ROLL_LEN / 2
    e = h + KNOB_LEN
    for s in (-1, 1):
        prof = [(s * (h - 0.02), ROD_R), (s * (h + 0.03), ROD_R), (s * (h + 0.05), KNOB_R * 0.8),
                (s * (e - 0.06), KNOB_R), (s * (e - 0.02), KNOB_R * 0.7), (s * e, 0.0)]
        x_lathe(bm, prof if s > 0 else list(reversed(prof)), SIDES, ROLL_R)
    return bm


def tie():
    bm = bmesh.new()
    r = ROLL_R + 0.018
    x_lathe(bm, [(TIE_X - TIE_W / 2, r), (TIE_X + TIE_W / 2, r)], SIDES, ROLL_R)
    # a knot on the front of the roll and two tails trailing down onto the ground
    knot = Vector((TIE_X, -r - 0.02, ROLL_R + 0.02))
    rp.box(bm, knot, (0.1, 0.06, 0.08))
    for dx, ln in ((-0.06, TAIL_LEN), (0.08, TAIL_LEN * 0.8)):
        a = knot + Vector((0, -0.01, -0.03))
        b = Vector((TIE_X + dx, -r - 0.08, 0.06))
        c = Vector((TIE_X + dx * 1.6, -r - 0.08 - ln * 0.6, 0.015))
        rp.strip(bm, a, b, 0.06, 0.018, side=Vector((1, 0, 0)))
        rp.strip(bm, b, c, 0.06, 0.018, side=Vector((1, 0, 0)))
    return bm


def label():
    # an indigo title slip pasted round the front of the roll
    bm = bmesh.new()
    r = ROLL_R + LABEL_H / 2
    x_lathe(bm, [(LABEL_X - LABEL_W / 2, r), (LABEL_X + LABEL_W / 2, r)], SIDES, ROLL_R)
    return bm


def build():
    makers = {"ManualScrollPaper": paper, "ManualScrollRod": rod, "ManualScrollTie": tie,
              "ManualScrollLabel": label}
    return [rp.finish(n, makers[n](), rp.PALETTE[c]) for n, c in PARTS.items()]


def anchors():
    return {
        "base": dict(pos=[0, 0, 0], note="rests here: the middle of its footprint on the surface"),
        "centre": dict(pos=[0, 0, ROLL_R], note="middle of the roll (glow / prompt)"),
        "top": dict(pos=[0, 0, ROLL_R * 2], note="top of the roll"),
    }


def previews(scene, objs):
    return rp.standard_previews(scene, objs, OUT_DIR, "manual_scroll", detail_z=ROLL_R, detail_dist=2.0, held=False)


if __name__ == "__main__":
    rp.item_main(NAME, OUT_DIR, build, anchors,
                 "1 Blender unit = 1 stud; X along the roll, Y outward (loose end toward -Y), Z up; origin = centre of the footprint on the ground",
                 previews=previews, render_previews=RENDER_PREVIEWS)
