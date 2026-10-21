"""Builds the MainPeak rock meshes (spirit-peak style) and exports them for Roblox.

Run inside Blender (Text Editor or exec; builds into its own scene "MainPeak"), or headless on the saved file:
  blender.exe -b art/main_peak/MainPeakRock.blend --python art/main_peak/build_main_peak.py
  append "-- <out_dir> [save]" to write the FBX/JSON elsewhere and re-save the .blend there
Coordinates: 1 Blender unit = 1 stud, Blender origin = world origin, Blender (x, y, z) = world (X, -Z, Y).
So in Roblox: placement frame is CFrame.identity (see place_main_peak.luau).

Layout (world coords), matching the existing gameplay structures (plan: docs/systems/map.md, "Main peak"):
  ring terrace   y 582, rim r~185      bridgeheads r 172.5 at 22.5+45k deg; one rim notch (RIM_NOTCH) where the
                 west waterfall's stream leaves the terrace and drops down a chute in the cliff
  plaza mesa     y 647 under Plaza.PlazaFloor (x +-100, z -35..115); ledge at y 614; south wall kept
                 clear of GrandStairs flights (z >= 129)
  summit tower   flat top y 791 (SUMMIT_TOP) at (2, -90); SkySteps start on it at (-7, 794, -94) and climb to
                 the tribulation disc (Y ~855, r 30) floating above
  base           y -10 .. 432, coarse, hidden under the cloud deck (tops y 415-424)
  mesa clefts    two vertical grooves in the mesa walls for the falls (MESA_CLEFTS)
  cliff ledges   five deliberate ones (LEDGES): a shrine ledge under the balcony, a waterfall step in the chute,
                 three pine ledges of different sizes in one cluster on the south-west face

Colour comes from splitting meshes: rock is split per stone column into three value tones
(MainRock<Region>1..3, Region = Spire/Mesa/Cliff/Foot) and textured in Studio. Walkable floors are Roblox
Terrain written by terrain_main_peak.luau from the outlines this script exports (JSON "terrain"); a moss band
hangs under the terrace rim on a few arcs (MainMoss).
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Vector, noise
from mathutils.kdtree import KDTree

import sys
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []   # headless: -- [out_dir] [save]
OUT_DIR = next((a for a in ARGS if a != "save"), None) or (os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals()
                                          else bpy.path.abspath("//"))
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
# the one notch in the terrace rim: the west fall's stream leaves the terrace here and drops down a chute
RIM_NOTCH = dict(angle=186.0, half=3.0, blend=2.5, r=176.0)   # world deg, half-width/blend deg, cap radius
# vertical grooves in the mesa walls that the falls run down; (x, z) is the wall's top edge point,
# side -1 = west wall (groove pushes +x), +1 = east wall; the 614 ledge between the two west runs is the step
MESA_CLEFTS = [
    dict(x=-102.0, z=-16.0, side=-1, w=7.0, depth=4.0, spans=[(585.0, 612.0), (616.0, 639.0)]),
    dict(x=102.0, z=-6.0, side=1, w=5.0, depth=3.5, spans=[(585.0, 604.0)]),
]

# (x, z, lean per 100 studs (x, z), [(y, radius), ...]) world coords; lean is applied above y 648.
# Zhangjiajie-style sandstone towers (docs/systems/map.md): near-sheer sides, flat tops that carry green tufts,
# horizontal bedding. All different heights; tops end square (a short shoulder, not a dome).
# Feet stay inside r ~150 so the terrace ring (and the north bridgeheads at r 168.5) stays open, and below
# y 648 north of z -40 so nothing pokes up behind the plaza balustrade.
SUMMIT_TOP = 791.0   # flat top under the SkySteps' first stone (-6.8, 794, -94); the tribulation disc floats above
SPIRES = [
    # the summit tower
    (2, -90, (0, 0), [(570, 40), (648, 35), (700, 31), (740, 28), (770, 25.5), (784, 23.5), (789, 22.5),
                      (SUMMIT_TOP, 21)]),
    # shoulder towers packed around it
    (-30, -68, (-3, 2), [(575, 24), (648, 21), (700, 19), (740, 17), (752, 16), (755, 14.5)]),
    (36, -66, (3, 2), [(575, 22), (648, 19), (690, 17), (718, 15), (724, 14), (726, 12.5)]),
    (30, -120, (3, -4), [(575, 25), (648, 22), (720, 20), (762, 18), (770, 17), (773, 15.5)]),
    (-26, -122, (-3, -4), [(575, 22), (648, 19), (690, 17), (708, 15), (713, 14), (715, 12.5)]),
    (-62, -98, (-7, -2), [(575, 22), (648, 17), (676, 15), (690, 13), (694, 12), (696, 10.5)]),
    (64, -96, (7, -2), [(575, 20), (648, 16), (668, 14), (680, 12), (684, 11), (686, 9.5)]),
    (4, -138, (0, -6), [(575, 20), (648, 17), (690, 15), (702, 13), (706, 12), (708, 10.5)]),
    # two slender column towers at the back, under the summit's height
    (-44, -128, (-1.5, -2), [(575, 14), (648, 13), (700, 11.5), (745, 10), (762, 9), (767, 8)]),
    (52, -126, (2, -1.5), [(575, 13), (648, 12), (700, 11), (735, 9.5), (746, 8.5), (750, 8)]),
]
SPIRE_MIN_TUFT = 60.0
LEDGE_RECESS = 1.2   # cliff-ledge basins sit this far below their stone lip; terrain grass fills them   # studs^2: flats on the towers above this get grass (tops and ledges), smaller stay rock
MASSIF = dict(cx=0.0, cz=-96.0, levels=[(575, 100, 46), (582, 100, 46), (620, 90, 44), (650, 76, 40),
                                          (680, 50, 30), (695, 22, 13)])

# Cliff ledges (world x, y, z at the cliff face, footprint, kind). Each has a reason (docs/systems/map.md):
# the shrine ledge under the south balcony (seen from the balcony and the Peak_1 / Peak_8 bridges), the
# waterfall step in the RIM_NOTCH chute, and a pine cluster (big, medium, small) on the south-west face.
LEDGES = [
    (0.0, 548.0, 189.0, 30, "shrine"),
    (-181.5, 536.0, -19.1, 13, "fall"),
    (-125.3, 548.0, 140.7, 20, "pine"),
    (-157.4, 528.3, 109.7, 13, "pine"),
    (-160.3, 506.0, 118.9, 8, "pine"),
]
# moss hanging under the terrace's turf lip on a few arcs (world deg from, to; max depth below the lip)
MOSS_ARCS = [(34.0, 58.0, 4.5), (128.0, 150.0, 6.0), (196.0, 212.0, 3.5), (286.0, 318.0, 5.0)]
# terrace lawn sectors: boundaries (world deg), each sector one of three shades, neighbours differ
LAWN_SECTORS = [0.0, 31.0, 78.0, 104.0, 151.0, 197.0, 236.0, 262.0, 301.0, 338.0]
LAWN_SHADES = [1, 2, 3, 1, 2, 1, 3, 2, 3, 2]

ROCK_REGIONS = ["Spire", "Mesa", "Cliff"]
PARTS = [  # export meshes: name, preview colour
    *[("MainRock%s%d" % (r, k), (0.48 - 0.05 * k, 0.46 - 0.05 * k, 0.44 - 0.05 * k, 1))
      for r in ROCK_REGIONS for k in (1, 2, 3)],
    *[("MainRockFoot%d" % k, (0.48 - 0.05 * k, 0.46 - 0.05 * k, 0.44 - 0.05 * k, 1)) for k in (1, 2, 3)],
    ("MainMoss", (0.31, 0.42, 0.27, 1)),
    ("MainLedges", (0.45, 0.43, 0.41, 1)),
]
# Walkable floors (terrace lawn, ring path, plaza ledge, cliff-ledge tops) are Roblox Terrain, written by
# art/main_peak/terrain_main_peak.luau from the outlines this script exports (JSON "terrain"); the rock under
# them is sunk TERRAIN_SINK below the floor height so the terrain covers it.
TERRAIN_SINK = 1.5
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
        n = RIM_NOTCH
        d = ang_diff(a, n["angle"])
        if d < n["half"] + n["blend"]:
            c = n["r"] + 30 * smoothstep(n["half"], n["half"] + n["blend"], d)
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
    """The mesa ledge's lawn as one exact slab like the terrace's: top at LEDGE_Y, a turf lip bulging a little
    past the ledge's outer edge, running in under the upper wall. No lawn where there's no ledge (south, in
    front of the GrandStairs). Returns (lip, top)."""
    def ring(off, depth):
        pts = []
        for i in range(seg):
            t = 2 * math.pi * i / seg
            edge, width = mesa_ledge_edge(t)
            r = edge - (0.6 if width < 3.0 else 0.0) - off
            pts.append(bv(PLAZA["cx"] + math.cos(t) * r, LEDGE_Y - depth, PLAZA["cz"] + math.sin(t) * r))
        return pts

    lip_rings = [ring(o, d) for o, d in LIP_RINGS]
    top_rings = [lip_rings[-1]] + [ring(o, 0.0) for o in (2.5, 6.0, MESA_LAWN_W)]

    def outward(c):
        t, _ = mesa_polar(c)
        return bv(math.cos(t), 0, math.sin(t))

    lip, top = slab_lofts(lip_rings, top_rings, outward, LEDGE_Y)
    for bm in (lip, top):
        bare = [f for f in bm.faces if mesa_ledge_edge(mesa_polar(f.calc_center_median())[0])[1] < 3.0]
        bmesh.ops.delete(bm, geom=bare, context='FACES')
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return lip, top


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
    """The towers' feet, remeshed with the massif so they grow out of it; above TOWER_SPLIT build_towers takes
    over."""
    for k, (sx0, sz0, lean, knots) in enumerate(SPIRES):
        rings = []
        y0, y1 = knots[0][0], min(knots[-1][0], TOWER_FROM + 24.0)
        y = y0
        while True:
            r = lerp_knots(knots, y)
            sx, sz = spire_axis(sx0, sz0, lean, y)
            ring = []
            for i in range(seg):
                t = 2 * math.pi * i / seg
                n = 1.0 + 0.16 * noise.noise(Vector((math.cos(t) * 1.4 + k * 7, math.sin(t) * 1.4, y * 0.012)))
                if y >= y1 - 0.01 and k == 0:
                    n = 1.0   # the summit's top stays a clean flat for the SkySteps
                ring.append(bv(sx + math.cos(t) * r * n, y, sz + math.sin(t) * r * n))
            rings.append(ring)
            if y >= y1:
                break
            y = min(y1, y + 6)
        loft(bm, rings)


def column_prism(rock, grass, c, rad, n, rot, ctop, deep, seed, back=None, grass_cap=False):
    """One stone column stump: an n-sided prism (world centre c = Vector((x, z))) from `deep` up to `ctop`,
    narrowing toward its foot (and shifted by `back` there, to tuck into a cliff). With grass_cap, a grass
    polygon inset in its top so a rim of stone shows around it."""
    back = back or Vector((0.0, 0.0))

    def poly(scale, hgt, shift=Vector((0.0, 0.0)), inset=0.0):
        pts = []
        for m in range(n):
            t = rot + 2 * math.pi * m / n
            rr = (rad - inset) * scale * (0.9 + 0.2 * cell_hash(Vector((m, seed, 1.7))))
            q = c + shift + Vector((math.cos(t), math.sin(t))) * rr
            pts.append(bv(q.x, hgt, q.y))
        return pts

    loft(rock, [poly(0.6, deep, back), poly(1.0, ctop - min(2.0, (ctop - deep) * 0.3)), poly(1.0, ctop)])
    if grass_cap:
        grass.faces.new([grass.verts.new(p) for p in poly(1.0, ctop + 0.06, inset=min(0.55, rad * 0.25))])


TOWER_FROM = 600.0   # faceted tower stacks start here, buried in the massif; the remeshed spires end below
TOWER_SPLIT = 652.0  # remeshed spire tubes are cut off at this height (the stacks take over)


def clip_poly(poly, a, b, c):
    """Keep the part of a 2D polygon (list of (x, y)) where a*x + b*y <= c."""
    out = []
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        dp, dq = a * p[0] + b * p[1] - c, a * q[0] + b * q[1] - c
        if dp <= 0:
            out.append(p)
        if (dp < 0) != (dq < 0) and abs(dp - dq) > 1e-12:
            t = dp / (dp - dq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def voronoi_cells(points, boundary):
    """Voronoi cell of each point, clipped to the boundary polygon (all 2D)."""
    cells = []
    for i, p in enumerate(points):
        poly = list(boundary)
        for j, q in enumerate(points):
            if i == j or not poly:
                continue
            a, b = q[0] - p[0], q[1] - p[1]
            c = (q[0] ** 2 + q[1] ** 2 - p[0] ** 2 - p[1] ** 2) / 2
            poly = clip_poly(poly, a, b, c)
        cells.append(poly)
    return cells


def build_towers():
    """The towers above the massif as bundles of vertical stone columns, the same rock as the cliffs and the
    spirit-peak pillars: each tower's cross-section is split into Voronoi cells (unit disc, scaled by the
    tower's radius profile at each height); the cells on the outside run the full height as columns, each in
    stacked segments that step a little in or out (the breaks land at different heights per column), with a
    narrow groove between neighbours. Inner cells only rise above a hidden core near the top. Every column
    ends at its own height: the outer ones lower, the middle ones highest, so a tower's top is an irregular
    crown of column tops stepping up. The summit's middle columns end level at SUMMIT_TOP (the SkySteps
    start there). Returns {tone: bmesh}."""
    out = {1: bmesh.new(), 2: bmesh.new(), 3: bmesh.new()}
    disc = [(math.cos(2 * math.pi * i / 28), math.sin(2 * math.pi * i / 28)) for i in range(28)]
    for k, (sx0, sz0, lean, knots) in enumerate(SPIRES):
        y1, r_top = knots[-1]
        r_ref = lerp_knots(knots, 650.0)
        n_cells = max(7, min(16, int(r_ref * 0.55)))
        # points: a ring of outer cells and a few inner ones, jittered
        pts = []
        n_out = max(6, n_cells - max(1, n_cells // 4))
        for i in range(n_out):
            t = 2 * math.pi * (i + 0.5 * cell_hash(Vector((k, i, 0.7)))) / n_out
            rr = 0.78 + 0.12 * cell_hash(Vector((k, i, 1.3)))
            pts.append((math.cos(t) * rr, math.sin(t) * rr))
        for i in range(n_cells - n_out):
            t = 2 * math.pi * cell_hash(Vector((k, i, 2.9)))
            rr = 0.32 * cell_hash(Vector((k, i, 3.7)))
            pts.append((math.cos(t) * rr, math.sin(t) * rr))
        cells = voronoi_cells(pts, disc)
        for ci, (poly, p) in enumerate(zip(cells, pts)):
            if len(poly) < 3:
                continue
            cx = sum(q[0] for q in poly) / len(poly)
            cz = sum(q[1] for q in poly) / len(poly)
            dist = math.hypot(cx, cz)
            outer = dist > 0.5
            h = cell_hash(Vector((k * 3.1, ci, 4.4)))
            # crown: the middle reaches the top, outer columns stop lower (stepped, not a ring)
            if k == 0 and dist < 0.62:
                ctop = SUMMIT_TOP
            else:
                drop = (r_top * 1.1 + 4.0) * smoothstep(0.25, 0.95, dist) * (0.35 + 0.65 * h)
                ctop = y1 - drop - (0.0 if dist < 0.3 else 1.5 * h)
            cbot = TOWER_FROM if outer else ctop - (8.0 + 10.0 * h)
            # inset toward the cell centre: a narrow groove between neighbours
            inset = 0.88

            seg_len = 14.0 + 22.0 * cell_hash(Vector((k, ci, 6.1)))
            phase = seg_len * cell_hash(Vector((k, ci, 7.7)))
            # segment boundaries (stacked column pieces); each piece pushes out by its own amount
            ys = [cbot]
            y = math.floor((cbot + phase) / seg_len) * seg_len - phase + seg_len
            while y < ctop - 3.0:
                ys.append(y)
                y += seg_len
            ys.append(ctop)
            ddir = Vector((cx, cz)).normalized() if dist > 1e-6 else Vector((0.0, 0.0))
            for si, (ya, yb) in enumerate(zip(ys, ys[1:])):
                push = (cell_hash(Vector((k, ci, si * 1.37))) - 0.3) * 0.09 if outer else 0.0

                def ring(yy, extra=1.0):
                    r = lerp_knots(knots, yy)
                    ax, az = spire_axis(sx0, sz0, lean, yy)
                    pts3 = []
                    for qx, qz in poly:
                        lx = cx + (qx - cx) * inset * extra
                        lz = cz + (qz - cz) * inset * extra
                        pts3.append(bv(ax + (lx + ddir.x * push) * r, yy, az + (lz + ddir.y * push) * r))
                    return pts3

                # each piece: a small bevel at its top so the stacked breaks catch light
                rings = [ring(ya), ring(max(ya, yb - 0.8)), ring(yb, 0.94)]
                tone = 1 if h < 0.34 else (2 if h < 0.72 else 3)
                if yb > 745 and tone == 3:
                    tone = 2   # the high columns lean lighter against the sky
                loft(out[tone], rings)
        # the hidden core the inner columns stand on (fills the gaps between the outer columns)
        core = []
        for yy in (TOWER_FROM, max(TOWER_FROM + 1, y1 - r_top * 1.1 - 6.0)):
            r = lerp_knots(knots, yy) * 0.72
            ax, az = spire_axis(sx0, sz0, lean, yy)
            core.append([bv(ax + math.cos(2 * math.pi * i / 16) * r, yy, az + math.sin(2 * math.pi * i / 16) * r)
                         for i in range(16)])
        loft(out[3], core)
    for bm in out.values():
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return out


def build_ledges():
    """The LEDGES as irregular stone shelves built from the same columns as the cliff: a jittered hex grid of
    5-7 sided column stumps whose tops step down toward the shelf's edges, each running down and tucking back
    into the cliff. Grass only on the shelf's main flat (the columns at full height), as caps inset in each
    column top so stone shows between them; the shrine ledge keeps its middle bare for the shrine.
    Returns (rock, grass caps, turf lips); the lips mesh stays empty (kept for the export list)."""
    rock, grass, lips = bmesh.new(), bmesh.new(), bmesh.new()
    for k, (x, y, z, size, kind) in enumerate(LEDGES):
        d = Vector((x, z)).normalized()
        side = Vector((-d.y, d.x))
        top = y - 0.7
        cell = 7.0 if size >= 20 else 5.0
        out_len = size * 0.55          # how far the shelf stands out of the cliff face
        half_w = size * 0.62
        rows = int(out_len / (cell * 0.866)) + 3
        cols = int(half_w / cell) + 2
        for i in range(-2, rows):
            for j in range(-cols, cols + 1):
                u = (j + (0.5 if i % 2 else 0.0)) * cell     # along the face
                v = i * cell * 0.866                          # out from the face (negative = into the cliff)
                h = cell_hash(Vector((k * 7.1 + i, j * 1.3, 2.0)))
                u += (h - 0.5) * cell * 0.5
                v += (cell_hash(Vector((i, k * 3.3 + j, 5.0))) - 0.5) * cell * 0.4
                # irregular footprint: wider near the face, ragged by column
                lim = half_w * (1.0 - max(0.0, v) / (out_len + 1e-6) * 0.55) * (0.8 + 0.35 * h)
                if abs(u) > lim or v > out_len:
                    continue
                edge = max(abs(u) / max(lim, 1e-6), max(0.0, v) / out_len)
                # the main flat is a shallow basin LEDGE_RECESS below the stone around it; terrain grass fills it
                # (terrain_main_peak.luau), so the green sits sunk in the stone. Edge columns step down.
                if edge < 0.55:
                    step = LEDGE_RECESS
                elif edge < 0.75:
                    step = -0.6 * cell_hash(Vector((i, j * 1.9, k + 7.0)))   # a stone lip just proud of the grass
                else:
                    step = (0.8 + 1.8 * cell_hash(Vector((i * 1.7, j, k + 9.0)))) * edge
                if kind == "shrine" and abs(u) < half_w * 0.45 and edge < 0.55:
                    step = 0.0  # the shrine's floor: bare stone, no basin
                if v < -cell * 0.5:
                    step = -1.5 - 3.0 * h  # columns at the back stand a little higher, against the cliff
                ctop = top - step
                c = Vector((x, z)) + side * u + d * v
                n = 5 + int(cell_hash(Vector((j, i, k + 4.0))) * 3)
                rot = cell_hash(Vector((i, j, k + 1.0))) * math.pi
                rad = cell * (0.58 + 0.12 * h)
                deep = ctop - (6.0 + size * 0.55 + 4.0 * h)

                def poly(scale, hgt, back=0.0, inset=0.0):
                    pts = []
                    for m in range(n):
                        t = rot + 2 * math.pi * m / n
                        rr = (rad - inset) * scale * (0.9 + 0.2 * cell_hash(Vector((m, i + j, k))))
                        q = c - d * back + Vector((math.cos(t), math.sin(t))) * rr
                        pts.append(bv(q.x, hgt, q.y))
                    return pts

                loft(rock, [poly(0.55, deep, back=cell * 0.8), poly(1.0, ctop - 2.0), poly(1.0, ctop)])
    for b in (rock, grass):
        bmesh.ops.recalc_face_normals(b, faces=b.faces)
        bmesh.ops.triangulate(b, faces=b.faces[:])
    for f in grass.faces:  # caps face up
        if f.normal.z < 0:
            f.normal_flip()
    return rock, grass, lips


def ledge_anchors():
    """Where things stand on each ledge (world x, y, z of the main flat), its outward direction and size."""
    out = []
    for x, y, z, size, kind in LEDGES:
        d = Vector((x, z)).normalized()
        stand = Vector((x, z)) + d * (size * 0.55 * 0.3)
        out.append(dict(kind=kind, size=size, top=[round(stand.x, 2), round(y - 0.7, 2), round(stand.y, 2)],
                        out=[round(d.x, 4), 0.0, round(d.y, 4)], half_w=round(size * 0.62, 2)))
    return out


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
    big, cell = columns(co, 16.0 * s, 7.0 * s)
    rib, _ = columns(co, 6.0 * s, 2.4 * s)
    # horizontal bedding like the Zhangjiajie sandstone: bands every ~11 studs that wander a little; most
    # buttress/band pairs get a shallow groove, some a deep one, so they read as strata, not rings
    layer = (co.z + 6.0 * noise.noise(Vector((co.x / 35.0, co.y / 35.0, 2.2)))) / 11.0
    n = math.floor(layer)
    t = layer - n
    hsh = cell_hash(cell + Vector((0, 0, n * 3.1)))
    depth = 2.6 if hsh > 0.75 else (1.2 if hsh > 0.3 else 0.0)
    groove = -depth * (1.0 - smoothstep(0.06, 0.14, t)) * s   # a crisp notch, not a rounded band
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


# the turf lip: (offset in from the edge, depth below the lawn) rings, from the lip's underside up to where
# the flat top starts; negative offsets overhang the rock
LIP_RINGS = [(-0.5, LIP + 0.3), (-0.9, 0.35), (-0.7, 0.0)]


def lip_scale(world_deg):
    """1 = full overhang; 0 at the bridge landings, where the bridge decks pass under the lawn's edge."""
    d = min(ang_diff(world_deg, b) for b in BRIDGE_ANGLES)
    return smoothstep(3.0, 6.0, d)


