r"""Beast Folk (Wolf) cosmetics: three tail variants and three ear variants for the player's R6 avatar.

Intent: a wild but disciplined martial hunter. The ears are the hero up top: upright and alert,
a little taller and sharper than the fox's but still chunky cups with depth (never thin spikes),
charcoal rims framing soft cream fur. The tail is the hero from behind: a heavy bushy brush that
hangs back and down to about knee height (no curl), grading from big clumps at the root to a pale
feathered end, angled back far enough to clear the legs' running swing.

  Tails (WaistBackAttachment): WolfTailBrush, WolfTailMane, WolfTailBanner
  Ears  (HatAttachment):       WolfEarsSentinel, WolfEarsRuff, WolfEarsLance
Each set is its own FBX + JSON beside this script, with its own armature. See README.md. Built
from the approved fox set's builder (cosmetics/fox/build_fox.py): same rig, regions, sealed fur,
seating and checks.

Run through the Blender MCP (Blender runs on Windows, so paths come from __file__):
    P = r"\\wsl.localhost\Ubuntu\home\cj\roblox\martial-world-race-cosmetics\art\player\cosmetics\wolf\build_wolf.py"
    exec(compile(open(P).read(), P, "exec"), {"__file__": P})
Optional globals: RENDER (default True: sheet tiles into renders/), EXPORT (default True: FBX,
JSON, shade PNG, .blend), ONLY (a set of set names: rebuild and export just those). Then run
lineup.py (the side-by-side lineup and its renders) and stitch the sheets with make_sheet.py.

Axes and units (the R6 reference, art/rig/r6_rigged.fbx, see art/rig/rig_preview.py):
  1 Blender unit = 1 stud. +X = the avatar's left (its left arm), it faces -Y, Z up.
  Hips z 0, torso z 0..2, head top z 3.1, feet z -2.
  Head HatAttachment        = (0, 0, 3.1)  (Head centre + Roblox (0, 0.6, 0))
  Torso WaistBackAttachment = (0, 0.5, 0)  (Torso centre + Roblox (0, -1, 0.5): bottom, back face)
Built in avatar space with identity object transforms; the export moves each set so its
attachment is the origin (FBX and JSON are in attachment space). Roblox: a Blender point
(x, y, z) is (-x, z, y) from the attachment, no extra rotation.

Recolour contract: each colour region is its own mesh object (one Roblox MeshPart, one Color)
with its own material, prefixed Wolf_ so another race's rebuild can't recolour it: FurOuter
(<Ears>_LeftEar, _RightEar, <Tail>_Tail), FurInner (<Ears>_LeftEarInner, _RightEarInner),
FurTip (<Tail>_TailTip). Depth shading is the shared greyscale ramp (built with the fox's
settings, so wolf_shade.png matches fox_shade.png byte for byte) on UV V: tail base, ear tips
and the ears' front rims get darker, so tinting by Color still works.

Rig (one armature per set, bones named like Roblox Motor6Ds; Root = the attachment point):
  Ears: Root -> EarLBase -> EarL, Root -> EarRBase -> EarR   (Base is planted; key EarL/EarR)
  Tail: Root -> TailBase -> Tail1 -> ... -> Tail5           (Tail1's head = where it leaves the body)
Bone rolls: tail bones' local Z is the side normal of the tail's parallel-transport frame (world
+X at the root), ears' local Z is world +X, so local X bends/folds every joint the same way.
Weights blend smoothly across each joint; ears blend from Base into the ear over its lowest third.

Fur: a full smooth core plus overlapping fur clumps. Each clump is a closed wedge whose
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
SAVE_BLEND = globals().get("SAVE_BLEND", True)   # with EXPORT: write Wolf.blend
ONLY = globals().get("ONLY")           # optional set of set names to (re)build; others stay as they are

SCENE = "Cosmetics"
ROOT_COLLECTION = "WolfCosmetics"
HIDE_COLLECTIONS = ("FoxCosmetics",)
MAT_PREFIX = "Wolf_"                    # materials are per race: the fox rebuild once recoloured a shared FurOuter
HAT = Vector((0.0, 0.0, 3.1))          # Head HatAttachment, rest pose
WAIST_BACK = Vector((0.0, 0.5, 0.0))   # Torso WaistBackAttachment, rest pose
EAR_SHARP_DEG = 28.0                   # ears: edges sharper than this shade hard (house crease)
FUR_SHARP_DEG = 135.0                  # inner fur cushion and tufts: smooth all over (harder reads as crumpled stone)
TAIL_SHARP_DEG = 70.0                  # tail: soft fur, only the clumps' side ridges stay crisp

# Colours (linear). Plain SmoothPlastic in Roblox; MeshPart.Color carries these per region.
COLORS = {
    "FurOuter": (0.20, 0.205, 0.22, 1),   # mid charcoal grey, a hint cool (rims and tips shade darker)
    "FurInner": (0.80, 0.74, 0.62, 1),    # muted cream
    "FurTip":   (0.88, 0.87, 0.84, 1),    # near-white, a touch warm
}
SHADE_FILE = "wolf_shade.png"  # greyscale ramp on UV V: V 0 = darkest, V >= SHADE_REACH = white
SHADE_MIN = 0.55               # darkest value (tail root, ear tip, ear rim); the fox's settings, so the
                               # ramp is byte-identical to fox_shade.png and the uploaded one is shared
SHADE_REACH = 0.45             # V where the darkening has faded out

# ----------------------------------------------------------------------------------------------
# Ears: three wolf sets with clearly different silhouettes, all chunky cups sized to the R6 head
# (1.20 wide, 1.02 tall). The approved cute fox ears are about 64% of head height with a base about
# 40% of its width; a wolf ear is a touch taller and sharper (brief) but never tall, thin or spiky
# (user: "now we're going too long", "not cute it just looks creepy"). Heights are what shows above
# the head. X base centre |x| on the head top, H ear length (part of it is sunk), W base
# half-width, T thickness, CUP front hollow depth, BELLY widens the mid ear, SIDE_EXP < 1 rounds
# the sides out (soft), > 1 pinches them concave toward the tip (sharp), CURL tip offset backwards
# (+Y), TILT outward roll, YAW turn of the opening outward, LEAN backward lean (degrees),
# EDGE_TUFTS serrations on the rims near the base, NOTCH (t, depth) a V nick in the outer rim or
# None, TIP_DARK how far down the shade ramp darkens the tip (1 = top 45%, 1.6 = top 70%).
# PEAK "point" | "round", FOLD (t, degrees, "out" | "forward") or None. RIM_DARK 0..1 how dark the
# shell's front rim around the cream is (the reference's charcoal rims; 1 = the ramp's darkest).
# TUFTS: the cream fur in the cup, a few soft chunky fur tufts of mixed sizes, each coming to a
# slight point: (t, u root on the front surface, up, out, forward axis parts, length as a fraction
# of H, belly radius, curl). curl 0..1 bends the tuft's end over and down toward where it points.
CUTE_TUFTS = [(0.05, 0.0, 1.0, 0.0, 0.80, 0.44, 0.125, 0.70),    # big centre tuft, curls over the front rim
              (0.08, 0.95, 1.0, 0.45, 0.50, 0.34, 0.11, 0.50),   # outer rim, curls over it
              (0.10, -0.95, 1.0, 0.50, 0.55, 0.30, 0.10, 0.50),  # inner rim, smaller
              (0.18, 0.10, 1.0, 0.05, 0.30, 0.46, 0.11, 0.25),   # a long flame up the cup
              (0.30, -0.75, 1.0, 0.25, 0.30, 0.32, 0.085, 0.30)] # a shorter one along the inner rim
# the ruff's cream spills further out of the base, wilder
# the wolf's: the fox's tuft layout, shorter, a touch fatter and curling less, so the cream stays
# inside the grey cup as soft clumps instead of spilling out over the rim like shards
WOLF_TUFTS = [(t, u, up, out * 0.6, fwd * 0.7, ln * 0.78, rad * 1.12, curl * 0.45)
              for (t, u, up, out, fwd, ln, rad, curl) in CUTE_TUFTS]
RUFF_TUFTS = WOLF_TUFTS
EARS = {
    # A, cool and alert: an upright, clean triangle with a firm point and charcoal rims; the
    # reference's wolf ear, kept chunky
    "WolfEarsSentinel": dict(label="Sentinel", mood="cool, alert", PEAK="point", FOLD=None, X=0.31, H=0.78,
                             W=0.23, T=0.28, CUP=0.15, BELLY=0.45, SIDE_EXP=0.95, CURL=0.02, TILT=9, YAW=12,
                             LEAN=4, EDGE_TUFTS=0, TUFTS=WOLF_TUFTS, NOTCH=None, TIP_DARK=1.3, RIM_DARK=1.0),
    # B, tuff: shorter, broader and splayed out to the sides like a guard dog's, a battle notch in
    # the outer rim and fur serrations on both rims near the base
    "WolfEarsRuff": dict(label="Ruff", mood="tuff, scrappy", PEAK="point", FOLD=None, X=0.33, H=0.80,
                         W=0.24, T=0.30, CUP=0.15, BELLY=0.55, SIDE_EXP=0.9, CURL=0.0, TILT=30, YAW=22,
                         LEAN=0, EDGE_TUFTS=2, TUFTS=RUFF_TUFTS, NOTCH=(0.50, 0.26), TIP_DARK=1.5, RIM_DARK=1.0),
    # C, sleek: laid well back along the head like a wolf on the run, the tip sweeping back; from
    # the front it reads low and wide, from the side a streamlined swept shape
    "WolfEarsLance": dict(label="Lance", mood="sleek, focused", PEAK="point", FOLD=None, X=0.30, H=0.98,
                          W=0.22, T=0.27, CUP=0.14, BELLY=0.40, SIDE_EXP=1.05, CURL=0.34, TILT=16, YAW=8,
                          LEAN=40, EDGE_TUFTS=0, TUFTS=WOLF_TUFTS, NOTCH=None, TIP_DARK=1.2, RIM_DARK=0.85),
}

# Tails. Intent: a heavy, bushy wolf brush that hangs (no curl, no ball), the reference's long
# grey tail with a pale feathered end. It leaves the lower back a little above the waist, carries
# back and arcs down to about knee height (z -1). The arc is what clears the running legs: an R6
# leg swung back 1 radian sweeps up to its back face's line (0.54 y + 0.84 z = 0.5 from the hip)
# and reaches about 2.06 studs from the hip, so the upper tail stays above that line and the
# hanging end stays outside that reach (run_clearance in the JSON measures it). Three silhouettes: Brush the
# reference (full, even taper), Mane a broader, flatter, shaggier brush with flared clumps, Banner
# a slimmer, straighter hang with the longest pale end.
# PATH control points (avatar space; the root sits inside the torso). R core max radius, PROFILE
# core radius along the length (s 0..1, x R), CAP the end's length as a fraction of the end
# radius (> 1 a soft long point), FLAT depth/width of the section, TIP_S where the pale TailTip
# starts, BEND the sheet's deformation check per Tail joint: (local axis, degrees); Z = about the
# side axis (lift/tuck), X = sideways sway.
# CLUMPS: ROWS x PER_ROW staggered from S0 to S1 (s), each LEN long (s), WIDTH and THICK as
# fractions of the local core radius, FLARE how far past the core the clump end stands, SWIRL its
# turn around the tail (radians), BULGE its mid arch, ROUND the end's roundness (4 = a soft round
# lobe, 1.5 = a soft point).
BANNER = [(0, 0.40), (0.15, 0.58), (0.40, 0.80), (0.62, 1.0), (0.80, 0.94), (0.92, 0.66), (1, 0.40)]
#        slim at the root, filling out lower down into a full flag-like end
WOLF = [(0, 0.45), (0.12, 0.78), (0.35, 1.0), (0.55, 0.97), (0.75, 0.78), (0.90, 0.52), (1, 0.34)]
#       full brush, widest at a third to a half, tapering into a soft long point (the CAP)
CLUMP_GRADE = (1.40, 0.55)   # clump length scale at the root and at the tip (big at the base)
CLUMP_VARY = 0.30            # +- clump length variation (fixed pseudo-random): no even pinecone rows
TIP_CLUMP_AT = 0.45          # a clump is tip-coloured when this fraction of it is past TIP_S

TAILS = {
    # A: the reference, a full grey brush slanting back and down, pale point at knee height
    "WolfTailBrush": dict(
        label="Brush", mood="cool", shape="full brush hanging back and down to the knees",
        PATH=[(0, 0.15, 0.72), (0, 0.85, 0.88), (0, 1.65, 0.78), (0, 2.38, 0.30), (0, 2.75, -0.45),
              (0, 2.82, -1.30)],
        R=0.48, PROFILE=WOLF, CAP=1.8, FLAT=0.86, TIP_S=0.72, BEND=("X", -16),
        CLUMPS=dict(ROWS=6, PER_ROW=5, S0=0.12, S1=0.88, LEN=0.28, WIDTH=1.45, THICK=0.50,
                    FLARE=0.45, SWIRL=0.25, BULGE=0.08, ROUND=1.7)),
    # B: broader and flatter (a wide fan seen from behind), shaggy flared clumps, a bit shorter
    "WolfTailMane": dict(
        label="Mane", mood="tuff", shape="broad shaggy brush, flared clumps",
        PATH=[(0, 0.15, 0.75), (0, 0.90, 0.92), (0, 1.75, 0.82), (0, 2.50, 0.32), (0, 2.92, -0.40),
              (0, 3.00, -1.10)],
        R=0.54, PROFILE=WOLF, CAP=1.5, FLAT=0.70, TIP_S=0.74, BEND=("X", -16),
        CLUMPS=dict(ROWS=6, PER_ROW=5, S0=0.12, S1=0.86, LEN=0.30, WIDTH=1.30, THICK=0.50,
                    FLARE=0.70, SWIRL=0.15, BULGE=0.10, ROUND=1.4)),
    # C: slimmer and straighter, the steepest hang, the longest pale end
    "WolfTailBanner": dict(
        label="Banner", mood="sleek", shape="slim root filling out into a long, full pale end",
        PATH=[(0, 0.15, 0.72), (0, 0.85, 0.88), (0, 1.62, 0.78), (0, 2.35, 0.30), (0, 2.78, -0.45),
              (0, 2.86, -1.40)],
        R=0.48, PROFILE=BANNER, CAP=2.2, FLAT=0.92, TIP_S=0.62, BEND=("X", -16),
        CLUMPS=dict(ROWS=7, PER_ROW=4, S0=0.12, S1=0.88, LEN=0.26, WIDTH=1.55, THICK=0.45,
                    FLARE=0.32, SWIRL=0.10, BULGE=0.06, ROUND=2.0)),
}

# Sheet rows: the three looks (any ears go with any tail in game).
PAIRS = [("WolfTailBrush", "WolfEarsSentinel"), ("WolfTailMane", "WolfEarsRuff"),
         ("WolfTailBanner", "WolfEarsLance")]

EAR_Y = 0.06          # a touch behind the head centre
EAR_SINK = 0.10       # the whole base rim sits this far under the head surface, along its normal (no gap anywhere)
EAR_EDGE_MARGIN = 0.95  # a foot past the head's outline is pulled in to this fraction of the way to the edge
EAR_CONFORM_T = 0.30  # the base follows the head's curve, fading out by this height fraction
HEAD_MIN_Z = 2.6      # a downward ray landing below this missed the head (the ear overhangs it)
EAR_ROWS = 10         # rings from base to tip
EAR_COLS = 7          # points across the front (and back) of each ring, plus a rounded rim point each side
INNER_SPAN = 0.56     # the cream cushion's share of the ear's width (fox 0.66): a wider charcoal rim shows
EAR_RIM = 0.6         # rim depth as a fraction of the ear's thickness T (the shell never thins to a card)
TUFT_SIDES = 8        # inner fur tufts: ring vertices
TUFT_PROFILE = [(0.0, 0.0), (0.10, 0.72), (0.30, 1.0), (0.52, 0.86), (0.72, 0.55), (0.88, 0.24), (1.0, 0.0)]   # (along, radius): fat belly, tapering to a slight point
EAR_BEND = (0.04, 0.32)   # ear height fraction where the weight goes from Base to the ear bone
CORE_SIDES = 12       # core ring vertices (mostly covered by clumps)
CORE_STATIONS = 32    # core rings along the tail
TAIL_BONES = 5
JOINT_BLEND = 0.45    # weight blend half-width around each tail joint, in bone lengths
CLUMP_ROOT = 0.80     # clump underside sits at this fraction of the core radius (inside the core)
CLUMP_RINGS = (0.0, 0.22, 0.44, 0.64, 0.80, 0.92)   # stations along each clump before its end (one fewer than the fox: budget)
CAP_RINGS = 4         # rings in the core's round end
# Running check (R6 Animate run: limbs swing 1 radian each way about the hip and shoulder)
RUN_DEG = 57.3
BODY_BACK_Y = 0.55    # the tail's own root is inside the body up to here; the check starts past it
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
    m = rp.preview_material(MAT_PREFIX + name, COLORS[name])
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


def add_tuft(bm, tv, p, root, axis, length, radius, curl=0.0, flat=0.6):
    """A soft, chunky fur tuft: a closed teardrop from `root` (buried in the cushion) along `axis`,
    round-bellied, tapering to a slight point. curl bends its end over and down toward where it
    points (over the rim). flat squashes it front to back."""
    axis = axis.normalized()
    over = Vector((axis.x, axis.y, 0))
    over = (over.normalized() if over.length > 1e-6 else Vector((0, -1, 0))) + Vector((0, 0, -0.7))
    over.normalize()
    rings, c, prev = [], root.copy(), 0.0
    for s_, r_ in TUFT_PROFILE:
        d = axis.slerp(over, min(1.0, curl * s_ ** 1.5))   # bends more toward the end
        c = c + d * (length * (s_ - prev))
        prev = s_
        side = d.cross(Vector((0, 1, 0)))
        side = side.normalized() if side.length > 1e-6 else Vector((1, 0, 0))
        depth = side.cross(d).normalized()
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
    rims = []   # per outer vertex: 0..1 how much it belongs to the front rim around the cream
    us = [-1 + 2 * i / (EAR_COLS - 1) for i in range(EAR_COLS)]
    ts = [1 - (1 - i / EAR_ROWS) ** 1.4 for i in range(EAR_ROWS)]   # rings closer near the tip
    rings = []
    for t in ts:
        r = ([bm.verts.new(ear_front(p, t, u)) for u in us] + [bm.verts.new(ear_rim(p, t, 1))]
             + [bm.verts.new(ear_back(p, t, u)) for u in reversed(us)] + [bm.verts.new(ear_rim(p, t, -1))])
        tvals += [t] * len(r)
        rims += [smoothstep(0.45, 0.95, abs(u)) for u in us] + [1.0] + [0.0] * len(us) + [1.0]
        rings.append(r)
    tip = bm.verts.new(ear_front(p, 1.0, 0) + Vector((0, p["T"] * 0.1, 0)))
    tvals.append(1.0)
    rims.append(1.0)
    rp.loft(bm, rings + [[tip]], cap_start=True, cap_end=False)

    # Inner ear: a plump cream cushion filling the cup, plus a few chunky tufts that spill out
    # over the rim at the base.
    ib, itv = bmesh.new(), []
    k, t1 = INNER_SPAN, 0.78
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
    # tuft sizes follow the ear's height up to the approved Broad ear's (0.78), so a taller ear's
    # fold doesn't grow its tufts and a stubbier ear's tufts shrink with it
    h_ref = min(p["H"], 0.78)
    k_rad = h_ref / 0.78
    for (t, u, up, out, fwd, ln, rad, curl) in p["TUFTS"]:
        root = ear_front(p, t * h_ref / p["H"], u * 0.55) + Vector((0, -0.02, 0))
        axis = Vector((out * (1 if u >= 0 else -1), -fwd, up))
        add_tuft(ib, itv, p, root, axis, ln * h_ref, rad * (0.5 + 0.5 * k_rad), curl)
    fold_tip(p, bm)
    fold_tip(p, ib)
    return bm, ib, tvals, itv, rims


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


def head_sink_point(x, y):
    """The point EAR_SINK under the head surface at (x, y), measured along the surface normal
    (straight down onto the rig mesh, then inward). On the head's rounded edge a vertical sink is
    only a sliver deep (0.023 measured there), which showed as a dark gap at the rim."""
    rig = next((o for o in rp.rig_objects() if o.type == "MESH"), None)
    inv = rig.matrix_world.inverted()
    hit, loc, n, _ = rig.ray_cast(inv @ Vector((x, y, 6.0)), (inv.to_3x3() @ Vector((0, 0, -1))).normalized())
    n = (rig.matrix_world.to_3x3() @ n).normalized()
    if n.z < 0:
        n = -n
    return rig.matrix_world @ loc - n * EAR_SINK


def seat_on_head(bm, tvals, m):
    """Move ear-local verts to avatar space and seat the base on the head's rounded top: each
    vertex's foot (its point on the ear's base plane) is dropped or raised under the head surface
    straight below it (EAR_SINK deep along the surface normal), fully at the base and fading out
    by EAR_CONFORM_T. A foot past the head's outline (the ear's outer back corner over the head's
    rounded corner) is first pulled in toward the ear's centre to just inside the outline, so the
    lower ear never hangs beside the head with air under it (the dark gap the user saw)."""
    centre = m @ Vector((0, 0, 0))
    for v, t in zip(bm.verts, tvals):
        foot = m @ Vector((v.co.x, v.co.y, 0.0))
        pos = m @ v.co
        w = 1 - smoothstep(0.0, EAR_CONFORM_T, t)
        w_in = 1 - smoothstep(EAR_CONFORM_T, 2 * EAR_CONFORM_T, t)   # the pull-in reaches higher
        if w_in > 0:
            # the vertex itself (the ear leans out, so it sits outside its foot) and its foot must
            # both be over the head; pull the pair in toward the ear's centre until they are
            for probe in (pos, foot):
                if head_surface_z(probe.x, probe.y) is not None:
                    continue
                k = 1.0
                while k > 0 and head_surface_z(centre.x + (probe.x - centre.x) * k,
                                               centre.y + (probe.y - centre.y) * k) is None:
                    k -= 0.02
                assert k > 0, "ear base off the head at (%.2f, %.2f)" % (probe.x, probe.y)
                k *= EAR_EDGE_MARGIN
                shift = Vector(((centre.x - probe.x) * (1 - k), (centre.y - probe.y) * (1 - k), 0)) * w_in
                pos += shift
                foot += shift
            if w > 0:
                pos += (head_sink_point(foot.x, foot.y) - foot) * w
        v.co = pos


def surface_width(bm):
    """X extent of where the shell's edges cross the head surface (the visible base width; the
    buried base ring itself is pulled in and down over the head's rounded edge)."""
    rig = next(o for o in rp.rig_objects() if o.type == "MESH")
    inv = rig.matrix_world.inverted()

    def signed(w):
        _, p, n, _ = rig.closest_point_on_mesh(inv @ w)
        return (w - rig.matrix_world @ p).dot((rig.matrix_world.to_3x3() @ n).normalized())
    bm.verts.index_update()
    d = {v.index: signed(v.co) for v in bm.verts}
    xs = []
    for e in bm.edges:
        a, b = e.verts
        if (d[a.index] < 0) != (d[b.index] < 0):
            k = d[a.index] / (d[a.index] - d[b.index])
            xs.append(a.co.x + (b.co.x - a.co.x) * k)
    return max(xs) - min(xs)


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
    outer, inner, tv_o, tv_i, rims = build_ear_local(p)
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
            if shade and tag == "L":   # width across the head where the shell meets its surface
                base_w = surface_width(bm)
            # ear tips and the front rim around the cream darker (V 0 = the ramp's darkest)
            vv = ([min(1.0 - t * p["TIP_DARK"], 1.0 - p["RIM_DARK"] * rim) for t, rim in zip(tv, rims)]
                  if shade else [1.0] * len(tv))
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
        self.src = points
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
    """The smooth core from s_lo to s_hi; at s 1 it closes in a round cap (CAP x the end radius
    long) instead of a point."""
    rings = []
    n_st = max(2, round(CORE_STATIONS * (s_hi - s_lo)))

    def ring_at(p, t, n, r):
        b = t.cross(n)
        return [bm.verts.new(p + (n * math.cos(th) + b * math.sin(th) * q["FLAT"]) * r)
                for th in (2 * math.pi * k / CORE_SIDES for k in range(CORE_SIDES))]
    for i in range(n_st + 1):
        s = s_lo + (s_hi - s_lo) * i / n_st
        p, t, n = path.at(s)
        rings.append(ring_at(p, t, n, core_radius(q, s)))
        sv += [s] * CORE_SIDES
    if s_hi >= 1.0:
        p, t, n = path.at(1.0)
        r = core_radius(q, 1.0)
        for k in range(1, CAP_RINGS):
            phi = math.pi / 2 * k / CAP_RINGS
            rings.append(ring_at(p + t * r * q["CAP"] * math.sin(phi), t, n, r * math.cos(phi)))
            sv += [1.0] * CORE_SIDES
        rings.append([bm.verts.new(p + t * r * q["CAP"])])
        sv.append(1.0)
    rp.loft(bm, rings, cap_start=cap_start, cap_end=len(rings[-1]) > 1)


