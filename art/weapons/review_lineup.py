"""Lays out the "Review" scene's lineup and renders it: every weapon and item standing upright on
the R6's floor (z -2) in a row beside the rig, so the set can be judged together.

Run inside Blender after the build scripts (each copies itself into Review/ReviewModels as
Review_<MeshName>, sharing mesh data): exec(compile(open(p).read(), p, "exec"), {"__file__": p,
"__name__": "__main__"}). The jian and Spirit Stone keep their slots on the rig's right-hand side
(-X); the rest run from the rig's left (+X) outward, longest polearms first.
Renders art/weapons/preview/lineup.png and leaves the Review scene active, framed in material shading.
"""
import importlib
import os
import sys

import bpy
from mathutils import Matrix

OUT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else ""
sys.path.insert(0, os.path.join(OUT_DIR, "..", "rig"))
import rig_preview as rp  # noqa: E402
importlib.reload(rp)

GAP = 0.6                 # studs between neighbours
RIG_EDGE = 2.0            # the R6 spans x -2..2
LEFT = [("Jian", -3.2), ("SpiritStone", -4.2)]    # (mesh prefix, x of the pivot)
RIGHT = ["Staff", "Guandao", "Dadao", "Greatsword", "Zither", "Dizi"]


def group(prefix):
    col = bpy.data.collections[rp.REVIEW_COLLECTION]
    return [o for o in col.objects if o.name.startswith("Review_" + prefix)]   # SpiritStone also takes its Core


def main():
    scn = bpy.data.scenes[rp.REVIEW_SCENE]
    bpy.context.window.scene = scn
    groups = {p: group(p) for p in [n for n, _ in LEFT] + RIGHT}
    rp.pose_arm_forward(0)
    for prefix, x in LEFT:
        objs = groups[prefix]
        if objs:
            rp.place(objs, rp.stand_matrix(objs, x))
    cursor = RIG_EDGE + GAP
    for prefix in RIGHT:
        objs = groups[prefix]
        if not objs:
            print("missing in Review:", prefix)
            continue
        rp.place(objs, Matrix.Identity(4))
        c, s = rp.bounds(objs)
        x = cursor + s[0] / 2 - c[0]          # left edge of the item at the cursor
        rp.place(objs, rp.stand_matrix(objs, x))
        cursor += s[0] + GAP
    allobjs = [o for o in bpy.data.collections[rp.REVIEW_COLLECTION].objects]
    c, s = rp.bounds(allobjs + [o for o in rp.rig_objects() if o.type == "MESH"])
    rp.setup_render(scn, res=(1800, 900))
    width = s[0] + 1.2
    shot = rp.render(scn, os.path.join(OUT_DIR, "preview", "lineup.png"), (c[0], -40, c[2]), (c[0], 0, c[2]),
                     ortho=max(width, (s[2] + 1.0) * 2))
    shot34 = rp.render(scn, os.path.join(OUT_DIR, "preview", "lineup_three_quarter.png"),
                       (c[0] + 9, -26, c[2] + 6), (c[0], 0, c[2] - 0.5), lens=50)
    frame_viewport(scn, allobjs)
    print(shot, shot34, "x range", round(c[0] - s[0] / 2, 2), round(c[0] + s[0] / 2, 2))


def frame_viewport(scn, objs):
    for win in bpy.context.window_manager.windows:
        if win.scene != scn:
            continue
        for area in win.screen.areas:
            if area.type != "VIEW_3D":
                continue
            space = area.spaces.active
            space.shading.type = "MATERIAL"
            region = next(r for r in area.regions if r.type == "WINDOW")
            for o in bpy.context.view_layer.objects:
                o.select_set(False)
            for o in objs + [o for o in rp.rig_objects() if o.type == "MESH"]:
                if o.name in bpy.context.view_layer.objects:
                    o.select_set(True)
            with bpy.context.temp_override(window=win, area=area, region=region):
                bpy.ops.view3d.view_axis(type="FRONT")
                bpy.ops.view3d.view_selected()
            for o in bpy.context.view_layer.objects:
                o.select_set(False)


if __name__ == "__main__":
    main()
