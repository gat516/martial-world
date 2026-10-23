r"""Demonic Human cosmetics: curved dark horns and a thin spaded whip tail for the player's R6 avatar.

Directions (each a horn pair + a tail with its own silhouette; any horns go with any tail):
  Ram      DemonHornsRam (HatAttachment)     + DemonTailWhip  (WaistBackAttachment)
  Swept    DemonHornsSwept                   + DemonTailHook
  Crescent DemonHornsCrescent                + DemonTailTrail
The purple flame wisp in the reference is VFX, not a mesh: its attachment point is the JSON's
`vfx_wisp` anchor (on the tail, just above the spade), for the vfx agent.

Run in a visible Blender window (tools/blender_live.sh, see its header):
    tools/blender_live.sh run demonic-human art/player/cosmetics/demonic-human/build_demonic_human.py
Optional globals: RENDER (default True: sheet tiles into renders/), EXPORT (default False until a
direction is picked: FBX, JSON, shade PNG), SAVE_BLEND (default True), ONLY (set of set names).
Then stitch the sheet with make_sheet.py.

Axes and units (the R6 reference, art/rig/r6_rigged.fbx, see art/rig/rig_preview.py):
  1 Blender unit = 1 stud. +X = the avatar's left, it faces -Y, Z up. Hips z 0, torso z 0..2,
  head z 2.08..3.10 (1.20 wide, 1.20 deep, 1.02 tall), feet z -2.
  Head HatAttachment        = (0, 0, 3.1)
  Torso WaistBackAttachment = (0, 0.5, 0)
Built in avatar space; the export moves each set so its attachment is the origin.

Regions (one mesh and material each, so each is one MeshPart with its own Color):
  Horn (<Horns>_LeftHorn, _RightHorn), HornVein (_LeftHornVein, _RightHornVein),
  Tail (<Tail>_Tail), Spade (<Tail>_Spade), TailVein (<Tail>_TailVein: the tail's vein and the
  spade's inlay). Depth shading is the shared greyscale ramp on UV V (same settings as the fox).

Rig (bones named like Motor6Ds; Root = the attachment point, never deforms):
  Horns: Root -> HornLBase -> HornL, Root -> HornRBase -> HornR  (Base holds what's inside the head)
  Tail:  Root -> TailBase -> Tail1 -> ... -> Tail5               (the spade rides Tail5)
Seating: every horn starts inside the head; the build asserts its whole root ring is under the
head's surface, so it pierces the head with no gap from any side.
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
import rig_preview as rp  # noqa: E402

RENDER = globals().get("RENDER", True)
EXPORT = globals().get("EXPORT", False)
SAVE_BLEND = globals().get("SAVE_BLEND", True)
ONLY = globals().get("ONLY")

SCENE = "Cosmetics"
ROOT_COLLECTION = "DemonicHumanCosmetics"
HAT = Vector((0.0, 0.0, 3.1))
WAIST_BACK = Vector((0.0, 0.5, 0.0))
SHARP_DEG = 28.0          # house crease: horn ridges and spade bevels shade hard
TAIL_SHARP_DEG = 60.0     # the whip itself stays smooth

# Colours (linear). Obsidian black with a crimson vein; plain SmoothPlastic in Roblox.
COLORS = {
    "Horn":     (0.030, 0.024, 0.028, 1),   # obsidian, a hint of warm crimson-black
    "HornVein": (0.50, 0.020, 0.030, 1),    # deep crimson
    "Tail":     (0.034, 0.028, 0.034, 1),   # dark matte skin
    "Spade":    (0.030, 0.024, 0.028, 1),   # obsidian like the horns
    "TailVein": (0.50, 0.020, 0.030, 1),
}
ROUGH = {"Horn": 0.32, "HornVein": 0.5, "Tail": 0.65, "Spade": 0.32, "TailVein": 0.5}
SHADE_FILE = "demonic_shade.png"   # the fox's ramp settings, so it matches fox_shade.png
MAT_PREFIX = "Demon_"             # material names: Demon_Horn, Demon_HornVein, ... (the region is the suffix)
SHADE_MIN = 0.55
SHADE_REACH = 0.45

# ----------------------------------------------------------------------------------------------
# Intent: the horns are the hero (the read from 40 studs: a crown of dark curves), the tail the
# secondary line, the veins the detail. Sinister but refined: thick, smooth, controlled curves with
# hooked points, never tall needles. Each horn is a tube along PATH (left horn, avatar space; the
# right is its mirror), the first point buried in the head.
# R0 base radius, PROFILE radius along the length (s 0..1, x R0), FLAT section depth/width,
# RIDGES grooves cut around the horn (plates), VEINS (s0, s1, angle0, angle1, half-width) raised
# crimson lines (angle around the section, radians from the side normal).
HORNS = {
    # the reference: rises back and out, then curls down beside the head, tip hooking forward
    "DemonHornsRam": dict(
        label="Ram", mood="sinister, classic",
        PATH=[(0.30, 0.05, 2.84), (0.38, 0.08, 3.12), (0.52, 0.18, 3.32), (0.74, 0.34, 3.36),
              (0.90, 0.46, 3.12), (0.93, 0.36, 2.82), (0.86, 0.08, 2.68), (0.81, -0.16, 2.78),
              (0.80, -0.27, 2.95)],
        R0=0.17, PROFILE=[(0, 1.1), (0.18, 1.0), (0.45, 0.82), (0.72, 0.55), (0.9, 0.30), (1, 0.05)],
        FLAT=0.82, RIDGES=7,
        VEINS=[(0.16, 0.92, 0.3, 1.6, 0.034), (0.38, 0.60, 1.0, 2.3, 0.024), (0.55, 0.78, 1.3, 0.4, 0.022)]),
    # aristocratic: low and sleek, from the brow sweeping back past the head, tips lifting
    "DemonHornsSwept": dict(
        label="Swept", mood="refined, aristocratic",
        PATH=[(0.24, -0.16, 2.86), (0.28, -0.20, 3.12), (0.34, -0.08, 3.30), (0.42, 0.22, 3.40),
              (0.52, 0.56, 3.44), (0.60, 0.86, 3.54), (0.63, 1.04, 3.72)],
        R0=0.155, PROFILE=[(0, 1.1), (0.2, 1.0), (0.55, 0.82), (0.8, 0.55), (0.93, 0.30), (1, 0.05)],
        FLAT=0.80, RIDGES=5,
        VEINS=[(0.12, 0.90, 0.8, 1.2, 0.030), (0.40, 0.66, 1.1, 2.0, 0.022)]),
    # bold: thick crescents rising out and curving in over the head, a "U" from the front
    "DemonHornsCrescent": dict(
        label="Crescent", mood="bold, menacing",
        PATH=[(0.30, 0.0, 2.84), (0.40, 0.0, 3.12), (0.60, -0.02, 3.26), (0.76, -0.05, 3.44),
              (0.75, -0.08, 3.62), (0.63, -0.11, 3.74), (0.50, -0.13, 3.78)],
        R0=0.20, PROFILE=[(0, 1.1), (0.2, 1.0), (0.5, 0.78), (0.78, 0.48), (0.92, 0.26), (1, 0.05)],
        FLAT=0.85, RIDGES=5,
        VEINS=[(0.14, 0.90, 0.2, 0.9, 0.036), (0.36, 0.62, 0.6, -0.6, 0.026)]),
}

# Tails: a thin whip that still reads (radius about 0.12), on a 6-bone chain, ending in a spade.
# PATH control points (avatar space; the root is inside the torso and the whip leaves the back
# about 0.8 above the waist, so a leg kicked back 57 degrees while running passes under it), R base radius, PROFILE along
# the length, SPADE outline kind ("arrow" barbed arrowhead, "heart" card spade, "leaf" long blade),
# SPADE_L length, SPADE_W width scale, SPADE_UP the direction its flat faces (world), BEND the
# sheet's bent pose per joint (local axis, degrees), VEIN (s0, s1, angle0, turns, half-width).
WHIP = [(0, 1.15), (0.10, 1.0), (0.45, 0.80), (0.80, 0.62), (1, 0.50)]
TAILS = {
    # the reference: arcs up behind, then falls in an S to the right, arrowhead at knee height
    "DemonTailWhip": dict(
        label="Whip", mood="sinister, classic",
        PATH=[(0, 0.15, 0.55), (0, 0.75, 0.82), (0, 1.30, 1.05), (-0.15, 1.85, 1.05), (-0.45, 2.30, 0.80),
              (-0.70, 2.50, 0.25), (-0.85, 2.45, -0.35), (-0.90, 2.30, -0.75)],
        R=0.15, PROFILE=WHIP, SPADE="arrow", SPADE_L=0.70, SPADE_W=1.0, SPADE_UP=(0.2, 1, 0),
        BEND=("Z", -25), VEIN=(0.12, 0.96, 0.0, 1.0, 0.026)),
    # tempting: rises behind the back into a question-mark hook, a card spade at shoulder height
    "DemonTailHook": dict(
        label="Hook", mood="tempting, refined",
        PATH=[(0, 0.15, 0.55), (0, 0.75, 0.82), (0.05, 1.30, 1.00), (0.12, 1.62, 1.40), (0.22, 1.58, 2.02),
              (0.42, 1.42, 2.38), (0.66, 1.30, 2.36), (0.80, 1.25, 2.12)],
        R=0.15, PROFILE=WHIP, SPADE="heart", SPADE_L=0.62, SPADE_W=1.0, SPADE_UP=(0, 1, 0),
        BEND=("Z", 20), VEIN=(0.12, 0.96, 0.0, 1.0, 0.026)),
    # prowling: streams back low behind the legs and sweeps aside, the blade tip lifting
    "DemonTailTrail": dict(
        label="Trail", mood="dangerous, prowling",
        PATH=[(0, 0.15, 0.55), (0, 0.75, 0.82), (0.05, 1.50, 0.45), (0.15, 2.25, -0.45), (0.35, 2.75, -1.05),
              (0.70, 3.15, -1.25), (1.05, 3.30, -1.05), (1.25, 3.25, -0.70)],
        R=0.155, PROFILE=WHIP, SPADE="leaf", SPADE_L=0.85, SPADE_W=1.0, SPADE_UP=(0, 0.3, 1),
        BEND=("X", 18), VEIN=(0.12, 0.96, 0.0, 1.0, 0.026)),
}
DIRECTIONS = [("Ram", "DemonHornsRam", "DemonTailWhip"), ("Swept", "DemonHornsSwept", "DemonTailHook"),
              ("Crescent", "DemonHornsCrescent", "DemonTailTrail")]

HORN_SIDES = 10
HORN_STATIONS = 24
RIDGE_RANGE = (0.14, 0.80)   # s span of the grooves (none inside the head or at the point)
RIDGE_DEPTH = 0.10           # groove depth, fraction of the local radius
RIDGE_HALF = 0.012           # groove half-width in s
HORN_SINK_MIN = 0.03         # every root-ring vertex sits at least this far inside the head
VEIN_RISE = 0.45             # vein ridge height above the surface, fraction of its half-width
TAIL_SIDES = 10
TAIL_STATIONS = 64
TAIL_BONES = 5
JOINT_BLEND = 0.45
SPADE_THICK = 0.13           # spade thickness at the centre (studs); edges are a third of it
SPADE_OVERLAP = 0.22         # the whip's end runs this fraction of the spade length into it
ROOT_BONE_LEN = 0.25
RUN_DEG = 57.3               # R6 run: limbs swing 1 radian each way


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
    img = bpy.data.images.get(SHADE_FILE)
    if img is not None:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(SHADE_FILE, 4, 128, alpha=False)
    img.colorspace_settings.name = "sRGB"
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
    m = rp.preview_material(MAT_PREFIX + name, COLORS[name])   # race-prefixed: other races share the Blender data names
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
    nt.links.new(next(s for s in mix.outputs if s.type == "RGBA"), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = ROUGH[name]
    return m


def new_object(name, bm, mat, col, vvals, sharp):
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
        lc.children[col.name].exclude = False
    return col


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


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
            n = (n - t * n.dot(t))
            n = n.normalized() if n.length > 1e-6 else t.orthogonal().normalized()
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


def add_ridge(bm, vals, pts, val_of=None):
    """A raised vein: a closed diamond-section tube along pts = [(point on the surface, outward
    normal, tangent, half-width)], its underside sunk into the surface, both ends a point."""
    rings = []
    for i, (p, e, t, w) in enumerate(pts):
        a = t.cross(e).normalized()
        if w <= 1e-4:
            rings.append([bm.verts.new(p - e * 0.004)])
        else:
            sink = w * 0.9
            rings.append([bm.verts.new(v) for v in (p + a * w - e * sink * 0.4, p + e * w * VEIN_RISE,
                                                    p - a * w - e * sink * 0.4, p - e * sink)])
        vals += [val_of(i) if val_of else 0.0] * len(rings[-1])
    rp.loft(bm, rings, cap_start=True, cap_end=True)


# ---------------------------------------------------------------------------------- body ------
def rig_mesh():
    return next(o for o in rp.rig_objects() if o.type == "MESH")


def depth_inside(p):
    """How far point p (avatar space) is inside the R6 body surface (negative = outside)."""
    rig = rig_mesh()
    inv = rig.matrix_world.inverted()
    ok, loc, nrm, _ = rig.closest_point_on_mesh(inv @ p)
    loc = rig.matrix_world @ loc
    nrm = (inv.transposed().to_3x3() @ nrm).normalized()
    return -(p - loc).dot(nrm)


def bbox_of(pred):
    rig = rig_mesh()
    vs = [rig.matrix_world @ v.co for v in rig.data.vertices]
    vs = [v for v in vs if pred(v)]
    return (Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)]))


def head_bbox():
    return bbox_of(lambda v: v.z > 2.0 and abs(v.x) < 1.0)


def torso_bbox():
    return bbox_of(lambda v: 0.0 <= v.z <= 2.0 and abs(v.x) < 1.0)


# ---------------------------------------------------------------------------------- horns -----
def horn_radius(p, s, grooves=True):
    r = p["R0"] * interp_profile(p["PROFILE"], s)
    if grooves and p["RIDGES"]:
        a, b = RIDGE_RANGE
        for k in range(p["RIDGES"]):
            c = a + (b - a) * (k + 0.5) / p["RIDGES"]
            r *= 1 - RIDGE_DEPTH * max(0.0, 1 - abs(s - c) / RIDGE_HALF)
    return r


def horn_stations(p):
    ss = {i / HORN_STATIONS for i in range(HORN_STATIONS + 1)}
    if p["RIDGES"]:
        a, b = RIDGE_RANGE
        for k in range(p["RIDGES"]):
            c = a + (b - a) * (k + 0.5) / p["RIDGES"]
            ss |= {c - RIDGE_HALF, c, c + RIDGE_HALF}
    return sorted(s for s in ss if s < 0.985)


def section_point(path, p, s, th, r):
    c, t, n = path.at(s)
    b = t.cross(n)
    e = n * math.cos(th) + b * math.sin(th) * p["FLAT"]
    return c + e * r, (n * math.cos(th) + b * math.sin(th) / p["FLAT"]).normalized(), t


def build_horn_local(p):
    """Left horn (avatar space): (horn bm, s per vertex, vein bm, s per vertex)."""
    path = Path(p["PATH"])
    bm, sv = bmesh.new(), []
    rings = []
    for s in horn_stations(p):
        r = horn_radius(p, s)
        rings.append([bm.verts.new(section_point(path, p, s, 2 * math.pi * k / HORN_SIDES, r)[0])
                      for k in range(HORN_SIDES)])
        sv += [s] * HORN_SIDES
    c, t, _ = path.at(1.0)
    rings.append([bm.verts.new(c)])
    sv.append(1.0)
    rp.loft(bm, rings, cap_start=True, cap_end=False)
    vb, vv = bmesh.new(), []
    for s0, s1, a0, a1, w in p["VEINS"]:
        n = max(6, int((s1 - s0) * 34))
        pts, ss = [], []
        for i in range(n + 1):
            u = i / n
            s = s0 + (s1 - s0) * u
            th = a0 + (a1 - a0) * u + 0.12 * math.sin(u * 9.0)
            q, e, tt = section_point(path, p, s, th, horn_radius(p, s, grooves=False))
            ww = w * min(1.0, u / 0.15, (1 - u) / 0.35) * min(1.0, horn_radius(p, s, False) / 0.08)
            pts.append((q, e, tt, max(0.0, ww)))
            ss.append(s)
        add_ridge(vb, vv, pts, lambda i, ss=ss: ss[i])
    return path, bm, sv, vb, vv


def mirror_bm(bm):
    out = bm.copy()
    for v in out.verts:
        v.co.x = -v.co.x
    return out


def build_horns(name, root_col):
    p = HORNS[name]
    col = collection(name, root_col)
    path, horn, hs, vein, vs = build_horn_local(p)
    # seating: the root ring and cap lie inside the head
    root = [v.co.copy() for v, s in zip(horn.verts, hs) if s == 0.0]
    worst = min(depth_inside(v) for v in root)
    assert worst >= HORN_SINK_MIN, "%s root ring pokes out of the head (%.3f)" % (name, worst)
    exit_s = next(i / 200 for i in range(201) if depth_inside(path.at(i / 200)[0]) < 0)
    arm = new_armature(name + "_Rig", col)
    eb = arm.data.edit_bones
    rb = eb.new("Root")
    rb.head, rb.tail = HAT, HAT + Vector((0, 0, ROOT_BONE_LEN))
    rb.align_roll(Vector((1, 0, 0)))
    rb.use_deform = False
    for tag, side in (("L", 1), ("R", -1)):
        m = Vector((side, 1, 1))
        h0, h1, tip = path.at(0)[0] * 1, path.at(exit_s)[0] * 1, path.at(0.55)[0] * 1
        h0, h1, tip = [Vector((v.x * side, v.y, v.z)) for v in (h0, h1, tip)]
        base = eb.new("Horn%sBase" % tag)
        base.head, base.tail = h0, h1
        base.align_roll(Vector((1, 0, 0)))
        base.parent = rb
        hb = eb.new("Horn%s" % tag)
        hb.head, hb.tail = h1, tip
        hb.align_roll(Vector((1, 0, 0)))
        hb.parent, hb.use_connect = base, True
    bpy.ops.object.mode_set(mode="OBJECT")
    objs = []
    for tag, nm, side in (("L", "Left", 1), ("R", "Right", -1)):
        for src, ss, region, sharp in ((horn, hs, "Horn", SHARP_DEG), (vein, vs, "HornVein", SHARP_DEG)):
            bm = src.copy() if side == 1 else mirror_bm(src)
            vv = [1.0 - 0.8 * s for s in ss] if region == "Horn" else [1.0] * len(ss)   # points darker
            o = new_object("%s_%s%s" % (name, nm, region), bm, material(region), col, vv, sharp)
            o["region"] = region
            w = [[("Horn%sBase" % tag, 1 - smoothstep(exit_s, exit_s + 0.08, s)),
                  ("Horn%s" % tag, smoothstep(exit_s, exit_s + 0.08, s))] for s in ss]
            skin(o, arm, w)
            objs.append(o)
    horn.free()
    vein.free()
    return arm, objs, dict(exit_s=exit_s, root_depth_min=round(worst, 3))


def horn_proportions(name, objs):
    lo, hi = head_bbox()
    hh, hw = hi.z - lo.z, hi.x - lo.x
    vs = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    top = max(v.z for v in vs)
    span = max(v.x for v in vs) - min(v.x for v in vs)
    back = max(v.y for v in vs) - hi.y
    p = HORNS[name]
    return dict(height_above_head=round(top - hi.z, 3), height_to_head=round((top - hi.z) / hh, 2),
                span=round(span, 3), span_to_head=round(span / hw, 2),
                base_diameter=round(2 * p["R0"], 3), base_to_head=round(2 * p["R0"] / hw, 2),
                length=round(Path(p["PATH"]).length, 3), length_to_head=round(Path(p["PATH"]).length / hh, 2),
                past_head_back=round(back, 3), head_size=[round(hw, 3), round(hi.y - lo.y, 3), round(hh, 3)])


# ---------------------------------------------------------------------------------- tail ------
def spade_outline(kind):
    """(u, v) outline, counter-clockwise: u 0 at the neck .. 1 at the point, v across (x length)."""
    if kind == "arrow":
        half = [(0.0, 0.07), (0.14, 0.11), (0.05, 0.33), (0.12, 0.43), (0.40, 0.37), (0.72, 0.17), (1.0, 0.0)]
    elif kind == "heart":   # a playing-card spade: two round lobes at the neck, a point ahead
        half = []
        for k in range(1, 15):
            a = math.pi * k / 14
            x = 16 * math.sin(a) ** 3
            y = 13 * math.cos(a) - 5 * math.cos(2 * a) - 2 * math.cos(3 * a) - math.cos(4 * a)
            half.append(((12.5 - y) / 29.5, x / 16 * 0.46))
        half = [(0.18, 0.07)] + [h for h in half if h[1] > 0.06 or h[0] > 0.5] + [(1.0, 0.0)]
    else:   # leaf: a long sleek blade
        half = [(0.0, 0.07)] + [(u, 0.07 * (1 - u) + 0.27 * math.sin(math.pi * u ** 0.8))
                                for u in (0.1, 0.2, 0.32, 0.45, 0.58, 0.7, 0.8, 0.9)] + [(1.0, 0.0)]
    right = [(u, -v) for u, v in half]          # neck .. tip
    left = [(u, v) for u, v in reversed(half[:-1])]   # tip-1 .. neck
    return right + left


def build_spade(q, path):
    """The spade: a bevelled two-tier slab on the path's end, flat facing SPADE_UP."""
    c_end, t_end, _ = path.at(1.0)
    L = q["SPADE_L"]
    fwd = t_end.normalized()
    up = Vector(q["SPADE_UP"])
    up = (up - fwd * up.dot(fwd)).normalized()
    side = fwd.cross(up).normalized()
    origin = c_end - fwd * (SPADE_OVERLAP * L)
    pts2 = spade_outline(q["SPADE"])
    bm = bmesh.new()
    edge = SPADE_THICK * 0.17

    def world(u, v, h):
        return origin + fwd * (u * L) + side * (v * L * q["SPADE_W"]) + up * h
    top = [bm.verts.new(world(u, v, edge)) for u, v in pts2]
    bot = [bm.verts.new(world(u, v, -edge)) for u, v in pts2]
    n = len(pts2)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    ft = bm.faces.new(top)
    fb = bm.faces.new(list(reversed(bot)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in (ft, fb):   # two bevelled tiers rising to the centre on each face
        bmesh.ops.inset_region(bm, faces=[f], thickness=0.045 * L, depth=SPADE_THICK * 0.22, use_even_offset=True)
        bmesh.ops.inset_region(bm, faces=[f], thickness=0.06 * L, depth=SPADE_THICK * 0.11, use_even_offset=True)
    frame = dict(origin=origin, fwd=fwd, side=side, up=up, L=L)
    # the crimson inlay: a ridge down the middle of each face, and one along each shoulder
    vb, vv = bmesh.new(), []
    centre_h = edge + SPADE_THICK * 0.33
    for sgn in (1, -1):
        e = up * sgn
        line = []
        for i in range(9):
            u = 0.22 + 0.62 * i / 8
            w = 0.022 * min(1.0, i / 2, (8 - i) / 3)
            line.append((world(u, 0, centre_h * sgn), e, fwd, w))
        add_ridge(vb, vv, line)
    return bm, vb, frame


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
    # whip
    bm, sv = bmesh.new(), []
    rings = []
    for i in range(TAIL_STATIONS + 1):
        s = i / TAIL_STATIONS
        c, t, n = path.at(s)
        b = t.cross(n)
        r = q["R"] * interp_profile(q["PROFILE"], s)
        rings.append([bm.verts.new(c + (n * math.cos(a) + b * math.sin(a)) * r)
                      for a in (2 * math.pi * k / TAIL_SIDES for k in range(TAIL_SIDES))])
        sv += [s] * TAIL_SIDES
    rp.loft(bm, rings, cap_start=True, cap_end=True)
    # vein: a crimson line spiralling gently along the whip
    vb, vs = bmesh.new(), []
    s0, s1, a0, turns, w = q["VEIN"]
    n_pts = 70
    line, ss = [], []
    for i in range(n_pts + 1):
        u = i / n_pts
        s = s0 + (s1 - s0) * u
        c, t, n = path.at(s)
        b = t.cross(n)
        a = a0 + 2 * math.pi * turns * u + 0.25 * math.sin(u * 23)
        e = n * math.cos(a) + b * math.sin(a)
        r = q["R"] * interp_profile(q["PROFILE"], s)
        line.append((c + e * r, e, t, w * min(1.0, u / 0.08, (1 - u) / 0.08)))
        ss.append(s)
    add_ridge(vb, vs, line, lambda i: ss[i])
    spade, svein, frame = build_spade(q, path)
    sp_vals = [1.0] * len(spade.verts)
    sv_vals = [1.0] * len(svein.verts)
    # merge the spade's inlay into the vein region (one TailVein MeshPart)
    me_tmp = bpy.data.meshes.new("_tmp_spadevein")
    svein.to_mesh(me_tmp)
    svein.free()
    vb.from_mesh(me_tmp)
    bpy.data.meshes.remove(me_tmp)
    vs += sv_vals
    objs = []
    for bmx, vals, region, sharp in ((bm, sv, "Tail", TAIL_SHARP_DEG), (spade, sp_vals, "Spade", SHARP_DEG),
                                     (vb, vs, "TailVein", SHARP_DEG)):
        shade = [0.25 + 0.75 * s for s in vals] if region == "Tail" else [1.0] * len(vals)
        o = new_object("%s_%s" % (name, region), bmx, material(region), col, shade, sharp)
        o["region"] = region
        skin(o, arm, [tail_weights(s, joints) for s in vals])
        objs.append(o)
    c_end = path.at(0.93)[0]
    anchors = dict(vfx_wisp=dict(point=r3(c_end), note="on the whip just above the spade; the purple "
                                 "flame wisp (VFX) attaches here, riding Tail5"),
                   spade_tip=dict(point=r3(frame["origin"] + frame["fwd"] * frame["L"])))
    return arm, objs, path, anchors


def tail_weights(s, joints):
    names = ["TailBase"] + ["Tail%d" % (k + 1) for k in range(TAIL_BONES)]
    b = (joints[1] - joints[0]) * JOINT_BLEND
    ramps = [1.0] + [smoothstep(j - b, j + b, s) for j in joints[:TAIL_BONES]] + [0.0]
    return [(names[i], ramps[i] - ramps[i + 1]) for i in range(len(names)) if ramps[i] - ramps[i + 1] > 1e-4]


def tail_proportions(name, objs, path):
    lo, hi = torso_bbox()
    tw, th = hi.x - lo.x, hi.z - lo.z
    q = TAILS[name]
    spade = next(o for o in objs if o.name.endswith("_Spade"))
    sv = [v.co for v in spade.data.vertices]
    span = max((a - b).length for a in sv[::3] for b in sv[::3])
    return dict(length=round(path.length, 3), length_to_torso_height=round(path.length / th, 2),
                thickness=round(2 * q["R"], 3), thickness_to_torso_width=round(2 * q["R"] / tw, 2),
                spade_length=q["SPADE_L"], spade_length_to_torso_width=round(q["SPADE_L"] / tw, 2),
                spade_span=round(span, 3), torso_size=[round(tw, 3), round(hi.y - lo.y, 3), round(th, 3)])


def limb_clearance(objs):
    """Smallest gap between the tail's rest mesh and the R6 legs and arms swinging +-RUN_DEG about
    the hips and shoulders (boxes 1 x 1 x 2). Negative = it hits."""
    limbs = [("LeftLeg", 0.0, (0.0, 1.0)), ("RightLeg", 0.0, (-1.0, 0.0)), ("LeftArm", 1.5, (1.0, 2.0)),
             ("RightArm", 1.5, (-2.0, -1.0))]
    vs = [v.co for o in objs for v in o.data.vertices if v.co.y > 0.6]   # past the torso's back
    best, where = 99.0, None
    for k in range(-6, 7):
        a = math.radians(RUN_DEG * k / 6)
        for cx, pz, (x0, x1) in limbs:
            top = 0.0 if pz == 0.0 else 0.5   # the leg hangs from its hip; the arm reaches 0.5 above
            for v in vs:
                dx = max(x0 - v.x, 0, v.x - x1)
                y, z = v.y, v.z - pz
                yr = y * math.cos(a) + z * math.sin(a)      # into the limb's frame
                zr = -y * math.sin(a) + z * math.cos(a)
                dy = max(abs(yr) - 0.5, 0)
                dz = max(-2.0 + top - zr, 0, zr - top) if pz == 0.0 else max(-1.5 - zr, 0, zr - top)
                d = (dx * dx + dy * dy + dz * dz) ** 0.5
                if d <= 0:
                    d = -0.01   # inside the limb
                if d < best:
                    best, where = d, "%s at %s, swing %d deg" % (cx, r3(v), round(math.degrees(a)))
    return round(best, 3), where


# ---------------------------------------------------------------------------------- rig -------
def new_armature(name, col):
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


def pose(arm, bend=("Z", 0.0)):
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        if pb.name.startswith("Tail") and pb.name != "TailBase":
            rot = [0.0, 0.0, 0.0]
            rot["XYZ".index(bend[0])] = math.radians(bend[1])
            pb.rotation_euler = rot
    bpy.context.view_layer.update()


# ---------------------------------------------------------------------------------- export ----
def r3(v):
    return [round(x, 3) for x in v]


def to_roblox(v):
    return [round(-v[0], 3), round(v[2], 3), round(v[1], 3)]


def shift_set(arm, objs, offset):
    m = Matrix.Translation(offset)
    for o in objs:
        o.data.transform(m)
    arm.data.transform(m)
    bpy.context.view_layer.update()


def export_set(name, arm, objs, attach, attach_name, extra):
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
        bones = {b.name: dict(parent=b.parent.name if b.parent else None, head=r3(b.head_local),
                              tail=r3(b.tail_local), roblox_head=to_roblox(b.head_local), deform=b.use_deform)
                 for b in arm.data.bones}
        report = dict(
            name=name, attachment=attach_name, attachment_avatar_space=r3(attach),
            units="1 Blender unit = 1 stud; positions relative to the attachment (Blender X avatar left, "
                  "-Y avatar front, Z up)",
            roblox_mapping="a Blender point (x, y, z) is (-x, z, y) in the attachment's Roblox frame; "
                           "mesh Size = (bx, bz, by), CFrame = CFrame.new(-cx, cz, cy)",
            colors={k: r3(v[:3]) for k, v in COLORS.items()},
            shade=dict(file=SHADE_FILE, uv="V only (U = 0.5)", darkest=SHADE_MIN, fade_to_white_at_v=SHADE_REACH),
            meshes=meshes, tris_total=sum(m["tris"] for m in meshes.values()), bones=bones)
        report.update(extra)
        with open(os.path.join(HERE, name + ".json"), "w") as fh:
            json.dump(report, fh, indent=1)
    finally:
        shift_set(arm, objs, attach)
    return report


# ---------------------------------------------------------------------------------- sheet -----
# (view, eye direction, target, ortho scale or None = perspective, distance)
VIEWS = [
    ("front", (0, -1, 0.10), (0, 0.9, 0.9), 7.6, 20),
    ("side", (1, 0, 0.08), (0, 1.3, 0.6), 7.8, 20),
    ("back", (0, 1, 0.12), (0, 0.9, 0.6), 7.6, 20),
    ("threequarter", (0.8, 0.85, 0.38), (0.2, 1.2, 0.6), 8.0, 20),
    ("bent", (1, 0.35, 0.15), (0.2, 1.4, 0.4), 8.6, 20),
    ("head", (-0.55, -0.85, 0.30), (0, 0.1, 3.2), None, 5.0),
    ("seat_side", (1.0, 0.1, 0.10), None, None, 2.8),
    ("seat_back", (0.4, 1.0, 0.10), None, None, 2.8),
    ("game", (0.45, 1.0, 0.35), (0, 0.6, 1.2), None, 12.0),
]


def render_tiles(scene, root_col, out_dir, res=380):
    rp.setup_render(scene, res=(res, res))
    layer = scene.view_layers[0].layer_collection.children[root_col.name]
    shots = []
    for label, horns, tail in DIRECTIONS:
        for c in layer.children:
            c.exclude = c.name not in (horns, tail)
        t_arm = bpy.data.objects[tail + "_Rig"]
        p = HORNS[horns]
        seat = Path(p["PATH"]).at(0.08)[0]
        for view, d, tgt, ortho, dist in VIEWS:
            pose(t_arm, TAILS[tail]["BEND"] if view == "bent" else ("Z", 0.0))
            tgt = Vector(tgt) if tgt else seat
            eye = tgt + Vector(d).normalized() * dist
            lens = 65 if view == "game" else 50
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (label, view)), tuple(eye),
                                   tuple(tgt), ortho=ortho, lens=lens))
        pose(t_arm)
    for c in layer.children:
        c.exclude = False
    return shots


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
    keep = set(HORNS) | set(TAILS)
    for c in list(root_col.children):
        if c.name not in keep:
            for o in list(c.objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.collections.remove(c)
    shade_image()
    built, report = {}, {}
    for name in HORNS:
        if ONLY and name not in ONLY:
            continue
        arm, objs, seat = build_horns(name, root_col)
        extra = dict(variant=HORNS[name]["label"], mood=HORNS[name]["mood"], proportions=horn_proportions(name, objs), seating=seat)
        built[name] = (arm, objs, HAT, "HatAttachment", extra)
    for name in TAILS:
        if ONLY and name not in ONLY:
            continue
        arm, objs, path, anchors = build_tail(name, root_col)
        anchors = {k: dict(v, point=r3(Vector(v["point"]) - WAIST_BACK), roblox=to_roblox(Vector(v["point"]) - WAIST_BACK))
                   for k, v in anchors.items()}
        extra = dict(variant=TAILS[name]["label"], mood=TAILS[name]["mood"], proportions=tail_proportions(name, objs, path),
                     limb_clearance_running=limb_clearance(objs)[0],
                     tightest_limb=limb_clearance(objs)[1], anchors=anchors)
        built[name] = (arm, objs, WAIST_BACK, "WaistBackAttachment", extra)
    for name, (arm, objs, attach, att_name, extra) in built.items():
        report[name] = dict(tris={o.name: tri_count(o) for o in objs},
                            tris_total=sum(tri_count(o) for o in objs), **extra)
        if EXPORT:
            export_set(name, arm, objs, attach, att_name, extra)
    os.makedirs(os.path.join(HERE, "renders"), exist_ok=True)
    with open(os.path.join(HERE, "renders", "report.json"), "w") as fh:
        json.dump(report, fh, indent=1)
    print(json.dumps({k: dict(tris=v["tris_total"], **{kk: vv for kk, vv in v.items()
                                                        if kk in ("limb_clearance_running", "tightest_limb", "seating")})
                      for k, v in report.items()}, indent=1))
    if RENDER and not ONLY:
        print(len(render_tiles(scene, root_col, os.path.join(HERE, "renders"))), "tiles")
    if SAVE_BLEND:
        rp.save_blend(scene, os.path.join(HERE, "DemonicHuman.blend"))


main()
