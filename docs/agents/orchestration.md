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
- **Tear down** once the feature is pushed or dropped: `git worktree remove
  ../martial-world-<feature>` and `git branch -D <feature>` (`-D` because the
  branch was merged into `test`, not into whatever the main checkout has out).
  Nothing else removes them, and they pile up.
  `git worktree list` shows what's left; the test checkout always stays.
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
- Sandbox windows manage themselves (user, 2026-10-23): `open` and `close` tile
  every sandbox in a grid on the second monitor, a new one opens minimised when
  the others are, and they minimise and restore as a group. Don't move them by
  hand; `tools/sandbox.sh tile` re-lays them out.
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

### Shared files across parallel agents (2026-10-23/24)
- **One owner per mapped file at a time.** `assets/Hud.rbxmx` holds the vitals,
  hotbar, inventory, toast, build window and buttons, so HUD passes run one after
  another; pass extra HUD feedback to the agent that owns it rather than starting
  another.
- **A sandbox goes stale when `test` moves.** Before an agent exports a shared file,
  it merges `test` into its branch and rebuilds that root in its sandbox from the
  file on disk, or its export quietly undoes other merges. Open a fresh sandbox for
  each new pass (build it after the branch is up to date, not during a merge).
- **Id swaps race parallel work.** When one agent re-uploads art and swaps ids, a
  screen built at the same time keeps the old ids: after merging, grep the new
  files for ids that the swap replaced.
- **Rewards-style shared files**: an agent that must touch a subtree another agent
  owns splices only that subtree, keeps its referents, and says so for the merge.

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

**Run the main session from the test checkout.** Agent types, their `tools:`
lists, skills and `.claude/settings.json` load from the checkout the session
starts in, once, at startup. Until 2026-10-23 every session started in the main
checkout, on a branch from 10-22: none of the visual-loop runs loaded the
allowlists, `visual-gate`, the critic ("Agent type 'visual-critic' not found") or
the 1-hour subagent cache. Start orchestrating sessions in `../martial-world-test`
(or a checkout of the latest `test`), and restart after merging agent or skill
changes. `tools/token_report.py` shows it: a run whose per-turn tool schemas
still list `Artifact` launched without its allowlist.

**Keep runs short and briefs lean (2026-10-23).** Every turn re-reads the whole
context, so cost grows with turns times context. The first visual-loop day ran
ui-designer at a median 141 turns and 340k peak (one lint pass: 380 turns, 760k),
vfx at 119 and 300k, animator at 110 and 370k; Bash output (mostly `sed -n` file
dumps) filled more of that context than captures did.
- **Human review resumes; fix rounds after that start fresh.** Relay the user's
  pick or note with SendMessage within the hour (the cache holds for an hour).
  After two review rounds, or when the user answers later than that, start a
  fresh agent from the agent's last handoff status line (branch, stage call,
  open choice) plus the note, not a third resume.
- **Fixes after a finished run go to a fresh agent**, briefed with the branch, the
  `studio_id` and the list of fixes.
- **Briefs point, they don't paste.** Name the doc parts and files to read; don't
  paste doc text, AGENTS.md rules or the preloaded skills into the brief.
- **Ask for a short report.** The agent-report skill sets its shape; a report is
  read once by you, but anything you quote from it into the next brief is paid again.
- **Measure.** `python3 tools/token_report.py --days 1` shows the main/subagent
  split and, per agent type, launch size, turns, peak context, captures per run
  and the tool schemas loaded per turn. Run it after a big pass.

**Tool allowlists.** Every agent file sets `tools:`. Without it an agent loads every
tool schema in the session (the Artifact tool alone is ~9k tokens) on every turn,
about 18k tokens before it does anything. When an agent needs a new tool or MCP
server, add it to that agent's `tools:` line (whole servers as `mcp__<server>__*`;
the Figma server is `mcp__3c3ea100-5a4a-43ab-8480-10c29c81d158__*`). Keep
`SubagentHandback` in every list: it's how the agent delivers its report. Visual
agents carry `Agent(visual-critic, general-purpose)` so they can call the critic
and nothing else.

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
| Player / R6 assets (race cosmetics, accessories worn on the player) | `modeler` | Blender, never Studio parts (user, 2026-10-23, after the part-built race looks: "that sucked") |
| Docs, agent files and skills: fold learnings, dedupe, fix stale, split | `docs-keeper` | `/tidy-docs`; docs only, never code or assets |

Modeling, VFX and animation agents (`modeler`, `enemy-modeler`, `vfx`, `world-fx`,
`animator`) run on Opus. Their frontmatter sets `model: opus`; don't override it
with Sonnet (user, 2026-10-22).

### Briefs

