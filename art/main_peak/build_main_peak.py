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
TOP_TRIS = 60000     # decimation target for everything above the clouds
BASE_TRIS = 12000
MIN_LAWN = 3000.0    # studs^2; the terrace, plaza ledge and mesa; smaller flats on the body stay rock
LIP = 1.3            # how far the turf wraps down over a lawn's edge
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
    # the summit tower (tip under MainPeak.Summit), slimmer than a cone so the cluster reads as karst pillars
    (2, -90, (0, 0), [(570, 40), (648, 33), (700, 29), (745, 25), (770, 20), (785, 15.5), (795, 10.5),
                      (805, 7.5), (812.3, 5)]),
    # shoulder towers packed around it: near-vertical sides, rounded caps, all different heights
    (-30, -68, (-3, 2), [(575, 24), (648, 21), (715, 18), (738, 14), (750, 8), (755, 3.5)]),
    (36, -66, (3, 2), [(575, 22), (648, 19), (700, 16), (722, 12), (732, 6.5), (736, 3)]),
    (30, -120, (3, -4), [(575, 25), (648, 22), (735, 18.5), (760, 13), (772, 6), (776, 3)]),
    (-26, -122, (-3, -4), [(575, 22), (648, 19), (690, 16), (708, 11), (716, 5), (719, 2.5)]),
    (-62, -98, (-7, -2), [(575, 22), (648, 17), (676, 13), (690, 7), (695, 3)]),
    (64, -96, (7, -2), [(575, 20), (648, 16), (668, 12), (680, 6), (684, 2.5)]),
    (4, -138, (0, -6), [(575, 20), (648, 17), (684, 13), (700, 7), (705, 3)]),
]
MASSIF = dict(cx=0.0, cz=-96.0, levels=[(575, 100, 46), (582, 100, 46), (620, 90, 44), (650, 76, 40),
                                          (680, 50, 30), (695, 22, 13)])

# Cliff pines (world base x, y, z, footprint) that get a ledge to stand on; none inside a waterfall chute
CLIFF_PINES = [(-103.9, 559.1, -167.0, 13), (-159.8, 458.0, -92.3, 12), (56.6, 503.4, 179.1, 16),
               (154.8, 527.3, 111.9, 10), (-160.3, 503.4, 118.9, 13), (-125.3, 546.7, 140.7, 12),
               (-174.6, 459.6, -74.1, 13), (-157.4, 528.3, 109.7, 12), (-123.1, 502.1, 173.3, 6),
               (-173.0, 459.0, 77.0, 16), (67.6, 528.1, 171.7, 14), (-161.8, 459.7, 97.2, 8),
               (94.5, 526.6, 169.9, 19), (166.5, 459.5, -96.0, 6)]

