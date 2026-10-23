"""Shorten the boss bar's trough so it ends left of the ruby socket.

The Figma sheet `Export / Roblox Boss Bar` (node 35:177) still has the first trough
(x 28..524 of the 560x104 box), whose last ~5% ran under the socket, so the first
hits on a boss didn't show. The fix (2026-10-23) was made after the plan's Figma MCP
calls ran out, so it is applied here to the matted 2x sheet instead: the trough, its
rim and its slanted cuts end at x 494 (bottom 470), and the plate's body colour
fills where the old trough was. These are the sheet's own vector shapes (flat
colours and 1 px lines), not generated ornaments. Once the sheet itself is updated
(Trough and Rim to 466 wide, cuts every 46.6), export it with figma_boss_export.py
and drop this step.

    uv run --with pillow --with numpy python -c "import sys; sys.path.insert(0, 'tools'); from figma_boss_export import matte; matte('light.png', 'dark.png').save('sheet2x.png')"
    uv run --with pillow --with numpy python tools/boss_trough_patch.py sheet2x.png art/ui/figma/boss
"""
import sys
import numpy as np
from PIL import Image, ImageDraw
S = sys.argv[1]; OUT = sys.argv[2]
sheet = np.asarray(Image.open(S)).astype(np.float64)
K = 2  # sheet scale
SS = 8
OLD = [(28, 40), (524, 40), (500, 64), (28, 64)]
TW = 466
NEW = [(28, 40), (28 + TW, 40), (28 + TW - 24, 64), (28, 64)]

def mask(poly, ox, oy, shape):
    h, w = shape
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).polygon([((ox + x) * K * SS, (oy + y) * K * SS) for x, y in poly], fill=255)
    return np.asarray(m.resize((w, h), Image.BOX)).astype(np.float64) / 255

def lines(segs, width, ox, oy, shape):
    h, w = shape
    m = Image.new("L", (w * SS, h * SS), 0)
    d = ImageDraw.Draw(m)
    for (x0, y0), (x1, y1) in segs:
        d.line([((ox + x0) * K * SS, (oy + y0) * K * SS), ((ox + x1) * K * SS, (oy + y1) * K * SS)], fill=255, width=int(width * K * SS))
    return np.asarray(m.resize((w, h), Image.BOX)).astype(np.float64) / 255

def inset(poly, t):
    (x0, y0), (x1, _), (x2, y2), _ = poly
    s = t * 2 ** 0.5  # a 45-degree edge moves sideways by t*sqrt(2)
    return [(x0 + t, y0 + t), (x1 - s + t, y0 + t), (x2 - s, y2 - t), (x0 + t, y2 - t)]

shape = sheet.shape[:2]
# --- plate (sheet 40,20): body colour where the old trough no longer is
ox, oy = 40, 20
old = mask(inset(OLD, -0.75), ox, oy, shape); new = mask(NEW, ox, oy, shape)
xs1 = np.arange(shape[1]) / K - ox
gone = np.clip(old - new, 0, 1) * (xs1 >= 400)[None, :]
col = sheet[:, int((ox + 25.5) * K)]  # body column, vertical gradient
body = np.repeat(col[:, None, :], shape[1], axis=1)
g = gone[..., None]
sheet = sheet * (1 - g) + body * g
# --- mount (sheet 40,150): clear the old rim and cuts right of the gold cap, left of the socket
ox, oy = 40, 150
xs = np.arange(shape[1]) / K - ox
band = ((xs >= 40) & (xs <= 496.5)).astype(np.float64)[None, :]
old_m = mask(inset(OLD, -0.6), ox, oy, shape) * band
a = sheet[..., 3] / 255 * (1 - old_m)
# new rim: 1px inside stroke
rim = np.clip(mask(NEW, ox, oy, shape) - mask(inset(NEW, 1), ox, oy, shape), 0, 1) * band
# new cuts every tenth, 45 degrees, 1.5px, near black at 0.55
cuts = lines([((28 + TW * i / 10 - 12, 64), (28 + TW * i / 10 + 12, 40)) for i in range(1, 10)], 1.5, ox, oy, shape)
def over(rgb, alpha, src_rgb, src_a):
    out_a = src_a + alpha * (1 - src_a)
    out = (src_rgb * src_a[..., None] + rgb * (alpha * (1 - src_a))[..., None]) / np.maximum(out_a, 1e-6)[..., None]
    return out, out_a
rgb = sheet[..., :3].copy()
rgb, a = over(rgb, a, np.array([5, 7, 10.0]), cuts * 0.55 * band)
rgb, a = over(rgb, a, np.array([0x97, 0x76, 0x3b], dtype=float), rim)
sheet[..., :3] = rgb
sheet[..., 3] = a * 255
img = Image.fromarray(np.clip(sheet, 0, 255).round().astype(np.uint8), "RGBA")
for name, (x, y, w, h) in {"bossbar_plate": (40, 20, 560, 104), "bossbar_mount": (40, 150, 560, 104)}.items():
    img.crop((x * K, y * K, (x + w) * K, (y + h) * K)).resize((1024, 190), Image.LANCZOS).save(f"{OUT}/{name}.png")
    print("wrote", name)
