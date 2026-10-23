r"""Ghost cosmetics: forehead talismans and spirit wisps for the player's R6 avatar.

Intent: a lingering cultivation spirit, sorrowful and elegant, never horror. The wisps are the
hero (the silhouette read at game distance, pale and fading); the talisman is the face's
identity mark (aged paper, red brush glyphs) and stays small and flat on the brow.

  Talismans (FaceFrontAttachment): GhostTalismanStrip, GhostTalismanBanner, GhostTalismanSeal
  Wisps: GhostSleeveL / GhostSleeveR (Left/RightGripAttachment), GhostTrain (WaistCenterAttachment),
         GhostStole (BodyBackAttachment)
Each set is its own collection (and, on export, FBX + JSON beside this script) with its own armature.

Run in the race's own Blender window (tools/blender_live.sh run ghost <this file>).
Optional globals: RENDER (default True: sheet tiles into renders/), EXPORT (default True: FBX,
JSON, shade PNGs), SAVE_BLEND (default True: Ghost.blend), ONLY (set names).
Then stitch the sheet with make_sheet.py.

Axes and units (the R6 reference, art/rig/r6_rigged.fbx): 1 Blender unit = 1 stud. +X = the
avatar's left, it faces -Y, Z up. Hips z 0, torso z 0..2 (2 wide, 1 deep), arms x +-1..+-2 and
z -0.5..1.5, legs z -2..0. The head is a cylinder of radius 0.6, z 2.084..3.101 (rounded top
from z 2.9), centre z 2.5. Attachments (rest pose, avatar space):
  FaceFrontAttachment (0, -0.6, 2.5)   LeftGripAttachment (1.5, 0, -0.5)
  RightGripAttachment (-1.5, 0, -0.5)  WaistCenterAttachment (0, 0, 0)   BodyBackAttachment (0, 0.5, 1)
Built in avatar space; the export moves each set so its attachment is the origin.

Recolour contract: one mesh object (one MeshPart) per colour region, material named
Ghost_<Region>: Paper, Ink, Cord (talismans), Spirit (sleeve cuffs, the solid body of a wisp)
and Wisp (the trailing ribbons). Paper uses the shared greyscale ramp (fox_shade.png settings,
edges darker = aged). Spirit and Wisp use ghost_fade.png: greyscale brightening and alpha
fading along UV V (V 0 at the root, 1 at the tip), for SurfaceAppearance AlphaMode Transparency.

Rig: bones named like the Motor6Ds they become. Root (the attachment, non-deforming) ->
  talisman: TalismanBase (the pinned top) -> Talisman (hinge across the paper; + about local X
            lifts the paper off the face)
  wisps:    WispBase (buried roots, cuffs) -> Wisp<Tag>1..n per ribbon (+ about local X bends it
            across its face, local Z sways it edgewise)
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.geometry import delaunay_2d_cdt

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "art", "rig"))
import rig_preview as rp  # noqa: E402

RENDER = globals().get("RENDER", True)
EXPORT = globals().get("EXPORT", True)
SAVE_BLEND = globals().get("SAVE_BLEND", True)
ONLY = globals().get("ONLY")

SCENE = "Cosmetics"
ROOT_COLLECTION = "GhostCosmetics"
FACE_FRONT = Vector((0.0, -0.6, 2.5))
LEFT_GRIP = Vector((1.5, 0.0, -0.5))
RIGHT_GRIP = Vector((-1.5, 0.0, -0.5))
WAIST_CENTER = Vector((0.0, 0.0, 0.0))
BODY_BACK = Vector((0.0, 0.5, 1.0))

# Colours (linear). Region name -> default.
COLORS = {
    "Paper":  (0.79, 0.62, 0.32, 1),   # faded yellow parchment
    "Ink":    (0.52, 0.025, 0.015, 1), # vermilion brush ink
    "Cord":   (0.025, 0.03, 0.08, 1),  # dark indigo cord (the weapon kit's cord)
    "Spirit": (0.60, 0.78, 0.95, 1),   # pale blue-white
    "Wisp":   (0.42, 0.78, 0.90, 1),   # pale cyan
}
PAPER_SHARP_DEG = 50.0
WISP_SHARP_DEG = 80.0     # silk: smooth, only the folds stay crisp

# Shade ramps (V only). Paper: the shared fox ramp (byte-identical settings, reusable asset).
SHADE_FILE, SHADE_MIN, SHADE_REACH = "fox_shade.png", 0.55, 0.45
# Wisps: value from FADE_VAL[0] at the root to FADE_VAL[1] at the tip, alpha from FADE_ALPHA[0]
# to FADE_ALPHA[1] (starting to fade at FADE_START): a solid root melting into mist.
FADE_FILE = "ghost_fade.png"
FADE_VAL = (0.78, 1.0)
FADE_ALPHA = (0.85, 0.12)
FADE_START = 0.25
PREVIEW_ALPHA = True       # the renders show the fade (the Roblox target); False = solid check

# ---------------------------------------------------------------------------------------------
# Talismans. Paper coords (u, w): u across (+ = avatar's left), w up, w 0 = the top edge.
# CX, TOP: where the top centre sits on the face; TILT degrees (+ turns the bottom to the right);
# SHAPE: "strip" | "banner" (swallowtail) | "seal" (square); W, H size; TEAR (top, sides, bottom)
# torn-edge depth; CURL how far the bottom edge lifts off the face; PIN_W the pinned band at the
# top (w); GLYPHS: polylines [(u, w), ...] with a brush width; CORD: a cord band across the top.
PAPER_FRONT, PAPER_BACK = 0.022, 0.016   # paper: out of / into the face surface
INK_FRONT, INK_BACK = 0.030, 0.012       # ink: proud of the paper, back buried in it
CORD_FRONT, CORD_BACK = 0.042, 0.020


def circle(cu, cw, r, n=16, a0=0.0, a1=2 * math.pi):
    return [(cu + r * math.cos(a0 + (a1 - a0) * k / n), cw + r * math.sin(a0 + (a1 - a0) * k / n))
            for k in range(n + 1)]


TALISMANS = {
    # the classic: a long strip hanging from the brow, set off centre so one eye shows
    "GhostTalismanStrip": dict(
        label="Strip", SHAPE="strip", CX=0.12, TOP=2.99, TILT=-6, W=0.34, H=0.62,
        TEAR=(0.006, 0.018, 0.055), CURL=0.035, PIN_W=0.10,
        GLYPHS=[([(-0.09, -0.07), (0.0, -0.06), (0.09, -0.075)], 0.030),
                ([(-0.11, -0.13), (0.0, -0.12), (0.11, -0.13)], 0.028),
                ([(0.0, -0.08), (0.01, -0.22), (-0.01, -0.36), (0.0, -0.47)], 0.034),
                ([(-0.08, -0.21), (0.08, -0.20)], 0.026),
                (circle(0.0, -0.32, 0.055, 14), 0.020),
                ([(-0.10, -0.40), (-0.05, -0.44)], 0.022),
                ([(0.10, -0.40), (0.05, -0.44)], 0.022),
                ([(0.0, -0.47), (0.04, -0.50), (0.07, -0.48)], 0.024)],
        CORD=False),
    # the reference's banner: wider, a swallowtail fork and a dark cord across the top
    "GhostTalismanBanner": dict(
        label="Banner", SHAPE="banner", CX=-0.02, TOP=2.98, TILT=4, W=0.42, H=0.56, NOTCH=0.13,
        TEAR=(0.004, 0.014, 0.035), CURL=0.03, PIN_W=0.10,
        GLYPHS=[(circle(0.0, -0.22, 0.10, 20), 0.026),
                ([(0.0, -0.08), (0.0, -0.22), (0.0, -0.37)], 0.032),
                ([(-0.07, -0.22), (0.07, -0.22)], 0.024),
                ([(-0.15, -0.10), (-0.15, -0.30)], 0.020),
                ([(0.15, -0.10), (0.15, -0.30)], 0.020)],
        CORD=True),
    # a small square seal tilted on one side of the brow, a round vermilion seal mark
    "GhostTalismanSeal": dict(
        label="Seal", SHAPE="seal", CX=-0.16, TOP=2.98, TILT=14, W=0.32, H=0.32,
        TEAR=(0.010, 0.016, 0.022), CURL=0.02, PIN_W=0.09,
        GLYPHS=[(circle(0.0, -0.16, 0.10, 20), 0.024),
                ([(0.0, -0.10), (0.0, -0.22)], 0.026),
                ([(-0.06, -0.15), (0.06, -0.15)], 0.024),
                ([(-0.035, -0.20), (0.035, -0.20)], 0.018)],
        CORD=False),
}

# ---------------------------------------------------------------------------------------------
# Wisp ribbons. Each ribbon: PATH control points (avatar space, the first inside the body),
# N0 its initial width direction, W max half width, PROFILE half width along s (x W),
# TH half thickness, BOW how far the edges sweep back from the centre (x the half width: a
# billowing, cupped silk instead of a flat plank), WAVE (amplitude, cycles) a soft swell of the
# width along the length (misty, not spiky), TWIST degrees of turn along its length,
# SPLIT (s, spread, short) splits the end into two round tongues (spread x the half width apart,
# the second one `short` shorter) or None, BONES joints, S_OUT where it leaves the body.
SOFT = [(0, 0.55), (0.15, 0.9), (0.40, 1.0), (0.70, 0.85), (0.90, 0.55), (1, 0.0)]
BAND = [(0, 0.8), (0.1, 1.0), (0.9, 1.0), (1, 0.8)]

# Sleeves: a flared spectral cuff on each forearm, its back drawn out into one broad drape and a
# smaller ribbon that stream back. Built for the left arm (+X), mirrored for the right. Nothing
# comes inside x 1.02 (the arm's inner face): the legs and torso sit there.
CUFF = dict(TOP=0.75, BOTTOM=-0.30, DROOP=0.45, A_TOP=0.59, FLARE=0.48, A_IN=0.47, N=6.0, SIDES=28,
            RINGS=6, INNER_X=1.03)
SLEEVE_RIBBONS = {
    "A": dict(PATH=[(1.60, 0.25, -0.20), (1.62, 0.70, -0.62), (1.68, 1.25, -0.98), (1.75, 1.85, -1.08),
                    (1.82, 2.40, -0.92), (1.88, 2.80, -0.55)],
              N0=(1, 0, 0), W=0.38, PROFILE=SOFT, TH=0.04, BOW=0.35, WAVE=(0.12, 2.0), TWIST=25,
              SPLIT=(0.74, 1.0, 0.14), BONES=4, S_OUT=0.10),
    "B": dict(PATH=[(1.95, 0.15, -0.05), (2.15, 0.55, -0.35), (2.28, 1.05, -0.55), (2.34, 1.55, -0.50),
                    (2.38, 1.95, -0.25)],
              N0=(0.2, 0, 1), W=0.22, PROFILE=SOFT, TH=0.035, BOW=0.3, WAVE=(0.10, 1.5), TWIST=-35,
              SPLIT=None, BONES=3, S_OUT=0.12),
}
# Train: the lower body. A sash across the lower back, from under it three broad sheets: a wide one that
# flows back level (above the legs' back swing), sinks low and curls up at its end, and
# two smaller ones that fan out and down to either side. They stay inside |x| 0.95 until they are
# past the arms' back swing (2 studs behind the shoulder).
SASH = dict(PATH=[(-0.96, 0.50, 0.50), (-0.5, 0.53, 0.47), (0.0, 0.54, 0.46), (0.5, 0.53, 0.47), (0.96, 0.50, 0.50)],
            N0=(0, 0, 1), W=0.17, PROFILE=BAND, TH=0.07, BOW=0.0, WAVE=(0.0, 1.0), TWIST=0, SPLIT=None,
            CLOSED=True)   # a sash across the lower back that the sheets flow out from
_SIDE_L = dict(PATH=[(0.40, 0.30, 0.60), (0.52, 0.95, 0.62), (0.70, 1.75, 0.25), (1.10, 2.35, -0.25),
                     (1.45, 2.75, -0.85), (1.55, 2.90, -1.25)],
               N0=(1, 0, -0.3), W=0.32, PROFILE=SOFT, TH=0.045, BOW=0.35, WAVE=(0.12, 2.0), TWIST=30,
               SPLIT=None, BONES=4, S_OUT=0.10)
TRAIN_RIBBONS = {
    "Tail": dict(PATH=[(0, 0.10, 0.45), (0, 0.75, 0.42), (0, 1.45, 0.30), (0, 2.15, 0.00), (0.05, 2.75, -0.60),
                       (0.10, 3.20, -1.15), (0.05, 3.70, -1.30), (0.0, 4.05, -1.00), (0.0, 4.15, -0.60)],
                 N0=(1, 0, 0), W=0.82, PROFILE=[(0, 0.85), (0.25, 1.0), (0.6, 0.95), (0.85, 0.7), (1, 0.0)],
                 TH=0.06, BOW=0.30, WAVE=(0.10, 2.5), TWIST=0, SPLIT=None, BONES=5, S_OUT=0.10),
    "L": _SIDE_L,
    "R": dict(_SIDE_L, PATH=[(-x, y, z) for (x, y, z) in _SIDE_L["PATH"]], N0=(-1, 0, -0.3), TWIST=-30),
}
# Stole: a celestial maiden's floating silk. A wide hoop rises from the shoulder blades and arches
# behind the head like a halo; from the same spots a long end floats out over each arm (above its
# swing) and drifts down past the hand. Hoop and ends meet buried in the back, so it reads as one silk.
_HOOP_L = [(0.55, 0.30, 1.70), (0.95, 0.85, 2.15), (1.25, 1.15, 2.85), (1.10, 1.25, 3.55), (0.60, 1.28, 4.00),
           (0.0, 1.30, 4.15)]
_TRAIL_L = dict(PATH=[(0.50, 0.30, 1.78), (1.00, 0.80, 2.10), (1.60, 1.05, 2.12), (2.25, 1.20, 1.75),
                      (2.55, 1.40, 1.05), (2.70, 1.70, 0.35), (2.85, 2.05, -0.20)],
                N0=(0, -0.25, 1), W=0.24, PROFILE=SOFT, TH=0.035, BOW=0.3, WAVE=(0.12, 2.0), TWIST=70,
                SPLIT=(0.80, 1.0, 0.12), BONES=4, S_OUT=0.10)
STOLE_RIBBONS = {
    "Hoop": dict(PATH=_HOOP_L + [(-x, y, z) for (x, y, z) in reversed(_HOOP_L[:-1])],
                 N0=(0, 1, 0), W=0.20, PROFILE=BAND, TH=0.035, BOW=0.25, WAVE=(0.08, 3.0), TWIST=0, SPLIT=None,
                 BONES=3, S_OUT=0.06, CLOSED=True),
    "TrailL": _TRAIL_L,
    "TrailR": dict(_TRAIL_L, PATH=[(-x, y, z) for (x, y, z) in _TRAIL_L["PATH"]], TWIST=-70),
}

WISPS = {
    "GhostSleeveL": dict(label="Sleeves", kind="sleeve", side=1, attach=LEFT_GRIP,
                         attach_name="LeftGripAttachment", ribbons=SLEEVE_RIBBONS),
    "GhostSleeveR": dict(label="Sleeves", kind="sleeve", side=-1, attach=RIGHT_GRIP,
                         attach_name="RightGripAttachment", ribbons=SLEEVE_RIBBONS),
    "GhostTrain": dict(label="Train", kind="train", side=1, attach=WAIST_CENTER,
                       attach_name="WaistCenterAttachment", ribbons=TRAIN_RIBBONS),
    "GhostStole": dict(label="Stole", kind="stole", side=1, attach=BODY_BACK,
                       attach_name="BodyBackAttachment", ribbons=STOLE_RIBBONS),
}

# Variants (all three kept, 2026-10-23), one sheet row each: (name, talisman, wisp sets)
DIRECTIONS = [("Sleeves", "GhostTalismanStrip", ["GhostSleeveL", "GhostSleeveR"]),
              ("Train", "GhostTalismanBanner", ["GhostTrain"]),
              ("Stole", "GhostTalismanSeal", ["GhostStole"])]

RIBBON_SIDES = 8
STATION_LEN = 0.07      # ribbon ring spacing (studs)
JOINT_BLEND = 0.45
ROOT_BONE_LEN = 0.2
RUN_DEG = 57.3
BEND_DEG = 22.0         # sheet bend check per wisp joint
FLUTTER_DEG = 25.0      # sheet talisman lift


# --------------------------------------------------------------------------------- helpers ----
def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def interp(profile, s):
    for (s0, r0), (s1, r1) in zip(profile, profile[1:]):
        if s0 <= s <= s1:
            u = (s - s0) / (s1 - s0)
            u = u * u * (3 - 2 * u)
            return r0 + (r1 - r0) * u
    return profile[-1][1]


def ramp_image(name, fn, alpha):
    img = bpy.data.images.get(name)
    if img is not None:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(name, 4, 128, alpha=alpha)
    img.colorspace_settings.name = "sRGB"
    px = []
    for y in range(128):
        px += list(fn((y + 0.5) / 128)) * 4
    img.pixels.foreach_set(px)
    img.update()
    if EXPORT:
        img.filepath_raw = os.path.join(HERE, name)
        img.file_format = "PNG"
        img.save()
    img.pack()
    return img


def shade_fn(v):
    g = SHADE_MIN + (1 - SHADE_MIN) * smoothstep(0.0, SHADE_REACH, v)
    return (g, g, g, 1.0)


def fade_fn(v):
    g = FADE_VAL[0] + (FADE_VAL[1] - FADE_VAL[0]) * smoothstep(0.0, 1.0, v)
    a = FADE_ALPHA[0] + (FADE_ALPHA[1] - FADE_ALPHA[0]) * smoothstep(FADE_START, 1.0, v)
    return (g, g, g, a)


def material(region):
    name = "Ghost_" + region
    m = rp.preview_material(name, COLORS[region])
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    for n in [n for n in nt.nodes if n.type in ("TEX_IMAGE", "MIX", "MATH")]:
        nt.nodes.remove(n)
    fade = region in ("Spirit", "Wisp")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.get(FADE_FILE if fade else SHADE_FILE)
    tex.interpolation = "Linear"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    rgba_in = [s for s in mix.inputs if s.type == "RGBA"]
    rgba_in[0].default_value = COLORS[region]
    nt.links.new(tex.outputs["Color"], rgba_in[1])
    out = next(s for s in mix.outputs if s.type == "RGBA")
    nt.links.new(out, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    m.use_backface_culling = True   # Roblox culls back faces; show what it will show
    if fade:
        nt.links.new(out, bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 0.35
        if PREVIEW_ALPHA:
            nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        else:
            for lk in list(bsdf.inputs["Alpha"].links):
                nt.links.remove(lk)
            bsdf.inputs["Alpha"].default_value = 1.0
        for attr, val in (("surface_render_method", "DITHERED"), ("blend_method", "HASHED")):
            try:
                setattr(m, attr, val)
            except (AttributeError, TypeError):
                pass
        try:
            m.use_transparency_overlap = True
        except AttributeError:
            pass
    return m


def new_object(name, bm, region, col, vvals, sharp):
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
    me.materials.append(material(region))
    o["region"] = region
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


def rig_mesh():
    return next(o for o in rp.rig_objects() if o.type == "MESH")


def body_bbox(test):
    vs = [rig_mesh().matrix_world @ v.co for v in rig_mesh().data.vertices]
    vs = [v for v in vs if test(v)]
    return (Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)]))


def head_bbox():
    return body_bbox(lambda v: v.z > 2.0 and abs(v.x) < 1.0)


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


def pose(arm, bend=0.0, flutter=0.0):
    """Sheet check: every Wisp joint bent `bend` degrees about local X, the talisman lifted
    `flutter` degrees. 0 = rest."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        if pb.name.startswith("Wisp") and pb.name != "WispBase":
            pb.rotation_euler = (math.radians(bend), 0, 0)
        if pb.name == "Talisman":
            pb.rotation_euler = (math.radians(flutter), 0, 0)
    bpy.context.view_layer.update()


