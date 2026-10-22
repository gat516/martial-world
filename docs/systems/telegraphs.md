# Telegraphs and attack feel

How enemy attacks warn the player and how they land. Every enemy and boss follows
this; the enemy-designer, vfx and animator agents build against it. Decided with
the user on 2026-10-22, after the FFXIV-style references and a write-up on visual
clarity against visual appeal.

## The problem
An attack used to be drawn twice: a bright red ground shape (the telegraph) and the
attack's own effect (fire, lightning, a slash). Both shouted, so they clashed. The
shape made good effects look cheap, and the effects made the shape harder to read.
The shapes are still the clearest way to say where a blow lands, so they stay.
What changes is how they look and how they behave over the attack's life.

## One danger language (`src/client/Telegraphs.luau`)
- **One colour for every enemy:** a warm danger orange (`DANGER` in Telegraphs),
  never the attack's element. The effect carries the element: fire, venom, thunder.
  The telegraph only says danger, where, which way and when.
- **The edge does the work.** A bright, thin, glowing outline, plus a very faint
  fill (most of the ground still shows through). The edge must stay readable on a
  phone screen at 40 studs, so it's never thinner than about 0.5 studs and is
  scaled up for big areas.
- **A timing fill.** Inside the outline, a brighter band grows to the edge
  (circles grow out from the centre, boxes from the attacker, cones sweep out from
  the apex), arriving exactly when the blow lands. This is the "when" for players
  on any device.
- **Over the attack's life:**

  | Phase | The telegraph |
  |---|---|
  | Windup | The outline appears and the faint fill sets the area |
  | Last ~0.25 s | The edge brightens and pulses once: dodge now |
  | Release | It fades out in ~0.15 s while the effect takes over |
  | Lingering hazard (pools, fields) | A dim, slowly breathing edge stays for as long as it hurts |

