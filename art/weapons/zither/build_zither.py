"""Builds the zither (guzheng-style, a cultivator's instrument-weapon) and exports it for Roblox.

Run inside Blender: exec(compile(open(p).read(), p, "exec"), {"__file__": p, "__name__": "__main__"}).
Builds into its own scene "Zither" and copies itself into the "Review" lineup scene if it exists.

Units and axes: 1 Blender unit = 1 stud (art/rig/rig_preview.py has the R6 measurements and the
FBX/Roblox mapping). Origin = the body's centre. +Z runs along the zither from the tail to the
head (the wide end with the tuning box), X is across the soundboard, -Y is the soundboard (string
side), +Y the flat underside. A long arched lacquered body, a bronze head and tail, bronze bridges
on a slanting line, silk strings, and a red tassel at the head.

Anchors: `back_carry` (on the underside, strap it on the R6's back with the strings facing out)
and `play` (on the underside: rest it flat in front or across the lap, strings up, head to the
player's right). Each has `up` (the direction that should face away from the body / upward).

Exports Zither.fbx, Zither.json (tris/centre/size in Blender axes + anchors) and Zither.blend.
"""
import importlib
import math
import os
import sys

import bmesh
from mathutils import Matrix, Vector

OUT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else ""
sys.path.insert(0, os.path.join(OUT_DIR, "..", "..", "rig"))
import rig_preview as rp  # noqa: E402
importlib.reload(rp)

NAME = "Zither"
RENDER_PREVIEWS = True

# --- proportions (studs) -----------------------------------------------------------------
LENGTH = 4.2              # a little shorter than the R6 is tall
HEAD_W, TAIL_W = 1.0, 0.82   # it narrows toward the tail
BACK_Y = 0.13             # flat underside
SIDE_Y = -0.08            # top of the side walls
ARCH_Y = -0.19            # crown of the arched soundboard
HEAD_LEN = 0.42           # bronze head (tuning box) and tail caps
TAIL_LEN = 0.22
CAP_GROW = 0.04           # caps stand proud of the body
N_STRINGS = 13            # stylised: a guzheng has 21; 13 reads on a phone
STRING_W, STRING_T = 0.025, 0.018
BRIDGE_H = 0.07           # bridges lift the strings off the board
BRIDGE_LINE = (-0.9, 0.9) # bridge line runs from z -0.9 (x min side) to z +0.9 (x max side)
TASSEL_ON = True

PARTS = {"ZitherBody": "lacquer", "ZitherFittings": "bronze", "ZitherStrings": "silk", "ZitherTassel": "red"}
HALF = LENGTH / 2


def half_width(z):
    t = (z + HALF) / LENGTH
    return TAIL_W / 2 + (HEAD_W - TAIL_W) / 2 * t


def top_y(x, w):
    """Soundboard height (as Y) at x across a body of half width w: a shallow arch."""
    u = min(1.0, abs(x) / w)
    return SIDE_Y + (ARCH_Y - SIDE_Y) * (1 - u * u)


def section(z, grow=0.0):
    w = half_width(z) + grow
    pts = [(w, BACK_Y + grow), (-w, BACK_Y + grow), (-w, SIDE_Y - grow)]
    for k in range(1, 6):
        x = -w + 2 * w * k / 6
        pts.append((x, top_y(x, w) - grow))
    pts.append((w, SIDE_Y - grow))
    return [(x, y, z) for x, y in pts]


def body():
    bm = bmesh.new()
    zs = [-HALF + TAIL_LEN - 0.02, 0.0, HALF - HEAD_LEN + 0.02]
    rp.loft(bm, [[bm.verts.new(p) for p in section(z)] for z in zs])
    return bm


def string_x():
    w = min(half_width(-HALF + TAIL_LEN), half_width(HALF - HEAD_LEN)) * 0.84
    return [-w + 2 * w * i / (N_STRINGS - 1) for i in range(N_STRINGS)]


def bridge_z(x):
    xs = string_x()
    t = (x - xs[0]) / (xs[-1] - xs[0])
    return BRIDGE_LINE[0] + (BRIDGE_LINE[1] - BRIDGE_LINE[0]) * t


