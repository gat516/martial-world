# Progression: Qi Condensation to Foundation Establishment 9

The stage-by-stage plan for the whole current game. [core-loop.md](core-loop.md) is
the north star; this page is how it plays out over about 16 hours. Numbers live
in `src/shared/Pacing.luau`; this page is the design they are tuned against.
Decided 2026-10-22 in conversation; stage assignments and targets are proposals
until playtested. Nothing here is built yet unless it says so.

## Decisions (user, 2026-10-22)
- **Qi Refining (QR1-9)** sits between Qi Condensation and Foundation
  Establishment. The ladder is 27 stages: QC1-9, QR1-9, FE1-9. FE9 is the cap
  for now, with a "Core Formation awaits" teaser.
- **Tribulations are for the heaven-defying only.** A normal player never sees
  one. A player with a heaven-defying bloodline or spirit root faces a
  tribulation at every major breakthrough (QC9->QR1, QR9->FE1, and later ones).
  See "Tribulations".
- **Nobody is barred by skill, least of all on mobile.** Bosses are optional
  (faster, not required), difficulty is pure skill with no modes, and no
  tribulation or minigame is the only road forward. See "Difficulty".
- **Content: reuse what exists.** The 13 shipped beasts and 3 bosses are spread
  over the ladder with elite tiers (below); new beasts are not needed to get to FE9.
- **Next system: the sect and its quests** (below).
- **Insight is deleted; walls are the bar (user, 2026-10-23).** A breakthrough
  is graded by what the player experienced that stage (the foundation grade, a
  permanent stat bonus); death spills half of the unbanked haul (a spirit ring keeps some safe); the forced breakthrough
  becomes the qi surge. See [roadmap](roadmap.md) "Phase A". Not built yet: the
  code still gates on insight.
- **Bloodlines, not races.** Cosmetic traits (horns, tails, wings, see-through
  spirits) come with a bloodline. See "Bloodlines".

## Length targets (active play, proposals)
| Major | Stages | Target | Per stage |
|---|---|---|---|
| Qi Condensation | 9 | about 2 h (as built) | 13 min |
| Qi Refining | 9 | about 4 h | 27 min |
| Foundation Establishment | 9 | about 10 h | 67 min |

Bars cannot keep growing 1.6x a stage: from QC9 on, the curve grows about 1.25x
a stage with a step at each major. Time per stage is stretched by quests,
events and exploring (more things to do per stage), not by a bigger grind.
Passive cultivation still never stops. Derive each stage's bar and income from
its target minutes with the formulas in the `Pacing.luau` header.

## The stage template
Every three stages is a **chapter**; every nine is a **realm**.
- **Stage 1 of a chapter:** something new (a region seal, a beast tier, a home
  idea). The "hook" of the chapter.
- **Stage 2:** the loop settles in (breather).
- **Stage 3:** a mini-wall: the chapter's elite hunt or event chain, a foundation experience.
- **Stage 9 of a realm:** the wall: the biggest bar, the realm's experiences, an
  optional realm boss as the fast road to a Deep foundation. Heaven-defying players add the tribulation.

One new idea per chapter, never per stage, and never two at once.

## Regions
The map isn't done, so these are logical regions; the map-builder fits them later.
| Region | Stages | Seal opens at | Beasts (tier) | Boss |
|---|---|---|---|---|
| Inner Wilds | QC1-4 | QC1 | Spirit Wolf, Venom Serpent, Stone Boar | Elder Wolf King (QC9 boss, met here early as a sign, not a fight) |
| Ruined Borderlands | QC5-9 | QC5 | Stone Tortoise, Shadow Mane Wolf, Blood Centipede, Flame Raven, Blood Bat, Blood-Fed Hound | Jade Jiao (QC7), Elder Wolf King (QC9) |
| Outer Wastes | QR1-5 | QR1 | elite tier of the Borderlands set | Thunder Ape (QR5, re-tiered) |
| Deep Wilds | QR6-9, FE1-3 | QR6 | elite tier of all, Ember-Scale Pangolin | Nine-Tailed Fox (QR9, re-tiered) |
| The Far Reaches | FE4-9 | FE1 or FE4 (open) | apex tier of all | Elder Wolf King, Jade Jiao, Thunder Ape, Nine-Tailed Fox as event bosses |