- **Two tiers.** Most attacks get the standard telegraph. Big blows (a boss's
  ultimates, anything over ~25% of the player's health, attacks that stun) set
  `telegraph = "heavy"` on the attack def: a stronger fill, a double edge and an
  earlier pulse. Keep heavy rare, or nothing stands out.
- **Overlaps:** a set of sub-areas (a barrage) draws each part's edge but shares
  one faint fill, so overlapping shapes don't stack into an opaque blob.
- **Summons and howls draw nothing.** A roar or howl that does no damage gets an
  effect from `EnemyFX`, never a ground ring.

## Projectiles are not area attacks
Ground lanes for projectiles read like area attacks, and they clash with the bolt
itself. Each projectile type gets its own treatment:
- **Travelling shots** (bolts, lances, boulders thrown flat): no ground lane. During
  the windup, two thin rails (or one thin aim line) from the mouth or hand show
  the direction. They brighten just before release and vanish when the shot
  leaves. The projectile in flight is the warning: a bright core, a readable
  silhouette, a contrasting trail and a shadow on the ground.
- **Lobbed shots** (boulders, venom globs landing on a spot): a ground reticle at
  the landing point. A ring closes on its centre and arrives as the shot lands,
  and the impact plays an explosion.
- **Beams:** two rails along the path, which brighten and are replaced by the
  beam.
- **Homing shots:** the ring under the target that follows them (`projectileMark`).

## Attacks that make sense (motion and chaining)
- **Every movement ends in a blow.** A charge isn't just a run: it ends in a swipe,
  a gore or a shoulder hit. A leap lands in its slam area, and if the target is
  still in reach the beast follows up with a swipe. The follow-up plays only when
  the target is in reach on arrival. Otherwise the beast skids, turns to find the
  target and recovers. Show the follow-up's area as a second, later telegraph, so
  it isn't a surprise.
- **Turn into the move, never after it.** A body turns during the anticipation or
  in the air, never on landing. A leap that lands and only then rotates looks
  weightless (the Thunder Ape did this). An overshoot ends in a skid-and-turn with
  weight: the feet plant, the body swings round and the head leads.
- **Weight.** Anticipation scales with size. Big bodies crouch before a jump, hang
  at the apex, land with compression (knees and spine), and the camera-facing
  impact gets a shockwave and dust. Recovers step; they never slide.
- **Vary the movement.** Jumps and dashes pick from different landing spots and
  arcs: over the player, to their flank, back out of reach, or a short hop.
  A boss shouldn't land the same way twice in a row.
- **Ranged bosses make their own range.** Players are almost always close, so a
  ranged attack whose `minRange` is rarely met never fires, or worse, fires point
  blank. A beast with ranged attacks needs a move that makes distance (a shove
  that knocks the player back, a retreating leap, a burrow away) and then uses the
  ranged attack from there.

## Impact (effects)
Ground effects don't stop at their element. Every impact layers, from the vfx
library: a ground shockwave ring, debris or dust kicked out, a flash at contact,
and, for explosions and landings, a short burst plus a lingering scorch or crack
that fades. Projectiles get a real in-flight effect and a real explosion where
they land. Big hits add a camera shake in `EnemyFX` scaled by distance. The
element colours the layers; the shockwave gives the oomph.

## Mobile
The game is open to phone players: small screens, a thumb on the stick, a lower
camera. So the edges and timing fill are thick and high-contrast, never colour
alone (the pulse and fill carry the timing too). Windups follow the
enemy-designer's minimums, and sustained effects stay within the phone
particle budgets in `docs/vfx/style.md`.

## Implementation (`Config.NEW_TELEGRAPHS`)
The new look is on in the testbed only (`NEW_TELEGRAPHS = TESTBED` in `Config.luau`);
the main game still draws the old red shapes until the user approves. Setting it to
`true` ships it. Both looks live in `src/client/Telegraphs.luau` (`legacyShow` is
the old one).

- **Building blocks.** Circles and boxes are one flat part each with a SurfaceGui
  on top: rounded or square Frames whose `UIStroke` is the edge, a wider faint
  stroke for the glow, a Frame for the faint fill and one for the timing fill. Cones
  are one anchor part with Beams lying flat: Bezier arcs (90 degrees at most each)
  and two sides for the edge and glow, triangle slices (20 degrees at most) for the
  fills. A cone of 359 degrees or more draws as a circle. No neon wedges.
- **Over time.** One RenderStepped loop (connected only while something shows)
  drives every telegraph from its start: timing fill `k` = elapsed / seconds, the
  pulse (edge to full opacity, width swells by `PULSE_WIDEN` and back) in the last
  `PULSE` s (`HEAVY_PULSE` for heavy), then a `FADE` s fade.
- **Tier.** Read from the attack def by the telegraph's attack name and the model's
  `EnemyType` (searched through `attacks`, `rotate`, phases and `arrive`
  follow-ups, cached). `telegraph = "heavy"` today: Thunder Ape `bodySlam`,
  `skyfallSlam`, `judgment`; fox `nineTailFall`; Jiao `erupt`, `jiaoCoil`. A new
  heavy attack only needs the field (the Wolf King's `kingLeap` once it lands).
  Telegraphs sent without a model (`EnemyService.strike`) are standard.
- **Barrages** (`shape.parts`): each part draws its edge and a light timing fill
  (`BARRAGE_TIMING`) but no faint fill of its own, so overlaps stay clear. Barrage
  `bolt` lanes (the fox's volley) draw as rails.
- **Projectiles.** `Projectiles.warnLane` sends a box with `aim = "rails"`, and a
  `bolt` attack's own lanes (the Jiao) are recognised by the def's kind: both
  draw two `RAIL_WIDTH` rails along the lane's sides that run out from the mouth
  in `RAIL_DRAW` s, fade toward the far end, pulse before release and vanish in
  `RAIL_FADE` s. `Projectiles.warnLanding` sends a circle with `lob = true`: a
  reticle (edge, four ticks, centre dot) with a ring that closes from
  `RETICLE_START` radii onto the edge, arriving at touchdown. The homing mark
  (`projectileMark`) is a standard circle of `MARK_RADIUS` that follows the target
  (`Telegraphs.follow`). The shapes stay `box`/`circle`, so EnemyFX windup cues
  read them unchanged.
- **Pools.** An attack with `poolSeconds` (Jiao `venomPools`) keeps each circle's
  edge at `LINGER_OPACITY`, breathing every `LINGER_BREATH` s, for the pool's life.
- **Howls** (`kind = "howl"`, summons, roars, the fox's retreat marker) draw nothing
  for any enemy; their `parts` (the retreat's fire trail) still draw.
- **Mobile.** Edge width is `EDGE_SHARE` of the radius or half-width, clamped to
  `EDGE_MIN` 0.5 .. `EDGE_MAX` 1.3 studs; timing is carried by the fill growing and
  the pulse, not by colour.
- **Previews.** `Telegraphs.still(shape, seconds, t, parent, model?, attack?)` draws
  one frozen moment into a folder in Edit mode (SurfaceGuis can take a frame or two
  to appear in a capture).

Knobs (top of `Telegraphs.luau`): `DANGER`, `EDGE_*`, `GLOW_*`, `FILL_OPACITY`,
`TIMING_OPACITY`, `HEAVY_*`, `PULSE`, `PULSE_WIDEN`, `FADE`, `BARRAGE_TIMING`,
`LINGER_*`, `RAIL_*`, `RETICLE_START`, `MARK_RADIUS`.

Known gaps: the shapes lie flat at the centre's height, so they float or sink on
slopes as the old ones did; a projectile's ground shadow in flight belongs to its
drawer (ProjectileView, vfx) and isn't drawn yet for every cue; untested on a phone.
