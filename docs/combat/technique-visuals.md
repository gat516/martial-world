# Technique visuals

Covers how technique effects are built, timed and played, and the helpers every technique shares; read it before changing any technique effect, then the technique's own file below. Gameplay shapes and numbers are in [combat](../systems/combat.md), the look in [style](../vfx/style.md).

## Playback and timing
Casts are drawn on every client: the caster draws its own at release, the server
relays `Effect "cast"` with the caster's technique level to everyone else, and
`CombatEffects.cast(character, id, origin, dir, chain, level)` plays the tier
template for that level. Visuals must match the gameplay shape (line length and
width, circle radius, chain jumps, zone radius and seconds, buff seconds).

Timing follows the cast's action timeline (`ActionRules.castProfile`, built
from `Config.Combat.FIST_STEPS` for the technique's animation): a template's
`Windup` part plays from cast start to Hit (`CombatEffects.windup`, caster
only), `cast()` runs at Hit, emitters tagged `Phase = "active"` are fitted to
Hit -> Hit Stop (`TechniqueVFX.fit` against the root's `AuthoredActive`), and
untagged aftermath keeps its authored fade through recovery.

## Templates and specs
Templates (`ReplicatedStorage.Effects`, `assets/Effects.rbxm`, built from the
vfxia Asset Library). Each technique's T1-T4 are generated in Edit mode from a
spec, `tools/vfx_specs/<Id>.luau` (a list of beats: `{ block, from, to,
params }`), by `vfxBlocks.buildFromSpec` (`tools/vfx_blocks.luau`, the shared
builders: ground/impact/air shockwaves, release flash, drop streak, hand
gather, impact burst/stack, crater ring, mesh shell, screen shake). Edit the
spec and rebuild rather than editing templates by hand; `tools/vfx_diff.luau`
checks a rebuild against the previous templates.

Techniques other than Palm Strike draw themselves in
`Client.TechniqueFX.<Id>` (`{ cast = function(CombatEffects, def, level,
character, origin, dir, chain): boolean }`; false falls back to the old
drawing in `CombatEffects.cast`).

## Per technique

| Technique | File |
|---|---|
| Palm Strike | [palm-strike](techniques/palm-strike.md) |
| Sword Qi Wave | [sword-qi-wave](techniques/sword-qi-wave.md) |
| Lightning Talisman | [lightning-talisman](techniques/lightning-talisman.md) |
| Fire Seal | [fire-seal](techniques/fire-seal.md) |
| Iron Skin | [iron-skin](techniques/iron-skin.md) |
| Heaven-Splitting Descent | [heaven-splitter](techniques/heaven-splitter.md) |
| Rampaging Tiger Cleave | [rampaging-tiger](techniques/rampaging-tiger.md) |
| Moonflash Draw | [moonflash-draw](techniques/moonflash-draw.md) |
| Dragon-Piercing Thrust | [dragon-pierce](techniques/dragon-pierce.md) |
| Crescent Moon Sweep | [crescent-sweep](techniques/crescent-sweep.md) |
| Twin Phoenix Cannon | [twin-phoenix-cannon](techniques/twin-phoenix-cannon.md) |
| Great Sage Awakening | [great-sage-awakening](techniques/great-sage-awakening.md) |

## Weapon skills: BladeSkill and WeaponFX
**Weapon skills with their own clip** (Heaven-Splitting Descent, Rampaging
Tiger Cleave) share `TechniqueFX/BladeSkill.luau`: the effect plays once per
cast (`claim`), on a clock that reads the move's playing AnimationTrack on
the caster (the caster's own, or the replicated one an observer sees), so
every beat lands on the clip's own pose even when the relay is late; beats
tied to a clip marker (`Hit` "n", `Leap`) fire on the marker, with the clip
time as the fallback. If the track stops before the last hit (a cancelled
cast) the rest is dropped. Without a track it runs from the first hit at
`def.castSpeed`. The blade draws its own arcs: the template's `Edge` Trails,
`Glow` beam and `Motes` move onto the held weapon's `Base`/`Tip`
attachments (a virtual blade off the right arm when no weapon is held) and
switch on for the windows where the sampled motion actually swings.
Previews: `_G.vfxSpecs.BladeKit.preview` (weapon rig, clip scrubbed at
castSpeed, root driven over `lungeWindow`).

**Swing, cancel, punch and rend** (QA pass 2026-10-21, after the remake's
playtest: "some of it stucks or doesn't properly align with the weapon").
The long clips' `Hit` markers fire as a swing starts (the blade still raised
behind the head), so `WeaponFX.swing(character, window, onPeak)` tracks the
held weapon's point relative to the root through that hit's Hit -> Hit Stop
window and calls back on the frame after its speed peaks (where the blade
bites; the window's end otherwise) with the point, the swing direction and
the blade axis. Flares (`WeaponFX.flare`), claws, light impacts and slam
bites play there, facing the way the blade cuts rather than the root's look.
A cast cut short (dodge, stun, any action before it finishes) calls
`CombatEffects.cancel` from `CombatController` (`stopRuntime` and the track's
Stopped handler): `WeaponFX.cancel` runs what was registered with
`WeaponFX.onCancel` (the `Charge`, the default hand gather, Great Sage's
twirl, Twin Phoenix's left-fist gather), so nothing keeps glowing after a
dodge. Observers never get the cancel; their copies end on their timers.
Big hits add `CombatEffects.punch(at, strength, tint, seconds)`: a camera
push-in and a short contrast/saturation grade through the Hit -> Hit Stop
window (the hit-pause feel; II+ or III+ only, tier I stays clean). The
no-Game-Module shake `SHAKE_BY_TIER` is 0.12 / 0.2 / 0.32 / 0.46. A strike
that carves the ground uses `BladeSkill.rend` (block `groundRend`), not a
Neon slit: Textures on a part laid from the bite (a black branching crack, a
jagged slit tinted the element and cooling to ink, III+ a wider crack web),
flat Beams of the element's qi burning in the crack and cooling
(`GlowFade`), and `RendKicks` stations that kick a smoke-flipbook puff,
falling rock chips, II+ a glowing star crack and III+ Craters rock kicks as
the carving reaches them, with a crack-web flipbook flash, a dark crater
crack and a dust ring at the bite. The shared hit stack (`impactBurst`) and
blade flare (`bladeFlare`) gained a white-hot core (hard dot, Brightness 4)
and a thin shock ring over deeper ink, falling rock chips under the target
at II+ and a spiky star on the flare at III+; every technique template was
rebuilt with them.

## MeshWave shockwaves and add-ons
3D shockwaves (all tiers) are MeshWave models, played by TechniqueVFX with
or without the Game Module: a Model with `MeshWave = true` and a child
`Mesh` part (Transparency 1 in the template), tweened at emit time relative
to its parent part/attachment from `FromSize`/`FromOffset`/`FromTransparency`
to `ToSize`/`ToOffset`/`ToTransparency` over `Duration` (`Style` easing,
`Rotation` degrees, inherited `EmitDelay`; `Phase = "active"` lets `fit()`
retime it). Names avoid Start/End so SimpleMeshVFX doesn't also play them.
Palm Strike: `Ground/GroundWave` (torus to `def.radius`), per target
`Impact/GroundShock` and `Body/ImpactRing` (II+ `ImpactSwirl`, III+
ForceField `ImpactBubble`), and `Palm/AirRing` (1/1/2/3 flying forward).

Add-ons used: Craters (`CraterVFX` attachments `RockRing`, `Kick`; enemies
get the client-only `CraterIgnore` tag so rocks skip them), SimpleMeshVFX
(`Shell`, `Dome` Start/End models), Splines (`Wisps`, emitted explicitly:
emitting a part doesn't reach parts nested in it), ScreenEffects
(`CameraShake`/`ImpactFrames` CSV attributes on attachments `Shake`,
`Frames`, `Quake`). All need the Game Module with those add-ons installed in
the place; without it (`TechniqueVFX.full` false) only the particles play and
`CombatEffects.shake` stands in for the camera shake.

## Known gaps
- Observers get a cast only at its first hit, so they never see a windup:
  no weapon technique's `Charge`, no Great Sage twirl (`CombatEffects.windup`
  runs on the caster only).
- Per-technique gaps are in each technique's file (Palm Strike, Sword Qi
  Wave, Fire Seal, Heaven-Splitting Descent, Great Sage Awakening).
