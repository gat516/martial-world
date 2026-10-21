# Character: roots, methods, bloodlines and the character window

**Status:** cultivation methods are built (v1: random starter at Foundation; see
below): server, the Self card's read-only Method row, the reward feed entry and
the admin `method` chips. Switching between owned methods happens seated, in
the meditation menu's Method tile (built; see [meditation](meditation.md)). The spirit root is built on the server (`src/shared/Roots.luau`,
`src/server/Roots.luau`, `Pacing.Roots`). Still to do for it: the Testing Stone
in the hub and the Marrow Washing Pill. The reveal card and the first
character window (Self card) are built (`RootReveal`, `SelfCard`). Everything else here is design: build it one layer
at a time, in the order of "Unlock timeline".

## Purpose
Give every player things that make *their* cultivator theirs: a nature they are
born with, a way they cultivate, and powers they find. Each layer adds one new
idea when the player is ready for it, never several at once.

## Design intent

### Who it is for
Kids as much as cultivation readers. Every layer must make sense from its card
alone: a name, an icon, a grade colour and **one line** saying what it does.
Xianxia flavour goes in names and elder lines, never in rules the player has
to learn.

### Rules every layer follows
1. **One question per layer.** No two layers may both mean "a bit more damage".
   - Realm: how strong am I?
   - Weapon and Dao ([weapons](weapons.md)): how do I fight, and how good am I with it?
   - Spirit root: what is my element?
   - Cultivation method: how fast do I cultivate, and how far can I go?
   - Bloodline: what special power does my body have?
2. **One new idea per session.** A layer unlocks with an elder line and a pulse,
   and nothing else unlocks in the same sitting.
3. **One quality language.** Roots, methods and bloodlines use the weapon
   grades and colours (Mortal grey, Spirit blue, Earth gold, Heaven purple,
   `Weapons.Grades`). Players learn the colours once and read them everywhere.
4. **One synergy rule: matching elements help.** A root, a method, a combat
   technique and a bloodline can each have an element; matching ones get a bonus.
   This is the only cross-layer rule, and the cards say it ("Matches your root!").
5. **No bad rolls that stick.** Anything random at the start can be improved
   through play.
6. **No dead choices.** Every element and every option does something from day one.
7. **Mobile first.** Card lists, never stat grids; exact numbers sit behind a tap.

### Names
Combat skills are already called **techniques** (`Techniques.luau`). To avoid
two "techniques", the cultivation kind is called a **cultivation method** in
game and in code (`Methods`).

## Unlock timeline

| When | Layer | How the player meets it |
|---|---|---|
| Start | Weapon (Fist / Iron Jian) | starting kit; already built |
| After the first breakthrough (QC2) | **Spirit root** | new onboarding beat: touch the Testing Stone |
| First second-class weapon / manual | Dao paths | already built (Inventory > Weapons tab) |
| Reaching Foundation Establishment | **Cultivation method** | the elder: "the sect's breathing method can take you no further"; pick one at the sect library |
| First bloodline essence found (FE+) | **Bloodline** | an essence drops (sealed relic, boss, event); intake ritual while meditating |
| Later | treasures, spirit beast, ... | see "Later layers" |

At about ten hours (FE) a player knows four ideas: realm, weapon/Dao, root and
method. Bloodlines are the first thing past that.

## Spirit root

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
auras ([auras.md](auras.md)): Fire a heart beating twice and a crown of flame
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
- Raised by the **Marrow Washing Pill** (built: Legendary, `Items.luau`; 5% from
  the Elder Wolf King, and a rare heavenly treasure). Later also alchemy and the
  Auspicious Clouds relic. It is a long-term goal, not a gate.

**Rerolls (built, decided 2026-10-21): earned, never sold.** The **Root Rebirth
Pill** (Epic; 8% from the Elder Wolf King, and a rare heavenly treasure)
reforms the root as a different element (`Roots.reroll`, rolled with the usual
odds). The new element waits in `data.root.pending` and the player chooses:
keep it, or return to the old one (`Roots.choose`, `CultivationAction("root",
keepNew)`). **Each element keeps its own grade** (decided 2026-10-21): one
you've never held starts at Spirit, and one you held before comes back at the
grade it reached (`Roots.switch` saves the old element's grade in
`root.grades`; `Roots.gradeOf`). Marrow Washing raises only the current element.
The pending row shows the new element's own grade. So a reroll trades grade for
element; returning costs nothing, so it can never leave you worse off
(principle 5), and it isn't gacha: no Robux, and you can always say no.
Both pills are absorbed seated in meditation (`Inventory.use`, item uses
`rootGrade` / `rootReroll`), from the meditation menu's Spirit Root page.