PARTS = [  # export meshes: name, preview colour
    ("MainRockSpire", (0.22, 0.25, 0.30, 1)),
    ("MainRockMesa", (0.24, 0.26, 0.30, 1)),
    ("MainRockCliffA", (0.21, 0.24, 0.29, 1)),
    ("MainRockCliffB", (0.21, 0.24, 0.29, 1)),
    ("MainRockCliffC", (0.21, 0.24, 0.29, 1)),
    ("MainRockBase", (0.20, 0.23, 0.28, 1)),
    ("MainGrass", (0.18, 0.42, 0.16, 1)),
    ("MainLedges", (0.21, 0.24, 0.29, 1)),
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


def stone_columns(co, s):
    """Stone columns like the spirit peaks: 2D Voronoi over x/y (so cells run straight down), each cell
    pushed in or out by its own amount and split into stacked segments every 25-60 studs, with a narrow
    groove where cells meet. Returns (offset along the wall's horizontal normal, cell id)."""
    d, pts = noise.voronoi(Vector((co.x / (9.0 * s), co.y / (9.0 * s), 0.0)), distance_metric='DISTANCE')
    cell = pts[0]
    seg_len = 25.0 + 35.0 * cell_hash(cell + Vector((3.1, 0, 0)))
    k = math.floor((co.z + seg_len * cell_hash(cell + Vector((0, 7.7, 0)))) / seg_len)
    out = (6.0 * cell_hash(cell + Vector((0, 0, k * 1.37))) - 2.0) * s
    groove = -1.4 * s * (1.0 - smoothstep(0.0, 0.12, d[1] - d[0]))
    return out + groove, cell


def crown_top(co, below):
    """Depth below a lawn's surface where this column's rock starts stepping out (a broken crown)."""
    _, cell = stone_columns(co, 1.3)
    return below + 0.5 + 6.0 * cell_hash(cell + Vector((5.3, 1.1, 0)))


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
    return lerp_knots([(CLOUD_Y, 168), (440, 172), (500, 177), (550, 182), (575, 186), (TERRACE_Y, 187)], y)


def cliff_radius(th, y):
    """Radius of the ring cliff at world angle th (radians) and height y."""
    d = Vector((math.cos(th), math.sin(th), 0))
    amp = 4.0 + 8.0 * smoothstep(575, 530, y)  # rim stays >= ~183 for the ring lanterns at r 176
    r = (cliff_profile(y) + amp * noise.noise(Vector((d.x * 2.5, d.y * 2.5, y * 0.006)))
         + 0.4 * amp * noise.noise(Vector((d.x * 7, d.y * 7, 4.0 + y * 0.02))))
    c = cap_radius(math.degrees(th), y)
    return r if c is None else min(r, c - 0.5)


def build_cliff(bm, seg=256):
    rings = []
    ys = [CLOUD_Y + i * 4 for i in range(int((TERRACE_Y - CLOUD_Y) / 4))] + [TERRACE_Y]
    for y in ys:
        ring = []
        for i in range(seg):
            th = 2 * math.pi * i / seg
            r = cliff_radius(th, y)
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


def mesa_point(t, y, off):
    """Point on the mesa wall at plaza-centred angle t, height y, offset off out from the top edge."""
    p = PLAZA
    x, z = rr_point(t, p["hx"] + off, p["hz"] + off, p["hz"] + min(off, 2.0), 4 + off)
    if off > 0.5:  # irregular below the top edge so the walls don't read as a box (south stays put)
        k = 1.0 + 0.08 * noise.noise(Vector((x / 30.0, z / 30.0, y / 40.0))) * off / 12
        x = x * k
        if z < 0:
            z = z * k
    return x, z


MESA_LEDGE_OFF = 12.0
TERRACE_LAWN_W, MESA_LAWN_W = 85.0, 11.0  # how far each lawn slab reaches in from its outer edge
FOOT_CUT = 1.2  # walls rising off a lawn slab are cut this high and dropped straight into the grass


def mesa_polar(co):
    """(angle, distance) of a Blender point around the plaza centre, in the plaza's x/z plane."""
    x, z = co.x - PLAZA["cx"], -co.y - PLAZA["cz"]
    return math.atan2(z, x), math.hypot(x, z)


def mesa_ledge_edge(t):
    """Distance from the plaza centre to the ledge's outer edge, and the ledge's width, at angle t."""
    ox, oz = mesa_point(t, LEDGE_Y, MESA_LEDGE_OFF)
    ix, iz = mesa_point(t, LEDGE_Y, 3.0)
    return math.hypot(ox, oz), math.hypot(ox, oz) - math.hypot(ix, iz)


def build_mesa(bm, seg=200):
    p = PLAZA
    # (y, offset) from the top edge; the ledge is two loops at the same height
    levels = [(575, 19), (582, 18), (600, 14), (LEDGE_Y - 0.01, 12), (LEDGE_Y, 12), (LEDGE_Y, 3.0),
              (630, 2.0), (642, 0.7), (MESA_Y, 0.0)]
    rings = []
    for y, off in levels:
        ring = []
        for i in range(seg):
            x, z = mesa_point(2 * math.pi * i / seg, y, off)
            ring.append(bv(p["cx"] + x, y, p["cz"] + z))
        rings.append(ring)
    loft(bm, rings)


def build_mesa_lawn(seg=800):  # fine enough to follow the rounded corners without zigzags
    """The mesa ledge's lawn as one exact slab like the terrace's: top at LEDGE_Y, a straight green side
    LIP deep on the ledge's outer edge, running in under the upper wall. Where there's no ledge (south) the
    slab sits just inside the wall, hidden."""
    bm = bmesh.new()
    rings = []
    for off, z in [(0.0, LEDGE_Y - LIP), (0.0, LEDGE_Y), (2.5, LEDGE_Y), (6.0, LEDGE_Y), (MESA_LAWN_W, LEDGE_Y)]:
        ring = []
        for i in range(seg):
            t = 2 * math.pi * i / seg
            edge, width = mesa_ledge_edge(t)
            r = edge - (0.6 if width < 3.0 else 0.0) - off
            ring.append(bv(PLAZA["cx"] + math.cos(t) * r, z, PLAZA["cz"] + math.sin(t) * r))
        rings.append(ring)
    loft(bm, rings, cap_top=False, cap_bottom=False)
    bm.normal_update()
    flip = []
    for f in bm.faces:
        c = f.calc_center_median()
        t, _ = mesa_polar(c)
        out = bv(math.cos(t), 0, math.sin(t))
        if (c.z > LEDGE_Y - 0.01 and f.normal.z < 0) or (c.z < LEDGE_Y - 0.01 and f.normal.dot(out) < 0):
            flip.append(f)
    bmesh.ops.reverse_faces(bm, faces=flip)
    # no lawn where there's no ledge (south, in front of the GrandStairs): the wall's columns would expose it
    bare = [f for f in bm.faces if mesa_ledge_edge(mesa_polar(f.calc_center_median())[0])[1] < 3.0]
    bmesh.ops.delete(bm, geom=bare, context='FACES')
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def mesa_ledge_wall(bm):
    """Same flush band as rim_wall, under the mesa ledge's outer edge."""
    for v in bm.verts:
        co = v.co
        depth = LEDGE_Y - co.z
        if depth < -0.5 or depth > LIP + 16.0:
            continue
        t, d = mesa_polar(co)
        edge, width = mesa_ledge_edge(t)
        if width < 3.0 or not edge - 4.0 < d < edge + 6.0:  # only the ledge's own edge, not the towers behind
            continue
        if depth <= LIP + 0.05:
            target = edge - 0.15 if (depth > 0.05 or d > edge - 1.5) else d
        else:
            flush = edge - 0.15
            top = crown_top(co, LIP)
            target = flush + (d - flush) * smoothstep(top, top + 10.0, depth)
        x, z = co.x - PLAZA["cx"], -co.y - PLAZA["cz"]
        if d > 1e-6:
            co.x = PLAZA["cx"] + x * target / d
            co.y = -(PLAZA["cz"] + z * target / d)


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


def build_pine_ledges():
    """One clean ledge per cliff pine, kept out of the remeshed body so the rock detail can't break it into
    steps: a rock wedge sunk back into the cliff, and a grass cap with the same turf lip as the lawns."""
    rock, grass = bmesh.new(), bmesh.new()
    seg = 10
    for k, (x, y, z, size) in enumerate(CLIFF_PINES):
        d = Vector((x, z)).normalized()
        side = Vector((-d.y, d.x))
        top = y - 0.7
        w = max(7.0, size * 0.55)
        half = (26.0 + w * 0.5) / 2          # outer edge just past the trunk, back edge deep in the cliff
        mid = Vector((x, z)) + d * (w * 0.5 - half)

        def ring(scale, h, back=0.0):
            pts = []
            for i in range(seg):
                t = 2 * math.pi * i / seg
                j = 1.0 + 0.12 * noise.noise(Vector((math.cos(t) * 1.3 + k * 5.1, math.sin(t) * 1.3, 0.4)))
                c = mid - d * back + d * (math.cos(t) * half * scale * j) + side * (math.sin(t) * w * 1.1 * scale * j)
                pts.append(bv(c.x, h, c.y))
            return pts

        # grass slab and the rock under it share one outline; the rock keeps a solid band, then tucks back
        # into the cliff
        cap = ring(1.0, top)
        lip = ring(1.0, top - LIP)
        band = ring(0.97, top - LIP - 2.5)
        foot = ring(0.45, top - w * 1.4, back=half * 0.9)
        loft(grass, [lip, cap], cap_top=False, cap_bottom=False)
        cv = [grass.verts.new(p) for p in cap]
        centre = grass.verts.new(bv(mid.x, top, mid.y))
        for i in range(seg):
            grass.faces.new((cv[i], cv[(i + 1) % seg], centre))
        loft(rock, [foot, band, lip], cap_top=False)
    for b in (rock, grass):
        bmesh.ops.remove_doubles(b, verts=b.verts[:], dist=0.001)
        bmesh.ops.recalc_face_normals(b, faces=b.faces)
        bmesh.ops.triangulate(b, faces=b.faces[:])
    return rock, grass


def build_upper():
    bm = bmesh.new()
    build_cliff(bm)
    build_mesa(bm)
    build_massif(bm)
    build_spires(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = link("MP_Upper", bm)
    rm = obj.modifiers.new("Remesh", 'REMESH')
    rm.mode = 'VOXEL'
    rm.voxel_size = VOXEL
    rm.use_smooth_shade = False
    apply_all(obj)
    return obj


# --- sculpting the remeshed body ---------------------------------------------

def columns(co, cell, amp):
    """Vertical prisms: 2D Voronoi over x/y, each cell pushed out by its own amount, sharp between cells."""
    d, pts = noise.voronoi(Vector((co.x / cell, co.y / cell, 0.0)), distance_metric='DISTANCE', exponent=2.5)
    o0, o1 = cell_hash(pts[0]), cell_hash(pts[1])
    k = smoothstep(0.0, 0.1, d[1] - d[0])
    return ((o0 + o1) * 0.5 * (1 - k) + o0 * k) * amp - d[0] * amp * 0.3, pts[0]


def spire_detail(co, s):
    """Karst-pillar relief: vertical buttresses with finer ribs on them, and broken ledges that wander up
    and down. The stacked blocks used on the cliffs smoothed into a melted cone on a spire this
    tall."""
    big, cell = columns(co, 16.0 * s, 5.0 * s)
    rib, _ = columns(co, 6.0 * s, 1.8 * s)
    layer = (co.z + 12.0 * noise.noise(Vector((co.x / 35.0, co.y / 35.0, 2.2)))) / 19.0
    n = math.floor(layer)
    t = layer - n
    # only some buttress/layer pairs get a ledge, so they read as breaks, not rings
    ledge = cell_hash(cell + Vector((0, 0, n * 3.1))) > 0.45
    groove = -2.2 * (1.0 - smoothstep(0.0, 0.35, t)) * s if ledge else 0.0
    return big + rib + groove


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


def build_terrace_lawn(seg=1024):  # fine enough to follow the bridge and waterfall notches
    """The terrace lawn as one exact slab: top at TERRACE_Y out to the cliff rim, then a straight green
    side LIP deep on the rim's outline. Inward it runs under the mesa and massif walls (hidden)."""
    bm = bmesh.new()
    rings = []
    for off, z in [(0.0, TERRACE_Y - LIP), (0.0, TERRACE_Y), (3.0, TERRACE_Y), (8.0, TERRACE_Y),
                   (16.0, TERRACE_Y), (30.0, TERRACE_Y), (50.0, TERRACE_Y), (TERRACE_LAWN_W, TERRACE_Y)]:
        ring = []
        for i in range(seg):
            th = 2 * math.pi * i / seg
            r = cliff_radius(th, TERRACE_Y) - off
            ring.append(bv(math.cos(th) * r, z, math.sin(th) * r))
        rings.append(ring)
    loft(bm, rings, cap_top=False, cap_bottom=False)
    bm.normal_update()
    flip = []
    for f in bm.faces:
        c = f.calc_center_median()
        out = Vector((c.x, c.y, 0)).normalized()
        if (c.z > TERRACE_Y - 0.01 and f.normal.z < 0) or (c.z < TERRACE_Y - 0.01 and f.normal.dot(out) < 0):
            flip.append(f)
    bmesh.ops.reverse_faces(bm, faces=flip)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def in_rim(co):
    """The thin bands along the terrace and mesa-ledge edges that smoothing and decimation leave alone."""
    if LEDGE_Y - LIP - 1.0 < co.z < LEDGE_Y + 0.5:
        t, d = mesa_polar(co)
        edge, width = mesa_ledge_edge(t)
        return width >= 3.0 and edge - 2.0 < d < edge + 1.0
    if not TERRACE_Y - LIP - 1.0 < co.z < TERRACE_Y + 0.5:
        return False
    r = math.hypot(co.x, co.y)
    return r > 150 and r > cliff_radius(math.radians(world_angle(co.x, co.y)), TERRACE_Y) - 2.0


def rim_wall(bm):
    """Square off the terrace edge like the cliff ledges: the top meets a straight wall LIP deep on the
    rim's outline (the lawn wraps exactly that), then the rock stays inside the outline with its blocks
    sunk inward before the cliff widens out again lower down."""
    for v in bm.verts:
        co = v.co
        depth = TERRACE_Y - co.z
        r = math.hypot(co.x, co.y)
        if r < 150 or depth < -0.5 or depth > LIP + 16.0:
            continue
        th = math.radians(world_angle(co.x, co.y))
        rim = cliff_radius(th, TERRACE_Y)
        if depth <= LIP + 0.05:
            target = rim - 0.15 if (depth > 0.05 or r > rim - 1.5) else r  # just behind the lawn slab's side
        else:
            # a solid band flush under the slab (like the cliff ledges), then the blocks fade back in; inside
            # the blend nothing pokes past the rim
            flush = rim - 0.15
            top = crown_top(co, LIP)
            target = flush + (r - flush) * smoothstep(top, top + 10.0, depth)
        if r > 1e-6:
            co.x *= target / r
            co.y *= target / r


def pine_clear(co):
    """0 right around a cliff pine's ledge, 1 elsewhere."""
    k = 1.0
    for x, y, z, size in CLIFF_PINES:
        dist = math.hypot(co.x - x, co.y + z)
        k = min(k, max(smoothstep(size + 4.0, size + 14.0, dist), smoothstep(12.0, 24.0, abs(co.z - y))))
    return k


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
        elif r > 150 and y < TERRACE_Y + 0.5:
            s = 1.3
        elif -co.y > 105 and abs(co.x) < 112:
            s = 0.85   # mesa front behind the GrandStairs: shallower blocks so few hit the clamp
        else:
            s = 1.0
        if y > 806 and math.hypot(co.x - 2, -co.y + 90) < 9:
            continue  # summit cap stays clean for the Summit anchor
        old_r, old_z = r, -co.y
        if y > 652:
            detail = spire_detail(co, s)
        else:  # around the pine ledges the columns only recess, so they can't bury a slab
            c, k = stone_columns(co, s)[0], pine_clear(co)
            detail = c * k + min(c, 0.0) * (1.0 - k)
        co += h * (detail * f)
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
    rim_wall(bm)
    mesa_ledge_wall(bm)
    bm.to_mesh(obj.data)
    bm.free()
    rim = obj.vertex_groups.new(name="Rim")
    rim.add([v.index for v in obj.data.vertices if in_rim(v.co)], 1.0, 'REPLACE')
    sm = obj.modifiers.new("Smooth", 'SMOOTH')
    sm.factor = 0.2  # just the voxel jaggies: the column edges stay crisp
    sm.iterations = 1
    sm.vertex_group, sm.invert_vertex_group = "Rim", True  # the terrace edge stays crisp
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
    if obj.vertex_groups.get("Rim"):
        dec.vertex_group, dec.invert_vertex_group = "Rim", True
    tri = obj.modifiers.new("Tri", 'TRIANGULATE')
    apply_all(obj)


# --- base below the clouds ---------------------------------------------------

def base_profile(h):
    # the top overlaps the cliff ring's foot (r ~172 at y 410) so the rock runs straight through the cloud deck
    return lerp_knots([(-10, 222), (60, 220), (150, 216), (250, 212), (330, 204), (370, 192), (400, 182),
                       (420, 176), (440, 170)], h)


def build_base(seg=180):
    rings = []
    y = -10.0
    ys = []
    while y < 440:
        ys.append(y)
        y += 3.0 if y > 250 else 6.0
    ys.append(440.0)
    for y in ys:
        ring = []
        for i in range(seg):
            th = 2 * math.pi * i / seg
            d = Vector((math.cos(th), math.sin(th), 0))
            r = base_profile(y) * (1.0 + 0.05 * noise.noise(Vector((d.x * 1.2, d.y * 1.2, 9.3 + y * 0.003))))
            p = bv(math.cos(th) * r, y, math.sin(th) * r)
            h = Vector((p.x, p.y, 0)).normalized()
            # same column blocks as the cliff above (tall cells), coarsening toward the ground
            # the same columns as the cliff above (same cell scale where they meet), coarser toward the ground
            p += h * stone_columns(p, 1.3 + 0.9 * smoothstep(400, 150, y))[0]
            ring.append(p)
        rings.append(ring)
    bm = bmesh.new()
    loft(bm, rings, cap_top=False)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = link("MP_Base", bm)
    sm = obj.modifiers.new("Smooth", 'SMOOTH'); sm.factor = 0.15; sm.iterations = 1
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


def is_grass(f):
    c = f.calc_center_median()
    return c.z >= 430 and not under_floor(c) and f.normal.z > 0.6


def bare_lip(co):
    """Bridge landings and waterfall lips stay bare rock."""
    a = world_angle(co.x, co.y)
    return math.hypot(co.x, co.y) > 165 and co.z > 540 and cap_radius(a, co.z) is not None


def patches(faces):
    """Connected groups of the given faces."""
    cand, seen, out = set(faces), set(), []
    for f in cand:
        if f in seen:
            continue
        seen.add(f)
        stack, patch = [f], []
        while stack:
            g = stack.pop()
            patch.append(g)
            for e in g.edges:
                for n in e.link_faces:
                    if n in cand and n not in seen:
                        seen.add(n)
                        stack.append(n)
        out.append(patch)
    return out


def rim_level(patch):
    """Median height of a patch's edge, so one low dip doesn't drag the whole lip down the cliff."""
    inside = set(patch)
    zs = sorted(v.co.z for f in patch for e in f.edges
                if sum(n in inside for n in e.link_faces) == 1 for v in e.verts)
    return zs[len(zs) // 2]


def lawn_faces(bm, is_seed, keep, skip=lambda c: False):
    """Grass = the kept up-facing patches, wrapped LIP studs down over their edges. Each patch's edge is first
    sliced level LIP below its edge's median height, so the turf ends on one clean contour instead of following
    the zigzag of decimated triangles."""
    def seeds():
        return [p for p in patches([f for f in bm.faces if is_seed(f)]) if keep(p)]

    cuts = []
    for p in seeds():
        z = rim_level(p) - LIP
        cuts.append(z)
        xs = [v.co.x for f in p for v in f.verts]
        ys = [v.co.y for f in p for v in f.verts]
        near = [f for f in bm.faces if min(xs) - 4 < f.calc_center_median().x < max(xs) + 4
                and min(ys) - 4 < f.calc_center_median().y < max(ys) + 4
                and abs(f.calc_center_median().z - z) < 6]
        geom = list({x for f in near for x in list(f.verts) + list(f.edges)}) + near
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z), plane_no=(0, 0, 1))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.normal_update()
    out = set()
    for p in seeds():
        # the cut made for this patch (slicing can nudge its rim level a hair)
        floor = min(cuts, key=lambda z: abs(z - (rim_level(p) - LIP))) - 0.01
        top = [f for f in p if min(v.co.z for v in f.verts) >= floor]  # steep seeds below the cut stay rock
        out.update(top)
        stack = top
        while stack:  # grow downhill only, so walls rising behind a lawn stay rock
            f = stack.pop()
            fz = f.calc_center_median().z
            for e in f.edges:
                for n in e.link_faces:
                    if n in out:
                        continue
                    c = n.calc_center_median()
                    if c.z <= fz + 0.05 and min(v.co.z for v in n.verts) >= floor and not skip(c):
                        out.add(n)
                        stack.append(n)
    return list(out), cuts


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


SHARP_ANGLE = math.radians(28)


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
    # the big lawns, plus the ledges pines stand on; every other flat stays rock so the cliffs aren't freckled
    lawn, cuts = lawn_faces(bm, is_grass, lambda p: sum(f.calc_area() for f in p) >= MIN_LAWN,
                            skip=lambda c: bare_lip(c) or under_floor(c))
    # the terrace lawn is its own exact slab; the body's own lawn faces there are dropped under it
    def on_mesa_ledge(c):
        t, d = mesa_polar(c)
        return d < mesa_ledge_edge(t)[0] + 0.5

    # the terrace and the mesa ledge get exact lawn slabs; the body's own flats there are dropped under them
    def under_slab(c):
        if c.z < TERRACE_Y + FOOT_CUT + 1.5:
            rim = cliff_radius(math.radians(world_angle(c.x, c.y)), TERRACE_Y)
            return math.hypot(c.x, c.y) > rim - TERRACE_LAWN_W
        if LEDGE_Y - LIP - 1.0 < c.z < LEDGE_Y + 3.0:
            t, d = mesa_polar(c)
            edge, width = mesa_ledge_edge(t)
            return d > edge - MESA_LAWN_W and d < edge + 0.5
        return False

    # Nothing is deleted from the rock (deleting left holes wherever the wall's columns recess past a slab's
    # inner edge). Instead the rock under each slab is pushed just below the lawn: lawn faces a slab covers
    # stay rock, and they, the bare flats there and the wall feet up to FOOT_CUT drop to SUNK under the slab.
    SUNK = 0.6
    drop = {f for f in lawn if under_slab(f.calc_center_median())}
    for f in bm.faces:
        c = f.calc_center_median()
        if f.normal.z > 0.9 and abs(c.z - TERRACE_Y) < 0.05 and under_slab(c):
            drop.add(f)
        elif f.normal.z > 0.9 and abs(c.z - LEDGE_Y) < 0.05 and on_mesa_ledge(c) and under_slab(c):
            drop.add(f)
    sunk = set()
    for f in drop:
        level = TERRACE_Y if f.calc_center_median().z < TERRACE_Y + FOOT_CUT + 1.5 else LEDGE_Y
        for v in f.verts:
            if v not in sunk and v.co.z > level - SUNK:
                v.co.z = level - SUNK
                sunk.add(v)

    def covered(c, level):
        # only where that slab (a ring, not a disc) covers it
        if level == TERRACE_Y:
            rim = cliff_radius(math.radians(world_angle(c.x, c.y)), TERRACE_Y)
            return rim - TERRACE_LAWN_W + 1.0 < math.hypot(c.x, c.y) < rim - 3.0
        t, d = mesa_polar(c)
        edge, width = mesa_ledge_edge(t)
        return width >= 3.0 and edge - MESA_LAWN_W + 1.0 < d < edge - 3.0

    # walls rising off a slab meet it on one straight line: slice level at FOOT_CUT and drop the ragged foot
    # below the cut straight down under the grass, so no rock teeth poke through
    for level in (TERRACE_Y, LEDGE_Y):
        cut = level + FOOT_CUT
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, cut), plane_no=(0, 0, 1))
        for v in bm.verts:
            if level - SUNK < v.co.z < cut - 0.01 and covered(v.co, level):
                v.co.z = level - SUNK
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.verts.index_update()
    lawn = [f for f in lawn if f.is_valid and f not in drop]
    grass = extract(bm, lawn)
    for slab in (build_terrace_lawn(), build_mesa_lawn()):
        me = bpy.data.meshes.new("tmp_lawn_slab")
        slab.to_mesh(me)
        slab.free()
        grass.from_mesh(me)
        bpy.data.meshes.remove(me)
    spire = extract(bm, [f for f in bm.faces if f.calc_center_median().z > 652])
    mesa = extract(bm, [f for f in bm.faces if f.calc_center_median().z > TERRACE_Y + 1.0
                        and math.hypot(*f.calc_center_median().xy) < 165])
    def sector(f):
        c = f.calc_center_median()
        return int(((world_angle(c.x, c.y) + 30) % 360) // 120)
    cliff_a = extract(bm, [f for f in bm.faces if sector(f) == 0])
    cliff_b = extract(bm, [f for f in bm.faces if sector(f) == 1])
    ledges, ledge_grass = build_pine_ledges()
    ledge_grass.verts.ensure_lookup_table()
    me = bpy.data.meshes.new("tmp_ledge_grass")
    ledge_grass.to_mesh(me)
    ledge_grass.free()
    grass.from_mesh(me)  # appends the ledge caps to the lawn mesh
    bpy.data.meshes.remove(me)
    meshes = {"MainRockSpire": spire, "MainRockMesa": mesa, "MainRockCliffA": cliff_a, "MainRockCliffB": cliff_b,
              "MainRockCliffC": bm, "MainGrass": grass, "MainLedges": ledges}
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