# ----------------------------------------------------------------------------- talisman -------
def head_front_y(x, z):
    """The head surface's y at (x, z), by a ray from the front along +Y onto the rig mesh."""
    rig = rig_mesh()
    inv = rig.matrix_world.inverted()
    hit, loc, *_ = rig.ray_cast(inv @ Vector((x, -3.0, z)), (inv.to_3x3() @ Vector((0, 1, 0))).normalized())
    assert hit, "talisman point (%.2f, %.2f) misses the head" % (x, z)
    y = (rig.matrix_world @ loc).y
    assert y < -0.1, "talisman point (%.2f, %.2f) is off the face (y %.2f)" % (x, z, y)
    return y


def outline(p):
    """Torn outline [(u, w)] (counter-clockwise seen from the front) and a per-point edge kind."""
    W, H = p["W"] / 2, p["H"]
    if p["SHAPE"] == "banner":
        n = p["NOTCH"]
        corners = [(-W, 0), (-W, -H), (-W * 0.15, -H + n * 0.15), (0, -H + n), (W * 0.15, -H + n * 0.15),
                   (W, -H), (W, 0)]
        kinds = ["side", "bottom", "bottom", "bottom", "bottom", "side", "top"]
    else:
        corners = [(-W, 0), (-W, -H), (W, -H), (W, 0)]
        kinds = ["side", "bottom", "side", "top"]
    pts, kk = [], []
    for i, (a, b) in enumerate(zip(corners, corners[1:] + corners[:1])):
        a, b = Vector(a), Vector(b)
        n = max(2, int((b - a).length / 0.022))
        for k in range(n):
            pts.append(a.lerp(b, k / n))
            kk.append(kinds[i])
    amp = dict(zip(("top", "side", "bottom"), p["TEAR"]))
    seed = sum(ord(c) for c in p["label"])
    out = []
    m = len(pts)
    for i, (q, kind) in enumerate(zip(pts, kk)):
        prev, nxt = pts[i - 1], pts[(i + 1) % m]
        t = (nxt - prev).normalized()
        inward = Vector((-t.y, t.x))   # CCW: inward is to the left
        x = i * 0.9 + seed
        bite = (0.55 + 0.45 * math.sin(x * 1.7) * math.sin(x * 0.63 + 1.3)) ** 2 + 0.25 * math.sin(x * 3.9)
        d = amp[kind] * max(0.0, bite)
        # corners tear a little more (paper ages from its corners)
        d += amp[kind] * 0.6 * max(0.0, 1 - min((q - Vector(c)).length for c in corners) / 0.05)
        out.append(q + inward * d)
    return out


