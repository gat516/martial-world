r"""Builds the stylized cloud-sea meshes (chunky cumulus clumps) and exports them for Roblox.

Run headless, never in the shared interactive Blender (evaluating modifiers on a scene that isn't
shown in the window crashed it):
  "/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --factory-startup \
      --python '\\wsl.localhost\Ubuntu\home\cj\roblox\martial-world\art\clouds\build_clouds.py'
Optional: -- preview  renders art/clouds/preview.png instead of exporting.

Each cloud is a union of round billows (icospheres, voxel-remeshed into one shell so the creases
between billows stay readable), cut flat underneath, decimated to a tri budget and smooth-shaded.
Billows stay round; only their arrangement gives the cloud its width, so nothing reads as a
squashed sphere. UVs carry a baked value ramp instead of a texture layout: U = 0.5, V = how lit the
surface is (up-facing and high = 1, down-facing and low = 0). In Roblox the meshes use
CloudRamp.png (4 soft bands: cool shaded underside -> warm lit top) as TextureID.

Units and axes: 1 Blender unit = 1 stud. Each mesh has its origin at the centre of its flat bottom,
X = length, Y = depth, Z = up. Instances are scaled and rotated in Studio (place_clouds.luau).

Exports art/clouds/Clouds.fbx (one mesh object per cloud shape) and art/clouds/Clouds.json
(tris, centre and size in Blender axes per mesh), and art/clouds/Clouds.blend (just these objects).
"""
import json
import math
import os
import random

import bmesh
import bpy
from mathutils import Vector

OUT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else bpy.path.abspath("//")
NAME = "Clouds"
SCENE = "Clouds"
BILLOW_SUBDIV = 3       # icosphere subdivisions per billow before the union remesh
HERO_CHANCE = 0.2       # share of billows blown up by HERO_SCALE
HERO_SCALE = 1.3
RAMP_NZ = 0.7           # share of the ramp coordinate from the normal (rest from height)

# name: dict(
#   length, depth: footprint ellipse (studs); height: rough top of the central dome
#   rows: billow tiers, each (count, radius range as share of depth, ring position 0..1 of the footprint,
#         lift as share of height); tiers further in sit higher
#   voxel: remesh voxel size; tris: decimation target; seed
#   arc: optional (radius, degrees) bends the footprint around a circle (wisps hugging a pillar)
SHAPES = {
    # dense deck clumps: wide, low, a rim of mid billows around a few big central heads
    "Cloud_DeckA": dict(length=260, depth=190, height=70, seed=11, voxel=2.6, tris=1600,
                        rows=[(14, (0.17, 0.26), 0.92, 0.05), (8, (0.22, 0.30), 0.55, 0.35),
                              (5, (0.18, 0.27), 0.32, 0.55)]),
    "Cloud_DeckB": dict(length=300, depth=170, height=60, seed=23, voxel=2.8, tris=1600,
                        rows=[(16, (0.15, 0.25), 0.92, 0.04), (9, (0.20, 0.29), 0.55, 0.30),
                              (5, (0.19, 0.27), 0.30, 0.52)]),
    "Cloud_DeckC": dict(length=220, depth=200, height=85, seed=37, voxel=2.5, tris=1600,
                        rows=[(13, (0.16, 0.24), 0.90, 0.05), (7, (0.22, 0.30), 0.52, 0.38),
                              (4, (0.20, 0.29), 0.28, 0.62)]),
    # long low strip: fills between clumps and makes the far deck edges
    "Cloud_DeckLong": dict(length=440, depth=140, height=50, seed=41, voxel=3.0, tris=1500,
                           rows=[(20, (0.18, 0.28), 0.90, 0.04), (10, (0.22, 0.32), 0.45, 0.30)]),
    # towering cumulus: mid-height banks between peaks
    "Cloud_Tower": dict(length=230, depth=170, height=150, seed=53, voxel=2.6, tris=2200,
                        rows=[(15, (0.20, 0.30), 0.95, 0.05), (10, (0.24, 0.34), 0.66, 0.26),
                              (6, (0.28, 0.36), 0.38, 0.52), (3, (0.30, 0.38), 0.16, 0.80)]),
    # horizon bank: huge, big billows only (seen far through the haze)
    "Cloud_Bank": dict(length=760, depth=240, height=230, seed=67, voxel=6.0, tris=2200,
                       rows=[(18, (0.18, 0.28), 0.92, 0.05), (11, (0.24, 0.34), 0.60, 0.32),
                             (6, (0.28, 0.38), 0.30, 0.62), (2, (0.30, 0.40), 0.10, 0.85)]),
    # small cumulus: clusters at mid height and filler around wisps
    "Cloud_Puff": dict(length=70, depth=58, height=40, seed=79, voxel=1.0, tris=700,
                       rows=[(8, (0.22, 0.30), 0.85, 0.06), (3, (0.28, 0.36), 0.35, 0.48)]),
    # wisp arc: a low band of billows bent around a circle of radius 1x its arc radius; wraps a pillar foot
    "Cloud_WispArc": dict(length=1, depth=46, height=30, seed=97, voxel=1.6, tris=1400, arc=(130, 150),
                          rows=[(22, (0.30, 0.46), 0.85, 0.06), (11, (0.34, 0.50), 0.25, 0.34)]),
}


