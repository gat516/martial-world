"""Builds the SpiritWolf body, variant A: rigid segment meshes for the shared Motor6D wolf rig.

Run inside Blender: exec(compile(open(p).read(), p, "exec"), {"__file__": p, "__name__": "__main__"}).
Builds into its own scene "SpiritWolf", writes the palette texture (SpiritWolfPalette.png), renders
previews (rest, the test poses and +-60 degree joint sweeps) into preview/, and exports SpiritWolf.fbx,
SpiritWolf.json and SpiritWolf.blend next to this script.

Rig: no skinning. Both SpiritWolf bodies (A: these meshes, B: Studio Parts) share one Motor6D rig with the
legacy part and joint names, built by art/enemies/spirit_wolf/rig_wolf.luau (the main session's file), so
the existing EnemyAnimator drives either body unchanged. Each segment here is one rigid mesh named after
its part; its rest centre/size go into the JSON. Every segment end that meets a joint is a rounded cap
centred on that joint's pivot and runs ~0.2+ past it into its neighbour, and fur collars hang over the
seams, so a +-60 degree turn about any pivot never opens a gap (checked in the sweep previews).

Look: a stylized painterly wolf in chunky planes (the concept: dark slate back, mane and tail with big
spiky tufts, pale cream belly, legs, muzzle and chest, red eyes, a snarl with big white teeth, big pale
claws). Colour comes from a 64x64 palette texture: every face is UV-mapped onto one swatch, and every
MeshPart shares the one uploaded texture on SmoothPlastic. The eyes are separate Neon meshes.

Units and axes: 1 Blender unit = 1 stud. Everything below is authored in ROBLOX MODEL SPACE (ground at
Y = 0, the wolf faces -Z, its left side is -X) and converted with B(): Blender (x, y, z) = (rx, -rz, ry).
Origin = the ground point under the body. Each mesh's origin is its bounding-box centre.
FBX: house settings (rig_preview.export_item): Roblox imports ~11x oversized with axes remapped, so the
place script sets Size = (bx, bz, by) and CFrame = pivot * Angles(0, pi, 0) * CFrame.new(-cx, cz, cy)
from the JSON (Blender axes), i.e. centre (cx, cz, -cy) in model space.
"""
import importlib
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else bpy.path.abspath("//")
sys.path.insert(0, os.path.join(OUT_DIR, "..", "..", "rig"))
import rig_preview as rp  # noqa: E402
importlib.reload(rp)

NAME = "SpiritWolf"
PALETTE_FILE = "SpiritWolfPalette.png"
RENDER_PREVIEWS = "--no-previews" not in sys.argv and not globals().get("NO_PREVIEWS")
SHARP_DEG = 40.0      # faces meeting sharper than this get a hard edge (tubes stay soft, tufts crisp)
SIDES_BODY = 10       # ring sides: torso, neck, head
SIDES_LIMB = 8        # legs, tail, jaw
SWEEP_DEG = 60.0      # joint sweep preview angle (the rig must not gap at +-this)


def B(p):
    """Roblox model space (x, y up, z back) -> Blender (x, y forward, z up)."""
    return Vector((p[0], -p[2], p[1]))


# --- palette ---------------------------------------------------------------------------------------
SWATCHES = {   # name -> (hex, column, row) on a 4x4 grid of 16 px cells; rows mirror (0=3, 1=2) so a V flip
    "slate": ("#2F3B50", 0, 0),       # on import can't change a colour
    "slatehi": ("#46566E", 1, 0),
    "cream": ("#C8C1B0", 2, 0),
    "shade": ("#9E978A", 3, 0),
    "ivory": ("#EEE9DC", 0, 1),       # claws and teeth
    "dark": ("#1B1E25", 1, 1),        # nose, lips and pads
    "mouth": ("#6B2A33", 2, 1),       # mouth and ear inside
    "eye": ("#FF2B2B", 3, 1),         # eyes (the Neon eye meshes use Color, not the texture)
}
EYE_HEX = "#FF2B2B"


def srgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def linear(h):
    return tuple([c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb(h)] + [1.0])


def swatch_uv(name):
    _, col, row = SWATCHES[name]
    return ((col + 0.5) / 4, 1 - (row + 0.5) / 4)   # UV origin bottom-left; row 0 = top of the image


def make_palette():
    img = bpy.data.images.get(PALETTE_FILE)
    if img:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(PALETTE_FILE, 64, 64, alpha=False)
    px = [0.0] * (64 * 64 * 4)
    for hx, col, row in SWATCHES.values():
        r, gg, b = srgb(hx)
        for mirror_row in (row, 3 - row):
            for yy in range(16):
                for xx in range(16):
                    X, Y = col * 16 + xx, (3 - mirror_row) * 16 + yy   # Blender pixel rows run bottom-up
                    i = (Y * 64 + X) * 4
                    px[i:i + 4] = [r, gg, b, 1.0]
    img.pixels = px
    img.filepath_raw = os.path.join(OUT_DIR, PALETTE_FILE)
    img.file_format = "PNG"
    img.save()
    return img


def palette_material(img):
    m = bpy.data.materials.get("SpiritWolfPalette") or bpy.data.materials.new("SpiritWolfPalette")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None) or nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    m.diffuse_color = linear("#2F3B50")
    return m


