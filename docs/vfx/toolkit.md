# VFX toolkit

The plugin, the asset library and the Studio pipeline for building effects.
How effects should look is in [style.md](style.md); the `vfx` agent's brief
(`.claude/agents/vfx.md`) says how to work. This is reference: read the parts
you need.

## The plugin

The user's VFX plugin is **vfxia** ("Modular Roblox VFX System"), a paid local
plugin (`%LOCALAPPDATA%\Roblox\Plugins\VFXPlugin.rbxmx`, obfuscated, don't read
it). Docs: https://vfxer.pages.dev/docs/introduction. The site is a JS app, so
WebFetch sees an empty page. To re-read the docs, pull the Supabase anon key
from the site's JS bundle and query the docs table:

```bash
JS=$(curl -s https://vfxer.pages.dev/docs | grep -o '/assets/index-[^"]*\.js')
K=$(curl -s "https://vfxer.pages.dev$JS" | grep -o 'eyJ[A-Za-z0-9_.-]\{60,\}' | grep -m1 'InVydmR6')
curl -s "https://urvdzgdmvihezbqhhadd.supabase.co/rest/v1/Documentation?select=title,content&icon=not.is.null&order=id.asc" -H "apikey: $K" -H "Authorization: Bearer $K"
```

The plugin is a UI the **user** drives (Emit panel, sliders, curve editor,
asset library, presets menu `~`). You can't click it. Everything it does is
stored as plain data on the instances (properties, attributes, tags) and played
by the Game Module, so you author effects through the MCP and keep them fully
compatible with the plugin: the user can then select your effect and tweak it
with the sliders, press **R** to emit and **T** to enable.

### How an effect is structured

An effect ("VFX") is any instance tree: a Part/Attachment/Model/Folder holding
ParticleEmitters, Beams (with Attachment0/1), Trails, lights, Sounds, MeshParts
or Parts with SpecialMesh + Decal (mesh flipbooks). `emit` walks the
descendants.

Emit attributes (Emit panel). Put them on the root, or on any descendant to
override it. Each is a number, or a NumberRange for a random value (the panel's
`10-20` text is just how the user types `NumberRange.new(10, 20)`):

| Attribute | Meaning |
|---|---|
| `EmitCount` | count for `ParticleEmitter:Emit(count)`; add-ons reuse it (e.g. debris rocks per emit) |
| `EmitDelay` | seconds to wait before emitting; delays all descendants too |
| `EmitDuration` | if > 0, `enable` for that many seconds then `disable`; `-1` enables and never disables |
| `EmitRepeat` | repeat `emit` this many times; `-1` repeats on `enable` until disabled ("Toggle Loop") |
| `EmitRepeatDelay` | seconds between repeats |

Existing effects in this place also carry per-Beam `Duration`, `TweenStyle`,
`TweenDirection` and `Width0`/`Width1` attributes (beam width tweens), and
`Flipbook` on mesh-flipbook Decals (`frame1,frame2,...` asset ids). Read them
off `ServerStorage.AssetLibrary.VFX` (portals, waterfalls, wells, a shrine)
when you need an example of how the plugin lays an effect out.

Tags: `ColorVFX` recolours the effect with its part's Color, `ScaleVFX` scales
it with the part's size.

### Game Module (`ReplicatedStorage.vfx`)

The user inserts it with the plugin's code button (ask them if
`ReplicatedStorage:FindFirstChild("vfx")` is nil). With the setting
"Auto-initialize module" on, `shared.fx` is the same API without a require. It
is plugin-owned: the plugin updates it and syncs add-ons into it, so don't map
it in `default.project.json` or edit it by hand; it lives in the place file.

```lua
local fx = require(game:GetService("ReplicatedStorage").vfx)
fx.emit(vfx)                     -- what the Emit button does; returns {[string]: object}
fx.enable(vfx) / fx.disable(vfx) -- the Enable button (looping emitters, beams, EmitDuration)
fx.retime(vfx, timeScale)        -- speed up / slow down without TimeScale
fx.rescale(vfx, scale)           -- size, speed etc. together
fx.recolor(vfx, hue?, saturation?, lightness?)
fx.getCFrame(vfx) -> CFrame
fx.maxLifetime(vfx) -> number    -- when it's safe to destroy (not always exact)
fx.debris(vfx, destroyAfter?)    -- moves it to workspace.Terrain.TempVFX as temporary
fx.destroyAfter(vfx, time?, callback?)
fx.sample(sequence, t, seed?)    -- value of a Number/ColorSequence at t
fx.pool.new(template, expansion?):expand(n) -- :take() / :give(obj)
```

### Editor tools (for the user) and their scripted equivalents

The plugin's editing windows are for a human at the mouse. You produce the
same results as data. Know what each one does, so you can tell the user which
to reach for when they tweak your work:

