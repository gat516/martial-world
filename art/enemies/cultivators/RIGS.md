# Cultivator rigs: animator notes

The five cultivators in `ServerStorage._RosterCultivators` (RogueCultivator,
DemonicCultivator, BloodSectCultist, OuterSectDisciple, SectElder) are stock R6 rigs
that also have extra joints for cloth, props and weapons. They open in Moon Animator 2
and the Roblox Animation Editor like `Workspace.Rig`.

## Common to every rig

- **The stock R6 part is untouched.** Head, Torso, Left/Right Arm, Left/Right Leg,
  HumanoidRootPart, and the six stock Motor6Ds (RootJoint, Neck, Left/Right Shoulder,
  Left/Right Hip) have the same names, parents, Part0/Part1 and C0/C1 as
  `Workspace.Rig`. Roblox's stock R6 animations (e.g. walk `rbxassetid://180426354`)
  drive them exactly as they drive `Workspace.Rig`, so any R6 animation plays
  unchanged. The stock R6 sign conventions apply:
  - Shoulders and hips: Z swings the limb forward and back. On the right side +Z is
    forward; on the left side -Z is forward. A negative X moves the limb out to the side
    on both sides.
  - Neck and RootJoint: +X nods or leans forward, and Z turns.
- **Root.** The HumanoidRootPart is the root and is the only part with CanCollide on.
  Nothing is anchored. The Humanoid has an Animator, and the rigs have no scripts.
- **Extra joints** are Motor6Ds, each named after the part it moves (its Part1). Each
  sits inside its Part0 (the limb or the joint it hangs from), and its Part1 is
  parented inside that Part0 too. Each pivot is at the real hinge (the top of a
  hanging piece, the grip of a held one).
- **Sign convention for every extra joint.** At rest each joint's frame has no
  rotation in model space, so its axes are the model's own axes: X across the body,
  Y up, and -Z forward, the way the rig faces. These axes turn with the parent limb.
  For a piece hanging down from its hinge:
  - **+X** swings the lower end forward and **-X** swings it back (a cape or tail
    flaring out behind the body uses -X).
  - **+Z** swings the lower end toward the model's right (+X) and **-Z** toward its
    left.
  - **+Y** turns the piece to the model's left (counter-clockwise from above).
- **Detail pieces don't block keys.** Pieces such as trims, the robe and the ink on a
  talisman are WeldConstraint'ed to the part they ride on, so keying that part
  carries them with it. They don't have joints of their own, so don't key them. Hair
  is a stock Accessory (welded to the Head), and it moves with the head.
- **The split robe.** The robe skirt is a hip band on the Torso plus a robe tube on
  each leg, so the legs swing freely and each leg carries its half of the skirt.
  Strides up to about 0.8 rad at the hips show no gap below the hip band. Wider
  strides start to open the skirt at the front and back.
- **Weapons** keep the game's weapon models. The motor (`HiltR` for the jian, `Hilt`
  for the spear) lives inside the weapon's hilt part, with Part0 = Right Arm. Its
  pivot (C0) is the grip in the fist, so rotating it turns the weapon in the hand.
  It is keyed by the hilt part's name (`HiltR` or `Hilt`), under the Right Arm.
- **Scale.** The Elder is the R6 rig scaled to 1.2 with `Model:ScaleTo`, and every C0
  and C1 is scaled with it. Translation keys are in studs. Rotations are the same as
  at scale 1. Stock animations play correctly on the Elder; checked against
  `Workspace.Rig` with positions scaled by 1.2.

## RogueCultivator

| Joint | Moves | Parent | Pivot / notes |
|---|---|---|---|
| CapeBack | the straw cape's back panel and its ragged straw hem | Torso | under the mantle (0, 3.8, 0.65); -X flares the cape back, Z sways it |
| Gourd | the wine gourd and its cord | Torso | where the cord leaves the sash at the back right; X/Z swing it |
| HiltR | the jian | Right Arm | the grip; at rest the blade points forward, as a player holds it |

