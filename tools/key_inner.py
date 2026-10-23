"""Key a frame cut's flat middle to transparent, leaving only its rim.

Used for ornament_item_slot_selected_ring.png (the hotbar's held-slot Halo,
drawn over the slot frame): flood-fills from the centre through pixels near the
centre colour and ramps their alpha by distance from it, so the inner edge stays
soft. Keying only; the ornament itself is untouched.

    uv run --with pillow --with numpy python tools/key_inner.py in.png out.png
"""
import sys
from collections import deque
import numpy as np
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGBA")
a = np.asarray(im).astype(np.float64)
h, w = a.shape[:2]
ref = a[h//2, w//2, :3]
dist = np.sqrt(((a[..., :3] - ref) ** 2).sum(axis=2))
seen = np.zeros((h, w), bool)
q = deque([(h//2, w//2)]); seen[h//2, w//2] = True
while q:
    y, x = q.popleft()
    for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
        ny, nx = y+dy, x+dx
        if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] and dist[ny, nx] < 70:
            seen[ny, nx] = True; q.append((ny, nx))
# soften: within the region, alpha ramps with distance from the flat interior colour
ramp = np.clip((dist - 25) / 45, 0, 1)
alpha = a[..., 3] / 255
alpha = np.where(seen, alpha * ramp, alpha)
out = a.copy(); out[..., 3] = alpha * 255
Image.fromarray(out.round().astype(np.uint8), "RGBA").save(sys.argv[2])
print("keyed", seen.sum(), "of", h*w)
