"""Lay accessory variants out side by side, one R6 body each, in a "Lineup" scene.

Run inside Blender (the MCP or tools/blender_live.sh run <name> tools/blender_lineup.py)
with the global LOOKS: a list of rows, each row a list of looks, each look a list of
set collection names worn together, e.g.
    LOOKS = [[["FoxEarsSleek", "FoxTailPlume"], ["FoxEarsBroad", "FoxTailCrescent"]],
             [["WolfEarsSentinel", "WolfTailBrush"]]]
Optional globals: SPACING (studs between bodies, default 6), BODY (the body collection,
default "R6Reference"), SCENE ("Lineup"). The sets aren't moved or copied: each body is a
collection instance, so rebuilding a set updates the lineup. Bones are hidden in the view.
"""
import bpy

LOOKS = globals().get("LOOKS")
assert LOOKS, "set LOOKS: rows of looks, each a list of set collection names"
SPACING = float(globals().get("SPACING", 6.0))
BODY = globals().get("BODY", "R6Reference")
SCENE = globals().get("SCENE", "Lineup")

old = bpy.data.scenes.get(SCENE)
if old:
    bpy.data.scenes.remove(old)
scene = bpy.data.scenes.new(SCENE)
cols = bpy.data.collections


def instance(name, loc, label):
    empty = bpy.data.objects.new(label, None)
    empty.instance_type = "COLLECTION"
    empty.instance_collection = cols[name]
    empty.location = loc
    scene.collection.objects.link(empty)


for r, row in enumerate(LOOKS):
    width = (len(row) - 1) * SPACING
    for c, look in enumerate(row):
        loc = (c * SPACING - width / 2, r * SPACING * 1.2, 0.0)
        instance(BODY, loc, f"Body_{r}_{c}")
        for name in look:
            instance(name, loc, f"I_{name}")
        text = bpy.data.curves.new(f"Label_{r}_{c}", "FONT")
        text.body = " + ".join(look)
        text.size = 0.3
        text.align_x = "CENTER"
        label = bpy.data.objects.new(f"Label_{r}_{c}", text)
        label.location = (loc[0], loc[1] - 1.6, 0.02)
        scene.collection.objects.link(label)

if bpy.context.window:
    bpy.context.window.scene = scene
    for area in bpy.context.window.screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.overlay.show_bones = False
            region = next(rg for rg in area.regions if rg.type == "WINDOW")
            with bpy.context.temp_override(area=area, region=region):
                bpy.ops.view3d.view_all()
print(f"lineup: {sum(len(r) for r in LOOKS)} bodies in scene {SCENE}")