def slab_lofts(rings_lip, rings_top, outward, level):
    """Loft the lip and the top of a lawn slab into two bmeshes with outward/up normals."""
    out = []
    for rings in (rings_lip, rings_top):
        bm = bmesh.new()
        loft(bm, rings, cap_top=False, cap_bottom=False)
        bm.normal_update()
        flip = []
        for f in bm.faces:
            c = f.calc_center_median()
            o = outward(c)
            if (c.z > level - 0.01 and f.normal.z < 0) or (c.z < level - 0.01 and f.normal.dot(o) < 0):
                flip.append(f)
        bmesh.ops.reverse_faces(bm, faces=flip)
        out.append(bm)
    return out


def build_terrace_lawn(seg=1024):  # fine enough to follow the bridge landings and the rim notch
    """The terrace lawn as one exact slab: top at TERRACE_Y out to the cliff rim, then a turf lip that bulges
    a little past the rim and wraps LIP down. Inward it runs under the mesa and massif walls (hidden).
    Returns (lip, {shade: top})."""
    def ring(off, depth):
        pts = []
        for i in range(seg):
            th = 2 * math.pi * i / seg
            o = off if off >= 0 else off * lip_scale(math.degrees(th))
            r = cliff_radius(th, TERRACE_Y) - o
            pts.append(bv(math.cos(th) * r, TERRACE_Y - depth, math.sin(th) * r))
        return pts

    lip_rings = [ring(o, d) for o, d in LIP_RINGS]
    top_rings = [lip_rings[-1]] + [ring(o, 0.0) for o in (3.0, 8.0, 16.0, 30.0, 50.0, TERRACE_LAWN_W)]
    lip, top = slab_lofts(lip_rings, top_rings, lambda c: Vector((c.x, c.y, 0)).normalized(), TERRACE_Y)

    def shade(c):
        a = world_angle(c.x, c.y)
        k = max(i for i, b in enumerate(LAWN_SECTORS) if a >= b)
        return LAWN_SHADES[k]

    tops = partition(top, shade)
    bmesh.ops.triangulate(lip, faces=lip.faces[:])
    for b in tops.values():
        bmesh.ops.triangulate(b, faces=b.faces[:])
    return lip, tops