def inside(poly, pt):
    c = False
    for a, b in zip(poly, poly[1:] + poly[:1]):
        if (a.y > pt.y) != (b.y > pt.y) and pt.x < (b.x - a.x) * (pt.y - a.y) / (b.y - a.y) + a.x:
            c = not c
    return c


def edge_dist(poly, pt):
    best = 1e9
    for a, b in zip(poly, poly[1:] + poly[:1]):
        ab = b - a
        t = max(0.0, min(1.0, (pt - a).dot(ab) / max(1e-12, ab.dot(ab))))
        best = min(best, (a + ab * t - pt).length)
    return best


class Paper:
    """Paper coords -> avatar space on the face: tilt about the top centre, then drop each point
    onto the head surface (ray along +Y) with an offset (+ = out of the face) and the curl."""

    def __init__(self, p):
        self.p = p
        self.c, self.s = math.cos(math.radians(p["TILT"])), math.sin(math.radians(p["TILT"]))

    def xz(self, u, w):
        return self.p["CX"] + u * self.c - w * self.s, self.p["TOP"] + u * self.s + w * self.c

    def curl(self, u, w):
        p = self.p
        k = smoothstep(-p["H"] * 0.55, -p["H"], w)
        return p["CURL"] * (k * k + 0.5 * k * (abs(u) / (p["W"] / 2)) ** 3)

    def at(self, u, w, out):
        x, z = self.xz(u, w)
        return Vector((x, head_front_y(x, z) - out - self.curl(u, w), z))

    def frame(self):
        """(hinge point at PIN_W, across, down) in avatar space."""
        x, z = self.xz(0, -self.p["PIN_W"])
        return Vector((x, head_front_y(x, z) - PAPER_FRONT, z)), Vector((self.c, 0, self.s)), Vector((self.s, 0, -self.c))