def add_clump(bm, sv, q, path, c, s_a, length, theta0):
    """One fur clump: a closed lobe from inside the core out past the outline, its end rounded by
    ROUND (a soft round lobe on the cute tails, a soft point on the bold one). Section: five points
    over its outer face, three on its underside buried in the core."""
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
        env = (0.8 + 0.5 * math.sin(math.pi * u * 0.9)) * max(0.0, 1 - u ** c["ROUND"]) ** 0.5
        w = c["WIDTH"] * r_ref * 0.5 * env
        h = c["THICK"] * r_ref * 0.5 * env
        if u >= 1.0:
            rings.append([bm.verts.new(p + e * (d + h * 0.5))])
            sv.append(s)
            continue
        top = p + e * d
        under = p + e * min(d - h * 0.3, r * CLUMP_ROOT)       # buried in the core
        pts = [top + a * (-w), top + a * (-0.7 * w) + e * (0.75 * h), top + e * h,
               top + a * (0.7 * w) + e * (0.75 * h), top + a * w,
               under + a * (0.5 * w), under, under + a * (-0.5 * w)]
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
            theta = 2 * math.pi * (j + 0.5 * (k % 2) + 0.30 * math.sin(k * 3.7 + j * 1.9)) / c["PER_ROW"]
            grade = CLUMP_GRADE[0] + (CLUMP_GRADE[1] - CLUMP_GRADE[0]) * (k / (c["ROWS"] - 1))
            length = c["LEN"] * grade * (1 + CLUMP_VARY * math.sin(k * 2.3 + j * 4.1))
            bm, sv = parts[1] if s_a + length * TIP_CLUMP_AT >= q["TIP_S"] else parts[0]
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
    """Blender (x, y, z) -> Roblox (-x, z, y) from the attachment (docs/character/player-accessories.md)."""
    return [round(-v[0], 3), round(v[2], 3), round(v[1], 3)]


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
            roblox_mapping="a Blender point (x, y, z) is (-x, z, y) in the attachment's Roblox frame; "
                           "mesh Size = (bx, bz, by), CFrame = CFrame.new(-cx, cz, cy) from the attachment, "
                           "no rotation",
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
# (name, eye direction from target, target, ortho scale or None = perspective, distance)
VIEWS = [
    ("front", (0, -1, 0.10), (0, 0.9, 0.7), 7.4, 20),
    ("side", (1, 0, 0.08), (0, 1.4, 0.6), 7.6, 20),
    ("back", (0, 1, 0.12), (0, 0.9, 0.7), 7.4, 20),
    ("threequarter", (0.8, 0.85, 0.38), (0.2, 1.0, 0.8), 7.6, 20),
    ("bent", (0.45, 1, 0.25), (0.3, 1.4, 0.5), 8.0, 20),
]
# running pose, both phases: (name, phase, eye direction); phase +1 swings the left leg forward,
# the right leg back, the left arm back and the right arm forward
RUN_VIEWS = [("run_a", 1, (1, 0.05, 0.10)), ("run_b", -1, (-0.9, 0.7, 0.15))]
RUN_TARGET, RUN_ORTHO = (0, 1.2, 0.4), 7.8
TAIL_GAME = ((0.35, 1, 0.35), (0, 0.8, 0.8))   # game camera: direction, target (12 studs, GAME_LENS)
SEAT_VIEW = ((1.0, 0.1, -0.45), (0, 0.55, 0.5), 4.2)   # where it leaves the back: low, from the side
CLOSE_VIEW = ((0.85, 0.75, 0.35), 4.6)   # close-up of the bent tail: direction, distance


