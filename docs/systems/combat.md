# Combat and action states

## Purpose
Action combat against beasts: an M1 chain per weapon class (a five-hit fist
chain bare-handed; see [weapons](weapons.md)), a flying-sword dash with
i-frames and perfect dodges, and up to a few equipped techniques. Realm power
scales all player damage.

## Design intent
- Responsive on every device: the client predicts actions and hits; the server
  re-checks the same timelines and owns damage and cooldowns.
- Every enemy attack that hurts is telegraphed on the ground first, and dodging
  through it negates it. A **perfect dodge** (just before the hit) refunds
  technique cooldowns.
- Souls-style lock-on (PC T/middle mouse, gamepad R3, touch Lock button) and a
  touch **Auto** mode that locks, closes in and strikes by itself so mobile
  players only dash and cast.
- Getting hurt marks you in combat for a few seconds: no teleporting away, and
  it's the condition for a forced breakthrough.

## Key files
- `src/shared/ActionRules.luau`: the one action timeline (attack, cast, dodge),
  combo state, buffers and cooldowns, shared by client and server.
- `src/shared/Hitbox.luau`: the shared M1 hitbox, per weapon class.
- `src/shared/Weapons.luau`, `src/server/Weapons.luau`: weapon classes, the
  equipped weapon, grade and Dao multipliers ([weapons](weapons.md)).
- `src/shared/Techniques.luau`: technique defs (line, circle, chain, zone, buff),
  levels (`MAX_LEVEL` 10, +8% damage a level, XP per cast). At the top of
  tiers I-III (levels 3, 6, 9) XP stops at a bottleneck (`Techniques.bottleneck`);
  the player breaks it seated in meditation by spending insight and Spirit Stones
  (`InventoryAction "comprehend"` -> `Progression.comprehend`, costs in
  `Pacing.Comprehension`), which opens the next visual tier.
- `src/shared/Knockback.luau`: how far player hits push beasts (by realm power
  ratio and beast weight) and the stagger they cause.
