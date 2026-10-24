# Escape!

Roblox game synced with Rojo (`default.project.json`; `rojo serve` is run by the user). Tools are pinned in `rokit.toml`.

**Orchestrating** (spawning agents, sandboxes, merging into the test build,
picking which agent does what)? Read [docs/agents/orchestration.md](docs/agents/orchestration.md)
first. A subagent doing one task doesn't need it.

## Workflow

- Git is the only work history; no session logs or notes. Start with `git log` and `git status`.
- The user playtests. Don't write or run tests, start play sessions, or verify through the MCP unless explicitly asked. Note what's untested instead of claiming it works.
- Commit each finished feature as one revertible commit, staging only that feature's files. The subject says what changed; the body says why, plus anything unfinished or next.
- Visual work (bodies, props, clips, effects, UI, map) goes through the `visual-gate` skill: the discipline's lint to zero FAIL, one contact sheet, a `visual-critic` round, then the report quotes the verdict. Briefs follow [docs/agents/briefs.md](docs/agents/briefs.md). Subagents post a `## Status:` line at each phase; the user watches them with `tools/agent_feed.sh`.

## Token budget

Every turn re-sends the whole context, so anything that enters it is paid for again on every later turn. Subagent runs are about three quarters of the project's spend (`python3 tools/token_report.py`).
- **Captures cost the most.** A Studio `screen_capture` is ~1.7k tokens and stays for the rest of the run; map and vfx runs have averaged 20-30. Check by numbers first (positions, bounds, `AbsolutePosition`, raycasts) and capture only to confirm a look, once per change, not after each tweak. Give `blender__look` a small `max_size`. Don't Read back images you've already seen.
- **Read narrowly.** Grep for the spot (`grep -n ... | head`), then read about 60 lines around it (Read with `offset`/`limit`, or `sed -n 'a,bp'`); never `cat` or `sed` a whole script or doc. `sed -n` dumps were a quarter of all Bash output in the visual runs. Read a doc's index and the one part you need. Don't re-read what you just wrote or read.
- **Scripts go in files.** A Python or Luau helper you'll run more than once goes in a scratch file (or `tools/`, if `docs/tools.md` doesn't already list one) and is run by path; each inline heredoc stays in context for the rest of the run. Small edits use Edit, not a Python rewrite script.
- **Keep output short.** Trim command output with `tail`, `head` or `grep`; have Luau and Python print a summary, not instance-tree dumps.
- **One deliverable per run.** When a run has grown long (dozens of captures, 100+ turns), commit, then hand back with what's next instead of pushing on; a fresh agent picks it up from the branch.

## Branches

