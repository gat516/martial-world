# Enemy effects (EnemyFX) and boss impacts

Part of [enemies](../systems/enemies.md). How a beast's client effects are wired to
server cues, and the shared boss impact layers.

## Adding a beast's effects
Put `src/client/EnemyFX/<EnemyType>.luau` returning any of `windup`, `strike`,
`dash`, `stagger`, `death`, `land`, `hit`, each `(cue) -> ()`; a cue is `{ model,
root, kind, attack, shape, seconds, target, at }` (shape and seconds left only on
windup, target only on hit). Branch on `cue.attack` (the model's `Attack`
attribute when the cue fires). Skipped past 220 studs from the camera. Server
code never plays effects; if a cue is missing, add an attribute, a field on the
telegraph, or an `enemyCue` (below), not a server-side effect.

A barrage's windup (the Fox's, the Raven's embers) is ONE `windup` cue whose
`shape` is `{ kind = "multi", parts, center }`: the real circles, lanes and cones are in
`shape.parts` (each with its own centre or box, `radius` and `delay`), and `shape.center` is
the beast's own ground position, not the target. Read `shape.parts`, never `shape.center`, for
where a barrage lands.

Where each cue comes from (`EnemyFX/init.luau`):
| Cue | Source |
|---|---|
| `windup` | the `Telegraph` remote (needs the enemy model in it); `seconds` = time left |
| `strike` | `AIState` goes windup -> dash or recover (fires for every attack, telegraphed or not) |
| `dash` | `AIState` becomes dash (same tick as strike for lunges) |
| `stagger` | `AIState` becomes stagger |
| `land` | `AIState` leaves dash (to recover, stagger, anything), or the server's `enemyCue` |
| `hit` | only the server: `Effect:FireAllClients("enemyCue", model, "hit", character)` once per player caught |
| `death` | `Health` reaches 0 |

`enemyCue` is generic: `Effect:FireAllClients("enemyCue", model, name, target?)`
calls handler `name` with `cue.target = target` (a Character or nil). Use it for
moments with no state change, such as a leap's touchdown when the leap isn't
modelled as a dash. Handlers dedupe what can arrive twice (the Spirit Wolf
ignores a second `land` within 0.3 s).

Bosses get no stock howl ring: `Telegraphs` skips the pale swelling disc for any `howl` shape from a boss def (roars, intros, phase calls, the fox's leap marker, the Jiao's emerge), since each boss's EnemyFX plays its own effect there. Under `Config.NEW_TELEGRAPHS` (testbed only for now) no enemy gets one: a `howl` shape draws nothing, and the wolf's `howl` windup cue carries its roar effect. Damaging and crowd-control areas still draw (in the new look: [telegraphs.md](../systems/telegraphs.md)).

## Boss impacts (2026-10-22)
`src/client/EnemyFX/Impact.luau` plays
`Effects.EnemyImpact` (builder `tools/vfx_specs/EnemyImpact.luau`), layered
on every boss's ground blows, landings, skids and projectile ends (and the
normal wolf's roar). Templates are authored at radius 10 in neutral colours;
each layer's `Role` attribute is painted from the element palette (thunder,
venom, fox, moon, earth), and the shake falls off with distance. Layers:
`Shock` (Neon torus wave and echo, bright front, rough ring, rays, dark
crater; 6), `Dust` (skirt, smoke ring, flipbook plume, rock chips; 4),
`Contact` (flash, flipbook star, glint, sparks, ink; 5), `Burst` (splat
flipbook, flame tongues, embers, dark smoke; 4), `Scar` (scorch, crack web,
burning crack cooling to dark, smoulder; 4, fades over 3.5 s), `Rocks`
(Craters ring, Game Module only), `Roar`/`RoarDust` (sound rings, breath,
motes; forward dust, grit, ring), `Skid` (spray, chips, scuff, puff), `Shot`
(core over a dark disc, halo, glint, shed sparks, dark and bright trails).
A heavy landing is about 100 particles one-shot. Untested: everything at play
speed and in a real fight (only Edit-mode stills of a landing, the roar and a
bolt were checked), the arrival follow-ups and skids against the combat
agent's live cues (the skid is detected from `Attack` or `AttackName` ending
in `Skid`), Craters rocks and Game Module playback, phone cost with several
impacts at once, and whether the extra shakes double up with the templates'
ScreenEffects shakes when the Game Module is present.
