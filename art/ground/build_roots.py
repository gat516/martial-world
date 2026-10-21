"""Builds the peak roots: Zhangjiajie-style flared feet where the spirit pillars and the main peak's rock meet the
under-sect floor, and exports them for Roblox. Same look as the spirit pillar (art/build_peak_pillar.py): a sleeve
round the rock whose radius steps out per 2D-Voronoi cell, so the foot reads as crisp vertical stone columns of
different widths and heights, each crown stepping back into the cliff, with narrow grooves between them.

Run inside the live Blender (exec this file through the MCP; it builds into its own scene "PeakRoots" and makes
it the window's scene). Pure bmesh, no modifiers.

Meshes (1 Blender unit = 1 stud, Z up = world y, Z 0 = world y 0):
  PeakRoot / PeakRootFoot  in the spirit peak frame of build_peak_pillar.py: origin at the Plateau centre (x, z),
                           X = peak-local right, Y = outward (away from the main peak). One mesh for all eight peaks.
  MainRoot / MainRootFoot  origin at world (2, 0, 2), X = world x, Y = -world z (identity placement).
  *Foot is the invisible collider: the convex hull of the root's bottom (y BOTTOM..FOOT_TOP), used with Hull
  collision so players walking at the base bump into the flare the way it looks.

Input: root_profiles.json (the rock bases' outlines raycast in Studio at several heights against their collision
hulls, so every column's inner face is buried in the existing rock). Output: PeakRoots.fbx, PeakRoots.json
(tris, centre and size per mesh in Blender axes), PeakRoots.blend.
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Vector, noise

OUT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else bpy.path.abspath("//")
NAME = "PeakRoots"

BOTTOM = -22.0      # the skirt starts this far under world y 0 (the floor is y ~4-30)
FOOT_TOP = 40.0     # the collider covers the root up to here
TUCK = 6.0          # above a column's top the surface sinks this far inside the rock hull (the visual rock sits a
                    # few studs inside its hull in the grooves, so this must clear that)
SHOULDER = 2.5      # height over which a column's top steps in (crisp, like the pillar's column crowns)

ROOTS = {
    # seg: facets round the ring; col: Voronoi column size (studs); flare: (min, max) how far a column stands
    # out of the rock at the floor; tops: (min, max) world y where a column's crown meets the cliff;
    # pinch: (world angle deg, half width deg, factor) where the flare is cut; skip: no columns at all
    "PeakRoot": dict(src="peak", seg=80, col=14.0, flare=(4.0, 10.0), tops=(40.0, 125.0), top_y=130.0,
                     # toward the neighbouring pillars (the narrow slots between peaks) and the main rock
                     pinch=[(180.0, 20.0, 0.3), (315.0, 20.0, 0.3), (247.5, 25.0, 0.5)]),
    "MainRoot": dict(src="main", seg=128, col=16.0, flare=(3.5, 8.5), tops=(34.0, 100.0), top_y=106.0,
                     # the Ascension Array stands at the rock's foot at 90 deg: leave the face plain there
                     pinch=[(90.0, 12.0, 0.15)], skip=[(90.0, 4.5)]),
}

PARTS_COLOR = (0.34, 0.325, 0.31, 1.0)  # viewport only; Studio colour is set by place_roots.luau


def load_profiles():
    with open(os.path.join(OUT_DIR, "root_profiles.json")) as fh:
        return json.load(fh)


def angdiff(a, b):
    return (a - b + 180.0) % 360.0 - 180.0


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def cell_hash(p):
    return (math.sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719) * 43758.5453) % 1.0


def outline(src, ys, a_deg, y):
    """Rock outline radius (its collision hull) at world angle a_deg and height y (linear in both)."""
    prof = src["prof"]
    s = (a_deg % 360.0) / 5.0
    s0 = int(math.floor(s)) % 72
    s1 = (s0 + 1) % 72
    t = s - math.floor(s)

    def at(k):
        return prof[k][s0] + (prof[k][s1] - prof[k][s0]) * t

    if y <= ys[0]:
        return at(0)
    for k in range(len(ys) - 1):
        if y <= ys[k + 1]:
            u = (y - ys[k]) / (ys[k + 1] - ys[k])
            return at(k) + (at(k + 1) - at(k)) * u
    return at(len(ys) - 1)


def to_blender(kind, src, dx, dz):
    """World offset (dx, dz) from the root's centre -> Blender (x, y)."""
    if kind == "peak":
        th = math.radians(src["outward_deg"])
        return (-dx * math.sin(th) + dz * math.cos(th), dx * math.cos(th) + dz * math.sin(th))
    return (dx, -dz)


def ring_heights(top_y):
    hs, h = [BOTTOM], BOTTOM
    while h < top_y:
        h += 7.0 if h < 70 else 14.0
        hs.append(min(h, top_y))
    return hs


