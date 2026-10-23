r"""Spirit Fox cosmetics: three tail variants and three ear variants for the player's R6 avatar.

  Tails (WaistBackAttachment): FoxTailPlume, FoxTailCrescent, FoxTailWisp
  Ears  (HatAttachment):       FoxEarsSleek, FoxEarsBroad, FoxEarsLong
Each set is its own FBX + JSON beside this script, with its own armature. See README.md.

Run through the Blender MCP (Blender runs on Windows, so paths come from __file__):
    P = r"\\wsl.localhost\Ubuntu\home\cj\roblox\martial-world-fox-v2\art\player\cosmetics\fox\build_fox.py"
    exec(compile(open(P).read(), P, "exec"), {"__file__": P})
Optional globals: RENDER (default True: sheet tiles into renders/), EXPORT (default True: FBX,
JSON, shade PNG, .blend), ONLY (a set of set names: rebuild and export just those, e.g. the
three ear sets; the rest stay as they are). Then stitch the sheet with make_sheet.py (`ears`
for the ear sheet).

Axes and units (the R6 reference, art/rig/r6_rigged.fbx, see art/rig/rig_preview.py):
  1 Blender unit = 1 stud. +X = the avatar's left (its left arm), it faces -Y, Z up.
  Hips z 0, torso z 0..2, head top z 3.1, feet z -2.
  Head HatAttachment        = (0, 0, 3.1)  (Head centre + Roblox (0, 0.6, 0))
  Torso WaistBackAttachment = (0, 0.5, 0)  (Torso centre + Roblox (0, -1, 0.5): bottom, back face)
Built in avatar space with identity object transforms; the export moves each set so its
attachment is the origin (FBX and JSON are in attachment space).

Recolour contract: each colour region is its own mesh object (one Roblox MeshPart, one Color)
with its own material: FurOuter (<Ears>_LeftEar, _RightEar, <Tail>_Tail), FurInner
(<Ears>_LeftEarInner, _RightEarInner), FurTip (<Tail>_TailTip). Depth shading is a greyscale
gradient (fox_shade.png, white with darkening at one end) on UV V: tail base and ear tips get
darker, so tinting by Color still works. Without the texture the parts read as flat colours.

Rig (one armature per set, bones named like Roblox Motor6Ds; Root = the attachment point):
  Ears: Root -> EarLBase -> EarL, Root -> EarRBase -> EarR   (Base is planted; key EarL/EarR)
  Tail: Root -> TailBase -> Tail1 -> ... -> Tail5           (Tail1's head = where it leaves the body)
Bone rolls: tail bones' local Z is the side normal of the tail's parallel-transport frame (world
+X at the root), ears' local Z is world +X, so local X bends/folds every joint the same way.
Weights blend smoothly across each joint; ears blend from Base into the ear over its lowest third.

Fur: a full smooth core plus overlapping flame-shaped clumps. Each clump is a closed wedge whose
underside sits inside the core, so there are no floating shells, open backs or see-through gaps.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "art", "rig"))
import rig_preview as rp  # noqa: E402  (shared R6 helpers: rig import, loft, render)

RENDER = globals().get("RENDER", True)
EXPORT = globals().get("EXPORT", True)
ONLY = globals().get("ONLY")           # optional set of set names to (re)build; others stay as they are

SCENE = "Cosmetics"
ROOT_COLLECTION = "FoxCosmetics"
HAT = Vector((0.0, 0.0, 3.1))          # Head HatAttachment, rest pose
WAIST_BACK = Vector((0.0, 0.5, 0.0))   # Torso WaistBackAttachment, rest pose
EAR_SHARP_DEG = 28.0                   # ears: edges sharper than this shade hard (house crease)
FUR_SHARP_DEG = 80.0                   # inner fur cushion and tufts: soft, only real creases
TAIL_SHARP_DEG = 70.0                  # tail: soft fur, only the clumps' side ridges stay crisp

# Colours (linear). Plain SmoothPlastic in Roblox; MeshPart.Color carries these per region.
COLORS = {
    "FurOuter": (0.80, 0.22, 0.055, 1),   # warm reddish-orange
    "FurInner": (0.93, 0.70, 0.60, 1),    # soft cream with a muted pink
    "FurTip":   (0.95, 0.89, 0.78, 1),    # cream-white
}
SHADE_FILE = "fox_shade.png"   # greyscale ramp on UV V: V 0 = darkest, V >= SHADE_REACH = white
SHADE_MIN = 0.55               # darkest value (tail root, ear tip): about one value step
SHADE_REACH = 0.45             # V where the darkening has faded out

# ----------------------------------------------------------------------------------------------
# Ears: three cute sets with clearly different silhouettes (round dome, soft notched point, a top
# flopped out to the side), all chunky and sized to the R6 head (about 1.2 wide, 1.0 tall).
# Heights are what shows above the head.
# X base centre |x| on the head top, H ear length (part of it is sunk), W base half-width,
# T thickness, CUP front hollow depth, BELLY widens the mid ear, SIDE_EXP < 1 rounds the sides
# out (soft), > 1 pinches them concave toward the tip (sharp), CURL tip offset backwards (+Y),
# TILT outward roll, YAW turn of the opening outward, LEAN backward lean (degrees), EDGE_TUFTS
# serrations on each rim near the base, NOTCH (t, depth) a V nick in the outer rim or None,
# TIP_DARK how far down the shade ramp darkens the tip (1 = top 45%, 1.6 = top 70%).
# PEAK "point" | "round" (a dome, no point), FOLD (t, degrees, "out" | "forward") or None.
# TUFTS: the cream fur in the cup, a few soft chunky teardrops: (t, u root on the front surface,
# up, out, forward axis parts, length as a fraction of H, belly radius). Base tufts lean forward
# so they spill over the rim.
CUTE_TUFTS = [(0.03, 0.0, 1.0, 0.0, 0.9, 0.36, 0.13), (0.06, -0.8, 1.0, 0.45, 0.7, 0.30, 0.11),
              (0.06, 0.8, 1.0, 0.45, 0.7, 0.30, 0.11), (0.30, 0.1, 1.0, 0.15, 0.5, 0.26, 0.09)]
EARS = {
    # cute, alert: a soft, chunky triangle with a gentle point, a small notch and a darker tip
    "FoxEarsSleek": dict(label="Sleek", mood="cute, alert", PEAK="point", FOLD=None, X=0.31, H=0.80, W=0.21,
                         T=0.30, CUP=0.15, BELLY=0.6, SIDE_EXP=0.75, CURL=0.03, TILT=15, YAW=16, LEAN=6,
                         EDGE_TUFTS=0, TUFTS=CUTE_TUFTS, NOTCH=(0.55, 0.18), TIP_DARK=1.4),
    # cute (approved 2026-10-23, "YES, the cute set for foxes is perfect"): a round, soft dome
    # peak (no point), plump and upright. Locked: polish only.
    "FoxEarsBroad": dict(label="Broad", mood="cute", PEAK="round", FOLD=None, X=0.31, H=0.78, W=0.21, T=0.30,
                         CUP=0.15, BELLY=0.75, SIDE_EXP=1.0, CURL=0.0, TILT=15, YAW=18, LEAN=3,
                         EDGE_TUFTS=0, TUFTS=CUTE_TUFTS, NOTCH=None, TIP_DARK=0.8),
    # cute, sleepy: a round ear whose top half flops out to the side
    "FoxEarsLong": dict(label="Long", mood="cute, sleepy", PEAK="round", FOLD=(0.45, 70, "out"), X=0.31, H=0.84,
                        W=0.21, T=0.30, CUP=0.15, BELLY=0.75, SIDE_EXP=1.0, CURL=0.0, TILT=15, YAW=16, LEAN=4,
                        EDGE_TUFTS=0, TUFTS=CUTE_TUFTS, NOTCH=None, TIP_DARK=1.0),
}

# Tails. PATH control points (avatar space, root inside the body), R core max radius, PROFILE
# core radius along the length (s 0..1, x R), FLAT depth/width of the section, TIP_S where the
# TailTip colour starts, BEND the sheet's deformation check per Tail joint: (local axis, degrees);
# Z = about the side axis (curl/uncurl), X = sideways sway. CLUMPS: ROWS x PER_ROW staggered from S0 to S1 (s), each LEN long (s), WIDTH and
# THICK as fractions of the local core radius, FLARE how far past the core the clump point
# stands (breaks the outline), SWIRL its turn around the tail (radians), BULGE its mid arch.
TAPER = [(0, 0.32), (0.10, 0.72), (0.26, 1.0), (0.48, 0.92), (0.70, 0.62), (0.88, 0.30), (1, 0.0)]
#        full near the base, widest at a quarter, the last 40% tapering to a point
CLUMP_GRADE = (1.25, 0.65)   # clump length scale at the root and at the tip (big at the base)

TAILS = {
    "FoxTailPlume": dict(
        label="Plume", PATH=[(0, 0.2, 0.08), (0, 0.8, -0.15), (-0.25, 1.55, -0.15), (-0.2, 2.2, 0.5),
                             (0.25, 2.4, 1.4), (0.7, 2.15, 2.3), (1.0, 1.65, 2.85)],
        R=0.80, PROFILE=TAPER,
        FLAT=0.88, TIP_S=0.70, BEND=("Z", -40),
        CLUMPS=dict(ROWS=7, PER_ROW=5, S0=0.12, S1=0.88, LEN=0.30, WIDTH=1.45, THICK=0.50,
                    FLARE=0.48, SWIRL=0.50, BULGE=0.08)),
    "FoxTailCrescent": dict(
        label="Crescent", PATH=[(0, 0.2, 0.08), (0.1, 0.85, -0.2), (0.6, 1.6, -0.4), (1.3, 2.0, 0.1),
                                (1.75, 1.95, 1.0), (1.8, 1.65, 1.95)],
        R=0.82, PROFILE=TAPER,
        FLAT=0.85, TIP_S=0.72, BEND=("Z", -40),
        CLUMPS=dict(ROWS=7, PER_ROW=5, S0=0.12, S1=0.88, LEN=0.32, WIDTH=1.40, THICK=0.50,
                    FLARE=0.40, SWIRL=0.15, BULGE=0.10)),
    "FoxTailWisp": dict(
        label="Wisp", PATH=[(0, 0.2, 0.08), (0, 0.8, -0.3), (0.15, 1.5, -0.85), (0.4, 2.3, -0.95),
                            (0.7, 2.9, -0.45), (0.9, 3.05, 0.4), (0.95, 2.75, 1.15)],
        R=0.68, PROFILE=TAPER,
        FLAT=0.9, TIP_S=0.74, BEND=("X", 30),   # a sideways sway: curling it hits the legs or floor
        CLUMPS=dict(ROWS=8, PER_ROW=5, S0=0.12, S1=0.88, LEN=0.36, WIDTH=1.25, THICK=0.45,
                    FLARE=0.55, SWIRL=0.80, BULGE=0.05)),
}

# Sheet rows: which ears are shown with which tail (any ears go with any tail in game).
PAIRS = [("FoxTailPlume", "FoxEarsSleek"), ("FoxTailCrescent", "FoxEarsBroad"), ("FoxTailWisp", "FoxEarsLong")]
FAN_TAIL = "FoxTailPlume"      # the multi-tail proof on the sheet (not exported)
FAN_ANGLES = (-40, 0, 40)      # degrees about the attachment's back axis (README: 5 and 9 tails)

EAR_Y = 0.06          # a touch behind the head centre
EAR_SINK = 0.10       # the whole base rim sits this far under the head surface (no gap anywhere)
EAR_CONFORM_T = 0.30  # the base follows the head's curve, fading out by this height fraction
HEAD_MIN_Z = 2.6      # a downward ray landing below this missed the head (the ear overhangs it)
EAR_ROWS = 10         # rings from base to tip
EAR_COLS = 7          # points across the front (and back) of each ring, plus a rounded rim point each side
EAR_RIM = 0.6         # rim depth as a fraction of the ear's thickness T (the shell never thins to a card)
TUFT_SIDES = 8        # inner fur tufts: ring vertices
TUFT_PROFILE = [(0.0, 0.0), (0.12, 0.7), (0.35, 1.0), (0.62, 0.85), (0.85, 0.45), (1.0, 0.0)]   # (along, radius): fat belly, soft point
EAR_BEND = (0.04, 0.32)   # ear height fraction where the weight goes from Base to the ear bone
CORE_SIDES = 16       # core ring vertices (mostly covered by clumps)
CORE_STATIONS = 40    # core rings along the tail
TAIL_BONES = 5
JOINT_BLEND = 0.45    # weight blend half-width around each tail joint, in bone lengths
CLUMP_ROOT = 0.80     # clump underside sits at this fraction of the core radius (inside the core)
CLUMP_RINGS = (0.0, 0.2, 0.42, 0.64, 0.84)   # stations along each clump before its point
ROOT_BONE_LEN = 0.25


# ---------------------------------------------------------------------------------- helpers ---
def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def interp_profile(profile, s):
    for (s0, r0), (s1, r1) in zip(profile, profile[1:]):
        if s0 <= s <= s1:
            u = (s - s0) / (s1 - s0)
            u = u * u * (3 - 2 * u)
            return r0 + (r1 - r0) * u
    return profile[-1][1]


def shade_image():
    """The greyscale depth ramp (tiny, tintable): saved beside the script as SHADE_FILE."""
    img = bpy.data.images.get(SHADE_FILE)
    if img is not None:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(SHADE_FILE, 4, 128, alpha=False)
    img.colorspace_settings.name = "sRGB"   # set before the pixels: changing it resets a generated buffer
    w, h = img.size
    px = []
    for y in range(h):
        v = (y + 0.5) / h
        g = SHADE_MIN + (1 - SHADE_MIN) * smoothstep(0.0, SHADE_REACH, v)
        px += [g, g, g, 1.0] * w
    img.pixels.foreach_set(px)
    img.update()
    if EXPORT:
        img.filepath_raw = os.path.join(HERE, SHADE_FILE)
        img.file_format = "PNG"
        img.save()
    img.pack()
    return img


def material(name):
    """Region material: its colour multiplied by the shade ramp (what Roblox's tint does)."""
    m = rp.preview_material(name, COLORS[name])
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    for n in [n for n in nt.nodes if n.type in ("TEX_IMAGE", "MIX")]:
        nt.nodes.remove(n)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.get(SHADE_FILE) or shade_image()
    tex.interpolation = "Linear"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    rgba_in = [s for s in mix.inputs if s.type == "RGBA"]
    rgba_in[0].default_value = COLORS[name]
    nt.links.new(tex.outputs["Color"], rgba_in[1])
    out = next(s for s in mix.outputs if s.type == "RGBA")
    nt.links.new(out, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7
    return m


def new_object(name, bm, mat, col, vvals, sharp):
    """Link bm as object `name`; vvals[i] = shade V of vertex i (UV U is 0.5)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = not (e.is_manifold and e.calc_face_angle(0) > math.radians(sharp))
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    if bpy.data.meshes.get(name):
        bpy.data.meshes.remove(bpy.data.meshes[name])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    uv = me.uv_layers.new(name="UVMap")
    for loop in me.loops:
        uv.data[loop.index].uv = (0.5, min(0.995, max(0.005, vvals[loop.vertex_index])))
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    me.materials.append(mat)
    return o


def collection(name, parent):
    col = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if col.name not in parent.children:
        parent.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    lc = bpy.context.view_layer.layer_collection.children.get(parent.name)
    if lc and lc.children.get(col.name):
        lc.children[col.name].exclude = False   # objects in an excluded collection can't go active
    return col


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


# ---------------------------------------------------------------------------------- ears ------
def ear_width(p, t):
    """Half-width at height fraction t (0 base .. 1 tip). PEAK "round" closes in a dome (no point)."""
    belly = 1 + p["BELLY"] * math.sin(math.pi * t) * (1 - t)
    if p["PEAK"] == "round":
        return p["W"] * belly * max(0.0, 1 - t ** 2.2) ** 0.5
    return p["W"] * (1 - t) ** p["SIDE_EXP"] * belly


def fold_tip(p, bm):
    """FOLD (t, degrees, "out" | "forward"): everything above height fraction t flops at a constant
    curvature, outward to the side (the outer rim is +x) or forward over the opening, keeping the
    shell's thickness."""
    if not p["FOLD"]:
        return
    ft, deg, way = p["FOLD"]
    z0, length, theta = ft * p["H"], (1 - ft) * p["H"], math.radians(deg)
    r = length / theta
    for v in bm.verts:
        s = v.co.z - z0
        if s <= 0:
            continue
        phi = theta * s / length
        if way == "out":
            x = v.co.x
            v.co.x = r - (r - x) * math.cos(phi)
            v.co.z = z0 + (r - x) * math.sin(phi)
        else:
            y = v.co.y
            v.co.y = -r + (r + y) * math.cos(phi)
            v.co.z = z0 + (r + y) * math.sin(phi)


def edge_tuft(p, t):
    """Serrated rim near the base: 0..1 bump at each tuft."""
    n = p["EDGE_TUFTS"]
    if n == 0 or t > 0.42:
        return 0.0
    u = t / 0.42 * n
    return max(0.0, 1 - abs((u % 1) - 0.5) * 2) ** 2 * (1 - t / 0.42)


def ear_front(p, t, u):
    """Point on the ear's front (opening) surface in ear-local space; u in -1..1 across."""
    w = ear_width(p, t) * (1 + 0.55 * edge_tuft(p, t) * abs(u) ** 4)
    if p["NOTCH"] and u > 0:   # +u is the outer rim (the right ear is built mirrored)
        nt, depth = p["NOTCH"]
        w *= 1 - depth * max(0.0, 1 - abs(t - nt) / 0.07) * u ** 4
    fade = (1 - t) ** 0.6
    y = p["CUP"] * (1 - u * u) * fade + p["CURL"] * t * t
    return Vector((u * w, y, t * p["H"]))


def ear_back(p, t, u):
    """The ear's back: a full rounded shell behind the front, RIM x T deep at the rim, so the ear has
    body from every side (not a card)."""
    f = ear_front(p, t, u)
    fade = (1 - t) ** 0.35
    return f + Vector((0, p["T"] * (EAR_RIM + (1 - EAR_RIM) * math.sqrt(max(0.0, 1 - u * u))) * fade, 0))


def ear_rim(p, t, side):
    """Rounded rim point between the front and back edges on one side (side = +1 / -1)."""
    f, b = ear_front(p, t, side), ear_back(p, t, side)
    return (f + b) / 2 + Vector((side * (b.y - f.y) * 0.3, 0, 0))


def add_tuft(bm, tv, p, root, axis, length, radius, flat=0.75):
    """A soft, chunky fur tuft: a closed teardrop from `root` (buried in the cushion) along `axis`,
    round-bellied with a gentle point. flat squashes it front to back."""
    axis = axis.normalized()
    side = axis.cross(Vector((0, 1, 0)))
    side = side.normalized() if side.length > 1e-6 else Vector((1, 0, 0))
    depth = side.cross(axis).normalized()
    rings = []
    for s_, r_ in TUFT_PROFILE:
        c = root + axis * (length * s_)
        if r_ == 0:
            rings.append([bm.verts.new(c)])
        else:
            rings.append([bm.verts.new(c + (side * math.cos(a) + depth * math.sin(a) * flat) * radius * r_)
                          for a in (2 * math.pi * k / TUFT_SIDES for k in range(TUFT_SIDES))])
        tv += [max(0.0, c.z / p["H"])] * len(rings[-1])
    rp.loft(bm, rings, cap_start=False, cap_end=False)


def build_ear_local(p):
    """Returns (outer bm, inner bm, outer verts' t, inner verts' t) in ear-local space."""
    bm, tvals = bmesh.new(), []
    us = [-1 + 2 * i / (EAR_COLS - 1) for i in range(EAR_COLS)]
    ts = [1 - (1 - i / EAR_ROWS) ** 1.4 for i in range(EAR_ROWS)]   # rings closer near the tip
    rings = []
    for t in ts:
        r = ([bm.verts.new(ear_front(p, t, u)) for u in us] + [bm.verts.new(ear_rim(p, t, 1))]
             + [bm.verts.new(ear_back(p, t, u)) for u in reversed(us)] + [bm.verts.new(ear_rim(p, t, -1))])
        tvals += [t] * len(r)
        rings.append(r)
    tip = bm.verts.new(ear_front(p, 1.0, 0) + Vector((0, p["T"] * 0.1, 0)))
    tvals.append(1.0)
    rp.loft(bm, rings + [[tip]], cap_start=True, cap_end=False)

    # Inner ear: a plump cream cushion filling the cup, plus a few chunky tufts that spill out
    # over the rim at the base.
    ib, itv = bmesh.new(), []
    k, t1 = 0.66, 0.78
    rows = 6
    rings = []
    for i in range(rows):
        t = t1 * i / rows
        span = k * (1 - (t / t1) ** 1.6) ** 0.5
        fr, br = [], []
        for u in us:
            base = ear_front(p, t, u * span)
            fluff = p["CUP"] * 0.75 * (1 - u * u) * (1 - (t / t1) ** 2)
            fr.append(base + Vector((0, -0.012 - fluff, 0)))
            br.append(base + Vector((0, 0.03, 0)))
        r = [ib.verts.new(v) for v in fr] + [ib.verts.new(v) for v in reversed(br)]
        itv += [t] * len(r)
        rings.append(r)
    itip = ib.verts.new(ear_front(p, t1, 0) + Vector((0, -0.01, 0)))
    itv.append(t1)
    rp.loft(ib, rings + [[itip]], cap_start=True, cap_end=False)
    for (t, u, up, out, fwd, ln, rad) in p["TUFTS"]:
        root = ear_front(p, t, u * 0.55) + Vector((0, -0.02, 0))
        axis = Vector((out * (1 if u >= 0 else -1), -fwd, up))
        add_tuft(ib, itv, p, root, axis, ln * p["H"], rad)
    fold_tip(p, bm)
    fold_tip(p, ib)
    return bm, ib, tvals, itv


def ear_matrix(p, side):
    """side +1 = left ear (+X), -1 = right. Ear-local -> avatar space, base centre EAR_SINK under the
    head top. The right ear is the mirror image (local X flipped), so the outer rim (+u) and its
    notch face outward on both."""
    rot = (Matrix.Rotation(math.radians(p["YAW"] * side), 4, "Z")
           @ Matrix.Rotation(math.radians(p["TILT"] * side), 4, "Y")
           @ Matrix.Rotation(math.radians(-p["LEAN"]), 4, "X"))
    top = head_top_z(p["X"] * side, EAR_Y)
    return (Matrix.Translation((p["X"] * side, EAR_Y, top - EAR_SINK)) @ rot
            @ Matrix.Diagonal((side, 1, 1, 1)))


def head_surface_z(x, y):
    """The R6 head's surface height at (x, y) by a ray straight down onto the rig mesh, or None
    when the ray misses the head (lands on the shoulders or nothing)."""
    rig = next((o for o in rp.rig_objects() if o.type == "MESH"), None)
    inv = rig.matrix_world.inverted()
    origin, direction = inv @ Vector((x, y, 6.0)), (inv.to_3x3() @ Vector((0, 0, -1))).normalized()
    hit, loc, *_ = rig.ray_cast(origin, direction)   # the rig only, never other cosmetics
    z = (rig.matrix_world @ loc).z if hit else None
    return z if z is not None and HEAD_MIN_Z < z < 3.3 else None


def seat_on_head(bm, tvals, m):
    """Move ear-local verts to avatar space and seat the base on the head's rounded top: each
    vertex's foot (its point on the ear's base plane) is dropped or raised to EAR_SINK under the
    head surface straight below it, fully at the base and fading out by EAR_CONFORM_T. So the
    whole footprint, including where it crosses the head's rounded edge, is buried."""
    for v, t in zip(bm.verts, tvals):
        foot = m @ Vector((v.co.x, v.co.y, 0.0))
        pos = m @ v.co
        w = 1 - smoothstep(0.0, EAR_CONFORM_T, t)
        if w > 0:
            surf = head_surface_z(foot.x, foot.y)
            centre = m @ Vector((0, 0, 0))
            k = 1.0
            while surf is None and t > 0 and k > 0:   # above the base, past the head's edge: use the edge
                k -= 0.05
                surf = head_surface_z(centre.x + (foot.x - centre.x) * k, centre.y + (foot.y - centre.y) * k)
            assert surf is not None, "ear base overhangs the head at (%.2f, %.2f)" % (foot.x, foot.y)
            pos.z += (surf - EAR_SINK - foot.z) * w
        v.co = pos


def head_top_z(x, y):
    """The R6 head's surface height at (x, y), by ray cast straight down onto the rig mesh."""
    rig = next((o for o in rp.rig_objects() if o.type == "MESH"), None)
    if rig is None:
        return HAT.z
    inv = rig.matrix_world.inverted()
    origin, direction = inv @ Vector((x, y, 6.0)), (inv.to_3x3() @ Vector((0, 0, -1))).normalized()
    hit, loc, *_ = rig.ray_cast(origin, direction)   # the rig only, never other cosmetics
    z = (rig.matrix_world @ loc).z if hit else HAT.z
    return z if 2.5 < z < 3.3 else HAT.z


def build_ears(name, root_col):
    p = EARS[name]
    col = collection(name, root_col)
    outer, inner, tv_o, tv_i = build_ear_local(p)
    arm = new_armature(name + "_Rig", col)
    eb = arm.data.edit_bones
    root = eb.new("Root")
    root.head, root.tail = HAT, HAT + Vector((0, 0, ROOT_BONE_LEN))
    root.align_roll(Vector((1, 0, 0)))
    root.use_deform = False
    mats = {}
    for tag, side in (("L", 1), ("R", -1)):
        m = ear_matrix(p, side)
        mats[tag] = m
        hinge = m @ Vector((0, 0, EAR_SINK))
        base = eb.new("Ear%sBase" % tag)
        base.head, base.tail = m @ Vector((0, 0, 0)), hinge
        base.align_roll(Vector((1, 0, 0)))
        base.parent = root
        ear = eb.new("Ear%s" % tag)
        ear.head, ear.tail = hinge, m @ Vector((0, p["CURL"] * 0.4, p["H"] * 0.7))
        ear.align_roll(Vector((1, 0, 0)))
        ear.parent, ear.use_connect = base, True
    bpy.ops.object.mode_set(mode="OBJECT")
    objs = []
    for tag, nm in (("L", "Left"), ("R", "Right")):
        for src, tv, region, mat, shade in ((outer, tv_o, "Ear", "FurOuter", True),
                                            (inner, tv_i, "EarInner", "FurInner", False)):
            bm = src.copy()
            seat_on_head(bm, tv, mats[tag])
            if shade and tag == "L":   # footprint across the head: the base ring's x extent
                xs = [v.co.x for v, t in zip(bm.verts, tv) if t == 0]
                base_w = max(xs) - min(xs)
            vv = [1.0 - t * p["TIP_DARK"] if shade else 1.0 for t in tv]   # ear tips darker
            o = new_object("%s_%s%s" % (name, nm, region), bm, material(mat), col, vv,
                           EAR_SHARP_DEG if shade else FUR_SHARP_DEG)
            o["region"] = mat
            if shade and tag == "L":
                o["base_width"] = base_w
            w = [[("Ear%sBase" % tag, 1 - smoothstep(*EAR_BEND, t)), ("Ear%s" % tag, smoothstep(*EAR_BEND, t))]
                 for t in tv]
            skin(o, arm, w)
            objs.append(o)
    outer.free()
    inner.free()
    return arm, objs


# ---------------------------------------------------------------------------------- tail ------
def catmull(points, samples=400):
    pts = [Vector(p) for p in points]
    pts = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        n = samples // (len(pts) - 3)
        for k in range(n):
            t = k / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-2])
    return out


