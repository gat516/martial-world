# Enemy effects: rules and checks

The user's decisions for beast and boss effects, from the bestiary and boss
passes (2026-10-22). Read it for any enemy effect. The cue wiring is in
[enemies](../systems/enemies.md), "Adding a beast's effects". The
enemy-designer's brief gives the beats and timings, and stands in for the plan.

## Look

- **Element palette.** Each beast's effects carry its affinity:
  - venom: jade-green
  - earth: jade over umber
  - shadow: ink and violet
  - fire: red and gold
  - ice: white-blue
  - blood: crimson

  Never put the Spirit Wolf's pale blue or the King's gold on another beast.
  The telegraph stays in the one danger colour.
- **Readable beats.**
  - `Tell` parts dim, then brighten across the windup (`TellBase` keeps the
    original colour).
  - Every bright layer sits on a dark or slate copy so it reads in daylight.
  - Every hit and landing gets dust, chips or a flash.
- **Small and clean for regular beasts** (ring 1-2 sizes). Never on any enemy:
  body copies or afterimages, always-on ground circles, flat discs for roars,
  crowns or halos.
- **Don't double up or redraw** (Elder Wolf King pass).
  - Don't layer the shared `Impact` stacks on top of a boss's own impacts: the
    generic rings doubled every hit.
  - Don't redraw the telegraph's danger area with ground markers or turning
    arrays. The telegraph owns where and when.
  - A beast's own qi (spirit flames, motes) shows where it really flares (aura,
    a call, death), not bolted onto every attack.

## Phones

Pack beasts keep emitter counts low. A swarm (the Blood Bat) uses 1-3 emitters a
beat and plays a shared beat (the shriek) on one beast only.

## Building

- **Build on the shared kit.**
  - `src/client/EnemyFX/BeastKit.luau`: lob, beam, anchor point, tell sweep,
    attachment lookup by class.
  - `Impact`: explode, ground, swipe, skid, shot, roar with a custom palette.
  - Gate each handler by the model's `Template`.
- **Reuse other enemies' templates** where they fit. Still write the intent, beat
  sheet and causes into the spec header.
- **Read the cue, don't assume.**
  - A barrage's circles are in `shape.parts`.
  - A lob launches at the release time the brief gives (the pose throws at the
    same moment).
  - Sizes come from the cue or the def, not constants, where they can.

## Checks

- **Fire every cue against the real bodies** with `tools/enemy_fx_smoke.luau`
  (errors, spawn counts, missing hooks) before committing.
  - Use `stateful = true` for bosses. Their handlers guard on the model's
    `Attack`/`AIState`/`StateAt`, and without it every cue returns early and
    still reads "ok".
- **Preview the real cue path** with `tools/enemy_fx_shot.luau`, one call per
  review moment.
- The user reviews the look.
