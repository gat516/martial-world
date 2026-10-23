The core every vfx and world-fx agent reads: what the plugin, library and Game Module are, the rules that always apply, the build-preview-export loop, the phone budget, and an index of the topic files under `toolkit/` with when to read each.

# VFX toolkit

How effects should look is in [style.md](style.md); how to work is in the agent's brief
(`.claude/agents/vfx.md`, `world-fx.md`). This page is the tools. Read it, then only the
topic files your task needs (index at the bottom).

## The three tools

- **The plugin, vfxia** ("Modular Roblox VFX System"), a paid local plugin. It is a UI the
  **user** drives (Emit panel, sliders, curve editor, asset library, presets menu `~`); you
  can't click it. Everything it does is plain data on the instances (properties, attributes,
  tags) played by the Game Module, so you author effects through the MCP and keep them fully
  plugin-compatible: the user can select your effect, tweak it with the sliders, press **R**
  to emit and **T** to enable. Details: [toolkit/plugin.md](toolkit/plugin.md).
- **The Game Module**, `ReplicatedStorage.vfx` (`shared.fx`), plays effects in game:
  `fx.emit`, `fx.enable`/`disable`, `fx.debris`, `fx.rescale`/`recolor`/`retime`, `fx.pool`.
  The user inserts it from the plugin; it's plugin-owned (never map or edit it). When it's
  missing, `TechniqueVFX` runs a plain fallback (`TechniqueVFX.full` false): still author the
  Emit attributes and say module playback is untested. Add-ons (Craters, SimpleMeshVFX,
  ScreenEffects, Splines, LightningBeams) sync into it: [toolkit/addons.md](toolkit/addons.md).
- **The asset library**: thousands of textures, flipbooks, meshes and sounds inside the
  plugin, searched live through `tools/vfx_library.luau`. Every effect's look is built from
  it, picked fresh: [toolkit/library.md](toolkit/library.md).

## How an effect is structured

An effect is any instance tree: a Part/Attachment/Model/Folder holding ParticleEmitters,
Beams (with Attachment0/1), Trails, lights, Sounds, MeshParts or Parts with SpecialMesh +
Decal (mesh flipbooks). `emit` walks the descendants.

Emit attributes (the Emit panel) go on the root, or on any descendant to override it. Each is
a number, or a NumberRange for a random value (the panel's `10-20` is how the user types
`NumberRange.new(10, 20)`):

| Attribute | Meaning |
|---|---|
| `EmitCount` | count for `ParticleEmitter:Emit(count)`; add-ons reuse it (e.g. debris rocks per emit) |
| `EmitDelay` | seconds to wait before emitting; delays all descendants too |
| `EmitDuration` | if > 0, `enable` for that many seconds then `disable`; `-1` enables and never disables |
| `EmitRepeat` | repeat `emit` this many times; `-1` repeats on `enable` until disabled ("Toggle Loop") |
| `EmitRepeatDelay` | seconds between repeats |

Tags: `ColorVFX` recolours the effect with its part's Color, `ScaleVFX` scales it with the
part's size. Existing effects also carry per-Beam `Duration`, `TweenStyle`, `TweenDirection`
and `Width0`/`Width1` attributes (beam width tweens), and `Flipbook` on mesh-flipbook Decals
(`frame1,frame2,...` asset ids); read them off `ServerStorage.AssetLibrary.VFX` (portals,
waterfalls, wells, a shrine) for an example of how the plugin lays an effect out.

## Rules that always apply

