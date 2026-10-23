r"""Stone Spirit cosmetics: three directions of floating jade-veined rock shards and stone plates
for the player's R6 avatar (brief: art/player/cosmetics/briefs/stone-spirit.md, reference panel 5
of docs/reference/race_cosmetics.png).

  Peak   (hero: two big stacked-stone pauldrons with floating chips; a small shard arc behind)
         StonePeakPlateL / StonePeakPlateR (Left/RightShoulderAttachment), StonePeakShards (NeckAttachment)
  Orbit  (hero: a full ring of six shards circling the shoulders; quiet forearm bracers)
         StoneOrbitShards (NeckAttachment), StoneOrbitBracerL / R (Left/RightGripAttachment)
  Fist   (hero: heavy stone gauntlets over the forearms and fists; three small shards)
         StoneFistGauntletL / R (Left/RightGripAttachment), StoneFistShards (NeckAttachment)
Each accessory (set) is its own FBX + JSON beside this script, with its own armature.

Run in its own visible Blender window (tools/blender_live.sh):
    tools/blender_live.sh run stone-spirit art/player/cosmetics/stone-spirit/build_stone_spirit.py [RENDER=False] [EXPORT=False]
RENDER (default True) renders the sheet tiles into renders/; EXPORT (default True) writes the FBX,
JSON, shade PNG and StoneSpirit.blend. ONLY="Peak,Orbit" limits the directions built.
Then stitch the sheet with make_sheet.py.

Axes and units (the R6 reference, art/rig/r6_rigged.fbx, see art/rig/rig_preview.py):
  1 Blender unit = 1 stud. +X = the avatar's left (its left arm), it faces -Y, Z up.
  Hips z 0, torso z 0..2 (x -1..1), arms x 1..2 (left) and -2..-1 (right), z 0..2, head top z 3.1.
  NeckAttachment          = (0, 0, 2)       Torso centre + Roblox (0, 1, 0)
  LeftShoulderAttachment  = (1.5, 0, 2)     Left Arm centre + Roblox (0, 1, 0): top of the arm
  LeftGripAttachment      = (1.5, 0, 0)     Left Arm centre + Roblox (0, -1, 0): bottom of the arm
  (Right ones at x -1.5.) Built in avatar space; export moves each set so its attachment is the
  origin. A Blender point (x, y, z) is Roblox (-x, z, y) from the attachment (fox README).

Recolour contract: two regions, each its own mesh object (one MeshPart, one Color): Rock
(every rock body, material Stone_Rock) and Jade (the glowing veins, material Stone_Jade, Neon in
Roblox). Depth shading is a greyscale ramp (stone_shade.png) on UV V: rock undersides darker, so tinting by Color still works.

Rig (one armature per set, Root = the attachment point, never keyed):
  Plates/bracers/gauntlets: Root -> Plate (the stone and its veins, rigid), Root -> Chip1.. (each
    floating chip, rigid: bob them by translating the bone).
  Shards: Root -> Orbit (head at the ring centre, pointing along the ring's axis: rotate it about
    its own Y to spin the ring, or sway it for the Peak arc) -> Shard1..N (head at each shard's
    centre: bob/tumble each one). Every vertex is weighted 1.0 to one bone: rock doesn't bend.

Stone is crisp, faceted, chunky: convex hulls of a few dozen points on a jittered (super)ellipsoid,
flat-shaded past the house 28 degree crease. Veins are closed strips laid along zigzag crack walks
projected onto the stone surface, sunk half into it, so no single-sided faces.
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "art", "rig"))
import rig_preview as rp  # noqa: E402

RENDER = globals().get("RENDER", True)
EXPORT = globals().get("EXPORT", True)
ONLY = globals().get("ONLY")
ONLY = set(ONLY.split(",")) if isinstance(ONLY, str) else ONLY

SCENE = "Cosmetics"
ROOT_COLLECTION = "StoneSpiritCosmetics"
STONE_SHARP_DEG = 28.0      # house crease: facets meeting sharper than this shade hard

NECK = Vector((0.0, 0.0, 2.0))
SHOULDER_L = Vector((1.5, 0.0, 2.0))
GRIP_L = Vector((1.5, 0.0, 0.0))
SHOULDER_PIVOT_L = Vector((1.5, 0.0, 1.5))   # R6 Left Shoulder joint (arm swings about X here)
ARM_INNER_X = 1.03          # nothing on an arm comes inside this x (the torso side is x 1.0)

# Colours (linear). Plain SmoothPlastic (Rock) and Neon (Jade) in Roblox; MeshPart.Color carries these.
MAT_PREFIX = "Stone_"          # material = prefix + region (Stone_Rock, Stone_Jade): unique across races
COLORS = {
    "Rock": (0.075, 0.08, 0.088, 1),    # dark basalt slate
    "Jade":  (0.04, 0.88, 0.42, 1),     # luminous jade green, a touch of teal
}
JADE_EMIT = 1.2                 # preview glow (Neon in Roblox)
SHADE_FILE = "stone_shade.png"  # greyscale ramp on UV V: V 0 = darkest (rock undersides)
SHADE_MIN = 0.6
SHADE_REACH = 0.5

# ---------------------------------------------------------------------------------------------
# Rock pieces. A hull: (centre, radii, points, jitter, seed, exponent). exponent 2 = ellipsoid,
# higher = boxier (sleeves that must contain the arm block). jitter is radial, as a fraction
# (outward only when exponent > 2 so sleeves never cut into the arm).
# CLAMP (inner_x, base_z_at_inner, base_z_drop, base_span): points are pushed to x >= inner_x
# (flush with the arm's inner face, clear of the torso when the arm swings) and up onto a base
# plane that drops base_z_drop over base_span outward, buried in the arm top.
# CRACKS: (start direction from the piece centre, heading, segments, segment length, turn deg,
# branches [(at fraction, angle deg, segments)]). Built for the LEFT side; the right is mirrored.
# ---------------------------------------------------------------------------------------------
PLATES = {
    # Peak: a mountain on each shoulder. A wide main slab, a lip dropping down the outer arm and a
    # smaller stacked crest on top, so it reads as layered stone. Hero of the Peak direction.
    "StonePeakPlate": dict(
        attach="LeftShoulderAttachment", at=SHOULDER_L, centre=(1.62, 0.0, 2.2),
        hulls=[((1.64, 0.0, 2.14), (0.80, 0.82, 0.50), 26, 0.10, 11, 2.0),
               ((2.12, 0.02, 1.86), (0.34, 0.70, 0.52), 16, 0.10, 12, 2.0),
               ((1.58, 0.06, 2.50), (0.44, 0.48, 0.26), 14, 0.12, 13, 2.0)],
        clamp=(ARM_INNER_X, 1.86, 0.45, 1.3), z_min=1.30,
        cracks=[((0.1, -0.25, 1.0), (0.9, -0.5, -0.3), 5, 0.24, 34, [(0.45, -55, 3)]),
                ((0.6, 0.45, 0.6), (0.1, 1.0, -0.6), 4, 0.24, 30, [(0.5, 50, 2)]),
                ((0.35, -1.0, 0.1), (0.3, 0.0, -1.0), 3, 0.2, 30, [])],
        vein_w=0.13,
        chips=[((2.40, -0.32, 2.88), 0.15, 21), ((2.08, 0.46, 3.12), 0.12, 22)]),
    # Orbit: a quiet bracer on each forearm (the ring is the hero): a boxy sleeve and a raised
    # outer slab with one crack.
    "StoneOrbitBracer": dict(
        attach="LeftGripAttachment", at=GRIP_L, centre=(1.6, 0.0, 0.66),
        hulls=[((1.53, 0.0, 0.66), (0.63, 0.64, 0.40), 26, 0.06, 31, 4.0),
               ((2.12, 0.0, 0.68), (0.16, 0.50, 0.40), 12, 0.08, 32, 2.0)],
        clamp=(ARM_INNER_X, -10, 0, 1), z_min=-10,
        cracks=[((1.0, -0.2, 0.25), (0.0, 0.3, -1.0), 3, 0.2, 35, [(0.5, 55, 2)])],
        vein_w=0.11, chips=[]),
    # Fist: heavy gauntlets: a big boxy sleeve to past the fist, a knuckle slab at the bottom, a
    # thick outer slab and a floating chip off each. Hero of the Fist direction.
    "StoneFistGauntlet": dict(
        attach="LeftGripAttachment", at=GRIP_L, centre=(1.65, 0.0, 0.55),
        hulls=[((1.60, 0.0, 0.62), (0.70, 0.74, 0.62), 30, 0.06, 41, 4.0),
               ((1.72, -0.12, 0.08), (0.62, 0.72, 0.24), 16, 0.08, 42, 2.0),
               ((2.30, 0.0, 0.66), (0.24, 0.66, 0.52), 14, 0.10, 43, 2.0)],
        clamp=(ARM_INNER_X, -10, 0, 1), z_min=-0.12,
        cracks=[((1.0, 0.0, 0.6), (0.0, -0.4, -1.0), 4, 0.24, 34, [(0.4, 60, 2), (0.75, -60, 2)]),
                ((0.2, -1.0, 0.1), (0.3, 0.0, -1.0), 3, 0.22, 30, []),
                ((0.3, 1.0, 0.3), (0.3, 0.0, -1.0), 3, 0.22, 30, [])],
        vein_w=0.14,
        chips=[((2.62, -0.35, 1.25), 0.13, 51)]),
}

# Shard rings: centre z, radius, tilt (deg, about X: + tips the front of the ring up), and the shards:
# (angle deg around the ring: 0 = the avatar's front, +90 = its left), height offset, size, seed.
# Shard size is the half-height of a chunky crystal (aspect at most ~1.4: not tall and thin).
SHARDS = {
    # Peak: a crescent of five shards behind the shoulders and head, the middle one highest.
    "StonePeakShards": dict(z=2.75, radius=1.35, tilt=0, spin="sway", shards=[
        (128, 0.10, 0.26, 61), (154, 0.38, 0.32, 62), (180, 0.55, 0.40, 63),
        (206, 0.38, 0.30, 64), (232, 0.10, 0.25, 65)]),
    # Orbit: a full ring of six shards around the shoulders, sizes and heights varied so it's not
    # a clockface; tilted a little so the front rides higher. Hero of the Orbit direction.
    "StoneOrbitShards": dict(z=2.8, radius=2.25, tilt=10, spin="spin", shards=[
        (30, 0.10, 0.42, 71), (90, -0.08, 0.35, 72), (150, 0.14, 0.48, 73),
        (210, -0.04, 0.37, 74), (270, 0.12, 0.44, 75), (330, -0.10, 0.33, 76)]),
    # Fist: three small shards circling high over the shoulders (the gauntlets are the hero).
    "StoneFistShards": dict(z=3.0, radius=1.75, tilt=0, spin="spin", shards=[
        (60, 0.0, 0.28, 81), (180, 0.12, 0.32, 82), (300, -0.05, 0.26, 83)]),
}
SHARD_POINTS = 11         # hull points per shard (chunky, few big facets)
SHARD_JITTER = 0.16
SHARD_VEIN_W = 0.10           # wide enough to read at game distance (0.06 was a hairline)

DIRECTIONS = {   # direction -> (label, hero, sets)
    "Peak": ("Peak", "big stacked-stone pauldrons, shard arc behind",
             ["StonePeakPlateL", "StonePeakPlateR", "StonePeakShards"]),
    "Orbit": ("Orbit", "full ring of six shards, quiet bracers",
              ["StoneOrbitShards", "StoneOrbitBracerL", "StoneOrbitBracerR"]),
    "Fist": ("Fist", "heavy stone gauntlets, three small shards",
             ["StoneFistGauntletL", "StoneFistGauntletR", "StoneFistShards"]),
}

VEIN_OUT = 0.03           # vein top stands this far off the stone
VEIN_IN = 0.05            # and sinks this far into it
CRACK_SUBSTEPS = 4        # projected samples per crack segment
ROOT_BONE_LEN = 0.25
PIECE_BONE_LEN = 0.3


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
    """Region material: colour x shade ramp; Jade also glows (Neon in Roblox)."""
    m = rp.preview_material(MAT_PREFIX + name, COLORS[name], emit=JADE_EMIT if name == "Jade" else 0.0)
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
    rgba_in = [s for s in mix.inputs if s.type == "RGBA"]
    rgba_in[0].default_value = COLORS[name]
    nt.links.new(tex.outputs["Color"], rgba_in[1])
    nt.links.new(next(s for s in mix.outputs if s.type == "RGBA"), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85 if name == "Rock" else 0.4
    return m


def new_object(name, bm, region, col, vfun):
    """Link bm as object `name` (region material, flat facets past the crease); vfun(co) = shade V."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = not (e.is_manifold and e.calc_face_angle(0) > math.radians(STONE_SHARP_DEG))
    for nm in (name,):
        if bpy.data.objects.get(nm):
            bpy.data.objects.remove(bpy.data.objects[nm], do_unlink=True)
        if bpy.data.meshes.get(nm):
            bpy.data.meshes.remove(bpy.data.meshes[nm])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    uv = me.uv_layers.new(name="UVMap")
    for loop in me.loops:
        uv.data[loop.index].uv = (0.5, min(0.995, max(0.005, vfun(me.vertices[loop.vertex_index].co))))
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    me.materials.append(bpy.data.materials.get(MAT_PREFIX + region) or material(region))
    o["region"] = region
    return o


