# Briefs for visual agents

What the main session (or the enemy-designer) must put in a brief before
spawning a visual agent. Most of the worst results so far were the brief's fault:
a boss body "reworked" because the brief said so, bodies at the wrong scale, art
generated without a reference, a screen built with no exemplar to match. An agent
that gets a brief missing a **required** field stops and asks for it once, then
ends its turn (it doesn't invent the missing piece).

Every brief, every discipline:

| Field | Required | What it is |
|---|---|---|
| Goal | yes | one or two sentences: what it is, what the player should feel, its gameplay job |
| Sandbox | yes | `studio_id` of the sandbox opened for it (orchestration.md), or "no Studio needed" |
| Worktree and branch | yes | the checkout to work in |
| References | yes for anything new or reworked | image paths (`docs/reference/...`), the testbed row, a video grid; the agent builds *to* these |
| Exemplar to match | yes | an entry in `docs/reference/approved/README.md` this should sit beside, and any entry in its rejected list it must not resemble |
| Do not change | yes for reworks and fixes | what stays exactly as is (the reference body's silhouette and colours; the HUD footprint; a sound already wired) |
| Contracts | when others depend on it | attack and cue names, attachment and tell-part names, module APIs, asset ids |
| Scale and size | yes for bodies, props, UI | the testbed row scale (fox 2.13x, ape 3.71x, python 3.17x...), weapon length against the R6 rig, UI baseline sizes |
| User's words | when there are any | quotes from the conversation about this item, verbatim |
| Done means | yes | the lint is clean, the critic says SHIP, exported to `assets/...`, docs updated, `Test build:` line |
| Variants | default yes | "send 2-3 directions first" unless the brief names an exact match |

Per discipline, on top of the above:

- **animator**: the attack table (windup, active, recover, cooldown in ms), the
  windup pose wanted, which joints are free (EnemyAnimator owns head, tail, legs),
  the rig's `RIGS.md` section, loops needed (idle, walk, run), the stiffness
  checklist (anticipation, chain lag, overshoot and settle, landing compress).
- **vfx / world-fx**: the beat and cue names with their ms from the animation's
  markers, the element palette, the attachments the body exposes, what the
  telegraph already shows (so the effect doesn't redraw it), what to reuse from
  other effects, phone budget, sound yes/no.
- **enemy-modeler**: the designer's segment list and joint pivots, part budget,
  palette, tell parts, attachments, the reference row entry and its scale, and
  "no added armour or detail unless listed".
- **modeler**: the pipeline target (prop, held weapon, terrain piece), size
  against `art/rig/r6_rigged.fbx`, grip anchors, triangle budget, where it's
  placed, hand-pass flags expected.
- **ui-designer**: the reference image, the kit file URL, the screens and states
  (rest, hover, phone), the four lint sizes, the footprint ceiling on phone, the
  house pieces to reuse, the Codex sheet if new art is needed.
- **map-builder**: the area's doc, the composition reference, what's locked
  (terrain owner, layout files), the POI list, lighting time of day.

Shared with every agent: "post a `## Status:` line at each phase", "capture only
for the sheet", "don't edit `.claude/`", "commit on your branch, don't merge or
push", and the `Test build:` line if combat, enemies or animations changed.
