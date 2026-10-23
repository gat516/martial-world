r"""Beast Folk (Tiger) cosmetics: tiger ears and tiger tails for the player's R6 avatar.

Directions (one row each on the sheet; any ears go with any tail in game):
  Cub    (cute):       TigerEarsRound  + TigerTailCurl   plump dome ears, thick tail curling up at the tip
  Feral  (aggressive): TigerEarsPinned + TigerTailLash   ears flattened out and back so the white
                                                         spots face forward, long low whip of a tail
  Regal  (proud):      TigerEarsTufted + TigerTailCrown  upright ears with a fur-fringed outer rim,
                                                         tail raised high in a question-mark arc
Intent: a powerful beast lineage, not a cartoon. The hero of the set is the tail (ringed stripes,
banded tip) read from behind at game distance; the ears' hero is the white spot on a dark back.

Run in your own visible Blender (tools/blender_live.sh run tiger <this script>), or headless with
tools/blender_run.sh. Globals: RENDER (default True: sheet tiles into renders/), EXPORT (default
False until a direction is picked: FBX, JSON, shade PNG). The .blend is always saved.
Then stitch the sheet with make_sheet.py.

Axes and units (the R6 reference, art/rig/r6_rigged.fbx):
  1 Blender unit = 1 stud. +X = the avatar's left, it faces -Y, Z up. Hips z 0, torso z 0..2,
  head z 1.9..3.1 (1.2 x 1.2 x 1.2), feet z -2.
  Head HatAttachment        = (0, 0, 3.1)
  Torso WaistBackAttachment = (0, 0.5, 0)
Built in avatar space; the export moves each set so its attachment is the origin.

Recolour contract: one mesh (one MeshPart) per colour region, material named by region:
  FurOuter  orange       <Ears>_LeftEar/_RightEar, <Tail>_Tail
  FurStripe dark brown   <Ears>_LeftEarBack/_RightEarBack (the dark ear back), <Tail>_TailStripe
                         (every ring plus the dark tail end)
  FurTip    white        <Ears>_LeftEarSpot/_RightEarSpot (the ocelli), <Tail>_TailTip (white band)
  FurInner  cream        <Ears>_LeftEarInner/_RightEarInner
Depth shading is a greyscale ramp (tiger_shade.png) on UV V, so tinting by Color still works.

Tail construction: the fox's sealed fur, a smooth core plus closed flame-shaped clumps buried in
it, graded big to small with lifted ends. Each clump row has a colour (PATTERN), so the stripes
follow the fur instead of being hard rings. Ear markings are thin closed slabs sunk into the
ear's back shell, kept small (a dot on a dark tip, never a pair of eyes).

Rig: Ears Root -> EarLBase -> EarL (and R); Tail Root -> TailBase -> Tail1..Tail5.
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

SCENE = "Cosmetics"
ROOT_COLLECTION = "TigerCosmetics"
HAT = Vector((0.0, 0.0, 3.1))
WAIST_BACK = Vector((0.0, 0.5, 0.0))
EAR_SHARP_DEG = 28.0
FUR_SHARP_DEG = 80.0
TAIL_SHARP_DEG = 70.0

# Colours (linear).
COLORS = {
    "FurOuter":  (0.78, 0.25, 0.035, 1),   # tiger orange
    "FurStripe": (0.045, 0.022, 0.014, 1),  # dark brown
    "FurTip":    (0.92, 0.89, 0.83, 1),    # white
    "FurInner":  (0.93, 0.82, 0.70, 1),    # pale cream
    "Whiskers":  (0.06, 0.035, 0.025, 1),  # dark brown, reads on any skin tone at game distance
}
SHADE_FILE = "tiger_shade.png"
SHADE_MIN = 0.6
SHADE_REACH = 0.4

# ------------------------------------------------------------------------------------- ears ---
# Sizes are checked against the R6 head (1.20 wide, 1.02 tall by the fox sheet's measure,
# HEAD_H_REF): the approved cute fox ears stand 0.65 studs (64% of head height) on a base 40% of
# head width; rounded tiger ears sit a little lower. Never tall and thin ("creepy"). X base centre |x|, H shell length (part is sunk), W base
# half-width, T thickness, CUP front hollow, BELLY mid widening, PEAK_EXP dome exponent of the
# round peak (2 = circle, 3+ = flatter, squarer top, 1.3 = almond), CURL tip offset back (+Y),
# TILT outward roll, YAW opening turned outward, LEAN backward lean (degrees).
# EDGE (count, t0, t1, amount) fur serrations along the rims (outer rim full, inner rim 40%).
# PATCH dark tip band across the top of the back, rim to rim (t centre, u centre, t radius,
# u radius, superellipse exponent). SPOT a small soft white dash straddling its lower edge
# (same fields). A white dot inside a dark oval read as a pair of eyes from behind (user,
# 2026-10-23), so the dark never rings the white.
# TUFTS cream fur in the cup: (t, u, up, out, forward, length as a fraction of H, radius).
ROUND_TUFTS = [(0.03, 0.0, 1.0, 0.0, 0.9, 0.42, 0.12), (0.05, -0.75, 1.0, 0.5, 0.7, 0.36, 0.10),
               (0.05, 0.75, 1.0, 0.5, 0.7, 0.36, 0.10)]
PINNED_TUFTS = [(0.03, 0.0, 1.0, 0.0, 0.8, 0.40, 0.10), (0.05, 0.75, 1.0, 0.6, 0.6, 0.34, 0.09)]
TUFTED_TUFTS = [(0.03, 0.0, 1.0, 0.0, 0.9, 0.44, 0.12), (0.05, -0.75, 1.0, 0.5, 0.7, 0.36, 0.10),
                (0.05, 0.75, 1.0, 0.5, 0.7, 0.36, 0.10)]
EARS = {
    # cute: a plump round dome, upright, wide at the base
    "TigerEarsRound": dict(label="Round", mood="cute", X=0.30, H=0.70, W=0.25, T=0.26, CUP=0.11,
                           BELLY=0.35, PEAK_EXP=2.0, CURL=0.0, TILT=14, YAW=14, LEAN=4,
                           EDGE=None, TUFTS=ROUND_TUFTS,
                           PATCH=(0.84, 0.0, 0.17, 0.99, 6.0), SPOT=(0.67, 0.0, 0.06, 0.26, 2.0)),
    # aggressive: flattened out sideways and swept back, almond peak, white spots turned forward
    "TigerEarsPinned": dict(label="Pinned", mood="aggressive", X=0.33, H=0.70, W=0.23, T=0.22, CUP=0.09,
                            BELLY=0.30, PEAK_EXP=1.35, CURL=0.10, TILT=62, YAW=-30, LEAN=24,
                            EDGE=(2, 0.05, 0.45, 0.35), TUFTS=PINNED_TUFTS,
                            PATCH=(0.84, 0.0, 0.17, 0.99, 6.0), SPOT=(0.67, 0.0, 0.06, 0.26, 2.0)),
    # proud: taller, upright, flat-round top, a fur fringe along the outer rim
    "TigerEarsTufted": dict(label="Tufted", mood="proud", X=0.30, H=0.80, W=0.24, T=0.25, CUP=0.11,
                            BELLY=0.20, PEAK_EXP=3.2, CURL=0.03, TILT=10, YAW=10, LEAN=6,
                            EDGE=(4, 0.04, 0.80, 0.55), TUFTS=TUFTED_TUFTS,
                            PATCH=(0.85, 0.0, 0.16, 0.99, 6.0), SPOT=(0.69, 0.0, 0.055, 0.25, 2.0)),
}
HEAD_H_REF = 1.02     # head height the approved fox ears were measured against (fox sheet)
EAR_Y = 0.10          # a little behind the head centre
EAR_SINK = 0.10       # the whole base rim sits this far under the head surface
EAR_CONFORM_T = 0.30
HEAD_MIN_Z = 2.6
EAR_ROWS = 9
EAR_COLS = 7
EAR_RIM = 0.6
TUFT_SIDES = 6
TUFT_PROFILE = [(0.0, 0.0), (0.12, 0.7), (0.35, 1.0), (0.62, 0.85), (0.85, 0.45), (1.0, 0.0)]
EAR_BEND = (0.04, 0.32)
PATCH_OUT = 0.025     # dark back stands this far off the shell
SPOT_OUT = 0.045      # the white spot stands off a little more (on the dark patch)
PATCH_IN = 0.05       # both slabs reach this far into the shell (closed, no open edges)
PATCH_RINGS, PATCH_SIDES = 2, 10
PATCH_DOME = 0.5      # the slab top falls this fraction of its height toward the rim (soft edge)

# ------------------------------------------------------------------------------------- tails --
# The fox's sealed fur (art/player/cosmetics/fox): a full smooth core plus flame-shaped clumps,
# each a closed wedge whose underside is buried in the core, graded big at the root to small at
# the tip, their ends lifted off the core so the outline breaks into fur. The stripes follow the
# clumps: PATTERN gives each clump row a colour (O orange, S stripe, W white, D dark end). A
# stripe is two rows (SS): the rows are staggered half a clump, so a single dark row checkers
# with its orange neighbours; two close into a ring with a ragged, clump-shaped edge. Stripe clumps on
# the underside turn orange every other one (tiger stripes thin out underneath).
# PATH control points (avatar space, root inside the body), R core max radius, PROFILE core
# radius along the length (s 0..1, x R), FLAT section depth/width, BEND the sheet's bent pose
# per Tail joint (local axis, degrees). CLUMPS: ROWS x PER_ROW from S0 to S1 (s), LEN clump
# length (s), WIDTH / THICK fractions of the core radius, FLARE how far the end lifts past the
# core, SWIRL turn round the tail (radians), BULGE mid arch.
TAILS = {
    # cute: thick, hangs low behind and curls up into a fluffy white-then-dark tip
    "TigerTailCurl": dict(
        label="Curl", mood="cute",
        PATH=[(0, 0.2, 0.06), (0, 0.95, 0.12), (0.3, 1.75, -0.12), (0.85, 2.4, -0.2),
              (1.3, 2.65, 0.2), (1.4, 2.5, 0.85), (1.12, 2.15, 1.1)],
        R=0.40, PROFILE=[(0, 0.7), (0.1, 0.92), (0.3, 1.0), (0.6, 0.9), (0.8, 0.86), (0.9, 0.72), (1, 0.0)],
        FLAT=0.92, BEND=("Z", -35), PATTERN="OSSOOSSOOSSOOSSWWD",
        CLUMPS=dict(ROWS=18, PER_ROW=4, S0=0.07, S1=0.94, LEN=0.13, WIDTH=1.75, THICK=0.55,
                    FLARE=0.45, SWIRL=0.12, BULGE=0.10)),
    # aggressive: long and low, held level off the hips (clear of the legs), whips up at the end
    # into a dark point
    "TigerTailLash": dict(
        label="Lash", mood="aggressive",
        PATH=[(0, 0.2, 0.06), (0, 1.1, 0.3), (-0.15, 2.05, 0.02), (-0.45, 3.0, -0.55),
              (-0.65, 3.85, -0.5), (-0.62, 4.35, 0.15), (-0.42, 4.25, 0.72)],
        R=0.32, PROFILE=[(0, 0.75), (0.08, 0.95), (0.2, 1.0), (0.6, 0.8), (0.85, 0.62), (0.94, 0.45), (1, 0.0)],
        FLAT=0.9, BEND=("X", 25), PATTERN="OOSSOOSSOOSSOOSSOWDD",
        CLUMPS=dict(ROWS=20, PER_ROW=4, S0=0.06, S1=0.95, LEN=0.11, WIDTH=1.75, THICK=0.5,
                    FLARE=0.40, SWIRL=0.10, BULGE=0.06)),
    # proud: rises high at the avatar's left in a question-mark arc, fluffy banded tip
    "TigerTailCrown": dict(
        label="Crown", mood="proud",
        PATH=[(0, 0.2, 0.06), (0.05, 0.95, 0.2), (0.35, 1.55, 0.6), (0.72, 1.8, 1.3),
              (1.0, 1.7, 2.15), (1.1, 1.38, 2.7), (1.0, 1.08, 2.62)],
        R=0.37, PROFILE=[(0, 0.72), (0.1, 0.92), (0.3, 1.0), (0.6, 0.9), (0.8, 0.86), (0.9, 0.74), (1, 0.0)],
        FLAT=0.92, BEND=("Z", -30), PATTERN="OSSOOSSOOSSOOSSWWD",
        CLUMPS=dict(ROWS=18, PER_ROW=4, S0=0.07, S1=0.94, LEN=0.13, WIDTH=1.75, THICK=0.55,
                    FLARE=0.45, SWIRL=0.12, BULGE=0.10)),
}
CLUMP_GRADE = (1.3, 0.7)    # clump length scale at the root and at the tip (big at the base)
ROW_JITTER = 0.12           # clump start stagger within a row (in row steps): low, so stripe rows read as rings
STRIPE_WIDEN = 1.0          # stripe clumps are wider, so a dark row closes into a ring
CLUMP_ROOT = 0.80           # clump underside at this fraction of the core radius (inside the core)
CLUMP_RINGS = (0.0, 0.3, 0.6, 0.85)   # stations along each clump before its point
CORE_SIDES = 12
CORE_STATIONS = 40
TAIL_BONES = 5
JOINT_BLEND = 0.45
ROOT_BONE_LEN = 0.25
# Limb clearance check (printed, in the JSON): legs swing about the hips, arms about the
# shoulders, up to this many degrees either way (a run cycle).
SWING_DEG = 50
ROOT_ZONE = 0.6
LIMBS = {  # name: (box min, box max, pivot) in rest pose
    "LeftLeg": ((0.0, -0.5, -2.0), (1.0, 0.5, 0.0), (0.5, 0.0, 0.0)),
    "RightLeg": ((-1.0, -0.5, -2.0), (0.0, 0.5, 0.0), (-0.5, 0.0, 0.0)),
    "LeftArm": ((1.0, -0.5, 0.0), (2.0, 0.5, 2.0), (1.5, 0.0, 1.5)),
    "RightArm": ((-2.0, -0.5, 0.0), (-1.0, 0.5, 2.0), (-1.5, 0.0, 1.5)),
}

# ---------------------------------------------------------------------------------- whiskers --
# Own accessory on Head.FaceFrontAttachment (head centre + Roblox (0, 0, -0.6) = Blender
# (0, -0.6, 2.5)). Simple on purpose (user, 2026-10-23: "they dont have to wrap around the face"):
# each cheek has one root point on the head's front face; every strand is one closed, thick,
# tapered shape sunk a little at that point and sticking straight out sideways, fanned by its
# angle, with at most a gentle curl at the tip. Styles differ only in count, length and curl.
# STRANDS: (fan angle up in degrees, length in studs, tip curl up in degrees). R root radius,
# FLAT its front-to-back depth over its height.
WHISKERS = {
    "TigerWhiskersMarks": dict(label="Marks", mood="cute", R=0.065, FLAT=0.75,
                               STRANDS=[(16, 0.42, 0), (0, 0.46, 0), (-16, 0.42, 0)]),
    "TigerWhiskersFine": dict(label="Fine", mood="aggressive", R=0.055, FLAT=0.75,
                              STRANDS=[(12, 0.55, -8), (0, 0.59, -8), (-12, 0.55, -8)]),
    "TigerWhiskersCurl": dict(label="Curl", mood="proud", R=0.062, FLAT=0.75,
                              STRANDS=[(10, 0.58, 40), (-10, 0.56, 30)]),
}
FACE_FRONT = Vector((0.0, -0.6, 2.5))
WHISKER_ROOT = (0.34, 2.33)   # cheek point (|x|, z) on the head's front face
WHISKER_OUT = Vector((1.0, -0.45, 0.0)).normalized()   # straight out sideways, a little forward
WHISKER_SINK = 0.05           # how far each root sinks into the face
WHISKER_SIDES = 8
WHISKER_STATIONS = 8

# Sheet rows: (direction, tail, ears, whiskers, one-line note)
PAIRS = [("Cub", "TigerTailCurl", "TigerEarsRound", "TigerWhiskersMarks",
          "cute: round dome ears, thick tail curling up into a banded tip, short whisker marks"),
         ("Feral", "TigerTailLash", "TigerEarsPinned", "TigerWhiskersFine",
          "aggressive: ears pinned flat (spots face forward), long low lash, fine swept whiskers"),
         ("Regal", "TigerTailCrown", "TigerEarsTufted", "TigerWhiskersCurl",
          "proud: upright fringed ears, tail raised in a high arc, curled whiskers")]


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


def material(name):
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
    nt.links.new(next(s for s in mix.outputs if s.type == "RGBA"), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.75
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


def body_part_bounds(part):
    """(min, max) of the R6 mesh's vertices weighted mostly to `part` (Head, Torso, ...)."""
    rig = next(o for o in rp.rig_objects() if o.type == "MESH")
    gi = rig.vertex_groups[part].index
    ps = [rig.matrix_world @ v.co for v in rig.data.vertices
          if v.groups and max(v.groups, key=lambda g: g.weight).group == gi]
    return (Vector([min(p[i] for p in ps) for i in range(3)]), Vector([max(p[i] for p in ps) for i in range(3)]))


