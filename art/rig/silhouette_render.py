"""Silhouette renders of a Blender model, for tools/fidelity_check.py: white on black,
orthographic, the same framing every time, so a prop or terrain piece can be scored against
its reference before the FBX export. Docs: docs/enemies/modeling-checks.md.

Views (the house convention: the model faces -Y, Z up; see rig_preview.py):
  front   from -Y, looking at the model's face
  side    from +X, the model's left: its front on screen left, like tools/model_shot.luau's side
  34      front-left and a little above, like model_shot's 34
Framing: an orthographic camera aimed at the bounding-box centre with ortho_scale = the
bounding sphere's diameter x MARGIN, so a model fills the same share of the frame from every
view and between runs.

Use from a build script (after the model exists), next to rig_preview:
    sys.path.insert(0, os.path.join(OUT_DIR, "..", "..", "rig"))
    import silhouette_render as sr
    sr.render_silhouettes(objs, os.path.join(OUT_DIR, "preview"), "Lantern")
or straight through the Blender MCP on the selected objects (writes to the system temp
folder's silhouettes/):
    p = r"\\\\wsl.localhost\\Ubuntu\\home\\cj\\roblox\\martial-world\\art\\rig\\silhouette_render.py"
    exec(compile(open(p).read(), p, "exec"), {"__file__": p, "__name__": "__main__"})
Writes <prefix>_sil_front.png, _sil_side.png and _sil_34.png and returns their paths. Renders
in a temporary scene, so the working scene, its camera and its world are left alone.
"""
import math
import os

import bpy
from mathutils import Vector

RES = 640
MARGIN = 1.08
VIEWS = {
    "front": Vector((0, -1, 0)),
    "side": Vector((1, 0, 0)),
    "34": Vector((1, -1, 0.7)).normalized(),
}


def _bounds(objs):
    pts = []
    deps = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        if o.type != "MESH":
            continue
        ev = o.evaluated_get(deps)
        pts += [ev.matrix_world @ Vector(c) for c in ev.bound_box]
    if not pts:
        raise ValueError("silhouette_render: no mesh objects given")
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def _workbench(scene):
    engines = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_WORKBENCH" if "BLENDER_WORKBENCH" in engines else engines[0]
    scene.render.resolution_x = scene.render.resolution_y = RES
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    sh = scene.display.shading
    sh.light = "FLAT"
    sh.color_type = "SINGLE"
    sh.single_color = (1.0, 1.0, 1.0)
    for attr in ("show_cavity", "show_shadows", "show_specular_highlight", "show_object_outline", "show_xray"):
        if hasattr(sh, attr):
            setattr(sh, attr, False)
    world = bpy.data.worlds.get("SilhouetteWorld") or bpy.data.worlds.new("SilhouetteWorld")
    world.color = (0.0, 0.0, 0.0)
    scene.world = world


def render_silhouettes(objs, out_dir, prefix, views=("front", "side", "34")):
    """Render each view of `objs` (mesh objects) to out_dir/<prefix>_sil_<view>.png."""
    objs = [o for o in objs if o.type == "MESH"]
    lo, hi = _bounds(objs)
    centre = (lo + hi) / 2
    radius = (hi - lo).length / 2
    window = bpy.context.window
    old_scene = window.scene
    scene = bpy.data.scenes.new("_Silhouette")
    paths = []
    try:
        for o in objs:
            scene.collection.objects.link(o)
        _workbench(scene)
        cam_data = bpy.data.cameras.new("_SilhouetteCam")
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = 2 * radius * MARGIN
        cam_data.clip_start, cam_data.clip_end = 0.01, radius * 8 + 10
        cam = bpy.data.objects.new("_SilhouetteCam", cam_data)
        scene.collection.objects.link(cam)
        scene.camera = cam
        window.scene = scene
        os.makedirs(out_dir, exist_ok=True)
        for name in views:
            d = VIEWS[name]
            cam.location = centre + d * (radius * 3 + 1)
            cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
            path = os.path.join(out_dir, "%s_sil_%s.png" % (prefix, name))
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True, scene=scene.name)
            paths.append(path)
    finally:
        window.scene = old_scene
        for o in list(scene.collection.objects):
            scene.collection.objects.unlink(o)
        cam = bpy.data.objects.get("_SilhouetteCam")
        if cam:
            bpy.data.objects.remove(cam, do_unlink=True)
        cd = bpy.data.cameras.get("_SilhouetteCam")
        if cd:
            bpy.data.cameras.remove(cd)
        bpy.data.scenes.remove(scene)
    return paths


if __name__ == "__main__":
    import tempfile
    sel = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    name = (bpy.context.active_object.name if bpy.context.active_object else "model").replace(" ", "_")
    print(render_silhouettes(sel, os.path.join(tempfile.gettempdir(), "silhouettes"), name))