# --- joints (Roblox model space; the shared rig spec) ----------------------------------------------
JOINTS = {   # name -> (pivot, parent part, child part)
    "JointRoot": ((0, 2.85, 1.6), None, "Hips"),
    "JointSpine": ((0, 3.0, 0.8), "Hips", "Chest"),
    "JointNeck": ((0, 3.15, -1.75), "Chest", "Neck"),
    "JointHead": ((0, 3.15, -2.85), "Neck", "Skull"),
    "JointJaw": ((0, 2.75, -3.4), "Skull", "Jaw"),
    "JointEarL": ((-0.45, 3.7, -3.15), "Skull", "EarL"),
    "JointEarR": ((0.45, 3.7, -3.15), "Skull", "EarR"),
    "JointTail": ((0, 3.3, 2.75), "Hips", "TailBase"),
    "JointTail2": ((0, 3.25, 3.75), "TailBase", "TailMid"),
    "JointTail3": ((0, 3.4, 4.85), "TailMid", "TailTip"),
}
for _s, _x in (("L", -1), ("R", 1)):
    JOINTS.update({
        "JointLegF" + _s: ((_x * 0.7, 2.45, -1.3), "Chest", "UpperLegF" + _s),
        "JointElbowF" + _s: ((_x * 0.72, 1.35, -1.25), "UpperLegF" + _s, "LowerLegF" + _s),
        "JointWristF" + _s: ((_x * 0.72, 0.32, -1.35), "LowerLegF" + _s, "PawF" + _s),
        "JointLegB" + _s: ((_x * 0.7, 2.5, 2.1), "Hips", "UpperLegB" + _s),
        "JointKneeB" + _s: ((_x * 0.75, 1.35, 1.8), "UpperLegB" + _s, "LowerLegB" + _s),
        "JointHockB" + _s: ((_x * 0.75, 0.62, 2.3), "LowerLegB" + _s, "PawB" + _s),
    })
PART_JOINT = {child: j for j, (_, _, child) in JOINTS.items()}
PART_JOINT.update({"EyeL": None, "EyeR": None})   # the eyes ride the Skull
SPEC_BOXES = {   # the shared spec's rest centre/size, for the report (the meshes run past where joints need it)
    "Hips": ((0, 2.85, 1.9), (1.9, 1.7, 1.8)), "Chest": ((0, 2.9, -0.5), (2.2, 2.0, 2.8)),
    "Neck": ((0, 3.05, -2.35), (1.3, 1.3, 1.3)), "Skull": ((0, 3.15, -3.35), (1.45, 1.25, 1.3)),
    "Jaw": ((0, 2.55, -4.05), (0.75, 0.3, 1.15)), "TailBase": ((0, 3.25, 3.25), (0.7, 0.7, 1.1)),
    "TailMid": ((0, 3.3, 4.3), (0.8, 0.8, 1.2)), "TailTip": ((0, 3.75, 5.3), (0.6, 0.9, 0.9)),
}
for _s, _x in (("L", -1), ("R", 1)):
    SPEC_BOXES.update({
        "Ear" + _s: ((_x * 0.5, 4.05, -3.1), (0.45, 0.75, 0.25)),
        "UpperLegF" + _s: ((_x * 0.72, 1.9, -1.3), (0.7, 1.3, 0.8)),
        "LowerLegF" + _s: ((_x * 0.72, 0.8, -1.3), (0.45, 1.1, 0.5)),
        "PawF" + _s: ((_x * 0.72, 0.15, -1.6), (0.65, 0.3, 0.85)),
        "UpperLegB" + _s: ((_x * 0.75, 1.95, 2.0), (0.85, 1.4, 1.0)),
        "LowerLegB" + _s: ((_x * 0.75, 1.0, 2.05), (0.45, 0.8, 0.5)),
        "PawB" + _s: ((_x * 0.75, 0.35, 2.15), (0.6, 0.7, 0.85)),
        "Eye" + _s: ((_x * 0.38, 3.3, -3.98), (0.3, 0.14, 0.08)),
    })


def chain(part):
    """Joints from the root down to `part`'s own joint."""
    out = []
    while part:
        j = PART_JOINT.get(part)
        if part in ("EyeL", "EyeR"):
            part = "Skull"
            continue
        if not j:
            break
        out.append(j)
        part = JOINTS[j][1]
    return list(reversed(out))


# --- shapes (Roblox model space) -------------------------------------------------------------------
# torso stations: (z, top y, bottom y, half width); caps are rounded, depth in studs
CHEST = [(-1.75, 3.70, 2.22, 0.80), (-1.30, 3.88, 1.92, 1.02), (-0.60, 3.90, 1.90, 1.10),
         (0.10, 3.86, 2.00, 1.04), (0.80, 3.72, 2.28, 0.90)]
CHEST_CAPS = (0.28, 0.40)          # front (into the neck), back (into the hips)
CHEST_SPLIT = -0.30                # slate above this height fraction on the chest sides
HIPS = [(0.80, 3.62, 2.30, 0.82), (1.30, 3.75, 2.10, 0.92), (1.95, 3.72, 2.05, 0.95),
        (2.50, 3.55, 2.20, 0.85), (2.80, 3.32, 2.45, 0.60)]
HIPS_CAPS = (0.40, 0.20)
HIPS_SPLIT = -0.10
SKULL = [(-2.85, 3.68, 2.62, 0.62), (-3.20, 3.78, 2.56, 0.72), (-3.60, 3.66, 2.60, 0.64),
         (-3.90, 3.38, 2.66, 0.44), (-4.35, 3.22, 2.68, 0.34), (-4.78, 3.12, 2.74, 0.26)]
SKULL_CAPS = (0.30, 0.06)
JAW = [(-3.40, 2.84, 2.58, 0.34), (-3.80, 2.72, 2.42, 0.31), (-4.25, 2.68, 2.44, 0.25),
       (-4.58, 2.66, 2.50, 0.18)]
JAW_CAPS = (0.22, 0.05)
NECK = [((0, 3.10, -1.75), 0.62, 0.60), ((0, 3.10, -2.30), 0.60, 0.58), ((0, 3.15, -2.85), 0.58, 0.56)]
NECK_CAPS = (0.30, 0.30)
CREST = [(-1.25, 0.70), (-0.80, 0.66), (-0.30, 0.60), (0.20, 0.52)]   # (z, height) on the chest
HIP_CREST = [(0.85, 0.40), (1.40, 0.34), (1.95, 0.28)]                              # on the hips
EYE_ROLL = 15.0          # degrees, inner corner down


