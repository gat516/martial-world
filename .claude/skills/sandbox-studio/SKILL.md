---
name: sandbox-studio
description: Working in your own sandbox Studio (the studio_id in your brief) - passing the id, loading scripts from disk, pushing edited src/ modules, leaving it clean, and when the user's own Studios may be touched. Use whenever a brief gives you a sandbox or you need a Studio at all.
user-invocable: false
---

# Your sandbox Studio

The main session opens a disposable Studio for you (`tools/sandbox.sh open <name>`):
a fresh place built from your branch's `test.project.json`, so it has the repo's
code and `assets/` but no `Workspace.Map` and no `AssetLibrary`. Its `studio_id`
is in your brief. How the main session runs sandboxes: `docs/agents/orchestration.md`.

## Rules

- Pass the `studio_id` on every Studio MCP call. If the brief has no sandbox, or
  it doesn't answer, say so and stop.
- Never open, close, tile or start Play in a sandbox. The main session keeps it
  open and may hand it to the next agent.
- Studio MCP calls run one at a time. Parallel `execute_luau` calls time out.
- Rojo isn't connected, so you may edit mapped instances in place without a
  staging copy. Only what you export to `assets/` lasts (the `studio-export`
  skill). Rojo brings it into the other places once your branch is merged.
- A sandbox holds only what's in git. The user's hand edits that they haven't
  exported live only in their own place. Before you regenerate a template they
  may have touched, check their Studio read-only and report any differences.
- A sandbox goes stale when `test` moves. Before exporting a file other agents
  also export, merge `test` into your branch and ask for a fresh sandbox, or your
  export quietly undoes their work.

## Getting files from disk into it

- Don't paste long source into `execute_luau`. Serve it and load it:
  - `tools/serve.sh`: port 8767 serves `art/enemies/`, 8768 the repo root.
  - `tools/ensure_receiver.sh`: port 8766 serves `tools/*.luau` and
    `tools/vfx_specs/*.luau`, and receives exports.
  - Then `loadstring(game:GetService("HttpService"):GetAsync(url .. "?" .. os.clock()))()`.
    The query string stops a cached copy coming back.
  - These servers die with every session, so run the script before each load.
    They bind to 127.0.0.1 only; never serve on 0.0.0.0.
- The sandbox holds `src/` as it was when it opened. After editing a module,
  push it before a preview or QA script requires it: run `tools/serve.sh`, then
  `loadstring(HttpService:GetAsync("http://127.0.0.1:8768/tools/push_src.luau"))()`
  and `_G.pushSrc({ "src/client/EnemyPoses/Boar.luau" })`.
- `require` caches a ModuleScript in Edit. After changing one, load the new
  version with `loadstring`.
- Edit-mode `_G` state can be lost, so keep helpers re-runnable instead of
  relying on what's in `_G`.

## Leave it clean

Before you report, remove preview scenes, `__P*` clones, staging copies and temp
folders. Templates you built stay in place and match your export.

## The user's Studios

The user's Studios are for playing and map work: `Workspace.Map` and
`AssetLibrary` live only there.
- Touch one only when the task needs it (map placement, library pieces, a final
  placement check against the map).
- Never start or stop Play there, and never change Selection. Other sessions
  share the camera and viewport.
- If it flips into Play under you, work on files and retry later.
- Rojo is connected there, so structural changes to mapped instances need
  staging (the `studio-export` skill).
