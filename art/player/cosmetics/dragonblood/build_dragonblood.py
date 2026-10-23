r"""Dragonblood cosmetics: antler horns and a short scaled tail with a fur tuft, for the R6 avatar.

Intent: the Dragonblood are noble, bloodline-awakened dragon cultivators. The hero is the antler
silhouette rising from the temples and sweeping up and back over the hair (the part-built
DragonHorns the user approved: ivory beams shading to pale gold, two gold tines a side), read
from 40 studs as "dragon, regal". The tail is the quiet second voice: short, sturdy, green
scales with a cream spine ridge and a cream tuft at the tip. Soft and rounded, never spiky.

Three directions, one horn set + one tail set each (see DIRECTIONS):
  A  Antler    DragonHornsAntler    + DragonTailTuft     the approved placeholder, remodelled
  B  Celestial DragonHornsCelestial + DragonTailRising   long low sweep back, three tines rising
  C  Cub       DragonHornsCub       + DragonTailStub     short, chunky, one fat tine (cute)
Each set is its own FBX + JSON beside this script, with its own armature.

Run in its own visible Blender window (other modelers share the machine):
    tools/blender_live.sh open dragonblood
    tools/blender_live.sh run dragonblood art/player/cosmetics/dragonblood/build_dragonblood.py [RENDER=False] [EXPORT=False]
Then stitch the sheet: uv run --with pillow python3 -I art/player/cosmetics/dragonblood/make_sheet.py

Axes and units (the R6 reference, art/rig/r6_rigged.fbx): 1 Blender unit = 1 stud. +X = the
avatar's left, it faces -Y, Z up. Hips z 0, torso z 0..2, head top z ~3.0, feet z -2.
  Head HatAttachment        = (0, 0, 3.1)  (Head centre + Roblox (0, 0.6, 0))
  Torso WaistBackAttachment = (0, 0.5, 0)  (Torso bottom, back face)
Built in avatar space; the export moves each set so its attachment is the origin. A Blender
point (x, y, z) is Roblox (-x, z, y) from the attachment.

Regions (one mesh object = one MeshPart = one Color; material named by region):
  Horns: <Set>_LeftHorn, _RightHorn (Horn), <Set>_LeftHornTip, _RightHornTip (HornTip: the
         gold beam end and tine ends)
  Tail:  <Set>_Tail (Scales: core + scale plates), <Set>_TailRidge (Ridge: the cream spine fins),
         <Set>_TailTuft (Tuft: the fur plume at the tip)
Depth shading is a greyscale ramp (dragon_shade.png) on UV V, tinted by Color in Roblox.

Rig (bones named like the Motor6Ds they become; Root = the attachment point, never keyed):
  Horns: Root -> HornLBase -> HornL, Root -> HornRBase -> HornR   (Base = the buried root)
  Tail:  Root -> TailBase -> Tail1 -> ... -> Tail5               (Tail1 = where it leaves the body)
Horns are rigid on HornL/HornR (a twitch of up to ~0.2 rad); the tail blends across every joint.

Sealing: every tube is closed and starts buried (horn beams inside the head, tines inside the
beam, tail core inside the torso, scales, fins and tuft clumps with their undersides inside the
core), so no piece floats and nothing is single-sided.
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
EXPORT = globals().get("EXPORT", True)

SCENE = "Cosmetics"
ROOT_COLLECTION = "DragonbloodCosmetics"
BLEND = "Dragonblood.blend"
HAT = Vector((0.0, 0.0, 3.1))
WAIST_BACK = Vector((0.0, 0.5, 0.0))
HORN_SHARP_DEG = 50.0      # horns: smooth organic tubes, only the region seams shade hard
TAIL_SHARP_DEG = 40.0      # scales and fins keep a crisp rim, the core stays smooth
TUFT_SHARP_DEG = 70.0      # fur: soft, only the clump ridges

# Colours (linear). Defaults per direction; the region is what bloodlines recolour.
IVORY = (0.855, 0.776, 0.604, 1)
PALE_GOLD = (0.672, 0.402, 0.077, 1)
WARM_GOLD = (0.75, 0.48, 0.10, 1)
PALE_JADE = (0.36, 0.52, 0.36, 1)
CREAM = (0.83, 0.75, 0.58, 1)
CREAM_WHITE = (0.88, 0.84, 0.73, 1)
DEEP_GREEN = (0.040, 0.160, 0.085, 1)
SHADE_FILE = "dragon_shade.png"
SHADE_MIN = 0.58           # darkest ramp value (horn root, tail root)
SHADE_REACH = 0.5          # V where the darkening has faded out

# ----------------------------------------------------------------------------------- horns -----
# Left horn, avatar-space offsets from HatAttachment (the right horn mirrors X).
# BEAM: centreline control points; the first sits buried in the head, the second near its surface.
# R: beam radius at the root; PROFILE: (s along the beam, radius x R); BURLS: (s, swell) soft
# knuckles where tines leave. TIP_S: where the gold HornTip region starts on the beam.
# TINES: (s on the beam, tip offset from that point, bend added to the midpoint, root radius,
# tip-region start along the tine). Tine tips are rounded caps, never needles.
HORNS = {
    # A: the approved part-built DragonHorns, remodelled smooth: the same rise from the temples,
    # sweep up and back and two tines, ivory to pale gold. Per the user's pick (2026-10-23) the
    # beams splay in a wide V (tips well outside the head's sides) and the two tines are long,
    # capsule-like and prominent, still round-ended.
    "DragonHornsAntler": dict(
        label="Antler", mood="regal (approved look)",
        BEAM=[(0.30, -0.02, -0.34), (0.33, 0.02, -0.05), (0.46, 0.10, 0.24), (0.66, 0.24, 0.50),
              (0.90, 0.50, 0.80), (1.08, 0.86, 1.00)],
        R=0.185, PROFILE=[(0, 1.0), (0.2, 0.92), (0.5, 0.76), (0.8, 0.62), (1.0, 0.56)],
        BURLS=[(0.45, 0.10), (0.70, 0.09)], TIP_S=0.66,
        TINES=[(0.45, (-0.02, -0.14, 0.62), (-0.03, 0.03, 0.03), 0.102, 0.40),
               (0.70, (0.04, 0.02, 0.58), (-0.02, 0.06, 0.02), 0.092, 0.40)],
        COLORS=dict(Horn=IVORY, HornTip=PALE_GOLD)),
    # B: an eastern dragon antler: the beam runs low and long back over the head, its end lifting,
    # with three short tines standing up off it like a crown. Pale jade with gold tips (panel 6).
    "DragonHornsCelestial": dict(
        label="Celestial", mood="noble, celestial",
        BEAM=[(0.33, -0.10, -0.32), (0.35, -0.06, -0.04), (0.44, 0.14, 0.26), (0.54, 0.50, 0.44),
              (0.60, 0.98, 0.50), (0.62, 1.42, 0.62), (0.58, 1.70, 0.86)],
        R=0.185, PROFILE=[(0, 1.0), (0.2, 0.92), (0.5, 0.76), (0.8, 0.62), (1.0, 0.54)],
        BURLS=[(0.36, 0.08), (0.55, 0.08), (0.74, 0.07)], TIP_S=0.84,
        TINES=[(0.36, (0.10, -0.12, 0.46), (0.0, 0.02, 0.0), 0.092, 0.55),
               (0.55, (0.10, -0.02, 0.44), (0.0, 0.05, 0.0), 0.085, 0.55),
               (0.74, (0.08, 0.06, 0.36), (0.0, 0.06, 0.0), 0.078, 0.55)],
        COLORS=dict(Horn=PALE_JADE, HornTip=WARM_GOLD)),
    # C: a young dragon's horn: short and chunky, rising and curling back at a round tip, with
    # one fat tine forward: a soft Y. About the fox ears' height above the head.
    "DragonHornsCub": dict(
        label="Cub", mood="cute",
        BEAM=[(0.33, -0.04, -0.32), (0.35, -0.02, -0.04), (0.42, 0.04, 0.24), (0.48, 0.18, 0.46),
              (0.50, 0.40, 0.58), (0.50, 0.60, 0.56)],
        R=0.22, PROFILE=[(0, 1.0), (0.3, 0.95), (0.6, 0.82), (1.0, 0.70)],
        BURLS=[(0.50, 0.08)], TIP_S=0.72,
        TINES=[(0.50, (0.10, -0.20, 0.30), (0.0, 0.0, 0.02), 0.125, 0.45)],
        COLORS=dict(Horn=IVORY, HornTip=PALE_GOLD)),
}
HORN_SIDES = 12
BEAM_STATIONS = 26
TINE_STATIONS = 10
HORN_FLAT = 0.9            # beam section depth / width (a touch oval)
SEAM_OVERLAP = 0.012      # HornTip sleeve starts this far (arc fraction) before the colour seam
SEAM_SLEEVE = 1.015        # and is this much fatter, hiding the body's end cap
HORN_BEND = 15.0           # the sheet's twitch check: HornL/HornR tipped back this far (degrees)

# ------------------------------------------------------------------------------------ tails -----
# PATH control points (avatar space, root inside the torso); R core radius; PROFILE core radius
# along the length (x R): the scaled part tapers, then the tuft core puffs out and closes;
# TUFT_S where the scales end and the Tuft core starts; FLAT section depth / width.
# SCALES: ROWS x PER_ROW shingle plates over the scaled part, LEN (studs), LIFT how far a plate's
# rounded end stands off the core (so the next row overlaps it), THICK as a fraction of r.
# RIDGE: N cream fins along the spine, H height (studs) at the root shrinking to H*SHRINK, LEN
# each fin's length (studs), SWEEP how far the peak leans back.
# TUFT: fur clumps (as the fox's), ROWS x PER_ROW with row starts from S0 (before TUFT_S, so the fur
# grows out from among the last scales) to S1, LEN (studs) x GRADE (first row, last row): short at
# the root, long at the end, so the clumps run together into one flame-shaped plume. WIDTH, THICK,
# FLARE, SWIRL as the fox's.
# BEND: the sheet's deformation check per Tail joint: (local axis, degrees).
TAILS = {
    # A: the reference's tail: back and a little down, the tuft flowing up and out at the end.
    "DragonTailTuft": dict(
        label="Tuft", PATH=[(0, 0.15, 0.46), (0, 0.80, 0.30), (0.06, 1.40, 0.0), (0.22, 1.95, -0.18),
                            (0.40, 2.40, -0.02), (0.56, 2.76, 0.28), (0.64, 2.98, 0.56)],
        R=0.36, FLAT=0.92, TUFT_S=0.60,
        PROFILE=[(0, 1.0), (0.12, 1.02), (0.40, 0.84), (0.60, 0.66), (0.76, 0.86), (0.90, 0.70),
                 (1.0, 0.0)],
        SCALES=dict(ROWS=9, PER_ROW=9, LEN=0.28, LIFT=0.05, THICK=0.07),
        RIDGE=dict(N=6, H=0.16, SHRINK=0.55, LEN=0.30, SWEEP=0.5),
        TUFT=dict(ROWS=4, PER_ROW=6, S0=0.48, S1=0.80, LEN=0.80, GRADE=(0.45, 1.3), WIDTH=2.1, THICK=0.75,
                  FLARE=0.42, SWIRL=0.7),
        BEND=("Z", -22)),
    # B: rises behind the back in a slow arc, a tall flame plume at the top (regal, banner-like).
    "DragonTailRising": dict(
        label="Rising", PATH=[(0, 0.15, 0.46), (0, 0.80, 0.32), (0.04, 1.35, 0.16), (0.10, 1.80, 0.36),
                              (0.14, 2.05, 0.90), (0.10, 2.02, 1.45), (0.04, 1.90, 1.85)],
        R=0.35, FLAT=0.92, TUFT_S=0.60,
        PROFILE=[(0, 1.0), (0.12, 1.02), (0.40, 0.84), (0.60, 0.64), (0.76, 0.88), (0.90, 0.72),
                 (1.0, 0.0)],
        SCALES=dict(ROWS=9, PER_ROW=9, LEN=0.28, LIFT=0.05, THICK=0.07),
        RIDGE=dict(N=6, H=0.17, SHRINK=0.55, LEN=0.30, SWEEP=0.5),
        TUFT=dict(ROWS=4, PER_ROW=6, S0=0.48, S1=0.80, LEN=0.95, GRADE=(0.45, 1.3), WIDTH=2.1, THICK=0.75,
                  FLARE=0.42, SWIRL=0.8),
        BEND=("Z", -20)),
    # C: stubby and thick, drooping then flicking out to the side into a short, fat flame of a tuft.
    "DragonTailStub": dict(
        label="Stub", PATH=[(0, 0.15, 0.50), (0, 0.72, 0.34), (0.10, 1.15, 0.06), (0.34, 1.48, -0.02),
                            (0.58, 1.70, 0.18)],
        R=0.40, FLAT=0.95, TUFT_S=0.58,
        PROFILE=[(0, 1.0), (0.15, 1.04), (0.42, 0.88), (0.58, 0.74), (0.74, 0.92), (0.88, 0.74),
                 (1.0, 0.0)],
        SCALES=dict(ROWS=7, PER_ROW=9, LEN=0.26, LIFT=0.05, THICK=0.07),
        RIDGE=dict(N=4, H=0.16, SHRINK=0.7, LEN=0.30, SWEEP=0.4),
        TUFT=dict(ROWS=4, PER_ROW=6, S0=0.44, S1=0.78, LEN=0.62, GRADE=(0.5, 1.25), WIDTH=2.2, THICK=0.8,
                  FLARE=0.45, SWIRL=0.6),
        BEND=("X", 25)),
}
TAIL_COLORS = dict(Scales=DEEP_GREEN, Ridge=CREAM, Tuft=CREAM_WHITE)
CORE_SIDES = 14
CORE_STATIONS = 36
TAIL_BONES = 5
JOINT_BLEND = 0.45
CLUMP_ROOT = 0.80
CLUMP_RINGS = (0.0, 0.2, 0.42, 0.64, 0.84)
SCALE_RINGS = (0.0, 0.5, 0.85)   # few rings: flat plates, cheap
ROOT_BONE_LEN = 0.25

# Sheet rows: one direction per row (horns + tail).
DIRECTIONS = [
    ("A", "DragonHornsAntler", "DragonTailTuft"),
    ("B", "DragonHornsCelestial", "DragonTailRising"),
    ("C", "DragonHornsCub", "DragonTailStub"),
]


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
        g = SHADE_MIN + (1 - SHADE_MIN) * smoothstep(0.0, SHADE_REACH, (y + 0.5) / h)
        px += [g, g, g, 1.0] * w
    img.pixels.foreach_set(px)
    img.update()
    if EXPORT:
        img.filepath_raw = os.path.join(HERE, SHADE_FILE)
        img.file_format = "PNG"
        img.save()
    img.pack()
    return img


def material(region, color):
    """Region material: colour x shade ramp (what Roblox's SurfaceAppearance tint does)."""
    m = rp.preview_material(region, color)
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    for n in [n for n in nt.nodes if n.type in ("TEX_IMAGE", "MIX")]:
        nt.nodes.remove(n)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.get(SHADE_FILE) or shade_image()
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    rgba = [s for s in mix.inputs if s.type == "RGBA"]
    rgba[0].default_value = color
    nt.links.new(tex.outputs["Color"], rgba[1])
    nt.links.new(next(s for s in mix.outputs if s.type == "RGBA"), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    return m


def set_material_color(region, color):
    m = bpy.data.materials[region]
    mix = next(n for n in m.node_tree.nodes if n.type == "MIX")
    [s for s in mix.inputs if s.type == "RGBA"][0].default_value = color
    m.diffuse_color = color


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

    def __init__(self, points, n0=Vector((1, 0, 0))):
        self.p = catmull(points)
        self.l = [0.0]
        for a, b in zip(self.p, self.p[1:]):
            self.l.append(self.l[-1] + (b - a).length)
        self.length = self.l[-1]
        self.t, self.n = [], []
        n = n0.copy()
        for i in range(len(self.p)):
            t = (self.p[min(i + 1, len(self.p) - 1)] - self.p[max(i - 1, 0)]).normalized()
            n = (n - t * n.dot(t))
            if n.length < 1e-6:
                n = t.orthogonal()
            n.normalize()
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


def tube(bm, path, rfun, ss, sides, flat=1.0, cap_start=True, cap_end=True):
    """Closed tube along path at params ss; rfun(s) = radius (0 = a point). Returns the s of each vert."""
    rings, sv = [], []
    for s in ss:
        p, t, n = path.at(s)
        b = t.cross(n)
        r = rfun(s)
        if r < 1e-4:
            rings.append([bm.verts.new(p)])
            sv.append(s)
            continue
        rings.append([bm.verts.new(p + (n * math.cos(a) + b * math.sin(a) * flat) * r)
                      for a in (2 * math.pi * k / sides for k in range(sides))])
        sv += [s] * sides
    rp.loft(bm, rings, cap_start=cap_start and len(rings[0]) > 1, cap_end=cap_end and len(rings[-1]) > 1)
    return sv


def rounded(rfun, length, r_end_fn):
    """Wrap rfun so the last r_end studs close in a hemisphere (a soft round tip)."""
    def f(s):
        r_end = r_end_fn()
        e = (1 - s) * length
        if e < r_end:
            return min(rfun(s), math.sqrt(max(0.0, r_end ** 2 - (r_end - e) ** 2)))
        return rfun(s)
    return f


def stations(s0, s1, n, end_dense=True):
    """Params from s0 to s1, closer together toward s1 (for the round tip)."""
    out = []
    for i in range(n + 1):
        u = i / n
        if end_dense:
            u = 1 - (1 - u) ** 1.6
        out.append(s0 + (s1 - s0) * u)
    return out


def head_bbox():
    rig = next(o for o in rp.rig_objects() if o.type == "MESH")
    vs = [rig.matrix_world @ v.co for v in rig.data.vertices]
    vs = [v for v in vs if v.z > 2.0 and abs(v.x) < 1.0]
    return (Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)]))