class Path:
    """Arc-length parametrised centreline with parallel-transport frames (n = side normal)."""

    def __init__(self, points):
        self.p = catmull(points)
        self.l = [0.0]
        for a, b in zip(self.p, self.p[1:]):
            self.l.append(self.l[-1] + (b - a).length)
        self.length = self.l[-1]
        self.t, self.n = [], []
        n = Vector((1, 0, 0))
        for i in range(len(self.p)):
            t = (self.p[min(i + 1, len(self.p) - 1)] - self.p[max(i - 1, 0)]).normalized()
            n = (n - t * n.dot(t)).normalized()
            self.t.append(t)
            self.n.append(n.copy())

    def at(self, s):
        d = min(1.0, max(0.0, s)) * self.length
        for i in range(len(self.l) - 1):
            if self.l[i + 1] >= d:
                u = (d - self.l[i]) / max(1e-9, self.l[i + 1] - self.l[i])
                p = self.p[i].lerp(self.p[i + 1], u)
                t = self.t[i].lerp(self.t[i + 1], u).normalized()
                n = self.n[i].lerp(self.n[i + 1], u)
                n = (n - t * n.dot(t)).normalized()
                return p, t, n
        return self.p[-1], self.t[-1], self.n[-1]

    def param_of(self, point):
        best = min(range(len(self.p)), key=lambda i: (self.p[i] - point).length)
        return self.l[best] / self.length