def collection(name, parent):
    col = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if col.name not in parent.children:
        parent.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(col.children):
        for o in list(c.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(c)
    return col


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def height_shade(span):
    """Shade V from height: the lowest part of a rock darkest, white from hi up."""
    lo, hi = span
    return lambda co: smoothstep(lo, hi, co.z)


# ---------------------------------------------------------------------------------- rock ------
def fib_dirs(n, rng):
    out = []
    ga = math.pi * (3 - math.sqrt(5))
    off = rng.uniform(0, 2 * math.pi)
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(1 - z * z)
        a = i * ga + off
        d = Vector((r * math.cos(a), r * math.sin(a), z))
        d += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.18
        out.append(d.normalized())
    return out


def add_hull(bm, centre, radii, n, jitter, seed, expo=2.0, rot=None, clamp=None, z_min=None):
    """A faceted rock: the convex hull of n jittered points on a (super)ellipsoid."""
    rng = random.Random(seed)
    a, b, c = radii
    rot = rot or Matrix.Identity(3)
    pts = []
    for d in fib_dirs(n, rng):
        s = (abs(d.x) ** expo + abs(d.y) ** expo + abs(d.z) ** expo) ** (-1 / expo)   # superellipsoid radius
        j = rng.uniform(0, jitter) if expo > 2 else rng.uniform(-jitter, jitter)
        p = Vector((d.x * a, d.y * b, d.z * c)) * s * (1 + j)
        p = Vector(centre) + rot @ p
        if clamp:
            ix, bz, drop, span = clamp
            p.x = max(p.x, ix)
            p.z = max(p.z, bz - drop * min(1.0, max(0.0, (p.x - ix) / span)))
        if z_min is not None:
            p.z = max(p.z, z_min)
        pts.append(p)
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    drop = list({v for v in res["geom_interior"] + res["geom_unused"] if isinstance(v, bmesh.types.BMVert)})
    bmesh.ops.delete(bm, geom=drop, context="VERTS")
    return pts


# ---------------------------------------------------------------------------------- veins -----
def surface(bvh, centre, d):
    d = d.normalized()
    hit = bvh.ray_cast(centre + d * 20.0, -d, 40.0)
    if hit[0] is None:
        return None
    return hit[0], hit[1].normalized()


def crack_walk(bvh, centre, start, heading, segs, seg_len, turn, rng):
    s = surface(bvh, centre, Vector(start))
    p, n = s
    h = Vector(heading)
    h = (h - n * h.dot(n)).normalized()
    pts = [(p, n)]
    headings = []
    for i in range(segs):
        ang = math.radians(turn) * (1 if i % 2 == 0 else -1) * rng.uniform(0.55, 1.15)
        h = Matrix.Rotation(ang, 3, n) @ h
        for _ in range(CRACK_SUBSTEPS):
            q = p + h * (seg_len / CRACK_SUBSTEPS)
            s = surface(bvh, centre, q - centre)
            if s is None:
                break
            np_, nn = s
            hv = np_ - p
            hv = hv - nn * hv.dot(nn)
            if hv.length > 1e-6:
                h = hv.normalized()
            p, n = np_, nn
            pts.append((p, n))
            headings.append(h.copy())
    return pts, headings


def add_vein(bm, pts, width):
    """A closed strip along pts [(p, n)], half sunk into the stone, tapering at both ends."""
    if len(pts) < 2:
        return
    rings = []
    m = len(pts)
    for i, (p, n) in enumerate(pts):
        a = pts[max(i - 1, 0)][0]
        b = pts[min(i + 1, m - 1)][0]
        t = (b - a)
        t = (t - n * t.dot(n)).normalized()
        s = n.cross(t).normalized()
        u = i / (m - 1)
        w = width * 0.5 * (0.35 + 0.65 * smoothstep(0.0, 0.25, min(u, 1 - u)))
        rings.append([bm.verts.new(p + s * w + n * VEIN_OUT), bm.verts.new(p - s * w + n * VEIN_OUT),
                      bm.verts.new(p - s * w * 0.6 - n * VEIN_IN), bm.verts.new(p + s * w * 0.6 - n * VEIN_IN)])
    rp.loft(bm, rings)


def add_cracks(stone_bm, centre, cracks, width, seed, vein_bm):
    bvh = BVHTree.FromBMesh(stone_bm)
    rng = random.Random(seed)
    centre = Vector(centre)
    for start, heading, segs, seg_len, turn, branches in cracks:
        pts, heads = crack_walk(bvh, centre, start, heading, segs, seg_len, turn, rng)
        add_vein(vein_bm, pts, width)
        for at, ang, bsegs in branches:
            k = max(1, min(len(pts) - 2, int(at * (len(pts) - 1))))
            p, n = pts[k]
            h = Matrix.Rotation(math.radians(ang), 3, n) @ heads[k - 1]
            bpts, _ = crack_walk(bvh, centre, (p - centre), h, bsegs, seg_len * 0.8, turn, rng)
            add_vein(vein_bm, bpts, width * 0.75)


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


def add_bone(arm, name, head, tail, parent=None, deform=True):
    b = arm.data.edit_bones.new(name)
    b.head, b.tail = Vector(head), Vector(tail)
    b.roll = 0.0
    b.use_deform = deform
    if parent:
        b.parent = arm.data.edit_bones[parent]
    return b


def bind(obj, arm, bone):
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")


def mirror_x(v):
    return Vector((-v[0], v[1], v[2]))


# ---------------------------------------------------------------------------------- builders --
def build_plate(base, side, col):
    """One plate accessory (L or R): Rock + Jade meshes and floating chips, rigged."""
    p = PLATES[base]
    name = base + side
    sgn = 1 if side == "L" else -1
    stone = bmesh.new()
    for c, r, n, j, seed, expo in p["hulls"]:
        add_hull(stone, c, r, n, j, seed, expo, clamp=p["clamp"], z_min=p["z_min"])
    vein = bmesh.new()
    add_cracks(stone, p["centre"], p["cracks"], p["vein_w"], 7, vein)
    chips = []
    for i, (c, r, seed) in enumerate(p["chips"]):
        cb = bmesh.new()
        rng = random.Random(seed)
        rot = Matrix.Rotation(rng.uniform(-0.7, 0.7), 3, "X") @ Matrix.Rotation(rng.uniform(0, 6.3), 3, "Z")
        add_hull(cb, c, (r, r * 0.85, r * 1.25), 9, 0.15, seed, rot=rot)
        chips.append(("Chip%d" % (i + 1), Vector(c), cb))
    if sgn < 0:
        for bm in [stone, vein] + [cb for _, _, cb in chips]:
            for v in bm.verts:
                v.co.x = -v.co.x
    zs = [v.co.z for v in stone.verts]
    shade = height_shade((min(zs), min(zs) + 0.75 * (max(zs) - min(zs))))
    objs = [new_object(name + "_Rock", stone, "Rock", col, shade),
            new_object(name + "_Jade", vein, "Jade", col, lambda co: 1.0)]
    chip_objs = []
    for cname, c, cb in chips:
        chip_objs.append((cname, new_object("%s_%s" % (name, cname), cb, "Rock", col,
                                            height_shade((c.z - 0.2, c.z + 0.15)))))
    at = p["at"] if sgn > 0 else mirror_x(p["at"])
    arm = new_armature(name + "_Rig", col)
    add_bone(arm, "Root", at, at + Vector((0, 0, ROOT_BONE_LEN)), deform=False)
    pc = Vector(p["centre"]) if sgn > 0 else mirror_x(p["centre"])
    add_bone(arm, "Plate", pc, pc + Vector((0, 0, PIECE_BONE_LEN)), "Root")
    for (cc, _, _), (cname, o) in zip(p["chips"], chip_objs):
        c = Vector(cc) if sgn > 0 else mirror_x(cc)
        add_bone(arm, cname, c, c + Vector((0, 0, PIECE_BONE_LEN * 0.6)), "Root")
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in objs:
        bind(o, arm, "Plate")
    for cname, o in chip_objs:
        bind(o, arm, cname)
    return arm, objs + [o for _, o in chip_objs], p["attach"].replace("Left", "Left" if sgn > 0 else "Right")


def ring_frame(q):
    """Ring centre and rotation (tilt about X: + tips the front up)."""
    c = Vector((0.0, 0.0, q["z"]))
    return c, Matrix.Rotation(math.radians(-q["tilt"]), 3, "X")


def shard_pos(q, ang, dz):
    c, rot = ring_frame(q)
    a = math.radians(ang)
    return c + rot @ Vector((math.sin(a) * q["radius"], -math.cos(a) * q["radius"], dz))


def build_shards(name, col):
    q = SHARDS[name]
    objs = []
    centres = []
    for i, (ang, dz, size, seed) in enumerate(q["shards"]):
        pos = shard_pos(q, ang, dz)
        rng = random.Random(seed)
        rot = (Matrix.Rotation(math.radians(ang + 90), 3, "Z") @ Matrix.Rotation(rng.uniform(-0.45, 0.45), 3, "X")
               @ Matrix.Rotation(rng.uniform(-0.35, 0.35), 3, "Y"))
        radii = (size * rng.uniform(0.72, 0.85), size * rng.uniform(0.62, 0.75), size)
        stone = bmesh.new()
        add_hull(stone, pos, radii, SHARD_POINTS, SHARD_JITTER, seed, rot=rot)
        vein = bmesh.new()
        start = rot @ Vector((rng.uniform(-0.3, 0.3), -1.0, rng.uniform(0.3, 0.7)))   # outward-ish face
        start = (pos - Vector((0, 0, pos.z))).normalized() * 0.8 + Vector((0, 0, 0.6)) + start * 0.3
        heading = Vector((0, 0, -1)) + rot @ Vector((rng.uniform(-0.5, 0.5), 0, 0))
        add_cracks(stone, pos, [(start, heading, 3, size * 0.55, 38, [(0.5, 60, 1)])], SHARD_VEIN_W,
                   seed, vein)
        k = i + 1
        sh = height_shade((pos.z - size, pos.z + size * 0.5))
        objs.append(new_object("%s_Shard%d" % (name, k), stone, "Rock", col, sh))
        objs.append(new_object("%s_Shard%dJade" % (name, k), vein, "Jade", col, lambda co: 1.0))
        centres.append(pos)
    c, rot = ring_frame(q)
    arm = new_armature(name + "_Rig", col)
    add_bone(arm, "Root", NECK, NECK + Vector((0, 0, ROOT_BONE_LEN)), deform=False)
    add_bone(arm, "Orbit", c, c + rot @ Vector((0, 0, PIECE_BONE_LEN)), "Root", deform=False)
    for i, pos in enumerate(centres):
        add_bone(arm, "Shard%d" % (i + 1), pos, pos + rot @ Vector((0, 0, PIECE_BONE_LEN * 0.6)), "Orbit")
    bpy.ops.object.mode_set(mode="OBJECT")
    for i in range(len(centres)):
        bind(objs[2 * i], arm, "Shard%d" % (i + 1))
        bind(objs[2 * i + 1], arm, "Shard%d" % (i + 1))
    return arm, objs, "NeckAttachment"


ATTACH_POS = {"NeckAttachment": NECK, "LeftShoulderAttachment": SHOULDER_L,
              "RightShoulderAttachment": mirror_x(SHOULDER_L), "LeftGripAttachment": GRIP_L,
              "RightGripAttachment": mirror_x(GRIP_L)}


# ---------------------------------------------------------------------------------- checks ----
def body_boxes():
    rig = next(o for o in rp.rig_objects() if o.type == "MESH")
    vs = [rig.matrix_world @ v.co for v in rig.data.vertices]
    sel = {"arm": lambda v: v.x > 1.01, "torso": lambda v: abs(v.x) < 0.99 and 0.01 < v.z < 1.99,
           "head": lambda v: v.z > 2.0 and abs(v.x) < 1.0}
    out = {}
    for k, f in sel.items():
        s = [v for v in vs if f(v)]
        out[k] = (Vector([min(v[i] for v in s) for i in range(3)]), Vector([max(v[i] for v in s) for i in range(3)]))
    return out


def bbox(objs):
    vs = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    return Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)])


