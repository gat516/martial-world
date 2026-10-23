r"""Builds the karst pillar kit (tall stone pillars rising through the cloud sea) and exports it for Roblox.

The look matches the spirit peak pillars (art/build_peak_pillar.py): the same rock method (crisp vertical
2D-Voronoi stone columns, each split into stacked segments at its own heights, narrow grooves, a light
smooth, decimation and ~28 deg crease shading), the same plain colours in Studio (no textures), and lawn
tops built like the peaks' lawns: a faceted flat slab with a bevelled edge and one straight green side
(the overhanging turf lip), the rock flush under it and widening downward with a broken crown of
columns. The Zhangjiajie reference only sets the silhouettes and the composition: tall towers of varied
height and thickness, step-backs with lawn ledges, a few outcrop ledges for a pine, green on top.
Pines and bushes are not baked: the bounds JSON lists tree spots and place_karst.luau clones the same
library pines/bushes the peaks use there.

Live Blender (shared session; take the lock in the scratchpad's map/blender.lock first; kit notes in docs/map/karst-pillars.md):
  p = r'\\wsl.localhost\Ubuntu\home\cj\roblox\martial-world\art\karst\build_karst.py'
  g = {'__file__': p, '__name__': '__main__', 'KARST_ARGS': ['preview']}   # or ['export']
  exec(compile(open(p).read(), p, 'exec'), g)
Headless (same result):  blender.exe -b --factory-startup --python <p> -- export
Everything is built in the scene "Karst", made the window's active scene first (the Decimate modifier is
applied there; never evaluate modifiers on a scene that isn't shown).

Kit: each kind is an upper piece from the joint (z = 0, inside the cloud deck) up to its lawn tops, plus
trunk pieces (Karst_Trunk / KarstFar_Trunk, one per leg) from the ground to the joint. The deck hides the
joint. Two meshes per kind: <Kind> (rock) and <Kind>_Green (lawn slabs). KarstFar_* are low-poly
silhouettes for r > ~1100.

Units and axes: 1 Blender unit = 1 stud; X, Y horizontal, Z up; origin at the kind's base centre.
Instances are scaled per pillar in Studio (place_karst.luau).

Exports art/karst/Karst.fbx, art/karst/Karst.json (tris, centre and size per mesh; legs, lawn ledges and
tree spots per kind) and art/karst/Karst.blend.
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise

OUT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else bpy.path.abspath("//")
NAME = "Karst"
SCENE = "Karst"
SHARP_ANGLE = math.radians(28)   # as the peaks: creases sharper than this stay crisp
TILE = 12.0                      # studs per UV unit (box UVs, for when a tiling material is used)
SLOPE_H = 1.4                    # lawn edge bevel height, as the peaks
LIP = 1.3                        # straight green side under the bevel (the turf lip), as the peaks
SMOOTH = 0.25                    # one light smoothing pass on the rock below the lip (voxel jaggies)
WOBBLE = 0.11                    # slow bulge/pinch of the cliff outline down the pillar
LEDGE = 9.0                      # min width of a step-back lawn past the rock above it
TUCK = 0.3                       # share of rim_out the rock reaches under the lip (the rest overhangs)
KEEP_BAND = 1.0                  # rock below each lawn lip kept out of decimation (stays flush with the lip)
RING_STEP = 3.5                  # studs between rings before decimation (upper pieces)

# Rock colours shown in Blender (Studio sets its own Color: map.md rock family, PeakRock #7A7570)
ROCK_RGB = (0x7A, 0x75, 0x70)
TRUNK_RGB = (0x61, 0x5D, 0x59)
LAWN_RGB = (0x6E, 0x8F, 0x5A)

# Each kind: legs (one rock shell each). A leg is a stack of sections, lowest first:
#   (top z, top radius): every section has a lawn top; the next one up starts just under it and is
#   narrower, so the lower lawn shows as a ledge ring (a step-back). Below its top a section widens by
#   `flare` studs per stud of depth. lean (dx, dy per stud), bend (studs, sideways sag), x, y: leg centre.
# outcrops: [(height share, angle deg, size)] wedge ledges with a lawn on top (a pine grows there).
# tris: decimation target for the rock. far: low-poly silhouette (coarser columns, no outcrops).
KINDS = {
    # slender needle with a small stepped head
    "Karst_Needle": dict(seed=3, tris=2200, legs=[
        dict(x=0, y=0, flare=0.024, lean=(0.012, 0), bend=4, sections=[(372, 18.2), (420, 12.8)])],
        outcrops=[(0.62, 40, 9)]),
    # spire: two step-backs near the top, slight S-bend
    "Karst_Spire": dict(seed=7, tris=2800, legs=[
        dict(x=0, y=0, flare=0.028, bend=7, sections=[(330, 27), (405, 21.6), (460, 16.2)])],
        outcrops=[(0.55, 200, 12)]),
    # thick tower stepping back three times
    "Karst_Tower": dict(seed=11, tris=4200, legs=[
        dict(x=0, y=0, flare=0.03, bend=5, sections=[(262, 51.3), (338, 43.2), (392, 35.1), (420, 27)])],
        outcrops=[(0.42, 120, 16), (0.5, 300, 11)]),
    # broad flat-topped mesa, the widest kind (a wooded lawn on top)
    "Karst_Mesa": dict(seed=13, tris=4400, legs=[
        dict(x=0, y=0, flare=0.026, bend=3, sections=[(345, 59.4), (400, 51.3)])],
        outcrops=[(0.6, 70, 15)]),
    # two pillars fused at the foot, tops at different heights
    "Karst_Twin": dict(seed=17, tris=4200, legs=[
        dict(x=-24, y=0, flare=0.022, lean=(-0.008, 0), bend=5, sections=[(380, 27), (450, 20.2)]),
        dict(x=28, y=3, flare=0.024, lean=(0.01, 0), bend=4, sections=[(350, 21.6)])],
        outcrops=[(0.5, 250, 11)]),
    # two legs joined high up by a natural arch
    "Karst_Arch": dict(seed=19, tris=4200, legs=[
        dict(x=-52, y=0, flare=0.02, bend=3, sections=[(370, 23), (440, 17.6)]),
        dict(x=52, y=0, flare=0.02, bend=3, sections=[(380, 18.9)])],
        arch=dict(z=290, rise=20, ry=24, rz=21, sections=12, ring=12), outcrops=[]),
    # broken top: a wide lawn shoulder with a narrow shard rising off one side
    "Karst_Broken": dict(seed=23, tris=3000, legs=[
        dict(x=0, y=0, flare=0.026, bend=4, sections=[(318, 40.5), (362, 15)])],
        outcrops=[(0.45, 160, 13)]),
    # leaning pillar with a perched, offset head
    "Karst_Leaning": dict(seed=29, tris=2600, legs=[
        dict(x=0, y=0, flare=0.024, lean=(0.045, 0.01), bend=3, sections=[(350, 25.7), (430, 20.2)])],
        outcrops=[(0.5, 20, 10)]),
    # short wide stub that only just pierces the deck
    "Karst_Stub": dict(seed=31, tris=2000, legs=[
        dict(x=0, y=0, flare=0.04, bend=2, sections=[(125, 45.9), (170, 36.5)])],
        outcrops=[]),
    # three thin spires fused at the foot
    "Karst_Trio": dict(seed=37, tris=3800, legs=[
        dict(x=0, y=-23, flare=0.018, lean=(0, -0.01), bend=4, sections=[(450, 14.9)]),
        dict(x=20, y=13, flare=0.018, lean=(0.01, 0.005), bend=4, sections=[(370, 13.5)]),
        dict(x=-20, y=12, flare=0.018, lean=(-0.01, 0.005), bend=3, sections=[(300, 12.2)])],
        outcrops=[]),
    # trunk: ground to the joint, coarser columns, flared foot; scaled per leg in Studio
    "Karst_Trunk": dict(seed=41, tris=1500, trunk=True, legs=[
        dict(x=0, y=0, flare=0.02, bend=3, sections=[(400, 48.6)])], outcrops=[]),
    # far silhouettes
    "KarstFar_Spire": dict(seed=43, tris=700, far=True, legs=[
        dict(x=0, y=0, flare=0.02, bend=6, sections=[(360, 25.7), (450, 17.6)])], outcrops=[]),
    "KarstFar_Tower": dict(seed=47, tris=850, far=True, legs=[
        dict(x=0, y=0, flare=0.02, bend=5, sections=[(300, 51.3), (380, 40.5), (420, 29.7)])], outcrops=[]),
    "KarstFar_Twin": dict(seed=53, tris=850, far=True, legs=[
        dict(x=-24, y=0, flare=0.022, bend=5, sections=[(450, 23)]),
        dict(x=28, y=3, flare=0.024, bend=4, sections=[(350, 20.2)])], outcrops=[]),
    "KarstFar_Trunk": dict(seed=59, tris=260, far=True, trunk=True, legs=[
        dict(x=0, y=0, flare=0.02, bend=2, sections=[(400, 48.6)])], outcrops=[]),
}


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def cell_hash(p):
    return (math.sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719) * 43758.5453) % 1.0


# --- sections (one stacked step of a leg) -----------------------------------------------------------

class Section:
    """One step of a leg: a faceted lawn top at `top`, rock widening below it with columns, as the peaks."""

    def __init__(self, leg, z0, top, r, rng):
        self.leg, self.z0, self.top, self.r = leg, z0, top, r
        self.facets = max(8, min(22, round(math.tau * r / 9.0)))
        self.corners = []
        sd = rng.uniform(0, 50)
        for n in range(self.facets):
            a = math.tau * n / self.facets
            d = Vector((math.cos(a), math.sin(a), 0))
            bulge = 0.10 * max(0.0, noise.noise(Vector((d.x * 2.6, d.y * 2.6, sd + 6.4))))
            rad = r * (1.0 + 0.10 * noise.noise(Vector((d.x * 1.1, d.y * 1.1, sd + 5.1)))) * (0.985 + bulge)
            out = 1.0 + 1.4 * smoothstep(-0.6, 0.6, noise.noise(Vector((d.x * 1.8, d.y * 1.8, sd + 2.7))))
            self.corners.append((rad, out))
        self.sd = sd

    def facet(self, th, i):
        k = (th % math.tau) / math.tau * self.facets
        n, t = int(math.floor(k)), k - math.floor(k)
        a, b = self.corners[n % self.facets][i], self.corners[(n + 1) % self.facets][i]
        return a + (b - a) * t

    def rim(self, th):
        return self.facet(th, 0)

    def rim_out(self, th):
        return self.facet(th, 1)

    def radius(self, th, z):
        """Rock surface below the lip: flush under the lawn edge, widening with depth, columns pushed out
        by their own amount per stacked segment (they start a little lower than their neighbours)."""
        depth = self.top - z
        e = SLOPE_H + LIP
        # the rock tucks in under the turf lip (the lip overhangs by most of rim_out), then widens
        floor = self.rim(th) + self.rim_out(th) * TUCK + max(0.0, depth - e) * self.leg.flare
        # slow bulges and pinches down the cliff (not right under the lawn, which stays flush with its lip)
        d = Vector((math.cos(th), math.sin(th), 0))
        wob = noise.noise(Vector((d.x * 1.2, d.y * 1.2, z * 0.009 + self.sd + self.leg.seedz)))
        floor *= 1.0 + WOBBLE * wob * smoothstep(e, e + 24.0, depth)
        out, cell = self.leg.columns(th, z, depth)
        # columns step out a few studs below the lawn (a broken crown under the turf, not a plate on a stump)
        start = e + 2.0 + 8.0 * cell_hash(cell + Vector((5.3, 1.1, self.sd)))
        return floor + out * smoothstep(start, start + 5.0, depth)


class Leg:
    def __init__(self, spec, kind, rng):
        self.x0, self.y0 = spec["x"], spec["y"]
        self.flare = spec["flare"]
        self.far = kind.get("far", False)
        self.trunk = kind.get("trunk", False)
        lx, ly = spec.get("lean", (0, 0))
        self.lean = Vector((lx, ly, 0))
        a = rng.uniform(0, math.tau)
        self.bend = Vector((math.cos(a), math.sin(a), 0)) * spec.get("bend", 0.0)
        self.h = spec["sections"][-1][0]
        self.seedz = rng.uniform(0, 100)
        # column cell size: the peaks' 9-stud columns, narrower on thin legs, coarser far away / on trunks
        r_ref = spec["sections"][0][1]
        self.cs = max(0.6, min(1.0, (r_ref / 45.0) ** 0.5)) * (1.9 if self.far else (1.4 if self.trunk else 1.0))
        # every step-back must leave a real ledge: a lower lawn reaches LEDGE past the rock of the section
        # above it at that height (that rock widens downward and carries columns, so it is wider than its
        # own lawn)
        secs = [list(t) for t in spec["sections"]]
        for k in range(len(secs) - 2, -1, -1):
            up_top, up_r = secs[k + 1]
            under = up_r + (up_top - secs[k][0]) * self.flare + 6.0 * self.cs
            secs[k][1] = max(secs[k][1], under + max(LEDGE, 0.3 * up_r))
        self.sections = []
        z0 = 0.0
        for top, r in secs:
            self.sections.append(Section(self, z0, top, r, rng))
            z0 = top - SLOPE_H - LIP - 0.5     # next section starts just under this lawn (hidden)
        self.shard = None
        if spec.get("shard"):
            share, height = spec["shard"]
            s = self.sections[-1]
            ang = rng.uniform(0, math.tau)
            off = Vector((math.cos(ang), math.sin(ang), 0)) * s.r * share
            self.shard = (off, height)

    def centre(self, z):
        return Vector((self.x0, self.y0, 0)) + self.lean * z + self.bend * math.sin(math.pi * min(1.0, z / self.h))

    def columns(self, th, z, depth):
        """As build_peak_pillar.columns: 2D Voronoi cells round the leg (so they run straight up), each split
        into stacked segments every 25-60 studs at its own phase; returns (outward offset, cell)."""
        s = self.cs
        d2 = Vector((math.cos(th), math.sin(th), 0)) * 55.0
        d, pts = noise.voronoi(Vector((d2.x / (9.0 * s), d2.y / (9.0 * s), self.seedz)), distance_metric='DISTANCE')
        cell = pts[0]
        seg_len = 25.0 + 35.0 * cell_hash(cell + Vector((3.1, 0, 0)))
        k = math.floor((z + seg_len * cell_hash(cell + Vector((0, 7.7, 0)))) / seg_len)
        amp = s
        out = (1.0 + 5.0 * cell_hash(cell + Vector((0, 0, k * 1.37)))) * amp
        crack = smoothstep(0.0, 0.12, d[1] - d[0])   # cells meet in a narrow groove
        return out * (0.35 + 0.65 * crack), cell


# --- meshes -----------------------------------------------------------------------------------------

def ring_heights(sec, step):
    """Rings from the section's base up to the top of its rock (under the lawn lip), denser near the top."""
    e = SLOPE_H + LIP
    hs = [sec.top - e]
    z = sec.top - e - 1.2
    while z > sec.z0:
        hs.append(z)
        z -= 1.2 if sec.top - z < 12 else step
    hs.append(sec.z0)
    return hs[::-1]