def core_radius(q, s):
    return q["R"] * interp_profile(q["PROFILE"], min(1.0, max(0.0, s)))


def add_core(bm, sv, q, path, s_lo, s_hi, cap_start):
    rings = []
    n_st = max(2, round(CORE_STATIONS * (s_hi - s_lo)))
    for i in range(n_st + 1):
        s = s_lo + (s_hi - s_lo) * i / n_st
        p, t, n = path.at(s)
        b = t.cross(n)
        r = core_radius(q, s)
        if r < 1e-4:
            rings.append([bm.verts.new(p)])
            sv.append(s)
            continue
        rings.append([bm.verts.new(p + (n * math.cos(th) + b * math.sin(th) * q["FLAT"]) * r)
                      for th in (2 * math.pi * k / CORE_SIDES for k in range(CORE_SIDES))])
        sv += [s] * CORE_SIDES
    rp.loft(bm, rings, cap_start=cap_start, cap_end=len(rings[-1]) > 1)


def add_clump(bm, sv, q, path, c, s_a, length, theta0):
    """One flame-shaped fur clump: a closed wedge from inside the core out to a point past the
    outline. Section: four points on its outer face, two on its underside buried in the core."""
    length = min(length, 0.995 - s_a)
    r_ref = core_radius(q, s_a + length * 0.4)
    rings = []
    for u in list(CLUMP_RINGS) + [1.0]:
        s = s_a + u * length
        p, t, n = path.at(s)
        b = t.cross(n)
        r = core_radius(q, s)
        th = theta0 + c["SWIRL"] * u
        e = (n * math.cos(th) + b * math.sin(th) * q["FLAT"]).normalized()
        a = t.cross(e).normalized()
        d = r * (0.85 + (0.15 + c["FLARE"]) * u ** 1.4) + r_ref * c["BULGE"] * math.sin(math.pi * u)   # end lifts off
        if u >= 1.0:
            rings.append([bm.verts.new(p + e * d)])
            sv.append(s)
            continue
        w = c["WIDTH"] * r_ref * 0.5 * (1 - u) ** 0.7 * (0.8 + 0.9 * u)
        h = c["THICK"] * r_ref * 0.5 * (1 - u) ** 0.6 * (0.8 + 0.6 * u)
        top = p + e * d
        under = p + e * min(d - h * 0.3, r * CLUMP_ROOT)       # buried in the core
        pts = [top + a * (-w), top + a * (-0.5 * w) + e * h, top + a * (0.5 * w) + e * h, top + a * w,
               under + a * (0.45 * w), under + a * (-0.45 * w)]
        rings.append([bm.verts.new(v) for v in pts])
        sv += [s] * len(pts)
    rp.loft(bm, rings, cap_start=True, cap_end=False)


