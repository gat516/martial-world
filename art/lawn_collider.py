"""Invisible collider boxes under a lawn mesh, so a thin open turf shell can't let players fall through.

Why: PeakGrass is an open surface (the lawn top plus its 1.3-stud lip, and the cliff-ledge turf ~420 studs
further down) in one MeshPart. Roblox's PreciseConvexDecomposition of a mesh that tall and thin leaves gaps
in the lawn's collision (measured: a ~8x8 hole over the abode dome and a 3-stud-wide diagonal crack on every
spirit peak). A few axis-aligned boxes just under the visible turf close them for good.

lawn_strips(bm, ...) returns boxes [x0, x1, y0, y1, top] in the mesh's own axes (Blender, z up): strips of
STRIP studs along x, each spanning the y interval where the flat lawn is present for the whole strip, inset
INSET from its edge, with the top a hair under the lowest turf in the box. build_peak_pillar.py writes them
into SpiritPeakPillar.json ("lawn_collider"); place_peak_pillar.luau builds them as Parts.

Run headless to (re)compute them from an exported FBX without rebuilding the meshes:
  blender -b --factory-startup -P art/lawn_collider.py -- art/SpiritPeakPillar.fbx PeakGrass art/SpiritPeakPillar.json
"""
import json
import sys

import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

STRIP = 4.0       # strip width along x (studs)
SAMPLE = 0.5      # sampling step inside a strip
INSET = 1.0       # keep the box this far inside the lawn's flat edge, so it never pokes out of the bevel
FLAT_NZ = 0.95    # a face counts as lawn when it is this close to level...
MIN_Z = -2.8      # ...and at least this high (the plateau top; the cliff ledges sit far lower)
BELOW = 0.1       # box top sits this far under the lowest turf it covers
MIN_LEN = 3.0     # drop intervals shorter than this


def lawn_strips(bm, min_z=MIN_Z, strip=STRIP):
    bm.normal_update()  # bm.transform() leaves face normals in the old axes
    tree = BVHTree.FromBMesh(bm)
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    x_lo, x_hi, y_lo, y_hi = min(xs), max(xs), min(ys), max(ys)

    def top_at(x, y):
        loc, nrm, _, _ = tree.ray_cast(Vector((x, y, 1000.0)), Vector((0, 0, -1)), 2000.0)
        if loc is None or loc.z < min_z or abs(nrm.z) < FLAT_NZ:
            return None
        return loc.z

    def frange(a, b, s):
        n = int((b - a) / s)
        return [a + i * s for i in range(n + 1)]

    boxes = []
    x0 = x_lo - (x_lo % strip)
    while x0 < x_hi:
        x1 = x0 + strip
        cols = frange(x0 + INSET, x1 - INSET, SAMPLE) if strip > 2 * INSET else [(x0 + x1) / 2]
        # widen the probe by INSET so the box keeps clear of the lawn edge across the strip's sides too
        probe = frange(x0 - INSET, x1 + INSET, SAMPLE)
        run, lowest = None, None
        for y in frange(y_lo, y_hi + SAMPLE, SAMPLE):
            zs = [top_at(x, y) for x in probe]
            ok = all(z is not None for z in zs)
            if ok:
                lowest = min(zs) if run is None else min(lowest, min(zs))
                run = y if run is None else run
            if not ok or y >= y_hi:
                if run is not None:
                    a, b = run + INSET, (y if ok else y - SAMPLE) - INSET
                    if b - a >= MIN_LEN:
                        boxes.append([round(x0, 3), round(x1, 3), round(a, 3), round(b, 3),
                                      round(lowest - BELOW, 3)])
                run, lowest = None, None
        x0 = x1
    return boxes


def _main(argv):
    import bpy
    fbx, mesh_name, json_path = argv
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx)
    obj = bpy.data.objects[mesh_name]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)
    boxes = lawn_strips(bm)
    with open(json_path) as fh:
        report = json.load(fh)
    report["lawn_collider"] = boxes
    with open(json_path, "w") as fh:
        json.dump(report, fh, indent=1)
    print("lawn collider boxes:", len(boxes))


if __name__ == "__main__" and "--" in sys.argv:
    _main(sys.argv[sys.argv.index("--") + 1:])