| Tool | What it does | Your equivalent |
|---|---|---|
| Sliders (hue, saturation, lightness, Scale, Retime) | recolour, scale and retime a selected effect | `fx.recolor` / `fx.rescale` / `fx.retime`, or set the values directly |
| Curve Editor | edits NumberSequences (curve or sequence mode, Envelope, Floor/Ceiling, presets) | write the `NumberSequence` yourself, shaped like its presets: sine, quad, cubic, exponential, linear, wave, V |
| Copier | copies and pastes properties between instances | copy properties in Luau, or build every tier from one builder |
| Path visualizer / Splines | draws spline paths and particle spawn shapes in the viewport | the Splines add-on's attributes. The plugin's `DrawSplines` / `DrawParticles` settings (`shared.fx.settings.set`) may make them show in your `screen_capture` while previewing (untested); turn them off afterwards |
| Trail preview | plays a trail along a test shape (circle, ...) | preview the real effect with `tools/vfx_preview.luau` |
| Emit panel, R / T | emit / enable the selection | `fx.emit` / `fx.enable` |
| Presets menu (`~`) | saved presets and commands (Beam Circle, Charging Particle, Toggle Loop, Sync Beams, Clear TempVFX, ...) | ask the user to drop a preset in if one fits a beat, then build from it |

### Add-ons

Each add-on is driven by its own tag plus attributes on the effect, and its
`game` module syncs into the Game Module's add-ons folder (so in-game use
needs the Game Module in the place). Their doc pages are empty, so read the
source before using one.

- Installed in the user's plugin: **LightningBeams**, **Craters** (ground
  craters/rock rings), **ScreenEffects** (camera shake, screen flashes and
  overlays), **SimpleMeshVFX** (mesh shells, rings, spikes), **Splines**
  (bezier paths with trails/particles), **AnimationUtil**.
- `python3 tools/vfx_addons.py` unpacks them from the plugin settings into
  `tools/frag/addons/<Name>.rbxmx` (gitignored). Read each `game` module there
  for its tag, attributes and what `emit`/`enable` do.
- Also listed on the docs site but not installed: Movers, Debris (physics
  rocks), Sequencer (tweens). Ask the user to install one if a plan needs it.
- `ServerStorage.vfx_addons` only exists once the user installs an add-on in
  this place, through Manage Add-ons.