def fittings():
    bm = bmesh.new()
    # head (tuning box) and tail caps: the body's section, grown a little, with flat ends
    for z0, z1, g in ((HALF - HEAD_LEN, HALF, CAP_GROW * 1.6), (-HALF, -HALF + TAIL_LEN, CAP_GROW)):
        rp.loft(bm, [[bm.verts.new(p) for p in section(z, g)] for z in (z0, z1)])
    # nuts: the ridges the strings run over at the head and tail
    for z in (HALF - HEAD_LEN + 0.06, -HALF + TAIL_LEN - 0.06):
        w = half_width(z) * 0.9
        rp.box(bm, (0, top_y(0, w) - 0.03, z), (2 * w, 0.06, 0.06))
    # bridges: little inverted-V blocks (wedges) under each string on the slanting line
    for x in string_x():
        z = bridge_z(x)
        base = top_y(x, half_width(z))
        a = [bm.verts.new(v) for v in ((x - 0.045, base + 0.01, z - 0.04), (x + 0.045, base + 0.01, z - 0.04),
                                       (x + 0.045, base + 0.01, z + 0.04), (x - 0.045, base + 0.01, z + 0.04))]
        b = [bm.verts.new(v) for v in ((x - 0.012, base - BRIDGE_H, z - 0.02), (x + 0.012, base - BRIDGE_H, z - 0.02),
                                       (x + 0.012, base - BRIDGE_H, z + 0.02), (x - 0.012, base - BRIDGE_H, z + 0.02))]
        rp.loft(bm, [a, b])
    return bm


def strings():
    bm = bmesh.new()
    zt, zh = -HALF + TAIL_LEN - 0.06, HALF - HEAD_LEN + 0.06
    for x in string_x():
        zb = bridge_z(x)
        yb = top_y(x, half_width(zb)) - BRIDGE_H - STRING_T / 2
        yt = top_y(0, half_width(zt) * 0.9) - 0.06 - STRING_T / 2
        yh = top_y(0, half_width(zh) * 0.9) - 0.06 - STRING_T / 2
        side = Vector((1, 0, 0))
        rp.strip(bm, (x, yt, zt), (x, yb, zb), STRING_W, STRING_T, side)
        rp.strip(bm, (x, yb, zb), (x, yh, zh), STRING_W, STRING_T, side)
    return bm


def tassel():
    # hangs from the head's corner; in the upright lineup it falls along the body's side
    bm = bmesh.new()
    x = half_width(HALF) + CAP_GROW * 1.6 + 0.02
    rp.tassel(bm, HALF - 0.12, cord=0.3, length=0.5, scale=1.1, cx=x, cy=0.0)
    return bm


def build():
    makers = {"ZitherBody": body, "ZitherFittings": fittings, "ZitherStrings": strings, "ZitherTassel": tassel}
    return [rp.finish(n, makers[n](), rp.PALETTE[c], smooth=(n != "ZitherFittings"))
            for n, c in PARTS.items() if n != "ZitherTassel" or TASSEL_ON]


def anchors():
    back = BACK_Y + CAP_GROW * 1.6
    return {
        "back_carry": dict(pos=[0, back, 0.3], up=[0, -1, 0], dir=[0, 0, 1],
                           note="on the underside: put this on the R6's back (Torso back face) with `up` (strings) "
                                "facing away from the body; tilt `dir` (head) ~30 deg over the right shoulder"),
        "play": dict(pos=[0, back, 0], up=[0, -1, 0], dir=[0, 0, 1],
                     note="on the underside: rest flat in front of / across the lap, `up` (strings) upward, "
                          "`dir` (head) toward the player's right"),
        "pluck": dict(pos=[0, top_y(0, half_width(0.9)) - BRIDGE_H, 1.3],
                      note="where the right hand plucks (between the bridges and the head), for effects"),
        "head": dict(pos=[0, 0, HALF]),
        "tail": dict(pos=[0, 0, -HALF]),
    }


def previews(scene, objs):
    shots = rp.standard_previews(scene, objs, OUT_DIR, "zither", detail_z=1.2, detail_dist=3.0, held=False)
    # back carry: underside against the torso back (y +0.5), strings out, head over the right shoulder
    rp.pose_arm_forward(0)
    a = anchors()["back_carry"]
    frame = (Matrix.Translation((0.0, 0.5, 1.0)) @ Matrix.Rotation(math.radians(-30), 4, "Y") @
             Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Translation(-Vector(a["pos"])))
    rp.place(objs, frame)
    shots.append(rp.render(scene, os.path.join(OUT_DIR, "preview", "zither_back_carry.png"),
                           (-6.5, 9.5, 3.5), (0, 0, 0.6), lens=45))
    # play: flat in front of the R6, strings up
    play = anchors()["play"]
    frame = (Matrix.Translation((0.0, -1.4, -0.2)) @ Matrix.Rotation(math.radians(90), 4, "Z") @
             Matrix.Rotation(math.radians(-90), 4, "X") @ Matrix.Translation(-Vector(play["pos"])))
    rp.place(objs, frame)
    shots.append(rp.render(scene, os.path.join(OUT_DIR, "preview", "zither_play.png"),
                           (4.5, -7.5, 4.5), (0, -1.0, 0.3), lens=45))
    rp.place(objs, Matrix.Identity(4))
    return shots


if __name__ == "__main__":
    rp.item_main(NAME, OUT_DIR, build, anchors,
                 "1 Blender unit = 1 stud; Z tail->head, X across, -Y = strings side; origin = body centre",
                 previews=previews, render_previews=RENDER_PREVIEWS)
