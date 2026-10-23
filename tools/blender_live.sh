#!/usr/bin/env bash
# Visible Blender windows that agents drive, so the user can watch several
# modelers build at once (the Blender MCP only reaches one Blender).
#
#   tools/blender_live.sh open <name> [file.blend]   open a Blender window for <name>
#   tools/blender_live.sh run <name> <script.py> [KEY=VALUE ...]
#                                                    run a script in it, print its output
#   tools/blender_live.sh close <name>               quit that Blender (no save prompt)
#   tools/blender_live.sh list                       windows that are up
#
# run: the script executes in the window's main thread, so the build appears
# live in its viewport. Globals persist between runs in one window. __file__ is
# set to the script's Windows path. KEY=VALUE pairs become globals ("True"/"False"
# and numbers converted). Exit status 1 on a traceback. Save your .blend early
# (bpy.ops.wm.save_as_mainfile) so the window title names your set.
# Headless alternative for jobs nobody needs to watch: tools/blender_run.sh.
# Close your window before you report.
set -euo pipefail
BLENDER="/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"
ROOT=/tmp/blender-live
HERE=$(cd "$(dirname "$0")" && pwd)
cmd=${1:-}; name=${2:-}
dir="$ROOT/$name"

case "$cmd" in
open)
	[ -n "$name" ] || { echo "usage: open <name> [file.blend]"; exit 2; }
	if [ -f "$dir/ready" ] && [ -f "$dir/pid" ] && kill -0 "$(cat "$dir/pid")" 2>/dev/null; then
		echo "already open: $name"; exit 0
	fi
	rm -rf "$dir"; mkdir -p "$dir/inbox" "$dir/outbox"
	args=()
	if [ $# -ge 3 ]; then args=("$(wslpath -w "$(realpath -m "$3")")"); fi
	nohup "$BLENDER" "${args[@]}" --python "$(wslpath -w "$HERE/blender_live_server.py")" -- "$(wslpath -w "$dir")" >"$dir/blender.out" 2>&1 &
	echo $! >"$dir/pid"
	for _ in $(seq 1 120); do [ -f "$dir/ready" ] && break; sleep 0.5; done
	[ -f "$dir/ready" ] || { echo "Blender for $name didn't come up; see $dir/blender.out"; exit 1; }
	echo "open: $name"
	;;
run)
	[ $# -ge 3 ] || { echo "usage: run <name> <script.py> [KEY=VALUE ...]"; exit 2; }
	[ -f "$dir/ready" ] || { echo "no window for $name; run: tools/blender_live.sh open $name"; exit 1; }
	script=$(realpath "$3"); shift 3
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
	wscript=$(wslpath -w "$script")
	job="$(date +%s%N)"
	cat >"$dir/inbox/.$job.tmp" <<EOF
import json as _json
globals().update(_json.loads(r'''$globals'''))
__file__ = r'''$wscript'''
exec(compile(open(__file__, encoding="utf-8").read(), __file__, "exec"), globals())
EOF
	mv "$dir/inbox/.$job.tmp" "$dir/inbox/$job.py"
	while [ ! -f "$dir/outbox/$job.done" ]; do
		kill -0 "$(cat "$dir/pid")" 2>/dev/null || { echo "Blender for $name exited"; exit 1; }
		sleep 0.3
	done
	cat "$dir/outbox/$job.log"
	failed=0; grep -q BLENDER_RUN_FAILED "$dir/outbox/$job.log" && failed=1
	rm -f "$dir/outbox/$job.log" "$dir/outbox/$job.done"
	exit $failed
	;;
close)
	[ -f "$dir/pid" ] || { echo "not open: $name"; exit 0; }
	echo 'import bpy; bpy.ops.wm.quit_blender()' >"$dir/inbox/zzquit.py"
	for _ in $(seq 1 20); do kill -0 "$(cat "$dir/pid")" 2>/dev/null || break; sleep 0.5; done
	kill "$(cat "$dir/pid")" 2>/dev/null || true
	rm -rf "$dir"; echo "closed: $name"
	;;
list)
	for d in "$ROOT"/*/; do
		[ -d "$d" ] || continue; n=$(basename "$d")
		if [ -f "$d/pid" ] && kill -0 "$(cat "$d/pid")" 2>/dev/null; then echo "$n open"; else echo "$n dead"; fi
	done
	;;
*) sed -n 2,18p "$0"; exit 2 ;;
esac
