# Rampaging Tiger Cleave visuals

Covers the `RampagingTiger` technique effect (templates `RampagingTiger_T1..T4`, spec `tools/vfx_specs/RampagingTiger.luau`, `TechniqueFX.RampagingTiger`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md) (weapon-skill helpers: `BladeSkill`, `WeaponFX`, swing/cancel/punch/rend).

Templates `RampagingTiger_T1..T4`, authored at radius 10 around the caster;
`TechniqueFX.RampagingTiger`. Tawny amber qi over black brush-ink, white-gold
core at IV. Heavy pass 2026-10-23: the spec header holds the intent, beat sheet
and layer sheet; the animation, markers and def are untouched (the def's
weapon is the Saber / dadao).

**Beats** (clip markers drive them; real ms at castSpeed 1): the Charge along
the dadao (0-480); Hit 1 at 480, the diagonal cut; the Leap at 950; the wheel
1000-1780 (spin hits 1033, 1317); the landing cleave at 1783, the one peak;
follow-through to ~2200, dissipation to ~3500.

**Shipped look: direction A, "Tiger's claws"** (`spec.variant = "A"`):
- Every cut: three claw strokes (`Claw`, amber Beams over ink) in world space,
  running along the caster's look into the circle in a plane standing on that
  line, rolled -35 deg for Hit 1's diagonal and upright for the spin hits; a
  tip flare (`Flare`: ink splat, star-burst flipbook, glint, all flat in the
  claws' plane; sparks) at the blade's peak; a light impact per enemy.
- Leap: a ragged wind-ring mesh and a dust ring at the feet.
- The wheel (all tiers): `Wheel` stands in the blade's circle at the right
  side; each `Wheel*` emitter (VelocityPerpendicular, so it lies in the wheel
  plane) fires once per `Step` degrees the tip turns, sized to the blade's
  reach and rolled to the tip's angle (`RollSign` -1, `RollOffset`), so claw
  crescents (2x2 flipbook, amber over ink) tear round behind the tip. III+
  embers.
- Landing (Hit 4, at the swing's peak): the HERO is a giant three-claw rake on
  `Cleave`, a world-space plane along the cut (normal = swing x blade, kept
  near level; each emitter rolled by the swing's angle, clamped +-35 deg), on
  an ink copy: edge-on from behind, the full rake from the side. Then the core
  flash, an ink splat on the ground, chips, the tip flare in the cut's plane,
  three claw rends torn forward (`Gouge`/`GougeKicks`, `BladeSkill.rend`), a
  ragged shock ring and dust wall to r 10 (`Slam`; heavy impacts as the front
  reaches each enemy), III+ Craters rock ring and cracks, IV the one
  PointLight (2.5, 0.5 s). Hit-pause punch II+, shake 1.1 / 1.8 / 2.8 / 3.8,
  impact frames III+.
- Cut in this pass: the torus waves, the forward "roar" rings, the IV giant
  Beam claw, the IV swirl shell dome, the flat hit-ring splash.
- **No camera-facing shapes** (user, 2026-10-23): every shaped layer lies in a
  world plane set by the cut. Only round dust, motes, chips, sparks, the blade
  glow beams and the shared per-enemy impact (`impactStack`) face the camera.
  Built from library textures, flipbooks and meshes on emitters and beams;
  parts are invisible carriers only.

**Direction B, "Ink-brush cleave"** (`spec.variant = "B"`, finished): the
wheel is an ink ensō with an amber edge (brush crescent, longer life); the
landing hero is a huge brush stroke in the cut's plane over an umber dust
burst, with the same splat, rends and shock. Switch in the sandbox with
`_G.vfxSpecs.RampagingTiger.variant = "B"` then `.build(ReplicatedStorage.Effects.RampagingTiger)`.

**Sounds** (`SoundService.SFX.Techniques.RampagingTiger`, library ids, played
with `Sfx.play` at the beat and position): `Cut` (Swing (7), Hit 1),
`SpinCut` (Swing (3), Hits 2-3), `Hit` per enemy (gap 0.05), `Leap`
(WindWoosh, at the feet), `Whirl` (Magic WHOOSH, follows the wheel, cut at its
end), and at the bite `Bite` (Energy Sword Impact), `Slam` (Earth Slam, the
loudest) and III+ `Rumble` (Earthquake Debris).

**Layer counts** (emitters + beams per template): T1 53, T2 59, T3 66, T4 67;
per beat at T4: cut 3 claw strokes x2 beams + flare 4,
wheel 2 (+ embers), landing hero 2 + strike 3 + slam 2-4 + rends.

**Open items**
- B is slated to become Inkfall Cleave: its own def, templates and
  TechniqueFX module; the look is finished here.
- The per-enemy impact stack (shared `impactStack`) still faces the camera;
  ask before reorienting it, it is shared by every technique.
- Untested in play: feel at speed, the sounds' mix, phone cost, the rake's
  roll on real swings (Edit-mode previews scrub the clip).