def run_pose(phase):
    """R6 running pose on the reference rig: legs and arms RUN_DEG about the hip and shoulder
    axes (phase +1 / -1 picks which side leads), 0 = rest."""
    arm = rp.armature()
    for name, pivot, sign in (("Left Leg", (0, 0, 0), -1), ("Right Leg", (0, 0, 0), 1),
                              ("Left Arm", (0, 0, 1.5), 1), ("Right Arm", (0, 0, 1.5), -1)):
        pb = arm.pose.bones[name]
        pb.matrix_basis = Matrix.Identity(4)
        if phase:
            pv = Vector(pivot)
            rot = (Matrix.Translation(pv) @ Matrix.Rotation(math.radians(RUN_DEG * sign * phase), 4, "X")
                   @ Matrix.Translation(-pv))
            bpy.context.view_layer.update()
            pb.matrix = rot @ pb.bone.matrix_local
    bpy.context.view_layer.update()


def render_tiles(scene, root_col, out_dir, rows, res=420):
    rp.setup_render(scene, res=(res, res))
    layer = scene.view_layers[0].layer_collection.children[root_col.name]

    def show(names):
        for c in layer.children:
            c.exclude = c.name not in names

    shots = []
    for tail, ears in rows:
        show({tail, ears})
        t_arm = bpy.data.objects[tail + "_Rig"]
        q = TAILS[tail]
        for view, d, tgt, ortho, dist in VIEWS:
            pose(t_arm, q["BEND"] if view == "bent" else ("Z", 0.0))
            eye = Vector(tgt) + Vector(d).normalized() * dist
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (tail, view)), tuple(eye), tgt,
                                   ortho=ortho, lens=50))
        pose(t_arm)
        for view, phase, d in RUN_VIEWS:
            run_pose(phase)
            eye = Vector(RUN_TARGET) + Vector(d).normalized() * 20
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (tail, view)), tuple(eye),
                                   RUN_TARGET, ortho=RUN_ORTHO, lens=50))
        run_pose(0)
        d, tgt = TAIL_GAME
        eye = Vector(tgt) + Vector(d).normalized() * GAME_DIST
        shots.append(rp.render(scene, os.path.join(out_dir, "%s_game.png" % tail), tuple(eye), tgt, lens=GAME_LENS))
        d, tgt, dist = SEAT_VIEW
        eye = Vector(tgt) + Vector(d).normalized() * dist
        shots.append(rp.render(scene, os.path.join(out_dir, "%s_seat.png" % tail), tuple(eye), tgt, lens=35))
        # Close-up in the bent pose, where gaps between clumps would open widest.
        pose(t_arm, q["BEND"])
        ev = bpy.data.objects[tail + "_Tail"].evaluated_get(bpy.context.evaluated_depsgraph_get()).data
        mid = sum((v.co for v in ev.vertices), Vector()) / len(ev.vertices)
        d, dist = CLOSE_VIEW
        eye = mid + Vector(d).normalized() * dist
        shots.append(rp.render(scene, os.path.join(out_dir, "%s_close.png" % tail), tuple(eye), tuple(mid), lens=50))
        pose(t_arm)
    for c in layer.children:
        c.exclude = False
    return shots


