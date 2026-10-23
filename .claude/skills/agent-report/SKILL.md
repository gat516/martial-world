---
name: agent-report
description: How a content subagent finishes - which docs to update in the same commit, the report's shape (result first, what was checked, what's untested), and the closing Workflow learnings and Workflow optimization sections the main session folds back into agent definitions and docs. Use when wrapping up any task.
user-invocable: false
---

# Finishing a task

## Docs, in the same commit

- Update every doc your change touches: the system's core doc and its part
  file (`docs/enemies/<enemy>.md`, `docs/map/<area>.md`, ...). Cover behaviour,
  design intent, files, remotes, tuning and known gaps.
- Update `docs/README.md` if you added a mapped asset, a remote or a new system
  file.
- Fix anything stale you ran into. A decision the user made in conversation
  goes into the matching doc.
- Keep docs lean: the current state and decisions, not history. Git has the
  history. A new item (an enemy, an area, an effect set) gets its own part file
  and one line in its core doc's index.
- Gotchas that only matter for one system go in that system's doc or its
  `RIGS.md`, not in your report alone.

## The report

Use plain words, and lead with the result.
1. **What you made or changed, and why.** One line per decision the user would
   care about, e.g. "cut the ground crack: a roar pushes air, it doesn't hit the
   ground".
2. **Where it lives and plays:** files, templates, ids, event or attack names.
3. **What you checked:** numeric checks, the angles or moments you captured,
   and the capture paths.
4. **What's untested.** The user playtests, so be specific: feel, phone cost,
   blending, multiplayer.
5. **Open items:** anything you couldn't match from the brief, `NeedsHandPass`
   flags, decisions for the user.
6. If you touched combat, enemy AI, attacks, techniques, events or animations,
   repeat the commit's `Test build:` line.

Ask the user to review visuals in Studio. Don't send a pile of screenshots.

## Close with these two sections

- **Workflow learnings:** what cost time and how to avoid it; tool, plugin,
  Rojo, exporter or MCP gotchas; anything in the docs or your agent file that
  was wrong or missing. Not your taste or picks: no ids, palettes or recipes for
  others to copy.
- **Workflow optimization:** concrete changes ranked by time saved (a tool, a
  shared building block, batching). Build the small, clearly worthwhile ones and
  commit them; list the rest.

Don't edit your own agent file (`.claude/agents/*.md`) or these skills. The
main session folds your sections in, and the `docs-keeper` agent tidies them.