def torso_bbox():
    rig = next(o for o in rp.rig_objects() if o.type == "MESH")
    vs = [rig.matrix_world @ v.co for v in rig.data.vertices]
    vs = [v for v in vs if 0.02 < v.z < 1.98 and abs(v.x) < 0.99]
    return (Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)]))


def head_surface_z(x, y):
    rig = next(o for o in rp.rig_objects() if o.type == "MESH")
    inv = rig.matrix_world.inverted()
    origin, direction = inv @ Vector((x, y, 6.0)), (inv.to_3x3() @ Vector((0, 0, -1))).normalized()
    hit, loc, *_ = rig.ray_cast(origin, direction)
    z = (rig.matrix_world @ loc).z if hit else None
    return z if z is not None and 2.4 < z < 3.3 else None


def inside_head(pt, margin=0.0):
    """Is pt under the head's top surface (and within its footprint) by at least margin?"""
    lo, hi = head_bbox()
    if not (lo.x + margin < pt.x < hi.x - margin and lo.y + margin < pt.y < hi.y - margin and pt.z > lo.z):
        return False
    z = head_surface_z(pt.x, pt.y)
    return z is not None and pt.z < z - margin


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


def pose(arm, bend=("Z", 0.0), horn=0.0):
    """Tail joints bent bend[1] degrees about local bend[0]; horns tipped back `horn` degrees
    (about local Z = world +X; negative local Z tips the tip back)."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        if pb.name.startswith("Tail") and pb.name != "TailBase":
            rot = [0.0, 0.0, 0.0]
            rot["XYZ".index(bend[0])] = math.radians(bend[1])
            pb.rotation_euler = rot
        if pb.name in ("HornL", "HornR"):
            pb.rotation_euler = (0, 0, math.radians(-horn))
    bpy.context.view_layer.update()


# ---------------------------------------------------------------------------------- horns -----
def horn_parts(p):
    """Left horn in avatar space: (horn bm, horn verts' (V, weight-to-HornL)), same for the tip,
    the beam path and the s where the beam leaves the head."""
    path = Path([HAT + Vector(q) for q in p["BEAM"]], n0=Vector((0, 1, 0)))
    L, R = path.length, p["R"]
    assert inside_head(path.at(0.0)[0], margin=R * 0.9), "%s: beam root not buried in the head" % p["label"]

    def base_r(s):
        r = R * interp_profile(p["PROFILE"], s)
        for sb, amp in p["BURLS"]:
            r += R * amp * math.exp(-((s - sb) * L / 0.12) ** 2)
        return r
    r_end = R * p["PROFILE"][-1][1]
    beam_r = rounded(base_r, L, lambda: r_end)
    # where the beam leaves the head: first station whose centre is above the surface
    s_out = next(s / 200 for s in range(200) if not inside_head(path.at(s / 200)[0]))
    body, tip = (bmesh.new(), []), (bmesh.new(), [])
    ss = stations(0.0, p["TIP_S"], round(BEAM_STATIONS * p["TIP_S"]), end_dense=False)
    sv = tube(body[0], path, beam_r, ss, HORN_SIDES, HORN_FLAT, cap_start=True, cap_end=True)
    body[1].extend((s, smoothstep(s_out - 0.03, s_out + 0.06, s)) for s in sv)
    # HornTip starts SEAM_OVERLAP before the seam as a sleeve SEAM_SLEEVE fatter than the body, so
    # the body's end cap sits inside it: no light line or crack where the colours meet.
    ss = stations(p["TIP_S"] - SEAM_OVERLAP, 1.0, round(BEAM_STATIONS * (1 - p["TIP_S"])) + 4)
    sv = tube(tip[0], path, lambda s: beam_r(s) * SEAM_SLEEVE, ss, HORN_SIDES, HORN_FLAT, cap_start=True,
              cap_end=False)
    tip[1].extend((s, 1.0) for s in sv)
    for s_t, off, bend, r0, t_tip in p["TINES"]:
        root, _, _ = path.at(s_t)
        off, bend = Vector(off), Vector(bend)
        # rooted at the beam centre, a slight arc, the end leaning back like the beam
        tpath = Path([root, root + off * 0.5 + bend, root + off], n0=Vector((0, 1, 0)))
        tl = tpath.length
        t_r = rounded(lambda s, r0=r0: r0 * (1.0 - 0.38 * s), tl, lambda r0=r0: r0 * 0.62)
        n_b = max(3, round(TINE_STATIONS * t_tip))
        sv = tube(body[0], tpath, t_r, stations(0.0, t_tip, n_b, end_dense=False), HORN_SIDES - 2,
                  cap_start=True, cap_end=True)
        body[1].extend((0.6 + 0.4 * s, 1.0) for s in sv)
        sv = tube(tip[0], tpath, lambda s, f=t_r: f(s) * SEAM_SLEEVE,
                  stations(t_tip - SEAM_OVERLAP * 2, 1.0, TINE_STATIONS - n_b + 4), HORN_SIDES - 2,
                  cap_start=True, cap_end=False)
        tip[1].extend((1.0, 1.0) for s in sv)
    return body, tip, path, s_out


def mirror_bm(bm):
    out = bm.copy()
    for v in out.verts:
        v.co.x = -v.co.x
    return out


def build_horns(name, root_col):
    p = HORNS[name]
    col = collection(name, root_col)
    body, tip, path, s_out = horn_parts(p)
    hinge_l = path.at(s_out)[0]
    root_l = path.at(0.0)[0]
    top_l = path.at(0.8)[0]
    arm = new_armature(name + "_Rig", col)
    eb = arm.data.edit_bones
    root = eb.new("Root")
    root.head, root.tail = HAT, HAT + Vector((0, 0, ROOT_BONE_LEN))
    root.align_roll(Vector((1, 0, 0)))
    root.use_deform = False
    for tag, side in (("L", 1), ("R", -1)):
        mx = Vector((side, 1, 1))
        base = eb.new("Horn%sBase" % tag)
        base.head = root_l * mx
        base.tail = hinge_l * mx
        base.align_roll(Vector((1, 0, 0)))
        base.parent = root
        hb = eb.new("Horn%s" % tag)
        hb.head, hb.tail = hinge_l * mx, top_l * mx
        hb.align_roll(Vector((1, 0, 0)))
        hb.parent, hb.use_connect = base, True
    bpy.ops.object.mode_set(mode="OBJECT")
    objs = []
    for tag, side, nm in (("L", 1, "Left"), ("R", -1, "Right")):
        for (bm, data), region, sharp in ((body, "Horn", HORN_SHARP_DEG), (tip, "HornTip", HORN_SHARP_DEG)):
            b = bm.copy() if side == 1 else mirror_bm(bm)
            o = new_object("%s_%s%s" % (name, nm, region), b, material(region, p["COLORS"][region]), col,
                           [d[0] for d in data], sharp)
            o["region"] = region
            skin(o, arm, [[("Horn%sBase" % tag, 1 - w), ("Horn%s" % tag, w)] for _, w in data])
            objs.append(o)
    body[0].free()
    tip[0].free()
    return arm, objs, dict(s_out=s_out, hinge=hinge_l, path=path)


def horn_proportions(name, objs, info):
    """Horn size against the head: visible height above the head top, the footprint where the beam
    leaves the head, and the total span (outer tip to tip)."""
    lo, hi = head_bbox()
    hh, hw = hi.z - lo.z, hi.x - lo.x
    p = HORNS[name]
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    top = max(v.z for v in pts)
    span = max(v.x for v in pts) - min(v.x for v in pts)
    back = max(v.y for v in pts) - hi.y
    beam_d = 2 * p["R"] * interp_profile(p["PROFILE"], info["s_out"])
    return dict(head_size=[round(hi.x - lo.x, 3), round(hi.y - lo.y, 3), round(hh, 3)],
                height_above_head=round(top - hi.z, 3), height_to_head=round((top - hi.z) / hh, 2),
                root_diameter=round(beam_d, 3), root_to_head_width=round(beam_d / hw, 2),
                span=round(span, 3), span_to_head_width=round(span / hw, 2),
                reach_behind_head=round(back, 3))


# ---------------------------------------------------------------------------------- tail ------
def core_radius(q, s):
    return q["R"] * interp_profile(q["PROFILE"], min(1.0, max(0.0, s)))


def frame(q, path, s, th):
    """Point, tangent, outward direction e at angle th around the core and its across-axis a."""
    p, t, n = path.at(s)
    b = t.cross(n)
    e = (n * math.cos(th) + b * math.sin(th) * q["FLAT"]).normalized()
    return p, t, e, t.cross(e).normalized()


def add_scale(bm, sv, q, path, s_a, len_s, th, hw):
    """One shingle scale: a closed, slightly domed plate lying on the core, its rounded end lifted
    off it toward the tip so the next row overlaps it. The underside is buried in the core."""
    c = q["SCALES"]
    rings = []
    for u in list(SCALE_RINGS) + [1.0]:
        s = s_a + u * len_s
        p, t, e, a = frame(q, path, s, th)
        r = core_radius(q, s)
        d = r * (0.97 + c["LIFT"] * u)
        if u >= 1.0:
            rings.append([bm.verts.new(p + e * d)])
            sv.append(s)
            continue
        w = hw * (0.75 + 0.25 * math.sin(math.pi * min(1.0, u * 1.6))) * math.sqrt(max(0.0, 1 - u ** 3))
        h = c["THICK"] * r * (1 - 0.45 * u)
        pts = [p + e * d + a * (-w), p + e * (d + h) + a * (-0.5 * w), p + e * (d + h) + a * (0.5 * w),
               p + e * d + a * w, p + e * (r * 0.78) + a * (0.4 * w), p + e * (r * 0.78) + a * (-0.4 * w)]
        rings.append([bm.verts.new(v) for v in pts])
        sv += [s] * len(pts)
    rp.loft(bm, rings, cap_start=True, cap_end=False)


def add_fin(bm, sv, q, path, s_a, len_s, height, sweep, thick=0.055):
    """A soft spine fin on the tail's back: a closed rounded sail, buried at its foot, its peak
    leaning toward the tip."""
    rings = []
    us = [0.0, 0.12, 0.3, 0.5, 0.68, 0.84, 1.0]
    for u in us:
        s = s_a + u * len_s
        p, t, n = path.at(s)
        up = -t.cross(n)              # the dorsal side (parallel transport from +X keeps it there)
        side = n
        r = core_radius(q, s)
        prof = math.sin(math.pi * min(1.0, u ** 0.75)) ** 0.8   # rounded, peak past the middle
        h = height * prof
        top = p + up * (r * 1.02 + h) + t * (sweep * h)
        foot = p + up * (r * 0.62)
        tk = thick * (0.55 + 0.45 * prof)
        pts = [foot + side * tk, top + side * tk * 0.55, top - side * tk * 0.55, foot - side * tk]
        rings.append([bm.verts.new(v) for v in pts])
        sv += [s] * 4
    rp.loft(bm, rings, cap_start=True, cap_end=True)


def add_clump(bm, sv, q, path, c, s_a, length, theta0):
    """A fur clump (the fox's): a closed wedge from inside the core out to a point past the outline."""
    length = min(length, 0.995 - s_a)
    r_ref = core_radius(q, s_a + length * 0.4)
    rings = []
    for u in list(CLUMP_RINGS) + [1.0]:
        s = s_a + u * length
        th = theta0 + c["SWIRL"] * u
        p, t, e, a = frame(q, path, s, th)
        r = core_radius(q, s)
        d = r * (0.85 + (0.15 + c["FLARE"]) * u ** 1.4) + r_ref * 0.08 * math.sin(math.pi * u)
        if u >= 1.0:
            rings.append([bm.verts.new(p + e * d)])
            sv.append(s)
            continue
        w = c["WIDTH"] * r_ref * 0.5 * (1 - u) ** 0.7 * (0.8 + 0.9 * u)
        h = c["THICK"] * r_ref * 0.5 * (1 - u) ** 0.6 * (0.8 + 0.6 * u)
        top = p + e * d
        under = p + e * min(d - h * 0.3, r * CLUMP_ROOT)
        pts = [top + a * (-w), top + a * (-0.5 * w) + e * h, top + a * (0.5 * w) + e * h, top + a * w,
               under + a * (0.45 * w), under + a * (-0.45 * w)]
        rings.append([bm.verts.new(v) for v in pts])
        sv += [s] * len(pts)
    rp.loft(bm, rings, cap_start=True, cap_end=False)


def build_tail_meshes(q, path, s_att):
    L = path.length
    scales, ridge, tuft = (bmesh.new(), []), (bmesh.new(), []), (bmesh.new(), [])
    ts = q["TUFT_S"]
    # core: the scaled part, then the tuft core starting a little inside it
    n_core = round(CORE_STATIONS * ts)
    scales[1].extend(tube(scales[0], path, lambda s: core_radius(q, s),
                          [ts * i / n_core for i in range(n_core + 1)], CORE_SIDES, q["FLAT"]))
    t0 = ts - 0.04
    n_t = round(CORE_STATIONS * (1 - t0))
    tuft[1].extend(tube(tuft[0], path, lambda s: core_radius(q, s) * 0.97,
                        [t0 + (1 - t0) * i / n_t for i in range(n_t + 1)], CORE_SIDES, q["FLAT"]))
    # scales: staggered rows from just outside the body to under the tuft
    c = q["SCALES"]
    len_s = c["LEN"] / L
    s0 = max(0.04, s_att - 0.02)
    s1 = ts - len_s * 0.55
    for k in range(c["ROWS"]):
        s_a = s0 + (s1 - s0) * k / (c["ROWS"] - 1)
        r = core_radius(q, s_a + len_s * 0.5)
        hw = math.pi * r / c["PER_ROW"] * 1.18
        for j in range(c["PER_ROW"]):
            th = 2 * math.pi * (j + 0.5 * (k % 2)) / c["PER_ROW"]
            add_scale(scales[0], scales[1], q, path, s_a, len_s * (1.0 - 0.2 * k / c["ROWS"]), th, hw)
    # spine ridge
    rd = q["RIDGE"]
    fl = rd["LEN"] / L
    r0, r1 = max(0.05, s_att + 0.02), q["TUFT"]["S0"] - fl * 0.5   # the fur takes over from the ridge
    for k in range(rd["N"]):
        f = k / max(1, rd["N"] - 1)
        h = rd["H"] * (1 + (rd["SHRINK"] - 1) * f)
        add_fin(ridge[0], ridge[1], q, path, r0 + (r1 - r0) * f, fl * (1 + (rd["SHRINK"] - 1) * f * 0.6), h,
                rd["SWEEP"])
    # tuft clumps, overlapping the seam onto the last scales
    tc = q["TUFT"]
    for k in range(tc["ROWS"]):
        f = k / max(1, tc["ROWS"] - 1)
        cl = tc["LEN"] / L * (tc["GRADE"][0] + (tc["GRADE"][1] - tc["GRADE"][0]) * f)
        row = dict(tc, FLARE=tc["FLARE"] * (0.35 + 0.65 * f))   # the first fur lies flat: no collar
        for j in range(tc["PER_ROW"]):
            s_a = tc["S0"] + (tc["S1"] - tc["S0"]) * f + 0.012 * math.sin(k * 5.1 + j * 2.7)
            th = 2 * math.pi * (j + 0.5 * (k % 2) + 0.15 * math.sin(k * 3.7 + j * 1.9)) / tc["PER_ROW"]
            add_clump(tuft[0], tuft[1], q, path, row, s_a, cl * (1 + 0.12 * math.sin(k * 2.3 + j * 4.1)), th)
    return scales, ridge, tuft


def tail_weights(s, joints):
    names = ["TailBase"] + ["Tail%d" % (k + 1) for k in range(TAIL_BONES)]
    b = (joints[1] - joints[0]) * JOINT_BLEND
    ramps = [1.0] + [smoothstep(j - b, j + b, s) for j in joints[:TAIL_BONES]] + [0.0]
    return [(names[i], ramps[i] - ramps[i + 1]) for i in range(len(names)) if ramps[i] - ramps[i + 1] > 1e-4]


def build_tail(name, root_col):
    q = TAILS[name]
    col = collection(name, root_col)
    path = Path(q["PATH"])
    s_att = path.param_of(WAIST_BACK + Vector((0, 0, 0.36)))   # where the core leaves the back
    arm = new_armature(name + "_Rig", col)
    eb = arm.data.edit_bones
    root = eb.new("Root")
    root.head, root.tail = WAIST_BACK, WAIST_BACK + Vector((0, ROOT_BONE_LEN, 0))
    root.align_roll(Vector((1, 0, 0)))
    root.use_deform = False
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
    parts = build_tail_meshes(q, path, s_att)
    for (bm, sv), suffix, region, sharp in zip(parts, ("Tail", "TailRidge", "TailTuft"),
                                               ("Scales", "Ridge", "Tuft"),
                                               (TAIL_SHARP_DEG, TAIL_SHARP_DEG, TUFT_SHARP_DEG)):
        vv = [min(1.0, s / q["TUFT_S"]) if region != "Tuft" else 1.0 for s in sv]
        o = new_object("%s_%s" % (name, suffix), bm, material(region, TAIL_COLORS[region]), col, vv, sharp)
        o["region"] = region
        skin(o, arm, [tail_weights(s, joints) for s in sv])
        objs.append(o)
    return arm, objs, path


def tail_proportions(objs):
    lo, hi = torso_bbox()
    tw, th = hi.x - lo.x, hi.z - lo.z
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    pts = [v for v in pts if v.y > hi.y]   # the part outside the body
    reach = max(v.y for v in pts) - hi.y
    width = max(v.x for v in pts) - min(v.x for v in pts)
    height = max(v.z for v in pts) - min(v.z for v in pts)
    low = min(v.z for v in pts)
    return dict(torso_size=[round(tw, 3), round(hi.y - lo.y, 3), round(th, 3)],
                reach_behind_back=round(reach, 3), reach_to_torso_height=round(reach / th, 2),
                width=round(width, 3), width_to_torso_width=round(width / tw, 2),
                height=round(height, 3), height_to_torso_height=round(height / th, 2), lowest_z=round(low, 3))


def leg_clearance(objs):
    """(rest clearance, largest backward leg swing before contact). Rest: the closest tail vertex
    below the hips (z < -0.3) behind the legs' back face (y 0.5). Swing: each R6 leg (x 0..1 or
    -1..0, y -0.5..0.5, z -2..0) rotated back about the hip axis (y 0, z 0) in 5 degree steps until
    a tail vertex falls inside it."""
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    rest = min((v.y - 0.5 for v in pts if v.z < -0.3), default=9.0)
    swing = 90
    for deg in range(0, 95, 5):
        a = math.radians(deg)
        hit = False
        for v in pts:
            if abs(v.x) > 1.0 or v.y < 0.65:
                continue   # beside the legs, or the root within 0.15 of the back, where a swung
                           # R6 leg's top corner passes through the torso itself anyway
            # rotate the point forward by the swing (into the leg's rest frame)
            y = v.y * math.cos(a) + v.z * math.sin(a)
            z = -v.y * math.sin(a) + v.z * math.cos(a)
            if -0.5 < y < 0.5 and -2.0 < z < 0.0:
                hit = True
                break
        if hit:
            swing = deg - 5
            break
    return round(rest, 3), swing


# ---------------------------------------------------------------------------------- export ----
def r3(v):
    return [round(x, 3) for x in v]


def shift_set(arm, objs, offset):
    m = Matrix.Translation(offset)
    for o in objs:
        o.data.transform(m)
    arm.data.transform(m)
    bpy.context.view_layer.update()


def export_set(name, arm, objs, attach, attach_name, colors, extra):
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
                              tail=r3(b.tail_local), roblox_head=[round(-b.head_local.x, 3), round(b.head_local.z, 3),
                                                                  round(b.head_local.y, 3)], deform=b.use_deform)
                 for b in arm.data.bones}
        report = dict(
            name=name, attachment=attach_name, attachment_avatar_space=r3(attach),
            units="1 Blender unit = 1 stud; positions relative to the attachment (Blender X avatar left, "
                  "-Y avatar front, Z up)",
            roblox_mapping="a Blender point (x, y, z) is (-x, z, y) from the attachment; mesh Size = (bx, bz, by), "
                           "CFrame relative to the attachment = CFrame.new(-cx, cz, cy), no rotation",
            colors={k: r3(v[:3]) for k, v in colors.items()},
            shade=dict(file=SHADE_FILE, uv="V only (U = 0.5)", darkest=SHADE_MIN, fade_to_white_at_v=SHADE_REACH),
            meshes=meshes, tris_total=sum(m["tris"] for m in meshes.values()), bones=bones)
        report.update(extra)
        with open(os.path.join(HERE, name + ".json"), "w") as fh:
            json.dump(report, fh, indent=1)
    finally:
        shift_set(arm, objs, attach)
    return report


