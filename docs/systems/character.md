# Character: roots, methods, bloodlines and the character window

**Status:** the spirit root is built on the server (`src/shared/Roots.luau`,
`src/server/Roots.luau`, `Pacing.Roots`). Still to do for it: the Testing Stone
in the hub, the reveal pillar vfx, the reveal card and character window UI,
and the Marrow Washing Pill. Everything else here is design: build it one layer
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
- Raised by rare items: a **Marrow Washing Pill** (alchemy/garden or boss drop)
  and the Auspicious Clouds sealed relic. It is a long-term goal, not a gate.

**Rerolls:** none at launch. A paid reroll turns the root into gacha; decide
deliberately later (see [monetization](monetization.md)).

**Data:** `data.root = { element: string, grade: string }` (schema v6); `""`
element = not yet tested. Tuning in `Pacing.Roots`. Pushed in `PlayerState`
(`root`); published as player attributes `Root` and `RootGrade` for others'
nameplates and effects. Admin panel: "Spirit root" (reroll, set, untest,
raise grade). Analytics: event `RootTested` with the element.

## Cultivation method

**What it is:** how you cultivate. Until FE everyone uses the sect's unnamed
basic breathing method; it is only named when it stops being enough.

**Meeting it:** on reaching Foundation Establishment the elder says the basic
method can take you no further, and points you to the **sect library**. There
you **choose one of five** starter methods, one per basic element. The one
matching your root is listed first and marked "Matches your root!", so a kid
can just take the top one, and anyone else can pick freely. Rare-root players
get a matching sixth option.

**What a method does (three lines on its card):**
1. **Qi speed:** a multiplier on gathering, refining and passive cultivation.
2. **Reaches:** the highest realm it can take you to. This becomes the gate for
   later majors (e.g. a Spirit-grade method reaches Core Formation, an Earth one
   Nascent Soul). FE1 is the top realm today, so this line only matters once
   later stages exist.
3. **Aura:** a visual around you while meditating or circulating (flame lotus,
   water ring, falling leaves...), made by the `vfx` agent. Higher grades can add
   a small effect to it, like healing allies who meditate nearby.

- A method matching your root gets a qi-speed bonus (the synergy rule).
- Better methods come from bosses, world events, caches and later realms' libraries.
- **Switching is free** while meditating, between methods you own. There is no
  lost progress, so trying one out is never a mistake.

**Data:** `data.methods = { owned: { [id]: true }, active: string }`; defs in
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
Weapons tab (f10a380). The character window does not repeat them; it shows the
equipped weapon as a small badge only.

**Opening it:** tap the **realm crest** in the vitals. There is no new top-right
tile (that row is full on phones). The crest pulses, and the elder points at it
once, at the root reveal. If playtests show people don't find it, add a tile then.

**It grows with the player:**

| Stage | What the window shows |
|---|---|
| Before the root reveal | the crest isn't tappable yet |
| After the root reveal | one card, **Self**: realm, stage bar, spirit root (element, grade, perk), weapon badge. No tabs. |
| FE (method) | Self gains a **Method** row: name, grade, the three lines, a "Change" button while meditating |
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
| Foundation Establishment | choose a cultivation method | method (aura) |
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
3. **Dao insights (collection).** Before the Dao tree exists, insights are
   collected by meditating at special places or during weather and events
   ("comprehended the Dao of Thunder in a storm"). Each gives a tiny passive.
   They become the tree's branches at Nascent Soul.
4. **Titles.** Earned from feats and shown on the nameplate, cosmetic with at most
   a tiny bonus. Cheap to build, and kids like collecting them.
5. **Meridians.** Dropped in favour of the Dao tree; one deep build layer is enough.

## Open questions
- The Testing Stone and the sect library need places in the hub
  (`map-builder`), and the root pillar needs a vfx.
- Should root grade raise the realm ceiling too, or stay a speed bonus only?
  Recommendation: speed only, so the method is the single gate.