def partition(bm, key):
    """Split a bmesh's faces into new bmeshes by key(face centre)."""
    groups = {}
    for f in bm.faces:
        groups.setdefault(key(f.calc_center_median()), []).append(f)
    out = {}
    for k, faces in groups.items():
        nb = bmesh.new()
        vmap = {}
        for f in faces:
            vs = []
            for v in f.verts:
                if v not in vmap:
                    vmap[v] = nb.verts.new(v.co)
                vs.append(vmap[v])
            if len(set(vs)) == len(vs):
                nb.faces.new(vs)
        out[k] = nb
    bm.free()
    return out


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
    for x, y, z, size, _ in LEDGES:
        dist = math.hypot(co.x - x, co.y + z)
        k = min(k, max(smoothstep(size + 4.0, size + 14.0, dist), smoothstep(12.0, 24.0, abs(co.z - y))))
    return k


MESA_LEVELS = [(575, 19), (582, 18), (600, 14), (LEDGE_Y - 0.01, 12), (LEDGE_Y, 3.0), (630, 2.0), (642, 0.7),
               (MESA_Y, 0.0)]  # (y, offset out from the top edge) of the mesa wall, as build_mesa lofts it


def cleft(co):
    """Cut a mesa-wall vertex back into its waterfall groove (MESA_CLEFTS): a flat-floored vertical channel
    `depth` behind the wall's base line, with steep sides, fading out at each span's ends. Applied after the
    column relief, so the groove floor stays clean. Blender co (x, -z, y)."""
    wx, wz, y = co.x, -co.y, co.z
    for c in MESA_CLEFTS:
        if c["side"] * wx < abs(c["x"]) - 4.0 or c["side"] * wx > abs(c["x"]) + 30.0:
            continue
        dz = abs(wz - c["z"])
        if dz >= c["w"]:
            continue
        for y0, y1 in c["spans"]:
            if y0 < y < y1:
                k = smoothstep(c["w"], c["w"] - 2.5, dz) * smoothstep(y0, y0 + 1.5, y) * (1.0 - smoothstep(y1 - 1.5, y1, y))
                base = PLAZA["hx"] + lerp_knots(MESA_LEVELS, y)   # distance of the wall's base line from x = 0
                plane = base - c["depth"]
                d = c["side"] * wx
                if d > plane:
                    co.x = c["side"] * (d + (plane - d) * k)
                return


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
        if y > SUMMIT_TOP - 4 and math.hypot(co.x - 2, -co.y + 90) < 15:
            continue  # the summit's flat top stays clean (SkySteps start on it)
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
    for v in bm.verts:  # after the ledge wall, which would square the lower groove back out
        cleft(v.co)
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
    # the foot flares out toward the ground; the top meets the cliff ring's foot (r ~168 at y 410) so the
    # columns run straight on down through the cloud deck
    return lerp_knots([(-10, 222), (60, 219), (150, 212), (250, 200), (330, 186), (380, 174), (414, 168)], h)


