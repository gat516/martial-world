# Orchestrating agents

For the main session, or any agent that spawns or merges for others. Subagents
doing one task don't need this file: AGENTS.md has what they need.

## Test build

The test build is a local, never-published Studio place, `mw-sandbox-test`,
built from the `test` checkout and kept live by Rojo. Every dev builds their own
on their own machine; nothing about it is tied to the owner's account or computer.
It replaces publishing the testbed as its own experience, which didn't work out
(user, 2026-10-22).
- **The test checkout** is a worktree of `test` at `../martial-world-test`. Create it
  once: `git worktree add ../martial-world-test test`.
- **Opening it**, from inside the test checkout: run `tools/sandbox.sh open test`,
  then `rojo serve test.project.json` (port 34873), and the dev connects the Rojo
  plugin in that window to port 34873 (one click). Without WSL (`sandbox.sh` drives
  Windows Studio from WSL), run `rojo build test.project.json -o mw-sandbox-test.rbxl`
  and open that file in Studio. From then on, every merge into the test checkout
  syncs into the open build. Reopen it the same way after a restart. Nothing in it
  is saved: everything lasting lives in git and `assets/`.
- **One test build per machine,** shared by every agent on it. `tools/sandbox.sh
  prune` never closes it. Agents don't close it and don't build in it: they build in
  their own sandbox, and their work reaches the test build only through a merge.
  Rojo is connected there, so AGENTS.md's staging rules apply.
- **Porting from an agent sandbox:** the agent exports its work to `assets/` and
  commits it on its feature branch. The orchestrator merges that branch into the
  test checkout, and Rojo brings it into the test build. Never copy and paste
  between Studios.
- It runs `test.project.json` like the old testbed, so `Config.TESTBED` is true
  there, with the same arena and stubs ([testbed](../systems/testbed.md)).

## Merging and pushing

- When a feature is finished, merge its branch into the local test checkout
  (`git -C ../martial-world-test merge --no-ff <feature>`). Pull `origin/test` into
  the test checkout first, so nobody else's pushed work is lost. Resolve conflicts
  in the test checkout. For `assets/Effects.rbxm`, rebuild it with
  `tools/effects_merge.py` from `test`'s copy plus your group.
- The dev playtests there. Fixes go on the same feature branch and are merged
  again. Once the dev approves, push: `git -C ../martial-world-test push origin test`.
  If they drop the feature, reset the test checkout to `origin/test`.
- Only the owner (gat516) merges `test` into `main` and publishes. GitHub doesn't
  enforce this yet (the plan is a ruleset on `main` that blocks pushes, force-pushes
  and deletion, with only the Repository admin role allowed past it), so it holds
  by convention.

## Sandboxes

Agents that build or preview without the map (vfx, world-fx templates,
enemy-modeler, modeler props, animator, enemy-designer, ui-designer) work in a
sandbox Studio that the main session runs (user, 2026-10-22):
- Before spawning the agent, run `tools/sandbox.sh open <name>` from the agent's
  feature-branch checkout (it builds a fresh place from that checkout's
  `test.project.json`), wait for it in `list_roblox_studios`, and put its
  `studio_id` in the brief. The agent exports to `assets/`, leaves the sandbox clean,
  and never opens or closes one itself.
- A sandbox outlives its agents. When there's more work, start a fresh agent in the
  same sandbox (which saves the user re-clicking plugins such as vfxLib), and close
  it only when the work is done (`tools/sandbox.sh list` / `prune <hours>` for
  leftovers).
- Agents that export the same file (`assets/Effects.rbxm`) run one after another in
  the same sandbox, so each builds on the last one's export. Agents running at the
  same time each get their own sandbox.
- **vfx and world-fx sandboxes need one click from the user.** A fresh sandbox has
  no vfx library until someone clicks the vfxLib plugin button in it, and agents
  can't press plugin buttons. After opening one for vfx work, ask the user to click
  vfxLib in that window (`mw-sandbox-<name>`), check that the library answers
  (`_G.vfxLibrary.search("ring")` from `tools/vfx_library.luau` returns tiles), and
  only then spawn the agent.
- The user's Studios are for playing and for map work (`Workspace.Map` and
  `AssetLibrary` live only in the place file).

## How many at once

