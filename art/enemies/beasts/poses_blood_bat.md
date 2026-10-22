# Iron-Winged Blood Bat poses (`src/client/EnemyPoses/BloodBat.luau`, shared stroke in `Flap.luau`)

Header of the module has the move list and the FAMILIES line. Numbers only, no visual review yet.

## Wing stroke
- Same Flap cycle as the raven at ~7 Hz (idle 46 rad/s, walk 46+0.6v, run 52+0.3v), sweep amplitudes 0.35/0.25/0.15, stroke 0.3-1.05 rad.
- **Membrane V**: the three skins rest at signed elevations +0.45, +0.25 and -0.61 (the finger skin slopes down). Flap style floor {0.34, 0.54, 0.2} and ceil {9, 9, 0.74} keep every skin at or above ~0.3 rad from flat, measured in the body frame. QA: idle/walk/run/circle 0.32-0.33, all live moves >= 0.30 (the dead pose is allowed to go flat).
- Twitchy: head, ears, body and jaw jump to new angles 3-11 times a second (`Flap.twitch`), a 60-100 rad/s shake on tell flares and the shriek.

## Moves
| Move | windup | active | recover | Notes |
|---|---|---|---|---|
| BloodDive | 0.6 | 0.47 | 0.8 | 0.09 s dip, climb 1.3 on hard strokes, wings snap back at the top, nose over, beak bared, shiver builds; stoop with wings folded back (yaw 0.8), last 0.12 s flares for the bite; recover = leech (0.5 s head shake, chewing, chest pulse) then a push off, nose up |
| BloodDiveSkid | - | - | 0.8 | LEAD: brake flare, head whips to live targetYaw, banks round |
| SonicShriek | 1.0 | 0.1 | 0.7 | breath in (wings drawn in), rear: head back, beak wide, ears flared, wings spread, body vibrating harder to 1.0; active = snap + violent shake; dizzy wobble |
| Hop | - | 0.25 | - | flap-away, two strokes, nose up |
| Stagger | - | 0.25 | - | |
| Death | - | 1.2 | - | tumble, belly-down (JointRoot Y -3.55, feet on Y 0), wings flat |

## Known touches
Folded/flared wing bones brush the ear wedges for one sample in the dive moves and the shriek recover (ears are tucked straight to keep it to that). Not fixed; check by eye.