- In the unpacked files, sources are `<string name="Source">` items nested
  inside the add-on module. Parse them with `xml.etree` and walk `Item`
  children; a regex over `<Item>…</Item>` stops at the first nested item.
  AnimationUtil has no `game` module (it's plugin-side only).

Reference, from their `game` modules (re-check the source if behaviour
surprises you):
- **Craters:** tag `CraterVFX` on a Part or Attachment.
  - Attributes: `Count`, `Lifetime`, `Size`, `SizeScale`, `Shape`
    (Ring/Line/Cone), `Radius`, `Variance`, `ConeAngle`, `Fill`, `Duration`
    (staggers spawns), `EmissionStart`/`End` (Progressive/Random/Reverse),
    `SpawnTime`, `DespawnTime`, `AngleX/Y/Z`, `MatchGround` (copies the
    ground's colour, material and textures), `UseMesh`/`MeshId`/`TextureId`,
    `YOffset`, `RaycastDistance`.
  - `Collision` defaults to true, so set it false.
  - Its raycast skips players and `CraterIgnore` only, not enemies.
  - It spawns anchored Parts into TempVFX.
- **SimpleMeshVFX:** a Model/Folder with `Start` and `End` BaseParts (or a
  part with an `End` child, or the `MeshVFX` tag).
  - It clones Start `EmitCount` times and tweens each clone to End's
    Size/Color/CFrame, ending at `EndTransparency`.
  - Attributes: `Duration`, `RotSpeed` (deg/s Vector3), `StartTransparency`,
    `FadeInTime`, `Part_TweenParams` ("Style,Direction,repeat,reverse,delay,time"),
    `LockedToPart`, `Distance`/`Scale`/`SpreadAngle`/`FacePath`, `EmitClone`.
  - Decals may carry `Flipbook`. It only emits for instances under workspace.
- **ScreenEffects:** CSV string attributes.
  - `CameraShake` = "Preset,FalloffDistance,Magnitude,FadeOutTime,Roughness,FadeInTime,RotInfluence,PosInfluence".
    Presets: Explosion, Earthquake, Vibration, Custom. It has its own
    distance falloff.
  - `ImpactFrames` = "Count,TintColor,Range,Contrast,Saturation,MinVisibility,-Duration,+Duration".
    It flips a ColorCorrection, only within Range and only when the point is
    visible.
  - `CameraWeldOffset`/`Scale` attach screen-space parts.
  - Use it in place of `CombatEffects.shake` for that effect, falling back to
    the shake when the module is missing.
- **Splines:** tag `SplineVFX`.
  - Control points are child attachments `1`, `2`, …, plus `End` (or an
    ObjectValue). The first PVInstance child is the template that travels the
    TCB path.
  - Attributes: `Duration`, `Easing` (NumberSequence), `EmitCount`, start
    `Shape`/`SpreadAngle`, `SyncPosition` (the path follows a moving root),
    `Tension`/`Continuity`/`Bias`/`Jaggedness`, `MirrorPath`, `Reverse`,
    `PoolObject`.
  - Children named `EmitOnHit`/`EmitOnFinish` fire at the end.
- Reach for an add-on where it fits a layer (Craters for ground breaks,
  SimpleMeshVFX for textured shells and rings instead of code tweens,
  ScreenEffects for shakes and impact frames, Splines for qi gathering along
  curves, LightningBeams for lightning). They sit in the layer stack next to
  the library emitters, not instead of them.

## The asset library (textures, meshes, sounds)

- Build effects from the plugin's Asset Library. You pick the assets yourself:
  - `tools/vfx_library.json` lists the whole library (7,087 usable assets:
    6,218 images, 41 mesh flipbooks, 77 meshes, 751 named sounds), in library
    order, each with `kind` and the search `keywords` it matched (ring, slash,
    lightning, flame, smoke, crack, rune, seal, aura, beam...). Grep it
    first. Keywords come from a fixed word list, so an asset can fit without
    matching your word.
  - For other words, search live: run `tools/vfx_library.luau` through
    `execute_luau`, then `_G.vfxLibrary.search("vortex", 40)`. It types into
    the plugin's own library search, so the user must have opened the Asset
    Library window once this Studio session (it keeps working after the window
    is closed). If it errors, ask the user to open it.
  - Tiles only carry ids, so judge looks from thumbnails before using one, on a
    contact sheet: `~/.local/bin/uv run -q --with pillow python3 -I tools/vfx_contact_sheet.py OUT NAME kw1,kw2 [kind] [max]`
    (or `ids:a;b;c` instead of keywords) writes a labelled sheet with a
    thumbnail cache; Read the PNG. Add `--size 420` for big tiles (16 a
    sheet) to read a flipbook's grid or fine detail. A black tile means the texture has an opaque
    black background, which is useless for tinted or additive use: skip it
    (e.g. 8952281337, 10365552478, 11037528577, 8214519774).
  - Don't vet ids with `ContentProvider:PreloadAsync`: it reports Failure for
    many library images that render fine. Render-test instead.
  - Search fresh for every effect, with words from its own references and
    idea. Don't start from ids another effect used.
  - Known gap (audit, 2026-10-22): the shipped templates (`Effects`,
    `AmbientFX`, `WorldFX`, `GuardFX`) use 201 of the 7,087 assets, 12 of
    the 41 flipbooks and 12 of the 77 meshes, and ten generic textures (the
    soft glow 9841273544 and 867619398, the ring mesh 471124075, stock
    sparks and impact rings) are about half of all texture uses. About 690
    Neon parts are still doing the drawing. Hero and secondary layers should
    get a texture, flipbook or mesh with the action's own shape; keep the
    generic glows and sparks for cores and sparkles. To redo the audit,
    `rojo build` each `.rbxm` to an `.rbxmx` in your scratchpad and count
    the `rbxassetid://` ids against `vfx_library.json`.
  - Flipbook ids in `vfx_library.json` are sprite sheets: put them on a
    ParticleEmitter with `FlipbookLayout` Grid2x2 or Grid4x4 (read the grid
    off a large thumbnail); no mesh needed.
  - Soft glow 867619398 shows a square edge when large and bright; use the hard
    dot 9841273544 for flashes and heartbeats.
  - A turning sigil is steadier as a turning SurfaceGui image than as two
    overlapping rotating particles, which drift out of step.
  - Use ids as `rbxassetid://<id>`. Meshes are MeshIds, sounds SoundIds, and
    flipbooks follow the library's mesh-flipbook layout (a Part with a
    SpecialMesh and a Decal whose `Flipbook` attribute lists the frames). Ask
    the user to insert one from the library if you need its exact setup.
- Assets already in `ServerStorage.AssetLibrary`, existing effects and
  `rbxasset://textures/particles/*` are fine to reuse alongside library picks.
- Don't draw your own textures with Pillow unless the user asks for it.
  When one is asked for: the system python has no Pillow, so run
  `~/.local/bin/uv run --with pillow --with numpy python art/<x>/draw_<x>.py`.
  To upload, serve the folder with
  `python3 -m http.server 8771 --bind 127.0.0.1 --directory art/<x>` (in the
  background) and pass `http://127.0.0.1:8771/<file>.png` to `upload_image`;
  keep the returned ids in `art/<x>/assets.json` and stop the server after.
- Sounds belong with `SoundService.SFX` / `src/client/Sfx.luau`; don't hide
  Sounds inside effect templates unless the plugin should emit them with it.

## Building and previewing in Studio

- Templates live in one mapped folder, `ReplicatedStorage.Effects`
  (`assets/Effects.rbxm`). If it doesn't exist yet, create it in Edit mode,
  export it (below), and map it in `default.project.json` next to `Ambience`.
  Name templates by use (`FistHit`, `QiBurst`, `BreakthroughPillar`), one root
  each, with the Emit attributes on the root.
- Never build inside the mapped folder (AGENTS.md, "Studio instances"). Clone
  it to `ReplicatedStorage._StagingEffects`, work there, export, destroy the
  staging copy, and let Rojo patch the real one from the file. That applies to
  every change, even an attribute tweak (Rojo doesn't write back), so batch
  tweaks into one staging pass.
- Build templates with one builder function installed in `_G` that takes
  `tier` (and keeps asset ids in a table such as `_G.PalmAssets`). Each tuning
  pass is then a single rebuild of T1..T4 instead of per-instance edits.
- Wrap edits in `ChangeHistoryService` recordings so Ctrl+Z undoes them.

### Template layout

One Model per tier (`<Id>_T<n>` under `Effects.<Id>`), facing the cast:
- Pivot at the ground point under the caster. Leave `PrimaryPart` nil and set
  an identity-rotation (upright) `WorldPivot`; stand pillars and cylinders up
  inside the model. Scripts that place a template must keep its pivot rotation
  (AGENTS.md, "Luau pitfalls"), or pillars spawn sideways. A PrimaryPart sits exactly on the pivot, so ground emitters
  land flush with the floor and z-fight away. Lift ground emitters ~0.2 studs.
- Parts by role: `Ground` (waves, dust, seal, cracks, debris); `Palm`/`Halo`
  or similar, repositioned from the caster at runtime; `Windup`, played at cast
  start through `TechniqueVFX.part`; `Impact` with a `Body` attachment,
  detached with `TechniqueVFX.take` and cloned per target with `burstAt`.
  Code-driven extras (swirl meshes, the one light) are found by name.
- Root attributes: `AuthoredRadius` (or length/width) so code rescales to the
  def; `AuthoredActive` (seconds the active-phase emitters were authored for);
  `AuthoredWindup` on the `Windup` part; `Phase = "active"` on emitters that
  must end by Hit Stop.
- Impacts go on the target's near side at body height with ZOffset 2-3. At the
  target's centre the burst is hidden inside its mesh.

### Anchor effects to the body

- Effects come from the body part that performs the move: a palm strike's
  release from the striking hand, a kick from the foot, a sword wave from the
  blade's arc. Find that part on the live character at runtime (for observers
  too), using the rig's hands/grip attachments, and place the release there at
  the release marker. Never use an offset guessed from the root. To find
  which limb strikes and where it is at each marker, sample the animation on
  a rig in Edit mode:
  1. `animator:LoadAnimation(anim)`, then wait until `track.Length > 0`.
     Before it loads you silently read the rest pose.
  2. `track:Play(0, 1, 0)` (speed 0).
  3. For each sample, set `track.TimePosition = t`, then call
     `animator:StepAnimations(0)` twice.
  4. Read limb CFrames relative to `HumanoidRootPart`. An R6 hand is
     `arm.CFrame * CFrame.new(0, -arm.Size.Y/2, 0)`.

  Sample ±0.07 s around each marker in 0.01 s steps; poses move fast near
  Hit. The Fists animations are R6. Palm Strike (Fists.4) strikes with the
  left arm, which is still sweeping in at Hit and fully extended ~0.04 s
  later.
- A weapon technique anchors to the held weapon model (`ServerStorage.WeaponModels`:
  `Tip` and `Base` attachments on the joint part, plus `grip`/`butt`/`head` anchors).
  `WeaponFX.rig(character, full)` returns the live span (`Base` -> `Tip`, or
  `butt`/`grip` -> `Tip` with `full`, a virtual 4-stud blade off the arm when
  nothing is held) with `at(f)` and `attach(f)` (attachments that ride the
  weapon). A template's `Charge` part (block `bladeCharge`: Attachments with an
  `At` attribute 0..1) is played on it by `CombatEffects.windup` for every
  technique whose `weapon` is a class: `WeaponFX.charge` moves the attachments
  (with their emitters, Beams and Trails) onto the weapon and stops them at
  Hit. `TechniqueVFX.spawn` strips `Charge` from the release copy. A technique
  module can also export `windup(CombatEffects, def, level, character, seconds)`
  and return true to replace the default.