**Elite and apex tiers** are the cheap way to fill 18 stages: the same body with
a tint, an aura tier and one extra move per tier (`vfx` and `animator` do a short
pass per beast, not a rebuild), higher `realm`, a new first-kill experience. A
beast re-tiered by realm keeps its identity, so the player reads "the same
wolf, but older".

## The ladder, stage by stage
`Wall` is what sends you out or home. `New` is the one idea of the chapter.

### Qi Condensation (built; the hook)
| Stage | Beat | Region | New | Wall |
|---|---|---|---|---|
| QC1 | HOOK | Inner Wilds | circulate, breakthrough | empty dantian |
| QC2 | HOOK | Inner Wilds | spirit root, travel out, first hunt | empty dantian |
| QC3 | HOOK | Inner Wilds | technique, refine | the tutorial ends |
| QC4 | BREATHER | Inner Wilds | **home grows:** garden and peak | none |
| QC5 | RAMP | Ruined Borderlands | **the sect board:** daily tasks, contribution, Outer Disciple rank | full dantian |
| QC6 | MINI-WALL | Borderlands | herbs matter (tier I herbs eaten for qi) | more than a dantian of qi |
| QC7 | BREATHER | Borderlands | second weapon class, Dao drills; Jade Jiao | beasts too strong |
| QC8 | RAMP | Borderlands | rumours of ruins; the first secret place | foundation (soft) |
| QC9 | WALL | Borderlands | the realm boss is optional (a Boss experience); the quiet breakthrough ceremony | bar |

### Qi Refining (new; the sect and the home deepen)
Rank becomes **Inner Disciple** at QR1.
| Stage | Beat | Region | New | Wall |
|---|---|---|---|---|
| QR1 | HOOK | Outer Wastes | Qi Refining; the wastes; chapter quests | region seal |
| QR2 | BREATHER | Wastes | weekly sect tasks | none |
| QR3 | MINI-WALL | Wastes | tier II herbs and the Herbarium; the Herbalist's second shelf (alchemy is a later update) | herbs |
| QR4 | RAMP | Wastes | seclusion: deliberate closed-door cultivation | full dantian |
| QR5 | BREATHER | Wastes | Thunder Ape event and boss | beasts too strong |
| QR6 | MINI-WALL | Deep Wilds | Dao glimpses at special places (storms, springs) | region seal |
| QR7 | RAMP | Deep Wilds | sect trials: a rank test with a tiny reward | foundation (soft) |
| QR8 | BREATHER | Deep Wilds | the first secret-realm rift (weapon refinement is a later update) | none |
| QR9 | WALL | Deep Wilds | optional realm boss (Nine-Tailed Fox); a heart-demon trial is offered | bar |

### Foundation Establishment (new content, 10 hours)
Rank **Core Disciple** at FE1. FE1 gives the cultivation method (as designed in
[character](systems/character.md)).
| Stage | Beat | New | Wall |
|---|---|---|---|
| FE1 | HOOK | **cultivation method:** the sect library; Far Reaches seal | method |
| FE2 | BREATHER | method upgrades from exploring | none |
| FE3 | MINI-WALL | tier III herbs; the Pavilion's second shelf | herbs |
| FE4 | RAMP | **treasure slot:** one equipped treasure | foundation (soft) |
| FE5 | BREATHER | secret realms: timed rifts with manuals | none |
| FE6 | MINI-WALL | **spirit beast egg:** a cosmetic pet that follows you | beasts too strong |
| FE7 | RAMP | tier IV herbs; Dao tree preview | full dantian |
| FE8 | BREATHER | the Far Reaches' handcrafted secret realm (mining and ores are a later update) | none |
| FE9 | WALL | the cap: optional apex boss gauntlet (the four bosses); the flying sword shown, not given | bar |

## Home, herbs and the loop (the missing link)
The garden dies at QC6 because herb qi is flat. Fix:
- **Herb tiers, by region.** I Common (QC), II Spirit (QR1-5), III Rare (QR6-FE3),
  IV Treasure (FE4-8), V Heavenly (FE9+). Eating a herb gives a fixed **share of
  the current dantian** by tier (about 6, 9, 12, 16, 20 percent), so a herb always
  matters but never replaces hunting.
- **Seeds come from the region.** Beasts drop their region's seeds, so going out
  feeds the garden; the garden saves trips. Sect errands ask for herbs (home
  turns into quests).