# CloudRamp.png bands (bottom = shaded underside .. top = lit crown), sRGB 0-255, with the V where
# each band starts; edges blend over RAMP_SOFT so the steps read painted, not banded-CG
RAMP = [(0.00, (168, 177, 204)), (0.24, (206, 212, 229)), (0.44, (234, 237, 244)), (0.64, (255, 253, 248))]
RAMP_SOFT = 0.035
RAMP_PX = 256

CIRCLE_CENTRES = {}   # arc shapes: circle centre in mesh coordinates (filled by build)


def use_scene():
    if bpy.app.background:
        return bpy.context.scene
    return bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)


def clear(scn, names):
    for n in names:
        o = bpy.data.objects.get(n)
        if o:
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if me and me.users == 0 and isinstance(me, bpy.types.Mesh):
                bpy.data.meshes.remove(me)


def billows(spec):
    """Billow centres and radii (studs), footprint centred on the origin."""
    rng = random.Random(spec["seed"])
    L, D, H = spec["length"], spec["depth"], spec["height"]
    arc = spec.get("arc")
    out = []
    for count, (rlo, rhi), ring, lift in spec["rows"]:
        for i in range(count):
            r = D * rng.uniform(rlo, rhi)
            if rng.random() < HERO_CHANCE:      # a few oversized heads break the even rhythm
                r *= HERO_SCALE
            if arc:
                R, deg = arc
                t = (i + rng.uniform(-0.3, 0.3)) / max(count - 1, 1) - 0.5    # -0.5..0.5 along the arc
                a = math.radians(deg) * t
                off = D * 0.5 * ring * rng.uniform(-1, 1)
                taper = 1.0 - 0.35 * abs(t * 2) ** 2                           # thin ends
                r *= taper
                x, y = math.sin(a) * (R + off), math.cos(a) * (R + off) - R
            else:
                a = (i + rng.uniform(-0.35, 0.35)) / count * math.tau
                s = ring * rng.uniform(0.82, 1.0)
                x = math.cos(a) * (L * 0.5 - r * 0.8) * s
                y = math.sin(a) * (D * 0.5 - r * 0.8) * s
                taper = 1.0
            z = H * lift * rng.uniform(0.85, 1.15) * taper + r * 0.15
            out.append((Vector((x, y, z)), r))
    return out


def evaluated_bmesh(scn, obj):
    """The object's mesh with its modifiers applied. A scene that isn't shown in a window has no
    depsgraph of its own, so evaluate under a temporary context override of this scene."""
    assert bpy.app.background, "run headless: blender -b --factory-startup --python build_clouds.py"
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    ev = obj.evaluated_get(dg)
    out = bmesh.new()
    out.from_mesh(ev.to_mesh())
    ev.to_mesh_clear()
    return out


