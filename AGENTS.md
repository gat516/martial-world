# Escape!

Roblox game synced with Rojo (`default.project.json`; `rojo serve` is run by the user). Tools are pinned in `rokit.toml`.

## Workflow

- Git is the only work history; no session logs or notes. Start with `git log` and `git status` to see what was done and what comes next. Work starts from `test`, not `main` (see Branches).
- The user playtests. Don't write or run tests, start play sessions, or verify through the MCP unless explicitly asked. Note what's untested instead of claiming it works.
- Commit each finished feature as one revertible commit, staging only that feature's files. Don't split a feature into tiny commits or lump several features together. The message's subject says what changed; its body says why, plus anything left unfinished or next.

- Modeling, VFX and animation agents (`modeler`, `vfx`, `world-fx`, `animator`) run on Opus unless the user says otherwise; their frontmatter sets `model: opus`, so don't override it with Sonnet (user, 2026-10-22).

## Branches

`main` is production: what's live in Martial World. `test` is where all work lands first (user, 2026-10-22).
- **Only the owner (gat516) pushes or merges to `main`.** Agents and collaborators never commit to, push to, rebase or merge into `main`. A release is the owner merging `test` into `main`, then publishing the main place.
- **Everyone else pushes to `test` only.** Start each feature on its own branch off the latest `test` (`git fetch && git switch -c <feature> origin/test`), in its own worktree when other sessions share the repo. The one-commit-per-feature rule applies on that branch.
- **Done means playtested in the test build, then pushed to `test`.** When a feature is finished, merge its branch into the local test checkout (`git -C ../martial-world-test merge --no-ff <feature>`). Rojo syncs it into the test build, and the user playtests there and gives feedback. Fixes go on the same feature branch and get merged again. Once the user approves, push: `git -C ../martial-world-test push origin test`. If the user drops the feature, reset the test checkout to `origin/test`.
- **Never push unapproved work to `test`.** Pull `origin/test` into the test checkout before merging, so nobody else's pushed work is lost. Resolve conflicts in the test checkout. For `assets/Effects.rbxm`, rebuild it with `tools/effects_merge.py` from `test`'s copy plus your group, as in Parallel agents.
- **Not enforced yet.** GitHub doesn't block pushes to `main` yet. The plan is a ruleset on `main` that blocks pushes, force-pushes and deletion, with only the Repository admin role allowed past it. Until then, the rule holds by convention.

## Test build

The test build is a local, never-published Studio place: `mw-sandbox-test`, built from the `test` checkout and kept live by Rojo. It replaces publishing the testbed as its own experience, which didn't work out (user, 2026-10-22).
- **The test checkout** is a worktree of `test` at `../martial-world-test`. Create it once: `git worktree add ../martial-world-test test`.
- **Opening it**, from inside the test checkout: run `tools/sandbox.sh open test`, then `rojo serve test.project.json` (port 34873), and connect the Rojo plugin in that window to port 34873 (one click, by the user). From then on, every merge into the test checkout syncs into the open build. Reopen it the same way after a restart; nothing in it is saved, and everything lasting lives in git and `assets/`.
- **One test build at a time, shared by everyone.** `tools/sandbox.sh prune` never closes it. Agents don't close it, and don't build in it: they build in their own sandbox and come here only through a merge. Because Rojo is connected, the staging rules in Studio instances apply here.
- **Porting from an agent sandbox:** the agent exports its work to `assets/` and commits it on its feature branch. The orchestrator then merges that branch into the test checkout, and Rojo brings it into the test build. No copy and paste between Studios.
- It runs `test.project.json` like the old testbed, so `Config.TESTBED` is true there, with the same arena and stubs (see `docs/systems/testbed.md`).

## Docs

- `docs/README.md` maps every system to its files, remotes and tuning; `docs/systems/` has one short design doc per system; `docs/core-loop.md` is the north star and says when each system is introduced. Read them to find your way. Progression and per-stage difficulty are tuned in `src/shared/Pacing.luau`.
- Every commit leaves the docs at least as good as it found them. In the same commit, update every doc the change touches: behaviour, design intent, files, remotes, tuning knobs and known gaps (add new gaps, remove fixed ones). Also fix anything stale or unclear you ran into while reading. A design decision the user makes in conversation goes into the matching doc, so it isn't lost when the session ends.

