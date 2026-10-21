"""Builds the Spirit Stone (the currency pickup) and exports it for Roblox.

Run inside Blender: exec(compile(open(p).read(), p, "exec"), {"__file__": p, "__name__": "__main__"}).
Builds into its own scene "SpiritStone"; RENDER_PREVIEWS also poses the R6 reference beside it.

Units and axes: 1 Blender unit = 1 stud (see art/rig/rig_preview.py for the R6 measurements and
the FBX/Roblox axis mapping). Origin = the stone's centre (spin/bob pivot for a pickup), Z up.

A hexagonal crystal: a pointed crown, a twisted girdle band that breaks the sides into triangle
facets, and a shorter pointed base. Two meshes: the faceted shell and a smaller glowing core
inside it (Neon in Roblox, seen through a slightly transparent shell).

Exports SpiritStone.fbx, SpiritStone.json (tris/centre/size in Blender axes, plus anchors) and
SpiritStone.blend, next to this script.
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

NAME = "SpiritStone"
RENDER_PREVIEWS = True
SIDES = 6                 # hexagonal: few, big facets read best at pickup size
# profile from tip to base: (z, radius, twist in units of half a facet). Twisting alternate
# rings breaks the sides into crisp triangle facets (the mesh is the rings' convex hull).
PROFILE = [
    (0.38, 0.00, 0),      # crown point
    (0.25, 0.14, 1),      # crown shoulder
    (0.07, 0.22, 0),      # upper girdle (widest)
    (-0.06, 0.20, 1),     # lower girdle
    (-0.30, 0.00, 0),     # base point
]
CORE_SCALE = 0.55         # glowing core, relative to the shell
SHELL_ALPHA = 0.8         # preview only: how see-through the shell is (Roblox Transparency ~0.2)

PARTS = {
    "SpiritStone": ((0.20, 0.85, 0.72, 1), 0.5),      # jade-cyan shell, soft glow
    "SpiritStoneCore": ((0.55, 1.00, 0.88, 1), 2.5),  # bright core (Neon)
}


def crystal(scale=1.0):
    bm = bmesh.new()
    rings = []
    for z, r, twist in PROFILE:
        if r <= 0:
            rings.append([bm.verts.new((0, 0, z * scale))])
            continue
        a0 = twist * math.pi / SIDES
        rings.append([bm.verts.new((r * scale * math.cos(a0 + 2 * math.pi * i / SIDES),
                                    r * scale * math.sin(a0 + 2 * math.pi * i / SIDES), z * scale))
                      for i in range(SIDES)])
    # the convex hull of the rings: always a clean convex gem, every facet a flat triangle
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = False          # every facet flat: the shape is the gem cut
    return bm


def finish(name, bm, color, emit):
    me = bpy.data.meshes.get(name)
    if me:
        bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    m = rp.preview_material("Preview" + name, color, emit)
    if name == "SpiritStone":
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Alpha"].default_value = SHELL_ALPHA
        for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            if hasattr(m, attr):
                try:
                    setattr(m, attr, val)
                except TypeError:
                    pass
    o.data.materials.append(m)
    return o


def bounds(o):
    ws = [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = Vector((min(v.x for v in ws), min(v.y for v in ws), min(v.z for v in ws)))
    mx = Vector((max(v.x for v in ws), max(v.y for v in ws), max(v.z for v in ws)))
    return [round(x, 3) for x in (mn + mx) / 2], [round(x, 3) for x in mx - mn]


def build(scene):
    for n in PARTS:
        o = bpy.data.objects.get(n)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
    return [finish(n, crystal(1.0 if n == "SpiritStone" else CORE_SCALE), col, emit) for n, (col, emit) in PARTS.items()]


def export(objs):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, NAME + ".fbx"), use_selection=True,
                             object_types={'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                             axis_forward='-Z', axis_up='Y', mesh_smooth_type='EDGE', bake_space_transform=True)
    base = PROFILE[-1][0]
    anchors = {
        "centre": dict(pos=[0, 0, 0], note="pivot; spin/bob about +Z (Roblox +Y)"),
        "base": dict(pos=[0, 0, base], note="lowest point; rest the pivot this far above the ground"),
        "light": dict(pos=[0, 0, 0], note="PointLight here (glow colour = the core colour)"),
    }
    for a in anchors.values():
        p = a["pos"]
        a["roblox"] = [round(p[0], 3), round(p[2], 3), round(-p[1], 3)]
    report = {
        "units": "1 Blender unit = 1 stud; Z up; origin = stone centre",
        "roblox_mapping": "Size = (bx, bz, by); CFrame = pivot * CFrame.Angles(0, math.pi, 0) * CFrame.new(-cx, cz, cy); "
                          "anchor 'roblox' = (x, z, -y) relative to the pivot",
        "anchors": anchors,
        "meshes": {},
    }
    for o in objs:
        centre, size = bounds(o)
        report["meshes"][o.name] = dict(tris=len(o.data.polygons), center=centre, size=size)
    with open(os.path.join(OUT_DIR, NAME + ".json"), "w") as fh:
        json.dump(report, fh, indent=1)
    return report


def place(objs, m):
    for o in objs:
        o.matrix_world = m


def previews(scene, objs):
    rp.import_rig(scene)
    rp.setup_render(scene)
    out = os.path.join(OUT_DIR, "preview")
    shots = []
    # held up in the right fist (arm forward), just past the end of the arm
    rp.pose_arm_forward(90)
    pb = rp.armature().pose.bones["Right Arm"]
    hand = rp.armature().matrix_world @ pb.matrix @ pb.bone.matrix_local.inverted()
    place(objs, Matrix.Translation(hand @ (rp.HAND + Vector((0, 0, -0.38)))))   # upright, just past the fist
    shots.append(rp.render(scene, os.path.join(out, "spirit_stone_held.png"), (5.0, -8.0, 3.2), (-0.8, -1.0, 1.4), lens=50))
    # dropped on the ground by the R6's feet, front view for scale
    rp.pose_arm_forward(0)
    place(objs, Matrix.Translation((-2.6, -0.4, -2.0 - PROFILE[-1][0])))
    shots.append(rp.render(scene, os.path.join(out, "spirit_stone_scale.png"), (-0.6, -14, 0.6), (-0.6, 0, 0.6), ortho=6.6))
    # close-ups, rig hidden
    place(objs, Matrix.Identity(4))
    lc = scene.view_layers[0].layer_collection.children[rp.RIG_COLLECTION]
    lc.exclude = True
    shots.append(rp.render(scene, os.path.join(out, "spirit_stone_closeup.png"), (1.3, -1.9, 0.75), (0, 0, 0.03), lens=60))
    shots.append(rp.render(scene, os.path.join(out, "spirit_stone_closeup_top.png"), (0.5, -0.8, 2.0), (0, 0, 0.03), lens=60))
    lc.exclude = False
    return shots


def main():
    scene = rp.use_scene(NAME)
    objs = build(scene)
    report = export(objs)
    shots = previews(scene, objs) if RENDER_PREVIEWS else []
    rp.save_blend(scene, os.path.join(OUT_DIR, NAME + ".blend"))
    print(json.dumps(report["meshes"]), shots)


if __name__ == "__main__":
    main()