def union_mesh(scn, name, spec):
    """Join the billow spheres, voxel-remesh them into one shell, return the evaluated mesh as bmesh."""
    b = bmesh.new()
    for c, r in billows(spec):
        m = bmesh.ops.create_icosphere(b, subdivisions=BILLOW_SUBDIV, radius=r)
        bmesh.ops.translate(b, vec=c, verts=m["verts"])
    me = bpy.data.meshes.new(name + "_U")
    b.to_mesh(me)
    b.free()
    tmp = bpy.data.objects.new(name + "_U", me)
    scn.collection.objects.link(tmp)
    mod = tmp.modifiers.new("Remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = spec["voxel"]
    mod.adaptivity = 0.0
    out = evaluated_bmesh(scn, tmp)
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.meshes.remove(me)
    return out


def cut_bottom(b):
    """Cut flat at z = 0 and cap the hole (stylized clouds sit on a flat base)."""
    geom = b.verts[:] + b.edges[:] + b.faces[:]
    res = bmesh.ops.bisect_plane(b, geom=geom, plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
    cut_edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    bmesh.ops.holes_fill(b, edges=cut_edges, sides=0)
    loose = [v for v in b.verts if not v.link_faces]
    bmesh.ops.delete(b, geom=loose, context="VERTS")
    bmesh.ops.triangulate(b, faces=b.faces[:])


def decimate(scn, name, b, tris):
    me = bpy.data.meshes.new(name + "_D")
    b.to_mesh(me)
    b.free()
    tmp = bpy.data.objects.new(name + "_D", me)
    scn.collection.objects.link(tmp)
    mod = tmp.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = min(1.0, tris / max(len(me.polygons), 1))
    mod.use_collapse_triangulate = True
    out = evaluated_bmesh(scn, tmp)
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.meshes.remove(me)
    bmesh.ops.triangulate(out, faces=out.faces[:])
    return out


def ramp_uv(b):
    """V = lit amount from the smoothed vertex normal and height; U fixed mid-texture."""
    b.normal_update()
    zmax = max((v.co.z for v in b.verts), default=1.0) or 1.0
    uv = b.loops.layers.uv.verify()
    for f in b.faces:
        f.smooth = True
        for lp in f.loops:
            v = lp.vert
            nz = v.normal.z
            s = RAMP_NZ * (0.5 + 0.5 * nz) + (1 - RAMP_NZ) * (v.co.z / zmax)
            # flat bottom cap: force fully shaded so the underside reads as the darkest band
            if v.co.z < 0.05 and nz < -0.9:
                s = 0.0
            lp[uv].uv = (0.5, max(0.0, min(1.0, s)))


def build(scn, name, spec):
    b = union_mesh(scn, name, spec)
    cut_bottom(b)
    b = decimate(scn, name, b, spec["tris"])
    # recentre: origin at the bottom centre of the footprint
    lo = Vector((min(v.co.x for v in b.verts), min(v.co.y for v in b.verts), 0))
    hi = Vector((max(v.co.x for v in b.verts), max(v.co.y for v in b.verts), 0))
    mid = (lo + hi) * 0.5
    bmesh.ops.translate(b, vec=-mid, verts=b.verts)
    if spec.get("arc"):
        CIRCLE_CENTRES[name] = [round(-mid.x, 3), round(-spec["arc"][0] - mid.y, 3), 0.0]
    ramp_uv(b)
    me = bpy.data.meshes.new(name)
    b.to_mesh(me)
    b.free()
    o = bpy.data.objects.new(name, me)
    scn.collection.objects.link(o)
    return o


def ramp_colour(v):
    def srgb_to_lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    col = RAMP[0][1]
    for start, c in RAMP[1:]:
        t = max(0.0, min(1.0, (v - (start - RAMP_SOFT)) / (2 * RAMP_SOFT)))
        t = t * t * (3 - 2 * t)
        col = tuple(a + (b - a) * t for a, b in zip(col, c))
    return [srgb_to_lin(c) for c in col]


def write_ramp():
    """CloudRamp.png: 8 x RAMP_PX vertical gradient, row 0 (bottom in Blender) = V 0."""
    img = bpy.data.images.new("CloudRamp", 8, RAMP_PX, alpha=False)
    px = []
    for y in range(RAMP_PX):
        r, g, b = ramp_colour((y + 0.5) / RAMP_PX)
        px += [r, g, b, 1.0] * 8
    img.pixels = px
    img.filepath_raw = os.path.join(OUT_DIR, "CloudRamp.png")
    img.file_format = "PNG"
    img.save()
    return img


def ramp_material(img, objs):
    """One shared material with the ramp as base colour; the FBX embeds it so Roblox's importer
    uploads the texture along with the meshes (no separate image upload)."""
    mat = bpy.data.materials.get("CloudRamp") or bpy.data.materials.new("CloudRamp")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None) or nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs[0], bsdf.inputs[0])
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
    return mat


