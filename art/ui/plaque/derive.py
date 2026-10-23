"""Cut the house title plaques into three-part ribbons (cap, plain middle, cap).

Sources are the plaques drawn to the HUD vitals reference
(docs/reference/ui/hud_vitals_reference.webp): `name_plaque.png` (ruby diamond studs)
and `realm_plaque.png` (gold diamond studs). Both have pointed, bevelled ends and a
dark lacquer middle. Nothing is repainted: each cap is a crop of the plaque's own end,
the right cap is the plaque's own right end, and the middle is a 32 px strip of its
plain band.

Caps come in two lengths:
  *_capL / *_capR        stud and bevelled point only (the plate's end plus its stud)
  *_capL_curl / _capR... the stud, its scroll curl and the short line between them

Run: uv run --with pillow python art/ui/plaque/derive.py, then
uv run --with pillow --with numpy python tools/alpha_bleed.py art/ui/plaque/*.png
"""

from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
UI = HERE.parent

# name: (source, plate end x (first plain column), short cap start x, curl cap start x)
PLAQUES = {
    "plaque_ruby": ("name_plaque.png", 297, 235, 174),
    "plaque_gold": ("realm_plaque.png", 376, 306, 222),
}


def main() -> None:
    for name, (src, plain, short, curl) in PLAQUES.items():
        img = Image.open(UI / src).convert("RGBA")
        w, h = img.size
        mirror = w - plain  # first column of the right cap
        img.crop((short, 0, plain, h)).save(HERE / f"{name}_capL.png")
        img.crop((mirror, 0, w - short, h)).save(HERE / f"{name}_capR.png")
        img.crop((curl, 0, plain, h)).save(HERE / f"{name}_capL_curl.png")
        img.crop((mirror, 0, w - curl, h)).save(HERE / f"{name}_capR_curl.png")
        mid = w // 2 - 16
        img.crop((mid, 0, mid + 32, h)).save(HERE / f"{name}_mid.png")
        print(name, "cap", plain - short, "curl", plain - curl, "x", h)


if __name__ == "__main__":
    main()