def section_rock(bm, leg, sec, seg, step, bottom_cap):
    rings = []
    for z in ring_heights(sec, step):
        c = leg.centre(z)
        ring = []
        for i in range(seg):
            th = math.tau * i / seg
            r = sec.radius(th, z)
            ring.append(bm.verts.new(c + Vector((math.cos(th) * r, math.sin(th) * r, z))))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i]))
    # flat top under the lawn (hidden) and the bottom
    bm.faces.new(rings[-1])
    if bottom_cap:
        bm.faces.new(list(reversed(rings[0])))
    return rings


def lawn(bm, leg, sec, seg):
    """The peaks' lawn top: flat (a gentle roll), bevelled edge down SLOPE_H and out by rim_out, then a
    straight green side LIP tall; closed underneath (hidden in the rock)."""
    top, c = sec.top, leg.centre(sec.top)

    def roll(x, y, f):
        return top + 0.4 * f * noise.noise(Vector((x / 16.0, y / 16.0, sec.sd)))
    rim = [], [], []
    for i in range(seg):
        th = math.tau * i / seg
        d = Vector((math.cos(th), math.sin(th), 0))
        r, o = sec.rim(th), sec.rim_out(th)
        p0 = c + d * r
        rim[0].append(bm.verts.new((p0.x, p0.y, roll(p0.x, p0.y, 1.0))))
        p1 = c + d * (r + o)
        rim[1].append(bm.verts.new((p1.x, p1.y, top - SLOPE_H)))
        rim[2].append(bm.verts.new((p1.x, p1.y, top - SLOPE_H - LIP)))
    for a, b in ((rim[0], rim[1]), (rim[1], rim[2])):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i]))
    prev = rim[0]
    for f in (0.7, 0.35):
        ring = []
        for v in rim[0]:
            x, y = c.x + (v.co.x - c.x) * f, c.y + (v.co.y - c.y) * f
            ring.append(bm.verts.new((x, y, roll(x, y, f))))
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((ring[i], ring[j], prev[j], prev[i]))
        prev = ring
    centre = bm.verts.new((c.x, c.y, top))
    for i in range(seg):
        bm.faces.new((prev[i], prev[(i + 1) % seg], centre))
    bm.faces.new(list(reversed(rim[2])))


