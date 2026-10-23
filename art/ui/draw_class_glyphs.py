"""Weapon class glyphs: white, square, tinted in game (SlotArt.classGlyph).

Sword, Saber, Spear, Staff and Fist are the Figma kit's white cuts
(codex/cut/ornament_weapon_*.png), only padded to a square canvas so a square
ImageLabel doesn't stretch them. The kit has no greatsword or guandao glyph yet:
until Codex draws them (docs/ui/codex-sheets.md, "Class glyphs"), those two are
the white silhouettes of their drawn item icons (icons/icon_IronGreatsword.png,
icons/icon_IronGuandao.png). Nothing is redrawn.

Run: uv run --with pillow python art/ui/draw_class_glyphs.py
Writes art/ui/glyphs/class_<Class>.png (256 px).
"""

from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
OUT = HERE / "glyphs"
SIZE = 256
MARGIN = 0.06  # share of the canvas left clear on each side

KIT = {
    "Sword": "codex/cut/ornament_weapon_sword.png",
    "Saber": "codex/cut/ornament_weapon_saber.png",
    "Spear": "codex/cut/ornament_weapon_spear.png",
    "Staff": "codex/cut/ornament_weapon_staff.png",
    "Fist": "codex/cut/ornament_weapon_fist.png",
}
SILHOUETTE = {
    "Greatsword": "icons/icon_IronGreatsword.png",
    "Guandao": "icons/icon_IronGuandao.png",
}


def square(im: Image.Image) -> Image.Image:
    im = im.crop(im.getbbox())
    room = int(SIZE * (1 - 2 * MARGIN))
    scale = room / max(im.size)
    im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    canvas.alpha_composite(im, ((SIZE - im.width) // 2, (SIZE - im.height) // 2))
    return canvas


def white(im: Image.Image) -> Image.Image:
    alpha = im.getchannel("A")
    out = Image.new("RGBA", im.size, (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def main():
    OUT.mkdir(exist_ok=True)
    for name, path in KIT.items():
        square(Image.open(HERE / path).convert("RGBA")).save(OUT / f"class_{name}.png")
    for name, path in SILHOUETTE.items():
        im = Image.open(HERE / path).convert("RGBA")
        im = im.resize((im.width * 4, im.height * 4), Image.LANCZOS)
        square(white(im)).save(OUT / f"class_{name}.png")
    print("wrote", sorted(p.name for p in OUT.glob("class_*.png")))


if __name__ == "__main__":
    main()