# =============================================================================================
# Geometry builder: faces carry a swatch name; vertices are Roblox-space Vectors.
# =============================================================================================
class Geo:
    def __init__(self):
        self.verts = []
        self.faces = []       # (idx tuple, swatch)

    def v(self, p):
        self.verts.append(Vector(p))
        return len(self.verts) - 1

    def f(self, idx, sw):
        self.faces.append((tuple(idx), sw))

    def tube(self, rings, sides, colour, caps=(None, None), rot=math.pi / 2):
        """rings: [(centre, side_vec, up_vec)], radii baked into the vectors; side_vec None = a point.
        caps: (start, end) depth of a rounded cap past the end ring (0/None = flat, 'open' = none).
        colour(i, centre, h) -> swatch; h = face height around the ring (-1 bottom .. 1 top)."""
        rings = list(rings)
        def tangent(k):
            a, b = Vector(rings[max(k - 1, 0)][0]), Vector(rings[min(k + 1, len(rings) - 1)][0])
            return (b - a).normalized()
        # rounded caps: two shrinking rings and a point along the tangent
        for end in (0, 1):
            d = caps[end]
            if not d or d == "open":
                continue
            k = 0 if end == 0 else len(rings) - 1
            c, s, u = rings[k]
            t = tangent(k) * (-1 if end == 0 else 1)
            extra = [(Vector(c) + t * d * 0.62, s * 0.79, u * 0.79), (Vector(c) + t * d * 0.92, s * 0.40, u * 0.40),
                     (Vector(c) + t * d, None, None)]
            rings = (list(reversed(extra)) + rings) if end == 0 else (rings + extra)
        idx = []
        for c, s, u in rings:
            c = Vector(c)
            if s is None:
                idx.append([self.v(c)])
            else:
                idx.append([self.v(c + s * math.cos(rot + 2 * math.pi * j / sides) +
                                   u * math.sin(rot + 2 * math.pi * j / sides)) for j in range(sides)])
        n0 = 3 if caps[0] and caps[0] != "open" else 0          # bands belonging to the start cap
        n1 = 3 if caps[1] and caps[1] != "open" else 0
        bands = len(idx) - 1
        cols = {}
        order = [i for i in range(bands) if n0 <= i < bands - n1] + [i for i in range(bands) if not n0 <= i < bands - n1]
        for i in order:
            a, b = idx[i], idx[i + 1]
            n = max(len(a), len(b))
            ca = Vector(rings[i][0])
            ua = rings[i][2] if rings[i][2] is not None else rings[i + 1][2]
            ua = ua if ua is not None else Vector((0, 1, 0))
            for j in range(n):
                k = (j + 1) % n
                if len(a) == 1:
                    q = (a[0], b[k], b[j])
                elif len(b) == 1:
                    q = (a[j], a[k], b[0])
                else:
                    q = (a[j], a[k], b[k], b[j])
                cen = sum((self.verts[x] for x in q), Vector()) / len(q)
                if i < n0 and (n0, j) in cols:
                    sw = cols[(n0, j)]                      # caps take the colour of the band they close
                elif i >= bands - n1 and (bands - n1 - 1, j) in cols:
                    sw = cols[(bands - n1 - 1, j)]
                else:
                    cb = (ca + Vector(rings[i + 1][0])) / 2
                    h = (cen - cb).normalized().dot(ua.normalized()) if (cen - cb).length > 1e-6 else 0.0
                    sw = colour(i, cen, h)
                cols[(i, j)] = sw
                self.f(q, sw)
        for end, ring in ((0, idx[0]), (1, idx[-1])):
            if len(ring) > 2 and caps[end] != "open":
                cen = sum((self.verts[x] for x in ring), Vector()) / len(ring)
                self.f(tuple(reversed(ring)) if end == 0 else tuple(ring), colour(-1, cen, 0.0))
        return idx

    def spike(self, base, vec, width, thick, sw, bend=(0, 0, 0), across=None, sides=4, belly=0.72):
        """A fur tuft / claw / tooth: a flattened cone from `base` along `vec`, its tip pushed by `bend`."""
        base, vec, bend = Vector(base), Vector(vec), Vector(bend)
        d = vec.normalized()
        a = Vector(across) if across is not None else (Vector((0, 1, 0)) if abs(d.y) < 0.85 else Vector((1, 0, 0)))
        a = (a - d * a.dot(d)).normalized()
        n = d.cross(a).normalized()
        def ringat(c, s):
            return [self.v(c + a * (width / 2 * s) * math.cos(2 * math.pi * j / sides + math.pi / sides) +
                           n * (thick / 2 * s) * math.sin(2 * math.pi * j / sides + math.pi / sides))
                    for j in range(sides)]
        r0 = ringat(base, 1.0)
        r1 = ringat(base + vec * 0.45 + bend * 0.25, belly)
        tip = self.v(base + vec + bend)
        for j in range(sides):
            k = (j + 1) % sides
            self.f((r0[j], r0[k], r1[k], r1[j]), sw)
            self.f((r1[j], r1[k], tip), sw)
        self.f(tuple(reversed(r0)), sw)


def stations(tab):
    """(z, top, bottom, half width) stations -> rings along -Z/+Z (side +X, up +Y)."""
    return [((0, (t + b) / 2, z), Vector((hw, 0, 0)), Vector((0, (t - b) / 2, 0))) for z, t, b, hw in tab]


def path(points):
    """[(centre, r_side, r_other)] along a path -> rings perpendicular to it (side kept along X)."""
    out = []
    n = len(points)
    for i, (c, rs, ro) in enumerate(points):
        c = Vector(c)
        if rs <= 0:
            out.append((c, None, None))
            continue
        a, b = Vector(points[max(i - 1, 0)][0]), Vector(points[min(i + 1, n - 1)][0])
        t = (b - a).normalized()
        s = Vector((1, 0, 0))
        s = (s - t * s.dot(t)).normalized()
        u = t.cross(s).normalized()
        if (abs(t.y) < 0.7 and u.y < 0) or (abs(t.y) >= 0.7 and u.z < 0):
            u = -u     # "up" is +Y on level tubes; on near-vertical ones it points back (+Z)
        out.append((c, s * rs, u * ro))
    return out


