# Core loop

The north star. Every system, onboarding beat and reward should fit this page;
if a new idea can't say where it plugs in, it waits. Decided 2026-10-21.

## In one sentence
**Cultivate until you hit a wall, go out and break it, come home stronger.**
Every realm opens a new region and, at the big ones, a new power.

## The rhythm: home and out

```
        +---------------- HOME ----------------+
        |  cultivate: passive, meditate,       |
        |  refine raw qi (minigame)            |
        |  garden, peak, spend stones          |
        +--------------------------------------+
              |  hit a wall          ^  bring back qi, insight,
              v                      |  manuals, weapons, herbs
        +----------------- OUT ----------------+
        |  HUNT: beasts, bosses, qi nodes      |
        |  EXPLORE: caches, ruins, secret      |
        |  places, events; find methods,       |
        |  manuals, weapons, treasures         |
        +--------------------------------------+
                         |
              bar full + walls cleared
                         v
                   BREAK THROUGH
         (stronger; new region; at majors, a new power)
```

Both halves matter. Home is calm and always makes progress (passive
cultivation never stops, online or off). Out is where the action, loot and
surprises are, and it has two verbs:
- **Hunt:** fight for qi and insight. Reliable and repeatable.
- **Explore:** go off the path to find things: technique manuals, cultivation
  methods, weapons, treasures, secret spots to meditate or comprehend a Dao.
  It's uncertain and exciting, and it's where the "what's over there?" pull and
  most of the long-term goals come from. The world caches (ManualCache,
  WeaponRack) are the first piece of this; each new region should add more. Neither is a side game: **home turns what you bring back into
progress, and out is where you get what home is missing.**

The game must always tell the player **which wall they're at and where to go**.
The full stage plan (QC1 to FE9, with Qi Refining, the sect, difficulty modes) is in [progression](progression.md).
The pieces exist (the passive warnings "You must go out and experience the
world" and "You feel as if you need more insight", the objective line, the quest
board), but they don't yet frame it as one rhythm.

## Walls: what sends you out (or home)

| Wall | How it feels | Broken by | Where | State |
|---|---|---|---|---|
| Empty dantian | bar not full, no raw qi to refine | hunting, qi nodes, eating herbs | the wilds, the garden | built |
| Full dantian | carrying lots of raw qi | refining it | home or a qi node | built |
| Insight | full bar, "you need more insight" | first kills of new beasts, the boss, kill milestones | the wilds | built (QC9) |
| Region seal | the next wilds array is sealed | reaching its realm | breaking through | built (QC5, FE1) |
| Tribulation | a major breakthrough, **heaven-defying players only** (bloodline or root; decided 2026-10-22) | surviving or bracing against the lightning; never a skill gate | the main peak | built for everyone at QC9; to be gated behind the flag |
| Beasts too strong | dying out there | weapon, technique, Dao, root, herbs, breaking through | both | partly: it's not signposted |
| Method | can't go past Foundation | finding a cultivation method | the library, then exploring (ruins, secret places), bosses | design ([character](character/method.md)) |
| Missing piece | "a manual / weapon / method is out there" | exploring: caches, ruins, event sites | the wilds | partly: caches built, nothing points to them |

A good stage asks for one or two walls, not all of them. Pacing already does
this (`Pacing.luau`: HOOK, BREATHER, RAMP, MINI-WALL, WALL).

## What a trip out brings back
- **Always:** raw qi. That's the reason to go.
- **Often:** insight (new beasts), Spirit Stones, herbs and seeds.
- **Sometimes, as the surprise that makes trips exciting:** a technique manual,
  a weapon, an event treasure, and later a bloodline essence or a root reroll.

Every trip should get the thing you went for, plus a chance at a surprise.

## Every system's arrow into the loop

| System | Its one arrow |
|---|---|
| Cultivation, refining, breakthroughs | **the loop itself** |
| Wilds, beasts, qi nodes, bosses | **the loop itself** (out: hunt) |
| Caches, ruins, secret places | **the loop itself** (out: explore) for manuals, methods, weapons |
| Meditation | home progress (faster passive) |
| Garden | herbs become qi and buffs (fewer trips) and sell for stones |
| Peak building | meditation and garden bonuses (a better home) |
| Weapons, Dao, techniques | how you fight out there (deal with "beasts too strong") |
| Technique comprehension | spends insight and stones from trips out to break a technique's bottleneck (a new tier) |
| Spirit root | a small perk on home or out, and your element |
| World events, treasures, caches | surprise loot during trips |
| Tribulation | the gate of a major realm |
| Travel | moves you between home and out |

