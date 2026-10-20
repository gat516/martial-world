"""Builds the Spirit Peak pillar meshes and exports them for Roblox.

Run inside Blender (Text Editor or exec). Axes: X = peak-local right, Y = outward
(away from the MainPeak), Z = up. Origin = the peak's Plateau centre (world y 553.5).
1 Blender unit = 1 stud.

Exports art/SpiritPeakPillar.fbx (one mesh per Roblox material) and
art/SpiritPeakPillar.json (mesh bounds + decor anchors, in the same axes).
"""
import json
import math
import os
import random

import bmesh
import bpy
from mathutils import Vector, noise
from mathutils.bvhtree import BVHTree

OUT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else bpy.path.abspath("//")
TOP_Z = -1.5                 # walkable top (world y 552)
DEPTH = 562.0                # down to the ground ring (world y -10)
SPLIT_H = 176.0              # upper/lower mesh split, just under the cloud deck (world y ~376)
TILE = 12.0                  # studs per UV unit, for Roblox material tiling
SEG = 128

# Abode hall carved into the pillar (elliptical footprint, domed ceiling)
HALL = dict(cx=0.0, cy=6.0, ax=31.0, ay=27.0, floor=-24.5, wall_top=-15.0, apex=-7.5)  # floor surface = floor - 0.5
MIN_WALL = 6.0

# CaveAbode.CliffStairs step centres (x, outward, z), top to bottom. The steps spiral around the
# cliff ~52.5 studs from the axis: 4.4 run (tangent) x 4 tall x 13 wide (radial).
STEPS = [(-37.8, 36.4, -5.6), (-35.3, 38.9, -8.8), (-32.5, 41.2, -11.9), (-29.7, 43.3, -15.0),
         (-26.7, 45.2, -18.1), (-23.6, 46.9, -21.3), (-20.4, 48.4, -24.4), (-17.0, 49.7, -27.5)]

PORCH_TOP = -25.0  # landing in front of the abode door

# Cliff ledges: (angle deg, 90 = outward; depth below top; radius; protrusion)
OUTCROPS = [(20, 36, 11, 7), (205, 50, 13, 8), (322, 74, 10, 6), (158, 96, 12, 7),
            (58, 122, 9, 6), (242, 142, 14, 9), (352, 166, 11, 7),
            (110, 205, 14, 9), (30, 300, 16, 10), (210, 420, 18, 11)]

HELPERS = ["PeakPillar", "CutCave", "CutHall", "CutStairs", "StairBlock", "Outcrops"]
PARTS = [  # one MeshPart = one Roblox material
    ("PeakRock", (0.22, 0.25, 0.30, 1)),
    ("PeakRockBase", (0.20, 0.23, 0.28, 1)),
    ("PeakGrass", (0.18, 0.42, 0.16, 1)),
    ("AbodeWalls", (0.55, 0.50, 0.42, 1)),
    ("AbodeFloor", (0.45, 0.32, 0.20, 1)),
]


def clear(names):
    for n in names:
        o = bpy.data.objects.get(n)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)


def link(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return o


def activate(obj):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)


def apply_all(obj):
    activate(obj)
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def boolean(target, other, op):
    activate(target)
    b = target.modifiers.new("Bool_" + other.name, 'BOOLEAN')
    b.operation = op
    b.solver = 'EXACT'
    b.use_self = True  # stair boxes overlap each other
    b.object = other
    bpy.ops.object.modifier_apply(modifier=b.name)
    other.hide_set(True)


# --- rock column -------------------------------------------------------------

def profile(h):
    if h < 10: return 50.0
    if h < 24: return 50.0 - (h - 10) / 14 * 4.0
    if h < 100: return 46.0 - (h - 24) / 76 * 6.0
    if h < SPLIT_H: return 40.0 - (h - 100) / (SPLIT_H - 100) * 1.0
    if h < 512: return 39.0 + (h - SPLIT_H) / (512 - SPLIT_H) * 46.0   # widens toward the ground
    return 85.0 + (h - 512) / (DEPTH - 512) * 11.0


def detail_scale(h):
    # coarser blocks below the clouds, where it's only seen from far away
    return 1.0 + max(0.0, h - SPLIT_H) / (DEPTH - SPLIT_H) * 0.9


