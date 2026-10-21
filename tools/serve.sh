#!/usr/bin/env bash
# Makes sure the read-only file servers sandboxes load from are up (both die
# with every session, so run this before any HTTP load):
#   8767  art/enemies  build, rig, preview and QA scripts
#                      (http://127.0.0.1:8767/<group>/<file>.luau)
#   8768  repo root    anything else, e.g. src/ modules for tools/push_src.luau
#                      (http://127.0.0.1:8768/src/client/EnemyPoses/Boar.luau)
# The receiver on 8766 (exports, VFX helpers) is tools/ensure_receiver.sh.
# Logs: tools/frag/serve-<port>.log.
cd "$(dirname "$0")/.."
mkdir -p tools/frag
start() {
	local port=$1 dir=$2 probe=$3
	if curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/$probe" | grep -q 200; then
		echo "$port already serving $dir"
		return 0
	fi
	nohup python3 -m http.server "$port" --bind 127.0.0.1 --directory "$dir" >"tools/frag/serve-$port.log" 2>&1 &
	disown
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		sleep 0.3
		if curl -s -o /dev/null "http://127.0.0.1:$port/$probe"; then
			echo "$port serving $dir"
			return 0
		fi
	done
	echo "$port failed to start; see tools/frag/serve-$port.log" >&2
	return 1
}
start 8767 art/enemies check_rig.luau
start 8768 . default.project.json