def build_tail_meshes(q, path):
    """[(bm, svals)] for Tail (root..TIP_S, core + clumps) and TailTip (the rest)."""
    parts = [(bmesh.new(), []), (bmesh.new(), [])]
    add_core(*parts[0], q, path, 0.0, q["TIP_S"], True)
    add_core(*parts[1], q, path, q["TIP_S"], 1.0, True)
    c = q["CLUMPS"]
    step = (c["S1"] - c["S0"]) / (c["ROWS"] - 1)
    for k in range(c["ROWS"]):
        for j in range(c["PER_ROW"]):
            # fixed pseudo-random stagger (re-runs match): breaks the rows so they never band
            s_a = c["S0"] + step * (k + 0.35 * math.sin(k * 5.1 + j * 2.7))
            theta = 2 * math.pi * (j + 0.5 * (k % 2) + 0.18 * math.sin(k * 3.7 + j * 1.9)) / c["PER_ROW"]
            grade = CLUMP_GRADE[0] + (CLUMP_GRADE[1] - CLUMP_GRADE[0]) * (k / (c["ROWS"] - 1))
            length = c["LEN"] * grade * (1 + 0.15 * math.sin(k * 2.3 + j * 4.1))
            bm, sv = parts[1] if s_a + length * 0.5 >= q["TIP_S"] else parts[0]
            add_clump(bm, sv, q, path, c, max(0.06, s_a), length, theta)
    return parts