# ---------------------------------------------------------------------------------- ears ------
def ear_width(p, t):
    belly = 1 + p["BELLY"] * math.sin(math.pi * t) * (1 - t)
    return p["W"] * belly * max(0.0, 1 - t ** p["PEAK_EXP"]) ** 0.5


def edge_tuft(p, t):
    if not p["EDGE"]:
        return 0.0
    n, t0, t1, _ = p["EDGE"]
    if t < t0 or t > t1:
        return 0.0
    u = (t - t0) / (t1 - t0) * n
    return max(0.0, 1 - abs((u % 1) - 0.5) * 2) ** 2 * math.sin(math.pi * (t - t0) / (t1 - t0)) ** 0.5


def ear_front(p, t, u):
    """Front (opening) surface, ear-local; u -1..1 across, +u the outer rim (the right ear is mirrored)."""
    amt = p["EDGE"][3] if p["EDGE"] else 0.0
    rim = abs(u) ** 4 * (1.0 if u > 0 else 0.4)
    w = ear_width(p, t) * (1 + amt * edge_tuft(p, t) * rim)
    y = p["CUP"] * (1 - u * u) * (1 - t) ** 0.6 + p["CURL"] * t * t
    return Vector((u * w, y, t * p["H"]))


def ear_back(p, t, u):
    f = ear_front(p, t, u)
    fade = (1 - t) ** 0.35
    return f + Vector((0, p["T"] * (EAR_RIM + (1 - EAR_RIM) * math.sqrt(max(0.0, 1 - u * u))) * fade, 0))