def lerp(tab, z, k):
    """Interpolate column k of a station table at z."""
    tab = sorted(tab)
    if z <= tab[0][0]:
        return tab[0][k]
    for a, b in zip(tab, tab[1:]):
        if z <= b[0]:
            return a[k] + (b[k] - a[k]) * (z - a[0]) / (b[0] - a[0])
    return tab[-1][k]


def jag(cen, amp=0.14):
    """A deterministic zigzag for the slate/cream border."""
    t = (cen.z * 2.4 + abs(cen.x) * 0.8) % 1.0    # a sawtooth along the body, so the border zigzags
    return amp * (1.6 * abs(t - 0.5) * 2 - 0.8)


# =============================================================================================
# Segments: one function per part; each returns a Geo
# =============================================================================================
def two_tone(split, cream="cream", amp=0.14):
    def col(i, cen, h):
        return "slate" if h > split + jag(cen, amp) else cream
    return col


def flank_tufts(g, tab, zs, size):
    for z in zs:
        top, bot, hw = lerp(tab, z, 1), lerp(tab, z, 2), lerp(tab, z, 3)
        y = (top + bot) / 2 + (top - bot) / 2 * 0.0
        for sx in (-1, 1):
            g.spike((sx * hw * 0.93, y, z), (sx * 0.10, -size, 0.12), 0.46, 0.12, "slate", bend=(0, 0, 0.03))


def seg_chest():
    g = Geo()
    g.tube(stations(CHEST), SIDES_BODY, two_tone(CHEST_SPLIT), caps=(CHEST_CAPS[0], CHEST_CAPS[1]))
    # crest: slate spikes peaking at y 4.4 over z -1.2..0.4, raking back
    for k, (z, h) in enumerate(CREST):
        top = lerp(CHEST, z, 1)
        g.spike((0, top - 0.12, z), (0, h, h * 0.55), 0.70, 0.20, "slatehi" if k % 2 else "slate",
                bend=(0, -0.03, 0.06), across=(1, 0, 0))
        if k % 2 == 0:
            for sx in (-1, 1):
                g.spike((sx * 0.42, top - 0.14, z + 0.1), (sx * 0.30, h * 0.62, h * 0.45), 0.48, 0.15, "slate",
                        across=(0, 0, 1))
    flank_tufts(g, CHEST, (-0.95, -0.35, 0.25), 0.40)
    # shoulder collars: slate tufts hanging over the top of each front leg
    for sx in (-1, 1):
        g.spike((sx * 0.92, 2.80, -1.55), (sx * 0.20, -0.45, -0.05), 0.42, 0.14, "slate", across=(0, 0, 1))
        g.spike((sx * 0.95, 2.70, -1.05), (sx * 0.18, -0.42, 0.10), 0.40, 0.14, "slatehi", across=(0, 0, 1))
    # cream-shade bib tufts under the chest front
    for sx in (-0.28, 0.0, 0.28):
        g.spike((sx, 2.10, -1.55), (sx * 0.3, -0.38, -0.08), 0.32, 0.12, "shade", across=(1, 0, 0))
    return g


def seg_hips():
    g = Geo()
    g.tube(stations(HIPS), SIDES_BODY, two_tone(HIPS_SPLIT), caps=HIPS_CAPS)
    for k, (z, h) in enumerate(HIP_CREST):
        top = lerp(HIPS, z, 1)
        g.spike((0, top - 0.10, z), (0, h, h * 0.7), 0.50, 0.16, "slate" if k % 2 else "slatehi",
                across=(1, 0, 0))
    flank_tufts(g, HIPS, (1.15, 1.85), 0.36)
    # hip collars over the thigh tops, and the tail-root collar
    for sx in (-1, 1):
        g.spike((sx * 0.92, 2.95, 1.75), (sx * 0.16, -0.42, 0.18), 0.42, 0.14, "slate", across=(0, 0, 1))
        g.spike((sx * 0.85, 3.05, 2.45), (sx * 0.16, -0.30, 0.30), 0.36, 0.13, "slatehi", across=(0, 0, 1))
        g.spike((sx * 0.25, 3.45, 2.62), (sx * 0.18, 0.12, 0.38), 0.28, 0.11, "slate", across=(0, 1, 0))
    g.spike((0, 3.55, 2.55), (0, 0.18, 0.40), 0.30, 0.11, "slate", across=(1, 0, 0))
    return g


def seg_neck():
    g = Geo()
    g.tube(path(NECK), SIDES_BODY, two_tone(-0.25), caps=NECK_CAPS)
    # the mane ruff: two collars of tufts radiating out and back; slate above, a cream bib below
    for ring_z, scale, n in ((-2.15, 1.0, 9), (-2.65, 0.65, 7)):
        for k in range(n):
            a = math.pi / 2 + 2 * math.pi * k / n
            dx, dy = math.cos(a), math.sin(a)
            base = Vector((dx * 0.50, 3.10 + dy * 0.48, ring_z))
            reach = (0.90 if dy > 0.5 else 0.85 if dy > -0.3 else 0.55) * scale
            vec = Vector((dx * reach * 1.05, dy * reach + 0.12 * scale, 0.45 * scale + 0.15))
            sw = "shade" if dy < -0.55 else ("slatehi" if k % 3 == 1 else "slate")
            g.spike(base, vec, 0.58 * scale + 0.08, 0.17, sw, bend=(0, -0.05 * scale, 0.05),
                    across=(-dy, dx, 0))
    return g