def slab(bm, tris, coords2, boundary, front_fn, back_fn, vals, vfn):
    """A closed slab: front triangles, back triangles, side walls along the boundary loop."""
    fv = [bm.verts.new(front_fn(c)) for c in coords2]
    bv = [bm.verts.new(back_fn(c)) for c in coords2]
    for c in coords2:
        vals.append(vfn(c))
    for c in coords2:
        vals.append(vfn(c))
    for a, b, c in tris:
        bm.faces.new((fv[a], fv[b], fv[c]))
        bm.faces.new((bv[c], bv[b], bv[a]))
    for i, j in zip(boundary, boundary[1:] + boundary[:1]):
        bm.faces.new((fv[i], bv[i], bv[j], fv[j]))


def paper_mesh(p, paper):
    poly = outline(p)
    W, H = p["W"] / 2, p["H"]
    pts = list(poly)
    step = 0.045
    nu, nw = int(2 * W / step) + 2, int(H / step) + 2
    for i in range(nu):
        for j in range(nw):
            q = Vector((-W + 2 * W * i / (nu - 1), -H * j / (nw - 1)))
            if inside(poly, q) and edge_dist(poly, q) > 0.018:
                pts.append(q)
    nb = len(poly)
    edges = [(i, (i + 1) % nb) for i in range(nb)]
    vco, _, faces, orig, _, _ = delaunay_2d_cdt(pts, edges, [], 0, 1e-6)
    assert len(vco) == len(pts), "CDT added vertices"
    tris = []
    for f in faces:
        cen = sum((vco[k] for k in f), Vector((0, 0))) / 3
        if inside(poly, cen):
            tris.append(tuple(f))
    # CDT output order matches the input (asserted), so the outline is indices 0..nb-1
    bm, vals = bmesh.new(), []
    coords = [Vector(v) for v in vco]
    slab(bm, tris, coords, list(range(nb)),
         lambda c: paper.at(c.x, c.y, PAPER_FRONT), lambda c: paper.at(c.x, c.y, -PAPER_BACK), vals,
         lambda c: 0.2 + 0.8 * min(1.0, edge_dist(poly, c) / 0.07))   # aged: darker edges
    return bm, vals, coords


def stroke_mesh(bm, vals, ws, poly, width, paper, front, back, w_of=None):
    """One brush stroke: a closed flat band along polyline poly (paper coords), width tapering at
    both ends like a brush; front/back offsets from the face surface."""
    pts = [Vector(q) for q in poly]
    dense = []
    for a, b in zip(pts, pts[1:]):
        n = max(1, int((b - a).length / 0.02))
        dense += [a.lerp(b, k / n) for k in range(n)]
    dense.append(pts[-1])
    closed = (pts[0] - pts[-1]).length < 1e-6
    rings = []
    m = len(dense)
    for i, q in enumerate(dense):
        t = (dense[min(i + 1, m - 1)] - dense[max(i - 1, 0)]).normalized()
        nrm = Vector((-t.y, t.x))
        s = i / (m - 1)
        k = 1.0 if closed else (0.35 + 0.65 * math.sin(math.pi * min(1.0, s * 1.15)) ** 0.5)
        hw = width / 2 * max(0.3, k)
        a, b = q + nrm * hw, q - nrm * hw
        r = [bm.verts.new(paper.at(a.x, a.y, front)), bm.verts.new(paper.at(b.x, b.y, front)),
             bm.verts.new(paper.at(b.x, b.y, -back)), bm.verts.new(paper.at(a.x, a.y, -back))]
        rings.append(r)
        vals += [1.0] * 4
        ws += [q.y] * 4
    rp.loft(bm, rings, cap_start=True, cap_end=True)