FOOT_TOP = 414.0
FOOT_TRIS = 30000


def build_base(seg=640):
    """The peak's foot below the cliff ring, in the same vertical stone columns as the cliff above it (same
    cell scale and stacked segments, so the columns read as running on down to the ground), lofted directly
    like the spirit-peak pillars: fine rings, each vertex pushed out by its column's amount."""
    ys = []
    y = -10.0
    while y < FOOT_TOP:
        ys.append(y)
        y += 2.0 if y > 300 else 3.0
    ys.append(FOOT_TOP)
    rings = []
    for y in ys:
        ring = []
        for i in range(seg):
            th = 2 * math.pi * i / seg
            d = Vector((math.cos(th), math.sin(th), 0))
            amp = 12.0
            r = (base_profile(y) + amp * noise.noise(Vector((d.x * 2.5, d.y * 2.5, y * 0.006)))
                 + 0.4 * amp * noise.noise(Vector((d.x * 7, d.y * 7, 4.0 + y * 0.02))))
            p = bv(math.cos(th) * r, y, math.sin(th) * r)
            h = Vector((p.x, p.y, 0)).normalized()
            p += h * stone_columns(p, 1.3)[0]
            ring.append(p)
        rings.append(ring)
    bm = bmesh.new()
    loft(bm, rings, cap_top=False)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = link("MP_Base", bm)
    sm = obj.modifiers.new("Smooth", 'SMOOTH'); sm.factor = 0.2; sm.iterations = 1
    apply_all(obj)
    decimate(obj, FOOT_TRIS)
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


