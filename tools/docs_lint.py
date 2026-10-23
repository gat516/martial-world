#!/usr/bin/env python3
"""Find rot in the docs, agent definitions and skills.

    python3 tools/docs_lint.py            # everything
    python3 tools/docs_lint.py docs/map   # only files under these paths

Reports:
  link    a relative markdown link whose target doesn't exist
  path    a backticked repo path (src/, docs/, art/, tools/, assets/, .claude/)
          that doesn't exist (placeholders with <, *, ... are skipped)
  size    an agent or skill over its line budget, or a doc over DOC_BUDGET
  dup     a long line repeated verbatim across agent, skill and AGENTS.md files
          (shared text belongs in one skill or doc)
Exit code 1 when anything is reported. Read-only.
"""
import os, re, sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AGENT_BUDGET, SKILL_BUDGET, DOC_BUDGET = 250, 200, 450
# gitignored scratch folders that only exist mid-task
SCRATCH = ("tools/frag", "art/fbx_export")
PATH_RE = re.compile(r"`((?:src|docs|art|tools|assets|\.claude)/[^`\s]+)`")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")


def md_files(scope):
    roots = scope or ["AGENTS.md", "docs", ".claude/agents", ".claude/skills", "art"]
    for r in roots:
        p = os.path.join(ROOT, r)
        if os.path.isfile(p):
            yield p
            continue
        for d, dirs, files in os.walk(p):
            dirs[:] = [x for x in dirs if not x.startswith(".") or x in (".claude",)]
            for f in files:
                if f.endswith(".md"):
                    yield os.path.join(d, f)


def exists(rel):
    rel = rel.split("#")[0].split(":")[0].rstrip("/.,;")
    return not rel or os.path.exists(os.path.join(ROOT, rel))


def main():
    problems = []
    shared = defaultdict(set)
    for path in md_files(sys.argv[1:]):
        rel = os.path.relpath(path, ROOT)
        with open(path, encoding="utf-8") as f:
            text = f.read()
        lines = text.split("\n")
        for m in LINK_RE.finditer(text):
            t = m.group(1)
            if re.match(r"[a-z]+:", t) or t.startswith("#"):
                continue
            target = os.path.normpath(os.path.join(os.path.dirname(path), t.split("#")[0]))
            if not os.path.exists(target):
                problems.append(f"link  {rel}: {t}")
        for m in PATH_RE.finditer(text):
            p = m.group(1)
            if re.search(r"[<>*{}]|\.\.\.|\$", p) or p.startswith(SCRATCH):
                continue
            if not exists(p):
                problems.append(f"path  {rel}: {p}")
        n = len(lines)
        if rel.startswith(".claude/agents/") and n > AGENT_BUDGET:
            problems.append(f"size  {rel}: {n} lines (agent budget {AGENT_BUDGET})")
        elif rel.startswith(".claude/skills/") and n > SKILL_BUDGET:
            problems.append(f"size  {rel}: {n} lines (skill budget {SKILL_BUDGET})")
        elif rel.startswith("docs/") and n > DOC_BUDGET:
            problems.append(f"size  {rel}: {n} lines (doc budget {DOC_BUDGET}; split into parts)")
        if rel.startswith(".claude/") or rel == "AGENTS.md":
            for line in lines:
                key = " ".join(line.split()).lower()
                if len(key) > 70 and not key.startswith(("description:", "|", "name:")):
                    shared[key].add(rel)
    for key, files in shared.items():
        if len(files) > 1:
            problems.append(f"dup   {', '.join(sorted(files))}: {key[:90]}...")
    for p in sorted(problems):
        print(p)
    print(f"{len(problems)} issue(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