def cell_hash(p):
    return (math.sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719) * 43758.5453) % 1.0


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def chunk(pos, s):
    # stacked eroded blocks: Voronoi cells pushed out by a per-cell amount, bevelled at edges
    q = Vector((pos.x / (19.0 * s), pos.y / (19.0 * s), pos.z / (36.0 * s)))
    d, pts = noise.voronoi(q, distance_metric='DISTANCE', exponent=2.5)
    o0, o1 = cell_hash(pts[0]), cell_hash(pts[1])
    k = smoothstep(0.0, 0.08, d[1] - d[0])
    return (((o0 + o1) * 0.5 * (1 - k) + o0 * k) * 10.0 - d[0] * 2.5) * s


def ring_depths():
    hs, h = [], 0.0
    while h < DEPTH:
        hs.append(h)
        h += 1.2 if h < SPLIT_H else 3.5
    hs.append(DEPTH)
    return hs


def surface_radius(th, h):
    dirv = Vector((math.cos(th), math.sin(th), 0))
    base = profile(h) * (1.0 + 0.12 * noise.noise(Vector((dirv.x * 1.1, dirv.y * 1.1, 5.1 + h * 0.003))))
    return base, base + min(1.0, h / 4.0) * chunk(dirv * base + Vector((0, 0, TOP_Z - h)), detail_scale(h))


def top_height(x, y, f):
    # gentle roll in the grass, flatter toward the middle where things get built
    return TOP_Z + 0.5 * f * noise.noise(Vector((x / 16.0, y / 16.0, 0.7)))


