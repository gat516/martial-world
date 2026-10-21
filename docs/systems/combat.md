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
vfxia Asset Library):
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
- An interrupted enemy windup's telegraph still plays out on clients.
- `Dodge` and `Cast` remotes in `assets/Remotes.rbxmx` are unused.
