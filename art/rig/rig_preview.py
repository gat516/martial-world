"""Shared helpers for hand-held items and pickups: the R6 scale reference and preview renders.

Imported by the item build scripts (art/weapons/*/build_*.py, art/items/*/build_*.py); not run
on its own. Blender runs on Windows here, so paths come from each script's __file__.

Units (every item reuses these):
  1 Blender unit = 1 stud. art/rig/r6_rigged.fbx imports at exactly stud scale: the R6 is
  4 wide (torso 2 + two 1-stud arms) and 5.1 tall, feet at z -2, hips z 0, shoulders z 2,
  head top z 3.1. It faces -Y (Blender front view looks at its face); its right arm is the
  one at x -2..-1. The R6 RightGripAttachment (bottom centre of the right arm) is at
  (-1.5, 0, 0) in rest pose.
  FBX export: apply_unit_scale + FBX_SCALE_UNITS, -Z forward / Y up, as the peaks do.
  Roblox's import comes in ~11x oversized and remaps axes, so the place script sets every
  MeshPart's Size and CFrame from the bounds JSON:
    Size = (bx, bz, by), CFrame = pivot * CFrame.Angles(0, math.pi, 0) * CFrame.new(-cx, cz, cy)
  A point (x, y, z) in Blender is (x, z, -y) in the model's Roblox space: Blender +Z is Roblox
  up, +X stays +X, +Y becomes -Z.
"""
import math
import os

import bpy
from mathutils import Matrix, Vector

RIG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "r6_rigged.fbx")
RIG_COLLECTION = "R6Reference"
HAND = Vector((-1.5, 0.0, 0.0))        # R6 RightGripAttachment, rest pose
SHOULDER = Vector((-1.5, 0.0, 1.5))    # R6 Right Shoulder joint (Torso C0 (1, 0.5, 0))
RIG_COLOR = (0.62, 0.64, 0.68, 1)      # neutral gray so the item's colours read against it
BG_COLOR = (0.13, 0.15, 0.19)          # preview world colour


def use_scene(name):
    scn = bpy.data.scenes.get(name) or bpy.data.scenes.new(name)
    bpy.context.window.scene = scn
    return scn


def preview_material(name, color, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.55
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emit
    else:
        bsdf.inputs["Emission Strength"].default_value = 0.0
    m.diffuse_color = color
    return m


def rig_objects():
    col = bpy.data.collections.get(RIG_COLLECTION)
    return list(col.objects) if col else []


def import_rig(scene):
    """Load the R6 rig once into its own collection and link it into `scene`."""
    col = bpy.data.collections.get(RIG_COLLECTION)
    if col is None:
        col = bpy.data.collections.new(RIG_COLLECTION)
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=RIG_FILE)
        for o in set(bpy.data.objects) - before:
            for c in list(o.users_collection):
                c.objects.unlink(o)
            col.objects.link(o)
            if o.type == "MESH":
                o.data.materials.clear()
                o.data.materials.append(preview_material("PreviewR6", RIG_COLOR))
    if col.name not in scene.collection.children:
        scene.collection.children.link(col)
    return col


def armature():
    return next(o for o in rig_objects() if o.type == "ARMATURE")


def pose_arm_forward(angle=90.0):
    """R6 'toolnone' hold: right arm raised forward about the shoulder joint (0 = rest)."""
    arm = armature()
    pb = arm.pose.bones["Right Arm"]
    pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    pivot = arm.matrix_world.inverted() @ SHOULDER
    rot = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(-angle), 4, "X") @ Matrix.Translation(-pivot)
    pb.matrix = rot @ pb.bone.matrix_local
    bpy.context.view_layer.update()
    return arm.matrix_world @ rot @ arm.matrix_world.inverted()   # world-space transform of the hand


def setup_render(scene, res=(900, 900)):
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            continue
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    world = scene.world or bpy.data.worlds.new(scene.name + "World")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (*BG_COLOR, 1)
    bg.inputs["Strength"].default_value = 1.0
    if hasattr(scene, "eevee"):
        for attr in ("use_bloom",):
            if hasattr(scene.eevee, attr):
                setattr(scene.eevee, attr, True)
    _light(scene, "PreviewKey", (4, -6, 7), 650, 6.0)   # brighter blows steel out to white
    _light(scene, "PreviewFill", (-6, -3, 2), 250, 8.0)
    _light(scene, "PreviewRim", (0, 7, 5), 500, 5.0)