def body_bbox(test):
    """Bounding box (min, max) of the R6 reference mesh's vertices that pass `test`."""
    rig = next(o for o in rp.rig_objects() if o.type == "MESH")
    vs = [rig.matrix_world @ v.co for v in rig.data.vertices]
    vs = [v for v in vs if test(v)]
    return (Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)]))


def tail_proportions(objs, path):
    """Tail size against the torso it hangs from: visible length (along the centreline from where
    it leaves the back to the end of the cap) / torso height, girth (the widest full section,
    fur included) / torso width; plus the leg height for scale."""
    t_lo, t_hi = body_bbox(lambda v: 0.0 <= v.z <= 2.0 and abs(v.x) <= 1.0)
    l_lo, l_hi = body_bbox(lambda v: v.z < 0.0)
    s_out = next((i / 400 for i in range(401) if path.at(i / 400)[0].y > t_hi.y), 0.0)
    q = next(q for q in TAILS.values() if q["PATH"] == path.src)
    length = path.length * (1 - s_out) + core_radius(q, 1.0) * q["CAP"]
    girth = 0.0
    for o in objs:
        for v in o.data.vertices:
            i = min(range(0, len(path.p), 4), key=lambda k: (path.p[k] - v.co).length_squared)
            if path.l[i] / path.length > s_out:
                girth = max(girth, (path.p[i] - v.co).length * 2)
    th, tw = t_hi.z - t_lo.z, t_hi.x - t_lo.x
    return dict(length=round(length, 2), girth=round(girth, 2), torso_size=r3(t_hi - t_lo),
                leg_height=round(l_hi.z - l_lo.z, 2), length_to_torso_height=round(length / th, 2),
                girth_to_torso_width=round(girth / tw, 2))


