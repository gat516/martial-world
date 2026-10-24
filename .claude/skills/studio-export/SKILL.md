---
name: studio-export
description: Saving Studio-built instances to assets/ so they last - choosing the exporter (binary .rbxm keeps attributes, tags and C0/C1; .rbxmx for GUIs), the shared receiver, exporting only your part of a shared file, and the staging copy needed before any structural change to a Rojo-mapped instance in a Rojo-connected place. Use before every export and before creating, deleting, renaming or reparenting anything Rojo maps.
user-invocable: false
---

# Exporting to assets/

Rojo maps files under `assets/` into every place (`default.project.json` and
`test.project.json`). Studio edits are never written back to disk, so anything
you build in Studio lasts only once it's exported there.

## Pick the exporter

| What | Exporter | Output |
|---|---|---|
| Effects, enemies, rigs: anything with attributes, tags, Motor6D C0/C1 or Humanoid properties | `tools/export_rbxm.luau` (`_G.exportRbxm`) | binary `.rbxm`, every property kept |
| GUIs and plain templates (`Hud.rbxmx`, `ItemTemplates`) | `tools/export_rbxmx.luau` (`_G.exportRbxmx`) | `.rbxmx` XML, readable diffs |

The rbxmx exporter writes only string, boolean and number attributes (the
`LintIgnore` marks), no tags, and only the properties in its `PROPS` list. Before
exporting a tree with it, check that the tree has no tags or other attribute types.

## Steps

1. Run `tools/ensure_receiver.sh`. Every session shares one receiver on
   127.0.0.1:8766, so don't start a second one. Post under a name unique to your
   task (`Effects_<Group>`, `Hud_<task>`): the file lands in `tools/frag/<name>`,
   and a shared name gets overwritten by a parallel agent. The receiver runs from
   the main checkout, so from a worktree the file lands in
   `/home/cj/roblox/martial-world/tools/frag/`, not yours: pass that dir as `--frag`
   to `ui_lint.py`, `export_check.py` and `ui_margin.py`.
2. Install the exporter: load the `.luau` file through `execute_luau`, which sets
   the `_G` function. Load it over HTTP (the `sandbox-studio` skill).
3. Post the tree:
   - Binary: `HttpService:PostAsync("http://127.0.0.1:8766/<name>.rbxm", _G.exportRbxm("<path>", "<RealRootName>"))`
     writes `tools/frag/<name>.rbxm`. The second argument renames the root in the
     file only, so a staging copy can be exported under the real name.
   - XML: `HttpService:PostAsync("http://127.0.0.1:8766/<name>", _G.exportRbxmx("<path>"))`
     writes `tools/frag/<name>.xml`. Wrap it in `<roblox version="4">`...`</roblox>`,
     rename the root item's `Name` back if you exported a staging copy, and write
     it to `assets/<File>.rbxmx`.
   - `execute_luau` refuses posts over 1 MB, so export only your subtree or group.
     For a shared `.rbxmx` (Hud), splice your subtree into the file: the other
     elements keep their attributes. A full export from a sandbox drops marks
     (`LintIgnore`) that other sessions added.
4. Check the result.
   - For XML, read the `git diff`: it should show only what you meant to change.
   - For a binary file, `rojo build` a tiny project that maps it and grep the
     output for every group and template that should be there, including other
     agents'.
5. Property-only changes (an `Image` id, `SliceCenter`, a colour) can go straight
   into an `.rbxmx` on disk. Rojo patches them in without duplicating anything.

## Shared files

`assets/Effects.rbxm`, `assets/Enemies.rbxm`, `assets/Hud.rbxmx` and
`assets/SoundGroups/SFX.rbxmx` hold many agents' work. Each has one owner at a
time; your brief says whether that's you.
- Never copy a whole export over a shared binary.
  - Effects: export a temporary folder holding only a clone of your group, as
    `Effects`, posted as `Effects_<Group>.rbxm`, then run
    `python3 tools/effects_merge.py tools/frag/Effects_<Group>.rbxm <Group>`. It
    replaces or adds only that group. More in `docs/vfx/toolkit/export.md`.
  - Enemies: build in your own `ServerStorage._Roster<Group>` and commit HEAD's
    file plus your template.
- If the brief names a lock dir for the file, take it before exporting and
  release it after the commit.
- Merge into a shared binary only right before you commit, and commit a blob
  built from HEAD plus your part (the `shared-commit` skill). A merge left in
  the working tree gets swept into another session's commit.

## Staging (Rojo-connected places only)

This applies to the user's Studios and the test build. Sandboxes have no Rojo
and skip it.

Never create, delete, rename or reparent anything inside a Rojo-managed instance
there. Rojo tracks only what it made, so a hand-built copy sits beside the
synced one and scripts find the wrong one (`Hud:110: attempt to index nil`).
Changing properties of existing instances in place is fine. For structural work:
1. Clone the managed root to an unmapped sibling, e.g.
   `local s = StarterGui.Hud:Clone(); s.Name = "_StagingHud"; s.Parent = StarterGui`.
   If the real one is visible, hide it while you work (`Hud.Enabled = false`).
2. Make and preview every change in the staging copy. Any placement or build
   script must target the staging copy, not the real root.
3. Export it under the real root name (steps above) and write it to `assets/`.
4. Destroy the staging copy and restore the real one (`Enabled = true`).
   StarterGui copies leftovers into every player.
5. Check that the real root now has your change, once.
   - If Rojo isn't connected, ask the user to connect it. Don't rebuild by hand.
   - If you see duplicates, have the user reconnect Rojo. Run
     `tools/find_duplicates.luau` only when the user asks for a duplicate check.