def path_radius(th, rad):
    """Inner (rad 150) or outer (rad 166) edge radius of the ring walk at world angle th (radians)."""
    d = Vector((math.cos(th), math.sin(th), 0))
    j = 0.8 * noise.noise(Vector((d.x * 6 + rad, d.y * 6, 1.7)))
    r = rad + (j if rad < 160 else -abs(j))   # outer edge never reaches the bridgeheads (r 168.5)
    if rad > 160:
        r += (APRON_RADIUS - r) * apron(math.degrees(th) % 360)
    return r


def build_path(seg=360):
    bm = bmesh.new()
    top, bot = TERRACE_Y + 0.12, TERRACE_Y - 0.3
    rings = []
    for rad, z in ((150.0, bot), (150.0, top), (166.0, top), (166.0, bot)):
        ring = []
        for i in range(seg):
            th = 2 * math.pi * i / seg
            r = path_radius(th, rad)
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
    if c.z > 652:
        return False  # no grass on the towers: their green comes from trees placed in Studio
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


def append(dst, src):
    """Append src's geometry to dst (both bmeshes); frees src."""
    me = bpy.data.meshes.new("tmp_append")
    src.to_mesh(me)
    src.free()
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)


def rock_tone(c):
    """1 (light), 2 or 3 (dark) per stone column: the same 2D Voronoi cells the columns are sculpted from, so a
    whole column shares one value and the change lands in the grooves between columns. Spires use bigger
    cells (their buttresses), and lean lighter toward the top so the summit reads against the sky."""
    s = 16.0 if c.z > 652 else 9.0 * 1.3
    d, pts = noise.voronoi(Vector((c.x / s, c.y / s, 0.0)), distance_metric='DISTANCE')
    h = cell_hash(pts[0] + Vector((11.3, 0.0, 0.0)))
    if c.z > 700:
        h *= 0.75
    return 1 if h < 0.34 else (2 if h < 0.72 else 3)


