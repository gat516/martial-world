Exporting templates with attributes intact, merging your group into the shared `assets/Effects.rbxm`, and file ownership and the Studio lock when other vfx agents run. Read before you export or commit, and whenever another vfx agent may be running.

# Export, merge and working alongside other agents

## Export (attributes must survive)

`tools/export_rbxmx.luau` drops attributes and tags and only knows a short property list, so
it is wrong for effects. Use the binary exporter (`vfxStage.finish()` and
`tools/vfx_export.sh` do these steps for you, [pipeline.md](pipeline.md)):

1. `tools/ensure_receiver.sh` (starts `tools/receive_rbxmx.py` on loopback 8766 unless one is
   already up).
2. Run `tools/export_rbxm.luau` through `execute_luau` (installs `_G.exportRbxm`).
3. `game:GetService("HttpService"):PostAsync("http://127.0.0.1:8766/Effects.rbxm", _G.exportRbxm("ReplicatedStorage._StagingEffects", "Effects"))`.
   The second argument writes the root under its real name.
4. Move `tools/frag/Effects.rbxm` to `assets/Effects.rbxm`. It's binary, so check it by
   building it: `~/.rokit/bin/rojo build` a scratch project that maps only that file to an
   `.rbxmx` in your scratchpad and grep the result for the templates and
   `AttributesSerialize`.
5. Destroy the staging copy; with Rojo connected, check the real folder now holds your
   changes and there is one copy of it.

## Merge, don't copy (sandboxes and parallel agents)

`assets/Effects.rbxm` is one file holding every group, and a sandbox's export holds the whole
folder as it was when that sandbox opened. Copying an export over the file (`vfx_export.sh`)
throws away any group another agent shipped since. Instead:
- Export a temporary folder holding only a clone of your group
  (`ReplicatedStorage._Export<Group>`, exported under the name `Effects`, then destroyed),
  posted under your own name: `PostAsync("http://127.0.0.1:8766/Effects_<Group>.rbxm", ...)`
  lands in `tools/frag/Effects_<Group>.rbxm`. `execute_luau` refuses posts over 1 MB, and the
  whole Effects folder is bigger.
- Splice only your groups in:
  `python3 tools/effects_merge.py tools/frag/Effects_<Group>.rbxm <Group> [...]`. It replaces
  or adds `Effects.<Group>` and leaves every other group as it is on disk; attributes, tags
  and Refs survive (a merge of a file with itself round-trips identically). The merge only
  reads the named groups.
- Merge right before you commit, and commit a blob built from HEAD plus your group
  (`EFFECTS_TARGET=<copy of HEAD's file> tools/effects_merge.py ...`, then
  `git update-index --cacheinfo`), as AGENTS.md "Parallel agents" says: a merge left in the
  working tree gets swept into another session's commit.

## Ownership when several vfx agents share a worktree and Studio

- **Yours:** `src/client/TechniqueFX/<Id>.luau` (the technique's runtime:
  `return { cast = function(CombatEffects, def, level, character, origin, dir, chain): boolean }`,
  returning false to fall back to the old drawing), `tools/vfx_specs/<Id>.luau` (helpers only
  your technique needs go in that spec file), and the `Effects.<Id>` group in Studio.
- **Shared, don't edit while others are running:** `CombatEffects.luau`, `CastFX.luau`,
  `TechniqueVFX.luau`, `tools/vfx_blocks.luau`, the other tools, `tools/vfx_session.luau`
  (regenerate it to load your spec, but don't commit it), and `docs/`. If you need a shared
  change (a new block, a CastFX helper such as playLine/playZone), build it inside your own
  files and propose the shared version in your report; the main session merges it.
- Commit only your own files, staged by path (never `git add -A`).
- **Studio lock** (when agents share one Studio): call `vfxStage.lock(who)` (your technique
  id as `who`) before any staging, preview scene or capture run. Hold it from `begin(who)`
  through `finish()`, the export, `synced` and the git commit of `assets/Effects.rbxm`
  (together with your files), then `unlock(who)`. Re-lock to refresh it on long runs. If
  someone else holds it, do non-Studio work (spec, runtime code, planning) and try later.
  Never steal a fresh lock. Always stage from the live `Effects` while holding the lock;
  never reuse an old staging copy. `vfxPreview.clear()` removes every preview scene, so only
  call it while you hold the lock.
- In a shared Studio, other sessions use the same `_G`: scope any `_G` helper overrides
  inside the call that needs them, and leave others' `_*Preview` / `_Staging*` folders alone
  ([previewing.md](previewing.md), "Shared Studio").
