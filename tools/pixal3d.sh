#!/usr/bin/env bash
# Pixal3D image -> textured GLB, run on Windows (D:\pixal3d) from WSL.
#
#   tools/pixal3d.sh --check                         preflight only (RAM, VRAM, lock)
#   tools/pixal3d.sh --image in.png --output out.glb [--tris 20000] [--texture 1024]
#                    [--seed 42] [--fov 0.2] [--force]
#
# Paths may be WSL paths; they're converted for Windows. The run refuses to start
# when the preflight fails, unless --force. Docs: tools/pixal3d/README.md.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image|--output)
      flag="$1"; path="$2"; shift 2
      [[ "$flag" == --output ]] && mkdir -p "$(dirname "$path")"
      [[ "$flag" == --image && ! -f "$path" ]] && { echo "no such image: $path" >&2; exit 1; }
      args+=("$flag" "$(wslpath -w "$(realpath -m "$path")")")
      ;;
    *) args+=("$1"); shift ;;
  esac
done

# cmd.exe can't start in a \\wsl.localhost directory, so run from D:.
cd /mnt/d/pixal3d
exec cmd.exe /c "D:\\pixal3d\\envrun.cmd" python "$(wslpath -w "$here/pixal3d/gen.py")" "${args[@]}"