- **Peak and garden tiers** gate plots and soil. The peak levels with contribution
  and realm, not stones alone.
- **Alchemy is a later update (user, 2026-10-22).** No furnace, crafted pills or
  breakthrough-aid pills for now. Herbs are eaten directly (qi and timed buffs), and
  pills, cores and elixirs stay loot and shop finds (the Root Pill and Marrow Washing
  Pill already work that way). Foundation repair comes from meditation, seclusion and
  tending the garden instead. See [roadmap](roadmap.md) "Deferred to a later update".
- **Cultivating at home stays calm and always progresses.** Meditation and peak
  bonuses keep scaling through Pacing; nothing here asks for skill.

## The sect and its quests
The sect is what sends you out and welcomes you home. It uses the existing
quest defs (`Quests.Quest`, `data.quests`).
- **Ranks:** Outer Disciple (QC1), Inner Disciple (QR1), Core Disciple (FE1).
  Promotion needs realm and contribution, so rank is not just a realm label.
- **The board** (introduced at QC5): the current wall first, then at most two
  other goals.
  - **Dailies:** three offered, one to three taken; hunt, herb errand, gather,
    event call. Pays contribution and some stones.
  - **Weeklies:** one large goal per week.
  - **Chapter chains:** story per region, ending at its boss or secret place.
  - **Bounties:** a named elite or boss, repeatable.
  - **Sect tasks:** tend the sect garden, escort, deliver herbs.
- **Contribution points** buy from the Pavilion: technique manual copies, pills,
  seeds, weapons, cosmetics. Weekly cap, so it can't inflate. **Never qi**; qi
  stays with Pacing.
- **Givers:** the elder, the board, and people around the sect; rumours point
  out into the world ("a cultivator's cave lies past the ruined bridge").

## Tribulations (heaven-defying only)
Normal players break through with a bar and a quiet ceremony.
A weak foundation grade makes the tribulation harder, never impossible.
- **Who:** a player whose bloodline or spirit root is flagged `heavenDefying`.
  They face a tribulation at **every major** breakthrough.
- **Why:** the heavens won't suffer them to exist. Lines are written per cause
  and picked at random, for example:
  - "The heavens do not allow a body like yours to exist."
  - "Dragon blood in a mortal vessel. Heaven moves to correct the error."
  - "Your root was never meant to be. The Dao denies you."
  - "A flaw in the world, and heaven means to mend it."
  - "You steal what is heaven's alone. It will take it back."
- **Variants** by cause (Dragon: gold lightning; Demon: black fire and mind-demon;
  Pure Yang: flame; Phoenix: rebirth flames). They change the look and reward,
  not whether you can pass.
- **Accessible:** generous telegraphs, a visible safe zone, a damage floor so a
  fumbled strike does not kill, no aim or reflex gate. **Preparation can replace
  skill:** protective charms and herbs, found or bought, let anyone pass (crafted talismans are a later update).
- **Spectacle:** a tribulation is visible server-wide and the sky shows it. It is
  a world event: others can watch it and are warned off the platform.