def limb_clearance(objs):
    """Tail vertices (past the back, y > BODY_BACK_Y) inside a leg or arm box anywhere in the
    R6 run swing (+-RUN_DEG about the hip and shoulder axes; both phases), and at rest.
    Returns {limb: (vertices inside, deepest in studs)}."""
    limbs = {"LeftLeg": (0.0, 1.0, 0.0, -2.0, 0.0), "RightLeg": (-1.0, 0.0, 0.0, -2.0, 0.0),
             "LeftArm": (1.0, 2.0, 1.5, -1.5, 0.5), "RightArm": (-2.0, -1.0, 1.5, -1.5, 0.5)}
    vs = [v.co.copy() for o in objs for v in o.data.vertices if v.co.y > BODY_BACK_Y]
    out = {}
    steps = [RUN_DEG * (k / 8 - 1) for k in range(17)]
    for name, (x0, x1, pz, z0, z1) in limbs.items():
        hits, deep = set(), 0.0
        for ang in steps:
            ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
            for i, v in enumerate(vs):
                if not x0 <= v.x <= x1:
                    continue
                y, z = v.y, v.z - pz   # into the limb's frame (rotate back by ang about X)
                ly, lz = y * ca + z * sa, -y * sa + z * ca
                if -0.5 <= ly <= 0.5 and z0 <= lz <= z1:
                    hits.add(i)
                    deep = max(deep, min(0.5 - ly, ly + 0.5, lz - z0, z1 - lz, v.x - x0, x1 - v.x))
        out[name] = (len(hits), round(deep, 3))
    return out


