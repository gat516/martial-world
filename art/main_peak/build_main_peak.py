"""Builds the MainPeak rock meshes (spirit-peak style) and exports them for Roblox.

Run inside Blender (Text Editor or exec). Builds into its own scene "MainPeak".
Coordinates: 1 Blender unit = 1 stud, Blender origin = world origin, Blender (x, y, z) = world (X, -Z, Y).
So in Roblox: placement frame is CFrame.identity (see place_main_peak.luau).

Layout (world coords), matching the existing gameplay structures:
  ring terrace   y 582, rim r~185      bridgeheads r 172.5 at 22.5+45k deg, springs r 168 at 0/90/180/270
  plaza mesa     y 647 under Plaza.PlazaFloor (x +-100, z -35..115); ledge at y 614; south wall kept
                 clear of GrandStairs flights (z >= 129)
  summit spire   tip y 812 at (2, -86) under MainPeak.Summit; SkySteps start ~ (-7, 794, -94)
  base           y -10 .. 432, coarse, hidden under the cloud deck (tops y 415-424)

Exports art/main_peak/MainPeakRock.fbx (one mesh per Roblox material/region) and
art/main_peak/MainPeakRock.json (mesh bounds in Blender axes + tri counts).
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Vector, noise
from mathutils.kdtree import KDTree

OUT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else bpy.path.abspath("//")
NAME = "MainPeakRock"
TILE = 12.0          # studs per UV unit
VOXEL = 1.5          # remesh resolution of the upper body
TOP_TRIS = 47000     # decimation target for everything above the clouds
BASE_TRIS = 6000
TERRACE_Y, LEDGE_Y, MESA_Y = 582.0, 614.0, 647.0
CLOUD_Y = 410.0      # upper body starts here; base runs below (overlap hidden in the clouds)

PLAZA = dict(cx=0.0, cz=40.0, hx=102.0, hz=77.0)   # mesa top edge, 2 beyond PlazaFloor
SOUTH_MAX_Z = 127.5   # GrandStairs flights start at z 129.2
BRIDGE_ANGLES = [22.5 + 45 * k for k in range(8)]   # world atan2(z, x), degrees
WATERFALL_ANGLES = [0, 90, 180, 270]

# (x, z, [(y, radius), ...]) world coords; radius profile of each spire, low to high
# (x, z, lean per 100 studs (x, z), [(y, radius), ...]) world coords; lean is applied above y 648.
# Feet stay inside r ~150 so the terrace ring (and the north bridgeheads at r 168.5) stays open, and below
# y 648 north of z -40 so nothing pokes up behind the plaza balustrade.
SPIRES = [
    (2, -90, (0, 0), [(570, 58), (582, 56), (648, 46), (700, 42), (740, 33), (765, 25), (785, 16), (795, 10.5),
                      (805, 7.5), (812.3, 5)]),
    (-50, -104, (-6, -4), [(575, 36), (648, 30), (700, 21), (740, 11), (760, 4)]),
    (46, -108, (7, -5), [(575, 32), (648, 27), (700, 16), (725, 8), (738, 3.5)]),
    (-26, -126, (-4, -8), [(575, 22), (648, 19), (690, 10), (712, 3.5)]),
    (66, -72, (8, 3), [(575, 26), (648, 18), (680, 9), (696, 3.5)]),
    (-68, -66, (-8, 4), [(575, 26), (648, 18), (684, 9), (700, 3.5)]),
    (24, -126, (3, -7), [(575, 18), (648, 15), (676, 7), (690, 3.5)]),
]
MASSIF = dict(cx=0.0, cz=-96.0, levels=[(575, 100, 46), (582, 100, 46), (620, 90, 44), (650, 76, 40),
                                          (680, 50, 30), (695, 22, 13)])

# Cliff pines (world base x, y, z, footprint) that get a ledge to stand on
CLIFF_PINES = [(-103.9, 559.1, -167.0, 13), (-179.8, 458.0, -41.5, 12), (56.6, 503.4, 179.1, 16),
               (154.8, 527.3, 111.9, 10), (-160.3, 503.4, 118.9, 13), (-125.3, 546.7, 140.7, 12),
               (-189.0, 459.6, -15.8, 13), (-157.4, 528.3, 109.7, 12), (-123.1, 502.1, 173.3, 6),
               (-182.1, 459.0, 52.1, 16), (67.6, 528.1, 171.7, 14), (-185.3, 459.7, 35.9, 8),
               (94.5, 526.6, 169.9, 19), (166.5, 459.5, -96.0, 6)]

PARTS = [  # export meshes: name, preview colour
    ("MainRockSpire", (0.22, 0.25, 0.30, 1)),
    ("MainRockMesa", (0.24, 0.26, 0.30, 1)),
    ("MainRockCliffA", (0.21, 0.24, 0.29, 1)),
    ("MainRockCliffB", (0.21, 0.24, 0.29, 1)),
    ("MainRockCliffC", (0.21, 0.24, 0.29, 1)),
    ("MainRockBase", (0.20, 0.23, 0.28, 1)),
    ("MainGrass", (0.18, 0.42, 0.16, 1)),
    ("MainPath", (0.62, 0.60, 0.55, 1)),
]
HELPERS = ["MP_Upper", "MP_Base", "MP_Path"]


# --- helpers -----------------------------------------------------------------

def bv(x, y, z):
    """world (x, y, z) -> Blender vector"""
    return Vector((x, -z, y))


def world_angle(bx, by):
    return math.degrees(math.atan2(-by, bx)) % 360


def ang_diff(a, b):
    return abs((a - b + 180) % 360 - 180)


def lerp_knots(knots, y):
    if y <= knots[0][0]:
        return knots[0][1:] if len(knots[0]) > 2 else knots[0][1]
    for (y0, *a), (y1, *b) in zip(knots, knots[1:]):
        if y <= y1:
            t = (y - y0) / (y1 - y0)
            v = [p + (q - p) * t for p, q in zip(a, b)]
            return v if len(v) > 1 else v[0]
    return knots[-1][1:] if len(knots[-1]) > 2 else knots[-1][1]


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def cell_hash(p):
    return (math.sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719) * 43758.5453) % 1.0


def chunk(pos, s, sv=None):
    # same stacked-block Voronoi as the spirit-peak pillars (Blender axes, z up); sv = vertical cell scale
    sv = s if sv is None else sv
    q = Vector((pos.x / (19.0 * s), pos.y / (19.0 * s), pos.z / (36.0 * sv)))
    d, pts = noise.voronoi(q, distance_metric='DISTANCE', exponent=2.5)
    o0, o1 = cell_hash(pts[0]), cell_hash(pts[1])
    k = smoothstep(0.0, 0.08, d[1] - d[0])
    return (((o0 + o1) * 0.5 * (1 - k) + o0 * k) * 10.0 - d[0] * 2.5) * s


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
    bpy.context.scene.collection.objects.link(o)
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


def loft(bm, rings, cap_top=True, cap_bottom=True):
    """rings: list of lists of Vectors (same count), low to high; closed tube with optional caps"""
    vr = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(rings[0])
    for a, b in zip(vr, vr[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_bottom:
        bm.faces.new(list(reversed(vr[0])))
    if cap_top:
        bm.faces.new(vr[-1])


# --- radius caps: bridge landings and waterfall chutes -----------------------

def cap_radius(a, y):
    """Max cliff radius at world angle a (deg) and height y, or None."""
    cap = None
    if y > 540:
        d = min(ang_diff(a, b) for b in BRIDGE_ANGLES)
        if d < 7.5:
            c = 177.5 + 30 * smoothstep(4.5, 7.5, d) + max(0.0, 560 - y) * 0.6  # bridgeheads end at r 176.5
            cap = c
    if 400 < y:
        d = min(ang_diff(a, b) for b in WATERFALL_ANGLES)
        if d < 14:
            c = 175.0 + 30 * smoothstep(10.5, 14, d)
            cap = c if cap is None else min(cap, c)
    return cap


# --- upper body primitives ---------------------------------------------------

def cliff_profile(y):
    # tapers in toward the clouds so the terrace reads as an overhanging crown
    return lerp_knots([(CLOUD_Y, 172), (440, 172), (500, 177), (550, 182), (575, 186), (TERRACE_Y, 187)], y)


def build_cliff(bm, seg=256):
    rings = []
    ys = [CLOUD_Y + i * 4 for i in range(int((TERRACE_Y - CLOUD_Y) / 4))] + [TERRACE_Y]
    for y in ys:
        ring = []
        for i in range(seg):
            th = 2 * math.pi * i / seg
            a = math.degrees(th)
            d = Vector((math.cos(th), math.sin(th), 0))
            amp = 4.0 + 8.0 * smoothstep(575, 530, y)  # rim stays >= ~183 for the ring lanterns at r 176
            r = (cliff_profile(y) + amp * noise.noise(Vector((d.x * 2.5, d.y * 2.5, y * 0.006)))
                 + 0.4 * amp * noise.noise(Vector((d.x * 7, d.y * 7, 4.0 + y * 0.02))))
            c = cap_radius(a, y)
            if c is not None:
                r = min(r, c - 0.5)
            ring.append(Vector((math.cos(th) * r, math.sin(th) * r, y)))  # world angle th: x=cos, z=sin
        rings.append([bv(p.x, p.z, p.y) for p in ring])
    loft(bm, rings)


def rr_sdf(px, pz, hx, hz_n, hz_s, rc):
    # rounded rectangle centred at the plaza centre, separate north/south half extents
    hz = hz_s if pz > 0 else hz_n
    qx, qz = abs(px) - (hx - rc), abs(pz) - (hz - rc)
    return math.hypot(max(qx, 0), max(qz, 0)) + min(max(qx, qz), 0) - rc


def rr_point(t, hx, hz_n, hz_s, rc):
    d = (math.cos(t), math.sin(t))
    lo, hi = 0.0, 400.0
    for _ in range(30):
        m = (lo + hi) / 2
        if rr_sdf(d[0] * m, d[1] * m, hx, hz_n, hz_s, rc) < 0:
            lo = m
        else:
            hi = m
    return d[0] * lo, d[1] * lo


def build_mesa(bm, seg=200):
    p = PLAZA
    # (y, offset) from the top edge; the ledge is two loops at the same height
    levels = [(575, 19), (582, 18), (600, 14), (LEDGE_Y - 0.01, 12), (LEDGE_Y, 12), (LEDGE_Y, 3.0),
              (630, 2.0), (642, 0.7), (MESA_Y, 0.0)]
    rings = []
    for y, off in levels:
        ring = []
        for i in range(seg):
            t = 2 * math.pi * i / seg
            x, z = rr_point(t, p["hx"] + off, p["hz"] + off, p["hz"] + min(off, 2.0), 4 + off)
            if off > 0.5:  # irregular below the top edge so the walls don't read as a box (south stays put)
                k = 1.0 + 0.08 * noise.noise(Vector((x / 30.0, z / 30.0, y / 40.0))) * off / 12
                x = x * k
                if z < 0:
                    z = z * k
            ring.append(bv(p["cx"] + x, y, p["cz"] + z))
        rings.append(ring)
    loft(bm, rings)


def build_massif(bm, seg=96):
    m = MASSIF
    rings = []
    for y, ax, az in m["levels"]:
        ring = []
        for i in range(seg):
            t = 2 * math.pi * i / seg
            n = 1.0 + 0.12 * noise.noise(Vector((math.cos(t) * 1.7, math.sin(t) * 1.7, y * 0.02)))
            ring.append(bv(m["cx"] + math.cos(t) * ax * n, y, m["cz"] + math.sin(t) * az * n))
        rings.append(ring)
    loft(bm, rings)


def spire_axis(sx, sz, lean, y):
    t = max(0.0, y - 648) / 100.0
    return sx + lean[0] * t * t, sz + lean[1] * t * t


def build_spires(bm, seg=48):
    for k, (sx0, sz0, lean, knots) in enumerate(SPIRES):
        rings = []
        y0, y1 = knots[0][0], knots[-1][0]
        y = y0
        while True:
            r = lerp_knots(knots, y)
            sx, sz = spire_axis(sx0, sz0, lean, y)
            ring = []
            for i in range(seg):
                t = 2 * math.pi * i / seg
                n = 1.0 + 0.16 * noise.noise(Vector((math.cos(t) * 1.4 + k * 7, math.sin(t) * 1.4, y * 0.012)))
                if y >= y1 - 0.01:
                    n = 1.0
                ring.append(bv(sx + math.cos(t) * r * n, y, sz + math.sin(t) * r * n))
            rings.append(ring)
            if y >= y1:
                break
            y = min(y1, y + 6)
        loft(bm, rings)


def build_pine_ledges(bm):
    for x, y, z, size in CLIFF_PINES:
        d = Vector((x, z)).normalized()
        side = Vector((-d.y, d.x))
        top = y - 0.7
        w = max(7.0, size * 0.55)
        reach = Vector((x, z)) + d * (w * 0.5)       # outer edge just past the trunk
        back = Vector((x, z)) - d * 26.0              # deep into the cliff
        pts_top, pts_bot = [], []
        for c in (reach + side * w, reach - side * w, back - side * w * 1.2, back + side * w * 1.2):
            pts_top.append(bv(c.x, top, c.y))
        for c in (reach * 0.2 + back * 0.8 + side * w * 0.6, reach * 0.2 + back * 0.8 - side * w * 0.6,
                  back - side * w, back + side * w):
            pts_bot.append(bv(c.x, top - w * 1.6, c.y))
        loft(bm, [pts_bot, pts_top])


def build_upper():
    bm = bmesh.new()
    build_cliff(bm)
    build_mesa(bm)
    build_massif(bm)
    build_spires(bm)
    build_pine_ledges(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = link("MP_Upper", bm)
    rm = obj.modifiers.new("Remesh", 'REMESH')
    rm.mode = 'VOXEL'
    rm.voxel_size = VOXEL
    rm.use_smooth_shade = False
    apply_all(obj)
    return obj


# --- sculpting the remeshed body ---------------------------------------------

def spire_scale(bx, by, y):
    best, s = 1e9, 1.0
    for sx0, sz0, lean, knots in SPIRES:
        if y < knots[0][0] or y > knots[-1][0] + 2:
            continue
        r = lerp_knots(knots, y)
        sx, sz = spire_axis(sx0, sz0, lean, y)
        dist = math.hypot(bx - sx, -by - sz)
        if abs(dist - r) < best:
            best, s = abs(dist - r), max(0.4, min(1.0, r / 30.0))
    return s


def snap_levels(bm):
    for v in bm.verts:
        if v.normal.z > 0.9:
            for lv in (TERRACE_Y, LEDGE_Y, MESA_Y):
                if abs(v.co.z - lv) < 0.9:
                    v.co.z = lv


def flat_tree(bm):
    flats = [v for v in bm.verts if v.normal.z > 0.9]
    kd = KDTree(len(flats))
    for i, v in enumerate(flats):
        kd.insert(v.co, i)
    kd.balance()
    return kd


def sculpt(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    snap_levels(bm)
    kd = flat_tree(bm)
    for v in bm.verts:
        co = v.co
        y = co.z
        _, _, dist = kd.find(co)
        f = smoothstep(1.0, 5.0, dist)
        if f <= 0.0:
            continue
        h = Vector((v.normal.x, v.normal.y, 0.0))
        if h.length < 0.2:
            continue
        h.normalize()
        r = math.hypot(co.x, co.y)
        sv = None
        if y > 652:
            s = spire_scale(co.x, co.y, y)
            sv = 1.3   # tall karst columns rather than stacked pebbles
        elif r > 150 and y < TERRACE_Y + 0.5:
            s = 1.3
        elif -co.y > 105 and abs(co.x) < 112:
            s = 0.85   # mesa front behind the GrandStairs: shallower blocks so few hit the clamp
        else:
            s = 1.0
        if y > 806 and math.hypot(co.x - 2, -co.y + 90) < 9:
            continue  # summit cap stays clean for the Summit anchor
        old_r, old_z = r, -co.y
        co += h * (chunk(co, s, sv) * f)
        # constraints: flights in front of the south wall, bridge landings, waterfall chutes
        wz = -co.y
        if y > TERRACE_Y + 0.5 and y < 656 and abs(co.x) < 112 and wz > SOUTH_MAX_Z:
            co.y = -min(wz, max(old_z, SOUTH_MAX_Z))
        c = cap_radius(world_angle(co.x, co.y), y)
        if c is not None:
            nr = math.hypot(co.x, co.y)
            lim = max(old_r, c)
            if nr > lim:
                co.x *= lim / nr
                co.y *= lim / nr
    bm.to_mesh(obj.data)
    bm.free()
    sm = obj.modifiers.new("Smooth", 'SMOOTH')
    sm.factor = 0.5
    sm.iterations = 2
    apply_all(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    snap_levels(bm)
    bm.to_mesh(obj.data)
    bm.free()


def decimate(obj, target):
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    dec = obj.modifiers.new("Decimate", 'DECIMATE')
    dec.ratio = min(1.0, target / max(1, tris))
    tri = obj.modifiers.new("Tri", 'TRIANGULATE')
    apply_all(obj)


# --- base below the clouds ---------------------------------------------------

def base_profile(h):
    return lerp_knots([(-10, 222), (60, 220), (150, 216), (250, 212), (330, 206), (360, 196), (390, 180),
                       (410, 166), (428, 156)], h)


def build_base(seg=72):
    rings = []
    y = -10.0
    ys = []
    while y < 428:
        ys.append(y)
        y += 6.0
    ys.append(428.0)
    for y in ys:
        ring = []
        for i in range(seg):
            th = 2 * math.pi * i / seg
            d = Vector((math.cos(th), math.sin(th), 0))
            r = base_profile(y) * (1.0 + 0.05 * noise.noise(Vector((d.x * 1.2, d.y * 1.2, 9.3 + y * 0.003))))
            p = bv(math.cos(th) * r, y, math.sin(th) * r)
            h = Vector((p.x, p.y, 0)).normalized()
            p += h * chunk(p, 2.2) * smoothstep(428, 392, y)  # no blocks poking out above the clouds
            ring.append(p)
        rings.append(ring)
    bm = bmesh.new()
    loft(bm, rings, cap_top=False)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = link("MP_Base", bm)
    sm = obj.modifiers.new("Smooth", 'SMOOTH'); sm.factor = 0.6; sm.iterations = 2
    apply_all(obj)
    decimate(obj, BASE_TRIS)
    return obj


# --- paved ring walk on the terrace ------------------------------------------

# GrandStairs flights land at r ~167 (landing to r ~175); the ring widens into a paved apron under them.
STAIR_FEET_ANGLES = [57.0, 123.0]   # world atan2(z, x), degrees
APRON_RADIUS = 178.0
APRON_HALF, APRON_BLEND = 5.0, 5.0  # full width +-5 deg, blends back to the ring over 5 more


def apron(world_deg):
    """0..1: how far the outer edge reaches toward APRON_RADIUS at this angle."""
    best = 0.0
    for a in STAIR_FEET_ANGLES:
        d = ang_diff(world_deg, a)
        best = max(best, 1.0 - smoothstep(APRON_HALF, APRON_HALF + APRON_BLEND, d))
    return best


def build_path(seg=360):
    bm = bmesh.new()
    top, bot = TERRACE_Y + 0.12, TERRACE_Y - 0.3
    rings = []
    for rad, z in ((150.0, bot), (150.0, top), (166.0, top), (166.0, bot)):
        ring = []
        for i in range(seg):
            th = 2 * math.pi * i / seg
            d = Vector((math.cos(th), math.sin(th), 0))
            j = 0.8 * noise.noise(Vector((d.x * 6 + rad, d.y * 6, 1.7)))
            r = rad + (j if rad < 160 else -abs(j))   # outer edge never reaches the bridgeheads (r 168.5)
            if rad > 160:
                p = bv(math.cos(th), 0, math.sin(th))
                r += (APRON_RADIUS - r) * apron(world_angle(p.x, p.y))
            ring.append(bv(math.cos(th) * r, z, math.sin(th) * r))
        rings.append(ring)
    vr = [[bm.verts.new(p) for p in r] for r in rings]
    for a, b in zip(vr, vr[1:] + vr[:1]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return link("MP_Path", bm)


# --- split + UV + export -----------------------------------------------------

def under_floor(c):
    return abs(c.x) < 100.5 and -35.5 < -c.y < 115.5 and c.z > MESA_Y - 3


def is_grass(f, kd, flats):
    c = f.calc_center_median()
    if c.z < 430 or under_floor(c):
        return False
    if f.normal.z > 0.6:
        return True
    r = math.hypot(c.x, c.y)
    a = world_angle(c.x, c.y)
    if r > 165 and c.z > 540 and cap_radius(a, c.z) is not None:
        return False  # bridge landings and waterfall lips stay bare rock
    if f.normal.z < -0.3:
        return False
    co, i, dist = kd.find(c)
    lip = 1.0 + 2.5 * (noise.noise(Vector((c.x / 9.0, c.y / 9.0, 3.3))) + 1.0)
    return flats[i].z > c.z and dist < lip


def extract(bm, faces):
    out = bmesh.new()
    vmap = {}
    for f in faces:
        vs = []
        for v in f.verts:
            if v.index not in vmap:
                vmap[v.index] = out.verts.new(v.co)
            vs.append(vmap[v.index])
        if len(set(vs)) == len(vs) and out.faces.get(vs) is None:
            out.faces.new(vs)
    bmesh.ops.delete(bm, geom=faces, context='FACES_ONLY')
    bm.verts.index_update()
    return out


SHARP_ANGLE = math.radians(40)


def smooth_by_angle(bm):
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if not e.is_manifold or e.calc_face_angle(0.0) > SHARP_ANGLE:
            e.smooth = False
        elif len({f.normal.z > 0.98 for f in e.link_faces}) > 1:
            e.smooth = False  # flat walk surfaces keep pure up normals (no streaks across big decimated tris)


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


def split(upper, base, path):
    bm = bmesh.new()
    bm.from_mesh(upper.data)
    bm.normal_update()
    bm.verts.index_update()
    # rim points: edges of up-facing faces sampled every 1.5 studs (decimated flats have few verts)
    flats = []
    for f in bm.faces:
        if f.normal.z > 0.9 and f.calc_center_median().z > 430:
            for e in f.edges:
                a, b = e.verts[0].co, e.verts[1].co
                n = max(1, int((a - b).length / 1.5))
                flats.extend(a.lerp(b, i / n) for i in range(n + 1))
    kd = KDTree(len(flats))
    for i, p in enumerate(flats):
        kd.insert(p, i)
    kd.balance()
    grass = extract(bm, [f for f in bm.faces if is_grass(f, kd, flats)])
    spire = extract(bm, [f for f in bm.faces if f.calc_center_median().z > 652])
    mesa = extract(bm, [f for f in bm.faces if f.calc_center_median().z > TERRACE_Y + 1.0
                        and math.hypot(*f.calc_center_median().xy) < 165])
    def sector(f):
        c = f.calc_center_median()
        return int(((world_angle(c.x, c.y) + 30) % 360) // 120)
    cliff_a = extract(bm, [f for f in bm.faces if sector(f) == 0])
    cliff_b = extract(bm, [f for f in bm.faces if sector(f) == 1])
    meshes = {"MainRockSpire": spire, "MainRockMesa": mesa, "MainRockCliffA": cliff_a, "MainRockCliffB": cliff_b,
              "MainRockCliffC": bm, "MainGrass": grass}
    for o, n in ((base, "MainRockBase"), (path, "MainPath")):
        b = bmesh.new()
        b.from_mesh(o.data)
        meshes[n] = b
    return meshes


def finish(meshes):
    clear([n for n, _ in PARTS])
    objs = []
    for name, col in PARTS:
        b = meshes[name]
        bmesh.ops.delete(b, geom=[e for e in b.edges if not e.link_faces], context='EDGES')
        bmesh.ops.delete(b, geom=[v for v in b.verts if not v.link_faces], context='VERTS')
        b.normal_update()
        box_uv(b)
        smooth_by_angle(b)
        o = link(name, b)
        m = bpy.data.materials.get("Preview" + name) or bpy.data.materials.new("Preview" + name)
        m.use_nodes = True
        next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = col
        o.data.materials.append(m)
        objs.append(o)
    clear(HELPERS)
    return objs


def export(objs):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, NAME + ".fbx"), use_selection=True,
                             object_types={'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                             axis_forward='-Z', axis_up='Y', mesh_smooth_type='EDGE', bake_space_transform=True)
    report = {"placement": "CFrame.identity (Blender origin = world origin)", "meshes": {}}
    for o in objs:
        centre, size = bounds(o)
        report["meshes"][o.name] = dict(tris=len(o.data.polygons), center=centre, size=size)
    with open(os.path.join(OUT_DIR, NAME + ".json"), "w") as fh:
        json.dump(report, fh, indent=1)
    return report


def use_scene():
    scn = bpy.data.scenes.get("MainPeak") or bpy.data.scenes.new("MainPeak")
    bpy.context.window.scene = scn
    return scn


def export_path_only():
    """Rebuild just MainPath into MainPeakPath.fbx (a quick re-import), and update its JSON entry."""
    use_scene()
    clear(["MP_Path", "MainPath"])
    path = build_path()
    b = bmesh.new()
    b.from_mesh(path.data)
    b.normal_update()
    box_uv(b)
    smooth_by_angle(b)
    o = link("MainPath", b)
    clear(["MP_Path"])
    for x in bpy.context.selected_objects:
        x.select_set(False)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, "MainPeakPath.fbx"), use_selection=True,
                             object_types={'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                             axis_forward='-Z', axis_up='Y', mesh_smooth_type='EDGE', bake_space_transform=True)
    jp = os.path.join(OUT_DIR, NAME + ".json")
    with open(jp) as fh:
        report = json.load(fh)
    centre, size = bounds(o)
    report["meshes"]["MainPath"] = dict(tris=len(o.data.polygons), center=centre, size=size)
    with open(jp, "w") as fh:
        json.dump(report, fh, indent=1)
    return report["meshes"]["MainPath"]


def main():
    use_scene()
    clear(HELPERS + [n for n, _ in PARTS])
    upper = build_upper()
    sculpt(upper)
    decimate(upper, TOP_TRIS)
    base = build_base()
    path = build_path()
    objs = finish(split(upper, base, path))
    report = export(objs)
    for k, v in report["meshes"].items():
        print(k, v)


if __name__ == "__main__":
    main()