def build_moss(seg_per_deg=3):
    """Moss hanging under the terrace's turf lip on MOSS_ARCS: a ragged band just outside the flush rock under
    the rim, tapering in and out at each arc's ends."""
    bm = bmesh.new()
    for k, (a0, a1, depth) in enumerate(MOSS_ARCS):
        n = int((a1 - a0) * seg_per_deg)
        top, bot = [], []
        for i in range(n + 1):
            a = a0 + (a1 - a0) * i / n
            th = math.radians(a)
            r = cliff_radius(th, TERRACE_Y) + 0.12
            t = i / n
            taper = smoothstep(0.0, 0.18, t) * smoothstep(1.0, 0.82, t)
            rag = 0.55 + 0.45 * noise.noise(Vector((a * 0.35, k * 3.7, 0.5)))
            dz = LIP + 0.3 + depth * taper * max(0.15, rag)
            top.append(bv(math.cos(th) * r, TERRACE_Y - LIP, math.sin(th) * r))
            bot.append(bv(math.cos(th) * (r - 0.25), TERRACE_Y - dz, math.sin(th) * (r - 0.25)))
        tv = [bm.verts.new(p) for p in top]
        bvv = [bm.verts.new(p) for p in bot]
        for i in range(n):
            f = bm.faces.new((tv[i], bvv[i], bvv[i + 1], tv[i + 1]))
    bm.normal_update()
    flip = [f for f in bm.faces if f.normal.dot(Vector((*f.calc_center_median().xy, 0)).normalized()) < 0]
    bmesh.ops.reverse_faces(bm, faces=flip)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def split(upper, base, path):
    bm = bmesh.new()
    bm.from_mesh(upper.data)
    bm.normal_update()
    bm.verts.index_update()
    # the big lawns, plus the ledges pines stand on; every other flat stays rock so the cliffs aren't freckled
    def keep(p):
        area = sum(f.calc_area() for f in p)
        return area >= MIN_LAWN or (area >= SPIRE_MIN_TUFT and p[0].calc_center_median().z > 652)

    lawn, cuts = lawn_faces(bm, is_grass, keep,
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
    SUNK = TERRAIN_SINK
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
    # body lawns at the terrace or ledge level the slab outline missed stay rock, sunk under the terrain floor;
    # only the towers' tufts (well above the plaza ledge) keep a grass mesh
    for f in [f for f in lawn if f.calc_center_median().z < LEDGE_Y + 8]:
        level = TERRACE_Y if f.calc_center_median().z < TERRACE_Y + 8 else LEDGE_Y
        for v in f.verts:
            if v.co.z > level - SUNK:
                v.co.z = level - SUNK
    lawn = [f for f in lawn if f.calc_center_median().z >= LEDGE_Y + 8]
    body_grass = extract(bm, lawn)  # the few body lawns the slabs don't cover (mesa top corners, spire flats)
    spire = extract(bm, [f for f in bm.faces if f.calc_center_median().z > 652])
    mesa = extract(bm, [f for f in bm.faces if f.calc_center_median().z > TERRACE_Y + 1.0
                        and math.hypot(*f.calc_center_median().xy) < 165])
    meshes = {}
    for region, b in (("Spire", spire), ("Mesa", mesa), ("Cliff", bm)):
        tones = partition(b, rock_tone)
        for k in (1, 2, 3):
            meshes["MainRock%s%d" % (region, k)] = tones.get(k) or bmesh.new()

    # the lawns themselves are terrain now; only their turf lips stay as a mesh (a crisp overhanging edge
    # the 4-stud voxels can't make), and the small tufts on the towers' tops and ledges
    terrace_lip, terrace_tops = build_terrace_lawn()
    mesa_lip, mesa_top = build_mesa_lawn()
    ledges, ledge_caps, ledge_lips = build_ledges()
    for b in list(terrace_tops.values()) + [mesa_top]:
        b.free()
    lip = bmesh.new()
    for b in (terrace_lip, mesa_lip, ledge_lips):
        append(lip, b)
    ledge_caps.free()
    for tone, b in build_towers().items():
        append(meshes["MainRockSpire%d" % tone], b)
    append(ledges, body_grass)   # (normally empty: every lawn is terrain now)
    lip.free()   # the turf lip mesh is gone: the terrain lawn's own edge droops over the rim instead
    meshes["MainMoss"] = build_moss()
    meshes["MainLedges"] = ledges
    b = bmesh.new()
    b.from_mesh(base.data)
    tones = partition(b, rock_tone)
    for k in (1, 2, 3):
        meshes["MainRockFoot%d" % k] = tones.get(k) or bmesh.new()
    return meshes


# the Studio colours (place_main_peak.luau COLORS), for Blender's material preview
PREVIEW_HEX = {"Spire1": "8E8983", "Spire2": "7F7A74", "Spire3": "6E6A65", "Mesa1": "8A847D", "Mesa2": "7A7570",
               "Mesa3": "6A6661", "Cliff1": "7F7A74", "Cliff2": "706B66", "Cliff3": "615D59", "Foot1": "7F7A74",
               "Foot2": "706B66", "Foot3": "615D59", "TurfLip": "5A7A48", "Moss": "4E6B45", "Ledges": "7A7570"}


def preview_color(name, fallback):
    for key, hx in PREVIEW_HEX.items():
        if name.endswith(key):
            c = [int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4)]
            return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)
    return fallback


