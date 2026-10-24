r"""The three wolf looks side by side, one R6 body each (tools/blender_lineup.py), plus the sheet's
lineup renders (renders/lineup_<view>.png). Leaves the live window on the Lineup scene so the
user can orbit it; rebuilding a set with build_wolf.py updates the lineup (collection instances).

Run through the Blender MCP after build_wolf.py:
    P = r"\\wsl.localhost\Ubuntu\home\cj\roblox\martial-world-race-cosmetics\art\player\cosmetics\wolf\lineup.py"
    exec(compile(open(P).read(), P, "exec"), {"__file__": P})
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "art", "rig"))
import rig_preview as rp  # noqa: E402

LOOKS = [[["WolfEarsSentinel", "WolfTailBrush"], ["WolfEarsRuff", "WolfTailMane"],
          ["WolfEarsLance", "WolfTailBanner"]]]
SPACING = 6.0
RENDER = globals().get("RENDER", True)
# (name, eye direction, target, ortho scale)
SHOTS = [("lineup_back", (0.25, 1, 0.18), (0, 1.2, 0.8), 17.0),
         ("lineup_side", (1, 1.1, 0.15), (0, 1.2, 0.8), 15.0),
         ("lineup_front", (-0.25, -1, 0.15), (0, 1.0, 0.8), 17.0)]

LINEUP = os.path.join(REPO, "tools", "blender_lineup.py")
exec(compile(open(LINEUP).read(), LINEUP, "exec"), {"__file__": LINEUP, "LOOKS": LOOKS, "SPACING": SPACING})
scene = bpy.data.scenes["Lineup"]
if RENDER:
    from mathutils import Vector
    rp.setup_render(scene, res=(1280, 720))
    for name, d, tgt, ortho in SHOTS:
        eye = Vector(tgt) + Vector(d).normalized() * 30
        rp.render(scene, os.path.join(HERE, "renders", name + ".png"), tuple(eye), tgt, ortho=ortho)
    for o in [o for o in scene.collection.objects if o.name.startswith("Preview")]:
        scene.collection.objects.unlink(o)   # keep the lights and camera out of the user's view
print("lineup rendered" if RENDER else "lineup built")