def tail_weights(s, joints):
    """[(bone, weight)] for arc param s: smooth blends across each joint."""
    names = ["TailBase"] + ["Tail%d" % (k + 1) for k in range(TAIL_BONES)]
    b = (joints[1] - joints[0]) * JOINT_BLEND
    ramps = [1.0] + [smoothstep(j - b, j + b, s) for j in joints[:TAIL_BONES]] + [0.0]
    return [(names[i], ramps[i] - ramps[i + 1]) for i in range(len(names)) if ramps[i] - ramps[i + 1] > 1e-4]


def build_tail(name, root_col):
    q = TAILS[name]
    col = collection(name, root_col)
    path = Path(q["PATH"])
    arm = new_armature(name + "_Rig", col)
    eb = arm.data.edit_bones
    root = eb.new("Root")
    root.head, root.tail = WAIST_BACK, WAIST_BACK + Vector((0, ROOT_BONE_LEN, 0))
    root.align_roll(Vector((1, 0, 0)))
    root.use_deform = False
    s_att = path.param_of(WAIST_BACK)
    joints = [s_att + (0.97 - s_att) * k / TAIL_BONES for k in range(TAIL_BONES + 1)]
    prev = eb.new("TailBase")
    p0, _, n0 = path.at(0.0)
    prev.head, prev.tail = p0, path.at(joints[0])[0]
    prev.align_roll(n0)
    prev.parent = root
    for k in range(TAIL_BONES):
        bone = eb.new("Tail%d" % (k + 1))
        ph, _, nh = path.at(joints[k])
        bone.head, bone.tail = ph, path.at(joints[k + 1])[0]
        bone.align_roll(nh)
        bone.parent, bone.use_connect = prev, True
        prev = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    objs = []
    for (bm, sv), region, mat in zip(build_tail_meshes(q, path), ("Tail", "TailTip"), ("FurOuter", "FurTip")):
        vv = [s if region == "Tail" else 1.0 for s in sv]   # darker toward the root
        o = new_object("%s_%s" % (name, region), bm, material(mat), col, vv, TAIL_SHARP_DEG)
        o["region"] = mat
        skin(o, arm, [tail_weights(s, joints) for s in sv])
        objs.append(o)
    return arm, objs, path