def ear_rim(p, t, side):
    f, b = ear_front(p, t, side), ear_back(p, t, side)
    return (f + b) / 2 + Vector((side * (b.y - f.y) * 0.3, 0, 0))


def add_tuft(bm, tv, p, root, axis, length, radius, flat=0.75):
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


def back_point(p, t, u):
    """Point on the ear's back and its outward normal (toward +Y, away from the opening)."""
    e = 1e-3
    pt = ear_back(p, t, u)
    du = ear_back(p, t, min(1, u + e)) - ear_back(p, t, max(-1, u - e))
    dt = ear_back(p, min(1, t + e), u) - ear_back(p, max(0, t - e), u)
    n = du.cross(dt)
    n = n.normalized() if n.length > 1e-9 else Vector((0, 1, 0))
    return pt, (n if n.y >= 0 else -n)


def add_patch(bm, tv, p, spec, out):
    """A closed slab on the ear's back over a superellipse (t, u) domain: top PATCH/SPOT_OUT off the
    shell, bottom PATCH_IN inside it, so it's sealed and never z-fights."""
    tc, uc, rt, ru, ex = spec
    top_rings, bot_rings = [], []
    c, n = back_point(p, tc, uc)
    ctop, cbot = bm.verts.new(c + n * out), bm.verts.new(c - n * PATCH_IN)
    tv += [tc, tc]
    for k in range(1, PATCH_RINGS + 1):
        r = k / PATCH_RINGS
        tr, br = [], []
        for j in range(PATCH_SIDES):
            a = 2 * math.pi * j / PATCH_SIDES
            ca, sa = math.cos(a), math.sin(a)
            sc = math.copysign(abs(ca) ** (2 / ex), ca)
            ss = math.copysign(abs(sa) ** (2 / ex), sa)
            t, u = tc + rt * r * ss, uc + ru * r * sc
            pt, nn = back_point(p, min(0.97, t), max(-0.95, min(0.95, u)))
            tr.append(bm.verts.new(pt + nn * out * (1 - PATCH_DOME * r * r)))
            br.append(bm.verts.new(pt - nn * PATCH_IN))
            tv += [t, t]
        top_rings.append(tr)
        bot_rings.append(br)
    rp.loft(bm, [[ctop]] + top_rings + list(reversed(bot_rings)) + [[cbot]], cap_start=False, cap_end=False)