def build_talisman(name, root_col):
    p = TALISMANS[name]
    col = collection(name, root_col)
    paper = Paper(p)
    arm = new_armature(name + "_Rig", col)
    eb = arm.data.edit_bones
    root = eb.new("Root")
    root.head, root.tail = FACE_FRONT, FACE_FRONT + Vector((0, -ROOT_BONE_LEN, 0))
    root.use_deform = False
    hinge, across, down = paper.frame()
    top = paper.at(0, 0, PAPER_FRONT)
    base = eb.new("TalismanBase")
    base.head, base.tail = top, hinge
    base.parent = root
    bone = eb.new("Talisman")
    bone.head, bone.tail = hinge, hinge + down * (p["H"] - p["PIN_W"]) * 0.85
    bone.parent, bone.use_connect = base, True
    for b in (root, base, bone):
        b.align_roll(Vector((0, -1, 0)))   # local Z out of the face, X across the paper
    bpy.ops.object.mode_set(mode="OBJECT")

    def weights(w):
        k = smoothstep(-p["PIN_W"], -p["PIN_W"] - 0.12, w)
        return [("TalismanBase", 1 - k), ("Talisman", k)]

    objs = []
    bm, vals, coords = paper_mesh(p, paper)
    o = new_object(name + "_Paper", bm, "Paper", col, vals, PAPER_SHARP_DEG)
    skin(o, arm, [weights(c.y) for c in coords] * 2)
    objs.append(o)
    bm, vals, ws = bmesh.new(), [], []
    for poly, width in p["GLYPHS"]:
        stroke_mesh(bm, vals, ws, poly, width, paper, INK_FRONT, -INK_BACK)
    o = new_object(name + "_Ink", bm, "Ink", col, vals, PAPER_SHARP_DEG)
    skin(o, arm, [weights(w) for w in ws])
    objs.append(o)
    if p["CORD"]:
        bm, vals, ws = bmesh.new(), [], []
        W = p["W"] / 2 + 0.005
        stroke_mesh(bm, vals, ws, [(-W, -0.025), (0, -0.03), (W, -0.025)], 0.045, paper, CORD_FRONT, CORD_BACK)
        stroke_mesh(bm, vals, ws, circle(0, -0.03, 0.025, 10), 0.03, paper, CORD_FRONT + 0.012, CORD_BACK)  # knot
        o = new_object(name + "_Cord", bm, "Cord", col, vals, PAPER_SHARP_DEG)
        skin(o, arm, [[("TalismanBase", 1.0)] for _ in ws])
        objs.append(o)
    return arm, objs


# --------------------------------------------------------------------------------- ribbons ----
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
    """Arc-length parametrised centreline with parallel-transport frames (n = width direction)."""

    def __init__(self, points, n0=(1, 0, 0)):
        self.p = catmull(points)
        self.l = [0.0]
        for a, b in zip(self.p, self.p[1:]):
            self.l.append(self.l[-1] + (b - a).length)
        self.length = self.l[-1]
        self.t, self.n = [], []
        n = Vector(n0).normalized()
        for i in range(len(self.p)):
            t = (self.p[min(i + 1, len(self.p) - 1)] - self.p[max(i - 1, 0)]).normalized()
            n = n - t * n.dot(t)
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


def frame(path, r, s):
    p, t, n = path.at(s)
    n = Matrix.Rotation(math.radians(r["TWIST"]) * s, 3, t) @ n
    return p, t, n, t.cross(n)


def sweep(bm, vals, s_list, fn, bow=0.0):
    """Loft lens-shaped rings: fn(s) -> (centre, width dir, thickness dir, half width, half thick).
    bow sweeps the edges back along the thickness direction (a cupped, billowing section)."""
    rings = []
    for s in s_list:
        c, n, b, w, th = fn(s)
        k_bow = bow * smoothstep(0.0, 0.3, s)   # flat where it leaves the body, billowing after
        if w <= 1e-4:
            rings.append([bm.verts.new(c)])
        else:
            rings.append([bm.verts.new(c + n * math.cos(a) * w + b * (math.sin(a) * th + k_bow * w * math.cos(a) ** 2))
                          for a in (2 * math.pi * k / RIBBON_SIDES for k in range(RIBBON_SIDES))])
        vals += [s] * len(rings[-1])
    rp.loft(bm, rings, cap_start=len(rings[0]) > 1, cap_end=len(rings[-1]) > 1)


def stations(path, s0, s1):
    n = max(4, int(path.length * (s1 - s0) / STATION_LEN))
    return [s0 + (s1 - s0) * i / n for i in range(n + 1)]


def build_ribbon(bm, vals, r, path):
    """A tapered silk ribbon (closed lens section); with SPLIT its end becomes two tongues that grow
    out of the body's width (they overlap it where they start, so there is no seam)."""
    W, TH = r["W"], r["TH"]

    amp, cyc = r["WAVE"]
    bow = r["BOW"]

    def width(s):
        swell = 1 + amp * math.sin(2 * math.pi * cyc * s + 0.7) * smoothstep(0.0, 0.25, s)
        return W * interp(r["PROFILE"], s) * swell

    if r.get("CLOSED"):
        def fn(s):
            p, t, n, b = frame(path, r, s)
            return p, n, b, width(s), TH
        sweep(bm, vals, stations(path, 0, 1), fn, bow)
        return
    split = r["SPLIT"]
    s_main_end = split[0] + 0.10 if split else 1.0

    def fn_main(s):
        p, t, n, b = frame(path, r, s)
        w = width(s)
        if split:   # the body closes quickly past the split, inside the two tongues
            w *= 1 - smoothstep(split[0], s_main_end, s) ** 2
            if s >= s_main_end - 1e-6:
                w = 0.0
        return p, n, b, w, TH * (1 - 0.5 * smoothstep(0.7, 1.0, s))
    sweep(bm, vals, stations(path, 0, s_main_end), fn_main, bow)
    if not split:
        return
    s0, spread, short = split
    for side, end in ((1, 1.0), (-1, 1.0 - short)):
        def fn_t(s, side=side, end=end):
            p, t, n, b = frame(path, r, s)
            u = max(0.0, (s - s0) / (end - s0))
            # the tongue drifts out sideways, then its end swings a little forward/back (flow)
            off = side * spread * width(s0) * 0.5 * smoothstep(0.0, 0.6, u)
            c = p + n * off + b * side * 0.06 * smoothstep(0.4, 1.0, u)
            w = width(s0) * 0.58 * max(0.0, 1 - u ** 3) ** 0.5   # full almost to the end: a round tip
            return c, n, b, w, TH * (1 - 0.4 * u)
        sweep(bm, vals, stations(path, s0 - 0.04, end), fn_t, bow * 0.6)


def chain_joints(r, path):
    return [r["S_OUT"] + (0.97 - r["S_OUT"]) * k / r["BONES"] for k in range(r["BONES"] + 1)]


def chain_weights(tag, s, joints, nb):
    names = ["WispBase"] + ["Wisp%s%d" % (tag, k + 1) for k in range(nb)]
    b = (joints[1] - joints[0]) * JOINT_BLEND
    ramps = [1.0] + [smoothstep(j - b, j + b, s) for j in joints[:nb]] + [0.0]
    return [(names[i], ramps[i] - ramps[i + 1]) for i in range(len(names)) if ramps[i] - ramps[i + 1] > 1e-4]