- `src/server/Combat.luau`: `action` (Attack remote: begin/hit/cancel/sync),
  damage validation, `damageEnemy`, `hurt` (i-frames, perfect dodge, Iron Skin,
  non-lethal), `power` (the stage's `power`), `inCombat`, technique XP.
- `src/server/Movement.luau`, `src/client/Movement.luau`: the only writers of walk
  speed, jump and facing (actions, running, herb buffs, meditation all feed it).
- `src/client/CombatController.luau`: input, prediction, buffering, animations.
- `src/client/ActionState.luau`: local predicted action state, and
  `crowdKind`/`crowdLocked` (the local player's flinch/stagger/stun).
- `src/server/PlayerStun.luau`, `src/client/CrowdControl.luau`: player flinch,
  stagger and stun ([Player crowd control](#player-crowd-control)).
- `src/client/LockOn.luau`, `Sprint.luau`, `ShiftLock.luau` (Alt), `HeadLook.luau`.
  Sprint's loop is `Animations/Run` in `assets/Animations.rbxmx` (rbxassetid
  117319074411273, the new run clip; the old one was 81617655199380). Its
  playback speed is scaled from `Config.Movement.RUN_ANIMATION_SPEED` (26 studs/s,
  set for the old clip), so the new clip's pace is untuned: check the feet against
  the ground at run speed and retune that number if it slides.
- `src/client/CombatEffects.luau`, `Telegraphs.luau`: cosmetic effects and ground warnings.
- `src/client/CastFX.luau`: shared runtime helpers for technique effects, used
  for the caster's own casts and relayed ones alike: the striking limb
  (`handPosition`, R6/R15), the ground under a point with characters, enemies
  and effects excluded (`groundBelow`), the enemies a circle/zone/line covers
  with their near-side contact point and arrival progress (`targets`), arrival
  timing from a growing curve (`curveTime`/`frontTime`), impacts placed on a
  target (`impactAt`), and cast phases from `ActionRules.castProfile` (`phases`).
- `src/client/TechniqueVFX.luau`: plays technique effect templates
  (`ReplicatedStorage.Effects.<Id>.<Id>_T<tier>`) through the vfxia Game Module
  (`ReplicatedStorage.vfx`, plugin-owned, not mapped); falls back to plain
  `ParticleEmitter:Emit` with a warning while the module is missing.

## Techniques and weapon gating
Every technique has a `weapon`: a weapon class or `"Any"`. A class technique
casts only with that class equipped: the client shows "Requires a sword" (or
"Requires bare hands") without starting, and the server refuses the begin with
the same message. Class techniques scale with the class's grade and Dao
comprehension, and each cast grants that class `Pacing.Weapons.XP_CAST` Dao XP.
- Any: Lightning Talisman, Iron Skin, Fire Seal. Fist: Palm Strike. Sword: Sword Qi Wave.
- Weapon skills play their own clip (`Animations.Techniques.<Id>`) at
  `castSpeed`; `hits` lists each strike's clip window and damage (matching the
  clip's `Hit`/`Hit Stop` markers, numbered for multi-hit). Windup runs to the
  first hit, the active window to the last stop, and the caster is committed
  through it. The client reports the first hit; the server lands the later ones
  at their times from wherever the caster is then (unless the action ended).
- `lunge`: the client drives the root forward over `lungeWindow` (the clip's
  Lunge or Leap -> Land markers); each hit is measured from the root unless it is
  farther from the cast's start than the lunge plus `LUNGE_SLACK` and
  `LUNGE_WALK_ALLOWANCE`, when it's pulled back.

| Id | Weapon | Shape | Hits (dmg) | Lunge | Cooldown |
|---|---|---|---|---|---|
| TwinPhoenixCannon | Fist | line 18 x 6, right then left fist | 14, 14 | - | 9 |
| MoonflashDraw | Sword | line 18 x 5 from the cast's start (the dash path) | 30 | 14, i-frames while dashing | 7 |
| RampagingTiger | Saber | circle r 10 around the caster | 9, 7, 7, 16 | 6 over the leap | 12 |
| HeavenSplitter | Greatsword | circle r 12 centred 4 ahead | 6, 6, 60 (slam) | 6 over the leap; castSpeed 1.3 | 16 |
| CrescentSweep | Guandao | circle r 11 | 32 | - | 9 |
| DragonPierce | Spear | line 22 x 4 | 34 | 8 | 8 |
| GreatSageAwakening | Staff | buff 8 s: +25% all damage, +15% M1 speed; circle r 8 burst at the strike | 12 | - | 20 |

## Dodge visuals
Only the dodging player sees them (`CombatEffects`, from `CombatController`).
Templates: `ReplicatedStorage.Effects.Dodge`, built by
`tools/vfx_specs/Dodge.luau` (`_G.buildDodgeFX(staging)`; no tiers).
- **Dodge** (`dashTrail`): one light qi streak along the path, two
  camera-facing jade Trails (`Dodge.Streak`) moved onto the root for the dash
  and gone ~0.2 s after it. Nothing else: no gust, no afterimages, nothing
  left behind.
- **Perfect dodge** (`perfectDodge`, on `Effect "perfect"`, i.e. when the hit
  would have landed), "the blow cut only a shadow": a gold Neon ghost of the
  body is left where the dash began (holds 0.12 s, dissolves over 0.45 s) with
  a white star glint where the blow meets it and gold motes lifting off it
  (`Perfect.Ghost`); a gold Beam streak from the ghost to the player
  (`Perfect.Streak`, held 0.1 s, thinned out over 0.3 s); a glint, flare and
  sparks on the player (`Perfect.Player`) with a gold Highlight rim (0.35 s; Highlights are capped at 31 on screen, so map dressing must carry none);
  the rest of the dash streak turns gold; and a short desaturated time-slow
  grade (0.08 s hold, 0.4 s return). No ground ring and no shake.

## Technique visuals
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

Templates (`ReplicatedStorage.Effects`, `assets/Effects.rbxm`, built from the
vfxia Asset Library). Each technique's T1-T4 are generated in Edit mode from a
spec, `tools/vfx_specs/<Id>.luau` (a list of beats: `{ block, from, to,
params }`), by `vfxBlocks.buildFromSpec` (`tools/vfx_blocks.luau`, the shared
builders: ground/impact/air shockwaves, release flash, drop streak, hand
gather, impact burst/stack, crater ring, mesh shell, screen shake). Edit the
spec and rebuild rather than editing templates by hand; `tools/vfx_diff.luau`
checks a rebuild against the previous templates.
- **Palm Strike** (`PalmStrike_T1..T4`, authored at radius 9, rescaled to
  `def.radius`). Fists.4 strikes with the **left** hand (`def.hand`), which
  `CombatEffects` finds on the live character (R6 arm tip, R15 grip
  attachment), for observers too. Windup (caster only): qi motes and a charge
  glow ride the swinging hand (II+ Spline wisps curve in, III+ a seal closes
  on it). At Hit: a flash from the palm, a streak drops from it to the ground
  and splashes, and the gold shockwave opens from the feet (the gameplay
  centre) to the radius by Hit Stop, with dust kicked along the ground.
  Each enemy inside the radius gets an impact as the front reaches it: star
  flash, spiky ring, sparks, drawn in front of it, plus `CombatEffects.flash`.
  II adds an echo ring, rays and impact dust; III a seal, cracks, a spinning
  SimpleMeshVFX shell, a Craters rock ring erupting with the wave and rock
  kicks on the first three targets; IV a crater, a dome shell, a nimbus halo
  behind the head, one point light, ScreenEffects impact frames and an
  Explosion shake on the first impact. Remade 2026-10-21 for the Hit window
  (bare hand, so the anchors stay on the live left palm): the windup qi is a
  stream through the whole 0.38 s (the hand gather's `Gather` runs on
  `Rate` + `EmitDuration`, scaled by `TechniqueVFX.fit`), the palm release
  gets the shared flare (cross glint, star-burst flipbook over ink, sparks) and
  a cross glint on the release flash, and every impact picks up the shared ink
  splat and star-burst flipbook (smoke flipbook tail at III+). The wave front
  was already fitted to Hit -> Hit Stop, so the sandbox run landed impacts
  0.04-0.05 s after the release. Layers T1 / T4: windup 2 / 4, release 9 / 13,
  ground 3 / 8, impact 8 / 14.
- Techniques other than Palm Strike draw themselves in
  `Client.TechniqueFX.<Id>` (`{ cast = function(CombatEffects, def, level,
  character, origin, dir, chain): boolean }`; false falls back to the old
  drawing in `CombatEffects.cast`).
- **Sword Qi Wave** (`SwordQiWave_T1..T4`, authored at length 32 and width 5;
  `TechniqueFX.SwordQiWave`). Fists.3 cuts flat across the front with the
  **right** arm, so the release flashes on the live right hand at Hit: a star
  flash, 3D swirl air rings thrown forward, a light shake. The blade (`Blade`)
  is a horizontal crescent of Beams (core, edge and a camera-facing glow
  layer) with a wake trail. It flies the line on the template's `TravelCurve`
  over `TravelTime` (0.36 s), driven by a pausable tween registered in
  `TechniqueVFX.waves`. A ray along the path stops it at a wall or rising
  ground, and it bursts where it ends (`Terminal`: `impactBurst` +
  `impactShockwave`, III+ a Craters ring). Each enemy on the line gets a cyan
  `impactStack` plus a crescent cut flash when the blade's front reaches its
  near side (`curveTime`), and `CombatEffects.flash`. Behind the blade a Neon
  slit (`Cut`) is drawn on the ground and cools into an ink scar (`Scar`); II+
  motes rise off it (`Path`). II adds an echo blade, release sparks, impact
  swirl and dust; III a second echo, a second air ring, bubbles, rock kicks,
  path cracks and the terminal crater; IV a gold core, three air rings, one
  point light riding the blade, a sword-intent crescent and impact frames at
  the release, and a quake on the first impact. Damage still lands on the
  whole line at Hit. Remade 2026-10-21 on the jian and the Hit window: the
  0.32 s windup is a `Charge` along the model's Base -> Tip (dark beam under a
  cyan one, motes, a point glint) instead of a hand gather; the release (star,
  the shared flare, air rings) bursts on the blade 0.8 of the way to the tip,
  not on the hand, and the real edge draws its own ribbon, glow and motes
  (`Edge`, `BladeSkill.edge`) through the cut; the crescent has an ink crescent
  under it and crosses the line in 0.12 s (was 0.36), the echoes trailing, with
  every impact squeezed into Hit 0.35 -> Hit Stop 0.467 (`WeaponFX.landing`; a
  sandbox run with a jian landed them 0.02-0.03 s after the release and the
  terminal at 0.13 s) instead of up to ~0.36 s after the damage number; every
  cut gets a cyan crescent flipbook and the shared ink splat and star-burst
  flipbook. Layers T1 / T4: charge 8 / 8, release 8 / 12, edge 3 / 4, blade 11,
  impact 10 / 16, terminal 10 / 16.
- **Lightning Talisman** (`LightningTalisman_T1..T4`;
  `TechniqueFX.LightningTalisman`). At Hit a paper talisman card leaves the
  left hand (Fists.2) and tumbles to a point above the first target in
  `chain`, where it flares and burns while a jagged bolt strikes down. Bolts
  then hop along `chain` every `HopDelay` (0.04 to 0.028 s by tier), bowing over
  the bodies. Each target gets an impact (flash, Neon impact torus, ground
  shock, crackle; II+ scorch and seals); the last gets a heavier finale with an
  electric ring, a ground splash and a shake (III+ Craters rocks). With no
  target the card flies to max range or the first wall or ground and bursts
  there. II adds forks, release sparks and an air ring; III a double strand,
  seals under every target and impact bubbles; IV two forks and a sky strike on
  the first target with the move's one light and a quake. Bolts are Beams on
  a jittered attachment chain; with the Game Module the main core is the
  LightningBeams add-on. Tuning lives in root attributes (`HopDelay`,
  `Strands`, `Forks`, `BoltWidth`, `BoltLife`, `Segments`, `Jitter`,
  `Flickers`, `CardSpeed`, `SealTargets`, `SkyStrike`). Damage lands at Hit;
  the hops are only a visual stagger. When `chain` is nil (Edit previews) the
  module predicts it with Combat.chainTargets' rule. Remade 2026-10-21 for the
  Hit window (bare hand, so the anchor stays on the live left palm): the card
  now crosses in 0.05-0.12 s (`CardSpeed` 200-245 studs/s, was 110-125 and up
  to 0.22 s) and the hops are 0.04-0.028 s apart (were 0.12-0.09 s), so the
  first strike lands ~0.05 s after the release and the whole chain within
  ~0.15 s instead of up to ~0.5 s after the damage number (a sandbox run
  landed the first impact 0.03 s and the finale 0.1 s after the release); the
  windup is a stream through 0.25 s; the release on the hand gets the shared
  flare (violet cross glint, star-burst flipbook over ink, sparks); every
  impact carries the shared ink splat and star-burst flipbook. Layers T1 / T4:
  windup 4 / 6, hand release 7 / 9, card 5, impact 9 / 17, finale 15 / 20,
  fizzle 11 / 17.
- **Fire Seal** (`FireSeal_T1..T4`, authored at radius 8, a 0.214 s active
  window and 4 s; `TechniqueFX.FireSeal`). Fists.4 strikes with the left hand.
  Windup: qi gathers into the palm. At Hit the seal is thrown as a projectile
  (a Neon core with a trail and a spinning ring, `Palm/Bolt`, `BoltRing`),
  whose 0.24 s flight is fitted to the active window, and lands at the zone
  centre (`def.offset` ahead, on the ground) with an impact stack and a torus
  rolling out to the rim (`Land`, delayed by the flight). For `def.seconds` a
  raised Neon `Rim` torus marks exactly `def.radius`, with a turning rune
  glyph, flame tongues and embers (`Zone`, enabled/disabled by the runtime;
  its held MeshParts carry `Show`/`Spin`/`Flicker`). Every `def.tick` a
  `PulseRing` sweeps to the rim, the rim flares, and each enemy inside
  (re-queried per tick, up to 4) gets a burn hit (`Impact`: flare, embers,
  `impactShockwave` rings) and an orange `CombatEffects.flash`. At the end the
  hold fades and `Finale` bursts. Ticks are counted on the client from the
  cast time (k × tick, the first held until the landing), because the server's
  ticks aren't sent. II adds a spinning `InnerSeal` and rim flares; III a
  counter-rotating `CounterSeal` and second glyph, a `FlameWall` spike crown
  on the rim, `PulseCrown` spikes per tick, a Craters rock ring, scorch and
  shake at the landing, and a flame tongue under each burn hit; IV a flame
  `Pillar` at the landing, the move's one PointLight, and a big finale with an
  Explosion shake. Remade 2026-10-21 for the Hit window (bare hand, so the
  anchor stays on the live left palm): the 0.5 s windup is a stream through
  the whole windup (not one burst), the release on the palm gets the shared
  flare (fire-orange cross glint, star-burst flipbook over ink, sparks), and
  every burn hit and the landing carry the shared ink splat and star-burst
  flipbook. The seal's flight was already fitted to Hit -> Hit Stop (0.14 s).
  Layers T1 / T4: windup 2 / 4, palm 10 / 11, landing 11 / 22, zone 2 / 3,
  burn hit 4 / 5, finale 4 / 7.
- **Iron Skin** (`IronSkin_T1..T4`, authored for the 4 s buff and a ground ring
  of r 4; `TechniqueFX.IronSkin`; new 2026-10-21, it used to be a Highlight and
  a burst of sparkles). The Golden Bell: the body hardens into plated
  gold-bronze. Windup (0.2 s, caster only, the shared hand-gather stream at the
  chest). At Hit (Fists.1) a flash and the shared flare on the torso, a gold
  ground ring, and a bell: a ForceField sphere snapping out round the body with
  a ring. Then the buff holds for `def.seconds` on every client: plate glints
  flickering over dark soot flecks on the torso and gold gleams off the arms
  (emitters moved onto the body parts named by their `Bone` attribute); II+ a
  pulsing ForceField `Shell` part round the body; III+ a rune seal turning
  under the feet; IV a ringed halo over the head. It ends with a ring and gold
  dust (`Fade`), or stops at once if the caster dies. Layers T1 / T4: windup
  2 / 3, release 9 / 10, ground 3 / 4, loop 4 / 6, end 2.
- **Weapon skills with their own clip** (Heaven-Splitting Descent, Rampaging
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
- **Swing, cancel, punch and rend** (QA pass 2026-10-21, after the remake's
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
- **Heaven-Splitting Descent** (`HeavenSplitter_T1..T4`, authored at radius 12
  centred 4 ahead; `TechniqueFX.HeavenSplitter`). Heaven-azure qi, white core
  (gold at IV), ink scars. Light hits (Hit 1 sweep, Hit 2 rising cut): a light
  impact on each enemy in the circle. Leap: a torus and dust ring at the feet,
  II+ swirl rings rising up the body. Airborne: the blade glows and sheds
  motes; III+ a faint rune seal opens over the landing circle (following the
  predicted landing) and a vertical rift tears open in the sky above it; III+
  a phantom greatsword (ForceField at III, Neon at IV) rides the real blade
  down and bites the ground, holds and dissolves. Slam (last hit, at the
  root's live position): a star flash where the blade bites, a fissure split
  from there through the circle (Neon slit cooling to an ink scar), a torus
  shockwave rolling out to the radius with a dust skirt and rays, heavy
  impacts timed by the torus front; II+ a pillar of light collapses onto the
  bite and an echo torus; III+ Craters rock ring, crater and cracks, rock
  kicks, fissure cracks; IV a dome shell, the one PointLight, impact frames
  and an Explosion quake. Remade 2026-10-21 on the greatsword and the clip's
  markers: the windup (0 -> Hit 1, 0.14 s at 1.3x) is a `Charge` along the
  model's Base -> Tip (dark beam under an azure one, motes, a point glint)
  instead of a hand gather; each Hit marker flares on the live blade tip
  (`Flare`: cross glint, star-burst flipbook over an ink splat, sparks; 1.5x at
  the slam); the slam's heavy impacts are squeezed into Hit 3 -> Hit Stop 3
  (`WeaponFX.landing`) instead of following the 0.5 s torus; every impact also
  carries the shared ink splat and star-burst flipbook. Layers T1 / T4:
  charge 8 / 8, flare 4, light impact 8 / 12, slam 8 / 15, impact 8 / 14.
- **Rampaging Tiger Cleave** (`RampagingTiger_T1..T4`, authored at radius 10
  around the caster; `TechniqueFX.RampagingTiger`). Tawny amber qi over black
  brush-ink, white-gold core at IV. Every cut flashes three claw strokes in the
  air (`Claw`: amber Beams over ink, diagonal for Hit 1, vertical for the spin
  hits and the landing) and an impact on each enemy in the circle. Leap: a
  torus and dust ring. II+ while the blade wheels (1.0-1.78 clip) a spinning
  amber swirl ring stands in its circle at the right side (`Wheel`, sized to
  the blade's reach; III+ a counter-turning ForceField ring, embers). Landing
  (last hit): flash where the blade bites, three claw gouges fanned forward
  (Neon slits cooling to ink), roar rings thrown forward (1/1/2/3), a torus
  shockwave to the radius, heavy impacts by the front; III+ Craters rock
  ring, cracks, rock kicks; IV a giant claw over the strike, a swirl shell,
  the one PointLight, impact frames and a quake. Remade 2026-10-21 on the
  saber and the clip's markers: the windup (0 -> Hit 1, 0.48 s) is a `Charge`
  along the dadao's Base -> Tip (dark beam under an amber one, motes, a point
  glint) instead of a hand gather; each cut (Hit 1-3) and the landing (Hit 4)
  flare on the live blade tip as the marker fires (`Flare`: cross glint,
  star-burst flipbook over an ink splat, sparks; 1.5x at the landing); and the
  landing's heavy impacts are squeezed into Hit 4 -> Hit Stop 4 (0.117 s,
  `WeaponFX.landing`) rather than following the 0.46 s torus out to r 10. All
  hits also get the shared ink splat and star-burst flipbook. Layers T1 / T4:
  charge 8 / 8, cut flare 4, claw 12, impact 8 / 14, landing 8 / 14.
- **Moonflash Draw** (`MoonflashDraw_T1..T4`, authored along a 14-stud dash
  with width 5; `TechniqueFX.MoonflashDraw`). An iaido dash-cut in silver
  moonlight: the clip draws the blade from the right hip and sweeps it flat
  round the front at chest height while the caster lunges `def.lunge` from Hit
  to Hit Stop. Windup: a glint on the drawing hand. At Hit a crescent-moon
  flash and swirl air rings burst on the hand. A horizontal crescent of Beams
  (`Front`) rides `def.length - def.lunge` studs ahead of the caster's live
  root (with a time floor so it never stalls), dragging a wake band as wide as
  the hitbox, a streak Beam from the dash start (`Streak`) and a glowing slit
  on the ground (`Cut`) that cools into an ink scar (`Scar`). Each enemy on the
  line gets a silver `impactStack` and a crescent cut as the front passes it.
  The dash ends in a crescent mark and ground torus at the feet (`Finish`).
  II+ leaves Neon afterimages of the body along the path (1/2/3 by tier), an
  echo crescent, and the signature "sheathe": ~0.12 s after the dash every
  target cut flashes again with a crossing crescent and a standing white ring
  while the slit flares (`Sheathe`). III adds 2 air rings, impact bubbles and
  rock kicks, path cracks and a Craters ring at the finish; IV a gold core,
  three afterimages, one point light on the front, a crescent moon rising
  behind the finish, impact frames at the sheathe and a quake on the first
  impact. `WeaponFX` (same folder) holds the helpers the weapon skills share.
  Remade 2026-10-21 on the jian itself (`WeaponFX.rig`, the model's Base ->
  Tip): the windup is a `Charge` along the blade (dark beam under a cold bright
  one, motes, a glint at the point: the blade catching the light as it clears
  the scabbard, 0.067 s); the draw flash, moon and air rings burst on the
  blade 0.8 of the way to the tip rather than on the hand; through the dash an
  `Edge` rides Base -> Tip (a solid moon ribbon, II+ a long afterimage, a Glow
  beam, shed motes); the crescent front has an ink crescent under it; every cut
  gets a crescent-moon flipbook (and the shared ink splat and star-burst
  flipbook), fired as the front passes it, so all of it sits inside the
  lunge window (Hit 0.067 -> Hit Stop 0.233, the clip's Lunge markers); a
  `SheatheGlint` (star, halo, crescent flipbook, motes) flares on the live tip
  as the blade is put away, 0.12 s after the dash. Layers T1 / T4: charge 8 /
  8, release 5 / 8, edge 3 / 4, travel 13 / 13, impact 10 / 16, sheathe 4 / 9,
  finish 3 / 4.
- **Dragon-Piercing Thrust** (`DragonPierce_T1..T4`, authored at length 22
  and width 4; `TechniqueFX.DragonPierce`). A red-tasselled spear dragon in
  crimson and gold: the clip draws the spear back along the right side, then
  drives it round and forward from Hit to Hit Stop while the caster lunges.
  Windup: crimson qi spirals into the hands (II+ Spline wisps, III+ a seal).
  At Hit a forward-facing vortex disc, a star and swirl air rings burst where the
  lance starts on the line, at the height of the live spear point (the
  weapon's `Tip` attachment, else the right hand). A
  drill of qi (`Lance`: twisted spiral-cone MeshWaves stretched to the line,
  `Stretch = true`) shoots from the point to the line's end on `TravelCurve`
  over `TravelTime` (0.16 s), with a gold core and crimson glow Beam and a hot
  head shedding sparks; swirl rings (`Ring1..n`, `Station` = fraction along
  the line) burst across the line as the front passes them. A ray stops it at
  a wall. Each enemy gets a crimson `impactStack` plus sparks punched out of
  its far side when the front reaches it, and the lance bursts at its end
  (`Terminal`: impact stack and vortex). A dark `Furrow` follows the front
  and fades. II adds a gold dragon helix coiled round the lance, path dust
  and motes, impact swirl; III a counter-wound second helix, impact bubbles
  and rock kicks, a Craters ring at the terminal, path cracks; IV a gold-white
  core, five rings, the dragon seal flashing at the point with impact frames,
  one point light on the lance head and a quake at the terminal. Remade
  2026-10-21 on the spear and the thrust's window: the 0.3 s windup is a
  `Charge` along the whole spear (butt -> head, `full`: a dark beam under a
  crimson one, motes along the shaft, a glint on the head) instead of a hand
  gather; the release on the live spear head gets the shared flare (cross
  glint, star-burst flipbook over ink, sparks); the lance has an ink beam under
  its glow; the front crosses the line in 0.12 s (was 0.16) and every impact is
  squeezed into Hit 0.30 -> Hit Stop 0.40 (`WeaponFX.landing`; a sandbox run
  with a spear on the rig landed the impacts 0.06 s and the terminal 0.07 s
  after the release); impacts carry the shared ink splat and star-burst
  flipbook. Layers T1 / T4: charge 8 / 8, release 9 / 13, lance 9 / 14,
  impact 9 / 15, terminal 9 / 15.
- **Crescent Moon Sweep** (`CrescentSweep_T1..T4`, authored at radius 11;
  `TechniqueFX.CrescentSweep`). A jade crescent cut out of the air: the clip
  winds the guandao back low behind the left hip, then from Hit to Hit Stop
  whips it round ~323 deg in one low spin (behind, right, front, left).
  Windup: jade motes gather into the grip (II+ wisps, III+ a seal). At Hit a
  flash on the blade tip. The `Sweep` part is turned round the caster on that
  heading curve (`StartHeading` -126, `SweepDegrees` 323 over the active
  window, then `FollowDegrees` of follow-through), so its radial Trails lay a
  flat jade sheet with a bright moon edge at the blade's reach that closes into
  a disc and fades. A ground torus rolls out to `def.radius`, a wispy swirl
  ring spreads at knee height, dust is kicked outward and a jade-ink crescent
  is scorched under the sweep. Each enemy in the circle gets a jade
  `impactStack` and a crescent cut when the blade's heading passes it (one in
  the arc the spin skips, behind-left, at Hit Stop). II adds an inner edge,
  wave echo and rays, rising motes, impact swirl; III a spinning SimpleMeshVFX
  swirl shell, a Craters ring erupting with the wave, impact bubbles and rock
  kicks; IV a gold edge, a jade-gold moon rising behind the caster, one point
  light on the sweep, impact frames at the release and a quake on the first
  impact. Remade 2026-10-21 on the guandao and the Hit window: the 0.63 s
  windup is a `Charge` along the whole pole (butt -> blade, `full`; dark beam
  under a jade one, motes along the shaft, a glint on the blade) as it is
  wound back; the release flash on the blade gets the shared flare (cross
  glint, star-burst flipbook over ink, sparks); the sheet lies on a dark ink
  sheet and the real blade draws its own ribbon, glow and motes (`Edge` on the
  model's Base -> Tip) through the spin; every cut gets a crescent-moon
  flipbook plus the shared ink splat and star-burst flipbook. Impacts already
  fire as the heading passes (inside Hit 0.633 -> Hit Stop 0.75 plus the
  follow-through). Layers T1 / T4: charge 8 / 8, release 6 / 6, sweep 4 / 5,
  edge 3 / 4, ground 6 / 11, impact 10 / 16.
- **Twin Phoenix Cannon** (`TwinPhoenixCannon_T1..T4`, authored at length 18
  and width 6; `TechniqueFX.TwinPhoenixCannon`). The skill animation throws
  two overhand forward punches, right fist at `Hit "1"`/`Release "1"` (0.30)
  and left at `Hit "2"` (0.833); each fist is fully extended ~0.03 s later,
  where its release plays on the live hand. `cast()` runs at the first hit
  and schedules the second from `def.hits` at the cast's playback rate. Each
  blast is a phoenix: a Neon fire head with swept-back Beam wings and a
  burning tail (`BlastR` crimson, `BlastL` gold and a size up) flying the line
  on its `TravelCurve` (~0.26 s), stopped by walls or rising ground, with a
  muzzle flash and 3D air rings off the fist (`FistR/L`), a fire impact on
  every enemy its front reaches (`ImpactR/L`: impact stack plus flame flare),
  an explosion where it ends (`TerminalR/L`) and a burn line cooling to a
  char mark (`BurnR/L`, `CharR/L`). Between the blasts gold qi gathers in the
  left fist (`Gather`, everyone sees it). II adds flame feathers off the
  wings, release sparks, embers off the burn line and impact swirl/dust; III
  a rune "cannon seal" at each fist, 2 air rings, impact bubbles and rock
  kicks, a terminal Craters ring and a small shake; IV 3 air rings, white-gold
  heads, the one light riding the golden bird and a fire dome with a spike
  crown and an Explosion quake at its terminal. Damage lands on the server's
  hit times. Remade 2026-10-21 for the hit windows: each bird flies in 0.15 s
  (0.17 s gold) and every impact is squeezed into that blow's Hit -> Hit Stop
  window (`WeaponFX.hitWindow`/`landing`, floor 0.1 s) instead of trailing the
  damage number by up to 0.28 s. Layers added: a spiky flame-aura flipbook
  `Plume` streaming back off each bird's head, a `FistFlame` flipbook on the
  charging fist through the windup (and the left fist between the blasts), a
  coloured fire-flipbook `MuzzleFire` over an ink splat at each release, an
  ink splat and fire-flipbook `Bloom` (II+ a smoke flipbook) at each terminal,
  and the shared hit stack's ink splat and star-burst flipbook on every
  impact. The windup is a stream through 0.30 s, not one burst. Layers per
  beat for one bird (T1 / T4): windup 6 / 9, release 6 / 10, travel 10 / 11,
  impact 9 / 15, terminal 13 / 21, tail 2 / 3.
- **Great Sage Awakening** (`GreatSageAwakening_T1..T4`, authored at radius
  8 and 8 s; `TechniqueFX.GreatSageAwakening`). The Monkey King wakes: his
  golden circlet, golden flame, the somersault cloud, fiery eyes. The staff
  animation twirls the staff flat overhead (`Twirl "start"` 0.167 to `"end"`
  1.0, all on the `Hilt` joint) and brings one end down on the ground ~5
  studs ahead at `Hit` (1.15). Windup (`windup()`, needs the
  CombatEffects hook, see known gaps): from the Twirl start, gold ribbon
  Trails on both ends of the staff (the weapon's `Tip`/`Base` attachments)
  draw a spinning disc of arcs over the head; a rune seal grows under the
  feet with motes rising into the spin (`Twirl`), qi gathers into the right
  hand (`Windup`); III+ a wind swirl climbs the body. At Hit: a slam impact
  where the low staff end meets the ground (`Slam`), a gold flash on the body
  (`Body`), the shared ground shockwave to `def.radius` and a pillar of gold
  light (stretched Neon ball) from the feet (`Ground`), and a gold impact on
  each enemy as the front reaches it. Then the buff aura holds for
  `def.seconds` on every client (`Aura`): a gold Neon circlet round the head,
  gold flame wisps rising off the torso, and short gold arcs off the staff on
  every swing (`Staff`); it ends with a puff (`Fade`) or stops if the caster
  dies. II adds rays, an echo ring, pillar streaks, cloud puffs at the feet,
  rising motes and a pulsing circlet; III a ground seal, slam cracks, a
  Craters rock ring, impact bubbles and kicks, and two glowing golden eyes;
  IV a second torus, a taller pillar with a spike crown, an Explosion quake,
  a turning halo behind the back and the move's one light (flashed at the
  strike, then a soft gold glow for the buff). Remade 2026-10-21 on the staff
  and the Hit window: the twirl's trails and the buff's arcs now ride the
  staff's real ends (the model's `butt` and `Tip`; `Base` is only the grip side
  of the head, so the old trail started a hand's width from the head), a
  `Charge` (a dark beam under a gold one, motes along the whole staff,
  `WeaponFX.charge` full) runs along it while it spins, the slam gets the
  shared flare (cross glint, star-burst flipbook over ink, sparks) where the
  end bites, and every impact is squeezed into Hit 1.15 -> Hit Stop 1.25
  (`WeaponFX.landing`; a sandbox run with a staff landed them 0.04-0.05 s after
  the release). The `windup` hook now exists in `CombatEffects.windup`, so the
  twirl plays. Layers T1 / T4: charge 8 / 8, twirl 3 / 4, slam 12 / 17, ground
  4 / 10, impact 8 / 14.
- 3D shockwaves (all tiers) are MeshWave models, played by TechniqueVFX with
  or without the Game Module: a Model with `MeshWave = true` and a child
  `Mesh` part (Transparency 1 in the template), tweened at emit time relative
  to its parent part/attachment from `FromSize`/`FromOffset`/`FromTransparency`
  to `ToSize`/`ToOffset`/`ToTransparency` over `Duration` (`Style` easing,
  `Rotation` degrees, inherited `EmitDelay`; `Phase = "active"` lets `fit()`
  retime it). Names avoid Start/End so SimpleMeshVFX doesn't also play them.
  Palm Strike: `Ground/GroundWave` (torus to `def.radius`), per target
  `Impact/GroundShock` and `Body/ImpactRing` (II+ `ImpactSwirl`, III+
  ForceField `ImpactBubble`), and `Palm/AirRing` (1/1/2/3 flying forward).
- Add-ons used: Craters (`CraterVFX` attachments `RockRing`, `Kick`; enemies
  get the client-only `CraterIgnore` tag so rocks skip them), SimpleMeshVFX
  (`Shell`, `Dome` Start/End models), Splines (`Wisps`, emitted explicitly:
  emitting a part doesn't reach parts nested in it), ScreenEffects
  (`CameraShake`/`ImpactFrames` CSV attributes on attachments `Shake`,
  `Frames`, `Quake`). All need the Game Module with those add-ons installed in
  the place; without it (`TechniqueVFX.full` false) only the particles play and
  `CombatEffects.shake` stands in for the camera shake.

## Player crowd control

Bosses (and any enemy) can take a player's control for a moment, and every hit
that lands makes the player react. One server API, `src/server/PlayerStun.luau`;
the player is an R6 rig, so the reactions are procedural joint offsets drawn by
`src/client/CrowdControl.luau` on every client (observers see them too).

`PlayerStun.apply(player, kind, seconds?, source?)` returns `"applied"`,
`"immune"`, `"evaded"` or `"ignored"`. `source` is a Model the player stumbles
away from.

| Kind | Length (`Config.Combat.CC`) | Effect |
|---|---|---|
| `"flinch"` | 0.28 s | a hard recoil (torso snaps back ~24 deg, head whip, arms jolt) with a white pulse on the character and a camera shake for the local player. Never cancels or blocks an action; walking at 75%. Fired by `Combat.hurt` on every enemy hit that deals damage, so enemies don't call it; heavier hits upgrade it ([below](#enemy-hits-reaction-level-and-knockback)). |
| `"stagger"` | 0.75 s (0.4-1.0) | knocked off balance: cancels the current action, no attacking, dodging, casting, sprinting or jumping, walking at 20%, a short stumble away from `source`, camera shake. |
| `"stun"` | `seconds` (default 1.2, at most 3) | cancels the action; no actions, no movement, no steering. Pose: a snap back with the arms thrown out, then an upright drunken sway on a wide stance (one swing ~3 s; every other swing nearly falls and is caught with a sideways step, the arms lifting for balance; the heavy head and loose arms trail a beat behind), shaken off in the last 0.35 s. |

Protection, so a boss can't chain-lock a player:
- A dodge's i-frames (or a dash skill's) dodge a stagger or stun: `"evaded"`.
- After a stagger or stun ends, the player is immune to both for `IMMUNITY` (1 s).
  A stun may replace a stagger in progress; nothing replaces a stun.
- A stun landing within `DR_WINDOW` (6 s) of the end of the last one lasts
  `DR_FACTOR` (half) as long per link in the chain (1.2, 0.6, then 0.3 s, which is
  under `STUN_MIN` and ignored). A longer pause resets the chain.
- Flinches never start during a stagger or stun, or within `FLINCH_GAP` of the last.

Other API: `PlayerStun.isLocked(player)` (stagger or stun now), `kind(player)`,
`remaining(player)`, `clear(player)`. State replicates as Humanoid attributes:
`CCKind`, `CCStart`, `CCEnd` (server time), `CCMove` (walk speed share, applied by
both `Movement` writers), `CCLock`, `CCFrom` (source position). No remote.
Gating: server `Combat.action` refuses `begin` while locked and `PlayerStun`
cancels the running action (`onLock`); client `ActionState.crowdLocked()` blocks
`tryStart`, drops buffered inputs, sprint, approach and jumping.

Enemy attacks can carry `stun = { kind, radius, seconds? }` (Enemies.luau): at
the end of the windup every player inside that circle is hit with
### Enemy hits: reaction level and knockback

Every enemy hit that lands (`hurtPlayer`/`hurtPart` in EnemyService) picks one of
the three levels (`EnemyService.reaction`):
1. a stun or stagger the attack carries for its hits (`stun.onHit`, a barrage's
   `hitStun` on parts flagged `stun`), else
2. the attack's own `react` (`"flinch" | "stagger" | "stun"`, length
   `reactSeconds`), else
3. `"stagger"` for a heavy blow (`CC.HEAVY_KINDS`: slam, charge, leap) from a
   beast of weight `CC.STAGGER_WEIGHT` (2.5, the Stone Boar) or more, else
4. the flinch `Combat.hurt` already gave.

So wolves and serpents only flinch, the boar's charge staggers, boss slams,
charges and leaps stagger, the Thunder Ape's Body Slam staggers (`react`) and
Judgment and the Jiao's coil stun (`stun.onHit`). A slam's outer pound wave only
flinches. Protection (immunity, i-frames) applies as above.

The hit also knocks the player back, by the enemy (`EnemyService.knockback`):
the beast's `knock` studs, else `KNOCK_BASE + KNOCK_PER_WEIGHT * weight` (wolf ~2,
boar ~2.8, wolf king and fox 5, ape and jiao 6), times `KNOCK_BY_REACT` (1.5 for a
stagger or stun), capped at `KNOCK_MAX` (9). An attack's `knock` replaces it
(`0` = none: the Jiao's coil, so the ring keeps its trap). A snare's pull
replaces the shove. The server sends Effect `"knock"` (from, studs) to the hit
player only and `CrowdControl.knock` shoves their own root away from the beast
over `KNOCK_SECONDS` (0.22 s, easing off), taking over from the stagger's stumble
while it plays. Untested in play: the shove fights the Humanoid's ground
controller the same way the stumble does, so the real distance may come out
shorter than `studs`.

`PlayerStun.apply`, and the exact circle is telegraphed like a damaging attack.
The new Elder Wolf King opens every fresh engagement with a `roar` (`pack.howl`, a `howl` attack, 1.0 s windup, no damage) that staggers players within 18 studs for 0.8 s; the server holds the roar until the target is within 24 studs so it can catch them (a dodge or backing off avoids it). Its Pack Call (the two health-threshold calls) also has
`stun = { kind = "stun", radius = 20, seconds = 1.0 }`; it only exists behind
`Config.Wilds.NEW_WOLF_KING` (testbed). Dodge through the roar or stay out of the ring.

## Data flow
Client presses -> `ActionRules` decides if legal -> plays locally and sends
`Attack { begin }`; hit reports follow as `Attack { hit, targets }` -> server
replays the timeline, checks timing (`MAX_LAG`, `CLOCK_SLACK`) and the slackened
hitbox (a claimed target outside it now still counts if it was inside at the
swing's time, rewound at most `REWIND`: lag compensation, `EnemyHistory`), applies `damage * Combat.power(player)` (times `Weapons.multiplier` for M1)
and knockback, and acknowledges
via `Effect "action"`. Enemy attacks call `Combat.hurt`, which reports
`"perfect" | "dodged" | "hit"` and fires `Effect "hurt"`/`"perfect"`.

## Tuning knobs
- `Config.Combat`: `CLASSES` (each weapon class's chain with per-step `push`,
  hitbox and max targets; `FIST_STEPS` is the Fist chain), chain/reset timings, buffers, dodge
  (`DODGE_*`, `IFRAME_*`, `PERFECT_*`), hitbox and server slack, `REWIND` (swing
  lag compensation) and `ESCAPE_LEAD` (enemy strikes spare a player already
  moving out, see [enemies](enemies.md) "Server and client"), lock-on and
  auto ranges, `IN_COMBAT_SECONDS`.
- `Techniques.luau`: per-technique damage, cooldown, shape, cast timing,
  `weapon`, and for weapon skills `hits`, `castSpeed`, `lunge`/`lungeWindow`.
- `Config.Combat.LUNGE_SLACK`, `LUNGE_WALK_ALLOWANCE`: the server's lunge check.
  `VISUAL_TIERS` maps levels to the four visual tiers (I 1-3, II 4-6, III 7-9,
  IV 10), and so where the comprehension bottlenecks sit; `TechniqueVFX.STEP_COUNT` is the extra particle count per level inside a tier.
- `Knockback.luau`: `REALM_EXPONENT`, `MIN_DISTANCE`, `ARMOR_BREAK`, stun, base pushes.
- Per stage (`Pacing.luau`): player `power` and `health` (curve and Adjust).
- `Config.Combat.CC`: flinch, stagger and stun lengths, move shares, stumble push, immunity and diminishing returns.

## Known gaps
- Palm Strike plays Fists.4, whose `Hit Stop` marker is at 0.45 s, but
  `Config.Combat.FIST_STEPS[4].hitStop` is 0.50: the hitbox window (and the
  effect's active phase, which follows Config) runs ~0.05 s of source time past
  the animation's marker. Effects follow Config until the two are aligned.
- Enemy hits flinch players but don't knock them back. Flinch, stagger and stun
  are procedural R6 poses (untested in play, no authored clips) and there is no
  dazed-stars effect yet: the VFX library has a `star` but no template is built.
  The Elder Wolf King's `Roar` pose is still unplayed (its Pack Call keeps its own).
- Sword Qi Wave's blade stops visually at walls, but its damage box still
  reaches through them.
- Fire Seal's tick visuals are timed on the client from the cast, not from
  the server's damage ticks (which aren't sent), and the first one waits for
  the seal to land (~0.24 s after the first damage tick).
- An interrupted enemy windup's telegraph still plays out on clients.
- Great Sage Awakening's twirl (`TechniqueFX.GreatSageAwakening.windup`: the
  staff trails, ground seal and rising streaks) plays on the caster only
  (`CombatEffects.windup` hands off to a technique module's `windup`), and
  observers only get the cast at the first hit, so they never see the twirl,
  and neither do they see any weapon technique's `Charge`. The buff
  aura runs `def.seconds` from the cast on each client (it stops early only if
  the caster dies or leaves), not from a server buff start/end signal.
- `Dodge` and `Cast` remotes in `assets/Remotes.rbxmx` are unused.
