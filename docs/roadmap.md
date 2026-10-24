# Roadmap: progression, onboarding, techniques, garden, building

The plan for taking the game from "QC1-9 plus a thin Foundation" to a full game
that lasts QC1 to FE9. [progression](progression.md) is the stage ladder and the
sect; [core-loop](core-loop.md) is the north star. This page is **what we build,
in what order, and why**. Written 2026-10-22 from conversation. Proposals unless
marked built; nothing here has been playtested.

## Principles (from the user)
1. **Nobody is barred by skill.** Bosses, tribulations and difficulty never gate
   progress. No difficulty modes with scaling. Mobile players always have a road. (Open against boss tiers and variants: [enemies](systems/enemies.md), Known gaps.)
2. **Two ways to climb, both complete:** the fighter (hunt, bosses, events) and the
   gardener (meditate, garden, seclusion, building, non-combat quests). Fighters are
   faster. Gardeners are never stuck.
3. **You can't skip the world.** Rushing a breakthrough hurts; experiencing the
   world heals and rewards. A soft cost, not a lock.
4. **Story over rules.** Every system reads as cultivation fiction (cracked
   foundation, heart demons, sect rank), not a menu.
5. Every system names its **arrow into the loop** (core-loop rules).
6. **Few mechanics at once (user, 2026-10-23).** Fun for kids and mobile players
   first; depth for hardcore players without permadeath. Each mechanic is taught
   alone and fits in one sentence from the elder, or it's cut.

## Deferred to a later update (user, 2026-10-22)
These are real plans but **not in this pass**. Nothing before FE9 depends on them.
- **Alchemy:** the peak furnace, crafted pills (qi, heal, buffs, breakthrough aids,
  foundation repair), pill impurities and talismans. The mid-QR slowdown is met by
  the garden and the peak instead (user, 2026-10-23).
- **Weapon enhancement (refinement):** spend ore and stones to raise a weapon's
  grade. Candidate verb for Foundation Establishment.
- **Mining and ores** (the out verb that feeds refinement).
- **Body refinement:** a candidate verb for a later realm.
- **What stands in now:** herbs are eaten directly; pills, cores and elixirs are loot
  and shop items; foundation repair uses meditation, seclusion and tending; stones
  sink into the Herbalist, the Pavilion and building; weapon grades come from
  caches, bosses and the rack. Keep the hooks open (herb tier qi share, the item
  `use` system, a spare building slot for a furnace) so the update drops in.
- [core-loop](core-loop.md) already lists these as unscheduled crafting.

## 1. Progression

### Built (untuned)
27-stage ladder, `heavenDefying` tribulation gate, optional bosses on the quest
board ([progression](progression.md)).

### Phase A: foundation, the haul and the surge (decided 2026-10-23)
Replaces the solidity meter and the insight gate. No new HUD meter: the phone HUD
has no room, so the grade rides on toasts and the breakthrough card, and the surge
button only appears while it's ready.