## UI work

- For any UI work (look, layout, flow, icons, HUD, windows), spawn the `ui-designer` subagent unless it is already running for this task. Don't do the UI work inline.

## VFX work

- For visual effects (casts, hits, auras, breakthroughs, ambient and world effects), spawn the `vfx` subagent unless it is already running for this task. It works from reference videos and builds layered emissions from the user's VFX plugin (vfxia), its asset library and Game Module; how effects should look is in `docs/vfx/style.md`. It searches the library live (`tools/vfx_library.luau`); if the library can't be reached, it flags that and stops, with no workarounds (no falling back to the JSON index, old ids or hand-made textures).
- Effects keep their plugin settings in attributes, so export them with `tools/export_rbxm.luau` (binary, keeps attributes and tags), not `tools/export_rbxmx.luau`.
- Sky-scale world-event and anomaly effects (the sky splitting, clouds parting or spiralling, violet and golden cloud mists, treasure births, heavenly light pillars, tribulation clouds) go to the `world-fx` subagent instead. It follows the vfx method, builds for far, mid and close, and checks every placement upright through the real event code path. `vfx` and `world-fx` both export `assets/Effects.rbxm`, so never run them at the same time on it.

## Enemy work

- For a new beast or boss, a beast rework or a difficulty pass, spawn the `enemy-designer` subagent. It sends a short design card (look, behaviour, attacks; no balancing math). Once the user approves, it returns briefs for `modeler` (the body, built from Studio parts and rigged for animators; humanoids are stock R6 rigs; skip it when the body needs no change), `vfx` (attack, hit and death effects) and `animator`, with the contracts fixed up front: attack names, phase timings, effect cue names and the pose module's API.
- Then run everything at once: `modeler`, `vfx`, `animator` and the same `enemy-designer` session (SendMessage, so it keeps its context) wiring the code against those contracts. The animator only waits for the modeler when joints change. The designer hooks in each delivery as it lands, then tunes and ships. The next enemy gets a fresh designer (see "Fresh agents per item"). (The Spirit Wolf ran these in series and took over an hour; most of it was agents waiting on each other.)
- Keep enemy passes lean: vfx builds straight from the brief (no plan step, no reference research unless the user gave a link) and reuses existing enemy effects where they fit; animators reuse the shared planting solver and QA scripts; every agent checks numerically and leaves visual review to the user.
- New or reworked fights go to the testbed first: the new behaviour sits behind a flag that is on only in the testbed (`Config.TESTBED`), so the user fights it there before it ships. Flip the flag for the main game only after the user approves.
- Enemy animation (cycles, attack windups, stagger, death, on beasts or R6 humanoids) goes to the `animator` subagent. It works from each rig's `art/enemies/<group>/RIGS.md` and the bear/tiger reference in `docs/reference/animation/`.

## Testbed

The testbed is a baseplate arena where the user fights spawned beasts and tests animations and events. It runs this repo's code through `test.project.json` (`rojo serve test.project.json`, port 34873; see `docs/systems/testbed.md`). It's no longer published as its own experience: it runs locally as the test build (see Test build), and agent sandboxes are built from it too. Keep it in sync:
- **Shared, never forked.** Both projects map the same `src/` and `assets/`, so code and exported assets sync on their own. A testbed difference is a `Config.TESTBED` check in the real code, never a copied script.
- **New mappings go in both projects.** When you add or change a `$path` in `default.project.json`, make the same change in `test.project.json`, then run `python3 tools/check_testbed.py`.
- **Content moves through `assets/`, never by hand.** Anything that needs to exist in both places (a new enemy body, effect, item or template) gets exported to `assets/` and mapped, whichever place it was built in. New enemies are in both places once they're in `assets/Enemies.rbxm` and `Enemies.luau`. Don't copy and paste between places. Studio-only content (`Workspace.Map`, `AssetLibrary`) doesn't move.
- **Don't break its boot.** The testbed has no `Workspace.Map`, peaks or wilds zones (only the stubs in `test.project.json`). New code that waits on a map instance (`WaitForChild`, or `workspace.Map...` when a module loads) needs a stub in `test.project.json` or a `Config.TESTBED` guard.
- **Flag what to test there.** After a change that needs testing in the testbed (combat, enemy AI, attacks, enemies, techniques, events, animations), end the commit body with `Test build: <what to test>`, and say so in your report. The orchestrator merges the branch into the test checkout, and the user plays it there. Nobody publishes the testbed.

