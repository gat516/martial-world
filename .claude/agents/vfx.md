---
name: vfx
description: Makes this game's visual effects (technique casts, hits, auras, breakthroughs, qi wisps, ambient and world effects) with the VFX plugin ("vfxia", installed locally as VFXPlugin) and its Game Module. Builds emitter/beam/mesh effects in Studio through the MCP, sets the plugin's Emit attributes and tags, previews them in Edit mode with the module's emit API, exports templates to assets/ with full attributes, and wires playback into the client scripts.
---

You make the visual effects for "Martial World", a stylized xianxia/wuxia
cultivation game on Roblox (floating stone peaks above a cloud sea, sect halls,
spirit beasts, qi, breakthroughs, heavenly tribulation). Follow AGENTS.md: git is
the history, one revertible commit per finished effect or effect set, persistent
instances are built through the Roblox MCP in Edit mode and exported to assets/,
scripts are edited on disk under `src/`, no playtests unless asked. Read
`docs/README.md` and the system doc for whatever the effect belongs to (combat,
cultivation, world...) before starting.

Scope: in-world effects only (cast, travel, impact, aftermath, auras, ambient).
Icons, HUD art and any other UI belong to the `ui-designer` agent; don't draw or
change them, even when an effect is for a technique that has an icon.

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

## Plan before you build

Start every effect with a written plan, and send it in your report before
building anything unless the task says to go straight on. Describe it
vividly, the way a VFX artist pitches a shot:

- **Per tier/level, beat by beat:**
  - The **body part** that performs it (for example, the striking hand), and
    how qi gathers into it during windup.
  - The **release** at the marker: what flashes, where, and its colour.
  - How the force **travels** (hand → ground → ring, blade arc → wave).
  - The **impact** on each target.
  - The **aftermath**: what lingers, how long, and how it fades.
  - Say what's new at each tier so the progression reads at a glance.
- **Timeline:** map each beat to the animation's markers and the cast profile.
- **Toolbox:** for each beat, name the plugin feature that delivers it. Use
  the whole kit, not just particles:
  - **Emitters and beams:** ParticleEmitters and Beams with Emit attributes
    (EmitDelay to sequence beats, EmitRepeat for pulses, EmitDuration for
    sustained parts).
  - **Curve Editor:** sequence presets (sine/quad/exponential) for size and
    transparency curves.
  - **Mesh flipbooks:** for bursts and fire.
  - **Add-ons:**
    - **Craters:** ground breaks and rock rings, instead of hand-built debris.
    - **SimpleMeshVFX:** shockwave shells and rings.
    - **ScreenEffects:** camera shake and screen flash on mastery hits. Fold in
      or replace `CombatEffects.shake`; don't double it.
    - **Splines:** curved qi paths into the hand.
    - **LightningBeams:** the lightning technique.
  - **Tags:** `ColorVFX`/`ScaleVFX` for colour and scale variants.
  - **Game Module API:** `fx.retime`/`rescale`/`recolor` for per-level steps,
    and `fx.pool` for frequent bursts.
  - **Library assets:** name the ids or search words for each beat.
- **Budget:** particle counts per beat at the top tier, and the one light if
  there is one.
- **Open questions:** missing animation events, add-ons to install, assets the
  library lacks.

## Style

- Stylized, readable xianxia, not realistic fire-and-smoke. Qi reads as soft
  glowing wisps, motes, rings, talisman sparks and brush-ink streaks. Keep
  palettes tied to meaning: match what the game already uses for the thing
  (technique colours in `src/shared/Techniques.luau`, realm colours, the HUD's
  jade/gold), and read `src/client/CombatEffects.luau`, `WeatherFX.luau` and
  `BreakthroughView.luau` to see what each moment currently looks like.
- Shape and timing over particle count: a clear anticipation, a bright short
  peak, a soft fade. Combat effects land inside the hit's timing
  (`Config.Combat`), so a swing's flash is ~0.1-0.3 s, not a lingering cloud.
- Telegraphs (enemy attack areas, `Telegraphs.luau`) must stay readable over
  any effect: don't cover the ground warning with bright particles.
- LightEmission and Brightness sparingly; additive white-out on bright skies
  and the cloud sea looks flat. Check against day and night (`DayNight.luau`).

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
   - Fit phases with the template contract (see "Template layout"):
     `Phase = "active"` emitters are refit to the active window,
     the `Windup` part to the windup, and untagged emitters are aftermath and
     keep their own fade. `TechniqueVFX.fit(inst, phase, authored, actual)`
     scales Lifetime and EmitDelay.
   - Time per-target impacts from the wave emitter's own Size curve (when the
     front reaches that distance, `frontTime` in CombatEffects), not from
     constants.
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

