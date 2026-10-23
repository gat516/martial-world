# Escape!

Roblox game synced with Rojo (`default.project.json`; `rojo serve` is run by the user). Tools are pinned in `rokit.toml`.

**Orchestrating** (spawning agents, sandboxes, merging into the test build,
picking which agent does what)? Read [docs/agents/orchestration.md](docs/agents/orchestration.md)
first. A subagent doing one task doesn't need it.

## Workflow

- Git is the only work history; no session logs or notes. Start with `git log` and `git status`.
- The user playtests. Don't write or run tests, start play sessions, or verify through the MCP unless explicitly asked. Note what's untested instead of claiming it works.
- Commit each finished feature as one revertible commit, staging only that feature's files. The subject says what changed; the body says why, plus anything unfinished or next.

## Branches

`main` is production (what's live). `test` is where all work lands first (user, 2026-10-22).
- Start each feature on its own branch off the latest `test` (`git fetch && git switch -c <feature> origin/test`), in its own worktree when other sessions share the repo.
- Only the owner (gat516) pushes or merges to `main`. Never push to `test` work the dev hasn't approved in the test build.

## Docs

`docs/README.md` maps every system to its files, remotes and tuning; `docs/systems/` has one design doc per system; `docs/core-loop.md` is the north star; [docs/world-overview.md](docs/world-overview.md) is the setting and zones in brief. Big systems are split: a core doc plus parts (`docs/enemies/<enemy>.md`, `docs/map/`, `docs/combat/`, `docs/vfx/toolkit/`...).
- **Read only what your task needs:** the core doc, then the one part you're working on. Don't read a whole folder.
- Every commit leaves the docs at least as good as it found them. In the same commit, update every doc the change touches (behaviour, design intent, files, remotes, tuning, known gaps) and fix anything stale you ran into. A design decision the user makes in conversation goes into the matching doc.
- Keep docs lean: current state and decisions, not history (git has it). A new item (enemy, area, effect set) gets its own part file and a line in its core doc's index.

## Testbed

The testbed is a baseplate arena (`test.project.json`, `Config.TESTBED` true; [testbed](docs/systems/testbed.md)). It runs locally as the test build, and agent sandboxes are built from it.
- **Shared, never forked.** Both projects map the same `src/` and `assets/`. A testbed difference is a `Config.TESTBED` check in the real code, never a copied script.
- **New mappings go in both projects.** Change a `$path` in `default.project.json`, make the same change in `test.project.json`, then run `python3 tools/check_testbed.py`.
- **Content moves through `assets/`**, never by hand (a new enemy is in both places once it's in `assets/Enemies.rbxm` and `Enemies.luau`). `Workspace.Map` and `AssetLibrary` are Studio-only.
- **Don't break its boot.** It has no `Workspace.Map`, peaks or wilds zones (only stubs). Code that waits on a map instance needs a stub in `test.project.json` or a `Config.TESTBED` guard.
- **Flag what to test there.** After a change to combat, enemy AI, attacks, techniques, events or animations, end the commit body with `Test build: <what to test>` and say so in your report.

## Studio

- **Sandbox agents** work only in the sandbox whose `studio_id` their brief gives. They never open or close Studios, never start Play, export to `assets/`, and leave it clean. If the brief has no sandbox, say so and stop.
- Create persistent instances (RemoteEvents, GUIs, parts, folders, templates) with the Roblox Studio MCP in edit mode. Game scripts reference them; don't build them at runtime with `Instance.new` or "create if missing" fallbacks. Runtime cloning of templates and short-lived effects is fine.
- Rojo doesn't write Studio edits back to disk. To keep MCP-authored instances, export them under `assets/` and map them. Effects keep plugin settings in attributes, so export them with `tools/export_rbxm.luau` (binary), not `export_rbxmx`. Edit scripts on disk under `src/`, not in Studio.
- **Never create, delete, rename or reparent anything inside a Rojo-managed instance** in a Rojo-connected place (the user's Studios, the test build). Rojo adds its own copy beside one built by hand, and scripts find the wrong one (`Hud:110: attempt to index nil`). Use staging instead:
  1. Clone the managed root to an unmapped sibling (e.g. `StarterGui._StagingHud`), and hide the real one while previewing if it's visible.
  2. Make and preview the changes in the staging copy.
  3. Export it, rename its root back to the real name in the file, and write it to `assets/`.
  4. Destroy the staging copy (StarterGui copies leftovers into every player). If Rojo isn't connected, have the user connect it; don't rebuild by hand.

  Changing properties of existing managed instances in place is fine. Sandboxes have no Rojo, so staging isn't needed there.
- **Never delete, replace or rebuild over instances you didn't create in this task**, even ones that look like leaked copies of your own work: they may be the user's hand edits. Ask first. Before regenerating a template, check the live one for changes that aren't in the builder and report them.
- `Workspace.Map` lives only in the place file: commit messages list Studio-side map changes, and the user saves the place. Structurally hard builds (buildings, roofs, stairs, bridges, arches, tight fits) get a second pass and are tagged `NeedsHandPass` with a `HandPassReason`, listed in the report.
- Run `tools/find_duplicates.luau` only when the user asks for a duplicate check.

## Committing alongside other sessions

Several sessions share the repo. Two commits have been swallowed so far.
- Commit right after staging, only your own files and hunks; check `git diff --cached --name-only` first. For shared docs, build the index blob from `git show HEAD:` plus your hunk, and rebuild it from the current HEAD right before committing (HEAD moves). After committing through a temporary `GIT_INDEX_FILE`, `git reset -- <your paths>` in the shared index.
- Binary shared files (`assets/Effects.rbxm`) can't be committed by hunk. Merge into the working file only right before you commit, and commit a blob built from HEAD plus your group (`EFFECTS_TARGET=<copy of HEAD's file> tools/effects_merge.py ...`, then `git update-index --cacheinfo`). A merge left in the working tree gets swept into another session's commit (46f7e1a).
- Edit scripts read the whole file before opening it for writing (`s = open(p).read()`, then `open(p, "w")`). Opening for writing first truncates it; this emptied `SFX.rbxmx` and `enemies.md` mid-pass. For big files, write to a temp file and rename it.
- No one starts Play or touches terrain outside their own task. If Studio flips into Play, keep working on files and wait.

## Uploading to Roblox

Every agent publishes its own assets; don't ask the user to upload or publish anything.
- Animations, audio and models: `python3 tools/upload_asset.py <animation|audio|model> <files>` uploads through Open Cloud, owned by the main game's group (772472600), grants the testbed universe Use on animations and audio, and prints the `rbxassetid://` ids. An animation file is a `.rbxm` whose root is one KeyframeSequence. Record the ids where the asset lives (the `Animation`/`Sound` instance, `art/.../README.md` or `assets.json`).
- Images (UI art, emitter textures): the Studio MCP's `upload_image` (Open Cloud would return a Decal).
- The Open Cloud key is in `~/.config/roblox/api_key`. Never read, print, copy or commit it; only the script touches it.

## Luau pitfalls

- A statement starting with `(` (e.g. `(x :: TextLabel).Text = ...`) right after a line ending in a call, identifier or `)` fails with "Ambiguous syntax". This keeps recurring. End the previous line with `;`, or assign the cast to a local first.
- Placing a cloned template: keep its pivot rotation, `model:PivotTo(CFrame.new(spot) * template:GetPivot().Rotation)` (add a random yaw on top if you want). Never `PivotTo(CFrame.new(spot))`: an upright-turned pivot part lays the model on its side (sideways light pillars more than once, `dc61d6f`). When authoring a template, prefer `PrimaryPart` nil with an identity-rotation `WorldPivot` at the ground point, with cylinders stood up inside the model.
- Run `tools/check.sh` (luau-lsp) after editing scripts. It reports only load-breaking errors, and those must be fixed. `tools/check.sh --all` shows every lint and type warning; most are noise without Roblox type definitions.