def mirror_r(r, side):
    if side == 1:
        return r
    return dict(r, PATH=[(-x, y, z) for (x, y, z) in r["PATH"]], N0=(-r["N0"][0], r["N0"][1], r["N0"][2]),
                TWIST=-r["TWIST"])


def superellipse(a, n, th):
    c, s = math.cos(th), math.sin(th)
    return a / (abs(c) ** n + abs(s) ** n) ** (1 / n)


def build_cuff(bm, vals, side):
    """A closed flared cuff on the forearm: outer wall flaring out and back and drooping at the back,
    the bottom rim, the inner wall (inside the arm), the top rim. A solid ring, sealed. On the
    body side it is pressed flat against the arm's inner face (x INNER_X), where the torso and
    legs sit flush with the arm."""
    c = CUFF
    cx = 1.5 * side
    ths = [2 * math.pi * k / c["SIDES"] for k in range(c["SIDES"])]

    def bottom(th):
        return c["BOTTOM"] - c["DROOP"] * (0.5 + 0.5 * math.sin(th)) ** 2   # +y (back) droops

    def flare(th):   # most toward the back and outside, none toward the body
        return max(0.0, 0.5 + 0.5 * (0.55 * math.cos(th) + 0.85 * math.sin(th))) ** 1.5

    def ring_at(r_fn, z_fn, inset=0.0):
        out = []
        for th in ths:
            r = r_fn(th)
            x = r * math.cos(th)
            x = max(x, c["INNER_X"] - 1.5 + inset)   # the body side: flat on the arm's inner face
            out.append(bm.verts.new((cx + side * x, r * math.sin(th), z_fn(th))))
        return out

    def outer(k):
        return lambda th: superellipse(c["A_TOP"], c["N"], th) + c["FLARE"] * k ** 1.6 * flare(th)
    rings, vs = [], []
    for i in range(c["RINGS"] + 1):
        k = i / c["RINGS"]
        rings.append(ring_at(outer(k), lambda th, k=k: c["TOP"] + (bottom(th) - c["TOP"]) * k))
        vs.append(0.05 + 0.15 * k)
    inner = (lambda th: superellipse(c["A_IN"], c["N"], th))
    rings.append(ring_at(lambda th: (outer(1.0)(th) + inner(th)) / 2 + 0.03, lambda th: bottom(th) - 0.04, 0.005))
    vs.append(0.22)
    for k in (1.0, 0.5, 0.0):
        rings.append(ring_at(inner, lambda th, k=k: c["TOP"] + (bottom(th) - c["TOP"]) * k, 0.01))
        vs.append(0.1)
    rings.append(ring_at(lambda th: (inner(th) + superellipse(c["A_TOP"], c["N"], th)) / 2,
                         lambda th: c["TOP"] + 0.03, 0.005))
    vs.append(0.05)
    for r, v in zip(rings, vs):
        vals += [v] * len(r)
    rings.append(rings[0])
    rp.loft(bm, rings, cap_start=False, cap_end=False)


def build_wisp(name, root_col):
    q = WISPS[name]
    side = q["side"]
    col = collection(name, root_col)
    arm = new_armature(name + "_Rig", col)
    eb = arm.data.edit_bones
    root = eb.new("Root")
    att = q["attach"]
    root.head, root.tail = att, att + Vector((0, ROOT_BONE_LEN, 0))
    root.use_deform = False
    base = eb.new("WispBase")
    base.head, base.tail = att, att + Vector((0, 0, ROOT_BONE_LEN))
    base.parent = root
    paths, jts = {}, {}
    for tag, r0 in q["ribbons"].items():
        r = mirror_r(r0, side)
        path = Path(r["PATH"], r["N0"])
        paths[tag] = (r, path)
        if r.get("CLOSED"):   # a hoop: a chain from each root up to the top
            halves = (("L", 0.0, 0.5), ("R", 1.0, 0.5))
        else:
            halves = (("", None, None),)
        for suffix, s_a, s_b in halves:
            if s_a is None:
                joints = chain_joints(r, path)
            else:
                joints = [s_a + (s_b - s_a) * (r["S_OUT"] * 2 + (0.97 - r["S_OUT"] * 2) * k / r["BONES"])
                          for k in range(r["BONES"] + 1)]
            prev = base
            for k in range(r["BONES"]):
                b = eb.new("Wisp%s%s%d" % (tag, suffix, k + 1))
                ph, th_, nh, bh = frame(path, r, joints[k])
                b.head, b.tail = ph, frame(path, r, joints[k + 1])[0]
                b.align_roll(bh)   # local Z = the ribbon's face normal: X bends across the face
                b.parent = prev
                b.use_connect = prev is not base
                prev = b
            jts[tag + suffix] = joints
    bpy.ops.object.mode_set(mode="OBJECT")

    objs = []
    # Wisp region: every ribbon in one mesh (one colour), weights per ribbon chain
    bm, vals, weights, vv = bmesh.new(), [], [], []
    for tag, r0 in q["ribbons"].items():
        r, path = paths[tag]
        n0 = len(vals)
        build_ribbon(bm, vals, r, path)
        # V for the fade: 0 at the root, 1 at the tip (a hoop fades halfway towards its top)
        vv += [min(s, 1 - s) if r.get("CLOSED") else s for s in vals[n0:]]
        for s in vals[n0:]:
            if r.get("CLOSED"):
                kL = 1 - smoothstep(0.45, 0.55, s)
                wl = chain_weights(tag + "L", s, jts[tag + "L"], r["BONES"])
                wr = chain_weights(tag + "R", 1 - s, [1 - j for j in jts[tag + "R"]], r["BONES"])
                ws = {}
                for nm, w in wl:
                    ws[nm] = ws.get(nm, 0) + w * kL
                for nm, w in wr:
                    ws[nm] = ws.get(nm, 0) + w * (1 - kL)
                weights.append(list(ws.items()))
            else:
                weights.append(chain_weights(tag, s, jts[tag], r["BONES"]))
    o = new_object(name + "_Wisp", bm, "Wisp", col, vv, WISP_SHARP_DEG)
    skin(o, arm, weights)
    objs.append(o)
    if q["kind"] in ("sleeve", "train"):
        bm, vals = bmesh.new(), []
        if q["kind"] == "sleeve":
            build_cuff(bm, vals, side)
        else:
            build_ribbon(bm, vals, SASH, Path(SASH["PATH"], SASH["N0"]))
            vals = [0.1] * len(vals)
        o = new_object(name + "_Spirit", bm, "Spirit", col, vals, 40.0)
        skin(o, arm, [[("WispBase", 1.0)]] * len(vals))
        objs.append(o)
    return arm, objs


# ------------------------------------------------------------------------- checks / ratios ----
LIMBS = {   # name: (x0, x1, pivot z, local z0, local z1); legs swing about z 0, arms about z 1.5
    "LeftLeg": (0.0, 1.0, 0.0, -2.0, 0.0), "RightLeg": (-1.0, 0.0, 0.0, -2.0, 0.0),
    "LeftArm": (1.0, 2.0, 1.5, -2.0, 0.0), "RightArm": (-2.0, -1.0, 1.5, -2.0, 0.0)}