def prism(bm, c, r, z0, z1, sides, rng):
    bot, top = [], []
    a0 = rng.uniform(0, math.tau)
    for k in range(sides):
        a = a0 + math.tau * k / sides + rng.uniform(-0.15, 0.15)
        rr = r * rng.uniform(0.85, 1.1)
        d = Vector((math.cos(a), math.sin(a), 0))
        bot.append(bm.verts.new(c + d * rr + Vector((0, 0, z0))))
        top.append(bm.verts.new(c + d * rr * 0.8 + Vector((0, 0, z1 + rng.uniform(-1, 1) * r * 0.25))))
    for k in range(sides):
        j = (k + 1) % sides
        bm.faces.new((bot[k], bot[j], top[j], top[k]))
    bm.faces.new(top)


def outcrop(rock, green, leg, z, ang, size, rng):
    """A wedge ledge out of the cliff (as the peaks' outcrops) with a small lawn slab on top."""
    th = math.radians(ang)
    sec = next(s for s in leg.sections if s.z0 <= z <= s.top)
    dirv = Vector((math.cos(th), math.sin(th), 0))
    side = Vector((-dirv.y, dirv.x, 0))
    r = sec.radius(th, z)
    centre = leg.centre(z) + dirv * (r + size * 0.45 - size * 0.55)
    thick = size * rng.uniform(0.8, 1.1)
    n = 7
    tops, mids, bots, lawn_pts = [], [], [], []
    for i in range(n):
        a = math.tau * i / n + rng.uniform(-0.2, 0.2)
        rr = size * rng.uniform(0.8, 1.1)
        off = dirv * (math.cos(a) * rr) + side * (math.sin(a) * rr * 1.3)
        tops.append(rock.verts.new(centre + off * 0.92 + Vector((0, 0, z - SLOPE_H - LIP))))
        mids.append(rock.verts.new(centre + off + Vector((0, 0, z - SLOPE_H - LIP - 1.5))))
        bots.append(rock.verts.new(centre + off * 0.3 - dirv * size * 0.4 + Vector((0, 0, z - thick))))
        lawn_pts.append(centre + off * 0.92)
    rock.faces.new(tops)
    rock.faces.new(list(reversed(bots)))
    for i in range(n):
        j = (i + 1) % n
        rock.faces.new((tops[i], mids[i], mids[j], tops[j]))
        rock.faces.new((mids[i], bots[i], bots[j], mids[j]))
    # lawn slab on it: flat top, bevel out, green side down to the rock top
    t, b1, b2 = [], [], []
    for p in lawn_pts:
        d = (p - centre).normalized()
        t.append(green.verts.new((p.x - d.x * 0.6, p.y - d.y * 0.6, z)))
        b1.append(green.verts.new((p.x + d.x * 0.5, p.y + d.y * 0.5, z - SLOPE_H)))
        b2.append(green.verts.new((p.x + d.x * 0.5, p.y + d.y * 0.5, z - SLOPE_H - LIP)))
    green.faces.new(t)
    green.faces.new(list(reversed(b2)))
    for a, b in ((t, b1), (b1, b2)):
        for i in range(n):
            j = (i + 1) % n
            green.faces.new((a[i], a[j], b[j], b[i]))
    return centre, size