def seg_skull():
    g = Geo()
    def col(i, cen, h):
        snout = cen.z < -3.85
        if h < -0.86 and cen.z < -3.0:
            return "mouth"                       # palate, seen when the jaw drops
        if h < -0.50 and snout:
            return "dark"                        # lip line
        slate_line = 0.05 + (0.55 if snout else 0.0) + jag(cen, 0.18)
        return "slate" if h > slate_line and cen.z > -4.15 else "cream"
    g.tube(stations(SKULL), SIDES_BODY, col, caps=SKULL_CAPS)
    # nose: a dark chunky wedge on the muzzle tip
    g.spike((0, 3.08, -4.62), (0, 0.02, -0.30), 0.34, 0.24, "dark", across=(1, 0, 0), belly=0.9)
    # brow ridges for the scowl (over the eyes, slanting down toward the nose)
    for sx in (-1, 1):
        g.spike((sx * 0.16, 3.50, -3.72), (sx * 0.30, -0.10, -0.10), 0.22, 0.10, "slate", across=(0, 1, 0))
    # cheek tufts: slate and cream-shade spikes swept back off the cheeks
    for sx in (-1, 1):
        g.spike((sx * 0.62, 3.05, -3.25), (sx * 0.38, -0.05, 0.38), 0.34, 0.12, "slate", across=(0, 1, 0))
        g.spike((sx * 0.55, 2.75, -3.35), (sx * 0.34, -0.22, 0.30), 0.30, 0.11, "shade", across=(0, 1, 0))
        g.spike((sx * 0.50, 3.45, -3.05), (sx * 0.30, 0.12, 0.40), 0.30, 0.11, "slatehi", across=(0, 1, 0))
    # upper teeth: big canines and a zigzag row along the lip
    for sx in (-1, 1):
        g.spike((sx * 0.24, 2.76, -4.52), (0, -0.34, 0.01), 0.11, 0.10, "ivory", sides=3, belly=0.55)
        for k, z in enumerate((-3.95, -4.12, -4.29)):
            x = sx * (0.38 - 0.03 * k)
            g.spike((x, 2.72, z), (0, -0.16, 0), 0.09, 0.07, "ivory", sides=3, belly=0.55)
    return g


def seg_jaw():
    g = Geo()
    def col(i, cen, h):
        if h > 0.70 and cen.z < -3.5:
            return "mouth"      # tongue/inner mouth
        if h > 0.35 and cen.z < -3.6:
            return "dark"       # lower lip
        return "cream"
    g.tube(stations(JAW), SIDES_LIMB, col, caps=JAW_CAPS)
    for sx in (-1, 1):
        g.spike((sx * 0.20, 2.62, -4.42), (sx * 0.03, 0.30, -0.02), 0.10, 0.09, "ivory", sides=3, belly=0.55)
        for k, z in enumerate((-3.85, -4.05, -4.22)):
            g.spike((sx * (0.29 - 0.03 * k), 2.66, z), (0, 0.13, 0), 0.08, 0.06, "ivory", sides=3, belly=0.55)
    return g


def seg_ear(sx):
    g = Geo()
    tilt = math.radians(15)
    base = Vector((sx * 0.45, 3.50, -3.12))
    tip = Vector((sx * (0.45 + 0.75 * math.tan(tilt)), 4.45, -3.05))
    w, t = 0.21, 0.12
    corners = [base + Vector((-w, 0, -t)), base + Vector((w, 0, -t)), base + Vector((w, 0, t)),
               base + Vector((-w, 0, t))]
    bi = [g.v(p) for p in corners]
    ti = g.v(tip)
    g.f((bi[1], bi[0], ti), "slate")     # front (-Z)
    g.f((bi[2], bi[1], ti), "slate")
    g.f((bi[3], bi[2], ti), "slate")
    g.f((bi[0], bi[3], ti), "slate")
    g.f((bi[0], bi[1], bi[2], bi[3]), "slate")
    # inner ear: a dark-red triangle just proud of the front face
    fn = ((corners[1] - corners[0]).cross(tip - corners[0])).normalized()
    if fn.z > 0:
        fn = -fn
    inner = [base + Vector((-w * 0.55, 0.12, -t)) + fn * 0.02, base + Vector((w * 0.55, 0.12, -t)) + fn * 0.02,
             tip + (base - tip) * 0.18 + fn * 0.02]
    ii = [g.v(p) for p in inner]
    jj = [g.v(p - fn * 0.015) for p in inner]     # a thin wedge, so it stays closed and faces out
    g.f((ii[1], ii[0], ii[2]), "mouth")
    g.f((jj[0], jj[1], jj[2]), "mouth")
    for a, b in ((0, 1), (1, 2), (2, 0)):
        g.f((ii[a], ii[b], jj[b], jj[a]), "mouth")
    return g


def seg_eye(sx):
    g = Geo()
    c = Vector((sx * 0.38, 3.30, -3.98))
    roll = math.radians(EYE_ROLL)
    a = Vector((math.cos(roll), sx * math.sin(roll), 0))   # long axis: outer corner up
    a.x *= sx
    nrm = Vector((sx * 0.45, 0.15, -0.88)).normalized()    # looks forward and a little out
    a = (a - nrm * a.dot(nrm)).normalized()
    b = nrm.cross(a).normalized()
    if b.y < 0:
        b = -b
    quad = [c + a * 0.15, c + b * 0.07, c - a * 0.15, c - b * 0.05]
    front = [g.v(p + nrm * 0.03) for p in quad]
    back = [g.v(p - nrm * 0.05) for p in quad]
    g.f(front, "eye")
    g.f(tuple(reversed(back)), "eye")
    for j in range(4):
        k = (j + 1) % 4
        g.f((back[j], back[k], front[k], front[j]), "eye")
    return g


