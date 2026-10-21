# Escape!

Roblox game synced with Rojo (`default.project.json`; `rojo serve` is run by the user). Tools are pinned in `rokit.toml`.

## Workflow

- Git is the only work history; no session logs or notes. Start with `git log` and `git status` to see what was done and what comes next.
- The user playtests. Don't write or run tests, start play sessions, or verify through the MCP unless explicitly asked. Note what's untested instead of claiming it works.
- Commit each finished feature as one revertible commit, staging only that feature's files. Don't split a feature into tiny commits or lump several features together. The message's subject says what changed; its body says why, plus anything left unfinished or next.

## Docs

- `docs/README.md` maps every system to its files, remotes and tuning; `docs/systems/` has one short design doc per system; `docs/core-loop.md` is the north star and says when each system is introduced. Read them to find your way. Progression and per-stage difficulty are tuned in `src/shared/Pacing.luau`.
- Every commit leaves the docs at least as good as it found them. In the same commit, update every doc the change touches: behaviour, design intent, files, remotes, tuning knobs and known gaps (add new gaps, remove fixed ones). Also fix anything stale or unclear you ran into while reading. A design decision the user makes in conversation goes into the matching doc, so it isn't lost when the session ends.

## UI work

- For any UI work (look, layout, flow, icons, HUD, windows), spawn the `ui-designer` subagent unless it is already running for this task. Don't do the UI work inline.

## VFX work

- For visual effects (casts, hits, auras, breakthroughs, ambient and world effects), spawn the `vfx` subagent unless it is already running for this task. It works from reference videos and builds layered emissions from the user's VFX plugin (vfxia), its asset library and Game Module; how effects should look is in `docs/vfx/style.md`.
- Effects keep their plugin settings in attributes, so export them with `tools/export_rbxm.luau` (binary, keeps attributes and tags), not `tools/export_rbxmx.luau`.
- Sky-scale world-event and anomaly effects (the sky splitting, clouds parting or spiralling, violet and golden cloud mists, treasure births, heavenly light pillars, tribulation clouds) go to the `world-fx` subagent instead. It follows the vfx method, builds for far, mid and close, and checks every placement upright through the real event code path. `vfx` and `world-fx` both export `assets/Effects.rbxm`, so never run them at the same time on it.

## Enemy work

