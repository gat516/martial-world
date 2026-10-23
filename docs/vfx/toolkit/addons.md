The plugin's add-ons (Craters, SimpleMeshVFX, ScreenEffects, Splines, LightningBeams): tags, attributes and gotchas. Read when a layer uses an add-on.

# Add-ons

Each add-on is driven by its own tag plus attributes on the effect, and its `game` module
syncs into the Game Module's add-ons folder, so in-game use needs the Game Module in the
place. Their doc pages are empty, so read the source before using one.

- Installed in the user's plugin: **LightningBeams**, **Craters** (ground craters/rock
  rings), **ScreenEffects** (camera shake, screen flashes and overlays), **SimpleMeshVFX**
  (mesh shells, rings, spikes), **Splines** (bezier paths with trails/particles),
  **AnimationUtil** (plugin-side only, no `game` module).
- Listed on the docs site but not installed: Movers, Debris (physics rocks), Sequencer
  (tweens). Ask the user to install one if a plan needs it.
- `python3 tools/vfx_addons.py` unpacks them from the plugin settings into
  `tools/frag/addons/<Name>.rbxmx` (gitignored). Read each `game` module there for its tag,
  attributes and what `emit`/`enable` do. Sources are `<string name="Source">` items nested
  inside the add-on module: parse with `xml.etree` and walk `Item` children (a regex over
  `<Item>…</Item>` stops at the first nested item). `tools/vfx_addons.md` has notes too.
- `ServerStorage.vfx_addons` only exists once the user installs an add-on in this place,
  through Manage Add-ons.
- Reach for one where it fits a layer: Craters for ground breaks, SimpleMeshVFX for textured
  shells and rings instead of code tweens, ScreenEffects for shakes and impact frames,
  Splines for qi gathering along curves, LightningBeams for lightning. They sit in the layer
  stack next to the library emitters, not instead of them.
- `TechniqueVFX.full` is false when the Game Module is missing. Branch on it for add-on beats
  (e.g. ScreenEffects shake vs `CombatEffects.shake`), so nothing doubles and the fallback
  stays clean.

Reference from their `game` modules (re-check the source if behaviour surprises you):

## Craters
- Tag `CraterVFX` on a Part or Attachment. Spawns anchored Parts into TempVFX.
- Attributes: `Count`, `Lifetime`, `Size`, `SizeScale`, `Shape` (Ring/Line/Cone), `Radius`,
  `Variance`, `ConeAngle`, `Fill`, `Duration` (staggers spawns), `EmissionStart`/`End`
  (Progressive/Random/Reverse), `SpawnTime`, `DespawnTime`, `AngleX/Y/Z`, `MatchGround`
  (copies the ground's colour, material and textures), `UseMesh`/`MeshId`/`TextureId`,
  `YOffset`, `RaycastDistance`.
- `Collision` defaults to true: set it false. Its raycast skips players and `CraterIgnore`
  only, not enemies. No CastShadow option, so count its parts in the budget.
- `Shape=Ring, Fill=true, EmissionStart=Progressive, Duration=<active>` erupts rocks outward
  with a wave. `MatchGround` on grass makes the rocks green.
- Mesh rocks raised and tilted (YOffset 0.45, AngleX 25–50) read better than blocks. Use
  `ServerStorage.AssetLibrary` Inno `Rock_01..07` (for example 17608108317).

## SimpleMeshVFX
- A Model/Folder with `Start` and `End` BaseParts (or a part with an `End` child, or the
  `MeshVFX` tag). It clones Start `EmitCount` times and tweens each clone to End's
  Size/Color/CFrame, ending at `EndTransparency`. Only emits for instances under workspace.
- Attributes: `Duration`, `RotSpeed` (deg/s Vector3), `StartTransparency`, `FadeInTime`,
  `Part_TweenParams` ("Style,Direction,repeat,reverse,delay,time"), `LockedToPart`,
  `Distance`/`Scale`/`SpreadAngle`/`FacePath`, `EmitClone`. Decals may carry `Flipbook`.
- Keep the Start and End meshes at Transparency 1 in the template, so the plain fallback
  shows nothing rather than stray meshes.

## ScreenEffects
- CSV string attributes:
  - `CameraShake` = "Preset,FalloffDistance,Magnitude,FadeOutTime,Roughness,FadeInTime,RotInfluence,PosInfluence".
    Presets: Explosion, Earthquake, Vibration, Custom. Own distance falloff; the default is
    100–500 studs, so set your own.
  - `ImpactFrames` = "Count,TintColor,Range,Contrast,Saturation,MinVisibility,-Duration,+Duration".
    Flips a ColorCorrection, only within Range and only when the point is visible.
  - `CameraWeldOffset`/`Scale` attach screen-space parts.
- Fields follow the defaults' types: a NumberRange is `30~120`, a Vector3 `1;2;3`, an empty
  field takes the default. Color3 didn't parse in any format tried: leave TintColor empty.
- Put each attribute on its own empty Attachment, so inherited emit attributes don't fire it
  once per child emitter.
- Use it in place of `CombatEffects.shake` for that effect, falling back to the shake when
  the module is missing. It can't be captured in previews, and its shakes move the editor
  camera (`vfx_preview` strips them).

## Splines
- Tag `SplineVFX`. Control points are child attachments `1`, `2`, …, plus `End` (or an
  ObjectValue). The first PVInstance child is the template that travels the TCB path.
- Attributes: `Duration`, `Easing` (NumberSequence), `EmitCount`, start
  `Shape`/`SpreadAngle`, `SyncPosition` (the path follows a moving root),
  `Tension`/`Continuity`/`Bias`/`Jaggedness`, `MirrorPath`, `Reverse`, `PoolObject`.
- Children named `EmitOnHit`/`EmitOnFinish` fire at the end.
- Spline trails can't be frozen for a still; say so in the report instead of spending
  captures on them. Emit a SplineVFX part nested in another part on its own (the Game Module
  doesn't descend into nested Parts).