def arch(bm, legs, spec, rng):
    a, b = legs[0], legs[1]
    pa, pb = a.centre(spec["z"]), b.centre(spec["z"])
    n, secs = spec["ring"], spec["sections"]
    rings = []
    tan = (pb - pa).normalized()
    side = tan.cross(Vector((0, 0, 1))).normalized()
    up = side.cross(tan).normalized()
    for s in range(secs + 1):
        t = s / secs
        p = pa.lerp(pb, t)
        tt = max(0.0, min(1.0, (t - 0.15) / 0.7))
        p.z = spec["z"] + spec["rise"] * math.sin(math.pi * tt)
        thick = 1.0 - 0.25 * math.sin(math.pi * tt)
        ring = []
        for k in range(n):
            ang = math.tau * k / n
            j = rng.uniform(0.9, 1.1)
            ring.append(bm.verts.new(p + side * math.cos(ang) * spec["rz"] * j * thick
                                     + up * math.sin(ang) * spec["ry"] * j * thick))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((r0[k], r0[j], r1[j], r1[k]))
    mid = pa.lerp(pb, 0.5)
    return Vector((mid.x, mid.y, spec["z"] + spec["rise"] + spec["ry"] * 0.75))


def tree_spots(leg, sec, rng, inner=None):
    """Pine and bush spots on a lawn: a few pines inside, bushes near the edge (odd counts, one side)."""
    spots = []
    c = leg.centre(sec.top)
    area = math.pi * sec.r ** 2 - (math.pi * inner ** 2 if inner else 0)
    n = max(1, min(5, round(area / 900)))
    if n % 2 == 0:
        n += 1 if n < 5 else -1
    placed = []
    size_ref = (0.93 * sec.r - inner) * 2.2 if inner else sec.r   # a narrow ledge grows a small pine
    for _ in range(n):
        p = c
        for _ in range(25):
            a = rng.uniform(0, math.tau)
            if inner:   # mid-ledge, between the rock above and the lawn edge
                f = (inner + rng.uniform(0.35, 0.6) * (0.93 * sec.r - inner)) / sec.r
            else:
                f = 0.68 * math.sqrt(rng.random())
            p = c + Vector((math.cos(a), math.sin(a), 0)) * sec.r * f
            if all((p - q).length > max(9.0, sec.r * 0.35) for q in placed):
                break
        placed.append(p)
        spots.append(dict(kind="pine", x=round(p.x, 2), y=round(p.y, 2), z=round(sec.top, 2),
                          s=round(rng.uniform(0.7, 1.1) * max(0.55, min(1.2, size_ref / 24)), 2)))
    a = rng.uniform(0, math.tau)
    for k in range(rng.choice((1, 3))):
        th = a + k * rng.uniform(0.35, 0.6)
        r = sec.rim(th) - 2.5
        p = c + Vector((math.cos(th) * r, math.sin(th) * r, 0))
        spots.append(dict(kind="bush", x=round(p.x, 2), y=round(p.y, 2), z=round(sec.top, 2),
                          s=round(rng.uniform(0.8, 1.3), 2)))
    return spots


