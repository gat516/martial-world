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
taller, wider and brighter and the element's pieces bigger; a Heaven or Immortal
root also gets the sky burst. A short glow on the stone when `first` is false.

**Rare-root glow (user, 2026-10-24):** a rare root (Lightning, Wind, Ice) shows
after the reveal too: while its player sits (meditating or circulating), every
client adds a PointLight of the element's colour to their method aura
(`MethodAura` `RARE_GLOW`, read from the `Root` attribute), so others can tell a
rare root at a glance. Code only; a richer element trail is a vfx pass for later.

**Element (rolled):**

| Element | Odds | Perk (one line on the card) | Matching techniques (`Techniques` `element`) |
|---|---|---|---|
| Fire | 18% | Your techniques hit harder (+8%) | Fire Seal, Twin Phoenix Cannon |
| Water | 18% | You heal faster out of combat (2%/s) | Crescent Moon Sweep |
| Wood | 18% | Your herbs grow faster (+25%, while online) | Dragon-Piercing Thrust |
| Metal | 18% | Your weapon strikes hit harder (+8%) | Sword Qi Wave, Iron Skin, Rampaging Tiger Cleave |
| Earth | 18% | You have more health (+10%) | Palm Strike, Heaven-Splitting Descent |
| Lightning (rare) | 4% | You run faster (+3), and your techniques hit harder (+6%) | Lightning Talisman |
| Wind (rare) | 3% | You jump higher (+20%), and your weapon strikes hit harder (+6%) | Great Sage Awakening |
| Ice (rare) | 3% | You take less damage (-8%), and you have more health (+6%) | Moonflash Draw |

- Perks are small so no element is "the best"; the numbers are at Spirit grade
  and scale with grade (`Pacing.Roots.PERKS`, `BONUS`, `GRADES`).
- **Rare roots are worth at least a common one (user, 2026-10-24).** The review
  found Lightning (+2 walk) and Wind (+15% jump) the weakest perks, so teens
  would reroll away from the rarest roots. Each rare element now has a stronger
  main perk plus a second perk worth about a common root's whole perk
  (`Pacing.Roots.BONUS`; `Roots.perks` lists them, `Roots.perk` sums by kind).
  The card shows both lines.
- **Matching technique:** +15% damage on techniques of your element
  (`Pacing.Roots.MATCH`). Every element has at least one.
- The perks touch systems that already exist (combat, health, regen, garden,
  movement), so every root does something on day one. Where they apply:
  `Cultivation.rate` / `applyStats` (speed, health, walk, jump), `Circulation`
  (refining speed), `Combat` (`strike`, technique damage, `guard` in `hurt`),
  `Garden.tendGarden` (growth), `Roots` (Water's regen loop).

**Grade (grows):** everyone starts at **Spirit** grade (jade). In the lore a
Mortal grade means no root at all, so nobody is told their root is trash.
- Spirit -> Earth -> Heaven -> **Immortal** raises passive and refining speed
  (x1.0, x1.1, x1.25, x1.4) and strengthens the element perks (x1, x1.5, x2, x2.5).
- **Why these four (user, 2026-10-24: keep Earth and Heaven, more steps welcome):**
  one rare grade was added on top, **Immortal**, because every kid knows an
  immortal is the very top of cultivation, it needs no explaining, and it gives
  Heaven-grade players a long goal. Its colour is rose (`Roots.GradeColors`;
  weapons have no Immortal grade). No grade was added below Spirit: a lower start
  would either change everyone's speed (existing saves at Spirit would leapfrog new
  players) or be a step that does nothing, and a starting grade under "Spirit"
  risks reading as "your root is trash". Existing saves keep their grade.
- Raised by the **Marrow Washing Pill** (built: Legendary, `Items.luau`), and it
  takes several: **3 to reach Earth, 5 more for Heaven, 8 more for Immortal**
  (`Pacing.Roots.WASH`).
  Each absorbed pill adds one to the current element's washing progress
  (`root.washed[element]`, `Roots.wash`); reaching the count raises the grade and
  clears it (pills absorbed also count in `data.stats.washed`, Root Rebirth Pills in
  `rerolls`, for the [heart-demon](../systems/heart-demon.md) trial). The Spirit Root page shows the progress ("Washed 1/3 toward Earth
  grade") on the root row and the pill row.
- **Extremely rare (user, 2026-10-23: "those pills should be EXTREMELY rare and u
  should need multiple"):** bosses only, never common beasts (Elder Wolf King and
  Jade Jiao 2%, Thunder Ape and Nine-Tailed Fox 4%), and the rarest heavenly
  treasure (weight 1 of 103, about 1%). Earth is a long hunt; nothing in Qi
  Condensation realistically reaches Heaven. Later also alchemy and the
  Auspicious Clouds relic. It is a long-term goal, not a gate.
- **Pity fragments (user, 2026-10-24).** Every boss kill (Enemies `boss`) and every
  claimed heavenly treasure that gives no root pill gives a **Marrow Washing
  fragment**, and 25% of the time also a **Root Rebirth fragment**
  (`Inventory.pity`, `Pacing.Roots.FRAGMENTS`). **10 fragments fuse into the pill
  on their own** (`Inventory.fragment`; granted like a drop, with a notice), so no
  one goes 200 kills dry: Earth is at most 30 boss kills. Fragments are counted in
  `root.fragments` (by pill id, shared by every element, never lost on death) and
  shown on the Spirit Root page and the root card's detail once one is held. The
  **Sect Pavilion** sells them for contribution, weekly-capped
  (`Pacing.Sect.FRAGMENTS`, [sect](../systems/sect.md)), so gardeners have a road
  too. Never sold for Robux.
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

**Heaven grade vs Defier of Heaven (user, 2026-10-24).** The Heaven grade keeps its
name. The heaven-defying flag (`data.heavenDefying`, tribulations) is called
**Defier of Heaven** wherever players see it (`Pacing.HeavenDefying.TITLE`), never
"heaven-defying", so the two can't be mixed up.

**Data:** `data.root = { element: string, grade: string, pending: string, grades: { [element]: grade }, washed: { [element]: pills }, fragments: { [pillId]: count } }` (schema v6; `pending`, `grades`, `washed` and `fragments` filled by default); `""`
element = not yet tested; `grade` is the current element's, `grades` the others'
(saves from before 2026-10-21 have none recorded, so earlier elements read as Spirit). Tuning in `Pacing.Roots`. Pushed in `PlayerState`
(`root`); published as player attributes `Root` and `RootGrade` for others'
nameplates and effects. Admin panel: "Spirit root" (reroll, set, untest,
raise grade). Analytics: event `RootTested` with the element.