OLD_PARTS = ["MainRockSpire", "MainRockMesa", "MainRockCliffA", "MainRockCliffB", "MainRockCliffC", "MainGrass",
             "MainPath", "MainTufts", "MainLawn1", "MainLawn2", "MainLawn3", "MainRockBase"]


def finish(meshes):
    clear([n for n, _ in PARTS] + OLD_PARTS)
    objs = []
    for name, col in PARTS:
        b = meshes[name]
        assert len(b.faces) > 0, name + " came out empty"
        bmesh.ops.delete(b, geom=[e for e in b.edges if not e.link_faces], context='EDGES')
        bmesh.ops.delete(b, geom=[v for v in b.verts if not v.link_faces], context='VERTS')
        b.normal_update()
        box_uv(b)
        smooth_by_angle(b)
        o = link(name, b)
        m = bpy.data.materials.get("Preview" + name) or bpy.data.materials.new("Preview" + name)
        m.use_nodes = True
        col = preview_color(name, col)
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = col
        bsdf.inputs["Roughness"].default_value = 0.9
        m.diffuse_color = col
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
    n = RIM_NOTCH
    report = {"placement": "CFrame.identity (Blender origin = world origin)", "meshes": {},
              "anchors": {  # world coords (x, y, z) for the placement/dressing scripts
                  "ledges": ledge_anchors(),
                  "rim_notch": dict(angle=n["angle"], r=n["r"], rim=[round(math.cos(math.radians(n["angle"])) * n["r"], 2),
                                    TERRACE_Y, round(math.sin(math.radians(n["angle"])) * n["r"], 2)]),
                  "mesa_clefts": [dict(x=c["x"], z=c["z"], side=c["side"], w=c["w"], spans=c["spans"])
                                  for c in MESA_CLEFTS],
              },
              "terrain": terrain_outlines()}
    for o in objs:
        centre, size = bounds(o)
        report["meshes"][o.name] = dict(tris=len(o.data.polygons), center=centre, size=size)
    with open(os.path.join(OUT_DIR, NAME + ".json"), "w") as fh:
        json.dump(report, fh, indent=1)
    return report