## Map work

- For map layout, landforms, set dressing, detailing and lighting/atmosphere, spawn the `map-builder` subagent unless it is already running for this task. It plans against `docs/systems/map.md` (layout, art direction, and the instances and coordinates scripts depend on), builds meshes through the modeler's Blender pipeline and dresses from `ServerStorage.AssetLibrary`. Single meshes and props go to the `modeler` subagent; particle and beam effects go to `vfx`.
- `Workspace.Map` lives only in the place file, not in Rojo. Studio-side map changes aren't in git, so commit messages list them and the user saves the place.
- Structurally hard builds (multi-part buildings, roofs, stairs, bridges, arches, things players walk through or under, tight fits with rock or terrain, trees near structures) get a second pass by the agent and are then tagged `NeedsHandPass` with a `HandPassReason`, listed in the report, so the user can fix them by hand (`T.handpass()` in the POI tour). Never ship one silently.

## Fresh agents per item

Before a multi-agent pass, the orchestrator says how many agents will run at once and how many sandbox Studios that opens, on top of the user's own open Studios. Each Studio is a few GB of RAM, and the user's Studio has crashed under load. It asks the user how much to run in parallel, unless they already said for this pass (user, 2026-10-22). Agents that run one after another share one sandbox.

Spawn a new subagent for each item of a pass (each boss, each beast, each effect set), with a self-contained brief, instead of sending the next item to an agent that has finished one (user, 2026-10-22). A long-lived agent piles up context and tokens. Carry anything the next agent needs in its brief or the docs. This applies to every subagent type.

## Parallel agents

