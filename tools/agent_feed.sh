#!/usr/bin/env bash
# Live feed of what every subagent in a Claude Code session is doing: one line
# per tool call or status message, newest last, from the subagent transcripts
# under ~/.claude/projects/<project>/<session>/subagents/ (they flush live).
#
#   tools/agent_feed.sh            # the most recently active session
#   tools/agent_feed.sh <session>  # a session id (prefix is fine)
#   tools/agent_feed.sh --once     # print the last 40 lines and exit
#
# Each line: HH:MM:SS  <agent type or name>  TOOL <name> <first 90 chars of input>
# or                   <agent>                SAYS <first 120 chars of a text block>
# A "## Status:" text block from an agent shows as STATUS, so agents that post a
# status line at each phase read as "building variant 2 of 3", not "execute_luau".
# Stop or steer an agent from the session: "stop the fox animator" (TaskStop) or a
# SendMessage; in the desktop app, the title-bar menu > Background tasks.
set -u
PROJ="$HOME/.claude/projects/$(pwd | sed 's#/#-#g')"
ONCE=0
SESSION=""
for a in "$@"; do
	case "$a" in
	--once) ONCE=1 ;;
	*) SESSION="$a" ;;
	esac
done
if [ -z "$SESSION" ]; then
	DIR=$(ls -td "$PROJ"/*/subagents 2>/dev/null | head -1)
else
	DIR=$(ls -d "$PROJ"/"$SESSION"*/subagents 2>/dev/null | head -1)
fi
if [ -z "${DIR:-}" ]; then
	echo "no subagent transcripts under $PROJ" >&2
	exit 1
fi
echo "feed: $DIR"

filter() {
	python3 -u -c '
import sys, json, os
names = {}
def name(path):
    aid = os.path.basename(path).replace("agent-", "").replace(".jsonl", "")
    if aid not in names:
        meta = path.replace(".jsonl", ".meta.json")
        try:
            m = json.load(open(meta))
            names[aid] = (m.get("agentType") or m.get("subagent_type") or m.get("description") or aid)[:18]
        except Exception:
            names[aid] = aid[:8]
    return names[aid]
for line in sys.stdin:
    path, _, raw = line.partition("\t")
    try:
        d = json.loads(raw)
    except Exception:
        continue
    if d.get("type") != "assistant":
        continue
    ts = d.get("timestamp", "")[11:19]
    who = name(path)
    for c in d.get("message", {}).get("content", []) or []:
        if not isinstance(c, dict):
            continue
        if c.get("type") == "tool_use":
            inp = c.get("input") or {}
            if isinstance(inp, dict):
                brief = inp.get("description") or inp.get("command") or inp.get("file_path") or inp.get("code") or inp.get("prompt") or json.dumps(inp)
            else:
                brief = str(inp)
            brief = " ".join(str(brief).split())[:90]
            tool = c.get("name", "")
            print(f"{ts}  {who:<18} TOOL {tool:<22} {brief}", flush=True)
        elif c.get("type") == "text":
            t = " ".join(c.get("text", "").split())
            if not t:
                continue
            kind = "STATUS" if t.lower().startswith("## status") or t.lower().startswith("status:") else "SAYS"
            print(f"{ts}  {who:<18} {kind} {t[:120]}", flush=True)
'
}

if [ "$ONCE" = 1 ]; then
	for f in "$DIR"/agent-*.jsonl; do tail -n 60 "$f" | sed "s#^#$f\t#"; done | filter | tail -n 40
	exit 0
fi
# tail every current and future transcript, prefixing each line with its file
tail -n 20 -F "$DIR"/agent-*.jsonl 2>/dev/null | awk -v dir="$DIR" '
	/^==> .* <==$/ { f=$2; next }
	NF { print f "\t" $0 }
' | filter