**Foundation grade (per breakthrough).**
- Every breakthrough is graded **Cracked, Steady, Solid or Deep** by what the
  player experienced during that stage. Hunt (first kills of the region's beasts),
  Boss (counts double, the fast road), Home (first harvest of a herb tier, a rare
  mutation), Dao (weapon Dao milestones), Discover (wild gardens, caches, secret
  places) and World (events and phenomena). Pools are per region and realm, so they
  never run out. Time fills the bar, not the grade.
- **Shown only where there's room:** the grade on the breakthrough card and in the
  Cultivate window; one toast when the bar fills short of Solid ("Your foundation
  is unsteady. The world still has things to teach you."). Breaking through anyway
  is always allowed and simply takes the lower grade.
- **Each grade is a permanent stat bonus, and the gap is noticeable.** Two players
  at the same stage differ by how they climbed. A Deep foundation is the reward for
  exploring, never a requirement.
- **It weighs on the trials, not on the wall:** a cracked foundation makes the
  tribulation (heaven-defiers only) and the optional heart-demon trial harder.
  No normal player is walled by it.
- **Tempering:** old grades can be raised later (seclusion, passing a heart-demon
  trial at a major), so nobody replays stages to fix one.
- **Rejected:** a visible solidity meter (no HUD room); damaging your own
  cultivation to reroll stats (the best play becomes regrinding, which players hate).
  Shattering your cultivation stays a one-time story beat on the demon path
  ([replayability](roadmap/replayability.md)).

**The haul and the spirit ring: the cost of death (user, 2026-10-23).**
- Today death costs nothing, so surviving a fight doesn't matter. Now what you
  carry home is at stake, which gives "bring it home" in the loop its weight.
- **At risk: this trip's haul,** everything picked up since you last banked: raw qi
  in the dantian, herbs, seeds, materials and Spirit Stones. **Never at risk:**
  refined cultivation, stages, the equipped weapon, learned techniques, and rare
  finds (manuals, weapons, bloodline essences), which are banked the moment you
  pick them up.
- **Banking** happens on reaching home, the sect, or any teleport array.
- **The spirit ring:** a storage ring with a few safe slots; whatever is in it is
  banked even out in the wilds. More slots by realm or from the Pavilion. Choosing
  what goes in the ring is the interesting decision.
- **Death spills about half the unbanked haul** where you died, as a spirit-light
  only you can pick up, for about 5 minutes. No other player can loot it (no griefing,
  no PvP looting). A death never costs cultivation or a stage.
- **Leaving while combat-tagged counts as a death** (no combat logging).
- **Rejected:** a wound on the cultivation bar as the death cost. Two death
  penalties at once is where it turns hardcore.

**The qi surge (replaces the forced breakthrough).**
- **Its point:** survive and keep your haul. A clutch comeback, not insurance.
- **Ready** when the bar is at least 90% and health is low (today's `canForce`
  conditions).
- **Fire:** on mobile a surge button appears in the touch cluster while it's ready;
  on PC a notice reads "M to qi surge". M is Meditate today; while the surge is
  ready in combat, M surges instead (nobody meditates mid-fight). No prompt, no pause.
- **Effect:** about 15 s at the next stage's stats and a small heal; the realm plaque
  shows the higher stage.
- **Cost:** it burns a share of the raw qi in your dantian (or essence blood, if that
  becomes a resource), so it trades a little of the haul to save the rest. When the
  combat tag drops, one toast: "Your cultivation falls back."
- The real forced breakthrough and its qi debt are removed; breakthroughs are seated only.

**Insight is deleted (built).** It no longer gates breakthroughs (the walls are the bar,
plus the tribulation for heaven-defiers) and no longer pays for comprehension.
Its sources (first kills, bosses, milestones) become foundation experiences.
Technique gating moves to weapon Dao (section 4). First kills and boss kills are
still tracked as hooks but grant nothing until foundation experiences land.

**Shelved UI:** the solidity meter (`FoundationMeter.luau`) and the death-save
prompt (`DeathSave.luau`) from the UI pass. Phase A needs instead: the surge
button and "M to qi surge" notice, the grade line on the breakthrough card, the
spirit ring slots, and the spilled-haul spirit-light.

**Build order:** docs and Pacing numbers; the haul, banking and death spill; the
spirit ring; foundation grades and experience pools; the surge (insight deletion
is built).

### Pacing, realm gaps and verbs (decided 2026-10-23)
Research behind it: Roblox median sessions are 5-9 min and D7 is 3-8%, so the
first session decides; full Roblox RPGs run 30-100 h; cultivation games use about
8-12% per minor stage and 2-2.5x at a major.
- **Targets (active play):** QC about 2.5 h, QR about 7 h, FE about 20 h, so about
  30 h to FE9, which stays the cap and should be hard to reach. Passive and
  offline cultivation stretch it over real days.
- **Shape:** every realm is early (1-3), middle (4-6) and late (7-9), each easy to
  hard, with a breather opening each third so a breakthrough feels good. QC never
  slows early: the first session lands two or three breakthroughs. **The real
  slowdown is mid Qi Refining**, where investing in your spirit garden and your
  peak (abode, formations, herbs) is what keeps cultivation moving (user,
  2026-10-23; not alchemy).
- **No stretch over 2-3 h without something new** (a zone, boss, rift or verb).
- **Strength:** about +10% per minor stage and about 2-2.5x at a major, plus
  **realm suppression**: damage from a lower major realm is heavily reduced
  against a higher one, so a QC player can barely scratch an FE beast. That's the
  heaven-and-earth gap without huge multipliers. Techniques count about as much
  as realm, so one minor stage up is fightable and a major is not.
- **Each major brings a new verb, not just numbers:** QC the body and combat, QR
  the abode: the garden and peak building that boost cultivation (and qi leaving
  the body), FE weapon refinement and a first
  sword glide. Body refinement and others are kept for later realms.
- **Heaven-defiers** resist suppression partly, so they fight above their level
  and farm stronger beasts, bosses and herbs. They pay with about a 1.5x bar and a
  tribulation at every major.
- **Herbs:** the tier share of the dantian needs a floor per tier (early herbs
  became tiny), and event herbs (Thousand-Year Ginseng) must stay big.

**Built 2026-10-23 (untuned in play):** the curve to these targets (table and
formulas in the `Pacing.luau` header), strength (+10% a minor, x2.25 a major, beasts
following through `Pacing.BeastBaseline`), realm suppression (`Pacing.Suppression`,
0.2x per major, both ways), heaven-defiers' 1.5x bar and half suppression resist
(`Pacing.HeavenDefying`), herb floors and event-herb shares (`Pacing.Herbs`). Not
built: the new verb per major; nothing sets `heavenDefying` yet.

### Pacing follow-ups
Tune the QR and FE curve from analytics; the two bosses tuned for the old FE1 get
re-tiered; region seals wait for the map.

## 2. Onboarding (QC1 to QC9, then each realm)
Today the hook ends at QC3 and the garden, sect and techniques arrive unannounced.
- **The hook (2026-10-23, from Roblox metrics):** combat within the first minute or
  two and two or three breakthroughs in the first few minutes, one mechanic at a
  time. The current first ten minutes are being audited to retune it.
- **Spread over every realm, sprinkled as the player advances:** QC teaches the loop
  (out and home, the garden, the board); QR the social layer and the abode
  (master, Halls, seclusion, rifts, the heart demon); FE the depth (method,
  refinement, treasures, pets). Move the second weapon and Dao drills out of QC.
- **QC1-3 (keep):** circulate, break through, root, travel out, hunt, technique,
  refine. Minor fixes only.
- **QC3 end:** the elder names the loop once ("cultivate until you hit a wall,
  go out and break it, come home stronger"). Built: the first time he's talked to in
  free play ([onboarding](systems/onboarding.md) "Talking to the elder").
- **QC4 "your home grows":** garden and peak building taught as one beat (plant a
  seed, place one item). Rewarded.
- **QC5 the sect board:** daily tasks and contribution; the first chapter quest.
- **QC6 herbs matter:** eat a herb for qi; the Herbalist.
- **QC7 weapon and Dao:** second weapon class, a Dao drill (exists as lessons).
- **QC8 rumours:** the elder points at a secret place and a wild garden.
- **QC9 the realm wall:** the quiet breakthrough ceremony; for a heaven-defier, the
  tribulation with its own dialogue.
- **Every major** repeats the pattern: one new idea, said once by the elder,
  with a rewarded objective and a guide.
- **The wall card:** a persistent "your wall is X, go to Y" line (the objective line
  already exists; make it read in loop terms). Shows the current wall and at most
  two other goals.
- Build: reuse the lesson system in `Quests.luau`; add lessons, not beats. UI by
  the ui-designer.

## 3. The sect and quests
**MVP first (user, 2026-10-23):** rank, contribution, the board with dailies and one
chapter chain, and the Pavilion. Halls, masters, weeklies, bounties, spirit quests
and sect-wide goals are sprinkled in later as the player advances (QR onward).
Per [progression](progression.md): ranks, board, dailies, weeklies, chapter chains,
bounties, sect tasks, contribution and a Pavilion shop (never qi).
- **Data:** a contribution counter and rank in `PlayerData`; quest defs reuse
  `Quests.Quest`; dailies reset by day (like the daily login).
- **Peaceful quests exist beside every combat quest** (herb errand, tend the sect
  garden, find a place, build a feature on your peak).
- **Build order:** rank and contribution, then the board UI, then dailies, then
  chains per region. UI by the ui-designer.

## 3b. Sect structure and contribution (proposed 2026-10-22)
- **One official sect, run by NPCs, that everyone starts in.** It is the hub, the
  elder, the board and the Pavilion. The demon path leaves it for the Blood Sect
  (also NPC-run); a rogue belongs to neither.
- **Player groups sit under it as Halls.** A Hall is 10-30 players with a shared
  name, banner, a hall they furnish together, a shared plot, and a small board of
  group goals. A Hall can belong to the sect, the Blood Sect or be independent, so
  every path can form one. **Hall is the name (user, 2026-10-22).** Lineage is
  kept for the mentor tie below.
- **Lineage as a light mentor tie inside a Hall:** a senior takes a junior, both earn
  contribution when the junior advances. It helps new players, which helps retention.
- **Contribution is soft.** The sect board offers tasks; nothing nags. At most one
  dismissible prompt per session ("The elder summons disciples to the hall"), no
  penalty for ignoring it. Each playstyle contributes in its own currency: herbs from
  the gardener, beast cores from the fighter, pieces for the hall from the builder.
- **Spirit quests:** occasional special asks from a spirit or the heavens (find a
  lost spirit, tend a dying tree, carry a message), rare, a story beat each, with a
  small reward. They are flavour and a cadence hook, never a chore.
- **Sect-wide goals:** server-wide shared tasks (fill the storehouse, light the
  wards before a beast tide) that reward everyone who helped. Cadence and social in one.

## 3e. Reasons to meet other players (2026-10-23)
The realm gap shows against content, so players need reasons to cross paths:
- **Shared credit:** everyone who damages a beast gets their own loot; no kill-stealing.
- **Group world events and roaming beast kings**, rewards scaled to each player's realm,
  so a senior helping still earns.
- **Co-op rifts** with better loot as a party; sect board tasks with shared credit.
- Halls and lineage after the MVP.

## 3d. Relationships: masters, disciples and sect siblings (proposed 2026-10-22)
NPC masters at QR1, cohorts of nine with numbered seats and epithets, player masters, up to three masters, bloodline granting (trial chains, the Blood Rite) and the safety rules: [relationships](roadmap/relationships.md).

## 3c. Reward banners: show cultivation gains
Today gains show as small toasts, floating numbers and a Rewards feed. Players should
feel the big ones.
- **Three tiers.** *Small:* a floating number or a line in the feed (qi, stones).
  *Medium:* a top banner for a notable gain (a technique tier, a foundation
  tempered, a Herbarium entry, a quest done). *Big:* a full card with a short beat and
  sound for milestones (a breakthrough, a first of a category, a bloodline, a rank).
- **The card shows what changed:** the stat deltas, the new unlock, and one line on
  what to do next ("Your foundation is firm. The Outer Wastes are open.").
- **One card, three jobs (user, 2026-10-22).** The boss victory card
  (`Rewards.luau`, `StarterGui.Rewards.BossReward`: a title, a subtitle, reward tiles
  that land on it, rays, tap to close) is reused for **quest completion** and for
  **onboarding objectives**, which are two different things with different looks:
  - *Boss victory:* as today ("Victory", "<boss> defeated").
  - *Quest complete:* "Quest complete" with the quest's name; tiles for stones, qi,
    contribution and a manual; the sect or Hall crest. Rare and weighty.
  - *Onboarding objective:* "Objective complete", lighter and quicker (a smaller card
    or banner, short life), because the hook fires many in a few minutes. Same tiles.
  The server sends one Effect with a `kind`, a title and a subtitle (today it is
  `"boss"` with a name and qi); `openCard` takes those instead of hard-coding "Victory".
- **Never block play;** big cards are skippable and queue, one at a time.
- **Build:** a reward-banner component in the HUD, fed by one server event with a tier;
  existing "breakthrough" cards fold into it. `ui-designer`, designed with the user.
  **Built (2026-10-23, [reward banners](ui/rewards.md)):** `Rewards.show` with small,
  feed, banner and card tiers and `Effect "reward"`; the boss card, feed, region banner
  and toast restyled onto the kit; breakthroughs open the milestone card. Quests,
  onboarding objectives and bloodlines still have to send their specs.

## 4. Techniques and weapons (why they feel lackluster, and the fix)
**What exists:** 12 techniques (5 any-weapon, one skill per weapon class; the table in [combat](systems/combat.md)). They
are mostly damage with a cooldown, plus a comprehension bottleneck. I haven't
playtested them; this diagnosis is from the numbers and docs.

**Why they feel weak:** there is one skill per class, so there's no choice; nothing
rewards using them over M1; no enemy asks for a technique; and nothing combines.

**The fix, in four layers (revised 2026-10-22: fewer techniques, deeper ones):**
1. **Three skills per weapon class (21), found as manuals, unlocked by weapon
   mastery (user, 2026-10-23).** A technique can only be *learned* once that class's
   Dao level reaches the threshold its power and rarity set: about level 2, 5 and 8
   for the three skills (Dao runs 0-10). A beginner can't pick up a greatsword and
   learn Heaven-Splitting Descent. A found manual is always kept: it sits in the pouch
   reading "Requires Greatsword Dao 6", so a drop is a goal, never a dead pickup.
   Any-weapon arts check the player's highest class Dao (open: or their own threshold).
   Comprehension (breaking a tier bottleneck) costs Spirit Stones and needs a higher
   Dao level in the class, not insight (built: class skills need Dao 2, bottleneck k
   needs learn + 2k; the 21-skill set and the 5/8 thresholds aren't made yet).
2. **Techniques deepen instead of multiplying.** Each technique levels up
   (existing comprehension) through its visual tiers T1-T4 ([vfx style](vfx/style.md)),
   so one skill grows from a plain cast into a spectacle. No new content per level
   beyond the tiers.
3. **Give them jobs.** Statuses the game already has (poison, slow, stun,
   bleed) plus a few new ones (burn, chill, break): each class owns a status
   (sword: bleed; spear: pierce armor; staff: stun; greatsword: break guard).
4. **Make enemies ask for them.** Armoured beasts (the Stone Tortoise) need
   guard-break; fliers (the Flame Raven) need ranged or pull; packs reward area
   moves; bosses have weak points and openers that a technique exploits. Enemy
   designers bake this into each beast's card. Root element resonance (exists)
   and combo windows (a status plus a technique = a bonus) reward pairing.
- **Quantity target:** about 28: 21 class skills (3 per class, the 7 that exist
  are the first of each), plus 7 any-weapon arts (the 5 existing and 2 elemental).
  Cut from the earlier 50; more can come later as manuals.
- **Weapon and arts UI is a separate flow fix.** The Inventory holds the pouch,
  arts and weapons in tabs and the player juggles badges and "Requires a sword".
  Proposal: an **Arms window per weapon** (Dao level, its three skill slots and
  their unlock levels) and a **hotbar preset per weapon**, so swapping weapons
  swaps the arts row, and a quick-swap on the HUD badge. To scope with the
  ui-designer after the user lists what is clunky now.
- **Visuals:** `vfx` agent per technique batch.
- **Build order:** statuses and combo rules, then the Arms window and per-weapon
  presets, then re-pass the existing techniques, then a class at a time (fresh
  agent per class).

## 5. The spirit garden
**Today:** about 11 herbs in 3 soils (bed, pond, grove), 7 mutations, sizes,
weather effects, wild sprouts, the Herbalist, Grow Now, and an aura on cultivation.
Herbs have tiers I-III and eating a qi herb gives its tier's share of the current
dantian (`Pacing.Herbs.EAT_SHARE`, built untuned), so the garden keeps its value past QC6.

**Plan:**
- **Herb tiers** I-V tied to regions, qi as a share of the dantian
  ([progression](progression.md)); 3-4 new herbs per tier (about 20 more).
- **Alchemy is deferred** (see "Deferred to a later update"). Herbs are eaten directly
  for now; their sinks are the Herbalist, the sect's errands, the Herbarium and buffs.
- **Tending matters:** watering, pests or weather events, rare mutation chances,
  and size records. Keep it calm, no punishment for being away.
- **The Herbarium:** a collection index of every herb, size and mutation seen,
  with rewards. It's the "grow a garden" hook and feeds the Home experiences.
- **Wild gardens:** discoverable spots in each region ("Discover" foundation
  experiences); harvest once a day; a reason to explore.
- **Visiting:** walk through a friend's peak and gift a herb. A cheap social hook,
  and a way to show building.
- **Gardener road:** garden aura, seclusion and tempering carry a pure gardener to every
  wall, just slower than a fighter ([progression](progression.md) "Difficulty").
- **Sect garden:** a shared plot the sect tasks tend (quests with no combat).
- **Build order:** herb tiers and qi scaling (built: tier field and dantian share;
  regional tiers IV-V and region seeds still to come), then the Herbarium,
  then wild gardens (map), then visiting.

## 6. Building and assets
**Today:** about 40 items in 7 categories (cultivation, decor, furniture, garden,
lighting, nature, structures), realm-gated, with meditation and garden bonuses;
the peak swaps its look at Foundation only.
**Needed:** more assets, more reasons to build.
- **Peak tiers per major** (QC, QR, FE): the peak itself changes look at each
  major, not only Foundation.
- **Themed sets**, 10-15 pieces each, unlocked by realm, rank or quest:
  1. *Mortal courtyard* (QC): walls, gate, simple halls, bridges, stairs.
  2. *Jade pavilion* (QR): pavilions, a spirit pond with a bridge, lanterns.
  3. *Cloud palace* (FE): floating platforms, tiered halls, banners, sky gardens.
  4. *Herb house* (QR3): drying racks, herb shelves, a tea pavilion (the furnace comes with alchemy).
  5. *Library and training* (QR7): scroll shelves, weapon racks, training dummies.
  6. *Formations:* functional arrays (a meditation array, a garden-growth array),
     which are where most bonuses should live.
- **Rewards for building:** bonuses stay small and capped (`AURA_CAP`), but more
  items count: a "peak score" that adds to meditation and garden up to a cap.
- **Sources:** sect contribution (Pavilion), quest rewards, event drops, the
  Herbalist and market for stones, and a few cosmetic robux items.
- **Peak size and rooms:** a larger buildable area per major (a plot unlock).
- **Pipeline:** the `modeler` agent in Blender (FBX plus a placement script) for
  structures, and Studio parts for small props; `ui-designer` for the catalog.
  A fresh modeler per set; see [build](systems/build.md). Roughly 60-80 pieces over
  the three majors.

## 7. World events and tribulation VFX
Per [progression](progression.md) "World events" and
[world events plan](vfx/world_events.md): resume `world-fx` (Heaven Split,
Beast Surge, new events) and rebuild the tribulation (clouds, bolts, eye, aftermath).
Tribulations stay rare, so the VFX can be big.

## 8. Enemies
The roster is enough for now. Next: elite and apex tiers (tint, aura, one move),
wire the **cultivator enemies** as human opponents and sect-quest targets, and
tune the old FE1 bosses.

## 9. Replayability: why come back after the ladder
**Baked in, not bolted on (user, 2026-10-23):** no reincarnation at FE. What makes a
second run different is designed in now: races and bloodlines, the sect, rogue and
demon paths, random rifts, foundation grades to beat, and the haul's risk.
Rebirth with a legacy, paths as affiliations (sect, rogue, a secret demon path), mixed secret realms and rifts, cadence, endless goals, social, new realms; then the discoverable demon secret chain: [replayability](roadmap/replayability.md). Rule: build 1-3 only after the core loop and the ladder are proven in playtests.

## 9b. More cultivation elements (candidates, 2026-10-22; QC to FE9 only)
Proposals to pick from; none decided. Each must name its arrow into the loop.
1. **Seclusion (closed-door cultivation).** Start it on purpose: sit for hours (the
   existing offline cultivation, framed). On return a short story result ("you
   comprehended..."), tempers an old foundation grade, a small chance of a fortuitous encounter.
   Arrow: home. Perfect for gardeners and mobile players.
2. **Heart-demon trial.** A choice-based, no-reflex inner trial at a major breakthrough
   (dialogue and choices that reflect how you played), optional, repairs or deepens
   the foundation. Replaces "skill" with story. Arrow: breakthrough and foundation grade.
3. **Fortuitous encounters.** Rare, random, sharable moments while out: an old hermit
   in a ring, a dying cultivator's bequest, a hidden spring. Small rewards, big
   stories. Arrow: out (explore). The genre's best content-creator fuel.
4. **Pill impurities** *(later update, with alchemy).* Pills leave toxicity that clouds
   your foundation. Purify by meditating.
5. **Talismans** *(crafting is a later update).* Consumable charms: heals, wards, buffs,
   tribulation protection. Found and bought ones can come sooner.
6. **Formations (arrays).** Functional building: a gathering array, a growth array, a
   ward. Mostly the building plan; also a Dao ("Formation Dao") to comprehend.
7. **Spirit beast taming.** A tamed beast follows you (the cosmetic pet at FE6, earlier
   as an egg). Becomes the soul companion later. Arrow: strongest kid hook.
8. **Alignment and reputation.** Righteous, neutral and demonic standing from your
   deeds; changes how NPCs and masters treat you. Ties to the demon secret.
9. **Spar and rank duels (opt-in).** Friendly duels for rank, no progress at stake, a
   Hall rivalry. Optional, kids and mobile safe.
- **Skip for now:** lifespan (stress), dual cultivation (audience), PvP-for-progress,
  an open player auction (scams).

## 10. Order of work and who does it

**How we work (user, 2026-10-22):** one system at a time, designed and built with the
user in the main session, checked at each step. Subagents are for mass asset
generation only (technique VFX batches, building sets, model batches). The Agents
column below is who builds the *assets*, not who designs the system.
Each phase ends in a commit and a test-build playtest.

| Phase | Work | Agents |
|---|---|---|
| A | Foundation grades, the haul and spirit ring, the qi surge, insight deleted | main session; `ui-designer` for the surge button, ring slots and grade line |
| B | Herb tiers, qi scaling, Herbarium | main session |
| C | Sect: rank, contribution, board, dailies, Pavilion | main; `ui-designer` |
| D | Onboarding lessons QC4-QC9 and the wall card | main; `ui-designer` |
| E | Statuses, combo rules, then techniques class by class (**deferred**, 2026-10-23: enough enemies; systems first) | main; one `vfx` per batch |
| F | Building: peak tiers, sets, formations | `modeler` per set; `ui-designer` |
| G | World events and tribulation VFX | `world-fx` |
| H | Elite tiers, cultivators, curve tuning | `enemy-designer` per beast; analytics |
| I | Replayability: paths, rifts, cadence, leaderboards, then rebirth | main; `world-fx`, `modeler` |

A, B and C can run together if we split files carefully; D waits for C; E and F can
run alongside them. Before spawning, ask how many agents and sandbox Studios at once
([orchestration](agents/orchestration.md#how-many-at-once)).

**UI built ahead of its systems (ready to wire, 2026-10-23):** the
Herbarium ([herbarium](ui/herbarium.md)), the sect board, quest log, rank, Hall and
lineage screens ([sect board](ui/sect-board.md), [halls and masters](ui/halls-masters.md))
and the dialogue screen ([dialogue](ui/dialogue.md)). The systems behind them are not built.
The solidity meter and death-save prompt are shelved by Phase A.

## Open questions
- Foundation grade bonuses: which stats, and how big a gap between Cracked and Deep?
- How many experiences per stage make each grade?
- Spill share (half proposed), spirit-light lifetime (5 min proposed), ring slot counts.
- Surge length (15 s proposed), its raw-qi cost, and does it have a cooldown beyond the 90% bar?
- Essence blood: a resource of its own (for the surge, the Blood Rite, the demon path) or flavour?
- How much harder is a tribulation or heart-demon trial per grade below Solid?
- Does the Herbarium reward cosmetics only, or foundation experiences?
- Which building sets are robux and which are earnable? (earnable first)
- Rebirth: is it a full reset (keeping the legacy) or a parallel second character?
- How harsh is the Blood Rite's cost (one stage plus days of ebb, as drafted)?
- Which NPC masters, and what does each teach? (draft the cast with the user)
- Does a player master unlock at FE1 or a major above the disciple, whichever is later?
- How hinted is the demon secret: rumours only, or does the elder give a nudge?
- Does the demon path keep its own home peak look, or reuse the sect's with a demon skin?
