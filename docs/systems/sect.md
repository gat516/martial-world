# The sect: rank, contribution, the board, the chain, the Pavilion

## Purpose
The sect sends you out and welcomes you home ([roadmap](../roadmap.md) 3, 3b;
[progression](../progression.md) "The sect and its quests"). The MVP (user,
2026-10-23: "lets scope it down and get a mvp going... we can sprinkle in new sect
mechanics as the player advances") is rank and contribution, the board with three
dailies, one chapter chain and a small Pavilion. Halls, masters, weeklies, bounties,
spirit quests and sect-wide goals come later, as the player advances (QR onward).

## Design intent
- **Contribution is soft.** The board only offers. Nothing counts down, flashes or
  opens by itself; a lapsed daily costs nothing.
- **Both roads.** No daily is only combat: at most one combat daily a day, the rest
  peaceful. Every combat chain step has a peaceful path beside it, and either one
  finishes it.
- **Never qi, never whole root pills** from contribution. Qi stays with Pacing. Root
  pill *fragments* are sold, a few a week (user, 2026-10-24: the gardener's road to a
  better root; never for Robux).
- **Rank goes by contribution earned** (all time), so spending at the Pavilion never
  costs a promotion.

## Behaviour
- **Opens at QC5** (`Pacing.Sect.OPENS`; no lesson of its own since 2026-10-24: the
  elder's Talk for the QC5 Rumours lesson points at it). From then on the board's
  Read prompt (`Workspace.Hub.QuestBoard`) opens the sect board; before, it opens the
  goals list as it did. The elder's "What should I aim for next?" still opens the goals
  list at any stage.
- **Ranks** (`RANKS`): Outer Disciple (start), Inner Disciple (QR1 and 600 earned, pays
  300 stones), Core Disciple (FE1 and 2500 earned, pays 1500 stones). When both are met
  a promotion notice (升 seal) is pinned first on the board; claiming it opens the
  rank card (`SectRank.rankUp`: the shared Rewards `rank` card with the stones tile),
  sets the player attribute `SectRank`, and counts a Foundation experience
  `world:sect:rank:<rank>`. The road to the next rank is always in the quest log
  ("Rise to Inner Disciple": the realm and "Contribution earned x / 600").
- **Dailies** (`DAILIES`): `OFFERED` (3) rolled at 00:00 UTC (like the daily login),
  at most `COMBAT_MAX` (1) combat ones with `COMBAT_CHANCE` (0.65), the rest peaceful.
  Take any of them (all three if you like); progress counts from when it was taken; a
  done one is claimed at the board. A new day drops unfinished ones. The pool:

| Kind | Notice | Goal (QC / QR / FE) | Contribution | Stones share |
|---|---|---|---|---|
| hunt (combat) | Thin the beasts: beasts at most `HUNT_BELOW` (2) stages under your realm (realm variants count by their spawn's realm) | 8 / 10 / 12 | 40 | 1 |
| herbs | Herbs for the alchemy hall: bring tier `HERB_TIER` herbs (I at QC, II at QR, III at FE), handed over on claim, cheapest first | 6 | 40 | 1 |
| gather | Draw from the qi veins: qi node gathers (`stats.gathered`) | 3 / 4 / 4 | 30 | 0.75 |
| seclusion | Close the door: an hour in seclusion (`stats.secluded`) | 60 min | 40 | 0.75 |
| store | Bring it home: one Store all that banks something | 1 | 25 | 0.5 |
| harvest | Tend the spirit beds: plants harvested | 4 / 6 / 8 | 30 | 0.75 |
| cache | A rumour of a cache: a world manual cache found (only offered while one is unclaimed) | 1 | 60 | 1.5 |

  Stones = `DAILY_STONES` by major (40 QC, 110 QR, 300 FE) x the share. Daily
  contribution stops at `WEEK_CAP` (700 a week, from Monday 00:00 UTC; the board's
  status row shows "x / 700 this week"); the stones still pay.
- **The chain, "Ash Past the Gorge"** (Ruined Borderlands, giver Elder Qingyun), one
  step at a time, each pinned (quest scroll) once its stage is reached; taking it
  starts it, claiming it sends the Quest Complete card (contribution and stones tiles,
  the next step's hint as its line). Steps pay `CHAIN` (60 contribution, 60 stones),
  the last `CHAIN_FINAL` (150, 200) plus a Foundation experience `world:sect:chain:Borderlands`.
  1. QC5 **Smoke past the gorge**: cross into the Ruined Borderlands (region `MiddleWilds`).
  2. QC6 **Ash on the road**: slay 6 beasts of QC5 or above, *or* bring 6 tier I herbs
     for the wounded.
  3. QC7 **The drowned shrine**: find the Drowned Shrine (within `PLACE_RADIUS` 50).
  4. QC8 **What the dead left**: slay 2 elite (or apex) beasts, *or* gather qi at 4 nodes.
  5. QC9 **The Broken Pagoda**: climb to the Broken Pagoda, *or* slay the Elder Wolf
     King (optional, the fast road).
  Places are found by name under `Workspace.Map` (`DrownedShrine`, `BrokenPagoda`, the
  Borderlands POIs), else the flat points in `Sect.luau` `PLACES` (the map doc's, moved
  +220/+700).
- **The Pavilion** (a notice, 阁 seal, last on the board): seed packets (tier I: 4
  seeds for 40, Outer; tier II: 3 for 150, Inner; tier III: 2 for 450, Core; one sold
  herb of the tier, rolled), the spirit ring's +1 slot (once per major: 200 QC, 500 QR,
  1200 FE; `Haul.ringSlots` adds `data.sect.ring[major]`), and copies of the
  kill-milestone manuals while not owned or held (Fire Seal 60, Sword Qi Wave 100,
  Iron Skin 150, Moonflash Draw 200, Palm Strike 250; through `Progression.grantManual`,
  so the Dao gate still holds), and root pill fragments ([spirit root](../character/spirit-root.md)
  "Pity fragments"): a Marrow Washing fragment for 100 (3 a week) and a Root Rebirth
  fragment for 80 (2 a week), `Pacing.Sect.FRAGMENTS`, counted in `data.sect.weekBought`
  and reset with the dailies' week (Monday 00:00 UTC). Ten fuse into the pill on their
  own (`Inventory.fragment`). Needs a tested root. 3 Marrow a week is about 300 of the
  ~700 a week dailies pay, so a pill every ~3.5 weeks from the Pavilion alone. No
  cosmetics: none are sold anywhere yet.
- **Quest log and tracking:** tapping a taken notice opens the quest log on it (taken
  dailies, the chain step with both paths, the rank road). Track puts it on the HUD
  objective line in free play (`Quests.trackedObjective`: after a guiding lesson,
  before the open lessons and the goals).
- **Testbed:** the board opens at any realm, the chain ignores stage gates, and place
  steps are done when taken (no map). The admin panel's "Sect contribution" section
  gives contribution (counts toward rank, past the cap) and rerolls the dailies.

## Heart demon
`stats.contribution` (earned) and `stats.dailies` (claimed) feed the sect question
([heart-demon](heart-demon.md)): the dutiful disciple from `DUTY_MIN` (10) dailies, or
the lone wolf (at most `LONE_MAX` 1, the board read).

## Data and remotes
- `data.sect`: `rank`, `contribution` (to spend), `earned`, `week`/`weekId`, `day`,
  `offered`, `taken` (by kind: goal, base counter, progress, tier, claimed), `chain`
  (steps done), `step` (the taken step's paths), `tracked`, `ring`, `bought`. Stats:
  `contribution`, `dailies`, `gathered`.
- Server to client on `QuestState`: `{ sect = view, open }` (status, tasks in board
  order, quests for the log, tracked, the Pavilion stock), sent when it changes and
  on the Read prompt; `{ sectRankUp = { rank, line, items } }`. Onboarding ignores both.
- Client to server on `CultivationAction` `("sect", op, arg)` (Main routes it to
  `Sect.handle`): `take` / `claim` (a kind or "chain"), `promote`, `buy` (`seeds:<tier>`,
  `ring`, `manual:<id>`), `track` (`daily:<kind>`, `chain` or ""). Refusals come back
  as toasts. Claims call `Quests.onClaimed` (`Daily:<kind>`, `Chain:Borderlands:<n>`,
  `Rank:<rank>`) for analytics and traits.

## Key files
- `src/server/Sect.luau`: everything above; `Sect.onKill` on `EnemyService.onKill`.
- `src/shared/Pacing.luau` `Sect` (all tuning), `HeartDemon` `DUTY_MIN`, `LONE_MAX`.
- `src/client/SectView.luau`: wires `Sect/SectBoard`, `Sect/QuestLog`, `Sect/SectRank`
  ([sect board](../ui/sect-board.md)) and the interim Pavilion list.
- Hooks elsewhere: `Quests` (`openBoard`, `trackedObjective`), `Haul.ringSlots`,
  `Cultivation` (`ringSlots` in the state), `QiNodes` (`stats.gathered`), `HeartDemon`
  (`sectQuestion`), `Admin` (`contribution`, `sectDailies`).

## Known gaps
- **UI (ui-designer):** no Pavilion page in `assets/Sect.rbxmx`; the Pavilion borrows the
  HUD's `QuestBoardWindow` list, retitled. The promotion and Pavilion notices use the
  daily seal with live 升 / 阁; dedicated seals would read better. No HUD entry opens the
  quest log (only a taken notice does; `SectView.openLog` is ready). The status row has
  no "earned toward rank" line (the log shows it).
- The elder's once-a-session pointer ("The elder summons disciples to the hall") isn't
  sent yet.
- Chain steps are defined in `Sect.luau`, not as `Quests.Quest` defs; a second chain
  should move them to a shared def format.
- Untested in play: all of it. Place positions without the map POIs are estimates.
- Later (roadmap 3): weeklies, bounties, sect tasks, the torn notice, Halls, masters.
