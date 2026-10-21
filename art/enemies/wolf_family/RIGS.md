# Wolf family rigs: animator notes

Spirit Wolf B (`ServerStorage._StagingEnemies.SpiritWolf_B`), Elder Wolf King and
Shadow-Mane Wolf (`ServerStorage._RosterWolves`). All three share one skeleton: the same
joint names, hierarchy and pivots, the King at 2.4x and the Shadow-Mane at 1.15x the
Spirit Wolf. A clip made on one plays on the others as long as it only keys the shared
joints, and the extras are named so they don't clash.

Built by `spirit_wolf_b/build_spirit_wolf_b.luau` + `spirit_wolf/rig_wolf.luau` and
`wolf_family/run_all.luau` (build + `rig_wolf_family.luau`). Re-running them rebuilds the
template, so make animations in a copy, never by hand edits on the template.

## Opening the rig

- Humanoid (RigType R15, a custom rig) with an Animator. HumanoidRootPart is the root
  and the PrimaryPart, unanchored in the template. Anchor the HRP of your working copy
  in Moon Animator 2 or the Animation Editor.
- Exactly one Motor6D leaves the HRP: `JointRoot` to `Hips`. Everything else hangs from it.
- Clips key poses by **part name** (Part1), not by motor name. Every Part1 is unique.
- Every part except the segments is a welded detail (WeldConstraint to its segment). You
  can't key a detail; it rides its segment.

## Axes and signs (the same on every joint)

Every joint frame has identity rotation in model space at rest. The wolf faces -Z; its
left is -X. So, for a rotation `CFrame.Angles(x, y, z)` on any joint:

- **+X (pitch)**: the front of the part tips up. Head and neck: nose up. Legs: the foot
  swings forward. Tail: the tail tip drops. Ears: tips pinned back. Jaw: **negative X
  opens the mouth.** Crest/Mane (dorsal): +X lays it flat, -X bristles it up.
- **+Y (yaw)**: turns to the wolf's left. Tail: the tip swings to the wolf's right.
- **+Z (roll)**: tops lean to the wolf's left. Left-side flaps (EarL, ManeL): -Z flares
  them up and out, +Z droops them. Right side (EarR, ManeR): +Z flares, -Z droops.

## Shared joints (all three)

| Motor6D | Moves (Part1) | Parent (Part0) | Hinge | Notes |
|---|---|---|---|---|
| JointRoot | Hips | HumanoidRootPart | over the hips | whole-body bob, crouch (translate Y), lunge pitch |
| JointSpine | Chest | Hips | waist | arch or hunch, ~±0.2 rad |
| JointNeck | Neck | Chest | base of the neck | |
| JointHead | Skull | Neck | back of the skull | EnemyAnimator drives this one |
| JointJaw | Jaw | Skull | jaw hinge under the ear | -X opens; up to -0.8 reads as a roar |
| JointEarL / JointEarR | EarL / EarR | Skull | ear base | +X pins back |
| JointLegFL / FR | UpperLegFL / FR | Chest | shoulder | EnemyAnimator drives these |
| JointElbowFL / FR | LowerLegFL / FR | UpperLeg | elbow | negative X folds the forearm back |
| JointWristFL / FR | PawFL / FR | LowerLeg | wrist | |
| JointLegBL / BR | UpperLegBL / BR | Hips | hip | EnemyAnimator drives these |
| JointKneeBL / BR | LowerLegBL / BR | UpperLeg | knee | positive X bends the shin forward (crouch) |
| JointHockBL / BR | PawBL / BR | LowerLeg | hock | negative X with a bent knee keeps the foot flat |
| JointTail | TailBase | Hips | tail root | EnemyAnimator drives this |
| JointTail2 | TailMid | TailBase | | |
| JointTail3 | TailTip | TailMid | | the brush on the King and Shadow-Mane rides this |

## Extras per body

| Body | Motor6D | Moves (Part1) | Parent | Notes |
|---|---|---|---|---|
| Spirit Wolf B | JointCrest | Crest (the dorsal spikes) | Chest | -X bristles for a windup |
| Elder Wolf King | JointCrest | Crest (silver dorsal blades) | Chest | -X bristles |
| Elder Wolf King | JointManeL / JointManeR | ManeL / ManeR (each side's mane blades) | Neck | sway with Y, flare with Z (signs above) |
| Elder Wolf King | JointSeal | Seal (the jade seal and its ring) | Neck | hinged at the collar; X swings it fore and aft. The Seal is a Neon tell |
| Shadow-Mane | JointMane | Mane (dorsal mane and shoulder drapes) | Chest | -X lifts it, +X streams it back |
| Shadow-Mane | JointManeL / JointManeR | ManeL / ManeR (each side's neck strands) | Neck | sway and flare like the King's |
| Shadow-Mane | JointForelock | Forelock | Skull | -X lifts it |

## Things to know

- **Only the legacy joints are driven in game today.** EnemyAnimator poses JointHead,
  JointTail and JointLeg* procedurally from `AIState` and overwrites them every frame. A
  clip played alongside it fights it on those joints; everything else (jaw, ears, spine,
  lower legs, tail chain, extras) is free.
- **Tested ranges** (no gaps, nothing separates): legs ±0.85 rad at the shoulder and hip,
  elbows and knees ±0.8, a 0.6-stud crouch on JointRoot, the jaw to -0.8, the neck and
  head to 0.35 yaw, the tail chain to 0.6 each, and a full leap stretch (forelegs +1.2,
  hind legs -1.0). The hind thighs have a rounded haunch on the hip axis, so they swing
  cleanly at any angle; the forelegs' block tops sit inside the chest.
- The King's scale is 2.4x: translations on JointRoot are in studs, so scale them up
  (a 0.5 crouch on the Spirit Wolf is 1.2 on the King). Rotations transfer unchanged.
- Tell parts (eyes, the King's brow mark, collar jade and seal) carry the `Tell`
  attribute; they flare in the client FX, not through the clip.
