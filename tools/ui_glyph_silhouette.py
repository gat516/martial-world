"""Turns a cut kit ornament into a white glyph: its own alpha, filled white, so it
can be tinted in game like the other glyphs (Glyphs are white and tinted in game).
Not a repaint: the outline is the ornament's own, only the colour goes.

Run: uv run --with pillow --with numpy python tools/ui_glyph_silhouette.py <cut name> <out name>
  e.g. ornament_shield_kite shelter_shield
     -> art/ui/codex/cut/ornament_shield_kite.png -> art/ui/glyphs/shelter_shield.png
Used for the realm-pressure marks (docs/systems/combat.md "Realm pressure").
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / "art" / "ui"


def main():
    src, out = sys.argv[1], sys.argv[2]
    a = np.array(Image.open(ROOT / "codex" / "cut" / f"{src}.png").convert("RGBA"))
    g = np.zeros_like(a)
    g[..., :3] = 255
    g[..., 3] = a[..., 3]
    path = ROOT / "glyphs" / f"{out}.png"
    Image.fromarray(g).save(path)
    print(path, a.shape[1], "x", a.shape[0])


if __name__ == "__main__":
    main()
