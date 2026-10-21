# Character: roots, methods, bloodlines and the character window

**Status: design, nothing built yet.** This is the plan for how a player's
character grows beyond realm and weapons. Build it one layer at a time, in the
order of "Unlock timeline".

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

**The reveal:** a new onboarding beat, `Root`, right after `Breakthrough`. The
elder sends you to the **Testing Stone** in the hub. You touch it, a pillar of
your element's colour rises (vfx), your root's name and one-line perk appear,
and the elder reacts (more excited for a rare root). It needs no decisions.
Players already past the beat get "Have your root tested" as a quest-board goal.

**Element (rolled):**

| Element | Odds | Perk (one line on the card) | Matching techniques today |
|---|---|---|---|
| Fire | 18% | Your techniques hit harder | Fire Seal |
| Water | 18% | You heal faster out of combat | - |
| Wood | 18% | Your herbs grow faster | - |
| Metal | 18% | Your weapon strikes hit harder | Sword Qi Wave, Iron Skin |
| Earth | 18% | You have more health | Palm Strike |
| Lightning (rare) | 4% | You run faster | Lightning Talisman |
| Wind (rare) | 3% | Your dodge recovers faster | - |
| Ice (rare) | 3% | Your hits sometimes slow enemies | - |

- Perks are small (about 5-10%) so no element is "the best".
- **Matching technique:** +15% damage on techniques of your element. This needs
  an `element` field on `Techniques` defs (the "Matching" column is a proposal).
  Water, Wood, Wind and Ice have no technique yet, so their perks carry them
  until they do; they should be first in line when new techniques are made.
- The perks touch systems that already exist (combat, health, regen, garden,
  movement, dodge), so every root does something on day one.

**Grade (grows):** everyone starts at **Spirit** grade (blue). In the lore a
Mortal grade means no root at all, so nobody is told their root is trash.
- Spirit -> Earth -> Heaven raises passive and refining speed (roughly x1.0,
  x1.1, x1.25) and strengthens the element perk.
- Raised by rare items: a **Marrow Washing Pill** (alchemy/garden or boss drop)
  and the Auspicious Clouds sealed relic. It is a long-term goal, not a gate.

**Rerolls:** none at launch. A paid reroll turns the root into gacha; decide
deliberately later (see [monetization](monetization.md)).

**Data:** `data.root = { element: string, grade: string }`; `""` element = not
yet tested. Tuning in `Pacing.Roots` (odds, grade multipliers, perk sizes).
Pushed in `PlayerState`; published as player attribute `Root` for others' nameplates
and effects.

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

## Later layers (ideas, ranked)

These are not committed. Each still needs its own "one question" and slot in
the timeline before it is built.

1. **Spirit beast companion.** A pet hatched from an egg that follows you and
   helps a little (picks up loot, a small assist attack). This is the strongest
   kid appeal of anything here, it monetizes naturally (eggs, cosmetics), and it
   answers its own question: "who travels with me?"
2. **Flying sword / treasures.** One equipped treasure; a flying sword is
   traversal (fly between peaks) at FE or Core Formation. Flying is a huge
   reward moment and fits the map's vertical peaks.
3. **Dao insights.** Small passives earned by meditating at special places or
   during weather and events ("comprehended the Dao of Thunder in a storm").
   This ties the world to the character, and shows as a collection rather than a tree.
4. **Titles.** Earned from feats and shown on the nameplate, cosmetic with at most
   a tiny bonus. Cheap to build, and kids like collecting them.
5. **Meridians.** A node tree on a body outline, opened with insight. It gives
   deep build choice but is the most complex option; build it last, if at all.

## Open questions
- **"Earth" means two things:** the Earth element and the Earth grade. A kid
  will read "Earth root, Earth grade" as the same thing. Options: call the
  element **Stone** (or **Mountain**), or rename the grade.
- The Testing Stone and the sect library need places in the hub
  (`map-builder`), and the root pillar needs a vfx.
- Should root grade raise the realm ceiling too, or stay a speed bonus only?
  Recommendation: speed only, so the method is the single gate.
