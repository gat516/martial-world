---
name: shared-commit
description: Committing safely in a repo several sessions share - staging only your own files and hunks, committing a shared doc or binary (assets/Effects.rbxm) as a blob built from HEAD plus your change, using a temporary index, and checking nothing of anyone else's was swept in. Use for every commit.
user-invocable: false
---

# Committing alongside other sessions

Several sessions commit to the same repo at once. Commits have been swallowed
twice, and a merge left in a working tree was swept into someone else's commit
(46f7e1a).

## Every commit

1. Run `git diff --cached --name-only` first. Anything listed that isn't yours
   was staged by another session: leave it alone, and use a temporary index
   (below).
2. Stage and commit in one command, naming your paths. Never use `git add -A`,
   `git add .` or `git commit -a`.
   ```bash
   git add -- src/client/Foo.luau docs/systems/foo.md && git commit -m "..."
   ```
3. Run `git show --stat HEAD` to check that the commit holds only your files.

Commit message: the subject says what changed, and the body says why, plus
anything unfinished. After a change to combat, enemy AI, attacks, techniques,
events or animations, end the body with `Test build: <what to test>`. Then add
the attribution line.

## A shared file holding other agents' changes

This covers shared docs (`docs/README.md`, `map.md`, a system's core doc) and
shared scripts (`EnemyAnimator.luau`, `Quadruped.luau`). Commit only your hunk,
built on the current HEAD:
```bash
S=<your scratchpad>
git show HEAD:docs/README.md > "$S/README.md"   # HEAD's version
# apply only your edit to $S/README.md (a script or Edit), then:
blob=$(git hash-object -w "$S/README.md")
git update-index --cacheinfo 100644,"$blob",docs/README.md
```
HEAD moves, so rebuild the blob right before committing. `git add -p` also
works when you can pick your hunks cleanly.

## A temporary index (when the shared index holds others' work)

```bash
export GIT_INDEX_FILE="$S/index"
git read-tree HEAD
git add -- <your paths>          # or update-index --cacheinfo as above
git commit -m "..."
unset GIT_INDEX_FILE
git reset -q -- <your paths>     # sync the shared index to the new HEAD
```

## Shared binaries (`assets/Effects.rbxm`)

A binary can't be committed by hunk. Merge your group into a copy of HEAD's file
and commit that blob:
```bash
git show HEAD:assets/Effects.rbxm > "$S/Effects.rbxm"
EFFECTS_TARGET="$S/Effects.rbxm" python3 tools/effects_merge.py tools/frag/Effects_<Group>.rbxm <Group>
blob=$(git hash-object -w "$S/Effects.rbxm")
git update-index --cacheinfo 100644,"$blob",assets/Effects.rbxm
```
For `assets/Enemies.rbxm`, commit HEAD's file plus your template, the same way.
Never leave a merged binary in the working tree.

## Scripts that edit files

Read the whole file before opening it for writing (`s = open(p).read()`, then
`open(p, "w")`). Opening for writing first empties the file; this has emptied
`SFX.rbxmx` and `enemies.md` mid-pass. For big files, write to a temp file and
rename it over the original.
