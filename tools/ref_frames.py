# Contact sheet of frames from a reference video (a YouTube URL or a local file),
# so an agent can study an effect beat by beat. Needs uv:
#   ~/.local/bin/uv run -q --with yt-dlp --with av --with imageio --with pillow \
#     --with numpy python -I tools/ref_frames.py SRC OUT.png [frames=16] [start-end]
# start-end (seconds, e.g. 1.5-3) zooms on one beat. Downloads go to OUT's folder.
import os, subprocess, sys

import imageio.v3 as iio
import numpy as np
from PIL import Image, ImageDraw

src, out = sys.argv[1], sys.argv[2]
count = int(sys.argv[3]) if len(sys.argv) > 3 else 16
window = sys.argv[4] if len(sys.argv) > 4 else None

if src.startswith("http"):
	folder = os.path.dirname(os.path.abspath(out))
	template = os.path.join(folder, "%(id)s.%(ext)s")
	subprocess.run([sys.executable, "-m", "yt_dlp", "-q", "-f", "bv*[height<=720]/b", "-o", template, src], check=True)
	name = subprocess.run([sys.executable, "-m", "yt_dlp", "--print", "id", src], capture_output=True, text=True).stdout.strip()
	src = next(os.path.join(folder, f) for f in os.listdir(folder) if f.startswith(name + ".") and f.rsplit(".", 1)[1] in ("mp4", "webm", "mkv"))

meta = iio.immeta(src, plugin="pyav")
fps = meta.get("fps") or 30
frames = list(iio.imiter(src, plugin="pyav"))
lo, hi = 0, len(frames) - 1
if window:
	a, b = (float(x) for x in window.split("-"))
	lo, hi = max(0, int(a * fps)), min(hi, int(b * fps))
picks = np.linspace(lo, hi, count).astype(int)

width = 360
tiles = []
for i in picks:
	im = Image.fromarray(frames[i]).convert("RGB")
	im = im.resize((width, int(im.height * width / im.width)))
	ImageDraw.Draw(im).text((6, 4), f"{i / fps:.2f}s", fill=(255, 255, 0))
	tiles.append(im)
cols = 4
rows = (len(tiles) + cols - 1) // cols
height = tiles[0].height
sheet = Image.new("RGB", (cols * width, rows * height))
for k, im in enumerate(tiles):
	sheet.paste(im, ((k % cols) * width, (k // cols) * height))
sheet.save(out)
print(f"{len(frames)} frames at {fps:.0f} fps; sheet {sheet.size} -> {out}")
