"""Builds the one-handed straight sword (jian) and exports it for Roblox.

Run inside Blender: exec(compile(open(p).read(), p, "exec"), {"__file__": p, "__name__": "__main__"}).
Builds into its own scene "Jian"; RENDER_PREVIEWS also poses the R6 reference beside it.

Units and axes (the reference for every weapon in art/weapons/):
  1 Blender unit = 1 stud (art/rig/rig_preview.py has the R6 measurements and the FBX/Roblox
  axis mapping). Origin = the grip centre, where the R6 right hand holds it: weld this point to
  the RightGripAttachment. +Z = along the blade towards the tip, X = edge to edge, Y = flat to
  flat. In the model's Roblox space that is blade +Y, edges along X, flats facing +-Z.

Exports Jian.fbx (one mesh per Roblox material), Jian.json (mesh tris/centre/size in Blender axes,
plus anchors: grip, tip, guard, tassel mount) and Jian.blend, next to this script.
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

NAME = "Jian"
RENDER_PREVIEWS = True
SHARP_DEG = 28.0           # faces meeting sharper than this get a hard edge

# --- proportions (studs; z measured from the grip centre) ---------------------------------
GRIP_LEN = 0.90            # one R6 hand (1 stud) plus a little: hand covers most of it
GRIP_RX, GRIP_RY = 0.115, 0.095   # oval grip, wider edge-wise like a real jian
GRIP_BANDS = 6             # cord-wrap ridges along the grip
GRIP_SIDES = 8
GUARD_Z = GRIP_LEN / 2     # guard sits on top of the grip
GUARD_HALF_W = 0.40        # guard tip-to-tip half width
GUARD_THICK = 0.22         # guard depth, flat to flat
BLADE_ROOT_Z = GUARD_Z + 0.20
BLADE_LEN = 2.45           # guard to tip; the R6 arm is 2, hip to shoulder is 2
BLADE_HALF_W = 0.15        # at the root (0.30 wide: chunky enough to read on a phone)
BLADE_TIP_HALF_W = 0.12    # just before the tip taper
BLADE_HALF_T = 0.05        # ridge to flat surface (diamond section)
TIP_LEN = 0.32             # the pointed tip run
POMMEL_LEN = 0.22
TASSEL_CORD = 0.22         # cord from the pommel ring to the knot
TASSEL_LEN = 0.42          # fringe length
TASSEL_ON = True
GRIP_ROLL = -90.0          # degrees about the blade axis, grip frame -> sword: turns an edge forward in the
                           # Roblox tool hold (rig_preview.EDGE_FORWARD_ROLL; 0 = flats forward)

PARTS = {  # one MeshPart per Roblox material; plain SmoothPlastic colours
    "JianBlade": (0.72, 0.77, 0.83, 1),    # cool polished steel
    "JianFittings": (0.80, 0.60, 0.24, 1),  # bronze guard, collar and pommel
    "JianGrip": (0.15, 0.17, 0.28, 1),      # dark indigo cord wrap
    "JianTassel": (0.80, 0.16, 0.13, 1),    # red silk tassel
}


# --- mesh helpers -------------------------------------------------------------------------

def loft(bm, rings, cap_start=True, cap_end=True):
    """Bridge rings (lists of verts, same count) into a tube; cap the ends with fans or ngons."""
    for a, b in zip(rings, rings[1:]):
        n = max(len(a), len(b))
        for i in range(n):
            j = (i + 1) % n
            if len(a) == 1:
                bm.faces.new((a[0], b[i], b[j]))
            elif len(b) == 1:
                bm.faces.new((a[i], b[0], a[j]))
            else:
                bm.faces.new((a[i], b[i], b[j], a[j]))
    if cap_start and len(rings[0]) > 2:
        bm.faces.new(list(reversed(rings[0])))
    if cap_end and len(rings[-1]) > 2:
        bm.faces.new(rings[-1])


def ring(bm, z, rx, ry, sides, rot=0.0):
    if rx <= 0:
        return [bm.verts.new((0, 0, z))]
    return [bm.verts.new((rx * math.cos(rot + 2 * math.pi * i / sides), ry * math.sin(rot + 2 * math.pi * i / sides), z))
            for i in range(sides)]


def lathe(bm, profile, sides, sy=1.0, rot=0.0):
    """profile: [(z, r)] from bottom to top; r 0 = a point."""
    rings = [ring(bm, z, r, r * sy, max(sides, 3), rot) if r > 0 else [bm.verts.new((0, 0, z))] for z, r in profile]
    loft(bm, rings)


def finish(name, bm, color):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = not (e.is_boundary or (e.is_manifold and e.calc_face_angle(0) > math.radians(SHARP_DEG)))
    me = bpy.data.meshes.get(name)
    if me:
        bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(rp.preview_material("Preview" + name, color))
    return o


# --- parts --------------------------------------------------------------------------------

def blade():
    # diamond section (edge, ridge, edge, ridge) with a crisp centre ridge on both flats
    bm = bmesh.new()
    z0, z1 = BLADE_ROOT_Z - 0.08, BLADE_ROOT_Z + BLADE_LEN - TIP_LEN   # root tucks into the guard
    tip = BLADE_ROOT_Z + BLADE_LEN
    stations = [(z0, BLADE_HALF_W, BLADE_HALF_T), (BLADE_ROOT_Z + 0.25, BLADE_HALF_W * 0.97, BLADE_HALF_T),
                (z1, BLADE_TIP_HALF_W, BLADE_HALF_T * 0.9),
                (z1 + TIP_LEN * 0.55, BLADE_TIP_HALF_W * 0.62, BLADE_HALF_T * 0.75)]
    rings = [[bm.verts.new(v) for v in ((w, 0, z), (0, t, z), (-w, 0, z), (0, -t, z))] for z, w, t in stations]
    rings.append([bm.verts.new((0, 0, tip))])
    loft(bm, rings, cap_end=False)
    return bm


def guard_outline():
    """Half outline (x >= 0) of the cloud guard seen from the front, (x, z) from the guard base:
    a shallow wedge rising to the blade, ending in a round cloud lobe that curls toward the grip."""
    top = [(0.0, 0.25), (0.10, 0.19), (0.22, 0.13)]
    cx, cz, r = GUARD_HALF_W - 0.085, 0.03, 0.085
    lobe = [(cx + r * math.cos(math.radians(a)), cz + r * math.sin(math.radians(a))) for a in (120, 75, 30, -15, -60, -105, -150)]
    bottom = [(0.18, -0.03), (0.08, 0.0), (0.0, 0.02)]
    return top + lobe + bottom


def guard_and_fittings():
    bm = bmesh.new()
    half = guard_outline()
    pts = half + [(-x, z) for x, z in reversed(half[1:-1])]   # mirror without doubling the centre points
    # extrude the outline flat-to-flat, with the front and back faces bevelled in a little
    t, inset = GUARD_THICK / 2, 0.035
    centre = Vector((0, 0.08))
    def shrink(p):
        v = Vector(p)
        return centre + (v - centre) * 0.86
    layers = [(-t, shrink), (-t + inset, None), (t - inset, None), (t, shrink)]
    rings = []
    for y, fn in layers:
        rings.append([bm.verts.new(((fn(p) if fn else Vector(p)).x, y, GUARD_Z + (fn(p) if fn else Vector(p)).y)) for p in pts])
    for a, b in zip(rings, rings[1:]):
        n = len(a)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    # collar ring between grip and guard
    lathe(bm, [(GUARD_Z - 0.07, GRIP_RX + 0.015), (GUARD_Z - 0.06, GRIP_RX + 0.03), (GUARD_Z + 0.01, GRIP_RX + 0.03)],
          GRIP_SIDES, GRIP_RY / GRIP_RX, rot=math.pi / GRIP_SIDES)
    # pommel: collar, then a flattened bulb with a ring at the bottom for the tassel
    pz = -GRIP_LEN / 2
    lathe(bm, [(pz - POMMEL_LEN, 0.0), (pz - POMMEL_LEN + 0.02, 0.09), (pz - POMMEL_LEN + 0.07, 0.17),
               (pz - 0.08, 0.17), (pz - 0.04, 0.13), (pz + 0.01, GRIP_RX + 0.02)],
          GRIP_SIDES, 0.75, rot=math.pi / GRIP_SIDES)
    return bm


def grip():
    # cord wrap: bands that bulge between narrow grooves
    bm = bmesh.new()
    prof = []
    z0, step = -GRIP_LEN / 2, GRIP_LEN / GRIP_BANDS
    for k in range(GRIP_BANDS):
        a = z0 + k * step
        prof += [(a, 0.86), (a + step * 0.2, 1.0), (a + step * 0.8, 1.0)]
    prof.append((GRIP_LEN / 2, 0.86))
    rings = [ring(bm, z, GRIP_RX * s, GRIP_RY * s, GRIP_SIDES, rot=math.pi / GRIP_SIDES) for z, s in prof]
    loft(bm, rings)
    return bm


def tassel():
    bm = bmesh.new()
    top = -GRIP_LEN / 2 - POMMEL_LEN + 0.03
    knot = top - TASSEL_CORD
    # cord (thin square tube), knot bead, then a fringe that flares and ends flat
    loft(bm, [ring(bm, top, 0.025, 0.025, 4), ring(bm, knot, 0.025, 0.025, 4)])
    lathe(bm, [(knot - 0.13, 0.0), (knot - 0.11, 0.055), (knot - 0.045, 0.075), (knot + 0.01, 0.04), (knot + 0.03, 0.0)], 6)
    f0 = knot - 0.12
    lathe(bm, [(f0 - TASSEL_LEN, 0.0), (f0 - TASSEL_LEN + 0.005, 0.11), (f0 - TASSEL_LEN * 0.55, 0.085), (f0, 0.045)],
          6, rot=math.pi / 6)
    return bm


# --- build / export -----------------------------------------------------------------------

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
    makers = {"JianBlade": blade, "JianFittings": guard_and_fittings, "JianGrip": grip, "JianTassel": tassel}
    return [finish(n, makers[n](), col) for n, col in PARTS.items() if n != "JianTassel" or TASSEL_ON]


def roblox_point(p):
    return [round(p[0], 3), round(p[2], 3), round(-p[1], 3)]


def export(objs):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, NAME + ".fbx"), use_selection=True,
                             object_types={'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                             axis_forward='-Z', axis_up='Y', mesh_smooth_type='EDGE', bake_space_transform=True)
    tip = BLADE_ROOT_Z + BLADE_LEN
    anchors = {
        "grip": dict(pos=[0, 0, 0], roll=GRIP_ROLL,
                     note="pivot; weld to the R6 RightGripAttachment, blade along +Z, an edge turned forward"),
        "tip": dict(pos=[0, 0, round(tip, 3)]),
        "guard": dict(pos=[0, 0, round(GUARD_Z + 0.08, 3)], note="guard centre, for hit/trail effects starting at the blade root"),
        "blade_mid": dict(pos=[0, 0, round((BLADE_ROOT_Z + tip) / 2, 3)]),
        "tassel_mount": dict(pos=[0, 0, round(-GRIP_LEN / 2 - POMMEL_LEN + 0.03, 3)], note="where the tassel cord hangs from"),
    }
    for a in anchors.values():
        a["roblox"] = roblox_point(a["pos"])
    lo = -GRIP_LEN / 2 - POMMEL_LEN
    report = {
        "units": "1 Blender unit = 1 stud; axes X edge-to-edge, Y flat-to-flat, Z along the blade; origin = grip centre",
        "roblox_mapping": "Size = (bx, bz, by); CFrame = pivot * CFrame.Angles(0, math.pi, 0) * CFrame.new(-cx, cz, cy); "
                          "anchor 'roblox' = (x, z, -y) relative to the pivot",
        "overall": dict(length=round(tip - lo, 3), length_with_tassel=None, blade=BLADE_LEN, grip=GRIP_LEN),
        "anchors": anchors,
        "meshes": {},
    }
    for o in objs:
        centre, size = bounds(o)
        report["meshes"][o.name] = dict(tris=len(o.data.polygons), center=centre, size=size)
    if "JianTassel" in report["meshes"]:
        m = report["meshes"]["JianTassel"]
        report["overall"]["length_with_tassel"] = round(tip - (m["center"][2] - m["size"][2] / 2), 3)
    report["tris_total"] = sum(m["tris"] for m in report["meshes"].values())
    with open(os.path.join(OUT_DIR, NAME + ".json"), "w") as fh:
        json.dump(report, fh, indent=1)
    return report


def previews(scene, objs):
    rp.import_rig(scene)
    rp.setup_render(scene)
    out = os.path.join(OUT_DIR, "preview")
    shots = []
    # 1) held: the R6 'toolnone' hold (arm forward, blade up), seen from the front three-quarter
    rp.pose_arm_forward(90)
    # arm-down hand frame: blade points forward (-Y); raising the arm turns it upright
    rest = Matrix.Translation(rp.HAND) @ Matrix.Rotation(math.radians(90), 4, "X")
    held = (rp.armature().matrix_world @ rp.armature().pose.bones["Right Arm"].matrix @
            rp.armature().pose.bones["Right Arm"].bone.matrix_local.inverted()) @ rest
    for o in objs:
        o.matrix_world = held
    shots.append(rp.render(scene, os.path.join(out, "jian_held.png"), (5.5, -8.5, 3.6), (-0.6, -1.0, 1.6), lens=50))
    shots.append(rp.render(scene, os.path.join(out, "jian_held_side.png"), (-9.5, -1.5, 2.0), (-1.5, -1.0, 1.6), ortho=7.5))
    # 2) scale: rig in rest pose, sword standing on its pommel beside it
    rp.pose_arm_forward(0)
    for o in objs:
        o.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()
    low = min(bounds(o)[0][2] - bounds(o)[1][2] / 2 for o in objs)
    stand = Matrix.Translation((-3.0, 0, -2.0 - low))   # lowest point (tassel) on the R6's floor
    for o in objs:
        o.matrix_world = stand
    shots.append(rp.render(scene, os.path.join(out, "jian_scale.png"), (-1.2, -14, 0.6), (-1.2, 0, 0.6), ortho=6.6))
    # 3) close-ups of guard/grip/pommel and of the whole sword
    for o in objs:
        o.matrix_world = Matrix.Identity(4)
    rig = bpy.data.collections[rp.RIG_COLLECTION]
    lc = scene.view_layers[0].layer_collection.children[rig.name]
    lc.exclude = True
    shots.append(rp.render(scene, os.path.join(out, "jian_closeup_hilt.png"), (1.6, -2.4, 0.9), (0, 0, 0.1), lens=60))
    shots.append(rp.render(scene, os.path.join(out, "jian_closeup_full.png"), (2.5, -5.5, 1.4), (0, 0, 1.2), ortho=4.6))
    lc.exclude = False
    for o in objs:
        o.matrix_world = Matrix.Identity(4)
    return shots


def main():
    scene = rp.use_scene(NAME)
    objs = build(scene)
    report = export(objs)
    shots = previews(scene, objs) if RENDER_PREVIEWS else []
    rp.save_blend(scene, os.path.join(OUT_DIR, NAME + ".blend"))
    print(json.dumps({k: v for k, v in report.items() if k in ("overall", "tris_total")}), shots)


if __name__ == "__main__":
    main()
