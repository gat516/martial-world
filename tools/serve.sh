#!/usr/bin/env bash
# Read-only file servers sandboxes load from over HTTP (they die with every
# session, so run this before any HTTP load).
#
#   tools/serve.sh                 the two shared servers:
#     8767  art/enemies  build, rig, preview and QA scripts
#                        (http://127.0.0.1:8767/<group>/<file>.luau)
#     8768  repo root    anything else, e.g. src/ modules for tools/push_src.luau
#                        (http://127.0.0.1:8768/src/client/EnemyPoses/Boar.luau)
#   tools/serve.sh <port> [dir]    serves dir (default: the repo root of the
#                        checkout this script lives in, i.e. your worktree) on that
#                        loopback port. Refuses a busy port and names the pid holding
#                        it. Prints the base URL; then, in Studio, set
#                        _G.SERVE_BASE = "<that URL>" so the art/tools scripts read
#                        from it (repo-root relative paths, art/enemies/... included).
#
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
if [ $# -eq 0 ]; then
	start 8767 art/enemies check_rig.luau
	start 8768 . default.project.json
	exit $?
fi
port=$1
dir=$(realpath "${2:-.}")
case $port in '' | *[!0-9]*)
	echo "usage: tools/serve.sh [<port> [dir]]" >&2
	exit 2
	;;
esac
if [ ! -d "$dir" ]; then
	echo "no such directory: $dir" >&2
	exit 2
fi
holder=$(ss -ltnp "sport = :$port" 2>/dev/null | tail -n +2)
if [ -n "$holder" ]; then
	echo "port $port is busy: $holder" >&2
	exit 1
fi
nohup python3 -m http.server "$port" --bind 127.0.0.1 --directory "$dir" >"tools/frag/serve-$port.log" 2>&1 &
pid=$!
disown
for _ in 1 2 3 4 5 6 7 8 9 10; do
	sleep 0.3
	if curl -s -o /dev/null "http://127.0.0.1:$port/"; then
		echo "serving $dir (pid $pid)"
		echo "http://127.0.0.1:$port/"
		exit 0
	fi
done
echo "$port failed to start; see tools/frag/serve-$port.log" >&2
exit 1
