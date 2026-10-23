# Stone Boar (shipped)

The ring-1 charger (shipped): fight, numbers, effects. Shared systems (AI states, wire, cues, attack mechanics, template contract): [enemies.md](../systems/enemies.md).

Built behind `Config.Wilds.NEW_BOAR` for the testbed first; the user shipped it to the
main game on 2026-10-21 (`NEW_BOAR = true`) without fighting it in the testbed first.
Setting the flag back to false still brings back the old boar (one 1.0 s charge,
160 HP, the old body). **Follow-up:** remove `OLD_STONE_BOAR` (Enemies.luau), the old
`StoneBoar` template in `assets/Enemies.rbxm` and the flag once the new boar has
proved itself in play. User direction (2026-10-21): "a charge and then it uses its tusk
to attack you". Either `NEW_WOLF` or `NEW_BOAR` turns on attack slots and dash-front
hits for every non-boss beast (`TURNS` in EnemyService).

With the flag on: the body is `StoneBoarB` (the roster boar, built by
`art/enemies/quadrupeds/build_stone_boar.luau` + `rig_stone_boar.luau`, posed by
`EnemyPoses/Boar.luau`, effects in `EnemyFX/StoneBoar.luau`, "Stone Boar effects"
above; shared leg planting in `EnemyPoses/Quadruped.luau`, QA
`art/enemies/quadrupeds/qa_quadruped_poses.luau`). EnemyAnimator loads the pose module
only if it's there (`FindFirstChild`) and falls back to the generic pose. Tells: the Neon cracks
`CrackL1/L2/R1/R2`, `CrackBack` (Chest) and `EyeL/EyeR` (Head); effect attachments
`TuskTip` (Head), `Core` (Chest), `HoofFL_FX`, `HoofFR_FX`. It never hops.
- **Pacing:** while the charge is ready (or within 1 s of it) it side-paces 16 studs
  out (`pack.circle` with `waitFor = "charge"`, 5 studs/s, facing you; it closes in
  from farther and backs out to 16 from closer). While the charge cools down it
  closes in to gore range and gores, holding at 4 studs when the gore is cooling too.
- **Charge:** straight through you, but only 3 studs past where you stood at the
  windup (`stopPast`; the lane is clamped between 12 and 30 studs, and the telegraph
  shows the real lane). EnemyAnimator times the dash pose from the `DashSeconds`
  attribute.
- **Follow-up:** if you're within 7 studs when the charge's recover ends it gores at
  once (`followUp`: past its pause and the gore's cooldown, but it still waits for the
  attack slot, up to 1 s past the recover, `FOLLOW_UP_WAIT`).