- **VFX:** the current tribulation is lacklustre; a `world-fx` pass (storm
  cloud, bolts, the heaven's eye, aftermath) is needed. Not started.
- **Failing** costs the existing cooldown, never cultivation.

## Bloodlines
Replaces races. See [character](systems/character.md) for the base design.
- **Taken or absorbed.** Found as essences or fruit-like items (bosses, events,
  secret places) or bought. Rare heaven-defying ones are never sold outright.
- **Cosmetic traits** come with the bloodline: demon horns and tails, wings
  (feathered, bat), see-through spirits, elemental effects. Variants within a
  family.
- **One bloodline skill and one passive** each; stages from duplicates.
- **Bought bloodlines are cosmetic plus a small perk** and do not skip any gate.
- **The demon path (open scope).** Taking a demon bloodline gets you expelled
  from the sect: no board, no library, no Pavilion. You cultivate by killing, on a
  bounty board of your own. Default: a variant on the same loop first (kills pay
  more, passive pays less); a full separate loop is later.

## Difficulty: bosses are optional
No difficulty modes, no damage or reward scaling (user, 2026-10-22: difficulty
stays pure skill). Instead, **nothing in the progression requires beating a
boss**, so a player who can't (a phone player, a peaceful one) is never stuck.
- **Bosses are optional.** They exist for worldbuilding and as quest targets
  ("slay the Elder Wolf King"). Killing one is a **faster road**: a big qi payout, a
  Boss experience (counts double toward the foundation grade), a manual or weapon, a bounty reward. Skipping one only costs time.
- **Two ways to climb, both complete:**
  - *The fighter:* hunt, bounties, bosses and events. Fast, with surprises.
  - *The gardener:* meditate, tend the spirit garden, run sect
    errands and chapter quests that need no combat. Slower, always sure.
  Pacing is tuned so the gardener's road reaches every wall, just later.
- **Every wall has a non-combat road.** A wall is the bar, never a boss. The
  foundation grade, the thing a boss speeds up, also comes from harvests, Dao
  milestones, secret places (explored, not fought), events and quests. First kills
  and bosses are *one* source, and a low grade never blocks a breakthrough.
- **Quests offer the fight, they don't demand it.** A bounty to slay a boss
  pays well; the same chain has a peaceful sibling (a herb errand, an exploring task).
- **Enemy difficulty stays what the designers set**, tuned per realm in
  `Pacing`. Fights can be hard; skipping them is always allowed.
- **Dying costs a little, never a stage.** A death spills about half of the haul
  you haven't banked, recoverable where you fell for a few minutes (Phase A), so
  trying stays cheap.
- Open: how big the gardener's slowdown is (a proposal: 1.5-2x the fighter's
  time), and whether to hint the peaceful road when a player keeps dying.

## World events
The event look pass (`docs/vfx/world_events.md`) resumes with Heaven Split,
Beast Surge and the new events. Plan:
- **Tiers by realm band**, with event grounds in every region; prizes scale with
  the band.
- **Existing:** Thousand-Year Ginseng, Beast Surge, Auspicious Clouds, Violet
  Cloud Mist, Golden Auspicious Clouds.
- **New (proposed):**
  - *Secret Realm Rift:* a timed rift to a small zone with manuals and Discover experiences.
  - *Roaming Beast King:* a boss (the four existing ones, re-tiered) walks the
    wilds, announced server-wide.
  - *Dao Rain:* a storm that gives comprehension progress to those who sit in it.
  - *Spirit Vein Eruption:* a qi surge at a node; qi for those who gather.
  - *Falling Star:* ore for the later crafting.
  - *Heaven-Defier's Tribulation:* another player's tribulation as a sky spectacle.
- Each new event needs a name, a trigger (weather and realm band), a prize and a
  `world-fx` look; `vfx` handles hits and casts.

## Known gaps and next steps
Built 2026-10-22: QR1-9 and FE2-9 rows in `Pacing.Curve` (and combat qi), the
`QiRefining` major in `Realms`, `data.heavenDefying` and the tribulation gate.

Still open from that pass:
- **Insight is still in the code** (QC9 5 up to FE6 13, and above 10 is
  unreachable without bosses). Phase A deletes it.
- **Nothing sets `heavenDefying`** yet (bloodline or root).
- **Region seals unchanged:** `Regions.luau` still seals the Outer region at FE1; the
  QR regions need the map.
- **Thunder Ape and Nine-Tailed Fox** are tuned for the old FE1 player (500 HP,
  power 3.0), which is now about QR5-6. Move their `realm` there, or lift their
  stats, once playtested.
- **Cultivator enemies** exist but aren't wired. They suit the QR and FE stages as
  human opponents and sect-quest targets.
- Curve numbers are untuned (see the table in `Pacing.luau`).

Steps:
1. ~~Pacing rows, `QiRefining`, the tribulation flag~~ (done, untuned).
2. Scale herb `eat` qi by tier; add the tier field to `Herbs.luau`.
3. Build the sect: ranks, contribution, board, Pavilion, dailies and chains.
4. Phase A: foundation grades, the haul and spirit ring, the qi surge, insight deleted ([roadmap](roadmap.md)); turn bosses into quest targets.
5. Build the bloodline layer earlier than FE (see [character](systems/character.md)).
6. World-event and tribulation vfx passes (`world-fx`).
7. Elite and apex beast tiers: `enemy-designer`, `vfx` and `animator`, one per beast.
8. Fit the regions to the map.