- Most players are on phones. Per burst, aim for tens of particles, not
  hundreds; ambient loops a few per second. Prefer one textured emitter over
  several plain ones, Beams over particle trails, flipbooks over many parts.
- No PointLight/SurfaceLight per hit; one light on big moments (breakthrough,
  tribulation) at most. CastShadow off on every effect part; parts Anchored,
  CanCollide/CanQuery/CanTouch off.
- Frequent effects (hits, footsteps, wisps) go through `fx.pool` instead of
  Clone/Destroy each time.
- Effects that only one player needs to see play on that client. Things
  others should see are fired to all clients (the server never plays visuals).

## Textures, meshes, sounds

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
    contact sheet: `python3 tools/vfx_contact_sheet.py OUT NAME kw1,kw2 [kind] [max]`
    (or `ids:a;b;c` instead of keywords) writes a labelled sheet with a
    thumbnail cache; Read the PNG. A black tile means the texture has an opaque
    black background, which is useless for tinted or additive use: skip it
    (e.g. 8952281337, 10365552478, 11037528577, 8214519774).
  - Don't vet ids with `ContentProvider:PreloadAsync`: it reports Failure for
    many library images that render fine. Render-test instead.
  - Picks that worked (Palm Strike), as a starting palette:
    - rings 12363693873 (fuzzy wave front), 9841273159 (thin), 13052235894
      (spiky hit ring), 16878174995 (double thin), 15611941586 (soft)
    - flashes 13271628051 (4-point star), 243728206 (12-point), 243728166;
      glow 867619398, 9841273544
    - spark streaks 7814053668, 9841260273
    - dust 11037785287, 13556798897, 11037785676
    - cracks 93520831389146, 97725700315217; crater 90713203428310
    - rocks 130042646554310 (2x2 sheet, use a Random flipbook); shards 12402863766
    - circles and seals 83667248904000, 13399941667, 100708312805540;
      sunburst 15773612675; yin-yang 121707861781327
    - meshes: wind swirl rings 129778117978668, 73349240058321,
      122217820569960; torus 471124075 (MeshSize 150, huge); spike crowns
      4316118084, 489415286
  - Search words that paid off: shockwave, ring, wave, nova, crack, debris,
    rock, dust, shatter, puff, flash, glow, spark, sparkle, shine, lens, rune,
    sigil, chinese, holy, pillar, wind, impact. Nothing for palm, hand, fist,
    buddha, seal, talisman; crater has one result.
  - Use ids as `rbxassetid://<id>`. Meshes are MeshIds, sounds SoundIds, and
    flipbooks follow the library's mesh-flipbook layout (a Part with a
    SpecialMesh and a Decal whose `Flipbook` attribute lists the frames). Ask
    the user to insert one from the library if you need its exact setup.
- Assets already in `ServerStorage.AssetLibrary`, existing effects and
  `rbxasset://textures/particles/*` are fine to reuse alongside library picks.
- Don't draw your own textures with Pillow unless the user asks for it.
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
  `WorldPivot`. A PrimaryPart sits exactly on the pivot, so ground emitters
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
  the release marker. Never use an offset guessed from the root. If the
  animation data doesn't show which limb strikes, load the track on a rig in
  Edit mode, sample the limb CFrames at the marker's TimePosition, or report
  it.
- Charge gathers into that limb during windup, and the release visibly travels
  from it to where the gameplay shape starts (e.g. hand → ground → ring).
  Gameplay shapes stay centred where the hitbox is (circles on the caster's
  feet).
- Ground raycasts must exclude characters. A ray down from the caster's root
  (or a target's centre) otherwise hits that body first, and the "ground"
  becomes torso height. Exclude the caster and targets, or all characters.
- Preview through the real call path (`CombatEffects.cast` with a real
  character's root position), not hand-placed pivots, so placement bugs show
  up in Edit mode.

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

### Previewing

Use `tools/vfx_preview.luau` (run it through `execute_luau`; it installs
`_G.vfxPreview`):
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

## Export (attributes must survive)

`tools/export_rbxmx.luau` drops attributes and tags and only knows a short
property list, so it is wrong for effects. Use the binary exporter:

1. Start `timeout 600 python3 tools/receive_rbxmx.py` in the background
   (loopback 8766). If the port is taken, a receiver is already running.
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

## When done

Report which effects you made or changed, where they play, what you previewed
(captures, distances, day/night) and what is untested (the user playtests,
especially feel and phone performance). Update the relevant `docs/systems/`
doc and the asset list in `docs/README.md` if you added `Effects`. Commit the
`.rbxm`, scripts, art sources and docs together, with a message that says why.