## A player's life, and when each thing is introduced

One new idea at a time. Home and out are both taught in the first ten minutes,
and everything else arrives when it first matters.

| Stage | Beat | Introduced |
|---|---|---|
| QC1-3 | HOOK | the rhythm itself, once: circulate (home) -> break through -> spirit root -> travel out -> hunt -> technique -> refine (home) -> QC3. This is the current onboarding. |
| QC4 | BREATHER | **home deepens:** garden and peak building (proposal; onboarding doesn't teach them today) |
| QC3-5 | | the first technique bottleneck (about 28 casts of one art): comprehension, spending insight and stones. Today only a toast and the Arts pane explain it; the elder should name it once. |
| QC5 | RAMP | a new region (Ruined Borderlands); the gather/refine loop sets in |
| QC6 | MINI-WALL | herbs start to matter (the garden pays off) |
| QC7-8 | BREATHER, RAMP | second weapon class and its Dao level (from caches and drops) |
| QC9 | WALL | insight and the first tribulation |
| FE | new realm | cultivation method, Outer Wastes |
| later majors | | the realm milestones: flying sword, soul companion, flight ([character](character/later-layers.md)) |
| a later update (decided 2026-10-22) | | crafting: mining and ores, weapon refinement, alchemy (see below and [roadmap](roadmap.md)) |

## Don't overwhelm: crafting comes later
Never put many mechanics in front of a player at once. Each one needs its own
moment in the table above, after the ones before it have settled in. Crafting
is the clearest case: it's planned but held back until the core loop, the
wilds and the first realms are solid. Out of scope until we schedule it.

- **Mining and ores:** a new "out" verb. Ore veins in the wilds, deeper regions
  hold rarer ores. It feeds weapon refinement. The model is *The Forge*
  (mine -> smelt -> forge -> better gear) in a cultivation skin.
- **Weapon refinement:** spend ores and Spirit Stones to raise a weapon's grade
  or temper it. This gives duplicate weapons and stones a use.
- **Alchemy:** turn herbs (the garden, the wilds) into pills: breakthrough aids,
  heals, buffs. It is the long-term sink for herbs and stones, and fixes herbs
  falling off at high stages (their flat qi stops mattering).

When one gets scheduled, it passes the "Rules for anything new" below and is
introduced alone, at a breather stage, by the elder or the quest board.

## Why it felt messy (and the fixes)
1. **The rhythm is never named.** Onboarding teaches each step but not "this is
   what you'll do over and over". Fix: the elder names it once at FreePlay, and
   the objective line always says the current wall in loop terms ("Your dantian
   is empty: hunt in the wilds").
2. **Home systems arrive unannounced.** The garden and peak building have no
   moment of their own. Fix: introduce them at QC4 as "your home grows".
3. **Exploring has no voice.** Caches exist but nothing hints at them, so going
   out only means fighting. Fix: each region gets a few discoverable spots, plus
   rumours from the elder and the quest board ("an old cultivator's cave lies
   past the ruined bridge").
4. **Breakthroughs are mostly bigger numbers.** Fix: a new region every few
   stages (already there) plus realm milestones at the majors.
5. **The quest board lists everything at once.** Fix: show the current wall
   first and at most two other goals.
6. **Content stops at FE1.** Planned in [progression](progression.md): Qi Refining
   and FE1-9, filled with elite tiers of the existing beasts, the sect's quests and
   scaled herbs. Not yet built.

## Techniques: many, found, chosen
Many more techniques are planned. Every one is a manual you find out in the
world (caches, ruins, boss pools, events, milestones), never something a tree or
shop hands out, so exploring keeps paying. Insight is deliberately scarce
against them: players comprehend a few favourites, not all. So each new region
must add its own insight sources (its beasts' first kills, event relics, secret
comprehension spots), or mastery slows to a crawl. No weapon perk trees: weapon
Dao stays a level that grows by fighting (decided 2026-10-21, to keep combat
simple).

## Rules for anything new
1. Name its **arrow** into the loop (table above).
2. Name the **wall it creates or the reward it gives**.
3. Name **when it's introduced**, and keep that to one new idea at a time.
4. Keep it **mobile-sized** and kid-readable (one line per effect).