# ---------------------------------------------------------------------------------- rig -------
def new_armature(name, col):
    """A fresh armature object in edit mode (caller adds bones, then returns to object mode)."""
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    if bpy.data.armatures.get(name):
        bpy.data.armatures.remove(bpy.data.armatures[name])
    ob = bpy.data.objects.new(name, bpy.data.armatures.new(name))
    col.objects.link(ob)
    ob.hide_render = True
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    return ob


def skin(obj, arm, weights_per_vert):
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    for vi, ws in enumerate(weights_per_vert):
        for name, w in ws:
            vg = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
            vg.add([vi], w, "REPLACE")


def pose(arm, bend=("Z", 0.0), ear_deg=0.0, flick=0.0):
    """Deformation check: each Tail joint bent bend[1] degrees about local bend[0] (Z = the side
    axis, X = sideways), each ear folded back ear_deg (about local Z, which is world +X: + local Z
    tips it forward, so back is negative) and flicked outward `flick` degrees (about local X,
    world +Y: the left ear goes +, the right -). Defaults = rest."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        if pb.name.startswith("Tail") and pb.name != "TailBase":
            rot = [0.0, 0.0, 0.0]
            rot["XYZ".index(bend[0])] = math.radians(bend[1])
            pb.rotation_euler = rot
        if pb.name in ("EarL", "EarR"):
            side = 1 if pb.name == "EarL" else -1
            pb.rotation_euler = (math.radians(flick * side), 0, math.radians(-ear_deg))
    bpy.context.view_layer.update()


# ---------------------------------------------------------------------------------- export ----
def r3(v):
    return [round(x, 3) for x in v]


def to_roblox(v):
    return [round(v[0], 3), round(v[2], 3), round(-v[1], 3)]


def shift_set(arm, objs, offset):
    """Move a set's rest geometry and bones by offset (Armature.transform: moving edit bones one by
    one would move connected joints twice)."""
    m = Matrix.Translation(offset)
    for o in objs:
        o.data.transform(m)
    arm.data.transform(m)
    bpy.context.view_layer.update()


def export_set(name, arm, objs, attach, attach_name, extra):
    """FBX + JSON in attachment space (the attachment = the origin), then move back."""
    pose(arm)
    shift_set(arm, objs, -attach)
    try:
        for o in bpy.context.selected_objects:
            o.select_set(False)
        for o in [arm] + objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.export_scene.fbx(filepath=os.path.join(HERE, name + ".fbx"), use_selection=True,
                                 object_types={"ARMATURE", "MESH"}, apply_unit_scale=True,
                                 apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y",
                                 mesh_smooth_type="EDGE", add_leaf_bones=False, bake_anim=False,
                                 primary_bone_axis="Y", secondary_bone_axis="X", use_armature_deform_only=False)
        meshes = {}
        for o in objs:
            ws = [v.co for v in o.data.vertices]
            mn = Vector([min(v[i] for v in ws) for i in range(3)])
            mx = Vector([max(v[i] for v in ws) for i in range(3)])
            meshes[o.name] = dict(region=o["region"], tris=tri_count(o), center=r3((mn + mx) / 2), size=r3(mx - mn))
        bones = {}
        for b in arm.data.bones:
            bones[b.name] = dict(parent=b.parent.name if b.parent else None, head=r3(b.head_local),
                                 tail=r3(b.tail_local), roblox_head=to_roblox(b.head_local),
                                 deform=b.use_deform)
        report = dict(
            name=name, attachment=attach_name, attachment_avatar_space=r3(attach),
            units="1 Blender unit = 1 stud; positions relative to the attachment (Blender X right/avatar left, "
                  "-Y avatar front, Z up)",
            roblox_mapping="a Blender point (x, y, z) is (x, z, -y) in the attachment's Roblox space; "
                           "mesh Size = (bx, bz, by), CFrame = CFrame.Angles(0, math.pi, 0) * CFrame.new(-cx, cz, cy)",
            colors={k: r3(v[:3]) for k, v in COLORS.items()},
            shade=dict(file=SHADE_FILE, uv="V only (U = 0.5)", darkest=SHADE_MIN, fade_to_white_at_v=SHADE_REACH),
            meshes=meshes, tris_total=sum(m["tris"] for m in meshes.values()), bones=bones)
        report.update(extra)
        with open(os.path.join(HERE, name + ".json"), "w") as fh:
            json.dump(report, fh, indent=1)
    finally:
        shift_set(arm, objs, attach)
    return report


# ---------------------------------------------------------------------------------- fan -------
def build_fan(root_col, tail_objs):
    """The multi-tail proof: rest copies of one tail turned about WaistBack's back axis."""
    col = collection("FoxFan", root_col)
    for ang in FAN_ANGLES:
        m = (Matrix.Translation(WAIST_BACK) @ Matrix.Rotation(math.radians(ang), 4, "Y")
             @ Matrix.Translation(-WAIST_BACK))
        for o in tail_objs:
            me = o.data.copy()
            me.transform(m)
            c = bpy.data.objects.new("Fan%+d_%s" % (ang, o.name), me)
            col.objects.link(c)
    return col