# ---------------------------------------------------------------------------------- sheet -----
BODY_TGT = (0, 0.6, 1.0)
VIEWS = [   # (name, eye direction, target, ortho scale or None, distance)
    ("front", (0, -1, 0.08), BODY_TGT, 7.6, 20),
    ("side", (1, 0, 0.06), (0, 0.9, 1.0), 7.6, 20),
    ("back", (0, 1, 0.10), BODY_TGT, 7.6, 20),
    ("threequarter", (0.8, 0.85, 0.35), (0.1, 0.8, 1.0), 7.8, 20),
    ("head", (-0.65, -0.75, 0.25), (0, 0.35, 3.65), None, 6.0),
    ("bent", (1, 0.35, 0.15), (0.1, 0.9, 1.0), 7.8, 20),
]
SEAT_VIEWS = [("seat_side", (1.0, 0.1, 0.12)), ("seat_back", (0.4, 1.0, 0.12))]
SEAT_DIST = 1.6
GAME = ("game", (0.45, 1, 0.38), 12.0, 65)   # game camera behind the player, true on-screen size


def render_tiles(scene, root_col, out_dir, res=380):
    rp.setup_render(scene, res=(res, res))
    layer = scene.view_layers[0].layer_collection.children[root_col.name]
    shots = []
    for key, horns, tail in DIRECTIONS:
        for c in layer.children:
            c.exclude = c.name not in (horns, tail)
        for region, colr in HORNS[horns]["COLORS"].items():
            set_material_color(region, colr)
        h_arm, t_arm = bpy.data.objects[horns + "_Rig"], bpy.data.objects[tail + "_Rig"]
        for view, d, tgt, ortho, dist in VIEWS:
            bent = view == "bent"
            pose(t_arm, TAILS[tail]["BEND"] if bent else ("Z", 0.0))
            pose(h_arm, horn=HORN_BEND if bent else 0.0)
            eye = Vector(tgt) + Vector(d).normalized() * dist
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (key, view)), tuple(eye), tgt,
                                   ortho=ortho, lens=50))
        pose(t_arm)
        pose(h_arm)
        hinge = BUILT_INFO[horns]["hinge"]
        for view, d in SEAT_VIEWS:
            eye = hinge + Vector(d).normalized() * SEAT_DIST
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (key, view)), tuple(eye),
                                   tuple(hinge), lens=50))
        # bent tail close-up, where gaps between scales and clumps open widest
        pose(t_arm, TAILS[tail]["BEND"])
        dg = bpy.context.evaluated_depsgraph_get()
        tob = bpy.data.objects[tail + "_Tail"].evaluated_get(dg)
        mid = sum((tob.matrix_world @ v.co for v in tob.data.vertices), Vector()) / len(tob.data.vertices)
        eye = mid + Vector((0.9, 0.8, 0.45)).normalized() * 3.4
        shots.append(rp.render(scene, os.path.join(out_dir, "%s_close.png" % key), tuple(eye), tuple(mid), lens=50))
        pose(t_arm)
        view, d, dist, lens = GAME
        tgt = Vector((0, 0, 2.2))
        eye = tgt + Vector(d).normalized() * dist
        shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (key, view)), tuple(eye), tuple(tgt),
                               lens=lens))
    for c in layer.children:
        c.exclude = False
    return shots