EAR_ROWS_SHEET = ["WolfEarsSentinel", "WolfEarsRuff", "WolfEarsLance"]
EAR_TARGET = (0.0, 0.0, 3.4)
# (name, eye direction, ortho scale): the head and ears from far, orthographic
EAR_VIEWS = [("front", (0, -1, 0.06), 2.5), ("side", (1, 0, 0.06), 2.5), ("back", (0, 1, 0.06), 2.5),
             ("fold", (1, 0.15, 0.15), 2.7), ("flick", (0.25, -1, 0.2), 2.7)]
EAR_FOLD, EAR_FLICK = 60.0, 35.0      # the sheet's deformation checks (degrees)
# game-camera read: 12 studs away at true on-screen size (1080p, 70 deg FOV: the head is ~75 px)
EAR_GAME = [("game_back", (0.35, 1, 0.35)), ("game_front", (0.35, -1, 0.25))]
GAME_DIST, GAME_LENS = 12.0, 65
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
        for view, d in EAR_GAME:
            tgt = Vector((0, 0, 2.6))
            eye = tgt + Vector(d).normalized() * GAME_DIST
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (name, view)), tuple(eye),
                                   tuple(tgt), lens=GAME_LENS))
    for c in layer.children:
        c.exclude = False
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


def ear_seat_check(objs):
    """Real numbers for the seat, per mesh: the shallowest base-ring vertex (and base-edge
    midpoint) under the head surface, measured along the surface normal (negative = buried), and
    how many vertices hang outside the head's outline below its top edge (air under them)."""
    rig = next(o for o in rp.rig_objects() if o.type == "MESH")
    inv = rig.matrix_world.inverted()

    def signed(w):
        _, p, n, _ = rig.closest_point_on_mesh(inv @ w)
        return (w - rig.matrix_world @ p).dot((rig.matrix_world.to_3x3() @ n).normalized())
    out = {}
    for o in objs:
        ring = EAR_COLS * 2 + 2 if o["region"] == "FurOuter" else EAR_COLS * 2
        vs = [o.matrix_world @ o.data.vertices[i].co for i in range(ring)]
        ds = [signed(v) for v in vs] + [signed((vs[i] + vs[(i + 1) % ring]) / 2) for i in range(ring)]
        hanging = sum(1 for v in o.data.vertices
                      if (o.matrix_world @ v.co).z < HAT.z and
                      head_surface_z(*(o.matrix_world @ v.co).xy) is None)
        out[o.name] = dict(base_shallowest=round(max(ds), 3), base_deepest=round(min(ds), 3),
                           verts_outside_head_below_top=hanging)
    return out


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
    keep = set(TAILS) | set(EARS)
    for c in list(root_col.children):            # drop collections of retired builds
        if c.name not in keep:
            for o in list(c.objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.collections.remove(c)
    for name in HIDE_COLLECTIONS:   # other races' sets: excluded from the view layer, never deleted
        lc = bpy.context.view_layer.layer_collection.children.get(name)
        if lc:
            lc.exclude = True
    shade_image()
    report = {}
    built = {}
    for name in EARS:
        if ONLY and name not in ONLY:
            continue
        arm, objs = build_ears(name, root_col)
        p = EARS[name]
        built[name] = (arm, objs, HAT, "HatAttachment",
                       dict(mood=p["mood"], proportions=ear_proportions(objs), seat=ear_seat_check(objs)))
    for name, q in TAILS.items():
        if ONLY and name not in ONLY:
            continue
        arm, objs, path = build_tail(name, root_col)
        built[name] = (arm, objs, WAIST_BACK, "WaistBackAttachment",
                       dict(mood=q["mood"], shape=q["shape"], proportions=tail_proportions(objs, path),
                            run_clearance=dict(swing_deg=RUN_DEG, past_y=BODY_BACK_Y,
                                               limbs={k: dict(verts_inside=n, deepest=dp) for k, (n, dp)
                                                      in limb_clearance(objs).items()}),
                            ))
    for name, (arm, objs, attach, att_name, extra) in built.items():
        report[name] = dict({o.name: tri_count(o) for o in objs}, **extra)
        if EXPORT:
            export_set(name, arm, objs, attach, att_name, extra)
    print(json.dumps(report))
    if RENDER:
        out = os.path.join(HERE, "renders")
        os.makedirs(out, exist_ok=True)
        for name, info in report.items():   # the sheet's labels (also before an export)
            with open(os.path.join(out, name + "_stats.json"), "w") as fh:
                json.dump(dict(info, tris_total=sum(v for v in info.values() if isinstance(v, int))), fh, indent=1)
        # other races' collections share this scene (FoxCosmetics...): hide them from the renders,
        # then put back exactly what was shown
        top = scene.view_layers[0].layer_collection.children
        others = {c.name: c.exclude for c in top if c.name not in (ROOT_COLLECTION, rp.RIG_COLLECTION)}
        for n in others:
            top[n].exclude = True
        top[ROOT_COLLECTION].exclude = False
        if any(n in built for n in TAILS):
            print(len(render_tiles(scene, root_col, out, PAIRS)), "tail tiles")
        if any(n in built for n in EARS):
            print(len(render_ear_tiles(scene, root_col, out, [n for n in EAR_ROWS_SHEET if n in built])), "ear tiles")
        for n, ex in others.items():
            top[n].exclude = ex
    if EXPORT and SAVE_BLEND:
        # Wolf.blend holds the wolf and the R6 reference only: other races' collections that share
        # the live scene are unlinked for the write and linked straight back
        others = [c for c in scene.collection.children if c.name not in (ROOT_COLLECTION, rp.RIG_COLLECTION)]
        states = {}

        def walk(lc, fn):
            fn(lc)
            for ch in lc.children:
                walk(ch, fn)
        for vl in scene.view_layers:
            for c in others:
                walk(vl.layer_collection.children[c.name],
                     lambda lc, vl=vl: states.__setitem__((vl.name, lc.name), (lc.exclude, lc.hide_viewport)))
        try:
            for c in others:
                scene.collection.children.unlink(c)
            rp.save_blend(scene, os.path.join(HERE, "Wolf.blend"))
        finally:
            for c in others:
                scene.collection.children.link(c)
            for vl in scene.view_layers:
                for c in others:
                    def put(lc, vl=vl):
                        st = states.get((vl.name, lc.name))
                        if st:
                            lc.exclude, lc.hide_viewport = st
                    walk(vl.layer_collection.children[c.name], put)

main()