def columns(cfg, a, dx, dz):
    """The spirit pillar's column look (build_peak_pillar.py columns()): 2D Voronoi cells round the rock, so
    columns run straight up, each with its own flare and crown height, meeting the next in a narrow groove.
    Returns (flare, crown height)."""
    d, pts = noise.voronoi(Vector((dx / cfg["col"], dz / cfg["col"], 0.0)), distance_metric='DISTANCE')
    cell = pts[0]
    lo, hi = cfg["flare"]
    flare = lo + (hi - lo) * cell_hash(cell + Vector((1.3, 0, 0)))
    t0, t1 = cfg["tops"]
    u = cell_hash(cell + Vector((0, 4.1, 0)))
    crown = t0 + (t1 - t0) * u * u  # most columns stop low, a few run high up the cliff
    crack = smoothstep(0.0, 0.12, d[1] - d[0])
    pinch = 1.0
    for c, w, f in cfg["pinch"]:
        dd = abs(angdiff(a, c))
        if dd < w:
            pinch = min(pinch, f + (1 - f) * smoothstep(0.0, 1.0, dd / w))
    if any(abs(angdiff(a, c)) < w for c, w in cfg.get("skip", [])):
        flare, crown = 0.0, BOTTOM - 4.0  # tucked into the rock all the way down
    return flare * pinch * (0.35 + 0.65 * crack), crown


def build_root(name, cfg, data):
    kind = cfg["src"]
    src, ys = data[kind], data["ys"]
    seg = cfg["seg"]
    bm = bmesh.new()
    grid, foot_pts = [], []
    cols = []
    for i in range(seg):
        a = 360.0 * i / seg
        r0 = outline(src, ys, a, 0.0)
        dx, dz = math.cos(math.radians(a)) * r0, math.sin(math.radians(a)) * r0
        cols.append((a,) + columns(cfg, a, dx, dz))
    for h in ring_heights(cfg["top_y"]):
        ring = []
        for a, flare, crown in cols:
            # the foot widens a little toward the floor; above the crown the face tucks into the rock
            grow = 1.0 + 0.6 * smoothstep(crown, BOTTOM, h)
            out = flare * grow * (1.0 - smoothstep(crown, crown + SHOULDER, h)) - TUCK * smoothstep(crown, crown + SHOULDER, h)
            out += 0.4  # stand just proud of the hull so the faces show
            r = outline(src, ys, a, h) + out
            px, pz = math.cos(math.radians(a)) * r, math.sin(math.radians(a)) * r
            bx, by = to_blender(kind, src, px, pz)
            ring.append(bm.verts.new((bx, by, h)))
            if h <= FOOT_TOP:
                foot_pts.append((bx, by, h))
        grid.append(ring)
    for lo_r, hi_r in zip(grid, grid[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((lo_r[i], lo_r[j], hi_r[j], hi_r[i]))
    bm.faces.new(list(reversed(grid[0])))  # bottom, under the floor
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    root = link(name, bm)

    fb = bmesh.new()
    for p in foot_pts:
        fb.verts.new(p)
    bmesh.ops.convex_hull(fb, input=fb.verts)
    loose = [v for v in fb.verts if not v.link_faces]
    bmesh.ops.delete(fb, geom=loose, context="VERTS")
    bmesh.ops.recalc_face_normals(fb, faces=fb.faces)
    foot = link(name + "Foot", fb)
    return root, foot


def link(name, bm):
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    me = bpy.data.meshes.get(name) or bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    mat = bpy.data.materials.get("RootRock") or bpy.data.materials.new("RootRock")
    mat.diffuse_color = PARTS_COLOR
    me.materials.clear()
    me.materials.append(mat)
    return o


def use_scene():
    scn = bpy.data.scenes.get("PeakRoots") or bpy.data.scenes.new("PeakRoots")
    if bpy.context.window:
        bpy.context.window.scene = scn
    return bpy.context.scene


def bounds(o):
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return [round(c, 3) for c in (lo + hi) / 2], [round(c, 3) for c in hi - lo]


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def export(objs):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, NAME + ".fbx"), use_selection=True,
                             object_types={'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                             axis_forward='-Z', axis_up='Y', mesh_smooth_type='EDGE', bake_space_transform=True)
    report = {"frames": {"PeakRoot": "spirit peak frame (Plateau x, z; look = outward), y 0",
                         "MainRoot": "world (2, 0, 2), identity"},
              "foot_top": FOOT_TOP, "bottom": BOTTOM, "meshes": {}}
    for o in objs:
        c, s = bounds(o)
        report["meshes"][o.name] = dict(tris=tri_count(o), center=c, size=s)
    with open(os.path.join(OUT_DIR, NAME + ".json"), "w") as fh:
        json.dump(report, fh, indent=1)
    return report


def main(save=True):
    use_scene()
    data = load_profiles()
    objs = []
    for name, cfg in ROOTS.items():
        objs.extend(build_root(name, cfg, data))
    # side by side in the viewport only for looking; export bakes no object transform (all at the origin)
    report = export(objs)
    if save:  # only this scene's data (the live session holds other areas' scenes too)
        bpy.data.libraries.write(os.path.join(OUT_DIR, NAME + ".blend"), {bpy.context.scene, *objs}, fake_user=True)
    return report


if __name__ == "__main__":
    print(json.dumps(main()["meshes"], indent=1))