LIMB_SIGN = {"LeftLeg": -1, "RightLeg": 1, "LeftArm": 1, "RightArm": -1}   # x the run phase angle


def rot_x(deg, pivot_z):
    return (Matrix.Translation((0, 0, pivot_z)) @ Matrix.Rotation(math.radians(deg), 4, "X")
            @ Matrix.Translation((0, 0, -pivot_z)))


def in_box(v, x0, x1, y0, y1, z0, z1):
    if x0 <= v.x <= x1 and y0 <= v.y <= y1 and z0 <= v.z <= z1:
        return min(v.x - x0, x1 - v.x, v.y - y0, y1 - v.y, v.z - z0, z1 - v.z)
    return None


def clearance(name, objs):
    """Vertices inside a limb (or, for sleeves, the torso) anywhere in the R6 run swing
    (+-RUN_DEG, 17 phases). A sleeve rides on its own arm. Buried roots (inside the torso, or the
    sleeve's own arm) don't count. Returns {limb: [verts inside, deepest]}."""
    q = WISPS[name]
    own = {"GhostSleeveL": "LeftArm", "GhostSleeveR": "RightArm"}.get(name)
    vs = [v.co.copy() for o in objs for v in o.data.vertices]
    out = {}
    for k in range(17):
        ph = RUN_DEG * (k / 8 - 1)
        if own:
            m = rot_x(ph * LIMB_SIGN[own], 1.5)
            pts = [m @ v for v in vs]
        else:
            pts = [v for v in vs if in_box(v, -1, 1, -0.5, 0.5, 0, 2) is None]
        for limb, (x0, x1, pz, z0, z1) in LIMBS.items():
            if limb == own:
                continue
            inv = rot_x(ph * LIMB_SIGN[limb], pz).inverted()
            for i, v in enumerate(pts):
                d = in_box(inv @ v, x0, x1, -0.5, 0.5, pz + z0, pz + z1)
                if d is not None:
                    e = out.setdefault(limb, [set(), 0.0])
                    e[0].add(i)
                    e[1] = max(e[1], d)
        if own:
            for i, v in enumerate(pts):
                d = in_box(v, -1, 1, -0.5, 0.5, 0, 2)
                if d is not None:
                    e = out.setdefault("Torso", [set(), 0.0])
                    e[0].add(i)
                    e[1] = max(e[1], d)
            low = min(v.z for v in pts)
            if low < -2.0:
                out.setdefault("Floor", [set(), 0.0])[1] = max(out.get("Floor", [0, 0])[1], -2.0 - low)
    return {k: [len(v[0]) if isinstance(v[0], set) else 0, round(v[1], 3)] for k, v in out.items()}


def bbox(objs):
    vs = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    return (Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)]))


def ribbon_len(r):
    path = Path(mirror_r(r, 1)["PATH"])
    return path.length * (1 - r["S_OUT"])


def proportions(name, objs):
    hl, hh = head_bbox()
    head_w, head_h = hh.x - hl.x, hh.z - hl.z
    if name in TALISMANS:
        lo, hi = bbox([o for o in objs if o.name.endswith("_Paper")])
        p = TALISMANS[name]
        return dict(height=round(p["H"], 2), width=round(p["W"], 2), head_size=[round(head_w, 2), round(head_h, 2)],
                    height_to_head=round(p["H"] / head_h, 2), width_to_head=round(p["W"] / head_w, 2),
                    note="size against the R6 head (1.20 wide, 1.02 tall)")
    q = WISPS[name]
    if q["kind"] == "sleeve":
        c = CUFF
        cuff_h = c["TOP"] - (c["BOTTOM"] - c["DROOP"])
        rA = ribbon_len(SLEEVE_RIBBONS["A"])
        return dict(arm_size=[1.0, 2.0], cuff_height=round(cuff_h, 2), cuff_height_to_arm=round(cuff_h / 2.0, 2),
                    cuff_opening=round(2 * c["A_TOP"] + c["FLARE"], 2),
                    cuff_opening_to_arm_width=round(2 * c["A_TOP"] + c["FLARE"], 2),
                    ribbon_length=round(rA, 2), ribbon_to_arm_length=round(rA / 2.0, 2),
                    ribbon_width_to_arm_width=round(2 * SLEEVE_RIBBONS["A"]["W"], 2))
    if q["kind"] == "train":
        t, sd = TRAIN_RIBBONS["Tail"], TRAIN_RIBBONS["L"]
        lo, hi = bbox(objs)
        return dict(torso_width=2.0, leg_height=2.0, tail_length=round(ribbon_len(t), 2),
                    tail_to_leg_height=round(ribbon_len(t) / 2.0, 2), tail_width_to_torso=round(2 * t["W"] / 2.0, 2),
                    side_length_to_leg=round(ribbon_len(sd) / 2.0, 2), span_to_torso_width=round((hi.x - lo.x) / 2.0, 2),
                    sash_width_to_torso=round(1.92 / 2.0, 2))
    lo, hi = bbox(objs)
    hoop = max(z for (_, _, z) in STOLE_RIBBONS["Hoop"]["PATH"]) + STOLE_RIBBONS["Hoop"]["W"]
    tr = ribbon_len(STOLE_RIBBONS["TrailL"])
    return dict(torso_size=[2.0, 2.0], hoop_above_shoulders=round(hoop - 2.0, 2),
                hoop_above_shoulders_to_torso=round((hoop - 2.0) / 2.0, 2),
                hoop_above_head_top=round(hoop - hh.z, 2),
                span=round(hi.x - lo.x, 2), span_to_torso_width=round((hi.x - lo.x) / 2.0, 2),
                trail_length=round(tr, 2), trail_to_torso_height=round(tr / 2.0, 2))


# ----------------------------------------------------------------------------------- export ---
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
            meshes[o.name] = dict(region=o["region"], tris=tri_count(o), center=r3((mn + mx) / 2), size=r3(mx - mn))
        bones = {b.name: dict(parent=b.parent.name if b.parent else None, head=r3(b.head_local),
                              tail=r3(b.tail_local), roblox_head=r3((-b.head_local.x, b.head_local.z, b.head_local.y)),
                              deform=b.use_deform) for b in arm.data.bones}
        report = dict(
            name=name, attachment=attach_name, attachment_avatar_space=r3(attach),
            units="1 Blender unit = 1 stud; positions relative to the attachment (Blender X avatar left, "
                  "-Y avatar front, Z up)",
            roblox_mapping="a Blender point (x, y, z) is (-x, z, y) in the attachment's Roblox frame; "
                           "mesh Size = (bx, bz, by), CFrame = CFrame.new(-cx, cz, cy)",
            colors={k: r3(v[:3]) for k, v in COLORS.items()},
            shade=dict(paper=dict(file=SHADE_FILE, darkest=SHADE_MIN, fade_to_white_at_v=SHADE_REACH),
                       wisp=dict(file=FADE_FILE, value=FADE_VAL, alpha=FADE_ALPHA, fade_start=FADE_START),
                       uv="V only (U = 0.5)"),
            meshes=meshes, tris_total=sum(m["tris"] for m in meshes.values()), bones=bones)
        report.update(extra)
        with open(os.path.join(HERE, name + ".json"), "w") as fh:
            json.dump(report, fh, indent=1)
    finally:
        shift_set(arm, objs, attach)
    return report