`main` is production (what's live). `test` is where all work lands first (user, 2026-10-22).
- Start each feature on its own branch off the latest `test` (`git fetch && git switch -c <feature> origin/test`), Make a worktree only when agents run in parallel; one agent, or agents running one after another, share a single checkout (user, 2026-10-23).
- Remove the worktree and branch once the feature is pushed to `test` or dropped (`git worktree remove <path> && git branch -D <feature>`). Nothing else cleans them up.
- Only the owner (gat516) pushes or merges to `main`. Never push to `test` work the dev hasn't approved in the test build.

## Docs

`docs/README.md` maps every system to its files, remotes and tuning; `docs/systems/` has one design doc per system; `docs/core-loop.md` is the north star; [docs/world-overview.md](docs/world-overview.md) is the setting and zones in brief. Big systems are split: a core doc plus parts (`docs/enemies/<enemy>.md`, `docs/map/`, `docs/combat/`, `docs/vfx/toolkit/`...).
- **Read only what your task needs:** the core doc, then the one part you're working on. Don't read a whole folder.
- Every commit leaves the docs at least as good as it found them. In the same commit, update every doc the change touches (behaviour, design intent, files, remotes, tuning, known gaps) and fix anything stale you ran into. A design decision the user makes in conversation goes into the matching doc.
- **New systems feed the heart demon (user, 2026-10-23, "this is important").** A new system or mechanic that reflects how someone plays (fighting, gardening, building, surging, dying, banking, sect work...) adds a counter and a question or answer to the heart-demon trial in the same commit ([heart-demon](docs/systems/heart-demon.md#keeping-it-current)).
- **Anything that can change progression speed goes through the progression designer (user, 2026-10-24).** A new mechanic, item, drop, reward, multiplier, spawn or respawn change that could speed up or slow down cultivation gets a `progression-designer` pass (the pacing model re-run, `docs/systems/progression-rules.md` updated) before it merges into `test`. Say so in the report if you couldn't.
- Keep docs lean: current state and decisions, not history (git has it). A new item (enemy, area, effect set) gets its own part file and a line in its core doc's index.

## Testbed

The testbed is a baseplate arena (`test.project.json`, `Config.TESTBED` true; [testbed](docs/systems/testbed.md)). It runs locally as the test build, and agent sandboxes are built from it.
- **Shared, never forked.** Both projects map the same `src/` and `assets/`. A testbed difference is a `Config.TESTBED` check in the real code, never a copied script.
- **New mappings go in both projects.** Change a `$path` in `default.project.json`, make the same change in `test.project.json`, then run `python3 tools/check_testbed.py`.
- **Content moves through `assets/`**, never by hand (a new enemy is in both places once it's in `assets/Enemies.rbxm` and `Enemies.luau`). `Workspace.Map` and `AssetLibrary` are Studio-only.
- **Don't break its boot.** It has no `Workspace.Map`, peaks or wilds zones (only stubs). Code that waits on a map instance needs a stub in `test.project.json` or a `Config.TESTBED` guard.
- **Flag what to test there.** After a change to combat, enemy AI, attacks, techniques, events or animations, end the commit body with `Test build: <what to test>` and say so in your report.

## Studio

- **Sandboxes only for parallel work.** Agents running one at a time use the Studio, Blender and checkout already open. A new sandbox (Studio, Blender window, worktree) is for an agent running alongside another, or when nothing is open. At most 4 Blenders at once, all visible (user, 2026-10-23).
- **Sandbox agents** work only in the sandbox whose `studio_id` their brief gives. They never open or close Studios, never start Play, export to `assets/`, and leave it clean. If the brief has no sandbox, say so and stop. Details: the `sandbox-studio` skill.
- Create persistent instances (RemoteEvents, GUIs, parts, folders, templates) with the Roblox Studio MCP in edit mode. Game scripts reference them; don't build them at runtime with `Instance.new` or "create if missing" fallbacks. Runtime cloning of templates and short-lived effects is fine.
- Rojo doesn't write Studio edits back to disk. To keep MCP-authored instances, export them under `assets/` and map them (the `studio-export` skill: binary `export_rbxm` for anything with attributes, tags or rigs). Edit scripts on disk under `src/`, not in Studio.
- **Never create, delete, rename or reparent anything inside a Rojo-managed instance** in a Rojo-connected place (the user's Studios, the test build). Rojo adds its own copy beside one built by hand, and scripts find the wrong one (`Hud:110: attempt to index nil`). Use a staging copy (the `studio-export` skill). Changing properties of existing managed instances in place is fine. Sandboxes have no Rojo, so staging isn't needed there.
- **Never delete, replace or rebuild over instances you didn't create in this task**, even ones that look like leaked copies of your own work: they may be the user's hand edits. Ask first. Before regenerating a template, check the live one for changes that aren't in the builder and report them.
- `Workspace.Map` lives only in the place file: commit messages list Studio-side map changes, and the user saves the place. Structurally hard builds (buildings, roofs, stairs, bridges, arches, tight fits) get a second pass and are tagged `NeedsHandPass` with a `HandPassReason`, listed in the report.
- Run `tools/find_duplicates.luau` only when the user asks for a duplicate check.

## Committing alongside other sessions

Several sessions share the repo, and two commits have been swallowed so far. Follow the `shared-commit` skill for every commit.
- Commit right after staging, only your own files and hunks (`git diff --cached --name-only` first; never `git add -A`). Shared docs and binaries (`assets/Effects.rbxm`) go in as a blob built from HEAD plus your change.
- Edit scripts read the whole file before opening it for writing (`s = open(p).read()`, then `open(p, "w")`). Opening for writing first truncates it; this emptied `SFX.rbxmx` and `enemies.md` mid-pass.
- No one starts Play or touches terrain outside their own task. If Studio flips into Play, keep working on files and wait.

## Uploading to Roblox

Every agent publishes its own assets; don't ask the user to upload or publish anything. Animations, audio and models go through `tools/upload_asset.py`, and images through the Studio MCP's `upload_image` (the `upload-asset` skill). The Open Cloud key is in `~/.config/roblox/api_key`. Never read, print, copy or commit it; only the script touches it.

## Skills and agents

Shared procedures live in `.claude/skills/` (`sandbox-studio`, `studio-export`, `upload-asset`, `shared-commit`, `mesh-pipeline`, `vfx-method`, `agent-report`), and each agent in `.claude/agents/` preloads the ones it uses on every task. An agent file holds its role, its taste and the rules that always apply. Situational lessons go in the system's docs. `docs-keeper` (`/tidy-docs`) keeps all of this lean; `python3 tools/docs_lint.py` finds broken links, stale paths, duplicates and over-budget files.

## Luau pitfalls

- A statement starting with `(` (e.g. `(x :: TextLabel).Text = ...`) right after a line ending in a call, identifier or `)` fails with "Ambiguous syntax". This keeps recurring. End the previous line with `;`, or assign the cast to a local first.
- Placing a cloned template: keep its pivot rotation, `model:PivotTo(CFrame.new(spot) * template:GetPivot().Rotation)` (add a random yaw on top if you want). Never `PivotTo(CFrame.new(spot))`: an upright-turned pivot part lays the model on its side (sideways light pillars more than once, `dc61d6f`). When authoring a template, prefer `PrimaryPart` nil with an identity-rotation `WorldPivot` at the ground point, with cylinders stood up inside the model.
- Never name a child (module, folder, instance) after an Instance property (`Name`, `Parent`, `Size`...): `script.Parent.Tabs.Name` is the folder's name, not the child, and `require` gets a string (the join screen failed to load, 2026-10-24). Rename it, or use `FindFirstChild("Name")`.
- Run `tools/check.sh` (luau-lsp) after editing scripts. It reports only load-breaking errors, and those must be fixed. `tools/check.sh --all` shows every lint and type warning; most are noise without Roblox type definitions. Neither catches an undefined global: run `tools/check.sh --all | grep "Unknown global"` (only Roblox built-ins should be left).
- After merging several branches, scan for unknown globals and require cycles before pushing (two merges broke the client, `c3823d6`).