def _light(scene, name, loc, power, size):
    data = bpy.data.lights.get(name) or bpy.data.lights.new(name, "AREA")
    data.energy, data.size = power, size
    o = bpy.data.objects.get(name) or bpy.data.objects.new(name, data)
    if o.name not in scene.collection.objects:
        scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, 1)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


def render(scene, path, eye, target, ortho=None, lens=50):
    """Render one still from `eye` looking at `target`; ortho = ortho_scale or None for perspective."""
    cam_data = bpy.data.cameras.get("PreviewCam") or bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.get("PreviewCam") or bpy.data.objects.new("PreviewCam", cam_data)
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    cam_data.type = "ORTHO" if ortho else "PERSP"
    if ortho:
        cam_data.ortho_scale = ortho
    cam_data.lens = lens
    cam_data.clip_start, cam_data.clip_end = 0.01, 200
    cam.location = eye
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    os.makedirs(os.path.dirname(path), exist_ok=True)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True, scene=scene.name)
    return path


def save_blend(scene, path):
    """Write just this scene (and what it uses) to its own .blend, leaving the session file alone."""
    bpy.data.libraries.write(path, {scene}, fake_user=True, compress=True)


# =============================================================================================
# Modeling kit shared by the weapon/item scripts (the jian keeps its own copies of the early
# versions; everything after it builds on these).
# Conventions: +Z runs along the item towards its business end (blade tip, staff head), X is
# edge to edge (single-edged blades: +X is the cutting edge), Y is flat to flat. The mesh origin
# is the build origin; where the right hand holds it is the `grip` anchor, which may sit away from
# the origin (balance point on a polearm, just under the guard on a two-hander) and carries a
# `roll`: degrees about the item's axis (+Z) from the grip frame to the item. EDGE_FORWARD_ROLL
# turns +X (the cutting edge) to face forward, the way the rig faces and swings, when held in
# Roblox's tool hold. Tool.Grip = the grip anchor's frame, roll included.
# =============================================================================================

import json  # noqa: E402

import bmesh  # noqa: E402

SHARP_DEG = 28.0   # faces meeting sharper than this get a hard edge

PALETTE = {  # the set's shared colours (plain SmoothPlastic in Roblox)
    "steel": (0.72, 0.77, 0.83, 1),    # blades
    "bronze": (0.80, 0.60, 0.24, 1),   # guards, collars, caps, pommels, bridges
    "cord": (0.15, 0.17, 0.28, 1),     # dark indigo cord wrap / thread bindings
    "red": (0.80, 0.16, 0.13, 1),      # tassels and ribbons
    "wood": (0.45, 0.27, 0.14, 1),     # polearm shafts
    "lacquer": (0.30, 0.15, 0.09, 1),  # zither body (dark red-brown lacquered wood)
    "silk": (0.93, 0.88, 0.72, 1),     # strings
    "bamboo": (0.70, 0.56, 0.30, 1),   # flute
    "dark": (0.08, 0.06, 0.05, 1),     # holes
}

EDGE_FORWARD_ROLL = -90.0   # grip roll that puts +X (the edge) forward in the hand; 0 = flats forward

REVIEW_SCENE = "Review"
REVIEW_COLLECTION = "ReviewModels"
GROUND_Z = -2.0    # the R6's floor


def loft(bm, rings, cap_start=True, cap_end=True):
    """Bridge rings (lists of verts, equal counts, or a single vert = a point) into a tube."""
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


def ring(bm, z, rx, ry, sides, rot=0.0, cx=0.0, cy=0.0):
    if rx <= 0:
        return [bm.verts.new((cx, cy, z))]
    return [bm.verts.new((cx + rx * math.cos(rot + 2 * math.pi * i / sides),
                          cy + ry * math.sin(rot + 2 * math.pi * i / sides), z)) for i in range(sides)]


def lathe(bm, profile, sides, sy=1.0, rot=None, cx=0.0, cy=0.0):
    """Turned part. profile: [(z, r)] bottom to top; r 0 = a point. sy squashes it flat-to-flat."""
    rot = math.pi / sides if rot is None else rot
    loft(bm, [ring(bm, z, r, r * sy, sides, rot, cx, cy) for z, r in profile])


