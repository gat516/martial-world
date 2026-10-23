#!/usr/bin/env bash
# Runs a Blender Python script in its own headless Blender (Windows blender.exe
# from WSL), so several modelers can build, render and export at once without
# sharing the user's live Blender MCP session (one process, one active scene).
#
#   tools/blender_run.sh <script.py> [file.blend] [KEY=VALUE ...]
#
# - file.blend is opened first if given (it's created by the script's own
#   bpy.ops.wm.save_as_mainfile otherwise); omit it to start from factory startup.
# - KEY=VALUE pairs become globals in the script (strings; "True"/"False" and
#   numbers are converted), like the MCP exec lines (RENDER=False EXPORT=True).
# - The script's stdout and stderr, and any traceback, are printed here
#   (blender.exe's own console output doesn't reach WSL).
# Paths are WSL paths; __file__ is set to the script's Windows path, so
# os.path.dirname(__file__) works for sibling files.
set -euo pipefail
BLENDER="/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"
[ $# -ge 1 ] || { sed -n 2,15p "$0"; exit 2; }
script=$(realpath "$1"); shift
blend=""
if [ $# -ge 1 ] && [[ "$1" == *.blend ]]; then blend=$(realpath -m "$1"); shift; fi
log=$(mktemp --suffix=.log)
wscript=$(wslpath -w "$script"); wlog=$(wslpath -w "$log")
globals="{}"
if [ $# -ge 1 ]; then
	globals=$(python3 -c '
import json, sys
g = {}
for kv in sys.argv[1:]:
    k, v = kv.split("=", 1)
    if v in ("True", "False"): v = v == "True"
    else:
        try: v = int(v)
        except ValueError:
            try: v = float(v)
            except ValueError: pass
    g[k] = v
print(json.dumps(g))' "$@")
fi
expr="
import sys, json, traceback
_f = open(r'''$wlog''', 'w', encoding='utf-8', buffering=1)
sys.stdout = sys.stderr = _f
g = json.loads(r'''$globals''')
g.update({'__file__': r'''$wscript''', '__name__': '__main__'})
try:
    exec(compile(open(r'''$wscript''', encoding='utf-8').read(), r'''$wscript''', 'exec'), g)
except BaseException:
    traceback.print_exc()
    _f.write('BLENDER_RUN_FAILED\n')
_f.close()
"
args=(-b --factory-startup)
[ -n "$blend" ] && [ -f "$blend" ] && args=(-b "$(wslpath -w "$blend")")
"$BLENDER" "${args[@]}" --python-expr "$expr" >/dev/null 2>&1 || true
cat "$log"
if grep -q BLENDER_RUN_FAILED "$log"; then rm -f "$log"; exit 1; fi
rm -f "$log"