def proportions(name, objs, boxes):
    """Sizes as ratios of the part each piece attaches to (printed and on the sheet)."""
    if name.endswith("Shards"):
        lo, hi = boxes["head"]
        hh = hi.z - lo.z
        sizes = []
        for o in objs:
            if o["region"] == "Rock":
                a, b = bbox([o])
                sizes.append(max(b - a))
        alo, ahi = bbox(objs)
        span = ahi.x - alo.x
        return dict(shards=len(sizes), shard_size=[round(min(sizes), 2), round(max(sizes), 2)],
                    shard_to_head_height=[round(min(sizes) / hh, 2), round(max(sizes) / hh, 2)],
                    span=round(span, 2), span_to_shoulders=round(span / 4.0, 2),
                    lowest_z=round(alo.z, 2), head_size=[round(hi.x - lo.x, 2), round(hh, 2)])
    lo, hi = boxes["arm"]
    aw, ad, al = hi.x - lo.x, hi.y - lo.y, hi.z - lo.z
    body = [o for o in objs if "_Chip" not in o.name]
    a, b = bbox(body)
    out = dict(width=round(b.x - a.x, 2), depth=round(b.y - a.y, 2), height=round(b.z - a.z, 2),
               width_to_arm=round((b.x - a.x) / aw, 2), depth_to_arm=round((b.y - a.y) / ad, 2),
               arm_size=[round(aw, 2), round(ad, 2), round(al, 2)])
    if "Plate" in name:
        out.update(above_arm=round(b.z - hi.z, 2), above_arm_to_arm_width=round((b.z - hi.z) / aw, 2))
    else:
        out.update(height_to_arm_length=round((b.z - a.z) / al, 2))
    return out


