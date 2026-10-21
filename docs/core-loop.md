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
| Tribulation | a major breakthrough | surviving the lightning | the main peak | built (QC9) |
| Beasts too strong | dying out there | weapon, technique, Dao, root, herbs, breaking through | both | partly: it's not signposted |
| Method | can't go past Foundation | finding a cultivation method | the library, then exploring (ruins, secret places), bosses | design ([character](systems/character.md)) |
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
| QC5 | RAMP | a new region (Ruined Borderlands); the gather/refine loop sets in |
| QC6 | MINI-WALL | herbs start to matter (the garden pays off) |
| QC7-8 | BREATHER, RAMP | second weapon class, Dao paths (from caches and drops) |
| QC9 | WALL | insight and the first tribulation |
| FE | new realm | cultivation method, Outer Wastes |
| later majors | | the realm milestones: flying sword, soul companion, flight ([character](systems/character.md)) |

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
6. **Content stops at FE1.** The long goal needs the next realm before more
   side systems.

## Rules for anything new
1. Name its **arrow** into the loop (table above).
2. Name the **wall it creates or the reward it gives**.
3. Name **when it's introduced**, and keep that to one new idea at a time.
4. Keep it **mobile-sized** and kid-readable (one line per effect).