def build_column():
    bm = bmesh.new()
    grid = []
    for h in ring_depths():
        z = TOP_Z - h
        ring = []
        for i in range(SEG):
            th = 2 * math.pi * i / SEG
            base, r = surface_radius(th, h)
            if h == 0:
                r = base * 0.985
            v = Vector((math.cos(th) * r, math.sin(th) * r, z))
            if h == 0:
                v.z = top_height(v.x, v.y, 1.0)
            ring.append(bm.verts.new(v))
        grid.append(ring)
    for a, b in zip(grid, grid[1:]):
        for i in range(SEG):
            j = (i + 1) % SEG
            bm.faces.new((a[i], a[j], b[j], b[i]))
    # radial top cap so the grass can roll instead of being one flat disc
    prev = grid[0]
    for f in (0.93, 0.82, 0.66, 0.48, 0.3, 0.14):
        ring = []
        for v in grid[0]:
            x, y = v.co.x * f, v.co.y * f
            ring.append(bm.verts.new((x, y, top_height(x, y, f))))
        for i in range(SEG):
            j = (i + 1) % SEG
            bm.faces.new((ring[i], ring[j], prev[j], prev[i]))
        prev = ring
    centre = bm.verts.new((0, 0, TOP_Z))
    for i in range(SEG):
        bm.faces.new((prev[i], prev[(i + 1) % SEG], centre))
    bm.faces.new(list(reversed(grid[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = link("PeakPillar", bm)
    sm = obj.modifiers.new("Smooth", 'SMOOTH'); sm.factor = 0.6; sm.iterations = 2
    dec = obj.modifiers.new("Decimate", 'DECIMATE'); dec.ratio = 0.2
    apply_all(obj)
    return obj


# --- outcrops ----------------------------------------------------------------

def build_outcrops():
    random.seed(5)
    bm = bmesh.new()
    anchors = []
    for ang, h, size, push in OUTCROPS:
        th = math.radians(ang)
        _, r = surface_radius(th, h)
        dirv = Vector((math.cos(th), math.sin(th), 0))
        side = Vector((-dirv.y, dirv.x, 0))
        centre = dirv * (r + push - size * 0.55)
        top, thick = TOP_Z - h, size * random.uniform(0.8, 1.1)
        n = 7
        tops, mids, bots = [], [], []
        for i in range(n):
            a = 2 * math.pi * i / n + random.uniform(-0.2, 0.2)
            rr = size * random.uniform(0.75, 1.15)
            off = dirv * (math.cos(a) * rr) + side * (math.sin(a) * rr * 1.3)
            tops.append(bm.verts.new(centre + off * 0.92 + Vector((0, 0, top + random.uniform(-0.4, 0.4)))))
            mids.append(bm.verts.new(centre + off + Vector((0, 0, top - 1.5 - random.uniform(0, 1.0)))))
            # wedge underside tucks back into the cliff
            bots.append(bm.verts.new(centre + off * 0.3 - dirv * size * 0.4 + Vector((0, 0, top - thick))))
        bm.faces.new(tops)
        bm.faces.new(list(reversed(bots)))
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((tops[i], mids[i], mids[j], tops[j]))
            bm.faces.new((mids[i], bots[i], bots[j], mids[j]))
        exposed = dirv * (r + push * 0.5)
        anchors.append(dict(x=round(exposed.x, 2), y=round(exposed.y, 2), z=round(top, 2), size=size))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return link("Outcrops", bm), anchors


# --- cutters -----------------------------------------------------------------

def add_box(bm, corners):
    v = [bm.verts.new(p) for p in corners]
    for f in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
        bm.faces.new([v[i] for i in f])


def oriented_box(bm, centre, run, w, run_half, w0, w1, z0, z1):
    c = [centre + run * -run_half + w * w0, centre + run * run_half + w * w0,
         centre + run * run_half + w * w1, centre + run * -run_half + w * w1]
    add_box(bm, [Vector((p.x, p.y, z0)) for p in c] + [Vector((p.x, p.y, z1)) for p in c])


def axis_box(lo, hi):
    return [(lo[0], lo[1], lo[2]), (hi[0], lo[1], lo[2]), (hi[0], hi[1], lo[2]), (lo[0], hi[1], lo[2]),
            (lo[0], lo[1], hi[2]), (hi[0], lo[1], hi[2]), (hi[0], hi[1], hi[2]), (lo[0], hi[1], hi[2])]


def cave_door_cutter():
    bm = bmesh.new()
    # corridor into the hall, exactly as wide as CaveAbode.Facade (piers at x +-12.05, outward
    # 44.5-54.5) so the facade plugs it with no slits; the piers sink a hair into the rock
    add_box(bm, axis_box((-12.0, 21, PORCH_TOP), (12.0, 54.5, -9.0)))
    # porch: open only in front of the facade face, reaching left to the foot of the stairs
    add_box(bm, axis_box((-26.0, 54.5, PORCH_TOP), (13.0, 90, -6.5)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return link("CutCave", bm)


def stair_solids():
    """Per step: rock support under the Step part and clearance above it, following the spiral."""
    block, cut = bmesh.new(), bmesh.new()
    for x, y, z in STEPS:
        radial = Vector((x, y, 0)).normalized()
        tangent = Vector((-radial.y, radial.x, 0))
        r = Vector((x, y)).length
        bottom, tread = z - 2.0, z + 2.0
        # wedge: deep at the cliff, only a few studs thick at the outer edge, so it tapers into the rock
        inner, outer = radial * (r - 12.0), radial * (r + 6.7)
        t = tangent * 2.6
        add_box(block, [inner - t + Vector((0, 0, bottom - 18)), inner + t + Vector((0, 0, bottom - 18)),
                        outer + t + Vector((0, 0, bottom - 4)), outer - t + Vector((0, 0, bottom - 4)),
                        inner - t + Vector((0, 0, bottom)), inner + t + Vector((0, 0, bottom)),
                        outer + t + Vector((0, 0, bottom)), outer - t + Vector((0, 0, bottom))])
        oriented_box(cut, Vector((0, 0, 0)), tangent, radial, 2.2, r - 8.5, r + 40.0, tread, tread + 14.0)
    # stone landing the stairs end on, flush with the doorway threshold and CaveAbode.Ledge top;
    # underside slopes back into the cliff like the step supports
    top = PORCH_TOP
    add_box(block, [(-28, 40, top - 16), (16, 40, top - 16), (16, 66, top - 4), (-28, 66, top - 4),
                    (-28, 40, top), (16, 40, top), (16, 66, top), (-28, 66, top)])
    for b in (block, cut):
        bmesh.ops.recalc_face_normals(b, faces=b.faces)
    return link("StairBlock", block), link("CutStairs", cut)


def hall_cutter(h, seg=28):
    bm = bmesh.new()
    levels = [(h["floor"] - 0.5, 1.0), (h["floor"] + 3, 1.0), (h["wall_top"] - 4, 1.0), (h["wall_top"], 0.97)]
    for k in range(1, 5):
        t = k / 5
        levels.append((h["wall_top"] + (h["apex"] - h["wall_top"]) * math.sin(t * math.pi / 2),
                       math.cos(t * math.pi / 2) * 0.97))
    rings = []
    for li, (z, s) in enumerate(levels):
        ring = []
        for i in range(seg):
            th = 2 * math.pi * i / seg
            j = 1.0
            if 0 < li < len(levels) - 1:  # rough rock walls; floor edge and apex stay clean
                j += 0.06 * noise.noise(Vector((math.cos(th) * 2, math.sin(th) * 2, z * 0.15)))
            ring.append(bm.verts.new((h["cx"] + math.cos(th) * h["ax"] * s * j,
                                      h["cy"] + math.sin(th) * h["ay"] * s * j, z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            n = (i + 1) % seg
            bm.faces.new((a[i], a[n], b[n], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    apex = bm.verts.new((h["cx"], h["cy"], h["apex"]))
    for i in range(seg):
        bm.faces.new((rings[-1][i], rings[-1][(i + 1) % seg], apex))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return link("CutHall", bm)


def wall_report(pillar, h):
    """Thinnest rock between hall wall and outer cliff, ignoring the doorway and stair openings."""
    bm = bmesh.new()
    bm.from_mesh(pillar.data)
    tree = BVHTree.FromBMesh(bm)
    worst = (1e9, None)
    for z in (h["floor"] + 1, (h["floor"] + h["wall_top"]) / 2, h["wall_top"]):
        for i in range(72):
            th = 2 * math.pi * i / 72
            p = Vector((h["cx"] + math.cos(th) * h["ax"], h["cy"] + math.sin(th) * h["ay"], z))
            if (abs(p.x) < 14 and p.y > 14) or (p.x < -8 and p.y > 20):
                continue
            d = Vector((math.cos(th) * h["ay"], math.sin(th) * h["ax"], 0)).normalized()
            hit = tree.ray_cast(p, d)
            if hit[0] is not None and hit[3] < worst[0]:
                worst = (hit[3], tuple(round(c, 1) for c in p))
    bm.free()
    return worst


# --- split + UV + export -----------------------------------------------------

def in_cut(c, h):
    cave = (-13 < c.x < 13 and c.y > 18 and -27 < c.z < -8) or (-27 < c.x < 14 and c.y > 53 and -26 < c.z < -6)
    # stops below the plateau so the top stays one continuous lawn around the stair head
    stairs = -50 < c.x < -8 and c.y > 28 and -34 < c.z < TOP_Z - 2.5
    return cave or stairs or in_abode(c, h)


def in_abode(c, h):
    hall = (((c.x - h["cx"]) / (h["ax"] + 1.5)) ** 2 + ((c.y - h["cy"]) / (h["ay"] + 1.5)) ** 2 < 1
            and h["floor"] - 1 < c.z < h["apex"] + 1)
    corridor = -13 < c.x < 13 and 0 < c.y < 46 and -27.5 < c.z < -8
    return hall or corridor


def is_grass(f, h):
    c = f.calc_center_median()
    if in_cut(c, h):
        return False
    if f.normal.z > 0.6:
        return True
    # ragged grass lip spilling over the rim, except over the abode front and stairs
    if c.y > 28 and -50 < c.x < 20 and c.z < TOP_Z - 1.0:
        return False
    lip =1.0 + 2.5 * (noise.noise(Vector((c.x / 9.0, c.y / 9.0, 3.3))) + 1.0)
    return c.z > TOP_Z - lip and f.normal.z > -0.3


def extract(bm, faces):
    out = bmesh.new()
    vmap = {}
    for f in faces:
        vs = []
        for v in f.verts:
            if v.index not in vmap:
                vmap[v.index] = out.verts.new(v.co)
            vs.append(vmap[v.index])
        if len(set(vs)) == len(vs) and out.faces.get(vs) is None:  # booleans can leave duplicates
            out.faces.new(vs)
    bmesh.ops.delete(bm, geom=faces, context='FACES_ONLY')
    bm.verts.index_update()
    return out


SHARP_ANGLE = math.radians(40)


def smooth_by_angle(bm):
    """Smooth shading so decimation facets don't show; creases sharper than SHARP_ANGLE stay crisp."""
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if not e.is_manifold or e.calc_face_angle(0.0) > SHARP_ANGLE:
            e.smooth = False


def box_uv(bm):
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        ax = max(range(3), key=lambda i: abs(f.normal[i]))
        for l in f.loops:
            co = l.vert.co
            u, v = ((co.y, co.z), (co.x, co.z), (co.x, co.y))[ax]
            l[uv].uv = (u / TILE, v / TILE)


def bounds(o):
    ws = [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = Vector((min(v.x for v in ws), min(v.y for v in ws), min(v.z for v in ws)))
    mx = Vector((max(v.x for v in ws), max(v.y for v in ws), max(v.z for v in ws)))
    return [round(x, 3) for x in (mn + mx) / 2], [round(x, 3) for x in mx - mn]


def split_and_export(pillar, h, anchors):
    clear([n for n, _ in PARTS])
    bm = bmesh.new()
    bm.from_mesh(pillar.data)
    # slice at the split so no decimated sliver spans both meshes (keeps bounds tight for culling)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, TOP_Z - SPLIT_H), plane_no=(0, 0, 1))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.verts.index_update()
    floor_bm = extract(bm, [f for f in bm.faces if in_abode(f.calc_center_median(), h) and f.normal.z > 0.82])
    walls_bm = extract(bm, [f for f in bm.faces if in_abode(f.calc_center_median(), h)])
    grass_bm = extract(bm, [f for f in bm.faces if is_grass(f, h)])
    base_bm = extract(bm, [f for f in bm.faces if f.calc_center_median().z < TOP_Z - SPLIT_H])
    for b in (bm, base_bm, grass_bm, walls_bm, floor_bm):  # drop loose verts left behind by extraction
        bmesh.ops.delete(b, geom=[e for e in b.edges if not e.link_faces], context='EDGES')
        bmesh.ops.delete(b, geom=[v for v in b.verts if not v.link_faces], context='VERTS')
    meshes = {"PeakRock": bm, "PeakRockBase": base_bm, "PeakGrass": grass_bm,
              "AbodeWalls": walls_bm, "AbodeFloor": floor_bm}
    objs = []
    for name, col in PARTS:
        b = meshes[name]
        box_uv(b)
        smooth_by_angle(b)
        o = link(name, b)
        m = bpy.data.materials.get("Preview" + name) or bpy.data.materials.new("Preview" + name)
        m.use_nodes = True
        next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = col
        o.data.materials.append(m)
        objs.append(o)

    clear(HELPERS)  # keep only the export meshes in the scene so nothing extra ends up in the FBX
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, "SpiritPeakPillar.fbx"), use_selection=True,
                             object_types={'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                             axis_forward='-Z', axis_up='Y', mesh_smooth_type='EDGE', bake_space_transform=True)
    report = {"meshes": {}, "anchors": anchors}
    for o in objs:
        centre, size = bounds(o)
        report["meshes"][o.name] = dict(tris=len(o.data.polygons), center=centre, size=size)
    with open(os.path.join(OUT_DIR, "SpiritPeakPillar.json"), "w") as fh:
        json.dump(report, fh, indent=1)
    return report


def main():
    clear(HELPERS + [n for n, _ in PARTS])
    pillar = build_column()
    wall = wall_report(pillar, HALL)
    outcrops, anchors = build_outcrops()
    block, stair_cut = stair_solids()
    boolean(pillar, outcrops, 'UNION')
    for cutter in (cave_door_cutter(), stair_cut, hall_cutter(HALL)):
        boolean(pillar, cutter, 'DIFFERENCE')
    boolean(pillar, block, 'UNION')  # last, so the porch cut can't eat the step supports
    pillar.modifiers.new("Tri", 'TRIANGULATE')
    apply_all(pillar)
    report = split_and_export(pillar, HALL, anchors)
    print("thinnest hall wall:", wall, "(min", MIN_WALL, ")")
    for k, v in report["meshes"].items():
        print(k, v)


main()