def box(bm, centre, size):
    cx, cy, cz = centre
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    lo = [bm.verts.new((cx + x, cy + y, cz - hz)) for x, y in ((-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy))]
    hi = [bm.verts.new((cx + x, cy + y, cz + hz)) for x, y in ((-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy))]
    loft(bm, [lo, hi])


def strip(bm, p0, p1, width, thick, side=Vector((1, 0, 0))):
    """A flat ribbon/string segment from p0 to p1, `width` along `side`, `thick` across both."""
    p0, p1 = Vector(p0), Vector(p1)
    d = (p1 - p0).normalized()
    s = (side - d * side.dot(d)).normalized() * (width / 2)
    t = d.cross(s).normalized() * (thick / 2)
    a = [bm.verts.new(p0 + u + v) for u, v in ((-s, -t), (s, -t), (s, t), (-s, t))]
    b = [bm.verts.new(p1 + u + v) for u, v in ((-s, -t), (s, -t), (s, t), (-s, t))]
    loft(bm, [a, b])


def blade_along(bm, path, section):
    """A blade swept along `path` [(x, z)] from root to tip, in the XZ plane. section(i, t) gives
    the cross-section [(u, y)]: u across the blade (+ = the path's +X side, the edge side), y flat
    to flat. A single (u, y) makes that station a point (the tip)."""
    rings = []
    n = len(path)
    for i, (x, z) in enumerate(path):
        a = Vector(path[max(i - 1, 0)])
        b = Vector(path[min(i + 1, n - 1)])
        tx, tz = (b - a).normalized()
        nx, nz = tz, -tx    # normal: +X for a path running up +Z
        rings.append([bm.verts.new((x + u * nx, y, z + u * nz)) for u, y in section(i, i / (n - 1))])
    loft(bm, rings, cap_end=False)


def cloud_guard(bm, z, half_w, thick, height=1.0, lobe=0.085):
    """The set's cloud guard (as on the jian): a wedge rising to the blade, ending in round cloud
    lobes that curl toward the grip; extruded flat-to-flat with bevelled faces. height scales the
    wedge, z is its base."""
    h = height
    top = [(0.0, 0.25 * h), (half_w * 0.25, 0.19 * h), (half_w * 0.55, 0.13 * h)]
    cx, cz = half_w - lobe, 0.03 * h
    arc = [(cx + lobe * math.cos(math.radians(a)), cz + lobe * math.sin(math.radians(a))) for a in (120, 75, 30, -15, -60, -105, -150)]
    bottom = [(half_w * 0.45, -0.03 * h), (half_w * 0.2, 0.0), (0.0, 0.02 * h)]
    half = top + arc + bottom
    pts = half + [(-x, zz) for x, zz in reversed(half[1:-1])]
    t, inset = thick / 2, min(0.035, thick * 0.16)
    centre = Vector((0, 0.08 * h))
    rings = []
    for y, shrink in ((-t, True), (-t + inset, False), (t - inset, False), (t, True)):
        rings.append([])
        for p in pts:
            v = centre + (Vector(p) - centre) * 0.86 if shrink else Vector(p)
            rings[-1].append(bm.verts.new((v.x, y, z + v.y)))
    for a, b in zip(rings, rings[1:]):
        for i in range(len(a)):
            j = (i + 1) % len(a)
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))


def cord_grip(bm, z0, z1, rx, ry, bands, sides=8):
    """Cord wrap: bands that bulge between narrow grooves, from z0 up to z1."""
    prof, step = [], (z1 - z0) / bands
    for k in range(bands):
        a = z0 + k * step
        prof += [(a, 0.86), (a + step * 0.2, 1.0), (a + step * 0.8, 1.0)]
    prof.append((z1, 0.86))
    loft(bm, [ring(bm, z, rx * s, ry * s, sides, math.pi / sides) for z, s in prof])


