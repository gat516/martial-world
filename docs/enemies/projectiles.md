# Boss projectiles

Part of [enemies](../systems/enemies.md). Backend built; the Nine-Tailed Fox's foxfireVolley uses it.

User decision (2026-10-21): real projectiles are for **bosses only**. Regular
beasts (the Venom Serpent's spit) keep their ground circles, and player
techniques keep resolving at Hit with the flight drawn on top.

A projectile is a real object in flight: it hits whoever it reaches when it
reaches them, so a player beats it by sidestepping or dashing through it, and
walls or rising ground stop it. The hit goes through the boss's `hurtPlayer`,
so dodges, reactions and knockback apply
([combat](../systems/combat.md#enemy-hits-reaction-level-and-knockback)).

**Warning the player.** Melee reads at a glance from the red ground fill;
projectiles use the same language, then the shot itself takes over:
- Straight shot: in the windup, the red lane it will fly down
  (`Projectiles.warnLane`), filling until release. In flight, the shot is the
  warning: its effect must be bright and big, with a ground shadow under it so
  its distance reads, and a whoosh (vfx agent).
- Lob: its landing circle (`Projectiles.warnLanding`), sent for windup + flight
  so the fill completes at touchdown.
- Homing shot: no lane (it follows you); a red ring under the target player that
  follows them through the windup (`Projectiles.mark`).
- Not built: a screen-edge arrow for a shot aimed at you from off screen (UI).

**Backend** (`src/server/Projectiles.luau`, `src/shared/ProjectilePath.luau`,
`src/client/ProjectileView.luau`):
- `Projectiles.fire(spec)` -> id. Spec: `owner` (the boss model; never hit, the
  shot ends if it leaves), `cue` (what clients draw), `origin`, `velocity`,
  `radius`, `gravity` (0 straight), `homing = { player, turn }` (deg/s),
  `range`, `lifetime` (default 4 s), `pierce`, `terrain = false` to pass through
  the map, `ignore`, `onHit(player, position)` (return false: not a hit, fly
  on), `onEnd(position, reason)` (`hit`, `terrain`, `range`, `lifetime`,
  `owner`, `cancel`), `data` (passed to the drawer). `Projectiles.lobVelocity`
  aims a lob onto a point in a given flight time. Also `cancel(id)`,
  `cancelOwner(model)`, `position(id)`. At most 80 in flight.
- Each Heartbeat the server steps the path and spherecasts the step against the
  map (skipping characters, live enemies and zones), then checks every player
  once per shot: hit when the step's segment comes within radius + 1.5 of their
  root, both where the server sees them and where their movement carries them
  within half their ping (the same grace as ground areas, `ESCAPE_LEAD`). A
  player in dodge i-frames (`Combat.evading`) is passed through; `onHit` still
  runs so the perfect dodge is granted.
- Clients get Effect `"projectile"` (spawn info with server start time) and
  `"projectileEnd"` (id, position, reason); nothing replicates per frame.
  ProjectileView catches a late spawn up by server time, flies it on the same
  `ProjectilePath` rule, and calls the drawer registered for its cue
  (`ProjectileView.register(cue, { start, step, finish })`). A homing shot may
  drift slightly on clients by the target's replication lag. In the testbed an
  unregistered cue draws a red debug ball; in the main game it draws nothing.
- Untested in play. Converting a boss attack: in its resolve, warn in the
  windup, then `fire` with `onHit = ctx.hurtPlayer(enemy, attack, player)` and
  register its drawer in that boss's EnemyFX. The knockback still pushes away
  from the boss, not along the shot.
- Converted (testbed, untested): Thunder Ape `boulderHurl` and `thunderLance` (`Attack.projectile`).
  The lob warns its r10 landing circle for the whole 1.7 s windup (`warnLanding`, locked at windup start),
  fires `cue "boulder"` at 1.25 s from the root-relative offset (7, 14, -2) (right hand overhead), radius 5,
  gravity 160, aimed with `lobVelocity` to land on the circle 0.45 s later, `data = { size = 5 }`. A direct
  hit hurts; on `onEnd` anyone else in the r10 circle takes the impact, only if it landed inside the circle.
  The lance warns the 8 x 90 lane (`warnLane`, 1.4 s) and fires `cue "thunderLance"` at windup end from 16
  studs ahead of the root at 3.5 studs above the ground: speed 150, radius 2.5 (matches the lane's half width),
  range 74, `pierce`, `data = { length = 90, width = 8 }`. A stagger of the ape before the release cancels the
  boulder's fire. Other candidates: Jade Jiao
  `venomLance` and `venomSpray`; Nine-Tailed Fox `foxfireVolley`. Each goes to
  the testbed first.
