"""Pixal3D image -> GLB, tuned for small game props on an 8 GB card.

Wraps Pixal3D's inference.py instead of forking it:
- background removal is lazy and uses the ungated ZhengPeng7/BiRefNet (only
  runs when the input has no transparency);
- low-VRAM mode at 1024 by default;
- the GLB's triangle budget and texture size are arguments, so output is
  already near game size instead of 1M tris / 4K.

Run through tools/pixal3d.sh (WSL) or D:\\pixal3d\\pixal3d.cmd (Windows); both go
through envrun.cmd, which sets up MSVC, CUDA and the Python env. Install:
tools/pixal3d/SETUP.md.
"""
import argparse
import os
import sys
import time

HOME = os.environ.get("PIXAL3D_HOME", r"D:\pixal3d")
sys.path.insert(0, os.path.join(HOME, "Pixal3D"))
os.environ.setdefault("ATTN_BACKEND", "sdpa")

try:
    import natten  # noqa: F401
except ImportError:
    # NAF needs natten.na2d; there's no Windows/Turing build, so use the
    # pure-PyTorch stand-in next to this file.
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "natten_shim"))

import inference  # noqa: E402  (sets Pixal3D's env defaults)
from pixal3d.pipelines import rembg  # noqa: E402
import o_voxel  # noqa: E402


class LazyBiRefNet:
    """Loads the background remover on first use, from an ungated repo."""

    def __init__(self, model_name=None):
        self.impl = None

    def _load(self):
        if self.impl is None:
            self.impl = rembg._BiRefNet("ZhengPeng7/BiRefNet")
        return self.impl

    def to(self, device):
        if self.impl is not None:
            self.impl.to(device)

    def cuda(self):
        self._load().cuda()

    def cpu(self):
        if self.impl is not None:
            self.impl.cpu()

    def __call__(self, image):
        return self._load()(image)


rembg._BiRefNet = rembg.BiRefNet
rembg.BiRefNet = LazyBiRefNet

# Low-VRAM mode parks every model in system RAM and moves one stage at a time
# to the GPU, so both have to be free before a run starts.
MIN_RAM_GB = 14.0
MIN_VRAM_GB = 5.0
LOCK = os.path.join(HOME, "gen.lock")


def preflight(min_ram_gb, min_vram_gb):
    import psutil
    import torch

    ok = True
    ram = psutil.virtual_memory()
    ram_free = ram.available / 2**30
    print(f"[preflight] RAM free {ram_free:.1f} / {ram.total / 2**30:.1f} GB (need {min_ram_gb})")
    if ram_free < min_ram_gb:
        ok = False
        hogs = sorted(psutil.process_iter(["name", "memory_info"]),
                      key=lambda p: p.info["memory_info"].rss if p.info["memory_info"] else 0, reverse=True)[:5]
        for p in hogs:
            print(f"[preflight]   {p.info['name']}: {p.info['memory_info'].rss / 2**30:.1f} GB")
    if not torch.cuda.is_available():
        print("[preflight] no CUDA device")
        return False
    vram_free, vram_total = (x / 2**30 for x in torch.cuda.mem_get_info())
    print(f"[preflight] VRAM free {vram_free:.1f} / {vram_total:.1f} GB (need {min_vram_gb})")
    if vram_free < min_vram_gb:
        ok = False
        print("[preflight]   close GPU-heavy apps (Studio, Blender viewport, games, browsers)")
    if os.path.exists(LOCK):
        print(f"[preflight] another generation is running (pid {open(LOCK).read().strip()}; delete {LOCK} if stale)")
        ok = False
    print(f"[preflight] {'OK' if ok else 'FAIL'}")
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--image")
    ap.add_argument("--output")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--tris", type=int, default=20000, help="decimation target (faces)")
    ap.add_argument("--texture", type=int, default=1024, help="baked texture size")
    ap.add_argument("--resolution", type=int, default=1024, choices=[1024, 1536])
    ap.add_argument("--fov", type=float, default=-1.0,
                    help="camera FOV in radians; -1 estimates it with MoGe (try 0.2 for flat product shots)")
    ap.add_argument("--high_vram", action="store_true", help="keep every model on the GPU (needs ~18 GB)")
    ap.add_argument("--min_ram_gb", type=float, default=MIN_RAM_GB)
    ap.add_argument("--min_vram_gb", type=float, default=MIN_VRAM_GB)
    ap.add_argument("--check", action="store_true", help="only run the preflight check")
    ap.add_argument("--force", action="store_true", help="run even if the preflight check fails")
    args = ap.parse_args()

    ok = preflight(args.min_ram_gb, args.min_vram_gb)
    if args.check:
        sys.exit(0 if ok else 2)
    if not args.image or not args.output:
        ap.error("--image and --output are required")
    if not ok and not args.force:
        print("[preflight] refusing to run; free memory or pass --force")
        sys.exit(2)
    with open(LOCK, "w") as f:
        f.write(str(os.getpid()))
    try:
        generate(args)
    finally:
        os.remove(LOCK)


def generate(args):

    real_to_glb = o_voxel.postprocess.to_glb

    def to_glb(**kw):
        kw["decimation_target"] = args.tris
        kw["texture_size"] = args.texture
        return real_to_glb(**kw)

    o_voxel.postprocess.to_glb = to_glb

    start = time.time()
    inference.run_inference(
        image_path=os.path.abspath(args.image),
        output_path=os.path.abspath(args.output),
        seed=args.seed,
        manual_fov=args.fov,
        low_vram=not args.high_vram,
        resolution=args.resolution,
    )
    print(f"[gen] {args.output} in {time.time() - start:.0f}s")


if __name__ == "__main__":
    main()
