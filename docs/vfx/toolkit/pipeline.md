The spec-driven build pipeline in detail: loading the helpers, specs and blocks, staging with `vfxStage`, runtime wiring with `CastFX`, review sweeps, and what to settle in the plan. Read at the start of every technique or enemy-effect build.

# The pipeline (every technique)

The short version is in [../toolkit.md](../toolkit.md); this is the detail.

## 1. Bootstrap

- The helpers are served over HTTP by the receiver: run `tools/ensure_receiver.sh` first (it
  starts `tools/receive_rbxmx.py` on loopback 8766 unless it's already up; the receiver dies
  with the session). It serves only plain `<name>.luau` paths: a cache-busting query string
  (`...luau?x=1`) returns 404.
- The one-line bootstrap
  `local m = Instance.new("ModuleScript"); m.Source = game:GetService("HttpService"):GetAsync("http://127.0.0.1:8766/vfx_session.luau"); require(m)`
  fails: `tools/vfx_session.luau` is over Studio's 200,000-character Script.Source limit.
  Load the helpers file by file instead: for each of `export_rbxm`, `anim_markers`,
  `vfx_diff`, `vfx_blocks`, `vfx_preview`, `vfx_stage` (`vfx_blocks` again after editing it,
  and the spec), `Instance.new("ModuleScript")`,
  `Source = HttpService:GetAsync("http://127.0.0.1:8766/<name>.luau")`, `require`.
  (`vfx_stage.luau` loads `vfx_diff.luau` from the receiver itself if needed.) Then read
  `tools/vfx_addons.md`.
- A fresh sandbox has no `workspace.Rig`: make one with
  `Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)`
  named `Rig`, and hang a weapon on it like `Weapons.apply` does
  (`weapon:PivotTo(arm.CFrame * joint.C0 * joint.C1:Inverse() * hilt.PivotOffset)`, parent
  it, then `joint.Part0 = arm`).
- Push edited `src/` modules into the sandbox with `tools/push_src.luau` before a preview
  (Rojo isn't connected in a sandbox).
- Several `GetObjects` animation loads in one `execute_luau` can drop the MCP connection
  ("Target is not reachable"); load two or three per call.

## 2. Plan

Read `animMarkers` for the move's animation ([animation-sync.md](animation-sync.md)), sample
the striking limb ([building.md](building.md), "Anchor effects to the body"), and settle these
with the user in the plan, not after the build:
- which limb strikes
- whether add-ons are OK
- the mastery motif (halo, print, ...)
- what to do about missing animation events
- whether tier IV impact frames or screen flashes are comfortable

## 3. Spec

Write `tools/vfx_specs/<Id>.luau` from the blocks in `tools/vfx_blocks.luau`. Every block
takes `(root, tier, p)`; the file header documents the params. The blocks:
- `groundShockwave`, `impactShockwave`, `airShockwave` and `shockwaveShell` (all 3D
  MeshWave-based);
- `releaseFlash`, `dropStreak`, `handGather` (with Spline wisps), `impactBurst`;
- `impactStack`, a tier-scaled big hit where every part can be overridden or set to `false`;
- `craterRing` (Ring/Cone), `screenShake`;
- `meshWave` and `emitter` for one-off pieces.

Beats are `{ block, from, to, params, phase, attrs }`. It's plain data, so keep it boring.

## 4. Build and stage (`tools/vfx_stage.luau`)

`vfxStage.begin(who)`, then `vfxBlocks.buildFromSpec(spec, parent)`, then `vfxStage.finish()`.
Then `tools/vfx_export.sh <names>` and `vfxStage.synced(check)`; Rojo can't patch until the
file is in `assets/`. (In a sandbox, or with another agent exporting at the same time, merge
instead: [export.md](export.md).)
- `begin()` makes the staging clone. It refuses when a template was changed in Studio since
  its last export (`finish()` stamps each template with a `BuildStamp` hash): a rebuild would
  wipe that edit, which is usually the user's. Diff it, fold it into the spec, report it,
  then `begin(who, { acceptEdits = true })`.
- It also warns about effect-looking instances loose in Workspace; report those and never
  delete them unasked (AGENTS.md, "Studio instances").
- To rebuild only some auras, `_G.buildMethodAura(staging, { only = { "BlazingHeart" } })`
  leaves the other methods untouched.
- `finish()` stamps, exports and destroys the staging copy. `tools/vfx_export.sh [names]`
  copies the export into `assets/` and verifies templates, attribute counts and add-on tags;
  `synced(check)` waits for Rojo to patch the real folder. Names are any instance name
  (`PalmStrike_T4`) or a `Group.Template` path for templates without a tier
  (`SpiritWolf.Landing`). Templates may be Folders as well as Models: the stamp hash and
  `vfxDiff` place parts in world space when the root has no pivot.

## 5. Runtime

Wire it with `CastFX`: `targets({ kind = "circle" | "zone" | "line", ... })`, `impactAt`,
`curveTime`/`frontTime`, `handPosition`, `phases`, and `groundBelow`. Caster and observer go
through the same code. The technique's runtime is `src/client/TechniqueFX/<Id>.luau`
([export.md](export.md), ownership; [in-game.md](in-game.md)).

## 6. Review

`vfxPreview.sweep({ id, level, radius })` at levels 1/4/7/10 builds one scene per moment
(windup/hit/hitstop/aftermath) and freezes particles and MeshWave tweens; take the captures
back to back ([previewing.md](previewing.md)). Retune by editing the spec and rebuilding;
`vfxDiff.snapshot`/`compare` shows what changed (exclude `EmitBreak`, runtime state the Game
Module writes). When writing a builder for something that already exists, snapshot the real
templates first and iterate to a zero diff.

## Partial work

When scope changes mid-edit, save the partial work with `git diff` into a patch in your
scratchpad, check out the files, commit only the finished piece, and keep the patch.
`git apply -3` re-applies it on top of later commits.
