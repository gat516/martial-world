"""Turns Codex's painted NPC portraits into flat gray silhouettes.

The user rejected the painted portraits (2026-10-22): NPCs show as a gray
silhouette of their figure in the Portrait frame, never the painting.

For each art/ui/codex/a4/<name>.png (a navy square on magenta):
  1. crops the navy square out of the magenta,
  2. masks the figure with rembg (isnet-general-use; the first run downloads
     a 179 MB model to ~/.rembg),
  3. fills holes in the mask (robes run off the bottom, counted as inside),
     keeps the largest shape, and below 60% height fills each row between its
     outer edges and never narrows it (shoulders only widen going down),
  4. writes the shape in flat gray on transparency, soft hair strands kept, as
     art/ui/codex/cut/portrait_<name>.png (the Portrait frame supplies the
     backdrop).

Run: uv run --with rembg --with onnxruntime --with pillow --with numpy --with scipy \
       python tools/ui_silhouette.py [names...]
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from rembg import new_session, remove
from scipy import ndimage

SRC = Path(__file__).resolve().parent.parent / "art/ui/codex"
GRAY = (118, 122, 132)
MAX_SIZE = 1024  # Roblox's image cap


def crop_square(im):
    a = np.array(im).astype(int)
    magenta = (a[..., 0] > 180) & (a[..., 2] > 180) & (a[..., 1] < 80)
    ys, xs = np.where(~magenta)
    return im.crop((xs.min() + 4, ys.min() + 4, xs.max() - 3, ys.max() - 3))


def solid_mask(m):
    h, w = m.shape
    solid = m > 0.35
    padded = np.pad(solid, ((0, 2), (0, 0)), constant_values=True)
    solid = ndimage.binary_fill_holes(padded)[:h]
    labels, _ = ndimage.label(solid)
    solid = labels == np.bincount(labels.ravel())[1:].argmax() + 1
    for y in range(int(h * 0.6), h):
        xs = np.where(solid[y])[0]
        if len(xs):
            a, b = xs.min(), xs.max()
            if a < w * 0.12:
                a = 0
            if b > w * 0.88:
                b = w - 1
            solid[y, a:b + 1] = True
        solid[y] |= solid[y - 1]
    return solid


def silhouette(session, path):
    square = crop_square(Image.open(path).convert("RGB"))
    m = np.array(remove(square, session=session, only_mask=True).convert("L")).astype(float) / 255
    alpha = np.maximum(solid_mask(m).astype(float), np.where(m > 0.08, m, 0))
    alpha = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    out = Image.new("RGBA", alpha.size, GRAY + (0,))
    out.putalpha(alpha)
    if max(out.size) > MAX_SIZE:
        out.thumbnail((MAX_SIZE, MAX_SIZE), Image.LANCZOS)
    return out


def main():
    only = set(sys.argv[1:])
    session = new_session("isnet-general-use")
    for path in sorted((SRC / "a4").glob("*.png")):
        if only and path.stem not in only:
            continue
        out = SRC / "cut" / f"portrait_{path.stem}.png"
        im = silhouette(session, path)
        im.save(out)
        print(f"ok   {out.relative_to(SRC.parent.parent.parent)}: {im.width} x {im.height}")


if __name__ == "__main__":
    main()
