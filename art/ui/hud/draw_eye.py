# White eye glyph (hud_eye.png): almond lids, iris ring, pupil; 256 px, transparent.
# No Pillow needed:  python3 art/ui/hud/draw_eye.py art/ui/hud/hud_eye.png
import math, struct, sys, zlib
N, SS = 256, 4
W, H = 112, 60
d = (W * W - H * H) / (2 * H)
R = H + d
T, IR, IT, PR = 17, 38, 14, 17
def cover(x, y):
    sd = max(math.hypot(x, y - d) - R, math.hypot(x, y + d) - R)
    if abs(sd) <= T / 2:
        return True
    if sd < -T / 2:
        r = math.hypot(x, y)
        return r <= PR or abs(r - IR) <= IT / 2
    return False
rows = []
for j in range(N):
    row = bytearray([0])
    for i in range(N):
        n = 0
        for sj in range(SS):
            for si in range(SS):
                x = i + (si + 0.5) / SS - N / 2
                y = j + (sj + 0.5) / SS - N / 2
                n += cover(x, y)
        row += bytes([255, 255, 255, round(255 * n / SS / SS)])
    rows.append(bytes(row))
def chunk(t, b):
    return struct.pack(">I", len(b)) + t + b + struct.pack(">I", zlib.crc32(t + b) & 0xFFFFFFFF)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 6, 0, 0, 0)) \
    + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