# ----------------------------------------------------------------------------------- sheet ----
# (view, eye direction, target, ortho scale or None, lens)
VIEWS = [("front", (0, -1, 0.08), (0, 0.6, 0.8), 7.6, 50),
         ("side", (1, 0, 0.08), (0, 1.0, 0.8), 7.6, 50),
         ("back", (0, 1, 0.12), (0, 0.6, 0.8), 7.6, 50),
         ("threequarter", (0.8, 0.85, 0.35), (0, 1.0, 0.8), 7.8, 50)]
SLEEVE_PIVOTS = {"GhostSleeveL": ("LeftArm", 1.5), "GhostSleeveR": ("RightArm", 1.5)}


def run_pose(phase, wisp_names):
    """The R6 run pose (limbs RUN_DEG about hip and shoulder; phase +1 / -1 / 0 rest); sleeves ride
    their arm."""
    arm = rp.armature()
    for bname, pz, limb in (("Left Leg", 0.0, "LeftLeg"), ("Right Leg", 0.0, "RightLeg"),
                            ("Left Arm", 1.5, "LeftArm"), ("Right Arm", 1.5, "RightArm")):
        pb = arm.pose.bones[bname]
        pb.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
        if phase:
            pb.matrix = rot_x(RUN_DEG * LIMB_SIGN[limb] * phase, pz) @ pb.bone.matrix_local
    for n in wisp_names:
        rig = bpy.data.objects[n + "_Rig"]
        rig.matrix_world = (rot_x(RUN_DEG * LIMB_SIGN[SLEEVE_PIVOTS[n][0]] * phase, 1.5)
                            if n in SLEEVE_PIVOTS and phase else Matrix.Identity(4))
    bpy.context.view_layer.update()


def set_alpha(on):
    global PREVIEW_ALPHA
    PREVIEW_ALPHA = on
    for region in ("Spirit", "Wisp"):
        material(region)


def render_tiles(scene, root_col, out_dir, res=400):
    rp.setup_render(scene, res=(res, res))
    layer = scene.view_layers[0].layer_collection.children[root_col.name]
    shots = []
    for label, tal, wisps in DIRECTIONS:
        names = {tal, *wisps}
        for c in layer.children:
            c.exclude = c.name not in names
        rigs = [bpy.data.objects[n + "_Rig"] for n in names]

        def shot(view, eye, tgt, ortho=None, lens=50):
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (label, view)), tuple(eye),
                                   tuple(tgt), ortho=ortho, lens=lens))
        for view, d, tgt, ortho, lens in VIEWS:
            shot(view, Vector(tgt) + Vector(d).normalized() * 20, tgt, ortho, lens)
        for r in rigs:
            pose(r, bend=BEND_DEG, flutter=FLUTTER_DEG)
        tgt = Vector((0, 1.0, 0.8))
        shot("bent", tgt + Vector((1, 0.6, 0.25)).normalized() * 20, tgt, 7.8)
        for r in rigs:
            pose(r)
        run_pose(1, wisps)
        tgt = Vector((0, 0.8, 0.5))
        shot("run", tgt + Vector((1, 0.05, 0.1)).normalized() * 20, tgt, 7.8)
        run_pose(0, wisps)
        # talisman close-ups: front, and from the side just above eye height (the seat)
        tgt = Vector((TALISMANS[tal]["CX"], -0.6, 2.72))
        shot("tal_front", tgt + Vector((0.15, -1, 0.05)).normalized() * 2.4, tgt)
        shot("tal_seat", tgt + Vector((1, -0.25, 0.12)).normalized() * 1.6, tgt)
        tal_rig = bpy.data.objects[tal + "_Rig"]
        pose(tal_rig, flutter=FLUTTER_DEG)
        shot("tal_flutter", tgt + Vector((1, -0.6, 0.1)).normalized() * 2.0, tgt)
        pose(tal_rig)
        # game camera: 12 studs, behind and above (the read players get)
        tgt = Vector((0, 0.5, 1.2))
        shot("game", tgt + Vector((0.45, 1, 0.4)).normalized() * 12.0, tgt, None, 65)
        shot("game_front", tgt + Vector((0.4, -1, 0.3)).normalized() * 12.0, tgt, None, 65)
        set_alpha(False)
        tgt = Vector((0, 0.8, 0.6))
        shot("solid", tgt + Vector((-0.8, 0.9, 0.3)).normalized() * 20, tgt, 7.8)
        set_alpha(True)
    for c in layer.children:
        c.exclude = False
    return shots


# ------------------------------------------------------------------------------------ main ----
def main():
    scene = bpy.data.scenes.get(SCENE) or rp.use_scene(SCENE)
    bpy.context.window.scene = scene
    rp.import_rig(scene)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    root_col = bpy.data.collections.get(ROOT_COLLECTION) or bpy.data.collections.new(ROOT_COLLECTION)
    if root_col.name not in scene.collection.children:
        scene.collection.children.link(root_col)
    for c in list(root_col.children):   # drop collections of retired builds
        if c.name not in set(TALISMANS) | set(WISPS):
            for o in list(c.objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.collections.remove(c)
    ramp_image(SHADE_FILE, shade_fn, False)
    ramp_image(FADE_FILE, fade_fn, True)
    built, report = {}, {}
    for name in TALISMANS:
        if ONLY and name not in ONLY:
            continue
        arm, objs = build_talisman(name, root_col)
        built[name] = (arm, objs, FACE_FRONT, "FaceFrontAttachment", dict(proportions=proportions(name, objs)))
    for name, q in WISPS.items():
        if ONLY and name not in ONLY:
            continue
        arm, objs = build_wisp(name, root_col)
        built[name] = (arm, objs, q["attach"], q["attach_name"],
                       dict(proportions=proportions(name, objs),
                            run_clearance=dict(swing_deg=RUN_DEG, inside=clearance(name, objs))))
    for name, (arm, objs, attach, att_name, extra) in built.items():
        report[name] = dict({o.name: tri_count(o) for o in objs}, **extra)
        if EXPORT:
            export_set(name, arm, objs, attach, att_name, extra)
    print(json.dumps(report, indent=1))
    os.makedirs(os.path.join(HERE, "renders"), exist_ok=True)
    with open(os.path.join(HERE, "renders", "report.json"), "w") as fh:
        json.dump(report, fh, indent=1)
    if RENDER:
        top = scene.view_layers[0].layer_collection.children
        others = {c.name: c.exclude for c in top if c.name not in (ROOT_COLLECTION, rp.RIG_COLLECTION)}
        for n in others:
            top[n].exclude = True
        top[ROOT_COLLECTION].exclude = False
        print(len(render_tiles(scene, root_col, os.path.join(HERE, "renders"))), "tiles")
        for n, ex in others.items():
            top[n].exclude = ex
    if SAVE_BLEND:
        rp.save_blend(scene, os.path.join(HERE, "Ghost.blend"))


main()
