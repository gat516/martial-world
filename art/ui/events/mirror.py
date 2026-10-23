"""Mirrored copies of kit cuts for the world-event, tribulation, rift and
leaderboard screens (docs/ui/world-events.md). Roblox can't flip an image, so
corner sets and the left-pointing direction chip are mirrored here. Mirroring
only; nothing is redrawn.

Run: uv run --with pillow python art/ui/events/mirror.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CUT = ROOT / "codex" / "cut"
OUT = Path(__file__).resolve().parent

H, V = Image.Transpose.FLIP_LEFT_RIGHT, Image.Transpose.FLIP_TOP_BOTTOM

# source piece -> {suffix: transposes}
JOBS = {
    "window_corner_small": {"tr": [H], "bl": [V], "br": [H, V]},
    "blood_panel_corner": {"tr": [H], "bl": [V], "br": [H, V]},
    "direction_chip": {"left": [H]},
}

for name, outs in JOBS.items():
    src = Image.open(CUT / f"ornament_{name}.png")
    for suffix, ops in outs.items():
        im = src
        for op in ops:
            im = im.transpose(op)
        im.save(OUT / f"{name}_{suffix}.png")
        print(f"{name}_{suffix}.png", im.size)
