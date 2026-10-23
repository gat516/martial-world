Building templates in Studio: where they live, template layout and attributes, anchoring effects to the body or weapon, and particle, beam, surface and texture gotchas. Read when you build or restructure a template.

# Building templates

## Where templates live

- One mapped folder, `ReplicatedStorage.Effects` (`assets/Effects.rbxm`). (Sky-scale world
  effects use `ReplicatedStorage.WorldFX`, `assets/WorldFX.rbxm`; see world-fx.) Name
  templates by use (`FistHit`, `QiBurst`, `BreakthroughPillar`), one root each, with the
  Emit attributes on the root. A new mapped folder is created in Edit mode, exported
  ([export.md](export.md)) and mapped next to `Ambience` in both `default.project.json` and
  `test.project.json`.
- Never build inside the mapped folder (AGENTS.md, "Studio instances"). Clone it to
  `ReplicatedStorage._StagingEffects`, work there, export, destroy the staging copy, and let
  Rojo patch the real one from the file. That applies to every change, even an attribute
  tweak (Rojo doesn't write back), so batch tweaks into one staging pass. `vfxStage` does
  this for you ([pipeline.md](pipeline.md)).
- Build templates from one builder (a spec in `tools/vfx_specs/<Id>.luau`, or a function in
  `_G` that takes `tier` with asset ids in a table such as `_G.PalmAssets`), so each tuning
  pass is a single rebuild of T1..T4 instead of per-instance edits.
- Wrap edits in `ChangeHistoryService` recordings so Ctrl+Z undoes them.

## Template layout

One Model per tier (`<Id>_T<n>` under `Effects.<Id>`), facing the cast:
- Pivot at the ground point under the caster. Leave `PrimaryPart` nil and set an
  identity-rotation (upright) `WorldPivot`; stand pillars and cylinders up inside the model.
  Scripts that place a template must keep its pivot rotation (AGENTS.md, "Luau pitfalls"),
  or pillars spawn sideways. A PrimaryPart sits exactly on the pivot, so ground emitters land
  flush with the floor and z-fight away: lift ground emitters ~0.2 studs.
- Parts by role: `Ground` (waves, dust, seal, cracks, debris); `Palm`/`Halo` or similar,
  repositioned from the caster at runtime; `Windup`, played at cast start through
  `TechniqueVFX.part`; `Impact` with a `Body` attachment, detached with `TechniqueVFX.take`
  and cloned per target with `burstAt`; `Charge` for weapon techniques (below). Code-driven
  extras (swirl meshes, the one light) are found by name.
- Root attributes: `AuthoredRadius` (or length/width) so code rescales to the def;
  `AuthoredActive` (seconds the active-phase emitters were authored for); `AuthoredWindup`
  on the `Windup` part; `Phase = "active"` on emitters that must end by Hit Stop (how these
  are refit: [animation-sync.md](animation-sync.md)).
- Impacts go on the target's near side at body height with ZOffset 2-3; at the target's
  centre the burst is hidden inside its mesh.
- Camera-facing sprites centred on the floor get cut in half (a white box): put flashes and
  bursts on an attachment above the floor.

## Anchor effects to the body

- Effects come from the body part that performs the move: a palm strike's release from the
  striking hand, a kick from the foot, a sword wave from the blade's arc. Find that part on
  the live character at runtime (for observers too), using the rig's hands/grip attachments,
  and place the release there at the release marker. Never use an offset guessed from the
  root.
- To find which limb strikes and where it is at each marker, sample the animation on a rig
  in Edit mode:
  1. `animator:LoadAnimation(anim)`, then wait until `track.Length > 0` (before it loads you
     silently read the rest pose).
  2. `track:Play(0, 1, 0)` (speed 0).
  3. For each sample, set `track.TimePosition = t`, then call `animator:StepAnimations(0)`
     twice.
  4. Read limb CFrames relative to `HumanoidRootPart`. An R6 hand is
     `arm.CFrame * CFrame.new(0, -arm.Size.Y/2, 0)`.

  Sample ±0.07 s around each marker in 0.01 s steps; poses move fast near Hit. The Fists
  animations are R6. Palm Strike (Fists.4) strikes with the left arm, which is still
  sweeping in at Hit and fully extended ~0.04 s later.
- **Weapon techniques** anchor to the held weapon model (`ServerStorage.WeaponModels`: `Tip`
  and `Base` attachments on the joint part, plus `grip`/`butt`/`head` anchors).
  `WeaponFX.rig(character, full)` returns the live span (`Base` -> `Tip`, or `butt`/`grip`
  -> `Tip` with `full`, a virtual 4-stud blade off the arm when nothing is held) with `at(f)`
  and `attach(f)` (attachments that ride the weapon). A template's `Charge` part (block
  `bladeCharge`: Attachments with an `At` attribute 0..1) is played on it by
  `CombatEffects.windup` for every technique whose `weapon` is a class: `WeaponFX.charge`
  moves the attachments (with their emitters, Beams and Trails) onto the weapon and stops
  them at Hit. `TechniqueVFX.spawn` strips `Charge` from the release copy. A technique module
  can also export `windup(CombatEffects, def, level, character, seconds)` and return true to
  replace the default.