**Data:** `data.root = { element: string, grade: string, pending: string, grades: { [element]: grade } }` (schema v6; `pending` and `grades` filled by default); `""`
element = not yet tested; `grade` is the current element's, `grades` the others'
(saves from before 2026-10-21 have none recorded, so earlier elements read as Spirit). Tuning in `Pacing.Roots`. Pushed in `PlayerState`
(`root`); published as player attributes `Root` and `RootGrade` for others'
nameplates and effects. Admin panel: "Spirit root" (reroll, set, untest,
raise grade). Analytics: event `RootTested` with the element.

## Cultivation method

**What it is:** how you cultivate. Until FE everyone uses the sect's unnamed
basic breathing method; it is only named when it stops being enough.

**Meeting it (built v1, 2026-10-21):** on reaching Foundation Establishment
(the breakthrough, or on joining for players already there) the elder gives you
a **random starter method** for your root (`Methods.giveStarter`): one of five,
one per basic element, plus the rare root's own for rare roots. No choice
screen. Better methods are **earned, not handed out**: Elder Qingyun's task and
exploring (caches with a `Method` attribute work today; ruins, bosses, events
to do). The switch UI is the meditation menu's Method tile. **Still to do:** the elder's task in
the quest line, method caches placed on the map.

**The breakthrough message must never mislead (decided 2026-10-21).** When a full
bar can't break through because the active method's `reaches` is the next stage's
limit, say so and point the way: "Your method can take you no further. Elder
Qingyun may have a task for you, or seek a stronger method out in the world."
Only when there is truly no next stage in the game does it say "You stand at the
peak of this world's cultivation, for now." Built in `Cultivation.breakthrough`,
the full-bar toast (`warning`) and the quest board ("Seek a stronger method").
Today FE1 is the real top, so the peak line shows there; Sect Breathing reaches
FE1 and starters FE9, so the method line first appears when FE2 exists.

**What a method does (three lines on its card):**
1. **Qi speed:** a multiplier on gathering, refining and passive cultivation.
2. **Reaches:** the highest realm it can take you to. This becomes the gate for
   later majors (e.g. a Spirit-grade method reaches Core Formation, an Earth one
   Nascent Soul). FE1 is the top realm today, so this line only matters once
   later stages exist.