- Charge gathers into that limb during windup, and the release visibly travels
  from it to where the gameplay shape starts (e.g. hand → ground → ring).
  Gameplay shapes stay centred where the hitbox is (circles on the caster's
  feet).
- Ground raycasts must exclude characters. A ray down from the caster's root
  (or a target's centre) otherwise hits that body first, and the "ground"
  becomes torso height. Exclude the caster and targets, or all characters.
- Preview through the real call path (`CombatEffects.cast` with a real
  character's root position), not hand-placed pivots, so placement bugs show
  up in Edit mode. Edit mode has no player characters, so set the preview
  rig's parts to `CanQuery = false` to stand in for the game's character
  exclusion. Tag enemy clones `Enemy` (with a living Humanoid) so
  `Hitbox.enemiesIn` finds them.
- When scope changes mid-edit, save the partial work with `git diff` into a
  patch in your scratchpad, check out the files, commit only the finished
  piece, and keep the patch for later.

### Particle gotchas

- `ParticleEmitter.Size` is a radius (half-width). A ring that must reach
  radius R ends its Size curve at R.
- Ground-hugging horizontal spray (a dust ring): `Shape = Box`,
  `EmissionDirection = Front`, `SpreadAngle = (5, 180)`. Cylinder/Outward on a
  small part sprays everything one way.
- Flat ground decals: `Orientation = VelocityPerpendicular`,
  `EmissionDirection = Top`, `Speed = 0.01`. For a vertical plane facing the
  strike use `Back`/`Front`.
- `MeshPart.MeshId` isn't writable from MCP scripts ("lacking capability"):
  create the part with `AssetService:CreateMeshPartAsync(id)` and clone it into
  the template. MeshId survives the binary export.

### Beams, surfaces and decals (from the water kit)

- A non-FaceCamera Beam faces along its attachments' Axis (local X).
  Identity attachments only lie flat for a beam running along world X; along
  Z it stands up as a wall. For flat beams (rims, ground streaks) turn the
  attachments `CFrame.Angles(0, 0, math.pi / 2)` so X points up.
- A Beam runs its texture's vertical image axis along its length. Draw strip
  textures upright (tiling top to bottom), or they show as stripes across it.
- Parent an Attachment before setting `WorldCFrame`. Unparented, WorldCFrame
  is stored as local, so the point lands at double its world position.
- Keep big surfaces under effects opaque. Transparent parts and particles are
  depth-sorted by part centre, so a slightly translucent water union drew over
  its own foam and splash particles and hid them.
- Decals render on Transparency-1 parts, so an invisible volume can carry a
  flat foam patch or seal decal.
- Any-shape flat surfaces: union blocks/cylinders (Studio CSG) into one part.
  A Texture tiles across the union's whole face, with no seams between pieces.
  The union takes its first part's rotation, so check which face points up.
- CSG (`UnionAsync`/`SubtractAsync`) errors unless at least one part is
  parented into the DataModel. Parent the pieces first, then destroy them.

### The pipeline (use this for every technique)

1. **Bootstrap:** load every helper in three lines:
   `local m = Instance.new("ModuleScript"); m.Source = game:GetService("HttpService"):GetAsync("http://127.0.0.1:8766/vfx_session.luau"); require(m)`.
   It needs the receiver: run `tools/ensure_receiver.sh` first (it starts
   `tools/receive_rbxmx.py` unless it's already up). Then read
   `tools/vfx_addons.md`.
2. **Plan:** read `animMarkers` for the move's animation, sample the striking
   limb, and settle the limb, add-ons, mastery motif and missing events with the
   user in the plan.
3. **Spec:** write `tools/vfx_specs/<Id>.luau` from the blocks in
   `tools/vfx_blocks.luau`. Every block takes `(root, tier, p)`, and the file
   header documents the params. The blocks:
   - `groundShockwave`, `impactShockwave`, `airShockwave` and `shockwaveShell`
     (all 3D MeshWave-based);
   - `releaseFlash`, `dropStreak`, `handGather` (with Spline wisps),
     `impactBurst`;
   - `impactStack`, a tier-scaled big hit where every part can be overridden
     or set to `false`;
   - `craterRing` (Ring/Cone), `screenShake`;
   - `meshWave` and `emitter` for one-off pieces.

   Beats are `{ block, from, to, params, phase, attrs }`. It's plain data, so
   keep it boring. A ForceField distortion shell was tried and dropped because
   it didn't read.
4. **Build:** `vfxStage.begin()`, then `vfxBlocks.buildFromSpec(spec, parent)`,
   then `vfxStage.finish()`. Then run `tools/vfx_export.sh <names>` and
   `vfxStage.synced(check)`. Rojo can't patch until the file is in `assets/`.
5. **Runtime:** wire it with `CastFX`: `targets({ kind = "circle" | "zone" | "line", ... })`,
   `impactAt`, `curveTime`/`frontTime`, `handPosition`, `phases`, and
   `groundBelow`. Caster and observer go through the same code.
6. **Review:** `vfxPreview.sweep({ id, level, radius })` at levels 1/4/7/10
   builds one scene per moment (windup/hit/hitstop/aftermath) and freezes
   particles and MeshWave tweens. Then take the captures back to back. Retune
   by editing the spec and rebuilding; `vfxDiff.snapshot`/`compare` shows
   what changed. Exclude `EmitBreak`, runtime state the Game Module writes.
   When writing a builder for something that already exists, snapshot the real
   templates first and iterate to a zero diff.

### Working alongside other vfx agents

Several vfx agents may build different techniques at the same time in the
same worktree and Studio. Ownership:
- **Yours:** `src/client/TechniqueFX/<Id>.luau` (the technique's runtime:
  `return { cast = function(CombatEffects, def, level, character, origin, dir, chain): boolean }`,
  returning false to fall back to the old drawing), `tools/vfx_specs/<Id>.luau`
  (helpers only your technique needs go in that spec file), and the
  `Effects.<Id>` group in Studio.
- **Shared, don't edit while others are running:** `CombatEffects.luau`,
  `CastFX.luau`, `TechniqueVFX.luau`, `tools/vfx_blocks.luau`, the other
  tools, `tools/vfx_session.luau` (regenerate it to load your spec, but don't
  commit it), and `docs/`. If you need a shared change (a new block, a
  CastFX helper such as playLine/playZone), build it inside your own files
  and propose the shared version in your report. The main session merges it.
- Commit only your own files, staged by path (never `git add -A`).
- **Studio lock:** call `vfxStage.lock(who)` (use your technique id as `who`)
  before any staging, preview scene or capture run. Hold it from
  `begin(who)` through `finish()`, `tools/vfx_export.sh`, `synced` and the
  git commit of `assets/Effects.rbxm` (together with your files), then
  `unlock(who)`. Re-lock to refresh it on long runs. If someone else holds
  it, do non-Studio work (spec, runtime code, planning) and try again later.
  Never steal a fresh lock. `assets/Effects.rbxm` holds every technique, so
  always stage from the live `Effects` while holding the lock; never reuse
  an old staging copy.
- `vfxPreview.clear()` removes every preview scene, so only call it while
  you hold the lock.

### Shared Studio

Other sessions use the same Studio and the same `_G`. Before a capture run:
- Check `workspace.CurrentCamera.CameraType`; another session may hold a
  Scriptable camera.
- Check for others' `_*Preview` / `_Staging*` folders, and leave them alone.
- Scope any `_G` helper overrides inside the call that needs them.
- ClockTime and Lighting can change under you mid-run, so note them with
  each capture.

### Fast path (helpers from the Palm Strike build)

- **Preview the real cast:** `tools/vfx_preview.luau`. Use `P.scene({ radius = ... })`,
  then `P.castThrough({ id, level, freezeAt })`, then `screen_capture`. It
  drives a rig through the move's animation at cast speed, with live hands and
  tagged enemies, through the real `CombatEffects.windup`/`cast`, and freezes
  at a moment. It already works around these Edit-mode traps:
  - `require` caches go stale: `P.fresh` requires fresh copies of
    `ReplicatedStorage.Shared`.
  - `screen_capture` swaps the camera, so effects under
    `workspace.CurrentCamera` don't show: `TechniqueVFX.folder` is pointed at
    a workspace folder.
  - `cleanup` destroys a frozen frame early, so it's disabled.
  - ScreenEffects shakes move the editor camera, so they're stripped.
  - Ground rays hit the preview rig. CanCollide/CanQuery don't help (an R6
    Humanoid forces Torso/Head collidable), so the rig goes in a collision
    group that doesn't collide with Default.
- `castThrough` takes a **level**, not a tier: use 1, 4, 7, 10 for T1–T4.
- **Stage and export:** `tools/vfx_stage.luau`. `vfxStage.begin()` makes the
  staging clone. It refuses when a template was changed in Studio since its
  last export (`finish()` stamps each template with a `BuildStamp` hash): a
  rebuild would wipe that edit, which is usually the user's. Diff it, fold it
  into the spec, report it, then `begin(who, { acceptEdits = true })`. It also
  warns about effect-looking instances loose in Workspace; report those and
  never delete them unasked (AGENTS.md, "Studio instances"). To rebuild only
  some auras, `_G.buildMethodAura(staging, { only = { "BlazingHeart" } })`
  leaves the other methods untouched. `vfxStage.finish()` stamps, exports
  and destroys the staging copy. Then `tools/vfx_export.sh [names]` copies
  the export into `assets/` and verifies templates, attribute counts and
  add-on tags, and `vfxStage.synced(check)` waits for Rojo to patch the real
  folder. Names are any instance name (`PalmStrike_T4`) or a
  `Group.Template` path for templates without a tier (`SpiritWolf.Landing`).
  Templates may be Folders as well as Models: the stamp hash and `vfxDiff`
  place parts in world space when the root has no pivot. `vfx_stage.luau`
  loads `vfx_diff.luau` from the receiver itself if `vfx_session.luau`
  hasn't, so it also works on its own. These replace the manual steps under
  "Export" below.
- Spline trails can't be frozen for a still, and ScreenEffects can't be
  captured. Say so in the report instead of spending captures on them.

### Module and add-on gotchas

- `tools/vfx_session.luau` is over Studio's 200,000-character Script.Source
  limit, so the one-line bootstrap fails. Load the helpers file by file instead:
  for each of `export_rbxm`, `anim_markers`, `vfx_diff`, `vfx_blocks`,
  `vfx_preview`, `vfx_stage` (`vfx_blocks` again after editing it, and the spec),
  `Instance.new("ModuleScript")`, `Source = HttpService:GetAsync("http://127.0.0.1:8766/<name>.luau")`,
  `require`. A fresh sandbox has no `workspace.Rig`: make one with
  `Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)`
  named `Rig`, and hang a weapon on it like `Weapons.apply` does
  (`weapon:PivotTo(arm.CFrame * joint.C0 * joint.C1:Inverse() * hilt.PivotOffset)`, parent it, then
  `joint.Part0 = arm`). Push edited `src/` modules with `tools/push_src.luau` before a preview.
- `screen_capture` captures whichever Studio is in front, not the `studio_id` you pass,
  so with several Studios open (the user's, other sandboxes) a capture can show
  somebody else's scene. Check the capture is yours before trusting it; otherwise
  verify numerically and leave the look to the user.
- Several `GetObjects` animation loads in one `execute_luau` can drop the MCP
  connection ("Target is not reachable"); load two or three per call.
- To make `screen_capture` see your sandbox, bring its window to the front
  first: `powershell.exe -NoProfile -Command "$p = Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowTitle -like '*mw-sandbox-<name>*' }; (New-Object -ComObject WScript.Shell).AppActivate($p.Id)"`.
- A sandbox has the testbed's `Arena.Baseplate` (top at y 648.6) over
  `vfxPreview.scene`'s default centre (y 640): pass `center = Vector3.new(400, 1200, 300)`.
  The scene's rig is pivoted by its bounding box, weapon included, so it can
  stand sunk into the floor; read heights from the root, not the floor.
- A scrubbed track (`castThrough` plays at speed 0 and sets TimePosition)
  never fires its markers, so BladeSkill beats tied to a marker run on their
  fallback, 0.08 s late, in previews only.
- Textures on a part's Top face: U runs along the part's X and its origin is
  the +X edge, V runs along Z from the +Z edge. A strip that grows from one
  end keeps its Texture still on the ground when that end is the +X edge.
  StudsPerTileV larger than the part's width with OffsetStudsV = (tile -
  width) / 2 shows only the middle band of the image (thin drawn strokes read
  thick). A SurfaceGui on a part didn't show in a `screen_capture` at all.

- The Game Module doesn't descend into Parts nested inside a Part, only into
  its emitters and attachments; emitting a Model reaches everything. Emit a
  SplineVFX part nested in another part on its own.
- ScreenEffects CSV:
  - Fields follow the defaults' types: a NumberRange is `30~120`, a Vector3
    is `1;2;3`, and an empty field takes the default.
  - Color3 didn't parse in any format tried, so leave TintColor empty.
  - Set your own CameraShake falloff; the default is 100–500 studs.
  - Put each attribute on its own empty Attachment, so inherited emit
    attributes don't fire it once per child emitter.
- Craters:
  - `Shape=Ring, Fill=true, EmissionStart=Progressive, Duration=<active>`
    erupts rocks outward with a wave.
  - `MatchGround` copies the ground's colour (on grass, rocks come out green).
  - Mesh rocks raised and tilted (YOffset 0.45, AngleX 25–50) read better than
    blocks. Use `ServerStorage.AssetLibrary` Inno `Rock_01..07` (for example
    17608108317).
  - It has no CastShadow option, so count its parts in the budget.
- SimpleMeshVFX: keep the Start and End meshes at Transparency 1 in the
  template, so the plain fallback shows nothing rather than stray meshes.
- `TechniqueVFX.full` is false when the Game Module is missing. Branch on it
  for add-on beats (e.g. ScreenEffects shake vs `CombatEffects.shake`), so
  nothing doubles and the fallback stays clean.
- `git apply -3` re-applies a saved partial patch on top of later commits.

### Settle up front, in the plan

Ask these in the plan, not after the build:
- which limb strikes
- whether add-ons are OK
- the mastery motif (halo, print, ...)
- what to do about missing animation events
- whether tier IV impact frames or screen flashes are comfortable

### Previewing

- **Edit-mode particles only simulate near the editor camera.** Viewed from
  far away (including `screen_capture`'s own camera move) you see only
  new-born particles: pale flames, missing layers, a stacked white core. Park
  `workspace.CurrentCamera` near the scene, wait ~2 s, then capture
  (`_G.auraPreview.look()` for auras; `vfxPreview.look(cam)`, and
  `castThrough`/`sweep` park it themselves). Freezing right after an emit
  captures nothing for the same reason.
- Other sessions may change ClockTime or draw splines into your captures;
  note the clock with each one.
- `tools/receive_rbxmx.py` dies with the session; `tools/ensure_receiver.sh`
  before loading tools over HTTP.
  It serves only plain `<name>.luau` paths: a cache-busting query string
  (`...luau?x=1`) returns 404.
- Previewing a runtime module (an `EnemyFX` helper) in Edit mode: point
  `TechniqueVFX.folder` at a workspace folder and stub `TechniqueVFX.cleanup`
  for the session, or the clones are destroyed (with their frozen particles)
  before `screen_capture` runs. Pass the capture's own `camera_position` and
  `look_at_position`; setting `CurrentCamera` alone isn't what the capture
  shows.

`tools/vfx_preview.luau` also has the lower-level calls (run it through
`execute_luau`; it installs `_G.vfxPreview`):
- `.scene({ radius, enemies, offsets })` builds a clean SmoothPlastic floor in
  open sky with a caster rig, enemy clones and red posts at the gameplay
  radius. Don't preview in the spawn area: beds, fences and props hide ground
  effects, and a textured Grass floor muddies them.
- `.emit(inst)` is a native `:Emit` honouring EmitCount/EmitDelay. Use it for
  timed captures: `shared.fx.emit` in Edit mode starts ~0.1 s late, so frozen
  frames show the wrong moment. Run `fx.emit` once per tier, frozen later, only
  to confirm the module plays everything.
- `.freeze()` sets `ParticleEmitter.TimeScale = 0` after your `task.wait(t)`
  so a capture holds the moment (tweens keep running). Then `.clear()`.
- Cameras with the scene at C: player view C+(-12,9,5) looking at C+(4,1,-1);
  side C+(3,6,16); top-down C+(0.1,28,0) (checks the shape against the radius
  posts).
- Capture each tier at release, mid-active, Hit Stop and aftermath, close up
  and at ~25 studs, day (ClockTime 16.6) and night (0.5). Restore ClockTime.
  Green dots on rigs are Studio's attachment display, not the effect.
- If the Game Module isn't in the place, still author the Emit attributes and
  say in-game module playback is untested.
- Clean up everything: preview scene, clones, staging, `workspace.Terrain.TempVFX`.
- If a capture right after a big edit looks wrong (stale scene, empty sky),
  take it again before debugging; the first frame can lag the change.


## Export (attributes must survive)

`tools/export_rbxmx.luau` drops attributes and tags and only knows a short
property list, so it is wrong for effects. Use the binary exporter:

1. Run `tools/ensure_receiver.sh` (starts `tools/receive_rbxmx.py` on
   loopback 8766 unless one is already up).
2. Run the contents of `tools/export_rbxm.luau` through `execute_luau` (installs
   `_G.exportRbxm`).
3. `game:GetService("HttpService"):PostAsync("http://127.0.0.1:8766/Effects.rbxm", _G.exportRbxm("ReplicatedStorage._StagingEffects", "Effects"))`
   The second argument writes the root under its real name.
4. Move `tools/frag/Effects.rbxm` to `assets/Effects.rbxm`. It's binary, so
   check it by building it: `~/.rokit/bin/rojo build` a scratch project that
   maps only that file to an `.rbxmx` in your scratchpad and grep the result
   for the templates and `AttributesSerialize`.
5. Destroy the staging copy; with Rojo connected, check the real folder now
   holds your changes and there is one copy of it.

## Playing effects in-game

- Client side, in the module that owns the moment (CombatEffects for casts and
  hits, BreakthroughView, WeatherFX, ...) or a small shared helper if several
  need it. Clone the template from `ReplicatedStorage.Effects`, position it
  (`PivotTo` / attach to the character's attachment), parent it under
  `workspace.CurrentCamera` or `workspace.Terrain.TempVFX` like the existing
  effects, then `fx.emit(clone)` and `fx.debris(clone)` (or `destroyAfter` with
  `fx.maxLifetime`). Loops: `fx.enable` / `fx.disable`, then clean up.
- Techniques go through `src/client/TechniqueVFX.luau`: it picks
  `Effects.<Id>.<Id>_T<tier>` from `Techniques.visualTier(level)`, steps
  EmitCounts +20% per level inside a tier, and falls back to plain emitters
  when the Game Module is missing. The cast payload carries the level. Extend
  this helper rather than adding a parallel path.
- Use `fx.rescale` / `fx.recolor` for variants (technique tier, realm, enemy
  size) instead of duplicating templates.
- Server-triggered moments already arrive over the `Effect` remote (see the
  table in `docs/README.md`); add a new kind there rather than a new remote.
- Replace the old hand-built Neon-part effects in CombatEffects only when the
  task asks for it, one effect at a time, keeping the same timing and hooks.
- Run `tools/check.sh` after editing scripts.

## Sync to the animation's events

Effects follow the animation the move actually plays. Before designing an
effect, read that animation's markers (animation events):

1. Find the animation. A technique's def has `animation = n`, meaning
   `ReplicatedStorage.Animations.Fists.<n>` (Palm Strike and Fire Seal play 4,
   Sword Qi Wave 3, Lightning Talisman 2, Iron Skin 1). Other moves (dashes,
   meditation, enemy attacks) name theirs in their own module. Check the code
   path, because a technique may get its own animation later.
2. Run `tools/anim_markers.luau` through `execute_luau`, then
   `_G.animMarkers("ReplicatedStorage.Animations.Fists.4")` (or an Animation
   instance, or an `rbxassetid://` id). It returns the length and every marker
   with its time and value.
   Markers are `KeyframeMarker` instances under each Keyframe: `tools/anim_markers.luau`
   reads them (its first version read `GetMarkers()`, which returns nothing for
   assets loaded with `GetObjects`).
3. Design the effect around the events it has. Today the Fists animations
   carry `Hit` (release, the hitbox opens) and `Hit Stop` (the hitbox closes):
   charge during windup, release and the impact burst at `Hit`, the strongest
   part through the window to `Hit Stop`, fade during recovery. Other moves may
   carry other events (a beam's start/hold/end, each blow of a barrage, a
   channel loop). Map every phase of the effect to a marker.
4. At runtime, take times from the game's own source, not hard-coded delays.
   Combat derives the action profile from `Config.Combat`
   (`src/shared/Config.luau`, the chain's `hit`/`hitStop`/`speed`) in
   `src/shared/ActionRules.luau`. For techniques use
   `Rules.castProfile(def)` (windup / active / recovery, the same numbers the
   caster and observers run on); `Rules.hitAt(action)` is the Hit moment of a
   live action. Listen to `AnimationTrack:GetMarkerReachedSignal(name)` on the
   playing track for events Combat doesn't model. Compare the markers with
   Config first. If they disagree, report it (known: Fists.4 Hit Stop 0.45 vs
   Config 0.50; Fists.5 0.333/0.350 vs 0.35/0.533). Effects follow Config, so
   they stay in step with the hitbox either way.
   - Fit phases with the template contract (see "Template layout" below):
     `Phase = "active"` emitters are refit to the active window,
     the `Windup` part to the windup, and untagged emitters are aftermath and
     keep their own fade. `TechniqueVFX.fit(inst, phase, authored, actual)`
     scales Lifetime and EmitDelay.
   - Time per-target impacts from the wave emitter's own Size curve (when the
     front reaches that distance, `frontTime` in CombatEffects), not from
     constants. A projectile's arrival is then squeezed into the blow's window:
     `WeaponFX.hitWindow(def, i)` is hit i's Hit -> Hit Stop at play speed and
     `WeaponFX.landing(arrival, travel, window)` returns the delay (never later
     than max(window, 0.1 s)), so the impact stack lands with the damage number
     instead of up to 0.3 s after it. Authored flights are 0.12-0.18 s.
5. **Stop and report** if the effect needs events the animation doesn't have.
   For example, a held beam with no start/end markers, a barrage with one `Hit`
   for many blows, or a charge with no release marker. Say which animation,
   which markers you'd need (names and roughly where), and what the effect
   would do with them. Don't fake the timing with guessed delays. Animations
   are the user's to edit.

Hits already have feedback: `CombatEffects.shake` (tiered by `SHAKE_BY_TIER`,
only within 45 studs of the camera), `CombatEffects.flash` (fired per impact,
not at release), damage numbers, and the technique's own Sfx cue. Build on
them instead of doubling them up.

## Budget (mobile first)

- Most players are on phones. Keep each emitter modest (tens per burst, not
  hundreds; loops a few to ~20 per second) and get richness from more kinds of
  layer instead (see [style.md](style.md)). Prefer textured emitters over plain
  ones, Beams over particle trails, flipbooks over many parts.
- No PointLight/SurfaceLight per hit; one light on big moments (breakthrough,
  tribulation) at most. CastShadow off on every effect part; parts Anchored,
  CanCollide/CanQuery/CanTouch off.
- Frequent effects (hits, footsteps, wisps) go through `fx.pool` instead of
  Clone/Destroy each time.
- Effects that only one player needs to see play on that client. Things
  others should see are fired to all clients (the server never plays visuals).
