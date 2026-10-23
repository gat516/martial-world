# Character: roots, methods, bloodlines and the character window

**Status:** cultivation methods are built (v1: random starter at Foundation; see
below): server, the Self card's read-only Method row, the reward feed entry and
the admin `method` chips. Switching between owned methods happens seated, in
the meditation menu's Method tile (built; see [meditation](meditation.md)). The spirit root is built on the server (`src/shared/Roots.luau`,
`src/server/Roots.luau`, `Pacing.Roots`). Still to do for it: the Testing Stone
in the hub and the Marrow Washing Pill. The reveal card and the first
character window (Self card) are built (`RootReveal`, `SelfCard`). Everything else here is design: build it one layer
at a time, in the order of "Unlock timeline" below.

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
| First second-class weapon / manual | Dao paths | already built (Inventory > Weapons & Arts tab) |
| Reaching Foundation Establishment | **Cultivation method** | the elder: "the sect's breathing method can take you no further"; pick one at the sect library |
| First bloodline essence found (FE+) | **Bloodline** | an essence drops (sealed relic, boss, event); intake ritual while meditating |
| Later | treasures, spirit beast, ... | see [later layers](../character/later-layers.md) |

At about ten hours (FE) a player knows four ideas: realm, weapon/Dao, root and
method. Bloodlines are the first thing past that.

## Layers

| Layer | Status | Doc |
|---|---|---|
| Spirit root | built (Testing Stone, reveal, perks, grade, rerolls) | [spirit root](../character/spirit-root.md) |
| Cultivation method | built v1 (random starter at FE, switching in meditation) | [cultivation method](../character/method.md); auras in [auras](auras.md) |
| Bloodline | design | [bloodline](../character/bloodline.md) |
| Character window | built (Self card v2, root reveal card) | [character window](../character/character-window.md) |
| Realm milestones, later layers | ideas | [later layers](../character/later-layers.md) |
| Player accessories (race cosmetics) | pipeline and rules | [player accessories](../character/player-accessories.md) |

## Open questions
- The sect library needs a place in the hub (`map-builder`). The Testing Stone
  (`Hub.TestingStone`) and the root pillar (`RootFX`) are built.
- Should root grade raise the realm ceiling too, or stay a speed bonus only?
  Recommendation: speed only, so the method is the single gate.