- For a new beast or boss, a beast rework or a difficulty pass, spawn the `enemy-designer` subagent. It sends a design sheet (attacks, animation, sounds, difficulty math), then returns briefs for `modeler` (the body) and `vfx` (attack, hit and death effects). Run those two with its briefs (in parallel when they don't share files), then spawn `enemy-designer` again with their results to rig, animate, wire sounds, add the def and tune.

## Map work

- For map layout, landforms, set dressing, detailing and lighting/atmosphere, spawn the `map-builder` subagent unless it is already running for this task. It plans against `docs/systems/map.md` (layout, art direction, and the instances and coordinates scripts depend on), builds meshes through the modeler's Blender pipeline and dresses from `ServerStorage.AssetLibrary`. Single meshes and props go to the `modeler` subagent; particle and beam effects go to `vfx`.
- `Workspace.Map` lives only in the place file, not in Rojo. Studio-side map changes aren't in git, so commit messages list them and the user saves the place.
- Structurally hard builds (multi-part buildings, roofs, stairs, bridges, arches, things players walk through or under, tight fits with rock or terrain, trees near structures) get a second pass by the agent and are then tagged `NeedsHandPass` with a `HandPassReason`, listed in the report, so the user can fix them by hand (`T.handpass()` in the POI tour). Never ship one silently.

## Parallel agents

Split big map or content passes across several subagents when the parts don't share state. All of them edit the same open Studio place and the same repo, so:
- Give each agent sole ownership: its own folders in Studio (e.g. a staging area off the map, or `ServerStorage.<Thing>`) and its own files. One owner at a time for terrain, `wilds_layout.luau`, `dress_wilds.luau` and any Rojo-mapped asset.
- Build in parallel, place in series. Builders make self-contained, tagged templates or prefabs away from the map; one map-builder places them, once the layout and terrain they sit on are done.
- No one starts Play or touches terrain outside their own task. If Studio flips into Play, keep working on files and wait.
- Commit immediately after staging, and only your own files and hunks. For shared docs (`map.md`, `README.md`), build the index blob from `git show HEAD:` plus your hunk. Check `git diff --cached --name-only` first. Two commits have been swallowed by parallel sessions so far.
- Split by zone only when the zones don't share code or layout files.

## Studio instances

- Create persistent instances (RemoteEvents, GUIs, parts, folders, templates) with the Roblox Studio MCP in edit mode. Game scripts reference them; don't build them at runtime with `Instance.new` or "create if missing" fallbacks.
- Runtime cloning of MCP-authored templates and short-lived effects is fine.
- Rojo doesn't write Studio edits back to disk. To keep MCP-authored instances in git, export them to `.rbxmx` under `assets/` and map them in `default.project.json`.
- Edit scripts on disk under `src/`, not in Studio.
- Never create, delete, rename or reparent anything inside a Rojo-managed instance (anything mapped in `default.project.json`). Rojo only tracks the instances it made, so when the exported `.rbxmx` syncs it adds its own copy next to one built by hand, and scripts find the wrong one with `FindFirstChild` (e.g. `Hud:110: attempt to index nil`). Structural changes go through staging instead:
  1. Clone the managed root to an unmapped sibling (e.g. `StarterGui._StagingHud`, `ServerStorage._StagingItemTemplates`). Hide the real one while previewing if it's visible (`Enabled = false`), and restore it afterwards.
  2. Make and preview the changes in the staging copy.
  3. Export the staging copy, rename its root back to the real name in the XML, and write the `.rbxmx`.
  4. Destroy the staging copy. Rojo patches its own instance from the file, so only one copy ever exists. If Rojo isn't connected, have the user connect it; don't rebuild the change by hand.

  Never leave a staging copy behind (StarterGui copies them into every player). Changing properties of existing managed instances in place is fine, as is writing property changes straight into the `.rbxmx`.
- Never delete, replace or rebuild over Studio instances you didn't create in this task, even ones that look like leaked copies of your own work: they may be the user's hand edits (a vfx agent wiped the user's hand-placed aura sigils this way). Ask first. Before a builder regenerates a template, check the live one for changes that aren't in the builder and report them.
- Run `tools/find_duplicates.luau` (through `execute_luau`) only when the user explicitly asks for a duplicate check. It is not a prerequisite for committing.

## Luau pitfalls

- A statement starting with `(` (e.g. `(x :: TextLabel).Text = ...`) right after a line ending in a call, identifier or `)` fails to load with "Ambiguous syntax: this looks like an argument list for a function call". This keeps recurring. End the previous line with `;`, or assign the cast to a local first.
- Placing a cloned template (world-event beacons, treasures, relics, effects, props): keep the template's pivot rotation, `model:PivotTo(CFrame.new(spot) * template:GetPivot().Rotation)` (add a random yaw on top if you want one). Never `PivotTo(CFrame.new(spot))`: when the pivot is a part turned upright (a cylinder lying on X, the usual pillar), dropping its rotation lays the whole model on its side and swings its offset parts sideways. This has caused sideways light pillars more than once (the Ginseng beacon, `dc61d6f`; world treasures). When authoring a template, prefer an upright pivot: `PrimaryPart` nil with an identity-rotation `WorldPivot` at the ground point, and stand cylinders up inside the model.
- Run `tools/check.sh` (luau-lsp, pinned in `rokit.toml`) after editing scripts. It reports only load-breaking errors (syntax errors), and those must be fixed. `tools/check.sh --all` shows every lint and type warning. Don't spend time on those unless one is severe (a real bug or a crash); most are noise without Roblox type definitions.