# ---------------------------------------------------------------------------------- main ------
BUILT_INFO = {}


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
        arm, objs, info = build_horns(name, root_col)
        BUILT_INFO[name] = info
        prop = horn_proportions(name, objs, info)
        built[name] = (arm, objs, HAT, "HatAttachment", HORNS[name]["COLORS"],
                       dict(label=HORNS[name]["label"], mood=HORNS[name]["mood"], proportions=prop))
    for name in TAILS:
        arm, objs, path = build_tail(name, root_col)
        prop = tail_proportions(objs)
        prop["leg_clearance_rest"], prop["leg_swing_back_clear_deg"] = leg_clearance(objs)
        prop["length"] = round(path.length, 3)
        built[name] = (arm, objs, WAIST_BACK, "WaistBackAttachment", TAIL_COLORS,
                       dict(label=TAILS[name]["label"], proportions=prop))
    for name, (arm, objs, attach, att_name, colors, extra) in built.items():
        report[name] = dict(tris=sum(tri_count(o) for o in objs), **extra["proportions"])
        if EXPORT:
            export_set(name, arm, objs, attach, att_name, colors, extra)
    print(json.dumps(report, indent=1))
    if EXPORT:
        rp.save_blend(scene, os.path.join(HERE, BLEND))
    if RENDER:
        top = scene.view_layers[0].layer_collection.children
        others = {c.name: c.exclude for c in top if c.name not in (ROOT_COLLECTION, rp.RIG_COLLECTION)}
        for n in others:
            top[n].exclude = True
        top[ROOT_COLLECTION].exclude = False
        print(len(render_tiles(scene, root_col, os.path.join(HERE, "renders"))), "tiles")
        for n, ex in others.items():
            top[n].exclude = ex


main()