def box_uv(bm):
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        ax = max(range(3), key=lambda i: abs(f.normal[i]))
        for lp in f.loops:
            co = lp.vert.co
            u, v = ((co.y, co.z), (co.x, co.z), (co.x, co.y))[ax]
            lp[uv].uv = (u / TILE, v / TILE)


def finish(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.normal_update()
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if not e.is_manifold or e.calc_face_angle(0.0) > SHARP_ANGLE:
            e.smooth = False
    box_uv(bm)


def link(scn, name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    scn.collection.objects.link(o)
    return o


def decimate(o, tris):
    """Collapse-decimate to the tri target (modifier applied on the active scene, which is ours)."""
    n = len(o.data.polygons)
    if n <= tris:
        return
    mod = o.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = tris / n
    mod.use_collapse_triangulate = True
    if o.vertex_groups.get("Keep"):
        mod.vertex_group, mod.invert_vertex_group = "Keep", True   # the lawn-flush band keeps its rings
    with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o], selected_editable_objects=[o]):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def build_kind(scn, name, kind):
    rng = random.Random(kind["seed"])
    legs = [Leg(s, kind, rng) for s in kind["legs"]]
    rock, green = bmesh.new(), bmesh.new()
    far = kind.get("far", False)
    info = dict(legs=[], ledges=[], trees=[])
    lips = []
    for leg in legs:
        for k, sec in enumerate(leg.sections):
            rbot = sec.r + max(0.0, sec.top - sec.z0) * leg.flare + 6 * leg.cs
            seg = max(24 if far else 48, min(160, round(math.tau * rbot / (4.5 if far else 2.8))))
            step = RING_STEP * (3.0 if far else (2.0 if leg.trunk else 1.0))
            section_rock(rock, leg, sec, seg, step, bottom_cap=(k == 0))
            if not leg.trunk:
                lips.append((leg.centre(sec.top), sec))
            if not leg.trunk:
                lawn(green, leg, sec, sec.facets if far else max(16, sec.facets * 2))
                upper = leg.sections[k + 1] if k + 1 < len(leg.sections) else None
                c = leg.centre(sec.top)
                info["ledges"].append(dict(x=round(c.x, 2), y=round(c.y, 2), z=round(sec.top, 2), r=round(sec.r, 2)))
                if not far:
                    under = (upper.r + (upper.top - sec.top) * leg.flare + 6.0 * leg.cs) if upper else None
                    info["trees"] += tree_spots(leg, sec, rng, inner=under)
        if leg.shard:
            off, height = leg.shard
            sec = leg.sections[-1]
            prism(rock, leg.centre(sec.top) + off, sec.r * 0.55, sec.top - 4, sec.top + height, 6, rng)
        s0 = leg.sections[0]
        info["legs"].append(dict(x=leg.x0, y=leg.y0, h=leg.h,
                                 r0=round(s0.r * 1.1 + 1.5 + s0.top * leg.flare + 6 * leg.cs, 2),
                                 rtop=leg.sections[-1].r,
                                 rtop_out=round(leg.sections[-1].r * 1.1 + 1.5 + 6 * leg.cs, 2)))
    if not far:
        for share, ang, size in kind.get("outcrops", []):
            leg = legs[0]
            z = leg.h * share
            c, sz = outcrop(rock, green, leg, z, ang, size, rng)
            info["ledges"].append(dict(x=round(c.x, 2), y=round(c.y, 2), z=round(z, 2), r=size))
            info["trees"].append(dict(kind="pine", x=round(c.x, 2), y=round(c.y, 2), z=round(z, 2),
                                      s=round(0.6 + size / 30, 2)))
    if kind.get("arch"):
        top = arch(rock, legs, kind["arch"], rng)
        info["trees"].append(dict(kind="bush", x=round(top.x, 2), y=round(top.y, 2), z=round(top.z, 2), s=1.0))

    def near_lip(co):   # the flush rings under each lawn lip stay exactly on the lawn outline
        for c, sec in lips:
            if sec.top - SLOPE_H - LIP - KEEP_BAND < co.z <= sec.top and (co.to_2d() - c.to_2d()).length < sec.r * 1.6:
                return True
        return False
    verts = [v for v in rock.verts if not near_lip(v.co)]
    bmesh.ops.smooth_vert(rock, verts=verts, factor=SMOOTH, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    finish(rock)
    keep = [v.index for v in rock.verts if near_lip(v.co)]
    ro = link(scn, name, rock)
    ro.vertex_groups.new(name="Keep").add(keep, 1.0, "REPLACE")
    decimate(ro, kind["tris"])
    ro.vertex_groups.clear()
    bm = bmesh.new()
    bm.from_mesh(ro.data)
    for lay in list(bm.loops.layers.uv):
        bm.loops.layers.uv.remove(lay)
    finish(bm)
    bm.to_mesh(ro.data)
    bm.free()
    objs = [ro]
    if len(green.faces):
        finish(green)
        objs.append(link(scn, name + "_Green", green))
    else:
        green.free()
    return objs, info


# --- scene, materials, export -----------------------------------------------------------------------

def use_scene():
    prev = bpy.context.window.scene if bpy.context.window else None
    scn = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    if bpy.context.window:
        bpy.context.window.scene = scn
    return scn, prev


def material(name, rgb):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
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


def bounds(o):
    xs = [v.co.x for v in o.data.vertices]
    ys = [v.co.y for v in o.data.vertices]
    zs = [v.co.z for v in o.data.vertices]
    c = [(max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, (max(zs) + min(zs)) / 2]
    s = [max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)]
    return [round(x, 3) for x in c], [round(x, 3) for x in s]


def lay_out(start=0.0):
    """Spread the kinds in a row for a look (export resets this)."""
    x = start
    for name in KINDS:
        ro = bpy.data.objects[name]
        w = ro.dimensions.x
        for o in (ro, bpy.data.objects.get(name + "_Green")):
            if o:
                o.location = (x + w / 2, 0, 0)
        x += w + 40
    return x


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
                             mesh_smooth_type="EDGE", bake_space_transform=True)
    report = {"origin": "base centre of each kind (upper: the joint in the cloud deck; trunk: the ground); "
                        "Blender X, Y horizontal, Z up", "meshes": {}, "kinds": infos}
    total = 0
    for o in objs:
        centre, size = bounds(o)
        report["meshes"][o.name] = dict(tris=len(o.data.polygons), center=centre, size=size)
        total += len(o.data.polygons)
    report["kit_tris"] = total
    with open(os.path.join(OUT_DIR, NAME + ".json"), "w") as fh:
        json.dump(report, fh, indent=1)
    bpy.data.libraries.write(os.path.join(OUT_DIR, NAME + ".blend"), set(objs), fake_user=True)
    return report