# ---------------------------------------------------------------------------------- sheet -----
# (name, eye direction from target, target, ortho scale or None = perspective, distance)
VIEWS = [
    ("front", (0, -1, 0.10), (0, 0.9, 0.7), 7.4, 20),
    ("side", (1, 0, 0.08), (0, 1.2, 0.7), 7.4, 20),
    ("back", (0, 1, 0.12), (0, 0.9, 0.7), 7.4, 20),
    ("threequarter", (0.8, 0.85, 0.38), (0.2, 1.0, 0.8), 7.6, 20),
    ("bent", (1, 0.35, 0.15), (0.2, 1.4, 0.2), 8.6, 20),
    ("ears", (-0.55, -0.85, 0.35), (0, 0, 3.45), None, 4.2),
]
CLOSE_VIEW = ((0.85, 0.75, 0.35), 4.6)   # close-up of the bent tail: direction, distance


def render_tiles(scene, root_col, out_dir, rows, res=420):
    rp.setup_render(scene, res=(res, res))
    layer = scene.view_layers[0].layer_collection.children[root_col.name]

    def show(names):
        for c in layer.children:
            c.exclude = c.name not in names

    shots = []
    for tail, ears in rows:
        show({tail, ears})
        t_arm, e_arm = bpy.data.objects[tail + "_Rig"], bpy.data.objects[ears + "_Rig"]
        for view, d, tgt, ortho, dist in VIEWS:
            bent = view == "bent"
            pose(t_arm, TAILS[tail]["BEND"] if bent else ("Z", 0.0))
            pose(e_arm, ear_deg=70.0 if bent else 0.0)
            eye = Vector(tgt) + Vector(d).normalized() * dist
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (tail, view)), tuple(eye), tgt,
                                   ortho=ortho, lens=50))
        # Close-up in the bent pose, where gaps between clumps would open widest.
        pose(t_arm, TAILS[tail]["BEND"])
        mid = sum((v.co for v in bpy.data.objects[tail + "_Tail"].evaluated_get(
            bpy.context.evaluated_depsgraph_get()).data.vertices), Vector()) / len(bpy.data.objects[tail + "_Tail"].data.vertices)
        d, dist = CLOSE_VIEW
        eye = mid + Vector(d).normalized() * dist
        shots.append(rp.render(scene, os.path.join(out_dir, "%s_close.png" % tail), tuple(eye), tuple(mid), lens=50))
        pose(t_arm)
        pose(e_arm)
    show({"FoxFan", PAIRS[0][1]})
    for view, d, tgt, ortho in (("back", (0, 1, 0.12), (0, 0.9, 0.9), 8.0),
                                ("threequarter", (0.8, 0.85, 0.38), (0.2, 1.0, 0.9), 8.2),
                                ("side", (1, 0, 0.08), (0, 1.2, 0.8), 7.8)):
        eye = Vector(tgt) + Vector(d).normalized() * 20
        shots.append(rp.render(scene, os.path.join(out_dir, "FoxFan_%s.png" % view), tuple(eye), tgt, ortho=ortho))
    for c in layer.children:
        c.exclude = c.name == "FoxFan"
    return shots


EAR_ROWS_SHEET = ["FoxEarsBroad", "FoxEarsSleek", "FoxEarsLong"]   # cute first, then the cool pair
EAR_TARGET = (0.0, 0.0, 3.4)
# (name, eye direction, ortho scale): the head and ears from far, orthographic
EAR_VIEWS = [("front", (0, -1, 0.06), 2.5), ("side", (1, 0, 0.06), 2.5), ("back", (0, 1, 0.06), 2.5),
             ("fold", (1, 0.15, 0.15), 2.7), ("flick", (0.25, -1, 0.2), 2.7)]