def seg_upper_front(sx):
    g = Geo()
    x = sx * 0.72
    pts = [((sx * 0.70, 2.45, -1.30), 0.34, 0.40), ((x, 1.90, -1.32), 0.27, 0.32), ((x, 1.35, -1.25), 0.21, 0.24)]
    def col(i, cen, h):
        return "slate" if cen.y > 2.05 + jag(cen, 0.12) else "cream"
    g.tube(path(pts), SIDES_LIMB, col, caps=(0.30, 0.21))
    g.spike((x + sx * 0.05, 1.50, -1.05), (sx * 0.04, -0.10, 0.40), 0.26, 0.10, "shade", across=(1, 0, 0))
    g.spike((x + sx * 0.10, 1.70, -1.10), (sx * 0.10, -0.08, 0.34), 0.22, 0.09, "cream", across=(1, 0, 0))
    return g


def seg_lower_front(sx):
    g = Geo()
    x = sx * 0.72
    pts = [((x, 1.35, -1.25), 0.19, 0.21), ((x, 0.80, -1.30), 0.16, 0.18), ((x, 0.32, -1.35), 0.14, 0.15)]
    g.tube(path(pts), SIDES_LIMB, lambda i, c, h: "cream", caps=(0.20, 0.15))
    return g


def paw(g, x, heel_z, toe_z, wrist, sx, front):
    """A chunky paw block on the ground, dark pads under, four big claws in front."""
    hz = heel_z
    tab = [(hz, 0.34, 0.0, 0.25), ((hz + toe_z) / 2, 0.30, 0.0, 0.32), (toe_z, 0.22, 0.0, 0.29)]
    rings = [((x, (t + b) / 2, z), Vector((hw, 0, 0)), Vector((0, (t - b) / 2, 0))) for z, t, b, hw in tab]
    def col(i, cen, h):
        return "dark" if h < -0.85 else "cream"
    g.tube(rings, SIDES_LIMB, col, caps=(0.10, 0.10))
    for k in range(4):
        cx = x + (k - 1.5) * 0.14
        g.spike((cx, 0.13, toe_z - 0.04), (0, -0.08, -0.30), 0.09, 0.11, "ivory", bend=(0, -0.05, 0), sides=3, belly=0.6)


def seg_paw_front(sx):
    g = Geo()
    x = sx * 0.72
    knob = [((x, 0.32, -1.35), 0.15, 0.16), ((x, 0.12, -1.38), 0.17, 0.17)]
    g.tube(path(knob), SIDES_LIMB, lambda i, c, h: "cream", caps=(0.20, "open"))
    paw(g, x, -1.20, -1.98, None, sx, True)
    return g


def seg_upper_back(sx):
    g = Geo()
    x = sx * 0.75
    pts = [((sx * 0.70, 2.50, 2.10), 0.42, 0.52), ((x, 2.00, 2.05), 0.38, 0.48), ((x, 1.35, 1.80), 0.22, 0.25)]
    def col(i, cen, h):
        return "slate" if cen.y > 2.15 + jag(cen, 0.14) else "cream"
    g.tube(path(pts), SIDES_LIMB, col, caps=(0.35, 0.22))
    return g


def seg_lower_back(sx):
    g = Geo()
    x = sx * 0.75
    pts = [((x, 1.35, 1.80), 0.19, 0.21), ((x, 0.98, 2.05), 0.15, 0.17), ((x, 0.62, 2.30), 0.13, 0.15)]
    g.tube(path(pts), SIDES_LIMB, lambda i, c, h: "cream", caps=(0.20, 0.15))
    return g


def seg_paw_back(sx):
    g = Geo()
    x = sx * 0.75
    meta = [((x, 0.62, 2.30), 0.14, 0.15), ((x, 0.18, 2.28), 0.16, 0.16)]
    g.tube(path(meta), SIDES_LIMB, lambda i, c, h: "cream", caps=(0.18, "open"))
    paw(g, x, 2.52, 1.84, None, sx, False)
    g.spike((x, 0.70, 2.40), (0, -0.10, 0.36), 0.24, 0.09, "shade", across=(1, 0, 0))   # hock tuft
    return g


def tail_colour(i, cen, h):
    return "slate" if h > -0.40 + jag(cen, 0.10) else "cream"


def tail_tufts(g, pts, ks):
    for k in ks:
        c = Vector(pts[k][0])
        nxt = Vector(pts[min(k + 1, len(pts) - 1)][0])
        back = (nxt - c).normalized()
        r = pts[k][1]
        for sx, sy, sw in ((0, 1, "slatehi"), (-1, 0.2, "slate"), (1, 0.2, "slate")):
            base = c + Vector((sx * r * 0.65, sy * r * 0.65, 0))
            g.spike(base, back * 0.48 + Vector((sx * 0.20, sy * 0.14, 0)), 0.42, 0.13, sw, across=(-sy, sx, 0))


def seg_tail_base():
    g = Geo()
    pts = [((0, 3.30, 2.75), 0.30, 0.30), ((0, 3.25, 3.25), 0.34, 0.34), ((0, 3.25, 3.75), 0.36, 0.36)]
    g.tube(path(pts), SIDES_LIMB, tail_colour, caps=(0.25, 0.32))
    tail_tufts(g, pts, [1])
    return g


def seg_tail_mid():
    g = Geo()
    pts = [((0, 3.25, 3.75), 0.36, 0.36), ((0, 3.30, 4.30), 0.42, 0.42), ((0, 3.40, 4.85), 0.36, 0.36)]
    g.tube(path(pts), SIDES_LIMB, tail_colour, caps=(0.30, 0.32))
    tail_tufts(g, pts, [0, 1])
    return g


def seg_tail_tip():
    g = Geo()
    pts = [((0, 3.40, 4.85), 0.34, 0.34), ((0, 3.62, 5.25), 0.30, 0.30), ((0, 3.95, 5.50), 0.20, 0.20),
           ((0, 4.22, 5.58), 0.0, 0.0)]
    g.tube(path(pts), SIDES_LIMB, tail_colour, caps=(0.30, None))
    tail_tufts(g, pts, [1])
    for vx, vy, vz in ((0, 0.40, 0.06), (-0.16, 0.30, 0.14), (0.16, 0.30, 0.14), (0, 0.22, 0.24)):
        g.spike((0, 4.0, 5.5), (vx, vy, vz), 0.20, 0.09, "slatehi", across=(1, 0, 0))
    return g