3. **Aura (built 2026-10-21; per-method rebuild the same day):** a visual
   around you while seated (meditating or circulating), seen by everyone:
   `src/client/MethodAura.luau`, keyed on the player attributes `Meditating`
   and `Method`; templates `ReplicatedStorage.Effects.MethodAura.<MethodId>`
   (builder `tools/vfx_specs/MethodAura.luau`, preview
   `tools/aura_preview.luau`). **Every method has its own aura** (decided
   2026-10-21: the old shared tinted template read as the same ring in
   different colours; the user: "there will be different cultivation
   techniques so obviously the grade of their vfx should be way different").
   Each is built from its method's idea and lives on the body first: Blazing
   Heart a beating chest core with flames off the limbs, Flowing Spring a
   still pool and droplets drawn to a belly core, Evergreen Root meridian
   branches growing out along the limbs, Iron Marrow a gold gem between the
   hands that clangs each exhale, Mountain Breath a carved rune stone ring
   that settles with the breath, Thunder Pulse a darkened body with cracks
   and arcs in irregular bursts, Drifting Cloud a cloud seat with wind drawn
   in on the inhale, Frost Lotus a glass lotus opening a ring per breath.
   Sect Breathing has only a faint mote on the breath. Sitting down, switching
   method and breaking through play the method's ignition surge first. Drawn
   within 140 studs for the 8 nearest (named methods first). Grade sets how
   grand it is (`GRADES` in MethodAura scales reach today; Spirit and up get
   their own pieces later). The per-method brief, what's built, the grade
   scale and the recipe for inventing new methods are in
   [auras.md](auras.md) (refs in `docs/reference/auras/`).

- A method matching your root gets a qi-speed bonus (the synergy rule).
- Better methods come from bosses, world events, caches and later realms' libraries.
- **Switching is free** while meditating, between methods you own. There is no
  lost progress, so trying one out is never a mistake.

**Data:** `data.methods = { owned: { [id]: true }, active: string }` (active
`""` = Sect Breathing, owned never lists it), player attribute `Method`, in the
`PlayerState` push as `methods`. Switch: `CultivationAction("method", id)`
(`Methods.switch`, while meditating). Effect `"method"` (id, becameActive) when
one is gained. Admin `method <id>` (no id resets). Server
`src/server/Methods.luau`; defs in
`src/shared/Methods.luau` (id, name, element, grade, qi multiplier, reaches,
aura). Tuning in `Pacing.Methods`.

## Bloodline

**What it is:** a special power in your body, awakened from a found essence.
For kids, bloodlines are mythical creatures; the classic special bodies are rare
bloodlines in the same slot, so there is **one slot and one idea**:

- Beasts: Azure Dragon, Vermilion Phoenix, White Tiger, Black Tortoise, Qilin.
- Rare bodies: Pure Yang Body, Pure Yin Body, Heavenly Demon Body.

**Finding and intake:** an essence is an item (`Items`) that drops from the
Auspicious Clouds relic, bosses or rare events. Using it while meditating starts
a short **awakening trial**: a circulation-minigame variant, or surviving a
wave of the creature's echoes. Passing it awakens the bloodline. Failing costs
time, never the essence (the same rule as the tribulation).

**What it gives:**
- **One bloodline skill**, an extra hotbar ability with a long cooldown that
  feels big (Dragon roar knockback, Phoenix flame dash with self-revive at
  higher stages, Tortoise shell). Exactly one, so the hotbar doesn't bloat.
- **One passive** in that creature's theme.
- **A visible mark:** eye glow, a faint aura, a tattoo-like marking.
- **Awakening stages (1-3):** more essences of the same bloodline strengthen
  it. Duplicates are never wasted.

**Swapping:** taking in a different essence replaces your bloodline, with a
confirmation. You keep the old one's stage if you ever return to it.

**Data:** `data.bloodline = { id: string, stages: { [id]: number } }`.

## Character window

**Where weapons live:** weapons and Dao comprehension are in the Inventory's
Weapons tab (f10a380). The character window does not list weapons; it shows
only the equipped class's Weapon Dao row (level, XP, what it gives).

**The reveal card** (`src/client/RootReveal.luau`, `Hud.RootReveal`): on the
local player's first test (Effect "root" with `first`), a small centre card: the
element's seal (`art/ui/draw_icons.py`, `icon_Root<Element>`) on rays in its
colour, "Spirit Root", the element's name, the grade in its colour and the
one-line perk. Rare roots add a gold ring round the seal and a "RARE!" tag. A tap
closes it after a beat, or it closes itself after 6 s. A repeat test shows no card
(the server toasts).

**Opening it:** the **Self tile** in the top-right row (`Hud.Buttons.SelfButton`,
between Cultivate and Inventory; a bust with a topknot, `art/ui/draw_ui.py`
`self_icon`). It is hidden until the root is tested; when the reveal card closes
it pops in, swells once and wears a small seal dot until the window is first
opened (not saved across sessions). Its close seal shuts the card (the
top-right tiles fade away while any window is open). Tapping the **realm
crest** in the vitals (`Crest.Open`) is a shortcut to the same card, with no dot of
its own. The elder pointing at it is still to do.

**Built (v2, `src/client/SelfCard.luau`, `Hud.SelfCard`):** one card (at most
380 px wide, grows to fit) with the realm name, its stage bar (cultivation toward
the next stage), then the Self page, a scrolling list of rows that all share one
shape. **Decided 2026-10-21** (the user found the old rows unclear: "Iron Marrow
Art is a what?", a truncated weapon name read as a technique, "Guandao Dao 0"):
each row is labelled by kind in small gold capitals, then names the thing, then
shows only its effects, one line each, gains in jade and losses in a muted red,
with the numbers taken from the shared defs. No flavour text, no techniques, no
weapon names.
- **Spirit Root** (10): "Metal Root", grade on the right; the perk at this grade
  (`Pacing.Roots.PERKS` x grade), "+15% Metal technique damage"
  (`Pacing.Roots.MATCH`), and the grade's cultivation speed (`Roots.speed`).
  **12-19** stay free for root actions (a Reroll button, a stored-roots strip).
- **Cultivation Method** (20, from Foundation; hidden on Sect Breathing): name and
  grade in its grade colour; "+20% cultivation speed (matches your root)"
  (`Methods.speed`) and "Takes you up to the end of Foundation" (`reaches`, the
  one limit that matters to the player). Read-only; switching is in the
  meditation menu.
- **Weapon Dao** (30): the equipped class's Dao ("Guandao Dao"), "Level 0" on
  the right, an XP bar ("12 / 30 Dao XP", or "Mastered"), the weapon damage it
  gives now (`Weapons.daoMultiplier`, e.g. "-20% weapon damage" below the
  neutral level) and at the next level.

The list grows up to what fits on screen (`LIST_MARGIN` from the top and
bottom) and then scrolls; later systems such as bloodlines add rows of the same
shape (none built yet). Tabs go between the stage bar and `Body.Pages` (each tab
a page frame in `Pages`).

**It grows with the player:**

| Stage | What the window shows |
|---|---|
| Before the root reveal | the crest isn't tappable yet |
| After the root reveal | one card, **Self**: realm, stage bar, Spirit Root row (element, grade, effects), Weapon Dao row (level, XP, damage). No tabs. |
| FE (method) | Self gains a **Cultivation Method** row (built): element seal, name and grade in its grade colour, cultivation speed (with the root match) and how far it takes you. Read-only; switching is in the meditation menu (built). Hidden while on Sect Breathing. |
| First bloodline | tabs appear: **Self** \| **Body** (bloodline card, stage pips, skill, passive) |
| Later layers | at most four tabs |

Each tab shows icon seals plus a short label. A new section gets a dot on the
crest until it has been opened. Exact numbers (multipliers, odds) appear only
when you tap a card.

The window is built by the `ui-designer` agent (AGENTS.md) and follows the
one-window rule in `Menus` (see [ui](ui.md)).

## Realm milestones: each major realm unlocks a new verb

Stats alone make a breakthrough feel like a bigger number. Each **major** realm
should also unlock one new thing you can *do*, announced at the breakthrough
card and taught by the elder. This keeps the "one new idea per session" rule:
majors are spaced hours apart. It also makes the realm ladder the backbone that
the other layers hang off, which is much easier for kids to follow than separate
unlock rules per system.

| Major realm | New verb | Layer it opens |
|---|---|---|
| Qi Condensation | fight, cultivate, travel by array | weapon, spirit root |
| Foundation Establishment | given a random cultivation method; find better ones | method (aura) |
| Core Formation | **ride a flying sword** (traversal between peaks, then zones) | method grade gates it |
| Nascent Soul | **your soul awakens**: an inner world opens, and in it you can raise a **soul companion** (the spirit beast, summoned to fight beside you) and grow your **Dao tree** | companion, Dao tree |
| Soul Transformation / Spirit Severing | **fly without a sword** | - |
| Beyond (Void, Immortal) | **split space**: open a rift to any place you've been, or a short-range blink in combat | - |

Notes:
- **Dao tree (Nascent Soul+).** The late-game home for Dao insights
  (comprehended from places, weather, events and weapon Dao mastery). Each
  insight grows a branch that gives a small passive. It's shown as a tree in your
  inner world, not a menu grid, so it reads as "my soul is growing". It replaces
  the meridian idea below as the deep build layer, and it appears so late that
  only invested players meet it.
- **Soul companion.** A pet is a strong kid hook, so a *cosmetic* spirit beast
  could follow you much earlier (eggs, hatching). At Nascent Soul it bonds with
  your soul and becomes summonable in combat. That way kids get the pet early,
  and the power comes with the realm.
- **Bloodline** sits outside the ladder: it's found, not reached, so it works as
  a surprise reward at any realm past FE.
- Flight needs map support (zone bounds, streaming, anti-exploit speed checks)
  and its own doc before it's built.

## Later layers (ideas, ranked)

These are not committed. Each still needs its own "one question" and slot in
the timeline before it is built.

1. **Cosmetic spirit beast (early).** A pet hatched from an egg that follows you.
   This is the strongest kid appeal of anything here, and it monetizes naturally
   (eggs, skins). It becomes the soul companion at Nascent Soul (see above).
2. **Treasures.** One equipped treasure (jade pendant, bell, mirror) with one
   effect each. The flying sword is the first treasure, at Core Formation.
3. **Daos (many, slow, mostly home perks).** Direction from 2026-10-21, timing
   still open. A player can walk **several Daos** (Fire, Water, Wood, Metal,
   Earth, Lightning, Wind...), but even **stepping onto a path takes a long
   time**, and most players won't master most of them. Progress comes from
   meditating at special places or during weather and events ("comprehended
   the Dao of Thunder in a storm"), never from a menu. Stages per Dao, e.g.
   Glimpse -> Stepped onto the path -> Small accomplishment -> Mastery.
   Perks lean on **life at home**, not combat numbers, so they don't fight the
   combat balance: Wood grows herbs faster (gardening), Water refines more
   cleanly, a Dao of Clarity makes comprehension cheaper. They also point at the
   later crafting: Fire for alchemy, Metal for mining and weapon refinement
   ([core loop](../core-loop.md)). Keep each perk one line and small, and keep
   qi-speed perks out (they bend Pacing). They become the Dao tree's branches at
   Nascent Soul.
4. **Titles.** Earned from feats and shown on the nameplate, cosmetic with at most
   a tiny bonus. Cheap to build, and kids like collecting them.
5. **Meridians.** Dropped in favour of the Dao tree; one deep build layer is enough.

## Open questions
- The sect library needs a place in the hub (`map-builder`). The Testing Stone
  (`Hub.TestingStone`) and the root pillar (`RootFX`) are built.
- Should root grade raise the realm ceiling too, or stay a speed bonus only?
  Recommendation: speed only, so the method is the single gate.
