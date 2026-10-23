"""One review image from several screen captures: a labelled grid (default
3 columns, so six moments make a 2x3 sheet), for the critic step of the
maker-critic loop.

  uv run --with pillow python3 -I tools/vfx_sheet.py OUT.png [--title T] [--cols 3] [--width 640] \
      "windup 320ms=/path/a.jpg" "hit 450ms=/path/b.jpg" ...

Each item is "label=path" (or a bare path, labelled with its file name).

Where captures come from: Claude Code saves every Studio MCP `screen_capture`
to the session's tool-results folder and prints the path in the tool result
("[Image: source: ~/.claude/projects/<project>/<session>/tool-results/
mcp-Roblox_Studio-blob-<n>.jpg]"); pass those paths. The MCP itself can't
write a capture to disk (`store_image` goes the other way, a local file into
Studio). Every capture also lands in the capturing agent's context, so for a
technique prefer `vfxPreview.filmstrip` (tools/vfx_preview.luau): six frozen
moments in one capture, already one image. Use this sheet for enemy effects
(`enemy_fx_shot`, one capture per moment) or any set of captures.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

BG = (24, 26, 31)
INK = (255, 220, 120)
DIM = (170, 175, 185)


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "Arial Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 2
    out = args.pop(0)
    opts = {"--title": None, "--cols": "3", "--width": "640"}
    items = []
    while args:
        a = args.pop(0)
        if a in opts:
            opts[a] = args.pop(0)
        else:
            items.append(a)
    if not items:
        print("no captures given")
        return 2
    cols = int(opts["--cols"])
    width = int(opts["--width"])
    cells = []
    for item in items:
        label, _, path = item.rpartition("=") if "=" in item else ("", "", item)
        path = os.path.expanduser(path)
        if not os.path.exists(path):
            print(f"missing: {path}")
            return 1
        im = Image.open(path).convert("RGB")
        h = round(im.height * width / im.width)
        cells.append((label or os.path.basename(path), im.resize((width, h), Image.LANCZOS)))
    rows = (len(cells) + cols - 1) // cols
    bar = 34
    cell_h = max(im.height for _, im in cells) + bar
    title_h = 44 if opts["--title"] else 0
    pad = 6
    sheet = Image.new("RGB", (cols * width + (cols + 1) * pad, title_h + rows * cell_h + (rows + 1) * pad), BG)
    draw = ImageDraw.Draw(sheet)
    if opts["--title"]:
        draw.text((pad + 4, 8), opts["--title"], fill=INK, font=font(26))
    f = font(22)
    for i, (label, im) in enumerate(cells):
        c, r = i % cols, i // cols
        x = pad + c * (width + pad)
        y = title_h + pad + r * (cell_h + pad)
        draw.text((x + 6, y + 5), f"{i + 1}  {label}", fill=INK, font=f)
        sheet.paste(im, (x, y + bar))
    sheet.save(out)
    print(f"{out} {sheet.width}x{sheet.height} ({len(cells)} captures, {cols} cols)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
