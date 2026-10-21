#!/usr/bin/env bash
# Moves the latest Effects export (tools/frag/Effects.rbxm, written by
# tools/receive_rbxmx.py) into assets/ and verifies it by building it to XML in
# a temp dir: lists every template, counts attributes and add-on tags, and
# fails if the file has no templates. Usage: tools/vfx_export.sh [Name ...]
# (names to require, e.g. PalmStrike_T4 Shell RockRing).
set -euo pipefail
cd "$(dirname "$0")/.."

src=tools/frag/Effects.rbxm
[[ -f $src ]] || { echo "no $src; export from Studio first (tools/vfx_stage.luau)"; exit 1; }
cp "$src" assets/Effects.rbxm

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp assets/Effects.rbxm "$tmp/"
cat > "$tmp/check.project.json" <<'JSON'
{ "name": "check", "tree": { "$className": "Folder", "Effects": { "$path": "Effects.rbxm" } } }
JSON
~/.rokit/bin/rojo build "$tmp/check.project.json" -o "$tmp/out.rbxmx" >/dev/null

python3 - "$tmp/out.rbxmx" "$@" <<'PY'
import base64, re, sys
xml = open(sys.argv[1]).read()
names = re.findall(r'<string name="Name">([^<]*)</string>', xml)
templates = sorted({n for n in names if re.match(r'.+_T\d+$', n)})
if not templates:
    sys.exit("no <Id>_T<n> templates in the export")
attrs = b"".join(base64.b64decode(b.strip()) for b in re.findall(r'<BinaryString name="AttributesSerialize">([^<]*)</BinaryString>', xml) if b.strip())
tags = b"".join(base64.b64decode(b.strip()) for b in re.findall(r'<BinaryString name="Tags">([^<]*)</BinaryString>', xml) if b.strip())
print("templates:", " ".join(templates))
key = lambda k: len(k).to_bytes(4, "little") + k.encode()  # names are length-prefixed
print("attributes:", ", ".join(f"{k}={attrs.count(key(k))}" for k in ["EmitCount", "EmitDelay", "Phase", "AuthoredActive", "AuthoredWindup", "AuthoredRadius", "CameraShake", "ImpactFrames", "Duration", "Count"]))
print("tags:", ", ".join(f"{k}={tags.count(k.encode())}" for k in ["CraterVFX", "SplineVFX", "MeshVFX", "ColorVFX", "ScaleVFX"]))
missing = [n for n in sys.argv[2:] if n not in names]
if missing:
    sys.exit("missing: " + " ".join(missing))
print("assets/Effects.rbxm ok")
PY
