"""Cut the vitals HUD art out of a Figma export of the kit's export sheet.

The Figma MCP's download_assets flattens a frame onto the canvas colour
(#F5F5F5), so export the sheet `Export / Roblox HUD (vitals)` (node 29:156, on
the Example page) twice at scale 2: once as it is (no fill) and once with the
sheet's fill set to black. This recovers the alpha from the difference
(light = a*F + (1-a)*245, dark = a*F), then crops each piece at the sheet's 1x
positions and writes them to art/ui/figma/.

    uv run --with pillow --with numpy python tools/figma_hud_export.py light.png dark.png
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

CANVAS = 245.0
OUT = Path(__file__).resolve().parent.parent / "art/ui/figma"
# name: (x, y, w, h) in the sheet at 1x, and the output size (None = 2x)
PIECES = {
    "hud_vitals_plate": ((40, 20, 520, 65), (1024, 128)),
    "hud_vitals_rims": ((40, 110, 520, 65), (1024, 128)),
    "hud_seat_rims": ((40, 200, 520, 65), (1024, 128)),
    "hud_realm_plaque": ((40, 290, 357, 26), None),
    "hud_round_seal": ((40, 340, 64, 64), None),
}


def matte(light_path: str, dark_path: str) -> Image.Image:
    light = np.asarray(Image.open(light_path).convert("RGB")).astype(np.float64)
    dark = np.asarray(Image.open(dark_path).convert("RGB")).astype(np.float64)
    a = np.clip(1.0 - (light - dark).mean(axis=2) / CANVAS, 0, 1)
    a[a < 2 / 255] = 0
    rgb = np.where(a[..., None] > 0, dark / np.maximum(a[..., None], 1e-6), 0)
    out = np.dstack([np.clip(rgb, 0, 255), a * 255]).round().astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def main() -> None:
    sheet = matte(sys.argv[1], sys.argv[2])
    OUT.mkdir(parents=True, exist_ok=True)
    for name, ((x, y, w, h), size) in PIECES.items():
        piece = sheet.crop((x * 2, y * 2, (x + w) * 2, (y + h) * 2))
        if size:
            piece = piece.resize(size, Image.LANCZOS)
        piece.save(OUT / f"{name}.png")
        print(name, piece.size)


if __name__ == "__main__":
    main()