def build_ear_local(p):
    """Returns {region: (bm, tvals)} in ear-local space."""
    bm, tvals = bmesh.new(), []
    us = [-1 + 2 * i / (EAR_COLS - 1) for i in range(EAR_COLS)]
    ts = [1 - (1 - i / EAR_ROWS) ** 1.4 for i in range(EAR_ROWS)]
    rings = []
    for t in ts:
        r = ([bm.verts.new(ear_front(p, t, u)) for u in us] + [bm.verts.new(ear_rim(p, t, 1))]
             + [bm.verts.new(ear_back(p, t, u)) for u in reversed(us)] + [bm.verts.new(ear_rim(p, t, -1))])
        tvals += [t] * len(r)
        rings.append(r)
    tip = bm.verts.new(ear_front(p, 1.0, 0) + Vector((0, p["T"] * 0.1, 0)))
    tvals.append(1.0)
    rp.loft(bm, rings + [[tip]], cap_start=True, cap_end=False)

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

    pb, ptv = bmesh.new(), []
    add_patch(pb, ptv, p, p["PATCH"], PATCH_OUT)
    sb, stv = bmesh.new(), []
    add_patch(sb, stv, p, p["SPOT"], SPOT_OUT)
    return {"Ear": (bm, tvals), "EarInner": (ib, itv), "EarBack": (pb, ptv), "EarSpot": (sb, stv)}


