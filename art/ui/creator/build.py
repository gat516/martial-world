"""Character creator art, assembled from the kit's cut ornaments (art/ui/codex/cut).

No drawing: corners are mirrored, three-part buttons are joined cap + plain middle + cap,
so Roblox can 9-slice them, and pieces are downscaled to about 2x their on-screen size.
Run: uv run --with pillow python art/ui/creator/build.py

Outputs (art/ui/creator/out/), with the slice data the GUI uses:
  panel_corner_{tl,tr,bl,br}.png  panel corners, ScaleType Fit, never stretched
  portrait_corner_{tl,tr,bl,br}.png  preview frame corners
  plate.png / plate_hi.png  nav plate and primary button (response button parts).
      SliceCenter = the middle strip (see SLICE below), SliceScale ~0.25 for a 56 px plate.
  rule_cloud.png  section-header rule (divider_cloud), 3-slice: caps never stretch.
  crest.png  title crest for the panel header (full piece, shown at native aspect).
  window_corner_{tl,tr,bl,br}.png  the parchment panel's corners (heaviest frame)
  window_corner_small_{tl,tr,bl,br}.png  the nav column's corners
  seat_plate.png  name plinth under the preview, shown whole at its native aspect
  halo.png  dao_ring behind the preview character; seal.png  seal_square header chop
  flourish_{l,r}.png  name_scroll cloud flourish and its mirror, either side of the screen title
  ruby_stud.png, keyplate.png, divider_vertical.png, inkwash_a.png  as cut, downscaled
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
CUT = ROOT / "art/ui/codex/cut"
OUT = Path(__file__).resolve().parent / "out"


def load(name: str) -> Image.Image:
    return Image.open(CUT / f"ornament_{name}.png").convert("RGBA")


def fit(img: Image.Image, long_side: int) -> Image.Image:
    w, h = img.size
    s = long_side / max(w, h)
    if s >= 1:
        return img
    return img.resize((round(w * s), round(h * s)), Image.LANCZOS)


def corners(name: str, long_side: int):
    tl = fit(load(name), long_side)
    out = {
        "tl": tl,
        "tr": tl.transpose(Image.FLIP_LEFT_RIGHT),
        "bl": tl.transpose(Image.FLIP_TOP_BOTTOM),
        "br": tl.transpose(Image.ROTATE_180),
    }
    for key, img in out.items():
        img.save(OUT / f"{name}_{key}.png")


def three_part(prefix: str, out_name: str, mid_repeat: int = 2) -> None:
    cap_l, mid, cap_r = load(f"{prefix}_capL"), load(f"{prefix}_mid"), load(f"{prefix}_capR")
    h = max(cap_l.height, mid.height, cap_r.height)
    w = cap_l.width + mid.width * mid_repeat + cap_r.width
    img = Image.new("RGBA", (w, h))
    img.alpha_composite(cap_l, (0, 0))
    for i in range(mid_repeat):
        img.alpha_composite(mid, (cap_l.width + i * mid.width, 0))
    img.alpha_composite(cap_r, (cap_l.width + mid.width * mid_repeat, 0))
    img.save(OUT / f"{out_name}.png")
    print(out_name, img.size, "slice x", cap_l.width + 2, "to", cap_l.width + mid.width * mid_repeat - 2)


def main() -> None:
    OUT.mkdir(exist_ok=True)
    corners("panel_corner", 331)
    corners("portrait_corner", 238)
    three_part("response_button", "plate")
    three_part("response_button_hi", "plate_hi")
    fit(load("divider_cloud"), 1024).save(OUT / "rule_cloud.png")
    fit(load("title_crest"), 1024).save(OUT / "crest.png")
    corners("window_corner", 512)
    corners("window_corner_small", 400)
    fit(load("seat_plate"), 1024).save(OUT / "seat_plate.png")
    fit(load("dao_ring"), 512).save(OUT / "halo.png")
    fit(load("seal_square"), 256).save(OUT / "seal.png")
    fit(load("ruby_stud"), 128).save(OUT / "ruby_stud.png")
    fit(load("keyplate"), 160).save(OUT / "keyplate.png")
    fit(load("divider_vertical"), 768).save(OUT / "divider_vertical.png")
    fit(load("inkwash_a"), 1024).save(OUT / "inkwash_a.png")
    flourish = fit(load("name_scroll"), 401)
    flourish.save(OUT / "flourish_r.png")  # tail left, cloud right: sits right of a title
    flourish.transpose(Image.FLIP_LEFT_RIGHT).save(OUT / "flourish_l.png")


if __name__ == "__main__":
    main()
