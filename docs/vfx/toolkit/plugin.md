The vfxia plugin in detail: its docs, the Game Module API, and the editor tools with their scripted equivalents. Read when you call `fx.*` from code, need a plugin feature you haven't used, or tell the user which plugin tool to tweak with.

# vfxia plugin and Game Module

Core facts (what the plugin is, Emit attributes, tags) are in [../toolkit.md](../toolkit.md).

## The plugin's docs

Docs: https://vfxer.pages.dev/docs/introduction. The site is a JS app, so WebFetch sees an
empty page; the content sits in a Supabase `Documentation` table behind the site's public
key. The shell recipe for querying it is in git history (`git show bf43e8b:docs/vfx/toolkit.md`,
section "The plugin"). The plugin file itself
(`%LOCALAPPDATA%\Roblox\Plugins\VFXPlugin.rbxmx`) is obfuscated; don't read it.

## Game Module (`ReplicatedStorage.vfx`)

The user inserts it with the plugin's code button (ask them if
`ReplicatedStorage:FindFirstChild("vfx")` is nil). With the setting "Auto-initialize module"
on, `shared.fx` is the same API without a require. It is plugin-owned: the plugin updates it
and syncs add-ons into it, so don't map it in `default.project.json` or edit it by hand; it
lives in the place file.

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

- It doesn't descend into Parts nested inside a Part, only into that part's emitters and
  attachments; emitting a Model reaches everything. Emit a SplineVFX part nested in another
  part on its own.
- `EmitBreak` is runtime state it writes; exclude it from diffs.
- In Edit mode `fx.emit` starts ~0.1 s late (see [previewing.md](previewing.md)).

## Editor tools (for the user) and their scripted equivalents

The plugin's editing windows are for a human at the mouse; you produce the same results as
data. Know them, so you can tell the user which to reach for when they tweak your work:

| Tool | What it does | Your equivalent |
|---|---|---|
| Sliders (hue, saturation, lightness, Scale, Retime) | recolour, scale and retime a selected effect | `fx.recolor` / `fx.rescale` / `fx.retime`, or set the values directly |
| Curve Editor | edits NumberSequences (curve or sequence mode, Envelope, Floor/Ceiling, presets) | write the `NumberSequence` yourself, shaped like its presets: sine, quad, cubic, exponential, linear, wave, V |
| Copier | copies and pastes properties between instances | copy properties in Luau, or build every tier from one builder |
| Path visualizer / Splines | draws spline paths and particle spawn shapes in the viewport | the Splines add-on's attributes. The plugin's `DrawSplines` / `DrawParticles` settings (`shared.fx.settings.set`) may make them show in your `screen_capture` while previewing (untested); turn them off afterwards |
| Trail preview | plays a trail along a test shape (circle, ...) | preview the real effect with `tools/vfx_preview.luau` |
| Emit panel, R / T | emit / enable the selection | `fx.emit` / `fx.enable` |
| Presets menu (`~`) | saved presets and commands (Beam Circle, Charging Particle, Toggle Loop, Sync Beams, Clear TempVFX, ...) | ask the user to drop a preset in if one fits a beat, then build from it |