EAR_FOLD, EAR_FLICK = 60.0, 35.0      # the sheet's deformation checks (degrees)
# game-camera read: 12 studs away at true on-screen size (1080p, 70 deg FOV: the head is ~75 px)
EAR_GAME = [("game_back", (0.35, 1, 0.35)), ("game_front", (0.35, -1, 0.25))]
GAME_DIST, GAME_LENS = 12.0, 65
RATIO_TARGET = 0.45   # the brief's upper height ratio (ear height / head height), previewed per set
# seating close-ups: eye just above head height, close, looking at the left ear's base
EAR_SEATS = [("seat_side", (1.0, 0.05, 0.10)), ("seat_back", (0.35, 1.0, 0.10)), ("seat_front", (0.35, -1.0, 0.10))]
SEAT_DIST = 1.5


def render_ear_tiles(scene, root_col, out_dir, names, res=420):
    rp.setup_render(scene, res=(res, res))
    layer = scene.view_layers[0].layer_collection.children[root_col.name]
    shots = []
    for name in names:
        for c in layer.children:
            c.exclude = c.name != name
        arm, p = bpy.data.objects[name + "_Rig"], EARS[name]
        for view, d, ortho in EAR_VIEWS:
            pose(arm, ear_deg=EAR_FOLD if view == "fold" else 0.0, flick=EAR_FLICK if view == "flick" else 0.0)
            eye = Vector(EAR_TARGET) + Vector(d).normalized() * 20
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (name, view)), tuple(eye),
                                   EAR_TARGET, ortho=ortho, lens=50))
        pose(arm)
        base = Vector((p["X"], EAR_Y, head_surface_z(p["X"], EAR_Y) + 0.12))
        for view, d in EAR_SEATS:
            eye = base + Vector(d).normalized() * SEAT_DIST
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (name, view)), tuple(eye),
                                   tuple(base), lens=50))
        # the same ears scaled about the hat point to the brief's ratio target (height RATIO_TARGET
        # of the head's height), a preview for the call on size; not exported
        lo, hi = head_bbox()
        k = RATIO_TARGET * (hi.z - lo.z) / ear_height([o for o in bpy.data.collections[name].objects
                                                       if o.type == "MESH"])
        keep = arm.matrix_world.copy()
        arm.matrix_world = Matrix.Translation(HAT) @ Matrix.Scale(k, 4) @ Matrix.Translation(-HAT) @ keep
        bpy.context.view_layer.update()
        eye = Vector(EAR_TARGET) + Vector((0.35, -1, 0.15)).normalized() * 20
        shots.append(rp.render(scene, os.path.join(out_dir, "%s_ratio.png" % name), tuple(eye), EAR_TARGET,
                               ortho=2.5, lens=50))
        arm.matrix_world = keep
        bpy.context.view_layer.update()
        for view, d in EAR_GAME:
            tgt = Vector((0, 0, 2.6))
            eye = tgt + Vector(d).normalized() * GAME_DIST
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (name, view)), tuple(eye),
                                   tuple(tgt), lens=GAME_LENS))
    for c in layer.children:
        c.exclude = c.name == "FoxFan"
    return shots


def head_bbox():
    """The R6 head mesh's bounding box (min, max): the rig's vertices above the neck."""
    rig = next(o for o in rp.rig_objects() if o.type == "MESH")
    vs = [rig.matrix_world @ v.co for v in rig.data.vertices]
    vs = [v for v in vs if v.z > 2.0 and abs(v.x) < 1.0]
    return (Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)]))


def ear_proportions(objs):
    """Ear size against the head it sits on: visible height / head height, base width / head width."""
    lo, hi = head_bbox()
    h, w = hi.z - lo.z, hi.x - lo.x
    left = next(o for o in objs if o.name.endswith("_LeftEar"))
    vh = ear_height(objs)
    return dict(visible_height=vh, base_width=round(left["base_width"], 3),
                head_size=r3(hi - lo), height_to_head=round(vh / h, 2),
                base_width_to_head=round(left["base_width"] / w, 2))


def ear_height(objs):
    """Visible height: the ears' top above the head surface under the ear base centre."""
    p = EARS[objs[0].name.split("_")[0]]
    top = max((o.matrix_world @ v.co).z for o in objs for v in o.data.vertices)
    return round(top - head_surface_z(p["X"], EAR_Y), 3)


# ---------------------------------------------------------------------------------- main ------
def main():
    scene = bpy.data.scenes.get(SCENE) or rp.use_scene(SCENE)
    bpy.context.window.scene = scene
    rp.import_rig(scene)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    root_col = bpy.data.collections.get(ROOT_COLLECTION) or bpy.data.collections.new(ROOT_COLLECTION)
    if root_col.name not in scene.collection.children:
        scene.collection.children.link(root_col)
    keep = set(TAILS) | set(EARS) | {"FoxFan"}
    for c in list(root_col.children):            # drop collections of retired builds
        if c.name not in keep:
            for o in list(c.objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.collections.remove(c)
    shade_image()
    report = {}
    built = {}
    for name in EARS:
        if ONLY and name not in ONLY:
            continue
        arm, objs = build_ears(name, root_col)
        p = EARS[name]
        built[name] = (arm, objs, HAT, "HatAttachment",
                       dict(mood=p["mood"], proportions=ear_proportions(objs)))
    for name, q in TAILS.items():
        if ONLY and name not in ONLY:
            continue
        arm, objs, path = build_tail(name, root_col)
        built[name] = (arm, objs, WAIST_BACK, "WaistBackAttachment",
                       dict(fan=dict(axis="attachment back axis (Blender +Y, Roblox +Z)", pivot=[0, 0, 0],
                                     angles_3=[-40, 0, 40], angles_5=[-50, -25, 0, 25, 50],
                                     angles_9=[-72, -54, -36, -18, 0, 18, 36, 54, 72])))
    for name, (arm, objs, attach, att_name, extra) in built.items():
        report[name] = dict({o.name: tri_count(o) for o in objs}, **extra)
        if EXPORT:
            export_set(name, arm, objs, attach, att_name, extra)
    if FAN_TAIL in built:
        build_fan(root_col, built[FAN_TAIL][1])
    print(json.dumps(report))
    if RENDER:
        out = os.path.join(HERE, "renders")
        if any(n in built for n in TAILS):
            print(len(render_tiles(scene, root_col, out, PAIRS)), "tail tiles")
        if any(n in built for n in EARS):
            print(len(render_ear_tiles(scene, root_col, out, [n for n in EAR_ROWS_SHEET if n in built])), "ear tiles")
    if EXPORT:
        rp.save_blend(scene, os.path.join(HERE, "Fox.blend"))

main()