EAR_REGIONS = {"Ear": "FurOuter", "EarInner": "FurInner", "EarBack": "FurStripe", "EarSpot": "FurTip"}


def ear_matrix(p, side):
    rot = (Matrix.Rotation(math.radians(p["YAW"] * side), 4, "Z")
           @ Matrix.Rotation(math.radians(p["TILT"] * side), 4, "Y")
           @ Matrix.Rotation(math.radians(-p["LEAN"]), 4, "X"))
    top = head_surface_z(p["X"] * side, EAR_Y) or HAT.z
    return (Matrix.Translation((p["X"] * side, EAR_Y, top - EAR_SINK)) @ rot
            @ Matrix.Diagonal((side, 1, 1, 1)))


def head_surface_z(x, y):
    rig = next((o for o in rp.rig_objects() if o.type == "MESH"), None)
    inv = rig.matrix_world.inverted()
    origin, direction = inv @ Vector((x, y, 6.0)), (inv.to_3x3() @ Vector((0, 0, -1))).normalized()
    hit, loc, *_ = rig.ray_cast(origin, direction)
    z = (rig.matrix_world @ loc).z if hit else None
    return z if z is not None and HEAD_MIN_Z < z < 3.3 else None


def seat_on_head(bm, tvals, m):
    """Seat the base on the head's rounded top (whole footprint buried EAR_SINK under the surface)."""
    centre = m @ Vector((0, 0, 0))
    for v, t in zip(bm.verts, tvals):
        foot = m @ Vector((v.co.x, v.co.y, 0.0))
        pos = m @ v.co
        w = 1 - smoothstep(0.0, EAR_CONFORM_T, t)
        if w > 0:
            surf = head_surface_z(foot.x, foot.y)
            k = 1.0
            while surf is None and k > 0:   # past the head's edge: use the edge
                k -= 0.05
                surf = head_surface_z(centre.x + (foot.x - centre.x) * k, centre.y + (foot.y - centre.y) * k)
            pos.z += (surf - EAR_SINK - foot.z) * w
        v.co = pos


def build_ears(name, root_col):
    p = EARS[name]
    col = collection(name, root_col)
    parts = build_ear_local(p)
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
        for region, (src, tv) in parts.items():
            mat = EAR_REGIONS[region]
            bm = src.copy()
            seat_on_head(bm, tv, mats[tag])
            vv = [1.0 - t * 0.5 if region == "Ear" else 1.0 for t in tv]
            o = new_object("%s_%s%s" % (name, nm, region), bm, material(mat), col, vv,
                           FUR_SHARP_DEG if region == "EarInner" else EAR_SHARP_DEG)
            o["region"] = mat
            w = [[("Ear%sBase" % tag, 1 - smoothstep(*EAR_BEND, t)), ("Ear%s" % tag, smoothstep(*EAR_BEND, t))]
                 for t in tv]
            skin(o, arm, w)
            objs.append(o)
    for src, _ in parts.values():
        src.free()
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


def top_factor(path, s, th):
    """1 on the tail's upper side, -1 underneath (world up)."""
    _, t, n = path.at(s)
    b = t.cross(n)
    d = n * math.cos(th) + b * math.sin(th)
    return max(-1.0, min(1.0, d.z / max(0.3, math.sqrt(max(1e-6, 1 - t.z * t.z)))))


def add_core(bm, sv, q, path, s_lo, s_hi, cap_start):
    """A smooth core piece from s_lo to s_hi (closed: capped, or ending in the tail's point)."""
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
    """One flame-shaped fur clump (the fox's): a closed wedge from inside the core out to a point
    past the outline."""
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
        d = r * (0.85 + (0.15 + c["FLARE"]) * u ** 1.4) + r_ref * c["BULGE"] * math.sin(math.pi * u)
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


ROW_REGION = {"O": "FurOuter", "S": "FurStripe", "W": "FurTip", "D": "FurStripe"}


