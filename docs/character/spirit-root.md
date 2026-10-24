# Spirit root

Covers the spirit root: the Testing Stone reveal and its pillar, elements and perks, grade, rerolls and data; read it when working on roots, `Roots.luau`, `RootFX` or root pills. Shared layer rules are in [character](../systems/character.md).

**What it is:** your element, revealed once, early. It is the first thing that
says "this cultivator is you".

**The reveal:** a new onboarding beat, `Root`, right after `Breakthrough`; travel
unlocks here, so the trip teaches the arrays. The elder sends you to the
**Testing Stone** in the hub (`Workspace.Hub.TestingStone` with a ProximityPrompt
`TestPrompt`; `Roots.test`). The server fires `Effect "root"` to everyone
`(player, element, grade, first)`. You touch it, a pillar of
your element's colour rises (vfx), your root's name and one-line perk appear,
and the elder reacts (more excited for a rare root). It needs no decisions.
Players already past the beat get "Have your root tested" as a quest-board goal.
The pillar is `src/client/RootFX.luau` (template `ReplicatedStorage.Effects.RootPillar`,
built by `tools/vfx_specs/RootPillar.luau`): a column from the stone's `PillarOrigin`
wrapped in the element's own reveal, in the same visual language as its methods'
auras ([auras.md](../systems/auras.md)): Fire a heart beating twice and a crown of flame
climbing the column, Water a pool spreading over the ground with ripples and
rings spouting up, Wood roots growing out and branches sprouting off the column
with a leaf burst at the top, Metal a gold gem and clang rings snapping out up
the column under a sunburst, Earth a carved stone ring rising round the stone
with a rune circle, Lightning jagged bolts striking the stone under a darkened
violet sky, Wind a vortex of rings corkscrewing up and clouds spraying out, Ice a
giant glass lotus blooming round the stone. Rare roots go taller with a ground
shockwave, a sky burst and a sky tint. Grade (in the payload) makes the column
taller, wider and brighter and the element's pieces bigger; a Heaven root also
gets the sky burst. A short glow on the stone when `first` is false.

**Element (rolled):**

| Element | Odds | Perk (one line on the card) | Matching techniques (`Techniques` `element`) |
|---|---|---|---|
| Fire | 18% | Your techniques hit harder (+8%) | Fire Seal, Twin Phoenix Cannon |
| Water | 18% | You heal faster out of combat (2%/s) | Crescent Moon Sweep |
| Wood | 18% | Your herbs grow faster (+25%, while online) | Dragon-Piercing Thrust |
| Metal | 18% | Your weapon strikes hit harder (+8%) | Sword Qi Wave, Iron Skin, Rampaging Tiger Cleave |
| Earth | 18% | You have more health (+10%) | Palm Strike, Heaven-Splitting Descent |
| Lightning (rare) | 4% | You run faster (+2) | Lightning Talisman |
| Wind (rare) | 3% | You jump higher (+15%) | Great Sage Awakening |
| Ice (rare) | 3% | You take less damage (-6%) | Moonflash Draw |

- Perks are small so no element is "the best"; the numbers are at Spirit grade
  and scale with grade (`Pacing.Roots.PERKS`, `GRADES`).
- **Matching technique:** +15% damage on techniques of your element
  (`Pacing.Roots.MATCH`). Every element has at least one.
- The perks touch systems that already exist (combat, health, regen, garden,
  movement), so every root does something on day one. Where they apply:
  `Cultivation.rate` / `applyStats` (speed, health, walk, jump), `Circulation`
  (refining speed), `Combat` (`strike`, technique damage, `guard` in `hurt`),
  `Garden.tendGarden` (growth), `Roots` (Water's regen loop).

**Grade (grows):** everyone starts at **Spirit** grade (blue). In the lore a
Mortal grade means no root at all, so nobody is told their root is trash.
- Spirit -> Earth -> Heaven raises passive and refining speed (roughly x1.0,
  x1.1, x1.25) and strengthens the element perk.
- Raised by the **Marrow Washing Pill** (built: Legendary, `Items.luau`), and it
  takes several: **3 to reach Earth, 5 more for Heaven** (`Pacing.Roots.WASH`).
  Each absorbed pill adds one to the current element's washing progress
  (`root.washed[element]`, `Roots.wash`); reaching the count raises the grade and
  clears it. The Spirit Root page shows the progress ("Washed 1/3 toward Earth
  grade") on the root row and the pill row.
- **Extremely rare (user, 2026-10-23: "those pills should be EXTREMELY rare and u
  should need multiple"):** bosses only, never common beasts (Elder Wolf King and
  Jade Jiao 2%, Thunder Ape and Nine-Tailed Fox 4%), and the rarest heavenly
  treasure (weight 1 of 103, about 1%). Earth is a long hunt; nothing in Qi
  Condensation realistically reaches Heaven. Later also alchemy and the
  Auspicious Clouds relic. It is a long-term goal, not a gate.
- **Never in the hook:** everyone starts at Spirit, and the first session never
  hands out or teaches root pills. The test kit skips them
  (`Config.TestKit.SKIP_ITEMS`); the RootPill lesson waits for QC5 and a pill
  actually held ([onboarding](../systems/onboarding.md)). Admin "raise grade"
  (F2) still jumps a whole grade at once (`Roots.raiseGrade`).

**Rerolls (built, decided 2026-10-21): earned, never sold.** The **Root Rebirth
Pill** (Epic; bosses only, 3% from the Elder Wolf King and Jade Jiao, 5% from
the Thunder Ape and Nine-Tailed Fox, and a rare heavenly treasure, weight 2)
reforms the root as a different element (`Roots.reroll`, rolled with the usual
odds). The new element waits in `data.root.pending` and the player chooses:
keep it, or return to the old one (`Roots.choose`, `CultivationAction("root",
keepNew)`). **Each element keeps its own grade** (decided 2026-10-21): one
you've never held starts at Spirit, and one you held before comes back at the
grade it reached (`Roots.switch` saves the old element's grade in
`root.grades`; `Roots.gradeOf`). Marrow Washing washes only the current element,
and each element keeps its own washing progress.
The pending row shows the new element's own grade. So a reroll trades grade for
element; returning costs nothing, so it can never leave you worse off
(principle 5), and it isn't gacha: no Robux, and you can always say no.
Both pills are absorbed seated in meditation (`Inventory.use`, item uses
`rootGrade` / `rootReroll`), from the meditation menu's Spirit Root page.

**Data:** `data.root = { element: string, grade: string, pending: string, grades: { [element]: grade }, washed: { [element]: pills } }` (schema v6; `pending`, `grades` and `washed` filled by default); `""`
element = not yet tested; `grade` is the current element's, `grades` the others'
(saves from before 2026-10-21 have none recorded, so earlier elements read as Spirit). Tuning in `Pacing.Roots`. Pushed in `PlayerState`
(`root`); published as player attributes `Root` and `RootGrade` for others'
nameplates and effects. Admin panel: "Spirit root" (reroll, set, untest,
raise grade). Analytics: event `RootTested` with the element.
