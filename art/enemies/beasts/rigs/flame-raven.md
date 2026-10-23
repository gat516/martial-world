# Flame Raven (16 joints)

Part of [beasts/RIGS.md](../RIGS.md): read that file's shared rules first.


A low hoverer. The body sits at about player-head height (Y 5.6) and the talons hang to
Y 3.3. **HRP**: 2.4 x 3 x 3 centred at Y 5, so HipHeight is 3.5. The Humanoid holds it
up, and the root sits where a grounded player's melee box reaches. The wings are spread in
a shallow V at rest, which is the top of a flap.

| Joint | Moves (Part1) | Parent | Notes |
|---|---|---|---|
| JointRoot | Body | HumanoidRootPart | pivots at the body centre: hover bob, dive tilt (-X noses down) |
| JointNeck | Neck | Body | |
| JointHead | Skull | Neck | legacy |
| JointJaw | Jaw | Skull | the lower beak; -X opens |
| JointCrest | Crest | Skull | the ember crest; -X stands it upright (flare) |
| JointShoulderL / R | UpperWingL / R | Body | flap: **L up = -Z, R up = +Z**; sweep back = +Y on L, -Y on R (measured; first notes had it reversed) |
| JointElbowL / R | ForeWingL / R | UpperWing | same signs as the shoulder |
| JointWristL / R | WingTipL / R | ForeWing | the primaries; same signs |
| JointTail | Tail | Body | the fan; +X lifts it |
| JointLegBL / BR | LegL / R | Body | legacy back-leg names: EnemyAnimator swings them (talons forward in its dash pose) |
| JointAnkleL / R | TalonL / R | Leg | +X curls the toes forward |

The wings have no legacy name. A pitch swing would row them, so they hold their spread
until EnemyAnimator learns a flap (roll at the shoulders).
Tells: the EyeL/R, the Crest, and the 8 primary tips (WingTip*Primary*Tip).

### FlameRavenB (the user's reference body, 1.0x, brought in 2026-10-22)

`assets/Enemies.rbxm` template `FlameRavenB`: the user's `FlameRaven` kept as it looks, 15.0 x 5.5 x 7.1 studs, 87 parts, the 16 joints above. Built by `bring_in_flame_raven.luau`. No Tell parts were added (the source's: `EyeL/R`, `Crest`, `WingTip{L,R}Primary1..4Tip`, all with `TellBase`).

- **Hover convention** (same as the Blood Bat): the pivot is the `HumanoidRootPart` centre at **Y 5.0**, identity rotation, and the Humanoid holds it up with `HipHeight 3.5` (= the root's bottom). The talons hang to Y 3.25. Not a ground pivot.
- **Root** is sized to the body, not the wingspan: 4.4 x 3.0 x 7.12 (head to tail fan), centred on the body in Z, so its centre is 0.47 behind the old pivot; `JointRoot` is at root-relative (0, 0.60, -0.37). Root centre to the beak (`Mouth`): 3.46 studs forward (Z -3.46, ground Y 6.80).
- **Wings** (roll about Z lifts, the Blood Bat's convention):

| Raven joint | Bat joint | Moves | Rest pivot (root-relative) | Axes |
|---|---|---|---|---|
| JointShoulderL / R | JointWingL / R | UpperWingL / R | (+-0.75, 1.15, -0.10) | flap roll Z: L up = -Z, R up = +Z; sweep back = +Y on L, -Y on R (measured; first notes had it reversed) |
| JointElbowL / R | JointWingL2 / R2 | ForeWingL / R | (+-2.55, 1.75, 0.10) | same signs |
| JointWristL / R | JointWingL3 / R3 | WingTipL / R (the primaries) | (+-4.05, 2.40, 0.35) | same signs |

  A shared flap cycle keyed on shoulder/elbow/wrist maps one to one onto the bat's WingX / WingX2 / WingX3 (same signs, same lag order), scaled by the span (raven pivots are about 2x the bat's). The raven rests spread in a shallow V (about the top of a flap); the bat at about 25 degrees up. Other joints: JointNeck (0, 1.05, -0.75), JointHead (0, 1.85, -1.20), JointJaw (0, 1.80, -2.10), JointCrest (0, 2.50, -1.65), JointTail (0, 0.30, +1.30), JointLegBL/BR (+-0.45, -0.25, +0.40), JointAnkleL/R (+-0.45, -1.15, +0.20).
- **Attachments**: `Mouth` (Skull, beak tip), `Core` (Body, chest, 5.68 up), `WingTipL_FX` / `WingTipR_FX` (on WingTipL/R, outer tip, X +-7.49 from the root, Y 7.97), `Talons_FX` (Body, between the talons at their lowest point, Y 3.25), `Crest_FX` (Crest, the top, Y 8.28).
- `HealthBar` 1 stud over the top. check_rig clean, keyframe_test keyable (16 joints).