def terrain_outlines(n=720):
    """Outlines terrain_main_peak.luau fills, sampled every 360/n degrees (world angle atan2(z, x)):
    rim = terrace rim radius; path = ring walk (inner, outer) radii; ledge = plaza ledge outer edge distance
    from the plaza centre (PLAZA cx, cz) at plaza angle, and its width (< 3 = no ledge)."""
    rim, path, ledge = [], [], []
    for i in range(n):
        th = 2 * math.pi * i / n
        rim.append(round(cliff_radius(th, TERRACE_Y), 2))
        path.append([round(path_radius(th, 150.0), 2), round(path_radius(th, 166.0), 2)])
        e, w = mesa_ledge_edge(th)
        ledge.append([round(e, 2), round(w, 2)])
    return dict(n=n, terrace_y=TERRACE_Y, ledge_y=LEDGE_Y, plaza=[PLAZA["cx"], PLAZA["cz"]], rim=rim, path=path,
                ledge=ledge, sink=TERRAIN_SINK, lawn_w=TERRACE_LAWN_W, mesa_lawn_w=MESA_LAWN_W)


def use_scene():
    scn = bpy.data.scenes.get("MainPeak") or bpy.data.scenes.new("MainPeak")
    if bpy.context.window:  # interactive; headless (blender -b) has no window and builds in the open scene
        bpy.context.window.scene = scn
    return bpy.context.scene


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
    objs = finish(split(upper, base, None))
    report = export(objs)
    for k, v in report["meshes"].items():
        print(k, v)
    if bpy.app.background and "save" in ARGS:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, NAME + ".blend"))


if __name__ == "__main__":
    main()
