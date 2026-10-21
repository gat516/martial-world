r"""Builds the bamboo kit (templates BambooCluster_4..16) for the wilds and exports it for Roblox.

The wilds were dressed with three part-built unions, ServerStorage._Templates.BambooCluster_1..3 (about
45 studs tall, 20 wide, ~1 stud culms with flat plank leaves, one colour each). This kit sits in the same
family and scale and adds variety: dense groves, sparse and single culms, a wind-bent clump, young shoots,
cut stumps and a dry gold accent. Stylized and chunky: six-sided culms whose segments flare up into a
crisp node ridge (the shape carries the bamboo read), lance-shaped leaf blades in drooping sprays that
alternate side to side up the crown, plain colours split over a few meshes so no cluster is one flat
colour (an older/darker culm mesh, deep and light leaf meshes).

Live Blender (Windows path; exec from the MCP):
  p = r'\\wsl.localhost\Ubuntu\home\cj\roblox\martial-world\art\bamboo\build_bamboo.py'
  g = {'__file__': p, '__name__': '__main__', 'BAMBOO_ARGS': ['preview']}   # or ['export']
  exec(compile(open(p).read(), p, 'exec'), g)
Headless (same result):  blender.exe -b --factory-startup --python <p> -- export
Everything is built in the scene "Bamboo", made the window's active scene first.

Meshes: one per kind and role, named <Kind>_<Role> (roles: Culm, CulmAlt, Leaf, LeafLight, Shoot, Cut).
Each becomes one MeshPart; place_bamboo.luau groups a kind's parts into a Model template.

Units and axes: 1 Blender unit = 1 stud; X, Y horizontal, Z up; origin at the kind's base centre on the
ground (culms start SINK studs below it so they stay planted on slopes). The template's pivot is that
point, upright (identity rotation).

Exports art/bamboo/Bamboo.fbx, art/bamboo/Bamboo.json (tris, centre, size and Studio colour per mesh;
template name, culm count and height per kind) and art/bamboo/Bamboo.blend.
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else bpy.path.abspath("//")
NAME = "Bamboo"
SCENE = "Bamboo"

SIDES = 6            # culm cross-section (six reads chunky and crisp; five starts to look like a pencil)
SINK = 1.0           # culms start this far below the ground point
NODE_RIDGE = 1.16    # node ridge radius over the culm radius there (the bamboo read)
NODE_STEP = 0.3      # height of the ridge's inward bevel above each node
TAPER = 0.45         # culm radius shrinks by this share from base to tip
TIP_LEN = 1.6        # closing cone at a culm's tip
BLADE_W = 1.35       # leaf blade width (scaled per kind by leaf)
BLADE_L = 5.6        # leaf blade length (scaled per kind by leaf)
TWIG = (0.8, 2.6)    # side branch length carrying a spray out from the culm
TWIG_R = 0.13       # side branch radius (three-sided)
PAIR = 0.45         # chance a crown node carries a second spray on the other side
BLADE_FOLD = 0.2     # blade edges dip by this share of the width under the midrib (a crisp fold)

# Studio colours (SmoothPlastic), one step either way inside the sage/jade family; dry kinds use the
# gold family. dress_wilds' old bamboo tones were 6F8A4E/7A9455/66804A/809A5C.
JADE = dict(Culm="7A9A50", CulmAlt="627E44", Leaf="5E7F45", LeafLight="86A65B", Shoot="8C8452", Cut="D6CB98")
YOUNG = dict(JADE, Culm="86A65A", CulmAlt="9BB866", LeafLight="92B262")
GOLD = dict(Culm="C3A152", CulmAlt="A6853D", Leaf="AE9549", LeafLight="CDB46A", Shoot="8E6E30", Cut="DCCFA0")

# Kinds. count: culms; foot: (rx, ry) footprint ellipse the culm bases fall in; h, r: height and base
# radius ranges; splay: extra outward tilt (deg) at the footprint rim; lean: (deg at base, deg at tip,
# azimuth deg) shared tilt (wind), tip tilt grows with height^2 so culms arch; jitter: random tilt (deg);
# step: node spacing range; crown: lowest share of the height with leaf sprays; density: chance a node
# above the crown carries a spray; blades: per spray; leaf: blade size factor; droop: blade pitch below
# horizontal (deg); alt: share of culms in the CulmAlt colour; light: share of light sprays (more near
# the top); shoots: young shoot cones (count, height range); stumps: cut culms (count, height range).
KINDS = {
    # 4: tall dense grove clump, the backbone of a bamboo stand
    "BambooGrove": dict(template=4, seed=41, pal=JADE, count=9, foot=(3.6, 3.2), h=(40, 57), r=(0.55, 0.78),
                        splay=7, lean=(0, 4, 0), jitter=3, step=(4.6, 6.0), crown=0.5, density=0.8,
                        blades=(4, 6), leaf=1.0, droop=(15, 45), alt=0.35, light=0.35),
    # 5: sparse clump of four culms, room between them
    "BambooSparse": dict(template=5, seed=52, pal=JADE, count=4, foot=(6.5, 5.0), h=(30, 46), r=(0.5, 0.7),
                         splay=9, lean=(0, 3, 90), jitter=4, step=(4.2, 5.6), crown=0.55, density=0.7,
                         blades=(4, 5), leaf=0.95, droop=(15, 40), alt=0.25, light=0.4),
    # 6: one tall thick culm with a nodding top
    "BambooSingle": dict(template=6, seed=63, pal=JADE, count=1, foot=(0, 0), h=(55, 55), r=(0.85, 0.85),
                         splay=0, lean=(1, 12, 30), jitter=0, step=(5.0, 6.2), crown=0.45, density=0.9,
                         blades=(5, 6), leaf=1.1, droop=(20, 45), alt=0, light=0.4),
    # 7: wind-bent clump: every culm leans and arches the same way, crowns streaming to leeward
    "BambooArching": dict(template=7, seed=74, pal=JADE, count=6, foot=(4.0, 3.5), h=(36, 50), r=(0.5, 0.7),
                          splay=4, lean=(10, 48, 0), jitter=4, step=(4.4, 5.6), crown=0.45, density=0.85,
                          blades=(4, 6), leaf=1.0, droop=(20, 50), alt=0.3, light=0.35, wind=0.7),
    # 8: short young clump with conical shoots coming up round it
    "BambooYoung": dict(template=8, seed=85, pal=YOUNG, count=5, foot=(3.2, 3.0), h=(13, 22), r=(0.35, 0.5),
                        splay=12, lean=(0, 6, 200), jitter=5, step=(2.8, 3.6), crown=0.3, density=0.9,
                        blades=(3, 5), leaf=0.8, droop=(5, 35), alt=0.4, light=0.5, shoots=(5, (3.0, 6.0))),
    # 9: cut stumps with slanted pale cut faces, sprigs and two regrowing culms
    "BambooStumps": dict(template=9, seed=96, pal=JADE, count=2, foot=(4.0, 3.5), h=(11, 15), r=(0.4, 0.5),
                         splay=10, lean=(0, 5, 120), jitter=4, step=(3.0, 3.8), crown=0.35, density=0.9,
                         blades=(3, 5), leaf=0.8, droop=(10, 40), alt=0.5, light=0.45,
                         stumps=(6, (1.5, 6.0), (0.7, 1.0))),
    # 10: dry gold accent clump, thinner crowns
    "BambooDry": dict(template=10, seed=107, pal=GOLD, count=5, foot=(4.5, 4.0), h=(30, 45), r=(0.5, 0.7),
                      splay=8, lean=(0, 6, 300), jitter=4, step=(4.2, 5.4), crown=0.55, density=0.55,
                      blades=(3, 5), leaf=0.95, droop=(30, 60), alt=0.4, light=0.4),
    # 11: wide low thicket, an oval row for edges and banks
    "BambooThicket": dict(template=11, seed=118, pal=JADE, count=8, foot=(9.0, 3.0), h=(24, 38), r=(0.45, 0.62),
                          splay=10, lean=(0, 4, 90), jitter=4, step=(3.8, 5.0), crown=0.4, density=0.85,
                          blades=(4, 5), leaf=0.95, droop=(15, 45), alt=0.35, light=0.4),
}
# Grove pieces. Bamboo grows only in pure dense groves (map.md): the stand tiles (grid) fill the inside of a
# grove edge to edge, 16 x 16 studs each, culms on a jittered grid so neighbouring tiles butt without a seam
# or a visible repeat (rotate them by 90 deg steps); five-sided culms with wider node steps and crowns only
# up high keep a grove of dozens of tiles affordable. The edge strip steps down from stand height to young
# culms (lay its -Y side against the stands); giants are the hero grove's few very tall culms.
KINDS.update({
    # 12-14: dense stand tiles (16 x 16), three seeds/heights so a grove never repeats
    "BambooStandA": dict(template=12, seed=131, pal=JADE, grid=(3, 3), twin=0.25, foot=(8, 8), h=(48, 64),
                         r=(0.55, 0.75), sides=5, splay=0, lean=(0, 3, 0), jitter=3, step=(6.0, 7.5), crown=0.6,
                         density=0.8, blades=(3, 5), leaf=1.05, droop=(20, 50), alt=0.35, light=0.35),
    "BambooStandB": dict(template=13, seed=142, pal=JADE, grid=(3, 3), twin=0.2, foot=(8, 8), h=(42, 58),
                         r=(0.5, 0.72), sides=5, splay=0, lean=(0, 3, 120), jitter=3, step=(5.6, 7.0), crown=0.58,
                         density=0.8, blades=(3, 5), leaf=1.0, droop=(20, 50), alt=0.4, light=0.3),
    "BambooStandC": dict(template=14, seed=153, pal=JADE, grid=(4, 3), twin=0.1, foot=(8, 8), h=(50, 68),
                         r=(0.5, 0.68), sides=5, splay=0, lean=(0, 3, 240), jitter=3, step=(6.0, 7.8), crown=0.62,
                         density=0.75, blades=(3, 4), leaf=1.05, droop=(20, 50), alt=0.3, light=0.4),
    # 15: hero giants: three very tall, thick culms for the hero grove
    "BambooGiant": dict(template=15, seed=164, pal=JADE, count=3, foot=(3.5, 3.0), h=(78, 96), r=(1.05, 1.35),
                        sides=6, splay=4, lean=(0, 7, 60), jitter=2, step=(6.5, 8.0), crown=0.6, density=0.9,
                        blades=(5, 6), leaf=1.35, droop=(20, 50), alt=0.35, light=0.35),
    # 16: grove edge strip (16 x 8): stand height on its -Y side stepping down to young culms on +Y
    "BambooEdge": dict(template=16, seed=175, pal=JADE, grid=(4, 2), twin=0.15, foot=(8, 4), h=(40, 54),
                       ramp=0.35, r=(0.42, 0.65), sides=5, splay=0, lean=(0, 6, 90), jitter=4, step=(4.6, 6.4),
                       crown=0.45, density=0.8, blades=(3, 5), leaf=0.95, droop=(15, 45), alt=0.35, light=0.45,
                       shoots=(3, (2.5, 5.0))),
})
ROLES = ("Culm", "CulmAlt", "Leaf", "LeafLight", "Shoot", "Cut")


# --- geometry --------------------------------------------------------------------------------------------

def frame(d):
    """Two unit vectors perpendicular to direction d (no twist for near-vertical d)."""
    ref = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 1, 0))
    u = (ref - d * ref.dot(d)).normalized()
    return u, d.cross(u)


def ring(bm, c, d, r, phase, cut=None):
    u, v = frame(d)
    out = []
    for i in range(SIDES):
        a = phase + 2 * math.pi * i / SIDES
        off = u * (math.cos(a) * r) + v * (math.sin(a) * r)
        p = c + off
        if cut:   # slanted cut: shift each vertex along the culm by its side's share of the slope
            p = p + d * (off.dot(cut[0]) * cut[1])
        out.append(bm.verts.new(p))
    return out


def bridge(bm, a, b):
    n = len(a)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))


def cap(bm, rng_, point, flip=False):
    n = len(rng_)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((rng_[j], rng_[i], point) if not flip else (rng_[i], rng_[j], point))


class Culm:
    """A culm spine: tilt grows from tilt0 at the base to tilt1 at the top (quadratic, so it arches)."""

    def __init__(self, base, length, tilt0, tilt1, az):
        self.base, self.length = base, length
        self.tilt0, self.tilt1, self.az = tilt0, tilt1, az
        self.pts = [base.copy()]
        self.ds = 0.5
        p = base.copy()
        s = 0.0
        while s < length + 1:
            p = p + self.dir(s + self.ds / 2) * self.ds
            self.pts.append(p.copy())
            s += self.ds

    def dir(self, s):
        t = min(max(s / self.length, 0), 1)
        th = self.tilt0 + (self.tilt1 - self.tilt0) * t * t
        return Vector((math.sin(th) * math.cos(self.az), math.sin(th) * math.sin(self.az), math.cos(th)))

    def at(self, s):
        k = s / self.ds
        i = min(int(k), len(self.pts) - 2)
        f = k - i
        return self.pts[i].lerp(self.pts[i + 1], f)


def build_culm(bm, cut_bm, rng, base, length, r0, tilt0, tilt1, az, step, stump=None):
    """Six-sided culm, segments flaring up into a node ridge. Returns [(s, point, dir, radius)] per node.
    stump: (slope) makes a short culm with a slanted cut top (pale cut face goes into cut_bm)."""
    sp = Culm(base, length, tilt0, tilt1, az)
    phase = rng.uniform(0, math.pi)
    rad = lambda s: r0 * (1 - TAPER * min(s / length, 1)) if not stump else r0
    nodes = []
    s = SINK + rng.uniform(0.3, 1.2)          # first node just above the ground
    while s < length - (0.4 if stump else TIP_LEN + 1.5):
        nodes.append(s)
        s += rng.uniform(*step) * (0.7 if s < 6 and not stump else 1.0)   # tighter nodes near the base
    prev = first = ring(bm, sp.at(0), sp.dir(0), rad(0), phase)
    out = []
    for s in nodes:
        r = rad(s)
        ridge = ring(bm, sp.at(s), sp.dir(s), r * NODE_RIDGE, phase)
        bridge(bm, prev, ridge)
        above = ring(bm, sp.at(s + NODE_STEP), sp.dir(s), r, phase)
        bridge(bm, ridge, above)
        prev = above
        out.append((s, sp.at(s), sp.dir(s), r))
    if stump:
        d = sp.dir(length)
        cdir = Vector((math.cos(az + 1.3), math.sin(az + 1.3), 0))
        cdir = (cdir - d * cdir.dot(d)).normalized()
        cut = (cdir, stump / max(r0, 0.01))
        top = ring(bm, sp.at(length), d, r0, phase, cut=cut)
        bridge(bm, prev, top)
        # cut face in its own mesh: rim annulus, inner wall down, recessed floor (the hollow culm)
        o = [cut_bm.verts.new(v.co) for v in top]
        inner = ring(cut_bm, sp.at(length), d, r0 * 0.62, phase, cut=cut)
        bridge(cut_bm, o, inner)
        floor = ring(cut_bm, sp.at(length) - d * 0.6, d, r0 * 0.62, phase, cut=cut)
        bridge(cut_bm, inner, floor)
        cut_bm.faces.new(list(reversed(floor)))
    else:
        top = ring(bm, sp.at(length), sp.dir(length), rad(length), phase)
        bridge(bm, prev, top)
        tip = bm.verts.new(sp.at(length + TIP_LEN))
        cap(bm, top, tip)
    cap(bm, first, bm.verts.new(sp.at(0) - sp.dir(0) * 0.3), True)
    return out


def blade(bm, origin, bdir, length, width):
    """A lance blade folded along its midrib: four verts, top and bottom faces (both sides render)."""
    side = bdir.cross(Vector((0, 0, 1)))
    side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
    up = side.cross(bdir).normalized()
    if up.z < 0:
        up = -up
    mid = origin + bdir * (length * 0.33) - up * (width * BLADE_FOLD)
    pts = [origin, mid + side * (width / 2), origin + bdir * length, mid - side * (width / 2)]
    for flip in (False, True):
        b, r_, t, l = (bm.verts.new(p) for p in pts)
        for tri in ((b, t, r_), (b, l, t)):
            f = bm.faces.new(tri)
            f.normal_update()
            if (f.normal.dot(up) < 0) != flip:
                f.normal_flip()


def spray(bm, rng, origin, az, n, size, droop, spread=55, rise=0.0):
    """A fan of n blades from origin, centred on azimuth az, drooping droop (deg range) below horizontal."""
    for j in range(n):
        f = (j / (n - 1) - 0.5) * 2 if n > 1 else 0
        a = az + math.radians(spread * f + rng.uniform(-12, 12))
        pitch = -math.radians(rng.uniform(*droop)) + rise
        d = Vector((math.cos(a) * math.cos(pitch), math.sin(a) * math.cos(pitch), math.sin(pitch)))
        k = rng.uniform(0.8, 1.15) * size
        blade(bm, origin, d, BLADE_L * k, BLADE_W * k)


def twig(bm, a, b):
    """A thin three-sided side branch from a to b (open ends: hidden in the culm and the spray)."""
    d = (b - a).normalized()
    u, v = frame(d)
    ra = [bm.verts.new(a + (u * math.cos(t) + v * math.sin(t)) * TWIG_R) for t in (0, 2.094, 4.189)]
    rb = [bm.verts.new(b + (u * math.cos(t) + v * math.sin(t)) * TWIG_R * 0.6) for t in (0, 2.094, 4.189)]
    bridge(bm, ra, rb)


def shoot(bm, rng, base, height, r):
    """A young shoot: two stacked six-sided cones (sheaths), leaning a little."""
    lean = Vector((rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), 1)).normalized()
    phase = rng.uniform(0, math.pi)
    b0 = base - lean * SINK
    r1 = ring(bm, b0, lean, r, phase)
    cap(bm, r1, bm.verts.new(b0 + lean * (height * 0.65 + SINK)))
    cap(bm, r1, bm.verts.new(b0 - lean * 0.2), True)
    b1 = b0 + lean * (SINK + height * 0.35)
    r2 = ring(bm, b1, lean, r * 0.68, phase + math.pi / SIDES)
    cap(bm, r2, bm.verts.new(b0 + lean * (height + SINK)))
    cap(bm, r2, bm.verts.new(b1 - lean * 0.2), True)


def in_foot(rng, foot):
    if foot[0] <= 0:
        return 0.0, 0.0
    a = rng.uniform(0, 2 * math.pi)
    t = math.sqrt(rng.uniform(0.05, 1))
    return math.cos(a) * foot[0] * t, math.sin(a) * foot[1] * t


def build_kind(name, k):
    rng = random.Random(k["seed"])
    bms = {role: bmesh.new() for role in ROLES}
    wind_az = math.radians(k["lean"][2])
    bases = []
    global SIDES
    SIDES = k.get("sides", 6)
    if "grid" in k:   # stand tiles: one culm per jittered cell over the whole rectangle, so tiles butt evenly
        nx, ny = k["grid"]
        rx, ry = k["foot"]
        for i in range(nx):
            for j in range(ny):
                cx = -rx + (i + 0.5) * 2 * rx / nx
                cy = -ry + (j + 0.5) * 2 * ry / ny
                x = cx + rng.uniform(-0.35, 0.35) * 2 * rx / nx
                y = cy + rng.uniform(-0.35, 0.35) * 2 * ry / ny
                bases.append((x, y))
                if rng.random() < k.get("twin", 0):   # a second culm hugging the first (bamboo clumps)
                    a = rng.uniform(0, 2 * math.pi)
                    bases.append((x + math.cos(a) * 2.0, y + math.sin(a) * 2.0))
    else:
        for _ in range(k["count"]):   # spread the bases so culms don't intersect at the ground
            for _try in range(40):
                x, y = in_foot(rng, k["foot"])
                if all((x - bx) ** 2 + (y - by) ** 2 > (2.0 * k["r"][1] + 0.5) ** 2 for bx, by in bases):
                    break
            bases.append((x, y))
    heights = []
    for (x, y) in bases:
        h = rng.uniform(*k["h"])
        if "ramp" in k:   # edge strips: full height at -y, falling to ramp x height at +y (towards the open side)
            h *= 1 - (1 - k["ramp"]) * (y + k["foot"][1]) / (2 * k["foot"][1])
        r0 = rng.uniform(*k["r"])
        rim = math.sqrt((x / k["foot"][0]) ** 2 + (y / k["foot"][1]) ** 2) if k["foot"][0] > 0 else 0
        out_az = math.atan2(y, x)
        # combine outward splay, shared lean and jitter into one tilt vector at base and at tip
        def tilt(deg_lean):
            vx = math.radians(k["splay"] * rim) * math.cos(out_az) + math.radians(deg_lean) * math.cos(wind_az)
            vy = math.radians(k["splay"] * rim) * math.sin(out_az) + math.radians(deg_lean) * math.sin(wind_az)
            vx += math.radians(rng.uniform(-k["jitter"], k["jitter"]))
            vy += math.radians(rng.uniform(-k["jitter"], k["jitter"]))
            return vx, vy
        t0, t1 = tilt(k["lean"][0]), tilt(k["lean"][1] * rng.uniform(0.8, 1.15))
        az = math.atan2(t0[1] + t1[1], t0[0] + t1[0])
        mag = lambda t: math.hypot(*t)
        role = "CulmAlt" if rng.random() < k["alt"] else "Culm"
        length = h + SINK
        nodes = build_culm(bms[role], bms["Cut"], rng, Vector((x, y, -SINK)), length, r0, mag(t0), mag(t1), az,
                           k["step"])
        heights.append(round(h, 2))
        crown(bms, rng, k, nodes, length, az, mag(t1), wind_az, role)
    if "stumps" in k:
        n, hr, rr = k["stumps"]
        for _ in range(n):
            for _try in range(40):
                x, y = in_foot(rng, (k["foot"][0] * 1.2, k["foot"][1] * 1.2))
                if all((x - bx) ** 2 + (y - by) ** 2 > (2.2 * rr[1]) ** 2 for bx, by in bases):
                    break
            bases.append((x, y))
            h = rng.uniform(*hr)
            r0 = rng.uniform(*rr)
            role = "CulmAlt" if rng.random() < k["alt"] else "Culm"
            nodes = build_culm(bms[role], bms["Cut"], rng, Vector((x, y, -SINK)), h + SINK, r0,
                               math.radians(rng.uniform(0, 5)), math.radians(rng.uniform(0, 5)),
                               rng.uniform(0, 2 * math.pi), (1.6, 2.4), stump=rng.uniform(0.35, 0.6) * r0)
            if h > 3.0 and nodes and rng.random() < 0.7:   # a sprig from a high node of the taller stumps
                s, p, d, r = nodes[-1]
                spray(bms["LeafLight" if rng.random() < 0.5 else "Leaf"], rng, p, rng.uniform(0, 6.28),
                      rng.randint(3, 4), 0.6, (0, 30), spread=50)
    if "shoots" in k:
        n, hr = k["shoots"]
        for _ in range(n):
            for _try in range(40):
                x, y = in_foot(rng, (k["foot"][0] * 1.6, k["foot"][1] * 1.6))
                if "ramp" in k:
                    y = abs(y) + k["foot"][1] * 0.6   # shoots come up on the open side
                if all((x - bx) ** 2 + (y - by) ** 2 > 1.6 ** 2 for bx, by in bases):
                    break
            bases.append((x, y))
            hh = rng.uniform(*hr)
            shoot(bms["Shoot"], rng, Vector((x, y, 0)), hh, 0.5 + hh * 0.1)
    return bms, heights


def crown(bms, rng, k, nodes, length, culm_az, tip_tilt, wind_az, culm_role):
    """Leaf sprays at nodes above the crown line, alternating sides, plus a tuft at the tip."""
    side = rng.uniform(0, 2 * math.pi)
    wind = k.get("wind", 0)
    for (s, p, d, r) in nodes:
        t = s / length
        if t < k["crown"] or rng.random() > k["density"]:
            continue
        side += math.pi + rng.uniform(-0.6, 0.6)            # alternate branching
        az = side
        if wind:                                             # streaming to leeward
            dx = math.cos(az) * (1 - wind) + math.cos(wind_az) * wind
            dy = math.sin(az) * (1 - wind) + math.sin(wind_az) * wind
            az = math.atan2(dy, dx)
        size = k["leaf"] * (0.75 + 0.45 * math.sin(math.pi * min(max((t - k["crown"]) / (1 - k["crown"]), 0), 1)))
        for n_ in range(2 if rng.random() < PAIR else 1):
            a = az + (math.pi + rng.uniform(-0.5, 0.5) if n_ else 0)
            role = "LeafLight" if rng.random() < k["light"] + 0.35 * (t - 0.5) else "Leaf"
            u = Vector((math.cos(a), math.sin(a), 0))
            tw = rng.uniform(*TWIG) * size
            root = p + Vector((0, 0, 0.15))
            origin = root + (u * 0.9 + Vector((0, 0, 0.45))).normalized() * (r + tw)
            twig(bms[culm_role], root, origin)
            spray(bms[role], rng, origin, a, rng.randint(*k["blades"]), size, k["droop"])
    # tip tuft: a few blades round the tip, rising then falling (follows the culm's nod)
    sp_tip = nodes[-1][1] if nodes else None
    if sp_tip is not None:
        top = nodes[-1][1] + nodes[-1][2] * (length - nodes[-1][0] + TIP_LEN * 0.6)
        role = "LeafLight" if rng.random() < k["light"] + 0.2 else "Leaf"
        spray(bms[role], rng, top, culm_az if (tip_tilt > 0.3 or wind) else rng.uniform(0, 6.28),
              rng.randint(3, 4), k["leaf"] * 0.8, (-10, 25), spread=150)


# --- scene, materials, export -----------------------------------------------------------------------------

def use_scene():
    scn = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    if bpy.context.window:
        bpy.context.window.scene = scn
    return scn


def material(name, hexcol):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    rgb = [int(hexcol[i:i + 2], 16) for i in (0, 2, 4)]
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    col = (lin(rgb[0]), lin(rgb[1]), lin(rgb[2]), 1.0)
    mat.diffuse_color = col
    try:
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs[0].default_value = col
        for inp in bsdf.inputs:
            if inp.name == "Roughness":
                inp.default_value = 0.9
    except Exception:
        pass
    return mat


def link(scn, name, bm, mat):
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    for f in bm.faces:
        f.smooth = False                                   # flat facets: crisp stylized shading
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    scn.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def bounds(o):
    xs = [v.co.x for v in o.data.vertices]
    ys = [v.co.y for v in o.data.vertices]
    zs = [v.co.z for v in o.data.vertices]
    c = [(max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, (max(zs) + min(zs)) / 2]
    s = [max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)]
    return [round(x, 3) for x in c], [round(x, 3) for x in s]


def lay_out(groups):
    """Spread the kinds in a row for a look (export resets this)."""
    x = 0.0
    for name, objs in groups.items():
        for o in objs:
            o.location = (x, 0, 0)
        x += 32
    bpy.context.view_layer.update()


def export(scn, objs, infos):
    for o in objs:
        o.location = (0, 0, 0)
    bpy.context.view_layer.update()
    for o in scn.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, NAME + ".fbx"), use_selection=True,
                             object_types={"MESH"}, apply_unit_scale=True,
                             apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y",
                             mesh_smooth_type="FACE", bake_space_transform=True)
    report = {"origin": "each kind's base centre on the ground (culms start 1 stud below); Blender X, Y "
                        "horizontal, Z up", "meshes": {}, "kinds": infos}
    for o in objs:
        centre, size = bounds(o)
        report["meshes"][o.name] = dict(tris=len(o.data.polygons), center=centre, size=size,
                                        color=o.get("studio_color"))
    with open(os.path.join(OUT_DIR, NAME + ".json"), "w") as fh:
        json.dump(report, fh, indent=1)
    bpy.data.libraries.write(os.path.join(OUT_DIR, NAME + ".blend"), set(objs), fake_user=True)
    return report


def main(args):
    scn = use_scene()
    for o in list(scn.objects):
        if any(o.name.startswith(n + "_") for n in KINDS):
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if isinstance(me, bpy.types.Mesh) and me.users == 0:
                bpy.data.meshes.remove(me)
    objs, infos, groups = [], {}, {}
    for name, k in KINDS.items():
        bms, heights = build_kind(name, k)
        groups[name] = []
        tris = 0
        for role, bm in bms.items():
            if not bm.faces:
                bm.free()
                continue
            o = link(scn, name + "_" + role, bm, material("Bamboo_%s_%s" % (role, k["pal"][role]), k["pal"][role]))
            o["studio_color"] = k["pal"][role]
            groups[name].append(o)
            objs.append(o)
            tris += len(o.data.polygons)
        infos[name] = dict(template="BambooCluster_%d" % k["template"], culms=len(heights), heights=heights,
                           tris=tris, parts=[o.name for o in groups[name]])
    if "export" in args:
        export(scn, objs, infos)
    lay_out(groups)
    return {n: (i["template"], i["tris"], max(i["heights"])) for n, i in infos.items()}


if __name__ == "__main__":
    a = globals().get("BAMBOO_ARGS")
    if a is None:
        a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["export"]
    RESULT = main(a)
    print(RESULT)
