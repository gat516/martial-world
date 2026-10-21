#!/usr/bin/env bash
# Makes sure tools/receive_rbxmx.py is serving 127.0.0.1:8766 (Studio loads the
# VFX helpers from it and posts exports to it). It dies with every session, so
# run this before any HTTP load or export. Log: tools/frag/receiver.log.
cd "$(dirname "$0")/.."
if curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8766/vfx_session.luau | grep -q 200; then
	echo "receiver already up on 8766"
	exit 0
fi
mkdir -p tools/frag
nohup python3 tools/receive_rbxmx.py >tools/frag/receiver.log 2>&1 &
disown
for _ in 1 2 3 4 5 6 7 8 9 10; do
	sleep 0.3
	if curl -s -o /dev/null http://127.0.0.1:8766/vfx_session.luau; then
		echo "receiver started on 8766 (pid $!)"
		exit 0
	fi
done
echo "receiver failed to start; see tools/frag/receiver.log" >&2
exit 1