SWING = (-60, 100)   # arm swing range checked (degrees, + forward): walking, and a raised tool hold


def in_swept_arm(v, margin=0.05):
    """Is v inside either arm at any angle in SWING (rotation about X at the shoulder pivot)?"""
    if not (1.0 - margin < abs(v.x) < 2.0 + margin):
        return False
    rel_y, rel_z = v.y, v.z - SHOULDER_PIVOT_L.z
    for deg in range(SWING[0], SWING[1] + 1, 5):
        a = math.radians(deg)      # undo a forward swing: forward tips the arm bottom toward -Y
        y = rel_y * math.cos(a) + rel_z * math.sin(a)
        z = -rel_y * math.sin(a) + rel_z * math.cos(a)
        if -0.5 - margin < y < 0.5 + margin and -1.5 - margin < z < 0.5 + margin:
            return True
    return False


def checks(name, objs):
    """Rules: arm pieces stay outside the torso (flush inner face); shards clear the head and both
    arms over the SWING range."""
    errs = []
    vs = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    if name.endswith("Shards"):
        for v in vs:
            if abs(v.x) < 0.75 and abs(v.y) < 0.75 and v.z < 3.25:
                errs.append("head %s" % r3(v))
            if in_swept_arm(v):
                errs.append("arm swing %s" % r3(v))
    else:
        for v in vs:
            if abs(v.x) < ARM_INNER_X - 1e-4:
                errs.append("torso %s" % r3(v))
    return errs[:4]


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
            a, b = bbox([o])
            meshes[o.name] = dict(region=o["region"], tris=tri_count(o), center=r3((a + b) / 2), size=r3(b - a),
                                  bone=o.vertex_groups[0].name)
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
            materials={MAT_PREFIX + "Rock": "SmoothPlastic", MAT_PREFIX + "Jade": "Neon"},
            shade=dict(file=SHADE_FILE, uv="V only (U = 0.5)", darkest=SHADE_MIN, fade_to_white_at_v=SHADE_REACH),
            meshes=meshes, tris_total=sum(m["tris"] for m in meshes.values()), bones=bones)
        report.update(extra)
        with open(os.path.join(HERE, name + ".json"), "w") as fh:
            json.dump(report, fh, indent=1)
    finally:
        shift_set(arm, objs, attach)
    return report


