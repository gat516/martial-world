---
name: tidy-docs
description: Run a docs-keeper pass - lint the docs, agents and skills, fold pending Workflow learnings into their homes, dedupe, fix stale paths and split over-budget files, then commit. Optional argument - a path to scope it (e.g. docs/map) or pasted Workflow learnings to fold in.
argument-hint: "[path | pasted learnings]"
disable-model-invocation: true
context: fork
agent: docs-keeper
---

Do a docs-keeper pass on a feature branch off the latest `test`. Work in your
own worktree if other sessions share the repo:
`git fetch && git worktree add -b docs-tidy-<date> ../martial-world-docs-tidy origin/test`.

Scope or input from the user: $ARGUMENTS

If that's a path, limit the pass to it. If it's pasted Workflow learnings, fold
those in first. If it's empty, run a full pass.

Finish with one commit on that branch, then report the branch name. Don't merge
or push it: the main session merges approved docs work into `test`.
