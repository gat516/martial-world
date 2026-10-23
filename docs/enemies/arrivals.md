# Arrivals, skids and turning into moves

Part of [enemies](../systems/enemies.md). Testbed only, behind `Config.Wilds.WEIGHTED_MOVES`.

The server side of [telegraphs.md](../systems/telegraphs.md) "Attacks that make sense" (2026-10-22 boss feel pass).
`WEIGHTED_MOVES = TESTBED`: the main game keeps the old snap-and-slide until the user
approves it.
- **Turning into the move.** A leap, bound, charge or lunge no longer snaps to face the
  target at windup start: the root turns toward where it goes over the first 60% of
  the windup (`EnemyMover.turnTo`, an eased timed yaw that wins over walking turns and
  works standing still). A leap or bound then finishes its yaw in the air, over 80% of
  the flight, to touch down facing the target (or along the flight when the target is
  still on the landing spot). Nothing turns after landing except an `arrive` follow-up
  turning into its own blow.
- **`arrive`** (attack field, an ordinary attack): started the moment the parent's dash,
  leap or bound arrives, with no recover between, if the target is within the
  follow-up's `range` and at most 100 degrees off the nose (its windup turns into it,
  over 70% of the windup). It keeps the attack slot, sends its own telegraph, windup
  and strike cues under its own name (AIState goes dash -> windup, so the parent's
  `land` cue still carries the parent's name), and a pattern boss resumes the attack
  it cut in front of. List it in the pattern or pool with `chainOnly` so clients find
  its timing.
- **`skid`** (attack field): no follow-up to start (the arrive missed, or there is none
  and the target is more than 60 degrees off the nose): AIState `recover` for the
  parent's recover, model attribute `AttackName = "<name>Skid"` (`Attack` stays the
  parent's; `AttackName` equals `Attack` everywhere else), a 1-5 stud slide on along a
  charge or lunge (0.06 s of its dash speed, over 0.3 s), and a turn to the target over
  75% of the recover (at most 0.9 s).
- **`DashSeconds`** is now also set for leaps and bounds (their real flight);
  `EnemyAnimator` times leap and bound poses by it.
- **Client** (`EnemyAnimator`, `EnemyMotion`): a recover whose `AttackName` names another
  move than `Attack` plays that move (the skids), timed by the parent's recover; an
  arrival's dash -> windup holds the landing pose until `Attack` names the follow-up;
  `motion` families (the ape) get `BoundMode`, `BoundSide`, the drawn velocity and the
  turn rate as pose input. With the flag on, leaps and bounds fly a flatter-topped arc
  (`EnemyMotion` `HANG`): same apex, flight time and landing, a quicker rise and drop
  and a short hang at the top.
- Users: Thunder Ape `thunderRush` -> `rushSwipe` / `thunderRushSkid`, `skyfallSlam` ->
  `skyfallSweep` / `skyfallSlamSkid`, its bound modes; Elder Wolf King `kingLeap` ->
  `kingRake` / `kingLeapSkid`; Spirit Wolf `pounceSkid`, `leapSkid` (skid only, when it
  overshoots). The Jade Jiao's `tailShove` uses `rangedNext` ([jade-jiao.md](jade-jiao.md)).

## Known gaps
- Arrivals, skids and turning into moves (`WEIGHTED_MOVES`) are untested in play:
  whether the eased windup turn reads, the ape's `over` bound (a 180-degree air turn
  over 0.64 s), skid slides against walls, the follow-ups' short windups (rushSwipe
  0.4 s right after a dodge of the rush), the Jiao holding still for its shot, and the
  36-stud tail shove, which the client plays over the stock `KNOCK_SECONDS` 0.22 s
  (a near-teleport; CrowdControl should stretch long knocks). The pose modules time a
  bound's flight from `active`, not the per-mode `DashSeconds`, until the animators
  read it.