# ---------------------------------------------------------------------------------- render ----
def swing_arms(left_deg=0.0, right_deg=0.0, sets=()):
    """Swing the R6 arms forward (+) about the shoulders and carry the arm-worn sets with them."""
    rig = rp.armature()
    world = {}
    for bone, deg, sgn in (("Left Arm", left_deg, 1), ("Right Arm", right_deg, -1)):
        pb = rig.pose.bones[bone]
        pb.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
        piv_w = Vector((SHOULDER_PIVOT_L.x * sgn, 0, SHOULDER_PIVOT_L.z))
        pivot = rig.matrix_world.inverted() @ piv_w
        rot = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(-deg), 4, "X") @ Matrix.Translation(-pivot)
        pb.matrix = rot @ pb.bone.matrix_local
        world[sgn] = Matrix.Translation(piv_w) @ Matrix.Rotation(math.radians(-deg), 4, "X") @ Matrix.Translation(-piv_w)
    bpy.context.view_layer.update()
    for s in sets:
        arm = bpy.data.objects.get(s + "_Rig")
        if arm is None or s.endswith("Shards"):
            continue
        arm.matrix_world = world[1 if s.endswith("L") else -1]
    bpy.context.view_layer.update()


def pose_shards(sets, orbit_deg=0.0, bob=0.0):
    for s in sets:
        arm = bpy.data.objects.get(s + "_Rig")
        if arm is None or not s.endswith("Shards"):
            continue
        for pb in arm.pose.bones:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
        arm.pose.bones["Orbit"].rotation_euler = (0, math.radians(orbit_deg), 0)
        for i, pb in enumerate(b for b in arm.pose.bones if b.name.startswith("Shard")):
            pb.location = (0, bob * (1 if i % 2 == 0 else -1), 0)        # bone Y = ring axis (up)
            pb.rotation_euler = (math.radians(25 * (1 if i % 2 else -1)), math.radians(30), 0)
    bpy.context.view_layer.update()