- **Library first, fresh every time.** Hero and secondary layers get a library texture,
  flipbook or mesh with the action's shape; parts only support. Search live; if the library
  can't be reached, flag it and stop (no JSON index, old ids or hand-made textures). Never
  scroll the library window to its end (it crashed the user's Studio). Pillow textures only
  when the user asks.
- **Never build inside a mapped folder.** Stage (`ReplicatedStorage._StagingEffects`, via
  `vfxStage`), export, destroy the staging copy, let Rojo patch. Never delete or rebuild over
  Studio instances you didn't create (AGENTS.md, "Studio instances").
- **Export binary** (`tools/export_rbxm.luau`, keeps attributes and tags), never
  `export_rbxmx.luau`. **Merge, don't copy** your group into `assets/Effects.rbxm`
  (`tools/effects_merge.py`), right before committing: [toolkit/export.md](toolkit/export.md).
- **Upright pivots.** Templates have `PrimaryPart` nil and an identity-rotation `WorldPivot`
  at the ground point; placement keeps the pivot rotation. Lift ground emitters ~0.2 studs.
- **Effects come from the body part that does the move** (hand, foot, the live weapon's
  `Base`->`Tip`), found on the live character at runtime, never an offset from the root.
  Ground raycasts exclude characters.
- **Timing comes from the animation's markers and `Config`**, never guessed delays; if the
  animation lacks the events an effect needs, stop and report:
  [toolkit/animation-sync.md](toolkit/animation-sync.md).
- **Preview through the real call path**, and remember Edit-mode particles only simulate near
  the editor camera and `screen_capture` grabs whichever Studio is in front:
  [toolkit/previewing.md](toolkit/previewing.md). When a capture can't be trusted, verify
  numerically and leave the look to the user.
- **Shared files and Studio.** Commit only your own files, by path. Don't edit shared runtime
  files or tools while other vfx agents run; propose the change in your report. Edit scripts
  read a file whole before opening it for writing (never
  `open(p, "w").write(f(open(p).read()))`: the write-open empties it first).
- **Sounds** live in `SoundService.SFX` / `Sfx.luau`; library sounds may not play in our
  experience, so say in-game playback is untested.

## The loop

1. **Bootstrap:** `tools/ensure_receiver.sh`, then load the helpers one file at a time over
   HTTP (`export_rbxm`, `anim_markers`, `vfx_diff`, `vfx_blocks`, `vfx_preview`, `vfx_stage`).
2. **Plan:** read the move's markers, sample the striking limb, settle limb, add-ons, mastery
   motif, missing events and tier IV screen effects with the user.
3. **Search:** one `_G.vfxLibrary.dump` per effect, contact sheets per layer.
4. **Spec and build:** `tools/vfx_specs/<Id>.luau` from `tools/vfx_blocks.luau`;
   `vfxStage.begin(who)` -> `vfxBlocks.buildFromSpec` -> `vfxStage.finish()`.
5. **Preview:** `vfxPreview.sweep` / `castThrough` (techniques), `enemy_fx_shot` (enemies);
   retune the spec and rebuild.
6. **Export and wire:** merge into `assets/Effects.rbxm`; runtime in
   `src/client/TechniqueFX/<Id>.luau` with `CastFX`, or the module that owns the moment
   ([toolkit/in-game.md](toolkit/in-game.md)); `tools/check.sh`; docs; one commit.

Full detail: [toolkit/pipeline.md](toolkit/pipeline.md).

## Budget (mobile first)

- Most players are on phones. Keep each emitter modest (tens per burst, not hundreds; loops a
  few to ~20 per second) and get richness from more kinds of layer instead
  ([style.md](style.md)). Prefer textured emitters over plain ones, Beams over particle
  trails, flipbooks over many parts.
- No PointLight/SurfaceLight per hit; one light on big moments (breakthrough, tribulation) at
  most. CastShadow off on every effect part; parts Anchored, CanCollide/CanQuery/CanTouch off.
  Craters parts can't turn shadows off, so count them.
- Frequent effects (hits, footsteps, wisps) go through `fx.pool` instead of Clone/Destroy
  each time.
- Effects only one player needs to see play on that client. Things others should see are
  fired to all clients (the server never plays visuals).

## Index: read when

| File | Read when |
|---|---|
| [toolkit/library.md](toolkit/library.md) | picking assets: live search, contact sheets, judging backgrounds and cell fill, flipbooks, the asset-use audit, own textures, sounds. Every new effect. |
| [toolkit/pipeline.md](toolkit/pipeline.md) | building a technique or enemy effect: bootstrap and a fresh sandbox rig, plan questions, spec blocks, `vfxStage` (BuildStamp, acceptEdits), `CastFX`, review sweeps, partial patches. |
| [toolkit/building.md](toolkit/building.md) | authoring or restructuring a template: template layout and root attributes, body and weapon anchoring (`WeaponFX`, sampling an animation), particle, beam, surface and texture gotchas. |
| [toolkit/previewing.md](toolkit/previewing.md) | previewing or capturing: `vfx_preview` calls, `enemy_fx_shot`/`enemy_fx_smoke`, camera presets, what can't be captured, window and shared-Studio traps. |
| [toolkit/export.md](toolkit/export.md) | exporting or committing `assets/Effects.rbxm`, or when another vfx agent may be running: export steps, the merge, file ownership, the Studio lock. |
| [toolkit/animation-sync.md](toolkit/animation-sync.md) | planning timing for any move: finding the animation, `animMarkers`, Config vs markers, phase fitting, projectile landing windows, when to stop and report. |
| [toolkit/in-game.md](toolkit/in-game.md) | wiring an effect into client code: owning module, TechniqueVFX tiers, variants, the `Effect` remote, existing hit feedback. |
| [toolkit/addons.md](toolkit/addons.md) | a layer uses Craters, SimpleMeshVFX, ScreenEffects, Splines or LightningBeams: tags, attributes, CSV formats, gotchas. |
| [toolkit/plugin.md](toolkit/plugin.md) | calling `fx.*` from code, re-reading the plugin's docs, or telling the user which plugin tool to tweak with. |
| [world_events.md](world_events.md) | (world-fx only) sky-scale events: the WorldFX kit, what's built, the plan for the rest. |