SEGMENTS = {"Hips": seg_hips, "Chest": seg_chest, "Neck": seg_neck, "Skull": seg_skull, "Jaw": seg_jaw,
            "TailBase": seg_tail_base, "TailMid": seg_tail_mid, "TailTip": seg_tail_tip}
for _s, _x in (("L", -1), ("R", 1)):
    SEGMENTS.update({
        "Ear" + _s: (lambda sx: lambda: seg_ear(sx))(_x),
        "Eye" + _s: (lambda sx: lambda: seg_eye(sx))(_x),
        "UpperLegF" + _s: (lambda sx: lambda: seg_upper_front(sx))(_x),
        "LowerLegF" + _s: (lambda sx: lambda: seg_lower_front(sx))(_x),
        "PawF" + _s: (lambda sx: lambda: seg_paw_front(sx))(_x),
        "UpperLegB" + _s: (lambda sx: lambda: seg_upper_back(sx))(_x),
        "LowerLegB" + _s: (lambda sx: lambda: seg_lower_back(sx))(_x),
        "PawB" + _s: (lambda sx: lambda: seg_paw_back(sx))(_x),
    })


# =============================================================================================
# Objects, export, previews
# =============================================================================================
def make_object(name, g, mat, eye_mat):
    for o in [bpy.data.objects.get(name)]:
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
    if bpy.data.meshes.get(name):
        bpy.data.meshes.remove(bpy.data.meshes[name])
    bm = bmesh.new()
    bv = [bm.verts.new(B(p)) for p in g.verts]
    uvl = bm.loops.layers.uv.new("UVMap")
    swl = bm.faces.layers.int.new("sw")
    for idx, sw in g.faces:
        try:
            f = bm.faces.new([bv[i] for i in idx])
        except ValueError:
            continue
        f[swl] = list(SWATCHES).index(sw)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    names = list(SWATCHES)
    for f in bm.faces:
        f.smooth = True
        uv = swatch_uv(names[f[swl]])
        for lp in f.loops:
            lp[uvl].uv = uv
    for e in bm.edges:
        e.smooth = not (e.is_boundary or (e.is_manifold and e.calc_face_angle(0) > math.radians(SHARP_DEG)))
    # origin at the bounding-box centre
    mn = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), min(v.co.z for v in bm.verts)))
    mx = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), max(v.co.z for v in bm.verts)))
    centre = (mn + mx) / 2
    for v in bm.verts:
        v.co -= centre
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.location = centre
    o.data.materials.append(eye_mat if name.startswith("Eye") else mat)
    return o


def build():
    scene = rp.use_scene(NAME)
    for o in list(scene.collection.objects):
        if o.type in {"MESH", "ARMATURE", "EMPTY"}:
            bpy.data.objects.remove(o, do_unlink=True)
    img = make_palette()
    mat = palette_material(img)
    eye_mat = rp.preview_material("SpiritWolfEye", linear(EYE_HEX), emit=4.0)
    objs = {name: make_object(name, fn(), mat, eye_mat) for name, fn in SEGMENTS.items()}
    return scene, objs


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def rest_matrices(objs):
    return {n: Matrix.Translation(o.location) for n, o in objs.items()}


def pose(objs, rest, rot):
    """rot: {joint: (rx, ry, rz) degrees in model space}; turns each part's subtree about the pivots."""
    for n, o in objs.items():
        m = Matrix.Identity(4)
        for j in chain(n):
            if j in rot:
                p = B(JOINTS[j][0])
                rx, ry, rz = (math.radians(a) for a in rot[j])
                # model-space Euler -> Blender: model X = Blender X, model Y = Blender Z, model Z = Blender -Y
                r = (Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(ry, 4, "Z") @ Matrix.Rotation(-rz, 4, "Y"))
                m = m @ Matrix.Translation(p) @ r @ Matrix.Translation(-p)
        o.matrix_world = m @ rest[n]
    bpy.context.view_layer.update()


def export(objs, rest):
    pose(objs, rest, {})
    ol = list(objs.values())
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in ol:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ol[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, NAME + ".fbx"), use_selection=True,
                             object_types={"MESH"}, apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="EDGE", bake_space_transform=True,
                             path_mode="STRIP")
    meshes = {}
    for n, o in objs.items():
        c, s = rp.bounds(o)
        rc = [round(c[0], 3), round(c[2], 3), round(-c[1], 3)]
        rs = [s[0], s[2], s[1]]
        meshes[n] = dict(tris=tris(o), center=c, size=s, roblox_center=rc, roblox_size=rs,
                         joint=PART_JOINT.get(n) or ("Skull (welded)" if n.startswith("Eye") else None),
                         textured=not n.startswith("Eye"))
        if n in SPEC_BOXES:
            meshes[n]["spec_center"], meshes[n]["spec_size"] = SPEC_BOXES[n]
    c, s = rp.bounds(ol)
    data = dict(
        units="1 Blender unit = 1 stud. center/size in Blender axes (x, y forward, z up); roblox_center/"
              "roblox_size in model space (ground Y 0, faces -Z, left -X): Size = (bx, bz, by), centre = "
              "(cx, cz, -cy), each MeshPart's rotation = CFrame.Angles(0, math.pi, 0) (the FBX import's frame).",
        total_tris=sum(m["tris"] for m in meshes.values()), center=c, size=s,
        roblox_size=[s[0], s[2], s[1]],
        palette=dict(file=PALETTE_FILE, swatches={k: v[0] for k, v in SWATCHES.items()},
                     note="64x64, 4x4 grid of 16 px cells, rows mirrored; every face's UVs sit on one cell centre"),
        joints={j: dict(pivot=list(p), part0=a, part1=b) for j, (p, a, b) in JOINTS.items()},
        meshes=meshes,
    )
    with open(os.path.join(OUT_DIR, NAME + ".json"), "w") as fh:
        json.dump(data, fh, indent=1)
    return data