def build_tail_meshes(q, path):
    """{region: (bm, svals)}: the core in three pieces (orange, white band, dark end) plus every
    clump in its row's colour."""
    parts = {r: (bmesh.new(), []) for r in TAIL_PIECES}
    c, pat = q["CLUMPS"], q["PATTERN"]
    assert len(pat) == c["ROWS"], "PATTERN needs one letter per clump row"
    step = (c["S1"] - c["S0"]) / (c["ROWS"] - 1)
    tip_s = c["S0"] + step * (pat.index("W") - 0.1)
    end_s = c["S0"] + step * (pat.index("D") + 0.3)
    # orange core with a dark band under each stripe row's visible clump ends
    cuts = [0.0]
    for k, letter in enumerate(pat):
        if letter == "S":
            a = c["S0"] + step * (k - 1.2) + c["LEN"] * 0.45
            cuts += [a, a + step * 0.9]
    cuts.append(tip_s)
    for i, (lo, hi) in enumerate(zip(cuts, cuts[1:])):
        add_core(*parts["FurOuter" if i % 2 == 0 else "FurStripe"], q, path, lo, hi, True)
    add_core(*parts["FurTip"], q, path, tip_s, end_s, True)
    add_core(*parts["FurStripe"], q, path, end_s, 1.0, True)
    for k in range(c["ROWS"]):
        for j in range(c["PER_ROW"]):
            # fixed pseudo-random stagger (re-runs match) breaks the rows so they never band
            s_a = c["S0"] + step * (k - 1.2 + ROW_JITTER * math.sin(k * 5.1 + j * 2.7))
            theta = 2 * math.pi * (j + 0.5 * (k % 2) + 0.18 * math.sin(k * 3.7 + j * 1.9)) / c["PER_ROW"]
            grade = CLUMP_GRADE[0] + (CLUMP_GRADE[1] - CLUMP_GRADE[0]) * (k / (c["ROWS"] - 1))
            length = c["LEN"] * grade * (1 + 0.15 * math.sin(k * 2.3 + j * 4.1))
            letter = pat[k]
            if letter == "S" and (j + k) % 2 == 0 and top_factor(path, s_a + length, theta) < -0.35:
                letter = "O"   # thinner underneath
            cc = dict(c, WIDTH=c["WIDTH"] * STRIPE_WIDEN) if letter in "SD" else c
            add_clump(*parts[ROW_REGION[letter]], q, path, cc, max(0.04, s_a), length, theta)
    return parts


TAIL_PIECES = {"FurOuter": "Tail", "FurStripe": "TailStripe", "FurTip": "TailTip"}


def tail_weights(s, joints):
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
    pieces = build_tail_meshes(q, path)
    objs = []
    for region, (bm, sv) in pieces.items():
        o = new_object("%s_%s" % (name, TAIL_PIECES[region]), bm, material(region), col, list(sv), TAIL_SHARP_DEG)
        o["region"] = region
        skin(o, arm, [tail_weights(s, joints) for s in sv])
        objs.append(o)
    return arm, objs, path


# ---------------------------------------------------------------------------------- whiskers --
def face_y(x, z):
    """The head's front surface y at (x, z) by a ray from the front, or None past its side."""
    rig = next(o for o in rp.rig_objects() if o.type == "MESH")
    inv = rig.matrix_world.inverted()
    origin, direction = inv @ Vector((x, -5.0, z)), (inv.to_3x3() @ Vector((0, 1, 0))).normalized()
    hit, loc, *_ = rig.ray_cast(origin, direction)
    y = (rig.matrix_world @ loc).y if hit else None
    return y if y is not None and y < 0.2 else None


def build_whiskers(name, root_col):
    w = WHISKERS[name]
    col = collection(name, root_col)
    arm = new_armature(name + "_Rig", col)
    eb = arm.data.edit_bones
    root = eb.new("Root")
    root.head, root.tail = FACE_FRONT, FACE_FRONT + Vector((0, 0, ROOT_BONE_LEN))
    root.align_roll(Vector((1, 0, 0)))
    root.use_deform = False
    x0, z0 = WHISKER_ROOT
    y0 = (face_y(x0, z0) or FACE_FRONT.y) + WHISKER_SINK
    for tag, side in (("L", 1), ("R", -1)):
        h = Vector((x0 * side, y0, z0))
        b = eb.new("Whisker%s" % tag)
        b.head, b.tail = h, h + Vector((WHISKER_OUT.x * side, WHISKER_OUT.y, 0)) * 0.35
        b.align_roll(Vector((0, 0, 1)))
        b.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    bm, sv, wts = bmesh.new(), [], []
    for tag, side in (("L", 1), ("R", -1)):
        out = Vector((WHISKER_OUT.x * side, WHISKER_OUT.y, 0))
        start = Vector((x0 * side, y0, z0))
        for fan, length, curl in w["STRANDS"]:
            d0 = (out * math.cos(math.radians(fan)) + Vector((0, 0, math.sin(math.radians(fan))))).normalized()
            pts, p, d = [start], start.copy(), d0
            for i in range(WHISKER_STATIONS):
                u = (i + 1) / WHISKER_STATIONS
                ang = math.radians(curl) * u * u   # bends only toward the tip
                d = (d0 * math.cos(ang) + Vector((0, 0, 1)) * math.sin(ang)).normalized()
                p = p + d * (length / WHISKER_STATIONS)
                pts.append(p)
            rings = []
            for i, c in enumerate(pts):
                u = i / WHISKER_STATIONS
                t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
                if i == len(pts) - 1:
                    rings.append([bm.verts.new(c)])
                    sv.append(u)
                    wts.append(tag)
                    continue
                r = w["R"] * max(0.0, 1 - u ** 2.2) ** 0.6   # full body, soft rounded taper
                dep = t.cross(Vector((0, 0, 1))).normalized()
                up = dep.cross(t).normalized()
                rings.append([bm.verts.new(c + (up * math.cos(a) + dep * math.sin(a) * w["FLAT"]) * r)
                              for a in (2 * math.pi * k / WHISKER_SIDES for k in range(WHISKER_SIDES))])
                sv += [u] * WHISKER_SIDES
                wts += [tag] * WHISKER_SIDES
            rp.loft(bm, rings, cap_start=True, cap_end=False)
    o = new_object(name + "_Whiskers", bm, material("Whiskers"), col, [1.0] * len(sv), 80.0)
    o["region"] = "Whiskers"
    skin(o, arm, [[("Whisker%s" % t, 1.0)] for t in wts])
    return arm, [o]