Write every visual brief against [briefs.md](briefs.md): references, the exemplar
to match from `docs/reference/approved/README.md`, the do-not-change list, scale,
contracts, "done means". An agent missing a required field asks once and stops,
which is cheaper than a body rebuilt around a guess. Default to "send 2-3
directions first"; the user picks, then it polishes once.

### Task size and plumbing (2026-10-23 timing audit)

Subagent wall time is call count times ~12 s, and call counts ran 150-400 on
whole-build or whole-boss tasks (the first UI lint sweep: 82 min, 397 calls; one
boss's motion: 37 min, 151 calls). Cut tasks to one screen, one move set, one
effect, one body, and run them in parallel across sandboxes. Before spawning,
serve the agent's worktree yourself (`tools/serve.sh <port> <dir>`, a port
`ss -ltn` shows free) and put the base URL in the brief; agents lost 20-40
calls each on ports, pasted scripts and rewritten helpers. Gate budget: ~80
calls, hard stop at 150 (`visual-gate`, "Budget").

### Human review beats self-review when the user is there

A maker reviewing its own work costs captures (the slowest, dearest call) and a
critic round; the user glancing at the live stage costs nothing. When the user
is at their desk, brief `Review: human`: the agent lints, puts the thing on the
stage, says what it would pick, and ends its turn. Relay the user's answer with
`SendMessage` (the agent resumes with its context). Brief `Review: critic` only
when they've said they're away. The stage loop runs inside Studio (a Heartbeat
connection), so a stopped agent costs nothing while the user looks; resume it
with their words, and it swaps the stage to the next build.

### The visual gate

Every visual agent preloads `visual-gate`: lint to zero FAIL, one contact sheet,
a fresh `visual-critic` (Opus, `tools: Read, Glob, Grep`, ~20k tokens a round,
two rounds max), and a report that quotes the verdict. A WRONG DIRECTION verdict
sends the agent back to the user with variants instead of polishing. When the
user approves a result, the maker saves its sheet under `docs/reference/approved/`
so the gallery stays the bar. You can spawn `visual-critic` yourself on a
screenshot the user sends, with the same inputs.

### Skills, learnings and the docs-keeper

Agents preload the shared skills they use on every task (`skills:` in their
frontmatter), so a brief doesn't need to repeat the sandbox, export, upload or
commit rules: give the `studio_id`, the task, and the contracts. Agents end their
reports with **Workflow learnings** and **Workflow optimization**. Collect those, and
after a batch of work lands (or when `python3 tools/docs_lint.py` reports agent
files over budget), run `/tidy-docs` with the learnings pasted in. The
`docs-keeper` puts each one in its home (agent file, skill or system doc) on its
own branch, and you merge it like any feature.

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
   agent runs its lint and one `visual-critic` round (the `visual-gate` skill), so
   the user reviews round two in Studio, not round zero.
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

## Watching and steering agents

The user can't steer what they can't see (user, 2026-10-23).
- **Live feed:** `tools/agent_feed.sh` tails every subagent transcript of the
  latest session (`~/.claude/projects/<project>/<session>/subagents/*.jsonl`,
  which flush live) into one line per tool call, and shows each agent's
  `## Status:` lines. Every brief asks for a status line per phase; an agent that
  only shows `execute_luau` for twenty minutes isn't following its brief.
- **In the sandbox window:** every visual agent keeps `tools/review_stage.luau`
  showing its current state (a model turning beside an R6, a clip or cast looping
  with effects and sounds, a UI screen with sample data) and refreshes it after
  each build round, then names the stop call (`_G.reviewStage.stop()`) in its
  report; [tools](../tools.md) has the modes. It never stops for a look; the user flags it if they want a
  change. Say in the brief when the user is away so variants get picked by the
  critic instead of waiting.
- **In the app:** the title-bar menu > Background tasks lists running agents,
  opens their output and stops them; Transcript view > Verbose shows every tool
  call. In a terminal, `/tasks` does the same (`x` stops one).
- **Stop or steer from the main session:** "stop the fox animator" (`TaskStop`),
  or "tell the vfx agent to drop the ground crack" (`SendMessage` to the agent;
  it resumes with its context). A stopped agent can't be messaged; spawn a fresh
  one with the brief plus what changed.

## Tokens

- `.claude/settings.json` sets `subagentPromptCacheTtl: "1h"`: subagents get a
  5-minute cache by default, so a 40-minute agent that pauses for Studio re-pays
  its whole prefix. Keep model, tools and cwd identical across a fan-out so they
  share the prefix.
- `effort:` in agent frontmatter: `high` on the critic, `low` on anything that only
  hosts a terminal (with `model: haiku`).
- Sheets, not screenshots: one stitched image per review round. Skills preload
  only what every task uses; the rest load on demand.
- The gate itself is the big saving: a critic round costs 15-25k tokens, a
  rejected pass costs a whole maker run plus the user's time.