# test poses: model-space degrees per joint (rotation about +X pitches the part's far end up when it
# points forward (-Z), down when it points back)
POSES = {
    "crouch": {"JointRoot": (0, 0, 0), "JointSpine": (-6, 0, 0), "JointNeck": (8, 0, 0), "JointHead": (-10, 0, 0),
               "JointLegFL": (-35, 0, 0), "JointElbowFL": (70, 0, 0), "JointWristFL": (-35, 0, 0),
               "JointLegFR": (-35, 0, 0), "JointElbowFR": (70, 0, 0), "JointWristFR": (-35, 0, 0),
               "JointLegBL": (40, 0, 0), "JointKneeBL": (-60, 0, 0), "JointHockBL": (25, 0, 0),
               "JointLegBR": (40, 0, 0), "JointKneeBR": (-60, 0, 0), "JointHockBR": (25, 0, 0),
               "JointTail": (-20, 0, 0)},
    "leap": {"JointSpine": (4, 0, 0), "JointHead": (8, 0, 0), "JointJaw": (-25, 0, 0),
             "JointLegFL": (60, 0, 0), "JointElbowFL": (-15, 0, 0), "JointWristFL": (20, 0, 0),
             "JointLegFR": (55, 0, 0), "JointElbowFR": (-10, 0, 0), "JointWristFR": (20, 0, 0),
             "JointLegBL": (-60, 0, 0), "JointKneeBL": (20, 0, 0), "JointHockBL": (30, 0, 0),
             "JointLegBR": (-55, 0, 0), "JointKneeBR": (15, 0, 0), "JointHockBR": (30, 0, 0),
             "JointTail": (-10, 0, 0)},
    "jaw_open": {"JointJaw": (-35, 0, 0), "JointHead": (10, 0, 0), "JointEarL": (0, 0, 20),
                 "JointEarR": (0, 0, -20)},
    "tail_curl": {"JointTail": (35, 0, 0), "JointTail2": (40, 15, 0), "JointTail3": (45, 15, 0),
                  "JointNeck": (0, 15, 0), "JointHead": (0, 15, 0)},
}


SWEEP_GROUPS = {   # joint sweeps: each group turned +-SWEEP_DEG about X (and the spine/neck about Y too)
    "legs": ["JointLegFL", "JointElbowFL", "JointWristFL", "JointLegFR", "JointElbowFR", "JointWristFR",
             "JointLegBL", "JointKneeBL", "JointHockBL", "JointLegBR", "JointKneeBR", "JointHockBR"],
    "head": ["JointNeck", "JointHead", "JointEarL", "JointEarR"],
    "spine_tail": ["JointSpine", "JointTail", "JointTail2", "JointTail3"],
    "yaw": ["JointSpine", "JointNeck", "JointHead", "JointTail", "JointTail2"],
}


def sweep(group, sign):
    a = SWEEP_DEG * sign
    return {j: ((0, a, 0) if group == "yaw" else (a, 0, 0)) for j in SWEEP_GROUPS[group]}


def previews(scene, objs, rest):
    rp.setup_render(scene, res=(640, 640))
    pv = os.path.join(OUT_DIR, "preview")
    tgt = B((0, 2.3, 0.3))
    side, three_q = B((-16, 2.6, 0.3)), B((-10, 6.0, -9.0))
    pose(objs, rest, {})
    rp.render(scene, os.path.join(pv, "rest_side.png"), side, tgt, ortho=12)
    rp.render(scene, os.path.join(pv, "rest_front.png"), B((0, 2.4, -16)), B((0, 2.2, 0)), ortho=6.5)
    rp.render(scene, os.path.join(pv, "rest_34.png"), three_q, tgt, lens=50)
    rp.render(scene, os.path.join(pv, "rest_back34.png"), B((9, 6.0, 10)), tgt, lens=50)
    rp.render(scene, os.path.join(pv, "rest_close.png"), B((-2.6, 3.8, -7.4)), B((0, 3.1, -3.8)), lens=50)
    rp.render(scene, os.path.join(pv, "rest_top.png"), B((0, 16, 0.3)), B((0, 0, 0.3)), ortho=12)
    for name, rot in POSES.items():
        pose(objs, rest, rot)
        rp.render(scene, os.path.join(pv, name + "_side.png"), side, tgt, ortho=12)
        rp.render(scene, os.path.join(pv, name + "_34.png"), three_q, tgt, lens=50)
    for group in SWEEP_GROUPS:
        for sign, tag in ((1, "plus"), (-1, "minus")):
            pose(objs, rest, sweep(group, sign))
            if group == "yaw":
                rp.render(scene, os.path.join(pv, "sweep_%s_%s.png" % (group, tag)), B((0, 16, 0.3)),
                          B((0, 0, 0.3)), ortho=13)
            else:
                rp.render(scene, os.path.join(pv, "sweep_%s_%s.png" % (group, tag)), side, tgt, ortho=13)
            rp.render(scene, os.path.join(pv, "sweep_%s_%s_34.png" % (group, tag)), three_q, tgt, lens=45)
    pose(objs, rest, {})


def main():
    scene, objs = build()
    rest = rest_matrices(objs)
    data = export(objs, rest)
    if RENDER_PREVIEWS:
        previews(scene, objs, rest)
    rp.save_blend(scene, os.path.join(OUT_DIR, NAME + ".blend"))
    print("tris", data["total_tris"], {k: v["tris"] for k, v in data["meshes"].items()}, "size", data["roblox_size"])


if __name__ == "__main__":
    main()