- **Opener:** each engagement opens with the charge, but if you rush it inside the
  charge's 12-stud minimum it uses its pool (the gore) instead of waiting
  (`pack.closeOpener`; the wolf doesn't set it).

Fix 2026-10-21: in play it only ever charged. The 30-stud dash left it far past you
so the follow-up lapsed, circling held it at 16 studs, and the opener rule blocked the
gore up close.

| Attack (`name`) | Kind | Windup / active / recover | Range | Area | Damage (QC4 165 HP) | Cooldown |
|---|---|---|---|---|---|---|
| `charge` (opener) | charge | 1.0 / up to 0.55 (distance + 3, 12-30 studs at 55/s, `dash`) / 0.7 | 12-28 | box 5 x lane | 26 (16%) | 4 s, then the gore if close |
| `gore` | cone | 0.6 / 0.15 (the hook: the first 0.15 s of recover) / 0.8 in all | 0-7 | cone r 7, 100 deg | 20 (12%) | 2.5 s |

Cues as the wolf's: `windup` (Telegraph remote, `seconds` = the windup only),
`strike` (windup -> dash for the charge, windup -> recover for the gore), `dash`
with the strike, `land` as it leaves `dash`, `hit` once per player caught (the
charge's when the dash front reaches them), `stagger`, `death`. The gore resolves at
windup end; the hook is drawn in the first 0.15 s of `recover`.

Health 200 (was 160), QC4, weight 2.5, qiDrop 24. Sounds (`SFX.Enemies.StoneBoar`, PSE,
picked by description, unheard): `Attack_charge` (Pig Grunts 2, deep, 0.85 pitch),
`Attack_gore` (Pig Squeals 6 at 0.7), `Hurt` (Pig Grunts 5), `Land` (Debris Rain 4, the
skid as a charge ends); the old boar picks these up too. The testbed's
`Wilds.Zones.BoarPair` keeps two at (100, 648.6, -40).


## Effects
`EnemyFX/StoneBoar.luau`, templates `ReplicatedStorage.Effects.StoneBoar`
(builder `tools/vfx_specs/StoneBoar.luau`, built straight from the
enemy-designer's brief, no new references). Earth qi: #FF8A2B amber with a
white-hot centre, #7E5D45 umber dust, #8F8B80 stone chips, a slate copy under
each bright shape for daylight. Every handler returns early unless the model's
`Template` is `StoneBoarB` (the old boar has none of these hooks). Body hooks
(a7115a5): attachments `TuskTip` (Head, between the two tusk points; each tusk
point is 1.15 studs either side), `Core` (Chest), `HoofFL_FX`/`HoofFR_FX`
(ground under the fore hooves); hind hooves are the `HoofBL`/`HoofBR` parts;
`Tell = true` on `CrackL1/L2/R1/R2`, `CrackBack` and `EyeL/EyeR`.

| Cue / attack | Template (layers) | Notes |
|---|---|---|
| windup, both | `EyeGlint` (amber star, pop) on each eye at t = 0 | every Tell part goes 50% dim -> hot amber over `seconds`, back 0.2 s after (`TellBase` keeps the original colour) |
| windup charge | `HoofScrape` (dust ring, puffs kicked back, slate grit) at HoofFL_FX at 0.2 and 0.55 x seconds; `Snort` (2 nostril jets) at NosePad at 0.8 x seconds | the second scrape and the snort only while AIState is still `windup` |
| windup gore | `TuskGlint` (slate dot, spinning amber glint, halo) on each tusk point | follows the Head |
| strike/dash charge | `DashDust` (umber ring, low puffs, chips, amber embers) between the hind hooves; `ChargeTrail` (dust, chips, slate grit, amber sparks; Rate emitters) ridden under the HRP at hoof level | strike and dash dedupe (0.25 s); trail stops at `land`, death or 0.65 s |
| strike gore | `GoreHook` (crescent sweep x bone core / amber rim / slate, glint at the peak) 4.5 studs ahead of TuskTip, 1 stud low, sweeping up 0.18 s | |
| land charge | `Skid` (umber under-puff, dust thrown forward, chips) 1.2 studs ahead of the fore hooves | |
| hit charge | `ChargeHit` (slate blot, amber flash, star, dust burst, chips) on the target's torso, near side | `CombatEffects.shake(0.3)` when the target is the local character |
| hit gore | `GoreHit` (crescent mark x core/slate, amber sparks, pop) | |
| stagger | `StaggerChips` (amber pop, dust, chips) at Core | Tell parts flicker 3x |
| death | `Death` (umber dust crumbling 0.9 s, amber motes rising, core glow and glint) | Tell parts fade to slate in 0.3 s; the body's 1 s fade is init's |

Layers per beat: windup 2 (+ tell) + 3 to 5; take-off 4 + 4; gore hook 4;
skid 3; hits 4 to 5; stagger 3; death 4. Library ids are in the builder's
`TEX` table. Untested in play: placement on the moving, animated body (tusk
points, trail height), the full cue path, how it reads at 40 studs and on
phones, and the Game Module path (effects play on TechniqueVFX's fallback
when the module isn't in the place).

## Known gaps
- The Stone Boar's gore fix (shorter charge, closing in while the charge cools down,
  goring when rushed) is untested in play: whether it now gores, whether the 4-stud
  hold crowds the player, and whether it backs off to charge too often for the gore
  to come up outside the follow-up.
- The Stone Boar fight shipped untested in play (not fought in the testbed first): its
  poses in EnemyAnimator, whether pacing at 16 studs reads as
  stalking, the gore's reach (range 7 against a cone of radius 7), the follow-up's wait
  for the slot, sounds (picked unheard). Time to kill at QC4 is about 14 s, above the
  pack-beast guide.
