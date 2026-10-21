# Combat and action states

## Purpose
Action combat against beasts: a five-hit fist chain, a flying-sword dash with
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
- `src/shared/Hitbox.luau`: the shared fist hitbox.
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
hitbox, applies `damage * Combat.power(player)` and knockback, and acknowledges
via `Effect "action"`. Enemy attacks call `Combat.hurt`, which reports
`"perfect" | "dodged" | "hit"` and fires `Effect "hurt"`/`"perfect"`.

## Tuning knobs
- `Config.Combat`: `FIST_STEPS`, chain/reset timings, buffers, dodge
  (`DODGE_*`, `IFRAME_*`, `PERFECT_*`), hitbox and server slack, lock-on and
  auto ranges, `IN_COMBAT_SECONDS`.
- `Techniques.luau`: per-technique damage, cooldown, shape, cast timing.
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