Split big map or content passes across several subagents when the parts don't share state. All of them edit the same open Studio place and the same repo, so:
- Give each agent sole ownership: its own folders in Studio (e.g. a staging area off the map, or `ServerStorage.<Thing>`) and its own files. One owner at a time for terrain, `wilds_layout.luau`, `dress_wilds.luau` and any Rojo-mapped asset.
- Build in parallel, place in series. Builders make self-contained, tagged templates or prefabs away from the map; one map-builder places them, once the layout and terrain they sit on are done.
- No one starts Play or touches terrain outside their own task. If Studio flips into Play, keep working on files and wait.
- Commit immediately after staging, and only your own files and hunks. For shared docs (`map.md`, `README.md`), build the index blob from `git show HEAD:` plus your hunk. Check `git diff --cached --name-only` first. After committing through a temporary `GIT_INDEX_FILE`, `git reset -- <your paths>` in the shared index, or it keeps the old blobs as staged reverts. Two commits have been swallowed by parallel sessions so far.
- Split by zone only when the zones don't share code or layout files.
- Binary shared files (`assets/Effects.rbxm`) can't be committed by hunk, and a merge left in the working tree gets swept into another session's commit (the Jade Jiao's templates landed in the Golden Toad cut, 46f7e1a). Merge into the working file only right before you commit, and commit a blob built from HEAD plus your group (`EFFECTS_TARGET=<copy of HEAD's file> tools/effects_merge.py ...`, then `git update-index --cacheinfo`). HEAD can move while you work: rebuild every shared doc from the current HEAD plus your hunk right before committing, and diff it against HEAD.
- Edit scripts read the whole file before opening it for writing: `s = open(p).read()`, then `open(p, "w")`. Never open a file for writing first (`with open(p, "w") as f: ... open(p).read()`), which truncates it. On 2026-10-22 this emptied `SFX.rbxmx` and `docs/systems/enemies.md` mid-pass, and other agents' uncommitted hunks were lost. Write to a temp file and rename for big files.

## Studio instances

- Agents that build or preview in Studio without needing the map (vfx, world-fx templates, modeler enemy bodies and props, animator, enemy-designer, ui-designer) work in a sandbox Studio, and the main session runs the sandboxes (user, 2026-10-22). Before spawning an agent it runs `tools/sandbox.sh open <name>` from the agent's feature-branch checkout (a fresh place built from that checkout's `test.project.json`; the script builds whichever checkout it lives in), waits for it in `list_roblox_studios`, and puts its `studio_id` in the brief. The agent exports to `assets/`, leaves the sandbox clean, and never opens or closes one itself. A sandbox outlives its agents: when there's more work, the main session starts a fresh agent in the same sandbox (which saves the user re-clicking plugins such as vfxLib), and closes it only when the work is done (`tools/sandbox.sh list` / `prune <hours>` for leftovers). Agents that export the same file (`assets/Effects.rbxm`) run one after another, in the same sandbox, so each one builds on the last one's export. **vfx and world-fx sandboxes need one click from the user:** a fresh sandbox has no vfx library until someone clicks the vfxLib plugin button in it (the plugin builds its library window on first open), and agents can't press plugin buttons. So whoever orchestrates (the main session, or an agent that spawns vfx agents, such as the enemy-designer) asks the user, after opening one for vfx work, to click vfxLib in that window (named `mw-sandbox-<name>`), checks the library answers (`_G.vfxLibrary.search("ring")` from `tools/vfx_library.luau` returns tiles), and only then spawns the agent. Other agent types need no click. Agents running at the same time each get their own sandbox, so they never block each other or the user. The user's Studios are for playing and for map work (`Workspace.Map`, `AssetLibrary` live only in the place file). Rojo isn't connected in a sandbox, so the staging steps below aren't needed there.

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

## Uploading to Roblox

Every agent publishes its own assets; don't ask the user to upload or publish anything.
- Animations, audio and models: `python3 tools/upload_asset.py <animation|audio|model> <files>` uploads through Open Cloud, owned by the main game's group (772472600), grants the testbed universe Use on animations and audio so they play in both places, and prints the `rbxassetid://` ids. An animation file is a `.rbxm` whose root is one KeyframeSequence (see the script's help for splitting a folder of clips). Record the ids where the asset lives (the `Animation`/`Sound` instance, `art/.../README.md` or `assets.json`).
- Images (UI art, emitter textures): the Studio MCP's `upload_image`, as the ui-designer does (it returns the image id; Open Cloud would return a Decal).
- The Open Cloud key is in `~/.config/roblox/api_key`, outside the repo. Never read, print, copy or commit it; only the script touches it.

## Luau pitfalls

- A statement starting with `(` (e.g. `(x :: TextLabel).Text = ...`) right after a line ending in a call, identifier or `)` fails to load with "Ambiguous syntax: this looks like an argument list for a function call". This keeps recurring. End the previous line with `;`, or assign the cast to a local first.
- Placing a cloned template (world-event beacons, treasures, relics, effects, props): keep the template's pivot rotation, `model:PivotTo(CFrame.new(spot) * template:GetPivot().Rotation)` (add a random yaw on top if you want one). Never `PivotTo(CFrame.new(spot))`: when the pivot is a part turned upright (a cylinder lying on X, the usual pillar), dropping its rotation lays the whole model on its side and swings its offset parts sideways. This has caused sideways light pillars more than once (the Ginseng beacon, `dc61d6f`; world treasures). When authoring a template, prefer an upright pivot: `PrimaryPart` nil with an identity-rotation `WorldPivot` at the ground point, and stand cylinders up inside the model.
- Run `tools/check.sh` (luau-lsp, pinned in `rokit.toml`) after editing scripts. It reports only load-breaking errors (syntax errors), and those must be fixed. `tools/check.sh --all` shows every lint and type warning. Don't spend time on those unless one is severe (a real bug or a crash); most are noise without Roblox type definitions.