- Charge gathers into that limb during windup, and the release visibly travels from it to
  where the gameplay shape starts (e.g. hand → ground → ring). Gameplay shapes stay centred
  where the hitbox is (circles on the caster's feet).
- Ground raycasts must exclude characters. A ray down from the caster's root (or a target's
  centre) otherwise hits that body first, and the "ground" becomes torso height. Exclude the
  caster and targets, or all characters.

## Particle gotchas

- `ParticleEmitter.Size` is a radius (half-width): a ring that must reach radius R ends its
  Size curve at R.
- Ground-hugging horizontal spray (a dust ring): `Shape = Box`, `EmissionDirection = Front`,
  `SpreadAngle = (5, 180)`. Cylinder/Outward on a small part sprays everything one way.
- Flat ground decals: `Orientation = VelocityPerpendicular`, `EmissionDirection = Top`,
  `Speed = 0.01`. For a vertical plane facing the strike use `Back`/`Front`.
- Dust reaches roughly speed / Drag studs (about 110 with Drag 2.5 for r42).
- `MeshPart.MeshId` isn't writable from MCP scripts ("lacking capability"): create the part
  with `AssetService:CreateMeshPartAsync(id)` and clone it into the template. MeshId
  survives the binary export (about 40 KB per distinct mesh, shared between copies).
- Solid Neon mesh waves read as plastic. ForceField material on a funnel or twister mesh
  reads as moving air. (A ForceField distortion shell was tried and dropped: it didn't read.)

## Beams, surfaces, decals and textures

- A non-FaceCamera Beam's width runs along its attachments' local Y (SecondaryAxis); measured
  in Edit mode (2026-10-23, guide pass): identity attachments stand any beam up as a wall,
  `Angles(0, 0, pi/2)` on a beam along world X turns Y along the length and it vanishes, and
  `CFrame.fromMatrix(pos, along, sideways)` (X along the beam, Y sideways on the ground) lies
  it flat at any heading. Check from straight above before trusting an orientation.
- A Beam's Transparency (and Color) sequence is only sampled at its segment joints: with
  `Segments = 1` a 1 -> 0.3 -> 1 ramp draws fully transparent. Give ramped beams 8+ segments.
- `TextureSpeed > 0` scrolls the texture from `Attachment0` toward `Attachment1`.
- A chain of beams sharing attachments (a path over uneven ground) restarts its texture at
  each `Attachment0`: set each copy's `TextureLength` to its own length so every segment
  shows whole tiles, and use a texture that tiles top to bottom.
- A Beam runs its texture's vertical image axis along its length. Draw strip textures
  upright (tiling top to bottom), or they show as stripes across it.
- Fade-strip textures on a beam fade toward `Attachment1`, dimming a lance's business end.
  Use a plain gradient for the glow and a line texture for the core.
- Parent an Attachment before setting `WorldCFrame`. Unparented, WorldCFrame is stored as
  local, so the point lands at double its world position.
- Keep big surfaces under effects opaque. Transparent parts and particles are depth-sorted by
  part centre, so a slightly translucent water union drew over its own foam and splash
  particles and hid them.
- Decals render on Transparency-1 parts, so an invisible volume can carry a flat foam patch
  or seal decal.
- Any-shape flat surfaces: union blocks/cylinders (Studio CSG) into one part. A Texture tiles
  across the union's whole face, with no seams between pieces. The union takes its first
  part's rotation, so check which face points up. CSG (`UnionAsync`/`SubtractAsync`) errors
  unless at least one part is parented into the DataModel: parent the pieces first, then
  destroy them.
- Textures on a part's Top face: U runs along the part's X with its origin at the +X edge, V
  runs along Z from the +Z edge. A strip that grows from one end keeps its Texture still on
  the ground when that end is the +X edge. StudsPerTileV larger than the part's width with
  OffsetStudsV = (tile - width) / 2 shows only the middle band of the image (thin drawn
  strokes read thick).
- A SurfaceGui on a part didn't show in a `screen_capture` at all in one pass; in another (guide
  formation circle: `SizingMode` FixedSize 512, `LightInfluence` 0, `Brightness` 2.4, on a
  Transparency-1 carrier) it showed fine. A turning sigil as rotating ImageLabels on one
  SurfaceGui is cheap and steady.
