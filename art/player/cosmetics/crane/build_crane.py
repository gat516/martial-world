r"""Beast Folk (Crane) cosmetics: red crown crest, white-and-black head plumes and a tail fan for
the player's R6 avatar, in three directions with their own silhouettes:

  Scholar   (elegant) flat red crown cap, horizontal streamer plumes, compact downward half-fan
  Ascendant (bold)    one tall red crest feather, swept-up wing plumes, rising sunburst fan
  Cascade   (soft)    raised red crown swept back, broad plumes draping over the nape, long trailing train

Each direction is two sets: CraneHead<Dir> (crest + plumes, HatAttachment) and CraneFan<Dir>
(WaistBackAttachment), each with its own armature. See README.md.

Run in this race's own visible Blender window (not the shared MCP one), from the repo root:
    tools/blender_live.sh open crane
    tools/blender_live.sh run crane art/player/cosmetics/crane/build_crane.py [RENDER=True] [EXPORT=False]
Then stitch the sheet: uv run --with pillow python3 -I art/player/cosmetics/crane/make_sheet.py

Axes and units (the R6 reference, art/rig/r6_rigged.fbx):
  1 Blender unit = 1 stud. +X = the avatar's left, it faces -Y (so +Y is behind it), Z up.
  Hips z 0, torso z 0..2 (back face y 0.5), head x/y +-0.6, z 2.08..3.10.
  Head HatAttachment        = (0, 0, 3.1)
  Torso WaistBackAttachment = (0, 0.5, 0)
Built in avatar space; the export moves each set so its attachment is the origin.

Feathers: every feather is a closed, chunky lens (six-point section with a raised rachis ridge
and slightly drooping vanes) swept along a bent centreline, so nothing is single-sided. Roots are
buried in the head or torso, and a buried down cushion fills the base of each plume and fan, so
the gaps between feathers near the body show feathers, not the background. A black-tipped
feather is two meshes (main and accent region) meeting at a shared internal cap.

Recolour contract: one mesh (MeshPart) per colour region, material named by region:
  FeatherMain (white), FeatherAccent (black), Crest (crimson).
Depth shading is a greyscale ramp (crane_shade.png) on UV V: feather roots darker, so each
layer reads over the one behind it and tinting by Color still works.

Rig (bones named like the Motor6Ds they become; Root = the attachment point, not deforming):
  Head: Root -> CrestBase -> Crest
        Root -> PlumeBase -> Plume1 -> Plume2 -> Plume3        (one central plume)
        or PlumeLBase -> PlumeL1..3 and PlumeRBase -> PlumeR1..3 (paired side plumes)
  Fan:  Root -> FanBase -> Fan<S> -> Fan<S>Tip  for sectors S = L2, L1, C, R1, R2
        (rotate a sector about local Z to spread or close the fan)
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
EXPORT = globals().get("EXPORT", False)
ONLY = globals().get("ONLY")             # optional comma list of directions to build

SCENE = "Cosmetics"
ROOT_COLLECTION = "CraneCosmetics"
HAT = Vector((0.0, 0.0, 3.1))            # Head HatAttachment, rest pose
WAIST_BACK = Vector((0.0, 0.5, 0.0))     # Torso WaistBackAttachment, rest pose
SHARP_DEG = 40.0                         # feather edges sharper than this shade hard (crisp vanes)

# Colours (linear). Plain SmoothPlastic in Roblox; MeshPart.Color carries these per region.
COLORS = {
    "FeatherMain":   (0.86, 0.87, 0.85, 1),     # soft white
    "FeatherAccent": (0.022, 0.024, 0.032, 1),  # ink black (a touch blue so it still shades)
    "Crest":         (0.50, 0.035, 0.04, 1),    # muted, clear crimson
}
SHADE_FILE = "crane_shade.png"   # greyscale ramp on UV V: V 0 = darkest, V >= SHADE_REACH = white
SHADE_MIN = 0.55                 # darkest value at a feather root
SHADE_REACH = 0.45               # (the same ramp as the fox's, so the uploaded image is shared)

# Preview only: a mid body and a lighter backdrop so both the white and the black feathers read.
PREVIEW_BODY = (0.26, 0.27, 0.30, 1)
PREVIEW_BG = (0.40, 0.45, 0.53)

# ---------------------------------------------------------------------------------- feathers --
# A feather spec (dict):
#   root (x, y, z) avatar space, buried in the body; either yaw/pitch/roll (degrees: yaw 0 = straight
#   back +Y, + turns toward +X; pitch + = up; roll turns the face about the shaft, 0 = face up,
#   90 = face to the side) or dir/up vectors.
#   L length, W half-width at the widest, T thickness (default 0.5 W), shape leaf/round/blade,
#   arc = in-plane bend (degrees over the length, about the face normal), cup = bend toward the face
#   (+) or away, asym vane asymmetry, notch (s, depth) a nick in the +side vane,
#   tip = fraction where the black accent starts (1 = none, 0 = all black),
#   region = "main" or "crest" (the non-accent colour), mirror = also build the X mirror image.
STATIONS = [0.0, 0.05, 0.14, 0.26, 0.40, 0.54, 0.66, 0.77, 0.86, 0.93, 0.975, 1.0]
VANE_DROOP = 0.16      # vane edges droop away from the face by this fraction of the width
QUILL = 0.28           # width at the root as a fraction of W


def profile(shape, s):
    """Half-width fraction along the feather (0 root .. 1 tip)."""
    if shape == "blade":            # long flight feather: widest early, a full taper to a soft point
        peak = 0.30
        if s < peak:
            return QUILL + (1 - QUILL) * math.sin(math.pi / 2 * s / peak)
        return max(0.0, 1 - ((s - peak) / (1 - peak)) ** 1.5) ** 0.7
    peak = 0.46 if shape == "leaf" else 0.52
    if s < peak:
        return QUILL + (1 - QUILL) * math.sin(math.pi / 2 * s / peak)
    u = (s - peak) / (1 - peak)
    if shape == "round":            # a soft rounded end (covert feathers)
        return max(0.0, 1 - u ** 2.4) ** 0.5
    return max(0.0, 1 - u ** 2.0) ** 0.62   # leaf: a soft, full point (chunky, never a needle)


def spec_frame(f):
    if "dir" in f:
        t = Vector(f["dir"]).normalized()
        up = Vector(f["up"])
        n = (up - t * up.dot(t)).normalized()
        return t, n
    yaw, pitch, roll = (math.radians(f.get(k, 0.0)) for k in ("yaw", "pitch", "roll"))
    t = Vector((math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
    side = t.cross(Vector((0, 0, 1)))
    side = side.normalized() if side.length > 1e-6 else Vector((1, 0, 0))
    n = side.cross(t).normalized()                       # the "up" perpendicular to the shaft
    n = Matrix.Rotation(roll, 3, t) @ n
    return t, n


def centreline(f, steps=100):
    """[(pos, t, n)] at steps+1 points along the feather."""
    pos = Vector(f["root"])
    t, n = spec_frame(f)
    ds = 1.0 / steps
    arc, cup, twist = (math.radians(f.get(k, 0.0)) for k in ("arc", "cup", "twist"))
    out = []
    for _ in range(steps + 1):
        out.append((pos.copy(), t.copy(), n.copy()))
        b = t.cross(n)
        r = (Matrix.Rotation(arc * ds, 3, n) @ Matrix.Rotation(cup * ds, 3, b)
             @ Matrix.Rotation(twist * ds, 3, t))
        t, n = (r @ t).normalized(), (r @ n).normalized()
        pos = pos + t * f["L"] * ds
    return out


def feather_ring(f, line, s):
    p, t, n = line[round(s * (len(line) - 1))]
    b = t.cross(n)
    w = f["W"] * profile(f.get("shape", "leaf"), s)
    if w < 1e-3:
        return [p]
    asym = f.get("asym", 0.0)
    wl, wr = w * (1 + asym), w * (1 - asym)
    if f.get("notch"):
        ns, depth = f["notch"]
        wr *= 1 - depth * max(0.0, 1 - abs(s - ns) / 0.05)
    th = f.get("T", f["W"] * 0.50) * (1 - 0.55 * s) * min(1.0, profile(f.get("shape", "leaf"), s) * 1.6)
    dl, dr = VANE_DROOP * wl, VANE_DROOP * wr
    return [p - b * wl - n * dl,
            p - b * (wl * 0.5) + n * (th * 0.55 - dl * 0.3),
            p + n * th,
            p + b * (wr * 0.5) + n * (th * 0.55 - dr * 0.3),
            p + b * wr - n * dr,
            p - n * (th * 0.45 + 0.5 * max(dl, dr))]


def feather_parts(f):
    """[(region, rings, svals)]: the main/crest part up to `tip`, the accent part after it."""
    line = centreline(f)
    tip = f.get("tip", 1.0)
    base = f.get("region", "main")
    stations = sorted(set(STATIONS + ([tip] if 0 < tip < 1 else [])
                          + ([f["notch"][0] - 0.05, f["notch"][0], f["notch"][0] + 0.05] if f.get("notch") else [])))
    parts = []
    lo = [s for s in stations if s <= tip]
    hi = [s for s in stations if s >= tip]
    if len(lo) > 1:
        parts.append((base, [feather_ring(f, line, s) for s in lo], lo))
    if len(hi) > 1:
        parts.append(("accent", [feather_ring(f, line, s) for s in hi], hi))
    return parts, line


def mirrored(f):
    g = dict(f)
    g["root"] = (-f["root"][0], f["root"][1], f["root"][2])
    if "dir" in f:
        g["dir"] = (-f["dir"][0], f["dir"][1], f["dir"][2])
        g["up"] = (-f["up"][0], f["up"][1], f["up"][2])
        g["flip"] = True
    else:
        g["yaw"] = -f.get("yaw", 0.0)
        g["roll"] = -f.get("roll", 0.0)
        g["arc"] = -f.get("arc", 0.0)
        g["twist"] = -f.get("twist", 0.0)
        g["asym"] = -f.get("asym", 0.0)
    g["mirror"] = False
    g["group"] = {"L": "R", "R": "L"}.get(f.get("group", "C"), "C")
    if "a" in f:
        g["a"] = -f["a"]
    return g


def expand(specs):
    out = []
    for f in specs:
        f = dict(f)
        if f.get("mirror"):
            f.setdefault("group", "L")
            out += [f, mirrored(f)]
        else:
            out.append(f)
    return out


# ------------------------------------------------------------------------------- directions ---
def head_plume(x, y, z, **k):
    return dict(root=(x, y, z), **k)


def fan_layer(hub, centre, normal, angles, push=0.0, cone=0.0, **k):
    """Feathers radiating from `hub` in the plane through `centre` (dir) with face `normal`;
    angles in degrees about the normal (+ turns toward +X when the normal faces back). push moves
    the layer toward the viewer behind (along normal), so later layers lie on earlier ones. cone
    tilts every feather that many degrees out of the plane toward the viewer, so the fan is a
    shallow dome with depth from the side, not a flat card."""
    centre, normal = Vector(centre).normalized(), Vector(normal).normalized()
    amax = max(abs(a) for a in angles) or 1.0
    out = []
    for a in angles:
        d = Matrix.Rotation(math.radians(a), 3, normal) @ centre
        side = d.cross(normal)
        d2 = Matrix.Rotation(math.radians(cone), 3, side) @ d
        up = Matrix.Rotation(math.radians(cone), 3, side) @ normal
        root = Vector(hub) + normal * push
        out.append(dict(root=tuple(root), dir=tuple(d2), up=tuple(up), a=a / amax if a else 0.0, **k))
    return out


def sunk(v, n, d):
    return tuple(Vector(v) + Vector(n).normalized() * d)


DIRECTIONS = {}

# --- Scholar: elegant and calm. A flat crown cap, broad streamer plumes trailing straight back
# with a gentle upward flick, a compact domed half-fan hanging behind the hips like a sash bow.
_n = Vector((0, 0.64, 0.77))              # fan face: back and up (seen from behind)
_c = Vector((0, 0.77, -0.64))             # fan centre: back and down, raked 50 deg off vertical
_hub = (0.0, 0.40, 0.30)
DIRECTIONS["Scholar"] = dict(
    label="Scholar", mood="elegant",
    note="flat crown cap, streamer plumes, compact half-fan",
    chains="center",
    crest=[
        dict(root=(0.0, -0.42, 3.05), yaw=0, pitch=3, roll=0, L=0.64, W=0.20, T=0.17, shape="round", region="crest"),
        dict(root=(0.10, -0.38, 3.05), yaw=16, pitch=1, roll=-8, L=0.52, W=0.16, T=0.14, shape="round",
             region="crest", mirror=True, group="C"),
        dict(root=(0.0, -0.24, 3.10), yaw=0, pitch=0, roll=0, L=0.44, W=0.15, T=0.14, shape="round", region="crest"),
    ],
    cushion=dict(c=(0.0, 0.55, 2.80), r=(0.27, 0.16, 0.22)),
    plumes=[
        head_plume(0.0, 0.40, 2.94, pitch=14, roll=90, L=1.45, W=0.27, arc=34, tip=0.74, shape="leaf",
                   notch=(0.62, 0.4), spine=True),
        head_plume(0.10, 0.40, 2.86, yaw=14, pitch=4, roll=78, L=1.30, W=0.25, arc=28, tip=0.70, mirror=True),
        head_plume(0.07, 0.40, 2.74, yaw=8, pitch=-9, roll=84, L=1.65, W=0.21, arc=40, tip=0.0, shape="blade",
                   mirror=True),
        head_plume(0.0, 0.40, 2.68, pitch=-15, roll=90, L=1.80, W=0.20, arc=46, tip=0.0, shape="blade"),
    ],
    fan_hub=_hub, fan_normal=tuple(_n),
    fan_cushion=dict(c=(0.0, 0.52, 0.30), r=(0.30, 0.12, 0.22)),
    fan=(fan_layer(_hub, _c, _n, [-72, -48, -24, 0, 24, 48, 72], cone=22, L=1.35, W=0.36, shape="round",
                   tip=0.0, cup=16)
         + fan_layer(_hub, _c, _n, [-60, -36, -12, 12, 36, 60], push=0.06, cone=26, L=1.12, W=0.36, shape="round",
                     tip=0.86, cup=14)
         + fan_layer(_hub, _c, _n, [-40, 0, 40], push=0.12, cone=30, L=0.72, W=0.35, shape="round", cup=10)),
)

# --- Ascendant: bold. One tall flame-like crest feather, plumes sweeping up and back from both
# sides of the head like folded wings, a sunburst fan rising behind the back.
_n = Vector((0, 0.82, -0.57))             # fan face: back and a little down
_c = Vector((0, 0.57, 0.82))              # fan centre: up and back
_hub = (0.0, 0.40, 0.35)
DIRECTIONS["Ascendant"] = dict(
    label="Ascendant", mood="bold",
    note="tall crest feather, swept-up wing plumes, sunburst fan",
    chains="sides",
    crest=[
        dict(root=(0.0, -0.24, 2.92), yaw=0, pitch=74, roll=90, L=0.95, W=0.24, T=0.13, arc=-62, shape="leaf",
             region="crest", notch=(0.55, 0.45), spine=True),
        dict(root=(0.07, -0.30, 2.98), yaw=34, pitch=40, roll=90, L=0.46, W=0.15, arc=-30, shape="leaf",
             region="crest", mirror=True, group="C"),
    ],
    cushion=dict(c=(0.0, 0.52, 2.86), r=(0.36, 0.17, 0.22)),
    plumes=[
        head_plume(0.24, 0.38, 2.96, yaw=22, pitch=50, roll=72, L=1.55, W=0.30, arc=-78, tip=0.70,
                   notch=(0.6, 0.4), mirror=True, group="L", spine=True),
        head_plume(0.20, 0.38, 2.86, yaw=26, pitch=36, roll=76, L=1.85, W=0.24, arc=-72, tip=0.0, shape="blade",
                   mirror=True, group="L"),
        head_plume(0.26, 0.36, 3.02, yaw=16, pitch=66, roll=68, L=1.10, W=0.30, arc=-70, tip=1.0, mirror=True,
                   group="L"),
        head_plume(0.14, 0.40, 2.76, yaw=28, pitch=20, roll=80, L=1.35, W=0.24, arc=-50, tip=0.62, mirror=True,
                   group="L"),
    ],
    fan_hub=_hub, fan_normal=tuple(_n),
    fan_cushion=dict(c=(0.0, 0.53, 0.40), r=(0.36, 0.12, 0.26)),
    fan=(fan_layer(_hub, _c, _n, [-88, -66, -44, -22, 0, 22, 44, 66, 88], cone=12, L=1.80, W=0.30, shape="blade",
                   tip=0.0)
         + fan_layer(_hub, _c, _n, [-77, -55, -33, -11, 11, 33, 55, 77], push=0.06, cone=16, L=1.5, W=0.33,
                     shape="leaf", tip=0.70, notch=(0.6, 0.35))
         + fan_layer(_hub, _c, _n, [-75, -50, -25, 0, 25, 50, 75], push=0.12, cone=22, L=0.84, W=0.33,
                     shape="round")),
)

# --- Cascade: soft and flowing. A raised red crown swept back like a small helmet crest, broad
# plumes draping down over the nape with tips curling out, a long trailing train.
_n = Vector((0, 0.77, 0.64))              # fan face: back and up
_c = Vector((0, 0.64, -0.77))             # fan centre: down and back
_hub = (0.0, 0.40, 0.22)
DIRECTIONS["Cascade"] = dict(
    label="Cascade", mood="soft",
    note="raised swept crown, draping nape plumes, trailing train",
    chains="center",
    crest=[
        dict(root=(0.0, -0.40, 3.02), yaw=0, pitch=22, roll=0, L=0.60, W=0.20, T=0.13, cup=-10, shape="round",
             region="crest", spine=True),
        dict(root=(0.0, -0.22, 3.04), yaw=0, pitch=30, roll=0, L=0.52, W=0.17, T=0.12, cup=-12, shape="leaf",
             region="crest"),
        dict(root=(0.09, -0.32, 3.02), yaw=18, pitch=16, roll=-20, L=0.46, W=0.15, T=0.11, shape="round",
             region="crest", mirror=True, group="C"),
    ],
    crest_cushion=dict(c=(0.0, -0.18, 3.08), r=(0.17, 0.30, 0.10)),
    cushion=dict(c=(0.0, 0.55, 2.70), r=(0.30, 0.16, 0.26)),
    plumes=[
        head_plume(0.0, 0.40, 2.88, pitch=-30, roll=8, L=1.30, W=0.32, arc=0, cup=-34, tip=0.78, shape="leaf",
                   spine=True),
        head_plume(0.12, 0.40, 2.84, yaw=22, pitch=-38, roll=30, L=1.20, W=0.30, cup=-30, tip=0.76, shape="leaf",
                   mirror=True),
        head_plume(0.22, 0.38, 2.74, yaw=40, pitch=-48, roll=48, L=1.0, W=0.28, cup=-26, tip=0.72, shape="leaf",
                   mirror=True),
        head_plume(0.06, 0.38, 2.70, yaw=10, pitch=-50, roll=14, L=1.55, W=0.26, cup=-30, tip=0.0, shape="blade",
                   mirror=True),
    ],
    fan_hub=_hub, fan_normal=tuple(_n),
    fan_cushion=dict(c=(0.0, 0.52, 0.22), r=(0.28, 0.12, 0.22)),
    fan=(fan_layer(_hub, _c, _n, [-30, -15, 0, 15, 30], cone=8, L=2.15, W=0.29, shape="blade", tip=0.0, cup=26)
         + fan_layer(_hub, _c, _n, [-34, -21, -7, 7, 21, 34], push=0.06, cone=12, L=1.75, W=0.32, shape="leaf",
                     tip=0.74, cup=22)
         + fan_layer(_hub, _c, _n, [-22, 0, 22], push=0.12, cone=18, L=0.95, W=0.33, shape="round", cup=14)),
)

FAN_SECTORS = ["L2", "L1", "C", "R1", "R2"]   # sector bones; L = the avatar's left (+X)
PLUME_JOINTS = (0.16, 0.42, 0.68, 0.96)        # s where PlumeBase|1|2|3 end
FAN_JOINTS = (0.14, 0.55, 0.96)                # s where FanBase|sector|sectorTip end
BLEND = 0.09                                   # weight blend half-width in s across each joint
ROOT_BONE_LEN = 0.25


# ---------------------------------------------------------------------------------- helpers ---
def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


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


class Region:
    """One region mesh being built: bmesh plus per-vertex (s, a, group, shade V)."""

    def __init__(self):
        self.bm = bmesh.new()
        self.attr = []

    def loft(self, rings, svals, a, group, shade_v):
        vr = []
        for ring, s in zip(rings, svals):
            vs = [self.bm.verts.new(p) for p in ring]
            self.attr += [(s, a, group, shade_v(s))] * len(vs)
            vr.append(vs)
        rp.loft(self.bm, vr, cap_start=len(vr[0]) > 2, cap_end=len(vr[-1]) > 2)

    def ellipsoid(self, c, r, group, rings=6, sides=10):
        c, vr = Vector(c), []
        for i in range(rings + 1):
            ph = math.pi * i / rings
            if i in (0, rings):
                vr.append([self.bm.verts.new(c + Vector((0, 0, -r[2] * math.cos(ph))))])
            else:
                vr.append([self.bm.verts.new(c + Vector((r[0] * math.sin(ph) * math.cos(th),
                                                         r[1] * math.sin(ph) * math.sin(th),
                                                         -r[2] * math.cos(ph))))
                           for th in (2 * math.pi * k / sides for k in range(sides))])
            self.attr += [(0.0, 0.0, group, 0.25)] * len(vr[-1])
        rp.loft(self.bm, vr, cap_start=False, cap_end=False)


def link_region(name, reg, mat, col):
    bm = reg.bm
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = not (e.is_manifold and e.calc_face_angle(0) > math.radians(SHARP_DEG))
    for old in (bpy.data.objects.get(name),):
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
    if bpy.data.meshes.get(name):
        bpy.data.meshes.remove(bpy.data.meshes[name])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    uv = me.uv_layers.new(name="UVMap")
    for loop in me.loops:
        uv.data[loop.index].uv = (0.5, min(0.995, max(0.005, reg.attr[loop.vertex_index][3])))
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    me.materials.append(material(mat))
    o["region"] = mat
    return o


REGION_MAT = {"main": "FeatherMain", "accent": "FeatherAccent", "crest": "Crest"}


def build_feathers(specs, regions, kind):
    """Adds each feather to its region meshes; returns {group: spine centreline}."""
    spines = {}
    for f in expand(specs):
        parts, line = feather_parts(f)
        group = "crest" if kind == "crest" else f.get("group", "C")
        for region, rings, svals in parts:
            regions.setdefault(region, Region()).loft(
                rings, svals, f.get("a", 0.0), group,
                (lambda s: 1.0) if region != "main" else (lambda s: s))
        if f.get("spine") and group not in spines:
            spines[group] = line
    return spines


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


def chain_weights(s, names, joints):
    ramps = [1.0] + [smoothstep(j - BLEND, j + BLEND, s) for j in joints[:len(names) - 1]] + [0.0]
    return [(names[i], ramps[i] - ramps[i + 1]) for i in range(len(names)) if ramps[i] - ramps[i + 1] > 1e-4]


def at_s(line, s):
    return line[round(min(1.0, max(0.0, s)) * (len(line) - 1))]


def add_chain(eb, parent, names, line, joints):
    prev, s0 = parent, 0.0
    for k, (name, s1) in enumerate(zip(names, joints)):
        b = eb.new(name)
        p0, t0, n0 = at_s(line, s0)
        b.head, b.tail = p0, at_s(line, s1)[0]
        b.align_roll(t0.cross(n0))       # local Z = the feather's side axis: rotate about Z to lift/drop
        b.parent = prev
        b.use_connect = k > 0
        prev, s0 = b, s1
    return prev


def plume_names(group):
    tag = "" if group == "C" else group
    return ["Plume%sBase" % tag] + ["Plume%s%d" % (tag, k) for k in (1, 2, 3)]


def build_head(dname, d, root_col):
    name = "CraneHead%s" % dname
    col = collection(name, root_col)
    regions = {}
    crest_spines = build_feathers(d["crest"], regions, "crest")
    plume_spines = build_feathers(d["plumes"], regions, "plume")
    regions["main"].ellipsoid(d["cushion"]["c"], d["cushion"]["r"], "C")
    if d.get("crest_cushion"):     # a buried red dome under feathers that lift off the head (no gap)
        regions["crest"].ellipsoid(d["crest_cushion"]["c"], d["crest_cushion"]["r"], "crest")
    arm = new_armature(name + "_Rig", col)
    eb = arm.data.edit_bones
    root = eb.new("Root")
    root.head, root.tail = HAT, HAT + Vector((0, 0, ROOT_BONE_LEN))
    root.align_roll(Vector((1, 0, 0)))
    root.use_deform = False
    crest_line = crest_spines.get("crest") or centreline(d["crest"][0])
    add_chain(eb, root, ["CrestBase", "Crest"], crest_line, (0.14, 0.96))
    groups = ["L", "R"] if d["chains"] == "sides" else ["C"]
    for g in groups:
        line = plume_spines.get(g)
        if line is None:      # the right side: mirror the left spine
            line = [(Vector((-p.x, p.y, p.z)), Vector((-t.x, t.y, t.z)), Vector((-n.x, n.y, n.z)))
                    for p, t, n in plume_spines["L"]]
        add_chain(eb, root, plume_names(g), line, PLUME_JOINTS)
    bpy.ops.object.mode_set(mode="OBJECT")
    objs = []
    for region, suffix in (("crest", "Crest"), ("main", "Plume"), ("accent", "PlumeAccent")):
        reg = regions.get(region)
        if reg is None:
            continue
        o = link_region("%s_%s" % (name, suffix), reg, REGION_MAT[region], col)
        ws = []
        for s, a, g, _ in reg.attr:
            if g == "crest":
                ws.append(chain_weights(s, ["CrestBase", "Crest"], (0.14,)))
            else:
                gg = g if g in groups else ("L" if g == "C" and "L" in groups else g)
                if g == "C" and "L" in groups:      # the shared cushion: half to each side's base
                    ws.append([("PlumeLBase", 0.5), ("PlumeRBase", 0.5)])
                else:
                    ws.append(chain_weights(s, plume_names(gg), PLUME_JOINTS[:3]))
        skin(o, arm, ws)
        objs.append(o)
    # The crest region took the cushion? No: the cushion is main. Crest verts all carry group crest.
    return name, arm, objs


def sector_of(a):
    """Blend weights over the 5 sectors for normalised angle a (-1..1, + = toward +X = L)."""
    centres = [1.0, 0.5, 0.0, -0.5, -1.0]
    out = []
    for name, c in zip(FAN_SECTORS, centres):
        w = max(0.0, 1 - abs(a - c) / 0.5)
        if w > 1e-4:
            out.append((name, w))
    return out


def build_fan(dname, d, root_col):
    name = "CraneFan%s" % dname
    col = collection(name, root_col)
    regions = {}
    build_feathers(d["fan"], regions, "fan")
    regions["main"].ellipsoid(d["fan_cushion"]["c"], d["fan_cushion"]["r"], "C")
    hub, normal = Vector(d["fan_hub"]), Vector(d["fan_normal"]).normalized()
    centre = Vector(d["fan"][0]["dir"])   # recomputed below from the widest layer
    layer0 = [f for f in d["fan"] if f.get("push", 0) == 0 and f["root"] == tuple(hub)]
    amax = max(abs(math.degrees(Vector(f["dir"]).angle(Vector(layer0[len(layer0) // 2]["dir"])))) for f in layer0)
    centre = Vector(layer0[len(layer0) // 2]["dir"]).normalized()
    length = max(f["L"] for f in d["fan"])
    arm = new_armature(name + "_Rig", col)
    eb = arm.data.edit_bones
    root = eb.new("Root")
    root.head, root.tail = WAIST_BACK, WAIST_BACK + Vector((0, ROOT_BONE_LEN, 0))
    root.align_roll(Vector((1, 0, 0)))
    root.use_deform = False
    base = eb.new("FanBase")
    base.head, base.tail = hub, hub + centre * length * FAN_JOINTS[0]
    base.align_roll(normal)
    base.parent = root
    for sname, c in zip(FAN_SECTORS, [1.0, 0.5, 0.0, -0.5, -1.0]):
        dv = Matrix.Rotation(math.radians(c * amax), 3, normal) @ centre
        if sname != "C" and (dv.x > 0) != sname.startswith("L"):
            dv = Matrix.Rotation(math.radians(-c * amax), 3, normal) @ centre
        b = eb.new("Fan" + sname)
        b.head, b.tail = hub + dv * length * FAN_JOINTS[0], hub + dv * length * FAN_JOINTS[1]
        b.align_roll(normal)
        b.parent = base
        t = eb.new("Fan%sTip" % sname)
        t.head, t.tail = b.tail, hub + dv * length * FAN_JOINTS[2]
        t.align_roll(normal)
        t.parent, t.use_connect = b, True
    bpy.ops.object.mode_set(mode="OBJECT")
    objs = []
    for region, suffix in (("main", "Fan"), ("accent", "FanAccent")):
        reg = regions.get(region)
        o = link_region("%s_%s" % (name, suffix), reg, REGION_MAT[region], col)
        ws = []
        for s, a, g, _ in reg.attr:
            wb = 1 - smoothstep(FAN_JOINTS[0] - BLEND, FAN_JOINTS[0] + BLEND, s)
            wt = smoothstep(0.55 - 0.12, 0.55 + 0.12, s)
            side = 1.0 if "flip" not in g else 1.0
            w = [("FanBase", wb)] if wb > 1e-4 else []
            for sec, sw in sector_of(a * side):
                if (1 - wb) * (1 - wt) * sw > 1e-4:
                    w.append(("Fan" + sec, (1 - wb) * (1 - wt) * sw))
                if (1 - wb) * wt * sw > 1e-4:
                    w.append(("Fan%sTip" % sec, (1 - wb) * wt * sw))
            ws.append(w)
        skin(o, arm, ws)
        objs.append(o)
    return name, arm, objs


def fan_sign(arm):
    """+1 when a positive rotation about a sector's local Z moves an L sector further toward +X."""
    return 1.0