## DemonicCultivator

| Joint | Moves | Parent | Pivot / notes |
|---|---|---|---|
| TailL | the left leg's pair of ragged back tails (black and crimson) | Left Leg | top of the tails at the back of the leg robe; -X flares them back |
| TailR | the right leg's pair | Right Leg | as TailL |

The palm and claw attacks use the arms only. The pauldron spikes and talons are
welded to the arms.

## BloodSectCultist

| Joint | Moves | Parent | Pivot / notes |
|---|---|---|---|
| HoodPeak | the raked hood point | Head | its base on the hood top; X nods it, Z flops it sideways |
| CapeletDrape | the back drape under the capelet | Torso | its top edge; -X flares it back |
| Talisman1, Talisman2, Talisman3 | the three front belt talismans (the ink rides each) | Torso | where each is tucked into the belt; X/Z flutter |
| TalismanBack | the back belt talisman | Torso | as above |
| Dagger | the whole kris dagger (grip, guard, pommel, blade, the glowing TellBladeEdge) | Right Arm | the grip in the fist; at rest it points forward |

## OuterSectDisciple

| Joint | Moves | Parent | Pivot / notes |
|---|---|---|---|
| RibbonL, RibbonR | the guan's two blue ribbons | Head | the back of the guan band; -X lifts them back, Z spreads them |
| SashTail1, SashTail2 | the two sash knot tails at the left hip | Torso | the knot; X/Z flutter |
| Hilt | the spear | Right Arm | the grip. At rest the spear stands upright at the right side, the butt just off the ground and the shaft clear of the sleeve. Swinging the right shoulder forward about 1.3 rad brings the spear level for a thrust |

## SectElder (boss, scale 1.2)

| Joint | Moves | Parent | Pivot / notes |
|---|---|---|---|
| SleeveWideL, SleeveWideR | the hanging wide-sleeve ends and their gold cuffs | Left/Right Arm | where the sleeve leaves the upper sleeve; X/Z flare and swing them |
| CoatTailL, CoatTailR | the long overcoat tails at the back of each leg (the gold hem rides each) | Left/Right Leg | the top of each tail; -X flares them back |
| Pendant | the jade bi, its cord, its glowing core and its tassel | Torso | where the cord leaves the sash; X/Z swing it |
| Beard | the long white beard (a plain jointed part, not an accessory) | Head | at the chin (0, 4.1, -0.5); X tucks it or blows it back |
| WhiskHandle | the fly-whisk handle and its gold cap | Right Arm | the grip in the fist |
| WhiskHair | the whisk's horsehair (all three strands) | WhiskHandle | the cap; key it for follow-through after a whisk swing |
| TalismanFan | an invisible pivot for the whole talisman fan | Torso | the Torso centre (0, 3, 0). +/-Y orbits the whole fan round the body, X/Z tilt it |
| Talisman1 to Talisman5 | each floating talisman and its glowing glyph | TalismanFan | each paper's own centre: rotate it to spin or tilt, translate it to bob or fly out |

The talismans are the one deliberate float. They hang behind the back with a clear
gap, and nothing touches them.

## Proof (2026-10-21)

- `art/enemies/keyframe_test.luau`: all five rigs report "keyable". Every Motor6D
  (the stock six and every extra joint) is keyed by its Part1 name and takes its
  keyframe: Rogue 9, Demonic 8, Cultist 13, Disciple 11, Elder 20. There are no
  duplicate joint part names.
- The stock R6 walk on the Humanoid's Animator matches a `Workspace.Rig` control on
  all six stock joints, with a maximum difference of 0.00000.
- `art/enemies/check_rig.luau` reports every rig clean. A forward-kinematics pose of
  the rest, windup and stress poses, with every extra joint swung 0.45 rad, keeps
  every welded piece on its part (drift at most 0.0005).
- Rebuild: run `build_<name>.luau`, then `preview_cultivators.luau` (rest and windup
  rows) or `solo_cultivator.luau` (one model, any pose, at (600, 400, 3000)).
