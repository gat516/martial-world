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
  levels (`MAX_LEVEL` 10, +8% damage a level, XP per cast).
- `src/shared/Knockback.luau`: how far player hits push beasts (by realm power
  ratio and beast weight) and the stagger they cause.
- `src/server/Combat.luau`: `action` (Attack remote: begin/hit/cancel/sync),
  damage validation, `damageEnemy`, `hurt` (i-frames, perfect dodge, Iron Skin,
  non-lethal), `power` (the stage's `power`), `inCombat`, technique XP.
- `src/server/Movement.luau`, `src/client/Movement.luau`: the only writers of walk
  speed, jump and facing (actions, running, herb buffs, meditation all feed it).
- `src/client/CombatController.luau`: input, prediction, buffering, animations.
- `src/client/ActionState.luau`: local predicted action state.
- `src/client/LockOn.luau`, `Sprint.luau`, `ShiftLock.luau` (Alt), `HeadLook.luau`.
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
  sparks on the player (`Perfect.Player`) with a gold Highlight rim (0.35 s);
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
  Explosion shake on the first impact.
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
  whole line at Hit; visual impacts follow the blade, up to ~0.36 s later.
- **Lightning Talisman** (`LightningTalisman_T1..T4`;
  `TechniqueFX.LightningTalisman`). At Hit a paper talisman card leaves the
  left hand (Fists.2) and tumbles to a point above the first target in
  `chain`, where it flares and burns while a jagged bolt strikes down. Bolts
  then hop along `chain` every `HopDelay` (0.12 to 0.09 s by tier), bowing over
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
  module predicts it with Combat.chainTargets' rule.
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
  Explosion shake.
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
  and an Explosion quake.
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
  the one PointLight, impact frames and a quake.
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

## Data flow
Client presses -> `ActionRules` decides if legal -> plays locally and sends
`Attack { begin }`; hit reports follow as `Attack { hit, targets }` -> server
replays the timeline, checks timing (`MAX_LAG`, `CLOCK_SLACK`) and the slackened
hitbox, applies `damage * Combat.power(player)` (times `Weapons.multiplier` for M1)
and knockback, and acknowledges
via `Effect "action"`. Enemy attacks call `Combat.hurt`, which reports
`"perfect" | "dodged" | "hit"` and fires `Effect "hurt"`/`"perfect"`.

## Tuning knobs
- `Config.Combat`: `CLASSES` (each weapon class's chain with per-step `push`,
  hitbox and max targets; `FIST_STEPS` is the Fist chain), chain/reset timings, buffers, dodge
  (`DODGE_*`, `IFRAME_*`, `PERFECT_*`), hitbox and server slack, lock-on and
  auto ranges, `IN_COMBAT_SECONDS`.
- `Techniques.luau`: per-technique damage, cooldown, shape, cast timing,
  `weapon`, and for weapon skills `hits`, `castSpeed`, `lunge`/`lungeWindow`.
- `Config.Combat.LUNGE_SLACK`, `LUNGE_WALK_ALLOWANCE`: the server's lunge check.
  `VISUAL_TIERS` maps levels to the four visual tiers (I 1-3, II 4-6, III 7-9,
  IV 10); `TechniqueVFX.STEP_COUNT` is the extra particle count per level inside a tier.
- `Knockback.luau`: `REALM_EXPONENT`, `MIN_DISTANCE`, `ARMOR_BREAK`, stun, base pushes.
- Per stage (`Pacing.luau`): player `power` and `health` (curve and Adjust).

## Known gaps
- Palm Strike plays Fists.4, whose `Hit Stop` marker is at 0.45 s, but
  `Config.Combat.FIST_STEPS[4].hitStop` is 0.50: the hitbox window (and the
  effect's active phase, which follows Config) runs ~0.05 s of source time past
  the animation's marker. Effects follow Config until the two are aligned.
- Enemy hits don't knock players back or stagger them yet.
- Sword Qi Wave's blade stops visually at walls, but its damage box still
  reaches through them.
- Fire Seal's tick visuals are timed on the client from the cast, not from
  the server's damage ticks (which aren't sent), and the first one waits for
  the seal to land (~0.24 s after the first damage tick).
- An interrupted enemy windup's telegraph still plays out on clients.
- `Dodge` and `Cast` remotes in `assets/Remotes.rbxmx` are unused.