def main(args):
    scn, prev = use_scene()
    for o in list(scn.objects):   # only our own objects (a comparison peak pillar may share the scene)
        if o.name in KINDS or (o.name.endswith("_Green") and o.name[:-6] in KINDS):
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if isinstance(me, bpy.types.Mesh) and me.users == 0:
                bpy.data.meshes.remove(me)
    rock_m, trunk_m = material("KarstRock", ROCK_RGB), material("KarstTrunk", TRUNK_RGB)
    lawn_m = material("KarstLawn", LAWN_RGB)
    objs, infos = [], {}
    for name, kind in KINDS.items():
        pair, info = build_kind(scn, name, kind)
        for o in pair:
            o.data.materials.append(lawn_m if o.name.endswith("_Green") else (trunk_m if kind.get("trunk") else rock_m))
        objs += pair
        infos[name] = info
    tris = {o.name: len(o.data.polygons) for o in objs}
    if "export" in args:
        rep = export(scn, objs, infos)
        lay_out()
        return {"kit_tris": rep["kit_tris"], "tris": tris}
    lay_out()
    return {"kit_tris": sum(tris.values()), "tris": tris}


if __name__ == "__main__":
    a = globals().get("KARST_ARGS")
    if a is None:
        a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["export"]
    RESULT = main(a)
    print(RESULT)
