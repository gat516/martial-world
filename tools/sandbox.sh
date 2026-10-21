#!/usr/bin/env bash
# Disposable Studio sessions for agents, so they never share (or get blocked
# by) the user's open Studio.
#
#   tools/sandbox.sh open <name>    build a fresh place from test.project.json
#                                   (repo code + assets/, testbed stubs, no
#                                   Workspace.Map) and open it in Studio
#   tools/sandbox.sh close <name>   close that Studio window (no save prompt)
#   tools/sandbox.sh list           list open sandboxes with their age
#   tools/sandbox.sh prune <hours>  close every sandbox open longer than that
#                                   (leftovers from agents that forgot)
#
# Always close your sandbox before you report, even when the task failed or
# was cut short: every one left open is a full Studio eating the user's RAM.
#
# The place file is mw-sandbox-<name>.rbxl in the Windows temp folder. Once it
# opens, it shows up in the Studio MCP's list_roblox_studios under that name;
# pass its id as studio_id. HttpService is on, so tools/ensure_receiver.sh
# exports work from it. Nothing in it is saved anywhere: export what you build
# to assets/ (tools/export_rbxm.luau), then close it.
set -euo pipefail
cd "$(dirname "$0")/.."

cmd=${1:-}
name=${2:-}
ps() { powershell.exe -NoProfile -Command "$1" | tr -d '\r'; }

case "$cmd" in
open)
	[[ "$name" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "usage: $0 open <name> (letters, digits, - or _)" >&2; exit 2; }
	winTemp=$(ps '[IO.Path]::GetTempPath()')
	dir=$(wslpath -u "$winTemp")/mw-sandbox
	mkdir -p "$dir"
	out="$dir/mw-sandbox-$name.rbxl"
	project=.sandbox-$name.project.json
	trap 'rm -f "$project"' EXIT
	python3 - "$project" <<'EOF'
import json, sys
p = json.load(open("test.project.json"))
p["name"] = "MW Sandbox"
p["tree"].setdefault("HttpService", {"$className": "HttpService"}).setdefault("$properties", {})["HttpEnabled"] = True
json.dump(p, open(sys.argv[1], "w"), indent=1)
EOF
	rojo build "$project" -o "$out" >/dev/null
	exe=$(ls -t /mnt/c/Users/*/AppData/Local/Roblox/Versions/*/RobloxStudioBeta.exe | head -1)
	nohup "$exe" "$(wslpath -w "$out")" >/dev/null 2>&1 &
	disown
	echo "opening $(basename "$out"); find it with list_roblox_studios (it can take ~20 s to connect)"
	echo "close it before you report: tools/sandbox.sh close $name"
	others=$("$0" list)
	[[ -n "$others" ]] && echo "already open:" && echo "$others"
	true
	;;
close)
	[[ "$name" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "usage: $0 close <name>" >&2; exit 2; }
	ps "Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { \$_.MainWindowTitle -like '*mw-sandbox-$name.rbxl*' } | ForEach-Object { Stop-Process -Id \$_.Id -Force; 'closed ' + \$_.MainWindowTitle }"
	;;
list)
	ps "Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { \$_.MainWindowTitle -like '*mw-sandbox-*' } | ForEach-Object { \$n = [regex]::Match(\$_.MainWindowTitle, 'mw-sandbox-([A-Za-z0-9_-]+)\\.rbxl').Groups[1].Value; '{0}  open {1:0.0} h' -f \$n, ((Get-Date) - \$_.StartTime).TotalHours }"
	;;
prune)
	[[ "$name" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "usage: $0 prune <hours>" >&2; exit 2; }
	ps "Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { \$_.MainWindowTitle -like '*mw-sandbox-*' -and ((Get-Date) - \$_.StartTime).TotalHours -gt $name } | ForEach-Object { Stop-Process -Id \$_.Id -Force; 'closed ' + \$_.MainWindowTitle }"
	;;
*)
	sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
	;;
esac
