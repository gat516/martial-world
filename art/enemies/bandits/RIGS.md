# Bandit rigs: animator notes

Templates: `ServerStorage._RosterBandits.{MountainBandit, BanditArcher, BanditChief}`.
Built by `build_*.luau` (shared helpers in `bandit_common.luau`). Previews in
`Workspace._RosterPreviewBandits` (anchored, `EditorOnly`; motors cut, so animate a fresh
clone of the template, not a preview copy).

Each bandit is a stock R6 rig: `HumanoidRootPart` (root, the only anchored part while you
animate it), `Humanoid` with an `Animator`, the six stock joints untouched, no scripts.
Every extra piece an animator moves on its own has its own Motor6D, named after the part it
moves, parented in its Part0. Everything else (armour, trim) is welded inside the part it
moves with, so it follows any pose. Opens in Moon Animator 2 and the Animation Editor;
`art/enemies/keyframe_test.luau` keys every joint by Part1 name and reports all three
keyable (MountainBandit 14 joints, BanditArcher 14, BanditChief 12).

## Sign conventions

Stock R6 (pose applied in the joint's frame):

| Joint | + rotation |
|---|---|
| Right Shoulder | +Z swings the arm forward. -X swings it out while it hangs; once the arm is overhead, +X tips it out |
| Left Shoulder | -Z swings the arm forward. -X swings it out while it hangs; overhead, +X tips it out |
| Right Hip | +Z swings the leg forward, -X out |
| Left Hip | -Z swings the leg forward, -X out |
| Neck | +X pitches the head down, +Z turns the face to the bandit's left |
| RootJoint | +X leans the torso forward, +Z turns the front to the bandit's left (so -Z brings the left shoulder forward) |

Extra joints have identity frames in model space at rest (unless noted), hinged at the
listed point:
- **+X** swings a hanging piece's lower end forward (-Z).
- **+Z** swings it toward the bandit's right (+X).
- **+Y** turns its front toward the bandit's left.

Pieces on a jointed limb take that limb's frame as it moves, so "forward" means forward
for that limb.

## MountainBandit (scale 1)

| Joint | Moves | Parent (Part0) | Hinge | Notes |
|---|---|---|---|---|
| Hilt | dao (whole `Dadao` model) | Right Arm | the grip, bottom of the hand | stock weapon motor, lives in `Dadao.Hilt`. +X pitches the blade up when the arm hangs |
| Hat | conical straw hat (+ chin cord) | Head | crown of the head | a plain part, not an Accessory, so it can tilt. Arms overhead pass through the brim: tilt it back (-X) or key it out of the way |
| SashTail1, SashTail2 | sash ribbons at the right front hip | Torso | top of each ribbon at the knot | when the right leg kicks high (more than ~0.8 forward plus out) the thigh reaches them: key them forward (+X) |
| WrapTail1, WrapTail2 | face-wrap tails at the back of the head | Head | knot at the back | -X lifts them back (wind or motion) |
| SkirtL, SkirtR | tunic flaps (front + back panel + teeth) | Left Leg / Right Leg | the hip axis | they ride the legs, so a stride never pokes the thigh through. Leave them at 0 for walks; key a little trail (-X on a forward leg) for flair |

## BanditArcher (scale 1)

| Joint | Moves | Parent | Hinge | Notes |
|---|---|---|---|---|
| Bow | the bow (grip, limbs, tips, string tips) | Left Arm | the grip, outside the fist | Its frame is the bow's: Y runs up the bow to the top tip, +Z points to the string side, X is normal to the bow plane. At rest the bow leans 0.9 from upright, top tip forward. +X tips the top toward the string side |
| Nock | the middle of the string (invisible carrier) | Bow | the string's middle | Same axes as Bow. **Translate** it: +Z draws the string back toward the archer; X and Y slide the nock point. The string is two Beams (tips to nock), so it bends wherever the nock goes |
| Quiver | quiver + arrows | Torso | middle of the back, where the strap crosses | +Z/-Z swings it side to side (bounce on a run) |
| BandTail1, BandTail2 | headband tails | Head | knot at the back | |
| ScarfTail | scarf end at the chest | Torso | top of the tail | |
| SkirtL, SkirtR | leather skirt flaps (front + back) | Left Leg / Right Leg | hip axis | ride the legs, as on the Mountain Bandit |

Full draw (the preview windup, `bandit_poses.luau`):
- `RootJoint A(0,0,-1.4)` turns the archer side-on with the left shoulder leading, and `Neck A(0,0,1.26)` turns the head back to face the target.
- `Left Shoulder A(0,1.4,-1.57) * A(0,pi,0)` points the bow arm at the target and twists it half a turn about its own axis, so the bow sits inboard of the fist, in line with the right hand. As XYZ Euler that's about (-3.14, -1.40, -1.57).
- `Right Shoulder A(0,1.4,1.57)` points the string arm the same way.
- `Bow A(-0.672, 0, pi)` stands the bow upright with the string toward the archer.
- `Nock` translate (-0.28, 0, 1.59) draws the string back to the right hand.

If you change the arm pose, `bandit_poses.luau` `P.solveAim` re-solves the upright Bow
angle (set the pose value to `"aim"` in the preview).

## BanditChief (scale 1.28, elite)

| Joint | Moves | Parent | Hinge | Notes |
|---|---|---|---|---|
| Hilt | guandao (whole `Guandao` model) | Right Arm | the grip | as on the Mountain Bandit. The pole is long: check it against the helm horns on overhead swings |
| Cape1 | upper fur cape panel | Torso | under the mantle at the shoulders | -X lifts the cape out behind (run, lunge) |
| Cape2 | lower cape panel + tufts | Cape1 | where the two panels meet | chain with Cape1: key Cape2 a little more than Cape1 for a curl |
| Plume | red helm plume (stem + 5 feathers) | Head | base of the stem | small overshoot on head turns sells weight |
| SkirtL, SkirtR | coat skirt halves + iron tassets | Left Leg / Right Leg | hip axis | ride the legs |

The model is scaled 1.28 with `Model:ScaleTo`, so joint offsets (C0/C1) are 1.28x stock.
Rotations are unchanged and keyframes from a scale-1 R6 play the same. Translations in a
clip are in studs, so a translated key moves 1/1.28 as far relative to the body.

## Safe ranges (where armour starts to clip)

These come from the posed clip test in `qa_bandits.luau`:
- **All:** stock R6 limbs cross each other in big poses (thigh into torso on a 1.0 stride, arms through the head overhead). That's R6, not the dress.
- **MountainBandit:** a high front kick (Right Hip forward more than ~0.8 with -0.5 out) reaches the sash ribbons. Arms overhead go through the hat brim.
- **BanditArcher:** clean in the tested poses: draw, 1.0 stride, arms overhead with a turned head.
- **BanditChief:**
  - Keep a hanging arm's out-swing (Shoulder X) within about -0.4. Past that the arm's top, and the pauldrons with it, swings in toward the helm.
  - A 1.0 rad arm swing brushes the bracer trim on the lamellar bands (0.13).
  - The shoulder fur tufts ride the arms, so arms overhead carry them clear.
