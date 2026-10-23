Previewing effects in Edit mode and capturing them: the one review image (filmstrip, `vfx_sheet.py`) and the placement lints, `vfx_preview` (castThrough, sweep, scene), enemy-effect shots, cameras, and every capture trap found so far. Read when you preview, freeze or capture an effect.

# Previewing and capturing

Edit mode is not Play: particles, tweens, cameras and markers all behave differently. When a
capture can't be trusted, verify numerically and leave the look to the user in Studio.

## Rules that decide whether a capture shows anything

- **Edit-mode particles only simulate near the editor camera.** From far away (including
  `screen_capture`'s own camera move) you see only new-born particles: pale flames, missing
  layers, a stacked white core. Park `workspace.CurrentCamera` near the scene, wait ~2 s, then
  capture (`_G.auraPreview.look()` for auras; `vfxPreview.look(cam)`; `castThrough`/`sweep`
  park it themselves). Freezing right after an emit captures nothing for the same reason.
- **`screen_capture` captures whichever Studio is in front**, not the `studio_id` you pass, so
  with several Studios open a capture can show somebody else's scene. Check it's yours. Bring
  your sandbox to the front first:
  `powershell.exe -NoProfile -Command "$p = Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowTitle -like '*mw-sandbox-<name>*' }; (New-Object -ComObject WScript.Shell).AppActivate($p.Id)"`.
  A minimised window captures as a flat grey frame and `AppActivate` doesn't fix it: restore
  it with PowerShell's user32 `ShowWindow(handle, 9)`.
- Pass the capture's own `camera_position` and `look_at_position`; setting `CurrentCamera`
  alone isn't what the capture shows. `screen_capture` swaps the camera, so effects under
  `workspace.CurrentCamera` don't show (point `TechniqueVFX.folder` at a workspace folder).
- After a library search the plugin's window sits over the viewport. Hide it
  (`...Seperate.Library.Visible = false`) and the dev GUI
  (`StarterGui.ShowDevelopmentGui = false`) for captures, then restore both.
- A layer can be blank on its first emit because its textures haven't loaded:
  `ContentProvider:PreloadAsync` the template's texture Decals before the first capture.
- If a capture right after a big edit looks wrong (stale scene, empty sky), take it again
  before debugging; the first frame can lag the change.
- **Can't be captured as stills; judge as templates or verify numerically:** beams and trails
  (can't be frozen), Spline trails, ScreenEffects, beams fading on Heartbeat, rate-enabled
  emitters and short-lived held props. Say so in the report instead of spending captures.
- Green dots on rigs are Studio's attachment display, not the effect. A SurfaceGui on a part
  didn't show in a `screen_capture` at all.

## The review image

The critic step judges one image plus the lint printouts, never a pile of captures.
- **Techniques:** `P.filmstrip({ id, level, radius })` plays the real cast six
  times (anticipation, windup, release, active, hitstop, aftermath, from
  `Rules.castProfile`), freezes each in its own cell on a dark plate with a
  Neon-part label (moment and ms), lays the cells out 3x2 square to the
  player-view camera and parks the editor camera far back at FieldOfView 18.
  One `screen_capture` with the returned camera is the review image. It builds
  at y 1200 (over the testbed baseplate) and hides the dev GUI; `P.clear()`
  restores both. Frozen particles still render from the far camera, because
  each cell is played with the camera parked close first. Cells are small
  (~500 px), so the shot reads timing and placement. Judge fine texture in
  Studio.
- **Enemies and anything else:** take the per-moment captures
  (`enemy_fx_shot`), then
  `uv run --with pillow python3 -I tools/vfx_sheet.py OUT.png --title ... "label=path" ...`
  makes a labelled grid (3 columns). The capture paths come from Claude Code,
  which saves every `screen_capture` under the session's `tool-results/`
  folder and prints `[Image: source: .../mcp-Roblox_Studio-blob-<n>.jpg]`. The
  MCP itself has no save-to-disk call (`store_image` loads a local file into
  Studio, the other way). Each capture also costs the capturing agent's
  context, so prefer the filmstrip where it applies.
- `enemy_fx_shot` leaves the dev GUI showing: set
  `StarterGui.ShowDevelopmentGui = false` before its captures and restore it.
- Before judging the look, lint the placement: `tools/vfx_origin_check.luau`
  (`_G.vfxOriginCheck(target)`), `tools/vfx_hooks_check.py` and
  `tools/vfx_texture_audit.py` ([enemy-effects](../enemy-effects.md), "Checks").

## Techniques: `tools/vfx_preview.luau` (`_G.vfxPreview`)

- **Preview the real cast:** `P.scene({ radius = ... })`, then
  `P.castThrough({ id, level, freezeAt })`, then `screen_capture`. It drives a rig through the
  move's animation at cast speed, with live hands and tagged enemies, through the real
  `CombatEffects.windup`/`cast`, and freezes at a moment. `castThrough` takes a **level**, not
  a tier: 1, 4, 7, 10 for T1–T4. `sweep` does every moment ([pipeline.md](pipeline.md),
  Review). It already works around these Edit-mode traps:
  - `require` caches go stale: `P.fresh` requires fresh copies of `ReplicatedStorage.Shared`.
  - `TechniqueVFX.folder` is pointed at a workspace folder (the camera swap above).
  - `cleanup` destroys a frozen frame early, so it's disabled.
  - ScreenEffects shakes move the editor camera, so they're stripped.
  - Ground rays hit the preview rig. CanCollide/CanQuery don't help (an R6 Humanoid forces
    Torso/Head collidable), so the rig goes in a collision group that doesn't collide with
    Default.
- Always preview through the real call path (`CombatEffects.cast` with a real character's
  root position), not hand-placed pivots, so placement bugs show up. Edit mode has no player
  characters, so set the preview rig's parts to `CanQuery = false` to stand in for the game's
  character exclusion. Tag enemy clones `Enemy` (with a living Humanoid) so
  `Hitbox.enemiesIn` finds them.
- Lower-level calls:
  - `.scene({ radius, enemies, offsets })`: a clean SmoothPlastic floor in open sky with a
    caster rig, enemy clones and red posts at the gameplay radius. Don't preview in the spawn
    area: beds, fences and props hide ground effects, and a textured Grass floor muddies them.
    In a sandbox the testbed's `Arena.Baseplate` (top at y 648.6) is over the default centre
    (y 640): pass `center = Vector3.new(400, 1200, 300)`. The scene's rig is pivoted by its
    bounding box, weapon included, so it can stand sunk into the floor; read heights from the
    root, not the floor.
  - `.emit(inst)`: a native `:Emit` honouring EmitCount/EmitDelay. Use it for timed captures:
    `shared.fx.emit` in Edit mode starts ~0.1 s late, so frozen frames show the wrong moment.
    Run `fx.emit` once per tier, frozen later, only to confirm the module plays everything.
  - `.freeze()` sets `ParticleEmitter.TimeScale = 0` after your `task.wait(t)` so a capture
    holds the moment (tweens keep running). Then `.clear()` (only while you hold the lock).
- A scrubbed track (`castThrough` plays at speed 0 and sets TimePosition) never fires its
  markers, so BladeSkill beats tied to a marker run on their fallback, 0.08 s late, in
  previews only.
- Previewing a runtime module (an `EnemyFX` helper) by hand: point `TechniqueVFX.folder` at a
  workspace folder and stub `TechniqueVFX.cleanup` for the session, or the clones (with their
  frozen particles) are destroyed before `screen_capture` runs.

## Enemy effects

- `tools/enemy_fx_shot.luau` (`_G.enemyFxShot`) clones the real body, fires a cue sequence at
  its real moments with the model's `Attack`/`AIState`/`StateAt` set as the server would,
  freezes particles and mesh-wave tweens at `freeze` seconds and returns the camera for
  `screen_capture`; one call per moment. It fires every cue before it freezes: to capture a
  windup, pass only the windup cue. Load it once per session: reloading resets its state, so
  earlier frozen scenes are never cleared and leak into later captures.
- Layers with an `EmitDelay` start about 0.1 s late in Edit mode (the Game Module's emit), so
  capture a peak at +150 ms rather than +50.
- `tools/enemy_fx_smoke.luau` takes `stateful = true` (and `wait`) for handlers that guard on
  the model's state, as the bosses' do; without it they return before spawning anything and
  the smoke run looks clean but tests nothing. Barrage cues spawn nothing unless the cue
  carries server-like `parts`; pass `shape` per cue.
- `get_console_output` is flooded with plugin settings warnings; wrap a handler call in
  `pcall` to read its errors.

## Cameras, moments and lighting

- With the scene at C: player view C+(-12,9,5) looking at C+(4,1,-1); side C+(3,6,16);
  top-down C+(0.1,28,0) (checks the shape against the radius posts).
- Capture each tier at release, mid-active, Hit Stop and aftermath, close up and at ~25
  studs, day (ClockTime 16.6) and night (0.5). Restore ClockTime.
- If the Game Module isn't in the place, still author the Emit attributes and say in-game
  module playback is untested.
- Clean up everything: preview scene, clones, staging, `workspace.Terrain.TempVFX`.

## Shared Studio

Other sessions may use the same Studio and the same `_G`. Before a capture run:
- Check `workspace.CurrentCamera.CameraType`; another session may hold a Scriptable camera.
- Check for others' `_*Preview` / `_Staging*` folders, and leave them alone.
- Scope any `_G` helper overrides inside the call that needs them.
- ClockTime and Lighting can change under you mid-run, and others may draw splines into your
  captures: note the clock with each capture.
