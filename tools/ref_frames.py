# Contact sheet of frames from a reference video (a YouTube URL or a local file),
# so an agent can study an effect beat by beat. Needs uv:
#   ~/.local/bin/uv run -q --with yt-dlp --with av --with pillow --with numpy \
#     python -I tools/ref_frames.py SRC OUT.png [frames=16] [start-end]
# start-end (seconds, e.g. 1.5-3) zooms on one beat. Downloads (480p at most,
# videos up to MAX_MINUTES long) are cached in ~/.cache/ref_frames, not the repo.
# It seeks to each picked moment and decodes one frame at a time: decoding a
# whole video into memory ran WSL out of RAM and crashed it (2026-10-21).
import os, subprocess, sys

import av
import numpy as np
from PIL import Image, ImageDraw

MAX_MINUTES = 20
CACHE = os.path.expanduser("~/.cache/ref_frames")

src, out = sys.argv[1], sys.argv[2]
count = int(sys.argv[3]) if len(sys.argv) > 3 else 16
window = sys.argv[4] if len(sys.argv) > 4 else None

if src.startswith("http"):
	os.makedirs(CACHE, exist_ok=True)
	name = subprocess.run([sys.executable, "-m", "yt_dlp", "--print", "id", src], capture_output=True, text=True, check=True).stdout.strip()
	cached = [f for f in os.listdir(CACHE) if f.startswith(name + ".") and f.rsplit(".", 1)[1] in ("mp4", "webm", "mkv")]
	if not cached:
		subprocess.run([
			sys.executable, "-m", "yt_dlp", "-q", "-f", "bv*[height<=480]/b[height<=480]/wv*/w",
			"--match-filter", f"duration < {MAX_MINUTES * 60}", "-o", os.path.join(CACHE, "%(id)s.%(ext)s"), src,
		], check=True)
		cached = [f for f in os.listdir(CACHE) if f.startswith(name + ".") and f.rsplit(".", 1)[1] in ("mp4", "webm", "mkv")]
	if not cached:
		sys.exit(f"not downloaded (longer than {MAX_MINUTES} min?): {src}")
	src = os.path.join(CACHE, cached[0])

width = 360
tiles = []
with av.open(src) as container:
	stream = container.streams.video[0]
	fps = float(stream.average_rate or 30)
	if container.duration:
		duration = container.duration / av.time_base
	else:
		duration = float(stream.duration * stream.time_base)
	lo, hi = 0.0, max(0.0, duration - 0.1)
	if window:
		a, b = (float(x) for x in window.split("-"))
		lo, hi = max(lo, a), min(hi, b)
	for t in np.linspace(lo, hi, count):
		container.seek(int(t / stream.time_base), stream=stream)
		frame = None
		for f in container.decode(stream):
			frame = f
			if f.time is None or f.time >= t - 0.5 / fps:
				break
		if frame is None:
			continue
		im = frame.to_image().convert("RGB")
		im = im.resize((width, int(im.height * width / im.width)))
		ImageDraw.Draw(im).text((6, 4), f"{frame.time or t:.2f}s", fill=(255, 255, 0))
		tiles.append(im)

cols = 4
rows = (len(tiles) + cols - 1) // cols
height = tiles[0].height
sheet = Image.new("RGB", (cols * width, rows * height))
for k, im in enumerate(tiles):
	sheet.paste(im, ((k % cols) * width, (k // cols) * height))
sheet.save(out)
print(f"{duration:.1f}s at {fps:.0f} fps; {len(tiles)} tiles {sheet.size} -> {out}")