def bounds(o):
    xs = [v.co.x for v in o.data.vertices]
    ys = [v.co.y for v in o.data.vertices]
    zs = [v.co.z for v in o.data.vertices]
    c = [(max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, (max(zs) + min(zs)) / 2]
    s = [max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)]
    return [round(x, 3) for x in c], [round(x, 3) for x in s]


def export(scn, objs):
    """FBX export needs a context scene; run it under a temporary override of this scene only."""
    if True:
        for o in scn.objects:
            o.select_set(False)
        for o in objs:
            o.select_set(True)
        bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, NAME + ".fbx"), use_selection=True,
                                 object_types={"MESH"}, apply_unit_scale=True,
                                 apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y",
                                 mesh_smooth_type="FACE", bake_space_transform=True,
                                 path_mode="COPY", embed_textures=True)
    report = {"origin": "bottom centre of each cloud; Blender X length, Y depth, Z up", "meshes": {}}
    for o in objs:
        centre, size = bounds(o)
        report["meshes"][o.name] = dict(tris=len(o.data.polygons), center=centre, size=size)
        if o.name in CIRCLE_CENTRES:
            report["meshes"][o.name]["circle_centre"] = CIRCLE_CENTRES[o.name]
            report["meshes"][o.name]["circle_radius"] = SHAPES[o.name]["arc"][0]
    with open(os.path.join(OUT_DIR, NAME + ".json"), "w") as fh:
        json.dump(report, fh, indent=1)
    bpy.data.libraries.write(os.path.join(OUT_DIR, NAME + ".blend"), set(objs), fake_user=True)
    return report


def preview(scn):
    """Workbench render of the spread-out shapes, lit from above, for a quick look."""
    for o in list(scn.objects):
        if o.type == "MESH" and o.name not in SHAPES:
            bpy.data.objects.remove(o, do_unlink=True)
    x = 0.0
    for name in SHAPES:
        o = bpy.data.objects[name]
        w = o.dimensions.x
        o.location = (x + w / 2, 0, 0)
        x += w + 60
    cam_data = bpy.data.cameras.new("PrevCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = x * 1.02
    cam_data.clip_end = 20000
    cam = bpy.data.objects.new("PrevCam", cam_data)
    scn.collection.objects.link(cam)
    cam.location = (x / 2, -3000, 3000 * math.tan(math.radians(20)) + 90)
    cam.rotation_euler = (math.radians(70), 0, 0)
    scn.camera = cam
    try:
        scn.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    scn.display.shading.light = "STUDIO"
    scn.display.shading.color_type = "TEXTURE"
    scn.render.resolution_x, scn.render.resolution_y = 2400, 500
    scn.render.filepath = os.path.join(OUT_DIR, "preview.png")
    bpy.ops.render.render(write_still=True)


def main(do_export=True):
    scn = use_scene()
    clear(scn, list(SHAPES))
    objs = []
    for i, (name, spec) in enumerate(SHAPES.items()):
        o = build(scn, name, spec)
        o.location = (i % 4 * 900, i // 4 * 600, 0)     # spread out for previews only; export ignores it
        objs.append(o)
    ramp_material(write_ramp(), objs)
    if not do_export:
        return {o.name: len(o.data.polygons) for o in objs}
    for o in objs:
        o.location = (0, 0, 0)
    return export(scn, objs)


if __name__ == "__main__":
    import sys
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "preview" in argv:
        print(main(do_export=False))
        preview(use_scene())
    else:
        print(main())