def tassel(bm, top, cord=0.22, length=0.42, scale=1.0, cx=0.0, cy=0.0):
    """Hanging tassel (as on the jian): cord, knot bead, flared fringe. Returns its lowest z."""
    s = scale
    knot = top - cord
    loft(bm, [ring(bm, top, 0.025 * s, 0.025 * s, 4, 0, cx, cy), ring(bm, knot, 0.025 * s, 0.025 * s, 4, 0, cx, cy)])
    lathe(bm, [(knot - 0.13 * s, 0.0), (knot - 0.11 * s, 0.055 * s), (knot - 0.045 * s, 0.075 * s),
               (knot + 0.01 * s, 0.04 * s), (knot + 0.03 * s, 0.0)], 6, rot=0, cx=cx, cy=cy)
    f0 = knot - 0.12 * s
    lathe(bm, [(f0 - length, 0.0), (f0 - length + 0.005, 0.11 * s), (f0 - length * 0.55, 0.085 * s), (f0, 0.045 * s)],
          6, cx=cx, cy=cy)
    return f0 - length


def finish(name, bm, color, smooth=True):
    """Triangulate, set hard edges past SHARP_DEG (or all flat), and link as object `name`."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = smooth
    for e in bm.edges:
        e.smooth = smooth and not (e.is_boundary or (e.is_manifold and e.calc_face_angle(0) > math.radians(SHARP_DEG)))
    o = bpy.data.objects.get(name)
    if o:
        bpy.data.objects.remove(o, do_unlink=True)
    me = bpy.data.meshes.get(name)
    if me:
        bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(preview_material("Preview" + name, color))
    return o


def bounds(objs):
    objs = objs if isinstance(objs, (list, tuple)) else [objs]
    ws = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    mn = Vector((min(v.x for v in ws), min(v.y for v in ws), min(v.z for v in ws)))
    mx = Vector((max(v.x for v in ws), max(v.y for v in ws), max(v.z for v in ws)))
    return [round(x, 3) for x in (mn + mx) / 2], [round(x, 3) for x in mx - mn]


def to_roblox(v):
    return [round(v[0], 3), round(v[2], 3), round(-v[1], 3)]


def export_item(out_dir, name, objs, anchors, units, extra=None):
    """FBX (one mesh per Roblox material) + bounds JSON, house settings. anchors: {name: {pos,
    optional dir/up (Blender vectors), note}}; each also gets its Roblox-space values."""
    for o in objs:
        o.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(out_dir, name + ".fbx"), use_selection=True,
                             object_types={'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                             axis_forward='-Z', axis_up='Y', mesh_smooth_type='EDGE', bake_space_transform=True)
    for a in anchors.values():
        a["pos"] = [round(x, 3) for x in a["pos"]]
        if "roll" in a:
            a["roll"] = round(a["roll"], 3)
        a["roblox"] = to_roblox(a["pos"])
        for k in ("dir", "up"):
            if k in a:
                a[k] = [round(x, 3) for x in a[k]]
                a["roblox_" + k] = to_roblox(a[k])
    c, s = bounds(objs)
    report = {
        "units": units,
        "roblox_mapping": "Size = (bx, bz, by); CFrame = pivot * CFrame.Angles(0, math.pi, 0) * CFrame.new(-cx, cz, cy); "
                          "anchor/direction 'roblox' = (x, z, -y) relative to the pivot (the mesh origin); "
                          "an anchor's 'roll' is degrees about the item axis (Blender +Z = Roblox +Y): "
                          "anchor frame = CFrame.new(roblox) * CFrame.Angles(0, rad(roll), 0); Tool.Grip = grip frame "
                          "(in Handle space)",
        "overall": dict(center=c, size=s, length=s[2]),
        "anchors": anchors,
        "meshes": {},
    }
    report.update(extra or {})
    for o in objs:
        oc, osz = bounds(o)
        report["meshes"][o.name] = dict(tris=len(o.data.polygons), center=oc, size=osz)
    report["tris_total"] = sum(m["tris"] for m in report["meshes"].values())
    with open(os.path.join(out_dir, name + ".json"), "w") as fh:
        json.dump(report, fh, indent=1)
    return report


def hand_matrix():
    """World transform of the right hand: an item's local frame goes here so its +Z points
    forward out of the fist with the arm down, and up with the arm raised (Roblox's hold)."""
    arm = armature()
    pb = arm.pose.bones["Right Arm"]
    bone = arm.matrix_world @ pb.matrix @ pb.bone.matrix_local.inverted()
    # the trailing half turn about the item axis matches Roblox's R6 RightGrip (C0 = (0,-1,0) with
    # -90 deg about X): item +X ends up on the rig's right, as it does in Studio
    return (bone @ Matrix.Translation(HAND) @ Matrix.Rotation(math.radians(90), 4, "X") @
            Matrix.Rotation(math.pi, 4, "Z"))


def grip_frame(anchor):
    """The grip anchor as a Blender-space frame on the item: position, then roll about +Z."""
    if not anchor:
        return Matrix.Identity(4)
    return Matrix.Translation(anchor["pos"]) @ Matrix.Rotation(math.radians(anchor.get("roll", 0.0)), 4, "Z")


def place(objs, m):
    for o in objs:
        o.matrix_world = m
    bpy.context.view_layer.update()


def stand_matrix(objs, x):
    """Upright on the R6's floor at `x`, lowest point on the ground."""
    place(objs, Matrix.Identity(4))
    c, s = bounds(objs)
    return Matrix.Translation((x, 0, GROUND_Z - (c[2] - s[2] / 2)))


def hide_rig(scene, hidden):
    lc = scene.view_layers[0].layer_collection.children.get(RIG_COLLECTION)
    if lc:
        lc.exclude = hidden


def standard_previews(scene, objs, out_dir, prefix, detail_z, detail_dist=2.6, held=True, grip=None):
    """held (arm forward), scale (standing beside the R6), full close-up, detail close-up."""
    import_rig(scene)
    setup_render(scene)
    out = os.path.join(out_dir, "preview")
    shots = []
    c, s = bounds(objs)
    if held:
        pose_arm_forward(90)
        place(objs, hand_matrix() @ grip_frame(grip).inverted())
        hc, hs = bounds(objs)
        span = max(5.5, hs[2] + 1.5)
        shots.append(render(scene, os.path.join(out, prefix + "_held.png"),
                            (span * 0.75, -span * 1.25, hc[2] + 0.6), (hc[0] * 0.5, -1.0, hc[2] * 0.6 + 0.3), lens=40))
    pose_arm_forward(0)
    x = -2.4 - s[0] / 2 + c[0] if c[0] < 0 else -2.4 - s[0] / 2 - c[0]
    place(objs, stand_matrix(objs, x))
    top = max(3.1, GROUND_Z + s[2])
    mid_x = (x - s[0] / 2 + 2.0) / 2
    shots.append(render(scene, os.path.join(out, prefix + "_scale.png"), (mid_x, -20, (GROUND_Z + top) / 2),
                        (mid_x, 0, (GROUND_Z + top) / 2), ortho=max(top - GROUND_Z, 2.0 - (x - s[0] / 2)) + 0.8))
    place(objs, Matrix.Identity(4))
    hide_rig(scene, True)
    shots.append(render(scene, os.path.join(out, prefix + "_closeup_full.png"), (c[0] + 2.5, -12, c[2] + 1.5),
                        (c[0], 0, c[2]), ortho=max(s) * 1.1))
    shots.append(render(scene, os.path.join(out, prefix + "_closeup_detail.png"),
                        (detail_dist * 0.55, -detail_dist, detail_z + detail_dist * 0.3), (0, 0, detail_z), lens=55))
    hide_rig(scene, False)
    return shots


def add_to_review(objs):
    """Copy the item into the Review scene's lineup (shared mesh data). review_lineup.py spaces them."""
    scn = bpy.data.scenes.get(REVIEW_SCENE)
    if scn is None:
        return None
    col = bpy.data.collections.get(REVIEW_COLLECTION)
    if col is None:
        col = bpy.data.collections.new(REVIEW_COLLECTION)
        scn.collection.children.link(col)
    for o in objs:
        old = bpy.data.objects.get("Review_" + o.name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        r = o.copy()
        r.name = "Review_" + o.name
        r.matrix_world = Matrix.Identity(4)
        col.objects.link(r)
    return col


def item_main(name, out_dir, build, anchors, units, extra=None, previews=None, render_previews=True):
    """The shared driver: build into scene `name`, export, preview, copy to Review, save .blend."""
    scene = use_scene(name)
    objs = build()
    report = export_item(out_dir, name, objs, anchors(), units, extra)
    shots = previews(scene, objs) if (previews and render_previews) else []
    place(objs, Matrix.Identity(4))
    add_to_review(objs)
    save_blend(scene, os.path.join(out_dir, name + ".blend"))
    print(json.dumps({"overall": report["overall"], "tris_total": report["tris_total"],
                      "meshes": {k: v["tris"] for k, v in report["meshes"].items()}}), shots)
    return report, shots
