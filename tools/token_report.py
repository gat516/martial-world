#!/usr/bin/env python3
"""Reports where this project's Claude Code sessions spend tokens.

Reads the local transcripts (~/.claude/projects/<this repo>/), counting each API
message once, and prints: main vs subagent usage, per-agent-type launch size,
turns, peak context and screenshots, the tool results that fill context, and
the tool schemas each agent type loads per turn. Cost shares use Opus list-price
weights (input 1, cache write 1.25, cache read 0.1, output 5); they rank, they
don't bill. Run it before and after a token pass (docs/agents/orchestration.md).

  python3 tools/token_report.py [--days N]
"""
import argparse
import collections
import glob
import json
import os
import re
import statistics
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEIGHT = {"input_tokens": 1, "cache_creation_input_tokens": 1.25,
          "cache_read_input_tokens": 0.1, "output_tokens": 5}


def project_dir():
    # Sessions in worktrees log under the main checkout's folder.
    common = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
                            cwd=ROOT, capture_output=True, text=True).stdout.strip()
    main = Path(common).parent if common else ROOT
    pdir = Path.home() / ".claude/projects" / re.sub(r"[^A-Za-z0-9]", "-", str(main))
    if not pdir.is_dir():
        raise SystemExit(f"no transcripts at {pdir}")
    return pdir


def lines(path):
    with open(path, errors="ignore") as f:
        for line in f:
            try:
                yield json.loads(line)
            except ValueError:
                pass


def tool_group(name):
    return "mcp__" + name.split("__")[1] if name.startswith("mcp__") else name


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=float, default=0, help="only transcripts modified in the last N days")
    args = ap.parse_args()
    pdir = project_dir()
    cutoff = time.time() - args.days * 86400 if args.days else 0
    mains = [p for p in glob.glob(f"{pdir}/*.jsonl") if os.path.getmtime(p) >= cutoff]
    subs = sorted((p for p in glob.glob(f"{pdir}/*/subagents/*.jsonl") if os.path.getmtime(p) >= cutoff),
                  key=os.path.getmtime)  # oldest first, so each type keeps its latest run's schemas

    usage = {"main": collections.Counter(), "sub": collections.Counter()}
    results = collections.Counter()
    calls = collections.Counter()
    runs = collections.defaultdict(list)
    schemas = {}
    unlisted = collections.Counter()  # runs that launched with every tool (Artifact present)
    seen = set()
    for path in mains + subs:
        kind = "sub" if "/subagents/" in path else "main"
        agent = "main"
        if kind == "sub":
            try:
                agent = json.load(open(path.replace(".jsonl", ".meta.json"))).get("agentType", "?")
            except (OSError, ValueError):
                agent = "?"
        names = {}
        ctx = []
        images = 0
        shaped = False
        for e in lines(path):
            if e.get("type") == "api-request-shape" and not shaped:
                shaped = True
                tools = (e.get("shape") or {}).get("tools") or []
                group = collections.Counter()
                for t in tools:
                    if not t.get("defer_loading"):
                        group[tool_group(t["name"])] += len(json.dumps(t)) // 4
                schemas[agent] = group
                unlisted[agent] += "Artifact" in group
            m = e.get("message")
            if not isinstance(m, dict):
                continue
            if e.get("type") == "assistant":
                u = m.get("usage")
                if u and m.get("id") not in seen:
                    seen.add(m.get("id"))
                    for k in WEIGHT:
                        usage[kind][k] += u.get(k) or 0
                    ctx.append(sum(u.get(k) or 0 for k in WEIGHT if k != "output_tokens"))
                for c in m.get("content") or []:
                    if isinstance(c, dict) and c.get("type") == "tool_use":
                        names[c["id"]] = c["name"]
            elif e.get("type") == "user" and isinstance(m.get("content"), list):
                for c in m["content"]:
                    if not (isinstance(c, dict) and c.get("type") == "tool_result"):
                        continue
                    n = names.get(c.get("tool_use_id"), "?")
                    body = c.get("content")
                    if isinstance(body, list):
                        images += sum(1 for x in body if isinstance(x, dict) and x.get("type") == "image")
                    results[n] += len(json.dumps(body)) if body is not None else 0
                    calls[n] += 1
        if kind == "sub" and ctx:
            runs[agent].append((ctx[0], len(ctx), max(ctx), images))

    cost = {k: sum(v[t] * WEIGHT[t] for t in WEIGHT) for k, v in usage.items()}
    total = sum(cost.values()) or 1
    print(f"{len(mains)} sessions, {len(subs)} subagent runs\n")
    for k, v in usage.items():
        share = {t: v[t] * WEIGHT[t] / (cost[k] or 1) for t in WEIGHT}
        print(f"{k:5} {cost[k] / total:5.0%} of cost | cache read {v['cache_read_input_tokens'] / 1e6:7.0f}M "
              f"({share['cache_read_input_tokens']:.0%}) | cache write {v['cache_creation_input_tokens'] / 1e6:5.0f}M "
              f"({share['cache_creation_input_tokens']:.0%}) | output {v['output_tokens'] / 1e6:4.1f}M ({share['output_tokens']:.0%})")

    print("\nper subagent type (medians; launch = first-turn context; all-tools = runs without their allowlist;\n schemas from each type's latest run)")
    print(f"  {'agent':16}{'runs':>5}{'all-tools':>10}{'launch':>8}{'turns':>7}{'peak':>8}{'imgs/run':>9}  per-turn tool schemas (tokens)")
    for agent, rs in sorted(runs.items(), key=lambda kv: -len(kv[1])):
        med = lambda i: int(statistics.median(r[i] for r in rs))
        sch = schemas.get(agent, {})
        top = ", ".join(f"{n} {s}" for n, s in sch.most_common(5))
        print(f"  {agent[:16]:16}{len(rs):5}{unlisted[agent]:10}{med(0):8}{med(1):7}{med(2):8}{sum(r[3] for r in rs) / len(rs):9.1f}  "
              f"{sum(sch.values())}: {top}")

    print("\ntool results by volume (chars; images count their base64)")
    for n, s in results.most_common(12):
        print(f"  {s / 1e6:7.1f}M {calls[n]:6} calls  avg {s // calls[n]:7}  {n}")


if __name__ == "__main__":
    main()