def whisker_sizes(objs, head):
    mn, mx = world_bounds(objs)
    hw = head[1].x - head[0].x
    past = max(mx.x - head[1].x, head[0].x - mn.x)
    return dict(span=round(mx.x - mn.x, 3), past_head_side=round(past, 3),
                span_vs_head_width=round((mx.x - mn.x) / hw, 2), past_side_vs_head_width=round(past / hw, 2),
                height_vs_head=round((mx.z - mn.z) / HEAD_H_REF, 2))


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


def pose(arm, bend=("Z", 0.0), ear_deg=0.0):
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        if pb.name.startswith("Tail") and pb.name != "TailBase":
            rot = [0.0, 0.0, 0.0]
            rot["XYZ".index(bend[0])] = math.radians(bend[1])
            pb.rotation_euler = rot
        if pb.name in ("EarL", "EarR"):
            pb.rotation_euler = (math.radians(ear_deg), 0, 0)
    bpy.context.view_layer.update()


# ---------------------------------------------------------------------------------- sizes -----
def world_bounds(objs):
    ps = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    return (Vector([min(p[i] for p in ps) for i in range(3)]), Vector([max(p[i] for p in ps) for i in range(3)]))


def ear_sizes(name, objs, head):
    """Visible ear height (top above the head surface under the base) and one ear's width, as
    ratios of the R6 head's height and width."""
    p = EARS[name]
    left = [o for o in objs if "_Left" in o.name]
    mn, mx = world_bounds(left)
    hh, hw = HEAD_H_REF, head[1].x - head[0].x
    vis = mx.z - (head_surface_z(p["X"], EAR_Y) or HAT.z)
    return dict(visible_height=round(vis, 3), width=round(mx.x - mn.x, 3),
                height_vs_head=round(vis / hh, 2), width_vs_head=round((mx.x - mn.x) / hw, 2))


def tail_sizes(name, path, torso):
    q = TAILS[name]
    th, td = torso[1].z - torso[0].z, torso[1].y - torso[0].y
    s_att = path.param_of(WAIST_BACK)
    length = path.length * (1 - s_att)
    thick = 2 * q["R"] * max(r for _, r in q["PROFILE"]) * (1 + 0.7 * q["CLUMPS"]["FLARE"])   # with the fur
    return dict(length=round(length, 2), thickness=round(thick, 2),
                length_vs_torso_height=round(length / th, 2), thickness_vs_torso_depth=round(thick / td, 2),
                limb_clearance=limb_clearance(q, path))


def limb_clearance(q, path):
    """Smallest gap (studs) between the tail's furred outline and any limb swung up to SWING_DEG
    either way about its hip or shoulder (negative = they overlap at some point of the swing), and
    the arc distance from the attachment where it's worst. The first ROOT_ZONE studs are skipped:
    every tail root sits right above the legs' hinge."""
    s_att = path.param_of(WAIST_BACK) + ROOT_ZONE / path.length
    out = {}
    for limb, (mn, mx, pv) in LIMBS.items():
        best, where = 99.0, 0.0
        for deg in range(-SWING_DEG, SWING_DEG + 1, 10):
            rot = Matrix.Rotation(math.radians(-deg), 3, "X")
            for i in range(61):
                s = s_att + (1 - s_att) * i / 60
                p = rot @ (path.at(s)[0] - Vector(pv)) + Vector(pv)   # into the limb's swung frame
                d = Vector([max(mn[k] - p[k], 0, p[k] - mx[k]) for k in range(3)]).length
                gap = d - core_radius(q, s) * (1 + 0.7 * q["CLUMPS"]["FLARE"])
                if gap < best:
                    best, where = gap, (s - s_att) * path.length + ROOT_ZONE
        out[limb] = [round(best, 2), round(where, 2)]
    return out