Before a multi-agent pass, say how many agents will run at once and how many
sandbox Studios that opens, on top of the user's own open Studios. Each Studio
takes a few GB of RAM, and the user's Studio has crashed under load. Ask the user
how much to run in parallel, unless they already said for this pass (user,
2026-10-22). Agents that run one after another share one sandbox.

**A fresh agent per item:** spawn a new subagent for each item of a pass (each boss,
each beast, each effect set) with a self-contained brief, instead of sending the
next item to an agent that has finished one (user, 2026-10-22). Long-lived agents
pile up context. Carry what the next agent needs in its brief or in the docs.

**Split big passes** across agents when the parts don't share state. Give each one
sole ownership of its Studio folders and files. Build in parallel and place in
series: builders make self-contained, tagged templates away from the map, and one
map-builder places them once the layout and terrain are done. Split by zone only
when the zones don't share code or layout files. Have one owner at a time for
terrain, `wilds_layout.luau`, `dress_wilds.luau` and any Rojo-mapped asset.

## Who does what

| Work | Agent | Notes |
|---|---|---|
| UI (look, layout, flow, icons, HUD, windows) | `ui-designer` | never inline |
| Effects (casts, hits, auras, breakthroughs, ambient) | `vfx` | from the vfxia library; it stops if the library can't be reached |
| Sky-scale world events (sky splitting, cloud mists, light pillars, tribulation clouds) | `world-fx` | never at the same time as `vfx` (both export `assets/Effects.rbxm`) |
| New beast or boss, rework, difficulty pass | `enemy-designer` | see below |
| Enemy and boss bodies | `enemy-modeler` | from the designer's brief |
| Enemy animation | `animator` | from each rig's `art/enemies/<group>/RIGS.md` |
| Map layout, landforms, dressing, lighting | `map-builder` | plans against [map](../systems/map.md) |
| Meshes, props, held weapons | `modeler` | Blender pipeline |

Modeling, VFX and animation agents (`modeler`, `enemy-modeler`, `vfx`, `world-fx`,
`animator`) run on Opus. Their frontmatter sets `model: opus`; don't override it
with Sonnet (user, 2026-10-22).

### The enemy pipeline

1. Spawn `enemy-designer`. It sends a short design card; for a boss that includes the
   signature mechanic, the ultimate, the phases and the difficulty tiers.
2. Once the user approves, it returns briefs with the contracts fixed up front:
   attack names, phase timings, effect cue names and the pose module's API.
3. Run everything at once: `enemy-modeler` (the body; skip it when the body is
   unchanged), `vfx`, `animator`, and the same `enemy-designer` session (via
   SendMessage, so it keeps its context) wiring the code against those contracts.
   The animator waits for the modeler only when joints change. The designer hooks in
   each delivery as it lands, then tunes and ships. Run in series, the Spirit Wolf
   took over an hour, mostly agents waiting on each other.
4. Keep enemy passes lean: vfx builds straight from the brief (no plan step, no
   reference research unless the user gave a link) and reuses existing enemy effects
   where they fit; animators reuse the shared planting solver and QA scripts; every
   agent checks numerically and leaves visual review to the user.
5. New or reworked fights go behind a `Config.TESTBED` flag; flip it for the main game
   only after the user approves.
6. The next enemy gets a fresh designer.
7. Shared-file hygiene for enemy passes (from the boss passes):
   - **Shared files and locks.** `assets/Enemies.rbxm` and `assets/Effects.rbxm` are
     shared across agents and sessions. Take the lock dir before exporting (the boss
     run used `scratchpad/locks/enemies-rbxm` and `effects-rbxm`), open a fresh
     sandbox after taking it, and check every group or template is still there
     afterwards: `rojo build` a tiny project that maps the file, then grep the output
     for the names.
   - **One owner per shared file.** In a parallel pass, name one owner up front for each
     file that several agents need, `EnemyAnimator.luau` above all. Put every attribute
     the client reads into the contract before anyone starts: skids are read from
     `AttackName`, while `Attack` keeps the parent's name.
   - **QA scripts** for animators are under `art/enemies/beasts/` and
     `art/enemies/quadrupeds/`. Check numerically, and capture a key frame in your own
     sandbox only where the numbers can't tell (step 4).