def pose(arm, bent=False):
    """Rest, or the sheet's check pose: plumes swayed 18 deg/joint and lifted, crest bent back,
    fan spread 18 deg per sector step with tips flexed."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        if not bent:
            continue
        n = pb.name
        if n.startswith("Plume") and not n.endswith("Base"):
            side = -1 if "R" in n[5:6] else 1
            pb.rotation_euler = (math.radians(14), 0, math.radians(-14 * side))
        elif n == "Crest":
            pb.rotation_euler = (0, 0, math.radians(-25))
        elif n.startswith("Fan") and n != "FanBase":
            sec = n[3:].replace("Tip", "")
            k = {"L2": 2, "L1": 1, "C": 0, "R1": -1, "R2": -2}[sec]
            if n.endswith("Tip"):
                pb.rotation_euler = (math.radians(16), 0, 0)
            else:
                pb.rotation_euler = (0, 0, math.radians(9 * k))
    bpy.context.view_layer.update()


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
        bones = {b.name: dict(parent=b.parent.name if b.parent else None, head=r3(b.head_local),
                              tail=r3(b.tail_local), roblox_head=[round(-b.head_local[0], 3),
                                                                  round(b.head_local[2], 3),
                                                                  round(b.head_local[1], 3)],
                              deform=b.use_deform)
                 for b in arm.data.bones}
        report = dict(
            name=name, attachment=attach_name, attachment_avatar_space=r3(attach),
            units="1 Blender unit = 1 stud; positions relative to the attachment (Blender X = avatar left, "
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
    ("front", (0, -1, 0.10), (0, 0.6, 1.0), 7.6, 20),
    ("side", (1, 0, 0.08), (0, 1.0, 1.0), 7.6, 20),
    ("back", (0, 1, 0.12), (0, 0.6, 1.0), 7.6, 20),
    ("threequarter", (0.8, 0.85, 0.38), (0.2, 0.8, 1.1), 7.8, 20),
    ("bent", (0.9, 0.8, 0.25), (0.2, 0.9, 1.0), 7.8, 20),
    ("seat", (0.95, 0.75, 0.06), (0.15, 0.55, 2.85), None, 2.6),     # head close, eye at head height
    ("crest", (0.9, -0.35, 0.18), (0.0, -0.15, 3.15), None, 2.2),    # crest seating from the side front
    ("fanclose", (0.75, 0.9, 0.12), (0.0, 0.9, 0.2), None, 4.4),     # bent fan close (spread, sealed?)
]


def render_tiles(scene, root_col, out_dir, names, res=420):
    rp.setup_render(scene, res=(res, res))
    bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (*PREVIEW_BG, 1)
    body = bpy.data.materials.get("PreviewR6")
    if body:
        bsdf = next(n for n in body.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = PREVIEW_BODY
    layer = scene.view_layers[0].layer_collection.children[root_col.name]
    shots = []
    for dname in names:
        show = {"CraneHead%s" % dname, "CraneFan%s" % dname}
        for c in layer.children:
            c.exclude = c.name not in show
        arms = [bpy.data.objects[n + "_Rig"] for n in show]
        for view, dvec, tgt, ortho, dist in VIEWS:
            for a in arms:
                pose(a, bent=view in ("bent", "fanclose"))
            eye = Vector(tgt) + Vector(dvec).normalized() * dist
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (dname, view)), tuple(eye), tgt,
                                   ortho=ortho, lens=50))
        for a in arms:
            pose(a)
    for c in layer.children:
        c.exclude = False
    return shots


# ---------------------------------------------------------------------------------- ratios ----
def body_part_boxes():
    """Bounding boxes (min, max) of the R6 head and torso, measured from the rig mesh."""
    rig = next(o for o in rp.rig_objects() if o.type == "MESH")
    ws = [rig.matrix_world @ v.co for v in rig.data.vertices]
    parts = {"head": [v for v in ws if v.z > 2.05],
             "torso": [v for v in ws if abs(v.x) < 0.95 and 0.05 < v.z < 1.95]}
    return {k: (Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)]))
            for k, vs in parts.items()}


def box_of(objs):
    ws = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    return Vector([min(v[i] for v in ws) for i in range(3)]), Vector([max(v[i] for v in ws) for i in range(3)])


def ratios(objs_by_set, parts):
    """Each piece's size as a ratio of the body part it attaches to (width = X, height = Z,
    reach = how far it stands out behind the part's back face, +Y). Printed and on the sheet."""
    out = {}
    (hmn, hmx), (tmn, tmx) = parts["head"], parts["torso"]
    hs, ts = hmx - hmn, tmx - tmn
    for sname, objs in objs_by_set.items():
        if sname.startswith("CraneHead"):
            crest = [o for o in objs if o["region"] == "Crest"]
            plume = [o for o in objs if o["region"] != "Crest"]
            (cmn, cmx), (pmn, pmx) = box_of(crest), box_of(plume)
            out[sname] = dict(
                crest_above_head=round((cmx.z - hmx.z) / hs.z, 2), crest_width=round((cmx.x - cmn.x) / hs.x, 2),
                crest_length=round((cmx.y - cmn.y) / hs.y, 2),
                plume_width=round((pmx.x - pmn.x) / hs.x, 2), plume_height=round((pmx.z - pmn.z) / hs.z, 2),
                plume_reach=round((pmx.y - hmx.y) / hs.y, 2), plume_above_head=round((pmx.z - hmx.z) / hs.z, 2))
        else:
            mn, mx = box_of(objs)
            out[sname] = dict(fan_width=round((mx.x - mn.x) / ts.x, 2), fan_height=round((mx.z - mn.z) / ts.z, 2),
                              fan_reach=round((mx.y - tmx.y) / ts.y, 2))
    return out


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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "Crane.blend"))   # names the window early
    shade_image()
    parts = body_part_boxes()
    print("head box", r3(parts["head"][0]), r3(parts["head"][1]), "torso box", r3(parts["torso"][0]),
          r3(parts["torso"][1]))
    built = {}
    names = [n for n in DIRECTIONS if not ONLY or n in str(ONLY).split(",")]
    report = {}
    for dname in names:
        d = DIRECTIONS[dname]
        for builder, attach, att_name in ((build_head, HAT, "HatAttachment"),
                                          (build_fan, WAIST_BACK, "WaistBackAttachment")):
            sname, arm, objs = builder(dname, d, root_col)
            report[sname] = {o.name: tri_count(o) for o in objs}
            built[sname] = objs
            if EXPORT:
                export_set(sname, arm, objs, attach, att_name, dict(direction=dname, mood=d["mood"]))
    print(json.dumps(report, indent=1))
    rat = ratios(built, parts)
    print(json.dumps(rat, indent=1))
    os.makedirs(os.path.join(HERE, "renders"), exist_ok=True)
    with open(os.path.join(HERE, "renders", "ratios.json"), "w") as fh:
        json.dump(dict(ratios=rat, tris=report), fh, indent=1)
    if RENDER:
        out = os.path.join(HERE, "renders")
        os.makedirs(out, exist_ok=True)
        print(len(render_tiles(scene, root_col, out, names)), "tiles")
    bpy.ops.wm.save_mainfile()


main()
