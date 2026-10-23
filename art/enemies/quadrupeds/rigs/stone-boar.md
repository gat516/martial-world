# StoneBoar_R (21 joints)

Part of [quadrupeds/RIGS.md](../RIGS.md): read that file's shared rules first.


| Joint | Moves | Parent | Notes |
|---|---|---|---|
| JointRoot | Hips | HumanoidRootPart | body root, pivot (0, 3.3, 1.2) |
| JointChest | Chest (front mass, shields, front plates) | Hips | spine bend, pivot (0, 3.5, 1.0) |
| JointNeck | Neck | Chest | |
| JointHead | Head (skull, snout, tusks, eyes, brows) | Neck | the tusks ride the head: aim them with the head |
| JointJaw | Jaw (lower tusks, mouth) | Head | - opens |
| JointEarL / R | EarL / EarR | Head | - pins the ears back |
| JointLegFL / FR | UpperLegFL / FR | Chest | |
| JointLowerLegFL / FR | LowerLegFL / FR | UpperLeg | the elbow |
| JointHoofFL / FR | HoofFL / FR | LowerLeg | the wrist |
| JointLegBL / BR | UpperLegBL / BR | Hips | |
| JointLowerLegBL / BR | LowerLegBL / BR | UpperLeg | the knee: - folds the shank back |
| JointHoofBL / BR | HoofBL / BR | LowerLeg | the hock |
| JointTail | Tail | Hips | + drops it, - lifts it |
| JointTailTip | TailTip (with the tuft) | Tail | |

- The Neon tells are the shoulder cracks, the back crack and the eyes, all on Chest and Head.
- Empty effect Attachments (no joint of their own, they ride their part): `TuskTip` on Head at (0, 4.05, -5.85), centred between the tusk points; `Core` on Chest at its centre (0, 3.4, -0.6); `HoofFL_FX` / `HoofFR_FX` on HoofFL / HoofFR at ground level under the fore hooves, (-1.15, 0, -1.35) / (1.15, 0, -1.35).
- Poses live in `src/client/EnemyPoses/Boar.luau` (Wolf.luau's format; planting from the shared `Quadruped.luau`). QA: `qa_quadruped_poses.luau`.
- **Leg bends (tested):** the fore middle joint juts forward as it folds (`JointLowerLegF*` -, the shank goes back); the hind one juts back like a hock (`JointLowerLegB*` +, the shank comes forward). The rest geometry already slants that way. Fold-backs the other way work for the solver but look wrong on a hoofed animal.
- **The head sits right over the fore legs.** Pitching it down with `JointNeck`/`JointHead` alone swings the jowl back into the elbows and the brow into the chest. Slide the neck forward with it: `JointNeck = CFrame.new(0, 0, -0.3) * pitch` (the neck overlaps the chest by 0.55 at rest, so no gap opens up to about -0.5). Head down -0.3 total, the gore hook up +0.5 with yaw 0.4, and a 0.8 combined yaw all clear with a 0.3-0.55 slide (more slide for more yaw).
- **Fore leg forward swing:** past about 0.65 the elbow ball rises under the chest (it shows as a raised knee at the chest front, fine), and the shank reaches the low jowl, a real clip. The RIGS paw hint (+1.0) clips with the head down: the shipped paw is `JointLegFL` +0.6, `JointLowerLegFL` -1.3, `JointHoofFL` +0.5 with the neck slid 0.45. Gallop fore swing stays near 0.5.
- **Root crouch:** the fore legs are dead straight at rest, so any shoulder rise (root pitch +, chest pitch +) or fore hoof reach forward makes the planted legs drop the root. A root pitch of +0.06 with a -0.3 drop puts the load on the haunches (hind compress ~0.37, fore ~0.15). The hind knee ball rises 0.2-0.35 into the hips' underside in any crouch; it stays inside the body.
- **Death:** roll it about the ground line under the left hooves' outer edge (x -1.6), not by lerping to a rolled root, or the body passes through the ground mid-roll. Full roll 1.45 plus a 0.06 drop puts the flank on the ground; rolling past 1.45 sinks the chest. Keep head yaw at 0 when it lies on its side: 0.1 rad sinks the long head 0.3.