# ---------------------------------------------------------------------------------- export ----
def r3(v):
    return [round(x, 3) for x in v]


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
            meshes[o.name] = dict(region=o["region"], tris=tri_count(o), center=r3((mn + mx) / 2), size=r3(mx - mn),
                                  roblox_center=[round(-(mn.x + mx.x) / 2, 3), round((mn.z + mx.z) / 2, 3),
                                                 round((mn.y + mx.y) / 2, 3)])
        bones = {}
        for b in arm.data.bones:
            h = b.head_local
            bones[b.name] = dict(parent=b.parent.name if b.parent else None, head=r3(h), tail=r3(b.tail_local),
                                 roblox_head=[round(-h.x, 3), round(h.z, 3), round(h.y, 3)], deform=b.use_deform)
        report = dict(
            name=name, attachment=attach_name, attachment_avatar_space=r3(attach),
            units="1 Blender unit = 1 stud; positions relative to the attachment (Blender X avatar left, "
                  "-Y avatar front, Z up)",
            roblox_mapping="a Blender point (x, y, z) is (-x, z, y) in the attachment's Roblox frame; "
                           "mesh Size = (bx, bz, by), CFrame = CFrame.new(-cx, cz, cy), no rotation",
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
# (view, eye direction from target, target, ortho scale or None = perspective, distance)
VIEWS = [
    ("front", (0, -1, 0.10), (0, 1.0, 0.5), 8.6, 20),
    ("side", (1, 0, 0.08), (0, 1.6, 0.5), 8.6, 20),
    ("back", (0, 1, 0.12), (0, 1.0, 0.5), 8.6, 20),
    ("threequarter", (0.8, 0.85, 0.38), (0.0, 1.4, 0.6), 8.6, 20),
    ("bent", (1, 0.35, 0.15), (0.0, 1.6, 0.4), 8.6, 20),
    ("ears", (0.55, 0.85, 0.40), (0, 0.05, 3.15), None, 4.0),
    ("face", (-0.45, -1.0, 0.25), (0, -0.2, 2.75), None, 4.4),
]
SEAT = ((1.0, 0.3, 0.10), 2.3)     # ear seating close-up: from the side, just above head height
CLOSE = ((0.85, 0.75, 0.35), 3.4)   # bent tail close-up


def render_tiles(scene, root_col, out_dir, res=400):
    rp.setup_render(scene, res=(res, res))
    layer = scene.view_layers[0].layer_collection.children[root_col.name]
    shots = []
    for direction, tail, ears, whisk, _ in PAIRS:
        for c in layer.children:
            c.exclude = c.name not in (tail, ears, whisk)
        t_arm, e_arm = bpy.data.objects[tail + "_Rig"], bpy.data.objects[ears + "_Rig"]
        for view, d, tgt, ortho, dist in VIEWS:
            bent = view == "bent"
            pose(t_arm, TAILS[tail]["BEND"] if bent else ("Z", 0.0))
            pose(e_arm, ear_deg=50.0 if bent else 0.0)
            eye = Vector(tgt) + Vector(d).normalized() * dist
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (direction, view)), tuple(eye), tgt,
                                   ortho=ortho, lens=50))
        pose(e_arm)
        p = EARS[ears]
        base = Vector((p["X"], EAR_Y, (head_surface_z(p["X"], EAR_Y) or HAT.z) + 0.1))
        d, dist = SEAT
        shots.append(rp.render(scene, os.path.join(out_dir, "%s_seat.png" % direction),
                               tuple(base + Vector(d).normalized() * dist), tuple(base), lens=50))
        pose(t_arm, TAILS[tail]["BEND"])
        obj = bpy.data.objects[tail + "_Tail"]
        ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
        mid = sum((v.co for v in ev.vertices), Vector()) / len(ev.vertices)
        d, dist = CLOSE
        shots.append(rp.render(scene, os.path.join(out_dir, "%s_close.png" % direction),
                               tuple(mid + Vector(d).normalized() * dist), tuple(mid), lens=50))
        pose(t_arm)
    for c in layer.children:
        c.exclude = False
    return shots


# ---------------------------------------------------------------------------------- main ------
def main():
    scene = bpy.context.scene
    if scene.name != SCENE:
        scene = bpy.data.scenes.get(SCENE) or scene
        scene.name = SCENE
    for o in list(scene.collection.objects):
        if o.type in ("MESH", "CAMERA", "LIGHT") and o.name in ("Cube", "Camera", "Light"):
            bpy.data.objects.remove(o, do_unlink=True)
    rp.import_rig(scene)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    root_col = bpy.data.collections.get(ROOT_COLLECTION) or bpy.data.collections.new(ROOT_COLLECTION)
    if root_col.name not in scene.collection.children:
        scene.collection.children.link(root_col)
    keep = set(TAILS) | set(EARS) | set(WHISKERS)
    for c in list(root_col.children):
        if c.name not in keep:
            for o in list(c.objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.collections.remove(c)
    shade_image()
    head, torso = body_part_bounds("Head"), body_part_bounds("Torso")
    built, sizes = {}, {}
    for name in EARS:
        arm, objs = build_ears(name, root_col)
        sizes[name] = dict(ear_sizes(name, objs, head), tris=sum(tri_count(o) for o in objs), mood=EARS[name]["mood"])
        built[name] = (arm, objs, HAT, "HatAttachment", dict(mood=EARS[name]["mood"], sizes=sizes[name]))
    for name in TAILS:
        arm, objs, path = build_tail(name, root_col)
        sizes[name] = dict(tail_sizes(name, path, torso), tris=sum(tri_count(o) for o in objs))
        built[name] = (arm, objs, WAIST_BACK, "WaistBackAttachment", dict(sizes=sizes[name]))
    for name in WHISKERS:
        arm, objs = build_whiskers(name, root_col)
        sizes[name] = dict(whisker_sizes(objs, head), tris=sum(tri_count(o) for o in objs), mood=WHISKERS[name]["mood"])
        built[name] = (arm, objs, FACE_FRONT, "FaceFrontAttachment", dict(mood=WHISKERS[name]["mood"], sizes=sizes[name]))
    sizes["_reference"] = dict(head=dict(height=HEAD_H_REF, width=round(head[1].x - head[0].x, 3)),
                               torso=dict(height=round(torso[1].z - torso[0].z, 3), depth=round(torso[1].y - torso[0].y, 3)))
    print(json.dumps(sizes, indent=1))
    os.makedirs(os.path.join(HERE, "renders"), exist_ok=True)
    with open(os.path.join(HERE, "renders", "sizes.json"), "w") as fh:
        json.dump(sizes, fh, indent=1)
    if EXPORT:
        for name, (arm, objs, attach, att_name, extra) in built.items():
            export_set(name, arm, objs, attach, att_name, extra)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "Tiger.blend"))
    if RENDER:
        print(len(render_tiles(scene, root_col, os.path.join(HERE, "renders"))), "tiles")


main()