# (name, eye direction, target, ortho scale or None, distance, lens)
VIEWS = [
    ("front", (0, -1, 0.08), (0, 0, 1.4), 6.4, 20, 50),
    ("side", (1, 0, 0.08), (0, 0, 1.4), 6.4, 20, 50),
    ("back", (0, 1, 0.10), (0, 0, 1.4), 6.4, 20, 50),
    ("front34", (0.75, -0.9, 0.3), (0.2, 0, 1.6), None, 11.5, 50),
    ("rear34", (0.8, 0.85, 0.38), (0.2, 0, 1.6), None, 11.5, 50),
    ("game", (0.3, 1, 0.42), (0, 0, 1.5), None, 12.0, 32),
]


def render_tiles(scene, root_col, out_dir, dirs, res=420):
    rp.setup_render(scene, res=(res, res))
    layer = scene.view_layers[0].layer_collection.children[root_col.name]
    shots = []
    for key in dirs:
        sets = DIRECTIONS[key][2]
        for c in layer.children:
            for cc in c.children:          # un-excluding a parent doesn't restore its children,
                cc.exclude = False         # and un-excluding a child un-excludes its parent
            c.exclude = c.name != key
        for view, d, tgt, ortho, dist, lens in VIEWS:
            eye = Vector(tgt) + Vector(d).normalized() * dist
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (key, view)), tuple(eye), tgt,
                                   ortho=ortho, lens=lens))
        # Motion: left arm forward 70, right back 45, the ring turned 40 and shards bobbed/tumbled.
        swing_arms(70, -45, sets)
        pose_shards(sets, 40, 0.15)
        tgt = Vector((0.3, -0.2, 1.4))
        eye = tgt + Vector((1, -0.55, 0.25)).normalized() * 12
        shots.append(rp.render(scene, os.path.join(out_dir, "%s_motion.png" % key), tuple(eye), tuple(tgt), lens=50))
        swing_arms(0, 0, sets)
        pose_shards(sets)
        # Seating close-ups: the left arm piece from low at the side and the front.
        arm_set = next(s for s in sets if s.endswith("L"))
        a, b = bbox([o for o in bpy.data.collections[arm_set].objects if o.type == "MESH" and "_Chip" not in o.name])
        mid = (a + b) / 2
        for view, d in (("seat_side", (1, -0.25, -0.12)), ("seat_front", (0.35, -1, -0.08))):
            eye = mid + Vector(d).normalized() * 3.2
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (key, view)), tuple(eye),
                                   tuple(mid), lens=50))
    for c in layer.children:
        c.exclude = False
        for cc in c.children:
            cc.exclude = False
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
    shade_image()
    for m in ("Rock", "Jade"):
        material(m)
    boxes = body_boxes()
    report = {}
    built = {}
    dirs = [k for k in DIRECTIONS if not ONLY or k in ONLY]
    for key in dirs:
        dcol = collection(key, root_col)
        for s in DIRECTIONS[key][2]:
            scol = bpy.data.collections.new(s)
            dcol.children.link(scol)
            if s.endswith("Shards"):
                arm, objs, att = build_shards(s, scol)
            else:
                arm, objs, att = build_plate(s[:-1], s[-1], scol)
            prop = proportions(s, objs, boxes)
            errs = checks(s, objs)
            extra = dict(direction=key, proportions=prop)
            if s.endswith("Shards"):
                extra["orbit"] = dict(mode=SHARDS[s]["spin"], tilt_deg=SHARDS[s]["tilt"],
                                      how="rotate the Orbit bone about its own Y (the ring's axis): a full "
                                          "spin, or a sway of about +-20 deg for the Peak arc; bob each "
                                          "ShardN along its own Y")
            built[s] = (arm, objs, ATTACH_POS[att], att, extra)
            report[s] = dict(tris=sum(tri_count(o) for o in objs), meshes=len(objs), proportions=prop,
                             problems=errs)
    print(json.dumps(report, indent=1))
    os.makedirs(os.path.join(HERE, "renders"), exist_ok=True)
    rpath = os.path.join(HERE, "renders", "report.json")
    old = json.load(open(rpath)) if os.path.exists(rpath) else {}
    old.update(report)
    with open(rpath, "w") as fh:
        json.dump(old, fh, indent=1)
    if EXPORT:
        for s, (arm, objs, at, att, extra) in built.items():
            export_set(s, arm, objs, at, att, extra)
    if RENDER:
        print(len(render_tiles(scene, root_col, os.path.join(HERE, "renders"), dirs)), "tiles")
    rp.save_blend(scene, os.path.join(HERE, "StoneSpirit.blend"))


main()
