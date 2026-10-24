# Pixal3D generator

Image to textured GLB (TencentARC Pixal3D, TRELLIS.2 backbone, MIT), installed
natively on Windows at `D:\pixal3d` and driven from WSL. The `asset-generator`
agent (`.claude/agents/asset-generator.md`) owns the workflow; this file is the
tool itself.

## Use

```
tools/pixal3d.sh --check
tools/pixal3d.sh --image art/x/ref.png --output art/x/gen/x_s42.glb --tris 20000 --texture 1024 --seed 42
```

- **Preflight**: every run first checks free RAM (14 GB), free VRAM (5 GB) and
  `D:\pixal3d\gen.lock` (one generation at a time). If any check fails it lists
  the biggest processes and exits 2 without generating. `--force` overrides it, but
  only when the user says so. `--min_ram_gb` / `--min_vram_gb` tune the limits.
- **Input**: one object, centred, filling most of the frame, plain or transparent
  background, no ground shadow. A transparent PNG skips background removal
  (otherwise `ZhengPeng7/BiRefNet` cuts it out).
- **Camera**: MoGe estimates the field of view. Pass `--fov 0.2` for flat,
  orthographic-looking concept art if the result looks stretched.
- **Output**: `--tris` is the decimation target and `--texture` the baked
  texture size; upstream defaults are 1M tris and 4K. The GLB is Y-up, about 1
  unit across, with base colour, metallic and roughness textures.
- **Mode**: low-VRAM mode at 1024 resolution by default. Models wait in RAM and
  move to the GPU one stage at a time. `--resolution 1536` and `--high_vram`
  exist, but don't fit an 8 GB card.
- `D:\pixal3d\pixal3d.cmd` takes the same arguments from a Windows prompt.

## Install layout (`D:\pixal3d`)

| Path | What |
|---|---|
| `env\` | micromamba env: Python 3.10, CUDA toolkit 12.4.1 (nvidia channel), torch 2.6.0+cu124, triton-windows 3.2 |
| `BuildTools\` | VS 2022 Build Tools (MSVC 14.44), used to compile the extensions |
| `Pixal3D\` | TencentARC/Pixal3D @ f7cf384 |
| `TRELLIS.2\` | microsoft/TRELLIS.2 @ 75fbf01, for `o-voxel` |
| `ext\` | CuMesh @ 12289e1, FlexGEMM @ 6dd94a8, nvdiffrast v0.4.0 |
| `hf\`, `torch\` | Hugging Face and torch.hub caches (Pixal3D single-view ckpts, DINOv3, MoGe-2, NAF, BiRefNet) |
| `envrun.cmd` | copy of `tools/pixal3d/envrun.cmd`; sets up MSVC, CUDA, the env and caches, then runs its arguments |
| `pixal3d.cmd` | copy of `tools/pixal3d/pixal3d.cmd` |

`gen.py` runs from the repo, so changes need no reinstall. Edit `envrun.cmd` and
`pixal3d.cmd` here, then copy them to `D:\pixal3d`.

## Rebuilding

1. Build Tools: `winget install Microsoft.VisualStudio.2022.BuildTools` with
   `--installPath D:\pixal3d\BuildTools --add Microsoft.VisualStudio.Workload.VCTools`.
2. Env: `micromamba create -p D:\pixal3d\env -c nvidia/label/cuda-12.4.1 -c conda-forge python=3.10 cuda-toolkit=12.4.1 git`,
   then (through `envrun.cmd`) torch 2.6.0/torchvision 0.21.0 from the cu124 index.
3. Python deps: Pixal3D's `requirements.txt` with `trimesh>=4.10.1` (MoGe 3.0
   needs 4.11 or newer), plus `ninja`, `triton-windows<3.3`, `einops` (NAF) and Pixal3D's utils3d wheel.
   `requirements-lock.txt` is the resulting `pip freeze`.
4. Extensions: `pip install --no-deps --no-build-isolation` each of CuMesh,
   FlexGEMM, `TRELLIS.2\o-voxel` and nvdiffrast, with `TORCH_CUDA_ARCH_LIST=7.5`
   (RTX 2070). FlexGEMM and o-voxel need the MSVC fixes in `patches/`:
   `template` keyword on `data_ptr<T>()` in a generic lambda, GCC-only `1e-6d`
   literals, and size_t-to-int64 narrowing in tensor shapes. Install FlexGEMM from
   source even if MoGe already pulled it from git, because that copy has no kernels.
5. Weights download on first run. Single-view only; the `_mv` ckpts were skipped.

## Known limits

- The RTX 2070 (Turing) has no FlashAttention and no native bf16, so it uses
  PyTorch SDPA with emulated bf16. That is slower than the authors' numbers.
- NATTEN (NAF's neighbourhood attention) has no Windows build for Turing, so
  `natten_shim/` stands in with a pure-PyTorch `na2d` that matches a
  brute-force reference. `gen.py` uses it only when the real `natten` is
  missing. It's slower and uses more memory than the fused kernel.
- The baked textures are PBR and photographic. The game's look is flat
  colours, so the agent repaints or bakes down to flat colour regions.
